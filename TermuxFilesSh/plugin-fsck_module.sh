#!/bin/bash
PLUGIN_NAME="plugin_fsck_module.sh"
LOG_FILE="$HOME/twisteros_supermanager/logs/plugin.log"
STATUS_JSON="$HOME/twisteros_supermanager/twister-dashboard/data/plugin_status.json"

echo "$(date '+%Y-%m-%d %H:%M:%S') 🗄 Spouštím FS kontrolu..." | tee -a "$LOG_FILE"

sudo fsck -A -y

jq --arg p "$PLUGIN_NAME" --arg s "✅ dokončeno" '.[$p]=$s' "$STATUS_JSON" > "${STATUS_JSON}.tmp" && mv "${STATUS_JSON}.tmp" "$STATUS_JSON"

echo "✅ FS kontrola dokončena." | tee -a "$LOG_FILE"
