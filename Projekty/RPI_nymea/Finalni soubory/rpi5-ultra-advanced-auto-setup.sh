#!/bin/bash

# Ultra Rozšířený Automatický Konfiguraci Skript pro Raspberry Pi 5
# Autor: AI asistovaný
# Datum: 2025-09-12
# Verze: 4.0

set -e  # Skript zastaví při chybě
exec > >(tee -a /var/log/rpi5-ultra-setup.log) 2>&1

# Funkce pro barevný výstup
print_status() {
    echo -e "\e[1;34m[$1]\e[0m $2"
}

print_success() {
    echo -e "\e[1;32m[✓]\e[0m $1"
}

print_warning() {
    echo -e "\e[1;33m[!]\e[0m $1"
}

print_error() {
    echo -e "\e[1;31m[✗]\e[0m $1"
}

# Funkce pro logování
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | sudo tee -a /var/log/rpi5-ultra-setup.log >/dev/null
}

# Funkce pro kontrolu závislostí
check_dependencies() {
    local deps=("$@")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        print_error "Chybějící závislosti: ${missing[*]}"
        return 1
    fi
    return 0
}

# Funkce pro detekci Raspberry Pi modelu a parametrů
detect_rpi_info() {
    print_status "INFO" "Detekce hardwarových parametrů..."
    log_message "Začátek detekce hardwarových parametrů"
    
    # Detekce modelu Raspberry Pi
    if [ -f /proc/device-tree/model ]; then
        RPI_MODEL=$(tr -d '\0' < /proc/device-tree/model)
        print_status "INFO" "Detekovaný hardware: $RPI_MODEL"
        log_message "Detekovaný hardware: $RPI_MODEL"
    else
        print_warning "Nelze detekovat model hardware"
        RPI_MODEL="Unknown"
    fi
    
    # Detekce množství RAM
    TOTAL_RAM=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    TOTAL_RAM_GB=$((TOTAL_RAM / 1024 / 1024))
    print_status "INFO" "Detekovaná RAM: ${TOTAL_RAM_GB}GB"
    log_message "Detekovaná RAM: ${TOTAL_RAM_GB}GB"
    
    # Detekce teploty CPU
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        CPU_TEMP=$(($(cat /sys/class/thermal/thermal_zone0/temp) / 1000))
        print_status "INFO" "Aktuální teplota CPU: ${CPU_TEMP}°C"
        log_message "Aktuální teplota CPU: ${CPU_TEMP}°C"
    fi
    
    # Detekce úložného prostoru
    DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}')
    DISK_SIZE=$(df -h / | awk 'NR==2 {print $2}')
    print_status "INFO" "Velikost disku: $DISK_SIZE, Využití: $DISK_USAGE"
    log_message "Velikost disku: $DISK_SIZE, Využití: $DISK_USAGE"
    
    # Detekce aktuálního hostname a IP
    CURRENT_HOSTNAME=$(hostname)
    CURRENT_IP=$(hostname -I | awk '{print $1}')
    print_status "INFO" "Aktuální hostname: $CURRENT_HOSTNAME, IP: $CURRENT_IP"
    log_message "Aktuální hostname: $CURRENT_HOSTNAME, IP: $CURRENT_IP"
    
    # Nastavení GPU paměti podle dostupné RAM
    if [ $TOTAL_RAM_GB -ge 8 ]; then
        GPU_MEM=512
    elif [ $TOTAL_RAM_GB -ge 4 ]; then
        GPU_MEM=256
    else
        GPU_MEM=128
    fi
    print_status "INFO" "Nastavena GPU paměť: ${GPU_MEM}MB"
    log_message "Nastavena GPU paměť: ${GPU_MEM}MB"
    
    # Detekce verze OS
    if [ -f /etc/os-release ]; then
        OS_NAME=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
        OS_VERSION=$(grep VERSION_ID /etc/os-release | cut -d= -f2 | tr -d '"')
        print_status "INFO" "Operační systém: $OS_NAME, Verze: $OS_VERSION"
        log_message "Operační systém: $OS_NAME, Verze: $OS_VERSION"
    fi
}

# Funkce pro kontrolu připojení k internetu
check_internet_connection() {
    print_status "KONTROLA" "Kontrola připojení k internetu..."
    log_message "Kontrola připojení k internetu"
    
    local test_urls=("8.8.8.8" "1.1.1.1" "google.com")
    local connected=false
    
    for url in "${test_urls[@]}"; do
        if ping -q -c 2 -W 1 "$url" >/dev/null 2>&1; then
            print_success "Připojení k internetu je funkční (pomocí $url)"
            log_message "Připojení k internetu je funkční (pomocí $url)"
            connected=true
            break
        fi
    done
    
    if [ "$connected" = false ]; then
        print_error "Chyba připojení k internetu"
        log_message "Chyba připojení k internetu"
        return 1
    fi
    
    # Test rychlosti internetu (volitelné)
    read -p "Chcete otestovat rychlost internetového připojení? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "TEST" "Testování rychlosti internetu..."
        if command -v speedtest-cli &> /dev/null; then
            speedtest-cli --simple
        else
            print_warning "speedtest-cli není nainstalován"
        fi
    fi
    
    return 0
}

