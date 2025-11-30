# ==========================================================
# WSL/Linux/Termux ULTIMATE PRO MAX GUI v2 - Enhanced
# ==========================================================
# Autor: Starko / Fatalerorr69
# GitHub: https://github.com/Fatalerorr69
# Verze: 2.0 - Kompletní integrace WSL funkcí
# ==========================================================

#Requires -RunAsAdministrator

# ---------------------- Nastavení -------------------------
$ErrorActionPreference = "Continue"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogFile = Join-Path $ScriptDir "wsl_gui_$(Get-Date -Format 'yyyyMMdd').log"
$BackupDir = Join-Path $ScriptDir "backups"
$ConfigFile = Join-Path $ScriptDir "wsl_config.json"
$CustomScriptsDir = Join-Path $ScriptDir "custom_scripts"

# WSL Specifická nastavení
$WSLDrive = "W:"
$WSLBackupRoot = Join-Path $WSLDrive "WSL_Backups"
$DefaultWSLUser = "starko"

# Vytvoření adresářů
@($BackupDir, $CustomScriptsDir) | ForEach-Object { 
    if (!(Test-Path $_)) { New-Item -ItemType Directory -Path $_ -Force | Out-Null }
}

# ---------------------- Základní funkce logování ------------------
function Write-LogInfo { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Blue; Add-Content $LogFile "[INFO] $Message" }
function Write-LogSuccess { param($Message) Write-Host "[OK] $Message" -ForegroundColor Green; Add-Content $LogFile "[OK] $Message" }
function Write-LogWarning { param($Message) Write-Host "[WARN] $Message" -ForegroundColor Yellow; Add-Content $LogFile "[WARN] $Message" }
function Write-LogError { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red; Add-Content $LogFile "[ERROR] $Message" }

Write-LogInfo "=== Spuštění WSL Ultimate v2 $(Get-Date) ==="

# ---------------------- System Info ----------------------
function Get-SystemInfo {
    $info = @{
        OS = (Get-CimInstance Win32_OperatingSystem).Caption
        Version = [System.Environment]::OSVersion.Version
        Architecture = [System.Environment]::Is64BitOperatingSystem
        Hostname = $env:COMPUTERNAME
        User = $env:USERNAME
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
    }
    return $info
}

# ---------------------- Auto-Fix Functions -----------------
function Test-AdminRights {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-LogWarning "SKRIPT NEBĚŽÍ JAKO SPRÁVCE!"
        return $false
    }
    Write-LogSuccess "Skript běží s administrátorskými právy"
    return $true
}

function Test-ExecutionPolicy {
    $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
    Write-LogInfo "Aktuální Execution Policy: $currentPolicy"
    
    if ($currentPolicy -eq "Restricted") {
        Write-LogWarning "Execution Policy je 'Restricted' - skript nelze spustit!"
        return $false
    }
    return $true
}

function Repair-ExecutionPolicy {
    Write-LogInfo "Opravuji Execution Policy..."
    
    try {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Write-LogSuccess "Execution Policy nastavena na RemoteSigned"
        return $true
    } catch {
        Write-LogError "Nelze nastavit Execution Policy: $_"
        return $false
    }
}

function Unblock-ScriptFile {
    param([string]$ScriptPath)
    
    if (Test-Path $ScriptPath) {
        try {
            Unblock-File -Path $ScriptPath
            Write-LogSuccess "Soubor odblokován: $ScriptPath"
            return $true
        } catch {
            Write-LogWarning "Nelze odblokovat soubor: $_"
            return $false
        }
    }
    return $false
}

function Start-Elevated {
    Write-LogInfo "Spouštím skript s administrátorskými právy..."
    
    $scriptPath = $MyInvocation.MyCommand.Path
    $arguments = "-ExecutionPolicy Bypass -File `"$scriptPath`""
    
    Start-Process powershell -ArgumentList $arguments -Verb RunAs
    exit
}

# ---------------------- Detekce WSL ----------------------
function Get-WSLDistributions {
    $distros = @()
    try {
        $wslList = wsl --list --quiet 2>$null
        if ($wslList) {
            $distros = $wslList | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim() -replace '\x00','' }
        }
    } catch {
        Write-LogWarning "WSL není nainstalován nebo není dostupný"
    }
    return $distros
}

function Show-WSLStatus {
    Write-Host "=== Status WSL Distribucí ===" -ForegroundColor Cyan
    
    $distros = Get-WSLDistributions
    if ($distros.Count -eq 0) {
        Write-Host "Žádné WSL distribuce nebyly nalezeny" -ForegroundColor Red
        return
    }
    
    foreach ($distro in $distros) {
        $status = "Zastaveno"
        $color = "Red"
        
        # Kontrola, zda distribuce běží
        $running = wsl -d $distro -u root -- bash -c "echo 'running'" 2>$null
        if ($running -eq "running") {
            $status = "Běží"
            $color = "Green"
        }
        
        Write-Host "• $distro : " -NoNewline
        Write-Host $status -ForegroundColor $color
        
        # Informace o HOME adresáři
        $homePath = Join-Path $WSLDrive "${distro}_home_$DefaultWSLUser"
        if (Test-Path $homePath) {
            Write-Host "  HOME: $homePath" -ForegroundColor Gray
        }
    }
    
    # Informace o W: disku
    if (Test-Path $WSLDrive) {
        $driveInfo = Get-PSDrive -Name "W" -ErrorAction SilentlyContinue
        if ($driveInfo) {
            $freeSpace = [math]::Round($driveInfo.Free / 1GB, 2)
            $usedSpace = [math]::Round(($driveInfo.Used + $driveInfo.Free) / 1GB, 2)
            Write-Host "`nW: Disk: $freeSpace GB volných z $usedSpace GB" -ForegroundColor Yellow
        }
    }
}

