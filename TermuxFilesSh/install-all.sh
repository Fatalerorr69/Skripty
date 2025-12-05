#!/bin/bash
# Nymea:Kiosk Ultimate System - All-in-one Installer
# Verze: 3.5
# Autor: Fatalerorr69

set -e

LOG_FILE="/var/log/nymea-kiosk-install.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "===== Začínám instalaci Nymea:Kiosk Ultimate System ====="

# 1. Aktualizace systému
log "Aktualizuji systém..."
sudo apt-get update -y && sudo apt-get upgrade -y

# 2. Instalace základních balíčků
log "Instaluji potřebné balíčky..."
sudo apt-get install -y unzip git wget curl nano htop unzip fail2ban

# 3. Rozbalení archivu (pokud existuje)
if [ -f "nymeakiosk-ultimate-system.zip" ]; then
    log "Rozbaluji archiv..."
    unzip -o nymeakiosk-ultimate-system.zip -d /opt/nymeakiosk
else
    log "Soubor nymeakiosk-ultimate-system.zip nenalezen. Přeskočeno."
fi

cd /opt/nymeakiosk || { log "Nelze přejít do /opt/nymeakiosk"; exit 1; }

# 4. Instalace Nymea
log "Instaluji nymea:core a nymea:app..."
sudo apt-get install -y nymea nymea-app nymea-plugins

# 5. Nastavení služby
log "Povolím a spustím služby..."
sudo systemctl enable nymead
sudo systemctl start nymead

# 6. Instalace pluginů
log "Instaluji všechny pluginy..."
./scripts/install-plugins.sh --all || true

# 7. Nastavení Kiosk režimu
log "Konfiguruji kiosk režim..."
./scripts/setup-kiosk.sh --orientation=landscape --autostart=true || true

# 8. Zabezpečení
log "Nastavuji zabezpečení..."
sudo systemctl enable fail2ban

# 9. Monitoring a dashboardy
log "Instaluji monitoring..."
sudo apt-get install -y prometheus grafana

sudo systemctl enable prometheus grafana-server
sudo systemctl start prometheus grafana-server

# 10. Zálohy
log "Nastavuji zálohování..."
./scripts/configure-backup.sh --frequency=daily --retention=30 || true

# 11. Dokončení
log "===== Instalace dokončena! ====="
log "Web rozhraní: http://$(hostname -I | awk '{print $1}'):8080"
log "Grafana: http://$(hostname -I | awk '{print $1}'):3000"
log "Prometheus: http://$(hostname -I | awk '{print $1}'):9090"
