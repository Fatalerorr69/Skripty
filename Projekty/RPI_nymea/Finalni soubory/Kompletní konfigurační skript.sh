#!/bin/bash

# Kompletní konfigurační skript pro Raspberry Pi 5
# Autor: AI asistovaný
# Datum: 2025-09-12
# Verze: 4.0

set -e  # Skript zastaví při chybě

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

# Funkce pro detekci Raspberry Pi modelu a parametrů
detect_rpi_info() {
    print_status "INFO" "Detekce hardwarových parametrů..."
    
    # Detekce modelu Raspberry Pi
    if [ -f /proc/device-tree/model ]; then
        RPI_MODEL=$(tr -d '\0' < /proc/device-tree/model)
        print_status "INFO" "Detekovaný hardware: $RPI_MODEL"
    else
        print_warning "Nelze detekovat model hardware"
        RPI_MODEL="Unknown"
    fi
    
    # Detekce množství RAM
    TOTAL_RAM=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    TOTAL_RAM_GB=$((TOTAL_RAM / 1024 / 1024))
    print_status "INFO" "Detekovaná RAM: ${TOTAL_RAM_GB}GB"
    
    # Detekce teploty CPU (pokud je dostupná)
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        CPU_TEMP=$(($(cat /sys/class/thermal/thermal_zone0/temp) / 1000))
        print_status "INFO" "Aktuální teplota CPU: ${CPU_TEMP}°C"
    fi
    
    # Nastavení GPU paměti podle dostupné RAM
    if [ $TOTAL_RAM_GB -ge 4 ]; then
        GPU_MEM=256
    else
        GPU_MEM=128
    fi
    print_status "INFO" "Nastavena GPU paměť: ${GPU_MEM}MB"
    
    # Detekce aktuálního hostname
    CURRENT_HOSTNAME=$(hostname)
    print_status "INFO" "Aktuální hostname: $CURRENT_HOSTNAME"
    
    # Detekce úložného prostoru
    DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}')
    print_status "INFO" "Využití disku: $DISK_USAGE"
}

# Funkce pro kontrolu připojení k internetu
check_internet_connection() {
    print_status "KONTROLA" "Kontrola připojení k internetu..."
    if ping -q -c 3 -W 1 8.8.8.8 >/dev/null 2>&1; then
        print_success "Připojení k internetu je funkční"
        return 0
    else
        print_error "Chyba připojení k internetu"
        return 1
    fi
}

# Funkce pro instalaci nástrojů a utilit
install_tools() {
    print_status "INSTALACE" "Instalace systémových nástrojů a utilit..."
    
    # Základní nástroje
    sudo apt-get install -y \
        vim git tmux curl wget htop \
        build-essential python3-dev python3-pip python3-venv \
        openssh-server ufw fail2ban logrotate \
        screen unzip p7zip-full rsync \
        lm-sensors sysstat iotop iftop nethogs \
        ntpdate usbutils pciutils lshw \
        jq bc stress apt-transport-https \
        ca-certificates gnupg-agent software-properties-common \
        zram-tools rpi-eeprom smartmontools \
        libimage-exiftool-perl ffmpeg \
        tree ncdu dos2unix xmlstarlet \
        net-tools traceroute dnsutils
    
    # Instalace Docker (pokud není nainstalován)
    if ! command -v docker &> /dev/null; then
        print_status "INSTALACE" "Instalace Dockeru..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        rm get-docker.sh
    fi
    
    # Instalace Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        print_status "INSTALACE" "Instalace Docker Compose..."
        sudo pip3 install docker-compose
    fi
    
    # Instalace dalších užitečných nástrojů
    print_status "INSTALACE" "Instalace dalších užitečných nástrojů..."
    sudo pip3 install \
        speedtest-cli \
        platformio \
        RPi.GPIO \
        adafruit-blinka \
        adafruit-circuitpython-bme280 \
        requests \
        pillow \
        pandas \
        numpy \
        flask \
        fastapi \
        uvloop
    
    # Instalace Node.js a npm
    if ! command -v node &> /dev/null; then
        print_status "INSTALACE" "Instalace Node.js..."
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi
    
    # Instalace dalších globalních npm balíčků
    sudo npm install -g \
        npm@latest \
        node-red \
        homebridge \
        express-generator \
        typescript \
        nodemon \
        pm2
    
    print_success "Nástroje a utility byly nainstalovány"
}

