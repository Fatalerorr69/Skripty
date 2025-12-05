#!/bin/bash
# ==========================================
# Ultra Robustní SmartHome All-in-One Universal Installer
# Linux / Windows / Termux
# Node-RED, Home Assistant, ioBroker, Draw.io, pluginy + demo flow
# S pokročilým ošetřením chyb, logováním, zálohováním a obnovením
# ==========================================

set -euo pipefail  # Přísnější kontrola chyb

# --- Konfigurace a globální proměnné ---
readonly DEMO_FLOW_URL="https://pastebin.com/raw/zR1kJxqL"
readonly CONFIG_FILE="${HOME}/.smarthome_installer.conf"
readonly LOG_FILE="${HOME}/smarthome_install.log"
readonly BACKUP_DIR="${HOME}/smarthome_backup"
readonly LOCK_FILE="/tmp/smarthome_installer.lock"

# Defaultní konfigurace
readonly DEFAULT_CONFIG=(
    "TIMEZONE=Europe/Prague"
    "NODERED_PORT=1880"
    "HASS_PORT=8123"
    "IOBROKER_PORT=8081"
    "ENABLE_BACKUP=true"
    "MAX_RETRIES=3"
    "DOWNLOAD_TIMEOUT=30"
)

# --- Inicializace a utility ---
init_logging() {
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    exec > >(tee -a "$LOG_FILE") 2>&1
    echo "=== Instalace spuštěna: $(date) ===" | tee -a "$LOG_FILE"
}

log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
    
    # Barevný výstup na konzoli
    case "$level" in
        "ERROR") echo -e "\033[0;31m[$level] $message\033[0m" ;;
        "WARNING") echo -e "\033[0;33m[$level] $message\033[0m" ;;
        "SUCCESS") echo -e "\033[0;32m[$level] $message\033[0m" ;;
        "INFO") echo -e "\033[0;34m[$level] $message\033[0m" ;;
        *) echo "[$level] $message" ;;
    esac
}

check_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local pid=$(cat "$LOCK_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            log_message "ERROR" "Instalace již běží pod PID: $pid"
            exit 1
        else
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
}

cleanup_lock() {
    rm -f "$LOCK_FILE"
}

trap cleanup_lock EXIT

load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log_message "INFO" "Vytvářím výchozí konfigurační soubor: $CONFIG_FILE"
        printf "%s\n" "${DEFAULT_CONFIG[@]}" > "$CONFIG_FILE"
    fi
    
    source "$CONFIG_FILE"
    log_message "INFO" "Konfigurace načtena z: $CONFIG_FILE"
}

save_config() {
    local key="$1"
    local value="$2"
    
    if grep -q "^$key=" "$CONFIG_FILE" 2>/dev/null; then
        sed -i "s/^$key=.*/$key=$value/" "$CONFIG_FILE"
    else
        echo "$key=$value" >> "$CONFIG_FILE"
    fi
}

check_dependency() {
    local cmd="$1"
    local package="${2:-$cmd}"
    
    if ! command -v "$cmd" &> /dev/null; then
        log_message "WARNING" "Chybí požadovaný nástroj: $cmd"
        return 1
    fi
    log_message "DEBUG" "Nástroj nalezen: $cmd"
    return 0
}

check_network() {
    local test_urls=(
        "https://www.google.com"
        "https://github.com"
        "https://docker.com"
    )
    
    for url in "${test_urls[@]}"; do
        if curl -Is --connect-timeout 5 --retry 2 "$url" &> /dev/null; then
            log_message "INFO" "Síťové připojení OK: $url"
            return 0
        fi
    done
    
    log_message "ERROR" "Chyba síťového připojení - nelze kontaktovat testovací URL"
    return 1
}

backup_existing() {
    local target_dir="$1"
    local backup_type="${2:-auto}"
    
    if [ ! -d "$target_dir" ]; then
        return 0
    fi
    
    local backup_name="$(basename "$target_dir")_${backup_type}_backup_$(date +%Y%m%d_%H%M%S)"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    log_message "INFO" "Zálohování: $target_dir -> $backup_path"
    
    mkdir -p "$BACKUP_DIR"
    if cp -r "$target_dir" "$backup_path" 2>/dev/null; then
        log_message "SUCCESS" "Záloha vytvořena: $backup_path"
        echo "$backup_path"
        return 0
    else
        log_message "WARNING" "Nelze zalohovat: $target_dir"
        return 1
    fi
}

