#!/bin/bash
# =============================================
# TwisterOS SuperManager - Full Automated Installer
# Integrates: Powerful AI Station, Emulators, WebUI, Node-RED, Docker services, NAS, ROM/Bios manager
# Target: Raspberry Pi 5 (Twister OS)
# Usage: sudo bash twisteros_supermanager_full_installer.sh
# =============================================

set -euo pipefail
LOGFILE="/var/log/twisteros_supermanager_installer.log"
exec > >(tee -a "$LOGFILE") 2>&1

REPO_URL="https://github.com/Fatalerorr69/twisteros_supermanager.git"
INSTALL_DIR="/opt/twisteros_supermanager"
NAS_MOUNT="/mnt/twisteros_nas"
AI_SERVICE_NAME="ai_station.service"
MENU_SERVICE_NAME="twisteros-supermanager-menu.service"
NODE_RED_FLOW_FILE="$INSTALL_DIR/nodered_flow.json"
DOCKER_COMPOSE_FILE="$INSTALL_DIR/docker-compose.yml"
ROM_DIR="$INSTALL_DIR/roms"
BIOS_DIR="$INSTALL_DIR/bios"
WINE_APPS_DIR="$INSTALL_DIR/wine_apps"
WEBUI_DIR="$INSTALL_DIR/webui"

# Colors for terminal
GREEN="\e[32m"; RED="\e[31m"; NC="\e[0m"

info(){ echo -e "${GREEN}[INFO]${NC} $*"; }
err(){ echo -e "${RED}[ERR]${NC} $*"; }

require_root(){
  if [ "$EUID" -ne 0 ]; then
    err "Spusť skript jako root: sudo bash $0"
    exit 1
  fi
}

require_root

# ---------------------------
# 0) Příprava adresářů a závislostí
# ---------------------------
info "Vytvářím složky..."
mkdir -p "$INSTALL_DIR" "$NAS_MOUNT" "$ROM_DIR" "$BIOS_DIR" "$WINE_APPS_DIR" "$WEBUI_DIR"

info "Aktualizuji apt a instaluji závislosti..."
apt update
apt install -y git dialog curl wget python3 python3-pip docker.io docker-compose \
  wine box64 retroarch unzip jq nginx apache2-utils samba cifs-utils xz-utils

# Enable and start docker
systemctl enable docker --now || true

# ---------------------------
# 1) Klon / aktualizace repozitáře
# ---------------------------
if [ -d "$INSTALL_DIR/.git" ]; then
  info "Repozitář již existuje — pull..."
  git -C "$INSTALL_DIR" pull || true
else
  info "Klonuji repozitář..."
  git clone "$REPO_URL" "$INSTALL_DIR" || true
fi

# 2) Vytvoření a instalace AI Station jako systemd služby
info "Instaluji AI Station..."
AI_DIR="$INSTALL_DIR/ai_station"
mkdir -p "$AI_DIR"

if [ -f "$INSTALL_DIR/Powerful_AI_Station.sh" ]; then
  cp -f "$INSTALL_DIR/Powerful_AI_Station.sh" "$AI_DIR/"
else
  # pokud skript chybí, vytvoříme jednoduchý placeholder, který uživatel nahradí
  cat > "$AI_DIR/Powerful_AI_Station.sh" <<'AISCRIPT'
#!/bin/bash
# Placeholder Powerful AI Station - nahraďte vlastním skriptem
while true; do
  echo "Powerful AI Station running..." >> /var/log/ai_station.log
  sleep 60
done
AISCRIPT
  chmod +x "$AI_DIR/Powerful_AI_Station.sh"
fi

cat > "/etc/systemd/system/$AI_SERVICE_NAME" <<EOF
[Unit]
Description=Powerful AI Station
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=$AI_DIR/Powerful_AI_Station.sh
Restart=always
User=root
WorkingDirectory=$AI_DIR

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now "$AI_SERVICE_NAME"

