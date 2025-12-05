#!/bin/bash
PLUGIN_NAME="plugin_fix_scripts.sh"
LOG_FILE="$HOME/twisteros_supermanager/logs/plugin.log"
STATUS_JSON="$HOME/twisteros_supermanager/twister-dashboard/data/plugin_status.json"

echo "$(date '+%Y-%m-%d %H:%M:%S') 📝 Kontrola a oprava skriptů..." | tee -a "$LOG_FILE"

chmod +x $HOME/twisteros_supermanager/scripts/*.sh

jq --arg p "$PLUGIN_NAME" --arg s "✅ hotovo" '.[$p]=$s' "$STATUS_JSON" > "${STATUS_JSON}.tmp" && mv "${STATUS_JSON}.tmp" "$STATUS_JSON"

echo "✅ Skripty opraveny." | tee -a "$LOG_FILE"
