# Instalace Netdata pro detailní monitoring
bash <(curl -Ss https://my-netdata.io/kickstart.sh)

# nebo instalace Cockpitu pro webové řízení
sudo apt-get install -y cockpit
sudo systemctl enable cockpit
sudo systemctl start cockpit