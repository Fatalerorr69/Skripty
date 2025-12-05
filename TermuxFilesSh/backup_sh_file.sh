cat > backup_sh_files.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash

echo "[*] Povoluji přístup k úložišti..."
termux-setup-storage
sleep 1

DEST="/storage/emulated/0/TermuxBackupSH"

echo "[*] Vytvářím cílovou složku: $DEST"
mkdir -p "$DEST"

echo "[*] Vyhledávám všechny .sh soubory..."
COUNT=$(find "$HOME" -type f -name "*.sh" | wc -l)

echo "[*] Nalezeno souborů: $COUNT"
echo "[*] Kopíruji..."

find "$HOME" -type f -name "*.sh" -exec cp {} "$DEST" \;

echo ""
echo "==============================="
echo " Hotovo!"
echo " Zkopírováno .sh souborů: $COUNT"
echo " Výstupní složka:"
echo "   $DEST"
echo "==============================="
EOF