# Funkce pro instalaci nástrojů a utilit
install_tools() {
    print_status "INSTALACE" "Instalace systémových nástrojů a utilit..."
    log_message "Začátek instalace nástrojů a utilit"
    
    # Aktualizace seznamu balíčků
    sudo apt-get update
    
    # Kategorie nástrojů
    local categories=(
        "#Základní nástroje:vim git tmux curl wget htop screen unzip p7zip-full rsync tree ncdu dos2unix xmlstarlet"
        "#Vývojářské nástroje:build-essential python3-dev python3-pip python3-venv python3-wheel cmake make automake autoconf libtool"
        "#Síťové nástroje:net-tools traceroute dnsutils nmap tcpdump iftop iotop nethogs openssh-server openssh-client"
        "#Systémové nástroje:lm-sensors sysstat smartmontools hdparm iotop glances dstat uptimed logrotate"
        "#Bezpečnostní nástroje:ufw fail2ban rkhunter chkrootkit clamav clamav-daemon"
        "#Multimediální nástroje:ffmpeg libimage-exiftool-perl mediainfo vlc"
        # Přidáno mnoho dalších kategorií a nástrojů
        "#Databáze:sqlite3 libsqlite3-dev postgresql-client mysql-client"
        "#Webové nástroje:nginx-light apache2-utils certbot"
        "#Virtualizace:qemu-user-static libvirt-clients libvirt-daemon-system virt-manager"
        "#Síťové služby:avahi-daemon cups-bsd samba-client nfs-common"
        "#Grafické nástroje:x11-utils xvfb fbcat"
        "#Hardwarové nástroje:i2c-tools spi-tools picocom minicom"
        "#Jazyky a frameworky:ruby-full nodejs npm golang-go openjdk-17-jdk"
        "#Cloudové nástroje:awscli google-cloud-sdk azure-cli"
        "#Kontejnerové nástroje:podman buildah skopeo"
        "#Monitorovací nástroje:prometheus-node-exporter netdata"
        "#Utility:jq yq bc stress pv rename entr ranger fzf bat exa"
    )
    
    # Instalace nástrojů podle kategorií
    for category in "${categories[@]}"; do
        IFS=':' read -r category_name packages <<< "$category"
        category_name=$(echo "$category_name" | tr -d '#')
        
        print_status "INSTALACE" "Instalace $category_name..."
        log_message "Instalace $category_name: $packages"
        
        # Instalace balíčků s ošetřením chyb
        if ! sudo apt-get install -y $packages; then
            print_warning "Některé balíčky v kategorii $category_name se nepodařilo nainstalovat"
            log_message "Varování: Některé balíčky v kategorii $category_name se nepodařilo nainstalovat"
        fi
    done
    
    # Instalace Dockeru
    if ! command -v docker &> /dev/null; then
        print_status "INSTALACE" "Instalace Dockeru..."
        log_message "Instalace Dockeru"
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        rm get-docker.sh
    fi
    
    # Instalace Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        print_status "INSTALACE" "Instalace Docker Compose..."
        log_message "Instalace Docker Compose"
        sudo pip3 install docker-compose
    fi
    
    # Instalace dalších užitečných Python balíčků
    print_status "INSTALACE" "Instalace Python balíčků..."
    local python_packages=(
        "speedtest-cli" "platformio" "RPi.GPIO" "adafruit-blinka" "adafruit-circuitpython-bme280"
        "requests" "pillow" "pandas" "numpy" "flask" "fastapi" "uvloop" "websockets" "aiohttp"
        "pyserial" "pytest" "black" "mypy" "flake8" "jupyter" "matplotlib" "seaborn" "scikit-learn"
        "tensorflow" "torch" "torchvision" "opencv-python" "pytesseract" "pyzbar" "pynput" "pyautogui"
    )
    
    for package in "${python_packages[@]}"; do
        if ! sudo pip3 install "$package"; then
            print_warning "Nepodařilo se nainstalovat Python balíček: $package"
            log_message "Varování: Nepodařilo se nainstalovat Python balíček: $package"
        fi
    done
    
    # Instalace Node.js a npm
    if ! command -v node &> /dev/null; then
        print_status "INSTALACE" "Instalace Node.js..."
        log_message "Instalace Node.js"
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi
    
    # Instalace globalních npm balíčků
    print_status "INSTALACE" "Instalace globalních npm balíčků..."
    local npm_packages=(
        "npm@latest" "node-red" "homebridge" "express-generator" "typescript" "nodemon" "pm2"
        "yarn" "webpack" "babel-cli" "gulp-cli" "grunt-cli" "create-react-app" "vue-cli"
        "angular-cli" "nestjs/cli" "socket.io" "mqtt" "ws"
    )
    
    for package in "${npm_packages[@]}"; do
        if ! sudo npm install -g "$package"; then
            print_warning "Nepodařilo se nainstalovat npm balíček: $package"
            log_message "Varování: Nepodařilo se nainstalovat npm balíček: $package"
        fi
    done
    
    # Instalace Go aplikací
    print_status "INSTALACE" "Instalace Go aplikací..."
    local go_apps=(
        "github.com/aristocratos/btop@latest" 
        "github.com/cheat/cheat/cmd/cheat@latest"
        "github.com/sharkdp/bat@latest"
        "github.com/sharkdp/fd@latest"
        "github.com/BurntSushi/ripgrep@latest"
    )
    
    for app in "${go_apps[@]}"; do
        if ! go install "$app"; then
            print_warning "Nepodařilo se nainstalovat Go aplikaci: $app"
            log_message "Varování: Nepodařilo se nainstalovat Go aplikaci: $app"
        fi
    done
    
    print_success "Nástroje a utility byly nainstalovány"
    log_message "Nástroje a utility byly nainstalovány"
}

