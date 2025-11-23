#!/bin/bash

# Rozšířený skript pro automatickou konfiguraci Raspberry Pi 5
# Autor: AI asistovaný
# Datum: 2025-09-12
# Verze: 2.0

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
        lm-sensors sysstat iotop iftop \
        ntpdate usbutils pciutils lshw \
        jq bc stress apt-transport-https \
        ca-certificates gnupg-agent software-properties-common
    
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
        adafruit-circuitpython-bme280
    
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
EOF'
    fi
    
    # Optimalizace SWAP
    if [ $TOTAL_RAM_GB -lt 2 ]; then
        print_status "OPTIMALIZACE" "Optimalizace SWAP pro systémy s malou pamětí..."
        sudo sed -i 's/CONF_SWAPSIZE=.*/CONF_SWAPSIZE=1024/' /etc/dphys-swapfile
    fi
    
    # Optimalizace souborového systému
    print_status "OPTIMALIZACE" "Optimalizace souborového systému..."
    
    # Přidání optimalizací do /etc/fstab
    if ! grep -q "noatime" /etc/fstab; then
        sudo sed -i 's/defaults/defaults,noatime,nodiratime/' /etc/fstab
    fi
    
    # Nastavení časové zóny
    sudo timedatectl set-timezone Europe/Prague
    
    # Nastavení lokalizace
    sudo raspi-config nonint do_change_locale cs_CZ.UTF-8
    sudo raspi-config nonint do_configure_keyboard cz
    
    print_success "Systém byl optimalizován"
}

# Funkce pro konfiguraci sítě a bezpečnosti
configure_network_security() {
    print_status "SÍŤ" "Konfigurace sítě a bezpečnostních nastavení..."
    
    # Povolení SSH
    sudo raspi-config nonint do_ssh 0
    
    # Povolení VNC (volitelné)
    # sudo raspi-config nonint do_vnc 0
    
    # Nastavení firewallu
    sudo ufw allow ssh
    sudo ufw allow 80/tcp   # HTTP
    sudo ufw allow 443/tcp  # HTTPS
    sudo ufw allow 9090/tcp # nymea JSONRPC
    sudo ufw allow 1883/tcp # MQTT
    sudo ufw --force enable
    
    # Instalace a konfigurace fail2ban
    sudo apt-get install -y fail2ban
    sudo systemctl enable fail2ban
    sudo systemctl start fail2ban
    
    # Změna výchozího SSH portu (volitelné)
    # sudo sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config
    
    # Zakázání root přihlášení přes SSH (doporučeno)
    sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    
    # Restart SSH služby
    sudo systemctl restart ssh
    
    print_success "Síť a bezpečnost nakonfigurovány"
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
    
    print_success "Monitorovací nástroje nainstalovány"
}

# Hlavní funkce
main() {
    echo "================================================================"
    echo "    Rozšířená automatická konfigurace Raspberry Pi 5"
    echo "================================================================"
    
    # Kontrola oprávnění
    if [ "$EUID" -eq 0 ]; then
        print_error "Skript nesmí být spuštěn jako root/spuštěn s sudo"
        exit 1
    fi
    
    # Detekce parametrů
    detect_rpi_info
    
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
    
    # Závěrečné úpravy
    print_status "DOKONČENÍ" "Provádění závěrečných úprav..."
    
    # Přidání uživatele do potřebných skupin
    sudo usermod -a -G gpio,i2c,spi,docker $USER
    
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

Důležité porty:
- SSH: 22
- HTTP: 80
- HTTPS: 443
- nymea JSONRPC: 9090
- MQTT: 1883
- Netdata: 19999
- Cockpit: 9090

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
    echo " "
    echo "Po restartu se ujistěte, že:"
    echo "1. Všechny služby běží správně: systemctl status nymea"
    echo "2. Firewall je aktivní: sudo ufw status"
    echo "3. Aktualizujte nymea pluginy podle potřeby"
    echo "================================================================"
}

# Spuštění hlavní funkce
main "$@"