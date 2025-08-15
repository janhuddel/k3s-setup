#!/usr/bin/env bash
set -euo pipefail

source .env

TMPL_ID=$TEMPLATE_ID
TMPL_NAME=ubuntu-server-cloudimage
TMPL_MEMORY=2048
TMPL_NETWORK=virtio,bridge=vmbr0
TMPL_STORAGE=local-lvm

CI_USER=k3s-admin

# ensure, that file exists
CLOUDIMAGE_ISO=/var/lib/vz/template/iso/noble-server-cloudimg-amd64.img

# Vorab prüfen, ob das Image existiert
if [[ ! -f "$CLOUDIMAGE_ISO" ]]; then
  echo "Fehler: Cloud-Image nicht gefunden: $CLOUDIMAGE_ISO" >&2
  exit 1
fi

# Passwort sicher abfragen (verdeckt) + Bestätigung
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

qm create $TMPL_ID --memory $TMPL_MEMORY --name $TMPL_NAME --net0 $TMPL_NETWORK
qm importdisk $TMPL_ID $CLOUDIMAGE_ISO $TMPL_STORAGE
qm set $TMPL_ID --scsihw virtio-scsi-pci --scsi0 $TMPL_STORAGE:vm-${TMPL_ID}-disk-0
qm set $TMPL_ID --ide2 $TMPL_STORAGE:cloudinit
qm set $TMPL_ID --boot c --bootdisk scsi0
qm set $TMPL_ID --serial0 socket --vga serial0
qm set $TMPL_ID --ciuser "$CI_USER" --cipassword "$TMPL_PASSWORD"
qm set $TMPL_ID --sshkeys .ssh/id_rsa.pub

qm template $TMPL_ID
