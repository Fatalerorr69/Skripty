#!/usr/bin/env bash
# install_universal_ai_analyzer.sh
# Universal installer for AI Project Analyzer (Debian/Ubuntu/RPi5 compatible)
# Includes: interactive model selection, Ollama/LocalAI options, ChromaDB, Streamlit UI, FastAPI, plugins, codegen
# Author: Generated for Starko, 2025
set -euo pipefail
IFS=$'\n\t'

# --------- Config ---------
BASE_DIR="/opt/ai_project_analyzer"
ENV_FILE="/etc/ai_project_analyzer/env"
SYSTEMD_SERVICE="/etc/systemd/system/ai_project_analyzer.service"
LOG="/var/log/ai_project_analyzer_install.log"
PY_VERSION_REQUIRED="3.10"

# --------- helpers ----------
log() { echo -e "[$(date '+%F %T')] $*" | tee -a "$LOG"; }
error_exit() { echo "ERROR: $*" | tee -a "$LOG"; exit 1; }

# --------- root check ----------
if [[ $EUID -ne 0 ]]; then
  error_exit "Spusť jako root (sudo)."
fi

# --------- detect OS & arch ----------
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS_ID=$ID
  PRETTY_NAME=${PRETTY_NAME:-$NAME}
else
  error_exit "Nepodporovaný systém (chybí /etc/os-release)."
fi
ARCH=$(uname -m)
log "Detected OS: $PRETTY_NAME, ID=$OS_ID, ARCH=$ARCH"

# --------- update & base packages ----------
log "Updating packages..."
apt update -y >> "$LOG" 2>&1
apt upgrade -y >> "$LOG" 2>&1

log "Installing base packages..."
apt install -y python3 python3-venv python3-pip git curl wget build-essential \
  ca-certificates gnupg lsb-release unzip pkg-config jq lshw >/dev/null 2>&1 || true

# --------- docker install if missing ----------
if ! command -v docker >/dev/null 2>&1; then
  log "Installing Docker..."
  curl -fsSL https://get.docker.com | sh >> "$LOG" 2>&1 || warn="Docker install warning"
  systemctl enable --now docker || true
else
  log "Docker already installed."
fi

# docker compose plugin
if ! docker compose version >/dev/null 2>&1; then
  log "Installing Docker Compose plugin..."
  apt-get update -y >/dev/null 2>&1
  apt-get install -y docker-compose-plugin >/dev/null 2>&1 || true
fi

# --------- GPU detection ----------
HAS_NVIDIA=0
if command -v nvidia-smi >/dev/null 2>&1; then
  HAS_NVIDIA=1
  log "NVIDIA GPU detected."
else
  # quick PCI check
  if lspci | grep -i nvidia >/dev/null 2>&1; then
    log "NVIDIA hardware present but nvidia-smi missing (drivers not installed)."
  fi
fi

# --------- create dirs & env file ----------
log "Preparing directories..."
rm -rf "$BASE_DIR"
mkdir -p "$BASE_DIR"/{data/{input,output},plugins,logs,venv,src,codegen}
chown -R root:root "$BASE_DIR"
mkdir -p "$(dirname "$ENV_FILE")"
touch "$ENV_FILE"
chmod 600 "$ENV_FILE"

# --------- create venv & install python libs ----------
log "Creating Python virtualenv..."
python3 -m venv "$BASE_DIR/venv"
"$BASE_DIR/venv/bin/pip" install --upgrade pip setuptools wheel >/dev/null 2>&1

log "Installing Python packages (this can take several minutes)..."
"$BASE_DIR/venv/bin/pip" install --upgrade langchain llama-index chromadb sentence-transformers \
  tiktoken transformers fastapi uvicorn streamlit aiofiles python-multipart openai anthropic \
  google-generativeai requests python-dotenv psutil aiohttp unstructured faiss-cpu >/dev/null 2>&1 || true

# if NVIDIA present, attempt faiss-cuda (best-effort)
if [ "$HAS_NVIDIA" -eq 1 ]; then
  log "Attempting to install faiss-gpu (best-effort)..."
  "$BASE_DIR/venv/bin/pip" install faiss-gpu >/dev/null 2>&1 || log "faiss-gpu install failed; using faiss-cpu"
fi

