#!/data/data/com.termux/files/usr/bin/bash
# Univerzální spouštěč: root (su/tsu) nebo fallback proot-distro (kali/debian)

# Zkusit su
if command -v su >/dev/null 2>&1; then
    echo "[+] SU nalezen — pokouším se o root shell..."
    su -c "id && exec bash" && exit 0 || echo "[-] su selhalo nebo je zablokováno."
fi

# Zkusit tsu
if command -v tsu >/dev/null 2>&1; then
    echo "[+] tsu nalezen — pokouším se o root shell..."
    tsu && exit 0 || echo "[-] tsu selhalo nebo je zablokováno."
fi

# fallback: proot-distro (kali pokud existuje, jinak debian)
echo "[*] Root není dostupný — fallback na proot-distro."
if proot-distro list | grep -q kali; then
    echo "[*] Přihlašuji do Kali..."
    proot-distro login kali
else
    if ! proot-distro list | grep -q debian; then
        echo "[*] Debian není nainstalován — nainstaluji Debian..."
        proot-distro install debian
    fi
    echo "[*] Přihlašuji do Debianu..."
    proot-distro login debian
fi
