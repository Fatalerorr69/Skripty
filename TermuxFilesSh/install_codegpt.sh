#!/bin/bash
set -e

# ==========================================
# Automatická instalace Code Server + CodeGPT VSIX v Termuxu
# ==========================================

# 1️⃣ Aktualizace systému
echo "[1/6] Aktualizuji Termux..."
pkg update -y && pkg upgrade -y

# 2️⃣ Instalace Node.js a git
echo "[2/6] Instalace Node.js a git..."
pkg install -y nodejs git curl wget

# 3️⃣ Instalace Code Server
echo "[3/6] Instalace Code Server..."
curl -fsSL https://code-server.dev/install.sh | sh

# 4️⃣ Připrav VSIX soubor
VSIX_PATH="$HOME/dscodegpt.vsix"
if [ ! -f "$VSIX_PATH" ]; then
    echo "[4/6] Stahuji CodeGPT VSIX..."
    wget https://www.vsixhub.com/vsix/107240/dscodegpt-3.14.172_vsixhub.com.vsix -O "$VSIX_PATH"
fi

# 5️⃣ Instalace VSIX do Code Serveru
echo "[5/6] Instalace CodeGPT VSIX..."
code-server --install-extension "$VSIX_PATH"

# 6️⃣ Spuštění Code Server
echo "[6/6] Spouštím Code Server..."
echo "Code Server bude spuštěn na http://127.0.0.1:8080/"
echo "Heslo najdeš v ~/.config/code-server/config.yaml nebo defaultně při prvním spuštění."
echo "Pokud chceš otevřít URL automaticky, musíš mít nainstalovaný 'termux-open-url'."
echo ""

# Spustit na pozadí
code-server --bind-addr 127.0.0.1:8080 &

# Pokus automaticky otevřít URL v Termuxu
if command -v termux-open-url >/dev/null 2>&1; then
    sleep 3
    termux-open-url "http://127.0.0.1:8080/"
fi

echo "Instalace dokončena. Přihlas se do Code Serveru a ověř, že CodeGPT je aktivní."
