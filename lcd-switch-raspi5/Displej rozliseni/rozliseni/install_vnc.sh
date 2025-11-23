#!/bin/bash
# === Ultimátní VNC Auto Resize - Kompletní instalace v jednom skriptu ===
# Autor: Starko
# Verze: 2.2
set -e

if [[ $EUID -ne 0 ]]; then
    echo "❌ Spusť skript jako root (sudo)."
    exit 1
fi

# Zajištění potřebných závislostí pro PyQt6
echo "📦 Aktualizuji systém a instaluji balíčky..."
apt update && apt full-upgrade -y
apt install -y python3-pyqt6 realvnc-vnc-server x11-xserver-utils bc

# Nastavení KMS ovladače a VNC
echo "⚙️ Nastavuji KMS ovladač a povoluji VNC..."
raspi-config nonint do_gldriver KMS
raspi-config nonint do_vnc 0

# Konfigurace VNC serveru
VNC_CFG="/root/.vnc/config.d/vncserver-x11"
mkdir -p "$(dirname "$VNC_CFG")"
cat > "$VNC_CFG" <<EOF
Authentication=VncAuth
Encryption=AlwaysOff
EnableAutoAdjust=1
DesktopSizeDynamic=1
EOF

# === Vytváření pomocných skriptů ===
LAST_RES_FILE="/var/lib/vnc-last-resolution"
SMART_SCRIPT="/usr/local/bin/vnc-smart-resize"
LIVE_SCRIPT="/usr/local/bin/vnc-live-resize"
LOAD_SCRIPT="/usr/local/bin/vnc-load-last-res"

# Skript pro chytré přizpůsobení
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
fi
EOC
chmod +x "$SMART_SCRIPT"

# Skript pro Live monitor
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

# Skript pro načtení posledního rozlišení
cat > "$LOAD_SCRIPT" <<'EOL'
#!/bin/bash
LAST_RES_FILE="/var/lib/vnc-last-resolution"
if [ -f "$LAST_RES_FILE" ]; then
    RES=$(cat "$LAST_RES_FILE")
    if xrandr | grep -q "$RES"; then
        xrandr --output $(xrandr | grep -w connected | awk '{print $1}') --mode "$RES"
    fi
fi
EOL
chmod +x "$LOAD_SCRIPT"

# === Vytvoření GUI aplikace a ikony ===
APP_PATH="/usr/local/bin/vnc_res_manager.py"
ICON_PATH="/usr/share/applications/vnc_res_manager.desktop"

# Kód GUI aplikace
cat > "$APP_PATH" <<'EOF'
#!/usr/bin/env python3
import sys
import os
import subprocess
from PyQt6.QtWidgets import (
    QApplication, QWidget, QVBoxLayout, QLabel, QPushButton,
    QComboBox, QHBoxLayout, QMessageBox, QCheckBox, QLineEdit,
    QDialog, QDialogButtonBox
)
from PyQt6.QtGui import QIcon, QFont
from PyQt6.QtCore import Qt, QTimer

LAST_RES_FILE = "/var/lib/vnc-last-resolution"
VNC_XSTARTUP_DIR = "/etc/vnc/xstartup.d"
LIVE_SCRIPT_PATH = "/usr/local/bin/vnc-live-resize"
LOAD_SCRIPT_PATH = "/usr/local/bin/vnc-load-last-res"
SMART_SCRIPT_PATH = "/usr/local/bin/vnc-smart-resize"

PROFILES = {
    "4K (3840x2160)": "3840x2160",
    "FullHD (1920x1080)": "1920x1080",
    "HD (1280x720)": "1280x720",
    "Minimal (1024x768)": "1024x768"
}

