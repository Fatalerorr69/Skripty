#!/bin/bash
PLUGIN_NAME="plugin_dashboard.sh"
LOG_FILE="$HOME/twisteros_supermanager/logs/plugin.log"
STATUS_JSON="$HOME/twisteros_supermanager/twister-dashboard/data/plugin_status.json"
DASH_DIR="$HOME/twisteros_supermanager/twister-dashboard"

echo "$(date '+%Y-%m-%d %H:%M:%S') 🌐 Spouštím Twister Dashboard..." | tee -a "$LOG_FILE"

nohup node "$DASH_DIR/app.js" >/dev/null 2>&1 &

jq --arg p "$PLUGIN_NAME" --arg s "✅ aktivní" '.[$p]=$s' "$STATUS_JSON" > "${STATUS_JSON}.tmp" && mv "${STATUS_JSON}.tmp" "$STATUS_JSON"

echo "✅ Dashboard dostupný na http://localhost:8080" | tee -a "$LOG_FILE"
