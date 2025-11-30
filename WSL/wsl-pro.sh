#!/usr/bin/env bash
set -euo pipefail

# ============================================================
#   WSL TOOLKIT PRO – ENTERPRISE EDITION
# ============================================================

LOGFILE="/var/log/wsl-pro.log"

GREEN="\e[32m"; CYAN="\e[36m"; YELLOW="\e[33m"; RED="\e[31m"; NC="\e[0m"

log() { echo -e "[$(date '+%F %T')] $1" | sudo tee -a "$LOGFILE" >/dev/null; }
header() { clear; echo -e "${CYAN}============= WSL TOOLKIT PRO =============${NC}"; }
pause() { read -p "Pokračuj stiskem ENTER…" _; }

# ============================================================
# SYSTEM DETECTION
# ============================================================
detect_all() {
    DISTRO=$(grep -oP '(?<=^PRETTY_NAME=").*(?=")' /etc/os-release || echo unknown)
    USER_NAME=$(whoami)

    WSL_LIST=$(wsl.exe -l -q | tr -d '\r')
    ACTIVE_WSL=$(wslpath -w / | awk -F'\\' '{print $3}')

    HOME_TARGET="/mnt/w/${ACTIVE_WSL}/home/${USER_NAME}"
}

# ============================================================
# BASE CHECKS
# ============================================================
check_requirements() {
    header
    echo -e "${CYAN}Provádím diagnostiku systému…${NC}"

    if [ ! -d "/mnt/w" ]; then
        echo -e "${RED}[ERROR] Disk W: není připojen.${NC}"
        exit 1
    fi

    if ! command -v sudo >/dev/null; then
        echo "Instaluji sudo…"
        apt install -y sudo
    fi

    log "Requirements OK"
    pause
}

# ============================================================
# MODULE: HOME REDIRECTION
# ============================================================
move_home_to_w() {
    header
    detect_all

    echo -e "${CYAN}Nastavuji HOME na ${HOME_TARGET}${NC}"

    sudo mkdir -p "$HOME_TARGET"
    sudo chown -R "$USER_NAME":"$USER_NAME" "$HOME_TARGET"

    if [ -d "/home/$USER_NAME" ] && [ ! -L "/home/$USER_NAME" ]; then
        sudo mv -n "/home/$USER_NAME"/* "$HOME_TARGET/" 2>/dev/null || true
    fi

    sudo rm -rf "/home/$USER_NAME"
    sudo ln -s "$HOME_TARGET" "/home/$USER_NAME"

    log "Home moved"
    echo -e "${GREEN}[OK] Domovský adresář přesměrován.${NC}"
    pause
}

# ============================================================
# MODULE: BASE PACKAGES
# ============================================================
install_base() {
    header
    echo -e "${CYAN}Instalace základních balíčků…${NC}"

    sudo apt update -y
    sudo apt install -y \
        curl wget git unzip htop neofetch tmux tzdata \
        build-essential python3 python3-pip python3-venv \
        net-tools lsof lsb-release apt-transport-https \
        software-properties-common

    log "Base packages installed"
    pause
}

# ============================================================
# MODULE: HARDENING + FAIL2BAN
# ============================================================
install_hardening() {
    header
    echo -e "${CYAN}Instaluji Fail2ban + security hardening…${NC}"

    sudo apt install -y fail2ban

    sudo bash -c "cat > /etc/fail2ban/jail.local" <<EOF
[DEFAULT]
bantime = 10m
findtime = 10m
maxretry = 5
backend = systemd

[sshd]
enabled = true
EOF

    sudo systemctl enable fail2ban --now

    log "Fail2ban installed"
    pause
}

# ============================================================
# MODULE: MQ MQTT
# ============================================================
install_mqtt() {
    header
    echo -e "${CYAN}Instaluji Mosquitto MQTT broker…${NC}"

    sudo apt install -y mosquitto mosquitto-clients
    sudo systemctl enable mosquitto --now

    log "MQTT installed"
    pause
}

# ============================================================
# MODULE: WAYDROID
# ============================================================
install_waydroid() {
    header
    echo -e "${CYAN}Instaluji Waydroid (Android prostředí)…${NC}"

    sudo curl -s https://repo.waydro.id | sudo bash
    sudo apt install -y waydroid

    log "Waydroid installed"
    pause
}

# ============================================================
# MODULE: DOCKER + COMPOSE
# ============================================================
install_docker() {
    header

    sudo apt remove -y docker docker.io podman-docker || true

    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
       https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
      | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

    sudo apt update -y
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

    sudo usermod -aG docker "$USER_NAME"

    log "Docker installed"
    pause
}

# ============================================================
# MODULE: NODE.JS + PM2
# ============================================================
install_node() {
    header
    echo -e "${CYAN}Instaluji Node.js + PM2…${NC}"

    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt install -y nodejs
    sudo npm install -g pm2

    log "Node installed"
    pause
}

# ============================================================
# MODULE: RCLONE
# ============================================================
install_rclone() {
    header

    curl https://rclone.org/install.sh | sudo bash

    log "rclone installed"
    pause
}

# ============================================================
# MODULE: PYTHON ENV
# ============================================================
setup_python_env() {
    header

    mkdir -p ~/venv
    python3 -m venv ~/venv/wsl
    source ~/venv/wsl/bin/activate
    pip install flask requests paramiko numpy psutil

    log "Python env created"
    pause
}

# ============================================================
# MODULE: SYSTEM INFO
# ============================================================
show_info() {
    header
    echo -e "${CYAN}Systémové informace:${NC}"
    neofetch
    pause
}

# ============================================================
# MENU – PRO VERSION
# ============================================================
menu() {
    detect_all
    while true; do
        header
        echo -e "${GREEN}Aktivní distro: ${ACTIVE_WSL}${NC}"
        echo ""
        echo "[1] Přesměrovat HOME → W:"
        echo "[2] Instalovat základ"
        echo "[3] Instalovat Docker + Compose"
        echo "[4] Instalovat Waydroid"
        echo "[5] Instalovat MQTT broker"
        echo "[6] Instalovat Node.js + PM2"
        echo "[7] Instalovat rclone (cloud backup)"
        echo "[8] Instalovat Fail2ban + hardening"
        echo "[9] Python PRO environment"
        echo "[10] Diagnostika systému"
        echo "[11] Výpis logu"
        echo "[12] Restart WSL"
        echo "[0] Konec"
        echo ""
        read -p "Vyber akci: " CHOICE

        case "$CHOICE" in
            1) move_home_to_w ;;
            2) install_base ;;
            3) install_docker ;;
            4) install_waydroid ;;
            5) install_mqtt ;;
            6) install_node ;;
            7) install_rclone ;;
            8) install_hardening ;;
            9) setup_python_env ;;
            10) show_info ;;
            11) sudo cat "$LOGFILE"; pause ;;
            12) wsl.exe --shutdown; exit 0 ;;
            0) exit 0 ;;
        esac
    done
}

# ============================================================
check_requirements
menu