# Funkce pro konfiguraci nymea a pluginů
configure_nymea() {
    print_status "NYMEA" "Konfigurace nymea a instalace pluginů..."
    log_message "Začátek konfigurace nymea a pluginů"
    
    # Kontrola, zda je nymea nainstalováno
    if ! command -v nymead &> /dev/null; then
        print_warning "nymea není nainstalováno, pokus o instalaci..."
        log_message "nymea není nainstalováno, pokus o instalaci"
        
        # Přidání repositáře nymea
        wget -O - https://nymea.io/repository/gpg.key | sudo apt-key add -
        echo "deb https://nymea.io/repository/debian/ stable main" | sudo tee /etc/apt/sources.list.d/nymea.list
        
        # Aktualizace a instalace nymea
        sudo apt-get update
        sudo apt-get install -y nymea nymea-plugins nymea-app nymea-cli
    fi
    
    # Instalace doporučených pluginů
    print_status "NYMEA" "Instalace doporučených pluginů..."
    log_message "Instalace doporučených pluginů pro nymea"
    
    # Kompletní seznam pluginů pro nymea
    NYMEA_PLUGINS="
        nymea-plugin-zigbee nymea-plugin-modbus nymea-plugin-mqttclient
        nymea-plugin-kodi nymea-plugin-toniebox nymea-plugin-networkdetector
        nymea-plugin-wemo nymea-plugin-yeelight nymea-plugin-tasmota
        nymea-plugin-tradfri nymea-plugin-shelly nymea-plugin-sonos
        nymea-plugin-hue nymea-plugin-avahi nymea-plugin-bluetooth
        nymea-plugin-kodi nymea-plugin-lgsmarttv nymea-plugin-lgwebos
        nymea-plugin-nanoleaf nymea-plugin-netatmo nymea-plugin-plex
        nymea-plugin-samsung-tv nymea-plugin-smartthings nymea-plugin-spotify
        nymea-plugin-tplink nymea-plugin-unifi nymea-plugin-wienerlinien
        nymea-plugin-wunderground nymea-plugin-yamaha nymea-plugin-zway
        nymea-plugin-genericthings nymea-plugin-simplebutton nymea-plugin-simpleclosable
        nymea-plugin-simpledetectable nymea-plugin-simpleenergy nymea-plugin-simplelight
        nymea-plugin-simplemedia nymea-plugin-simplethermostat nymea-plugin-simpleweather
    "
    
    for plugin in $NYMEA_PLUGINS; do
        if apt-cache show $plugin &> /dev/null; then
            sudo apt-get install -y $plugin
            print_success "Nainstalován plugin: $plugin"
            log_message "Nainstalován plugin: $plugin"
        else
            print_warning "Plugin $plugin není dostupný"
            log_message "Varování: Plugin $plugin není dostupný"
        fi
    done
    
    # Nastavení nymea jako služby
    sudo systemctl enable nymea
    sudo systemctl start nymea
    
    # Vytvoření rozšířené konfigurace
    if [ ! -f /etc/nymea/nymea.conf ]; then
        print_status "NYMEA" "Vytváření rozšířené konfigurace..."
        log_message "Vytváření rozšířené konfigurace pro nymea"
        sudo mkdir -p /etc/nymea
        sudo bash -c 'cat > /etc/nymea/nymea.conf << EOF
[General]
Name=My Raspberry Pi Smart Home
Timezone=Europe/Prague
Language=cs
Debug=false
PerformanceLogging=false

[Cloud]
Enabled=false
AutomaticPush=false

[MQTT]
Enabled=true
Port=1883
Authentication=false
SSL=false

[WebServer]
Enabled=true
Port=8080
Authentication=true
SSL=false

[JSONRPC]
Enabled=true
Port=9090
Authentication=true
SSL=false

[Zigbee]
Enabled=true
SerialPort=/dev/ttyACM0

[Bluetooth]
Enabled=true
Adapter=hci0

[Rules]
Enabled=true
MaxLogEntries=1000

[Logging]
Enabled=true
Level=Info
MaxSize=10
MaxFiles=5

[Plugins]
LoadAll=true

[Network]
Interface=eth0
HostAddress=$(hostname -I | awk '\''{print $1}'\'')

[Time]
AutoUpdate=true
NTPServers=0.pool.ntp.org 1.pool.ntp.org 2.pool.ntp.org

[Backup]
AutoBackup=true
BackupInterval=7
MaxBackups=4
EOF'
    fi
    
    # Vytvoření základních pravidel a automatizací
    sudo mkdir -p /etc/nymea/automations
    sudo bash -c 'cat > /etc/nymea/automations/basic-rules.json << EOF
{
    "name": "Základní automatizace",
    "description": "Základní nastavení automatizací pro smart home",
    "events": [],
    "actions": [],
    "states": [],
    "rules": [
        {
            "name": "Noční režim",
            "description": "Vypnutí všech světel po půlnoci",
            "enabled": true,
            "time": {
                "time": "00:00",
                "weekdays": [1, 2, 3, 4, 5, 6, 7]
            },
            "actions": [
                {
                    "thingId": "{all-lights}",
                    "actionTypeId": "power",
                    "params": {
                        "power": false
                    }
                }
            ]
        }
    ]
}
EOF'
    
    print_success "Nymea bylo nakonfigurováno"
    log_message "Nymea bylo nakonfigurováno"
}

