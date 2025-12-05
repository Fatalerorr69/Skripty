#!/bin/bash
PLUGIN_NAME="plugin_mbr_gpt_module.sh"
LOG_FILE="$HOME/twisteros_supermanager/logs/plugin.log"
STATUS_JSON="$HOME/twisteros_supermanager/twister-dashboard/data/plugin_status.json"

echo "$(date '+%Y-%m-%d %H:%M:%S') 💾 Kontrola MBR/GPT..." | tee -a "$LOG_FILE"

sudo parted -l >/dev/null 2>&1 && STATUS="✅ ok" || STATUS="❌ chyba"

jq --arg p "$PLUGIN_NAME" --arg s "$STATUS" '.[$p]=$s' "$STATUS_JSON" > "${STATUS_JSON}.tmp" && mv "${STATUS_JSON}.tmp" "$STATUS_JSON"

echo "✅ MBR/GPT kontrola dokončena: $STATUS" | tee -a "$LOG_FILE"
