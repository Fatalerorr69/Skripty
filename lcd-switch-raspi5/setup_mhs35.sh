<<<<<<< HEAD
#!/bin/bash
# Interaktivní nastavení MHS35 TFT na Raspberry Pi 5
# Verze 1.1 – automatická detekce a měřítko pro různé desktopy

echo "=== Automatické nastavení MHS35 TFT ==="

# 1️⃣ Záloha config.txt
sudo cp /boot/config.txt /boot/config.txt.bak
echo "Backup /boot/config.txt vytvořen."

# 2️⃣ Detekce aktuálního rozlišení
echo "Detekce aktuálního rozlišení..."
CURRENT_RES=$(tvservice -s | grep -oP '\d+x\d+')
echo "Aktuální rozlišení: $CURRENT_RES"

# 3️⃣ Volba otočení displeje
echo "Zvolte otočení displeje:"
echo "0 = normální, 1 = 90°, 2 = 180°, 3 = 270°"
read -p "Zadejte číslo (0-3): " ROTATE
if ! [[ "$ROTATE" =~ ^[0-3]$ ]]; then
    ROTATE=0
    echo "Neplatná volba, použito 0°."
fi

# 4️⃣ Úprava config.txt
sudo sed -i '/hdmi_group/d;/hdmi_mode/d;/hdmi_cvt/d;/hdmi_drive/d;/display_rotate/d' /boot/config.txt
sudo tee -a /boot/config.txt > /dev/null <<EOL
# Nastavení pro MHS35 TFT 800x480
hdmi_group=2
hdmi_mode=87
hdmi_cvt=800 480 60 6 0 0 0
hdmi_drive=1
display_rotate=$ROTATE
EOL
echo "config.txt upraven s otočením $ROTATE."

# 5️⃣ Konfigurace X serveru
sudo mkdir -p /etc/X11/xorg.conf.d
sudo tee /etc/X11/xorg.conf.d/99-fbdev.conf > /dev/null <<EOL
Section "Monitor"
    Identifier "MHS35"
    Option "DPMS" "false"
EndSection

Section "Screen"
    Identifier "Screen0"
    Device "FBDEV"
    Monitor "MHS35"
    DefaultDepth 24
    SubSection "Display"
        Depth 24
        Modes "800x480"
    EndSubSection
EndSection
EOL
echo "X server nakonfigurován pro 800x480."

# 6️⃣ Nastavení měřítka pro Qt/Gtk
echo 'export QT_SCALE_FACTOR=1.5' >> ~/.xprofile
echo "Nastaveno QT_SCALE_FACTOR=1.5"

# GTK pro GNOME nebo kompatibilní
if command -v gsettings &>/dev/null; then
    gsettings set org.gnome.desktop.interface scaling-factor 2 || echo "GTK scale nenastaveno (GNOME nemusí být přítomen)"
fi

# 7️⃣ Restart desktop manageru
if systemctl is-active --quiet lightdm; then
    echo "Restartuji LightDM..."
    sudo systemctl restart lightdm
else
    echo "LightDM nenalezen. Doporučeno restartovat Raspberry Pi: sudo reboot"
fi

echo "=== Hotovo! ==="
=======
#!/bin/bash
# Interaktivní nastavení MHS35 TFT na Raspberry Pi 5
# Verze 1.1 – automatická detekce a měřítko pro různé desktopy

echo "=== Automatické nastavení MHS35 TFT ==="

# 1️⃣ Záloha config.txt
sudo cp /boot/config.txt /boot/config.txt.bak
echo "Backup /boot/config.txt vytvořen."

# 2️⃣ Detekce aktuálního rozlišení
echo "Detekce aktuálního rozlišení..."
CURRENT_RES=$(tvservice -s | grep -oP '\d+x\d+')
echo "Aktuální rozlišení: $CURRENT_RES"

# 3️⃣ Volba otočení displeje
echo "Zvolte otočení displeje:"
echo "0 = normální, 1 = 90°, 2 = 180°, 3 = 270°"
read -p "Zadejte číslo (0-3): " ROTATE
if ! [[ "$ROTATE" =~ ^[0-3]$ ]]; then
    ROTATE=0
    echo "Neplatná volba, použito 0°."
fi

# 4️⃣ Úprava config.txt
sudo sed -i '/hdmi_group/d;/hdmi_mode/d;/hdmi_cvt/d;/hdmi_drive/d;/display_rotate/d' /boot/config.txt
sudo tee -a /boot/config.txt > /dev/null <<EOL
# Nastavení pro MHS35 TFT 800x480
hdmi_group=2
hdmi_mode=87
hdmi_cvt=800 480 60 6 0 0 0
hdmi_drive=1
display_rotate=$ROTATE
EOL
echo "config.txt upraven s otočením $ROTATE."

# 5️⃣ Konfigurace X serveru
sudo mkdir -p /etc/X11/xorg.conf.d
sudo tee /etc/X11/xorg.conf.d/99-fbdev.conf > /dev/null <<EOL
Section "Monitor"
    Identifier "MHS35"
    Option "DPMS" "false"
EndSection

Section "Screen"
    Identifier "Screen0"
    Device "FBDEV"
    Monitor "MHS35"
    DefaultDepth 24
    SubSection "Display"
        Depth 24
        Modes "800x480"
    EndSubSection
EndSection
EOL
echo "X server nakonfigurován pro 800x480."

# 6️⃣ Nastavení měřítka pro Qt/Gtk
echo 'export QT_SCALE_FACTOR=1.5' >> ~/.xprofile
echo "Nastaveno QT_SCALE_FACTOR=1.5"

# GTK pro GNOME nebo kompatibilní
if command -v gsettings &>/dev/null; then
    gsettings set org.gnome.desktop.interface scaling-factor 2 || echo "GTK scale nenastaveno (GNOME nemusí být přítomen)"
fi

# 7️⃣ Restart desktop manageru
if systemctl is-active --quiet lightdm; then
    echo "Restartuji LightDM..."
    sudo systemctl restart lightdm
else
    echo "LightDM nenalezen. Doporučeno restartovat Raspberry Pi: sudo reboot"
fi

echo "=== Hotovo! ==="
>>>>>>> 2d437cc2ae07a396d41a3b74e61ac94634aea845
echo "Pokud obrazovka nezměnila rozlišení nebo měřítko, restartujte Raspberry Pi."