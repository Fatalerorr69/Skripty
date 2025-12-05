#!/bin/bash
echo "=== Backup & Restore ==="
echo "1) Full ADB backup"
echo "2) Restore backup"
echo "3) Backup internal storage"
echo "4) Exit"

read -p "Volba: " V
case $V in
    1) adb backup -apk -obb -shared -all -f starko_backup.ab ;;
    2) adb restore starko_backup.ab ;;
    3) adb pull /sdcard ./sdcard_backup ;;
    4) exit 0 ;;
esac
