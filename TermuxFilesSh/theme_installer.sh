#!/bin/bash
echo "🎨 Instalace témat Twister Smart..."

mkdir -p ~/.themes ~/.icons ~/Pictures/Wallpapers

# Populární linuxová témata
wget -q https://github.com/vinceliuice/WhiteSur-gtk-theme/archive/master.zip -O whitesur.zip
unzip whitesur.zip -d ~/.themes/WhiteSur

wget -q https://github.com/vinceliuice/WhiteSur-icon-theme/archive/master.zip -O icons.zip
unzip icons.zip -d ~/.icons/WhiteSur

wget -q https://unsplash.com/photos/2LowviVHZ-E/download?force=true -O ~/Pictures/Wallpapers/wall1.jpg

echo "🖌 Aplikuj motiv přes ‘Twister Appearance’ nebo xfce4-appearance-settings"
