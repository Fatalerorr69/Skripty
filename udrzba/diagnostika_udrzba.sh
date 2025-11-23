#!/bin/bash

# Globální proměnné
BACKUP_DIR="/var/backups/kali_system"

# Zkontroluje, zda skript běží jako root
if [[ $EUID -ne 0 ]]; then
   zenity --error --title="Chyba" --text="Tento skript musí být spuštěn jako root."
   exit 1
fi

# Kontrola a instalace zenity pro GUI
if ! command -v zenity &> /dev/null; then
    zenity --info --title="Instalace Zenity" --text="Nástroj 'zenity' pro GUI není nainstalován. Instaluji..."
    apt-get update -y
    apt-get install -y zenity
    if [ $? -ne 0 ]; then
        zenity --error --title="Chyba" --text="Instalace 'zenity' selhala. Skript nemůže pokračovat bez GUI."
        exit 1
    fi
fi

# Funkce pro aktualizaci systému
function aktualizace_a_upgrady {
    zenity --info --title="Aktualizace" --text="Spouštím aktualizaci a upgrade systému. Toto může chvíli trvat."
    apt-get update -y && apt-get upgrade -y && apt-get dist-upgrade -y
    if [ $? -eq 0 ]; then
        zenity --info --title="Dokončeno" --text="Systém je úspěšně aktualizován."
    else
        zenity --error --title="Chyba" --text="Aktualizace systému selhala."
    fi
}

# Funkce pro instalaci nástrojů
function instalace_nastroju {
    zenity --info --title="Instalace" --text="Instaluji potřebné nástroje (nmap, hydra, nikto atd.)."
    apt-get install -y nmap hydra sqlmap chkrootkit rsync preload debsums nikto
    if [ $? -eq 0 ]; then
        zenity --info --title="Dokončeno" --text="Nástroje jsou úspěšně nainstalovány."
    else
        zenity --error --title="Chyba" --text="Instalace nástrojů selhala."
    fi
}

# Funkce pro diagnostiku systému
function diagnostika_a_navrhy {
    VYSTUP=$( (
    echo "10" ; echo "# Kontrola volného místa na disku..."
    df -h / | awk 'NR==2 {print "Volné místo: " $4 " z " $2}'
    VOLNE_MISTO=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$VOLNE_MISTO" -ge 80 ]; then
        echo "🚨 Upozornění: Místo na disku je zaplněno z $VOLNE_MISTO%."
        echo "  - Návrh: Zkuste vyčistit systém (volba Čištění systému)."
    fi

    echo "40" ; echo "# Kontrola přerušených balíčků..."
    if dpkg -l | grep -q "rc"; then
        echo "🚨 Upozornění: Nalezeny přerušené balíčky."
        echo "  - Návrh: Zkuste je opravit příkazem 'sudo apt-get install -f'."
    else
        echo "  - Vše je v pořádku."
    fi

    echo "70" ; echo "# Kontrola rootkitů..."
    if command -v chkrootkit &> /dev/null; then
        sudo chkrootkit -q
    else
        echo "  - Nástroj chkrootkit není nainstalován. Instalujte ho (volba Instalace nástrojů)."
    fi
    echo "100" ; echo "Diagnostika dokončena."
    ) | zenity --progress --title="Diagnostika systému" --percentage=0 --auto-close)
    zenity --info --title="Výsledek diagnostiky" --text="$VYSTUP"
}

