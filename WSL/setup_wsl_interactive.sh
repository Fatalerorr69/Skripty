#!/bin/bash
# Starko Workspace Interaktivní Setup WSL 2.0
# Univerzální pro všechny distribuce
set -euo pipefail
IFS=$'\n\t'

# ---------- Funkce ----------

# Kontrola běhu v WSL
check_wsl() {
    if ! grep -q Microsoft /proc/version; then
        echo "[ERROR] Skript musí být spuštěn uvnitř WSL!" >&2
        exit 1
    fi
    echo "[INFO] WSL prostředí OK."
}

# Detekce všech distribucí
detect_distros() {
    echo "[INFO] Hledám nainstalované distribuce WSL..."
    mapfile -t DISTROS < <(wsl --list --quiet)
    echo "[INFO] Nalezené distribuce: ${DISTROS[*]}"
}

# Nastavení domovských adresářů
setup_home_dirs() {
    for DISTRO in "${DISTROS[@]}"; do
        HOME_DIR="/mnt/w/${DISTRO}/home"
        echo "[INFO] Kontrola a vytvoření adresáře $HOME_DIR..."
        if [ ! -d "$HOME_DIR" ]; then
            mkdir -p "$HOME_DIR"
        fi
        # Nastavení symlinku v distribuci
        wsl -d "$DISTRO" -- bash -c "sudo rm -rf /home && sudo ln -s $HOME_DIR /home && sudo chown -R \$USER:\$USER $HOME_DIR"
        echo "[INFO] Domovský adresář pro $DISTRO nastaven."
    done
}

# Instalace doporučených balíčků
install_packages() {
    for DISTRO in "${DISTROS[@]}"; do
        echo "[INFO] Instalace balíčků pro $DISTRO..."
        wsl -d "$DISTRO" -- bash -c "
            sudo apt update -y && sudo apt upgrade -y
            sudo apt install -y curl wget git vim htop unzip tar zip build-essential software-properties-common \
            docker.io docker-compose waydroid anbox rclone borgbackup tmux tmate jq yq mosquitto-clients \
            neofetch zsh python3-pip python3-venv vlc ffmpeg
            # Oh-My-Zsh
            if [ ! -d ~/.oh-my-zsh ]; then
                sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" --unattended
            fi
            chsh -s \$(which zsh)
        "
        echo "[INFO] Balíčky nainstalovány pro $DISTRO."
    done
}

# Instalace WebGUI a monitoringu
install_webgui() {
    for DISTRO in "${DISTROS[@]}"; do
        echo "[INFO] Instalace WebGUI pro $DISTRO..."
        wsl -d "$DISTRO" -- bash -c "
            sudo apt install -y python3-pip
            pip3 install flask flask-socketio watchdog psutil
            mkdir -p ~/webgui
            cat > ~/webgui/app.py << 'EOF'
from flask import Flask, render_template
import psutil
app = Flask(__name__)

@app.route('/')
def index():
    mem = psutil.virtual_memory()
    cpu = psutil.cpu_percent(interval=1)
    return f'<h1>Starko Workspace WebGUI</h1><p>CPU: {cpu}%</p><p>Memory: {mem.percent}%</p>'

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
EOF
        "
        echo "[INFO] WebGUI připraven pro $DISTRO."
    done
}

# Interaktivní menu
interactive_menu() {
    while true; do
        clear
        echo "==========================="
        echo "Starko Workspace - Menu"
        echo "==========================="
        echo "1) Spustit WebGUI"
        echo "2) Správa Docker kontejnerů"
        echo "3) Správa Waydroid"
        echo "4) Spustit zálohu (borg/tar)"
        echo "5) Instalace dalších balíčků"
        echo "6) Zkontrolovat stav služeb"
        echo "7) Ukončit"
        echo -n "Vyber možnost: "
        read CHOICE
        case "$CHOICE" in
            1)
                echo "[INFO] Spouštím WebGUI..."
                read -p "Zadej distribuci: " DISTRO
                wsl -d "$DISTRO" -- bash -c "nohup python3 ~/webgui/app.py >/dev/null 2>&1 &"
                echo "[INFO] WebGUI spuštěno na http://localhost:8080"
                read -p "Enter pro návrat do menu..."
                ;;
            2)
                echo "[INFO] Docker menu..."
                read -p "Zadej distribuci: " DISTRO
                wsl -d "$DISTRO" -- bash -c "docker ps -a"
                read -p "Enter pro návrat do menu..."
                ;;
            3)
                echo "[INFO] Waydroid menu..."
                read -p "Zadej distribuci: " DISTRO
                wsl -d "$DISTRO" -- bash -c "waydroid status"
                read -p "Enter pro návrat do menu..."
                ;;
            4)
                echo "[INFO] Spuštění zálohy..."
                read -p "Zadej distribuci: " DISTRO
                read -p "Zadej cílový adresář zálohy: " BACKUP_DIR
                mkdir -p "$BACKUP_DIR"
                wsl -d "$DISTRO" -- bash -c "tar -czf $BACKUP_DIR/${DISTRO}_backup_$(date +%F).tar.gz /home"
                echo "[INFO] Záloha dokončena."
                read -p "Enter pro návrat do menu..."
                ;;
            5)
                echo "[INFO] Instalace dalších balíčků..."
                read -p "Zadej distribuci: " DISTRO
                read -p "Zadej balíčky (oddělené mezerou): " PKGS
                wsl -d "$DISTRO" -- bash -c "sudo apt install -y $PKGS"
                echo "[INFO] Instalace dokončena."
                read -p "Enter pro návrat do menu..."
                ;;
            6)
                echo "[INFO] Stav služeb..."
                read -p "Zadej distribuci: " DISTRO
                wsl -d "$DISTRO" -- bash -c "systemctl status docker || echo 'Docker není spuštěn'"
                wsl -d "$DISTRO" -- bash -c "systemctl status mosquitto || echo 'Mosquitto není spuštěn'"
                read -p "Enter pro návrat do menu..."
                ;;
            7)
                echo "[INFO] Konec."
                exit 0
                ;;
            *)
                echo "[ERROR] Neplatná volba!"
                sleep 1
                ;;
        esac
    done
}

# ---------- Hlavní běh ----------
main() {
    check_wsl
    detect_distros
    setup_home_dirs
    install_packages
    install_webgui
    echo "[INFO] Všechny distribuce připraveny!"
    echo "[INFO] Spusťte interaktivní menu: "
    interactive_menu
}

main