# Funkce pro optimalizaci systému
optimize_system() {
    print_status "OPTIMALIZACE" "Optimalizace systému pro Raspberry Pi 5..."
    log_message "Začátek optimalizace systému"
    
    # Rozšíření filesystému na celou SD kartu
    sudo raspi-config nonint do_expand_rootfs
    
    # Nastavení GPU paměti
    sudo raspi-config nonint do_memory_split $GPU_MEM
    
    # Zákaz spořiče obrazovky
    sudo raspi-config nonint do_blanking 1
    
    # Optimalizace výkonu - nastavení governor na performance
    echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
    
    # Přidání optimalizací do /boot/config.txt pro RPi 5
    if grep -q "Raspberry Pi 5" /proc/device-tree/model; then
        print_status "OPTIMALIZACE" "Aplikování specifických optimalizací pro Raspberry Pi 5..."
        log_message "Aplikování specifických optimalizací pro Raspberry Pi 5"
        
        # Optimalizace pro RPi 5
        sudo bash -c 'cat >> /boot/config.txt << EOF

# =============================================
# Optimalizace pro Raspberry Pi 5
# =============================================
[pi5]
# Nastavení GPU
gpu_mem=${GPU_MEM}
gpu_freq=800
# Nastavení CPU
arm_freq=2400
over_voltage=2
# Nastavení paměti
sdram_freq=600
sdram_schmoo=0x02000040
# Nastavení videa
hdmi_enable_4kp60=1
hdmi_pixel_freq_limit=400000000
# Nastavení USB
max_usb_current=1
dtoverlay=usb-host,usb-dr-mode=host
# Nastavení audio
dtparam=audio=on
audio_pwm_mode=2
# Nastavení I/O
dtparam=i2c_arm=on
dtparam=spi=on
dtparam=i2s=on
# Nastavení displeje
disable_overscan=1
display_hdmi_rotate=0
display_lcd_rotate=0
# Nastavení teploty
temp_limit=85
# Nastavení bootování
boot_delay=1
disable_splash=1
# Nastavení Ethernet
dtparam=eth_led0=14
dtparam=eth_led1=14
# Nastavení WiFi
dtoverlay=vc4-kms-v3d-pi4
# Nastavení GPIO
gpio=0-25=a2
gpio=26-27=a3
EOF'
    fi
    
    # Optimalizace SWAP a ZRAM
    print_status "OPTIMALIZACE" "Optimalizace SWAP a ZRAM..."
    log_message "Optimalizace SWAP a ZRAM"
    
    if [ $TOTAL_RAM_GB -lt 4 ]; then
        sudo sed -i 's/CONF_SWAPSIZE=.*/CONF_SWAPSIZE=2048/' /etc/dphys-swapfile
        
        # Povolení ZRAM
        sudo sed -i 's/ENABLED=.*/ENABLED=true/' /etc/default/zramswap
        sudo sed -i 's/PERCENT=.*/PERCENT=100/' /etc/default/zramswap
        sudo sed -i 's/PRIORITY=.*/PRIORITY=100/' /etc/default/zramswap
        sudo systemctl enable zramswap
        sudo systemctl start zramswap
    fi
    
    # Optimalizace souborového systému
    print_status "OPTIMALIZACE" "Optimalizace souborového systému..."
    log_message "Optimalizace souborového systému"
    
    # Přidání optimalizací do /etc/fstab
    if ! grep -q "noatime" /etc/fstab; then
        sudo sed -i 's/defaults/defaults,noatime,nodiratime,commit=60,errors=remount-ro/' /etc/fstab
    fi
    
    # Optimalizace sysctl parametrů
    print_status "OPTIMALIZACE" "Optimalizace síťových parametrů..."
    log_message "Optimalizace síťových parametrů"
    
    sudo bash -c 'cat >> /etc/sysctl.conf << EOF

# =============================================
# Optimalizace sítě a výkonu
# =============================================
# Obecné nastavení
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=5
vm.overcommit_memory=1
vm.overcommit_ratio=50

# Síťové nastavení
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.core.rmem_default=16777216
net.core.wmem_default=16777216
net.core.optmem_max=65536
net.core.netdev_max_backlog=30000
net.core.somaxconn=65535

# IPv4 nastavení
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
net.ipv4.tcp_max_syn_backlog=3240000
net.ipv4.tcp_max_tw_buckets=1440000
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=15
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_keepalive_time=300
net.ipv4.tcp_keepalive_probes=5
net.ipv4.tcp_keepalive_intvl=15
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_mtu_probing=1

# IPv6 nastavení
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1

# Bezpečnostní nastavení
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.all.secure_redirects=0
net.ipv4.conf.default.secure_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv4.icmp_echo_ignore_all=1
EOF'
    
    # Optimalizace diskového I/O
    print_status "OPTIMALIZACE" "Optimalizace diskového I/O..."
    log_message "Optimalizace diskového I/O"
    
    # Nastavení I/O scheduler pro SSD
    if lsblk -d -o rota | grep -q "0"; then
        echo "kyber" | sudo tee /sys/block/sda/queue/scheduler
        echo "0" | sudo tee /sys/block/sda/queue/rotational
        echo "512" | sudo tee /sys/block/sda/queue/nr_requests
    fi
    
    # Nastavení časové zóny
    sudo timedatectl set-timezone Europe/Prague
    
    # Nastavení lokalizace
    sudo raspi-config nonint do_change_locale cs_CZ.UTF-8
    sudo raspi-config nonint do_configure_keyboard cz
    
    # Automatické aktualizace bez restartu (kde je to možné)
    sudo apt-get install -y unattended-upgrades
    sudo dpkg-reconfigure -plow unattended-upgrades
    
    # Vytvoření konfigurace pro automatické aktualizace
    sudo bash -c 'cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOF
Unattended-Upgrade::Origins-Pattern {
    "origin=Debian,codename=\${distro_codename},label=Debian-Security";
    "origin=Raspbian,codename=\${distro_codename},label=Raspbian-Security";
};
Unattended-Upgrade::Package-Blacklist {
    "raspberrypi-kernel";
};
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot-WithUsers "true";
EOF'
    
    # Optimalizace služeb
    print_status "OPTIMALIZACE" "Optimalizace systémových služeb..."
    log_message "Optimalizace systémových služeb"
    
    # Zakázání nepotřebných služeb
    local disable_services=(
        "bluetooth"
        "hciuart"
        "avahi-daemon"
        "cups-browsed"
        "cups"
        "rsync"
        "rpcbind"
    )
    
    for service in "${disable_services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            sudo systemctl disable "$service" --now
            print_success "Zakázána služba: $service"
            log_message "Zakázána služba: $service"
        fi
    done
    
    # Povolení užitečných služeb
    local enable_services=(
        "zramswap"
        "fail2ban"
        "cockpit"
        "netdata"
    )
    
    for service in "${enable_services[@]}"; do
        if ! systemctl is-enabled --quiet "$service"; then
            sudo systemctl enable "$service"
            print_success "Povolena služba: $service"
            log_message "Povolena služba: $service"
        fi
    done
    
    print_success "Systém byl optimalizován"
    log_message "Systém byl optimalizován"
}

