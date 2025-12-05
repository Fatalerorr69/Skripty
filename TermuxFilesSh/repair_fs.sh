#!/bin/bash
# ===============================================================
# repair_fs.sh – Oprava souborového systému
# ===============================================================

echo "🧹 Kontroluji /dev/mmcblk0p2 (root)..."
sudo umount /dev/mmcblk0p2 || true
sudo fsck.ext4 -Fy /dev/mmcblk0p2

echo "🧹 Kontroluji /dev/mmcblk0p1 (boot)..."
sudo umount /dev/mmcblk0p1 || true
sudo fsck.vfat -Fy /dev/mmcblk0p1

echo "📂 Oprava HOTOVA"
