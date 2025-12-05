#!/data/data/com.termux/files/usr/bin/bash
set -e

clear
echo "============================================"
echo " AI DEV CODESPACE – FULL INTEGRATION START"
echo "============================================"

# 1) Vstup repozitáře
read -p "Zadej URL repozitáře GitHub (HTTPS nebo SSH): " REPO_URL
REPO_DIR="$HOME/$(basename $REPO_URL .git)"

# 2) Instalace základních balíčků
pkg update -y && pkg upgrade -y
pkg install -y git wget curl nodejs python python-pip proot unzip nano openjdk-17 maven
pip install --user --upgrade pip || true
pip install --user openai watchdog 2>/dev/null || true
npm install -g eslint

# 3) Code-Server
if ! command -v code-server >/dev/null; then
    curl -fsSL https://code-server.dev/install.sh | sh || true
fi

# 4) Kill staré procesy
pkill -f "code-server" 2>/dev/null || true
pkill -f "ai_watcher_codespace.py" 2>/dev/null || true
sleep 1

# 5) Klon nebo update repozitáře
if [ -d "$REPO_DIR" ]; then
    cd "$REPO_DIR"
    git pull
else
    git clone "$REPO_URL" "$REPO_DIR"
    cd "$REPO_DIR"
fi

# 6) Instalace CodeGPT pluginu
echo "=== Instalace CodeGPT pluginu ==="
code-server --install-extension DanielSanMedium.vscode-codegpt || true

# 7) Spuštění Code-Server
nohup code-server --bind-addr 127.0.0.1:8080 --auth none >/dev/null 2>&1 &
sleep 2

# 8) Web Dashboard
mkdir -p "$HOME/dev_dashboard"
cat > "$HOME/dev_dashboard/server.js" << 'EOF'
const http = require('http');
const fs = require('fs');
const path = require('path');
http.createServer((req,res)=>{
  if(req.url==="/status") res.end("Running\n");
  else if(req.url==="/ai-report"){
    const dir = path.join(process.env.HOME,"AI_REPORT");
    if(!fs.existsSync(dir)){ res.end("No AI report"); return; }
    const files = fs.readdirSync(dir).map(f=>fs.readFileSync(path.join(dir,f),"utf8")).join("\n\n");
    res.end(files);
  } else res.end("AI Dev Dashboard");
}).listen(9000);
console.log("WEB DASHBOARD běží na http://127.0.0.1:9000");
EOF
nohup node "$HOME/dev_dashboard/server.js" >/dev/null 2>&1 &

# 9) AI Watcher + Auto Commit/Push + Interactive VS Code chat
mkdir -p "$HOME/AI_REPORT"
cat > "$HOME/ai_watcher_codespace.py" << 'EOF'
import os, time, subprocess, openai

api_key = os.getenv("OPENAI_API_KEY")
if not api_key:
    print("[AI Watcher Codespace] OPENAI_API_KEY není nastaven.")
    exit(0)

openai.api_key = api_key
repo = os.getcwd()
report_dir = os.path.join(os.path.expanduser("~"), "AI_REPORT")
os.makedirs(report_dir, exist_ok=True)

tracked_files = {os.path.join(root,f): os.path.getmtime(os.path.join(root,f))
                 for root,_,files in os.walk(repo)
                 for f in files if f.endswith((".py",".js",".ts",".html",".css",".java",".c",".cpp",".json",".sh"))}

while True:
    for f in tracked_files.keys():
        if not os.path.exists(f): continue
        mtime = os.path.getmtime(f)
        if mtime > tracked_files[f]:
            tracked_files[f] = mtime
            print(f"[AI Watcher Codespace] Soubor změněn: {f}")
            try:
                with open(f,"r",encoding="utf-8",errors="ignore") as file:
                    content = file.read()
                prompt = f"Analyze and refactor code, suggest improvements:\n{content}"
                resp = openai.ChatCompletion.create(
                    model="gpt-4",
                    messages=[{"role":"user","content":prompt}],
                    temperature=0.2
                )
                result = resp['choices'][0]['message']['content']
                patch_file = f + ".ai.patch"
                with open(patch_file,"w",encoding="utf-8") as out: out.write(result)
                print(f"[AI Watcher Codespace] Patch uložen: {patch_file}")

                # Commit a push
                subprocess.run(["git","add", patch_file])
                subprocess.run(["git","commit","-m", f"AI patch for {os.path.basename(f)}"])
                subprocess.run(["git","push"])
                print(f"[AI Watcher Codespace] Commit a push proveden pro {patch_file}")

            except Exception as e:
                print(f"[AI Watcher Codespace ERROR] {f}: {e}")
    time.sleep(5)
EOF

nohup python "$HOME/ai_watcher_codespace.py" >/dev/null 2>&1 &

# 10) Hotovo
echo "============================================"
echo " AI DEV CODESPACE – FULL INTEGRATION SPUŠTĚN"
echo " Dashboard:    http://127.0.0.1:9000"
echo " Code-Server:  http://127.0.0.1:8080"
echo " Repozitář:    $REPO_DIR"
echo " AI REPORTS:   $HOME/AI_REPORT/"
echo "============================================"
echo "Nezapomeň: export OPENAI_API_KEY='TVUJ_KEY'"
