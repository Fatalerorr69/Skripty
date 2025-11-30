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
CUSTOM_SCRIPTS_DIR="$SCRIPT_DIR/custom_scripts"

mkdir -p "$BACKUP_DIR" "$CUSTOM_SCRIPTS_DIR"
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
    echo
    echo "Zahrnuje:"
    echo "  - Detekci OS a distribucí"
    echo "  - Instalaci základních a rozšířených modulů"
    echo "  - Bezpečnostní nastavení"
    echo "  - Optimalizaci výkonu"
    echo "  - Health check"
    echo
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
    cleaner_pro
    
    echo
    echo -e "${GREEN}${BOLD}═══════════════════════════════════${RESET}"
    echo -e "${GREEN}${BOLD}   Quick Setup úspěšně dokončen!   ${RESET}"
    echo -e "${GREEN}${BOLD}═══════════════════════════════════${RESET}"
    echo
    echo "Doporučené další kroky:"
    echo "  - Nastavte cron jobs pro automatické zálohy (volba 16)"
    echo "  - Nakonfigurujte databáze podle potřeby (volba 14)"
    echo "  - Vytvořte system snapshot (volba 19)"
    
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
    echo -e "${BOLD}${YELLOW}═══ Služby & Databáze ═══${RESET}"
    echo "12) Network Diagnostics"
    echo "13) Service Manager"
    echo "14) Database Setup"
    echo "15) Web Server Setup"
    echo
    echo -e "${BOLD}${YELLOW}═══ Development & Automatizace ═══${RESET}"
    echo "16) Cron Manager"
    echo "17) Dev Environment"
    echo "18) Container Orchestration"
    echo "19) System Snapshot"
    echo
    echo -e "${BOLD}${YELLOW}═══ Správa & Nástroje ═══${RESET}"
    echo "20) SSH Key Manager"
    echo "21) Port Manager"
    echo "22) Environment Variables"
    echo "23) Log Viewer"
    echo "24) Rollback System"
    echo
    echo -e "${BOLD}${YELLOW}═══ Monitoring & Skripty ═══${RESET}"
    echo "25) 📊 Monitoring Dashboard (Live)"
    echo "26) 🔧 Custom Scripts Manager"
    echo
    echo " 0) Ukončit"
    echo
}

# ---------------------- Main Loop ------------------------
main() {
    detect_os
    detect_distros
    import_config
    
    # Inicializace custom skriptů při prvním spuštění
    if [[ ! -d "$CUSTOM_SCRIPTS_DIR" ]] || [[ -z "$(ls -A $CUSTOM_SCRIPTS_DIR 2>/dev/null)" ]]; then
        init_custom_scripts
    fi
    
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
            12) network_diagnostics;;
            13) service_manager;;
            14) database_setup;;
            15) webserver_setup;;
            16) cron_manager;;
            17) dev_environment;;
            18) container_orchestration;;
            19) system_snapshot;;
            20) ssh_key_manager;;
            21) port_manager;;
            22) env_manager;;
            23) log_viewer;;
            24) rollback_system;;
            25) monitoring_dashboard;;
            26) custom_scripts_manager;;
            0) export_config; ok "Ukončuji..."; exit 0;;
            *) warn "Neplatná volba"; sleep 1;;
        esac
    done
}

# ---------------------- Network Diagnostics -------------
network_diagnostics() {
    echo -e "${CYAN}--- Network Diagnostics ---${RESET}"
    
    # Port scan
    info "Otevřené porty:"
    if command -v ss &>/dev/null; then
        sudo ss -tulpn | grep LISTEN
    elif command -v netstat &>/dev/null; then
        sudo netstat -tulpn | grep LISTEN
    fi
    
    # DNS test
    info "DNS test:"
    for dns in 8.8.8.8 1.1.1.1 google.com; do
        if ping -c 1 -W 2 $dns &>/dev/null; then
            ok "✓ $dns"
        else
            warn "✗ $dns"
        fi
    done
    
    # Internet speed (rychlý test)
    if command -v curl &>/dev/null; then
        info "Rychlost stahování (test):"
        curl -o /dev/null -w "Speed: %{speed_download} B/s\n" https://speed.cloudflare.com/__down?bytes=10000000 2>/dev/null
    fi
    
    read -p "Press Enter..."
}

