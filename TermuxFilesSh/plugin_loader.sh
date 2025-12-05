#!/bin/bash
# ==============================================================
# Plugin Loader – dynamické načítání a správa všech pluginů
# Autor: Starko, 2025
# ==============================================================

set -euo pipefail
IFS=$'\n\t'

PLUGINS_DIR=~/twisteros_supermanager/plugins
STATUS_FILE=~/twisteros_supermanager/plugins/plugin_status.json
LOG_FILE=~/twisteros_supermanager/logs/plugin.log

# Inicializace JSON statusu
echo "{}" > "$STATUS_FILE"

# Funkce pro spouštění pluginů
plugin_action() {
    local plugin_file=$1
    local action=$2
    local plugin_name=$(basename "$plugin_file" .sh)

    if [[ ! -x "$plugin_file" ]]; then
        chmod +x "$plugin_file"
    fi

    echo "⚡ [$plugin_name] Akce: $action" | tee -a "$LOG_FILE"

    case $action in
        start)
            bash "$plugin_file" start
            echo "{\"$plugin_name\":\"running\"}" > /tmp/plugin_status.json
            jq -s 'add' "$STATUS_FILE" /tmp/plugin_status.json > "${STATUS_FILE}.tmp" && mv "${STATUS_FILE}.tmp" "$STATUS_FILE"
            ;;
        stop)
            bash "$plugin_file" stop
            echo "{\"$plugin_name\":\"stopped\"}" > /tmp/plugin_status.json
            jq -s 'add' "$STATUS_FILE" /tmp/plugin_status.json > "${STATUS_FILE}.tmp" && mv "${STATUS_FILE}.tmp" "$STATUS_FILE"
            ;;
        status)
            bash "$plugin_file" status
            ;;
        *)
            echo "Použití: $0 {start|stop|status|all}" ;;
    esac
}

# Akce pro všechny pluginy
all_plugins_action() {
    local action=$1
    for plugin in "$PLUGINS_DIR"/*.sh; do
        plugin_action "$plugin" "$action"
    done
}

# Hlavní logika
if [[ $# -lt 1 ]]; then
    echo "Použití: $0 {start|stop|status|all}"
    exit 1
fi

CMD=$1

case $CMD in
    start|stop|status)
        all_plugins_action "$CMD"
        ;;
    all)
        echo "⚡ Spouštím všechny pluginy (start)..." | tee -a "$LOG_FILE"
        all_plugins_action start
        ;;
    *)
        echo "Použití: $0 {start|stop|status|all}" ;;
esac