# --------- Local runtimes options ----------
cat <<'EOF'
Vyber lokální runtime (pokud chceš používat offline modely):
1) Pouze cloud API (doporučeno)
2) Instalovat Ollama (lokální modely, vyžaduje RAM)
3) Instalovat LocalAI (docker image)
EOF
read -rp "Vyber (1-3, default 1): " RUNTIME_CHOICE
RUNTIME_CHOICE=${RUNTIME_CHOICE:-1}

if [ "$RUNTIME_CHOICE" -eq 2 ]; then
  log "Instalace Ollama (pokud podporováno architekturou)..."
  if [[ "$ARCH" == "x86_64" || "$ARCH" == "aarch64" ]]; then
    curl -fsSL https://ollama.com/install.sh | sh >> "$LOG" 2>&1 || log "Ollama - instalace selhala nebo vyžaduje interakci."
  else
    log "Ollama automatická instalace není dostupná pro architekturu $ARCH."
  fi
elif [ "$RUNTIME_CHOICE" -eq 3 ]; then
  log "Pull LocalAI/llama.cpp docker image (best-effort)..."
  docker pull ghcr.io/go-skynet/llama.cpp:latest >> "$LOG" 2>&1 || log "LocalAI image pull selhal."
fi

# --------- interactive model selection ----------
cat <<'TXT'
Vyber primární model/zdroj:
1) OpenAI GPT-4-Turbo (cloud) — nejlepší přesnost, placené
2) Anthropic Claude 3 Opus (cloud) — obrovské kontexty, placené
3) Google Gemini 1.5 Pro (cloud) — výkonný, placené
4) DeepSeek / OpenAI-compatible custom endpoint
5) Lokální (Ollama/LocalAI) — offline, soukromé, náročné
TXT
read -rp "Volba (1-5, default 1): " MODEL_CHOICE
MODEL_CHOICE=${MODEL_CHOICE:-1}

# wipe env file and prepare basic lines
echo "# AI Project Analyzer environment" > "$ENV_FILE"
echo "BASE_DIR=\"$BASE_DIR\"" >> "$ENV_FILE"
case "$MODEL_CHOICE" in
  1)
    echo "MODEL=OPENAI" >> "$ENV_FILE"
    echo "INFO_MODEL=\"OpenAI GPT-4-Turbo: vysoká kvalita, placená API.\"" >> "$ENV_FILE"
    read -rp "Zadej OpenAI API key (sk-...): " OPENAI_KEY
    echo "OPENAI_API_KEY=\"$OPENAI_KEY\"" >> "$ENV_FILE"
    ;;
  2)
    echo "MODEL=CLAUDE" >> "$ENV_FILE"
    echo "INFO_MODEL=\"Anthropic Claude 3 Opus: velmi dlouhý kontext, placené API.\"" >> "$ENV_FILE"
    read -rp "Zadej Anthropic API key: " ANTHROPIC_KEY
    echo "ANTHROPIC_API_KEY=\"$ANTHROPIC_KEY\"" >> "$ENV_FILE"
    ;;
  3)
    echo "MODEL=GEMINI" >> "$ENV_FILE"
    echo "INFO_MODEL=\"Google Gemini 1.5 Pro: výkonný model, přesnost na textu.\" " >> "$ENV_FILE"
    read -rp "Zadej Google API key (nebo path k service account JSON): " GOOGLE_KEY
    echo "GOOGLE_API_KEY=\"$GOOGLE_KEY\"" >> "$ENV_FILE"
    ;;
  4)
    echo "MODEL=CUSTOM" >> "$ENV_FILE"
    read -rp "Zadej OpenAI-compatible API base URL (např. https://...): " CUSTOM_BASE
    echo "OPENAI_API_BASE=\"$CUSTOM_BASE\"" >> "$ENV_FILE"
    read -rp "Zadej API key pro endpoint: " CUSTOM_KEY
    echo "OPENAI_API_KEY=\"$CUSTOM_KEY\"" >> "$ENV_FILE"
    ;;
  5)
    echo "MODEL=LOCAL" >> "$ENV_FILE"
    echo "INFO_MODEL=\"Lokální model (Ollama/LocalAI): offline, nutno nainstalovat runtime a model.\" " >> "$ENV_FILE"
    ;;
  *)
    echo "MODEL=OPENAI" >> "$ENV_FILE"
    ;;
esac

