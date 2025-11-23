#!/bin/bash

# Finální automatizovaný skript pro nasazení ai-chatbot-manager v Dockeru na Kali Linux 2025.2
# Verze: 1.2.0 (Srpen 2025)
# Funkce: Instalace Dockeru, WiFi pentest nástrojů, sestavení image, spuštění, zabezpečení
# Nové: Integrace WiFi penetračního testování (Aircrack-ng, Wifite, Kismet, Hostapd)

echo "Spouštím nasazení ai-chatbot-manager s WiFi pentest integrací..."
echo "Datum a čas: $(date)"

# --- Parametry ---
GPU_ENABLED=1  # Použít GPU, pokud je dostupné
MODEL_DOWNLOAD=1  # Stáhnout model
WEBUI_AUTH="admin:securepassword123"  # Přihlašovací údaje pro WebUI
DB_ENCRYPT=0  # Bez šifrování DB
REPO_URL="https://github.com/your-repo/ai-chatbot-manager.git"  # Nahraďte vaším repozitářem
IMAGE_NAME="ai-chatbot-manager:latest"
CONTAINER_NAME="chatbot"
WIFI_INTERFACE="wlan0"  # Výchozí WiFi rozhraní

# Zpracování argumentů
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-gpu) GPU_ENABLED=0; shift ;;
        --skip-model-download) MODEL_DOWNLOAD=0; shift ;;
        --auth) WEBUI_AUTH="$2"; shift 2 ;;
        --encrypt-db) DB_ENCRYPT=1; shift ;;
        --wifi-interface) WIFI_INTERFACE="$2"; shift 2 ;;
        *) echo "Neznámý argument: $1"; exit 1 ;;
    esac
done

# --- Funkce ---
check_error() {
    if [ $? -ne 0 ]; then
        echo "Chyba: $1"
        exit 1
    fi
}

# --- Krok 1: Příprava prostředí ---
echo "Krok 1: Instaluji Docker a závislosti..."

sudo apt update && sudo apt upgrade -y
check_error "Nepodařilo se aktualizovat systém."

sudo apt install -y docker.io git python3 python3-pip libespeak1 nmap metasploit-framework aircrack-ng kismet wifite hostapd firmware-linux-nonfree
check_error "Nepodařilo se nainstalovat Docker a závislosti."

sudo systemctl enable docker --now
check_error "Nepodařilo se spustit Docker."

sudo usermod -aG docker $USER
newgrp docker
check_error "Nepodařilo se přidat uživatele do skupiny docker."

# Instalace NVIDIA Docker (pokud je GPU a GPU_ENABLED=1)
if [ $GPU_ENABLED -eq 1 ] && nvidia-smi &> /dev/null; then
    echo "Detekován NVIDIA GPU, instaluji NVIDIA Docker..."
    distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
    curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
    curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
    sudo apt update && sudo apt install -y nvidia-docker2
    check_error "Nepodařilo se nainstalovat NVIDIA Docker."
    sudo systemctl restart docker
fi

# --- Krok 2: Stažení balíčku ---
echo "Krok 2: Stahuji ai-chatbot-manager..."

if [ -d "ai-chatbot-manager" ]; then
    echo "Složka ai-chatbot-manager již existuje, aktualizuji..."
    cd ai-chatbot-manager
    git pull
else
    git clone $REPO_URL
    check_error "Nepodařilo se stáhnout repozitář."
    cd ai-chatbot-manager
fi

# --- Krok 3: Vytvoření potřebných souborů ---
echo "Krok 3: Vytvářím potřebné soubory..."

# Vytvoření requirements.txt
cat <<EOL > requirements.txt
transformers
torch
gradio
configparser
bitsandbytes
speech_recognition
pyttsx3
langdetect
sympy
pkg_resources
requests
beautifulsoup4
python-nmap
pymetasploit3
reportlab
cryptography
EOL

# Vytvoření Dockerfile (multi-stage pro menší image)
cat <<EOL > Dockerfile
# Stage 1: Builder
FROM kalilinux/kali-rolling:latest AS builder
WORKDIR /app
COPY requirements.txt .
RUN apt update && apt install -y python3 python3-pip && pip3 install --no-cache-dir -r requirements.txt
RUN pip3 install huggingface-hub[cli]
COPY . .
RUN pip3 install .

