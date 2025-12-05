#!/bin/bash
# smart-menu.sh – textové menu pro Twister Smart Suite
# Umístění: ~/twister-smart-suite/scripts/smart-menu.sh

set -euo pipefail
IFS=$'\n\t'

BASE="$HOME/twister-smart-suite"
SCRIPTS="$BASE/scripts"

# Základní kontrola závislostí
command -v dialog >/dev/null 2>&1 || { echo "Instaluji dialog..."; sudo apt update && sudo apt install -y dialog; }

while true; do
  CHOICE=$(dialog --clear --backtitle "Twister Smart Suite" \
    --title "Hlavní menu" \
    --menu "Vyber akci:" 18 60 10 \
    1 "Kontrola systému (check_twister_smart_suite.sh)" \
    2 "Opravit služby (repair_services.sh)" \
    3 "Síťová diagnostika (network_diag.sh)" \
    4 "HW info (hw_info.sh)" \
    5 "Generovat log balík (generate_logs.sh)" \
    6 "Restart Dashboardu (reset_dashboard.sh)" \
    7 "Aktualizovat suite (update_suite.sh)" \
    8 "Spustit plugin loader" \
    9 "Otevřít web dashboard (localhost:8080)" \
    0 "Konec" 3>&1 1>&2 2>&3)

  exit_status=$?
  clear
  if [ $exit_status -ne 0 ]; then
    echo "Ukončeno."
    exit 0
  fi

  case $CHOICE in
    1) bash "$BASE/check_twister_smart_suite.sh" ; read -rp "Stiskni Enter..." ;;
    2) bash "$SCRIPTS/repair_services.sh" ; read -rp "Stiskni Enter..." ;;
    3) bash "$SCRIPTS/network_diag.sh" ; read -rp "Stiskni Enter..." ;;
    4) bash "$SCRIPTS/hw_info.sh" ; read -rp "Stiskni Enter..." ;;
    5) bash "$SCRIPTS/generate_logs.sh" ; read -rp "Stiskni Enter..." ;;
    6) bash "$SCRIPTS/reset_dashboard.sh" ; read -rp "Stiskni Enter..." ;;
    7) bash "$SCRIPTS/update_suite.sh" ; read -rp "Stiskni Enter..." ;;
    8) bash "$BASE/modules/plugin_loader.sh" ; read -rp "Stiskni Enter..." ;;
    9) xdg-open "http://localhost:8080" >/dev/null 2>&1 || echo "Otevři v prohlížeči: http://localhost:8080" ; read -rp "Stiskni Enter..." ;;
    0) clear; exit 0 ;;
    *) echo "Neznámá volba";;
  esac
done
