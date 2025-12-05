#!/bin/bash
set -e
HOME_DIR="/home/starko"
NAS_DIR="${HOME_DIR}/Games/NAS/BIOS"
LOCAL_DIR="${HOME_DIR}/Games/BIOS"

echo "[BIOS Sync] Synchronizuji BIOS z NAS..."
mkdir -p "$LOCAL_DIR"
rsync -av --progress "$NAS_DIR/" "$LOCAL_DIR/"
echo "[BIOS Sync] Hotovo."