class VNCManager(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("VNC Resolution Manager")
        self.setWindowIcon(QIcon.fromTheme("display"))
        self.setGeometry(400, 200, 500, 300)
        self.available_resolutions = self.get_available_resolutions()
        layout = QVBoxLayout()
        layout.setSpacing(15)

        status_label = QLabel("Stav VNC:")
        status_label.setFont(QFont("Arial", 12, QFont.Weight.Bold))
        layout.addWidget(status_label)
        self.current_label = QLabel("Aktuální rozlišení: Načítám...")
        self.current_label.setFont(QFont("Arial", 10))
        layout.addWidget(self.current_label)

        vnc_controls_layout = QHBoxLayout()
        self.start_vnc = QPushButton("Spustit VNC")
        self.start_vnc.clicked.connect(lambda: self.vnc_service("start"))
        self.stop_vnc = QPushButton("Zastavit VNC")
        self.stop_vnc.clicked.connect(lambda: self.vnc_service("stop"))
        self.restart_vnc = QPushButton("Restartovat VNC")
        self.restart_vnc.clicked.connect(lambda: self.vnc_service("restart"))
        vnc_controls_layout.addWidget(self.start_vnc)
        vnc_controls_layout.addWidget(self.stop_vnc)
        vnc_controls_layout.addWidget(self.restart_vnc)
        layout.addLayout(vnc_controls_layout)

        profile_label = QLabel("Profily rozlišení:")
        profile_label.setFont(QFont("Arial", 12, QFont.Weight.Bold))
        layout.addWidget(profile_label)
        hlayout = QHBoxLayout()
        self.profile_box = QComboBox()
        for name in PROFILES.keys():
            self.profile_box.addItem(name)
        hlayout.addWidget(self.profile_box)
        self.apply_button = QPushButton("Použít profil")
        self.apply_button.clicked.connect(self.apply_profile)
        hlayout.addWidget(self.apply_button)
        layout.addLayout(hlayout)

        self.custom_button = QPushButton("Zadat vlastní rozlišení")
        self.custom_button.clicked.connect(self.set_custom_resolution)
        layout.addWidget(self.custom_button)

        self.live_checkbox = QCheckBox("Povolit Live Resize při připojení")
        self.live_checkbox.stateChanged.connect(self.toggle_live_resize)
        layout.addWidget(self.live_checkbox)

        self.setLayout(layout)
        self.update_status()
        self.timer = QTimer(self)
        self.timer.timeout.connect(self.update_status)
        self.timer.start(5000)

    def update_status(self):
        try:
            result = subprocess.run(
                ["xrandr", "--current"], capture_output=True, text=True, check=True
            )
            current_line = [
                line for line in result.stdout.split('\n') if '*' in line
            ]
            if current_line:
                current_resolution = current_line[0].split()[0]
                self.current_label.setText(f"Aktuální rozlišení: {current_resolution}")
            else:
                self.current_label.setText("Aktuální rozlišení: Nelze zjistit")
        except (subprocess.CalledProcessError, FileNotFoundError):
            self.current_label.setText("Aktuální rozlišení: Chyba zjištění")

        live_enabled = False
        if os.path.exists(os.path.join(VNC_XSTARTUP_DIR, "10-smart-resize")):
            with open(os.path.join(VNC_XSTARTUP_DIR, "10-smart-resize"), 'r') as f:
                if "vnc-live-resize" in f.read():
                    live_enabled = True
        self.live_checkbox.setChecked(live_enabled)

    def vnc_service(self, action):
        try:
            subprocess.run(
                ["sudo", "systemctl", action, "vncserver-x11-serviced"],
                check=True,
                capture_output=True,
                text=True
            )
            QMessageBox.information(self, "VNC Service", f"Služba VNC byla úspěšně {action}ována.")
        except subprocess.CalledProcessError as e:
            QMessageBox.critical(self, "Chyba", f"Nepodařilo se {action} VNC službu: {e.stderr}")
        self.update_status()

    def get_available_resolutions(self):
        try:
            result = subprocess.run(
                ["xrandr"], capture_output=True, text=True, check=True
            )
            resolutions = [
                line.split()[0] for line in result.stdout.split('\n') if " " in line and "*" not in line and line.strip() and "connected" not in line
            ]
            unique_resolutions = sorted(list(set(resolutions)), key=lambda x: int(x.split('x')[0]), reverse=True)
            return unique_resolutions
        except (subprocess.CalledProcessError, FileNotFoundError):
            return []

    def set_resolution(self, resolution):
        if not resolution in self.available_resolutions:
            QMessageBox.warning(self, "Neplatné rozlišení", f"Rozlišení '{resolution}' není podporováno vaším zařízením.")
            return False

        try:
            subprocess.run(
                ["sudo", "xrandr", "--output", "Virtual-1", "--mode", resolution],
                check=True,
                capture_output=True,
                text=True
            )
            with open(LAST_RES_FILE, "w") as f:
                f.write(resolution)
            QMessageBox.information(self, "Úspěch", f"Rozlišení bylo nastaveno na {resolution}.")
            self.update_status()
            return True
        except subprocess.CalledProcessError as e:
            QMessageBox.critical(self, "Chyba", f"Nepodařilo se nastavit rozlišení: {e.stderr}")
            return False

    def apply_profile(self):
        selected_profile_name = self.profile_box.currentText()
        resolution = PROFILES.get(selected_profile_name)
        if resolution:
            self.set_resolution(resolution)

    def set_custom_resolution(self):
        dialog = QDialog(self)
        dialog.setWindowTitle("Zadat vlastní rozlišení")
        dialog.setGeometry(self.geometry().x() + 50, self.geometry().y() + 50, 300, 100)
        layout = QVBoxLayout()
        dialog_label = QLabel("Zadejte rozlišení (např. 1920x1080):")
        resolution_input = QLineEdit()
        layout.addWidget(dialog_label)
        layout.addWidget(resolution_input)
        button_box = QDialogButtonBox(QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel)
        button_box.accepted.connect(dialog.accept)
        button_box.rejected.connect(dialog.reject)
        layout.addWidget(button_box)
        dialog.setLayout(layout)
        if dialog.exec() == QDialog.DialogCode.Accepted:
            custom_res = resolution_input.text()
            if custom_res:
                self.set_resolution(custom_res)

    def toggle_live_resize(self, state):
        xstartup_file = os.path.join(VNC_XSTARTUP_DIR, "10-smart-resize")
        if not os.path.exists(VNC_XSTARTUP_DIR):
            os.makedirs(VNC_XSTARTUP_DIR)
        if state == Qt.CheckState.Checked:
            content = f"""#!/bin/bash
sleep 2
{LOAD_SCRIPT_PATH} &
{SMART_SCRIPT_PATH} &
{LIVE_SCRIPT_PATH} &
"""
        else:
            content = f"""#!/bin/bash
sleep 2
{LOAD_SCRIPT_PATH} &
"""
        try:
            with open(xstartup_file, "w") as f:
                f.write(content)
            os.chmod(xstartup_file, 0o755)
            QMessageBox.information(self, "Nastavení Live Resize", "Nastavení bylo uloženo. Pro plné uplatnění restartujte VNC server.")
        except IOError as e:
            QMessageBox.critical(self, "Chyba zápisu", f"Nepodařilo se uložit nastavení Live Resize: {e}")

if __name__ == '__main__':
    app = QApplication(sys.argv)
    if os.geteuid() != 0:
        QMessageBox.critical(None, "Chyba oprávnění", "Aplikace musí být spuštěna s administrátorskými právy (sudo).")
        sys.exit(1)
    ex = VNCManager()
    ex.show()
    sys.exit(app.exec())
EOF
chmod +x "$APP_PATH"

# Kód ikony pro menu
cat > "$ICON_PATH" <<EOF
[Desktop Entry]
Name=VNC Resolution Manager
Comment=Spravujte rozlišení a nastavení VNC
Exec=sudo python3 $APP_PATH
Icon=display
Terminal=false
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
EOF
chmod +x "$AUTOSTART_DIR/10-smart-resize"

echo "♻️ Restart VNC serveru..."
systemctl restart vncserver-x11-serviced

echo "✅ Instalace dokončena!"
echo "ℹ️ Pro spuštění grafického správce klikněte na ikonu 'VNC Resolution Manager' v menu."
echo "   Nebo zadejte do terminálu: sudo python3 $APP_PATH"
echo "💡 Nezapomeňte v klientu VNC Vieweru zapnout 'Scaling: Resize remote session to fit window'."