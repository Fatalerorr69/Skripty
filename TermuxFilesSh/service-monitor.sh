#!/bin/bash
# Monitorování stavu Docker služeb

SERVICES=("portainer" "heimdall" "nextcloud" "jellyfin" "homeassistant")

while true; do
    clear
    echo "=== Docker Services Monitor ==="
    echo "Poslední kontrola: $(date)"
    echo ""
    
    for service in "${SERVICES[@]}"; do
        if docker ps | grep -q "$service"; then
            echo "✅ $service: RUNNING"
        else
            echo "❌ $service: STOPPED"
        fi
    done
    
    echo ""
    echo "CPU Teplota: $(vcgencmd measure_temp)"
    echo "RAM Usage: $(free -h | awk '/Mem:/ {print $3 "/" $2}')"
    echo ""
    echo "Stiskněte Ctrl+C pro ukončení"
    sleep 10
done
