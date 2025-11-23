#!/bin/bash
# Zálohovací skript pro nymea
BACKUP_DIR="/home/nymea/backups"
DATE=$(date +%Y%m%d_%H%M%S)

# Vytvoření zálohy
sudo nymeadctl --backup $BACKUP_DIR/nymea-backup-$DATE.tar.gz

# Smazání starých záloh (starších než 30 dní)
find $BACKUP_DIR -name "*.tar.gz" -mtime +30 -delete

echo "Záloha vytvořena: $BACKUP_DIR/nymea-backup-$DATE.tar.gz"