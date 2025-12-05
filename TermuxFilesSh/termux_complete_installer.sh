#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "==============================================="
echo "   TERMUX COMPLETE PACK INSTALLER"
echo "   Instalace všech dostupných doplňků"
echo "==============================================="

echo "[1/10] Aktualizace systému..."
pkg update -y && pkg upgrade -y

echo "[2/10] Aktivace všech repozitářů..."
pkg install root-repo -y
pkg install x11-repo -y
pkg install science-repo -y

echo "[3/10] Instalace základních nástrojů..."
pkg install -y git wget curl nano vim htop unzip zip tar proot tsu \
openssh net-tools dnsutils whois nmap iproute2

echo "[4/10] Instalace vývojových jazyků..."
pkg install -y python python-pip nodejs golang rust clang cmake make \
automake autoconf llvm pkg-config

echo "[5/10] Instalace archivních nástrojů..."
pkg install -y p7zip unrar brotli zstd xz-utils

echo "[6/10] Instalace bezpečnostních a RE nástrojů..."
pkg install -y hydra sqlmap nmap hashcat binutils radare2 gdb ltrace \
strace tcpdump john sslscan

echo "[7/10] Instalace Android/ADB nástrojů..."
pkg install -y termux-api android-tools aapt apksigner

echo "[8/10] Instalace GUI prostředí (XFCE4 + VNC)..."
pkg install -y tigervnc xfce4 xfce4-goodies xorg-xhost xorg-xrandr xorg-xsetroot

echo "[9/10] Instalace databází..."
pkg install -y sqlite postgresql redis mariadb

echo "[10/10] Instalace úplně všech balíčků z Termux repozitářů..."
for pkg in $(pkg list-all | cut -d' ' -f1 | tail -n +2); do
    pkg install -y $pkg || true
done

echo "==============================================="
echo "  Instalace dokončena!"
echo "  Všechny dostupné doplňky byly nainstalovány."
echo "==============================================="

echo "Spuštění XFCE:"
echo "vncserver -geometry 1280x720"