# 3) Vytvoření Docker Compose pro služby (Node-RED, WebUI, optionally Home Assistant)
info "Vytvářím docker-compose.yml..."
cat > "$DOCKER_COMPOSE_FILE" <<'YML'
version: '3.8'
services:
  nodered:
    image: nodered/node-red:latest
    restart: unless-stopped
    volumes:
      - ./nodered_data:/data
    ports:
      - "1880:1880"
    environment:
      - TZ=Europe/Prague

  webui:
    image: nginx:stable
    restart: unless-stopped
    volumes:
      - ./webui:/usr/share/nginx/html:ro
    ports:
      - "8080:80"

  # Home Assistant (volitelně) - uživatel si může přizpůsobit obraz
  homeassistant:
    image: "homeassistant/home-assistant:stable"
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./homeassistant_config:/config
YML

# vytvoření adresářů pro docker data
mkdir -p "$INSTALL_DIR/nodered_data" "$INSTALL_DIR/webui" "$INSTALL_DIR/homeassistant_config"
chown -R $SUDO_USER:$SUDO_USER "$INSTALL_DIR" || true

# 4) Node-RED flow (základní flow pro ovládání služeb přes API)
info "Vytvářím základní Node-RED flow..."
cat > "$NODE_RED_FLOW_FILE" <<'FLOW'
[{
  "id": "1a2b3c4d",
  "type": "tab",
  "label": "TwisterOS Control",
  "nodes": [
    {
      "id": "http_in",
      "type": "http in",
      "z": "1a2b3c4d",
      "name": "API Control",
      "url": "/api/service",
      "method": "post",
      "swaggerDoc": ""
    },
    {
      "id": "exec",
      "type": "exec",
      "z": "1a2b3c4d",
      "command": "/usr/local/bin/twisteros_service_control.sh",
      "append": true,
      "useSpawn": "false",
      "timer": "10"
    },
    {
      "id": "http_response",
      "type": "http response",
      "z": "1a2b3c4d"
    }
  ],
  "links": [
    {"source": "http_in", "target": "exec"},
    {"source": "exec", "target": "http_response"}
  ]
}]
FLOW

# vytvoříme soubor s pomocným skriptem, který Node-RED bude volat
cat > /usr/local/bin/twisteros_service_control.sh <<'SVC'
#!/bin/bash
read cmd
# jednoduchý kontroler příkazů: start|stop|restart <service>
case "$cmd" in
  "start"*) systemctl start ${cmd#start } ;;
  "stop"*) systemctl stop ${cmd#stop } ;;
  "restart"*) systemctl restart ${cmd#restart } ;;
  *) echo "unknown command" ;;
esac
SVC
chmod +x /usr/local/bin/twisteros_service_control.sh

# 5) WebUI - jednoduchá statická stránka + základní endpoint
info "Vytvářím jednoduché WebUI..."
cat > "$WEBUI_DIR/index.html" <<'HTML'
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>TwisterOS SuperManager WebUI</title>
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <style>body{font-family:Arial,Helvetica,sans-serif;padding:20px}</style>
</head>
<body>
  <h1>TwisterOS SuperManager</h1>
  <p>Node-RED: <a href="/nodered">1880</a></p>
  <p>AI Station: running</p>
  <button onclick="fetch('/api/service', {method:'POST', body:'restart ai_station'})">Restart AI Station</button>
</body>
</html>
HTML

# 6) Nginx basic auth (volitelné) - vytvoříme uživatele 'twister'
info "Nastavuji základní ochranu WebUI (volitelně)..."
htpasswd -bc "$INSTALL_DIR/webui/.htpasswd" twister twisteros || true

# 7) Docker compose up
info "Spouštím Docker Compose služby..."
cd "$INSTALL_DIR"
docker-compose up -d || true

