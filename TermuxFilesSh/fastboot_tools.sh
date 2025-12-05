#!/bin/bash
echo "=== Fastboot Tools ==="
fastboot devices
echo "1) Flash boot"
echo "2) Flash recovery"
echo "3) Flash system"
echo "4) Exit"

read -p "Volba: " V

case $V in
    1) read -p "boot.img: " F; fastboot flash boot "$F" ;;
    2) read -p "recovery.img: " F; fastboot flash recovery "$F" ;;
    3) read -p "system.img: " F; fastboot flash system "$F" ;;
    4) exit 0 ;;
esac
