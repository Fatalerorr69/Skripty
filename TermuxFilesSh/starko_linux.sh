#!/bin/bash
# starko_recovery_linux.sh - Recovery ISO Builder pro Ubuntu/Linux
# Autor: Starko Recovery
# Verze: 1.0

# ================================================
# KONFIGURACE
# ================================================
CONFIG_DIR="$HOME/StarkoRecovery"
ISO_OUTPUT="$CONFIG_DIR/Starko_Recovery_$(date +%Y%m%d).iso"
WORK_DIR="$CONFIG_DIR/work"
LOG_FILE="$CONFIG_DIR/build_$(date +%Y%m%d_%H%M%S).log"
VOLUME_LABEL="STARKO_RECOVERY_LINUX"

# ================================================
# FUNKCE PRO LOGOVÁNÍ
# ================================================
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error() {
    echo "[ERROR] $1" | tee -a "$LOG_FILE"
    exit 1
}

# ================================================
# KONTROLA PŘEDPOKLADŮ
# ================================================
check_requirements() {
    log "Kontroluji systémové požadavky..."
    
    # Kontrola superuživatelských práv
    if [[ $EUID -ne 0 ]]; then
        log "Spouštím jako root pro systémové operace..."
        if sudo -v; then
            log "Root přístup potvrzen"
        else
            error "Nelze získat root přístup"
        fi
    fi
    
    # Kontrola volného místa (minimálně 10GB)
    FREE_SPACE=$(df -BG "$HOME" | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $FREE_SPACE -lt 10 ]]; then
        error "Potřeba minimálně 10GB volného místa. Dostupné: ${FREE_SPACE}GB"
    fi
    
    # Kontrola nástrojů
    local tools=("xorriso" "wget" "curl" "7z" "fdisk" "parted" "mkfs.vfat" "mkfs.ext4")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log "Instaluji $tool..."
            sudo apt update && sudo apt install -y "$tool"
        fi
    done
    
    log "✓ Všechny požadavky splněny"
}

# ================================================
# PŘÍPRAVA ADRESÁŘŮ
# ================================================
prepare_directories() {
    log "Připravuji pracovní adresáře..."
    
    mkdir -p "$CONFIG_DIR" || error "Nelze vytvořit hlavní adresář"
    mkdir -p "$WORK_DIR" || error "Nelze vytvořit pracovní adresář"
    mkdir -p "$WORK_DIR/iso" || error "Nelze vytvořit ISO adresář"
    mkdir -p "$WORK_DIR/boot" || error "Nelze vytvořit boot adresář"
    mkdir -p "$WORK_DIR/recovery" || error "Nelze vytvořit recovery adresář"
    mkdir -p "$CONFIG_DIR/backups" || error "Nelze vytvořit backups adresář"
    
    log "✓ Adresáře připraveny"
}

# ================================================
# STAŽENÍ ZÁKLADNÍCH NÁSTROJŮ
# ================================================
download_tools() {
    log "Stahuji recovery nástroje..."
    
    # SystrescueCD (Linux recovery)
    if [[ ! -f "$WORK_DIR/sysresccd.iso" ]]; then
        log "Stahuji SystemRescueCD..."
        wget -O "$WORK_DIR/sysresccd.iso" \
            "https://sourceforge.net/projects/systemrescuecd/files/sysresccd-x86/10.0/systemrescuecd-10.0-amd64.iso/download" \
            --progress=bar:force 2>&1 | tee -a "$LOG_FILE"
    fi
    
    # GParted Live
    if [[ ! -f "$WORK_DIR/gparted.iso" ]]; then
        log "Stahuji GParted Live..."
        wget -O "$WORK_DIR/gparted.iso" \
            "https://sourceforge.net/projects/gparted/files/gparted-live-stable/1.5.0-6/gparted-live-1.5.0-6-amd64.iso/download" \
            --progress=bar:force 2>&1 | tee -a "$LOG_FILE"
    fi
    
    # TestDisk
    log "Instaluji TestDisk..."
    sudo apt install -y testdisk photorec
    
    # Clonezilla
    if [[ ! -f "$WORK_DIR/clonezilla.iso" ]]; then
        log "Stahuji Clonezilla..."
        wget -O "$WORK_DIR/clonezilla.iso" \
            "https://sourceforge.net/projects/clonezilla/files/clonezilla_live_stable/3.1.0-22/clonezilla-live-3.1.0-22-amd64.iso/download" \
            --progress=bar:force 2>&1 | tee -a "$LOG_FILE"
    fi
    
    log "✓ Nástroje staženy"
}