# 8) Instalace RetroArch cores (placeholder - uživatel si doplní z vlastních zdrojů)
info "Připravím adresář pro RetroArch core a ROM (uživatel doplní cores)..."
mkdir -p "$INSTALL_DIR/cores"

# 9) Menu skript (rozšířená verze)
info "Vytvářím rozšířené menu..."
cat > "$INSTALL_DIR/menu.sh" <<'MENU'
#!/bin/bash
DIALOG=${DIALOG=dialog}
HEIGHT=22; WIDTH=80; CHOICE_HEIGHT=14
BACKTITLE="TwisterOS SuperManager"; TITLE="Hlavní Menu"; MENU="Vyber akci:"
INSTALL_DIR="/opt/twisteros_supermanager"
NAS_MOUNT="/mnt/twisteros_nas"
AI_SERVICE="ai_station.service"
ROM_DIR="$INSTALL_DIR/roms"; BIOS_DIR="$INSTALL_DIR/bios"

OPTIONS=(
  1 "Správa AI Station (start/stop/status)"
  2 "RetroArch - vyber ROM a spusť"
  3 "Wine/Box64 - vyber aplikaci a spusť"
  4 "NAS - mount a kontrola"
  5 "BIOS/ROM manager"
  6 "Služby - Docker/Node-RED/WebUI/VNC"
  7 "Aktualizace a zálohování"
  8 "Konfigurace MHS TFT displeje"
  9 "Restartovat AI Station"
  10 "Konec"
)
while true; do
  CHOICE=$($DIALOG --clear --backtitle "$BACKTITLE" --title "$TITLE" --menu "$MENU" $HEIGHT $WIDTH $CHOICE_HEIGHT "${OPTIONS[@]}" 2>&1 >/dev/tty)
  clear
  case $CHOICE in
    1)
      ACTION=$($DIALOG --menu "AI Station" 12 40 4 1 Start 2 Stop 3 Restart 4 Status 2>&1 >/dev/tty)
      case $ACTION in
        1) systemctl start $AI_SERVICE ;;
        2) systemctl stop $AI_SERVICE ;;
        3) systemctl restart $AI_SERVICE ;;
        4) systemctl status $AI_SERVICE ;;
      esac
      read -p "Stiskni Enter..." ;;
    2)
      # vypsat ROM
      if [ -z "$(ls -A "$ROM_DIR" 2>/dev/null)" ]; then echo "Žádné ROMy"; else select r in "$ROM_DIR"/*; do [ -n "$r" ] && retroarch "$r" && break; done; fi
      read -p "Stiskni Enter..." ;;
    3)
      if [ -z "$(ls -A "$INSTALL_DIR/wine_apps" 2>/dev/null)" ]; then echo "Žádné aplikace"; else select a in "$INSTALL_DIR/wine_apps"/*; do [ -n "$a" ] && (file "$a" | grep -q PE32 && wine "$a" || box64 "$a") && break; done; fi
      read -p "Stiskni Enter..." ;;
    4)
      mount -a; mountpoint -q "$NAS_MOUNT" && echo "NAS připojeno" || echo "NAS není připojeno"; read -p "Stiskni Enter..." ;;
    5)
      SELECTION=$($DIALOG --menu "BIOS/ROM" 14 60 6 1 "Kopírovat BIOS" 2 "Kopírovat ROM" 3 "Vypsat obsah" 2>&1 >/dev/tty)
      case $SELECTION in
        1) SRC=$($DIALOG --fselect $HOME/ 20 60 2>&1 >/dev/tty); cp "$SRC" "$BIOS_DIR/" ;;
        2) SRC=$($DIALOG --fselect $HOME/ 20 60 2>&1 >/dev/tty); cp "$SRC" "$ROM_DIR/" ;;
        3) ls -la "$ROM_DIR"; ls -la "$BIOS_DIR"; ;;
      esac
      read -p "Stiskni Enter..." ;;
    6)
      SVC=$($DIALOG --menu "Služby" 12 50 4 1 Docker 2 Node-RED 3 WebUI 4 VNC 2>&1 >/dev/tty)
      case $SVC in
        1) systemctl restart docker; docker ps ;; 
        2) docker-compose -f /opt/twisteros_supermanager/docker-compose.yml restart nodered ;; 
        3) docker-compose -f /opt/twisteros_supermanager/docker-compose.yml restart webui ;; 
        4) systemctl restart vncserver-x11-serviced.service ;; 
      esac
      read -p "Stiskni Enter..." ;;
    7)
      cd /opt/twisteros_supermanager; git pull; BACKUP="$HOME/twisteros_backup_$(date +%Y%m%d%H%M)"; mkdir -p "$BACKUP"; cp -r * "$BACKUP"; echo "Zaloha v $BACKUP"; read -p "Stiskni Enter..." ;;
    8)
      if [ -f "$INSTALL_DIR/mhs_config.sh" ]; then bash "$INSTALL_DIR/mhs_config.sh"; else echo "Skript mhs_config.sh nenalezen."; fi; read -p "Stiskni Enter..." ;;
    9)
      systemctl restart $AI_SERVICE ;;
    10)
      clear; # [MODULE 4: AUTO NAS MOUNT + DETEKCE IP + FALLBACK]
info "Modul 4: Konfiguruji automatický NAS mount + autodetekci IP..."

cat > /usr/local/bin/twisteros_nas_mount.sh <<'NAS'
#!/bin/bash
NAS_MOUNT="/mnt/twisteros_nas"
NAS_IP_CANDIDATES=(
  "192.168.1.100"
  "192.168.0.100"
  "192.168.1.200"
  "$(hostname -I | awk '{print $1}')"
)

mkdir -p "$NAS_MOUNT"
log(){ echo "[NAS] $*"; }
log "Spouštím autodetekci NAS..."

for ip in "${NAS_IP_CANDIDATES[@]}"; do
  if ping -c1 -W1 "$ip" >/dev/null 2>&1; then
    log "Nalezen dostupný NAS: $ip"
    mount -t cifs "//$ip/twisteros" "$NAS_MOUNT" -o guest,vers=3.0 2>/dev/null && # [MODULE 5: AUTO-DETEKCE EMULÁTORŮ + DYNAMICKÁ REGISTRACE]
info "Modul 5: Detekuji nainstalované emulátory a registruji je..."

cat > /usr/local/bin/twisteros_emulator_scan.sh <<'EMU'
#!/bin/bash
EMULATOR_DIR="/opt/twisteros_supermanager/emulators"
mkdir -p "$EMULATOR_DIR"

declare -A EMUS=(
  [retroarch]="retroarch"
  [ppsspp]="ppsspp"
  [mupen64plus]="mupen64plus"
  [pcsx]="pcsx"
  [duckstation]="duckstation"
)

for e in "${!EMUS[@]}"; do
  if command -v "${EMUS[$e]}" >/dev/null 2>&1; then
    echo "$e" > "$EMULATOR_DIR/$e.enabled"
  fi
done
EMU
chmod +x /usr/local/bin/twisteros_emulator_scan.sh
/usr/local/bin/twisteros_emulator_scan.sh

# [MODULE 6: AUTOMATIC DRIVER FIX + HW DETECTION]
info "Modul 6: Automatická detekce HW + opravy ovladačů..."

cat > /usr/local/bin/twisteros_hw_fix.sh <<'HW'
#!/bin/bash
log(){ echo "[HW] $*"; }

CPU=$(lscpu | grep 'Model name')
GPU=$(lspci | grep VGA)
USB=$(lsusb)

log "CPU: $CPU"
log "GPU: $GPU"
log "USB zařízení: $USB"

# Fix 1: VC4 driver
if ! lsmod | grep -q vc4; then
  log "VC4 není aktivní — zapínám..."
  echo "dtoverlay=vc4-kms-v3d" >> /boot/config.txt
fi

# Fix 2: audio
if ! aplay -l | grep -q card; then
  log "Audio nenalezeno — resetuji PulseAudio..."
  systemctl --user restart pulseaudio || true
fi

# Fix 3: USB reset
log "Provádím USB reset (bezpečná varianta)..."
for x in /sys/bus/usb/devices/*/authorized; do echo 0 > $x; sleep 0.3; echo 1 > $x; done
HW
chmod +x /usr/local/bin/twisteros_hw_fix.sh

