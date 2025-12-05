#!/bin/bash

# =============================================
# Powerful AI Station Installer for TwisterOS on Raspberry Pi 5
# =============================================

set -e  # Exit on any error

echo "========================================"
echo " Installing Powerful AI Station"
echo "========================================"

# ----------------------------
# 1. System Update & Dependencies
# ----------------------------
echo "[1/6] Updating system and installing dependencies..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y python3-pip git curl wget

# Install Docker
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
fi

# ----------------------------
# 2. Core AI Backend (Ollama)
# ----------------------------
echo "[2/6] Installing Ollama AI engine..."
if ! command -v ollama &> /dev/null; then
    curl -fsSL https://ollama.ai/install.sh | sh
    sudo systemctl enable ollama
    # Wait for service to be ready
    sleep 10
fi

# Pull efficient AI models
echo "Downloading AI models (this may take a while)..."
ollama pull tinyllama:1.1b &
ollama pull phi3:mini &
wait

# ----------------------------
# 3. Central Management UI (Open WebUI)
# ----------------------------
echo "[3/6] Deploying Open WebUI..."
docker pull ghcr.io/open-webui/open-webui:main
docker run -d \
    --name open-webui \
    --restart always \
    -p 3000:8080 \
    -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
    --add-host=host.docker.internal:host-gateway \
    -v open-webui:/app/backend/data \
    ghcr.io/open-webui/open-webui:main

# ----------------------------
# 4. AI Vision & Object Detection
# ----------------------------
echo "[4/6] Setting up Computer Vision..."
sudo apt install -y python3-opencv

# Create vision service
cat > ~/ai_vision.py << 'EOF'
import cv2
import datetime

def motion_detector():
    cap = cv2.VideoCapture(0)
    ret, frame1 = cap.read()
    ret, frame2 = cap.read()
    
    while cap.isOpened():
        diff = cv2.absdiff(frame1, frame2)
        gray = cv2.cvtColor(diff, cv2.COLOR_BGR2GRAY)
        blur = cv2.GaussianBlur(gray, (5,5), 0)
        _, thresh = cv2.threshold(blur, 20, 255, cv2.THRESH_BINARY)
        dilated = cv2.dilate(thresh, None, iterations=3)
        contours, _ = cv2.findContours(dilated, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
        
        for contour in contours:
            if cv2.contourArea(contour) < 1000:
                continue
            print(f"Motion detected at {datetime.datetime.now()}")
            break
            
        frame1 = frame2
        ret, frame2 = cap.read()
        
        if cv2.waitKey(40) == 27:  # ESC key
            break

    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    motion_detector()
EOF

# ----------------------------
# 5. Text-to-Speech Service
# ----------------------------
echo "[5/6] Setting up Text-to-Speech..."
sudo apt install -y espeak
pip3 install gTTS

cat > ~/tts_service.py << 'EOF'
from gtts import gTTS
import os
import pygame
import tempfile

def speak(text, lang='en'):
    tts = gTTS(text=text, lang=lang)
    with tempfile.NamedTemporaryFile(delete=False, suffix='.mp3') as fp:
        tts.save(fp.name)
        pygame.mixer.init()
        pygame.mixer.music.load(fp.name)
        pygame.mixer.music.play()
        while pygame.mixer.music.get_busy():
            continue
        os.unlink(fp.name)

if __name__ == "__main__":
    speak("AI Station is ready and operational")
EOF

# ----------------------------
# 6. Central Dashboard & Startup
# ----------------------------
echo "[6/6] Creating central dashboard..."

# Create startup script
sudo tee /usr/local/bin/ai-station > /dev/null << 'EOF'
#!/bin/bash
echo "========================================"
echo "     AI Station Control Panel"
echo "========================================"
echo "Services:"
echo "  • Open WebUI: http://localhost:3000"
echo "  • Ollama API: http://localhost:11434"
echo ""
echo "Management Commands:"
echo "  ai-station-start    - Start all services"
echo "  ai-station-stop     - Stop all services"
echo "  ai-station-status   - Check service status"
echo "  ai-model-list       - Show installed AI models"
echo "========================================"
EOF

# Create management commands
sudo tee /usr/local/bin/ai-station-start > /dev/null << 'EOF'
#!/bin/bash
sudo systemctl start ollama
docker start open-webui
echo "AI Station services started"
EOF

sudo tee /usr/local/bin/ai-station-status > /dev/null << 'EOF'
#!/bin/bash
echo "Ollama: $(systemctl is-active ollama)"
echo "Open WebUI: $(docker inspect -f '{{.State.Status}}' open-webui)"
echo ""
echo "Installed AI Models:"
ollama list
EOF

sudo tee /usr/local/bin/ai-model-list > /dev/null << 'EOF'
#!/bin/bash
ollama list
EOF

# Make scripts executable
sudo chmod +x /usr/local/bin/ai-station*
sudo chmod +x /usr/local/bin/ai-model-list

# Create desktop shortcut
mkdir -p ~/Desktop
cat > ~/Desktop/AI-Station.desktop << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=AI Station
Comment=Central AI Management
Exec=xdg-open http://localhost:3000
Icon=applications-ai
Terminal=false
Categories=AI;
EOF

chmod +x ~/Desktop/AI-Station.desktop

# ----------------------------
# Completion
# ----------------------------
echo "========================================"
echo " Installation Complete!"
echo "========================================"
echo ""
echo "ACCESS POINTS:"
echo "• Web Interface: http://$(hostname -I | awk '{print $1}'):3000"
echo "• Terminal: Run 'ai-station' for control"
echo "• Desktop: Click 'AI Station' icon"
echo ""
echo "FIRST STEPS:"
echo "1. Open the WebUI in your browser"
echo "2. Create an account when prompted"
echo "3. Start chatting with AI models"
echo "4. Use 'ai-station-status' to check services"
echo ""
echo "MODELS INSTALLED:"
echo "• TinyLlama (1.1B) - Fast response"
echo "• Phi-3 Mini (3.8B) - High quality"
echo ""
echo "To add more models: 'ollama pull <model-name>'"
echo "========================================"

# Initial startup
sudo systemctl start ollama
echo "Services are starting up..."
sleep 5
echo "AI Station is ready! Open your browser to the address above."