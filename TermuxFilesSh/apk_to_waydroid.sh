#!/bin/bash

APK=$1
if [ -z "$APK" ]; then echo "Použití: apk_to_waydroid.sh soubor.apk"; exit 1; fi

echo "📦 Instaluji APK do Waydroid..."
sudo waydroid app install "$APK"

echo "📱 Aplikace nainstalována!"
