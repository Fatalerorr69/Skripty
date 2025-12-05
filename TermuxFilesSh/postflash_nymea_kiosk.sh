#!/usr/bin/env bash
#
# postflash_nymea_kiosk.sh
#
#pred instalaci skriptu
#sudo apt update && sudo apt install sshpass -y
#chmod +x postflash_nymea_kiosk.sh
#sudo ./postflash_nymea_kiosk.sh
#
#
# Interaktivní skript pro:
# 1) nastavení Wi-Fi + SSH na boot partition
# 2) vzdálenou konfiguraci Nymea Kiosk přes SSH
#

set -euo pipefail

# 1) Zjisti boot partition
echo -n "Zadej cestu k boot partition (např. /dev/sdX1): "
read -r BOOT_PART
if [[ ! -b "$BOOT_PART" ]]; then
  echo "Chyba: $BOOT_PART není block device." >&2
  exit 1
fi

# 2) Parametry sítě
echo -n "SSID Wi-Fi (např. Tenda): "
read -r SSID

echo -n "Heslo Wi-Fi (ponech prázdné pro otevřenou síť): "
read -r PSK

# 3) SSH přístup
echo -n "Cílová IP adresa zařízení (např. 192.168.1.50): "
read -r TARGET_IP

echo -n "Výchozí SSH heslo uživatele nymea (např. nymea): "
read -r SSH_PASS

# 4) Příprava boot partition
echo "=> Připojuji boot partition…"
MNT="/mnt/nymea-boot"
mkdir -p "$MNT"
mount "$BOOT_PART" "$MNT"

# 4.1) Konfigurace Wi-Fi
echo "=> Vytvářím wpa_supplicant.conf…"
cat > "$MNT/wpa_supplicant.conf" <<EOF
country=CZ
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
  ssid="${SSID}"
EOF

if [[ -z "$PSK" ]]; then
  cat >> "$MNT/wpa_supplicant.conf" <<EOF
  key_mgmt=NONE
}
EOF
else
  cat >> "$MNT/wpa_supplicant.conf" <<EOF
  psk="${PSK}"
  key_mgmt=WPA-PSK
}
EOF
fi

# 4.2) Povol SSH
touch "$MNT/ssh"

sync
umount "$MNT"
rmdir "$MNT"
echo "✅ Boot partition připravena."

# 5) Čekání na SSH
echo -n "⌛ Čekám na SSH na ${TARGET_IP} "
for i in {1..20}; do
  if sshpass -p "$SSH_PASS" ssh -q -o StrictHostKeyChecking=no -o ConnectTimeout=5 nymea@"$TARGET_IP" true; then
    echo "OK"
    break
  fi
  sleep 5
  echo -n "."
  if [[ $i -eq 20 ]]; then
    echo -e "\n❌ Nepodařilo se připojit přes SSH." >&2
    exit 1
  fi
done

# 6) Vzdálená konfigurace
echo "=> Spouštím vzdálenou konfiguraci…"
sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no nymea@"$TARGET_IP" bash <<'EOF_REMOTE'
set -euo pipefail

# 6.1 Změna hesla nymea
NEWPASS=$(openssl rand -base64 12)
echo "nymea:$NEWPASS" | sudo chpasswd
echo "• Heslo 'nymea' → $NEWPASS"

# 6.2 Vytvoření uživatele operator
sudo adduser --disabled-password --gecos "" operator
echo "operator:operator" | sudo chpasswd
sudo usermod -aG dialout operator

# 6.3 Časové pásmo + aktualizace
sudo timedatectl set-timezone Europe/Prague
sudo apt update && sudo apt upgrade -y

# 6.4 Firewall & Fail2Ban
sudo apt install ufw fail2ban -y
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw --force enable
cat <<F2B | sudo tee /etc/fail2ban/jail.local
[sshd]
enabled = true
maxretry = 3
bantime  = 3600
F2B
sudo systemctl restart fail2ban

# 6.5 Utilitní balíčky
sudo apt install htop netdata rsync -y

# 6.6 Nymea Core & App + kiosk služba
sudo apt install nymea-core nymea-app -y
cat <<SVC | sudo tee /etc/systemd/system/nymea-kiosk.service
[Unit]
Description=Nymea Kiosk Mode
After=network.target

[Service]
User=nymea
ExecStart=/usr/bin/nymea-app --kiosk --log /var/log/nymea-app.log
Restart=on-failure
LimitNOFILE=4096

[Install]
WantedBy=graphical.target
SVC
sudo systemctl daemon-reload
sudo systemctl enable nymea-kiosk.service
sudo systemctl start nymea-kiosk.service

# 6.7 Autologin do GUI
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
cat <<GETTY | sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin nymea --noclear %I \$TERM
GETTY
sudo systemctl daemon-reload

# 6.8 Demo plugin: DHT22
sudo apt install nymea-plugin-humidity -y
cat <<HUM | sudo tee /etc/nymea/plugin-humidity.yaml
device: /dev/ttyAMA0
sensor:
  type: DHT22
  pin: 4
updateInterval: 60s
HUM
sudo systemctl restart nymea-core

echo "🎉 Vzdálená konfigurace dokončena."
EOF_REMOTE

echo "✅ Instalace i konfigurace úspěšně dokončeny!"