# Funkce pro konfiguraci sítě a bezpečnosti
configure_network_security() {
    print_status "SÍŤ" "Konfigurace sítě a bezpečnostních nastavení..."
    log_message "Začátek konfigurace sítě a bezpečnosti"
    
    # Povolení SSH
    sudo raspi-config nonint do_ssh 0
    
    # Nastavení firewallu
    sudo ufw --force reset
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    
    # Povolení základních portů
    sudo ufw allow ssh
    sudo ufw allow 80/tcp   # HTTP
    sudo ufw allow 443/tcp  # HTTPS
    sudo ufw allow 9090/tcp # nymea JSONRPC
    sudo ufw allow 1883/tcp # MQTT
    
    # Povolení dalších užitečných portů
    sudo ufw allow 8080/tcp # Alternativní webový port
    sudo ufw allow 3000/tcp # Node.js aplikace
    sudo ufw allow 1880/tcp # Node-RED
    sudo ufw allow 9000/tcp # Portainer
    sudo ufw allow 8123/tcp # Home Assistant
    sudo ufw allow 19999/tcp # Netdata
    sudo ufw allow 9090/tcp # Cockpit
    
    sudo ufw --force enable
    
    # Rozšířená konfigurace fail2ban
    sudo bash -c 'cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 3
destemail = root@localhost
sender = root@$(hostname -f)
action = %(action_)s

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
maxretry = 3
bantime = 24h

[sshd-ddos]
enabled = true
port = ssh
logpath = %(sshd_log)s
maxretry = 5
bantime = 1h

[nginx-http-auth]
enabled = true
port = http,https
logpath = %(nginx_error_log)s

[nginx-botsearch]
enabled = true
port = http,https
logpath = %(nginx_access_log)s
maxretry = 10
bantime = 1h

[nginx-bad-request]
enabled = true
port = http,https
logpath = %(nginx_error_log)s
maxretry = 5
bantime = 1h

[apache-auth]
enabled = false
port = http,https
logpath = %(apache_error_log)s

[recidive]
enabled = true
bantime = 7d
findtime = 1d
maxretry = 3
EOF'
    
    # Rozšířená konfigurace SSH
    sudo bash -c 'cat > /etc/ssh/sshd_config.d/10-custom.conf << EOF
# Rozšířená konfigurace SSH
Port 22
Protocol 2
HostKey /etc/ssh/ssh_host_ed25519_key
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key

# Bezpečnostní nastavení
PermitRootLogin no
MaxAuthTries 3
MaxSessions 5
ClientAliveInterval 300
ClientAliveCountMax 2

# Omezení přístupu
AllowUsers $USER
AllowGroups ssh-users

# Nastavení autentizace
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
KerberosAuthentication no
GSSAPIAuthentication no

# Nastavení připojení
X11Forwarding no
PrintMotd no
PrintLastLog yes
TCPKeepAlive yes

# Nastavení výkonu
Compression no
UseDNS no

# Omezení prostředků
MaxStartups 10:30:100
EOF'
    
    # Vytvoření skupiny pro SSH uživatele
    sudo groupadd ssh-users
    sudo usermod -aG ssh-users $USER
    
    # Restart SSH služby
    sudo systemctl restart ssh
    
    # Konfigurace bezpečnostních limitů
    sudo bash -c 'cat > /etc/security/limits.d/custom.conf << EOF
# Omezení systémových prostředků
* soft nofile 65536
* hard nofile 65536
* soft nproc 65536
* hard nproc 65536
root soft nofile 65536
root hard nofile 65536
EOF'
    
    # Konfigurace sudoers
    sudo bash -c 'cat > /etc/sudoers.d/10-custom << EOF
# Bezpečnostní nastavení sudo
Defaults        env_reset
Defaults        mail_badpass
Defaults        secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Defaults        use_pty
Defaults        logfile=/var/log/sudo.log
Defaults        log_input, log_output
EOF'
    
    # Instalace a konfigurace ClamAV
    sudo freshclam
    sudo systemctl enable clamav-freshclam
    sudo systemctl start clamav-freshclam
    
    # Pravidelná kontrola malwaru
    (crontab -l 2>/dev/null; echo "0 3 * * 0 sudo clamscan -r / --exclude-dir=/sys/ --exclude-dir=/proc/ --exclude-dir=/dev/ --quiet --infected | mail -s \"ClamAV Scan Report\" root") | crontab -
    
    # Konfigurace AppArmor
    sudo apt-get install -y apparmor apparmor-utils
    sudo aa-enforce /etc/apparmor.d/*
    
    print_success "Síť a bezpečnost nakonfigurovány"
    log_message "Síť a bezpečnost nakonfigurovány"
}

# Funkce pro instalaci monitorovacích nástrojů
install_monitoring_tools() {
    print_status "MONITORING" "Instalace monitorovacích nástrojů..."
    log_message "Začátek instalace monitorovacích nástrojů"
    
    # Instalace Netdata s rozšířenými funkcemi
    if ! command -v netdata &> /dev/null; then
        print_status "MONITORING" "Instalace Netdata..."
        log_message "Instalace Netdata"
        bash <(curl -Ss https://my-netdata.io/kickstart.sh) --dont-wait --stable-channel --disable-telemetry
        
        # Konfigurace Netdata
        sudo bash -c 'cat > /etc/netdata/netdata.conf << EOF
[global]
    memory mode = ram
    history = 86400
    update every = 2
    web files owner = root
    web files group = root
    bind to = *
    
[web]
    mode = none
    bind to = *
    
[plugins]
    tc = no
    idlejitter = no
    cgroups = yes
    checks = no
    
[health]
    enabled = yes
    silent during low memory = yes
    
[cloud]
    enabled = no
    
[ml]
    enabled = yes
EOF'
    fi
    
    # Instalace Prometheus a exporters
    print_status "MONITORING" "Instalace Prometheus a exporters..."
    log_message "Instalace Prometheus a exporters"
    
    # Vytvoření uživatele pro Prometheus
    sudo useradd --no-create-home --shell /bin/false prometheus
    sudo useradd --no-create-home --shell /bin/false node_exporter
    
    # Stažení a instalace Node Exporter
    NODE_EXPORTER_VERSION="1.3.1"
    wget "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-arm64.tar.gz"
    tar xvf "node_exporter-${NODE_EXPORTER_VERSION}.linux-arm64.tar.gz"
    sudo mv "node_exporter-${NODE_EXPORTER_VERSION}.linux-arm64/node_exporter" /usr/local/bin/
    sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter
    rm -rf "node_exporter-${NODE_EXPORTER_VERSION}.linux-arm64"*
    
    # Vytvoření služby pro Node Exporter
    sudo bash -c 'cat > /etc/systemd/system/node_exporter.service << EOF
[Unit]
Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter \
    --collector.cpu \
    --collector.diskstats \
    --collector.filesystem \
    --collector.loadavg \
    --collector.meminfo \
    --collector.netdev \
    --collector.netstat \
    --collector.stat \
    --collector.time \
    --collector.vmstat \
    --collector.systemd \
    --collector.tcpstat \
    --collector.arp \
    --web.listen-address=:9100

[Install]
WantedBy=multi-user.target
EOF'
    
    sudo systemctl daemon-reload
    sudo systemctl enable node_exporter
    sudo systemctl start node_exporter
    
    # Instalace Process Exporter
    PROCESS_EXPORTER_VERSION="0.7.10"
    wget "https://github.com/ncabatoff/process-exporter/releases/download/v${PROCESS_EXPORTER_VERSION}/process-exporter-${PROCESS_EXPORTER_VERSION}.linux-arm64.tar.gz"
    tar xvf "process-exporter-${PROCESS_EXPORTER_VERSION}.linux-arm64.tar.gz"
    sudo mv "process-exporter-${PROCESS_EXPORTER_VERSION}.linux-arm64/process-exporter" /usr/local/bin/
    rm -rf "process-exporter-${PROCESS_EXPORTER_VERSION}.linux-arm64"*
    
    sudo bash -c 'cat > /etc/process-exporter.yaml << EOF
process_names:
  - name: "{{.Comm}}"
    cmdline:
    - '.+'
EOF'
    
    sudo bash -c 'cat > /etc/systemd/system/process_exporter.service << EOF
[Unit]
Description=Process Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=root
Group=root
Type=simple
ExecStart=/usr/local/bin/process-exporter -config.path /etc/process-exporter.yaml -web.listen-address :9256

[Install]
WantedBy=multi-user.target
EOF'
    
    sudo systemctl daemon-reload
    sudo systemctl enable process_exporter
    sudo systemctl start process_exporter
    
    # Vytvoření vlastního monitorovacího dashboardu
    print_status "MONITORING" "Vytváření vlastního monitorovacího dashboardu..."
    log_message "Vytváření vlastního monitorovacího dashboardu"
    
    sudo mkdir -p /opt/monitoring
    sudo bash -c 'cat > /opt/monitoring/dashboard.sh << EOF
#!/bin/bash
# Vlastní monitorovací dashboard

echo "=============================================="
echo "          Monitoring Dashboard"
echo "=============================================="
echo "Datum: $(date)"
echo "Systém: $(hostname)"
echo "IP: $(hostname -I | awk '\''{print $1}'\'')"
echo "----------------------------------------------"

# CPU
CPU_TEMP=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '\''{printf "%.1f°C", $1/1000}'\'' || echo "N/A")
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '\''{printf "%.1f%%", 100 - $1}'\'')
echo "CPU: Teplota=$CPU_TEMP, Využití=$CPU_USAGE"

# Paměť
MEM_TOTAL=$(free -h | awk '\''/Mem:/ {print $2}'\'')
MEM_USED=$(free -h | awk '\''/Mem:/ {print $3}'\'')
MEM_PERCENT=$(free | awk '\''/Mem:/ {printf "%.1f%%", $3/$2 * 100}'\'')
echo "RAM: Celkem=$MEM_TOTAL, Využito=$MEM_USED ($MEM_PERCENT)"

# Disk
DISK_TOTAL=$(df -h / | awk '\''NR==2 {print $2}'\'')
DISK_USED=$(df -h / | awk '\''NR==2 {print $3}'\'')
DISK_PERCENT=$(df -h / | awk '\''NR==2 {print $5}'\'')
echo "Disk: Celkem=$DISK_TOTAL, Využito=$DISK_USED ($DISK_PERCENT)"

# Síť
NET_RX=$(ip -s link show eth0 2>/dev/null | awk '\''/RX:/ {getline; print $1 " " $2}'\'' || echo "N/A")
NET_TX=$(ip -s link show eth0 2>/dev/null | awk '\''/TX:/ {getline; print $1 " " $2}'\'' || echo "N/A")
echo "Síť: RX=$NET_RX, TX=$NET_TX"

# Služby
echo "Služby:"
echo "  - SSH: $(systemctl is-active ssh)"
echo "  - Docker: $(systemctl is-active docker)"
echo "  - Netdata: $(systemctl is-active netdata)"
echo "  - Node Exporter: $(systemctl is-active node_exporter)"
echo "  - Nymea: $(systemctl is-active nymea)"

# Uptime
echo "Běží: $(uptime -p)"
echo "=============================================="
EOF'
    
    sudo chmod +x /opt/monitoring/dashboard.sh
    
    # Přidání cron úlohy pro pravidelný monitoring
    (crontab -l 2>/dev/null; echo "*/5 * * * * /opt/monitoring/dashboard.sh >> /var/log/system-dashboard.log") | crontab -
    
    print_success "Monitorovací nástroje nainstalovány"
    log_message "Monitorovací nástroje nainstalovány"
}