# ---------------------- WSL Advanced Functions -----------
function Initialize-WSLDrive {
    Write-LogInfo "Inicializuji W: disk pro WSL data..."
    
    if (!(Test-Path $WSLDrive)) {
        Write-LogWarning "W: disk není dostupný. Vytvářím základní strukturu..."
        New-Item -ItemType Directory -Path $WSLDrive -Force | Out-Null
    }
    
    # Vytvoření základní struktury adresářů
    $wslDirs = @($WSLBackupRoot, "$WSLDrive\WSL_Data", "$WSLDrive\WSL_Home")
    foreach ($dir in $wslDirs) {
        if (!(Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-LogSuccess "Vytvořen adresář: $dir"
        }
    }
}

function Set-WSLHomeDirectories {
    Write-LogInfo "Nastavuji domovské adresáře na W: disk..."
    
    $distros = Get-WSLDistributions
    if ($distros.Count -eq 0) {
        Write-LogError "Nenalezeny žádné WSL distribuce"
        return
    }
    
    Initialize-WSLDrive
    
    foreach ($distro in $distros) {
        Write-LogInfo "Zpracovávám distribuci: $distro"
        
        # Vytvoření cílového adresáře na W: disku
        $TargetHome = Join-Path $WSLDrive "${distro}_home_$DefaultWSLUser"
        if (!(Test-Path $TargetHome)) {
            New-Item -ItemType Directory -Path $TargetHome -Force | Out-Null
            Write-LogSuccess "Vytvořen domovský adresář: $TargetHome"
        }
        
        try {
            # Přesun HOME adresáře na W: disk
            Write-LogInfo "Přesouvám HOME adresář pro $distro..."
            wsl -d $distro -u root -- bash -c "
                # Záloha původního HOME
                if [ -d '/home/$DefaultWSLUser' ]; then
                    cp -r /home/$DefaultWSLUser/* '${TargetHome//\:/\\:}/' 2>/dev/null || true
                fi
                
                # Odstranění původního HOME a vytvoření symlinku
                rm -rf /home/$DefaultWSLUser
                ln -s '${TargetHome//\:/\\:}' /home/$DefaultWSLUser
                
                # Nastavení správných oprávnění
                chown -R $DefaultWSLUser:$DefaultWSLUser '${TargetHome//\:/\\:}'
                echo 'HOME adresář úspěšně přesunut na W: disk'
            " 2>$null
            
            Write-LogSuccess "Domovský adresář pro $distro nastaven na: $TargetHome"
            
        } catch {
            Write-LogError "Chyba při nastavování HOME adresáře pro $distro : $_"
        }
    }
    
    Write-LogSuccess "Nastavení domovských adresářů dokončeno"
}

function Export-WSLToWDrive {
    Write-LogInfo "Exportuji WSL distribuce na W: disk..."
    
    $distros = Get-WSLDistributions
    if ($distros.Count -eq 0) {
        Write-LogError "Nenalezeny žádné WSL distribuce"
        return
    }
    
    Initialize-WSLDrive
    
    foreach ($distro in $distros) {
        Write-LogInfo "Exportuji distribuci: $distro"
        
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $BackupDir = Join-Path $WSLBackupRoot $distro
        if (!(Test-Path $BackupDir)) {
            New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
        }
        
        $BackupFile = Join-Path $BackupDir "${distro}_${timestamp}.tar"
        
        try {
            # Export distribuce
            wsl --export $distro $BackupFile
            $fileSize = (Get-Item $BackupFile).Length / 1GB
            Write-LogSuccess "Export dokončen: $BackupFile ($([math]::Round($fileSize, 2)) GB)"
            
        } catch {
            Write-LogError "Chyba při exportu $distro : $_"
        }
    }
    
    Write-LogSuccess "Export všech distribucí dokončen"
}

function Install-WSLModules {
    Write-LogInfo "Instalace WSL modulů a nástrojů..."
    
    $distros = Get-WSLDistributions
    if ($distros.Count -eq 0) {
        Write-LogError "Nenalezeny žádné WSL distribuce"
        return
    }
    
    $modules = @(
        "docker.io", "docker-compose", "zsh", "tmux", "jq", "yq", 
        "rclone", "borgbackup", "mosquitto", "mqtt-tools", 
        "neofetch", "curl", "wget", "python3-pip", "git", "tar", "unzip"
    )
    
    foreach ($distro in $distros) {
        Write-LogInfo "Instalace modulů pro: $distro"
        
        try {
            # Aktualizace systému
            wsl -d $distro -u root -- bash -c "apt update && apt upgrade -y" 2>$null
            
            # Instalace modulů
            $modulesString = $modules -join " "
            wsl -d $distro -u root -- bash -c "apt install -y $modulesString" 2>$null
            
            # Instalace Oh My Zsh
            wsl -d $distro -u $DefaultWSLUser -- bash -c '
                sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || true
            ' 2>$null
            
            Write-LogSuccess "Moduly pro $distro nainstalovány"
            
        } catch {
            Write-LogError "Chyba při instalaci modulů pro $distro : $_"
        }
    }
    
    Write-LogSuccess "Instalace WSL modulů dokončena"
}

function Clean-WSLSystem {
    Write-LogInfo "Čištění WSL systémů..."
    
    $distros = Get-WSLDistributions
    if ($distros.Count -eq 0) {
        Write-LogError "Nenalezeny žádné WSL distribuce"
        return
    }
    
    foreach ($distro in $distros) {
        Write-LogInfo "Čistím distribuci: $distro"
        
        try {
            # Docker cleanup
            wsl -d $distro -u root -- bash -c "docker system prune -af || true" 2>$null
            
            # Cache cleanup
            wsl -d $distro -u root -- bash -c "
                rm -rf ~/.cache/waydroid ~/.cache/anbox 2>/dev/null || true
                pip3 cache purge 2>/dev/null || true
                apt autoremove -y 2>/dev/null || true
                apt autoclean 2>/dev/null || true
            " 2>$null
            
            Write-LogSuccess "Čištění $distro dokončeno"
            
        } catch {
            Write-LogError "Chyba při čištění $distro : $_"
        }
    }
    
    Write-LogSuccess "Čištění všech WSL distribucí dokončeno"
}

# ---------------------- Automatická oprava ---------------
function Invoke-WithRetry {
    param(
        [ScriptBlock]$ScriptBlock,
        [int]$MaxAttempts = 3
    )
    
    $attempt = 1
    while ($attempt -le $MaxAttempts) {
        try {
            & $ScriptBlock
            return $true
        } catch {
            Write-LogWarning "Pokus $attempt/$MaxAttempts selhal: $_"
            Start-Sleep -Seconds 2
            $attempt++
        }
    }
    Write-LogError "Operace selhala po $MaxAttempts pokusech"
    return $false
}

# ---------------------- WSL Management -------------------
function Install-WSL {
    Write-LogInfo "Instaluji WSL..."
    
    Invoke-WithRetry {
        wsl --install
        Write-LogSuccess "WSL nainstalován. Restartujte počítač."
    }
    
    Read-Host "Press Enter..."
}

function Install-WSLDistribution {
    Write-Host "`nDostupné distribuce:" -ForegroundColor Cyan
    Write-Host "1) Ubuntu"
    Write-Host "2) Debian"
    Write-Host "3) Kali Linux"
    Write-Host "4) Alpine"
    Write-Host "5) OpenSUSE"
    
    $choice = Read-Host "Vyberte distribuci"
    
    $distros = @{
        "1" = "Ubuntu"
        "2" = "Debian"
        "3" = "kali-linux"
        "4" = "Alpine"
        "5" = "openSUSE-42"
    }
    
    if ($distros.ContainsKey($choice)) {
        $distro = $distros[$choice]
        Write-LogInfo "Instaluji $distro..."
        wsl --install -d $distro
        Write-LogSuccess "$distro nainstalován"
    }
    
    Read-Host "Press Enter..."
}

function Set-WSLDefaultVersion {
    Write-Host "`nNastavení výchozí verze WSL:" -ForegroundColor Cyan
    Write-Host "1) WSL 1"
    Write-Host "2) WSL 2 (doporučeno)"
    
    $choice = Read-Host "Volba"
    
    if ($choice -eq "1" -or $choice -eq "2") {
        wsl --set-default-version $choice
        Write-LogSuccess "Výchozí verze nastavena na WSL $choice"
    }
    
    Read-Host "Press Enter..."
}

# ---------------------- Quick Fix Manager ----------------
function Show-QuickFixMenu {
    Clear-Host
    Write-Host "╔════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║           QUICK FIX - RYCHLÁ OPRAVA              ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Běžné problémy a řešení:" -ForegroundColor Yellow
    Write-Host "1️⃣  'Skript nelze spustit' → Změnit Execution Policy"
    Write-Host "2️⃣  'Není admin' → Spustit jako správce"  
    Write-Host "3️⃣  'Soubor blokován' → Odblokovat soubor"
    Write-Host "4️⃣  'Příkaz nebyl nalezen' → Použít .\ před názvem"
    Write-Host ""
    
    Write-Host "Automatické opravy:" -ForegroundColor Green
    Write-Host "1) Spustit všechny opravy"
    Write-Host "2) Pouze zkontrolovat problémy"
    Write-Host "3) Nastavit Execution Policy"
    Write-Host "4) Odblokovat tento skript"
    Write-Host "5) Spustit jako správce (restart)"
    Write-Host "6) Zpět do hlavního menu"
    Write-Host "0) Ukončit"
    Write-Host ""
}

function Invoke-QuickFix {
    param([string]$FixType = "all")
    
    Write-LogInfo "Provádím rychlou opravu: $FixType"
    
    $issuesFound = @()
    
    # Kontrola Execution Policy
    if (-not (Test-ExecutionPolicy)) {
        $issuesFound += "Execution Policy je Restricted"
        if ($FixType -eq "all" -or $FixType -eq "execution") {
            Repair-ExecutionPolicy
        }
    }
    
    # Kontrola admin práv
    if (-not (Test-AdminRights)) {
        $issuesFound += "Chybí administrátorská práva"
        if ($FixType -eq "all" -or $FixType -eq "admin") {
            Write-LogWarning "Restartuji skript jako správce..."
            Start-Sleep 2
            Start-Elevated
        }
    }
    
    # Kontrola blokovaného souboru
    $scriptPath = $MyInvocation.MyCommand.Path
    if (-not (Unblock-ScriptFile -ScriptPath $scriptPath)) {
        $issuesFound += "Soubor může být blokován"
    }
    
    if ($issuesFound.Count -eq 0) {
        Write-LogSuccess "Žádné problémy nenalezeny! Skript by měl fungovat správně."
    } else {
        Write-LogWarning "Nalezené problémy:"
        $issuesFound | ForEach-Object { Write-Host "  • $_" -ForegroundColor Yellow }
    }
    
    return $issuesFound.Count -eq 0
}

function Start-QuickFixManager {
    do {
        Show-QuickFixMenu
        $choice = Read-Host "Volba"
        
        switch ($choice) {
            "1" { 
                Write-LogInfo "Spouštím všechny opravy..."
                Invoke-QuickFix -FixType "all"
                if (Test-AdminRights -and (Test-ExecutionPolicy)) {
                    Write-LogSuccess "Všechny opravy úspěšně dokončeny!"
                } else {
                    Write-LogWarning "Některé opravy vyžadují restart skriptu"
                }
                Read-Host "`nPress Enter..."
            }
            "2" { 
                Write-LogInfo "Kontroluji problémy..."
                Invoke-QuickFix -FixType "check"
                Read-Host "`nPress Enter..."
            }
            "3" { 
                Repair-ExecutionPolicy
                Read-Host "`nPress Enter..."
            }
            "4" { 
                Unblock-ScriptFile -ScriptPath $MyInvocation.MyCommand.Path
                Read-Host "`nPress Enter..."
            }
            "5" { 
                Write-LogWarning "Restartuji skript s administrátorskými právy..."
                Start-Sleep 2
                Start-Elevated
            }
            "6" { break }
            "0" { exit }
            default { 
                Write-LogWarning "Neplatná volba"
                Start-Sleep -Seconds 1
            }
        }
    } while ($true)
}

# ---------------------- Package Managers -----------------
function Install-Chocolatey {
    if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-LogInfo "Instaluji Chocolatey..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Write-LogSuccess "Chocolatey nainstalován"
    } else {
        Write-LogSuccess "Chocolatey je již nainstalován"
    }
    
    Read-Host "Press Enter..."
}

function Install-Scoop {
    if (!(Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-LogInfo "Instaluji Scoop..."
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh')
        Write-LogSuccess "Scoop nainstalován"
    } else {
        Write-LogSuccess "Scoop je již nainstalován"
    }
    
    Read-Host "Press Enter..."
}

function Install-WinGet {
    if (!(Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-LogInfo "Instaluji WinGet..."
        Write-LogWarning "Stáhněte WinGet z Microsoft Store nebo GitHub"
        Start-Process "https://github.com/microsoft/winget-cli/releases"
    } else {
        Write-LogSuccess "WinGet je již nainstalován"
    }
    
    Read-Host "Press Enter..."
}

# ---------------------- Essential Tools ------------------
function Install-EssentialTools {
    Write-LogInfo "Instaluji základní nástroje..."
    
    $tools = @(
        "git",
        "vscode",
        "docker-desktop",
        "python",
        "nodejs",
        "7zip",
        "wget",
        "curl"
    )
    
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        foreach ($tool in $tools) {
            Write-LogInfo "Instaluji $tool..."
            choco install $tool -y 2>&1 | Out-Null
        }
        Write-LogSuccess "Základní nástroje nainstalovány"
    } else {
        Write-LogWarning "Nejprve nainstalujte Chocolatey (volba 11)"
    }
    
    Read-Host "Press Enter..."
}

# ---------------------- Docker Management ----------------
function Install-DockerDesktop {
    Write-LogInfo "Instaluji Docker Desktop..."
    
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        choco install docker-desktop -y
        Write-LogSuccess "Docker Desktop nainstalován"
    } else {
        Write-LogInfo "Stahuji Docker Desktop..."
        $url = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
        $output = Join-Path $env:TEMP "DockerDesktopInstaller.exe"
        Invoke-WebRequest -Uri $url -OutFile $output
        Start-Process -FilePath $output -Wait
        Write-LogSuccess "Docker Desktop nainstalován"
    }
    
    Read-Host "Press Enter..."
}

# ---------------------- Network Config -------------------
function Set-NetworkOptimization {
    Write-LogInfo "Optimalizuji síťové nastavení..."
    
    # Disable Teredo
    netsh interface teredo set state disabled
    
    # DNS cache optimization
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" -Name "MaxCacheTtl" -Value 86400 -Type DWord
    
    # TCP optimization
    netsh int tcp set global autotuninglevel=normal
    netsh int tcp set global chimney=enabled
    netsh int tcp set global dca=enabled
    netsh int tcp set global netdma=enabled
    
    Write-LogSuccess "Síť optimalizována"
    Read-Host "Press Enter..."
}

# ---------------------- Windows Cleaner ------------------
function Invoke-WindowsCleaner {
    Write-LogInfo "Čistím Windows..."
    
    # Temp files
    Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
    
    # Windows Update cleanup
    Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase
    
    # Recycle Bin
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    
    # Disk Cleanup
    Start-Process cleanmgr -ArgumentList "/sagerun:1" -Wait
    
    Write-LogSuccess "Windows vyčištěn"
    Read-Host "Press Enter..."
}

# ---------------------- Záloha ---------------------------
function New-SystemBackup {
    param([string]$Name)
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupFile = Join-Path $BackupDir "${Name}_${timestamp}.zip"
    
    Write-LogInfo "Vytvářím zálohu: $backupFile"
    
    try {
        $tempDir = Join-Path $env:TEMP "backup_temp_$timestamp"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        
        # Záloha WSL distribucí
        $distros = Get-WSLDistributions
        foreach ($distro in $distros) {
            $distroBackup = Join-Path $tempDir "$distro.tar"
            wsl --export $distro $distroBackup
        }
        
        # Záloha konfigurace
        Get-SystemInfo | ConvertTo-Json | Out-File (Join-Path $tempDir "system_info.json")
        
        Compress-Archive -Path $tempDir -DestinationPath $backupFile -Force
        Remove-Item $tempDir -Recurse -Force
        
        Write-LogSuccess "Záloha vytvořena: $backupFile"
    } catch {
        Write-LogError "Chyba při zálohování: $_"
    }
}

# ---------------------- Health Check ---------------------
function Invoke-HealthCheck {
    Clear-Host
    Write-Host "╔════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║              SYSTEM HEALTH CHECK                  ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    # CPU Usage
    $cpu = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
    Write-Host "CPU Usage: " -NoNewline
    Write-Host "$([math]::Round($cpu, 2))%" -ForegroundColor $(if($cpu -gt 80){"Red"}elseif($cpu -gt 60){"Yellow"}else{"Green"})
    
    # Memory
    $os = Get-CimInstance Win32_OperatingSystem
    $totalMem = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeMem = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $usedMem = $totalMem - $freeMem
    $memPercent = [math]::Round(($usedMem / $totalMem) * 100, 2)
    Write-Host "Memory: $usedMem GB / $totalMem GB " -NoNewline
    Write-Host "($memPercent%)" -ForegroundColor $(if($memPercent -gt 85){"Red"}elseif($memPercent -gt 70){"Yellow"}else{"Green"})
    
    # Disk
    $disk = Get-PSDrive C
    $diskPercent = [math]::Round((($disk.Used / ($disk.Used + $disk.Free)) * 100), 2)
    Write-Host "Disk C: $([math]::Round($disk.Used/1GB, 2)) GB / $([math]::Round(($disk.Used + $disk.Free)/1GB, 2)) GB " -NoNewline
    Write-Host "($diskPercent%)" -ForegroundColor $(if($diskPercent -gt 90){"Red"}elseif($diskPercent -gt 80){"Yellow"}else{"Green"})
    
    # WSL Status
    Write-Host ""
    Write-Host "WSL Distribuce:" -ForegroundColor Cyan
    $distros = Get-WSLDistributions
    if ($distros.Count -gt 0) {
        foreach ($distro in $distros) {
            $running = wsl -d $distro --exec echo "running" 2>$null
            if ($running -eq "running") {
                Write-Host "  ✓ $distro" -ForegroundColor Green
            } else {
                Write-Host "  ✗ $distro (stopped)" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "  Žádné WSL distribuce" -ForegroundColor Red
    }
    
    # Services
    Write-Host ""
    Write-Host "Důležité služby:" -ForegroundColor Cyan
    $services = @("WinRM", "W32Time", "Dhcp", "Dnscache", "LxssManager")
    foreach ($service in $services) {
        $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
        if ($svc) {
            $status = if ($svc.Status -eq "Running") { "✓" } else { "✗" }
            $color = if ($svc.Status -eq "Running") { "Green" } else { "Red" }
            Write-Host "  $status $($svc.DisplayName)" -ForegroundColor $color
        }
    }
    
    Read-Host "`nPress Enter..."
}

# ---------------------- Monitoring Dashboard -------------
function Show-MonitoringDashboard {
    while ($true) {
        Clear-Host
        Write-Host "╔════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║         MONITORING DASHBOARD - LIVE               ║" -ForegroundColor Cyan
        Write-Host "╚════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host "Čas: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
        Write-Host ""
        
        # CPU
        $cpu = [math]::Round((Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue, 2)
        Write-Host "CPU Usage: $cpu%" -ForegroundColor $(if($cpu -gt 80){"Red"}elseif($cpu -gt 60){"Yellow"}else{"Green"})
        $bar = "█" * [math]::Floor($cpu / 2) + "░" * (50 - [math]::Floor($cpu / 2))
        Write-Host "[$bar]"
        
        # Memory
        $os = Get-CimInstance Win32_OperatingSystem
        $memPercent = [math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100, 2)
        Write-Host "`nMemory: $memPercent%" -ForegroundColor $(if($memPercent -gt 85){"Red"}elseif($memPercent -gt 70){"Yellow"}else{"Green"})
        $bar = "█" * [math]::Floor($memPercent / 2) + "░" * (50 - [math]::Floor($memPercent / 2))
        Write-Host "[$bar]"
        
        # Disk
        $disk = Get-PSDrive C
        $diskPercent = [math]::Round((($disk.Used / ($disk.Used + $disk.Free)) * 100), 2)
        Write-Host "`nDisk C: $diskPercent%" -ForegroundColor $(if($diskPercent -gt 90){"Red"}elseif($diskPercent -gt 80){"Yellow"}else{"Green"})
        $bar = "█" * [math]::Floor($diskPercent / 2) + "░" * (50 - [math]::Floor($diskPercent / 2))
        Write-Host "[$bar]"
        
        # Network
        Write-Host "`nNetwork:" -ForegroundColor Cyan
        $adapters = Get-NetAdapter | Where-Object Status -eq "Up"
        foreach ($adapter in $adapters | Select-Object -First 3) {
            Write-Host "  $($adapter.Name): $($adapter.LinkSpeed)" -ForegroundColor Green
        }
        
        # Top Processes
        Write-Host "`nTop 5 Procesů (CPU):" -ForegroundColor Cyan
        Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 | ForEach-Object {
            Write-Host ("  {0,-20} {1,5:N1}% CPU" -f $_.ProcessName, $_.CPU)
        }
        
        # WSL Status
        Write-Host "`nWSL Status:" -ForegroundColor Cyan
        $distros = Get-WSLDistributions
        foreach ($distro in $distros) {
            Write-Host "  ✓ $distro" -ForegroundColor Green
        }
        
        Write-Host "`n[Q] Ukončit | Auto-refresh: 3s" -ForegroundColor Yellow
        
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq "Q") { break }
        }
        
        Start-Sleep -Seconds 3
    }
}

# ---------------------- Custom Scripts -------------------
function Initialize-CustomScripts {
    # Auto Backup
    @"
# PowerShell Auto Backup Script
`$BackupDir = "`$env:USERPROFILE\Backups\Auto"
New-Item -ItemType Directory -Path `$BackupDir -Force | Out-Null
`$Date = Get-Date -Format "yyyyMMdd_HHmmss"

Compress-Archive -Path `$env:USERPROFILE -DestinationPath "`$BackupDir\home_`$Date.zip" -Force
Get-ChildItem `$BackupDir -Filter "home_*.zip" | Where-Object LastWriteTime -lt (Get-Date).AddDays(-7) | Remove-Item

Write-Host "✓ Záloha dokončena: `$BackupDir\home_`$Date.zip"
"@ | Out-File (Join-Path $CustomScriptsDir "auto_backup.ps1")

    # System Monitor
    @"
# PowerShell System Monitor
`$cpu = [math]::Round((Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue, 2)
`$os = Get-CimInstance Win32_OperatingSystem
`$mem = [math]::Round(((`$os.TotalVisibleMemorySize - `$os.FreePhysicalMemory) / `$os.TotalVisibleMemorySize) * 100, 2)
`$disk = Get-PSDrive C
`$diskPercent = [math]::Round(((`$disk.Used / (`$disk.Used + `$disk.Free)) * 100), 2)

Write-Host "=== System Monitor ===" -ForegroundColor Cyan
Write-Host "CPU: `$cpu%"
Write-Host "Memory: `$mem%"
Write-Host "Disk: `$diskPercent%"

if (`$cpu -gt 80) { Write-Host "⚠ VAROVÁNÍ: Vysoké CPU!" -ForegroundColor Red }
if (`$mem -gt 85) { Write-Host "⚠ VAROVÁNÍ: Vysoká paměť!" -ForegroundColor Red }
if (`$diskPercent -gt 90) { Write-Host "⚠ VAROVÁNÍ: Plný disk!" -ForegroundColor Red }
"@ | Out-File (Join-Path $CustomScriptsDir "system_monitor.ps1")

    # Windows Update
    @"
# PowerShell Update All
Write-Host "=== Windows Update ===" -ForegroundColor Cyan
Install-PackageProvider -Name NuGet -Force -Scope CurrentUser
Install-Module PSWindowsUpdate -Force -Scope CurrentUser
Import-Module PSWindowsUpdate
Get-WindowsUpdate -Install -AcceptAll -AutoReboot

if (Get-Command choco -ErrorAction SilentlyContinue) {
    choco upgrade all -y
}

Write-Host "✓ Aktualizace dokončeny"
"@ | Out-File (Join-Path $CustomScriptsDir "update_all.ps1")

    # Network Test
    @"
# PowerShell Network Test
Write-Host "=== Network Test ===" -ForegroundColor Cyan

`$hosts = @("8.8.8.8", "1.1.1.1", "google.com")
foreach (`$host in `$hosts) {
    if (Test-Connection -ComputerName `$host -Count 1 -Quiet) {
        Write-Host "✓ `$host - OK" -ForegroundColor Green
    } else {
        Write-Host "✗ `$host - FAILED" -ForegroundColor Red
    }
}

Write-Host "`nSpeed Test (Cloudflare):"
Measure-Command { Invoke-WebRequest -Uri "https://speed.cloudflare.com/__down?bytes=10000000" -OutFile `$null }

Write-Host "`n✓ Network test dokončen"
"@ | Out-File (Join-Path $CustomScriptsDir "network_test.ps1")

    # Security Audit
    @"
# PowerShell Security Audit
Write-Host "=== Security Audit ===" -ForegroundColor Cyan

Write-Host "`nFirewall Status:"
Get-NetFirewallProfile | Select-Object Name, Enabled

Write-Host "`nAntivirus Status:"
Get-MpComputerStatus | Select-Object AntivirusEnabled, RealTimeProtectionEnabled

Write-Host "`nOpen Ports:"
Get-NetTCPConnection -State Listen | Select-Object LocalAddress, LocalPort | Sort-Object LocalPort

Write-Host "`n✓ Audit dokončen"
"@ | Out-File (Join-Path $CustomScriptsDir "security_audit.ps1")

    Write-LogSuccess "Custom skripty inicializovány"
}

function Show-CustomScriptsManager {
    if (!(Test-Path $CustomScriptsDir) -or (Get-ChildItem $CustomScriptsDir).Count -eq 0) {
        Initialize-CustomScripts
    }
    
    while ($true) {
        Clear-Host
        Write-Host "╔════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║         CUSTOM SCRIPTS MANAGER                    ║" -ForegroundColor Cyan
        Write-Host "╚════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""
        
        Write-Host "Dostupné skripty:" -ForegroundColor Green
        $scripts = Get-ChildItem $CustomScriptsDir -Filter "*.ps1"
        $i = 1
        foreach ($script in $scripts) {
            Write-Host " $i) $($script.Name)" -ForegroundColor White
            $i++
        }
        
        Write-Host "`nAkce:" -ForegroundColor Yellow
        Write-Host "a) Spustit skript"
        Write-Host "e) Editovat skript"
        Write-Host "n) Vytvořit nový skript"
        Write-Host "d) Smazat skript"
        Write-Host "r) Reinicializovat skripty"
        Write-Host "0) Zpět"
        
        $choice = Read-Host "`nVolba"
        
        switch ($choice) {
            "a" {
                $num = Read-Host "Číslo skriptu"
                if ($num -gt 0 -and $num -le $scripts.Count) {
                    $script = $scripts[$num - 1]
                    Write-Host "`nSpouštím: $($script.Name)" -ForegroundColor Cyan
                    & $script.FullName
                    Read-Host "`nPress Enter..."
                }
            }
            "e" {
                $num = Read-Host "Číslo skriptu"
                if ($num -gt 0 -and $num -le $scripts.Count) {
                    notepad $scripts[$num - 1].FullName
                }
            }
            "n" {
                $name = Read-Host "Název nového skriptu (bez .ps1)"
                $newScript = Join-Path $CustomScriptsDir "$name.ps1"
                @"
# Custom PowerShell Script
Write-Host "=== My Custom Script ===" -ForegroundColor Cyan

# Zde přidejte svůj kód

Write-Host "✓ Hotovo" -ForegroundColor Green
"@ | Out-File $newScript
                notepad $newScript
            }
            "d" {
                $num = Read-Host "Číslo skriptu ke smazání"
                if ($num -gt 0 -and $num -le $scripts.Count) {
                    Remove-Item $scripts[$num - 1].FullName -Force
                    Write-LogSuccess "Skript smazán"
                }
            }
            "r" {
                Initialize-CustomScripts
            }
            "0" { break }
        }
    }
}

# ---------------------- Main Menu ------------------------
function Show-MainMenu {
    Clear-Host
    Write-Host "╔════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  WSL/Windows ULTIMATE PRO MAX v2 - PowerShell     ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    # Status indikátory
    $adminStatus = if (Test-AdminRights) { "✓" } else { "✗" }
    $executionStatus = if (Test-ExecutionPolicy) { "✓" } else { "✗" }
    
    Write-Host "Status: Admin:$adminStatus Execution:$executionStatus" -ForegroundColor $(if ($adminStatus -eq "✓" -and $executionStatus -eq "✓") { "Green" } else { "Red" })
    
    $sysInfo = Get-SystemInfo
    Write-Host "OS: $($sysInfo.OS)" -ForegroundColor Gray
    Write-Host "User: $($sysInfo.User) | Host: $($sysInfo.Hostname)" -ForegroundColor Gray
    
    # Zobrazení statusu WSL
    Show-WSLStatus
    Write-Host ""
    
    Write-Host "═══ QUICK FIX ═══" -ForegroundColor Red
    Write-Host "F) Rychlá oprava problémů se spouštěním"
    Write-Host ""
    
    Write-Host "═══ WSL Management ═══" -ForegroundColor Yellow
    Write-Host " 1) Instalace WSL"
    Write-Host " 2) Instalace distribuce"
    Write-Host " 3) Nastavení výchozí verze WSL"
    Write-Host " 4) Seznam WSL distribucí"
    Write-Host " 5) Health Check"
    Write-Host ""
    
    Write-Host "═══ WSL Advanced ═══" -ForegroundColor Yellow
    Write-Host " 6) Nastavení domovských adresářů na W:"
    Write-Host " 7) Export distribucí na W: disk"
    Write-Host " 8) Instalace WSL modulů"
    Write-Host " 9) Čištění WSL systémů"
    Write-Host "10) Status WSL distribucí"
    Write-Host ""
    
    Write-Host "═══ Package Managers ═══" -ForegroundColor Yellow
    Write-Host "11) Instalace Chocolatey"
    Write-Host "12) Instalace Scoop"
    Write-Host "13) Instalace WinGet"
    Write-Host "14) Instalace základních nástrojů"
    Write-Host ""
    
    Write-Host "═══ Tools & Optimization ═══" -ForegroundColor Yellow
    Write-Host "15) Instalace Docker Desktop"
    Write-Host "16) Optimalizace sítě"
    Write-Host "17) Windows Cleaner"
    Write-Host "18) Záloha systému"
    Write-Host ""
    
    Write-Host "═══ Monitoring & Scripts ═══" -ForegroundColor Yellow
    Write-Host "19) 📊 Monitoring Dashboard"
    Write-Host "20) 🔧 Custom Scripts Manager"
    Write-Host ""
    
    Write-Host " 0) Ukončit" -ForegroundColor Red
    Write-Host ""
}

# ---------------------- Main Loop ------------------------
function Start-Application {
    Initialize-CustomScripts
    
    while ($true) {
        Show-MainMenu
        $choice = Read-Host "Volba"
        
        switch ($choice.ToUpper()) {
            "F" { Start-QuickFixManager }
            "1" { Install-WSL }
            "2" { Install-WSLDistribution }
            "3" { Set-WSLDefaultVersion }
            "4" { 
                $distros = Get-WSLDistributions
                Write-Host "`nNalezené distribuce:" -ForegroundColor Cyan
                $distros | ForEach-Object { Write-Host "  • $_" }
                Read-Host "`nPress Enter..."
            }
            "5" { Invoke-HealthCheck }
            "6" { Set-WSLHomeDirectories; Read-Host "`nPress Enter..." }
            "7" { Export-WSLToWDrive; Read-Host "`nPress Enter..." }
            "8" { Install-WSLModules; Read-Host "`nPress Enter..." }
            "9" { Clean-WSLSystem; Read-Host "`nPress Enter..." }
            "10" { Show-WSLStatus; Read-Host "`nPress Enter..." }
            "11" { Install-Chocolatey }
            "12" { Install-Scoop }
            "13" { Install-WinGet }
            "14" { Install-EssentialTools }
            "15" { Install-DockerDesktop }
            "16" { Set-NetworkOptimization }
            "17" { Invoke-WindowsCleaner }
            "18" { New-SystemBackup -Name "manual" }
            "19" { Show-MonitoringDashboard }
            "20" { Show-CustomScriptsManager }
            "0" { 
                Write-LogSuccess "Ukončuji..."
                exit 0
            }
            default { 
                Write-LogWarning "Neplatná volba"
                Start-Sleep -Seconds 1
            }
        }
    }
}

# ---------------------- Start ----------------------------
Write-LogInfo "WSL Ultimate v2 - Kompletní integrovaný systém s Auto-Fix"
Write-LogInfo "Provádím inicializační kontrolu..."

# Automatická kontrola při startu
$issues = @()
if (-not (Test-AdminRights)) { $issues += "NEJSTE SPRÁVCE" }
if (-not (Test-ExecutionPolicy)) { $issues += "BLOKOVANÁ EXECUTION POLICY" }

if ($issues.Count -gt 0) {
    Write-LogWarning "Nalezeny problémy: $($issues -join ', ')"
    Write-Host ""
    Write-Host "Doporučené řešení:" -ForegroundColor Yellow
    Write-Host "1. Spusťte PowerShell JAKO SPRÁVCE" -ForegroundColor Red
    Write-Host "2. Použijte: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor Red  
    Write-Host "3. Nebo spusťte: .\wsl_ultimate_v2.ps1" -ForegroundColor Red
    Write-Host ""
    
    $choice = Read-Host "Chcete spustit automatickou opravu? (y/n)"
    if ($choice -eq 'y') {
        Start-QuickFixManager
    } else {
        Write-LogInfo "Pokračuji s omezenou funkcionalitou..."
        Start-Application
    }
} else {
    Start-Application
}