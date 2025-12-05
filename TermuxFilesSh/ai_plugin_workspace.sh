#!/bin/bash
# ===========================================================
# Twister Smart Suite – AI Workspace Plugin
# Autor: Starko (2025)
# ===========================================================

PLUGIN_NAME="AI Workspace"
AI_DIR="$HOME/twisteros_supermanager/ai_workspace"

case "$1" in
    start)
        bash "$AI_DIR/ai_engine.sh" --startup
        echo "[AI Workspace] Engine aktivní."
        ;;

    stop)
        pkill -f ai_engine.sh || true
        echo "[AI Workspace] Zastaveno."
        ;;

    status)
        if pgrep -f ai_engine.sh > /dev/null; then
            echo "AI Workspace běží."
        else
            echo "AI Workspace neběží."
        fi
        ;;

    cli)
        bash "$AI_DIR/ai_cli.sh"
        ;;

    *)
        echo "Použití: plugin-ai_workspace.sh {start|stop|status|cli}"
        ;;
esac