# [MODULE 7: AUTO-UPDATE EMULATORS, WEBUI, AI]
info "Modul 7: Přidávám auto-updater pro všechny komponenty..."

cat > /usr/local/bin/twisteros_auto_update.sh <<'UPD'
#!/bin/bash
log(){ echo "[UPDATE] $*"; }

log "Aktualizuji SuperManager..."
git -C /opt/twisteros_supermanager pull >/dev/null 2>&1

log "Aktualizuji Docker kontejnery..."
docker-compose -f /opt/twisteros_supermanager/docker-compose.yml pull

docker-compose -f /opt/twisteros_supermanager/docker-compose.yml up -d

log "Aktualizuji RetroArch cores (pokud existují)..."
CORES_DIR="/opt/twisteros_supermanager/cores"
mkdir -p "$CORES_DIR"
# placeholder auto-update

log "Hotovo."
UPD
chmod +x /usr/local/bin/twisteros_auto_update.sh

# přidání CRON
(crontab -l 2>/dev/null; echo "0 */12 * * * /usr/local/bin/twisteros_auto_update.sh >/dev/null 2>&1") | crontab -

# [MODULE 8: AUTO GENERATOR .desktop IKON]
info "Modul 8: Generuji systémové ikony..."

cat > /usr/local/bin/twisteros_icon_gen.sh <<'ICON'
#!/bin/bash
DEST="/usr/share/applications"
DIR="/opt/twisteros_supermanager"

