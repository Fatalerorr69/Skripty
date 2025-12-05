#!/bin/bash
# ===============================
# HEADLESS FULL DEPLOY StarkHost v3
# ===============================
# Pouze Raspberry Pi 5
# =================================

REPO_URL="https://github.com/Fatalerorr69/rpi5-starkhost.git"
ZIP_PATH="/home/starko/Downloads/starkhost_v3_debian_full_local_full_github.zip"
WORK_DIR="/tmp/starkhost_deploy"
SERVICES=("home-assistant" "nodered" "aibot" "starkhost-dashboard")
PORTS=(8081 8443 1880 8099)

echo "=== START HEADLESS DEPLOY ==="

# 1️⃣ Aktualizace a instalace základních balíků
sudo apt update && sudo apt upgrade -y
sudo apt install -y git unzip python3-pip docker.io docker-compose nodejs npm curl lxc wget

# 2️⃣ Kontrola a příprava MHS35 displeje
if ls /dev/fb1 >/dev/null 2>&1; then
  echo "✅ MHS35 detekován"
else
  echo "⚠️ MHS35 nenalezen, pokračujeme headless"
fi

# 3️⃣ Deploy do repozitáře
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"
git clone "$REPO_URL" .
unzip "$ZIP_PATH" -d .

# 4️⃣ Vytvoření CI workflow
mkdir -p .github/workflows
cat > .github/workflows/lint.yml <<EOL
name: Shellcheck + YAML lint
on: [push, pull_request]
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Shellcheck
        run: find core modules -type f -name "*.sh" -exec shellcheck {} +
      - name: YAML Lint
        run: yamllint .
EOL

cat > .github/workflows/test.yml <<EOL
name: Post-install test
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run post-install test
        run: sudo bash core/post_install_test.sh
EOL

cat > .github/workflows/build.yml <<EOL
name: Build ZIP
on:
  push:
    branches: [ main ]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Create ZIP
        run: zip -r starkhost_v3_debian_full_local_full.zip . -x ".git/*"
      - name: Upload artifact
        uses: actions/upload-artifact@v3
        with:
          name: starkhost_v3_debian_full_local_full
          path: starkhost_v3_debian_full_local_full.zip
EOL

# 5️⃣ Git commit a push
git add .
git commit -m "Headless full deploy StarkHost v3 + CI"
git branch -M main
git push -u origin main

# 6️⃣ Lokální post-install test
echo "=== POST-INSTALL TEST ==="
check_service() {
  systemctl is-active --quiet "$1"
  [[ $? -eq 0 ]] && echo "✅ $1 běží" || echo "❌ $1 neběží"
}

for s in "${SERVICES[@]}"; do check_service "$s"; done
for p in "${PORTS[@]}"; do
  ss -tln | grep -q ":$p" && echo "✅ Port $p aktivní" || echo "⚠️ Port $p není aktivní"
done

echo "Test AIbot..."
curl -s http://localhost:8099/api/query -d '{"q":"ping"}' -H "Content-Type: application/json" | grep -q "pong" && echo "✅ AIbot OK" || echo "⚠️ AIbot bez odpovědi"

echo "=== HEADLESS DEPLOY HOTOV ==="
