#!/usr/bin/env bash
set -e

# ============================================================
#  MEGA TERMINAL UPGRADE 13.0 – FULL TERMINAL OS
#  Autor: Starko AI Workspace
#  Kompatibilita: WSL, Linux, Termux, RPi, macOS
# ============================================================

LOGFILE="$HOME/mega_upgrade.log"
PLUGIN_DIR="$HOME/.mega-upgrade/plugins"
TUI_DIR="$HOME/.mega-upgrade/tui"
PROFILE_DIR="$HOME/.mega-upgrade/profiles"
mkdir -p "$PLUGIN_DIR" "$TUI_DIR" "$PROFILE_DIR" ~/.local/bin

log() { echo -e "[INFO] $1" | tee -a "$LOGFILE"; }
warn() { echo -e "[WARN] $1" | tee -a "$LOGFILE"; }
error() { echo -e "[ERROR] $1" | tee -a "$LOGFILE"; }

# ------------------------------------------------------------
# DETEKCE PLATFORMY A PACKAGE MANAGERU
# ------------------------------------------------------------
detect_platform() {
    if grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then PLATFORM="WSL"
    elif command -v termux-info >/dev/null 2>&1; then PLATFORM="TERMUX"
    elif [[ "$OSTYPE" == "darwin"* ]]; then PLATFORM="MAC"
    elif command -v pacman >/dev/null 2>&1; then PLATFORM="ARCH"
    elif command -v dnf >/dev/null 2>&1; then PLATFORM="FEDORA"
    else PLATFORM="DEBIAN"
    fi
    log "Platforma: $PLATFORM"
}

detect_pm() {
    if command -v apt >/dev/null 2>&1; then PM="apt"
    elif command -v pacman >/dev/null 2>&1; then PM="pacman"
    elif command -v dnf >/dev/null 2>&1; then PM="dnf"
    elif command -v brew >/dev/null 2>&1; then PM="brew"
    elif command -v pkg >/dev/null 2>&1; then PM="pkg"
    else error "Nepodporovaný systém" && exit 1
    fi
    log "Package Manager: $PM"
}

install_pkg() {
    case "$PM" in
        apt) sudo apt install -y "$@" ;;
        pacman) sudo pacman -S --noconfirm "$@" ;;
        dnf) sudo dnf install -y "$@" ;;
        brew) brew install "$@" ;;
        pkg) pkg install -y "$@" ;;
    esac
}

update_system() {
    log "Aktualizuji systém..."
    case "$PM" in
        apt) sudo apt update && sudo apt upgrade -y ;;
        pacman) sudo pacman -Syu --noconfirm ;;
        dnf) sudo dnf upgrade -y ;;
        brew) brew update ;;
        pkg) pkg update ;;
    esac
}

# ------------------------------------------------------------
# PROFILY
# ------------------------------------------------------------
choose_profile() {
    echo ""
    echo "Vyber profil:"
    echo "1) Hacker Pro"
    echo "2) DevOps Pro"
    echo "3) Creator Pro"
    echo "4) Universal"
    read -p "Číslo profilu: " PROFILE
    case "$PROFILE" in
        1) PROFILE="HACKER" ;;
        2) PROFILE="DEVOPS" ;;
        3) PROFILE="CREATOR" ;;
        *) PROFILE="UNIVERSAL" ;;
    esac
    log "Vybraný profil: $PROFILE"
}

