# Stažení nejnovějšího obrazu nymea:kiosk
wget https://images.nymea.io/nymea-kiosk-latest.zip

# Rozbalení obrazu
unzip nymea-kiosk-latest.zip

# Příprava SD karty (nahraďte /dev/sdX vaším zařízením)
sudo dd if=nymea-kiosk-latest.img of=/dev/sdX bs=4M status=progress