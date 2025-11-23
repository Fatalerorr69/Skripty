Jak použít tento skript:
Stáhněte si skript na své Raspberry Pi 5:

bash
wget -O rpi5-config.sh https://example.com/rpi5-config.sh
Nastavte oprávnění ke spuštění:

bash
chmod +x rpi5-config.sh
Spusťte skript (bez sudo!):

bash
./rpi5-config.sh
Sledujte průběh instalace a konfigurace

Po dokončení restartujte systém:

bash
sudo reboot
Co skript dělá:
Detekuje hardware - zjistí model, paměť, teplotu

Nainstaluje nástroje - Docker, Python, Node.js a utility

Nakonfiguruje nymea - smart home platformu s pluginy

Optimalizuje systém - vyladí výkon pro RPi 5

Nastaví síť a zabezpečení - firewall, fail2ban, SSH

Instaluje monitoring - Netdata, Cockpit, Prometheus

Nastaví kontejnerové aplikace - Home Assistant, Node-RED, Portainer

Vytvoří zálohovací systém - automatické zálohování

Skript je kompletní a obsahuje vše potřebné pro nastavení Raspberry Pi 5 jako výkonného domácího serveru a smart home hubu.

