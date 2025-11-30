#!/usr/bin/env bash
# ==========================================================
# WSL / Linux / Termux ULTIMATE PRO MAX GUI DASHBOARD
# ==========================================================
# Autor: Starko / Fatalerorr69
# GitHub: https://github.com/Fatalerorr69
# ==========================================================

# ---------------------- Barvy a styly --------------------
RESET="\e[0m"
BOLD="\e[1m"
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
CYAN="\e[36m"

info()  { echo -e "${BLUE}[INFO]${RESET} $1"; }
ok()    { echo -e "${GREEN}[OK]${RESET} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${RESET} $1"; }
err()   { echo -e "${RED}[ERROR]${RESET} $1"; }

# ---------------------- Detekce OS -----------------------
OS_TYPE="unknown"
if grep -qi microsoft /proc/version 2>/dev/null; then OS_TYPE="wsl"
elif [[ "$TERMUX_VERSION" ]]; then OS_TYPE="termux"
elif [[ "$(uname)" == "Linux" ]]; then OS_TYPE="linux"; fi
info "Detekován OS: $OS_TYPE"

# ---------------------- Detekce distribucí ---------------
DISTROS=()
if [[ "$OS_TYPE" == "wsl" ]]; then
    mapfile -t DISTROS < <(wsl --list --quiet 2>/dev/null)
elif [[ "$OS_TYPE" == "linux" ]]; then
    DISTROS=("$(lsb_release -si 2>/dev/null || echo $(uname -s))")
elif [[ "$OS_TYPE" == "termux" ]]; then
    DISTROS=("Termux")
fi
ok "Nalezeny distribuce: ${DISTROS[*]}"

# ---------------------- Funkce: Nastavení domova ---------
setup_home() {
    echo -e "${CYAN}--- Nastavení domovských adresářů + symlinky ---${RESET}"
    for d in "${DISTROS[@]}"; do
        homePath="W:/$d/home"
        mkdir -p "$homePath" 2>/dev/null
        if [[ "$OS_TYPE" == "wsl" ]]; then
            wsl --distribution "$d" --exec bash -c "sudo rm -rf /home 2>/dev/null; sudo ln -s /mnt/w/$d/home /home" 2>/dev/null
        else
            ln -sf "$homePath" "/home" 2>/dev/null
        fi
        ok "Domovský adresář nastaven pro $d -> $homePath"
    done
    read -p "Press Enter..."
}

# ---------------------- Funkce: Základní moduly ----------
install_basic_modules() {
    echo -e "${CYAN}--- Instalace základních modulů ---${RESET}"
    if [[ "$OS_TYPE" == "wsl" || "$OS_TYPE" == "linux" ]]; then
        sudo apt update && sudo apt upgrade -y
        sudo apt install -y docker.io docker-compose zsh tmux neofetch jq yq rclone borgbackup mosquitto python3-pip git curl wget
    elif [[ "$OS_TYPE" == "termux" ]]; then
        pkg update -y && pkg upgrade -y
        pkg install -y docker zsh tmux neofetch jq rclone borg python git curl wget
    fi
    ok "Základní moduly nainstalovány"
    read -p "Press Enter..."
}

# ---------------------- Funkce: Rozšířené moduly ----------
install_advanced_modules() {
    echo -e "${CYAN}--- Instalace rozšířených modulů ---${RESET}"
    if [[ "$OS_TYPE" == "wsl" || "$OS_TYPE" == "linux" ]]; then
        sudo add-apt-repository -y ppa:waydroid/waydroid 2>/dev/null
        sudo apt update
        sudo apt install -y waydroid
    fi
    ok "Rozšířené moduly nainstalovány"
    read -p "Press Enter..."
}

# ---------------------- Funkce: Cleaner PRO -------------
cleaner_pro() {
    echo -e "${CYAN}--- Cleaner PRO Advanced ---${RESET}"
    if command -v docker &>/dev/null; then
        sudo docker system prune -af
    fi
    rm -rf ~/.cache/waydroid ~/.cache/anbox 2>/dev/null
    pip3 cache purge 2>/dev/null
    sudo apt autoremove -y
    sudo apt autoclean -y
    ok "Cleaner PRO dokončen"
    read -p "Press Enter..."
}

# ---------------------- Funkce: WebGUI -------------------
install_webgui() {
    echo -e "${CYAN}--- Instalace WebGUI ---${RESET}"
    mkdir -p ~/WebGUI
    git clone https://github.com/Fatalerorr69/WebGUI.git ~/WebGUI 2>/dev/null || info "WebGUI již existuje."
    ok "WebGUI připraveno"
    read -p "Press Enter..."
}

# ---------------------- Funkce: Záloha -------------------
backup_homes() {
    echo -e "${CYAN}--- Zálohování domovských adresářů ---${RESET}"
    for d in "${DISTROS[@]}"; do
        homePath="W:/$d/home"
        tar -czf "W:/${d}_home_backup_$(date +%Y%m%d%H%M).tar.gz" -C "$homePath" . 2>/dev/null
    done
    ok "Zálohy dokončeny"
    read -p "Press Enter..."
}

# ---------------------- Funkce: Kontrola modulů ----------
check_modules() {
    echo -e "${CYAN}--- Kontrola modulů ---${RESET}"
    modules=("docker" "docker-compose" "zsh" "tmux" "neofetch" "jq" "yq" "rclone" "borgbackup" "mosquitto" "waydroid")
    missing=""
    for m in "${modules[@]}"; do
        if ! command -v $m &>/dev/null; then missing+="$m "; fi
    done
    if [[ -n "$missing" ]]; then warn "Chybí moduly: $missing"; else ok "Všechny moduly nainstalovány."; fi
    read -p "Press Enter..."
}

# ---------------------- GUI menu -------------------------
while true; do
    clear
    echo -e "${BOLD}${CYAN}==== WSL / Linux / Termux ULTIMATE PRO MAX GUI ====${RESET}"
    echo -e "${BOLD}Distribuce:${RESET} ${DISTROS[*]}"
    echo -e "${BOLD}Stav modulů:${RESET}"
    for m in docker docker-compose zsh tmux neofetch jq yq rclone borgbackup mosquitto waydroid; do
        if command -v $m &>/dev/null; then echo -e " $GREEN✔ $m${RESET}"; else echo -e " $RED✖ $m${RESET}"; fi
    done
    echo
    echo "1) Detekce distribucí"
    echo "2) Nastavení domovských adresářů + symlinky"
    echo "3) Instalace základních modulů"
    echo "4) Instalace rozšířených modulů"
    echo "5) Cleaner PRO Advanced"
    echo "6) Instalace WebGUI"
    echo "7) Kontrola modulů"
    echo "8) Záloha domovských adresářů"
    echo "0) Ukončit"
    read -p "Vyberte možnost: " choice
    case $choice in
        1) ok "Nalezeny distribuce: ${DISTROS[*]}"; read -p "Press Enter...";;
        2) setup_home;;
        3) install_basic_modules;;
        4) install_advanced_modules;;
        5) cleaner_pro;;
        6) install_webgui;;
        7) check_modules;;
        8) backup_homes;;
        0) ok "Ukončuji..."; exit 0;;
        *) warn "Neplatná volba"; read -p "Press Enter...";;
    esac
done
