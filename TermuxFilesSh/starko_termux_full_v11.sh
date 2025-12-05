#!/data/data/com.termux/files/usr/bin/bash
# =================================================================
# STARKO_TERMUX_FULL_V11 - All-in-One Recovery & Toolkit
# Termux / Android
# =================================================================

# -----------------------------------------------------------------
# KONFIGURACE
# -----------------------------------------------------------------
ROOT_PATH="$HOME/StarkoRecovery_AIO"
LOG_FILE="$ROOT_PATH/Starko_Build_$(date +%Y%m%d_%H%M%S).log"

# Výchozí komponenty
COMP_WINPE=true
COMP_LINUX=true
COMP_FORENSIC=true
COMP_DRIVERS=true
COMP_AI=true
COMP_NETWORK=true
COMP_PENTEST=true
COMP_DIAGNOSTIC=true

# -----------------------------------------------------------------
# FUNKCE PRO LOGOVÁNÍ
# -----------------------------------------------------------------
function log_info() {
    echo "[INFO] $1" | tee -a "$LOG_FILE"
}

function log_warn() {
    echo "[WARN] $1" | tee -a "$LOG_FILE"
}

function log_error() {
    echo "[ERROR] $1" | tee -a "$LOG_FILE"
}

function log_success() {
    echo "[SUCCESS] $1" | tee -a "$LOG_FILE"
}

# -----------------------------------------------------------------
# PŘÍPRAVA ADRESÁŘŮ
# -----------------------------------------------------------------
function prepare_dirs() {
    log_info "Příprava adresářové struktury..."
    mkdir -p "$ROOT_PATH"/{WinPE,Linux,Drivers,Tools/{Forensic,Network,Diagnostic},AI,Boot,ISO,Scripts}
    log_success "Adresářová struktura připravena"
}

# -----------------------------------------------------------------
# DETEKCE USB
# -----------------------------------------------------------------
function detect_usb() {
    log_info "Detekce dostupných USB disků..."
    if command -v lsblk &>/dev/null; then
        USB_LIST=$(lsblk -o NAME,MOUNTPOINT,SIZE | grep -v "loop" | grep -v "boot")
        if [ -z "$USB_LIST" ]; then
            log_warn "Žádný USB disk nebyl nalezen"
        else
            echo "$USB_LIST"
        fi
    else
        log_warn "lsblk není dostupný, nelze detekovat USB"
    fi
}

# -----------------------------------------------------------------
# STAHOVÁNÍ NÁSTROJŮ
# -----------------------------------------------------------------
function download_linux_iso() {
    if [ "$COMP_LINUX" = true ]; then
        log_info "Stahování Linux ISO..."
        mkdir -p "$ROOT_PATH/Linux"
        declare -A LINUX_ISOS=(
            ["Ubuntu_Mini"]="https://cdimage.ubuntu.com/ubuntu-mini-iso/releases/24.04/release/ubuntu-mini-24.04-live-amd64.iso"
            ["SystemRescue"]="https://sourceforge.net/projects/systemrescuecd/files/sysresccd-x86/10.00/systemrescue-10.00-amd64.iso/download"
            ["GParted"]="https://sourceforge.net/projects/gparted/files/gparted-live-stable/1.5.0-7/gparted-live-1.5.0-7-amd64.iso/download"
        )
        for name in "${!LINUX_ISOS[@]}"; do
            target="$ROOT_PATH/Linux/$name.iso"
            if [ ! -f "$target" ]; then
                log_info "Stahuji $name..."
                wget -O "$target" "${LINUX_ISOS[$name]}" || log_error "Chyba při stahování $name"
            fi
        done
        log_success "Linux ISO připraveny"
    fi
}

