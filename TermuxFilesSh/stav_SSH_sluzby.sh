#!/bin/bash
# ===============================================================
# stav_SSH_sluzby.sh – Kontrola vzdálených služeb
# ===============================================================

echo "🔍 Kontrola SSH..."
systemctl status ssh --no-pager

echo "🖥 Kontrola VNC..."
systemctl status vncserver-x11-serviced --no-pager

echo "📡 Otevřené porty..."
ss -tuln | grep -E "(:22|:5900|:8080)"
