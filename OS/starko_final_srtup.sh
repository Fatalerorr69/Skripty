#!/usr/bin/env bash
# 🚀 Starko Final Setup verze-10+ FULL
# Kompletní univerzální setup pro Starko Workspace s vizuálním WebGUI, CI/CD a AI poradcem

set -e
echo "🌟 Starko Final Setup FULL v10+ začíná..."

# --- DETEKCE OS ---
OS_TYPE=$(uname | tr '[:upper:]' '[:lower:]')
IS_WINDOWS=false
IS_LINUX=false
if [[ "$OS_TYPE" == *"mingw"* || "$OS_TYPE" == *"msys"* || "$OS_TYPE" == *"cygwin"* ]]; then
    IS_WINDOWS=true
else
    IS_LINUX=true
fi

# --- PYTHON DETEKCE ---
PYTHON_CMD=""
for cmd in python3.11 python3 python; do
    if command -v $cmd >/dev/null 2>&1; then
        PYTHON_CMD=$cmd
        break
    fi
done
if [ -z "$PYTHON_CMD" ]; then
    echo "❌ Python 3.11+ nebyl nalezen."
    exit 1
fi
echo "🐍 Používám Python: $($PYTHON_CMD --version)"

# --- VENV ---
if [ ! -d "venv" ]; then
    $PYTHON_CMD -m venv venv
fi
if [ "$IS_WINDOWS" = true ]; then
    source venv/Scripts/activate
else
    source venv/bin/activate
fi
echo "✅ Virtuální prostředí aktivováno"

# --- INSTALACE MODULŮ ---
pip install --upgrade pip setuptools wheel
pip install flask dash requests rich pandas numpy psutil watchdog openai transformers torch prometheus_client eventlet

# --- STRUKTURA PROJEKTŮ ---
mkdir -p Projects/{AI_Workspace,Android_Toolkit,Docker_Containers,WebGUI,Starko_Tools,StarkoOS}
mkdir -p Projects/AI_Workspace/{models,scripts,data,logs}
mkdir -p Projects/WebGUI/{templates,static,logs}
mkdir -p Projects/Docker_Containers/{configs,images}
echo "# Starko Projects Workspace" > Projects/README.md

# --- GENERACE CI/CD SCRIPTS ---
CI_FILE="Projects/ci_cd.sh"
cat > $CI_FILE << 'EOL'
#!/usr/bin/env bash
# 🚀 Starko CI/CD - automatické testy a build
set -e
echo "🌟 Spouštím Starko CI/CD"

