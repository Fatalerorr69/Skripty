#!/bin/bash

# =============================================
# KOMPLETNÍ SKRIPT PRO FLASHOVÁNÍ DEBIAN LITE
# PRO RASPBERRY PI 5 NA SD KARTU V TERMUXU
# =============================================

set -e

# Barvy pro výpis
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Funkce pro logování
log_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Úvodní zpráva
echo "========================================"
echo "  FLASHOVÁNÍ DEBIAN LITE PRO RPI5"
echo "        TERMUX SKRIPT"
echo "========================================"
echo ""

# Kontrola storage permissions
log_info "Kontrola oprávnění pro úložiště..."
if [ ! -d ~/storage/downloads ]; then
    log_warning "Storage není nastaveno. Žádám o povolení..."
    termux-setup-storage
    sleep 2
fi

# Aktualizace a instalace balíčků
log_info "Aktualizace Termuxu a instalace balíčků..."
pkg update -y && pkg upgrade -y
pkg install -y wget unzip procps-utils lsblk

# Přesun do složky s downloady
cd ~/storage/downloads

# Kontrola existence ISO souboru
log_info "Hledám Debian Lite ISO soubor..."
ISO_FILE=$(find . -name "*.iso" -o -name "*.img" | head -n1)

if [ -z "$ISO_FILE" ]; then
    log_warning "Nenalezen žádný ISO/IMG soubor."
    echo "Zadejte URL pro stažení Debian Lite ISO:"
    read -p "URL: " ISO_URL
    if [ -n "$ISO_URL" ]; then
        log_info "Stahuji ISO soubor..."
        wget -O debian-rpi5.iso "$ISO_URL"
        ISO_FILE="debian-rpi5.iso"
    else
        log_error "Není zadána URL. Ukončuji."
        exit 1
    fi
else
    log_success "Nalezen soubor: $ISO_FILE"
fi

# Kontrola velikosti souboru
FILE_SIZE=$(stat -c%s "$ISO_FILE")
log_info "Velikost ISO souboru: $((FILE_SIZE / 1024 / 1024)) MB"

# Detekce SD karty
log_info "Připojte SD kartu přes USB OTG adaptér..."
echo "Čekám 5 sekund na detekci zařízení..."
sleep 5

log_info "Skenování připojených zařízení..."
echo "=== DOSTUPNÁ ZAŘÍZENÍ ==="
lsblk 2>/dev/null || cat /proc/partitions

echo ""
log_warning "PŘED POKRAČOVÁNÍM:"
echo "1. Ujistěte se, že SD karta je připojena"
echo "2. Zálohoval jsi data ze SD karty"
echo "3. Telefon je dostatečně nabitý"
echo ""

read -p "Pokračovat? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    log_info "Operace zrušena uživatelem."
    exit 0
fi

# Výběr zařízení
log_info "Zadejte cestu k SD kartě (např. /dev/sda):"
read -p "Zařízení: " DEVICE

# Kontrola existence zařízení
if [ ! -b "$DEVICE" ]; then
    log_error "Zařízení $DEVICE neexistuje nebo není blokové!"
    log_info "Dostupná zařízení:"
    lsblk 2>/dev/null || cat /proc/partitions
    exit 1
fi

# Finální potvrzení
echo ""
log_warning "⚠️  ⚠️  ⚠️  POSLEDNÍ VAROVÁNÍ ⚠️  ⚠️  ⚠️"
log_warning "Budu flashovat $ISO_FILE na $DEVICE"
log_warning "VŠECHNA DATA NA $DEVICE BUDOU SMAZÁNA!"
echo ""

read -p "Opravdu pokračovat? (napiš 'FLASH' pro potvrzení): " FINAL_CONFIRM
if [ "$FINAL_CONFIRM" != "FLASH" ]; then
    log_info "Operace zrušena."
    exit 0
fi

# Flashování
log_info "Začínám flashování..."
log_info "To může trvat několik minut..."
echo "Průběh:"

# Použijeme dd s progress
if command -v pv >/dev/null 2>&1; then
    pkg install -y pv
    pv "$ISO_FILE" | dd of="$DEVICE" bs=4M
else
    dd if="$ISO_FILE" of="$DEVICE" bs=4M status=progress
fi

# Synchronizace
log_info "Dokončování zápisu..."
sync

# Kontrola výsledku
if [ $? -eq 0 ]; then
    log_success "Flashování úspěšně dokončeno! 🎉"
    log_success "SD karta je připravena pro Raspberry Pi 5"
    
    # Další kroky pro RPi5
    echo ""
    log_info "Doporučené další kroky:"
    echo "1. Vložte SD kartu do Raspberry Pi 5"
    echo "2. Připojte napájení"
    echo "3. Pro SSH připojení:"
    echo "   - Přidejte prázdný soubor 'ssh' na boot partition"
    echo "4. Default login je často: root/root nebo pi/raspberry"
else
    log_error "Během flashování došlo k chybě!"
    exit 1
fi

echo ""
log_success "Skript dokončen! ✅"
