#!/bin/bash

echo "⚠️ Reset XFCE nastavení..."
rm -rf ~/.config/xfce4
rm -rf ~/.cache/sessions

echo "🔁 Restart prostředí..."
xfce4-panel --restart
xfdesktop --reload
