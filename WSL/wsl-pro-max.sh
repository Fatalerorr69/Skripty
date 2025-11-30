#!/bin/bash
# PRO MAX WSL Installer & Maintenance
# Author: Starko
# Purpose: Kompletní správa a instalace modulů pro všechny WSL distribuce

YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
RESET='\033[0m'

WSL_ROOT="/mnt/w"

# --------------------------------------------------------
# Funkce: detekce distribucí
detect_distributions() {
    echo -e "${YELLOW}[INFO] Detekce nainstalovaných WSL distribucí…${RESET}"
    DISTROS=$(wsl --list --quiet)
    echo "$DISTROS"
}

# --------------------------------------------------------
# Funkce: nastavení domovských adresářů
setup_home_dirs() {
    echo -e "${YELLOW}[INFO] Nastavuji domovské adresáře na W:/${RESET}"
    for DISTRO in $DISTROS; do
        HOME_DIR="$WSL_ROOT/$DISTRO/home"
        mkdir -p "$HOME_DIR"
        echo "[INFO] $DISTRO -> $HOME_DIR"
        # symlink pro WSL
        wsl -d "$DISTRO" -- sudo rm -rf /home
        wsl -d "$DISTRO" -- sudo ln -s "$HOME_DIR" /home
    done
}

# --------------------------------------------------------
# Funkce: instalace základních modulů
install_modules() {
    echo -e "${YELLOW}[INFO] Instalace doporučených modulů…${RESET}"
    for DISTRO in $DISTROS; do
        echo "[INFO] Instalace modulů pro $DISTRO"
        wsl -d "$DISTRO" -- sudo apt update
        wsl -d "$DISTRO" -- sudo apt install -y docker.io docker-compose rclone borgbackup tmuxinator tmate jq yq mosquitto-clients mosquitto python3-pip neofetch vim git curl wget unzip
        wsl -d "$DISTRO" -- sh -c "sh -c \"$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" || true"
        wsl -d "$DISTRO" -- sudo apt install -y waydroid
    done
}

# --------------------------------------------------------
# Funkce: Cleaner PRO Advanced
cleaner_pro_advanced() {
    echo -e "${YELLOW}[CLEANER PRO] Zahajuji údržbu…${RESET}"
    for DISTRO in $DISTROS; do
        echo "[CLEANER] $DISTRO"
        wsl -d "$DISTRO" -- bash -c "
            docker ps -aq | xargs -r docker stop
            docker ps -aq | xargs -r docker rm -f
            docker images -q | xargs -r docker rmi -f
            docker volume ls -q | xargs -r docker volume rm -f
            docker network prune -f -y
            rm -rf ~/.local/share/waydroid/* ~/.config/waydroid/* ~/.local/share/anbox/* ~/.cache/pip 2>/dev/null
            find ~ -type d -name 'venv*' -exec rm -rf {} + 2>/dev/null
            sudo rm -rf /tmp/* ~/.logs ~/.old_modules* ~/.cache/* 2>/dev/null
            find ~ -xtype l -delete 2>/dev/null
            sudo apt autoremove -y
            sudo apt clean -y
        "
    done
    echo -e "${GREEN}[CLEANER PRO] Údržba dokončena.${RESET}"
}

# --------------------------------------------------------
# Funkce: WebGUI setup
setup_webgui() {
    echo -e "${YELLOW}[INFO] Instalace základního WebGUI…${RESET}"
    for DISTRO in $DISTROS; do
        wsl -d "$DISTRO" -- sudo apt install -y python3-pip
        wsl -d "$DISTRO" -- pip3 install flask flask_socketio psutil
        # jednoduchý skeleton
        wsl -d "$DISTRO" -- bash -c "mkdir -p ~/webgui && echo 'print(\"Starko WebGUI Running\")' > ~/webgui/app.py"
    done
    echo -e "${GREEN}[INFO] WebGUI nainstalováno.${RESET}"
}

# --------------------------------------------------------
# Interaktivní menu
main_menu() {
    while true; do
        echo -e "\n${YELLOW}==== WSL PRO MAX MENU ====${RESET}"
        echo "1) Detekce distribucí"
        echo "2) Nastavení domovských adresářů"
        echo "3) Instalace modulů"
        echo "4) Cleaner PRO Advanced"
        echo "5) Instalace WebGUI"
        echo "0) Konec"
        read -p "Vyberte možnost: " choice
        case $choice in
            1) detect_distributions ;;
            2) setup_home_dirs ;;
            3) install_modules ;;
            4) cleaner_pro_advanced ;;
            5) setup_webgui ;;
            0) exit 0 ;;
            *) echo "Neplatná volba!" ;;
        esac
    done
}

# --------------------------------------------------------
# START
echo -e "${GREEN}[PRO MAX INSTALLER] Spuštění…${RESET}"
detect_distributions
main_menu