# Python testy
if [ -d "Projects/AI_Workspace/scripts" ]; then
    for f in Projects/AI_Workspace/scripts/*.py; do
        [ -f "$f" ] || continue
        echo "🐍 Testuji $f"
        python "$f"
    done
fi

# Docker build/test
if [ -d "Projects/Docker_Containers/configs" ]; then
    for f in Projects/Docker_Containers/configs/*.Dockerfile; do
        [ -f "$f" ] || continue
        IMAGE_NAME=$(basename "$f" .Dockerfile)
        echo "🐳 Build Docker $IMAGE_NAME"
        docker build -t "$IMAGE_NAME" -f "$f" .
    done
fi

# Waydroid check
if command -v waydroid >/dev/null 2>&1; then
    echo "📱 Waydroid session check"
    waydroid status || echo "Waydroid není spuštěn"
fi

# StarkOS ROM/BIOS check
if [ -d "Projects/StarkoOS" ]; then
    echo "🎮 Kontrola StarkOS modulů..."
    ls Projects/StarkoOS || echo "Žádné moduly"
fi

echo "✅ CI/CD dokončeno"
EOL
chmod +x $CI_FILE

# --- GitHub Actions workflow ---
mkdir -p Projects/.github/workflows
cat > Projects/.github/workflows/starko.yml << 'EOL'
name: Starko CI/CD
on:
  push:
    branches: [ main ]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - name: Setup Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.11'
    - name: Install dependencies
      run: |
        python -m pip install --upgrade pip
        pip install -r Projects/requirements.txt || true
    - name: Run CI/CD
      run: bash Projects/ci_cd.sh
EOL

# --- WebGUI s vizuálními tlačítky a live refresh ---
WEBGUI_FILE="Projects/WebGUI/app.py"
cat > $WEBGUI_FILE << 'EOL'
from flask import Flask, request, jsonify
import os, time, json, threading, subprocess

app = Flask(__name__)
LOG_FILE = "Projects/WebGUI/logs/live.log"
HISTORY_FILE = "Projects/WebGUI/logs/ai_history.json"

def append_log(msg):
    with open(LOG_FILE,"a") as f:
        f.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')} - {msg}\n")

def load_history():
    if os.path.exists(HISTORY_FILE):
        with open(HISTORY_FILE,"r") as f:
            return json.load(f)
    return []

def save_history(history):
    with open(HISTORY_FILE,"w") as f:
        json.dump(history,f,indent=2)

def run_system_command(cmd):
    append_log(f"Spouštím: {cmd}")
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        append_log(result.stdout)
        if result.stderr:
            append_log(result.stderr)
        return result.stdout
    except Exception as e:
        append_log(f"Chyba: {str(e)}")
        return str(e)

@app.route("/")
def index():
    logs=""
    if os.path.exists(LOG_FILE):
        with open(LOG_FILE,"r") as f:
            logs=f.read()
    modules = [
        {"name":"Python skript","cmd":"python Projects/AI_Workspace/scripts/test_script.py"},
        {"name":"Docker Hello World","cmd":"docker run hello-world"},
        {"name":"Waydroid session","cmd":"waydroid session start"},
        {"name":"StarkOS modul","cmd":"echo StarkOS modul spuštěn"},
        {"name":"ROM kontrola","cmd":"echo Kontrola ROM"},
        {"name":"BIOS kontrola","cmd":"echo Kontrola BIOS"},
        {"name":"Multiplayer server","cmd":"echo Spouštím multiplayer server"}
    ]
    buttons_html = ""
    for m in modules:
        buttons_html += f"<button onclick=\"runModule('{m['cmd']}')\">{m['name']}</button><br>"

    return f"""
    <h1>Starko AI Workspace + CI/CD v10+ Visual</h1>
    <div id="logs" style="border:1px solid #ccc;height:300px;overflow:auto;"><pre>{logs}</pre></div>
    <h2>Moduly:</h2>
    {buttons_html}

    <h2>AI Asistent:</h2>
    <input type="text" id="aiQuery" placeholder='Zadej dotaz...'>
    <button onclick="askAI()">Odeslat</button>
    <pre id="aiResponse"></pre>

    <script>
    async function runModule(cmd){
        let resp = await fetch('/run_module',{
            method:'POST', headers:{'Content-Type':'application/json'},
            body: JSON.stringify({module: cmd})
        });
        let data = await resp.json();
        alert('Modul spuštěn: '+data.module);
        refreshLogs();
    }

    async function askAI(){
        let query=document.getElementById('aiQuery').value;
        let resp=await fetch('/ai',{
            method:'POST', headers:{'Content-Type':'application/json'},
            body: JSON.stringify({query: query})
        });
        let data=await resp.json();
        document.getElementById('aiResponse').textContent=data.reply;
        refreshLogs();
    }

    async function refreshLogs(){
        let resp=await fetch('/get_logs');
        let data=await resp.json();
        document.getElementById('logs').innerHTML='<pre>'+data.logs+'</pre>';
    }

    setInterval(refreshLogs,3000);
    </script>
    """

@app.route("/get_logs")
def get_logs():
    logs=""
    if os.path.exists(LOG_FILE):
        with open(LOG_FILE,"r") as f:
            logs=f.read()
    return jsonify({"logs":logs})

@app.route("/ai",methods=["POST"])
def ai_assistant():
    data=request.json
    query=data.get("query","")
    recommendations=[]
    if "docker" in query.lower(): recommendations.append("Spustit další Docker kontejnery s AI projekty.")
    if "waydroid" in query.lower(): recommendations.append("Aktualizovat Android modul.")
    if "starkos" in query.lower(): recommendations.append("Zkontrolovat ROM a BIOSy pro StarkOS.")
    if "ci" in query.lower() or "pipeline" in query.lower(): recommendations.append("Spustit lokální CI/CD skript: bash Projects/ci_cd.sh")
    response=f"AI odpovídá: {query}\nDoporučení: {'; '.join(recommendations)}"
    history=load_history()
    history.append({"query":query,"reply":response})
    save_history(history)
    append_log(f"AI query: {query}")
    append_log(f"AI reply: {response}")
    return jsonify({"reply":response})

@app.route("/run_module",methods=["POST"])
def run_module():
    data=request.json
    module=data.get("module","")
    threading.Thread(target=run_system_command,args=(module,)).start()
    return jsonify({"status":"ok","module":module})

if __name__=="__main__":
    os.makedirs("Projects/WebGUI/logs",exist_ok=True)
    app.run(host="0.0.0.0",port=8080,debug=True)
EOL

echo "🎉 Starko Final Setup FULL v10+ připraven!"
echo "📁 Projekty: $(pwd)/Projects"
echo "🌐 WebGUI + AI: cd Projects/WebGUI && python app.py"
echo "💻 Spouštění modulů: POST /run_module (JSON {\"module\":\"name\"})"
echo "🛠️ Spuštění lokální CI/CD: bash Projects/ci_cd.sh"
echo "✅ Hotovo, kompletně vizuální, interaktivní, s live logy, AI poradcem a CI/CD."