# ---------------------- Service Manager ------------------
service_manager() {
    echo -e "${CYAN}--- Service Manager ---${RESET}"
    
    if command -v systemctl &>/dev/null; then
        echo "1) Seznam všech služeb"
        echo "2) Aktivní služby"
        echo "3) Selhané služby"
        echo "4) Enable/Disable službu"
        echo "5) Restart služby"
        read -p "Volba: " svc_choice
        
        case $svc_choice in
            1) systemctl list-units --type=service --all | less;;
            2) systemctl list-units --type=service --state=running;;
            3) systemctl list-units --type=service --state=failed;;
            4)
                read -p "Název služby: " svc_name
                read -p "Enable (e) nebo Disable (d)?: " ed
                [[ "$ed" == "e" ]] && sudo systemctl enable "$svc_name" || sudo systemctl disable "$svc_name"
                ;;
            5)
                read -p "Název služby: " svc_name
                sudo systemctl restart "$svc_name" && ok "Služba restartována"
                ;;
        esac
    else
        warn "systemctl není k dispozici"
    fi
    
    read -p "Press Enter..."
}

# ---------------------- Database Setup -------------------
database_setup() {
    echo -e "${CYAN}--- Database Setup ---${RESET}"
    echo "1) Instalace MySQL/MariaDB"
    echo "2) Instalace PostgreSQL"
    echo "3) Instalace Redis"
    echo "4) Instalace MongoDB"
    echo "5) Database Backup"
    read -p "Volba: " db_choice
    
    case $db_choice in
        1)
            if [[ "$PKG_MANAGER" == "apt" ]]; then
                pkg_install mariadb-server mariadb-client
                sudo systemctl enable mariadb
                sudo systemctl start mariadb
                ok "MariaDB nainstalována. Spusť: sudo mysql_secure_installation"
            fi
            ;;
        2)
            pkg_install postgresql postgresql-contrib
            sudo systemctl enable postgresql
            sudo systemctl start postgresql
            ok "PostgreSQL nainstalován"
            ;;
        3)
            pkg_install redis-server
            sudo systemctl enable redis-server
            sudo systemctl start redis-server
            ok "Redis nainstalován"
            ;;
        4)
            if [[ "$PKG_MANAGER" == "apt" ]]; then
                curl -fsSL https://www.mongodb.org/static/pgp/server-6.0.asc | sudo gpg --dearmor -o /usr/share/keyrings/mongodb-archive-keyring.gpg
                echo "deb [signed-by=/usr/share/keyrings/mongodb-archive-keyring.gpg] https://repo.mongodb.org/apt/ubuntu $(lsb_release -sc)/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list
                sudo apt update
                pkg_install mongodb-org
                ok "MongoDB nainstalován"
            fi
            ;;
        5)
            mkdir -p "$BACKUP_DIR/databases"
            if command -v mysqldump &>/dev/null; then
                sudo mysqldump --all-databases > "$BACKUP_DIR/databases/mysql_$(date +%Y%m%d_%H%M%S).sql"
                ok "MySQL záloha vytvořena"
            fi
            if command -v pg_dumpall &>/dev/null; then
                sudo -u postgres pg_dumpall > "$BACKUP_DIR/databases/postgresql_$(date +%Y%m%d_%H%M%S).sql"
                ok "PostgreSQL záloha vytvořena"
            fi
            ;;
    esac
    read -p "Press Enter..."
}

# ---------------------- Web Server Setup -----------------
webserver_setup() {
    echo -e "${CYAN}--- Web Server Setup ---${RESET}"
    echo "1) Instalace Nginx"
    echo "2) Instalace Apache"
    echo "3) Instalace Certbot (Let's Encrypt)"
    echo "4) Konfigurace virtual host"
    read -p "Volba: " web_choice
    
    case $web_choice in
        1)
            pkg_install nginx
            sudo systemctl enable nginx
            sudo systemctl start nginx
            ok "Nginx nainstalován na http://localhost"
            ;;
        2)
            pkg_install apache2
            sudo systemctl enable apache2
            sudo systemctl start apache2
            ok "Apache nainstalován na http://localhost"
            ;;
        3)
            if [[ "$PKG_MANAGER" == "apt" ]]; then
                pkg_install certbot python3-certbot-nginx
                ok "Certbot nainstalován. Spusť: sudo certbot --nginx -d yourdomain.com"
            fi
            ;;
        4)
            read -p "Doména (např. example.local): " domain
            read -p "Root adresář (např. /var/www/$domain): " webroot
            
            mkdir -p "$webroot"
            
            if command -v nginx &>/dev/null; then
                sudo tee /etc/nginx/sites-available/$domain > /dev/null <<EOF
server {
    listen 80;
    server_name $domain;
    root $webroot;
    index index.html index.php;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }
}
EOF
                sudo ln -sf /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/
                sudo nginx -t && sudo systemctl reload nginx
                ok "Nginx virtual host vytvořen pro $domain"
            fi
            ;;
    esac
    read -p "Press Enter..."
}