function download_forensic_tools() {
    if [ "$COMP_FORENSIC" = true ]; then
        log_info "Stahování forenzních nástrojů..."
        mkdir -p "$ROOT_PATH/Tools/Forensic"
        declare -A FORENSIC_TOOLS=(
            ["Autopsy"]="https://github.com/sleuthkit/autopsy/releases/download/autopsy-4.21.0/autopsy-4.21.0.zip"
            ["FTKImager"]="https://d1kpmuwb7gvu1i.cloudfront.net/FTKImager_4.7.1.zip"
            ["KAPE"]="https://www.kroll.com/en/kape/kape.zip"
        )
        for tool in "${!FORENSIC_TOOLS[@]}"; do
            target="$ROOT_PATH/Tools/Forensic/$tool"
            mkdir -p "$target"
            if [ ! -f "$target/$tool.zip" ]; then
                log_info "Stahuji $tool..."
                wget -O "$target/$tool.zip" "${FORENSIC_TOOLS[$tool]}" || log_error "Chyba u $tool"
                unzip -o "$target/$tool.zip" -d "$target" && rm "$target/$tool.zip"
            fi
        done
        log_success "Forenzní nástroje připraveny"
    fi
}

function prepare_ai() {
    if [ "$COMP_AI" = true ]; then
        log_info "Příprava AI modelu GPT4All..."
        mkdir -p "$ROOT_PATH/AI"
        AI_MODEL="$ROOT_PATH/AI/gpt4all-lora-quantized.bin"
        if [ ! -f "$AI_MODEL" ]; then
            wget -O "$AI_MODEL" "https://gpt4all.io/models/gpt4all-lora-quantized.bin" || log_error "Chyba při stahování AI modelu"
        fi
        log_success "AI modul připraven"
    fi
}

function prepare_network_tools() {
    if [ "$COMP_NETWORK" = true ]; then
        log_info "Instalace síťových nástrojů..."
        pkg install nmap wireshark-cli openssh -y
        log_success "Síťové nástroje připraveny"
    fi
}

function prepare_pentest_tools() {
    if [ "$COMP_PENTEST" = true ]; then
        log_info "Instalace PenTest toolkit..."
        pkg install metasploit -y
        log_success "PenTest toolkit připraven"
    fi
}

function prepare_diagnostic_tools() {
    if [ "$COMP_DIAGNOSTIC" = true ]; then
        log_info "Instalace diagnostických nástrojů..."
        pkg install htop neofetch -y
        log_success "Diagnostika připravena"
    fi
}

# -----------------------------------------------------------------
# HLAVNÍ MENU
# -----------------------------------------------------------------
function main_menu() {
    if ! command -v whiptail &>/dev/null; then
        log_warn "whiptail není nainstalovaný. Instalace..."
        pkg install whiptail -y
    fi

    OPTIONS=$(whiptail --title "STARKO TERMUX FULL V11" --checklist \
        "Vyber komponenty pro build:" 20 78 10 \
        "WinPE" "Windows PE Recovery (x64)" ON \
        "Linux" "Linux Recovery ISO" ON \
        "Forensic" "Forenzní nástroje" ON \
        "Drivers" "Ovladače HW" ON \
        "AI" "Offline AI modul GPT4All" ON \
        "Network" "Síťové nástroje" ON \
        "Pentest" "PenTest toolkit" ON \
        "Diagnostic" "Diagnostika HW" ON 3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then
        log_info "Build zrušen uživatelem"
        exit 0
    fi

    for opt in $OPTIONS; do
        case $opt in
            "\"WinPE\"") COMP_WINPE=true ;;
            "\"Linux\"") COMP_LINUX=true ;;
            "\"Forensic\"") COMP_FORENSIC=true ;;
            "\"Drivers\"") COMP_DRIVERS=true ;;
            "\"AI\"") COMP_AI=true ;;
            "\"Network\"") COMP_NETWORK=true ;;
            "\"Pentest\"") COMP_PENTEST=true ;;
            "\"Diagnostic\"") COMP_DIAGNOSTIC=true ;;
        esac
    done
}

# -----------------------------------------------------------------
# SPUŠTĚNÍ BUILD
# -----------------------------------------------------------------
function start_build() {
    log_info "=== SPUŠTĚN BUILD PROCES ==="
    prepare_dirs
    download_linux_iso
    download_forensic_tools
    prepare_ai
    prepare_network_tools
    prepare_pentest_tools
    prepare_diagnostic_tools
    log_success "=== BUILD DOKONČEN ==="
    whiptail --title "STARKO TERMUX FULL V11" --msgbox "Build dokončen! ISO a nástroje jsou v $ROOT_PATH" 10 60
}

# -----------------------------------------------------------------
# SPUŠTĚNÍ
# -----------------------------------------------------------------
main_menu
start_build
