#!/bin/bash
echo "=== APK Manager Pro ==="
echo "1) Install APK"
echo "2) Extract APK info"
echo "3) Backup APK"
echo "4) Exit"

read -p "Volba: " V
case $V in
    1) read -p "APK: " A; adb install "$A" ;;
    2) read -p "APK: " A; aapt dump badging "$A" ;;
    3) read -p "Balík: " P; adb shell pm path "$P" | sed 's/package://g' | while read L; do adb pull "$L"; done ;;
    4) exit 0 ;;
esac