# ---------------------- Cron Manager ---------------------
cron_manager() {
    echo -e "${CYAN}--- Cron Manager ---${RESET}"
    echo "1) Seznam cron jobs"
    echo "2) Přidat cron job"
    echo "3) Editovat crontab"
    echo "4) Automatické zálohy (denně)"
    echo "5) Automatické updaty (týdně)"
    read -p "Volba: " cron_choice
    
    case $cron_choice in
        1) crontab -l 2>/dev/null || warn "Žádné cron jobs";;
        2)
            read -p "Příkaz: " cmd
            read -p "Časování (např. '0 2 * * *' = denně 2:00): " timing
            (crontab -l 2>/dev/null; echo "$timing $cmd") | crontab -
            ok "Cron job přidán"
            ;;
        3) crontab -e;;
        4)
            local backup_script="$SCRIPT_DIR/auto_backup.sh"
            cat > "$backup_script" <<'EOF'
#!/bin/bash
tar -czf ~/backups/auto_backup_$(date +%Y%m%d).tar.gz ~/ 2>/dev/null
find ~/backups/ -name "auto_backup_*.tar.gz" -mtime +7 -delete
EOF
            chmod +x "$backup_script"
            (crontab -l 2>/dev/null; echo "0 2 * * * $backup_script") | crontab -
            ok "Automatické zálohy nastaveny (denně 2:00)"
            ;;
        5)
            (crontab -l 2>/dev/null; echo "0 3 * * 0 sudo apt update && sudo apt upgrade -y") | crontab -
            ok "Automatické updaty nastaveny (neděle 3:00)"
            ;;
    esac
    read -p "Press Enter..."
}

# ---------------------- Dev Environment ------------------
dev_environment() {
    echo -e "${CYAN}--- Development Environment ---${RESET}"
    echo "1) PHP (včetně Composer)"
    echo "2) Ruby (včetně Rails)"
    echo "3) Go"
    echo "4) Rust"
    echo "5) Java (OpenJDK)"
    echo "6) .NET SDK"
    read -p "Volba: " dev_choice
    
    case $dev_choice in
        1)
            pkg_install php php-cli php-fpm php-mysql php-curl php-gd php-mbstring php-xml php-zip
            if ! command -v composer &>/dev/null; then
                curl -sS https://getcomposer.org/installer | php
                sudo mv composer.phar /usr/local/bin/composer
            fi
            ok "PHP a Composer nainstalováno"
            ;;
        2)
            if ! command -v rbenv &>/dev/null; then
                git clone https://github.com/rbenv/rbenv.git ~/.rbenv
                echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
                echo 'eval "$(rbenv init -)"' >> ~/.bashrc
                git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
            fi
            ok "Ruby environment připraven"
            ;;
        3)
            if [[ "$PKG_MANAGER" == "apt" ]]; then
                wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz -O /tmp/go.tar.gz
                sudo tar -C /usr/local -xzf /tmp/go.tar.gz
                echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
                ok "Go nainstalováno"
            fi
            ;;
        4)
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
            ok "Rust nainstalován"
            ;;
        5)
            pkg_install default-jdk
            ok "Java nainstalována"
            ;;
        6)
            if [[ "$PKG_MANAGER" == "apt" ]]; then
                wget https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb -O /tmp/packages-microsoft-prod.deb
                sudo dpkg -i /tmp/packages-microsoft-prod.deb
                sudo apt update
                pkg_install dotnet-sdk-8.0
                ok ".NET SDK nainstalován"
            fi
            ;;
    esac
    read -p "Press Enter..."
}

# ---------------------- Container Orchestration ----------
container_orchestration() {
    echo -e "${CYAN}--- Container Orchestration ---${RESET}"
    echo "1) Instalace Docker Swarm"
    echo "2) Instalace Kubernetes (k3s)"
    echo "3) Instalace Portainer"
    echo "4) Docker Compose Stack Manager"
    read -p "Volba: " orch_choice
    
    case $orch_choice in
        1)
            if command -v docker &>/dev/null; then
                sudo docker swarm init
                ok "Docker Swarm inicializován"
            fi
            ;;
        2)
            curl -sfL https://get.k3s.io | sh -
            ok "k3s nainstalován"
            ;;
        3)
            if command -v docker &>/dev/null; then
                docker volume create portainer_data
                docker run -d -p 9000:9000 -p 8000:8000 --name portainer --restart always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce
                ok "Portainer běží na http://localhost:9000"
            fi
            ;;
        4)
            read -p "Cesta k docker-compose.yml: " compose_file
            if [[ -f "$compose_file" ]]; then
                docker-compose -f "$compose_file" up -d
                ok "Stack spuštěn"
            fi
            ;;
    esac
    read -p "Press Enter..."
}