chmod 600 "$ENV_FILE"
log "Env uložen v $ENV_FILE (perms 600)."

# --------- write application source files ----------
log "Vytvářím aplikační soubory..."

# analyzer.py (parallel, plugin-aware)
cat > "$BASE_DIR/src/analyzer.py" <<'PY'
#!/usr/bin/env python3
# Parallel analyzer with plugin support
import os, sys, json, traceback
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
import multiprocessing
MAX_WORKERS = max(1, multiprocessing.cpu_count() - 1)

ENV_PATH = "/etc/ai_project_analyzer/env"
def load_env():
    env = {}
    if os.path.exists(ENV_PATH):
        with open(ENV_PATH) as f:
            for line in f:
                line=line.strip()
                if not line or line.startswith("#"): continue
                if "=" in line:
                    k,v = line.split("=",1)
                    env[k]=v.strip().strip('"').strip("'")
    return env
ENV = load_env()

# plugin loader
PLUGINS_DIR = "/opt/ai_project_analyzer/plugins"
PLUGIN_FUNCS = []
if os.path.isdir(PLUGINS_DIR):
    for p in Path(PLUGINS_DIR).glob("*.py"):
        try:
            import importlib.util as iu
            spec = iu.spec_from_file_location(p.stem, str(p))
            m = iu.module_from_spec(spec)
            spec.loader.exec_module(m)
            if hasattr(m, "analyze"):
                PLUGIN_FUNCS.append(m.analyze)
        except Exception as e:
            print("Plugin load error", p, e)

def read_small_file(path, max_bytes=3*1024*1024):
    try:
        with open(path, "r", errors="ignore") as f:
            return f.read(max(0, min(max_bytes, os.path.getsize(path))))
    except:
        return ""

def analyze_file(path):
    path = str(path)
    content = read_small_file(path)
    r = {"path": path, "analysis": None, "plugins": [], "error": None}
    try:
        # plugin heuristics
        for plugin in PLUGIN_FUNCS:
            try:
                res = plugin(path, content)
                r["plugins"].append(res)
            except Exception as e:
                r["plugins"].append({"plugin_error": str(e)})
        # prepare prompt snippet
        prompt = f"Analyze file: {Path(path).name}\\nPath: {path}\\nContent (truncated):\\n{content[:10000]}\\nProvide: purpose, dependencies, suggestions for reorganization, security notes (secrets)."
        backend = ENV.get("MODEL","OPENAI").upper()
        if backend=="OPENAI" and ENV.get("OPENAI_API_KEY"):
            import openai
            openai.api_key = ENV.get("OPENAI_API_KEY")
            resp = openai.ChatCompletion.create(model="gpt-4-turbo", messages=[{"role":"user","content":prompt}], temperature=0.2)
            text = resp.choices[0].message.content
        elif backend=="CLAUDE" and ENV.get("ANTHROPIC_API_KEY"):
            import anthropic
            client = anthropic.Anthropic(api_key=ENV.get("ANTHROPIC_API_KEY"))
            comp = client.completions.create(prompt=prompt, model="claude-3-opus-20240229", max_tokens=800)
            text = comp.get("completion", comp.get("text", "(no reply)"))
        elif backend=="GEMINI" and ENV.get("GOOGLE_API_KEY"):
            import google.generativeai as genai
            genai.configure(api_key=ENV.get("GOOGLE_API_KEY"))
            model = genai.Models.get("gemini-1.5-pro")
            text = model.generate(prompt=prompt).text
        else:
            # fallback to generic OpenAI-compatible endpoint
            import requests, os
            url = os.getenv("OPENAI_API_BASE","https://api.openai.com/v1/chat/completions")
            headers = {"Authorization": f"Bearer {os.getenv('OPENAI_API_KEY','')}", "Content-Type":"application/json"}
            payload = {"model":"gpt-4o-mini","messages":[{"role":"user","content":prompt}], "temperature":0.2}
            try:
                rres = requests.post(url, json=payload, headers=headers, timeout=60)
                text = rres.json().get("choices",[{}])[0].get("message",{}).get("content","(no reply)")
            except Exception as e:
                text = f"(analysis failed: {e})"
        r["analysis"] = str(text)
    except Exception as e:
        r["error"] = traceback.format_exc()
    return r

