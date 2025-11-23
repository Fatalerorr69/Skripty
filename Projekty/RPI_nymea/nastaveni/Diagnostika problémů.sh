# Zobrazení logů nymea v reálném čase
journalctl -u nymead -f

# Kontrola stavu služeb
systemctl status nymead

# Testování síťové konektivity
nymeadctl --network-test