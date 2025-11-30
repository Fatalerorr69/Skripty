cd ~
cat > ubuntu2204_full_setup.sh << 'EOF'
#!/bin/bash

# --------------------------------------------------------
# Starko Ubuntu 22.04 WSL Full Setup Script
# --------------------------------------------------------

# --- INFO ---
echo "[INFO] Start setup: $(date)"

# --- Aktualizace systému ---
echo "[INFO] Aktualizuji systém..."
sudo apt update && sudo apt upgrade -y

# --- Základní balíčky ---
sudo apt install -y software-properties-common apt-transport-https ca-certificates curl wget gnupg lsb-release unzip git build-essential python3 python3-pip python3-venv vim nano tree htop rsync cifs-utils

# --- Oh-My-Zsh + pluginy ---
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "[INFO] Instalace Oh-My-Zsh..."
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc
echo "neofetch" >> ~/.zshrc

# --- Docker ---
echo "[INFO] Instalace Docker..."
sudo apt remove -y docker docker-engine docker.io containerd runc
sudo apt install -y docker.io docker-compose
sudo usermod -aG docker $USER

# --- Waydroid / Anbox ---
echo "[INFO] Instalace Waydroid..."
sudo add-apt-repository -y ppa:waydroid/waydroid
sudo apt update
sudo apt install -y waydroid
sudo waydroid init

# --- VNC / noVNC ---
echo "[INFO] Instalace VNC server a noVNC..."
sudo apt install -y tigervnc-standalone-server novnc websockify

# --- Zálohovací nástroje ---
echo "[INFO] Instalace rclone a borgbackup..."
sudo apt install -y rclone borgbackup

# --- IoT a MQTT ---
echo "[INFO] Instalace Mosquitto a MQTT nástrojů..."
sudo apt install -y mosquitto mosquitto-clients

# --- Workflow nástroje ---
sudo apt install -y tmuxinator tmate

# --- Kontrola a vytvoření uživatele starko ---
if ! id -u starko > /dev/null 2>&1; then
    echo "[INFO] Vytvářím uživatele starko..."
    sudo adduser --disabled-password --gecos "" starko
    sudo usermod -aG sudo starko
fi

# --- Nastavení domovského adresáře již proběhlo při instalaci, kontrola: ---
echo "[INFO] Domovský adresář starko: $HOME"

# --- Automatická záloha WSL ---
WSL_DISTRO=$(wsl -l -v | grep '*' | awk '{print $1}')
SNAPSHOT_NAME="${WSL_DISTRO}_backup_$(date +%Y%m%d_%H%M%S).tar"
wsl --export "$WSL_DISTRO" "/mnt/w/${SNAPSHOT_NAME}"
echo "[INFO] Snapshot uložen do W:/$SNAPSHOT_NAME"

# --- Kontrola nainstalovaných balíčků ---
echo "[INFO] Kontrola verzí..."
docker --version
docker-compose --version
waydroid --version
tmux -V
borg --version
rclone --version
mosquitto -h

# --- Dokončení ---
echo "[INFO] Všechny moduly nainstalovány a nastaveny!"
echo "[INFO] Restartujte WSL pro aktivaci Docker, Zsh a Waydroid."
EOF
