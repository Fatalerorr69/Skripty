<<<<<<< HEAD
#!/bin/bash
# HDMI Hot-Plug Auto Switch pro Raspberry Pi 5
# Automaticky přepíná hlavní výstup mezi HDMI a TFT při připojení/odpojení HDMI

LOG_FILE="/var/log/hdmi_hotplug.log"
echo "=== Spuštění HDMI Hot-Plug $(date) ===" >> $LOG_FILE

# Funkce pro přepnutí na HDMI
switch_to_hdmi() {
    echo "Přepínám na HDMI..." >> $LOG_FILE
    sed -i '/hdmi_group/d;/hdmi_mode/d;/hdmi_cvt/d;/hdmi_drive/d;/display_rotate/d' /boot/config.txt
    tee -a /boot/config.txt > /dev/null <<EOL
hdmi_group=1
hdmi_mode=16
hdmi_drive=2
EOL
    echo "HDMI nastaveno" >> $LOG_FILE
}

# Funkce pro přepnutí na TFT
switch_to_tft() {
    echo "Přepínám na TFT..." >> $LOG_FILE
     sed -i '/hdmi_group/d;/hdmi_mode/d;/hdmi_cvt/d;/hdmi_drive/d;/display_rotate/d' /boot/config.txt
     tee -a /boot/config.txt > /dev/null <<EOL
hdmi_group=2
hdmi_mode=87
hdmi_cvt=800 480 60 6 0 0 0
hdmi_drive=1
display_rotate=0
EOL
    echo "TFT nastaveno" >> $LOG_FILE
}

# Funkce pro nastavení DPI/měřítka podle desktopu
set_dpi() {
    DESKTOP=$(echo $XDG_CURRENT_DESKTOP | tr '[:upper:]' '[:lower:]')
    case "$DESKTOP" in
        lxde|lxqt)
            xrdb -merge <<< "Xft.dpi: 120"
            echo 'export QT_SCALE_FACTOR=1.5' >> ~/.xprofile
            ;;
        gnome)
            gsettings set org.gnome.desktop.interface scaling-factor 2
            gsettings set org.gnome.desktop.interface text-scaling-factor 1.5
            echo 'export QT_SCALE_FACTOR=1.5' >> ~/.xprofile
            ;;
        xfce)
            xfconf-query -c xsettings -p /Xft/DPI -s 120
            echo 'export QT_SCALE_FACTOR=1.5' >> ~/.xprofile
            ;;
        *)
            echo 'export QT_SCALE_FACTOR=1.5' >> ~/.xprofile
            ;;
    esac
}

# Inicialní kontrola HDMI při startu
if tvservice -n | grep -q "device_name"; then
    switch_to_hdmi
else
    switch_to_tft
fi

set_dpi

# Sledování HDMI hot-plug
echo "Spouštím sledování HDMI hot-plug..." >> $LOG_FILE
while true; do
    sleep 2
    if tvservice -n | grep -q "device_name"; then
        if [ ! -f /tmp/hdmi_connected ]; then
            touch /tmp/hdmi_connected
            switch_to_hdmi
            echo "HDMI připojeno, přepnuto." >> $LOG_FILE
            systemctl restart lightdm 2>/dev/null || echo "LightDM/GDM restart doporučen"
        fi
    else
        if [ -f /tmp/hdmi_connected ]; then
            rm /tmp/hdmi_connected
            switch_to_tft
            echo "HDMI odpojeno, přepnuto na TFT." >> $LOG_FILE
            systemctl restart lightdm 2>/dev/null || echo "LightDM/GDM restart doporučen"
        fi
    fi
=======
#!/bin/bash
# HDMI Hot-Plug Auto Switch pro Raspberry Pi 5
# Automaticky přepíná hlavní výstup mezi HDMI a TFT při připojení/odpojení HDMI

LOG_FILE="/var/log/hdmi_hotplug.log"
echo "=== Spuštění HDMI Hot-Plug $(date) ===" >> $LOG_FILE

# Funkce pro přepnutí na HDMI
switch_to_hdmi() {
    echo "Přepínám na HDMI..." >> $LOG_FILE
    sed -i '/hdmi_group/d;/hdmi_mode/d;/hdmi_cvt/d;/hdmi_drive/d;/display_rotate/d' /boot/config.txt
    tee -a /boot/config.txt > /dev/null <<EOL
hdmi_group=1
hdmi_mode=16
hdmi_drive=2
EOL
    echo "HDMI nastaveno" >> $LOG_FILE
}

# Funkce pro přepnutí na TFT
switch_to_tft() {
    echo "Přepínám na TFT..." >> $LOG_FILE
     sed -i '/hdmi_group/d;/hdmi_mode/d;/hdmi_cvt/d;/hdmi_drive/d;/display_rotate/d' /boot/config.txt
     tee -a /boot/config.txt > /dev/null <<EOL
hdmi_group=2
hdmi_mode=87
hdmi_cvt=800 480 60 6 0 0 0
hdmi_drive=1
display_rotate=0
EOL
    echo "TFT nastaveno" >> $LOG_FILE
}

# Funkce pro nastavení DPI/měřítka podle desktopu
set_dpi() {
    DESKTOP=$(echo $XDG_CURRENT_DESKTOP | tr '[:upper:]' '[:lower:]')
    case "$DESKTOP" in
        lxde|lxqt)
            xrdb -merge <<< "Xft.dpi: 120"
            echo 'export QT_SCALE_FACTOR=1.5' >> ~/.xprofile
            ;;
        gnome)
            gsettings set org.gnome.desktop.interface scaling-factor 2
            gsettings set org.gnome.desktop.interface text-scaling-factor 1.5
            echo 'export QT_SCALE_FACTOR=1.5' >> ~/.xprofile
            ;;
        xfce)
            xfconf-query -c xsettings -p /Xft/DPI -s 120
            echo 'export QT_SCALE_FACTOR=1.5' >> ~/.xprofile
            ;;
        *)
            echo 'export QT_SCALE_FACTOR=1.5' >> ~/.xprofile
            ;;
    esac
}

# Inicialní kontrola HDMI při startu
if tvservice -n | grep -q "device_name"; then
    switch_to_hdmi
else
    switch_to_tft
fi

set_dpi

# Sledování HDMI hot-plug
echo "Spouštím sledování HDMI hot-plug..." >> $LOG_FILE
while true; do
    sleep 2
    if tvservice -n | grep -q "device_name"; then
        if [ ! -f /tmp/hdmi_connected ]; then
            touch /tmp/hdmi_connected
            switch_to_hdmi
            echo "HDMI připojeno, přepnuto." >> $LOG_FILE
            systemctl restart lightdm 2>/dev/null || echo "LightDM/GDM restart doporučen"
        fi
    else
        if [ -f /tmp/hdmi_connected ]; then
            rm /tmp/hdmi_connected
            switch_to_tft
            echo "HDMI odpojeno, přepnuto na TFT." >> $LOG_FILE
            systemctl restart lightdm 2>/dev/null || echo "LightDM/GDM restart doporučen"
        fi
    fi
>>>>>>> 2d437cc2ae07a396d41a3b74e61ac94634aea845
done