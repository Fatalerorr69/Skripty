#!/bin/bash
set -e
USER_NAME="starko"
HOME_DIR="/home/${USER_NAME}"

echo "[1] Aktualizace systému a instalace základních balíčků"
sudo apt update && sudo apt upgrade -y
sudo apt install -y software-properties-common wget curl git unzip python3-pip build-essential cmake pkg-config \
libgtk-3-dev python3-gi python3-gi-cairo gir1.2-gtk-3.0 samba cifs-utils

echo "[2] Instalace Wine + Box64"
sudo dpkg --add-architecture i386
wget -O /tmp/box64.deb https://github.com/ptitSeb/box64/releases/download/2025.11.01/box64_2025.11.01_arm64.deb
sudo dpkg -i /tmp/box64.deb || sudo apt install -f -y
sudo apt install -y wine64 wine32
rm /tmp/box64.deb

echo "[3] Instalace RetroArch a emulátorů"
sudo apt install -y retroarch retroarch-joypad-autoconfig \
lr-snes9x lr-picodrive lr-fceumm lr-mgba lr-mame2003 lr-stella lr-desmume lr-ppsspp lr-dolphin-emu

echo "[4] Vytvoření adresářové struktury"
mkdir -p "${HOME_DIR}/Games/ROMs" "${HOME_DIR}/Games/BIOS" "${HOME_DIR}/Games/NAS" "${HOME_DIR}/Games/RetroArch"
chown -R ${USER_NAME}:${USER_NAME} "${HOME_DIR}/Games"

echo "[5] Nastavení NAS úložiště"
NAS_HOST="//nas.local/games"
NAS_USER="starko"
NAS_PASS="12345678"
NAS_MOUNT="${HOME_DIR}/Games/NAS"
echo "${NAS_HOST} ${NAS_MOUNT} cifs username=${NAS_USER},password=${NAS_PASS},uid=$(id -u ${USER_NAME}),gid=$(id -g ${USER_NAME}),iocharset=utf8 0 0" | sudo tee -a /etc/fstab
sudo mount -a

echo "[6] Vytvoření wrapperu Wine+Box64"
mkdir -p "${HOME_DIR}/bin"
cat > "${HOME_DIR}/bin/wine-box64.sh" <<'EOF'
#!/bin/bash
BOX64_PATH=$(which box64)
WINE_PATH=$(which wine64)
$BOX64_PATH $WINE_PATH "$@"
EOF
chmod +x "${HOME_DIR}/bin/wine-box64.sh"
chown ${USER_NAME}:${USER_NAME} "${HOME_DIR}/bin/wine-box64.sh"

echo "[7] Kopírování skriptů a nastavení práv"
chmod +x scripts/*.sh
chown ${USER_NAME}:${USER_NAME} scripts/*.sh

echo "[8] Setup služeb"
./scripts/setup_services.sh

echo "[9] Synchronizace ROM/BIOs a import do RetroArch"
./scripts/sync_roms.sh
./scripts/sync_bios.sh
./scripts/import_roms.sh

echo "[MHS] Detekce a instalace podpory displeje"
./scripts/detect_mhs.sh || true
./scripts/setup_mhs.sh || true
./scripts/test_mhs.sh || true



echo "[10] Hotovo. Doporučuji restartovat systém."
