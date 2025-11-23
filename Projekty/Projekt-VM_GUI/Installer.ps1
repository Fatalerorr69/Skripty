# =========================================================================
# Soubor: Installer.ps1
# Popis: Instalační skript pro VirtualBox RAW OS Launcher
# Verze: 6.1 (stabilizace detekce VBox, logování, artefakty v _resources)
# =========================================================================

# Tvrdší chování na chyby
$ErrorActionPreference = 'Stop'

# -------------------------------------------------------------------------
# 1) Ověření administrátorských práv a verze PowerShell
# -------------------------------------------------------------------------
function Assert-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal   = New-Object Security.Principal.WindowsPrincipal($currentUser)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "Chyba: Skript musí být spuštěn jako Administrátor." -ForegroundColor Red
        Read-Host "Stiskněte Enter pro ukončení"
        exit 1
    }
}

function Assert-PSVersion {
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Host "Chyba: Vyžadována verze PowerShell 5.0 nebo novější." -ForegroundColor Red
        Read-Host "Stiskněte Enter pro ukončení"
        exit 1
    }
}

Assert-Admin
Assert-PSVersion

# -------------------------------------------------------------------------
# 2) Logování + adresářová struktura
# -------------------------------------------------------------------------
$scriptPath   = Split-Path -Parent -Path $MyInvocation.MyCommand.Path
$dataDir      = Join-Path $scriptPath '_data'
$resourcesDir = Join-Path $scriptPath '_resources'
$updatesDir   = Join-Path $scriptPath '_updates'

foreach ($d in @($dataDir, $resourcesDir, $updatesDir)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d | Out-Null }
}

$logFile = Join-Path $dataDir 'install.log'

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $line  = "[$stamp][$Level] $Message"
    Write-Host $line
    Add-Content -Path $logFile -Value $line
}

Write-Log "Start Installer.ps1 v6.1"

trap {
    Write-Log "FATAL: $($_.Exception.Message)`n$($_.Exception.StackTrace)" "ERROR"
    Read-Host "Došlo k chybě. Stiskněte Enter pro ukončení"
    exit 1
}

# -------------------------------------------------------------------------
# 3) Robustní detekce VBoxManage.exe
# -------------------------------------------------------------------------
function Find-VBoxManage {
    $candidates = @()

    # PATH
    try {
        $cmd = Get-Command VBoxManage.exe -ErrorAction SilentlyContinue
        if ($cmd) { $candidates += $cmd.Source }
    } catch {}

    # Registry (x64 & WOW6432)
    foreach ($k in @('HKLM:\SOFTWARE\Oracle\VirtualBox','HKLM:\SOFTWARE\WOW6432Node\Oracle\VirtualBox')) {
        if (Test-Path $k) {
            try {
                $dir = (Get-ItemProperty $k -ErrorAction SilentlyContinue).InstallDir
                if ($dir) { $candidates += (Join-Path $dir 'VBoxManage.exe') }
            } catch {}
        }
    }

    # Běžné cesty
    $candidates += @(
        'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe',
        'C:\Program Files (x86)\Oracle\VirtualBox\VBoxManage.exe'
    )

    foreach ($p in $candidates | Select-Object -Unique) {
        if ($p -and (Test-Path $p)) {
            return (Resolve-Path $p).Path
        }
    }
    return $null
}

Write-Host "Kontroluji oprávnění a závislosti..." -ForegroundColor Yellow
$vboxPath = Find-VBoxManage

if (-not $vboxPath) {
    Write-Log "VirtualBox nebyl nalezen."
    # GUI pokus, jinak textový fallback
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $res = [System.Windows.Forms.MessageBox]::Show(
            "VirtualBox nebyl nalezen. Otevřít stránku pro stažení?",
            "VirtualBox chybí",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($res -eq [System.Windows.Forms.DialogResult]::Yes) {
            Start-Process "https://www.virtualbox.org/wiki/Downloads"
        }
    } catch {
        Write-Log "GUI MessageBox není k dispozici. Otevřete: https://www.virtualbox.org/wiki/Downloads"
    }
    Read-Host "Nainstalujte VirtualBox a stiskněte Enter pro opakování detekce..."
    $vboxPath = Find-VBoxManage
    if (-not $vboxPath) {
        throw "VirtualBox nebyl detekován ani po opakování."
    }
}