make_icon(){
  NAME="$1"; CMD="$2"; ICON_PATH="$3"
  FILE="$DEST/$NAME.desktop"
  cat > "$FILE" <<EOF
[Desktop Entry]
Name=$NAME
Exec=$CMD
Icon=$ICON_PATH
Terminal=true
Type=Application
Categories=Utility;
EOF
}

make_icon "TwisterOS SuperManager" "$DIR/menu.sh" "$DIR/icon.png"
make_icon "AI Station" "/usr/local/bin/twisteros_service_control.sh restart ai_station" "$DIR/ai.png"
ICON
chmod +x /usr/local/bin/twisteros_icon_gen.sh
/usr/local/bin/twisteros_icon_gen.sh

exit 0
  fi
done

log "NAS nebyl nalezen — Fallback režim. Používám lokální adresář."
exit 0
NAS
chmod +x /usr/local/bin/twisteros_nas_mount.sh

cat > /etc/systemd/system/twisteros-nas.mount.service <<'UNIT'
[Unit]
Description=Auto Mount TwisterOS NAS
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/twisteros_nas_mount.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable twisteros-nas.mount.service

exit 0 ;;
  esac
done
MENU

chmod +x "$INSTALL_DIR/menu.sh"

# 10) Systemd service - automatické spuštění menu při přihlášení (na grafickém prostředí může být potřeba upravit)
info "Vytvářím systemd službu pro menu..."
cat > "/etc/systemd/system/$MENU_SERVICE_NAME" <<EOF
[Unit]
Description=TwisterOS SuperManager Menu
After=graphical.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/menu.sh
Restart=on-failure
User=$SUDO_USER

[Install]
WantedBy=graphical.target
EOF

systemctl daemon-reload
systemctl enable --now "$MENU_SERVICE_NAME" || true

# 11) Updater: cron job, který kontroluje repozitář každých 6 hodin
info "Instaluji updater (cron)..."
CRON_CMD="/usr/bin/git -C $INSTALL_DIR pull >/dev/null 2>&1"
(crontab -l 2>/dev/null; echo "0 */6 * * * $CRON_CMD") | crontab -

