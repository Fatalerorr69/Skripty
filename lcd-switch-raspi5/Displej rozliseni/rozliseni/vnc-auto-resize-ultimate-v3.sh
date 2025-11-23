#!/bin/bash
# === Raspberry Pi: Ultimátní VNC Auto Resize (Live + Memory + Profiles) ===
# Autor: Starko
# Verze: 7.0

set -e

if [[ $EUID -ne 0 ]]; then
    echo "❌ Spusť skript jako root (sudo)."
    exit 1
fi

LAST_RES_FILE="/var/lib/vnc-last-resolution"

echo "📦 Aktualizuji systém..."
apt update && apt full-upgrade -y

echo "🖥 Instaluji balíčky..."
apt install -y realvnc-vnc-server realvnc-vnc-viewer x11-xserver-utils xrandr bc inotify-tools whiptail

echo "📂 Zálohuji konfiguraci..."
mkdir -p /root/vnc-backup
cp -a /root/.vnc /root/vnc-backup/ 2>/dev/null || true

echo "⚙️ Nastavuji KMS ovladač..."
raspi-config nonint do_gldriver KMS

echo "📡 Povoluji VNC..."
raspi-config nonint do_vnc 0

echo "🛠 Konfiguruji VNC server..."
VNC_CFG="/root/.vnc/config.d/vncserver-x11"
mkdir -p "$(dirname "$VNC_CFG")"
cat > "$VNC_CFG" <<EOF
Authentication=VncAuth
Encryption=AlwaysOff
EnableAutoAdjust=1
DesktopSizeDynamic=1
EOF

