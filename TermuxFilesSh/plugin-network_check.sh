#!/bin/bash
PLUGIN_NAME="plugin_network_check.sh"
LOG_FILE="$HOME/twisteros_supermanager/logs/plugin.log"
STATUS_JSON="$HOME/twisteros_supermanager/twister-dashboard/data/plugin_status.json"

echo "$(date '+%Y-%m-%d %H:%M:%S') 🌐 Kontrola sítě..." | tee -a "$LOG_FILE"

ping -c 3 8.8.8.8 >/dev/null 2>&1 && STATUS="✅ online" || STATUS="❌ offline"

jq --arg p "$PLUGIN_NAME" --arg s "$STATUS" '.[$p]=$s' "$STATUS_JSON" > "${STATUS_JSON}.tmp" && mv "${STATUS_JSON}.tmp" "$STATUS_JSON"

echo "✅ Kontrola sítě dokončena: $STATUS" | tee -a "$LOG_FILE"
