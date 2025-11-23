Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ===================== KONFIGURACE =====================
$configFile = "$PSScriptRoot\config.json"
if (-not (Test-Path $configFile)) { 
    [System.Windows.Forms.MessageBox]::Show("Konfigurační soubor config.json nebyl nalezen!","Chyba",0,"Error")
    exit
}
$config = Get-Content $configFile | ConvertFrom-Json

$VMList          = $config.VMList       # seznam VM, např. ["RAW-OS","Ubuntu-Lomini"]
$LogFile         = Join-Path $PSScriptRoot $config.LogFile
$SnapshotDir     = Join-Path $PSScriptRoot $config.SnapshotDir
$BackupDir       = Join-Path $PSScriptRoot $config.BackupDir
$RefreshInterval = $config.RefreshInterval
$VBoxManage      = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"

$script:VMStatus = @{}  # Stav každé VM

# ===================== SLOŽKY =====================
foreach ($dir in @($SnapshotDir,$BackupDir)) { 
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
}

# ===================== LOG FUNKCE =====================
function Write-Log {
    param([string]$Message,[string]$Level="INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp][$Level] $Message"

    if ($LogBox) {
        $LogBox.Items.Add($line)
        $LogBox.SelectedIndex = $LogBox.Items.Count - 1
    }
    Add-Content -Path $LogFile -Value $line
}

function Export-Log {
    $exportFile = Join-Path $PSScriptRoot "Log_$(Get-Date -Format yyyyMMdd_HHmmss).txt"
    $LogBox.Items | Out-File $exportFile
    Write-Log "Log exportován do '$exportFile'." "INFO"
}

# ===================== VM MANAGEMENT =====================
function Update-VMStatus {
    foreach ($vm in $VMList) {
        $info = & "$VBoxManage" showvminfo $vm --machinereadable
        $running = $info -match 'VMState="running"'
        $script:VMStatus[$vm] = if ($running) {"Běží"} else {"Vypnuto"}
    }
    if ($VMComboBox.SelectedItem) { $StatusLabel.Text = "Stav: $($script:VMStatus[$VMComboBox.SelectedItem])" }
}

function Start-VM { 
    $vm = $VMComboBox.SelectedItem
    if ($script:VMStatus[$vm] -eq "Běží") { Write-Log "VM '$vm' už běží." "INFO"; return }
    & "$VBoxManage" startvm $vm --type gui
    Write-Log "VM '$vm' spuštěna." "SUCCESS"
    Start-Sleep -Seconds 3
    Update-VMStatus
}

function Stop-VM {
    $vm = $VMComboBox.SelectedItem
    if ($script:VMStatus[$vm] -eq "Vypnuto") { Write-Log "VM '$vm' neběží." "INFO"; return }
    & "$VBoxManage" controlvm $vm acpipowerbutton
    Write-Log "VM '$vm' vypnuta (ACPI shutdown)." "INFO"
    Start-Sleep -Seconds 3
    Update-VMStatus
}

function Restart-VM { Stop-VM; Start-Sleep -Seconds 2; Start-VM }

# ===================== SNAPSHOTY =====================
function Update-SnapshotList {
    $SnapshotBox.Items.Clear()
    $vm = $VMComboBox.SelectedItem
    $files = Get-ChildItem -Path $SnapshotDir -Filter "$vm-*.vbox" -ErrorAction SilentlyContinue
    foreach ($f in $files) { $SnapshotBox.Items.Add($f.BaseName) }
}

function Create-Snapshot {
    $vm = $VMComboBox.SelectedItem
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $snapName = "$vm-$timestamp"
    & "$VBoxManage" snapshot $vm take $snapName
    Write-Log "Snapshot '$snapName' vytvořen." "SNAPSHOT"
    # Backup
    $vboxFile = Join-Path $SnapshotDir "$snapName.vbox"
    $backupFile = Join-Path $BackupDir "$snapName.vbox"
    if (Test-Path $vboxFile) { Copy-Item $vboxFile $backupFile -Force }
    Update-SnapshotList
}

function Restore-Snapshot {
    if ($SnapshotBox.SelectedItem) {
        $snap = $SnapshotBox.SelectedItem
        $vm = $VMComboBox.SelectedItem
        & "$VBoxManage" snapshot $vm restore $snap
        Write-Log "Snapshot '$snap' obnoven." "SUCCESS"
    } else { Write-Log "Vyber snapshot pro obnovení." "ERROR" }
}

function Delete-Snapshot {
    if ($SnapshotBox.SelectedItem) {
        $snap = $SnapshotBox.SelectedItem
        $vm = $VMComboBox.SelectedItem
        & "$VBoxManage" snapshot $vm delete $snap
        Write-Log "Snapshot '$snap' smazán." "WARNING"
        Update-SnapshotList
    } else { Write-Log "Vyber snapshot pro smazání." "ERROR" }
}

# ===================== DISK TOOLS =====================
function Mirror-Disk {
    $diskNumber = Read-Host "Zadej číslo fyzického disku (např. 1)"
    $vdiPath = Join-Path $SnapshotDir "Disk_Mirror_$diskNumber.vdi"
    & "$VBoxManage" internalcommands createrawvmdk -filename $vdiPath -rawdisk "\\.\PhysicalDrive$diskNumber"
    Write-Log "Fyzický disk $diskNumber zrcadlen do $vdiPath" "SUCCESS"
    $attach = Read-Host "Chceš připojit tento disk do VM? (ano/ne)"
    if ($attach -eq "ano") {
        $vm = $VMComboBox.SelectedItem
        & "$VBoxManage" storageattach $vm --storagectl "SATA" --port 1 --device 0 --type hdd --medium $vdiPath
        Write-Log "Disk připojen k VM $vm" "SUCCESS"
    }
}

function Attach-ISO {
    $isoPath = Read-Host "Zadej cestu k ISO souboru"
    $vm = $VMComboBox.SelectedItem
    & "$VBoxManage" storageattach $vm --storagectl "SATA" --port 2 --device 0 --type dvddrive --medium $isoPath
    Write-Log "ISO '$isoPath' připojeno k VM $vm" "SUCCESS"
}

function Detach-ISO {
    $vm = $VMComboBox.SelectedItem
    & "$VBoxManage" storageattach $vm --storagectl "SATA" --port 2 --device 0 --type dvddrive --medium none
    Write-Log "ISO odpojeno z VM $vm" "INFO"
}

# ===================== NETWORK TOOLS =====================
function Show-NetworkAdapters {
    $vm = $VMComboBox.SelectedItem
    & "$VBoxManage" showvminfo $vm | Select-String "NIC"
}

# ===================== GUI =====================
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "RAW OS Launcher ULTRA-PRO"
$Form.Size = New-Object System.Drawing.Size(1100,750)
$Form.StartPosition = "CenterScreen"
$Form.FormBorderStyle = 'Sizable'

# Log Box
$LogBox = New-Object System.Windows.Forms.ListBox
$LogBox.Location = New-Object System.Drawing.Point(10,400)
$LogBox.Size = New-Object System.Drawing.Size(1060,300)
$LogBox.Anchor = 'Top,Bottom,Left,Right'
$Form.Controls.Add($LogBox)

# VM ComboBox
$VMComboBox = New-Object System.Windows.Forms.ComboBox
$VMComboBox.Location = New-Object System.Drawing.Point(10,10)
$VMComboBox.Size = New-Object System.Drawing.Size(300,30)
$VMComboBox.Items.AddRange($VMList)
$VMComboBox.SelectedIndex = 0
$VMComboBox.Add_SelectedIndexChanged({ Update-VMStatus; Update-SnapshotList })
$Form.Controls.Add($VMComboBox)

# Snapshot ComboBox
$SnapshotBox = New-Object System.Windows.Forms.ComboBox
$SnapshotBox.Location = New-Object System.Drawing.Point(320,10)
$SnapshotBox.Size = New-Object System.Drawing.Size(300,30)
$Form.Controls.Add($SnapshotBox)
Update-SnapshotList

# Status Label
$StatusLabel = New-Object System.Windows.Forms.Label
$StatusLabel.Location = New-Object System.Drawing.Point(650,10)
$StatusLabel.Size = New-Object System.Drawing.Size(400,30)
$Form.Controls.Add($StatusLabel)
Update-VMStatus

# Buttons
$buttons = @{
    "Start VM"        = { Start-VM }
    "Stop VM"         = { Stop-VM }
    "Restart VM"      = { Restart-VM }
    "Create Snapshot" = { Create-Snapshot }
    "Restore Snapshot"= { Restore-Snapshot }
    "Delete Snapshot" = { Delete-Snapshot }
    "Mirror Disk"     = { Mirror-Disk }
    "Attach ISO"      = { Attach-ISO }
    "Detach ISO"      = { Detach-ISO }
    "Show NICs"       = { Show-NetworkAdapters }
    "Export Log"      = { Export-Log }
    "Clear Log"       = { $LogBox.Items.Clear(); Write-Log "Log vymazán." "INFO" }
}

$y=50
foreach ($name in $buttons.Keys) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $name
    $btn.Location = New-Object System.Drawing.Point(10,$y)
    $btn.Size = New-Object System.Drawing.Size(120,30)
    $btn.Add_Click($buttons[$name])
    $Form.Controls.Add($btn)
    $y += 35
}

# Timer pro refresh statusů
$Timer = New-Object System.Windows.Forms.Timer
$Timer.Interval = $RefreshInterval * 1000
$Timer.Add_Tick({ Update-VMStatus; Update-SnapshotList })
$Timer.Start()

# Show GUI
[void]$Form.ShowDialog()
