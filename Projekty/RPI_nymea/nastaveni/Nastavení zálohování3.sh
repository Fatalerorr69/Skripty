# Nastavení práv a spuštění
sudo chmod +x /usr/local/bin/nymea-backup.sh

# Přidání do cronu pro každodenní zálohování
(crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/nymea-backup.sh") | crontab -