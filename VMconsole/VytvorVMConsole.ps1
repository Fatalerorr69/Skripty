<<<<<<< HEAD
# === VMConsole – all‑in‑one se správou profilů a rotací záloh ===
$root = "C:\Users\Fatal\Desktop\GitHub\Moje Skripty\Skripty\VMconsole"

# 1) Struktura složek
$slozky = @(
  "$root",
  "$root\Config",
  "$root\Modules",
  "$root\Scripts",
  "$root\Data",
  "$root\logs",
  "$root\backups",
  "$root\resources",
  "$root\profiles"
)
$slozky | ForEach-Object { New-Item -ItemType Directory -Path $_ -Force | Out-Null }

# 2) Config.psd1
Set-Content "$root\Config\Config.psd1" @'
@{
  VBoxManagePath = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
  MirrorToolPath = ""
  LogDir         = "$PSScriptRoot\..\logs"
  DataDir        = "$PSScriptRoot\..\Data"
  ProfilesDir    = "$PSScriptRoot\..\profiles"
  DefaultVMType  = "headless"
  DryRun         = $true
  Confirm        = $true
  BackupRetention = 5  # počet záloh, které zůstanou
}
'@ -Encoding UTF8

# 3) Moduly
$moduly = @{
  "logging.psm1" = @'
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logDir = "$PSScriptRoot\..\logs"
    if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory | Out-Null }
    "$timestamp [$Level] $Message" | Out-File "$logDir\app.log" -Append -Encoding utf8
}
'@
  "vbox.psm1" = @'
function Get-VMList { & $Global:Config.VBoxManagePath list vms }
function Start-VM { param($Name, $Type = $Global:Config.DefaultVMType) & $Global:Config.VBoxManagePath startvm $Name --type $Type }
'@
  "network.psm1" = @'
function Set-VMNetwork { param($VMName, $Adapter, $Mode) & $Global:Config.VBoxManagePath modifyvm $VMName --nic$Adapter $Mode }
'@
  "scheduler.psm1" = @'
