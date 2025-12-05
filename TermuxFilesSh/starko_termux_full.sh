#!/data/data/com.termux/files/usr/bin/bash
source config/settings.sh
source modules/utils.sh
source modules/recovery.sh
source modules/android.sh
source modules/webgui.sh
source modules/ai.sh
source modules/build.sh
source modules/usb.sh
main_menu() {
    clear
    echo "=== $APP_NAME ==="
    echo "1) Recovery Tools"
    echo "2) Android Tools"
    echo "3) WebGUI"
    echo "4) AI Asistent"
    echo "5) Build Tools"
    echo "6) USB Tools"
    echo "7) Konec"
    read -p "> " c
    case $c in
        1) recovery_menu ;;
        2) android_menu ;;
        3) start_web_gui ;;
        4) ai_menu ;;
        5) build_menu ;;
        6) usb_menu ;;
        7) exit ;;
    esac
    main_menu
}
main_menu
