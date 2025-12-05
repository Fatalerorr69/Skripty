#!/bin/bash
PLUGIN_NAME="plugin_retro_games.sh"
LOG_FILE="$HOME/twisteros_supermanager/logs/plugin.log"
STATUS_JSON="$HOME/twisteros_supermanager/twister-dashboard/data/plugin_status.json"

echo "$(date '+%Y-%m-%d %H:%M:%S') 🎮 Správa herních souborů..." | tee -a "$LOG_FILE"

mkdir -p ~/Games/BIOS ~/Games/ROMs

# Zde lze doplnit automatické stahování nebo kontrolu ROM/BIOS

jq --arg p "$PLUGIN_NAME" --arg s "✅ aktivní" '.[$p]=$s' "$STATUS_JSON" > "${STATUS_JSON}.tmp" && mv "${STATUS_JSON}.tmp" "$STATUS_JSON"

echo "✅ ROM a BIOS připraveny." | tee -a "$LOG_FILE"
