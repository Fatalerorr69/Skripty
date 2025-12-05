#!/bin/bash
set -e

echo "[MHS] Detekce displeje…"

if lsusb | grep -qi "MHS"; then
    echo "MHS displej detekován přes USB."
    echo "MHS_USB"
    exit 0
fi

if dmesg | grep -qi "spi0.0"; then
    echo "MHS displej pravděpodobně typ SPI."
    echo "MHS_SPI"
    exit 0
fi

if dmesg | grep -qi "ili9486"; then
    echo "MHS displej ili9486"
    echo "MHS_ILI9486"
    exit 0
fi

echo "UNKNOWN"
exit 1
