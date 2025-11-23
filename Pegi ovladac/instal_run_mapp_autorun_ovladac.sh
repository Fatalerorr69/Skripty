#!/bin/bash

echo "=== Instalace AntimicroX a konfigurace PG-9157 ==="

# Instalace antimicrox
sudo apt update
sudo apt install antimicrox -y

# Vytvoření adresáře pro profily
mkdir -p ~/gamepad_profiles

echo "🧩 Nyní spusť příkaz 'antimicrox' a vytvoř mapovací profil (např. myš, klávesnice)."
echo "Až uložíš profil do ~/gamepad_profiles, pojmenuj ho např. pg9157-desktop.amgp."

read -p "Zmáčkni ENTER, až budeš mít profil připraven..."

# Vytvoření autostartu
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/antimicrox.desktop << EOF
[Desktop Entry]
Type=Application
Name=Antimicrox - PG9157
Exec=antimicrox --profile ~/gamepad_profiles/pg9157-desktop.amgp --hidden
X-GNOME-Autostart-enabled=true
EOF

echo "✅ Hotovo! Po startu systému se automaticky spustí AntimicroX s tvým profilem."