# Zobrazení dostupných pluginů
sudo apt search nymea-plugin-

# Instalace často používaných pluginů:
sudo apt-get install -y \
    nymea-plugin-zigbee \
    nymea-plugin-mqttclient \
    nymea-plugin-networkdetector \
    nymea-plugin-tasmota \
    nymea-plugin-shelly \
    nymea-plugin-modbus \
    nymea-plugin-kodi

# Restart nymea služby pro načtení nových pluginů
sudo systemctl restart nymead