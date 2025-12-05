#!/bin/bash

# =============================================
# OPRAVENÝ SKRIPT PRO TERMUX - FLASHOVÁNÍ DEBIAN
# =============================================

set -e

# Barvy pro výpis
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

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
echo "  OPRAVENÝ FLASH SKRIPT PRO TERMUX"
echo "========================================"
echo ""

# Kontrola storage permissions
log_info "Kontrola oprávnění pro úložiště..."
if [ ! -d ~/storage/downloads ]; then
    log_warning "Storage není nastaveno. Žádám o povolení..."
    termux-setup-storage
    sleep 3
fi

# Aktualizace a instalace balíčků
log_info "Aktualizace Termuxu a instalace balíčků..."
pkg update -y && pkg upgrade -y
pkg install -y wget unzip coreutils

# Přesun do složky s downloady
cd ~/storage/downloads

# Kontrola existence ISO souboru
log_info "Hledám ISO soubor..."
ISO_FILES=$(find . -maxdepth 1 -type f \( -iname "*.iso" -o -iname "*.img" \) | head -n1)

if [ -z "$ISO_FILES" ]; then
    log_warning "Nenalezen žádný ISO/IMG soubor."
    log_info "Dostupné soubory v downloads:"
    ls -la ~/storage/downloads/
    
    echo ""
    log_info "Chcete stáhnout Debian pro RPi5? (y/n)"
    read -p "Volba: " DOWNLOAD_CHOICE
    
    if [ "$DOWNLOAD_CHOICE" = "y" ] || [ "$DOWNLOAD_CHOICE" = "Y" ]; then
        log_info "Stahuji Debian Bookworm pro RPi5..."
        wget -O debian-rpi5.img.xz "https://gitlab.com/api/v4/projects/48135354/jobs/artifacts/bookworm/raw/debian-archive-keyring.gpg?job=build_bookworm_slim_rpi5"
        if [ -f "debian-rpi5.img.xz" ]; then
            log_info "Rozbalování souboru..."
            unxz debian-rpi5.img.xz
            ISO_FILE="debian-rpi5.img"
        else
            log_error "Stažení selhalo. Přidejte ISO soubor ručně do složky Downloads."
            exit 1
        fi
    else
        log_info "Přidejte ISO soubor do složky Downloads a spusťte skript znovu."
        exit 1
    fi
else
    ISO_FILE="$ISO_FILES"
    log_success "Nalezen soubor: $ISO_FILE"
fi

# Kontrola velikosti souboru
if [ -f "$ISO_FILE" ]; then
    FILE_SIZE=$(stat -c%s "$ISO_FILE" 2>/dev/null || du -b "$ISO_FILE" | cut -f1)
    log_info "Velikost souboru: $((FILE_SIZE / 1024 / 1024)) MB"
else
    log_error "Soubor $ISO_FILE nebyl nalezen!"
    exit 1
fi

# Detekce zařízení - OPRAVENÁ ČÁST
log_info "Připojte SD kartu přes USB OTG adaptér..."
echo "Čekám 5 sekund na detekci zařízení..."
sleep 5

log_info "Skenování připojených zařízení..."
echo "=== DOSTUPNÁ ZAŘÍZENÍ ==="

# Použijeme několik metod pro detekci
log_info "Metoda 1: /proc/partitions"
cat /proc/partitions 2>/dev/null && echo ""

log_info "Metoda 2: df -h"
df -h 2>/dev/null | grep -v "^tmpfs\|^/data\|^/system" && echo ""

log_info "Metoda 3: ls /dev/block"
ls -la /dev/block/ 2>/dev/null | grep -E "sd|mmc" || echo "Nenalezena SD karta"

echo ""
log_warning "DŮLEŽITÉ:"
echo "• SD karta se obvykle zobrazí jako /dev/block/sda nebo /dev/block/mmcblk*"
echo "• Interní úložiště je obvykle /dev/block/dm-* nebo /data"
echo ""

read -p "Pokračovat? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    log_info "Operace zrušena uživatelem."
    exit 0
fi

# Výběr zařízení
log_info "Zadejte cestu k SD kartě (např. /dev/block/sda):"
read -p "Zařízení: " DEVICE

# Kontrola existence zařízení
if [ ! -b "$DEVICE" ]; then
    log_error "Zařízení $DEVICE neexistuje nebo není blokové!"
    log_info "Dostupná bloková zařízení:"
    find /dev/block -type b 2>/dev/null | sort
    exit 1
fi

# Finální potvrzení
echo ""
log_warning "⚠️  ⚠️  ⚠️  POSLEDNÍ VAROVÁNÍ ⚠️  ⚠️  ⚠️"
log_warning "Budu flashovat: $ISO_FILE"
log_warning "Na zařízení: $DEVICE"
log_warning "VŠECHNA DATA NA $DEVICE BUDOU SMAZÁNA!"
echo ""

read -p "Opravdu pokračovat? (napiš 'FLASH' pro potvrzení): " FINAL_CONFIRM
if [ "$FINAL_CONFIRM" != "FLASH" ]; then
    log_info "Operace zrušena."
    exit 0
fi

# Flashování - OPRAVENÁ ČÁST
log_info "Začínám flashování..."
log_info "To může trvat 5-20 minut..."

# Vypočítáme velikost pro progress
TOTAL_SIZE=$(stat -c%s "$ISO_FILE" 2>/dev/null || du -b "$ISO_FILE" | cut -f1)

# Flashování s jednoduchým progress barem
log_info "Flashování: [                    ] 0%"
dd if="$ISO_FILE" of="$DEVICE" bs=1M 2>/dev/null &

# Jednoduchý progress indicator
DD_PID=$!
while kill -0 $DD_PID 2>/dev/null; do
    sleep 5
    CURRENT_POS=$(stat -c%s "$ISO_FILE" 2>/dev/null || echo "0")
    PROGRESS=$((CURRENT_POS * 100 / TOTAL_SIZE))
    BAR=$((PROGRESS / 5))
    printf "\rFlashování: [%-20s] %d%%" "$(printf '#%.0s' $(seq 1 $BAR))" "$PROGRESS"
done

wait $DD_PID
DD_EXIT=$?

# Synchronizace
log_info "\nDokončování zápisu..."
sync

# Kontrola výsledku
if [ $DD_EXIT -eq 0 ]; then
    log_success "Flashování úspěšně dokončeno! 🎉"
    log_success "SD karta je připravena pro Raspberry Pi 5"
    
    echo ""
    log_info "Doporučené další kroky:"
    echo "1. Vložte SD kartu do Raspberry Pi 5"
    echo "2. Připojte napájení"
    echo "3. Pro SSH: Vytvořte prázdný soubor 'ssh' na boot partition"
    echo "4. Default login: root/root nebo pi/raspberry"
else
    log_error "Během flashování došlo k chybě! Kód: $DD_EXIT"
    exit 1
fi

echo ""
log_success "Skript dokončen! ✅"
