#!/data/data/com.termux/files/usr/bin/bash
set -e

clear
echo "============================================"
echo " AI DEV ENVIRONMENT – CODE-CHAT INTEGRATION"
echo "============================================"

# -------------------------
# 1) Základní balíčky
# -------------------------
pkg update -y && pkg upgrade -y
pkg install -y git wget curl nodejs python python-pip proot nano openjdk-17 maven unzip

pip install --user --upgrade pip || true
pip install --user openai watchdog 2>/dev/null || true

# -------------------------
# 2) Instalace code-server
# -------------------------
if ! command -v code-server >/dev/null; then
    curl -fsSL https://code-server.dev/install.sh | sh || true
fi

# -------------------------
# 3) Kill staré instance
# -------------------------
pkill -f "code-server" 2>/dev/null || true
pkill -f "ai_chat_server.py" 2>/dev/null || true
sleep 1

# -------------------------
# 4) Výběr repozitáře
# -------------------------
echo "============================================"
echo " Vyber repozitář: "
echo "1) Klonovat nový"
echo "2) Použít existující"
read -p "Volba (1/2): " CHOICE

if [[ "$CHOICE" == "1" ]]; then
    read -p "Zadej URL GitHub repozitáře: " REPO_URL
    REPO_DIR="$HOME/$(basename $REPO_URL .git)"
    git clone "$REPO_URL" "$REPO_DIR"
elif [[ "$CHOICE" == "2" ]]; then
    read -p "Zadej cestu k existujícímu repozitáři: " REPO_DIR
    if [ ! -d "$REPO_DIR" ]; then
        echo "Repozitář neexistuje! Ukončuji..."
        exit 1
    fi
else
    echo "Neplatná volba! Ukončuji..."
    exit 1
fi

cd "$REPO_DIR"
git pull || true

# -------------------------
# 5) Instalace VSIX CodeGPT pluginu
# -------------------------
cd ~
wget -q https://www.vsixhub.com/vsix/176893/dscodegpt-3.14.135_vsixhub.com.vsix -O codegpt.vsix
code-server --install-extension ~/codegpt.vsix

# -------------------------
# 6) Spuštění code-server
# -------------------------
echo "=== Spouštím code-server ==="
code-server --bind-addr 127.0.0.1:8080 --auth none &

# -------------------------
# 7) AI Chat server (pro VS Code)
# -------------------------
mkdir -p "$HOME/ai_chat"
cat > "$HOME/ai_chat/ai_chat_server.py" << 'EOF'
import os
import openai
from flask import Flask, request, jsonify

api_key = os.getenv("OPENAI_API_KEY")
if not api_key:
    print("OPENAI_API_KEY není nastaven.")
    exit(0)

openai.api_key = api_key
app = Flask(__name__)

@app.route("/chat", methods=["POST"])
def chat():
    data = request.json
    msg = data.get("message", "")
    resp = openai.ChatCompletion.create(
        model="gpt-4",
        messages=[{"role":"user","content": msg}],
        temperature=0.2
    )
    return jsonify({"reply": resp['choices'][0]['message']['content']})

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5005)
EOF

nohup python "$HOME/ai_chat/ai_chat_server.py" >/dev/null 2>&1 &

echo "============================================"
echo " AI DEV ENVIRONMENT – READY"
echo "--------------------------------------------"
echo "Code-Server: http://127.0.0.1:8080"
echo "AI Chat API: http://127.0.0.1:5005"
echo "Repozitář: $REPO_DIR"
echo "============================================"
echo "Nezapomeň: export OPENAI_API_KEY='TVUJ_KEY'"
