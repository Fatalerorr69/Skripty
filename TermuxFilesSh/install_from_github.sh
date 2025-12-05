#!/bin/bash
# Instalace TwisterOS SuperManager ze stávajícího GitHub repozitáře
# Spustit s sudo

USER_NAME="starko"
USER_HOME="/home/$USER_NAME"
DEST_DIR="/opt/twisteros_supermanager"
REPO_URL="https://github.com/Fatalerorr69/twisteros_supermanager.git"

# -----------------------------
# 1️⃣ Aktualizace systému a instalace závislostí
# -----------------------------
echo "[1/8] Instalace základních balíčků..."
apt update && apt upgrade -y
apt install -y git python3 python3-pip python3-gi python3-gi-cairo gir1.2-gtk-3.0 docker.io cifs-utils nfs-common unzip wget curl dialog
pip3 install requests flask

# -----------------------------
# 2️⃣ Vytvoření cílové struktury
# -----------------------------
echo "[2/8] Vytvářím cílovou strukturu..."
sudo mkdir -p "$DEST_DIR"/{scripts,plugins,emulators,api,dashboard,nas,config,ROMs,BIOS,logs,bin}
sudo chown -R $USER_NAME:$USER_NAME "$DEST_DIR"

# -----------------------------
# 3️⃣ Klonování nebo aktualizace repozitáře
# -----------------------------
echo "[3/8] Klonování nebo aktualizace repozitáře..."
if [ -d "$DEST_DIR/repo" ]; then
    cd "$DEST_DIR/repo" && git pull
else
    git clone "$REPO_URL" "$DEST_DIR/repo"
fi

# -----------------------------
# 4️⃣ Kopírování všech souborů do cílové struktury
# -----------------------------
echo "[4/8] Kopírování souborů..."
rsync -a "$DEST_DIR/repo/scripts/" "$DEST_DIR/scripts/"
rsync -a "$DEST_DIR/repo/plugins/" "$DEST_DIR/plugins/"
rsync -a "$DEST_DIR/repo/emulators/" "$DEST_DIR/emulators/"
rsync -a "$DEST_DIR/repo/api/" "$DEST_DIR/api/"
rsync -a "$DEST_DIR/repo/dashboard/" "$DEST_DIR/dashboard/"
rsync -a "$DEST_DIR/repo/nas/" "$DEST_DIR/nas/"
rsync -a "$DEST_DIR/repo/config/" "$DEST_DIR/config/"
rsync -a "$DEST_DIR/repo/bin/" "$DEST_DIR/bin/"

sudo chmod +x "$DEST_DIR"/scripts/*.sh
sudo chmod +x "$DEST_DIR"/plugins/*.sh
sudo chmod +x "$DEST_DIR"/bin/*

# -----------------------------
# 5️⃣ Inicializace ROM, BIOS a NAS složky
# -----------------------------
echo "[5/8] Inicializuji ROMs, BIOS a NAS složky..."
mkdir -p "$DEST_DIR/ROMs" "$DEST_DIR/BIOS" "$DEST_DIR/nas_storage"
sudo chown -R $USER_NAME:$USER_NAME "$DEST_DIR/ROMs" "$DEST_DIR/BIOS" "$DEST_DIR/nas_storage"

# -----------------------------
# 6️⃣ Vytvoření systemd služby pro automatické spuštění
# -----------------------------
echo "[6/8] Vytvářím systemd službu..."
sudo tee /etc/systemd/system/supermanager.service > /dev/null <<EOF
[Unit]
Description=TwisterOS SuperManager
After=network.target

[Service]
Type=simple
User=$USER_NAME
ExecStart=$DEST_DIR/scripts/supermanager.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now supermanager.service

# -----------------------------
# 7️⃣ Volitelná konfigurace NAS a MHS displeje
# -----------------------------
echo "[7/8] Konfigurace NAS a MHS displeje..."
# - NAS mount (CIFS nebo NFS)
# - detekce MHS displeje
# Tento krok lze doplnit později dle konkrétní konfigurace
# Příklad pro NAS CIFS:
# sudo mkdir -p /mnt/nas
# sudo mount -t cifs -o username=starko,password=12345678 //NAS_IP/share /mnt/nas

# -----------------------------
# 8️⃣ Spuštění interaktivního menu
# -----------------------------
echo "[8/8] Spouštím interaktivní menu..."

function main_menu() {
    while true; do
        CHOICE=$(dialog --clear --backtitle "TwisterOS SuperManager" \
            --title "Hlavní menu" \
            --menu "Vyber možnost:" 15 60 10 \
            1 "Správa skriptů a pluginů" \
            2 "Správa emulátorů a ROM/BIOS" \
            3 "NAS a síťové úložiště" \
            4 "Detekce a konfigurace MHS displeje" \
            5 "Update systému a TwisterOS" \
            6 "Zálohování a obnovení" \
            7 "Restart služeb" \
            8 "Otevřít dashboard v prohlížeči" \
            9 "Ukončit" \
            3>&1 1>&2 2>&3)

        case $CHOICE in
            1) bash "$DEST_DIR/scripts/plugin_manager.sh" ;;
            2) bash "$DEST_DIR/scripts/emulator_manager.sh" ;;
            3) bash "$DEST_DIR/scripts/nas_manager.sh" ;;
            4) bash "$DEST_DIR/scripts/mhs_detect.sh" ;;
            5) bash "$DEST_DIR/scripts/update_all.sh" ;;
            6) bash "$DEST_DIR/scripts/backup_restore.sh" ;;
            7) bash "$DEST_DIR/scripts/service_restart.sh" ;;
            8) xdg-open "http://localhost:8080" ;;
            9) clear; exit 0 ;;
            *) dialog --msgbox "Neplatná volba!" 5 30 ;;
        esac
    done
}

main_menu
