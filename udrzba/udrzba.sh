#!/bin/bash

# Udržba systému s grafickým menu pro Raspberry Pi
# Tento skript provádí různé úkoly spojené s údržbou systému
# jako aktualizace, čištění, zobrazení informací atd.

# Zkontroluje, zda je nainstalován Yad, který je nezbytný pro GUI
if ! command -v yad &> /dev/null; then
    echo "Yad nebyl nalezen. Nainstalujte ho příkazem: sudo apt install -y yad"
    zenity --error --text="Program Yad není nainstalován. Nainstalujte jej pomocí terminálu a spusťte skript znovu."
    exit 1
fi

# Proměnné pro barevné výstupy v terminálu
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # Bez barvy

# Kontrola, zda je skript spuštěn s právy superuživatele (root)
check_root() {
    if [ "$EUID" -ne 0 ]; then
      yad --center --width=400 --height=150 --title="Chyba oprávnění" --text="Tento skript musí být spuštěn s právy superuživatele.\nPoužijte prosím 'sudo'." --button="Zavřít"
      exit 1
    fi
}

# Funkce pro aktualizaci systému
update_system() {
    echo -e "${YELLOW}Spouštím aktualizaci systému...${NC}"
    apt update && apt upgrade -y
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Systém byl úspěšně aktualizován.${NC}"
        yad --center --width=300 --title="Úspěch" --text="Systém byl úspěšně aktualizován." --button="OK"
    else
        echo -e "${RED}Chyba při aktualizaci systému.${NC}"
        yad --center --width=300 --title="Chyba" --text="Při aktualizaci došlo k chybě." --button="OK"
    fi
}

# Funkce pro čištění systému
clean_system() {
    echo -e "${YELLOW}Spouštím čištění systému...${NC}"
    apt autoremove -y && apt clean
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Systém byl úspěšně vyčištěn.${NC}"
        yad --center --width=300 --title="Úspěch" --text="Systém byl úspěšně vyčištěn." --button="OK"
    else
        echo -e "${RED}Chyba při čištění systému.${NC}"
        yad --center --width=300 --title="Chyba" --text="Při čištění došlo k chybě." --button="OK"
    fi
}

# Funkce pro zobrazení systémových informací
show_info() {
    echo -e "${YELLOW}Zobrazuji systémové informace...${NC}"
    INFO=$(
        echo "<b>Uptime:</b> $(uptime | awk '{print $3,$4}' | sed 's/,//')"
        echo "<b>Využití disku:</b> $(df -h / | awk 'NR==2 {print $5}')"
        echo "<b>Paměť RAM:</b> $(free -h | awk 'NR==2 {print $3 "/" $2}')"
        echo "<b>Teplota CPU:</b> $(vcgencmd measure_temp | sed 's/temp=//' | sed 's/'\''C//')°C"
    )
    yad --center --width=400 --height=200 --title="Informace o systému" --text="$INFO" --button="Zavřít"
    echo -e "${GREEN}Informace o systému zobrazeny.${NC}"
}

# Hlavní menu
while true; do
    CHOICE=$(yad --center --width=400 --height=200 --title="Správce systému" --text="Zvolte prosím akci:" \
        --button=" Aktualizovat systém " --button=" Vyčistit systém " \
        --button=" Zobrazit info " --button=" Konec " --undecorated)

    case $? in
        0) # Aktualizovat systém
            check_root
            update_system
            ;;
        1) # Vyčistit systém
            check_root
            clean_system
            ;;
        2) # Zobrazit info
            show_info
            ;;
        3) # Konec
            break
            ;;
        *) # Zavřeno
            break
            ;;
    esac
done
