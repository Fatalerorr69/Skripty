#!/usr/bin/env bash
set -euo pipefail
echo "[*] Mountuji VBoxGuestAdditions (pokud je vloženo CD)..."
MNT="/mnt/vbox_cdrom"
sudo mkdir -p "$MNT"
if ! mount | grep -q "$MNT"; then
  sudo mount /dev/cdrom "$MNT" || sudo mount /dev/sr0 "$MNT" || true
fi
if [ -x "$MNT/VBoxLinuxAdditions.run" ]; then
  echo "[*] Spouštím instalátor..."
  sudo bash "$MNT/VBoxLinuxAdditions.run" || true
else
  echo "[!] VBoxLinuxAdditions.run nebyl nalezen. Vložte CD z VirtualBoxu."
fi