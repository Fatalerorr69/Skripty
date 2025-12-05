#!/bin/bash
# ===============================================================
# fix_scripts.sh – Oprava systému Twister Smart Suite
# Autor: Starko (2025)
# ===============================================================

set -euo pipefail
IFS=$'\n\t'

echo "🔧 Spouštím opravný modul fix_scripts.sh..."
sleep 1

# ------------------ Oprava spouštěčů ------------------
echo "📁 Opravuji ikonové spouštěče..."

LAUNCHDIR="/usr/local/bin"
sudo mkdir -p $LAUNCHDIR

declare -A SHORTCUTS=(
  ["games"]="retroarch"
  ["media"]="vlc"
  ["tools"]="btop"
  ["office"]="libreoffice"
  ["system"]="xfce4-settings-manager"
  ["internet"]="chromium-browser"
)

for n in "${!SHORTCUTS[@]}"; do
    f="$LAUNCHDIR/twister-$n"
    echo "#!/bin/bash" | sudo tee $f >/dev/null
    echo "lxterminal -e '${SHORTCUTS[$n]}'" | sudo tee -a $f >/dev/null
    sudo chmod +x $f
done

sudo update-desktop-database || true

# ------------------ Conky ------------------
echo "📊 Kontrola Conky..."

if ! pgrep -x conky >/dev/null; then
    nohup conky >/dev/null 2>&1 &
fi

# ------------------ VNC ------------------
echo "🖥 Kontrola VNC serveru..."
sudo systemctl enable vncserver-x11-serviced.service
sudo systemctl start vncserver-x11-serviced.service

# ------------------ Docker ------------------
echo "🐳 Docker kontejner test..."
sudo systemctl enable docker
sudo systemctl start docker
sudo docker ps >/dev/null || echo "⚠ Docker běží, ale žádné kontejnery nejsou aktivní"

# ------------------ Dashboard ------------------
echo "🌐 Web Dashboard..."
if ! pgrep -f "http-server ~/twister-dashboard" > /dev/null; then
    nohup http-server ~/twister-dashboard -p 8080 >/dev/null 2>&1 &
fi

echo "✅ fix_scripts.sh: Hotovo!"