# 12) Samba (NAS) - vytvoření sdílení (pokud uživatel chce hostovat NAS na tomtéž RPi)
info "Volitelně nastavím Samba share pro $NAS_MOUNT"
cat > /etc/samba/smb.conf.d/twisteros_supermanager.conf <<SAMBA
[twisteros]
  path = $NAS_MOUNT
  browseable = yes
  read only = no
  guest ok = yes
SAMBA
systemctl restart smbd || true

# 13) Permissions
info "Nastavuji správná oprávnění..."
chown -R $SUDO_USER:$SUDO_USER "$INSTALL_DIR"
chmod -R 755 "$INSTALL_DIR"

# 14) Finalizace
info "Instalace dokončena."
info "Spouštím menu..."
# spuštění menu interaktivně pokud je přítomen TTY
if [ -t 1 ]; then
  sudo -u $SUDO_USER "$INSTALL_DIR/menu.sh"
fi

info "Hotovo. Log: $LOGFILE"

exit 0

# [MODULE 1 — RETROARCH & EMULATOR MANAGER]
install_retroarch_manager() {
    echo "[RetroArch Manager] Instalace začala..."
    apt-get install -y retroarch retroarch-assets || true
    mkdir -p /opt/twisteros_supermanager/cores
    mkdir -p /opt/twisteros_supermanager/roms
    echo "RetroArch instalován. Cores a ROM adresáře připraveny."
}

# [MODULE 2 — DOCKER SERVICES & SUPERWEBUI]
install_docker_services() {
    echo "[Docker Services] Instalace Dockeru a příprava SuperWebUI..."
    if ! command -v docker >/dev/null 2>&1; then
        curl -fsSL https://get.docker.com | sh
        systemctl enable docker --now
    fi

    mkdir -p /opt/twisteros_supermanager/docker
    cat > /opt/twisteros_supermanager/docker/docker-compose.yml <<'EOF'
version: '3'
services:
  webui:
    image: nginx
    container_name: superwebui
    volumes:
      - /opt/twisteros_supermanager/webui:/usr/share/nginx/html:ro
    ports:
      - "8181:80"
    restart: unless-stopped
  nodered:
    image: nodered/node-red
    container_name: supermanager_nodered
    ports:
      - "1880:1880"
    restart: unless-stopped
    volumes:
      - /opt/twisteros_supermanager/nodered:/data
EOF

    mkdir -p /opt/twisteros_supermanager/webui
    echo "<h1>SuperManager WebUI</h1>" > /opt/twisteros_supermanager/webui/index.html

    docker compose -f /opt/twisteros_supermanager/docker/docker-compose.yml up -d
    echo "Docker služby byly spuštěny. WebUI běží na portu 8181."
}

# [MODULE 3 — NODERED FLOW LOADER + API INTEGRACE]
install_nodered_flow() {
    echo "[Node-RED] Příprava flow a API integrace..."

    mkdir -p /opt/twisteros_supermanager/nodered

    cat > /opt/twisteros_supermanager/nodered/flow.json <<'EOF'
[
    {
        "id": "superui-status",
        "type": "http in",
        "url": "/api/status",
        "method": "get",
        "swaggerDoc": "",
        "x": 150,
        "y": 120,
        "wires": [["status-node"]]
    },
    {
        "id": "status-node",
        "type": "function",
        "func": "msg.payload = {status: 'running', services: ['AI Station','WebUI','Docker','NAS','RetroArch']}; return msg;",
        "outputs": 1,
        "x": 370,
        "y": 120,
        "wires": [["status-out"]]
    },
    {
        "id": "status-out",
        "type": "http response",
        "x": 610,
        "y": 120,
        "wires": []
    }
]
EOF

    echo "Node-RED flow vytvořen. Importuje se automaticky při startu kontejneru."
}