# ---------------------- System Snapshot ------------------
system_snapshot() {
    echo -e "${CYAN}--- System Snapshot ---${RESET}"
    
    local snapshot_dir="$BACKUP_DIR/snapshots/snapshot_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$snapshot_dir"
    
    info "Vytvářím snapshot systému..."
    
    # Systémové info
    uname -a > "$snapshot_dir/system_info.txt"
    df -h > "$snapshot_dir/disk_usage.txt"
    free -h > "$snapshot_dir/memory.txt"
    
    # Balíčky
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        dpkg --get-selections > "$snapshot_dir/packages.txt"
    fi
    
    # Docker
    if command -v docker &>/dev/null; then
        docker ps -a > "$snapshot_dir/docker_containers.txt"
        docker images > "$snapshot_dir/docker_images.txt"
    fi
    
    # Cron jobs
    crontab -l > "$snapshot_dir/crontab.txt" 2>/dev/null
    
    # Služby
    if command -v systemctl &>/dev/null; then
        systemctl list-units --type=service > "$snapshot_dir/services.txt"
    fi
    
    ok "Snapshot vytvořen: $snapshot_dir"
    read -p "Press Enter..."
}

# ---------------------- SSH Key Manager ------------------
ssh_key_manager() {
    echo -e "${CYAN}--- SSH Key Manager ---${RESET}"
    echo "1) Vygenerovat nový SSH klíč"
    echo "2) Seznam SSH klíčů"
    echo "3) Přidat klíč na remote server"
    echo "4) Test SSH připojení"
    read -p "Volba: " ssh_choice
    
    case $ssh_choice in
        1)
            read -p "Email: " email
            ssh-keygen -t ed25519 -C "$email" -f ~/.ssh/id_ed25519
            ok "SSH klíč vygenerován: ~/.ssh/id_ed25519"
            echo "Veřejný klíč:"
            cat ~/.ssh/id_ed25519.pub
            ;;
        2)
            ls -lh ~/.ssh/*.pub 2>/dev/null || warn "Žádné SSH klíče"
            ;;
        3)
            read -p "User@host: " remote
            ssh-copy-id "$remote" && ok "Klíč přidán"
            ;;
        4)
            read -p "User@host: " remote
            ssh -o ConnectTimeout=5 "$remote" "echo 'SSH OK'" && ok "Připojení úspěšné"
            ;;
    esac
    read -p "Press Enter..."
}

# ---------------------- Port Manager ---------------------
port_manager() {
    echo -e "${CYAN}--- Port Manager ---${RESET}"
    echo "1) Otevřené porty"
    echo "2) Otevřít port v firewallu"
    echo "3) Zavřít port v firewallu"
    echo "4) Port forward (WSL)"
    read -p "Volba: " port_choice
    
    case $port_choice in
        1)
            if command -v ss &>/dev/null; then
                ss -tulpn
            elif command -v netstat &>/dev/null; then
                netstat -tulpn
            fi
            ;;
        2)
            read -p "Port číslo: " port
            if command -v ufw &>/dev/null; then
                sudo ufw allow $port
                ok "Port $port otevřen"
            fi
            ;;
        3)
            read -p "Port číslo: " port
            if command -v ufw &>/dev/null; then
                sudo ufw deny $port
                ok "Port $port zavřen"
            fi
            ;;
        4)
            if [[ "$OS_TYPE" == "wsl" ]]; then
                read -p "Port číslo: " port
                powershell.exe -Command "netsh interface portproxy add v4tov4 listenport=$port listenaddress=0.0.0.0 connectport=$port connectaddress=(wsl hostname -I).Trim()"
                ok "Port forward nastaven pro port $port"
            else
                warn "Port forward je pouze pro WSL"
            fi
            ;;
    esac
    read -p "Press Enter..."
}

# ---------------------- Environment Variables ------------
env_manager() {
    echo -e "${CYAN}--- Environment Variables Manager ---${RESET}"
    echo "1) Zobrazit všechny ENV proměnné"
    echo "2) Přidat ENV proměnnou"
    echo "3) Smazat ENV proměnnou"
    echo "4) Export do .env souboru"
    read -p "Volba: " env_choice
    
    case $env_choice in
        1)
            printenv | sort | less
            ;;
        2)
            read -p "Název proměnné: " var_name
            read -p "Hodnota: " var_value
            echo "export $var_name=\"$var_value\"" >> ~/.bashrc
            source ~/.bashrc
            ok "Proměnná přidána do ~/.bashrc"
            ;;
        3)
            read -p "Název proměnné: " var_name
            sed -i "/export $var_name=/d" ~/.bashrc
            unset $var_name
            ok "Proměnná odstraněna"
            ;;
        4)
            printenv > "$SCRIPT_DIR/.env"
            ok ".env soubor vytvořen: $SCRIPT_DIR/.env"
            ;;
    esac
    read -p "Press Enter..."
}

# ---------------------- Log Viewer -----------------------
log_viewer() {
    echo -e "${CYAN}--- Log Viewer ---${RESET}"
    echo "1) System log"
    echo "2) Auth log"
    echo "3) Docker logs"
    echo "4) Nginx/Apache logs"
    echo "5) Tento skript log"
    echo "6) Čistit staré logy"
    read -p "Volba: " log_choice
    
    case $log_choice in
        1) sudo tail -f /var/log/syslog 2>/dev/null || sudo tail -f /var/log/messages;;
        2) sudo tail -f /var/log/auth.log 2>/dev/null || sudo tail -f /var/log/secure;;
        3)
            read -p "Container název: " container
            docker logs -f "$container"
            ;;
        4)
            if [[ -f /var/log/nginx/error.log ]]; then
                sudo tail -f /var/log/nginx/error.log
            elif [[ -f /var/log/apache2/error.log ]]; then
                sudo tail -f /var/log/apache2/error.log
            fi
            ;;
        5) tail -f "$LOGFILE";;
        6)
            sudo find /var/log -type f -name "*.log" -mtime +30 -delete
            ok "Staré logy vyčištěny"
            ;;
    esac
    read -p "Press Enter..."
}

# ---------------------- Rollback System ------------------
rollback_system() {
    echo -e "${CYAN}--- Rollback System ---${RESET}"
    echo "Dostupné snapshoty:"
    
    local snapshots=("$BACKUP_DIR"/snapshots/*)
    if [[ ${#snapshots[@]} -eq 0 ]]; then
        warn "Žádné snapshoty k dispozici"
        read -p "Press Enter..."
        return
    fi
    
    local i=1
    for snap in "${snapshots[@]}"; do
        echo "$i) $(basename $snap)"
        ((i++))
    done
    
    read -p "Vyberte snapshot k obnovení (číslo): " snap_num
    
    if [[ $snap_num -gt 0 && $snap_num -lt $i ]]; then
        local selected_snap="${snapshots[$((snap_num-1))]}"
        
        warn "POZOR: Toto obnoví systém do předchozího stavu!"
        read -p "Pokračovat? (yes/no): " confirm
        
        if [[ "$confirm" == "yes" ]]; then
            # Obnovení balíčků
            if [[ -f "$selected_snap/packages.txt" && "$PKG_MANAGER" == "apt" ]]; then
                sudo dpkg --set-selections < "$selected_snap/packages.txt"
                sudo apt-get dselect-upgrade -y
            fi
            
            # Obnovení cron jobs
            if [[ -f "$selected_snap/crontab.txt" ]]; then
                crontab "$selected_snap/crontab.txt"
            fi
            
            ok "Rollback dokončen"
        fi
    fi
    
    read -p "Press Enter..."
}

# ---------------------- Monitoring Dashboard -------------
monitoring_dashboard() {
    while true; do
        clear
        echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
        echo -e "${BOLD}${CYAN}║           MONITORING DASHBOARD - LIVE             ║${RESET}"
        echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════╝${RESET}"
        echo -e "${BOLD}Čas:${RESET} $(date '+%Y-%m-%d %H:%M:%S')"
        echo
        
        # CPU Usage
        if command -v top &>/dev/null; then
            local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
            echo -e "${BOLD}CPU Usage:${RESET} ${cpu_usage}%"
            # Progress bar
            local bar_length=50
            local filled=$((${cpu_usage%.*} * bar_length / 100))
            printf "["
            printf "%${filled}s" | tr ' ' '█'
            printf "%$((bar_length - filled))s" | tr ' ' '░'
            printf "]\n"
        fi
        
        # Memory Usage
        if command -v free &>/dev/null; then
            local mem_info=$(free | awk 'NR==2 {printf "%.1f", $3*100/$2}')
            local mem_used=$(free -h | awk 'NR==2 {print $3}')
            local mem_total=$(free -h | awk 'NR==2 {print $2}')
            echo
            echo -e "${BOLD}Memory Usage:${RESET} ${mem_info}% (${mem_used}/${mem_total})"
            local filled=$((${mem_info%.*} * 50 / 100))
            printf "["
            printf "%${filled}s" | tr ' ' '█'
            printf "%$((50 - filled))s" | tr ' ' '░'
            printf "]\n"
        fi
        
        # Disk Usage
        local disk_info=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
        local disk_used=$(df -h / | awk 'NR==2 {print $3}')
        local disk_total=$(df -h / | awk 'NR==2 {print $2}')
        echo
        echo -e "${BOLD}Disk Usage:${RESET} ${disk_info}% (${disk_used}/${disk_total})"
        local filled=$((disk_info * 50 / 100))
        printf "["
        printf "%${filled}s" | tr ' ' '█'
        printf "%$((50 - filled))s" | tr ' ' '░'
        printf "]\n"
        
        # Network Stats
        echo
        echo -e "${BOLD}Network:${RESET}"
        if command -v ip &>/dev/null; then
            ip -s link | awk '/^[0-9]+:/ {iface=$2} /RX:/ {getline; rx=$1} /TX:/ {getline; tx=$1; if(iface && rx && tx) printf "  %s RX: %s MB | TX: %s MB\n", iface, rx/1024/1024, tx/1024/1024}' | head -3
        fi
        
        # Running Processes
        echo
        echo -e "${BOLD}Top 5 Procesů (CPU):${RESET}"
        ps aux --sort=-%cpu | head -6 | tail -5 | awk '{printf "  %-20s %5s%% CPU %5s%% MEM\n", $11, $3, $4}'
        
        # Docker Containers
        if command -v docker &>/dev/null; then
            local running=$(docker ps -q | wc -l)
            local total=$(docker ps -aq | wc -l)
            echo
            echo -e "${BOLD}Docker:${RESET} $running/$total kontejnerů běží"
        fi
        
        # Load Average
        if [[ -f /proc/loadavg ]]; then
            local load=$(cat /proc/loadavg | awk '{print $1, $2, $3}')
            echo
            echo -e "${BOLD}Load Average:${RESET} $load"
        fi
        
        # Uptime
        echo
        echo -e "${BOLD}Uptime:${RESET} $(uptime -p 2>/dev/null || uptime)"
        
        echo
        echo -e "${YELLOW}[Q] Ukončit dashboard | [R] Refresh${RESET}"
        
        read -t 3 -n 1 key
        if [[ "$key" == "q" || "$key" == "Q" ]]; then
            break
        fi
    done
}

# ---------------------- Custom Scripts Manager -----------
init_custom_scripts() {
    # Auto Backup Script
    cat > "$CUSTOM_SCRIPTS_DIR/auto_backup.sh" <<'EOF'
#!/bin/bash
# Automatické zálohování důležitých adresářů
BACKUP_DIR=~/backups/auto
mkdir -p "$BACKUP_DIR"
DATE=$(date +%Y%m%d_%H%M%S)

tar -czf "$BACKUP_DIR/home_$DATE.tar.gz" ~/ --exclude='*/node_modules/*' --exclude='*/.cache/*' 2>/dev/null
find "$BACKUP_DIR" -name "home_*.tar.gz" -mtime +7 -delete

echo "✓ Záloha dokončena: $BACKUP_DIR/home_$DATE.tar.gz"
EOF

    # System Monitor Script
    cat > "$CUSTOM_SCRIPTS_DIR/system_monitor.sh" <<'EOF'
#!/bin/bash
# Monitoring systémových prostředků s alertem
CPU=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
MEM=$(free | awk 'NR==2 {printf "%.0f", $3*100/$2}')
DISK=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')

echo "=== System Monitor ==="
echo "CPU: ${CPU}%"
echo "Memory: ${MEM}%"
echo "Disk: ${DISK}%"

# Alerty
[[ ${CPU%.*} -gt 80 ]] && echo "⚠ VAROVÁNÍ: Vysoké CPU!"
[[ $MEM -gt 85 ]] && echo "⚠ VAROVÁNÍ: Vysoká paměť!"
[[ $DISK -gt 90 ]] && echo "⚠ VAROVÁNÍ: Plný disk!"
EOF

    # Docker Cleanup Script
    cat > "$CUSTOM_SCRIPTS_DIR/docker_cleanup.sh" <<'EOF'
#!/bin/bash
# Kompletní čištění Dockeru
echo "Čistím Docker..."
docker system prune -af --volumes
docker network prune -f
docker volume prune -f
echo "✓ Docker vyčištěn"
EOF

    # Update All Script
    cat > "$CUSTOM_SCRIPTS_DIR/update_all.sh" <<'EOF'
#!/bin/bash
# Aktualizace všech systémů
echo "=== Aktualizace systému ==="

# System packages
if command -v apt &>/dev/null; then
    sudo apt update && sudo apt upgrade -y
elif command -v dnf &>/dev/null; then
    sudo dnf upgrade -y
fi

# Node.js
command -v npm &>/dev/null && sudo npm update -g

# Python
command -v pip3 &>/dev/null && pip3 install --upgrade pip

# Docker images
command -v docker &>/dev/null && docker images --format "{{.Repository}}:{{.Tag}}" | xargs -L1 docker pull 2>/dev/null

echo "✓ Vše aktualizováno"
EOF

    # Security Audit Script
    cat > "$CUSTOM_SCRIPTS_DIR/security_audit.sh" <<'EOF'
#!/bin/bash
# Bezpečnostní audit systému
echo "=== Security Audit ==="

# SSH konfigurace
echo "SSH konfigurace:"
grep -E "PermitRootLogin|PasswordAuthentication" /etc/ssh/sshd_config 2>/dev/null

# Otevřené porty
echo -e "\nOtevřené porty:"
ss -tulpn 2>/dev/null | grep LISTEN

# Firewall status
echo -e "\nFirewall:"
sudo ufw status 2>/dev/null || echo "UFW není aktivní"

# Selhané přihlášení
echo -e "\nPoslední selhané přihlášení:"
sudo lastb | head -5 2>/dev/null

# World-writable files
echo -e "\nWorld-writable soubory v /etc:"
sudo find /etc -type f -perm -002 2>/dev/null | head -5

echo -e "\n✓ Audit dokončen"
EOF

    # Performance Test Script
    cat > "$CUSTOM_SCRIPTS_DIR/performance_test.sh" <<'EOF'
#!/bin/bash
# Test výkonu systému
echo "=== Performance Test ==="

# CPU test
echo "CPU test (5s)..."
dd if=/dev/zero bs=1M count=1000 | md5sum &>/dev/null
echo "✓ CPU test done"

# Disk speed test
echo -e "\nDisk write speed:"
dd if=/dev/zero of=/tmp/test bs=1M count=100 conv=fdatasync 2>&1 | grep -E "MB/s|GB/s"
rm -f /tmp/test

echo -e "\nDisk read speed:"
dd if=/tmp/test of=/dev/null bs=1M count=100 2>&1 | grep -E "MB/s|GB/s" || echo "Test skipped"

# Memory speed
echo -e "\nMemory info:"
free -h

echo -e "\n✓ Performance test dokončen"
EOF

    # Network Test Script
    cat > "$CUSTOM_SCRIPTS_DIR/network_test.sh" <<'EOF'
#!/bin/bash
# Komplexní test sítě
echo "=== Network Test ==="

# Ping test
echo "Ping test:"
for host in 8.8.8.8 1.1.1.1 google.com; do
    if ping -c 1 -W 2 $host &>/dev/null; then
        echo "✓ $host - OK"
    else
        echo "✗ $host - FAILED"
    fi
done

# DNS test
echo -e "\nDNS test:"
nslookup google.com &>/dev/null && echo "✓ DNS OK" || echo "✗ DNS FAILED"

# Port connectivity
echo -e "\nPort test (common ports):"
for port in 80 443 22 3306 5432; do
    timeout 1 bash -c "echo >/dev/tcp/google.com/$port" 2>/dev/null && echo "✓ Port $port open" || echo "✗ Port $port closed"
done

echo -e "\n✓ Network test dokončen"
EOF

    # Smart Cleanup Script
    cat > "$CUSTOM_SCRIPTS_DIR/smart_cleanup.sh" <<'EOF'
#!/bin/bash
# Inteligentní čištění systému
echo "=== Smart Cleanup ==="

FREED=0

# Temp files
echo "Čistím temp soubory..."
rm -rf /tmp/* ~/.cache/* 2>/dev/null
FREED=$((FREED + 100))

# Old logs
echo "Čistím staré logy..."
sudo find /var/log -type f -name "*.log" -mtime +30 -delete 2>/dev/null
FREED=$((FREED + 50))

# Package cache
if command -v apt &>/dev/null; then
    echo "Čistím APT cache..."
    sudo apt autoremove -y &>/dev/null
    sudo apt autoclean -y &>/dev/null
    FREED=$((FREED + 200))
fi

# Docker
if command -v docker &>/dev/null; then
    echo "Čistím Docker..."
    docker system prune -af &>/dev/null
    FREED=$((FREED + 500))
fi

# Old kernels
if command -v dpkg &>/dev/null; then
    echo "Čistím staré kernely..."
    dpkg -l | grep linux-image | awk '{print $2}' | grep -v $(uname -r) | xargs sudo apt-get -y purge 2>/dev/null
    FREED=$((FREED + 300))
fi

echo -e "\n✓ Uvolněno přibližně: ${FREED} MB"
EOF

    # Git Manager Script
    cat > "$CUSTOM_SCRIPTS_DIR/git_manager.sh" <<'EOF'
#!/bin/bash
# Hromadná správa Git repozitářů
echo "=== Git Repository Manager ==="

SEARCH_DIR="${1:-$HOME}"
echo "Hledám Git repozitáře v: $SEARCH_DIR"
echo

find "$SEARCH_DIR" -name ".git" -type d 2>/dev/null | while read gitdir; do
    repo=$(dirname "$gitdir")
    echo "Repository: $repo"
    cd "$repo"
    
    # Status
    git status -s | head -5
    
    # Uncommitted changes
    if [[ -n $(git status -s) ]]; then
        echo "  ⚠ Uncommitted changes!"
    fi
    
    # Behind origin
    git fetch &>/dev/null
    behind=$(git rev-list HEAD..origin/$(git branch --show-current) --count 2>/dev/null)
    [[ $behind -gt 0 ]] && echo "  ↓ Behind origin by $behind commits"
    
    echo
done

echo "✓ Git scan dokončen"
EOF

    # Service Health Check Script
    cat > "$CUSTOM_SCRIPTS_DIR/service_health.sh" <<'EOF'
#!/bin/bash
# Kontrola zdraví služeb
echo "=== Service Health Check ==="

SERVICES=("docker" "nginx" "apache2" "mysql" "postgresql" "redis" "mongodb")

for service in "${SERVICES[@]}"; do
    if systemctl is-active --quiet $service 2>/dev/null; then
        echo "✓ $service: RUNNING"
    elif systemctl list-unit-files | grep -q "^$service.service"; then
        echo "✗ $service: STOPPED"
    fi
done

echo -e "\n✓ Health check dokončen"
EOF

    # Nastavení práv
    chmod +x "$CUSTOM_SCRIPTS_DIR"/*.sh
    
    ok "Custom skripty inicializovány v $CUSTOM_SCRIPTS_DIR"
}

custom_scripts_manager() {
    [[ ! -d "$CUSTOM_SCRIPTS_DIR" || -z "$(ls -A $CUSTOM_SCRIPTS_DIR 2>/dev/null)" ]] && init_custom_scripts
    
    while true; do
        clear
        echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════╗${RESET}"
        echo -e "${BOLD}${CYAN}║           CUSTOM SCRIPTS MANAGER                  ║${RESET}"
        echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════╝${RESET}"
        echo
        
        echo -e "${BOLD}${GREEN}=== Dostupné skripty ===${RESET}"
        local scripts=("$CUSTOM_SCRIPTS_DIR"/*.sh)
        local i=1
        for script in "${scripts[@]}"; do
            [[ -f "$script" ]] && echo " $i) $(basename $script)"
            ((i++))
        done
        
        echo
        echo -e "${BOLD}${YELLOW}=== Akce ===${RESET}"
        echo "a) Spustit skript"
        echo "e) Editovat skript"
        echo "n) Vytvořit nový skript"
        echo "d) Smazat skript"
        echo "r) Reinicializovat výchozí skripty"
        echo "l) Zobrazit obsah skriptu"
        echo "0) Zpět"
        echo
        read -p "$(echo -e ${BOLD}${GREEN}Volba:${RESET} )" choice
        
        case $choice in
            a)
                read -p "Číslo skriptu: " num
                if [[ $num -gt 0 && $num -lt $i ]]; then
                    script="${scripts[$((num-1))]}"
                    echo -e "\n${CYAN}Spouštím: $(basename $script)${RESET}\n"
                    bash "$script"
                    read -p "Press Enter..."
                fi
                ;;
            e)
                read -p "Číslo skriptu: " num
                if [[ $num -gt 0 && $num -lt $i ]]; then
                    ${EDITOR:-nano} "${scripts[$((num-1))]}"
                fi
                ;;
            n)
                read -p "Název nového skriptu (bez .sh): " name
                local new_script="$CUSTOM_SCRIPTS_DIR/${name}.sh"
                cat > "$new_script" <<'EOFSCRIPT'
#!/bin/bash
# Custom skript

echo "=== My Custom Script ==="
# Zde přidejte svůj kód

echo "✓ Hotovo"
EOFSCRIPT
                chmod +x "$new_script"
                ok "Skript vytvořen: $new_script"
                ${EDITOR:-nano} "$new_script"
                ;;
            d)
                read -p "Číslo skriptu ke smazání: " num
                if [[ $num -gt 0 && $num -lt $i ]]; then
                    rm -f "${scripts[$((num-1))]}"
                    ok "Skript smazán"
                fi
                ;;
            r)
                warn "Toto přepíše všechny výchozí skripty!"
                read -p "Pokračovat? (y/n): " confirm
                [[ "$confirm" == "y" ]] && init_custom_scripts
                ;;
            l)
                read -p "Číslo skriptu: " num
                if [[ $num -gt 0 && $num -lt $i ]]; then
                    clear
                    echo -e "${CYAN}=== $(basename ${scripts[$((num-1))]}) ===${RESET}\n"
                    cat "${scripts[$((num-1))]}"
                    read -p "Press Enter..."
                fi
                ;;
            0) break;;
        esac
    done
}

# ---------------------- Start ----------------------------
main "$@"