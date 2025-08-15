#!/usr/bin/env bash
set -euo pipefail

source .env

TMPL_ID=$TEMPLATE_ID
TMPL_NAME=ubuntu-server-cloudimage
TMPL_MEMORY=2048
TMPL_NETWORK=virtio,bridge=vmbr0
TMPL_STORAGE=local-lvm

CI_USER=k3s-admin

# Storage für Snippets (Proxmox-Standard: 'local')
SNIPPETS_STORAGE=local
SNIPPETS_DIR="/var/lib/vz/snippets"
LOCAL_SNIPPET_FILE="./template-bootstrap/ansible-ready.yaml"  # Liegt neben diesem Script
SNIPPET_FILE="${SNIPPETS_DIR}/ansible-ready.yaml"

# ensure, that file exists
CLOUDIMAGE_ISO=/var/lib/vz/template/iso/noble-server-cloudimg-amd64.img

# Image prüfen
if [[ ! -f "$CLOUDIMAGE_ISO" ]]; then
  echo "Fehler: Cloud-Image nicht gefunden: $CLOUDIMAGE_ISO" >&2
  exit 1
fi

# SSH-Key prüfen
if [[ ! -f .ssh/id_rsa.pub ]]; then
  echo "Fehler: SSH Public Key .ssh/id_rsa.pub nicht gefunden." >&2
  exit 1
fi

# Snippet-Datei prüfen
if [[ ! -f "$LOCAL_SNIPPET_FILE" ]]; then
  echo "Fehler: Snippet-Datei $LOCAL_SNIPPET_FILE nicht gefunden." >&2
  exit 1
fi

# Passwort abfragen
read -r -s -p "Passwort für '${CI_USER}' eingeben: " TMPL_PASSWORD; echo
if [[ -z "${TMPL_PASSWORD}" ]]; then
  echo "Fehler: Passwort darf nicht leer sein." >&2
  exit 1
fi
read -r -s -p "Passwort wiederholen: " TMPL_PASSWORD2; echo
if [[ "${TMPL_PASSWORD}" != "${TMPL_PASSWORD2}" ]]; then
  echo "Fehler: Passwörter stimmen nicht überein." >&2
  exit 1
fi
unset TMPL_PASSWORD2
trap 'unset TMPL_PASSWORD' EXIT

# Snippet nach Proxmox kopieren
mkdir -p "$SNIPPETS_DIR"
cp "$LOCAL_SNIPPET_FILE" "$SNIPPET_FILE"

# Template erstellen
qm create $TMPL_ID --memory $TMPL_MEMORY --name $TMPL_NAME --net0 $TMPL_NETWORK
qm importdisk $TMPL_ID $CLOUDIMAGE_ISO $TMPL_STORAGE
qm set $TMPL_ID --scsihw virtio-scsi-pci --scsi0 $TMPL_STORAGE:vm-${TMPL_ID}-disk-0
qm set $TMPL_ID --ide2 $TMPL_STORAGE:cloudinit
qm set $TMPL_ID --boot c --bootdisk scsi0
qm set $TMPL_ID --serial0 socket --vga serial0

# Benutzer + Keys
qm set $TMPL_ID --ciuser "$CI_USER" --cipassword "$TMPL_PASSWORD"
qm set $TMPL_ID --sshkeys .ssh/id_rsa.pub

# Snippet zuordnen
qm set $TMPL_ID --cicustom "user=${SNIPPETS_STORAGE}:snippets/$(basename "$SNIPPET_FILE")"

# In Template umwandeln
qm template $TMPL_ID

echo "✅ Template $TMPL_ID ($TMPL_NAME) erstellt."
echo "   Cloud-Init Snippet '${LOCAL_SNIPPET_FILE}' wurde angehängt."