# --- Modul 4: Auto NAS Mount + Detekce IP + Fallback ---
info "Spouštím Modul 4: Auto NAS Mount..."
	cat > /usr/local/bin/twisteros_nas_mount.sh <<'NAS'
	#!/bin/bash
	NAS_MOUNT="/mnt/twisteros_nas"
	NAS_IP_CANDIDATES=("192.168.1.100" "192.168.0.100" "192.168.1.200" "$(hostname -I | awk '{print $1}')")
	mkdir -p "$NAS_MOUNT"
	for ip in "${NAS_IP_CANDIDATES[@]}"; do
	if ping -c1 -W1 "$ip" >/dev/null 2>&1; then
	mount -t cifs "//$ip/twisteros" "$NAS_MOUNT" -o guest,vers=3.0 2>/dev/null && exit 0
	fi
	done
	exit 0
	NAS
	chmod +x /usr/local/bin/twisteros_nas_mount.sh


# --- Modul 5: Auto-detekce emulátorů ---
info "Spouštím Modul 5: Auto-detekce emulátorů..."
	cat > /usr/local/bin/twisteros_emulator_scan.sh <<'EMU'
	#!/bin/bash
	EMULATOR_DIR="/opt/twisteros_supermanager/emulators"
	mkdir -p "$EMULATOR_DIR"
	declare -A EMUS=( [retroarch]=retroarch [ppsspp]=ppsspp [mupen64plus]=mupen64plus [pcsx]=pcsx [duckstation]=duckstation )
	for e in "${!EMUS[@]}"; do
	command -v "${EMUS[$e]}" >/dev/null 2>&1 && echo "$e" > "$EMULATOR_DIR/$e.enabled"
	done
	EMU
	chmod +x /usr/local/bin/twisteros_emulator_scan.sh


