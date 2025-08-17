#!/usr/bin/env bash
set -euo pipefail

source .env

# --- Parameter validation ---
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <NEWID> <NAME> [STORAGE] [IP] [DISK_SIZE]"
    echo "  NEWID     : Required – New VM ID"
    echo "  NAME      : Required – Name of the new VM"
    echo "  STORAGE   : Optional – Storage name (default: syno-nfs-01)"
    echo "  IP        : Optional – IP address in CIDR notation, e.g., 172.22.1.102/13"
    echo "  DISK_SIZE : Optional – Disk size (e.g., 20G for 20GB)"
    exit 1
fi

NEWID="$1"
NAME="$2"
STORAGE="${3:-syno-nfs-01}"
IP="${4:-}"
DISK_SIZE="${5:-}"

RAM=4096
CORES=2

# --- Clone VM ---
qm clone $TEMPLATE_ID "$NEWID" --name "$NAME" --full --storage "$STORAGE"

# --- Adjust hardware ---
qm set "$NEWID" --memory $RAM
qm set "$NEWID" --cores $CORES

# --- Resize disk if a disk size is specified ---
if [[ -n "$DISK_SIZE" ]]; then
    qm resize "$NEWID" scsi0 "$DISK_SIZE"
fi

# --- Set IP, if specified ---
if [[ -n "$IP" ]]; then
    # Adjust gateway, if necessary
    qm set "$NEWID" --ipconfig0 ip="$IP",gw=172.16.1.1
fi

# --- Start VM ---
qm start "$NEWID"

echo "VM $NAME (ID $NEWID) was successfully created and started."
