#!/bin/bash
# Plugin: Kontrola a oprava disků
LOG=~/twisteros_supermanager/logs/plugin.log

status() {
    echo "🖴 Kontrola disků..." | tee -a "$LOG"
    sudo smartctl --all /dev/sda | tee -a "$LOG"
    df -h | tee -a "$LOG"
}

start() { 
    echo "🔧 Spouštím kontrolu disků..." | tee -a "$LOG"
    status
}

stop() { 
    echo "⏹ Plugin Disk Health ukončen" | tee -a "$LOG"
}

case $1 in
    start) start ;;
    stop) stop ;;
    status) status ;;
    *) echo "Použití: $0 {start|stop|status}" ;;
esac
