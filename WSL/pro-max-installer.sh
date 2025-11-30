#!/usr/bin/env bash
set -e

WSL_ROOT="/mnt/w"
USER_NAME=$(whoami)

RED="\e[31m"; GREEN="\e[32m"; YELLOW="\e[33m"; BLUE="\e[34m"; RESET="\e[0m"

banner() {
    echo -e "${BLUE}"
    echo "=============================================="
    echo "            WSL PRO MAX INSTALLER"
    echo "   Multi-Distro Workspace Orchestrator v1.0"
    echo "=============================================="
    echo -e "${RESET}"
}

# --------------------------------------------------------
# LIST WSL DISTROS
# --------------------------------------------------------
get_distros() {
    echo "[INFO] Získávám seznam distribucí..."
    wsl.exe --list --quiet | sed 's/\r$//' > /tmp/wsl-distros.txt
}

# --------------------------------------------------------
# CHECK & CONFIGURE HOME PATH
# --------------------------------------------------------
setup_home() {
    local distro="$1"
    local home_path="$2"

    echo "[CHECK] Kontrola HOME pro $distro..."

    if [ ! -d "$home_path" ]; then
        echo "[FIX] Vytvářím $home_path..."
        sudo mkdir -p "$home_path"
    fi

    sudo chown -R $USER_NAME:$USER_NAME "$home_path"

    echo "[INFO] Nastavuji symlink /home/$USER_NAME → $home_path"
    sudo rm -rf /home/$USER_NAME || true
    sudo ln -s "$home_path" /home/$USER_NAME
}

# --------------------------------------------------------
# WRITE wsl.conf
# --------------------------------------------------------
create_wslconf() {
    echo "[WRITE] Přepisuji /etc/wsl.conf..."

    sudo bash -c "cat > /etc/wsl.conf" <<EOF
[user]
default=$USER_NAME

[automount]
enabled=true
root=/mnt/
options=metadata,umask=22,fmask=11

[interop]
appendWindowsPath=false

[network]
generateHosts=true
generateResolvConf=true
EOF
}

# --------------------------------------------------------
# INSTALL MODULE PACKS
# --------------------------------------------------------
install_modules() {
    echo -e "${YELLOW}[INSTALL] PRO MAX MODULE PACK${RESET}"
    sudo apt update -y
    sudo apt install -y \
        docker.io docker-compose \
        zsh tmux tmuxinator tmate \
        waydroid anbox \
        rclone borgbackup \
        neofetch htop iftop iotop \
        jq yq \
        mosquitto mosquitto-clients \
        net-tools dnsutils \
        unzip curl wget git \
        build-essential \
        python3 python3-pip \
        openssh-server \
        x11-apps \
        qemu-user-static

    sudo usermod -aG docker "$USER_NAME"
}

# --------------------------------------------------------
# WEBGUI SETUP
# --------------------------------------------------------
install_webgui() {
    echo "[INSTALL] WebGUI modul..."
    mkdir -p ~/webgui
    cat > ~/webgui/index.html <<EOF
<html>
<head><title>WSL WebGUI</title></head>
<body>
<h1>WSL PRO MAX — Dashboard</h1>
<p>Monitoring, moduly, systémové funkce.</p>
</body>
</html>
EOF
}

# --------------------------------------------------------
# MASTER MENU CREATION
# --------------------------------------------------------
create_menu() {
    cat > ~/wsl-pro <<'EOF'
#!/usr/bin/env bash

BLUE="\e[34m"; RESET="\e[0m"

menu() {
    echo -e "${BLUE}WSL PRO MAX — Hlavní menu${RESET}"
    echo "1) Diagnostika distribuce"
    echo "2) Auto-Fix (opravit HOME, wsl.conf, symlinky)"
    echo "3) Instalace modulů"
    echo "4) WebGUI status"
    echo "5) Restart WSL"
    echo "0) Konec"
    echo
}

while true; do
    menu
    read -p "Vyber možnost: " opt

    case $opt in
        1) neofetch ;;
        2) bash ~/wsl-autofix-pro.sh ;;
        3) bash ~/install-modules.sh ;;
        4) echo "WebGUI je v ~/webgui" ;;
        5) echo "WSL se restartuje…"; exit ;;
        0) exit ;;
    esac
done
EOF
    chmod +x ~/wsl-pro
}

# --------------------------------------------------------
# MAIN
# --------------------------------------------------------
banner
get_distros

echo "[INFO] Detekované distribuce:"
cat /tmp/wsl-distros.txt
echo

CURRENT_DISTRO=$(lsb_release -si 2>/dev/null || echo "Unknown")

DISTRO_DIR="$WSL_ROOT/$CURRENT_DISTRO/home"

setup_home "$CURRENT_DISTRO" "$DISTRO_DIR"
create_wslconf
install_modules
install_webgui
create_menu

echo
echo -e "${GREEN}[DONE] WSL PRO MAX Instalace dokončena.${RESET}"
echo "[INFO] Restartuj WSL:"
echo "    exit"
echo "    wsl --shutdown"
echo
echo "[INFO] Spuštění menu:"
echo "    wsl-pro"
