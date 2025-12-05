#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "=== Aktualizuji Termux ==="
pkg update -y && pkg upgrade -y

echo "=== Instalace základních nástrojů ==="
pkg install -y git curl wget proot unzip nano python python-pip nodejs openjdk-17 maven gh

echo "=== Instalace funkční OpenAI knihovny (bez Rust) ==="
pip uninstall -y openai jiter maturin || true
pip install --user "openai==0.28.1"

echo "=== Instalace watchdog (bez kompilace) ==="
pip install --user "watchdog==2.1.9"

echo "=== Instalace linters ==="
pip install --user pylint flake8
npm install -g eslint

echo "=== Instalace code-server ==="
pkg install -y tur-repo || true
pkg install -y code-server || true

if ! command -v code-server >/dev/null 2>&1; then
    echo "Fallback: Instalace code-server přes npm"
    npm install -g code-server
fi

echo "=== Instalace Termux X11 ==="
pkg install -y x11-repo
pkg install -y termux-x11 proot-distro

echo "=== Instalace Ubuntu sandbox ==="
proot-distro install ubuntu || true

echo "=== Vytvářím Web Dashboard ==="
mkdir -p ~/dev_dashboard
cat <<'EOF' > ~/dev_dashboard/server.js
const http = require('http');
const { exec } = require('child_process');

function run(cmd, res) {
    exec(cmd, (err, out, stderr) => {
        res.writeHead(200, {"Content-Type":"text/plain"});
        res.end(err ? stderr : out);
    });
}

http.createServer((req, res) => {
    if (req.url === "/status") run("uptime", res);
    else if (req.url === "/repos") run("ls -1", res);
    else if (req.url.startsWith("/clone?url=")) {
        const u = decodeURIComponent(req.url.replace("/clone?url=",""));
        run(`git clone ${u}`, res);
    }
    else {
        res.writeHead(200, {"Content-Type":"text/plain"});
        res.end("Dev Dashboard: /status /repos /clone?url=");
    }
}).listen(9000);

console.log("WEB DASHBOARD běží na http://127.0.0.1:9000");
EOF

echo "=== Vytvářím AI Analyzer (openai 0.28.1) ==="
cat <<'EOF' > ~/ai_repo_analyzer.py
import os, openai, json

openai.api_key = os.getenv("OPENAI_API_KEY")
repo = os.getenv("REPO_DIR")

print(f"[AI Analyzer] Analyzuji repozitář: {repo}")

def collect_files(root):
    files=[]
    for dp,_,fn in os.walk(root):
        for f in fn:
            if f.endswith((".js",".py",".java",".ts",".html",".css",".xml",".sh",".c",".cpp",".json")):
                files.append(os.path.join(dp,f))
    return files

files = collect_files(repo)
print(f"[AI Analyzer] Načteno {len(files)} souborů")

report = {}

for f in files:
    try:
        content = open(f,"r",encoding="utf-8",errors="ignore").read()
        msg = openai.ChatCompletion.create(
            model="gpt-4o-mini",
            messages=[{"role":"user","content":f"Analyze this file and list issues:\n{content}"}]
        )["choices"][0]["message"]["content"]
        report[f] = msg
    except Exception as e:
        report[f] = f"Error: {e}"

json.dump(report, open(os.path.join(repo,"AI_FULL_REPORT.json"),"w"), indent=2)
print("[AI Analyzer] HOTOVO")
EOF

echo "=== Vytvářím start skript ==="
cat <<'EOF' > ~/start_ai_dev_env.sh
#!/data/data/com.termux/files/usr/bin/bash

read -p "Zadej URL repozitáře GitHub: " URL
REPO=$(basename "$URL" .git)

if [ ! -d "$REPO" ]; then
    git clone "$URL"
fi

export REPO_DIR="$HOME/$REPO"

echo "=== Spouštím Code-Server ==="
code-server --bind-addr 127.0.0.1:8080 --auth none &

echo "=== Spouštím Web Dashboard ==="
node ~/dev_dashboard/server.js &

echo "=== Spouštím AI Analyzer ==="
python3 ~/ai_repo_analyzer.py &

echo "=== Spouštím Real-Time AI Watcher ==="
cd "$REPO"

python3 - <<PYTHON
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
import os, time, openai

openai.api_key = os.getenv("OPENAI_API_KEY")

class Watch(FileSystemEventHandler):
    def on_modified(self, e):
        if e.is_directory: return
        try:
            txt = open(e.src_path).read()
        except: return
        print(f"[AI] UPRAVENO: {e.src_path}")
        reply = openai.ChatCompletion.create(
            model="gpt-4o-mini",
            messages=[{"role":"user","content":"Improve this code:\n"+txt}]
        )["choices"][0]["message"]["content"]
        with open(e.src_path+".ai.txt","w") as f:
            f.write(reply)
        print(reply)

obs = Observer()
obs.schedule(Watch(), ".", recursive=True)
obs.start()

try:
    while True: time.sleep(1)
except KeyboardInterrupt:
    obs.stop()

obs.join()
PYTHON
EOF

chmod +x ~/start_ai_dev_env.sh

echo "=== INSTALACE DOKONČENA ==="
echo "Spusť:"
echo "   export OPENAI_API_KEY=\"TVŮJ_KEY\""
echo "   ./start_ai_dev_env.sh"