# ================================================
# EXTRACE ISO SOUBORŮ
# ================================================
extract_isos() {
    log "Extrahuji ISO soubory..."
    
    # Extrakce SystemRescueCD
    if [[ -f "$WORK_DIR/sysresccd.iso" ]]; then
        log "Extrahuji SystemRescueCD..."
        7z x -o"$WORK_DIR/sysresccd" "$WORK_DIR/sysresccd.iso" -y 2>&1 | tee -a "$LOG_FILE"
    fi
    
    # Extrakce GParted
    if [[ -f "$WORK_DIR/gparted.iso" ]]; then
        log "Extrahuji GParted..."
        7z x -o"$WORK_DIR/gparted" "$WORK_DIR/gparted.iso" -y 2>&1 | tee -a "$LOG_FILE"
    fi
    
    log "✓ ISO extrahovány"
}

# ================================================
# VYTVOŘENÍ BOOTOVACÍHO PROSTŘEDÍ
# ================================================
create_boot_environment() {
    log "Vytvářím bootovací prostředí..."
    
    # Vytvoření grub konfigurace
    cat > "$WORK_DIR/boot/grub.cfg" << 'EOF'
set timeout=10
set default=0

menuentry "Starko Recovery Linux" {
    linux /boot/vmlinuz-linux root=/dev/ram0
    initrd /boot/initramfs-linux.img
}

menuentry "SystemRescueCD" {
    linux /sysresccd/boot/x86_64/vmlinuz archisobasedir=sysresccd archisolabel=STARKO_RECOVERY
    initrd /sysresccd/boot/x86_64/sysresccd.img
}

menuentry "GParted Live" {
    linux /gparted/live/vmlinuz boot=live components
    initrd /gparted/live/initrd.img
}

menuentry "Clonezilla" {
    linux /clonezilla/live/vmlinuz boot=live union=overlay username=user
    initrd /clonezilla/live/initrd.img
}

menuentry "Memtest86+" {
    linux16 /boot/memtest86+/memtest.bin
}
EOF
    
    # Stažení memtest86+
    if [[ ! -f "$WORK_DIR/boot/memtest86+.bin" ]]; then
        wget -O "$WORK_DIR/boot/memtest86+.bin" \
            "https://www.memtest.org/download/5.31b/memtest86+-5.31b.bin.gz"
        gunzip "$WORK_DIR/boot/memtest86+.bin.gz"
    fi
    
    log "✓ Bootovací prostředí připraveno"
}