function Schedule-VMAction {
    param($VMName, $Action, $Time)
    schtasks /create /tn "VM_$Action`_$VMName" /tr "powershell -File `"$PSScriptRoot\..\Scripts\VMAction.ps1`" $VMName $Action" /sc once /st $Time
}
'@
  "monitor.psm1" = @'
function Get-VMStats { param($VMName) & $Global:Config.VBoxManagePath metrics collect $VMName }
'@
  "backup.psm1" = @'
function Backup-VM { 
    param($VMName, $Dest)
    $file = Join-Path $Dest "$VMName-$((Get-Date).ToString('yyyyMMdd_HHmmss')).ova"
    & $Global:Config.VBoxManagePath export $VMName --output $file
    Write-Log "Záloha vytvořena: $file"
    Rotate-Backups -Dest $Dest
}
function Rotate-Backups {
    param($Dest)
    $files = Get-ChildItem -Path $Dest -Filter *.ova | Sort-Object LastWriteTime -Descending
    if ($files.Count -gt $Global:Config.BackupRetention) {
        $toRemove = $files[$Global:Config.BackupRetention..($files.Count - 1)]
        foreach ($f in $toRemove) {
            Remove-Item $f.FullName -Force
            Write-Log "Smazána stará záloha: $($f.Name)"
        }
    }
}
'@
  "mirror.psm1" = @'
function Start-Mirror { param($Source, $Dest) robocopy $Source $Dest /MIR }
'@
  "profiles.psm1" = @'
function Save-VMProfile {
    param($VMName, $CPU, $RAM, $GPU)
    $profilePath = Join-Path $Global:Config.ProfilesDir "$VMName.psd1"
    @{
      CPU = $CPU
      RAM = $RAM
      GPU = $GPU
    } | Export-Clixml -Path $profilePath
    Write-Log "Uložen profil pro VM: $VMName"
}
function Load-VMProfile {
    param($VMName)
    $profilePath = Join-Path $Global:Config.ProfilesDir "$VMName.psd1"
    if (Test-Path $profilePath) {
        $profile = Import-Clixml $profilePath
        & $Global:Config.VBoxManagePath modifyvm $VMName --cpus $profile.CPU --memory $profile.RAM
        Write-Log "Aplikován profil pro VM: $VMName"
    } else {
        Write-Log "Profil pro VM $VMName nenalezen" "WARN"
    }
}
'@
}

foreach ($soubor in $moduly.Keys) {
    Set-Content "$root\Modules\$soubor" $moduly[$soubor] -Encoding UTF8
}

# 4) Skripty
Set-Content "$root\Scripts\Start-VMConsole.ps1" @'
Import-Module "$PSScriptRoot\..\Modules\logging.psm1" -Force
Import-Module "$PSScriptRoot\..\Modules\vbox.psm1" -Force
Import-Module "$PSScriptRoot\..\Modules\network.psm1" -Force
Import-Module "$PSScriptRoot\..\Modules\scheduler.psm1" -Force
Import-Module "$PSScriptRoot\..\Modules\monitor.psm1" -Force
Import-Module "$PSScriptRoot\..\Modules\backup.psm1" -Force
Import-Module "$PSScriptRoot\..\Modules\mirror.psm1" -Force
Import-Module "$PSScriptRoot\..\Modules\profiles.psm1" -Force
# GUI logika WPF by přišla sem
'@ -Encoding UTF8

Set-Content "$root\Scripts\VMAction.ps1" @'
param($VMName, $Action)
Import-Module "$PSScriptRoot\..\Modules\vbox.psm1" -Force
switch ($Action) {
    "start" { Start-VM -Name $VMName }
    "stop"  { & $Global:Config.VBoxManagePath controlvm $VMName poweroff }
}
'@ -Encoding UTF8

# 5) Komprese do ZIP
Compress-Archive -Path "$root\*" -DestinationPath "$root\VMConsole.zip" -Force

Write-Host "Hotovo! ZIP archiv je uložený jako $root\VMConsole.zip"
=======
# === VMConsole – all‑in‑one se správou profilů a rotací záloh ===
$root = "C:\Users\Fatal\Desktop\GitHub\Moje Skripty\Skripty\VMconsole"

# 1) Struktura složek
$slozky = @(
  "$root",
  "$root\Config",
  "$root\Modules",
  "$root\Scripts",
  "$root\Data",
  "$root\logs",
  "$root\backups",
  "$root\resources",
  "$root\profiles"
)
$slozky | ForEach-Object { New-Item -ItemType Directory -Path $_ -Force | Out-Null }

# 2) Config.psd1
Set-Content "$root\Config\Config.psd1" @'
@{
  VBoxManagePath = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
  MirrorToolPath = ""
  LogDir         = "$PSScriptRoot\..\logs"
  DataDir        = "$PSScriptRoot\..\Data"
  ProfilesDir    = "$PSScriptRoot\..\profiles"
  DefaultVMType  = "headless"
  DryRun         = $true
  Confirm        = $true
  BackupRetention = 5  # počet záloh, které zůstanou
}
'@ -Encoding UTF8

# 3) Moduly
$moduly = @{
  "logging.psm1" = @'
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logDir = "$PSScriptRoot\..\logs"
    if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory | Out-Null }
    "$timestamp [$Level] $Message" | Out-File "$logDir\app.log" -Append -Encoding utf8
}
'@
  "vbox.psm1" = @'
function Get-VMList { & $Global:Config.VBoxManagePath list vms }
function Start-VM { param($Name, $Type = $Global:Config.DefaultVMType) & $Global:Config.VBoxManagePath startvm $Name --type $Type }
'@
  "network.psm1" = @'
function Set-VMNetwork { param($VMName, $Adapter, $Mode) & $Global:Config.VBoxManagePath modifyvm $VMName --nic$Adapter $Mode }
'@
  "scheduler.psm1" = @'
function Schedule-VMAction {
    param($VMName, $Action, $Time)
    schtasks /create /tn "VM_$Action`_$VMName" /tr "powershell -File `"$PSScriptRoot\..\Scripts\VMAction.ps1`" $VMName $Action" /sc once /st $Time
}
'@
  "monitor.psm1" = @'
