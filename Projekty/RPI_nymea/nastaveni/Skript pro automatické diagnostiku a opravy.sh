# Skript pro automatické diagnostiku a opravy
#!/bin/bash

# Monitoring systémového zdraví
check_system_health() {
    echo "=== SYSTÉMOVÁ DIAGNOSTIKA ==="
    echo "Datum: $(date)"
    echo "Teplota CPU: $(vcgencmd measure_temp)"
    echo "Využití CPU: $(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')%"
    echo "Využití paměti: $(free -m | awk 'NR==2{printf "%.2f%%", $3*100/$2}')"
    echo "Využití disku: $(df -h / | awk 'NR==2{print $5}')"
}

# Automatické opravy běžných problémů
perform_automatic_fixes() {
    echo "=== AUTOMATICKÉ OPRAVY ==="
    
    # Oprava oprávnění souborů
    find /home/student-projects -type d -exec chmod 755 {} \;
    find /home/student-projects -type f -exec chmod 644 {} \;
    
    # Obnova chybějících závislostí
    pip3 install -r /opt/education-system/requirements.txt
    
    # Restartování nefunkčních služeb
    systemctl restart education-server
    systemctl restart project-manager
}

# Zálohování studentských projektů
backup_projects() {
    echo "=== ZÁLOHOVÁNÍ PROJEKTŮ ==="
    tar -czf /backups/student-projects-$(date +%Y%m%d).tar.gz /home/student-projects
    echo "Záloha vytvořena: /backups/student-projects-$(date +%Y%m%d).tar.gz"
}

# Hlavní funkce
main() {
    check_system_health
    perform_automatic_fixes
    backup_projects
    echo "=== DIAGNOSTIKA DOKONČENA ==="
}

main