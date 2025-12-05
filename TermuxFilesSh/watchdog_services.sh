#!/bin/bash

SERVICES=("home-assistant" "nodered" "mqtt")

echo "🔍 Kontrola služeb..."
for S in "${SERVICES[@]}"; do
  if ! sudo docker ps --format '{{.Names}}' | grep -qw "$S"; then
      echo "❌ $S neběží – opravuji..."
      case $S in
        home-assistant) cd ~/homeassistant && sudo docker compose up -d;;
        mqtt|nodered) cd ~/smart-hub && sudo docker compose up -d;;
      esac
  else
      echo "✅ $S OK"
  fi
done

if ! pgrep -f http-server >/dev/null; then
    echo "🌐 Dashboard byl vypnutý – spouštím..."
    nohup http-server ~/twister-dashboard -p 8080 >/dev/null 2>&1 &
fi
