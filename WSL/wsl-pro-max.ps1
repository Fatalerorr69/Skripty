# =============================================
# WSL PRO MAX INSTALLER & CLEANER
# Author: Starko
# =============================================

# ---------------------------------------------
# Funkce: Detekce nainstalovaných distribucí
# ---------------------------------------------
function Get-WSLDistributions {
    return wsl --list --quiet
}

# ---------------------------------------------
# Funkce: Nastavení domovských adresářů
# ---------------------------------------------
function Setup-HomeDirs {
    $distros = Get-WSLDistributions
    foreach ($distro in $distros) {
        Write-Host "[INFO] Nastavuji domovský adresář pro $distro..."
        $homePath = "W:\$distro\home"
        wsl -d $distro -- bash -c "sudo mkdir -p '$homePath'; sudo rm -rf /home; sudo ln -s '$homePath' /home"
    }
    Write-Host "[INFO] Domovské adresáře nastaveny."
}

# ---------------------------------------------
# Funkce: Instalace doporučených modulů
# ---------------------------------------------
function Install-Modules {
    $distros = Get-WSLDistributions
    foreach ($distro in $distros) {
        Write-Host "[INFO] Instalace modulů pro $distro..."
        wsl -d $distro -- bash -c "sudo apt update && sudo apt upgrade -y"
        wsl -d $distro -- bash -c "sudo apt install -y docker.io docker-compose zsh tmux jq yq rclone borgbackup mosquitto mqtt-tools neofetch curl wget python3-pip"
        wsl -d $distro -- bash -c "sh -c \"$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" || true"
        wsl -d $distro -- bash -c "mkdir -p /home/starko/WebGUI"
        Write-Host "[INFO] Moduly pro $distro hotové."
    }
}

# ---------------------------------------------
# Funkce: Cleaner PRO
# ---------------------------------------------
function Cleaner-PRO {
    $distros = Get-WSLDistributions
    foreach ($distro in $distros) {
        Write-Host "[CLEANER PRO] Čištění $distro..."
        wsl -d $distro -- bash -c "docker system prune -af || true"
        wsl -d $distro -- bash -c "rm -rf ~/.cache/waydroid ~/.cache/anbox || true"
        wsl -d $distro -- bash -c "pip3 cache purge || true"
        wsl -d $distro -- bash -c "echo '[SAFE] Snapshots vyčištěny, kontrola manuálně!'"
    }
    Write-Host "[CLEANER PRO] Hotovo."
}

# ---------------------------------------------
# Funkce: WebGUI instalace
# ---------------------------------------------
function Install-WebGUI {
    $distros = Get-WSLDistributions
    foreach ($distro in $distros) {
        Write-Host "[WebGUI] Instalace placeholderu pro $distro..."
        wsl -d $distro -- bash -c "mkdir -p /home/starko/WebGUI && echo 'WebGUI připraven' > /home/starko/WebGUI/readme.txt"
    }
    Write-Host "[WebGUI] Instalace dokončena."
}

# ---------------------------------------------
# Hlavní menu
# ---------------------------------------------
function Show-Menu {
    do {
        Clear-Host
        Write-Host "==== WSL PRO MAX MENU ===="
        Write-Host "1) Detekce distribucí"
        Write-Host "2) Nastavení domovských adresářů"
        Write-Host "3) Instalace modulů"
        Write-Host "4) Cleaner PRO Advanced"
        Write-Host "5) Instalace WebGUI"
        Write-Host "0) Konec"
        $choice = Read-Host "Vyberte možnost"

        switch ($choice) {
            "1" { Get-WSLDistributions | ForEach-Object { Write-Host $_ } ; Pause }
            "2" { Setup-HomeDirs ; Pause }
            "3" { Install-Modules ; Pause }
            "4" { Cleaner-PRO ; Pause }
            "5" { Install-WebGUI ; Pause }
            "0" { Write-Host "Konec"; break }
            default { Write-Host "Neplatná volba" ; Pause }
        }
    } while ($true)
}

# ---------------------------------------------
# Spuštění menu
# ---------------------------------------------
Show-Menu
