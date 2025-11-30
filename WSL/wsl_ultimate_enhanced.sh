#!/usr/bin/env bash
# ==========================================================
# WSL / Linux / Termux ULTIMATE PRO MAX GUI - ENHANCED
# ==========================================================
# Autor: Starko / Fatalerorr69
# GitHub: https://github.com/Fatalerorr69
# ==========================================================

set -euo pipefail
IFS=$'\n\t'

# ---------------------- Barvy a styly --------------------
RESET="\e[0m"; BOLD="\e[1m"; RED="\e[31m"; GREEN="\e[32m"
YELLOW="\e[33m"; BLUE="\e[34m"; CYAN="\e[36m"; MAGENTA="\e[35m"

info()  { echo -e "${BLUE}[INFO]${RESET} $1" | tee -a "$LOGFILE"; }
ok()    { echo -e "${GREEN}[OK]${RESET} $1" | tee -a "$LOGFILE"; }
warn()  { echo -e "${YELLOW}[WARN]${RESET} $1" | tee -a "$LOGFILE"; }
err()   { echo -e "${RED}[ERROR]${RESET} $1" | tee -a "$LOGFILE"; return 1; }

# ---------------------- Inicializace ---------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGFILE="$SCRIPT_DIR/wsl_gui_$(date +%Y%m%d).log"
BACKUP_DIR="$SCRIPT_DIR/backups"
CONFIG_FILE="$SCRIPT_DIR/wsl_config.conf"

mkdir -p "$BACKUP_DIR"
info "=== Spuštění $(date) ==="

# ---------------------- Detekce OS -----------------------
detect_os() {
    OS_TYPE="unknown"
    DISTRO_NAME="unknown"
    PKG_MANAGER="apt"
    
    if grep -qi microsoft /proc/version 2>/dev/null; then 
        OS_TYPE="wsl"
    elif [[ "$TERMUX_VERSION" ]]; then 
        OS_TYPE="termux"
        PKG_MANAGER="pkg"
    elif [[ "$(uname)" == "Linux" ]]; then 
        OS_TYPE="linux"
    fi
    
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        DISTRO_NAME="$ID"
        case "$ID" in
            ubuntu|debian) PKG_MANAGER="apt";;
            fedora|rhel|centos) PKG_MANAGER="dnf";;
            arch|manjaro) PKG_MANAGER="pacman";;
            alpine) PKG_MANAGER="apk";;
        esac
    fi
    
    info "OS: $OS_TYPE | Distro: $DISTRO_NAME | Package Manager: $PKG_MANAGER"
}

# ---------------------- Detekce distribucí ---------------
detect_distros() {
    DISTROS=()
    if [[ "$OS_TYPE" == "wsl" ]]; then
        mapfile -t DISTROS < <(wsl.exe --list --quiet 2>/dev/null | sed 's/\r//g' | grep -v '^$')
    elif [[ "$OS_TYPE" == "linux" ]]; then
        DISTROS=("$DISTRO_NAME")
    elif [[ "$OS_TYPE" == "termux" ]]; then
        DISTROS=("Termux")
    fi
    ok "Distribuce: ${DISTROS[*]}"
}

# ---------------------- Automatická oprava chyb ----------
auto_fix() {
    local cmd="$1"
    local max_attempts=3
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if eval "$cmd" 2>>"$LOGFILE"; then
            return 0
        else
            warn "Pokus $attempt/$max_attempts selhal, opakuji..."
            sleep 2
            ((attempt++))
        fi
    done
    err "Příkaz selhal po $max_attempts pokusech: $cmd"
    return 1
}

# ---------------------- Záloha před operací --------------
backup_before_action() {
    local name="$1"
    local backup_file="$BACKUP_DIR/${name}_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    info "Vytvářím zálohu: $backup_file"
    if [[ -d "$HOME" ]]; then
        tar -czf "$backup_file" -C "$HOME" . 2>/dev/null || warn "Částečná záloha"
        ok "Záloha vytvořena: $backup_file"
    fi
}

# ---------------------- Health Check ---------------------
system_health_check() {
    echo -e "${CYAN}--- Health Check ---${RESET}"
    
    # Disk space
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ $disk_usage -gt 90 ]]; then
        warn "Disk usage: ${disk_usage}% (KRITICKÉ!)"
    else
        ok "Disk usage: ${disk_usage}%"
    fi
    
    # Memory
    if command -v free &>/dev/null; then
        local mem_usage=$(free | awk 'NR==2 {printf "%.0f", $3*100/$2}')
        ok "Memory usage: ${mem_usage}%"
    fi
    
    # Load average
    if [[ -f /proc/loadavg ]]; then
        local load=$(cat /proc/loadavg | awk '{print $1}')
        ok "Load average: $load"
    fi
    
    read -p "Press Enter..."
}

