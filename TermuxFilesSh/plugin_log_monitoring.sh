#!/bin/bash
# Plugin: Realtime log monitor
LOG=~/twisteros_supermanager/logs/plugin.log

start() { 
    echo "📝 Spouštím sledování logů..." | tee -a "$LOG"
    tail -f ~/twisteros_supermanager/logs/scripts.log
}
stop() { echo "⏹ Log monitor plugin ukončen" | tee -a "$LOG"; }
status() { echo "Log monitor připraven" | tee -a "$LOG"; }

case $1 in
    start) start ;;
    stop) stop ;;
    status) status ;;
    *) echo "Použití: $0 {start|stop|status}" ;;
esac
