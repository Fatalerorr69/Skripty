#!/bin/bash
echo "=== ADB Tools ==="
adb devices
echo "1) Shell"
echo "2) Install APK"
echo "3) Uninstall package"
echo "4) Reboot"
echo "5) Exit"
read -p "Volba: " V

case $V in
    1) adb shell ;;
    2) read -p "Soubor APK: " F; adb install "$F" ;;
    3) read -p "Balík: " P; adb uninstall "$P" ;;
    4) adb reboot ;;
    5) exit 0 ;;
esac