def collect_files(base):
    for root,_,files in os.walk(base):
        for f in files:
            p = os.path.join(root,f)
            try:
                if os.path.getsize(p) <= 5*1024*1024:
                    yield p
            except Exception:
                continue

def analyze_folder(inp, outp):
    outp = os.path.abspath(outp)
    os.makedirs(outp, exist_ok=True)
    files = list(collect_files(inp))
    results=[]
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as ex:
        futures = {ex.submit(analyze_file,f): f for f in files}
        for fut in as_completed(futures):
            try:
                res = fut.result()
                results.append(res)
            except Exception as e:
                results.append({"path": str(futures[fut]), "error": str(e)})
    with open(os.path.join(outp,"analysis.json"),"w",encoding="utf-8") as fh:
        json.dump(results, fh, indent=2, ensure_ascii=False)
    with open(os.path.join(outp,"summary.json"),"w",encoding="utf-8") as fh:
        json.dump({"file_count": len(results)}, fh, indent=2)
    return outp

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: analyzer.py <input_dir> <output_dir>")
        sys.exit(2)
    analyze_folder(sys.argv[1], sys.argv[2])
PY

# generator.py (creates new_structure.md)
cat > "$BASE_DIR/src/generator.py" <<'PY'
#!/usr/bin/env python3
import os, sys, json
ENV_PATH="/etc/ai_project_analyzer/env"
def load_env():
    env={}
    if os.path.exists(ENV_PATH):
        with open(ENV_PATH) as f:
            for l in f:
                if "=" in l:
                    k,v=l.strip().split("=",1)
                    env[k]=v.strip().strip('"').strip("'")
    return env
ENV=load_env()

def generate(analysis_json, out_dir):
    with open(analysis_json,"r",encoding="utf-8") as fh:
        data=json.load(fh)
    summary=""
    for it in data:
        summary += f"FILE: {it.get('path')}\\n"
        if it.get("analysis"):
            summary += it.get("analysis")[:3000] + "\\n\\n"
    prompt=f\"\"\"You are an AI software architect. Based on the per-file analysis below, produce:
1) A recommended directory/tree for a new self-contained project.
2) A list of files with short descriptions.
3) For key scripts/config files provide example content (shell/python/Dockerfile/etc).
Return as a markdown file with clear CODE blocks where appropriate.

ANALYSIS:
{summary[:20000]}
\"\"\"
    text="(no model response)"
    backend = ENV.get("MODEL","OPENAI").upper()
    try:
        if backend=="OPENAI" and ENV.get("OPENAI_API_KEY"):
            import openai
            openai.api_key = ENV.get("OPENAI_API_KEY")
            res = openai.ChatCompletion.create(model="gpt-4-turbo", messages=[{"role":"user","content":prompt}], temperature=0.2)
            text = res.choices[0].message.content
        else:
            text = "FALLBACK: no cloud model configured. The analysis summary is below.\\n\\n" + summary[:20000]
    except Exception as e:
        text = "MODEL ERROR: " + str(e)
    os.makedirs(out_dir, exist_ok=True)
    out_md = os.path.join(out_dir,"new_structure.md")
    with open(out_md,"w",encoding="utf-8") as fh:
        fh.write(text)
    print(out_md)
    return out_md

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: generator.py <analysis_dir>")
        sys.exit(2)
    out = generate(os.path.join(sys.argv[1],"analysis.json"), sys.argv[1])
    print("Generated:", out)
PY

# codegen: convert new_structure.md into files (basic heuristic)
cat > "$BASE_DIR/src/codegen.py" <<'PY'
#!/usr/bin/env python3
import os, sys, re
from pathlib import Path

def parse_md_to_files(md_text):
    # heuristic:
    # find headings that look like "path/to/file.ext" or code fences with filenames in comments
    files = {}
    # detect code fences with header like "```bash filename: path/to/file.sh"
    fence_pattern = re.compile(r"```(?:bash|sh|python|Dockerfile)?\s*(?:filename:)?\s*([^\n\r]+)?\n(.*?)```", re.S)
    for m in fence_pattern.finditer(md_text):
        fname = (m.group(1) or "").strip()
        body = m.group(2).strip()
        if fname:
            files[fname] = body
    # fallback: look for lines starting with "- path: "
    for line in md_text.splitlines():
        if line.strip().startswith("- "):
            # very simple; skip
            continue
    return files

