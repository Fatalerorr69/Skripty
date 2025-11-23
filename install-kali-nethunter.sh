#!/bin/bash
set -e

WORKDIR=~/kali-nethunter
ROOTFS_URL="https://kali.download/nethunter-images/current/rootfs/kali-nethunter-rootfs-full-arm64.tar.xz"

mkdir -p "$WORKDIR/rootfs"
cd "$WORKDIR"

echo "[+] Stahuji Kali NetHunter ARM64 rootfs..."
wget -O kali-nethunter-rootfs-full-arm64.tar.xz "$ROOTFS_URL"

echo "[+] Rozbaluji rootfs..."
sudo tar -xJf kali-nethunter-rootfs-full-arm64.tar.xz -C rootfs

echo "[+] Připravuji systémové mounty..."
for m in dev proc sys dev/pts; do
  sudo mkdir -p rootfs/$m
  sudo mount --bind /$m rootfs/$m
done

sudo mkdir -p rootfs/etc
sudo cp /etc/resolv.conf rootfs/etc/resolv.conf

echo "[+] Kopíruji instalační skript do chrootu..."
cat << 'EOF' | sudo tee rootfs/tmp/setup-kali.sh > /dev/null
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

echo "[CHROOT] Spouštím aktualizaci a instalaci..."
apt update
apt install -y \
kali-linux-core kali-linux-large \
xfce4 xrdp lightdm dbus-x11 policykit-1 \
locales language-pack-cs sudo net-tools mousepad network-manager \
metasploit-framework wireshark burpsuite aircrack-ng john \
nmap hydra sqlmap netcat hashcat htop gparted gnupg curl git

echo "cs_CZ.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
update-locale LANG=cs_CZ.UTF-8
export LANG=cs_CZ.UTF-8

echo -e "123456\n123456" | passwd root

systemctl enable xrdp
systemctl start xrdp

echo "[CHROOT] Instalace dokončena."
EOF

sudo chmod +x rootfs/tmp/setup-kali.sh

echo "[+] Připraveno. Nyní vstup do chrootu:"
echo "    sudo chroot $WORKDIR/rootfs /bin/bash"
echo "A uvnitř spusť: bash /tmp/setup-kali.sh"