# ---------------------- Package manager wrapper ----------
pkg_install() {
    local packages="$@"
    
    case "$PKG_MANAGER" in
        apt)
            auto_fix "sudo apt update" && \
            auto_fix "sudo apt install -y $packages"
            ;;
        dnf)
            auto_fix "sudo dnf install -y $packages"
            ;;
        pacman)
            auto_fix "sudo pacman -S --noconfirm $packages"
            ;;
        pkg)
            auto_fix "pkg install -y $packages"
            ;;
        apk)
            auto_fix "sudo apk add $packages"
            ;;
    esac
}

pkg_update() {
    case "$PKG_MANAGER" in
        apt) auto_fix "sudo apt update && sudo apt upgrade -y";;
        dnf) auto_fix "sudo dnf upgrade -y";;
        pacman) auto_fix "sudo pacman -Syu --noconfirm";;
        pkg) auto_fix "pkg upgrade -y";;
        apk) auto_fix "sudo apk upgrade";;
    esac
}

# ---------------------- Nastavení domova -----------------
setup_home() {
    echo -e "${CYAN}--- Nastavení domovských adresářů ---${RESET}"
    backup_before_action "home_setup"
    
    for d in "${DISTROS[@]}"; do
        local homePath="/mnt/w/$d/home"
        
        if [[ "$OS_TYPE" == "wsl" ]]; then
            mkdir -p "$homePath" 2>/dev/null || warn "Nelze vytvořit $homePath"
            
            wsl.exe --distribution "$d" --exec bash -c "
                sudo mkdir -p /home_backup 2>/dev/null
                [[ -d /home ]] && sudo cp -r /home/* /home_backup/ 2>/dev/null
                sudo rm -rf /home 2>/dev/null
                sudo ln -sf $homePath /home
            " 2>/dev/null && ok "Home nastaven: $d" || warn "Chyba u $d"
        fi
    done
    read -p "Press Enter..."
}

# ---------------------- Základní moduly ------------------
install_basic_modules() {
    echo -e "${CYAN}--- Instalace základních modulů ---${RESET}"
    backup_before_action "basic_modules"
    
    pkg_update
    
    local packages="git curl wget vim nano htop tmux screen"
    packages+=" zsh build-essential python3 python3-pip"
    packages+=" net-tools iputils-ping dnsutils"
    
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        packages+=" software-properties-common apt-transport-https ca-certificates"
    fi
    
    pkg_install $packages
    
    # Docker
    if ! command -v docker &>/dev/null; then
        info "Instaluji Docker..."
        if [[ "$PKG_MANAGER" == "apt" ]]; then
            curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
            auto_fix "sudo sh /tmp/get-docker.sh"
            auto_fix "sudo usermod -aG docker $USER"
        fi
    fi
    
    ok "Základní moduly nainstalovány"
    read -p "Press Enter..."
}

# ---------------------- Rozšířené moduly -----------------
install_advanced_modules() {
    echo -e "${CYAN}--- Instalace rozšířených modulů ---${RESET}"
    backup_before_action "advanced_modules"
    
    # Docker Compose
    if ! command -v docker-compose &>/dev/null; then
        auto_fix "sudo curl -L \"https://github.com/docker/compose/releases/latest/download/docker-compose-\$(uname -s)-\$(uname -m)\" -o /usr/local/bin/docker-compose"
        auto_fix "sudo chmod +x /usr/local/bin/docker-compose"
    fi
    
    # Node.js & npm
    if ! command -v node &>/dev/null; then
        if [[ "$PKG_MANAGER" == "apt" ]]; then
            curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
            pkg_install nodejs
        fi
    fi
    
    # Python tools
    pip3 install --upgrade pip setuptools wheel 2>/dev/null || warn "Python pip aktualizace selhala"
    pip3 install ansible docker-compose pyyaml jinja2 2>/dev/null || warn "Python balíčky selhaly"
    
    # Monitoring
    pkg_install ncdu iotop nethogs glances 2>/dev/null || warn "Monitoring nástroje selhaly"
    
    ok "Rozšířené moduly nainstalovány"
    read -p "Press Enter..."
}

# ---------------------- Security Setup -------------------
security_setup() {
    echo -e "${CYAN}--- Bezpečnostní nastavení ---${RESET}"
    backup_before_action "security"
    
    # Firewall
    if command -v ufw &>/dev/null; then
        sudo ufw --force enable
        sudo ufw default deny incoming
        sudo ufw default allow outgoing
        sudo ufw allow ssh
        ok "UFW firewall aktivován"
    elif [[ "$PKG_MANAGER" == "apt" ]]; then
        pkg_install ufw
        sudo ufw --force enable
    fi
    
    # Fail2ban
    if [[ "$PKG_MANAGER" == "apt" ]] && ! command -v fail2ban-client &>/dev/null; then
        pkg_install fail2ban
        sudo systemctl enable fail2ban 2>/dev/null || warn "Fail2ban nelze povolit"
    fi
    
    # SSH hardening
    if [[ -f /etc/ssh/sshd_config ]]; then
        sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
        sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
        sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
        ok "SSH hardening aplikován"
    fi
    
    read -p "Press Enter..."
}

# ---------------------- Performance Tuning ---------------
performance_tuning() {
    echo -e "${CYAN}--- Optimalizace výkonu ---${RESET}"
    
    # Swappiness
    if [[ -w /proc/sys/vm/swappiness ]]; then
        echo 10 | sudo tee /proc/sys/vm/swappiness > /dev/null
        ok "Swappiness nastaven na 10"
    fi
    
    # File descriptors
    if [[ -f /etc/security/limits.conf ]]; then
        echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf > /dev/null
        echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf > /dev/null
        ok "File descriptors zvýšeny"
    fi
    
    # Docker optimization
    if command -v docker &>/dev/null && [[ -f /etc/docker/daemon.json ]]; then
        sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF
        sudo systemctl restart docker 2>/dev/null || warn "Docker restart selhal"
        ok "Docker optimalizován"
    fi
    
    read -p "Press Enter..."
}

# ---------------------- Cleaner PRO ----------------------
cleaner_pro() {
    echo -e "${CYAN}--- Cleaner PRO Advanced ---${RESET}"
    
    local freed_space=0
    
    # Docker cleanup
    if command -v docker &>/dev/null; then
        info "Čistím Docker..."
        docker system prune -af --volumes 2>/dev/null && ok "Docker vyčištěn"
    fi
    
    # Package manager cleanup
    case "$PKG_MANAGER" in
        apt)
            sudo apt autoremove -y
            sudo apt autoclean -y
            sudo apt clean
            ;;
        dnf)
            sudo dnf autoremove -y
            sudo dnf clean all
            ;;
        pacman)
            sudo pacman -Sc --noconfirm
            ;;
    esac
    
    # Cache cleanup
    rm -rf ~/.cache/* 2>/dev/null
    rm -rf /tmp/* 2>/dev/null
    
    # Log rotation
    sudo find /var/log -type f -name "*.log" -mtime +30 -delete 2>/dev/null
    
    # Old kernels (Ubuntu/Debian)
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        dpkg -l | grep linux-image | awk '{print $2}' | grep -v $(uname -r) | xargs sudo apt-get -y purge 2>/dev/null || warn "Kernel cleanup selhal"
    fi
    
    ok "Cleaner PRO dokončen"
    read -p "Press Enter..."
}

# ---------------------- Backup Manager -------------------
backup_manager() {
    echo -e "${CYAN}--- Backup Manager ---${RESET}"
    echo "1) Záloha domovských adresářů"
    echo "2) Záloha konfigurace systému"
    echo "3) Záloha Docker volumes"
    echo "4) Obnovit ze zálohy"
    echo "5) Seznam záloh"
    read -p "Volba: " backup_choice
    
    case $backup_choice in
        1)
            for d in "${DISTROS[@]}"; do
                local backup_file="$BACKUP_DIR/${d}_home_$(date +%Y%m%d_%H%M%S).tar.gz"
                tar -czf "$backup_file" -C "$HOME" . 2>/dev/null && ok "Záloha: $backup_file"
            done
            ;;
        2)
            local config_backup="$BACKUP_DIR/system_config_$(date +%Y%m%d_%H%M%S).tar.gz"
            sudo tar -czf "$config_backup" /etc 2>/dev/null && ok "Config záloha: $config_backup"
            ;;
        3)
            if command -v docker &>/dev/null; then
                docker volume ls -q | xargs -I {} docker run --rm -v {}:/data -v "$BACKUP_DIR":/backup alpine tar czf /backup/{}_$(date +%Y%m%d_%H%M%S).tar.gz /data
                ok "Docker volumes zálohovány"
            fi
            ;;
        4)
            ls -lth "$BACKUP_DIR"/*.tar.gz | head -10
            read -p "Zadej cestu k záloze: " restore_file
            [[ -f "$restore_file" ]] && tar -xzf "$restore_file" -C "$HOME" && ok "Obnoveno"
            ;;
        5)
            ls -lh "$BACKUP_DIR"
            ;;
    esac
    read -p "Press Enter..."
}

# ---------------------- Module Check ---------------------
check_modules() {
    echo -e "${CYAN}--- Kontrola modulů ---${RESET}"
    
    local modules=("docker" "docker-compose" "git" "curl" "wget" "vim" "tmux" "zsh" "python3" "pip3" "node" "npm")
    local installed=0
    local missing=0
    
    for m in "${modules[@]}"; do
        if command -v $m &>/dev/null; then
            local version=$(command $m --version 2>&1 | head -1)
            echo -e " ${GREEN}✓${RESET} $m: $version"
            ((installed++))
        else
            echo -e " ${RED}✗${RESET} $m"
            ((missing++))
        fi
    done
    
    echo
    ok "Nainstalováno: $installed | Chybí: $missing"
    read -p "Press Enter..."
}

# ---------------------- Quick Setup ----------------------
quick_setup() {
    echo -e "${MAGENTA}${BOLD}=== QUICK SETUP ===${RESET}"
    echo "Tento průvodce automaticky nastaví celý systém."
    read -p "Pokračovat? (y/n): " confirm
    
    [[ "$confirm" != "y" ]] && return
    
    info "Spouštím Quick Setup..."
    
    detect_os
    detect_distros
    system_health_check
    install_basic_modules
    install_advanced_modules
    security_setup
    performance_tuning
    
    ok "Quick Setup dokončen!"
    read -p "Press Enter..."
}

# ---------------------- Export konfigurace ---------------
export_config() {
    cat > "$CONFIG_FILE" <<EOF
OS_TYPE=$OS_TYPE
DISTRO_NAME=$DISTRO_NAME
PKG_MANAGER=$PKG_MANAGER
DISTROS=(${DISTROS[@]})
LAST_UPDATE=$(date)
EOF
    ok "Konfigurace exportována: $CONFIG_FILE"
}

import_config() {
    [[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE" && ok "Konfigurace importována"
}

# ---------------------- GUI Menu -------------------------
show_menu() {
    clear
    echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║  WSL/Linux/Termux ULTIMATE PRO MAX GUI - Enhanced ║${RESET}"
    echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════╝${RESET}"
    echo -e "${BOLD}OS:${RESET} $OS_TYPE | ${BOLD}Distro:${RESET} $DISTRO_NAME | ${BOLD}PKG:${RESET} $PKG_MANAGER"
    echo -e "${BOLD}Distribuce:${RESET} ${DISTROS[*]}"
    echo
    echo -e "${BOLD}${CYAN}Stav modulů:${RESET}"
    for m in docker git curl python3 node; do
        if command -v $m &>/dev/null; then 
            echo -e " ${GREEN}✓${RESET} $m"
        else 
            echo -e " ${RED}✗${RESET} $m"
        fi
    done
    echo
    echo -e "${BOLD}${YELLOW}═══ Základní ═══${RESET}"
    echo " 1) Quick Setup (vše najednou)"
    echo " 2) Detekce OS a distribucí"
    echo " 3) Nastavení domovských adresářů"
    echo " 4) Instalace základních modulů"
    echo " 5) Instalace rozšířených modulů"
    echo
    echo -e "${BOLD}${YELLOW}═══ Pokročilé ═══${RESET}"
    echo " 6) Bezpečnostní nastavení"
    echo " 7) Optimalizace výkonu"
    echo " 8) Cleaner PRO Advanced"
    echo " 9) Backup Manager"
    echo "10) Kontrola modulů"
    echo "11) Health Check"
    echo
    echo " 0) Ukončit"
    echo
}

# ---------------------- Main Loop ------------------------
main() {
    detect_os
    detect_distros
    import_config
    
    while true; do
        show_menu
        read -p "$(echo -e ${BOLD}${GREEN}Volba:${RESET} )" choice
        
        case $choice in
            1) quick_setup;;
            2) detect_os; detect_distros; read -p "Press Enter...";;
            3) setup_home;;
            4) install_basic_modules;;
            5) install_advanced_modules;;
            6) security_setup;;
            7) performance_tuning;;
            8) cleaner_pro;;
            9) backup_manager;;
            10) check_modules;;
            11) system_health_check;;
            0) export_config; ok "Ukončuji..."; exit 0;;
            *) warn "Neplatná volba"; sleep 1;;
        esac
    done
}

# ---------------------- Start ----------------------------
main "$@"