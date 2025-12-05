#!/data/data/com.termux/files/usr/bin/bash
set -e

clear
echo "============================================"
echo " AI DEV ENVIRONMENT – INTERACTIVE SETUP"
echo "============================================"

# -------------------------
# 1) Instalace základních balíčků
# -------------------------
echo "== Instalace nástrojů =="
pkg update -y && pkg upgrade -y
pkg install -y git wget curl nodejs python python-pip proot nano openjdk-17 maven unzip

pip install --user --upgrade pip || true
pip install --user openai watchdog 2>/dev/null || true

# -------------------------
# 2) Instalace code-server
# -------------------------
if ! command -v code-server >/dev/null; then
    echo "== Instalace code-server =="
    curl -fsSL https://code-server.dev/install.sh | sh || true
fi

# -------------------------
# 3) Instalace CodeGPT VSIX
# -------------------------
cd ~
echo "== Instalace CodeGPT VSIX =="
wget -q https://www.vsixhub.com/vsix/176893/dscodegpt-3.14.135_vsixhub.com.vsix -O codegpt.vsix
code-server --install-extension ~/codegpt.vsix

# -------------------------
# 4) Kill staré instance
# -------------------------
pkill -f "code-server" 2>/dev/null || true
pkill -f "ai_repo_analyzer.py" 2>/dev/null || true
pkill -f "ai_watcher.py" 2>/dev/null || true
sleep 1

# -------------------------
# 5) Výběr repozitáře
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
# 6) Spuštění code-server
# -------------------------
echo "=== Spouštím code-server ==="
code-server --bind-addr 127.0.0.1:8080 --auth none &

# -------------------------
# 7) Vytvoření a spuštění dashboardu
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
# 8) AI Analyzer + Watcher
# -------------------------
mkdir -p "$HOME/AI_REPORT"

cat > "$HOME/ai_repo_analyzer.py" << 'EOF'
import os, openai

api_key = os.getenv("OPENAI_API_KEY")
if not api_key:
    print("[AI Analyzer] OPENAI_API_KEY není nastaven.")
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

cat > "$HOME/ai_watcher.py" << 'EOF'
import os, time, openai

api_key = os.getenv("OPENAI_API_KEY")
if not api_key:
    print("[AI Watcher] OPENAI_API_KEY není nastaven.")
    exit(0)

openai.api_key = api_key
repo = os.getcwd()
report_dir = os.path.join(os.path.expanduser("~"), "AI_REPORT")
os.makedirs(report_dir, exist_ok=True)

tracked_files = {}
for root, _, files in os.walk(repo):
    for f in files:
        if f.endswith((".py",".js",".ts",".html",".css",".java",".c",".cpp",".json",".sh")):
            tracked_files[os.path.join(root,f)] = os.path.getmtime(os.path.join(root,f))

print("[AI Watcher] Sleduji změny v repozitáři...")

while True:
    for f in tracked_files.keys():
        if not os.path.exists(f): continue
        mtime = os.path.getmtime(f)
        if mtime > tracked_files[f]:
            print(f"[AI Watcher] Soubor změněn: {f}")
            tracked_files[f] = mtime
            try:
                with open(f, "r", encoding="utf-8", errors="ignore") as file:
                    content = file.read()
                prompt = f"Analyze this code and suggest improvements/fixes:\n{content}"
                resp = openai.ChatCompletion.create(
                    model="gpt-4",
                    messages=[{"role":"user","content":prompt}],
                    temperature=0.2
                )
                patch_file = f + ".ai.patch"
                with open(patch_file, "w", encoding="utf-8") as out:
                    out.write(resp['choices'][0]['message']['content'])
                print(f"[AI Watcher] Patch uložen: {patch_file}")
            except Exception as e:
                print(f"[AI Watcher ERROR] {f}: {e}")
    time.sleep(5)
EOF

nohup python "$HOME/ai_watcher.py" >/dev/null 2>&1 &

# -------------------------
# 9) Interaktivní menu
# -------------------------
while true; do
    echo "=================================="
    echo " INTERAKTIVNÍ MENU AI DEV ENVIRONMENT"
    echo "1) Spustit AI Analyzer ručně"
    echo "2) Zobrazit AI reporty"
    echo "3) Spustit patch na změněný soubor"
    echo "4) Git commit & push"
    echo "5) Otevřít dashboard (web)"
    echo "6) Otevřít code-server (web)"
    echo "7) Ukončit"
    read -p "Volba: " MENU_CHOICE

    case $MENU_CHOICE in
        1) python "$HOME/ai_repo_analyzer.py" ;;
        2) ls -lh "$HOME/AI_REPORT/" ;;
        3) read -p "Zadej cestu k souboru: " FILE; cat "$FILE.ai.patch" ;;
        4) git add . && git commit -m "AI update" && git push ;;
        5) echo "Otevři http://127.0.0.1:9000" ;;
        6) echo "Otevři http://127.0.0.1:8080" ;;
        7) echo "Ukončuji..."; pkill -f "code-server"; pkill -f "ai_repo_analyzer.py"; pkill -f "ai_watcher.py"; exit 0 ;;
        *) echo "Neplatná volba" ;;
    esac
done
