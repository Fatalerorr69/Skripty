#!/bin/bash
# Automatická instalace a konfigurace emulátorů
# Umístění: /opt/twisteros_supermanager/scripts/setup_emulators.sh

set -e

echo "=== Instalace základních balíčků ==="
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install -y \
    wine64 wine32 \
    box64 \
    retroarch \
    retroarch-joypad-autoconfig \
    libsdl2-2.0-0 \
    libgl1-mesa-glx \
    libvulkan1 \
    git curl unzip

echo "=== Kontrola Box64 ==="
if command -v box64 >/dev/null 2>&1; then
    echo "Box64 nainstalován."
else
    echo "Box64 nebyl nalezen, instalace přes PPA..."
    sudo add-apt-repository ppa:cybermax-dexter/box64
    sudo apt update
    sudo apt install -y box64
fi

echo "=== Konfigurace Wine ==="
winecfg &>/dev/null &
sleep 5
echo "Wine inicializován."

echo "=== Konfigurace RetroArch ==="
mkdir -p ~/RetroArch
retroarch --menu &>/dev/null &
sleep 5
echo "RetroArch připraven."

echo "=== Nastavení NAS jako trvalý mount ==="
NAS_DIR="/opt/twisteros_supermanager/nas_storage"
mkdir -p "$NAS_DIR"
read -p "Zadej NAS IP/Share (např. 192.168.1.100/share): " NAS_ADDR
read -p "Uživatel NAS: " NAS_USER
read -s -p "Heslo NAS: " NAS_PASS
echo
sudo mount -t cifs "//$NAS_ADDR" "$NAS_DIR" -o username=$NAS_USER,password=$NAS_PASS
echo "NAS připojeno do $NAS_DIR"

echo "=== Všechny emulátory a závislosti jsou připraveny ==="
