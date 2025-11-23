#!/bin/bash

set -e

echo "=== 🔧 PEGI PG-9157 - Automatická instalace, párování a autoconnect ==="

echo "[1/7] Aktivace Bluetooth služby..."
sudo systemctl enable bluetooth
sudo systemctl start bluetooth

echo "[2/7] Spouštím skenování zařízení (čekej 10s)..."
timeout 10s bluetoothctl scan on > /dev/null &

sleep 10

echo "[3/7] Hledám zařízení obsahující 'PG-9157'..."
devices=$(bluetoothctl devices | grep -i 'PG-9157')

if [[ -z "$devices" ]]; then
  echo "❌ Žádné zařízení s názvem 'PG-9157' nebylo nalezeno."
  echo "👉 Ujisti se, že ovladač je v režimu párování (HOME + X) a spusť skript znovu."
  exit 1
fi

echo ""
echo "✅ Nalezená zařízení:"
echo "$devices"
echo ""
read -p "Zadej MAC adresu zařízení, které chceš připojit: " mac

echo "[4/7] Páruji a připojuji ovladač ($mac)..."
bluetoothctl << EOF
agent on
default-agent
pair $mac
trust $mac
connect $mac
EOF

# Kontrola připojení
echo "[5/7] Ověřuji připojení..."
sleep 2
if bluetoothctl info "$mac" | grep -q "Connected: yes"; then
    echo "✅ Úspěšně připojeno k $mac"
else
    echo "❌ Nepodařilo se připojit."
    exit 1
fi

# Vytvoření autoconnect skriptu
echo "[6/7] Vytvářím autoconnect skript..."
AUTOCONN="/usr/local/bin/pg9157-connect.sh"
sudo bash -c "echo -e '#!/bin/bash\nbluetoothctl connect $mac' > $AUTOCONN"
sudo chmod +x $AUTOCONN

# Přidání do crontabu
echo "[7/7] Přidávám automatické připojení do crontabu..."
(crontab -l 2>/dev/null; echo "@reboot $AUTOCONN") | crontab -

echo ""
echo "🎮 Hotovo! Ovladač PG-9157 se bude po startu RPi5 automaticky připojovat."