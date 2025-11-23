#!/bin/bash
# Komplexní instalační skript pro vzdělávací systém
# Verze: 2.0
# Autor: Education Team

set -e

# Načtení konfigurace
source /home/education-system/config/system-config.yaml

# Funkce pro instalaci
install_system() {
    echo "=== INSTALACE VZDĚLÁVACÍHO SYSTÉMU ==="
    
    # 1. Aktualizace systému
    sudo apt-get update && sudo apt-get upgrade -y
    
    # 2. Instalace závislostí
    install_dependencies
    
    # 3. Konfigurace sítě
    configure_network
    
    # 4. Nastavení bezpečnosti
    configure_security
    
    # 5. Instalace vzdělávacích nástrojů
    install_education_tools
    
    # 6. Vytvoření projektové struktury
    create_project_structure
    
    # 7. Nastavení monitorování
    setup_monitoring
    
    echo "=== INSTALACE DOKONČENA ==="
}

# Spuštění instalace
install_system