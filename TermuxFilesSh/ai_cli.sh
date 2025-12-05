#!/bin/bash

AI_DIR="$HOME/twisteros_supermanager/ai_workspace"
HISTORY="$AI_DIR/ai_history.log"

mkdir -p "$AI_DIR"

echo "===== TwisterOS AI Workspace ====="
echo "Zadej dotaz (ukonči pomocí exit):"

while true; do
    echo -n "> "
    read INPUT

    [[ "$INPUT" == "exit" ]] && exit 0

    echo "[USER] $INPUT" >> "$HISTORY"

    # Simulovaná odpověď (napojení na LLM může být přidáno později)
    RESPONSE="Analýzu provádím... Systém pracuje normálně."

    echo "[AI] $RESPONSE"
    echo "[AI] $RESPONSE" >> "$HISTORY"
done
