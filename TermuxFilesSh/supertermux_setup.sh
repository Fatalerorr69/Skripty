#!/bin/bash
set -e

BOLD="\033[1m"
NC="\033[0m"

log() {
    echo -e "${BOLD}[INFO]${NC} $1"
}

error() {
    echo -e "${BOLD}[ERROR]${NC} $1"
}

# --------------------------------------------------------
# 1) Úvodní kontrola
# --------------------------------------------------------

log "Kontrola Termux prostředí..."

if ! command -v pkg >/dev/null; then
    error "Nejsi v Termuxu! Skript ukončen."
    exit 1
fi

termux-setup-storage || true

# --------------------------------------------------------
# 2) Aktualizace a opravy
# --------------------------------------------------------

log "Provádím aktualizace..."
pkg update -y
pkg upgrade -y

log "Opravuji balíčky..."
pkg install --fix-broken -y || true
pkg clean

# --------------------------------------------------------
# 3) Instalace hlavních repozitářů
# --------------------------------------------------------

log "Aktivuji X11 / Root / Unstable repozitáře..."
pkg install -y x11-repo root-repo unstable-repo

# --------------------------------------------------------
# 4) Instalace nástrojů pro vývoj
# --------------------------------------------------------

log "Instaluji základní nástroje..."
pkg install -y git wget curl nano vim neovim micro

log "Instaluji kompilátory..."
pkg install -y clang cmake make automake autoconf pkg-config

log "Instaluji programovací jazyky..."
pkg install -y python python-pip golang rust nodejs openjdk-17 php

log "Aktualizuji pip..."
pip install --upgrade pip --user

log "Instaluji web dev nástroje..."
npm install -g yarn pm2 http-server n

# --------------------------------------------------------
# 5) Instalace AI modulů
# --------------------------------------------------------

log "Instaluji AI/ML nástroje..."

pip install --user openai
pip install --user transformers tokenizers sentencepiece datasets
pip install --user huggingface_hub
pip install --user onnxruntime

# --------------------------------------------------------
# 6) Reverse engineering / hacking tools
# --------------------------------------------------------

log "Instaluji analýzu Android APK..."
pkg install -y jadx apktool aapt apksigner

log "Instaluji síťové nástroje..."
pkg install -y nmap net-tools hydra hashcat openssh

# --------------------------------------------------------
# 7) GUI / VNC prostředí
# --------------------------------------------------------

log "Instaluji GUI komponenty..."
pkg install -y tigervnc xorg-x11-fonts xorg-x11-server-utils lxde

mkdir -p ~/.vnc
echo "password" | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd

cat > ~/.vnc/xstartup <<EOF
#!/bin/sh
xrdb $HOME/.Xresources
startlxde &
EOF

chmod +x ~/.vnc/xstartup

# --------------------------------------------------------
# 8) Systém údržby a čištění
# --------------------------------------------------------

log "Instaluji pokročilé čištění..."
cat > ~/termux-cleaner.sh << 'EOF'
#!/bin/bash
echo "Čištění systému..."
pkg clean
pip cache purge
npm cache clean --force
rm -rf $HOME/.cache/*
find $HOME -type f -name "*.log" -delete
echo "Hotovo."
EOF

chmod +x ~/termux-cleaner.sh

# --------------------------------------------------------
# 9) Kontrola systému
# --------------------------------------------------------

log "Vytvářím systémový kontrolér..."
cat > ~/termux-diagnose.sh << 'EOF'
#!/bin/bash
echo "== DIAGNOSTIKA TERMUXU =="
echo "[1] DNS test"; nslookup google.com || echo "DNS FAIL"
echo "[2] Internet test"; ping -c 1 8.8.8.8 || echo "NET FAIL"
echo "[3] Storage test"; ls ~/storage || echo "STORAGE FAIL"
echo "[4] Pip test"; pip --version || echo "PIP FAIL"
echo "[5] Node test"; node --version || echo "NODE FAIL"
echo "[6] VNC test"; pgrep Xtigervnc >/dev/null && echo "VNC OK" || echo "VNC STOP"
EOF

chmod +x ~/termux-diagnose.sh

# --------------------------------------------------------
# 10) Dokončení
# --------------------------------------------------------

log "Termux SuperSetup dokončen!"
log "Dostupné nástroje:"
echo "- VNC start: vncserver :1"
echo "- Čištění systému: ./termux-cleaner.sh"
echo "- Diagnostika: ./termux-diagnose.sh"

exit 0
