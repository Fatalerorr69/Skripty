#!/bin/bash

set -e

echo "=== 🔧 Instalace & konfigurace PEGI PG-9157 jako náhrady klávesnice a myši ==="

# 1. Instalace antimicrox
echo "[1/6] Instalace antimicrox..."
sudo apt update
sudo apt install antimicrox -y

# 2. Vytvoření složky pro profily
echo "[2/6] Příprava složky s profily..."
mkdir -p ~/gamepad_profiles

# 3. Vytvoření výchozího profilu
echo "[3/6] Generuji výchozí profil pro PG-9157..."

cat > ~/gamepad_profiles/pg9157-desktop.amgp << 'EOF'
{
  "version": 2,
  "controller": "Gamepad",
  "stickConfigs": {
    "0": {
      "xAxis": {
        "mouse": true
      },
      "yAxis": {
        "mouse": true
      }
    }
  },
  "mappings": {
    "0": { "click": 1 },
    "1": { "click": 3 },
    "2": { "keys": ["C", "LCTRL"] },
    "3": { "keys": ["V", "LCTRL"] },
    "4": { "scroll": -1 },
    "5": { "scroll": 1 },
    "6": { "keys": ["ESC"] },
    "7": { "keys": ["ENTER"] },
    "11": { "keys": ["UP"] },
    "12": { "keys": ["DOWN"] },
    "13": { "keys": ["LEFT"] },
    "14": { "keys": ["RIGHT"] }
  }
}
EOF

# 4. Vytvoření autostartu
echo "[4/6] Nastavuji automatické spouštění profilu..."
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/antimicrox.desktop << EOF
[Desktop Entry]
Type=Application
Name=Antimicrox PG9157
Exec=antimicrox --profile /home/$USER/gamepad_profiles/pg9157-desktop.amgp --hidden
X-GNOME-Autostart-enabled=true
EOF

# 5. Informace o ověření funkčnosti
echo "[5/6] Instalace dokončena. Spouštím antimicrox pro ruční ověření..."
antimicrox --profile ~/gamepad_profiles/pg9157-desktop.amgp &

# 6. Shrnutí
echo ""
echo "✅ HOTOVO!"
echo "Po restartu bude ovladač PG-9157 automaticky fungovat jako myš a klávesnice."
echo "👉 Páčka ovládá kurzor, A/B klikají, D-pad šipky, X/Y kopírování, LB/RB scroll."