# ================================================
# VYTVOŘENÍ RECOVERY SKRIPTŮ
# ================================================
create_recovery_scripts() {
    log "Vytvářím recovery skripty..."
    
    # Hlavní recovery skript
    cat > "$WORK_DIR/recovery/starko_recovery.sh" << 'EOF'
#!/bin/bash
# Starko Recovery Tool for Linux

echo "=========================================="
echo "  STARTO RECOVERY LINUX v1.0"
echo "=========================================="

PS3='Vyberte akci: '
options=(
    "Test paměti (Memtest86+)"
    "Kontrola disku (smartctl)"
    "Obnova partition tabulky (TestDisk)"
    "Obnova souborů (PhotoRec)"
    "Klonování disku (dd)"
    "Kontrola souborového systému (fsck)"
    "Záloha MBR/GPT"
    "Obnova MBR/GPT"
    "Konec"
)

select opt in "${options[@]}"
do
    case $opt in
        "Test paměti (Memtest86+)")
            memtest86+
            ;;
        "Kontrola disku (smartctl)")
            echo "Dostupné disky:"
            lsblk -d -o NAME,SIZE,MODEL
            read -p "Zadejte disk (např. sda): " disk
            sudo smartctl -a "/dev/$disk"
            ;;
        "Obnova partition tabulky (TestDisk)")
            sudo testdisk
            ;;
        "Obnova souborů (PhotoRec)")
            sudo photorec
            ;;
        "Klonování disku (dd)")
            echo "VAROVÁNÍ: Operace může zničit data!"
            lsblk -d -o NAME,SIZE,MODEL
            read -p "Zdrojový disk: " src
            read -p "Cílový disk: " dst
            read -p "Pokračovat? (ano/ne): " confirm
            if [[ $confirm == "ano" ]]; then
                sudo dd if="/dev/$src" of="/dev/$dst" bs=4M status=progress
            fi
            ;;
        "Kontrola souborového systému (fsck)")
            lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT
            read -p "Zadejte partition (např. sda1): " part
            sudo umount "/dev/$part" 2>/dev/null
            sudo fsck "/dev/$part"
            ;;
        "Záloha MBR/GPT")
            lsblk -d -o NAME,SIZE
            read -p "Zadejte disk: " disk
            sudo dd if="/dev/$disk" of="$HOME/mbr_backup.bin" bs=512 count=1
            sudo sgdisk -b "$HOME/gpt_backup.bin" "/dev/$disk"
            echo "Záloha uložena v $HOME"
            ;;
        "Obnova MBR/GPT")
            lsblk -d -o NAME,SIZE
            read -p "Zadejte disk: " disk
            read -p "Cesta k záloze MBR: " mbr_backup
            read -p "Cesta k záloze GPT: " gpt_backup
            sudo dd if="$mbr_backup" of="/dev/$disk" bs=512 count=1
            sudo sgdisk -l "$gpt_backup" "/dev/$disk"
            ;;
        "Konec")
            break
            ;;
        *) echo "Neplatná volba";;
    esac
done
EOF
    
    chmod +x "$WORK_DIR/recovery/starko_recovery.sh"
    
    # Disk analysis script
    cat > "$WORK_DIR/recovery/disk_info.sh" << 'EOF'
#!/bin/bash
# Disk Information Tool

echo "=== INFORMACE O DISCÍCH ==="
echo ""

echo "1. Základní informace:"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL

echo ""
echo "2. SMART data (pokud dostupné):"
for disk in $(lsblk -d -o NAME | grep -v NAME); do
    echo "--- Disk $disk ---"
    sudo smartctl -i "/dev/$disk" | grep -E "(Model|Capacity|SMART)"
done

echo ""
echo "3. Partition tabulky:"
sudo fdisk -l

echo ""
echo "4. UUID všech partitions:"
sudo blkid

echo ""
echo "5. Volné místo:"
df -h
EOF
    
    chmod +x "$WORK_DIR/recovery/disk_info.sh"
    
    log "✓ Recovery skripty vytvořeny"
}

