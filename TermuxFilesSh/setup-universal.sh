#!/data/data/com.termux/files/usr/bin/bash
# setup-universal.sh - univerzální Termux setup + Kali-like tools v proot-distro
set -e

echo "[*] Aktualizuji Termux repozitáře..."
pkg update -y && pkg upgrade -y

echo "[*] Instalace základních balíčků..."
pkg install -y proot proot-distro root-repo tsu git curl wget nano vim python python-pip build-essential openssh htop unzip

echo "[*] Povolení přístupu ke storage (pokud potřeba)..."
termux-setup-storage || true

# Vytvoření spouštěče
mkdir -p ~/bin
cat > ~/bin/universal-root.sh <<'UNIV'
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
UNIV
chmod +x ~/bin/universal-root.sh

# Instalace Kali přes proot-distro (pokud uživatel souhlasí)
echo
echo "[?] Chceš nainstalovat Kali (proot-distro) s Kali-tools? Bude to stahovat stovky MB. Odpověz 'y' pro ANO, jinak cokoliv pro SKIP."
read -r ANSWER
if [ "\$ANSWER" = "y" ] || [ "\$ANSWER" = "Y" ]; then
    if ! proot-distro list | grep -q kali; then
        echo "[*] Instalace Kali (proot-distro) — to může chvíli trvat..."
        proot-distro install kali
    else
        echo "[=] Kali už je nainstalována."
    fi

    echo "[*] Spouštím Kali jednorázově a instaluji Kali-tools-top10 + další nástroje..."
    proot-distro login kali -- bash -c "
set -e
apt update && apt upgrade -y
# hlavní meta-balíček Kali top10; doplňkové užitečné nástroje
apt install -y kali-tools-top10 nmap sqlmap hydra john aircrack-ng nikto net-tools iproute2 isc-dhcp-client tcpdump \
    wireshark-qt metasploit-framework || true
# vytvořit příznak, že jsme inicializovali
mkdir -p /root/.config && touch /root/.config/.kali_init_done
echo '[=] Kali v proot-distro je připravena.'
exec bash
"
else
    echo "[*] Instalaci Kali jsi přeskočil. Pokud to změníš, spusť ~/setup-universal.sh znovu a potvrď instalaci Kali."
fi

echo
echo "[=] Hotovo. Spouštěč pro root/proot je: ~/bin/universal-root.sh"
echo "Pro spuštění napiš: ~/bin/universal-root.sh"
