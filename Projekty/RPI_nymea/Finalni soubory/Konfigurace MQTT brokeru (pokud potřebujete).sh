# Instalace Mosquitto MQTT brokeru
sudo apt-get install -y mosquitto mosquitto-clients

# Nastavení hesla pro MQTT
sudo mosquitto_passwd -c /etc/mosquitto/passwd nymea
sudo systemctl restart mosquitto