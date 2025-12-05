#!/bin/bash
set -e

if [[ "$1" == "--auto" ]]; then
    echo "[MHS] Automatická detekce…"
fi

# Detekce SPI MHS35
if lsmod | grep -q "fb_ili9486"; then
    echo "[MHS] MHS 3.5\" displej detekován."
else
    echo "[MHS] Nenalezen modul fb_ili9486 – instaluji…"
    modprobe spi_bcm2835 || true
    modprobe fb_ili9486 || true
fi

# Konfigurace framebufferu
CONFIG="/boot/config.txt"
if ! grep -q "dtoverlay=mhs35" $CONFIG; then
    echo "[MHS] Přidávám do config.txt"
    echo "dtoverlay=mhs35" >> $CONFIG
fi

echo "[MHS] Hotovo – vyžadován restart."
