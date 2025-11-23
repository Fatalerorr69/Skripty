# Instalace Home Assistant pomocí Docker
sudo apt-get install -y docker.io
sudo docker run -d \
  --name homeassistant \
  --privileged \
  --restart=unless-stopped \
  -e TZ=Europe/Prague \
  -v /home/nymea/hass:/config \
  --network=host \
  ghcr.io/home-assistant/home-assistant:stable