# Funkce pro konfiguraci nymea a pluginů
configure_nymea() {
    print_status "NYMEA" "Konfigurace nymea a instalace pluginů..."
    
    # Kontrola, zda je nymea nainstalováno
    if ! command -v nymead &> /dev/null; then
        print_warning "nymea není nainstalováno, pokus o instalaci..."
        
        # Přidání repositáře nymea
        wget -O - https://nymea.io/repository/gpg.key | sudo apt-key add -
        echo "deb https://nymea.io/repository/debian/ stable main" | sudo tee /etc/apt/sources.list.d/nymea.list
        
        # Aktualizace a instalace nymea
        sudo apt-get update
        sudo apt-get install -y nymea nymea-plugins nymea-app
    fi
    
    # Instalace doporučených pluginů
    print_status "NYMEA" "Instalace doporučených pluginů..."
    
    # Seznam doporučených pluginů
    NYMEA_PLUGINS="
        nymea-plugin-zigbee
        nymea-plugin-modbus
        nymea-plugin-mqttclient
        nymea-plugin-kodi
        nymea-plugin-toniebox
        nymea-plugin-networkdetector
        nymea-plugin-wemo
        nymea-plugin-yeelight
        nymea-plugin-tasmota
        nymea-plugin-tradfri
        nymea-plugin-shelly
        nymea-plugin-sonos
        nymea-plugin-hue
        nymea-plugin-avahi
        nymea-plugin-bluetooth
    "
    
    for plugin in $NYMEA_PLUGINS; do
        if apt-cache show $plugin &> /dev/null; then
            sudo apt-get install -y $plugin
            print_success "Nainstalován plugin: $plugin"
        else
            print_warning "Plugin $plugin není dostupný"
        fi
    done
    
    # Nastavení nymea jako služby
    sudo systemctl enable nymea
    sudo systemctl start nymea
    
    # Vytvoření základní konfigurace
    if [ ! -f /etc/nymea/nymea.conf ]; then
        print_status "NYMEA" "Vytváření základní konfigurace..."
        sudo mkdir -p /etc/nymea
        sudo bash -c 'cat > /etc/nymea/nymea.conf << EOF
[General]
Name=My Raspberry Pi Smart Home
Timezone=Europe/Prague

[MQTT]
Enabled=true
Port=1883

[Cloud]
Enabled=false

[JSONRPC]
Enabled=true
Port=9090

[Zigbee]
Enabled=true

[Bluetooth]
Enabled=true
EOF'
    fi
    
    print_success "Nymea bylo nakonfigurováno"
}

# Funkce pro optimalizaci systému
optimize_system() {
    print_status "OPTIMALIZACE" "Optimalizace systému pro Raspberry Pi 5..."
    
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
        
        # Optimalizace pro RPi 5
        sudo bash -c 'cat >> /boot/config.txt << EOF

# Optimalizace pro Raspberry Pi 5
[pi5]
# Zvýšení výkonu GPU
gpu_mem=${GPU_MEM}
# Lepší správa napájení
over_voltage=1
# Vyšší taktování (pokud chlazení dovolí)
arm_freq=2000
# Lepší výkon pro video
gpu_freq=600
# Zvýšení maximálního proudu pro USB
max_usb_current=1
# Lepší výkon pro USB
dtoverlay=usb-host,usb-dr-mode=host
# Lepší podpora audio
dtparam=audio=on
# Podpora pro HAT
dtparam=i2c_arm=on
dtparam=spi=on
dtparam=i2s=on
EOF'
    fi
    
    # Optimalizace SWAP a ZRAM
    if [ $TOTAL_RAM_GB -lt 2 ]; then
        print_status "OPTIMALIZACE" "Optimalizace SWAP a ZRAM pro systémy s malou pamětí..."
        sudo sed -i 's/CONF_SWAPSIZE=.*/CONF_SWAPSIZE=1024/' /etc/dphys-swapfile
        
        # Povolení ZRAM
        sudo sed -i 's/ENABLED=.*/ENABLED=true/' /etc/default/zramswap
        sudo systemctl enable zramswap
        sudo systemctl start zramswap
    fi
    
    # Optimalizace souborového systému
    print_status "OPTIMALIZACE" "Optimalizace souborového systému..."
    
    # Přidání optimalizací do /etc/fstab
    if ! grep -q "noatime" /etc/fstab; then
        sudo sed -i 's/defaults/defaults,noatime,nodiratime/' /etc/fstab
    fi
    
    # Optimalizace sysctl parametrů
    sudo bash -c 'cat >> /etc/sysctl.conf << EOF

# Optimalizace sítě a výkonu
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_fastopen=3
vm.swappiness=10
vm.vfs_cache_pressure=50
EOF'
    
    # Nastavení časové zóny
    sudo timedatectl set-timezone Europe/Prague
    
    # Nastavení lokalizace
    sudo raspi-config nonint do_change_locale cs_CZ.UTF-8
    sudo raspi-config nonint do_configure_keyboard cz
    
    # Automatické aktualizace bez restartu (kde je to možné)
    sudo apt-get install -y unattended-upgrades
    sudo dpkg-reconfigure -plow unattended-upgrades
    
    print_success "Systém byl optimalizován"
}