# ================================================
# VYTVOŘENÍ ISO SOUBORU
# ================================================
create_iso() {
    log "Vytvářím ISO soubor..."
    
    # Příprava struktury pro ISO
    ISO_DIR="$WORK_DIR/iso_final"
    mkdir -p "$ISO_DIR"
    
    # Kopírování souborů
    cp -r "$WORK_DIR/boot" "$ISO_DIR/"
    cp -r "$WORK_DIR/recovery" "$ISO_DIR/"
    cp -r "$WORK_DIR/sysresccd" "$ISO_DIR/" 2>/dev/null || true
    cp -r "$WORK_DIR/gparted" "$ISO_DIR/" 2>/dev/null || true
    
    # Vytvoření README
    cat > "$ISO_DIR/README.txt" << EOF
STARKO RECOVERY LINUX
=====================

Toto ISO obsahuje:
1. SystemRescueCD - kompletní Linux recovery
2. GParted - správce partition
3. TestDisk & PhotoRec - obnova dat
4. Memtest86+ - test paměti
5. Starko Recovery skripty

POUŽITÍ:
- Nahrát ISO na USB: dd if=this.iso of=/dev/sdX bs=4M
- Spustit z USB nebo CD/DVD

SKRIPTY:
- starko_recovery.sh - hlavní menu
- disk_info.sh - informace o discích

Autor: Starko Recovery Team
Verze: 1.0
Datum: $(date)
EOF
    
    # Vytvoření ISO pomocí xorriso
    log "Spouštím xorriso pro vytvoření ISO..."
    
    xorriso -as mkisofs \
        -r -V "$VOLUME_LABEL" \
        -J -joliet-long \
        -iso-level 3 \
        -o "$ISO_OUTPUT" \
        "$ISO_DIR" 2>&1 | tee -a "$LOG_FILE"
    
    if [[ $? -eq 0 ]]; then
        ISO_SIZE=$(du -h "$ISO_OUTPUT" | cut -f1)
        log "✓ ISO vytvořeno: $ISO_OUTPUT ($ISO_SIZE)"
    else
        error "Chyba při vytváření ISO"
    fi
}

# ================================================
# PŘÍPRAVA USB (VOLITELNÉ)
# ================================================
create_usb() {
    log "Příprava USB média..."
    
    echo "Dostupné USB disky:"
    lsblk -d -o NAME,SIZE,MODEL | grep -E "sd[a-z]|mmcblk[0-9]"
    
    read -p "Zadejte USB zařízení (např. sdb): " usb_device
    
    if [[ -z "$usb_device" ]]; then
        log "✓ Přeskočeno vytváření USB"
        return
    fi
    
    # Kontrola, že zařízení existuje
    if [[ ! -b "/dev/$usb_device" ]]; then
        error "Zařízení /dev/$usb_device neexistuje"
    fi
    
    # Varování
    echo "⚠ VAROVÁNÍ: Všechna data na /dev/$usb_device budou smazána!"
    read -p "Pokračovat? (ano/ne): " confirm
    
    if [[ "$confirm" != "ano" ]]; then
        log "✓ Zrušeno vytváření USB"
        return
    fi
    
    # Zápis ISO na USB
    log "Zapisuji ISO na USB (/dev/$usb_device)..."
    
    sudo dd if="$ISO_OUTPUT" of="/dev/$usb_device" bs=4M status=progress \
        && sync
    
    log "✓ USB připraveno: /dev/$usb_device"
}

# ================================================
# HLAVNÍ FUNKCE
# ================================================
main() {
    clear
    echo "=========================================="
    echo "  STARTO RECOVERY LINUX BUILDER"
    echo "=========================================="
    echo "Datum: $(date)"
    echo "Systém: $(uname -a)"
    echo "=========================================="
    
    # Spuštění všech kroků
    check_requirements
    prepare_directories
    download_tools
    extract_isos
    create_boot_environment
    create_recovery_scripts
    create_iso
    
    # Nabídka vytvoření USB
    echo ""
    read -p "Chcete vytvořit bootovací USB? (ano/ne): " create_usb_choice
    if [[ "$create_usb_choice" == "ano" ]]; then
        create_usb
    fi
    
    # Závěrečné informace
    echo ""
    echo "=========================================="
    echo "  BUILD DOKONČEN!"
    echo "=========================================="
    echo "ISO soubor: $ISO_OUTPUT"
    echo "Log soubor: $LOG_FILE"
    echo "Pracovní adresář: $WORK_DIR"
    echo ""
    echo "Příkazy pro použití:"
    echo "  # Nahrání ISO na USB:"
    echo "  sudo dd if=\"$ISO_OUTPUT\" of=/dev/sdX bs=4M status=progress"
    echo ""
    echo "  # Otestování v QEMU:"
    echo "  qemu-system-x86_64 -cdrom \"$ISO_OUTPUT\""
    echo "=========================================="
}

# ================================================
# SPUŠTĚNÍ
# ================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