Write-Log "VBoxManage: $vboxPath"
Set-Content -Path (Join-Path $dataDir 'VBoxManagePath.txt') -Value $vboxPath -Encoding UTF8

# -------------------------------------------------------------------------
# 4) Vytvoření manuálu a pomocných souborů
# -------------------------------------------------------------------------
$manual = @'
# RAW OS Launcher – Manuál

## Spuštění
- Spusťte `SpustitVM-v6.ps1` (kliknutím na zástupce na ploše nebo přímo).
- Ujistěte se, že je nainstalován Oracle VirtualBox.

## VBox Guest Additions (Linux)
1. Vložte "Insert Guest Additions CD image…" ve VirtualBoxu.
2. V hostu spusťte skript `_resources/linux-auto-install.sh`.

## Složky
- `_data` – logy a dočasné soubory instalátoru.
- `_resources` – pomocné skripty, manuál.
- `_updates` – budoucí aktualizace.

Verze manuálu: 6.1
'@

Set-Content -Path (Join-Path $resourcesDir 'Manual.md') -Value $manual -Encoding UTF8

$linuxScript = @'
#!/usr/bin/env bash
set -euo pipefail
echo "[*] Mountuji VBoxGuestAdditions (pokud je vloženo CD)..."
MNT="/mnt/vbox_cdrom"
sudo mkdir -p "$MNT"
if ! mount | grep -q "$MNT"; then
  sudo mount /dev/cdrom "$MNT" || sudo mount /dev/sr0 "$MNT" || true
fi
if [ -x "$MNT/VBoxLinuxAdditions.run" ]; then
  echo "[*] Spouštím instalátor..."
  sudo bash "$MNT/VBoxLinuxAdditions.run" || true
else
  echo "[!] VBoxLinuxAdditions.run nebyl nalezen. Vložte CD z VirtualBoxu."
fi
'@

$linuxPath = Join-Path $resourcesDir 'linux-auto-install.sh'
Set-Content -Path $linuxPath -Value $linuxScript -Encoding UTF8 -NoNewline

# -------------------------------------------------------------------------
# 5) Volitelně: vytvoření zástupce na plochu
# -------------------------------------------------------------------------
try {
    $shell = New-Object -ComObject WScript.Shell
    $desktop = [Environment]::GetFolderPath('Desktop')
    $lnkPath = Join-Path $desktop 'RAW OS Launcher.lnk'
    $target  = Join-Path $scriptPath 'SpustitVM-v6.ps1'
    $shortcut = $shell.CreateShortcut($lnkPath)
    $shortcut.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $shortcut.Arguments  = "-ExecutionPolicy Bypass -File `"$target`""
    $shortcut.WorkingDirectory = $scriptPath
    $shortcut.IconLocation = "$env:SystemRoot\System32\shell32.dll, 220"
    $shortcut.Save()
    Write-Log "Vytvořen zástupce: $lnkPath"
} catch {
    Write-Log "Zástupce se nepodařilo vytvořit: $($_.Exception.Message)" "WARN"
}

# -------------------------------------------------------------------------
# 6) Spuštění hlavní aplikace
# -------------------------------------------------------------------------
$mainScriptPath = Join-Path $scriptPath 'SpustitVM-v6.ps1'
if (-not (Test-Path $mainScriptPath)) {
    Write-Log "Hlavní skript nebyl nalezen: $mainScriptPath" "ERROR"
    Read-Host "Hlavní skript chybí. Stiskněte Enter pro ukončení"
    exit 1
}

Write-Host "Spouštím hlavní aplikaci..." -ForegroundColor Green
Write-Log  "Start hlavní aplikace: $mainScriptPath"

# Preferuj powershell.exe, pokud není, zkus pwsh
$psExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
if (-not (Test-Path $psExe)) { $psExe = "pwsh" }

Start-Process $psExe -ArgumentList "-ExecutionPolicy Bypass -File `"$mainScriptPath`"" -WorkingDirectory $scriptPath -Wait

Write-Host "Instalace a spuštění dokončeno." -ForegroundColor Green
Write-Log  "Installer dokončen."