# Funkce pro konfiguraci sítě a bezpečnosti
configure_network_security() {
    print_status "SÍŤ" "Konfigurace sítě a bezpečnostních nastavení..."
    
    # Povolení SSH
    sudo raspi-config nonint do_ssh 0
    
    # Nastavení firewallu
    sudo ufw allow ssh
    sudo ufw allow 80/tcp   # HTTP
    sudo ufw allow 443/tcp  # HTTPS
    sudo ufw allow 9090/tcp # nymea JSONRPC
    sudo ufw allow 1883/tcp # MQTT
    sudo ufw allow 8080/tcp # Alternativní webový port
    sudo ufw allow 3000/tcp # Node.js aplikace
    sudo ufw allow 1880/tcp # Node-RED
    sudo ufw --force enable
    
    # Instalace a konfigurace fail2ban
    sudo apt-get install -y fail2ban
    sudo systemctl enable fail2ban
    sudo systemctl start fail2ban
    
    # Konfigurace fail2ban pro vyšší zabezpečení
    sudo bash -c 'cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
mode = aggressive
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s

[sshd-ddos]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s

[nginx-http-auth]
enabled = true
EOF'
    
    # Zakázání root přihlášení přes SSH (doporučeno)
    sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    
    # Povolení SSH klíčů a zakázání hesla (doporučeno)
    sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    sudo sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    
    # Restart SSH služby
    sudo systemctl restart ssh
    
    # Nastavení statické IP (pokud je potřeba)
    read -p "Chcete nastavit statickou IP adresu? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        set_static_ip
    fi
    
    print_success "Síť a bezpečnost nakonfigurovány"
}

