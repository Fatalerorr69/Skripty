# Instalace základních bezpečnostních nástrojů
sudo apt-get install -y ufw fail2ban

# Konfigurace firewallu
sudo ufw allow ssh
sudo ufw allow 80/tcp    # HTTP pro webové rozhraní
sudo ufw allow 443/tcp   # HTTPS pro zabezpečené připojení
sudo ufw enable

# Základní konfigurace fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban