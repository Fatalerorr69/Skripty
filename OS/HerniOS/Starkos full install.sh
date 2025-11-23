#!/bin/bash

# === StarkOS: Kompletní instalační skript pro Raspberry Pi 5 ===
# Autor: Starko
# Verze: 1.0

set -e

# ==== 1) Základní proměnné ====
BASE_DIR="$HOME/HerniRezim"
ROMS_DIR="$BASE_DIR/roms"
SCRIPTS_DIR="$HOME/starkos-scripts"
LOGO_PATH="$HOME/.starkos_logo.png"
WEB_DIR="$HOME/starkos-web"
PEGASUS_CONFIG="$HOME/.config/pegasus-frontend"

# ==== 2) Základní příprava systému ====
echo "[1/16] Aktualizuji systém..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y pcsxr retroarch waydroid wget curl git unzip qrencode gtkdialog imagemagick hedgewars warzone2100 evtest joystick python3-pip
pip3 install flask qrcode netifaces

# ==== 3–12) (nezměněno: Kolekce, témata, skripty atd.) ====
# (ponecháno beze změn z předchozí verze)

# ==== 13) Webové rozhraní StarkOS ====
echo "[13/16] Instalace webového rozhraní..."
mkdir -p "$WEB_DIR/templates" "$WEB_DIR/static" "$WEB_DIR/uploads"

cat > "$WEB_DIR/app.py" <<'EOF'
from flask import Flask, render_template, request, redirect
import os, qrcode, netifaces

app = Flask(__name__, static_folder='static', template_folder='templates')
UPLOAD_FOLDER = 'uploads'
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

@app.route('/')
def index():
    ip = netifaces.ifaddresses('eth0')[netifaces.AF_INET][0]['addr'] if 'eth0' in netifaces.interfaces() else 'localhost'
    return render_template('index.html', ip=ip)

@app.route('/upload', methods=['POST'])
def upload_file():
    f = request.files['file']
    f.save(os.path.join(app.config['UPLOAD_FOLDER'], f.filename))
    return redirect('/')

@app.route('/run/<action>')
def run_action(action):
    if action == "android":
        os.system("waydroid show-full-ui &")
    elif action == "pegasus":
        os.system("pegasus-fe &")
    elif action == "menu":
        os.system("bash ~/starkos-scripts/starkos-control.sh &")
    return redirect('/')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF

cat > "$WEB_DIR/templates/index.html" <<'EOF'
<!DOCTYPE html>
<html lang="cs">
<head>
    <meta charset="UTF-8">
    <title>StarkOS Dashboard</title>
    <style>
        body { background: #111; color: #fff; font-family: sans-serif; text-align: center; }
        button { margin: 10px; padding: 15px; font-size: 16px; background: #00FF99; border: none; border-radius: 5px; }
        .upload { margin-top: 20px; }
    </style>
</head>
<body>
    <h1>StarkOS Web Dashboard</h1>
    <p>IP zařízení: {{ ip }} • <a href="http://{{ ip }}:5000" style="color:#00FF99">Otevřít na jiném zařízení</a></p>
    <button onclick="location.href='/run/android'">📱 Spustit Android</button>
    <button onclick="location.href='/run/pegasus'">🎮 Spustit Pegasus</button>
    <button onclick="location.href='/run/menu'">⚙️ Control Menu</button>

    <div class="upload">
        <form method="POST" enctype="multipart/form-data" action="/upload">
            <input type="file" name="file">
            <input type="submit" value="📥 Nahrát ROM / APK">
        </form>
    </div>
</body>
</html>
EOF

cat > "$WEB_DIR/start-web.sh" <<EOF
#!/bin/bash
cd $WEB_DIR
python3 app.py
EOF
chmod +x "$WEB_DIR/start-web.sh"

# ==== 14) Přidání do autostartu ====
echo "@bash $WEB_DIR/start-web.sh" >> ~/.config/lxsession/LXDE-pi/autostart

# ==== 15) Doplnění do hlavního menu ====
echo "9) Spustit Web Dashboard" >> "$SCRIPTS_DIR/starkos-control.sh"
echo "  9) bash $WEB_DIR/start-web.sh ;;" >> "$SCRIPTS_DIR/starkos-control.sh"

# ==== 16) Závěr ====
echo "✅ StarkOS Web Dashboard připraven na http://<tvoje_ip>:5000"
echo "🌐 Otevři z mobilu pomocí této IP nebo QR kódu."
echo "Spuštění: bash $WEB_DIR/start-web.sh"