# Funkce pro nastavení statické IP
set_static_ip() {
    print_status "SÍŤ" "Nastavení statické IP adresy..."
    
    # Získání síťových informací
    DEFAULT_INTERFACE=$(ip route | grep default | awk '{print $5}')
    CURRENT_IP=$(ip -4 addr show $DEFAULT_INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    GATEWAY=$(ip route | grep default | awk '{print $3}')
    DNS_SERVERS="8.8.8.8 1.1.1.1"
    
    # Výpis aktuálních nastavení
    echo "Aktuální nastavení:"
    echo "Rozhraní: $DEFAULT_INTERFACE"
    echo "IP adresa: $CURRENT_IP"
    echo "Brána: $GATEWAY"
    
    # Zadání nové statické IP
    read -p "Zadejte novou statickou IP adresu: " STATIC_IP
    read -p "Zadejte masku sítě (např. 24): " NETMASK
    
    # Vytvoření konfigurace pro dhcpcd
    STATIC_IP_CONFIG="
interface $DEFAULT_INTERFACE
static ip_address=$STATIC_IP/$NETMASK
static routers=$GATEWAY
static domain_name_servers=$DNS_SERVERS
"
    
    # Přidání konfigurace do dhcpcd.conf
    echo "$STATIC_IP_CONFIG" | sudo tee -a /etc/dhcpcd.conf
    
    print_success "Statická IP $STATIC_IP nastavena na rozhraní $DEFAULT_INTERFACE"
}

# Funkce pro instalaci monitorovacích nástrojů
install_monitoring_tools() {
    print_status "MONITORING" "Instalace monitorovacích nástrojů..."
    
    # Instalace Netdata pro monitoring
    if ! command -v netdata &> /dev/null; then
        print_status "MONITORING" "Instalace Netdata..."
        bash <(curl -Ss https://my-netdata.io/kickstart.sh) --dont-wait --stable-channel
    fi
    
    # Instalace Cockpit pro webové řízení
    if ! dpkg -l | grep -q cockpit; then
        print_status "MONITORING" "Instalace Cockpitu..."
        sudo apt-get install -y cockpit cockpit-packagekit
        sudo systemctl enable cockpit
        sudo systemctl start cockpit
    fi
    
    # Instalace Prometheus Node Exporter
    if ! systemctl is-active --quiet prometheus-node-exporter; then
        print_status "MONITORING" "Instalace Prometheus Node Exporter..."
        sudo useradd -rs /bin/false prometheus-node-exporter
        wget https://github.com/prometheus/node_exporter/releases/download/v1.3.1/node_exporter-1.3.1.linux-arm64.tar.gz
        tar xvf node_exporter-1.3.1.linux-arm64.tar.gz
        sudo mv node_exporter-1.3.1.linux-arm64/node_exporter /usr/local/bin/
        sudo chown prometheus-node-exporter:prometheus-node-exporter /usr/local/bin/node_exporter
        rm -rf node_exporter-1.3.1.linux-arm64*
        
        # Vytvoření služby pro Node Exporter
        sudo bash -c 'cat > /etc/systemd/system/prometheus-node-exporter.service << EOF
[Unit]
Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus-node-exporter
Group=prometheus-node-exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF'
        
        sudo systemctl daemon-reload
        sudo systemctl enable prometheus-node-exporter
        sudo systemctl start prometheus-node-exporter
    fi
    
    # Vytvoření vlastního monitorovacího skriptu
    print_status "MONITORING" "Vytváření vlastního monitorovacího skriptu..."
    
    sudo bash -c 'cat > /usr/local/bin/system-monitor << EOF
#!/bin/bash
echo "=== System Monitor ==="
echo "Datum: $(date)"
echo "Teplota CPU: $(($(cat /sys/class/thermal/thermal_zone0/temp) / 1000))°C"
echo "Využití CPU: $(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '\''{print 100 - $1}'\'')%"
echo "Využití RAM: $(free -m | awk '\''NR==2{printf "%.2f%%", $3*100/$2 }'\'')"
echo "Využití disku: $(df -h / | awk '\''NR==2{print $5}'\'')"
echo "Běží déle: $(uptime -p)"
EOF'
    
    sudo chmod +x /usr/local/bin/system-monitor
    
    # Přidání cron úlohy pro pravidelný monitoring
    (crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/system-monitor >> /var/log/system-monitor.log") | crontab -
    
    print_success "Monitorovací nástroje nainstalovány"
}

# Funkce pro instalaci kontejnerizovaných aplikací
install_containerized_apps() {
    print_status "KONTEJNERY" "Instalace kontejnerizovaných aplikací..."
    
    # Vytvoření adresáře pro Docker compose projekty
    mkdir -p ~/docker/{home-assistant,node-red,portainer,zigbee2mqtt,grafana,prometheus}
    
    # Home Assistant
    cat > ~/docker/home-assistant/docker-compose.yml << EOF
version: '3'
services:
  homeassistant:
    container_name: homeassistant
    image: "ghcr.io/home-assistant/home-assistant:stable"
    volumes:
      - ./config:/config
      - /etc/localtime:/etc/localtime:ro
      - /etc/timezone:/etc/timezone:ro
    ports:
      - "8123:8123"
    restart: unless-stopped
    privileged: true
    network_mode: host
    environment:
      - TZ=Europe/Prague
EOF
    
    # Node-RED
    cat > ~/docker/node-red/docker-compose.yml << EOF
version: '3'
services:
  node-red:
    image: nodered/node-red:latest
    container_name: node-red
    environment:
      - TZ=Europe/Prague
    ports:
      - "1880:1880"
    volumes:
      - ./data:/data
    restart: unless-stopped
EOF
    
    # Portainer
    cat > ~/docker/portainer/docker-compose.yml << EOF
version: '3'
services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    ports:
      - "9000:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./data:/data
EOF
    
    # Spuštění kontejnerů
    docker-compose -f ~/docker/portainer/docker-compose.yml up -d
    
    print_success "Kontejnerizované aplikace nainstalovány"
}

# Funkce pro vytvoření zálohovacího skriptu
create_backup_script() {
    print_status "ZÁLOHA" "Vytváření zálohovacího skriptu..."
    
    sudo bash -c 'cat > /usr/local/bin/backup-system << EOF
#!/bin/bash
# Zálohovací skript pro Raspberry Pi
BACKUP_DIR="/home/\$USER/backups"
TIMESTAMP=\$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="rpi-backup-\$TIMESTAMP.tar.gz"

echo "Vytváření zálohy systému..."
mkdir -p \$BACKUP_DIR

# Záloha důležitých souborů
tar -czf \$BACKUP_DIR/\$BACKUP_FILE \\
    /etc \\
    /home \\
    /var/lib \\
    /usr/local/bin 2>/dev/null

# Záloha seznamu balíčků
dpkg --get-selections > \$BACKUP_DIR/pkg-list-\$TIMESTAMP.txt

echo "Záloha vytvořena: \$BACKUP_DIR/\$BACKUP_FILE"
echo "Seznam balíčků: \$BACKUP_DIR/pkg-list-\$TIMESTAMP.txt"
EOF'
    
    sudo chmod +x /usr/local/bin/backup-system
    
    # Přidání cron úlohy pro týdenní zálohování
    (crontab -l 2>/dev/null; echo "0 2 * * 0 /usr/local/bin/backup-system") | crontab -
    
    print_success "Zálohovací skript vytvořen"
}

# Hlavní funkce
main() {
    echo "================================================================"
    echo "    Kompletní automatická konfigurace Raspberry Pi 5"
    echo "================================================================"
    
    # Kontrola oprávnění
    if [ "$EUID" -eq 0 ]; then
        print_error "Skript nesmí být spuštěn jako root/spuštěn s sudo"
        exit 1
    fi
    
    # Detekce parametrů
    detect_rpi_info
    
    # Kontrola internetového připojení
    check_internet_connection || {
        print_error "Chybí internetové připojení, které je vyžadováno"
        exit 1
    }
    
    # Aktualizace systému
    print_status "SYSTÉM" "Aktualizace systému..."
    sudo apt-get update
    sudo apt-get upgrade -y
    
    # Instalace nástrojů
    install_tools
    
    # Konfigurace nymea
    configure_nymea
    
    # Optimalizace systému
    optimize_system
    
    # Konfigurace sítě a bezpečnosti
    configure_network_security
    
    # Instalace monitorovacích nástrojů
    install_monitoring_tools
    
    # Instalace kontejnerizovaných aplikací
    install_containerized_apps
    
    # Vytvoření zálohovacího skriptu
    create_backup_script
    
    # Závěrečné úpravy
    print_status "DOKONČENÍ" "Provádění závěrečných úprav..."
    
    # Přidání uživatele do potřebných skupin
    sudo usermod -a -G gpio,i2c,spi,docker,audio,video $USER
    
    # Čištění
    sudo apt-get autoremove -y
    sudo apt-get autoclean -y
    
    # Vytvoření informačního souboru
    sudo bash -c "cat > /etc/rpi5-config-info.txt << EOF
Raspberry Pi 5 Konfigurace
---------------------------
Datum: $(date)
Model: $RPI_MODEL
Paměť: ${TOTAL_RAM_GB}GB
GPU paměť: ${GPU_MEM}MB

Nainstalované služby:
- nymea: $(systemctl is-active nymea)
- Docker: $(command -v docker >/dev/null && echo 'Ano' || echo 'Ne')
- Netdata: $(command -v netdata >/dev/null && echo 'Ano' || echo 'Ne')
- Cockpit: $(systemctl is-active cockpit >/dev/null && echo 'Ano' || echo 'Ne')
- Node Exporter: $(systemctl is-active prometheus-node-exporter >/dev/null && echo 'Ano' || echo 'Ne')

Důležité porty:
- SSH: 22
- HTTP: 80
- HTTPS: 443
- nymea JSONRPC: 9090
- MQTT: 1883
- Netdata: 19999
- Cockpit: 9090
- Home Assistant: 8123
- Node-RED: 1880
- Portainer: 9000

Příkazy:
- System monitoring: system-monitor
- Zálohování: backup-system
- Stav služeb: systemctl status nymea

Pro přístup k nymea webovému rozhraní: http://$(hostname -I | awk '{print $1}'):9090
EOF"
    
    echo "================================================================"
    print_success "Konfigurace úspěšně dokončena!"
    echo " "
    echo "Důležité informace:"
    echo "- Systém se doporučuje restartovat: sudo reboot"
    echo "- Přehled konfigurace je uložen v: /etc/rpi5-config-info.txt"
    echo "- nymea je dostupné na: http://$(hostname -I | awk '{print $1}'):9090"
    echo "- Netdata monitoring: http://$(hostname -I | awk '{print $1}'):19999"
    echo "- Cockpit: https://$(hostname -I | awk '{print $1}'):9090"
    echo "- Home Assistant: http://$(hostname -I | awk '{print $1}'):8123"
    echo "- Node-RED: http://$(hostname -I | awk '{print $1}'):1880"
    echo "- Portainer: http://$(hostname -I | awk '{print $1}'):9000"
    echo " "
    echo "Po restartu se ujistěte, že:"
    echo "1. Všechny služby běží správně: systemctl status nymea"
    echo "2. Firewall je aktivní: sudo ufw status"
    echo "3. Aktualizujte nymea pluginy podle potřeby"
    echo "================================================================"
}

# Spuštění hlavní funkce
main "$@"