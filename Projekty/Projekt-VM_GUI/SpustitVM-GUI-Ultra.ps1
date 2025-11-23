Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ===================== KONFIGURACE =====================
$VMName      = "RAW-OS"
$LogFile     = "$PSScriptRoot\SpustitVM-GUI-Ultra.log"
$SnapshotDir = "$PSScriptRoot\Snapshots"
$script:VMRunning = $false
$RefreshInterval = 5  # automatický refresh snapshotů každých X sekund

# Vytvoření složky pro snapshoty
if (-not (Test-Path $SnapshotDir)) { New-Item -ItemType Directory -Path $SnapshotDir | Out-Null }

# ===================== FUNKCE =====================
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp][$Level] $Message"

    # Barevné logy v GUI
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

    # Zápis do souboru
    Add-Content -Path $LogFile -Value $line
}

function Create-Snapshot {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $snapshotName = "$VMName-$timestamp"
    $snapshotFile = Join-Path $SnapshotDir "$snapshotName.txt"
    "Snapshot VM '$VMName' vytvořen v čase $timestamp" | Out-File $snapshotFile
    Write-Log "Snapshot '$snapshotName' vytvořen." "SNAPSHOT"
    Update-SnapshotList
}

function List-Snapshots { Get-ChildItem -Path $SnapshotDir -Filter "$VMName-*.txt" | Sort-Object LastWriteTime }

function Update-SnapshotList {
    $SnapshotBox.Items.Clear()
    $files = List-Snapshots
    foreach ($f in $files) { $SnapshotBox.Items.Add($f.BaseName) }
}

function Restore-Snapshot {
    if ($SnapshotBox.SelectedItem) {
        $selected = $SnapshotBox.SelectedItem
        $script:VMRunning = $false
        Write-Log "Obnovení VM '$VMName' ze snapshotu '$selected'." "SUCCESS"
        Update-Status
    } else { Write-Log "Vyber snapshot pro obnovení." "ERROR" }
}

function Delete-Snapshot {
    if ($SnapshotBox.SelectedItem) {
        $selected = $SnapshotBox.SelectedItem
        $filePath = Join-Path $SnapshotDir "$selected.txt"
        Remove-Item $filePath
        Write-Log "Snapshot '$selected' odstraněn." "WARNING"
        Update-SnapshotList
    } else { Write-Log "Vyber snapshot pro smazání." "ERROR" }
}

function Delete-Old-Snapshots {
    param([int]$Days = 7)
    $cutoff = (Get-Date).AddDays(-$Days)
    $oldFiles = Get-ChildItem -Path $SnapshotDir -Filter "$VMName-*.txt" | Where-Object { $_.LastWriteTime -lt $cutoff }
    foreach ($f in $oldFiles) { Remove-Item $f.FullName }
    Write-Log "$($oldFiles.Count) starých snapshotů odstraněno." "WARNING"
    Update-SnapshotList
}

function Start-VM {
    param([switch]$GUI)
    if ($script:VMRunning) { Write-Log "VM '$VMName' už běží." "INFO"; return }
    Create-Snapshot
    $script:VMRunning = $true
    if ($GUI) { Write-Log "Spuštění VM '$VMName' s GUI..." "SUCCESS" }
    else { Write-Log "Spuštění VM '$VMName' headless..." "SUCCESS" }
    Update-Status
}

function Stop-VM {
    param([switch]$Force)
    if (-not $script:VMRunning) { Write-Log "VM '$VMName' neběží." "INFO"; return }
    $script:VMRunning = $false
    if ($Force) { Write-Log "PowerOff VM '$VMName' natvrdo..." "WARNING" }
    else { Write-Log "ACPI shutdown VM '$VMName'..." "INFO" }
    Update-Status
}

function Restart-VM {
    if ($script:VMRunning) { Stop-VM -Force; Start-Sleep -Seconds 1 }
    Start-VM
}

function Start-VM-AutoRestore {
    $files = List-Snapshots | Sort-Object LastWriteTime -Descending
    if ($files.Count -gt 0) { Write-Log "Automatické obnovení posledního snapshotu '$($files[0].BaseName)'." "SNAPSHOT"; $script:VMRunning = $false }
    Start-VM -GUI
}

function Simulate-Error { $script:VMRunning = $false; Write-Log "Simulovaná chyba VM!" "ERROR"; Update-Status }

function Update-Status {
    if ($script:VMRunning) { $StatusLabel.Text = "Stav VM: Běží"; $StatusLabel.ForeColor = [System.Drawing.Color]::Green }
    else { $StatusLabel.Text = "Stav VM: Vypnuto"; $StatusLabel.ForeColor = [System.Drawing.Color]::Red }
}

# ===================== GUI =====================
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "RAW OS Launcher GUI Ultra"
$Form.Size = New-Object System.Drawing.Size(900,650)
$Form.StartPosition = "CenterScreen"
$Form.FormBorderStyle = 'Sizable'

# LogBox
$LogBox = New-Object System.Windows.Forms.ListBox
$LogBox.Location = New-Object System.Drawing.Point(10,300)
$LogBox.Size = New-Object System.Drawing.Size(860,300)
$LogBox.Anchor = 'Top,Bottom,Left,Right'
$Form.Controls.Add($LogBox)

# Snapshot ComboBox
$SnapshotBox = New-Object System.Windows.Forms.ComboBox
$SnapshotBox.Location = New-Object System.Drawing.Point(10,260)
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

# ToolTip
$Tooltip = New-Object System.Windows.Forms.ToolTip

# Buttons
$buttons = @{
    "Start Headless" = { Start-VM }
    "Start GUI"      = { Start-VM -GUI }
    "Stop ACPI"      = { Stop-VM }
    "Stop PowerOff"  = { Stop-VM -Force }
    "Restart VM"     = { Restart-VM }
    "Create Snapshot"= { Create-Snapshot }
    "Restore Snapshot"= { Restore-Snapshot }
    "Delete Snapshot"= { Delete-Snapshot }
    "Delete Old Snapshots"= { $days = [int](Read-Host "Počet dnů"); Delete-Old-Snapshots -Days $days }
    "AutoRestore + Start"= { Start-VM-AutoRestore }
    "Simulate Error" = { Simulate-Error }
    "Clear Log"      = { $LogBox.Items.Clear(); Write-Log "Log vymazán." "INFO" }
}

$y = 50
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

# ===================== Timer pro automatický refresh snapshotů =====================
$Timer = New-Object System.Windows.Forms.Timer
$Timer.Interval = $RefreshInterval * 1000
$Timer.Add_Tick({ Update-SnapshotList })
$Timer.Start()

# Show form
[void]$Form.ShowDialog()