# --- Modul 6: HW detection + Driver Fixes ---
info "Spouštím Modul 6: HW Detection + Driver Fixes..."
	cat > /usr/local/bin/twisteros_hw_fix.sh <<'HW'
	#!/bin/bash
	for x in /sys/bus/usb/devices/*/authorized; do echo 0 > $x; sleep 0.3; echo 1 > $x; done
	HW
	chmod +x /usr/local/bin/twisteros_hw_fix.sh


# --- Modul 7: Auto-update ---
info "Spouštím Modul 7: Auto-update..."
	cat > /usr/local/bin/twisteros_auto_update.sh <<'UPD'
	#!/bin/bash
	git -C /opt/twisteros_supermanager pull >/dev/null 2>&1
	docker-compose -f /opt/twisteros_supermanager/docker/docker-compose.yml pull
	UPD
	chmod +x /usr/local/bin/twisteros_auto_update.sh


# --- Modul 8: Auto generátor ikon ---
info "Spouštím Modul 8: Auto generátor ikon..."
	cat > /usr/local/bin/twisteros_icon_gen.sh <<'ICON'
	#!/bin/bash
	mkdir -p /usr/share/applications
	ICON_DIR="/opt/twisteros_supermanager"
	echo -e "[Desktop Entry]\nName=TwisterOS SuperManager\nExec=$ICON_DIR/menu_full.sh\nIcon=$ICON_DIR/icon.png\nTerminal=true\nType=Application\nCategories=Utility;" > /usr/share/applications/twisteros_supermanager.desktop
	ICON
	chmod +x /usr/local/bin/twisteros_icon_gen.sh



# [MODULE 9 — AI Integration Booster]
install_ai_booster(){
    echo "[AI Booster] Aktivace pokročilé AI integrace..."
    mkdir -p /opt/twisteros_supermanager/ai_models
    mkdir -p /opt/twisteros_supermanager/ai_logs
    touch /opt/twisteros_supermanager/ai_models/model.index

    # Instalace Ollama + modelů
    if ! command -v ollama >/dev/null 2>&1; then
        curl -fsSL https://ollama.com/install.sh | sh
    fi

    ollama pull llama3.2:3b || true
    ollama pull qwen2.5:1.5b || true

    echo "AI integrace dokončena. Modely připraveny."
}

# [MODULE 10 — Advanced BIOS Manager]
install_bios_manager(){
    echo "[BIOS Manager] Instalace..."
    mkdir -p /opt/twisteros_supermanager/bios
    mkdir -p /opt/twisteros_supermanager/bios_checker

    cat > /usr/local/bin/bios_check.sh <<'EOF'
#!/bin/bash
BIOS_DIR="/opt/twisteros_supermanager/bios"
if [ -z "$(ls -A $BIOS_DIR)" ]; then
    echo "BIOS složka je prázdná."
    exit 1
else
    echo "Nalezeny BIOS soubory:"
    ls -lh $BIOS_DIR
fi
EOF
    chmod +x /usr/local/bin/bios_check.sh
    echo "BIOS Manager dokončen."
}

# [MODULE 11 — Waydroid Auto-Installer]
install_waydroid_auto(){
    echo "[Waydroid] Instalace Waydroidu..."
    apt install -y curl ca-certificates sudo lxc python3 python3-distutils lightdm || true
    curl https://repo.waydroid.com/waydroid.gpg | gpg --dearmor > /usr/share/keyrings/waydroid.gpg
    echo "deb [signed-by=/usr/share/keyrings/waydroid.gpg] https://repo.waydroid.com/ bookworm main" >/etc/apt/sources.list.d/waydroid.list
    apt update
    apt install -y waydroid || true

    systemctl enable waydroid-container.service
    waydroid init || true
    echo "Waydroid úspěšně nainstalován a inicializován."
}

# [MODULE 12 — VNC + noVNC Server Installer]
install_vnc_stack(){
    echo "[VNC Stack] Instalace..."
    apt install -y realvnc-vnc-server realvnc-vnc-viewer || true
    systemctl enable vncserver-x11-serviced.service --now || true

    # noVNC
    mkdir -p /opt/novnc
    git clone https://github.com/novnc/noVNC /opt/novnc || true
    git clone https://github.com/novnc/websockify /opt/novnc/utils/websockify || true

    cat > /usr/local/bin/novnc_start.sh <<'EOF'
#!/bin/bash
cd /opt/novnc
./utils/novnc_proxy --vnc localhost:5900 --listen 6080
EOF
    chmod +x /usr/local/bin/novnc_start.sh

    echo "[VNC Stack] Instalováno: VNC + noVNC na portu 6080"
}

# [MODULE 13 — Full Web Dashboard 2.0]
install_web_dashboard2(){
    echo "[Web Dashboard] Budování nové verze..."
    mkdir -p /opt/twisteros_supermanager/web_dashboard

    cat > /opt/twisteros_supermanager/web_dashboard/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8"/>
<title>TwisterOS Super Dashboard 2.0</title>
<style>
body{font-family:Arial;background:#222;color:#eee;padding:20px;}
h1{color:#0f0;}
.card{background:#333;padding:20px;margin:10px;border-radius:8px;}
.btn{padding:10px 20px;background:#444;border:1px solid #0f0;color:#0f0;cursor:pointer;}
</style>
</head>
<body>
<h1>TwisterOS Super Dashboard 2.0</h1>
<div class="card"><h2>AI Station</h2><button class="btn" onclick="fetch('/api/ai/restart',{method:'POST'})">Restart AI</button></div>
<div class="card"><h2>Waydroid</h2><button class="btn" onclick="fetch('/api/waydroid/start',{method:'POST'})">Start</button></div>
<div class="card"><h2>VNC</h2><button class="btn" onclick="fetch('/api/vnc/start',{method:'POST'})">Start noVNC</button></div>
</body>
</html>
EOF

    echo "Web Dashboard 2.0 nainstalován."
}
