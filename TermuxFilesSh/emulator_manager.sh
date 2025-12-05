#!/bin/bash
# Správa emulátorů, ROM a BIOS TwisterOS SuperManager

EMULATOR_DIR="/opt/twisteros_supermanager/emulators"
ROM_DIR="/opt/twisteros_supermanager/ROMs"
BIOS_DIR="/opt/twisteros_supermanager/BIOS"

function list_emulators() {
    echo "Dostupné emulátory:"
    ls "$EMULATOR_DIR"
}

function list_roms() {
    echo "ROM soubory:"
    ls "$ROM_DIR"
}

function list_bios() {
    echo "BIOS soubory:"
    ls "$BIOS_DIR"
}

function run_emulator() {
    echo "Zadej název emulátoru:"
    read emu
    if [ -x "$EMULATOR_DIR/$emu" ]; then
        bash "$EMULATOR_DIR/$emu"
    else
        echo "Emulátor '$emu' neexistuje nebo není spustitelný."
    fi
    read -p "Stiskni Enter pro návrat..."
}

while true; do
    echo "=== Emulator Manager ==="
    echo "1) Vypsat emulátory"
    echo "2) Vypsat ROM"
    echo "3) Vypsat BIOS"
    echo "4) Spustit emulátor"
    echo "5) Návrat"
    read -p "Volba: " choice
    case $choice in
        1) list_emulators ;;
        2) list_roms ;;
        3) list_bios ;;
        4) run_emulator ;;
        5) break ;;
        *) echo "Neplatná volba." ;;
    esac
done