# ------------------------------------------------------------
# GPU / CPU DETEKCE
# ------------------------------------------------------------
detect_gpu() {
    if command -v nvidia-smi >/dev/null 2>&1; then GPU="NVIDIA"
    elif ls /dev/dri/* >/dev/null 2>&1; then GPU="INTEL/AMD"
    else GPU="NONE"
    fi
    log "GPU: $GPU"
}

install_gpu_stack() {
    case "$GPU" in
        NVIDIA) log "CUDA stack..." && install_pkg nvidia-cuda-toolkit || true ;;
        INTEL/AMD) log "Mesa stack..." && install_pkg mesa-utils || true ;;
        NONE) log "CPU fallback → libopenblas-dev" && install_pkg libopenblas-dev || true ;;
    esac
}

# ------------------------------------------------------------
# SHELL + ALIAS + STARSHIP + NERD FONT
# ------------------------------------------------------------
install_shell_tools() {
    TOOLS=(eza bat fzf ripgrep fd-find btop tmux ranger lazygit tldr duf dust neofetch)
    log "Instaluji terminálové nástroje..."
    for pkg in "${TOOLS[@]}"; do install_pkg "$pkg" || warn "$pkg přeskočen"; done

    log "Instaluji Starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y
    echo 'eval "$(starship init bash)"' >> ~/.bashrc

    log "Instaluji Nerd Font..."
    mkdir -p ~/.local/share/fonts && cd ~/.local/share/fonts
    wget -q https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
    unzip -o JetBrainsMono.zip
    fc-cache -fv
}

configure_aliases() {
cat >> ~/.bashrc << 'EOF'

alias ls="eza --icons"
alias ll="eza -al --icons"
alias cat="bat"
alias find="fd"
alias du="dust"
alias df="duf"
alias sysinfo="neofetch"
alias gs="git status"
alias gl="git log --oneline --graph"

export FZF_DEFAULT_COMMAND="fd --type f"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
EOF
}

# ------------------------------------------------------------
# AI TERMINAL
# ------------------------------------------------------------
install_ai_terminal() {
    log "Instaluji Ollama AI terminál..."
    curl -fsSL https://ollama.com/install.sh | bash
    cat > ~/.local/bin/ai << 'EOF'
#!/usr/bin/env bash
ollama run llama3 "$@"
EOF
    chmod +x ~/.local/bin/ai
}

# ------------------------------------------------------------
# DEV TOOLS PODLE PROFILU
# ------------------------------------------------------------
install_dev_tools() {
    case "$PROFILE" in
        HACKER) install_pkg nmap tcpdump wireshark sqlmap hydra proxychains ;;
        DEVOPS) install_pkg docker.io docker-compose kubectl terraform ansible helm ;;
        CREATOR) install_pkg ffmpeg imagemagick yt-dlp blender nodejs npm python3 python3-pip ;;
        UNIVERSAL) install_pkg python3 python3-pip nodejs npm git wget curl ;;
    esac
}

# ------------------------------------------------------------
# TUI DASHBOARD & SECURITY
# ------------------------------------------------------------
install_tui_dashboard() {
    log "Instaluji TUI dashboard..."
    install_pkg glances || true
    cat > "$TUI_DIR/starko-top.sh" << 'EOF'
#!/usr/bin/env bash
glances -w
EOF
    chmod +x "$TUI_DIR/starko-top.sh"

    cat > "$TUI_DIR/starko-secure.sh" << 'EOF'
#!/usr/bin/env bash
echo "Starko Security TUI"
sudo ufw status
sudo fail2ban-client status
EOF
    chmod +x "$TUI_DIR/starko-secure.sh"
}

# ------------------------------------------------------------
# PLUGIN SYSTEM
# ------------------------------------------------------------
run_plugins() {
    log "Spouštím pluginy..."
    for plugin in "$PLUGIN_DIR"/*.sh; do [ -f "$plugin" ] && bash "$plugin"; done
}

# ------------------------------------------------------------
# GITHUB SYNC
# ------------------------------------------------------------
setup_sync() {
    read -p "Zapnout GitHub sync? (y/n): " SYNC
    if [[ "$SYNC" != "y" ]]; then log "Sync přeskočen"; return; fi
    log "Inicializuji GitHub repo..."
    git config --global init.defaultBranch main
    mkdir -p ~/.mega-sync && cd ~/.mega-sync
    git init
    git add . && git commit -m "Initial sync"
}

# ------------------------------------------------------------
# FINAL OPTIMIZATION
# ------------------------------------------------------------
finalize() {
    log "Odstraňuji nepotřebné balíky..."
    case "$PM" in
        apt) sudo apt autoremove -y ;;
        pacman) sudo pacman -Rns $(pacman -Qdtq) --noconfirm || true ;;
        dnf) sudo dnf autoremove -y ;;
    esac
    log "Dokončeno! Restartuj terminál a užij si MEGA TERMINAL OS 13.0!"
}

# ------------------------------------------------------------
# SPUŠTĚNÍ
# ------------------------------------------------------------
detect_platform
detect_pm
choose_profile
update_system
detect_gpu
install_gpu_stack
install_shell_tools
configure_aliases
install_ai_terminal
install_dev_tools
install_tui_dashboard
run_plugins
setup_sync
finalize

