#!/bin/bash

# Skript pro nastavení síťového připojení a následnou konfiguraci Raspberry Pi 5
set -e

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

# Funkce pro kontrolu internetového připojení
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

# Funkce pro nastavení WiFi
setup_wifi() {
    print_status "NASTAVENÍ" "Nastavení WiFi připojení..."
    
    # Kontrola existence WiFi rozhraní
    if ! iwconfig 2>&1 | grep -q "wlan0"; then
        print_error "Nenalezeno WiFi rozhraní wlan0"
        return 1
    fi
    
    # Získání SSID a hesla
    read -p "Zadejte SSID WiFi sítě: " WIFI_SSID
    read -s -p "Zadejte heslo pro WiFi síť: " WIFI_PASSWORD
    echo
    
    # Přidání konfigurace do wpa_supplicant
    sudo bash -c 'cat >> /etc/wpa_supplicant/wpa_supplicant.conf << EOF
network={
    ssid="'$WIFI_SSID'"
    psk="'$WIFI_PASSWORD'"
}
EOF'
    
    # Restart síťových služeb
    sudo wpa_cli -i wlan0 reconfigure
    sudo systemctl restart dhcpcd
    
    # Čekání na připojení
    print_status "ČEKÁNÍ" "Čekám na připojení k WiFi..."
    sleep 15
}

# Funkce pro manuální konfiguraci sítě
manual_network_setup() {
    print_status "NASTAVENÍ" "Manuální konfigurace sítě..."
    
    # Zobrazení dostupných rozhraní
    echo "Dostupná síťová rozhraní:"
    ip link show | grep -E "^[0-9]+:" | grep -v "lo:" | awk -F: '{print $2}'
    
    # Výběr rozhraní
    read -p "Zadejte název síťového rozhraní (např. eth0 nebo wlan0): " INTERFACE
    
    # Možnosti konfigurace
    echo "Možnosti konfigurace:"
    echo "1) DHCP (automatická konfigurace)"
    echo "2) Statická IP (manuální konfigurace)"
    read -p "Zvolte možnost (1 nebo 2): " NET_OPTION
    
    case $NET_OPTION in
        1)
            # DHCP konfigurace
            sudo dhclient -v $INTERFACE
            ;;
        2)
            # Statická IP konfigurace
            read -p "Zadejte IP adresu (např. 192.168.1.100): " IP_ADDRESS
            read -p "Zadejte masku sítě (např. 24): " NETMASK
            read -p "Zadejte výchozí bránu (např. 192.168.1.1): " GATEWAY
            read -p "Zadejte DNS servery (oddělené mezerou, např. 8.8.8.8 1.1.1.1): " DNS_SERVERS
            
            # Dočasná konfigurace
            sudo ip addr add $IP_ADDRESS/$NETMASK dev $INTERFACE
            sudo ip route add default via $GATEWAY
            echo "nameserver ${DNS_SERVERS%% *}" | sudo tee /etc/resolv.conf
            ;;
        *)
            print_error "Neplatná volba"
            return 1
            ;;
    esac
    
    return 0
}

# Hlavní funkce pro nastavení sítě
setup_network() {
    print_status "SÍŤ" "Nastavení síťového připojení..."
    
    # Kontrola, zda již není připojení
    if check_internet_connection; then
        return 0
    fi
    
    # Možnosti připojení
    echo "Možnosti připojení k internetu:"
    echo "1) Nastavit WiFi"
    echo "2) Manuální konfigurace sítě"
    echo "3) Zkusit znovu automaticky"
    read -p "Zvolte možnost (1-3): " NET_CHOICE
    
    case $NET_CHOICE in
        1)
            setup_wifi
            ;;
        2)
            manual_network_setup
            ;;
        3)
            # Zkusit obnovit DHCP
            sudo dhclient -v eth0
            sudo dhclient -v wlan0
            sleep 5
            ;;
        *)
            print_error "Neplatná volba"
            return 1
            ;;
    esac
    
    # Kontrola, zda se podařilo nastavit připojení
    if check_internet_connection; then
        print_success "Síťové připojení bylo úspěšně nastaveno"
        return 0
    else
        print_error "Nepodařilo se nastavit síťové připojení"
        return 1
    fi
}

# Hlavní část skriptu
echo "================================================================"
echo "    Nastavení síťového připojení pro Raspberry Pi 5"
echo "================================================================"

# Kontrola oprávnění
if [ "$EUID" -ne 0 ]; then
    print_error "Tento skript musí být spuštěn s root oprávněními"
    echo "Použijte: sudo $0"
    exit 1
fi

# Pokus o nastavení sítě
if setup_network; then
    print_success "Síťové připojení je nyní funkční"
    
    # Stažení a spuštění hlavního konfiguračního skriptu
    print_status "STAHOVÁNÍ" "Stahuji hlavní konfigurační skript..."
    
    # Pokud skript ještě neexistuje, stáhneme jej
    if [ ! -f "rpi5-config.sh" ]; then
        wget -O rpi5-config.sh https://raw.githubusercontent.com/vaše-uživatelské-jméno/vaše-repozitář/main/rpi5-config.sh
        chmod +x rpi5-config.sh
    fi
    
    # Spuštění hlavního konfiguračního skriptu
    print_status "SPUŠTĚNÍ" "Spouštím hlavní konfigurační skript..."
    ./rpi5-config.sh
else
    print_error "Nepodařilo se nastavit síťové připojení"
    echo "Zkontrolujte následující:"
    echo "1. Je síťový kabel zapojený (pro eth0)"
    echo "2. Je WiFi router v dosahu a zapnutý"
    echo "3. Máte správné přihlašovací údaje k WiFi"
    echo "4. Nemáte blokovaná síťová rozhraní"
    exit 1
fi