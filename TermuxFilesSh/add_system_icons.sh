#!/bin/bash
echo "📁 Přidávám systémové ikony..."

APP_DIR="/usr/share/applications"

create_icon() {
NAME=$1
EXEC=$2
ICON=$3

sudo tee $APP_DIR/$NAME.desktop >/dev/null <<EOF
[Desktop Entry]
Name=$NAME
Exec=$EXEC
Icon=$ICON
Type=Application
Categories=Utility;
Terminal=false
EOF
}

create_icon "Smart Suite Dashboard" "chromium-browser http://localhost:8080" "preferences-system"
create_icon "Smart Suite Cleaner" "bash ~/system_cleaner.sh" "system-cleanup"
create_icon "Smart Sensors" "bash ~/plugins/plugin_sensors.sh" "utilities-system-monitor"

echo "✅ Ikony přidány!"
