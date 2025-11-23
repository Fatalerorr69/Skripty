Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ===================== KONFIGURACE =====================
$configFile = "$PSScriptRoot\config.json"
if (-not (Test-Path $configFile)) { 
    [System.Windows.Forms.MessageBox]::Show("Konfigurační soubor config.json nebyl nalezen!","Chyba",0,"Error")
    exit
}
$config = Get-Content $configFile | ConvertFrom-Json

$VMName          = $config.VMName
$LogFile         = Join-Path $PSScriptRoot $config.LogFile
$SnapshotDir     = Join-Path $PSScriptRoot $config.SnapshotDir
$BackupDir       = Join-Path $PSScriptRoot $config.BackupDir
$RefreshInterval = $config.RefreshInterval
$VBoxManage      = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"

$script:VMRunning = $false

# ===================== SLOŽKY =====================
foreach ($dir in @($SnapshotDir,$BackupDir)) { 
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
}

# ===================== FUNKCE =====================
function Write-Log {
    param([string]$Message,[string]$Level="INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp][$Level] $Message"

    if ($LogBox) {
        $LogBox.Items.Add($line)
        switch ($Level) {
            "INFO"    { $LogBox.ForeColor = [System.Drawing.Color]::Black }
            "WARNING" { $LogBox.ForeColor = [System.Drawing.Color]::Orange }
            "ERROR"   { $LogBox.ForeColor = [System.Drawing.Color]::Red }
            "SUCCESS" { $LogBox.ForeColor = [System.Drawing.Color]::Green }
            "SNAPSHOT"{ $LogBox.ForeColor = [System.Drawing.Color]::Blue }
        }
        $LogBox.SelectedIndex = $LogBox.Items.Count - 1
    }
    Add-Content -Path $LogFile -Value $line
}

# ===================== VM Management =====================
function Update-Status {
    $info = & "$VBoxManage" showvminfo $VMName --machinereadable
    if ($info -match 'VMState="running"') { $script:VMRunning = $true } else { $script:VMRunning = $false }

    if ($script:VMRunning) {
        $StatusLabel.Text = "Stav VM: Běží"
        $StatusLabel.ForeColor = [System.Drawing.Color]::Green
    } else {
        $StatusLabel.Text = "Stav VM: Vypnuto"
        $StatusLabel.ForeColor = [System.Drawing.Color]::Red
    }
}

function Start-VM { 
    if ($script:VMRunning) { Write-Log "VM '$VMName' už běží." "INFO"; return }
    & "$VBoxManage" startvm $VMName --type gui
    Write-Log "VM '$VMName' spuštěna." "SUCCESS"
    Start-Sleep -Seconds 3
    Update-Status
}

function Stop-VM {
    if (-not $script:VMRunning) { Write-Log "VM '$VMName' neběží." "INFO"; return }
    & "$VBoxManage" controlvm $VMName acpipowerbutton
    Write-Log "VM '$VMName' vypnuta (ACPI shutdown)." "INFO"
    Start-Sleep -Seconds 3
    Update-Status
}

function Restart-VM { Stop-VM; Start-Sleep -Seconds 2; Start-VM }

# ===================== Snapshoty =====================
function Update-SnapshotList {
    $SnapshotBox.Items.Clear()
    $files = Get-ChildItem -Path $SnapshotDir -Filter "$VMName-*.vbox" -ErrorAction SilentlyContinue
    foreach ($f in $files) { $SnapshotBox.Items.Add($f.BaseName) }
}

function Create-Snapshot {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $snapshotName = "$VMName-$timestamp"
    & "$VBoxManage" snapshot $VMName take $snapshotName
    Write-Log "Snapshot '$snapshotName' vytvořen." "SNAPSHOT"

    # Backup
    $vboxFile = Join-Path $SnapshotDir "$snapshotName.vbox"
    $backupFile = Join-Path $BackupDir "$snapshotName.vbox"
    if (Test-Path $vboxFile) { Copy-Item $vboxFile $backupFile -Force }
    Update-SnapshotList
}

function Restore-Snapshot {
    if ($SnapshotBox.SelectedItem) {
        $snap = $SnapshotBox.SelectedItem
        & "$VBoxManage" snapshot $VMName restore $snap
        Write-Log "Snapshot '$snap' obnoven." "SUCCESS"
    } else { Write-Log "Vyber snapshot pro obnovení." "ERROR" }
}

function Delete-Snapshot {
    if ($SnapshotBox.SelectedItem) {
        $snap = $SnapshotBox.SelectedItem
        & "$VBoxManage" snapshot $VMName delete $snap
        Write-Log "Snapshot '$snap' smazán." "WARNING"
        Update-SnapshotList
    } else { Write-Log "Vyber snapshot pro smazání." "ERROR" }
}

# ===================== Disk / Mirror Disk =====================
function Mirror-Disk {
    $diskNumber = Read-Host "Zadej číslo fyzického disku (např. 1)"
    $vdiPath = Join-Path $SnapshotDir "Disk_Mirror_$diskNumber.vdi"

    & "$VBoxManage" internalcommands createrawvmdk -filename $vdiPath -rawdisk "\\.\PhysicalDrive$diskNumber"
    Write-Log "Fyzický disk $diskNumber zrcadlen do $vdiPath" "SUCCESS"

    $attach = Read-Host "Chceš připojit tento disk do VM? (ano/ne)"
    if ($attach -eq "ano") {
        & "$VBoxManage" storageattach $VMName --storagectl "SATA" --port 1 --device 0 --type hdd --medium $vdiPath
        Write-Log "Disk připojen k VM $VMName" "SUCCESS"
    }
}

# ===================== Export Log =====================
function Export-Log {
    $exportFile = Join-Path $PSScriptRoot "Log_$(Get-Date -Format yyyyMMdd_HHmmss).txt"
    $LogBox.Items | Out-File $exportFile
    Write-Log "Log exportován do '$exportFile'." "INFO"
}

# ===================== GUI =====================
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "RAW OS Launcher ULTRA-PLUS"
$Form.Size = New-Object System.Drawing.Size(1000,700)
$Form.StartPosition = "CenterScreen"
$Form.FormBorderStyle = 'Sizable'

# Log Box
$LogBox = New-Object System.Windows.Forms.ListBox
$LogBox.Location = New-Object System.Drawing.Point(10,350)
$LogBox.Size = New-Object System.Drawing.Size(960,300)
$LogBox.Anchor = 'Top,Bottom,Left,Right'
$Form.Controls.Add($LogBox)

# Snapshot ComboBox
$SnapshotBox = New-Object System.Windows.Forms.ComboBox
$SnapshotBox.Location = New-Object System.Drawing.Point(10,310)
$SnapshotBox.Size = New-Object System.Drawing.Size(400,30)
$SnapshotBox.Anchor = 'Top,Left,Right'
$Form.Controls.Add($SnapshotBox)
Update-SnapshotList

# Status Label
$StatusLabel = New-Object System.Windows.Forms.Label
$StatusLabel.Location = New-Object System.Drawing.Point(10,10)
$StatusLabel.Size = New-Object System.Drawing.Size(400,30)
$Form.Controls.Add($StatusLabel)
Update-Status

# Tooltip
$Tooltip = New-Object System.Windows.Forms.ToolTip

# Buttons
$buttons = @{
    "Start VM"        = { Start-VM }
    "Stop VM"         = { Stop-VM }
    "Restart VM"      = { Restart-VM }
    "Create Snapshot" = { Create-Snapshot }
    "Restore Snapshot"= { Restore-Snapshot }
    "Delete Snapshot" = { Delete-Snapshot }
    "Mirror Disk"     = { Mirror-Disk }
    "Export Log"      = { Export-Log }
    "Clear Log"       = { $LogBox.Items.Clear(); Write-Log "Log vymazán." "INFO" }
}

$y=50
foreach ($name in $buttons.Keys) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $name
    $btn.Location = New-Object System.Drawing.Point(10,$y)
    $btn.Size = New-Object System.Drawing.Size(150,30)
    $btn.Add_Click($buttons[$name])
    $Tooltip.SetToolTip($btn,"Akce: $name")
    $Form.Controls.Add($btn)
    $y += 35
}

# Timer pro refresh snapshotů
$Timer = New-Object System.Windows.Forms.Timer
$Timer.Interval = $RefreshInterval * 1000
$Timer.Add_Tick({ Update-SnapshotList; Update-Status })
$Timer.Start()

# Zobraz GUI
[void]$Form.ShowDialog()