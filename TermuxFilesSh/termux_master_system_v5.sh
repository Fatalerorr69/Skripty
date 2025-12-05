#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "======================================================"
echo "  TERMUX MASTER SYSTEM v5"
echo "  COMPLETE PACK + UBUNTU + KALI + OPTIMALIZACE + GUI"
echo "  GUI: XFCE4"
echo "======================================================"

############################################
# 1) ZÁKLADNÍ AKTUALIZACE
############################################
echo "[1/12] Aktualizace Termuxu..."
pkg update -y && pkg upgrade -y

############################################
# 2) REPOZITÁŘE
############################################
echo "[2/12] Aktivace všech repozitářů..."
pkg install root-repo -y
pkg install x11-repo -y
pkg install science-repo -y

############################################
# 3) INSTALACE VŠECH DOPLŇKŮ (COMPLETE PACK)
############################################
echo "[3/12] Instalace základních nástrojů..."
pkg install -y git wget curl nano vim htop unzip zip tar proot tsu \
net-tools dnsutils whois iproute2 openssh proot-distro

echo "[3B] Vývojové nástroje..."
pkg install -y python python-pip nodejs golang rust clang cmake make \
automake autoconf llvm pkg-config

echo "[3C] Archivní a utility balíky..."
pkg install -y p7zip unrar brotli zstd xz-utils

echo "[3D] Security + hacking + RE nástroje..."
pkg install -y hydra sqlmap nmap hashcat radare2 gdb ltrace strace \
tcpdump john sslscan

echo "[3E] Android / systém..."
pkg install -y termux-api android-tools aapt apksigner

############################################
# 4) GUI – XFCE4 + VNC (pro Termux)
############################################
echo "[4/12] Instalace GUI XFCE4 pro Termux..."
pkg install -y tigervnc xfce4 xfce4-goodies \
xorg-xhost xorg-xrandr xorg-xsetroot

mkdir -p ~/.vnc
echo "#!/bin/sh
xrdb $HOME/.Xresources
startxfce4 &
" > ~/.vnc/xstartup
chmod +x ~/.vnc/xstartup

############################################
# 5) OPTIMALIZACE TERMUXU
############################################
echo "[5/12] Aplikace optimalizací..."
mkdir -p ~/.config
echo "ulimit -n 1048576" >> ~/.profile
echo "export LANG=cs_CZ.UTF-8" >> ~/.profile

############################################
# 6) INSTALACE UBUNTU
############################################
echo "[6/12] Instalace Ubuntu (proot-distro)..."
proot-distro install ubuntu || true

############################################
# 7) KONFIGURACE UBUNTU
############################################
echo "[7/12] Konfigurace Ubuntu..."

proot-distro login ubuntu -- bash -c "
apt update
apt install -y xfce4 xfce4-goodies tightvncserver \
git wget curl sudo locales nano software-properties-common
locale-gen cs_CZ.UTF-8
"

############################################
# 8) INSTALACE KALI LINUX
############################################
echo "[8/12] Instalace Kali Linuxu..."
proot-distro install kali || true

############################################
# 9) KONFIGURACE KALI LINUXU
############################################
echo "[9/12] Konfigurace Kali Linuxu..."

proot-distro login kali -- bash -c "
apt update
apt install -y xfce4 xfce4-goodies tightvncserver \
git wget curl nano sudo locales
locale-gen cs_CZ.UTF-8

apt install -y kali-linux-headless \
hydra nmap sqlmap hashcat wireshark aircrack-ng \
binwalk radare2 gdb john
"

############################################
# 10) AUTO-GUI STARTERY
############################################
echo "[10/12] Vytvářím startovací skripty..."

# Termux XFCE
cat > ~/start-termux-xfce.sh << 'EOF'
vncserver -geometry 1280x720
EOF
chmod +x ~/start-termux-xfce.sh

# Ubuntu XFCE
cat > ~/start-ubuntu.sh << 'EOF'
proot-distro login ubuntu -- bash -c "vncserver -geometry 1280x720"
EOF
chmod +x ~/start-ubuntu.sh

# Kali XFCE
cat > ~/start-kali.sh << 'EOF'
proot-distro login kali -- bash -c "vncserver -geometry 1280x720"
EOF
chmod +x ~/start-kali.sh

############################################
# 11) SDÍLENÁ SLOŽKA pro Ubuntu + Kali
############################################
echo "[11/12] Nastavuji sdílenou složku ~/shared ..."
mkdir -p ~/shared
proot-distro login ubuntu -- mkdir -p /root/shared
proot-distro login kali -- mkdir -p /root/shared

############################################
# 12) FINÁLNÍ INFO
############################################
echo "======================================================"
echo "  INSTALACE DOKONČENA!"
echo "======================================================"
echo "Spuštění XFCE pro Termux:"
echo "   bash start-termux-xfce.sh"
echo
echo "Spuštění Ubuntu GUI:"
echo "   bash start-ubuntu.sh"
echo
echo "Spuštění Kali GUI:"
echo "   bash start-kali.sh"
echo
echo "VNC přístup:"
echo "   V prohlížeči / VNC Viewer: 127.0.0.1:5901"
echo "======================================================"
