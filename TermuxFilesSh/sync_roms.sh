#!/bin/bash
set -e
HOME_DIR="/home/starko"
NAS_DIR="${HOME_DIR}/Games/NAS/ROMs"
LOCAL_DIR="${HOME_DIR}/Games/ROMs"

echo "[ROM Sync] Synchronizuji ROM z NAS..."
mkdir -p "$LOCAL_DIR"
rsync -av --progress "$NAS_DIR/" "$LOCAL_DIR/"
echo "[ROM Sync] Hotovo."
