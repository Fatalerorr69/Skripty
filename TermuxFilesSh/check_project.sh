#!/bin/bash
# Twister Smart Suite – kontrola projektu
set -euo pipefail

PROJECT="$HOME/twisteros_supermanager"

echo "🔍 Kontrola projektové struktury..."

DIRS=(
    "scripts"
    "plugins"
    "modules"
    "config"
    "backup"
    "logs"
    "twister-dashboard"
)

for d in "${DIRS[@]}"; do
    if [ ! -d "$PROJECT/$d" ]; then
        echo "❌ Chybí složka: $d"
        exit 1
    else
        echo "✅ OK: $d"
    fi
done

echo "🔍 Kontrola spustitelných práv..."
chmod -R +x "$PROJECT/scripts" "$PROJECT/plugins" "$PROJECT/modules"

echo "🔍 Kontrola kritických souborů..."

FILES=(
    "scripts/install_twister_smart_suite.sh"
    "scripts/start_twister_suite.sh"
    "scripts/smart_menu.sh"
    "twister-dashboard/index.html"
    "twister-dashboard/app.js"
)

for f in "${FILES[@]}"; do
    if [ ! -f "$PROJECT/$f" ]; then
        echo "❌ Chybí soubor: $f"
        exit 1
    else
        echo "✅ Soubor OK: $f"
    fi
done

echo "🎉 Projekt je kompletní a připravený!"