# Funkce pro čištění systému
function uklid_systemu {
    zenity --info --title="Čištění systému" --text="Spouštím čištění systému..."
    apt-get autoclean -y && apt-get autoremove -y
    rm -rf /var/cache/apt/archives/*.deb
    rm -rf /tmp/*
    zenity --info --title="Dokončeno" --text="Systém je vyčištěn."
}

# Funkce pro optimalizaci výkonu
function optimalizace_vykonu {
    zenity --info --title="Optimalizace výkonu" --text="Optimalizuji výkon systému. To může pomoci s rychlostí."
    sync; echo 3 > /proc/sys/vm/drop_caches
    if command -v preload &> /dev/null; then
        systemctl restart preload
    fi
    zenity --info --title="Dokončeno" --text="Optimalizace výkonu dokončena."
}

# Funkce pro zálohu systému
function zaloha_systemu {
    CIL=$(zenity --file-selection --directory --title="Vyberte adresář pro uložení zálohy")
    if [ -z "$CIL" ]; then
        zenity --warning --title="Zrušeno" --text="Záloha byla zrušena. Cílová cesta nebyla vybrána."
        return
    fi
    DATE_TIME=$(date +%Y-%m-%d_%H-%M-%S)
    BACKUP_PATH="$CIL/kali_backup_$DATE_TIME.tar.gz"
    
    zenity --info --title="Zálohování" --text="Spouštím zálohování systému do: $BACKUP_PATH"
    rsync -aAXv --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} / "$BACKUP_PATH"
    
    if [ $? -eq 0 ]; then
        zenity --info --title="Dokončeno" --text="Záloha byla úspěšně vytvořena."
    else
        zenity --error --title="Chyba" --text="Zálohování selhalo."
    fi
}

# Funkce pro obnovu systému
function obnova_systemu {
    ZALOHA_SOUBOR=$(zenity --file-selection --title="Vyberte záložní soubor (.tar.gz)")
    if [ ! -f "$ZALOHA_SOUBOR" ]; then
        zenity --warning --title="Zrušeno" --text="Obnova byla zrušena. Soubor neexistuje."
        return
    fi
    zenity --info --title="Obnovování" --text="Spouštím obnovu systému ze souboru: $ZALOHA_SOUBOR"
    tar -xzpvf "$ZALOHA_SOUBOR" -C /
    if [ $? -eq 0 ]; then
        zenity --info --title="Dokončeno" --text="Obnova systému byla úspěšně dokončena."
    else
        zenity --error --title="Chyba" --text="Obnova systému selhala."
    fi
}

# Funkce pro automatizaci skenování
function automaticke_skenovani {
    CIL_IP=$(zenity --entry --title="Nmap sken" --text="Zadejte cílovou IP adresu:")
    if [ -z "$CIL_IP" ]; then
        zenity --warning --title="Zrušeno" --text="Skenování zrušeno. Cíl nebyl zadán."
        return
    fi
    
    TYP_SKENU=$(zenity --list --radiolist --title="Nmap sken" --text="Vyberte typ skenu:" \
        --column="" --column="Typ" FALSE "porty" FALSE "OS" FALSE "agresivní")

    if [ -z "$TYP_SKENU" ]; then return; fi
    
    zenity --info --title="Skenování" --text="Spouštím sken: $TYP_SKENU na $CIL_IP"
    case $TYP_SKENU in
        porty) nmap -p- -sS -oX nmap_portscan_report.xml "$CIL_IP" ;;
        OS) nmap -O -oX nmap_osscan_report.xml "$CIL_IP" ;;
        agresivní) nmap -A -v -oX nmap_aggressive_report.xml "$CIL_IP" ;;
    esac
    zenity --info --title="Dokončeno" --text="Skenování dokončeno. Výstup uložen do souboru XML."
}

# Funkce pro generování zpráv
function generovat_zpravu {
    XML_SOUBOR=$(zenity --file-selection --title="Vyberte XML soubor z Nmapu")
    if [ ! -f "$XML_SOUBOR" ]; then
        zenity --warning --title="Zrušeno" --text="Generování zprávy zrušeno. Soubor neexistuje."
        return
    fi
    xsltproc "$XML_SOUBOR" -o "zprava_$(date +%Y%m%d%H%M%S).html"
    zenity --info --title="Dokončeno" --text="Zpráva v HTML formátu byla úspěšně vygenerována."
}

# Funkce pro audit zabezpečení
function audit_zabezpeceni {
    zenity --info --title="Audit zabezpečení" --text="Spouštím audit zabezpečení."
    VYSTUP=$( (
    echo "20" ; echo "# Kontrola integrity souborů s debsums..."
    if command -v debsums &> /dev/null; then
        debsums -c
    else
        echo "Nástroj debsums není nainstalován."
    fi

    echo "70" ; echo "# Skenování webových zranitelností s Nikto..."
    WEB_CIL=$(zenity --entry --title="Nikto sken" --text="Zadejte URL nebo IP webového serveru:")
    if [ -n "$WEB_CIL" ]; then
        nikto -h "$WEB_CIL" -o "nikto_report.txt"
    else
        echo "Cíl nebyl zadán. Skenování přeskočeno."
    fi
    echo "100" ; echo "Audit zabezpečení dokončen."
    ) | zenity --progress --title="Audit zabezpečení" --percentage=0 --auto-close)
    zenity --info --title="Výsledek auditu" --text="$VYSTUP"
}

# Funkce pro audit slabých hesel s Hydrou
function password_auditor {
    zenity --info --title="Audit hesel" --text="Spouštím audit slabých hesel s Hydrou."
    CIL_IP=$(zenity --entry --title="Audit hesel" --text="Zadejte cílovou IP adresu:")
    PROTOKOL=$(zenity --entry --title="Audit hesel" --text="Zadejte protokol (např. ssh, ftp, telnet):")
    if [ -z "$CIL_IP" ] || [ -z "$PROTOKOL" ]; then
        zenity --warning --title="Zrušeno" --text="Audit zrušen. Cíl nebo protokol nebyl zadán."
        return
    fi
    USERLIST=$(zenity --file-selection --title="Vyberte soubor se jmény uživatelů")
    PASSLIST=$(zenity --file-selection --title="Vyberte soubor se slovníkem hesel")
    if [ -z "$USERLIST" ] || [ -z "$PASSLIST" ]; then
        zenity --warning --title="Zrušeno" --text="Audit zrušen. Soubory nebyly vybrány."
        return
    fi
    hydra -L "$USERLIST" -P "$PASSLIST" "$PROTOKOL://$CIL_IP" -o hydra_report.txt
    zenity --info --title="Dokončeno" --text="Audit dokončen. Výsledky jsou uloženy v souboru hydra_report.txt."
}

# Hlavní GUI menu
function hlavni_menu {
    while true; do
        VYBER=$(zenity --list --title="Automatizace Kali" --text="Vyberte akci:" --column="Číslo" --column="Akce" \
            "1" "Aktualizovat a vylepšit systém" \
            "2" "Nainstalovat nástroje" \
            "3" "Spustit diagnostiku systému" \
            "4" "Vyčistit systém" \
            "5" "Optimalizovat výkon systému" \
            "6" "Vytvořit zálohu systému" \
            "7" "Obnovit systém ze zálohy" \
            "8" "Automatické skenování s Nmap" \
            "9" "Generovat zprávu ze skenu" \
            "10" "Spustit bezpečnostní audit" \
            "11" "Audit slabých hesel s Hydrou" \
            "12" "Konec")
        
        case $VYBER in
            "1") aktualizace_a_upgrady ;;
            "2") instalace_nastroju ;;
            "3") diagnostika_a_navrhy ;;
            "4") uklid_systemu ;;
            "5") optimalizace_vykonu ;;
            "6") zaloha_systemu ;;
            "7") obnova_systemu ;;
            "8") automaticke_skenovani ;;
            "9") generovat_zpravu ;;
            "10") audit_zabezpeceni ;;
            "11") password_auditor ;;
            "12") break ;;
            *) zenity --warning --title="Chyba" --text="Neplatná volba. Zkuste to znovu." ;;
        esac
    done
}

# Spuštění menu
hlavni_menu