# Funkce pro instalaci kontejnerizovaných aplikací
install_containerized_apps() {
    print_status "KONTEJNERY" "Instalace kontejnerizovaných aplikací..."
    log_message "Začátek instalace kontejnerizovaných aplikací"
    
    # Vytvoření adresáře pro Docker compose projekty
    mkdir -p ~/docker/{home-assistant,node-red,portainer,zigbee2mqtt,grafana,prometheus,nginx,postgres,redis,mosquitto,wordpress,nextcloud}
    
    # Home Assistant s rozšířenou konfigurací
    cat > ~/docker/home-assistant/docker-compose.yml << EOF
version: '3.8'
services:
  homeassistant:
    container_name: homeassistant
    image: "ghcr.io/home-assistant/home-assistant:stable"
    volumes:
      - ./config:/config
      - /etc/localtime:/etc/localtime:ro
      - /etc/timezone:/etc/timezone:ro
      - /var/run/dbus:/var/run/dbus:ro
      - /var/run/avahi-daemon/socket:/var/run/avahi-daemon/socket:ro
    ports:
      - "8123:8123"
    restart: unless-stopped
    privileged: true
    network_mode: host
    environment:
      - TZ=Europe/Prague
      - PUID=1000
      - PGID=1000
    devices:
      - /dev/ttyACM0:/dev/ttyACM0
      - /dev/ttyUSB0:/dev/ttyUSB0
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8123"]
      interval: 30s
      timeout: 10s
      retries: 3

  # MariaDB pro Home Assistant
  mariadb:
    image: mariadb:10.11
    container_name: mariadb
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: \${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: homeassistant
      MYSQL_USER: homeassistant
      MYSQL_PASSWORD: \${MYSQL_PASSWORD}
    volumes:
      - ./mariadb:/var/lib/mysql
    ports:
      - "3306:3306"
EOF
    
    # Node-RED s rozšířenou konfigurací
    cat > ~/docker/node-red/docker-compose.yml << EOF
version: '3.8'
services:
  node-red:
    image: nodered/node-red:latest
    container_name: node-red
    environment:
      - TZ=Europe/Prague
      - NODE_RED_ENABLE_SAFE_MODE=true
      - NODE_RED_ENABLE_PROJECTS=true
    ports:
      - "1880:1880"
    volumes:
      - ./data:/data
      - ./flows:/flows
      - ./settings.js:/data/settings.js
    restart: unless-stopped
    user: "1000:1000"
    networks:
      - node-red-net

  # Node-RED Dashboard
  node-red-dashboard:
    image: node-red-dashboard:latest
    container_name: node-red-dashboard
    restart: unless-stopped
    depends_on:
      - node-red
    networks:
      - node-red-net

networks:
  node-red-net:
    driver: bridge
EOF
    
    # Portainer Business Edition
    cat > ~/docker/portainer/docker-compose.yml << EOF
version: '3.8'
services:
  portainer:
    image: portainer/portainer-ee:latest
    container_name: portainer
    restart: unless-stopped
    ports:
      - "9000:9000"
      - "9443:9443"
      - "8000:8000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./data:/data
      - ./certs:/certs
    environment:
      - PORTAINER_SSL=true
      - PORTAINER_HTTP_DISABLE=true
    command: -H unix:///var/run/docker.sock --admin-password=\$