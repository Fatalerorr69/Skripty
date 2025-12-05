#!/bin/bash
# =============================================
# TwisterOS SuperManager Rozšířené Menu
# =============================================

DIALOG=${DIALOG=dialog}
HEIGHT=20
WIDTH=70
CHOICE_HEIGHT=12
BACKTITLE="TwisterOS SuperManager"
TITLE="Hlavní Menu"
MENU="Vyber akci:"

INSTALL_DIR="/opt/twisteros_supermanager"
NAS_MOUNT="/mnt/twisteros_nas"
AI_SERVICE="ai_station.service"
ROM_DIR="$INSTALL_DIR/roms"
BIOS_DIR="$INSTALL_DIR/bios"

mkdir -p "$ROM_DIR" "$BIOS_DIR"

OPTIONS=(
1 "Správa AI Station (start/stop/status)"
2 "Spuštění RetroArch her"
3 "Spuštění Wine/Box64 aplikací"
4 "Správa NAS"
5 "Správa BIOS/ROM"
6 "Správa služeb (Docker, VNC, Node-RED, WebUI)"
7 "Aktualizace a zálohování systému"
8 "Konfigurace MHS displeje"
9 "Konec"
)

while true; do
CHOICE=$($DIALOG --clear \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --menu "$MENU" $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

clear
case $CHOICE in
    1)
        AI_ACTION=$($DIALOG --menu "AI Station" 10 40 3 \
            1 "Start" \
            2 "Stop" \
            3 "Restart" \
            4 "Status" \
            2>&1 >/dev/tty)
        case $AI_ACTION in
            1) sudo systemctl start $AI_SERVICE ;;
            2) sudo systemctl stop $AI_SERVICE ;;
            3) sudo systemctl restart $AI_SERVICE ;;
            4) systemctl status $AI_SERVICE ;;
        esac
        read -p "Stiskni Enter pro návrat do menu..."
        ;;
    2)
        echo "Spouštění her RetroArch..."
        # Pokud jsou ROM soubory, nabídnout výběr
        GAMES=($ROM_DIR/*)
        if [ ${#GAMES[@]} -eq 0 ]; then
            echo "Žádné ROM soubory v $ROM_DIR"
        else
            select game in "${GAMES[@]}"; do
                retroarch -L /usr/lib/libretro/cores/$(basename "$game" .zip).so "$game"
                break
            done
        fi
        read -p "Stiskni Enter pro návrat do menu..."
        ;;
    3)
        echo "Spouštění Windows aplikací přes Wine/Box64..."
        WINE_APPS=($INSTALL_DIR/wine_apps/*)
        if [ ${#WINE_APPS[@]} -eq 0 ]; then
            echo "Žádné aplikace v $INSTALL_DIR/wine_apps"
        else
            select app in "${WINE_APPS[@]}"; do
                if file "$app" | grep -q "PE32"; then
                    wine "$app"
                else
                    box64 "$app"
                fi
                break
            done
        fi
        read -p "Stiskni Enter pro návrat do menu..."
        ;;
    4)
        echo "NAS mount..."
        sudo mount -a
        if mountpoint -q "$NAS_MOUNT"; then
            echo "NAS je připojeno na $NAS_MOUNT"
        else
            echo "NAS není dostupné."
        fi
        read -p "Stiskni Enter pro návrat do menu..."
        ;;
    5)
        BIOS_ACTION=$($DIALOG --menu "BIOS/ROM" 10 40 3 \
            1 "Kopírovat BIOS" \
            2 "Kopírovat ROM" \
            3 "Vypsat obsah složky" \
            2>&1 >/dev/tty)
        case $BIOS_ACTION in
            1)
                SRC=$(dialog --fselect $HOME/ 15 60 2>&1 >/dev/tty)
                sudo cp "$SRC" "$BIOS_DIR/"
                echo "BIOS zkopírován."
                ;;
            2)
                SRC=$(dialog --fselect $HOME/ 15 60 2>&1 >/dev/tty)
                cp "$SRC" "$ROM_DIR/"
                echo "ROM zkopírována."
                ;;
            3)
                ls -la "$ROM_DIR"
                ls -la "$BIOS_DIR"
                ;;
        esac
        read -p "Stiskni Enter pro návrat do menu..."
        ;;
    6)
        SERVICE_ACTION=$($DIALOG --menu "Služby" 12 50 4 \
            1 "Docker" \
            2 "Node-RED" \
            3 "WebUI" \
            4 "VNC" \
            2>&1 >/dev/tty)
        case $SERVICE_ACTION in
            1)
                sudo systemctl restart docker
                sudo docker ps
                ;;
            2)
                sudo systemctl restart nodered.service
                ;;
            3)
                sudo systemctl restart webui.service
                ;;
            4)
                sudo systemctl restart vncserver-x11-serviced.service
                ;;
        esac
        read -p "Stiskni Enter pro návrat do menu..."
        ;;
    7)
        echo "Aktualizace a zálohování..."
        cd $INSTALL_DIR
        git pull
        BACKUP_DIR="$HOME/twisteros_supermanager_backup_$(date +%Y%m%d%H%M)"
        mkdir -p "$BACKUP_DIR"
        cp -r $INSTALL_DIR/* "$BACKUP_DIR/"
        echo "Záloha uložena v $BACKUP_DIR"
        read -p "Stiskni Enter pro návrat do menu..."
        ;;
    8)
        echo "Konfigurace MHS TFT displeje..."
        # Spustit skript konfigurace displeje
        if [ -f "$INSTALL_DIR/mhs_config.sh" ]; then
            bash "$INSTALL_DIR/mhs_config.sh"
        else
            echo "Skript pro konfiguraci TFT displeje nenalezen."
        fi
        read -p "Stiskni Enter pro návrat do menu..."
        ;;
    9)
        clear
        exit 0
        ;;
    *)
        clear
        ;;
esac
done
