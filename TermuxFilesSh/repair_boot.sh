#!/bin/bash
# ===============================================================
# repair_boot.sh – Oprava boot sekce pro TwisterOS/RPi5
# ===============================================================

BOOT=/boot

echo "🔧 Opravuji config.txt..."
sudo tee $BOOT/config.txt >/dev/null << EOF
arm_64bit=1
gpu_mem=512
dtoverlay=vc4-kms-v3d
disable_overscan=1
EOF

echo "📌 Opravuji cmdline.txt..."
sudo tee $BOOT/cmdline.txt >/dev/null << EOF
console=serial0,115200 console=tty1 root=PARTUUID=$(blkid -s PARTUUID -o value /dev/mmcblk0p2) rw fsck.repair=yes rootwait quiet splash
EOF

echo "🔁 Obnova bootloaderu..."
sudo rpi-eeprom-update -a || true

echo "✅ Boot opraven!"
