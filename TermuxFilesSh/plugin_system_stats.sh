#!/bin/bash
# Plugin: CPU, RAM, Teplota
LOG=~/twisteros_supermanager/logs/plugin.log

status() {
    echo "🖥 CPU:" $(grep 'model name' /proc/cpuinfo | uniq | awk -F: '{print $2}') | tee -a "$LOG"
    echo "🧠 RAM:" $(free -h | grep Mem | awk '{print $3 "/" $2}') | tee -a "$LOG"
    echo "🌡 Teplota:" $(vcgencmd measure_temp 2>/dev/null || echo "N/A") | tee -a "$LOG"
}

start() { 
    echo "📊 System stats plugin spuštěn" | tee -a "$LOG"
    status
}
stop() { echo "⏹ System stats plugin ukončen" | tee -a "$LOG"; }

case $1 in
    start) start ;;
    stop) stop ;;
    status) status ;;
    *) echo "Použití: $0 {start|stop|status}" ;;
esac
