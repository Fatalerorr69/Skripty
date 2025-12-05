#!/bin/bash
# TwisterOS SuperManager - GUI Installer
set -euo pipefail

APP_NAME="TwisterOS SuperManager"
ARCHIVE="twisteros_supermanager.tar.gz"
INSTALL_DIR="/opt/twisteros_supermanager"
BIN_LINK="/usr/local/bin/twsm"
ICON_PATH="/usr/share/icons/twsm.png"

if ! command -v yad >/dev/null 2>&1 ; then
    sudo apt install -y yad
fi

yad --width=500 --center --title="$APP_NAME" \
    --text="<b>Instalátor $APP_NAME</b>\n\nTento instalátor nainstaluje celý systém TwisterOS SuperManager do systému.\n\nPokračovat?" \
    --button="Zrušit:1" --button="Instalovat:0"

if [[ $? -ne 0 ]]; then
    exit 0
fi

if [[ ! -f "$ARCHIVE" ]]; then
    yad --error --title="Chyba" --text="Soubor <b>$ARCHIVE</b> nebyl nalezen!"
    exit 1
fi

(
echo "10"; echo "# Připravuji instalaci…"
sudo mkdir -p "$INSTALL_DIR"
sleep 0.3

echo "30"; echo "# Rozbaluji archiv…"
sudo tar xzf "$ARCHIVE" -C "$INSTALL_DIR" --strip-components=1
sleep 0.5

echo "50"; echo "# Vytvářím spouštěcí příkaz…"
sudo bash -c "cat >/usr/local/bin/twsm" << 'EOF'
#!/bin/bash
/opt/twisteros_supermanager/main.sh "$@"
EOF
sudo chmod +x "$BIN_LINK"

echo "70"; echo "# Nastavuji ikonku a nabídku…"
sudo cp "$INSTALL_DIR/icon.png" "$ICON_PATH" 2>/dev/null || true

sudo bash -c "cat >/usr/share/applications/twsm.desktop" <<EOF
[Desktop Entry]
Name=TwisterOS SuperManager
Exec=twsm
Icon=twsm
Type=Application
Terminal=false
Categories=System;
EOF

echo "90"; echo "# Dokončuji…"
VERSION=$(date +"%Y.%m.%d-%H%M")
echo "$VERSION" | sudo tee /usr/share/twsm/version >/dev/null

sleep 0.3

echo "100"; echo "# Instalace dokončena!"
sleep 0.5
) | yad --progress --title="$APP_NAME" --width=500 --center --no-buttons \
         --auto-close --auto-kill --text="Instaluji…"

yad --info --title="Instalace dokončena" \
    --text="<b>$APP_NAME byl úspěšně nainstalován!</b>\n\nNajdeš jej v nabídce:\n<b>Applications → System Tools → TwisterOS SuperManager</b>"
