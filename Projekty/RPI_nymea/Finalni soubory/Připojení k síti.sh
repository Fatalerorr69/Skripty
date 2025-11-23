# Zobrazení dostupných WiFi sítí
nmcli device wifi list

# Připojení k WiFi síti
nmcli device wifi connect "SSID_vaší_sítě" password "vaše_heslo"

# Kontrola připojení
ping -c 3 google.com