#!/bin/bash

# --- Skript pro detekci zařízení ---

if command -v adb &>/dev/null; then
  echo "🔍 Hledám připojená zařízení ADB..."
  devices=$(adb devices | grep -w "device" | awk '{print $1}')

  if [ -z "$devices" ]; then
    zenity --warning --text="Žádné ADB zařízení nebylo nalezeno."
  else
    zenity --info --text="Nalezena následující zařízení:\n\n$devices\n\nPokračujte s dalšími akcemi."
    for device_serial in $devices; do
      model=$(adb -s "$device_serial" shell getprop ro.product.model | tr -d '\r')
      android_ver=$(adb -s "$device_serial" shell getprop ro.build.version.release | tr -d '\r')
      echo "📱 Detekováno: $model (Android $android_ver) - $device_serial"
      # Zde by se mohla provádět další automatická analýza pro AI poradce
    done
  fi
else
  zenity --error --text="ADB není nainstalováno nebo není v PATH. Zkontrolujte instalaci UltraOS Toolkitu."
fi

zenity --info --text="Detekce zařízení dokončena."