# ==========================================================
# WSL / Windows ULTIMATE PRO MAX GUI - PowerShell Edition
# ==========================================================
# Autor: Starko / Fatalerorr69
# GitHub: https://github.com/Fatalerorr69
# ==========================================================

#Requires -RunAsAdministrator

# ---------------------- Nastavení -------------------------
$ErrorActionPreference = "Continue"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogFile = Join-Path $ScriptDir "wsl_gui_$(Get-Date -Format 'yyyyMMdd').log"
$BackupDir = Join-Path $ScriptDir "backups"
$ConfigFile = Join-Path $ScriptDir "wsl_config.json"
$CustomScriptsDir = Join-Path $ScriptDir "custom_scripts"

# Vytvoření adresářů
@($BackupDir, $CustomScriptsDir) | ForEach-Object { 
    if (!(Test-Path $_)) { New-Item -ItemType Directory -Path $_ -Force | Out-Null }
}

# ---------------------- Funkce logování ------------------
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Blue; Add-Content $LogFile "[INFO] $Message" }
function Write-Success { param($Message) Write-Host "[OK] $Message" -ForegroundColor Green; Add-Content $LogFile "[OK] $Message" }
function Write-Warning { param($Message) Write-Host "[WARN] $Message" -ForegroundColor Yellow; Add-Content $LogFile "[WARN] $Message" }
function Write-ErrorLog { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red; Add-Content $LogFile "[ERROR] $Message" }

Write-Info "=== Spuštění $(Get-Date) ==="

# ---------------------- Detekce WSL ----------------------
function Get-WSLDistributions {
    $distros = @()
    try {
        $wslList = wsl --list --quiet 2>$null
        if ($wslList) {
            $distros = $wslList | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim() -replace '\x00','' }
        }
    } catch {
        Write-Warning "WSL není nainstalován nebo není dostupný"
    }
    return $distros
}

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
            Write-Warning "Pokus $attempt/$MaxAttempts selhal: $_"
            Start-Sleep -Seconds 2
            $attempt++
        }
    }
    Write-ErrorLog "Operace selhala po $MaxAttempts pokusech"
    return $false
}

# ---------------------- Záloha ---------------------------
function New-SystemBackup {
    param([string]$Name)
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupFile = Join-Path $BackupDir "${Name}_${timestamp}.zip"
    
    Write-Info "Vytvářím zálohu: $backupFile"
    
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
        
        Write-Success "Záloha vytvořena: $backupFile"
    } catch {
        Write-ErrorLog "Chyba při zálohování: $_"
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

# ---------------------- WSL Management -------------------
function Install-WSL {
    Write-Info "Instaluji WSL..."
    
    Invoke-WithRetry {
        wsl --install
        Write-Success "WSL nainstalován. Restartujte počítač."
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
        Write-Info "Instaluji $distro..."
        wsl --install -d $distro
        Write-Success "$distro nainstalován"
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
        Write-Success "Výchozí verze nastavena na WSL $choice"
    }
    
    Read-Host "Press Enter..."
}

# ---------------------- Package Managers -----------------
function Install-Chocolatey {
    if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Info "Instaluji Chocolatey..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Write-Success "Chocolatey nainstalován"
    } else {
        Write-Success "Chocolatey je již nainstalován"
    }
    
    Read-Host "Press Enter..."
}

function Install-Scoop {
    if (!(Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Info "Instaluji Scoop..."
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh')
        Write-Success "Scoop nainstalován"
    } else {
        Write-Success "Scoop je již nainstalován"
    }
    
    Read-Host "Press Enter..."
}

function Install-WinGet {
    if (!(Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Info "Instaluji WinGet..."
        Write-Warning "Stáhněte WinGet z Microsoft Store nebo GitHub"
        Start-Process "https://github.com/microsoft/winget-cli/releases"
    } else {
        Write-Success "WinGet je již nainstalován"
    }
    
    Read-Host "Press Enter..."
}

# ---------------------- Essential Tools ------------------
function Install-EssentialTools {
    Write-Info "Instaluji základní nástroje..."
    
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
            Write-Info "Instaluji $tool..."
            choco install $tool -y 2>&1 | Out-Null
        }
        Write-Success "Základní nástroje nainstalovány"
    } else {
        Write-Warning "Nejprve nainstalujte Chocolatey (volba 6)"
    }
    
    Read-Host "Press Enter..."
}

