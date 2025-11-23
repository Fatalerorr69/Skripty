<<<<<<< HEAD
#!/bin/bash
# --- Master build skript pro UltraOS Toolkit (Finalni verze) ---
# Tento skript sestaví kompletní balíček DEB.
set -euo pipefail

# Proměnné
BUILD_DIR="ultraos-toolkit"
PKG_VERSION="1.0.0"

# --- Barvy pro terminálový výstup ---
GREEN='\033[0;32m'
NC='\033[0m' # Bez barvy
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }

log_info "Spouštím sestavení balíčku UltraOS Toolkit verze $PKG_VERSION..."

# --- 1. Sestavení adresářové struktury ---
log_info "Vytvářím adresářovou strukturu..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/DEBIAN"
mkdir -p "$BUILD_DIR/usr/local/bin"
mkdir -p "$BUILD_DIR/etc/systemd/system"
mkdir -p "$BUILD_DIR/usr/share/applications"
mkdir -p "$BUILD_DIR/usr/share/ultraos/scripts"
mkdir -p "$BUILD_DIR/usr/share/ultraos/data"
mkdir -p "$BUILD_DIR/usr/share/ultraos/desktop"
mkdir -p "$BUILD_DIR/etc/vnc/xstartup.d"
mkdir -p "$BUILD_DIR/etc/skel/.config/autostart"

# --- 2. Vytvoření a úprava konfiguračních souborů ---
log_info "Vytvářím konfigurační soubory DEBIAN..."

# DEBIAN/control
cat > "$BUILD_DIR/DEBIAN/control" << EOF
Package: ultraos-toolkit
Version: $PKG_VERSION
Section: utils
Priority: optional
Architecture: all
Maintainer: Starko <starko@ultraos.local>
Depends: systemd-container, wget, tar, coreutils, zenity, yad, realvnc-vnc-server, x11-xserver-utils, bc, xfce4, python3-pyqt6, dos2unix, antimicrox, bluetoothctl, lightdm
Description: UltraOS Toolkit pro Raspberry Pi 5.
 Komplexní sada nástrojů pro správu kontejnerů, VNC, desktopu a Androidu.
EOF

# DEBIAN/postinst (Instalační skript)
cat > "$BUILD_DIR/DEBIAN/postinst" << 'EOF'
#!/bin/sh
set -e

log_info() {
    echo -e "\033[0;32m[INFO]\033[0m $1"
}

log_warn() {
    echo -e "\033[1;33m[VAROVÁNÍ]\033[0m $1" >&2
}

# Oprava konců řádků
log_info "Opravuji konce řádků ve všech skriptech..."
find /usr/local/bin /usr/share/ultraos -type f -exec dos2unix {} \;

# Spouštějící skripty pro kontejner
log_info "Spouštím instalační skript StarkOS..."
/usr/local/bin/install_starkos_lab.sh --no-dialog || log_warn "Instalace kontejneru selhala. Zkontrolujte logy."

# Konfigurace VNC
log_info "Konfiguruji a instaluji VNC server s auto-resize..."
bash /usr/local/bin/vnc_installer.sh || log_warn "Instalace VNC selhala. Pokračuji dál..."

