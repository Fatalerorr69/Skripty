# Kontrola stavu nymea služby
sudo systemctl status nymead

# Kontrola dostupnosti webového rozhraní
curl -I http://localhost

# Zobrazení systémových logů
journalctl -u nymead -f