# ---------------------- Docker Management ----------------
function Install-DockerDesktop {
    Write-Info "Instaluji Docker Desktop..."
    
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        choco install docker-desktop -y
        Write-Success "Docker Desktop nainstalován"
    } else {
        Write-Info "Stahuji Docker Desktop..."
        $url = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
        $output = Join-Path $env:TEMP "DockerDesktopInstaller.exe"
        Invoke-WebRequest -Uri $url -OutFile $output
        Start-Process -FilePath $output -Wait
        Write-Success "Docker Desktop nainstalován"
    }
    
    Read-Host "Press Enter..."
}

# ---------------------- Network Config -------------------
function Set-NetworkOptimization {
    Write-Info "Optimalizuji síťové nastavení..."
    
    # Disable Teredo
    netsh interface teredo set state disabled
    
    # DNS cache optimization
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" -Name "MaxCacheTtl" -Value 86400 -Type DWord
    
    # TCP optimization
    netsh int tcp set global autotuninglevel=normal
    netsh int tcp set global chimney=enabled
    netsh int tcp set global dca=enabled
    netsh int tcp set global netdma=enabled
    
    Write-Success "Síť optimalizována"
    Read-Host "Press Enter..."
}

# ---------------------- Windows Cleaner ------------------
function Invoke-WindowsCleaner {
    Write-Info "Čistím Windows..."
    
    # Temp files
    Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
    
    # Windows Update cleanup
    Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase
    
    # Recycle Bin
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    
    # Disk Cleanup
    Start-Process cleanmgr -ArgumentList "/sagerun:1" -Wait
    
    Write-Success "Windows vyčištěn"
    Read-Host "Press Enter..."
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

    Write-Success "Custom skripty inicializovány"
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
                    Write-Success "Skript smazán"
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
    Write-Host "║  WSL/Windows ULTIMATE PRO MAX - PowerShell Edition║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    $sysInfo = Get-SystemInfo
    Write-Host "OS: $($sysInfo.OS)" -ForegroundColor Gray
    Write-Host "User: $($sysInfo.User) | Host: $($sysInfo.Hostname)" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "═══ WSL Management ═══" -ForegroundColor Yellow
    Write-Host " 1) Instalace WSL"
    Write-Host " 2) Instalace distribuce"
    Write-Host " 3) Nastavení výchozí verze WSL"
    Write-Host " 4) Seznam WSL distribucí"
    Write-Host " 5) Health Check"
    Write-Host ""
    
    Write-Host "═══ Package Managers ═══" -ForegroundColor Yellow
    Write-Host " 6) Instalace Chocolatey"
    Write-Host " 7) Instalace Scoop"
    Write-Host " 8) Instalace WinGet"
    Write-Host " 9) Instalace základních nástrojů"
    Write-Host ""
    
    Write-Host "═══ Tools & Optimization ═══" -ForegroundColor Yellow
    Write-Host "10) Instalace Docker Desktop"
    Write-Host "11) Optimalizace sítě"
    Write-Host "12) Windows Cleaner"
    Write-Host "13) Záloha systému"
    Write-Host ""
    
    Write-Host "═══ Monitoring & Scripts ═══" -ForegroundColor Yellow
    Write-Host "14) 📊 Monitoring Dashboard"
    Write-Host "15) 🔧 Custom Scripts Manager"
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
        
        switch ($choice) {
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
            "6" { Install-Chocolatey }
            "7" { Install-Scoop }
            "8" { Install-WinGet }
            "9" { Install-EssentialTools }
            "10" { Install-DockerDesktop }
            "11" { Set-NetworkOptimization }
            "12" { Invoke-WindowsCleaner }
            "13" { New-SystemBackup -Name "manual" }
            "14" { Show-MonitoringDashboard }
            "15" { Show-CustomScriptsManager }
            "0" { 
                Write-Success "Ukončuji..."
                exit 0
            }
            default { 
                Write-Warning "Neplatná volba"
                Start-Sleep -Seconds 1
            }
        }
    }
}

# ---------------------- Start ----------------------------
Start-Application