function Get-VMStats { param($VMName) & $Global:Config.VBoxManagePath metrics collect $VMName }
'@
  "backup.psm1" = @'
function Backup-VM { 
    param($VMName, $Dest)
    $file = Join-Path $Dest "$VMName-$((Get-Date).ToString('yyyyMMdd_HHmmss')).ova"
    & $Global:Config.VBoxManagePath export $VMName --output $file
    Write-Log "Záloha vytvořena: $file"
    Rotate-Backups -Dest $Dest
}
function Rotate-Backups {
    param($Dest)
    $files = Get-ChildItem -Path $Dest -Filter *.ova | Sort-Object LastWriteTime -Descending
    if ($files.Count -gt $Global:Config.BackupRetention) {
        $toRemove = $files[$Global:Config.BackupRetention..($files.Count - 1)]
        foreach ($f in $toRemove) {
            Remove-Item $f.FullName -Force
            Write-Log "Smazána stará záloha: $($f.Name)"
        }
    }
}
'@
  "mirror.psm1" = @'
function Start-Mirror { param($Source, $Dest) robocopy $Source $Dest /MIR }
'@
  "profiles.psm1" = @'
function Save-VMProfile {
    param($VMName, $CPU, $RAM, $GPU)
    $profilePath = Join-Path $Global:Config.ProfilesDir "$VMName.psd1"
    @{
      CPU = $CPU
      RAM = $RAM
      GPU = $GPU
    } | Export-Clixml -Path $profilePath
    Write-Log "Uložen profil pro VM: $VMName"
}
function Load-VMProfile {
    param($VMName)
    $profilePath = Join-Path $Global:Config.ProfilesDir "$VMName.psd1"
    if (Test-Path $profilePath) {
        $profile = Import-Clixml $profilePath
        & $Global:Config.VBoxManagePath modifyvm $VMName --cpus $profile.CPU --memory $profile.RAM
        Write-Log "Aplikován profil pro VM: $VMName"
    } else {
        Write-Log "Profil pro VM $VMName nenalezen" "WARN"
    }
}
'@
}

foreach ($soubor in $moduly.Keys) {
    Set-Content "$root\Modules\$soubor" $moduly[$soubor] -Encoding UTF8
}

# 4) Skripty
Set-Content "$root\Scripts\Start-VMConsole.ps1" @'
Import-Module "$PSScriptRoot\..\Modules\logging.psm1" -Force
Import-Module "$PSScriptRoot\..\Modules\vbox.psm1" -Force
Import-Module "$PSScriptRoot\..\Modules\network.psm1" -Force
Import-Module "$PSScriptRoot\..\Modules\scheduler.psm1" -Force
Import-Module "$PSScriptRoot\..\Modules\monitor.psm1" -Force
Import-Module "$PSScriptRoot\..\Modules\backup.psm1" -Force
Import-Module "$PSScriptRoot\..\Modules\mirror.psm1" -Force
Import-Module "$PSScriptRoot\..\Modules\profiles.psm1" -Force
# GUI logika WPF by přišla sem
'@ -Encoding UTF8

Set-Content "$root\Scripts\VMAction.ps1" @'
param($VMName, $Action)
Import-Module "$PSScriptRoot\..\Modules\vbox.psm1" -Force
switch ($Action) {
    "start" { Start-VM -Name $VMName }
    "stop"  { & $Global:Config.VBoxManagePath controlvm $VMName poweroff }
}
'@ -Encoding UTF8

# 5) Komprese do ZIP
Compress-Archive -Path "$root\*" -DestinationPath "$root\VMConsole.zip" -Force

Write-Host "Hotovo! ZIP archiv je uložený jako $root\VMConsole.zip"
>>>>>>> 2d437cc2ae07a396d41a3b74e61ac94634aea845
