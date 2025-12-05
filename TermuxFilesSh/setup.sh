#!/bin/bash
# Rychlý setup skript - pouze instalace Dockeru a základní struktury

set -e

# Barvy
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
error() { echo -e "${RED}[CHYBA]${NC} $1"; exit 1; }

log "Spouštím rychlý setup Ultimate Raspberry Pi 5 Installer"

# Kontrola root práv
if [[ $EUID -eq 0 ]]; then
    error "Skript nesmí být spuštěn jako root!"
fi

# Aktualizace systému
log "Aktualizace systému..."
sudo apt update && sudo apt upgrade -y

# Instalace Dockeru
log "Instalace Dockeru..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
rm get-docker.sh
sudo usermod -aG docker $USER

# Vytvoření adresářů
log "Příprava adresářové struktury..."
mkdir -p ~/docker-stack/{config,data,backups,scripts}
mkdir -p ~/docker-stack/config/{portainer,heimdall,nextcloud,vaultwarden,jellyfin,homeassistant,pihole}

log "Rychlý setup dokončen!"
echo "Pro kompletní instalaci spusťte: ./install.sh"
