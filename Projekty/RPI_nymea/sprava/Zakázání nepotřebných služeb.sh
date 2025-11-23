# Kontrola aktivních služeb
sudo systemctl list-units --type=service --state=running

# Zakázání nepotřebných služeb (podle potřeby)
sudo systemctl disable nazev_sluzby