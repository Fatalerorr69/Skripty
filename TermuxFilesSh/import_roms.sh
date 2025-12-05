#!/bin/bash
set -e
HOME_DIR="/home/starko"
ROMS_DIR="${HOME_DIR}/Games/ROMs"
RETROARCH_DIR="${HOME_DIR}/Games/RetroArch/roms"

echo "[Import] Kopíruji ROM do RetroArch..."
mkdir -p "$RETROARCH_DIR"
cp -v "$ROMS_DIR/"* "$RETROARCH_DIR/"
echo "[Import] Hotovo."
