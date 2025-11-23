#!/bin/bash

# Skript pro počáteční nastavení Raspberry Pi 5 po instalaci
# Autor: AI asistovaný
# Datum: 2025-09-12
# Verze: 1.0

set -e  # Skript zastaví při chybě

echo "=== Automatická konfigurace Raspberry Pi 5 po instalaci ==="

# --- 1. Aktualizace systému a instalace základních balíčků ---
echo "Aktualizace seznamu balíčků..."
sudo apt-get update

echo "Instalace základních nástrojů a závislostí..."
sudo apt-get install -y \
    vim git tmux curl wget htop \
    build-essential python3-dev python3-pip \
    openssh-server ufw

# --- 2. Konfigurace vzdáleného přístupu ---
echo "Nastavení SSH pro vzdálený přístup..."
sudo raspi-config nonint do_ssh 0  # Povolení SSH :cite[6]

echo "Nastavení VNC (volitelné)..."
sudo raspi-config nonint do_vnc 0  # Povolení VNC :cite[6]

# --- 3. Nastavení sítě a bezpečnosti ---
echo "Nastavení firewallu (UFW)..."
sudo ufw allow ssh
sudo ufw allow 80/tcp   # HTTP (pokud potřebné)
sudo ufw allow 443/tcp  # HTTPS (pokud potřebné)
sudo ufw --force enable  # Zapne firewall

echo "Nastavení statické IP (upravte podle své sítě)..."
# Poznámka: Upravte soubor /etc/dhcpcd.conf podle potřeby
STATIC_IP_CONFIG="
interface eth0
static ip_address=192.168.1.100/24
static routers=192.168.1.1
static domain_name_servers=8.8.8.8 1.1.1.1
"
echo "$STATIC_IP_CONFIG" | sudo tee -a /etc/dhcpcd.conf

# --- 4. Optimalizace systému pro Raspberry Pi 5 ---
echo "Optimalizace výkonu a nastavení..."

# Rozšíření filesystému na celou SD kartu :cite[6]
sudo raspi-config nonint do_expand_rootfs

# Nastavení GPU paměti na 256 MB (pro 8GB model upravte)
sudo raspi-config nonint do_memory_split 256

# Zákaz spořiče obrazovky
sudo raspi-config nonint do_blanking 1

# --- 5. Konfigurace hardwarových rozhraní ---
echo "Povolování hardwarových rozhraní..."
sudo raspi-config nonint do_i2c 0    # Povolení I2C :cite[6]
sudo raspi-config nonint do_spi 0    # Povolení SPI :cite[6]
sudo raspi-config nonint do_serial 0 # Povolení sériového portu :cite[6]

# --- 6. Instalace a konfigurace nymea ---
echo "Instalace nymea-core..."
# Předpokládáme, že obraz nymea.io již je nainstalován.
# Pokud ne, odkomentujte následující řádky:
# wget https://nymea.io/documentation/users/installation/core
# sudo dpkg -i nymea-core_*.deb
# sudo apt-get install -f

echo "Nastavení nymea jako služby..."
sudo systemctl enable nymea
sudo systemctl start nymea

# --- 7. Nastavení uživatelského prostředí ---
echo "Nastavení časové zóny na Europe/Prague..."
sudo timedatectl set-timezone Europe/Prague

echo "Nastavení lokalizace na CZ..."
sudo raspi-config nonint do_change_locale cs_CZ.UTF-8
sudo raspi-config nonint do_configure_keyboard cz

# --- 8. Čištění a finální úpravy ---
echo "Aktualizace systému na nejnovější verze..."
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get autoremove -y
sudo apt-get autoclean -y

echo "Přidání uživatele do potřebných skupin..."
sudo usermod -a -G gpio,i2c,spi $USER

echo "=== Konfigurace dokončena ==="
echo "Doporučujeme restartovat systém: sudo reboot"