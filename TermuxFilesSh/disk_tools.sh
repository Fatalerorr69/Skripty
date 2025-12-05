#!/bin/bash
echo "=== Disk Tools ==="
echo "1) Extract ISO"
echo "2) Extract IMG"
echo "3) Make SquashFS"
echo "4) Exit"

read -p "Volba: " V
case $V in
    1) read -p "ISO: " I; 7z x "$I" ;;
    2) read -p "IMG: " I; 7z x "$I" ;;
    3) read -p "Folder: " D; mksquashfs "$D" out.sfs ;;
    4) exit 0 ;;
esac
