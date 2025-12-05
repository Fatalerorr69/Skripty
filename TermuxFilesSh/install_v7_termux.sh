#!/data/data/com.termux/files/usr/bin/bash

# ===============================
# StarkOS / UltraOS v7 – Termux / Android
# ===============================

OFFLINE_RUN="./installer_v7_full.run"
MODULE_REPO="https://github.com/Fatalerorr69/UltraOS_v7_modules.git"
MODULE_DIR="./installer_v7/modules"
LOG_FILE="./installer_v7/install_termux.log"
DASHBOARD_PORT=9000

echo "🔹 StarkOS / UltraOS v7 – Termux instalátor s web dashboardem"

# -------------------------------
# Funkce offline
# -------------------------------
install_offline() {
    echo "⚡ Používám offline balík..." | tee "$LOG_FILE"
    chmod +x "$OFFLINE_RUN"
    bash "$OFFLINE_RUN" 2>&1 | tee -a "$LOG_FILE"
}

# -------------------------------
# Funkce online
# -------------------------------
install_online() {
    echo "⚡ Stahuji moduly z GitHub..." | tee "$LOG_FILE"
    if [ -d "$MODULE_DIR" ]; then
        rm -rf "$MODULE_DIR"
    fi
    git clone "$MODULE_REPO" "$MODULE_DIR" 2>&1 | tee -a "$LOG_FILE"
    echo "✅ Moduly staženy." | tee -a "$LOG_FILE"
}

# -------------------------------
# Hlavní logika
# -------------------------------
if [ -f "$OFFLINE_RUN" ]; then
    install_offline
else
    install_online
fi

# -------------------------------
# Spuštění web dashboardu
# -------------------------------
if command -v starkos-web >/dev/null 2>&1; then
    echo "🌐 Spouštím web dashboard na http://127.0.0.1:$DASHBOARD_PORT ..."
    starkos-web &

    # Čekání, aby dashboard naběhl
    sleep 3

    # Otevření v prohlížeči Termuxu
    if command -v termux-open-url >/dev/null 2>&1; then
        termux-open-url "http://127.0.0.1:$DASHBOARD_PORT"
    else
        echo "⚠️ termux-open-url není dostupný, otevři ručně: http://127.0.0.1:$DASHBOARD_PORT"
    fi
else
    echo "⚠️ Web dashboard nebyl nalezen. Spusť ho ručně: starkos-web" | tee -a "$LOG_FILE"
fi

# -------------------------------
# Stav modulů
# -------------------------------
if [ -d "$MODULE_DIR" ]; then
    echo "📂 Stav modulů:" | tee -a "$LOG_FILE"
    for mod in "$MODULE_DIR"/*; do
        if [ -d "$mod" ]; then
            echo " - $(basename $mod) : OK" | tee -a "$LOG_FILE"
        fi
    done
fi

echo "🎉 Instalace dokončena. Přístup k dashboardu: http://127.0.0.1:$DASHBOARD_PORT"
