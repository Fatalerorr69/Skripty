#!/bin/bash
echo "=== Starko AI Helper 2.0 ==="
read -p "Dotaz: " Q

case "$Q" in
    *adb*) echo "ADB tip: Zkus adb kill-server && adb start-server" ;;
    *fastboot*) echo "Fastboot tip: Drž Volume-Down + USB." ;;
    *boot*) echo "Boot oprava: fastboot flash boot boot.img" ;;
    *) echo "AI: Tento dotaz zatím neznám." ;;
esac
