#!/bin/bash
# ===================================================================
# Twister Smart Suite – Kompletní spouštěcí skript
# Autor: Starko, 2025
# ===================================================================

set -euo pipefail
IFS=$'\n\t'

echo "🚀 Spouštím Twister Smart Suite..."

# ------------------------ 1️⃣ AI Workspace server ------------------------
echo "🤖 Spouštím AI Workspace server..."
AI_DIR=~/twisteros_supermanager/ai_workspace
if pgrep -f "ai_workspace_server.py" > /dev/null; then
    echo "✅ AI Workspace server již běží"
else
    nohup python3 $AI_DIR/ai_workspace_server.py >/dev/null 2>&1 &
    echo "✅ AI Workspace server spuštěn"
fi

# ------------------------ 2️⃣ Pluginy ------------------------
echo "🔌 Spouštím všechny pluginy..."
PLUGIN_DIR=~/twisteros_supermanager/plugins
for plugin in $PLUGIN_DIR/*.sh; do
    plugin_name=$(basename $plugin)
    if pgrep -f "$plugin" > /dev/null; then
        echo "ℹ️ Plugin již běží: $plugin_name"
    else
        bash "$plugin" &
        echo "✅ Plugin spuštěn: $plugin_name"
    fi
done

# ------------------------ 3️⃣ Twister Dashboard ------------------------
echo "🌐 Spouštím Twister Dashboard..."
DASHBOARD_DIR=~/twisteros_supermanager/twister-dashboard
if pgrep -f "http-server $DASHBOARD_DIR" > /dev/null; then
    echo "✅ Dashboard již běží"
else
    nohup http-server $DASHBOARD_DIR -p 8080 >/dev/null 2>&1 &
    echo "✅ Dashboard spuštěn na http://localhost:8080"
fi

# ------------------------ 4️⃣ Kontrola Docker kontejnerů ------------------------
DOCKER_CONTAINERS=("home-assistant" "nodered" "mqtt")
echo "📦 Kontrola Docker kontejnerů..."
for c in "${DOCKER_CONTAINERS[@]}"; do
    if sudo docker ps --format '{{.Names}}' | grep -qw "$c"; then
        echo "✅ Kontejner běží: $c"
    else
        echo "❌ Kontejner neběží, spouštím..."
        if [ "$c" == "home-assistant" ]; then
            cd ~/homeassistant && sudo docker compose up -d
        else
            cd ~/smart-hub && sudo docker compose up -d
        fi
    fi
done

# ------------------------ 5️⃣ VNC server ------------------------
echo "🖥 Kontrola VNC serveru..."
if systemctl is-active --quiet vncserver-x11-serviced.service; then
    echo "✅ VNC server běží"
else
    echo "❌ VNC neběží, spouštím..."
    sudo systemctl start vncserver-x11-serviced.service
fi

# ------------------------ 6️⃣ Conky ------------------------
echo "📊 Kontrola Conky..."
if pgrep -x conky > /dev/null; then
    echo "✅ Conky běží"
else
    echo "❌ Conky neběží, spouštím..."
    conky &
fi

# ------------------------ 7️⃣ SSH ------------------------
echo "🔌 Kontrola SSH..."
if systemctl is-active --quiet ssh; then
    echo "✅ SSH běží"
else
    echo "❌ SSH neběží, spouštím..."
    sudo systemctl start ssh
fi

# ------------------------ 8️⃣ ROM a BIOS ------------------------
echo "🎮 Kontrola ROM a BIOS..."
ROM_DIR=~/Games/ROMs
BIOS_DIR=~/Games/BIOS
mkdir -p "$ROM_DIR" "$BIOS_DIR"
[ -z "$(ls -A $ROM_DIR)" ] && echo "⚠️ ROM složka prázdná" || echo "✅ ROM složky OK"
[ -z "$(ls -A $BIOS_DIR)" ] && echo "⚠️ BIOS složka prázdná" || echo "✅ BIOS složky OK"

# ------------------------ 9️⃣ Stav otevřených portů ------------------------
echo "📡 Otevřené porty 22 a 5900:"
ss -tuln | grep -E '(:22|:5900)' || echo "⚠️ Porty nejsou otevřené"

echo "------------------------------------------------------------"
echo "✅ Twister Smart Suite spuštěn a zkontrolován!"
