#!/bin/bash
# ===============================================================
# kernel_selfheal.sh – Oprava kernelu a firmware
# ===============================================================

echo "🛠 Kernel SelfHeal..."

sudo apt install --reinstall -y raspberrypi-kernel raspberrypi-bootloader raspberrypi-kernel-headers

echo "📁 Opravuji firmware..."
sudo apt install --reinstall -y raspberrypi-firmware || true

echo "🔄 Kontrola modprobe..."
sudo depmod -a

echo "🔧 Oprava initramfs..."
sudo update-initramfs -u || true

echo "✅ Kernel SelfHeal hotov!"
