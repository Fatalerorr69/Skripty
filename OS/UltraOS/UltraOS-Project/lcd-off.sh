#!/bin/bash
echo "Obnovuji výstup na HDMI..."

# Obnov původní konfigurace
sudo cp /boot/config.txt.bak /boot/config.txt
sudo cp /boot/cmdline.txt.bak /boot/cmdline.txt

echo "Hotovo. Restartuj Raspberry Pi: sudo reboot"
