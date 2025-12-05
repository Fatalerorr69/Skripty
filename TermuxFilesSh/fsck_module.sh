#!/bin/bash
MODULE_NAME="fsck_module.sh"
LOG_FILE="$HOME/twisteros_supermanager/logs/plugin.log"

echo "$(date '+%Y-%m-%d %H:%M:%S') 🗄 Spouštím FSCK modul..." | tee -a "$LOG_FILE"

# Automatická kontrola všech disků (bez interaktivního potvrzení)
sudo fsck -AR -y

echo "$(date '+%Y-%m-%d %H:%M:%S') ✅ FSCK modul dokončen." | tee -a "$LOG_FILE"
