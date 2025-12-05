#!/data/data/com.termux/files/usr/bin/bash
set -e

clear
echo "============================================"
echo "   AI DEV ENVIRONMENT – CodeGPT FULL SETUP"
echo "============================================"

# -------------------------
# 1) Uživatelský vstup repozitáře
# -------------------------
read -p "Zadej URL GitHub repozitáře: " REPO_URL
REPO_DIR="$HOME/$(basename $REPO_URL .git)"

# -------------------------
# 2) Instalace základních balíčků
# -------------------------
echo "== Instalace nástrojů =="
pkg update -y && pkg upgrade -y
pkg install -y git wget curl nodejs python python-pip proot nano openjdk-17 maven

pip install --user --upgrade pip || true
pip install --user openai 2>/dev/null || true

# -------------------------
# 3) Instalace code-server
# -------------------------
if ! command -v code-server >/dev/null; then
    echo "== Instalace code-server =="
    curl -fsSL https://code-server.dev/install.sh | sh || true
fi

# -------------------------
# 4) Kill staré instance
# -------------------------
pkill -f "code-server" 2>/dev/null || true
sleep 1

# -------------------------
# 5) Klon nebo update repozitáře
# -------------------------
echo "== Načítám repozitář =="
if [ -d "$REPO_DIR" ]; then
    cd "$REPO_DIR"
    git pull
else
    git clone "$REPO_URL" "$REPO_DIR"
    cd "$REPO_DIR"
fi

# -------------------------
# 6) Instalace CodeGPT VSIX
# -------------------------
echo "== Instalace CodeGPT =="
cd ~
wget https://www.vsixhub.com/vsix/176893/dscodegpt-3.14.135_vsixhub.com.vsix -O codegpt.vsix
code-server --install-extension ~/codegpt.vsix

# -------------------------
# 7) Spuštění code-server
# -------------------------
echo "=== Spouštím code-server ==="
code-server --bind-addr 127.0.0.1:8080 --auth none &

# -------------------------
# 8) Vytvoření AI Dashboard
# -------------------------
mkdir -p "$HOME/dev_dashboard"
cat > "$HOME/dev_dashboard/server.js" << 'EOF'
const http = require('http');
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');

function run(cmd, res) {
    exec(cmd, (err, stdout, stderr) => {
        res.writeHead(200, {"Content-Type": "text/plain"});
        res.end(err ? stderr : stdout);
    });
}

http.createServer((req, res) => {
    if(req.url === "/status") run("uptime", res);
    else if(req.url === "/repos") run("ls -1", res);
    else if(req.url.startsWith("/clone?url=")) {
        const u = decodeURIComponent(req.url.replace("/clone?url=",""));
        run(`git clone ${u}`, res);
    }
    else if(req.url === "/ai-report") {
        const reportDir = path.join(process.env.HOME, "AI_REPORT");
        if(!fs.existsSync(reportDir)) { res.end("No AI report found."); return; }
        const files = fs.readdirSync(reportDir).map(f => fs.readFileSync(path.join(reportDir,f),"utf8")).join("\n\n");
        res.end(files);
    }
    else {
        res.end("AI Dev Dashboard:\n/status\n/repos\n/clone?url=URL\n/ai-report");
    }
}).listen(9000);

console.log("WEB DASHBOARD běží na http://127.0.0.1:9000");
EOF

nohup node "$HOME/dev_dashboard/server.js" >/dev/null 2>&1 &

# -------------------------
# 9) AI Analyzer
# -------------------------
mkdir -p "$HOME/AI_REPORT"
cat > "$HOME/ai_repo_analyzer.py" << 'EOF'
import os, openai

api_key = os.getenv("OPENAI_API_KEY")
if not api_key:
    print("[AI Analyzer] WARNING: OPENAI_API_KEY není nastaven.")
    exit(0)

openai.api_key = api_key
repo = os.getcwd()
report_dir = os.path.join(os.path.expanduser("~"), "AI_REPORT")
os.makedirs(report_dir, exist_ok=True)

for root, _, files in os.walk(repo):
    for f in files:
        if f.endswith((".py",".js",".ts",".html",".css",".java",".c",".cpp",".json",".sh")):
            try:
                with open(os.path.join(root,f), "r", encoding="utf-8", errors="ignore") as file:
                    content = file.read()
                prompt = f"Analyze this code and suggest improvements/fixes:\n{content}"
                resp = openai.ChatCompletion.create(
                    model="gpt-4",
                    messages=[{"role":"user","content":prompt}],
                    temperature=0.2
                )
                result = resp['choices'][0]['message']['content']
                outfile = os.path.join(report_dir, os.path.basename(f) + ".txt")
                with open(outfile, "w", encoding="utf-8") as out:
                    out.write(result)
            except Exception as e:
                print(f"[AI Analyzer ERROR] {f}: {e}")
EOF

nohup python "$HOME/ai_repo_analyzer.py" >/dev/null 2>&1 &

# -------------------------
# 10) Hotovo
# -------------------------
echo "============================================"
echo " AI DEV ENVIRONMENT S CodeGPT ÚSPĚŠNĚ SPUŠTĚN"
echo "--------------------------------------------"
echo " Dashboard:    http://127.0.0.1:9000"
echo " Code-Server:  http://127.0.0.1:8080"
echo " Repozitář:    $REPO_DIR"
echo " AI REPORTS:   $HOME/AI_REPORT/"
echo "============================================"
echo "Nezapomeň: export OPENAI_API_KEY='TVUJ_KEY'"
