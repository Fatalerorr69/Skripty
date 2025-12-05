#!/bin/bash
# ==========================================
# SmartHome All-in-One Docker Stack
# Node-RED + Home Assistant + ioBroker
# ==========================================

set -e

# --- Stáhnout demo flow pro Node-RED ---
DEMO_FLOW_URL="https://pastebin.com/raw/zR1kJxqL"
mkdir -p ./nodered_data
curl -s -o ./nodered_data/demo_flow.json "$DEMO_FLOW_URL"

# --- Spuštění Docker Compose stacku ---
docker-compose up -d

# --- Počkej 10s a otevři Node-RED dashboard ---
sleep 10

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    xdg-open "http://localhost:1880/ui" || true
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    powershell.exe Start-Process 'http://localhost:1880/ui'
elif [[ "$PREFIX" == "/data/data/com.termux/files/usr" ]]; then
    am start -a android.intent.action.VIEW -d "http://localhost:1880/ui"
fi

echo "=== SmartHome stack spuštěn ==="
echo "Node-RED → http://localhost:1880/ui"
echo "Home Assistant → http://localhost:8123"
echo "ioBroker Admin → http://localhost:8081”

