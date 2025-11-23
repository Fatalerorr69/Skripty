<# 
SpustitVM-v6.ps1 (Testovací verze se snapshoty)
Autor: Starko
Popis: Simulovaný launcher VM s menu, logy a zálohami (snapshoty)
Verze: 6.3-test
#>

# ===================== KONFIGURACE =====================
$VMName    = "RAW-OS"
$LogFile   = "$PSScriptRoot\SpustitVM-test.log"
$SnapshotDir = "$PSScriptRoot\Snapshots"
# =======================================================

# Proměnná pro simulaci stavu VM
$script:VMRunning = $false

# Vytvoření složky pro snapshoty, pokud neexistuje
if (-not (Test-Path $SnapshotDir)) {
    New-Item -ItemType Directory -Path $SnapshotDir | Out-Null
}

# Funkce: Logování
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp][$Level] $Message"
    Add-Content -Path $LogFile -Value $line
    Write-Host $line
}

# Funkce: Simulovaný snapshot
function Create-Snapshot {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $snapshotName = "$VMName-$timestamp"
    $snapshotFile = Join-Path $SnapshotDir "$snapshotName.txt"
    "Snapshot VM '$VMName' vytvořen v čase $timestamp" | Out-File $snapshotFile
    Write-Log "Simulovaný snapshot '$snapshotName' vytvořen."
}

# Funkce: Start VM
function Start-VM {
    param([switch]$GUI)
    if ($script:VMRunning) {
        Write-Log "VM '$VMName' už běží." "INFO"
    } else {
        # Před startem vytvoříme snapshot
        Create-Snapshot
        $script:VMRunning = $true
        if ($GUI) {
            Write-Log "Simulace spuštění VM '$VMName' s GUI..."
        } else {
            Write-Log "Simulace spuštění VM '$VMName' headless..."
        }
        Write-Log "VM '$VMName' nyní běží."
    }
}

# Funkce: Stop VM
function Stop-VM {
    param([switch]$Force)
    if (-not $script:VMRunning) {
        Write-Log "VM '$VMName' neběží." "INFO"
    } else {
        $script:VMRunning = $false
        if ($Force) {
            Write-Log "Simulace PowerOff VM '$VMName' natvrdo..."
        } else {
            Write-Log "Simulace ACPI shutdown VM '$VMName'..."
        }
        Write-Log "VM '$VMName' nyní vypnuta."
    }
}

# Funkce: Restart VM
function Restart-VM {
    if ($script:VMRunning) {
        Stop-VM -Force
        Start-Sleep -Seconds 1
    }
    Start-VM
}

# Funkce: Status
function Show-Status {
    if ($script:VMRunning) {
        Write-Log "VM '$VMName' běží." "INFO"
    } else {
        Write-Log "VM '$VMName' je vypnutá." "INFO"
    }
}

# Funkce: Výpis logu
function Show-Logs {
    if (Test-Path $LogFile) {
        Write-Host "`n=== Posledních 20 záznamů ==="
        Get-Content $LogFile -Tail 20
        Write-Host "==============================`n"
    } else {
        Write-Log "Soubor logu zatím neexistuje." "INFO"
    }
}

# ===================== START =====================
Write-Log "Start testovací simulace VM '$VMName' s podporou snapshotů"

do {
    Write-Host ""
    Write-Host "===== MENU Simulace VM ====="
    Write-Host "1) Spustit VM (headless)"
    Write-Host "2) Spustit VM (GUI)"
    Write-Host "3) Zastavit VM (ACPI shutdown)"
    Write-Host "4) Zastavit VM (PowerOff natvrdo)"
    Write-Host "5) Restartovat VM"
    Write-Host "6) Status VM"
    Write-Host "7) Výpis logu"
    Write-Host "0) Ukončit"
    Write-Host "==============================="
    $choice = Read-Host "Vyber akci"

    switch ($choice) {
        "1" { Start-VM }
        "2" { Start-VM -GUI }
        "3" { Stop-VM }
        "4" { Stop-VM -Force }
        "5" { Restart-VM }
        "6" { Show-Status }
        "7" { Show-Logs }
        "0" { Write-Log "Ukončení simulace menu."; break }
        default { Write-Host "Neplatná volba, zkuste znovu." }
    }
} while ($true)