restore_backup() {
    local backup_path="$1"
    local target_dir="$2"
    
    if [ ! -d "$backup_path" ]; then
        log_message "ERROR" "Záloha neexistuje: $backup_path"
        return 1
    fi
    
    log_message "INFO" "Obnovování zálohy: $backup_path -> $target_dir"
    
    if [ -d "$target_dir" ]; then
        rm -rf "$target_dir"
    fi
    
    if cp -r "$backup_path" "$target_dir"; then
        log_message "SUCCESS" "Záloha obnovena: $target_dir"
        return 0
    else
        log_message "ERROR" "Obnovení zálohy selhalo"
        return 1
    fi
}

list_backups() {
    if [ ! -d "$BACKUP_DIR" ]; then
        echo "Žádné zálohy nebyly nalezeny."
        return 1
    fi
    
    echo "Dostupné zálohy:"
    local count=1
    for backup in "$BACKUP_DIR"/*; do
        if [ -d "$backup" ]; then
            echo "  $count. $(basename "$backup")"
            count=$((count + 1))
        fi
    done
}

download_with_retry() {
    local url="$1"
    local output="$2"
    local max_retries="${3:-5}"
    local retry_count=0
    local wait_time=5
    
    while [ $retry_count -lt $max_retries ]; do
        log_message "INFO" "Stahování: $url -> $output (pokus $((retry_count + 1))/$max_retries)"
        
        if curl -fsSL --connect-timeout 30 --retry 2 -o "$output" "$url"; then
            log_message "SUCCESS" "Úspěšně staženo: $(basename "$output")"
            
            # Ověření, že stažený soubor není prázdný
            if [ ! -s "$output" ]; then
                log_message "WARNING" "Stažený soubor je prázdný: $output"
                return 1
            fi
            
            return 0
        fi
        
        retry_count=$((retry_count + 1))
        log_message "WARNING" "Stažení selhalo, čekám ${wait_time}s před dalším pokusem..."
        sleep $wait_time
        wait_time=$((wait_time * 2))  # Exponenciální backoff
    done
    
    log_message "ERROR" "Selhalo stažení po $max_retries pokusech: $url"
    return 1
}

wait_for_service() {
    local url="$1"
    local timeout="${2:-120}"
    local interval=5
    local elapsed=0
    
    log_message "INFO" "Čekám na službu: $url (timeout: ${timeout}s)"
    
    while [ $elapsed -lt $timeout ]; do
        if curl -sf "$url" &> /dev/null; then
            log_message "SUCCESS" "Služba je dostupná: $url"
            return 0
        fi
        
        sleep $interval
        elapsed=$((elapsed + interval))
        log_message "DEBUG" "Čekám... ($elapsed/${timeout}s)"
    done
    
    log_message "ERROR" "Timeout čekání na službu: $url"
    return 1
}

check_port_conflict() {
    local port="$1"
    local service="$2"
    
    case "$(uname -s)" in
        Linux*)
            if command -v netstat >/dev/null 2>&1 && netstat -tuln | grep ":$port " > /dev/null; then
                log_message "WARNING" "Port $port je již používán - může způsobit konflikt pro $service"
                return 1
            fi
            ;;
        Darwin*)
            if command -v lsof >/dev/null 2>&1 && lsof -i ":$port" > /dev/null 2>&1; then
                log_message "WARNING" "Port $port je již používán - může způsobit konflikt pro $service"
                return 1
            fi
            ;;
    esac
    
    return 0
}

# --- Linux instalace ---
install_linux() {
    log_message "INFO" "Začíná instalace pro Linux"
    
    # Detekce distribuce
    local distro_name="Unknown"
    local pkg_manager="apt"
    local docker_compose_cmd="docker-compose"
    
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        distro_name="$NAME $VERSION"
        
        case "$ID" in
            fedora|rhel|centos)
                pkg_manager="dnf"
                ;;
            arch)
                pkg_manager="pacman"
                ;;
            opensuse*)
                pkg_manager="zypper"
                ;;
        esac
    fi
    
    log_message "INFO" "Detekovaná distribuce: $distro_name (správce balíčků: $pkg_manager)"
    
    # Aktualizace systému
    log_message "INFO" "Aktualizace systému..."
    case "$pkg_manager" in
        apt)
            sudo apt update && sudo apt upgrade -y || {
                log_message "ERROR" "Aktualizace systému selhala"
                return 1
            }
            ;;
        dnf)
            sudo dnf update -y || {
                log_message "ERROR" "Aktualizace systému selhala"
                return 1
            }
            ;;
        pacman)
            sudo pacman -Syu --noconfirm || {
                log_message "ERROR" "Aktualizace systému selhala"
                return 1
            }
            ;;
    esac
    
    # Instalace závislostí
    local dependencies=()
    case "$pkg_manager" in
        apt)
            dependencies=(docker.io docker-compose snapd curl xdg-utils git jq wget net-tools)
            ;;
        dnf)
            dependencies=(docker docker-compose curl git jq wget net-tools)
            sudo systemctl enable --now docker
            ;;
        pacman)
            dependencies=(docker docker-compose curl git jq wget net-tools)
            sudo systemctl enable --now docker
            ;;
    esac
    
    for pkg in "${dependencies[@]}"; do
        log_message "INFO" "Instalace balíčku: $pkg"
        case "$pkg_manager" in
            apt) sudo apt install -y "$pkg" || log_message "WARNING" "Balíček se nemohl nainstalovat: $pkg" ;;
            dnf) sudo dnf install -y "$pkg" || log_message "WARNING" "Balíček se nemohl nainstalovat: $pkg" ;;
            pacman) sudo pacman -S --noconfirm "$pkg" || log_message "WARNING" "Balíček se nemohl nainstalovat: $pkg" ;;
        esac
    done
    
    # Spuštění Docker služby
    if ! sudo systemctl enable --now docker; then
        log_message "ERROR" "Nelze spustit Docker službu"
        return 1
    fi
    
    # Přidání uživatele do docker skupiny (pokud není již přidán)
    if ! groups "$USER" | grep -q '\bdocker\b'; then
        log_message "INFO" "Přidávám uživatele $USER do skupiny docker"
        sudo usermod -aG docker "$USER"
        log_message "INFO" "Pro uplatnění změn je třeba se odhlásit a znovu přihlásit"
    fi
    
    # Kontrola portů
    check_port_conflict "1880" "Node-RED"
    check_port_conflict "8123" "Home Assistant"
    
    # Node-RED Docker
    log_message "INFO" "Spouštím Node-RED kontejner"
    if docker ps -a --format "table {{.Names}}" | grep -q "nodered"; then
        log_message "INFO" "Node-RED kontejner již existuje, restartuji..."
        docker stop nodered || true
        docker rm nodered || true
    fi
    
    if ! docker run -d --restart=unless-stopped -p 1880:1880 \
         -v node_red_data:/data --name nodered nodered/node-red; then
        log_message "ERROR" "Spuštění Node-RED kontejneru selhalo"
        return 1
    fi
    
    # Čekání na inicializaci Node-RED
    wait_for_service "http://localhost:1880" 60
    
    log_message "INFO" "Instaluji Node-RED pluginy"
    local plugins=(
        "node-red-dashboard"
        "node-red-contrib-home-assistant-websocket" 
        "node-red-contrib-modbus"
        "node-red-contrib-telegrambot"
        "node-red-node-email"
        "node-red-contrib-influxdb"
    )
    
    for plugin in "${plugins[@]}"; do
        log_message "INFO" "Instalace pluginu: $plugin"
        if ! docker exec -i nodered npm install "$plugin"; then
            log_message "WARNING" "Instalace pluginu selhala: $plugin"
        fi
    done
    
    # Restart Node-RED pro načtení pluginů
    docker restart nodered
    wait_for_service "http://localhost:1880" 30
    
    # Home Assistant Docker
    log_message "INFO" "Spouštím Home Assistant"
    local ha_dir="${HOME}/homeassistant"
    backup_existing "$ha_dir"
    
    if docker ps -a --format "table {{.Names}}" | grep -q "homeassistant"; then
        log_message "INFO" "Home Assistant kontejner již existuje, odstranění..."
        docker stop homeassistant || true
        docker rm homeassistant || true
    fi
    
    if ! docker run -d --name homeassistant --privileged --restart=unless-stopped \
        -e TZ="${TIMEZONE:-Europe/Prague}" -v "$ha_dir:/config" -p 8123:8123 \
        ghcr.io/home-assistant/home-assistant:stable; then
        log_message "ERROR" "Spuštění Home Assistant selhalo"
        return 1
    fi
    
    # Draw.io
    if check_dependency "snap" "snapd"; then
        log_message "INFO" "Instalace Draw.io pomocí Snap"
        if ! sudo snap install drawio; then
            log_message "WARNING" "Instalace Draw.io selhala"
        fi
    else
        log_message "INFO" "Snap není dostupné, přeskočeno instalace Draw.io"
    fi
    
    # ioBroker Docker (volitelný)
    log_message "INFO" "Kontrola ioBroker..."
    if ! docker ps -a --format "table {{.Names}}" | grep -q "iobroker"; then
        log_message "INFO" "Instalace ioBroker"
        if docker run -d --restart=unless-stopped --name iobroker \
            -p 8081:8081 -v iobroker_data:/opt/iobroker \
            buanet/iobroker:latest; then
            log_message "SUCCESS" "ioBroker úspěšně nainstalován"
        else
            log_message "WARNING" "Instalace ioBroker selhala"
        fi
    fi
    
    # Demo flow
    local demo_dir="${HOME}/smarthome_demo"
    mkdir -p "$demo_dir"
    if ! download_with_retry "$DEMO_FLOW_URL" "${demo_dir}/demo_flow.json"; then
        log_message "WARNING" "Nelze stáhnout demo flow, vytvářím základní"
        create_basic_demo_flow "${demo_dir}/demo_flow.json"
    fi
    
    # Import demo flow do Node-RED (pokud je API dostupné)
    sleep 10
    import_node_red_flow "${demo_dir}/demo_flow.json"
    
    log_message "SUCCESS" "Linux instalace dokončena"
    return 0
}

create_basic_demo_flow() {
    local flow_file="$1"
    cat > "$flow_file" << 'EOF'
[
    {
        "id": "demo-flow",
        "type": "tab",
        "label": "SmartHome Demo",
        "disabled": false,
        "info": "Základní demo flow pro SmartHome"
    }
]
EOF
    log_message "INFO" "Základní demo flow vytvořeno: $flow_file"
}

import_node_red_flow() {
    local flow_file="$1"
    
    if [ ! -f "$flow_file" ]; then
        log_message "WARNING" "Soubor flow neexistuje: $flow_file"
        return 1
    fi
    
    log_message "INFO" "Importuji flow do Node-RED"
    
    # Zde by byla implementace importu přes Node-RED API
    # Toto je zjednodušená verze
    log_message "INFO" "Flow je připraveno k manuálnímu importu: $flow_file"
    log_message "INFO" "Pro import: Node-RED → Menu → Import → Select file → $flow_file"
}

# --- Windows instalace ---
install_windows() {
    log_message "INFO" "Začíná instalace pro Windows"
    
    local ps_script=$(cat << 'EOF'
    $ErrorActionPreference = "Stop"
    $ProgressPreference = 'SilentlyContinue'
    
    try {
        # Detekce administrátorských práv
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
        if (-not $isAdmin) {
            Write-Host "POZOR: Není spuštěno jako administrátor. Některé funkce nemusí fungovat." -ForegroundColor Yellow
        }
        
        Write-Host "Kontrola a instalace Node.js..." -ForegroundColor Green
        $nodeCheck = Get-Command node -ErrorAction SilentlyContinue
        if (-not $nodeCheck) {
            Write-Host "Instalace Node.js LTS..." -ForegroundColor Yellow
            winget install OpenJS.NodeJS.LTS -e --silent --accept-package-agreements --force
            if ($LASTEXITCODE -ne 0) { throw "Node.js instalace selhala" }
            
            # Aktualizace PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        }
        
        Write-Host "Instalace Node-RED a pluginů..." -ForegroundColor Green
        npm install -g --unsafe-perm node-red node-red-dashboard node-red-contrib-home-assistant-websocket node-red-contrib-modbus node-red-contrib-telegrambot
        if ($LASTEXITCODE -ne 0) { throw "Node-RED instalace selhala" }
        
        Write-Host "Kontrola ioBroker..." -ForegroundColor Green
        if (-not (Test-Path "C:\iobroker")) {
            Write-Host "Stahuji ioBroker installer..." -ForegroundColor Yellow
            Invoke-WebRequest -Uri 'https://iobroker.net/install.ps1' -OutFile "$env:TEMP\iobroker.ps1" -UseBasicParsing
            
            Write-Host "Spouštím ioBroker instalaci..." -ForegroundColor Yellow
            & "$env:TEMP\iobroker.ps1"
            if ($LASTEXITCODE -ne 0) { throw "ioBroker instalace selhala" }
        } else {
            Write-Host "ioBroker je již nainstalován" -ForegroundColor Green
        }
        
        Write-Host "Instalace ioBroker adaptérů..." -ForegroundColor Green
        Set-Location "C:\iobroker"
        $adapters = @("admin", "mqtt", "zigbee", "sonoff", "shelly", "hue")
        foreach ($adapter in $adapters) {
            Write-Host "Přidávám adapter: $adapter" -ForegroundColor Yellow
            node iobroker add $adapter
        }
        
        Write-Host "Instalace Draw.io..." -ForegroundColor Green
        winget install jgraph.drawio -e --silent --accept-package-agreements --force
        
        Write-Host "Stahování demo flow..." -ForegroundColor Green
        $flowDir = "$env:APPDATA\NodeRED"
        New-Item -ItemType Directory -Path $flowDir -Force | Out-Null
        $flowPath = "$flowDir\demo_flow.json"
        
        Invoke-WebRequest -Uri '$DEMO_FLOW_URL' -OutFile $flowPath -UseBasicParsing -ErrorAction Stop
        
        Write-Host "Spouštím služby..." -ForegroundColor Green
        Start-Process "node-red" -ArgumentList "-v" -WindowStyle Minimized
        Start-Process "http://localhost:1880/ui"
        
        Write-Host "INSTALACE ÚSPĚŠNÁ" -ForegroundColor Green
        exit 0
    }
    catch {
        Write-Host "CHYBA: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
EOF
)

    log_message "INFO" "Spouštím PowerShell skript pro Windows instalaci"
    if ! powershell -Command "$ps_script"; then
        log_message "ERROR" "Windows instalace selhala v PowerShell skriptu"
        return 1
    fi
    
    log_message "SUCCESS" "Windows instalace dokončena"
    return 0
}

# --- Termux instalace ---
install_termux() {
    log_message "INFO" "Začíná instalace pro Termux"
    
    # Zjistit původního uživatele Termuxu
    local termux_user
    if [ -n "${SUDO_USER:-}" ]; then
        termux_user="$SUDO_USER"
    else
        # Pokusit se najít typického Termux uživatele
        termux_user=$(who | awk '{print $1}' | grep -v root | head -1)
        if [ -z "$termux_user" ]; then
            termux_user="$(id -un 1000 2>/dev/null || echo "")"
        fi
    fi
    
    # Pokud jsme root, spustit pkg příkazy jako standardní uživatel
    if [ "$(id -u)" -eq 0 ] && [ -n "$termux_user" ]; then
        log_message "INFO" "Root detekován, spouštím pkg příkazy jako uživatel: $termux_user"
        
        # Aktualizace balíčků jako standardní uživatel
        if ! sudo -u "$termux_user" pkg update -y && sudo -u "$termux_user" pkg upgrade -y; then
            log_message "ERROR" "Aktualizace Termux selhala"
            return 1
        fi
        
        # Instalace závislostí jako standardní uživatel
        local dependencies=(nodejs-lts git curl jq wget nano)
        for pkg_name in "${dependencies[@]}"; do
            log_message "INFO" "Instalace balíčku: $pkg_name"
            if ! sudo -u "$termux_user" pkg install -y "$pkg_name"; then
                log_message "ERROR" "Instalace balíčku selhala: $pkg_name"
                return 1
            fi
        done
        
        log_message "INFO" "Instaluji Node-RED a pluginy"
        if ! sudo -u "$termux_user" npm install -g --unsafe-perm node-red node-red-dashboard node-red-contrib-modbus node-red-contrib-telegrambot; then
            log_message "ERROR" "Node-RED instalace selhala"
            return 1
        fi
    else
        # Standardní postup, pokud skript neběží jako root
        if ! pkg update -y && pkg upgrade -y; then
            log_message "ERROR" "Aktualizace Termux selhala"
            return 1
        fi
        
        local dependencies=(nodejs-lts git curl jq wget nano)
        for pkg_name in "${dependencies[@]}"; do
            log_message "INFO" "Instalace balíčku: $pkg_name"
            if ! pkg install -y "$pkg_name"; then
                log_message "ERROR" "Instalace balíčku selhala: $pkg_name"
                return 1
            fi
        done
        
        log_message "INFO" "Instaluji Node-RED a pluginy"
        if ! npm install -g --unsafe-perm node-red node-red-dashboard node-red-contrib-modbus node-red-contrib-telegrambot; then
            log_message "ERROR" "Node-RED instalace selhala"
            return 1
        fi
    fi
    
    local demo_dir="${HOME}/smarthome_demo"
    mkdir -p "$demo_dir"
    if ! download_with_retry "$DEMO_FLOW_URL" "${demo_dir}/demo_flow.json"; then
        log_message "WARNING" "Nelze stáhnout demo flow, vytvářím základní"
        create_basic_demo_flow "${demo_dir}/demo_flow.json"
    fi
    
    log_message "INFO" "Konfigurace Termux uložení"
    # termux-setup-storage může vyžadovat interakci, spustit v aktuálním prostředí
    termux-setup-storage || log_message "WARNING" "Nelze nastavit Termux storage"
    
    log_message "INFO" "Spouštím Node-RED na pozadí"
    # Spustit Node-RED v aktuálním prostředí (ne jako jiný uživatel)
    if node-red & then
        log_message "SUCCESS" "Node-RED úspěšně spuštěn na pozadí"
        local node_red_pid=$!
        echo "$node_red_pid" > /tmp/node_red.pid 2>/dev/null || true
    else
        log_message "ERROR" "Spuštění Node-RED selhalo"
        return 1
    fi
    
    # Čekání na inicializaci služby
    sleep 10
    
    log_message "INFO" "Otevírám prohlížeč"
    if ! am start -a android.intent.action.VIEW -d "http://localhost:1880/ui" > /dev/null 2>&1; then
        log_message "WARNING" "Nelze automaticky otevřít prohlížeč"
        log_message "INFO" "Manuálně otevřete: http://localhost:1880/ui"
    fi
    
    log_message "SUCCESS" "Termux instalace dokončena"
    return 0
}

# --- Odinstalace ---
uninstall_smarthome() {
    local system="$1"
    
    log_message "WARNING" "Začíná odinstalace SmartHome systému pro: $system"
    
    case "$system" in
        linux)
            log_message "INFO" "Zastavování a odstraňování kontejnerů..."
            docker stop nodered homeassistant iobroker 2>/dev/null || true
            docker rm nodered homeassistant iobroker 2>/dev/null || true
            docker volume rm node_red_data iobroker_data 2>/dev/null || true
            
            log_message "INFO" "Odstraňování adresářů..."
            rm -rf "${HOME}/homeassistant" "${HOME}/smarthome_demo"
            ;;
            
        windows)
            log_message "INFO" "Odstraňování Windows služeb..."
            powershell -Command "
                Stop-Process -Name node-red -Force -ErrorAction SilentlyContinue
                Stop-Process -Name node -Force -ErrorAction SilentlyContinue
            " || true
            ;;
            
        termux)
            log_message "INFO" "Odstraňování Termux instalace..."
            # Zastavit Node-RED proces pokud byl spuštěn
            if [ -f /tmp/node_red.pid ]; then
                local node_red_pid=$(cat /tmp/node_red.pid)
                kill "$node_red_pid" 2>/dev/null || true
                rm -f /tmp/node_red.pid
            fi
            pkill -f "node-red" || true
            npm uninstall -g node-red node-red-dashboard node-red-contrib-modbus node-red-contrib-telegrambot || true
            rm -rf "${HOME}/smarthome_demo"
            ;;
    esac
    
    log_message "SUCCESS" "Odinstalace dokončena pro: $system"
}

# --- Hlavní kontrola závislostí ---
check_system_dependencies() {
    log_message "INFO" "Kontroluji systémové závislosti"
    
    local basic_deps=("curl" "git")
    for dep in "${basic_deps[@]}"; do
        if ! check_dependency "$dep"; then
            log_message "ERROR" "Chybí kritická závislost: $dep"
            return 1
        fi
    done
    
    if ! check_network; then
        log_message "ERROR" "Problém se síťovým připojením"
        return 1
    fi
    
    case "$(uname -s)" in
        Linux*)
            # Bezpečná kontrola PREFIX proměnné s výchozí hodnotou
            if [[ "${PREFIX:-}" != "/data/data/com.termux/files/usr" ]]; then
                check_dependency "docker" || log_message "WARNING" "Docker bude nutné doinstalovat"
            fi
            ;;
        *) ;;
    esac
    
    return 0
}

show_status() {
    log_message "INFO" "Kontroluji stav služeb..."
    
    case "$(uname -s)" in
        Linux*)
            # Bezpečná kontrola PREFIX proměnné
            if [[ "${PREFIX:-}" != "/data/data/com.termux/files/usr" ]]; then
                echo "=== Docker kontejnery ==="
                docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | tee -a "$LOG_FILE" || true
                echo ""
            fi
            ;;
    esac
    
    local services=(
        "http://localhost:1880|Node-RED"
        "http://localhost:8123|Home Assistant"
        "http://localhost:8081|ioBroker"
    )
    
    echo "=== Stav služeb ===" | tee -a "$LOG_FILE"
    for service in "${services[@]}"; do
        local url="${service%|*}"
        local name="${service#*|}"
        
        if curl -sf "$url" > /dev/null 2>&1; then
            echo "✅ $name: BĚŽÍ ($url)" | tee -a "$LOG_FILE"
        else
            echo "❌ $name: NEDOSTUPNÉ ($url)" | tee -a "$LOG_FILE"
        fi
    done
}

show_menu() {
    echo ""
    echo "=== SmartHome Installer Menu ==="
    echo "1) Instalace"
    echo "2) Odinstalace"
    echo "3) Stav služeb"
    echo "4) Zálohování"
    echo "5) Obnovení"
    echo "6) Konfigurace"
    echo "7) Ukončit"
    echo ""
    read -p "Vyberte volbu [1-7]: " choice
    
    case $choice in
        1) main ;;
        2) 
            read -p "Opravdu chcete odinstalovat? (y/N): " confirm
            if [[ $confirm == [yY] ]]; then
                case "$(detect_os)" in
                    linux) uninstall_smarthome "linux" ;;
                    windows) uninstall_smarthome "windows" ;;
                    termux) uninstall_smarthome "termux" ;;
                esac
            fi
            ;;
        3) show_status ;;
        4) 
            read -p "Zálohovat který adresář? [full/hass/nodered]: " backup_type
            case $backup_type in
                hass) backup_existing "${HOME}/homeassistant" "manual" ;;
                nodered) backup_existing "${HOME}/node_red_data" "manual" ;;
                full) 
                    backup_existing "${HOME}/homeassistant" "manual"
                    backup_existing "${HOME}/node_red_data" "manual"
                    ;;
            esac
            ;;
        5)
            list_backups
            read -p "Číslo zálohy k obnovení: " backup_num
            # Implementace obnovení podle čísla
            ;;
        6)
            echo "Editovat konfiguraci: $CONFIG_FILE"
            ${EDITOR:-nano} "$CONFIG_FILE"
            ;;
        7) exit 0 ;;
        *) echo "Neplatná volba" ;;
    esac
}

detect_os() {
    case "$(uname -s)" in
        Linux*)
            # OPRAVA: Bezpečná kontrola PREFIX proměnné pomocí parameter expansion
            if [[ "${PREFIX:-}" == "/data/data/com.termux/files/usr" ]]; then
                echo "termux"
            else
                echo "linux"
            fi
            ;;
        CYGWIN*|MINGW*|MSYS*) echo "windows" ;;
        *) echo "unknown" ;;
    esac
}

# --- Hlavní funkce ---
main() {
    local debug_mode=""
    local skip_deps=""
    
    # Zpracování argumentů
    while [[ $# -gt 0 ]]; do
        case $1 in
            --debug)
                debug_mode="true"
                set -x
                ;;
            --skip-deps)
                skip_deps="true"
                ;;
            --menu)
                show_menu
                exit 0
                ;;
            --status)
                show_status
                exit 0
                ;;
            --uninstall)
                uninstall_smarthome "$(detect_os)"
                exit 0
                ;;
            *)
                log_message "ERROR" "Neznámý přepínač: $1"
                exit 1
                ;;
        esac
        shift
    done
    
    check_lock
    init_logging
    load_config
    
    log_message "INFO" "Spouštím SmartHome installer v režimu: $([ -n "$debug_mode" ] && echo "DEBUG" || echo "NORMAL")"
    
    # Hlavní kontrola před instalací
    if [ -z "$skip_deps" ]; then
        if ! check_system_dependencies; then
            log_message "ERROR" "Kontrola závislostí selhala"
            echo "Podrobnosti v logu: $LOG_FILE"
            exit 1
        fi
    fi
    
    # Detekce OS a spuštění instalace
    local os_detected
    os_detected=$(detect_os)
    
    case "$os_detected" in
        linux) install_linux ;;
        windows) install_windows ;;
        termux) install_termux ;;
        *)
            log_message "ERROR" "Nepodporovaný systém: $(uname -s)"
            exit 1
            ;;
    esac
    
    local install_status=$?
    
    # Závěrečné informace
    echo "" | tee -a "$LOG_FILE"
    echo "=== INSTALACE DOKONČENA ===" | tee -a "$LOG_FILE"
    echo "Detekovaný systém: $os_detected" | tee -a "$LOG_FILE"
    echo "Log soubor: $LOG_FILE" | tee -a "$LOG_FILE"
    echo "Konfigurace: $CONFIG_FILE" | tee -a "$LOG_FILE"
    
    if [ $install_status -eq 0 ]; then
        echo "STATUS: ✅ ÚSPĚCH" | tee -a "$LOG_FILE"
        echo "" | tee -a "$LOG_FILE"
        echo "=== SLUŽBY ===" | tee -a "$LOG_FILE"
        echo "Node-RED: http://localhost:1880/ui" | tee -a "$LOG_FILE"
        [[ "$os_detected" == "linux" ]] && echo "Home Assistant: http://localhost:8123" | tee -a "$LOG_FILE"
        [[ "$os_detected" == "windows" ]] && echo "ioBroker: http://localhost:8081" | tee -a "$LOG_FILE"
        echo "" | tee -a "$LOG_FILE"
        echo "Pro kontrolu stavu spusťte: $0 --status" | tee -a "$LOG_FILE"
        echo "Pro menu spusťte: $0 --menu" | tee -a "$LOG_FILE"
    else
        echo "STATUS: ❌ SELHÁNÍ - viz log soubor" | tee -a "$LOG_FILE"
        exit 1
    fi
    
    show_status
}

# --- Spuštění hlavní funkce ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

