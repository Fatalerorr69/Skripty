#!/bin/bash
echo "Vyber typ displeje:"
echo "1) MHS35"
echo "2) LCD35 (Waveshare)"
read -p "Zadej číslo: " typ

./backup-config.sh

case $typ in
  1)
    sudo sed -i '/^dtoverlay=/d' /boot/config.txt
    sudo bash -c 'echo "dtoverlay=mhs35:rotate=90,speed=16000000,fps=25" >> /boot/config.txt'
    ;;
  2)
    sudo sed -i '/^dtoverlay=/d' /boot/config.txt
    sudo bash -c 'echo "dtoverlay=waveshare35a:rotate=90" >> /boot/config.txt'
    ;;
  *)
    echo "Neplatná volba."
    exit 1
    ;;
esac

sudo sed -i 's/rootwait/rootwait fbcon=map:10 fbcon=font:VGA8x8/' /boot/cmdline.txt
echo "Hotovo. Restartuj Raspberry Pi: sudo reboot"
