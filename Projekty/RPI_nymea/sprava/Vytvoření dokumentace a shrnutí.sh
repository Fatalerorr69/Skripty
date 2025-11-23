# Generování shrnutí nastavení
sudo tee /home/nymea/SETUP_SUMMARY.md <<EOF
# Shrnutí nastavení nymea:kiosk

## Základní informace
- Datum instalace: $(date)
- Hostname: $(hostname)
- IP adresa: $(hostname -I)

## Nainstalované komponenty
- nymea:core: $(dpkg -l | grep nymea-core | awk '{print $3}')
- nymea:app: $(dpkg -l | grep nymea-app | awk '{print $3}')

## Bezpečnostní nastavení
- Firewall: $(sudo ufw status | grep Status)
- Fail2ban: $(systemctl is-active fail2ban)

## Monitorování
- Netdata: http://$(hostname -I | awk '{print $1}'):19999
- Node Exporter: http://$(hostname -I | awk '{print $1}'):9100

## Zálohování
- Automatické zálohování: každý den ve 2:00
- Umístění záloh: /home/nymea/backups/

## Užitečné příkazy
- Stav služeb: systemctl status nymead
- Monitorování: system-monitor
- Záloha: nymea-backup.sh

## Další poznámky
Tento systém byl nastaven pomocí automatizovaných skriptů.
Pro další údržbu použijte skripty v /usr/local/bin/
EOF

echo "=== Dokumentace vytvořena ==="
echo "Shrnutí nastavení je v /home/nymea/SETUP_SUMMARY.md"