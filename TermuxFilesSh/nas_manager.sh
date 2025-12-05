#!/bin/bash
# Správa NAS a síťového úložiště

NAS_DIR="/opt/twisteros_supermanager/nas_storage"

function mount_nas() {
    echo "Zadej NAS adresu (IP/share):"
    read nas_addr
    echo "Zadej uživatele NAS:"
    read nas_user
    echo "Zadej heslo NAS:"
    read -s nas_pass
    sudo mount -t cifs //$nas_addr $NAS_DIR -o username=$nas_user,password=$nas_pass
    echo "NAS připojeno do $NAS_DIR"
}

function unmount_nas() {
    sudo umount $NAS_DIR
    echo "NAS odpojeno."
}

while true; do
    echo "=== NAS Manager ==="
    echo "1) Připojit NAS"
    echo "2) Odpojit NAS"
    echo "3) Vypsat obsah NAS"
    echo "4) Návrat"
    read -p "Volba: " choice
    case $choice in
        1) mount_nas ;;
        2) unmount_nas ;;
        3) ls -lh "$NAS_DIR" ;;
        4) break ;;
        *) echo "Neplatná volba." ;;
    esac
    read -p "Stiskni Enter pro pokračování..."
done
