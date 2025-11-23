# Testování Zigbee sítě
sudo nymeadctl --zigbee --debug

# Testování Bluetooth zařízení
sudo hcitool lescan

# Testování MQTT
mosquitto_sub -h localhost -t "nymea/#"