def write_files(files, base_dir):
    for p, content in files.items():
        dest = Path(base_dir) / p
        dest.parent.mkdir(parents=True, exist_ok=True)
        with open(dest,"w",encoding="utf-8") as fh:
            fh.write(content)
        # make scripts executable if looks like shell
        if dest.suffix in (".sh",) or "bash" in content.splitlines()[0:2]:
            dest.chmod(0o755)
    return list(files.keys())

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: codegen.py <md_file> <output_base>")
        sys.exit(2)
    md = Path(sys.argv[1]).read_text(encoding="utf-8")
    files = parse_md_to_files(md)
    out = write_files(files, sys.argv[2])
    print("Created files:", out)
PY

# FastAPI minimal API
cat > "$BASE_DIR/src/api.py" <<'PY'
#!/usr/bin/env python3
from fastapi import FastAPI, UploadFile, File
import shutil, os
from pathlib import Path
app = FastAPI()
BASE = "/opt/ai_project_analyzer"
DATA_IN = os.path.join(BASE,"data","input")
DATA_OUT = os.path.join(BASE,"data","output")

@app.post("/upload/")
async def upload(file: UploadFile = File(...)):
    dest = Path(DATA_IN)/file.filename
    with open(dest,"wb") as fh:
        shutil.copyfileobj(file.file, fh)
    return {"status":"ok","path":str(dest)}

@app.post("/analyze/")
def analyze():
    import subprocess
    subprocess.Popen([os.path.join(BASE,"venv","bin","python"), os.path.join(BASE,"src","analyzer.py"), DATA_IN, DATA_OUT])
    return {"status":"started"}

@app.post("/generate/")
def generate():
    import subprocess
    subprocess.Popen([os.path.join(BASE,"venv","bin","python"), os.path.join(BASE,"src","generator.py"), DATA_OUT])
    return {"status":"started"}
PY

# Streamlit UI
cat > "$BASE_DIR/src/webui.py" <<'PY'
#!/usr/bin/env python3
import streamlit as st, os, subprocess, time
st.set_page_config(page_title="AI Project Analyzer", layout="wide")
st.title("AI Project Analyzer")
BASE="/opt/ai_project_analyzer"
IN_DIR = st.text_input("Input folder", os.path.join(BASE,"data","input"))
OUT_DIR = st.text_input("Output folder", os.path.join(BASE,"data","output"))

if st.button("Run analysis"):
    st.info("Starting analyzer (background)...")
    subprocess.Popen([os.path.join(BASE,"venv","bin","python"), os.path.join(BASE,"src","analyzer.py"), IN_DIR, OUT_DIR])
    st.success("Analysis started.")

if st.button("Generate new_structure.md"):
    st.info("Generating new_structure.md...")
    subprocess.Popen([os.path.join(BASE,"venv","bin","python"), os.path.join(BASE,"src","generator.py"), OUT_DIR])
    st.success("Generation started.")

if st.button("Run codegen (new_structure.md -> files)"):
    md = os.path.join(OUT_DIR,"new_structure.md")
    if os.path.exists(md):
        subprocess.Popen([os.path.join(BASE,"venv","bin","python"), os.path.join(BASE,"src","codegen.py"), md, os.path.join(BASE,"codegen")])
        st.success("Codegen started (check /opt/ai_project_analyzer/codegen)")
    else:
        st.error("Missing new_structure.md in output folder.")

st.markdown("### Upload files")
uploaded = st.file_uploader("Drop files here", accept_multiple_files=True)
if uploaded:
    for f in uploaded:
        with open(os.path.join(IN_DIR, f.name),"wb") as fh:
            fh.write(f.getbuffer())
    st.success("Uploaded files.")
    
st.markdown("### Logs")
logfile = os.path.join(BASE,"logs","app.log")
if os.path.exists(logfile):
    st.text(Path(logfile).read_text()[-4000:])
PY

# make executables
chmod +x "$BASE_DIR/src/"*.py

# --------- plugins: secret detector, dockerfile analyzer, dependency graph ----------
log "Installing example plugins..."