# === SMART RESIZE skript ===
SMART_SCRIPT="/usr/local/bin/vnc-smart-resize"
cat > "$SMART_SCRIPT" <<'EOC'
#!/bin/bash
LAST_RES_FILE="/var/lib/vnc-last-resolution"
VNC_LOG=$(ls -t /root/.vnc/*.log 2>/dev/null | head -n 1)
CLIENT_SIZE=$(grep -m1 -oP '\d+x\d+' "$VNC_LOG" 2>/dev/null)
[ -z "$CLIENT_SIZE" ] && CLIENT_SIZE="1920x1080"

WIDTH=$(echo $CLIENT_SIZE | cut -d"x" -f1)
HEIGHT=$(echo $CLIENT_SIZE | cut -d"x" -f2)
ASPECT=$(echo "scale=5; $WIDTH/$HEIGHT" | bc)

RES_LIST=$(xrandr | grep -w connected -A1 | tail -n 1 | awk '{print $1}')

BEST_MATCH=""
BEST_DIFF=999
for MODE in $RES_LIST; do
    W=$(echo $MODE | cut -d"x" -f1)
    H=$(echo $MODE | cut -d"x" -f2)
    MODE_ASPECT=$(echo "scale=5; $W/$H" | bc)
    DIFF=$(echo "scale=5; if ($ASPECT>$MODE_ASPECT) $ASPECT-$MODE_ASPECT else $MODE_ASPECT-$ASPECT" | bc)
    if (( $(echo "$DIFF < $BEST_DIFF" | bc -l) )); then
        BEST_DIFF=$DIFF
        BEST_MATCH=$MODE
    fi
done

if [ -n "$BEST_MATCH" ]; then
    xrandr --output $(xrandr | grep -w connected | awk '{print $1}') --mode "$BEST_MATCH"
    echo "$BEST_MATCH" > "$LAST_RES_FILE"
    echo "✅ Rozlišení nastaveno na $BEST_MATCH (okno klienta: $CLIENT_SIZE)"
else
    echo "❌ Nepodařilo se najít vhodné rozlišení."
fi
EOC
chmod +x "$SMART_SCRIPT"

# === LIVE monitor skript ===
LIVE_SCRIPT="/usr/local/bin/vnc-live-resize"
cat > "$LIVE_SCRIPT" <<'EOL'
#!/bin/bash
LAST_RES_FILE="/var/lib/vnc-last-resolution"
VNC_LOG=$(ls -t /root/.vnc/*.log 2>/dev/null | head -n 1)
[ -z "$VNC_LOG" ] && { echo "❌ Log VNC nenalezen."; exit 1; }

tail -F "$VNC_LOG" | while read LINE; do
    if echo "$LINE" | grep -q -oP '\d+x\d+'; then
        /usr/local/bin/vnc-smart-resize
    fi
done
EOL
chmod +x "$LIVE_SCRIPT"

# === LOAD posledního rozlišení ===
LOAD_SCRIPT="/usr/local/bin/vnc-load-last-res"
cat > "$LOAD_SCRIPT" <<'EOL'
#!/bin/bash
LAST_RES_FILE="/var/lib/vnc-last-resolution"
if [ -f "$LAST_RES_FILE" ]; then
    RES=$(cat "$LAST_RES_FILE")
    if xrandr | grep -q "$RES"; then
        xrandr --output $(xrandr | grep -w connected | awk '{print $1}') --mode "$RES"
        echo "🔄 Obnoveno poslední rozlišení: $RES"
    fi
fi
EOL
chmod +x "$LOAD_SCRIPT"

# === PROFIL přepínač ===
PROFILE_SCRIPT="/usr/local/bin/vnc-profile-switcher"
cat > "$PROFILE_SCRIPT" <<'EOL'
#!/bin/bash
# Profily: 4K, FullHD, HD, Minimal
PROFILES=("3840x2160" "1920x1080" "1280x720" "1024x768")
CHOICE=$(whiptail --title "Výběr profilu VNC rozlišení" --menu "Zvol rozlišení:" 15 50 5 \
"1" "4K (3840x2160)" \
"2" "FullHD (1920x1080)" \
"3" "HD (1280x720)" \
"4" "Minimal (1024x768)" 3>&1 1>&2 2>&3)

case $CHOICE in
    1) MODE=${PROFILES[0]} ;;
    2) MODE=${PROFILES[1]} ;;
    3) MODE=${PROFILES[2]} ;;
    4) MODE=${PROFILES[3]} ;;
    *) exit 1 ;;
esac

if xrandr | grep -q "$MODE"; then
    xrandr --output $(xrandr | grep -w connected | awk '{print $1}') --mode "$MODE"
    echo "$MODE" > /var/lib/vnc-last-resolution
    echo "✅ Rozlišení přepnuto na $MODE"
else
    echo "❌ Režim $MODE není podporován."
fi
EOL
chmod +x "$PROFILE_SCRIPT"

# === Ikona pro menu ===
cat > /usr/share/applications/vnc-profile-switcher.desktop <<EOF
[Desktop Entry]
Name=VNC Přepínač rozlišení
Comment=Rychlá změna rozlišení VNC
Exec=$PROFILE_SCRIPT
Icon=display
Terminal=true
Type=Application
Categories=Settings;
EOF

# === Autostart ===
AUTOSTART_DIR="/etc/vnc/xstartup.d"
mkdir -p "$AUTOSTART_DIR"
cat > "$AUTOSTART_DIR/10-smart-resize" <<EOF
#!/bin/bash
sleep 2
$LOAD_SCRIPT &
$SMART_SCRIPT &
$LIVE_SCRIPT &
EOF
chmod +x "$AUTOSTART_DIR/10-smart-resize"

echo "♻️ Restart VNC serveru..."
systemctl restart vncserver-x11-serviced

echo "✅ Instalace dokončena!"
echo "ℹ️ Funkce:"
echo " - Live resize během relace"
echo " - Paměť posledního rozlišení"
echo " - Načtení po startu"
echo " - Přepínání profilů (4K, FullHD, HD, Minimal)"
echo " - Ikona v menu pro rychlou změnu"
