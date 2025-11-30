#!/usr/bin/env bash
set -e

DISTRO_NAME=$(lsb_release -si 2>/dev/null || echo "Unknown")
USER_NAME=$(whoami)
WSL_HOME="/home/$USER_NAME"
WIN_HOME_MOUNT="/mnt/c/Users/$USER_NAME"
TARGET_W_HOME="/mnt/w/$DISTRO_NAME/home"

echo "======================================"
echo "     WSL AUTO-FIX PRO — START"
echo "======================================"
echo "[INFO] Distribuce: $DISTRO_NAME"
echo "[INFO] Uživatel: $USER_NAME"
echo

# ----------------------------------------
# 1) Kontrola správného HOME
# ----------------------------------------
echo "[CHECK] Kontroluji HOME..."

CURRENT_PWD=$(pwd)
if [[ "$CURRENT_PWD" == /mnt/c/* ]]; then
    echo "[WARN] Jsi ve Windows cestě: $CURRENT_PWD"
    echo "[FIX] Přesouvám do skutečné HOME..."
    cd $WSL_HOME
fi

echo "[OK] Aktuální cesta: $(pwd)"
echo

# ----------------------------------------
# 2) Kontrola existence /home/<user>
# ----------------------------------------
echo "[CHECK] Kontroluji existenci $WSL_HOME..."

if [ ! -d "$WSL_HOME" ]; then
    echo "[FIX] HOME neexistuje → vytvářím..."
    sudo mkdir -p "$WSL_HOME"
    sudo chown "$USER_NAME:$USER_NAME" "$WSL_HOME"
else
    echo "[OK] HOME existuje."
fi
echo

# ----------------------------------------
# 3) Kontrola a vytvoření cílové složky W:\<distro>\home
# ----------------------------------------
echo "[CHECK] Kontrola cílové Windows složky: $TARGET_W_HOME..."

if [ ! -d "$TARGET_W_HOME" ]; then
    echo "[FIX] Vytvářím $TARGET_W_HOME..."
    sudo mkdir -p "$TARGET_W_HOME"
fi

sudo chown -R "$USER_NAME:$USER_NAME" "$TARGET_W_HOME"
echo "[OK] Cíl připraven."
echo

# ----------------------------------------
# 4) Symlink /home/<user> → W:/<distro>/home
# ----------------------------------------
echo "[CHECK] Kontroluji symlink HOME..."

if [ ! -L "$WSL_HOME" ]; then
    echo "[FIX] Záloha původního HOME..."
    sudo mkdir -p /home/backup
    sudo mv $WSL_HOME /home/backup/$USER_NAME-$(date +%s) || true

    echo "[FIX] Vytvářím symlink..."
    sudo ln -s "$TARGET_W_HOME" "$WSL_HOME"
else
    echo "[OK] Symlink již existuje."
fi
echo

# ----------------------------------------
# 5) Oprava /etc/wsl.conf
# ----------------------------------------
echo "[CHECK] Kontrola /etc/wsl.conf..."

sudo bash -c 'cat > /etc/wsl.conf' <<EOF
[user]
default=starko

[automount]
enabled=true
root=/mnt/
options="metadata,umask=22,fmask=11"

[interop]
appendWindowsPath=false
EOF

echo "[OK] wsl.conf bylo opraveno!"
echo

# ----------------------------------------
# 6) Otestuj, že HOME funguje
# ----------------------------------------
echo "[CHECK] Test HOME..."

cd ~
TEST_PATH=$(pwd)

if [[ "$TEST_PATH" == "$WSL_HOME" ]]; then
    echo "[OK] HOME se načítá správně."
else
    echo "[ERR] HOME se nenačítá správně: $TEST_PATH"
fi
echo

# ----------------------------------------
# 7) Restart WSL
# ----------------------------------------
echo "[INFO] Restart WSL je nutný pro aplikaci změn."
echo "======================================"
echo "   WSL AUTO-FIX PRO — HOTOVO"
echo "======================================"