# Stage 2: Finální obraz
FROM kalilinux/kali-rolling:latest
WORKDIR /app
COPY --from=builder /usr/local/lib/python3.10/dist-packages /usr/local/lib/python3.10/dist-packages
COPY --from=builder /usr/local/bin /usr/local/bin
COPY . .
RUN apt update && apt install -y libespeak1 nmap metasploit-framework aircrack-ng kismet wifite hostapd firmware-linux-nonfree && rm -rf /var/lib/apt/lists/*
RUN python3 -c "from ai_chatbot_manager.db_manager import init_db; init_db()"
ARG MODEL_DOWNLOAD=1
RUN if [ \$MODEL_DOWNLOAD -eq 1 ]; then huggingface-cli download google/gemma-3-27b-abliterated --local-dir /app/models/gemma; fi
COPY config/hostapd.conf /app/config/hostapd.conf
EXPOSE 7860
CMD ["ai-chatbot-manager"]
EOL

# Vytvoření hostapd.conf pro Evil Twin útoky
cat <<EOL > config/hostapd.conf
interface=$WIFI_INTERFACE
driver=nl80211
ssid=FreeWiFi
hw_mode=g
channel=6
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=TestPassword123
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOL

# Vytvoření WiFi pentest pluginu
mkdir -p ai_chatbot_manager/plugins
cat <<EOL > ai_chatbot_manager/plugins/wifi_pentest_plugin.py
import subprocess
import sqlite3
from reportlab.lib.pagesizes import letter
from reportlab.pdfgen import canvas
from ai_chatbot_manager.db_manager import save_to_db

class WiFiPentestPlugin:
    def __init__(self):
        self.db_file = "project.db"
        self.allowed_commands = ["airodump-ng", "aireplay-ng", "wifite", "kismet"]

    def run_command(self, cmd):
        if any(allowed in cmd for allowed in self.allowed_commands):
            try:
                return subprocess.check_output(cmd, shell=True, text=True)
            except subprocess.CalledProcessError as e:
                return f"Chyba: {str(e)}"
        return "Nepovolený příkaz."

    def generate_report(self, findings, output_file="wifi_report.pdf"):
        c = canvas.Canvas(f"generated_apps/{output_file}", pagesize=letter)
        c.drawString(100, 750, "WiFi Penetration Test Report")
        y = 700
        for finding in findings:
            c.drawString(100, y, f"{finding['test']}: {finding['result']}")
            y -= 20
        c.save()
        return f"Report vygenerován: generated_apps/{output_file}"

    def process_input(self, prompt):
        if prompt.startswith("wifi:"):
            cmd = prompt.replace("wifi:", "").strip()
            if cmd.startswith("scan"):
                result = self.run_command("airodump-ng --band abg $WIFI_INTERFACE")
                save_to_db('pentest_results', {'test': 'WiFi scan', 'result': result})
                return f"Sken sítí dokončen:\n{result}"
            elif cmd.startswith("crack"):
                result = self.run_command("wifite --wpa --dict /usr/share/wordlists/rockyou.txt")
                save_to_db('pentest_results', {'test': 'WiFi crack', 'result': result})
                return f"Cracking dokončen:\n{result}"
            elif cmd.startswith("deauth"):
                ap_mac = cmd.split()[-1]
                result = self.run_command(f"aireplay-ng --deauth 10 -a {ap_mac} $WIFI_INTERFACE")
                save_to_db('pentest_results', {'test': f'Deauth {ap_mac}', 'result': result})
                return f"Deauth útok spuštěn:\n{result}"
            elif cmd.startswith("evil-twin"):
                result = self.run_command("hostapd /app/config/hostapd.conf")
                save_to_db('pentest_results', {'test': 'Evil Twin', 'result': result})
                return f"Evil Twin útok spuštěn:\n{result}"
            elif cmd.startswith("report"):
                conn = sqlite3.connect(self.db_file)
                c = conn.cursor()
                c.execute("SELECT * FROM pentest_results WHERE test LIKE 'WiFi%'")
                findings = [{'test': row[0], 'result': row[1]} for row in c.fetchall()]
                conn.close()
                return self.generate_report(findings)
        return None
EOL

# Úprava web_ui.py pro autentizaci
if ! grep -q "auth=" ai_chatbot_manager/web_ui.py; then
    sed -i "s/demo.launch(/demo.launch(server_name=\"0.0.0.0\", server_port=7860, auth=(\"${WEBUI_AUTH%%:*}\", \"${WEBUI_AUTH##*:}\"), /" ai_chatbot_manager/web_ui.py
    check_error "Nepodařilo se upravit web_ui.py pro autentizaci."
fi

# --- Krok 4: Vytvoření složek pro perzistentní data ---
echo "Krok 4: Vytvářím složky pro data..."

mkdir -p logs history generated_apps project_db config
check_error "Nepodařilo se vytvořit složky."

# --- Krok 5: Nastavení WiFi adaptéru ---
echo "Krok 5: Nastavuji WiFi adaptér do monitorovacího módu..."

sudo airmon-ng check kill
sudo airmon-ng start $WIFI_INTERFACE
check_error "Nepodařilo se nastavit monitorovací mód."

# --- Krok 6: Sestavení Docker image ---
echo "Krok 6: Sestavuji Docker image..."

docker build --build-arg MODEL_DOWNLOAD=$MODEL_DOWNLOAD -t $IMAGE_NAME .
check_error "Nepodařilo se sestavit Docker image."

# --- Krok 7: Spuštění kontejneru ---
echo "Krok 7: Spouštím kontejner..."

if [ $GPU_ENABLED -eq 1 ] && nvidia-smi &> /dev/null; then
    echo "Spouštím s GPU podporou..."
    docker run --gpus all --net=host -p 7860:7860 -v $(pwd)/logs:/app/logs -v $(pwd)/history:/app/history -v $(pwd)/generated_apps:/app/generated_apps -v $(pwd)/project_db:/app/project.db -v $(pwd)/config:/app/config -d --name $CONTAINER_NAME $IMAGE_NAME python3 -m ai_chatbot_manager.web_ui
else
    echo "Spouštím bez GPU..."
    docker run --net=host -p 7860:7860 -v $(pwd)/logs:/app/logs -v $(pwd)/history:/app/history -v $(pwd)/generated_apps:/app/generated_apps -v $(pwd)/project_db:/app/project.db -v $(pwd)/config:/app/config -d --name $CONTAINER_NAME $IMAGE_NAME python3 -m ai_chatbot_manager.web_ui
fi
check_error "Nepodařilo se spustit kontejner."

# --- Krok 8: Nastavení firewallu ---
echo "Krok 8: Nastavuji firewall..."

sudo ufw allow 7860
sudo ufw --force enable
check_error "Nepodařilo se nastavit firewall."

# --- Krok 9: Šifrování DB (volitelné) ---
if [ $DB_ENCRYPT -eq 1 ]; then
    echo "Krok 9: Nastavuji šifrování DB..."
    cat <<EOL > ai_chatbot_manager/db_manager.py
import sqlite3
import configparser
from cryptography.fernet import Fernet

config = configparser.ConfigParser()
config.read('config.ini')
db_file = config['General']['db_file']

key = Fernet.generate_key()
cipher = Fernet(key)
with open('db_key.key', 'wb') as f:
    f.write(key)

def init_db():
    conn = sqlite3.connect(db_file)
    c = conn.cursor()
    c.execute('''CREATE TABLE IF NOT EXISTS history (timestamp TEXT, user TEXT, ai TEXT)''')
    c.execute('''CREATE TABLE IF NOT EXISTS facts (url TEXT, content TEXT)''')
    c.execute('''CREATE TABLE IF NOT EXISTS pentest_results (test TEXT, result TEXT)''')
    conn.commit()
    conn.close()

def save_to_db(table, data):
    conn = sqlite3.connect(db_file)
    c = conn.cursor()
    if table == 'history':
        encrypted_user = cipher.encrypt(data['user'].encode()).decode()
        encrypted_ai = cipher.encrypt(data['ai'].encode()).decode()
        c.execute("INSERT INTO history VALUES (?, ?, ?)", (data['timestamp'], encrypted_user, encrypted_ai))
    elif table == 'facts':
        encrypted_content = cipher.encrypt(data['content'].encode()).decode()
        c.execute("INSERT INTO facts VALUES (?, ?)", (data['url'], encrypted_content))
    elif table == 'pentest_results':
        encrypted_result = cipher.encrypt(data['result'].encode()).decode()
        c.execute("INSERT INTO pentest_results VALUES (?, ?)", (data['test'], encrypted_result))
    conn.commit()
    conn.close()

def query_db(table, condition=''):
    conn = sqlite3.connect(db_file)
    c = conn.cursor()
    c.execute(f"SELECT * FROM {table} {condition}")
    results = c.fetchall()
    decrypted_results = []
    for row in results:
        if table == 'history':
            decrypted_results.append((row[0], cipher.decrypt(row[1].encode()).decode(), cipher.decrypt(row[2].encode()).decode()))
        elif table == 'facts':
            decrypted_results.append((row[0], cipher.decrypt(row[1].encode()).decode()))
        elif table == 'pentest_results':
            decrypted_results.append((row[0], cipher.decrypt(row[1].encode()).decode()))
    conn.close()
    return decrypted_results
EOL
    docker build --build-arg MODEL_DOWNLOAD=0 -t $IMAGE_NAME .
    check_error "Nepodařilo se znovu sestavit image s šifrováním."
fi

# --- Krok 10: Ověření a pokyny ---
echo "Nasazení dokončeno!"
echo "WebUI je dostupné na: http://localhost:7860 (přihlášení: ${WEBUI_AUTH%%:*}/${WEBUI_AUTH##*:})"
echo "Pro CLI přístup: docker exec -it $CONTAINER_NAME ai-chatbot-manager"
echo "Pro zastavení: docker stop $CONTAINER_NAME"
echo "Pro zálohu dat: tar -czf chatbot_backup.tar.gz logs history generated_apps project_db"
echo "Logy: cat logs/chatbot.log"
echo "DB: sqlite3 project_db/project.db 'SELECT * FROM history'"
echo "WiFi příkazy: 'wifi: scan', 'wifi: crack', 'wifi: deauth <AP_MAC>', 'wifi: evil-twin', 'wifi: report'"
echo "UPOZORNĚNÍ: WiFi testování provádějte pouze s povolením vlastníka sítě!"