cat > "$BASE_DIR/plugins/secret_detector.py" <<'PY'
# secret_detector.py
# simple plugin: regex-based secrets detection
import re
def analyze(path, content):
    findings=[]
    patterns = {
        "AWS_KEY": r"AKIA[0-9A-Z]{16}",
        "Likely API key": r"(?i)api[_-]?key\\W*[:=]\\W*[A-Za-z0-9\\-_.]{8,}",
        "Private key start": r"-----BEGIN (RSA|PRIVATE) KEY-----"
    }
    for name,pat in patterns.items():
        if re.search(pat, content):
            findings.append({"type": name, "match": True})
    return {"plugin":"secret_detector","findings":findings}
PY

cat > "$BASE_DIR/plugins/dockerfile_analyzer.py" <<'PY'
# dockerfile_analyzer.py
def analyze(path, content):
    if path.lower().endswith("dockerfile") or "dockerfile" in path.lower():
        lines = content.splitlines()
        froms = [l for l in lines if l.strip().upper().startswith("FROM")]
        return {"plugin":"dockerfile_analyzer","froms": froms, "line_count": len(lines)}
    return {"plugin":"dockerfile_analyzer","skipped": True}
PY

cat > "$BASE_DIR/plugins/dependency_graph.py" <<'PY'
# dependency_graph.py
# naive dependency extractor for package.json / requirements.txt / pyproject.toml
import json, re
def analyze(path, content):
    ret={"plugin":"dependency_graph","deps":[]}
    if path.endswith("package.json"):
        try:
            j=json.loads(content)
            deps=j.get("dependencies",{})
            ret["deps"]=list(deps.keys())
        except:
            ret["error"]="json_parse_failed"
    elif path.endswith("requirements.txt"):
        ret["deps"]=[line.strip().split("==")[0] for line in content.splitlines() if line.strip() and not line.strip().startswith("#")]
    elif path.endswith("pyproject.toml"):
        # naive parse
        m=re.findall(r'name\\s*=\\s*\"([^\"]+)\"', content)
        ret["deps"]=m
    else:
        ret["skipped"]=True
    return ret
PY

# --------- systemd service ----------
log "Creating systemd service for autostart (Streamlit UI)..."
cat > "$SYSTEMD_SERVICE" <<'UNIT'
[Unit]
Description=AI Project Analyzer (Streamlit)
After=network.target docker.service

[Service]
Type=simple
User=root
EnvironmentFile=/etc/ai_project_analyzer/env
WorkingDirectory=/opt/ai_project_analyzer
ExecStart=/opt/ai_project_analyzer/venv/bin/streamlit run /opt/ai_project_analyzer/src/webui.py --server.port 8501 --server.address 0.0.0.0
Restart=on-failure
RestartSec=5
StandardOutput=syslog
StandardError=syslog

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now ai_project_analyzer.service || log "systemd enable/start failed; you can start manually."

# --------- final notes ----------
log "Installation complete."
cat <<'END' | tee -a "$LOG"
DONE.

Web UI (Streamlit) should be reachable at: http://<your-machine-ip>:8501
Input folder:  /opt/ai_project_analyzer/data/input
Output folder: /opt/ai_project_analyzer/data/output
Codegen folder: /opt/ai_project_analyzer/codegen

To run manually:
  sudo systemctl start ai_project_analyzer
Or:
  source /opt/ai_project_analyzer/venv/bin/activate
  streamlit run /opt/ai_project_analyzer/src/webui.py --server.port 8501

API (FastAPI):
  /opt/ai_project_analyzer/venv/bin/uvicorn /opt/ai_project_analyzer/src/api:app --host 0.0.0.0 --port 8080

Plugins:
  Drop python plugin files with function analyze(path, content) -> dict into /opt/ai_project_analyzer/plugins

Code generation:
  After generation, run codegen:
    /opt/ai_project_analyzer/venv/bin/python /opt/ai_project_analyzer/src/codegen.py /opt/ai_project_analyzer/data/output/new_structure.md /opt/ai_project_analyzer/codegen

Security:
  - API keys stored in: /etc/ai_project_analyzer/env (600 perms)
  - If using NVIDIA GPU, install drivers & nvidia-docker (see official NVIDIA docs)

If you want, mohu:
  A) Přidat připravené pluginy pro: detekce tajných klíčů (vylepšená), static analysis (cpp/java), a deploy skripty.
  B) Vylepšit codegen, aby uměl lépe parsovat markdown -> soubory a automaticky commitovat do Git.
  C) Připravit krok-za-krokem GPU instalaci pro tvůj stroj.

END

log "Installer finished successfully."
