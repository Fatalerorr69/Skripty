#!/bin/bash
# NymeaKiosk Ultimate System - Full Auto GitHub Upload + URL + SHA256 check
# Autor: Fatalerorr69

set -e

# === KONFIGURACE ===
REMOTE_ZIP_URL="https://github.com/Fatalerorr69/nymeakiosk-ultimate-system.git"  # Změň na skutečnou URL
REMOTE_SHA256_URL="https://github.com/Fatalerorr69/nymeakiosk-ultimate-system.git.sha256" # URL souboru se SHA256

# === Dotaz na GitHub údaje ===
read -p "Zadej GitHub username: " GITHUB_USER
read -sp "Zadej GitHub Personal Access Token (PAT): " GITHUB_TOKEN
echo
read -p "Zadej název repozitáře (např. nymeakiosk-ultimate-system): " REPO_NAME
read -p "Chceš, aby repozitář byl private? (y/n): " PRIVATE_ANSWER
if [[ "$PRIVATE_ANSWER" =~ ^[Yy] ]]; then
    PRIVATE=true
else
    PRIVATE=false
fi
BRANCH="main"
REMOTE_URL="https://$GITHUB_USER:$GITHUB_TOKEN@github.com/$GITHUB_USER/$REPO_NAME.git"

# === FUNKCE ===
check_git() {
    for cmd in git curl unzip sha256sum; do
        if ! command -v $cmd &>/dev/null; then
            echo "[!] $cmd není nainstalován. Instalace..."
            if command -v apt &>/dev/null; then
                sudo apt update && sudo apt install -y $cmd
            elif command -v pkg &>/dev/null; then
                pkg install -y $cmd
            else
                echo "Nepodařilo se nainstalovat $cmd – nainstaluj ručně."
                exit 1
            fi
        fi
    done
}

check_url() {
    echo "[*] Kontrola dostupnosti URL: $1"
    if curl -s --head --request GET "$1" | grep "200 OK" > /dev/null; then
        echo "[+] URL dostupná."
    else
        echo "[!] URL není dostupná nebo neexistuje: $1"
        exit 1
    fi
}

download_zip() {
    if [ ! -f "nymeakiosk-ultimate-system.zip" ]; then
        check_url "$REMOTE_ZIP_URL"
        echo "[*] Stahuji ZIP soubor z $REMOTE_ZIP_URL ..."
        curl -L -o nymeakiosk-ultimate-system.zip "$REMOTE_ZIP_URL"
        echo "[+] Staženo nymeakiosk-ultimate-system.zip"
    else
        echo "[=] ZIP soubor již existuje, přeskočeno stahování."
    fi
}

verify_sha256() {
    if check_url "$REMOTE_SHA256_URL"; then
        echo "[*] Stahuji SHA256 soubor..."
        curl -L -o nymeakiosk-ultimate-system.zip.sha256 "$REMOTE_SHA256_URL"
        echo "[*] Ověřuji SHA256..."
        sha256sum -c nymeakiosk-ultimate-system.zip.sha256
        echo "[+] SHA256 ověřeno."
    else
        echo "[!] SHA256 soubor nedostupný, přeskočeno ověření."
    fi
}

create_repo() {
    echo "[*] Kontroluji, zda repozitář existuje..."
    if curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$GITHUB_USER/$REPO_NAME" \
        | grep -q '"id"'; then
        echo "[=] Repo již existuje. Pokračuji..."
    else
        echo "[*] Vytvářím nový repozitář $REPO_NAME ..."
        curl -s -H "Authorization: token $GITHUB_TOKEN" \
             -d "{\"name\":\"$REPO_NAME\",\"private\":$PRIVATE}" \
             https://api.github.com/user/repos >/dev/null
        echo "[+] Repo vytvořeno."
    fi
}

upload_repo() {
    echo "[*] Přecházím do složky projektu..."
    cd "$(dirname "$0")"

    echo "[*] Rozbaluji ZIP soubor..."
    unzip -o nymeakiosk-ultimate-system.zip -d ./nymeakiosk-ultimate-system

    echo "[*] Inicializuji git..."
    git init
    git branch -M "$BRANCH"

    echo "[*] Přidávám vzdálený repozitář..."
    git remote remove origin 2>/dev/null || true
    git remote add origin "$REMOTE_URL"

    echo "[*] Přidávám soubory a commit..."
    git add .
    git commit -m "Initial commit - NymeaKiosk Ultimate System v3.0" || true

    echo "[*] Push na GitHub..."
    git push -u origin "$BRANCH" --force

    echo "[+] Projekt úspěšně nahrán: https://github.com/$GITHUB_USER/$REPO_NAME"
}

# === START ===
check_git
download_zip
verify_sha256
create_repo
upload_repo