# Konfigurace desktopu XFCE4 (spuštěno uživatelem po prvním přihlášení)
log_info "Konfiguruji desktopové prostředí pro UltraOS..."
cp -r /usr/share/ultraos/desktop/* /etc/skel/.config/ || log_warn "Konfigurace desktopu selhala."

# Konfigurace ovladače
log_info "Konfiguruji ovladač Pegi PG-9157..."
/usr/share/ultraos/scripts/pg9157_abo.sh || log_warn "Konfigurace ovladače selhala."

# Povolení systemd služeb
log_info "Povoluji a spouštím systémové služby..."
systemctl daemon-reload
systemctl enable starkos-container.service
systemctl start starkos-container.service

log_info "UltraOS Toolkit instalace dokončena. Užijte si nový desktop!"

exit 0
EOF
chmod 755 "$BUILD_DIR/DEBIAN/postinst"

# DEBIAN/prerm (Odinstalační skript)
cat > "$BUILD_DIR/DEBIAN/prerm" << 'EOF'
#!/bin/sh
set -e
systemctl disable starkos-container.service || true
systemctl stop starkos-container.service || true
exit 0
EOF
chmod 755 "$BUILD_DIR/DEBIAN/prerm"

# --- 3. Generování skriptů a aplikací ---
log_info "Generuji skripty a aplikace..."

# Hlavní instalační skript kontejneru
# Ponecháváme ho s původními názvy, aby byl přehledný
cp install_starkos_lab.sh "$BUILD_DIR/usr/local/bin/"
chmod 755 "$BUILD_DIR/usr/local/bin/install_starkos_lab.sh"

# Skripty pro VNC
cat > "$BUILD_DIR/usr/local/bin/vnc_installer.sh" << 'EOF'
#!/bin/bash
# === Ultimátní VNC Auto Resize - Kompletní instalace a GUI ===
# Autor: Starko
# Verze: 3.0 (final)
set -e

# Kontrola oprávnění
if [[ $EUID -ne 0 ]]; then
    echo "❌ Spusť skript jako root (sudo)."
    exit 1
fi

# Zajištění závislostí
echo "📦 Aktualizuji systém a instaluji balíčky..."
apt update && apt install -y python3-pyqt6 realvnc-vnc-server x11-xserver-utils bc

# Konfigurace VNC serveru
VNC_CFG="/root/.vnc/config.d/vncserver-x11"
mkdir -p "$(dirname "$VNC_CFG")"
cat > "$VNC_CFG" <<_VNC_EOF_
Authentication=VncAuth
Encryption=AlwaysOff
EnableAutoAdjust=1
DesktopSizeDynamic=1
_VNC_EOF_

# Vytváření pomocných skriptů
LAST_RES_FILE="/var/lib/vnc-last-resolution"
SMART_SCRIPT="/usr/local/bin/vnc-smart-resize"
LIVE_SCRIPT="/usr/local/bin/vnc-live-resize"
LOAD_SCRIPT="/usr/local/bin/vnc-load-last-res"

cat > "$SMART_SCRIPT" <<'EOC'
#!/bin/bash
set -euo pipefail
LAST_RES_FILE="/var/lib/vnc-last-resolution"
VNC_LOG=$(ls -t /root/.vnc/*.log 2>/dev/null | head -n 1)
[ -z "$VNC_LOG" ] && VNC_LOG="/dev/null"
CLIENT_SIZE=$(grep -m1 -oP '\d+x\d+' "$VNC_LOG" 2>/dev/null)
[ -z "$CLIENT_SIZE" ] && CLIENT_SIZE="1920x1080"
WIDTH=$(echo "$CLIENT_SIZE" | cut -d"x" -f1)
HEIGHT=$(echo "$CLIENT_SIZE" | cut -d"x" -f2)
ASPECT=$(echo "scale=5; $WIDTH/$HEIGHT" | bc)
RES_LIST=$(xrandr | grep -w connected -A1 | tail -n 1 | awk '{print $1}')
BEST_MATCH=""
BEST_DIFF=999
for MODE in $RES_LIST; do
    W=$(echo "$MODE" | cut -d"x" -f1)
    H=$(echo "$MODE" | cut -d"x" -f2)
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
fi
EOC
chmod +x "$SMART_SCRIPT"

cat > "$LIVE_SCRIPT" <<'EOL'
#!/bin/bash
set -euo pipefail
LAST_RES_FILE="/var/lib/vnc-last-resolution"
VNC_LOG=$(ls -t /root/.vnc/*.log 2>/dev/null | head -n 1)
[ -z "$VNC_LOG" ] && { echo "Log VNC nenalezen."; exit 1; }
tail -F "$VNC_LOG" | while read LINE; do
    if echo "$LINE" | grep -q -oP '\d+x\d+'; then
        /usr/local/bin/vnc-smart-resize
    fi
done
EOL
chmod +x "$LIVE_SCRIPT"

cat > "$LOAD_SCRIPT" <<'EOL'
#!/bin/bash
set -euo pipefail
LAST_RES_FILE="/var/lib/vnc-last-resolution"
if [ -f "$LAST_RES_FILE" ]; then
    RES=$(cat "$LAST_RES_FILE")
    if xrandr | grep -q "$RES"; then
        xrandr --output $(xrandr | grep -w connected | awk '{print $1}') --mode "$RES"
    fi
fi
EOL
chmod +x "$LOAD_SCRIPT"

# --- Python GUI aplikace pro VNC ---
APP_PATH="/usr/local/bin/vnc_manager.py"
ICON_PATH="/usr/share/applications/vnc_manager.desktop"

cat > "$APP_PATH" <<'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import sys
import os
import subprocess
from PyQt6.QtWidgets import (
    QApplication, QWidget, QVBoxLayout, QLabel, QPushButton,
    QComboBox, QHBoxLayout, QMessageBox, QCheckBox
)
from PyQt6.QtGui import QIcon, QFont
from PyQt6.QtCore import Qt

class VNCManager(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("VNC Resolution Manager")
        self.setWindowIcon(QIcon.fromTheme("display"))
        self.setGeometry(400, 300, 450, 300)
        self.layout = QVBoxLayout()

        self.label = QLabel("Správce rozlišení VNC")
        self.label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.label.setFont(QFont("Arial", 16))
        self.layout.addWidget(self.label)

        manual_layout = QHBoxLayout()
        self.resolution_combo = QComboBox()
        self.resolution_combo.addItems(["4K (3840x2160)", "FullHD (1920x1080)", "HD (1280x720)", "Minimal (1024x768)"])
        self.resolution_button = QPushButton("Nastavit rozlišení")
        self.resolution_button.clicked.connect(self.set_resolution)
        manual_layout.addWidget(QLabel("Ruční nastavení:"))
        manual_layout.addWidget(self.resolution_combo)
        manual_layout.addWidget(self.resolution_button)
        self.layout.addLayout(manual_layout)

        self.auto_res_button = QPushButton("Spustit automatické přizpůsobení (Živě)")
        self.auto_res_button.clicked.connect(self.run_live_resize_script)
        self.layout.addWidget(self.auto_res_button)

        autostart_layout = QHBoxLayout()
        self.autostart_checkbox = QCheckBox("Povolit autostart skriptu při spuštění")
        self.autostart_checkbox.stateChanged.connect(self.toggle_autostart)
        self.update_autostart_state()
        autostart_layout.addWidget(self.autostart_checkbox)
        self.layout.addLayout(autostart_layout)

        self.setLayout(self.layout)

    def run_script_with_sudo(self, script_path, *args):
        try:
            command = ["pkexec", "bash", script_path] + list(args)
            subprocess.run(command, check=True, text=True)
            return True
        except subprocess.CalledProcessError as e:
            QMessageBox.critical(self, "Chyba oprávnění", f"Nepodařilo se spustit skript s právy root: {e}")
            return False
        except FileNotFoundError:
            QMessageBox.critical(self, "Chyba", f"Skript nebyl nalezen: {script_path}")
            return False

    def set_resolution(self):
        selected_text = self.resolution_combo.currentText()
        resolution = selected_text.split(" ")[0].strip()
        script_path = "/usr/local/bin/vnc-load-last-res"
        if self.run_script_with_sudo(script_path, resolution):
            QMessageBox.information(self, "Úspěch", f"Rozlišení nastaveno na {resolution}.")

    def run_live_resize_script(self):
        # Spuštění live resize jako pozadí, není potřeba pkexec
        try:
            subprocess.Popen(["/usr/local/bin/vnc-live-resize"])
            QMessageBox.information(self, "Úspěch", "Automatické přizpůsobení spuštěno na pozadí.")
        except FileNotFoundError:
            QMessageBox.critical(self, "Chyba", "Skript pro live resize nebyl nalezen.")

    def toggle_autostart(self, state):
        autostart_path = "/etc/vnc/xstartup.d/99-live-resize.sh"
        if state == Qt.CheckState.Checked:
            content = f'#!/bin/sh\n\n/usr/local/bin/vnc-live-resize &\n'
            try:
                with open(autostart_path, "w") as f:
                    f.write(content)
                os.chmod(autostart_path, 0o755)
                QMessageBox.information(self, "Autostart", "Autostart povolen.")
            except IOError as e:
                QMessageBox.critical(self, "Chyba zápisu", f"Nepodařilo se povolit autostart: {e}")
                self.autostart_checkbox.setChecked(False)
        else:
            try:
                if os.path.exists(autostart_path):
                    os.remove(autostart_path)
                QMessageBox.information(self, "Autostart", "Autostart zakázán.")
            except IOError as e:
                QMessageBox.critical(self, "Chyba zápisu", f"Nepodařilo se zakázat autostart: {e}")
                self.autostart_checkbox.setChecked(True)

    def update_autostart_state(self):
        autostart_path = "/etc/vnc/xstartup.d/99-live-resize.sh"
        if os.path.exists(autostart_path):
            self.autostart_checkbox.setChecked(True)
        else:
            self.autostart_checkbox.setChecked(False)

if __name__ == '__main__':
    app = QApplication(sys.argv)
    window = VNCManager()
    window.show()
    sys.exit(app.exec())
EOF
chmod 755 "$BUILD_DIR/usr/local/bin/vnc_manager.py"
cat > "$BUILD_DIR/usr/share/applications/vnc_manager.desktop" << 'EOF'
[Desktop Entry]
Name=UltraOS VNC Manager
Comment=Spravuje rozlišení a nastavení VNC
Exec=gksu /usr/local/bin/vnc_manager.py
Icon=display
Terminal=false
Type=Application
Categories=Settings;
EOF

# Vytvoření skriptu pro desktop (customize_ultraos_desktop.sh)
cat > "$BUILD_DIR/usr/share/ultraos/scripts/customize_ultraos_desktop.sh" << 'EOF'
#!/usr/bin/env bash
# Skript pro automatickou úpravu plochy UltraOS (témata, ikony, pozadí, dock, kompozitor)
set -euo pipefail

# Barvy pro logování
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[VAROVÁNÍ]${NC} $1" >&2; }
log_error() { echo -e "${RED}[CHYBA]${NC} $1" >&2; exit 1; }

# Kontrola XFCE
if ! command -v xfconf-query &> /dev/null; then
    log_error "Nástroj 'xfconf-query' nebyl nalezen. Ujistěte se, že používáte XFCE4."
fi

# Tapeta
log_info "Nastavuji tapetu..."
WALLPAPER_URL="http://googleusercontent.com/image_generation_content/0" # nahraď za reálnou URL
WALLPAPER_FILENAME="ultraos_wallpaper.png"
WALLPAPER_DIR="${HOME}/.local/share/backgrounds"
mkdir -p "$WALLPAPER_DIR"
wget -q -O "${WALLPAPER_DIR}/${WALLPAPER_FILENAME}" "$WALLPAPER_URL" || log_warn "Nepodařilo se stáhnout tapetu. Nastavuji výchozí."
xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/last-image -s "${WALLPAPER_DIR}/${WALLPAPER_FILENAME}"

# Téma (předpokládáme, že je nainstalované)
log_info "Nastavuji témata a ikony..."
xfconf-query -c xsettings -p /Net/ThemeName -s "Adwaita-dark"
xfconf-query -c xsettings -p /Net/IconThemeName -s "Tela-dark"

# Panel
log_info "Konfiguruji panel..."
PANEL_ID=$(xfconf-query -c xfce4-panel -p /panels -l | head -n 1 | awk -F'/' '{print $3}')
xfconf-query -c xfce4-panel -p "/panels/${PANEL_ID}/position" -s "bottom"
xfconf-query -c xfce4-panel -p "/panels/${PANEL_ID}/size" -s "35"

# Konfigurace autostartu
log_info "Nastavuji autostart pro spouštěče..."
mkdir -p "${HOME}/.config/autostart"
cat > "${HOME}/.config/autostart/vnc-manager.desktop" << _VNC_DESKTOP_
[Desktop Entry]
Type=Application
Exec=gksu /usr/local/bin/vnc_manager.py
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=VNC Manager
Comment=Správce VNC
_VNC_DESKTOP_

# Konfigurace Picomu
log_info "Nastavuji Picom Kompozitor pro vizuální efekty..."
mkdir -p "${HOME}/.config/picom"
cat > "${HOME}/.config/picom/picom.conf" << _PICOM_CONF_
backend = "glx";
vsync = true;
shadow = true;
shadow-radius = 7;
shadow-opacity = 0.75;
shadow-offset-x = -7;
shadow-offset-y = -7;
fading = true;
fade-delta = 4;
fade-in-step = 0.03;
fade-out-step = 0.03;
opacity-rule = [ "80:class_g = 'Alacritty'" ];
_PICOM_CONF_
cat > "${HOME}/.config/autostart/picom.desktop" << _PICOM_DESKTOP_
[Desktop Entry]
Type=Application
Exec=picom --config ~/.config/picom/picom.conf
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Picom
Comment=A lightweight compositor
_PICOM_DESKTOP_

log_info "Úprava desktopu dokončena!"
EOF
chmod 755 "$BUILD_DIR/usr/share/ultraos/scripts/customize_ultraos_desktop.sh"

# Skript pro Gamepad PG-9157
cat > "$BUILD_DIR/usr/share/ultraos/scripts/pg9157_abo.sh" << 'EOF'
#!/bin/bash
set -e
log_info() { echo -e "\033[0;32m[INFO]\033[0m $1"; }
log_warn() { echo -e "\033[1;33m[VAROVÁNÍ]\033[0m $1" >&2; }
log_info "Instalace a konfigurace antimicrox pro ovladač PG-9157..."
apt install -y antimicrox
mkdir -p "$HOME/gamepad_profiles"
cat > "$HOME/gamepad_profiles/pg9157-desktop.amgp" << _GAMECFG_
{
  "version": 2,
  "controller": "Gamepad",
  "stickConfigs": {
    "0": { "xAxis": { "mouse": true }, "yAxis": { "mouse": true } }
  },
  "mappings": {
    "0": { "click": 1 }, "1": { "click": 3 }, "2": { "keys": ["C", "LCTRL"] },
    "3": { "keys": ["V", "LCTRL"] }, "4": { "scroll": -1 }, "5": { "scroll": 1 },
    "6": { "keys": ["ESC"] }, "7": { "keys": ["ENTER"] }, "11": { "keys": ["UP"] },
    "12": { "keys": ["DOWN"] }, "13": { "keys": ["LEFT"] }, "14": { "keys": ["RIGHT"] }
  }
}
_GAMECFG_
mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/antimicrox-pg9157.desktop" << _AUTOSTART_
[Desktop Entry]
Type=Application
Exec=antimicrox -p ~/gamepad_profiles/pg9157-desktop.amgp
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=PG-9157 Gamepad
Comment=Spustí profil pro ovládání desktopu gamepadem
_AUTOSTART_
log_info "Konfigurace ovladače dokončena. Profil se spustí po přihlášení."
EOF
chmod 755 "$BUILD_DIR/usr/share/ultraos/scripts/pg9157_abo.sh"

# Skripty z předchozích částí (vylepšené a upravené pro umístění v balíčku)
cp gui.sh "$BUILD_DIR/usr/share/ultraos/scripts/"
cp udrzba.sh "$BUILD_DIR/usr/share/ultraos/scripts/"
cp ai_advisor.sh "$BUILD_DIR/usr/share/ultraos/scripts/"
cp detect_device.sh "$BUILD_DIR/usr/share/ultraos/scripts/"
cp frp_samsung.sh "$BUILD_DIR/usr/share/ultraos/scripts/"
cp backup-config.sh "$BUILD_DIR/usr/share/ultraos/scripts/"
cp lcd-off.sh "$BUILD_DIR/usr/share/ultraos/scripts/"
cp lcd-on.sh "$BUILD_DIR/usr/share/ultraos/scripts/"

# Generování .desktop souborů pro spouštění
cat > "$BUILD_DIR/usr/share/applications/ultraos-gui.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Name=UltraOS Android Toolkit
Comment=Hlavní nástroje pro správu Android zařízení
Exec=bash /usr/share/ultraos/scripts/gui.sh
Icon=android
Terminal=false
Type=Application
Categories=System;
EOF

cat > "$BUILD_DIR/usr/share/applications/ultraos-udrzba.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Name=UltraOS Údržba Systému
Comment=Nástroje pro údržbu a čištění systému
Exec=gksu bash /usr/share/ultraos/scripts/udrzba.sh
Icon=utilities-system-monitor
Terminal=false
Type=Application
Categories=System;
EOF

# --- 4. Sestavení balíčku .deb ---
log_info "Sestavuji finální balíček DEB..."
dpkg-deb --build --root-owner-group "$BUILD_DIR"

log_info "Hotovo! Balíček 'ultraos-toolkit.deb' byl úspěšně vytvořen."
=======
#!/bin/bash
# --- Master build skript pro UltraOS Toolkit (Finalni verze) ---
# Tento skript sestaví kompletní balíček DEB.
set -euo pipefail

# Proměnné
BUILD_DIR="ultraos-toolkit"
PKG_VERSION="1.0.0"

# --- Barvy pro terminálový výstup ---
GREEN='\033[0;32m'
NC='\033[0m' # Bez barvy
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }

log_info "Spouštím sestavení balíčku UltraOS Toolkit verze $PKG_VERSION..."

# --- 1. Sestavení adresářové struktury ---
log_info "Vytvářím adresářovou strukturu..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/DEBIAN"
mkdir -p "$BUILD_DIR/usr/local/bin"
mkdir -p "$BUILD_DIR/etc/systemd/system"
mkdir -p "$BUILD_DIR/usr/share/applications"
mkdir -p "$BUILD_DIR/usr/share/ultraos/scripts"
mkdir -p "$BUILD_DIR/usr/share/ultraos/data"
mkdir -p "$BUILD_DIR/usr/share/ultraos/desktop"
mkdir -p "$BUILD_DIR/etc/vnc/xstartup.d"
mkdir -p "$BUILD_DIR/etc/skel/.config/autostart"

# --- 2. Vytvoření a úprava konfiguračních souborů ---
log_info "Vytvářím konfigurační soubory DEBIAN..."

# DEBIAN/control
cat > "$BUILD_DIR/DEBIAN/control" << EOF
Package: ultraos-toolkit
Version: $PKG_VERSION
Section: utils
Priority: optional
Architecture: all
Maintainer: Starko <starko@ultraos.local>
Depends: systemd-container, wget, tar, coreutils, zenity, yad, realvnc-vnc-server, x11-xserver-utils, bc, xfce4, python3-pyqt6, dos2unix, antimicrox, bluetoothctl, lightdm
Description: UltraOS Toolkit pro Raspberry Pi 5.
 Komplexní sada nástrojů pro správu kontejnerů, VNC, desktopu a Androidu.
EOF

# DEBIAN/postinst (Instalační skript)
cat > "$BUILD_DIR/DEBIAN/postinst" << 'EOF'
#!/bin/sh
set -e

log_info() {
    echo -e "\033[0;32m[INFO]\033[0m $1"
}

log_warn() {
    echo -e "\033[1;33m[VAROVÁNÍ]\033[0m $1" >&2
}

# Oprava konců řádků
log_info "Opravuji konce řádků ve všech skriptech..."
find /usr/local/bin /usr/share/ultraos -type f -exec dos2unix {} \;

# Spouštějící skripty pro kontejner
log_info "Spouštím instalační skript StarkOS..."
/usr/local/bin/install_starkos_lab.sh --no-dialog || log_warn "Instalace kontejneru selhala. Zkontrolujte logy."

# Konfigurace VNC
log_info "Konfiguruji a instaluji VNC server s auto-resize..."
bash /usr/local/bin/vnc_installer.sh || log_warn "Instalace VNC selhala. Pokračuji dál..."

# Konfigurace desktopu XFCE4 (spuštěno uživatelem po prvním přihlášení)
log_info "Konfiguruji desktopové prostředí pro UltraOS..."
cp -r /usr/share/ultraos/desktop/* /etc/skel/.config/ || log_warn "Konfigurace desktopu selhala."

# Konfigurace ovladače
log_info "Konfiguruji ovladač Pegi PG-9157..."
/usr/share/ultraos/scripts/pg9157_abo.sh || log_warn "Konfigurace ovladače selhala."

# Povolení systemd služeb
log_info "Povoluji a spouštím systémové služby..."
systemctl daemon-reload
systemctl enable starkos-container.service
systemctl start starkos-container.service

log_info "UltraOS Toolkit instalace dokončena. Užijte si nový desktop!"

exit 0
EOF
chmod 755 "$BUILD_DIR/DEBIAN/postinst"

# DEBIAN/prerm (Odinstalační skript)
cat > "$BUILD_DIR/DEBIAN/prerm" << 'EOF'
#!/bin/sh
set -e
systemctl disable starkos-container.service || true
systemctl stop starkos-container.service || true
exit 0
EOF
chmod 755 "$BUILD_DIR/DEBIAN/prerm"

# --- 3. Generování skriptů a aplikací ---
log_info "Generuji skripty a aplikace..."

# Hlavní instalační skript kontejneru
# Ponecháváme ho s původními názvy, aby byl přehledný
cp install_starkos_lab.sh "$BUILD_DIR/usr/local/bin/"
chmod 755 "$BUILD_DIR/usr/local/bin/install_starkos_lab.sh"

# Skripty pro VNC
cat > "$BUILD_DIR/usr/local/bin/vnc_installer.sh" << 'EOF'
#!/bin/bash
# === Ultimátní VNC Auto Resize - Kompletní instalace a GUI ===
# Autor: Starko
# Verze: 3.0 (final)
set -e

# Kontrola oprávnění
if [[ $EUID -ne 0 ]]; then
    echo "❌ Spusť skript jako root (sudo)."
    exit 1
fi

# Zajištění závislostí
echo "📦 Aktualizuji systém a instaluji balíčky..."
apt update && apt install -y python3-pyqt6 realvnc-vnc-server x11-xserver-utils bc

# Konfigurace VNC serveru
VNC_CFG="/root/.vnc/config.d/vncserver-x11"
mkdir -p "$(dirname "$VNC_CFG")"
cat > "$VNC_CFG" <<_VNC_EOF_
Authentication=VncAuth
Encryption=AlwaysOff
EnableAutoAdjust=1
DesktopSizeDynamic=1
_VNC_EOF_

# Vytváření pomocných skriptů
LAST_RES_FILE="/var/lib/vnc-last-resolution"
SMART_SCRIPT="/usr/local/bin/vnc-smart-resize"
LIVE_SCRIPT="/usr/local/bin/vnc-live-resize"
LOAD_SCRIPT="/usr/local/bin/vnc-load-last-res"

cat > "$SMART_SCRIPT" <<'EOC'
#!/bin/bash
set -euo pipefail
LAST_RES_FILE="/var/lib/vnc-last-resolution"
VNC_LOG=$(ls -t /root/.vnc/*.log 2>/dev/null | head -n 1)
[ -z "$VNC_LOG" ] && VNC_LOG="/dev/null"
CLIENT_SIZE=$(grep -m1 -oP '\d+x\d+' "$VNC_LOG" 2>/dev/null)
[ -z "$CLIENT_SIZE" ] && CLIENT_SIZE="1920x1080"
WIDTH=$(echo "$CLIENT_SIZE" | cut -d"x" -f1)
HEIGHT=$(echo "$CLIENT_SIZE" | cut -d"x" -f2)
ASPECT=$(echo "scale=5; $WIDTH/$HEIGHT" | bc)
RES_LIST=$(xrandr | grep -w connected -A1 | tail -n 1 | awk '{print $1}')
BEST_MATCH=""
BEST_DIFF=999
for MODE in $RES_LIST; do
    W=$(echo "$MODE" | cut -d"x" -f1)
    H=$(echo "$MODE" | cut -d"x" -f2)
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
fi
EOC
chmod +x "$SMART_SCRIPT"

cat > "$LIVE_SCRIPT" <<'EOL'
#!/bin/bash
set -euo pipefail
LAST_RES_FILE="/var/lib/vnc-last-resolution"
VNC_LOG=$(ls -t /root/.vnc/*.log 2>/dev/null | head -n 1)
[ -z "$VNC_LOG" ] && { echo "Log VNC nenalezen."; exit 1; }
tail -F "$VNC_LOG" | while read LINE; do
    if echo "$LINE" | grep -q -oP '\d+x\d+'; then
        /usr/local/bin/vnc-smart-resize
    fi
done
EOL
chmod +x "$LIVE_SCRIPT"

cat > "$LOAD_SCRIPT" <<'EOL'
#!/bin/bash
set -euo pipefail
LAST_RES_FILE="/var/lib/vnc-last-resolution"
if [ -f "$LAST_RES_FILE" ]; then
    RES=$(cat "$LAST_RES_FILE")
    if xrandr | grep -q "$RES"; then
        xrandr --output $(xrandr | grep -w connected | awk '{print $1}') --mode "$RES"
    fi
fi
EOL
chmod +x "$LOAD_SCRIPT"

# --- Python GUI aplikace pro VNC ---
APP_PATH="/usr/local/bin/vnc_manager.py"
ICON_PATH="/usr/share/applications/vnc_manager.desktop"

cat > "$APP_PATH" <<'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import sys
import os
import subprocess
from PyQt6.QtWidgets import (
    QApplication, QWidget, QVBoxLayout, QLabel, QPushButton,
    QComboBox, QHBoxLayout, QMessageBox, QCheckBox
)
from PyQt6.QtGui import QIcon, QFont
from PyQt6.QtCore import Qt

class VNCManager(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("VNC Resolution Manager")
        self.setWindowIcon(QIcon.fromTheme("display"))
        self.setGeometry(400, 300, 450, 300)
        self.layout = QVBoxLayout()

        self.label = QLabel("Správce rozlišení VNC")
        self.label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.label.setFont(QFont("Arial", 16))
        self.layout.addWidget(self.label)

        manual_layout = QHBoxLayout()
        self.resolution_combo = QComboBox()
        self.resolution_combo.addItems(["4K (3840x2160)", "FullHD (1920x1080)", "HD (1280x720)", "Minimal (1024x768)"])
        self.resolution_button = QPushButton("Nastavit rozlišení")
        self.resolution_button.clicked.connect(self.set_resolution)
        manual_layout.addWidget(QLabel("Ruční nastavení:"))
        manual_layout.addWidget(self.resolution_combo)
        manual_layout.addWidget(self.resolution_button)
        self.layout.addLayout(manual_layout)

        self.auto_res_button = QPushButton("Spustit automatické přizpůsobení (Živě)")
        self.auto_res_button.clicked.connect(self.run_live_resize_script)
        self.layout.addWidget(self.auto_res_button)

        autostart_layout = QHBoxLayout()
        self.autostart_checkbox = QCheckBox("Povolit autostart skriptu při spuštění")
        self.autostart_checkbox.stateChanged.connect(self.toggle_autostart)
        self.update_autostart_state()
        autostart_layout.addWidget(self.autostart_checkbox)
        self.layout.addLayout(autostart_layout)

        self.setLayout(self.layout)

    def run_script_with_sudo(self, script_path, *args):
        try:
            command = ["pkexec", "bash", script_path] + list(args)
            subprocess.run(command, check=True, text=True)
            return True
        except subprocess.CalledProcessError as e:
            QMessageBox.critical(self, "Chyba oprávnění", f"Nepodařilo se spustit skript s právy root: {e}")
            return False
        except FileNotFoundError:
            QMessageBox.critical(self, "Chyba", f"Skript nebyl nalezen: {script_path}")
            return False

    def set_resolution(self):
        selected_text = self.resolution_combo.currentText()
        resolution = selected_text.split(" ")[0].strip()
        script_path = "/usr/local/bin/vnc-load-last-res"
        if self.run_script_with_sudo(script_path, resolution):
            QMessageBox.information(self, "Úspěch", f"Rozlišení nastaveno na {resolution}.")

    def run_live_resize_script(self):
        # Spuštění live resize jako pozadí, není potřeba pkexec
        try:
            subprocess.Popen(["/usr/local/bin/vnc-live-resize"])
            QMessageBox.information(self, "Úspěch", "Automatické přizpůsobení spuštěno na pozadí.")
        except FileNotFoundError:
            QMessageBox.critical(self, "Chyba", "Skript pro live resize nebyl nalezen.")

    def toggle_autostart(self, state):
        autostart_path = "/etc/vnc/xstartup.d/99-live-resize.sh"
        if state == Qt.CheckState.Checked:
            content = f'#!/bin/sh\n\n/usr/local/bin/vnc-live-resize &\n'
            try:
                with open(autostart_path, "w") as f:
                    f.write(content)
                os.chmod(autostart_path, 0o755)
                QMessageBox.information(self, "Autostart", "Autostart povolen.")
            except IOError as e:
                QMessageBox.critical(self, "Chyba zápisu", f"Nepodařilo se povolit autostart: {e}")
                self.autostart_checkbox.setChecked(False)
        else:
            try:
                if os.path.exists(autostart_path):
                    os.remove(autostart_path)
                QMessageBox.information(self, "Autostart", "Autostart zakázán.")
            except IOError as e:
                QMessageBox.critical(self, "Chyba zápisu", f"Nepodařilo se zakázat autostart: {e}")
                self.autostart_checkbox.setChecked(True)

    def update_autostart_state(self):
        autostart_path = "/etc/vnc/xstartup.d/99-live-resize.sh"
        if os.path.exists(autostart_path):
            self.autostart_checkbox.setChecked(True)
        else:
            self.autostart_checkbox.setChecked(False)

if __name__ == '__main__':
    app = QApplication(sys.argv)
    window = VNCManager()
    window.show()
    sys.exit(app.exec())
EOF
chmod 755 "$BUILD_DIR/usr/local/bin/vnc_manager.py"
cat > "$BUILD_DIR/usr/share/applications/vnc_manager.desktop" << 'EOF'
[Desktop Entry]
Name=UltraOS VNC Manager
Comment=Spravuje rozlišení a nastavení VNC
Exec=gksu /usr/local/bin/vnc_manager.py
Icon=display
Terminal=false
Type=Application
Categories=Settings;
EOF

# Vytvoření skriptu pro desktop (customize_ultraos_desktop.sh)
cat > "$BUILD_DIR/usr/share/ultraos/scripts/customize_ultraos_desktop.sh" << 'EOF'
#!/usr/bin/env bash
# Skript pro automatickou úpravu plochy UltraOS (témata, ikony, pozadí, dock, kompozitor)
set -euo pipefail

# Barvy pro logování
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[VAROVÁNÍ]${NC} $1" >&2; }
log_error() { echo -e "${RED}[CHYBA]${NC} $1" >&2; exit 1; }

# Kontrola XFCE
if ! command -v xfconf-query &> /dev/null; then
    log_error "Nástroj 'xfconf-query' nebyl nalezen. Ujistěte se, že používáte XFCE4."
fi

# Tapeta
log_info "Nastavuji tapetu..."
WALLPAPER_URL="http://googleusercontent.com/image_generation_content/0" # nahraď za reálnou URL
WALLPAPER_FILENAME="ultraos_wallpaper.png"
WALLPAPER_DIR="${HOME}/.local/share/backgrounds"
mkdir -p "$WALLPAPER_DIR"
wget -q -O "${WALLPAPER_DIR}/${WALLPAPER_FILENAME}" "$WALLPAPER_URL" || log_warn "Nepodařilo se stáhnout tapetu. Nastavuji výchozí."
xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/last-image -s "${WALLPAPER_DIR}/${WALLPAPER_FILENAME}"

# Téma (předpokládáme, že je nainstalované)
log_info "Nastavuji témata a ikony..."
xfconf-query -c xsettings -p /Net/ThemeName -s "Adwaita-dark"
xfconf-query -c xsettings -p /Net/IconThemeName -s "Tela-dark"

# Panel
log_info "Konfiguruji panel..."
PANEL_ID=$(xfconf-query -c xfce4-panel -p /panels -l | head -n 1 | awk -F'/' '{print $3}')
xfconf-query -c xfce4-panel -p "/panels/${PANEL_ID}/position" -s "bottom"
xfconf-query -c xfce4-panel -p "/panels/${PANEL_ID}/size" -s "35"

# Konfigurace autostartu
log_info "Nastavuji autostart pro spouštěče..."
mkdir -p "${HOME}/.config/autostart"
cat > "${HOME}/.config/autostart/vnc-manager.desktop" << _VNC_DESKTOP_
[Desktop Entry]
Type=Application
Exec=gksu /usr/local/bin/vnc_manager.py
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=VNC Manager
Comment=Správce VNC
_VNC_DESKTOP_

# Konfigurace Picomu
log_info "Nastavuji Picom Kompozitor pro vizuální efekty..."
mkdir -p "${HOME}/.config/picom"
cat > "${HOME}/.config/picom/picom.conf" << _PICOM_CONF_
backend = "glx";
vsync = true;
shadow = true;
shadow-radius = 7;
shadow-opacity = 0.75;
shadow-offset-x = -7;
shadow-offset-y = -7;
fading = true;
fade-delta = 4;
fade-in-step = 0.03;
fade-out-step = 0.03;
opacity-rule = [ "80:class_g = 'Alacritty'" ];
_PICOM_CONF_
cat > "${HOME}/.config/autostart/picom.desktop" << _PICOM_DESKTOP_
[Desktop Entry]
Type=Application
Exec=picom --config ~/.config/picom/picom.conf
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Picom
Comment=A lightweight compositor
_PICOM_DESKTOP_

log_info "Úprava desktopu dokončena!"
EOF
chmod 755 "$BUILD_DIR/usr/share/ultraos/scripts/customize_ultraos_desktop.sh"

# Skript pro Gamepad PG-9157
cat > "$BUILD_DIR/usr/share/ultraos/scripts/pg9157_abo.sh" << 'EOF'
#!/bin/bash
set -e
log_info() { echo -e "\033[0;32m[INFO]\033[0m $1"; }
log_warn() { echo -e "\033[1;33m[VAROVÁNÍ]\033[0m $1" >&2; }
log_info "Instalace a konfigurace antimicrox pro ovladač PG-9157..."
apt install -y antimicrox
mkdir -p "$HOME/gamepad_profiles"
cat > "$HOME/gamepad_profiles/pg9157-desktop.amgp" << _GAMECFG_
{
  "version": 2,
  "controller": "Gamepad",
  "stickConfigs": {
    "0": { "xAxis": { "mouse": true }, "yAxis": { "mouse": true } }
  },
  "mappings": {
    "0": { "click": 1 }, "1": { "click": 3 }, "2": { "keys": ["C", "LCTRL"] },
    "3": { "keys": ["V", "LCTRL"] }, "4": { "scroll": -1 }, "5": { "scroll": 1 },
    "6": { "keys": ["ESC"] }, "7": { "keys": ["ENTER"] }, "11": { "keys": ["UP"] },
    "12": { "keys": ["DOWN"] }, "13": { "keys": ["LEFT"] }, "14": { "keys": ["RIGHT"] }
  }
}
_GAMECFG_
mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/antimicrox-pg9157.desktop" << _AUTOSTART_
[Desktop Entry]
Type=Application
Exec=antimicrox -p ~/gamepad_profiles/pg9157-desktop.amgp
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=PG-9157 Gamepad
Comment=Spustí profil pro ovládání desktopu gamepadem
_AUTOSTART_
log_info "Konfigurace ovladače dokončena. Profil se spustí po přihlášení."
EOF
chmod 755 "$BUILD_DIR/usr/share/ultraos/scripts/pg9157_abo.sh"

# Skripty z předchozích částí (vylepšené a upravené pro umístění v balíčku)
cp gui.sh "$BUILD_DIR/usr/share/ultraos/scripts/"
cp udrzba.sh "$BUILD_DIR/usr/share/ultraos/scripts/"
cp ai_advisor.sh "$BUILD_DIR/usr/share/ultraos/scripts/"
cp detect_device.sh "$BUILD_DIR/usr/share/ultraos/scripts/"
cp frp_samsung.sh "$BUILD_DIR/usr/share/ultraos/scripts/"
cp backup-config.sh "$BUILD_DIR/usr/share/ultraos/scripts/"
cp lcd-off.sh "$BUILD_DIR/usr/share/ultraos/scripts/"
cp lcd-on.sh "$BUILD_DIR/usr/share/ultraos/scripts/"

# Generování .desktop souborů pro spouštění
cat > "$BUILD_DIR/usr/share/applications/ultraos-gui.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Name=UltraOS Android Toolkit
Comment=Hlavní nástroje pro správu Android zařízení
Exec=bash /usr/share/ultraos/scripts/gui.sh
Icon=android
Terminal=false
Type=Application
Categories=System;
EOF

cat > "$BUILD_DIR/usr/share/applications/ultraos-udrzba.desktop" << 'EOF'
[Desktop Entry]
Version=1.0
Name=UltraOS Údržba Systému
Comment=Nástroje pro údržbu a čištění systému
Exec=gksu bash /usr/share/ultraos/scripts/udrzba.sh
Icon=utilities-system-monitor
Terminal=false
Type=Application
Categories=System;
EOF

# --- 4. Sestavení balíčku .deb ---
log_info "Sestavuji finální balíček DEB..."
dpkg-deb --build --root-owner-group "$BUILD_DIR"

log_info "Hotovo! Balíček 'ultraos-toolkit.deb' byl úspěšně vytvořen."
>>>>>>> 2d437cc2ae07a396d41a3b74e61ac94634aea845
log_info "Můžeš ho nainstalovat příkazem: sudo dpkg -i ultraos-toolkit.deb"