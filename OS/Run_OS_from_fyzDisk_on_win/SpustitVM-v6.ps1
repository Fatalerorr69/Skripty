<<<<<<< HEAD
# =========================================================================
# Název souboru: SpustitVM-v6.0.ps1
# Popis: Vylepšená verze pro spouštění OS z fyzického disku s pokročilým GUI
# Verze: 6.0 (Přidána pokročilá kontrola chyb GUI)
# =========================================================================

# -------------------------------------------------------------------------
# 1. Kontrola oprávnění a závislostí
# -------------------------------------------------------------------------

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Chyba: Skript musí být spuštěn s administrátorskými právy." -ForegroundColor Red
    Read-Host "Stiskněte Enter pro ukončení"
    exit
}
$vboxPath = (Get-Item "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" -ErrorAction SilentlyContinue).FullName
if (-not $vboxPath) {
    Write-Host "Chyba: VirtualBox (VBoxManage.exe) nebyl nalezen. Ujistěte se, že je nainstalován." -ForegroundColor Red
    $dialogResult = [System.Windows.Forms.MessageBox]::Show("VirtualBox nebyl nalezen. Chcete otevřít stránku pro stažení?", "Chyba", "YesNo", "Error")
    if ($dialogResult -eq "Yes") {
        Start-Process "https://www.virtualbox.org/wiki/Downloads"
    }
    exit
}
$logFilePath = Join-Path $env:USERPROFILE "vm_log.txt"
if (Test-Path $logFilePath) {
    Clear-Content $logFilePath
}
$configPath = Join-Path $env:USERPROFILE "vm_config.json"

# -------------------------------------------------------------------------
# 2. Vytvoření GUI pro konfiguraci
# -------------------------------------------------------------------------

try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Spuštění VM z fyzického disku"
    $form.Size = New-Object System.Drawing.Size(650, 850)
    $form.StartPosition = "CenterScreen"
    $form.BackColor = [System.Drawing.Color]::Black
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Location = New-Object System.Drawing.Point(0, 0)
    $panel.Size = New-Object System.Drawing.Size(634, 750)
    $panel.AutoScroll = $true
    $form.Controls.Add($panel)
    
    $imagePath = Join-Path $PSScriptRoot "obrazek1.png"
    if (Test-Path $imagePath) {
        $form.BackgroundImage = [System.Drawing.Image]::FromFile($imagePath)
        $form.BackgroundImageLayout = "Stretch"
    } else {
        Write-Host "Pozadí obrázku nebylo nalezeno. Pokračuji bez něj." -ForegroundColor Yellow
    }

    function Add-Log ($text, $color="White", $logLevel="INFO") {
    # Přidání kontroly, zda je barva platná. Pokud ne, použijeme výchozí "White".
    if (-not $color -or $color -notlike "*") {
        $color = "White"
    }

    $logBox.Invoke([action]{
        $formattedText = "`n$((Get-Date -Format 'HH:mm:ss')) [$logLevel] - $text"
        $logBox.SelectionStart = $logBox.TextLength
        $logBox.SelectionLength = 0
        $logBox.SelectionColor = [System.Drawing.Color]::$color  # Tato část teď bude v bezpečí
        $logBox.AppendText($formattedText)
        $logBox.SelectionColor = [System.Drawing.Color]::White
        $logBox.ScrollToCaret()
    })
    Add-Content -Path $logFilePath -Value $formattedText
	}

    # ... zbytek skriptu zůstává beze změny ...
	
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Spuštění VM z fyzického disku"
    $form.Size = New-Object System.Drawing.Size(650, 850)
    $form.StartPosition = "CenterScreen"
    $form.BackColor = [System.Drawing.Color]::Black

    $panel = New-Object System.Windows.Forms.Panel
    $panel.Location = New-Object System.Drawing.Point(0, 0)
    $panel.Size = New-Object System.Drawing.Size(634, 750)
    $panel.AutoScroll = $true
    $form.Controls.Add($panel)
    
    $imagePath = Join-Path $PSScriptRoot "obrazek1.png"
    if (Test-Path $imagePath) {
        $form.BackgroundImage = [System.Drawing.Image]::FromFile($imagePath)
        $form.BackgroundImageLayout = "Stretch"
    } else {
        Write-Host "Pozadí obrázku nebylo nalezeno. Pokračuji bez něj." -ForegroundColor Yellow
    }

    function Add-Log ($text, $color="White", $logLevel="INFO") {
        $logBox.Invoke([action]{
            $formattedText = "`n$((Get-Date -Format 'HH:mm:ss')) [$logLevel] - $text"
            $logBox.SelectionStart = $logBox.TextLength
            $logBox.SelectionLength = 0
            $logBox.SelectionColor = [System.Drawing.Color]::$color
            $logBox.AppendText($formattedText)
            $logBox.SelectionColor = [System.Drawing.Color]::White
            $logBox.ScrollToCaret()
        })
        Add-Content -Path $logFilePath -Value $formattedText
    }

    function Update-Progress($value, $text) {
        $progressBar.Invoke([action]{
            $progressBar.Value = $value
            $statusLabel.Text = $text
        })
    }

    function Save-Config {
        $config = [PSCustomObject]@{
            diskIndex = ($diskBox.SelectedItem.Split(":")[0]).Trim()
            ram = $ramBox.Value
            cpu = $cpuBox.Value
            networkType = $networkBox.SelectedItem
            resolution = $resBox.SelectedItem
            sharePath = $sharePathBox.Text
            accel3d = $accel3dBox.Checked
            sourceFile = $sourceFileBox.SelectedItem
        }
        $config | ConvertTo-Json | Set-Content -Path $configPath
    }

    function Load-Config {
        if (Test-Path $configPath) {
            Add-Log "Načítám poslední konfiguraci..." "Blue"
            $config = Get-Content -Path $configPath | ConvertFrom-Json
            try {
                $diskBox.SelectedItem = $diskBox.Items | Where-Object { $_.StartsWith($config.diskIndex) } | Select-Object -First 1
                $ramBox.Value = $config.ram
                $cpuBox.Value = $config.cpu
                $networkBox.SelectedItem = $config.networkType
                $resBox.SelectedItem = $config.resolution
                $sharePathBox.Text = $config.sharePath
                $accel3dBox.Checked = $config.accel3d
                $sourceFileBox.SelectedItem = $config.sourceFile
                Add-Log "Konfigurace byla úspěšně načtena." "Green"
            } catch {
                Add-Log "Chyba při načítání konfigurace. Používám výchozí nastavení." "Red" "ERROR"
            }
        }
    }

    function Handle-Error($message, $exception) {
        Add-Log $message "Red" "ERROR"
        Add-Log "Detail chyby: $($exception.Exception.Message)" "Red" "ERROR"
        Update-Progress 0 "Došlo k chybě: $message"
        [System.Windows.Forms.MessageBox]::Show("Při spouštění došlo k chybě: `n$message `n`nDetail: $($exception.Exception.Message)", "Chyba", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }

    function Refresh-VMAndDiskLists {
        Add-Log "Skenuji dostupné virtuální stroje a disky..." "Blue"
        $vmBox.Items.Clear()
        $vmBox.Items.Add("Vytvořit novou VM")
        $vmList = (& "$vboxPath" list vms | Select-String -Pattern '"(.+)"' | ForEach-Object { ($_.Matches.Groups[1].Value) })
        $vmBox.Items.AddRange($vmList)
        $vmBox.SelectedIndex = 0
        
        $sourceFileBox.Items.Clear()
        $diskSources = @("Fyzický disk")
        $diskSources += (Get-ChildItem -Path "$env:USERPROFILE\VirtualBox VMs" -Recurse -Include "*.vdi", "*.vmdk", "*.ova", "*.ovf", "*.img", "*.iso" | Select-Object -ExpandProperty FullName)
        $diskSources = $diskSources | Sort-Object
        $sourceFileBox.Items.AddRange($diskSources)
        $sourceFileBox.SelectedIndex = 0
        
        Add-Log "Seznam virtuálních strojů a disků byl aktualizován." "Green"
    }

    $fontBold = New-Object System.Drawing.Font("Arial", 9, [System.Drawing.FontStyle]::Bold)
    $fontNormal = New-Object System.Drawing.Font("Arial", 8)
    $labelColor = [System.Drawing.Color]::White
    $yPos = 20
    
    # GUI prvky...
    # (Zde se nachází celý kód pro vytvoření GUI, který zůstává beze změny)
    # ...
    $diskSourceLabel = New-Object System.Windows.Forms.Label; $diskSourceLabel.Text = "Vyberte zdroj pro VM:"; $diskSourceLabel.Location = New-Object System.Drawing.Point(20, $yPos); $diskSourceLabel.Size = New-Object System.Drawing.Size(250, 20); $diskSourceLabel.Font = $fontBold; $diskSourceLabel.ForeColor = $labelColor; $diskSourceLabel.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($diskSourceLabel)
    $yPos += 25
    $diskSourceDesc = New-Object System.Windows.Forms.Label; $diskSourceDesc.Text = "Můžete použít fyzický disk nebo existující virtuální disk/apliance."; $diskSourceDesc.Location = New-Object System.Drawing.Point(20, $yPos); $diskSourceDesc.Size = New-Object System.Drawing.Size(580, 20); $diskSourceDesc.Font = $fontNormal; $diskSourceDesc.ForeColor = $labelColor; $diskSourceDesc.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($diskSourceDesc)
    $yPos += 25
    $sourceFileBox = New-Object System.Windows.Forms.ComboBox; $sourceFileBox.Location = New-Object System.Drawing.Point(20, $yPos); $sourceFileBox.Size = New-Object System.Drawing.Size(440, 20); $sourceFileBox.DropDownStyle = "DropDownList"; $panel.Controls.Add($sourceFileBox)
    $sourceFileBox.Add_SelectedIndexChanged({
        $isPhysicalDisk = ($sourceFileBox.SelectedItem -eq "Fyzický disk")
        $diskBox.Enabled = $isPhysicalDisk
        $vmdkBackupButton.Enabled = $isPhysicalDisk
        $vmdkDeleteButton.Enabled = $isPhysicalDisk
        $vmBox.SelectedItem = "Vytvořit novou VM"
    })
    
    $yPos += 40
    $disks = Get-WmiObject Win32_DiskDrive | ForEach-Object { "$($_.Index): $($_.Model) - $([math]::Round($_.Size/1GB)) GB" }
    $diskLabel = New-Object System.Windows.Forms.Label; $diskLabel.Text = "Vyberte fyzický disk:"; $diskLabel.Location = New-Object System.Drawing.Point(20, $yPos); $diskLabel.Size = New-Object System.Drawing.Size(250, 20); $diskLabel.Font = $fontBold; $diskLabel.ForeColor = $labelColor; $diskLabel.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($diskLabel)
    $yPos += 25
    $diskDesc = New-Object System.Windows.Forms.Label; $diskDesc.Text = "Zde zvolte disk, ze kterého bude VM bootovat. Bude vytvořeno virtuální zrcadlo."; $diskDesc.Location = New-Object System.Drawing.Point(20, $yPos); $diskDesc.Size = New-Object System.Drawing.Size(580, 20); $diskDesc.Font = $fontNormal; $diskDesc.ForeColor = $labelColor; $diskDesc.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($diskDesc)
    $yPos += 25
    $diskBox = New-Object System.Windows.Forms.ComboBox; $diskBox.Location = New-Object System.Drawing.Point(20, $yPos); $diskBox.Size = New-Object System.Drawing.Size(440, 20); $diskBox.DropDownStyle = "DropDownList"; $diskBox.Items.AddRange($disks); if ($diskBox.Items.Count -gt 0) { $diskBox.SelectedIndex = 0 }; $panel.Controls.Add($diskBox)
    $yPos += 40
    $vmdkLabel = New-Object System.Windows.Forms.Label; $vmdkLabel.Text = "Správa VMDK disku:"; $vmdkLabel.Location = New-Object System.Drawing.Point(20, $yPos); $vmdkLabel.Size = New-Object System.Drawing.Size(250, 20); $vmdkLabel.Font = $fontBold; $vmdkLabel.ForeColor = $labelColor; $vmdkLabel.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($vmdkLabel)
    $yPos += 25
    $vmdkDesc = New-Object System.Windows.Forms.Label; $vmdkDesc.Text = "Možnosti pro vytvoření, zálohování nebo smazání virtuálního disku .vmdk."; $vmdkDesc.Location = New-Object System.Drawing.Point(20, $yPos); $vmdkDesc.Size = New-Object System.Drawing.Size(580, 20); $vmdkDesc.Font = $fontNormal; $vmdkDesc.ForeColor = $labelColor; $vmdkDesc.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($vmdkDesc)
    $yPos += 25
    $vmdkBackupButton = New-Object System.Windows.Forms.Button; $vmdkBackupButton.Text = "Zálohovat VMDK"; $vmdkBackupButton.Location = New-Object System.Drawing.Point(20, $yPos); $vmdkBackupButton.Size = New-Object System.Drawing.Size(150, 25); $vmdkBackupButton.BackColor = [System.Drawing.Color]::Yellow; $vmdkBackupButton.ForeColor = [System.Drawing.Color]::Black; $panel.Controls.Add($vmdkBackupButton)
    $vmdkDeleteButton = New-Object System.Windows.Forms.Button; $vmdkDeleteButton.Text = "Smazat VMDK"; $vmdkDeleteButton.Location = New-Object System.Drawing.Point(180, $yPos); $vmdkDeleteButton.Size = New-Object System.Drawing.Size(150, 25); $vmdkDeleteButton.BackColor = [System.Drawing.Color]::Yellow; $vmdkDeleteButton.ForeColor = [System.Drawing.Color]::Black; $panel.Controls.Add($vmdkDeleteButton)
    $vmdkBackupButton.Add_Click({
        $diskIndex = ($diskBox.SelectedItem.Split(":")[0]).Trim()
        $vmdkPath = "$env:USERPROFILE\RAW_OS_Disk_$diskIndex.vmdk"
        if (-not (Test-Path $vmdkPath)) { Add-Log "Chyba: Soubor VMDK neexistuje." "Red"; return }
        $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderBrowser.Description = "Vyberte složku pro zálohu VMDK souboru"
        if ($folderBrowser.ShowDialog() -eq "OK") {
            try {
                Add-Log "Zálohuji VMDK soubor..."
                Copy-Item -Path $vmdkPath -Destination $folderBrowser.SelectedPath -Force -PassThru | Out-Null
                Add-Log "VMDK soubor byl úspěšně zálohován." "Green" "SUCCESS"
            } catch {
                Handle-Error "Chyba při zálohování VMDK souboru." $_
            }
        }
    })
    $vmdkDeleteButton.Add_Click({
        $diskIndex = ($diskBox.SelectedItem.Split(":")[0]).Trim()
        $vmdkPath = "$env:USERPROFILE\RAW_OS_Disk_$diskIndex.vmdk"
        if (-not (Test-Path $vmdkPath)) { Add-Log "Chyba: Soubor VMDK neexistuje." "Red"; return }
        $dialogResult = [System.Windows.Forms.MessageBox]::Show("Opravdu chcete smazat soubor $vmdkPath? Tuto akci nelze vrátit zpět.", "Potvrzení smazání", "YesNo", "Warning")
        if ($dialogResult -eq "Yes") {
            try {
                Add-Log "Mažu VMDK soubor..."
                Remove-Item -Path $vmdkPath -Force -Recurse
                Add-Log "VMDK soubor byl úspěšně smazán." "Green" "SUCCESS"
            } catch {
                Handle-Error "Chyba při mazání VMDK souboru." $_
            }
        }
    })
    
    $yPos += 40
    $vmLabel = New-Object System.Windows.Forms.Label; $vmLabel.Text = "Správa virtuálních strojů:"; $vmLabel.Location = New-Object System.Drawing.Point(20, $yPos); $vmLabel.Size = New-Object System.Drawing.Size(250, 20); $vmLabel.Font = $fontBold; $vmLabel.ForeColor = $labelColor; $vmLabel.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($vmLabel)
    $yPos += 25
    $vmDesc = New-Object System.Windows.Forms.Label; $vmDesc.Text = "Zvolte existující VM nebo nechte pole prázdné pro vytvoření nové."; $vmDesc.Location = New-Object System.Drawing.Point(20, $yPos); $vmDesc.Size = New-Object System.Drawing.Size(580, 20); $vmDesc.Font = $fontNormal; $vmDesc.ForeColor = $labelColor; $vmDesc.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($vmDesc)
    $yPos += 25
    $vmBox = New-Object System.Windows.Forms.ComboBox; $vmBox.Location = New-Object System.Drawing.Point(20, $yPos); $vmBox.Size = New-Object System.Drawing.Size(440, 20); $vmBox.DropDownStyle = "DropDownList"; $panel.Controls.Add($vmBox)
    $vmBox.Add_SelectedIndexChanged({
        if ($vmBox.SelectedItem -ne "Vytvořit novou VM") {
            Add-Log "Varování: Při výběru existující VM se ignorují parametry RAM, CPU a sítě." "Warning"
        }
    })
    $cloneButton = New-Object System.Windows.Forms.Button; $cloneButton.Text = "Klonovat VM"; $cloneButton.Location = New-Object System.Drawing.Point(440, $yPos); $cloneButton.Size = New-Object System.Drawing.Size(150, 25); $cloneButton.BackColor = [System.Drawing.Color]::Yellow; $cloneButton.ForeColor = [System.Drawing.Color]::Black; $panel.Controls.Add($cloneButton)
    $yPos += 40
    $snapshotButton = New-Object System.Windows.Forms.Button; $snapshotButton.Text = "Vytvořit Snapshot"; $snapshotButton.Location = New-Object System.Drawing.Point(440, $yPos); $snapshotButton.Size = New-Object System.Drawing.Size(150, 25); $snapshotButton.BackColor = [System.Drawing.Color]::Yellow; $snapshotButton.ForeColor = [System.Drawing.Color]::Black; $panel.Controls.Add($snapshotButton)
    $yPos += 40
    $openFolderButton = New-Object System.Windows.Forms.Button; $openFolderButton.Text = "Otevřít složku VM"; $openFolderButton.Location = New-Object System.Drawing.Point(440, $yPos); $openFolderButton.Size = New-Object System.Drawing.Size(150, 25); $openFolderButton.BackColor = [System.Drawing.Color]::Yellow; $openFolderButton.ForeColor = [System.Drawing.Color]::Black; $panel.Controls.Add($openFolderButton)
    $cloneButton.Add_Click({
        $vmName = $vmBox.SelectedItem
        if ($vmName -eq "Vytvořit novou VM") { Add-Log "Chyba: Nejprve musíte vybrat existující VM." "Red"; return }
        $cloneName = [Microsoft.VisualBasic.Interaction]::InputBox("Zadejte název klonu:", "Klonovat VM", "$vmName-Clone")
        if (-not $cloneName) { return }
        try {
            Add-Log "Klonuji VM '$vmName' na '$cloneName'..."
            & "$vboxPath" clonevm "$vmName" --name "$cloneName" --register | Out-Null
            Add-Log "VM byla úspěšně naklonována." "Green" "SUCCESS"
        } catch {
            Handle-Error "Chyba při klonování VM." $_
        }
    })
    $snapshotButton.Add_Click({
        $vmName = $vmBox.SelectedItem
        if ($vmName -eq "Vytvořit novou VM") { Add-Log "Chyba: Nejprve musíte vybrat existující VM." "Red"; return }
        $snapshotName = [Microsoft.VisualBasic.Interaction]::InputBox("Zadejte název snapshotu:", "Vytvořit Snapshot", "$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')")
        if (-not $snapshotName) { return }
        try {
            Add-Log "Vytvářím snapshot '$snapshotName' pro VM '$vmName'..."
            & "$vboxPath" snapshot "$vmName" take "$snapshotName" | Out-Null
            Add-Log "Snapshot byl úspěšně vytvořen." "Green" "SUCCESS"
        } catch {
            Handle-Error "Chyba při vytváření snapshotu." $_
        }
    })
    $openFolderButton.Add_Click({
        $vmName = $vmBox.SelectedItem
        if ($vmName -eq "Vytvořit novou VM") { Add-Log "Chyba: Nejprve musíte vybrat existující VM." "Red"; return }
        try {
            $vmInfo = & "$vboxPath" showvminfo "$vmName" --machinereadable
            $vmPath = $vmInfo | Select-String -Pattern '^CfgFile="(.+)"'
            if ($vmPath) {
                $vmFolder = [System.IO.Path]::GetDirectoryName($vmPath.Matches.Groups[1].Value)
                Start-Process $vmFolder
                Add-Log "Složka VM byla úspěšně otevřena." "Green" "SUCCESS"
            } else {
                Add-Log "Nelze najít složku pro vybranou VM." "Red"
            }
        } catch {
            Handle-Error "Chyba při otevírání složky VM." $_
        }
    })

    $yPos += 20
    $totalRamMB = (Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1MB
    $suggestedRam = [math]::Floor($totalRamMB * 0.5 / 512) * 512
    $ramLabel = New-Object System.Windows.Forms.Label; $ramLabel.Text = "RAM (MB):"; $ramLabel.Location = New-Object System.Drawing.Point(20, $yPos); $ramLabel.Size = New-Object System.Drawing.Size(100, 20); $ramLabel.Font = $fontBold; $ramLabel.ForeColor = $labelColor; $ramLabel.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($ramLabel)
    $ramBox = New-Object System.Windows.Forms.NumericUpDown; $ramBox.Location = New-Object System.Drawing.Point(120, $yPos); $ramBox.Minimum = 512; $ramBox.Maximum = 65536; $ramBox.Value = $suggestedRam; $ramBox.Increment = 512; $panel.Controls.Add($ramBox)
    $yPos += 25
    $ramDesc = New-Object System.Windows.Forms.Label; $ramDesc.Text = "Doporučená hodnota je 50 % vaší celkové RAM. (Doporučeno: $suggestedRam MB)"; $ramDesc.Location = New-Object System.Drawing.Point(20, $yPos); $ramDesc.Size = New-Object System.Drawing.Size(580, 20); $ramDesc.Font = $fontNormal; $ramDesc.ForeColor = $labelColor; $ramDesc.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($ramDesc)
    $yPos += 25
    $logicalProcessors = [Environment]::ProcessorCount
    $suggestedCpu = [math]::Floor($logicalProcessors / 2)
    if ($suggestedCpu -eq 0) { $suggestedCpu = 1 }
    $cpuLabel = New-Object System.Windows.Forms.Label; $cpuLabel.Text = "Počet jader CPU:"; $cpuLabel.Location = New-Object System.Drawing.Point(20, $yPos); $cpuLabel.Size = New-Object System.Drawing.Size(120, 20); $cpuLabel.Font = $fontBold; $cpuLabel.ForeColor = $labelColor; $cpuLabel.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($cpuLabel)
    $cpuBox = New-Object System.Windows.Forms.NumericUpDown; $cpuBox.Location = New-Object System.Drawing.Point(120, $yPos); $cpuBox.Minimum = 1; $cpuBox.Maximum = $logicalProcessors; $cpuBox.Value = $suggestedCpu; $panel.Controls.Add($cpuBox)
    $yPos += 25
    $cpuDesc = New-Object System.Windows.Forms.Label; $cpuDesc.Text = "Navrhovaná hodnota je polovina vašich logických jader. (Doporučeno: $suggestedCpu jader)"; $cpuDesc.Location = New-Object System.Drawing.Point(20, $yPos); $cpuDesc.Size = New-Object System.Drawing.Size(580, 20); $cpuDesc.Font = $fontNormal; $cpuDesc.ForeColor = $labelColor; $cpuDesc.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($cpuDesc)

    $yPos += 40
    $networkLabel = New-Object System.Windows.Forms.Label; $networkLabel.Text = "Konfigurace sítě:"; $networkLabel.Location = New-Object System.Drawing.Point(20, $yPos); $networkLabel.Size = New-Object System.Drawing.Size(150, 20); $networkLabel.Font = $fontBold; $networkLabel.ForeColor = $labelColor; $networkLabel.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($networkLabel)
    $yPos += 25
    $networkDesc = New-Object System.Windows.Forms.Label; $networkDesc.Text = "Zvolte typ síťového adaptéru pro VM. NAT je doporučený pro většinu uživatelů."; $networkDesc.Location = New-Object System.Drawing.Point(20, $yPos); $networkDesc.Size = New-Object System.Drawing.Size(580, 20); $networkDesc.Font = $fontNormal; $networkDesc.ForeColor = $labelColor; $networkDesc.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($networkDesc)
    $yPos += 25
    $networkBox = New-Object System.Windows.Forms.ComboBox; $networkBox.Location = New-Object System.Drawing.Point(20, $yPos); $networkBox.Size = New-Object System.Drawing.Size(200, 20); $networkBox.DropDownStyle = "DropDownList"; $networkBox.Items.AddRange(@("NAT", "Bridged Adapter", "Host-Only Adapter")); $networkBox.SelectedIndex = 0; $panel.Controls.Add($networkBox)

    $yPos += 40
    $resLabel = New-Object System.Windows.Forms.Label; $resLabel.Text = "Rozlišení:"; $resLabel.Location = New-Object System.Drawing.Point(20, $yPos); $resLabel.Size = New-Object System.Drawing.Size(100, 20); $resLabel.Font = $fontBold; $resLabel.ForeColor = $labelColor; $resLabel.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($resLabel)
    $resBox = New-Object System.Windows.Forms.ComboBox; $resBox.Location = New-Object System.Drawing.Point(120, $yPos); $resBox.Size = New-Object System.Drawing.Size(150, 20); $resBox.DropDownStyle = "DropDownList"; $resBox.Items.AddRange(@("1024x768", "1280x1024", "1920x1080")); $resBox.SelectedIndex = 1; $panel.Controls.Add($resBox)
    $yPos += 25
    $resDesc = New-Object System.Windows.Forms.Label; $resDesc.Text = "Nastavuje počáteční rozlišení VM. Lze změnit uvnitř."; $resDesc.Location = New-Object System.Drawing.Point(20, $yPos); $resDesc.Size = New-Object System.Drawing.Size(580, 20); $resDesc.Font = $fontNormal; $resDesc.ForeColor = $labelColor; $resDesc.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($resDesc)

    $yPos += 40
    $shareLabel = New-Object System.Windows.Forms.Label; $shareLabel.Text = "Sdílená složka:"; $shareLabel.Location = New-Object System.Drawing.Point(20, $yPos); $shareLabel.Size = New-Object System.Drawing.Size(150, 20); $shareLabel.Font = $fontBold; $shareLabel.ForeColor = $labelColor; $shareLabel.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($shareLabel)
    $yPos += 25
    $shareDesc = New-Object System.Windows.Forms.Label; $shareDesc.Text = "Tato složka bude přístupná ve VM. Ideální pro přenos souborů."; $shareDesc.Location = New-Object System.Drawing.Point(20, $yPos); $shareDesc.Size = New-Object System.Drawing.Size(580, 20); $shareDesc.Font = $fontNormal; $shareDesc.ForeColor = $labelColor; $shareDesc.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($shareDesc)
    $yPos += 25
    $sharePathBox = New-Object System.Windows.Forms.TextBox; $sharePathBox.Location = New-Object System.Drawing.Point(20, $yPos); $sharePathBox.Size = New-Object System.Drawing.Size(320, 20); $sharePathBox.Text = "$env:USERPROFILE\share"; $sharePathBox.ReadOnly = $true; $panel.Controls.Add($sharePathBox)
    $shareBrowseButton = New-Object System.Windows.Forms.Button; $shareBrowseButton.Text = "Vybrat..."; $shareBrowseButton.Location = New-Object System.Drawing.Point(350, $yPos); $shareBrowseButton.Size = New-Object System.Drawing.Size(110, 25); $shareBrowseButton.BackColor = [System.Drawing.Color]::Yellow; $shareBrowseButton.ForeColor = [System.Drawing.Color]::Black; $panel.Controls.Add($shareBrowseButton)
    $shareBrowseButton.Add_Click({
        $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderBrowser.Description = "Vyberte složku pro sdílení s VM"
        if ($folderBrowser.ShowDialog() -eq "OK") {
            $sharePathBox.Text = $folderBrowser.SelectedPath
        }
    })
    $yPos += 40
    $accel3dBox = New-Object System.Windows.Forms.CheckBox; $accel3dBox.Text = "Povolit 3D akceleraci"; $accel3dBox.Location = New-Object System.Drawing.Point(20, $yPos); $accel3dBox.Size = New-Object System.Drawing.Size(200, 20); $accel3dBox.Checked = $true; $accel3dBox.Font = $fontBold; $accel3dBox.ForeColor = $labelColor; $accel3dBox.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($accel3dBox)
    $yPos += 20
    $accel3dDesc = New-Object System.Windows.Forms.Label; $accel3dDesc.Text = "Zlepšuje grafický výkon v moderních desktopových prostředích."; $accel3dDesc.Location = New-Object System.Drawing.Point(20, $yPos); $accel3dDesc.Size = New-Object System.Drawing.Size(580, 20); $accel3dDesc.Font = $fontNormal; $accel3dDesc.ForeColor = $labelColor; $accel3dDesc.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($accel3dDesc)
    
    $yPos += 40
    $startButton = New-Object System.Windows.Forms.Button; $startButton.Text = "Spustit VM"; $startButton.Location = New-Object System.Drawing.Point(20, $yPos); $startButton.Size = New-Object System.Drawing.Size(120, 40); $startButton.BackColor = [System.Drawing.Color]::Yellow; $startButton.ForeColor = [System.Drawing.Color]::Black; $panel.Controls.Add($startButton)
    $closeButton = New-Object System.Windows.Forms.Button; $closeButton.Text = "Zavřít"; $closeButton.Location = New-Object System.Drawing.Point(150, $yPos); $closeButton.Size = New-Object System.Drawing.Size(120, 40); $closeButton.BackColor = [System.Drawing.Color]::Red; $closeButton.ForeColor = [System.Drawing.Color]::White; $panel.Controls.Add($closeButton)
    $closeButton.Add_Click({
        $form.Close()
    })
    
    $yPos += 60
    $statusLabel = New-Object System.Windows.Forms.Label; $statusLabel.Text = "Připraveno ke spuštění."; $statusLabel.Location = New-Object System.Drawing.Point(20, $yPos); $statusLabel.Size = New-Object System.Drawing.Size(590, 20); $panel.Controls.Add($statusLabel)
    $statusLabel.ForeColor = $labelColor; $statusLabel.BackColor = [System.Drawing.Color]::Transparent;
    $yPos += 20
    $progressBar = New-Object System.Windows.Forms.ProgressBar; $progressBar.Location = New-Object System.Drawing.Point(20, $yPos); $progressBar.Size = New-Object System.Drawing.Size(590, 20); $panel.Controls.Add($progressBar)
    
    $yPos += 30
    $logLabel = New-Object System.Windows.Forms.Label; $logLabel.Text = "Průběh akcí:"; $logLabel.Location = New-Object System.Drawing.Point(20, $yPos); $logLabel.Size = New-Object System.Drawing.Size(100, 20); $logLabel.Font = $fontBold; $logLabel.ForeColor = $labelColor; $logLabel.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($logLabel)
    $yPos += 20
    $logBox = New-Object System.Windows.Forms.RichTextBox; $logBox.Location = New-Object System.Drawing.Point(20, $yPos); $logBox.Size = New-Object System.Drawing.Size(590, 80); $logBox.Multiline = $true; $logBox.ReadOnly = $true; $panel.Controls.Add($logBox)
    $logBox.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60);
    $logBox.ForeColor = [System.Drawing.Color]::White;

} catch {
    Write-Host "FATÁLNÍ CHYBA: Nepodařilo se vytvořit GUI. Skript bude ukončen." -ForegroundColor Red
    Write-Host "Detail chyby: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Stiskněte Enter pro ukončení"
    exit
}

# (Zbývající kód skriptu pro události a spouštění zůstává beze změny)
# ...
$form.Add_Shown({
    Refresh-VMAndDiskLists
    Add-Log "Čekám na spuštění VM..."
    Load-Config
})

$startButton.Add_Click({
    $startButton.Enabled = $false
    
    $sourceFile = $sourceFileBox.SelectedItem
    $isPhysicalDisk = ($sourceFile -eq "Fyzický disk")
    
    if ($isPhysicalDisk) {
        $diskIndex = ($diskBox.SelectedItem.Split(":")[0]).Trim()
        $vmdkPath = "$env:USERPROFILE\RAW_OS_Disk_$diskIndex.vmdk"
        $vmName = "RAW_OS_VM_$diskIndex"
    } elseif ($sourceFile.EndsWith(".iso", [System.StringComparison]::OrdinalIgnoreCase)) {
        $isoPath = $sourceFile
        $vmName = [System.IO.Path]::GetFileNameWithoutExtension($isoPath) + "-ISO"
    } else {
        $diskIndex = "File"
        $vmdkPath = $sourceFile
        $vmName = [System.IO.Path]::GetFileNameWithoutExtension($sourceFile)
    }

    Save-Config
    Update-Progress 0 "Probíhá inicializace..."

    try {
        if ($isPhysicalDisk) {
            Update-Progress 10 "Kontroluji fyzický disk..."
            Add-Log "Pokouším se detekovat operační systém na disku $diskIndex..."
            $osType = "Linux_64"
            if (Test-Path "\\.\PhysicalDrive$diskIndex\Windows\System32") {
                Add-Log "Detekován operační systém Windows.", "Blue"
                $osType = "Windows_64"
            } else {
                Add-Log "Detekován operační systém Linux.", "Blue"
            }

            Update-Progress 20 "Vytvářím virtuální disk..."
            Add-Log "Kontroluji existenci VMDK souboru: $vmdkPath"
            if (-not (Test-Path $vmdkPath)) {
                & "$vboxPath" internalcommands createrawvmdk -filename "$vmdkPath" -rawdisk "\\.\PhysicalDrive$diskIndex" | Out-Null
                if (-not (Test-Path $vmdkPath)) {
                    throw "Vytvoření VMDK souboru se nezdařilo. Zkontrolujte, zda máte administrátorská práva a disk není používán jiným procesem."
                }
                Add-Log "VMDK soubor byl úspěšně vytvořen." "Green" "SUCCESS"
            } else {
                Add-Log "VMDK soubor již existuje, přeskočuji vytvoření."
            }
        }
        
        Update-Progress 40 "Kontroluji VM..."
        $vmExists = (& "$vboxPath" list vms | Select-String $vmName)
        if (-not $vmExists) {
            Add-Log "VM s tímto názvem neexistuje. Vytvářím nový..."
            & "$vboxPath" createvm --name "$vmName" --register | Out-Null
            Add-Log "VM '$vmName' byl úspěšně vytvořen." "Green" "SUCCESS"
        } else {
            Add-Log "VM '$vmName' již existuje. Budu jej konfigurovat."
        }
        
        Update-Progress 60 "Konfiguruji parametry..."
        $graphicsController = "vmsvga"
        if ($osType -eq "Windows_64") { $graphicsController = "vboxsvga" }
        
        $accel3dValue = "off"
        if ($accel3dBox.Checked) {
             $accel3dValue = "on"
        }
        
        & "$vboxPath" modifyvm "$vmName" --memory $ramBox.Value --cpus $cpuBox.Value --nic1 $networkBox.SelectedItem.ToLower().Replace(" ", "") --vram 128 --accelerate3d $accel3dValue --graphicscontroller $graphicsController | Out-Null
        
        $sataExists = & "$vboxPath" showvminfo "$vmName" --machinereadable | Select-String "SATA"
        if ($sataExists) {
             Add-Log "Kontroler 'SATA' již existuje, odstraňuji ho pro opětovné připojení..." "Yellow"
             & "$vboxPath" storagectl "$vmName" --name "SATA" --remove | Out-Null
        }
        & "$vboxPath" storagectl "$vmName" --name "SATA" --add sata --controller IntelAhci | Out-Null

        if ($isPhysicalDisk -or ($vmdkPath -and -not $vmdkPath.EndsWith(".iso"))) {
             & "$vboxPath" storageattach "$vmName" --storagectl "SATA" --port 0 --device 0 --type hdd --medium "$vmdkPath" | Out-Null
        }
        if ($isoPath) {
             & "$vboxPath" storageattach "$vmName" --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium "$isoPath" | Out-Null
        }

        $sharedFolderExists = & "$vboxPath" showvminfo "$vmName" --machinereadable | Select-String "winshare"
        if ($sharedFolderExists) {
             Add-Log "Sdílená složka 'winshare' již existuje, odstraňuji ji..." "Yellow"
             & "$vboxPath" sharedfolder remove "$vmName" --name "winshare" | Out-Null
        }
        if (-not (Test-Path $sharePathBox.Text)) {
            New-Item -Path $sharePathBox.Text -ItemType Directory -Force | Out-Null
        }
        & "$vboxPath" sharedfolder add "$vmName" --name "winshare" --hostpath "$($sharePathBox.Text)" --automount | Out-Null
        
        Update-Progress 100 "Startuji virtuální stroj..."
        & "$vboxPath" startvm "$vmName" --type gui
        
        Add-Log "VM byla spuštěna." "Green" "SUCCESS"
        [System.Windows.Forms.MessageBox]::Show("VM byla úspěšně spuštěna.", "Hotovo", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    } catch {
        Handle-Error "V procesu spouštění VM došlo k neočekávané chybě." $_
        
        $dialogResult = [System.Windows.Forms.MessageBox]::Show("Virtuální stroj selhal při bootování. Chcete připojit bootovací ISO/DVD a zkusit to znovu?", "Chyba bootování VM", "YesNo", "Warning")
        if ($dialogResult -eq "Yes") {
            $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
            $fileDialog.Title = "Vyberte ISO soubor operačního systému"
            $fileDialog.Filter = "ISO soubory (*.iso)|*.iso|Všechny soubory (*.*)|*.*"
            
            if ($fileDialog.ShowDialog() -eq "OK") {
                $isoPath = $fileDialog.FileName
                Add-Log "Připojuji ISO soubor: $isoPath" "Blue"
                
                & "$vboxPath" storageattach "$vmName" --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium none | Out-Null
                & "$vboxPath" storageattach "$vmName" --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium "$isoPath" | Out-Null
                
                Add-Log "ISO úspěšně připojeno. Restartuji VM..." "Green"
                Update-Progress 0 "Restartuji..."
                & "$vboxPath" startvm "$vmName" --type gui
                Add-Log "VM byla úspěšně restartována s novým ISO." "Green" "SUCCESS"
            } else {
                Add-Log "Žádný ISO soubor nebyl vybrán. Ukončuji..." "Red"
            }
        }
    } finally {
        $startButton.Enabled = $true
        Update-Progress 0 "Připraveno ke spuštění."
    }
})

$linuxScriptContent = @'
#!/bin/bash
if [ -f /var/log/vbox_auto_done ]; then exit 0; fi
LOG="/var/log/vbox_auto_setup.log"
exec > >(tee -i $LOG) 2>&1
echo "Spouštím automatickou instalaci Guest Additions..."
sudo apt update
sudo apt install -y build-essential dkms linux-headers-$(uname -r)
sudo mkdir -p /mnt/vbox_cdrom
sudo mount /dev/cdrom /mnt/vbox_cdrom
sudo /mnt/vbox_cdrom/VBoxLinuxAdditions.run
sudo mkdir -p /mnt/windows_share
sudo usermod -aG vboxsf $(whoami)
grep -q "winshare" /etc/fstab || echo "winshare /mnt/windows_share vboxsf defaults 0 0" | sudo tee -a /etc/fstab
sudo umount /mnt/vbox_cdrom
sudo touch /var/log/vbox_auto_done
echo "Instalace a mount dokončen."
'@
$serviceFileContent = @'
[Unit]
Description=VBox Guest Additions Auto Setup
After=network.target
[Service]
Type=oneshot
ExecStart=/usr/local/bin/vbox_auto_setup.sh
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
'@

$tempPath = [System.IO.Path]::GetTempPath()
Set-Content -Path (Join-Path $tempPath "vbox_auto_setup.sh") -Value $linuxScriptContent
Set-Content -Path (Join-Path $tempPath "vbox_auto_setup.service") -Value $serviceFileContent

[void]$form.ShowDialog()
=======
# =========================================================================
# Název souboru: SpustitVM-v6.0.ps1
# Popis: Vylepšená verze pro spouštění OS z fyzického disku s pokročilým GUI
# Verze: 6.0 (Přidána pokročilá kontrola chyb GUI)
# =========================================================================

# -------------------------------------------------------------------------
# 1. Kontrola oprávnění a závislostí
# -------------------------------------------------------------------------

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Chyba: Skript musí být spuštěn s administrátorskými právy." -ForegroundColor Red
    Read-Host "Stiskněte Enter pro ukončení"
    exit
}
$vboxPath = (Get-Item "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" -ErrorAction SilentlyContinue).FullName
if (-not $vboxPath) {
    Write-Host "Chyba: VirtualBox (VBoxManage.exe) nebyl nalezen. Ujistěte se, že je nainstalován." -ForegroundColor Red
    $dialogResult = [System.Windows.Forms.MessageBox]::Show("VirtualBox nebyl nalezen. Chcete otevřít stránku pro stažení?", "Chyba", "YesNo", "Error")
    if ($dialogResult -eq "Yes") {
        Start-Process "https://www.virtualbox.org/wiki/Downloads"
    }
    exit
}
$logFilePath = Join-Path $env:USERPROFILE "vm_log.txt"
if (Test-Path $logFilePath) {
    Clear-Content $logFilePath
}
$configPath = Join-Path $env:USERPROFILE "vm_config.json"

# -------------------------------------------------------------------------
# 2. Vytvoření GUI pro konfiguraci
# -------------------------------------------------------------------------

try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Spuštění VM z fyzického disku"
    $form.Size = New-Object System.Drawing.Size(650, 850)
    $form.StartPosition = "CenterScreen"
    $form.BackColor = [System.Drawing.Color]::Black
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Location = New-Object System.Drawing.Point(0, 0)
    $panel.Size = New-Object System.Drawing.Size(634, 750)
    $panel.AutoScroll = $true
    $form.Controls.Add($panel)
    
    $imagePath = Join-Path $PSScriptRoot "obrazek1.png"
    if (Test-Path $imagePath) {
        $form.BackgroundImage = [System.Drawing.Image]::FromFile($imagePath)
        $form.BackgroundImageLayout = "Stretch"
    } else {
        Write-Host "Pozadí obrázku nebylo nalezeno. Pokračuji bez něj." -ForegroundColor Yellow
    }

    function Add-Log ($text, $color="White", $logLevel="INFO") {
    # Přidání kontroly, zda je barva platná. Pokud ne, použijeme výchozí "White".
    if (-not $color -or $color -notlike "*") {
        $color = "White"
    }

    $logBox.Invoke([action]{
        $formattedText = "`n$((Get-Date -Format 'HH:mm:ss')) [$logLevel] - $text"
        $logBox.SelectionStart = $logBox.TextLength
        $logBox.SelectionLength = 0
        $logBox.SelectionColor = [System.Drawing.Color]::$color  # Tato část teď bude v bezpečí
        $logBox.AppendText($formattedText)
        $logBox.SelectionColor = [System.Drawing.Color]::White
        $logBox.ScrollToCaret()
    })
    Add-Content -Path $logFilePath -Value $formattedText
	}

    # ... zbytek skriptu zůstává beze změny ...
	
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Spuštění VM z fyzického disku"
    $form.Size = New-Object System.Drawing.Size(650, 850)
    $form.StartPosition = "CenterScreen"
    $form.BackColor = [System.Drawing.Color]::Black

    $panel = New-Object System.Windows.Forms.Panel
    $panel.Location = New-Object System.Drawing.Point(0, 0)
    $panel.Size = New-Object System.Drawing.Size(634, 750)
    $panel.AutoScroll = $true
    $form.Controls.Add($panel)
    
    $imagePath = Join-Path $PSScriptRoot "obrazek1.png"
    if (Test-Path $imagePath) {
        $form.BackgroundImage = [System.Drawing.Image]::FromFile($imagePath)
        $form.BackgroundImageLayout = "Stretch"
    } else {
        Write-Host "Pozadí obrázku nebylo nalezeno. Pokračuji bez něj." -ForegroundColor Yellow
    }

    function Add-Log ($text, $color="White", $logLevel="INFO") {
        $logBox.Invoke([action]{
            $formattedText = "`n$((Get-Date -Format 'HH:mm:ss')) [$logLevel] - $text"
            $logBox.SelectionStart = $logBox.TextLength
            $logBox.SelectionLength = 0
            $logBox.SelectionColor = [System.Drawing.Color]::$color
            $logBox.AppendText($formattedText)
            $logBox.SelectionColor = [System.Drawing.Color]::White
            $logBox.ScrollToCaret()
        })
        Add-Content -Path $logFilePath -Value $formattedText
    }

    function Update-Progress($value, $text) {
        $progressBar.Invoke([action]{
            $progressBar.Value = $value
            $statusLabel.Text = $text
        })
    }

    function Save-Config {
        $config = [PSCustomObject]@{
            diskIndex = ($diskBox.SelectedItem.Split(":")[0]).Trim()
            ram = $ramBox.Value
            cpu = $cpuBox.Value
            networkType = $networkBox.SelectedItem
            resolution = $resBox.SelectedItem
            sharePath = $sharePathBox.Text
            accel3d = $accel3dBox.Checked
            sourceFile = $sourceFileBox.SelectedItem
        }
        $config | ConvertTo-Json | Set-Content -Path $configPath
    }

    function Load-Config {
        if (Test-Path $configPath) {
            Add-Log "Načítám poslední konfiguraci..." "Blue"
            $config = Get-Content -Path $configPath | ConvertFrom-Json
            try {
                $diskBox.SelectedItem = $diskBox.Items | Where-Object { $_.StartsWith($config.diskIndex) } | Select-Object -First 1
                $ramBox.Value = $config.ram
                $cpuBox.Value = $config.cpu
                $networkBox.SelectedItem = $config.networkType
                $resBox.SelectedItem = $config.resolution
                $sharePathBox.Text = $config.sharePath
                $accel3dBox.Checked = $config.accel3d
                $sourceFileBox.SelectedItem = $config.sourceFile
                Add-Log "Konfigurace byla úspěšně načtena." "Green"
            } catch {
                Add-Log "Chyba při načítání konfigurace. Používám výchozí nastavení." "Red" "ERROR"
            }
        }
    }

    function Handle-Error($message, $exception) {
        Add-Log $message "Red" "ERROR"
        Add-Log "Detail chyby: $($exception.Exception.Message)" "Red" "ERROR"
        Update-Progress 0 "Došlo k chybě: $message"
        [System.Windows.Forms.MessageBox]::Show("Při spouštění došlo k chybě: `n$message `n`nDetail: $($exception.Exception.Message)", "Chyba", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }

    function Refresh-VMAndDiskLists {
        Add-Log "Skenuji dostupné virtuální stroje a disky..." "Blue"
        $vmBox.Items.Clear()
        $vmBox.Items.Add("Vytvořit novou VM")
        $vmList = (& "$vboxPath" list vms | Select-String -Pattern '"(.+)"' | ForEach-Object { ($_.Matches.Groups[1].Value) })
        $vmBox.Items.AddRange($vmList)
        $vmBox.SelectedIndex = 0
        
        $sourceFileBox.Items.Clear()
        $diskSources = @("Fyzický disk")
        $diskSources += (Get-ChildItem -Path "$env:USERPROFILE\VirtualBox VMs" -Recurse -Include "*.vdi", "*.vmdk", "*.ova", "*.ovf", "*.img", "*.iso" | Select-Object -ExpandProperty FullName)
        $diskSources = $diskSources | Sort-Object
        $sourceFileBox.Items.AddRange($diskSources)
        $sourceFileBox.SelectedIndex = 0
        
        Add-Log "Seznam virtuálních strojů a disků byl aktualizován." "Green"
    }

    $fontBold = New-Object System.Drawing.Font("Arial", 9, [System.Drawing.FontStyle]::Bold)
    $fontNormal = New-Object System.Drawing.Font("Arial", 8)
    $labelColor = [System.Drawing.Color]::White
    $yPos = 20
    
    # GUI prvky...
    # (Zde se nachází celý kód pro vytvoření GUI, který zůstává beze změny)
    # ...
    $diskSourceLabel = New-Object System.Windows.Forms.Label; $diskSourceLabel.Text = "Vyberte zdroj pro VM:"; $diskSourceLabel.Location = New-Object System.Drawing.Point(20, $yPos); $diskSourceLabel.Size = New-Object System.Drawing.Size(250, 20); $diskSourceLabel.Font = $fontBold; $diskSourceLabel.ForeColor = $labelColor; $diskSourceLabel.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($diskSourceLabel)
    $yPos += 25
    $diskSourceDesc = New-Object System.Windows.Forms.Label; $diskSourceDesc.Text = "Můžete použít fyzický disk nebo existující virtuální disk/apliance."; $diskSourceDesc.Location = New-Object System.Drawing.Point(20, $yPos); $diskSourceDesc.Size = New-Object System.Drawing.Size(580, 20); $diskSourceDesc.Font = $fontNormal; $diskSourceDesc.ForeColor = $labelColor; $diskSourceDesc.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($diskSourceDesc)
    $yPos += 25
    $sourceFileBox = New-Object System.Windows.Forms.ComboBox; $sourceFileBox.Location = New-Object System.Drawing.Point(20, $yPos); $sourceFileBox.Size = New-Object System.Drawing.Size(440, 20); $sourceFileBox.DropDownStyle = "DropDownList"; $panel.Controls.Add($sourceFileBox)
    $sourceFileBox.Add_SelectedIndexChanged({
        $isPhysicalDisk = ($sourceFileBox.SelectedItem -eq "Fyzický disk")
        $diskBox.Enabled = $isPhysicalDisk
        $vmdkBackupButton.Enabled = $isPhysicalDisk
        $vmdkDeleteButton.Enabled = $isPhysicalDisk
        $vmBox.SelectedItem = "Vytvořit novou VM"
    })
    
    $yPos += 40
    $disks = Get-WmiObject Win32_DiskDrive | ForEach-Object { "$($_.Index): $($_.Model) - $([math]::Round($_.Size/1GB)) GB" }
    $diskLabel = New-Object System.Windows.Forms.Label; $diskLabel.Text = "Vyberte fyzický disk:"; $diskLabel.Location = New-Object System.Drawing.Point(20, $yPos); $diskLabel.Size = New-Object System.Drawing.Size(250, 20); $diskLabel.Font = $fontBold; $diskLabel.ForeColor = $labelColor; $diskLabel.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($diskLabel)
    $yPos += 25
    $diskDesc = New-Object System.Windows.Forms.Label; $diskDesc.Text = "Zde zvolte disk, ze kterého bude VM bootovat. Bude vytvořeno virtuální zrcadlo."; $diskDesc.Location = New-Object System.Drawing.Point(20, $yPos); $diskDesc.Size = New-Object System.Drawing.Size(580, 20); $diskDesc.Font = $fontNormal; $diskDesc.ForeColor = $labelColor; $diskDesc.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($diskDesc)
    $yPos += 25
    $diskBox = New-Object System.Windows.Forms.ComboBox; $diskBox.Location = New-Object System.Drawing.Point(20, $yPos); $diskBox.Size = New-Object System.Drawing.Size(440, 20); $diskBox.DropDownStyle = "DropDownList"; $diskBox.Items.AddRange($disks); if ($diskBox.Items.Count -gt 0) { $diskBox.SelectedIndex = 0 }; $panel.Controls.Add($diskBox)
    $yPos += 40
    $vmdkLabel = New-Object System.Windows.Forms.Label; $vmdkLabel.Text = "Správa VMDK disku:"; $vmdkLabel.Location = New-Object System.Drawing.Point(20, $yPos); $vmdkLabel.Size = New-Object System.Drawing.Size(250, 20); $vmdkLabel.Font = $fontBold; $vmdkLabel.ForeColor = $labelColor; $vmdkLabel.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($vmdkLabel)
    $yPos += 25
    $vmdkDesc = New-Object System.Windows.Forms.Label; $vmdkDesc.Text = "Možnosti pro vytvoření, zálohování nebo smazání virtuálního disku .vmdk."; $vmdkDesc.Location = New-Object System.Drawing.Point(20, $yPos); $vmdkDesc.Size = New-Object System.Drawing.Size(580, 20); $vmdkDesc.Font = $fontNormal; $vmdkDesc.ForeColor = $labelColor; $vmdkDesc.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($vmdkDesc)
    $yPos += 25
    $vmdkBackupButton = New-Object System.Windows.Forms.Button; $vmdkBackupButton.Text = "Zálohovat VMDK"; $vmdkBackupButton.Location = New-Object System.Drawing.Point(20, $yPos); $vmdkBackupButton.Size = New-Object System.Drawing.Size(150, 25); $vmdkBackupButton.BackColor = [System.Drawing.Color]::Yellow; $vmdkBackupButton.ForeColor = [System.Drawing.Color]::Black; $panel.Controls.Add($vmdkBackupButton)
    $vmdkDeleteButton = New-Object System.Windows.Forms.Button; $vmdkDeleteButton.Text = "Smazat VMDK"; $vmdkDeleteButton.Location = New-Object System.Drawing.Point(180, $yPos); $vmdkDeleteButton.Size = New-Object System.Drawing.Size(150, 25); $vmdkDeleteButton.BackColor = [System.Drawing.Color]::Yellow; $vmdkDeleteButton.ForeColor = [System.Drawing.Color]::Black; $panel.Controls.Add($vmdkDeleteButton)
    $vmdkBackupButton.Add_Click({
        $diskIndex = ($diskBox.SelectedItem.Split(":")[0]).Trim()
        $vmdkPath = "$env:USERPROFILE\RAW_OS_Disk_$diskIndex.vmdk"
        if (-not (Test-Path $vmdkPath)) { Add-Log "Chyba: Soubor VMDK neexistuje." "Red"; return }
        $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderBrowser.Description = "Vyberte složku pro zálohu VMDK souboru"
        if ($folderBrowser.ShowDialog() -eq "OK") {
            try {
                Add-Log "Zálohuji VMDK soubor..."
                Copy-Item -Path $vmdkPath -Destination $folderBrowser.SelectedPath -Force -PassThru | Out-Null
                Add-Log "VMDK soubor byl úspěšně zálohován." "Green" "SUCCESS"
            } catch {
                Handle-Error "Chyba při zálohování VMDK souboru." $_
            }
        }
    })
    $vmdkDeleteButton.Add_Click({
        $diskIndex = ($diskBox.SelectedItem.Split(":")[0]).Trim()
        $vmdkPath = "$env:USERPROFILE\RAW_OS_Disk_$diskIndex.vmdk"
        if (-not (Test-Path $vmdkPath)) { Add-Log "Chyba: Soubor VMDK neexistuje." "Red"; return }
        $dialogResult = [System.Windows.Forms.MessageBox]::Show("Opravdu chcete smazat soubor $vmdkPath? Tuto akci nelze vrátit zpět.", "Potvrzení smazání", "YesNo", "Warning")
        if ($dialogResult -eq "Yes") {
            try {
                Add-Log "Mažu VMDK soubor..."
                Remove-Item -Path $vmdkPath -Force -Recurse
                Add-Log "VMDK soubor byl úspěšně smazán." "Green" "SUCCESS"
            } catch {
                Handle-Error "Chyba při mazání VMDK souboru." $_
            }
        }
    })
    
    $yPos += 40
    $vmLabel = New-Object System.Windows.Forms.Label; $vmLabel.Text = "Správa virtuálních strojů:"; $vmLabel.Location = New-Object System.Drawing.Point(20, $yPos); $vmLabel.Size = New-Object System.Drawing.Size(250, 20); $vmLabel.Font = $fontBold; $vmLabel.ForeColor = $labelColor; $vmLabel.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($vmLabel)
    $yPos += 25
    $vmDesc = New-Object System.Windows.Forms.Label; $vmDesc.Text = "Zvolte existující VM nebo nechte pole prázdné pro vytvoření nové."; $vmDesc.Location = New-Object System.Drawing.Point(20, $yPos); $vmDesc.Size = New-Object System.Drawing.Size(580, 20); $vmDesc.Font = $fontNormal; $vmDesc.ForeColor = $labelColor; $vmDesc.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($vmDesc)
    $yPos += 25
    $vmBox = New-Object System.Windows.Forms.ComboBox; $vmBox.Location = New-Object System.Drawing.Point(20, $yPos); $vmBox.Size = New-Object System.Drawing.Size(440, 20); $vmBox.DropDownStyle = "DropDownList"; $panel.Controls.Add($vmBox)
    $vmBox.Add_SelectedIndexChanged({
        if ($vmBox.SelectedItem -ne "Vytvořit novou VM") {
            Add-Log "Varování: Při výběru existující VM se ignorují parametry RAM, CPU a sítě." "Warning"
        }
    })
    $cloneButton = New-Object System.Windows.Forms.Button; $cloneButton.Text = "Klonovat VM"; $cloneButton.Location = New-Object System.Drawing.Point(440, $yPos); $cloneButton.Size = New-Object System.Drawing.Size(150, 25); $cloneButton.BackColor = [System.Drawing.Color]::Yellow; $cloneButton.ForeColor = [System.Drawing.Color]::Black; $panel.Controls.Add($cloneButton)
    $yPos += 40
    $snapshotButton = New-Object System.Windows.Forms.Button; $snapshotButton.Text = "Vytvořit Snapshot"; $snapshotButton.Location = New-Object System.Drawing.Point(440, $yPos); $snapshotButton.Size = New-Object System.Drawing.Size(150, 25); $snapshotButton.BackColor = [System.Drawing.Color]::Yellow; $snapshotButton.ForeColor = [System.Drawing.Color]::Black; $panel.Controls.Add($snapshotButton)
    $yPos += 40
    $openFolderButton = New-Object System.Windows.Forms.Button; $openFolderButton.Text = "Otevřít složku VM"; $openFolderButton.Location = New-Object System.Drawing.Point(440, $yPos); $openFolderButton.Size = New-Object System.Drawing.Size(150, 25); $openFolderButton.BackColor = [System.Drawing.Color]::Yellow; $openFolderButton.ForeColor = [System.Drawing.Color]::Black; $panel.Controls.Add($openFolderButton)
    $cloneButton.Add_Click({
        $vmName = $vmBox.SelectedItem
        if ($vmName -eq "Vytvořit novou VM") { Add-Log "Chyba: Nejprve musíte vybrat existující VM." "Red"; return }
        $cloneName = [Microsoft.VisualBasic.Interaction]::InputBox("Zadejte název klonu:", "Klonovat VM", "$vmName-Clone")
        if (-not $cloneName) { return }
        try {
            Add-Log "Klonuji VM '$vmName' na '$cloneName'..."
            & "$vboxPath" clonevm "$vmName" --name "$cloneName" --register | Out-Null
            Add-Log "VM byla úspěšně naklonována." "Green" "SUCCESS"
        } catch {
            Handle-Error "Chyba při klonování VM." $_
        }
    })
    $snapshotButton.Add_Click({
        $vmName = $vmBox.SelectedItem
        if ($vmName -eq "Vytvořit novou VM") { Add-Log "Chyba: Nejprve musíte vybrat existující VM." "Red"; return }
        $snapshotName = [Microsoft.VisualBasic.Interaction]::InputBox("Zadejte název snapshotu:", "Vytvořit Snapshot", "$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')")
        if (-not $snapshotName) { return }
        try {
            Add-Log "Vytvářím snapshot '$snapshotName' pro VM '$vmName'..."
            & "$vboxPath" snapshot "$vmName" take "$snapshotName" | Out-Null
            Add-Log "Snapshot byl úspěšně vytvořen." "Green" "SUCCESS"
        } catch {
            Handle-Error "Chyba při vytváření snapshotu." $_
        }
    })
    $openFolderButton.Add_Click({
        $vmName = $vmBox.SelectedItem
        if ($vmName -eq "Vytvořit novou VM") { Add-Log "Chyba: Nejprve musíte vybrat existující VM." "Red"; return }
        try {
            $vmInfo = & "$vboxPath" showvminfo "$vmName" --machinereadable
            $vmPath = $vmInfo | Select-String -Pattern '^CfgFile="(.+)"'
            if ($vmPath) {
                $vmFolder = [System.IO.Path]::GetDirectoryName($vmPath.Matches.Groups[1].Value)
                Start-Process $vmFolder
                Add-Log "Složka VM byla úspěšně otevřena." "Green" "SUCCESS"
            } else {
                Add-Log "Nelze najít složku pro vybranou VM." "Red"
            }
        } catch {
            Handle-Error "Chyba při otevírání složky VM." $_
        }
    })

    $yPos += 20
    $totalRamMB = (Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1MB
    $suggestedRam = [math]::Floor($totalRamMB * 0.5 / 512) * 512
    $ramLabel = New-Object System.Windows.Forms.Label; $ramLabel.Text = "RAM (MB):"; $ramLabel.Location = New-Object System.Drawing.Point(20, $yPos); $ramLabel.Size = New-Object System.Drawing.Size(100, 20); $ramLabel.Font = $fontBold; $ramLabel.ForeColor = $labelColor; $ramLabel.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($ramLabel)
    $ramBox = New-Object System.Windows.Forms.NumericUpDown; $ramBox.Location = New-Object System.Drawing.Point(120, $yPos); $ramBox.Minimum = 512; $ramBox.Maximum = 65536; $ramBox.Value = $suggestedRam; $ramBox.Increment = 512; $panel.Controls.Add($ramBox)
    $yPos += 25
    $ramDesc = New-Object System.Windows.Forms.Label; $ramDesc.Text = "Doporučená hodnota je 50 % vaší celkové RAM. (Doporučeno: $suggestedRam MB)"; $ramDesc.Location = New-Object System.Drawing.Point(20, $yPos); $ramDesc.Size = New-Object System.Drawing.Size(580, 20); $ramDesc.Font = $fontNormal; $ramDesc.ForeColor = $labelColor; $ramDesc.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($ramDesc)
    $yPos += 25
    $logicalProcessors = [Environment]::ProcessorCount
    $suggestedCpu = [math]::Floor($logicalProcessors / 2)
    if ($suggestedCpu -eq 0) { $suggestedCpu = 1 }
    $cpuLabel = New-Object System.Windows.Forms.Label; $cpuLabel.Text = "Počet jader CPU:"; $cpuLabel.Location = New-Object System.Drawing.Point(20, $yPos); $cpuLabel.Size = New-Object System.Drawing.Size(120, 20); $cpuLabel.Font = $fontBold; $cpuLabel.ForeColor = $labelColor; $cpuLabel.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($cpuLabel)
    $cpuBox = New-Object System.Windows.Forms.NumericUpDown; $cpuBox.Location = New-Object System.Drawing.Point(120, $yPos); $cpuBox.Minimum = 1; $cpuBox.Maximum = $logicalProcessors; $cpuBox.Value = $suggestedCpu; $panel.Controls.Add($cpuBox)
    $yPos += 25
    $cpuDesc = New-Object System.Windows.Forms.Label; $cpuDesc.Text = "Navrhovaná hodnota je polovina vašich logických jader. (Doporučeno: $suggestedCpu jader)"; $cpuDesc.Location = New-Object System.Drawing.Point(20, $yPos); $cpuDesc.Size = New-Object System.Drawing.Size(580, 20); $cpuDesc.Font = $fontNormal; $cpuDesc.ForeColor = $labelColor; $cpuDesc.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($cpuDesc)

    $yPos += 40
    $networkLabel = New-Object System.Windows.Forms.Label; $networkLabel.Text = "Konfigurace sítě:"; $networkLabel.Location = New-Object System.Drawing.Point(20, $yPos); $networkLabel.Size = New-Object System.Drawing.Size(150, 20); $networkLabel.Font = $fontBold; $networkLabel.ForeColor = $labelColor; $networkLabel.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($networkLabel)
    $yPos += 25
    $networkDesc = New-Object System.Windows.Forms.Label; $networkDesc.Text = "Zvolte typ síťového adaptéru pro VM. NAT je doporučený pro většinu uživatelů."; $networkDesc.Location = New-Object System.Drawing.Point(20, $yPos); $networkDesc.Size = New-Object System.Drawing.Size(580, 20); $networkDesc.Font = $fontNormal; $networkDesc.ForeColor = $labelColor; $networkDesc.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($networkDesc)
    $yPos += 25
    $networkBox = New-Object System.Windows.Forms.ComboBox; $networkBox.Location = New-Object System.Drawing.Point(20, $yPos); $networkBox.Size = New-Object System.Drawing.Size(200, 20); $networkBox.DropDownStyle = "DropDownList"; $networkBox.Items.AddRange(@("NAT", "Bridged Adapter", "Host-Only Adapter")); $networkBox.SelectedIndex = 0; $panel.Controls.Add($networkBox)

    $yPos += 40
    $resLabel = New-Object System.Windows.Forms.Label; $resLabel.Text = "Rozlišení:"; $resLabel.Location = New-Object System.Drawing.Point(20, $yPos); $resLabel.Size = New-Object System.Drawing.Size(100, 20); $resLabel.Font = $fontBold; $resLabel.ForeColor = $labelColor; $resLabel.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($resLabel)
    $resBox = New-Object System.Windows.Forms.ComboBox; $resBox.Location = New-Object System.Drawing.Point(120, $yPos); $resBox.Size = New-Object System.Drawing.Size(150, 20); $resBox.DropDownStyle = "DropDownList"; $resBox.Items.AddRange(@("1024x768", "1280x1024", "1920x1080")); $resBox.SelectedIndex = 1; $panel.Controls.Add($resBox)
    $yPos += 25
    $resDesc = New-Object System.Windows.Forms.Label; $resDesc.Text = "Nastavuje počáteční rozlišení VM. Lze změnit uvnitř."; $resDesc.Location = New-Object System.Drawing.Point(20, $yPos); $resDesc.Size = New-Object System.Drawing.Size(580, 20); $resDesc.Font = $fontNormal; $resDesc.ForeColor = $labelColor; $resDesc.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($resDesc)

    $yPos += 40
    $shareLabel = New-Object System.Windows.Forms.Label; $shareLabel.Text = "Sdílená složka:"; $shareLabel.Location = New-Object System.Drawing.Point(20, $yPos); $shareLabel.Size = New-Object System.Drawing.Size(150, 20); $shareLabel.Font = $fontBold; $shareLabel.ForeColor = $labelColor; $shareLabel.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($shareLabel)
    $yPos += 25
    $shareDesc = New-Object System.Windows.Forms.Label; $shareDesc.Text = "Tato složka bude přístupná ve VM. Ideální pro přenos souborů."; $shareDesc.Location = New-Object System.Drawing.Point(20, $yPos); $shareDesc.Size = New-Object System.Drawing.Size(580, 20); $shareDesc.Font = $fontNormal; $shareDesc.ForeColor = $labelColor; $shareDesc.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($shareDesc)
    $yPos += 25
    $sharePathBox = New-Object System.Windows.Forms.TextBox; $sharePathBox.Location = New-Object System.Drawing.Point(20, $yPos); $sharePathBox.Size = New-Object System.Drawing.Size(320, 20); $sharePathBox.Text = "$env:USERPROFILE\share"; $sharePathBox.ReadOnly = $true; $panel.Controls.Add($sharePathBox)
    $shareBrowseButton = New-Object System.Windows.Forms.Button; $shareBrowseButton.Text = "Vybrat..."; $shareBrowseButton.Location = New-Object System.Drawing.Point(350, $yPos); $shareBrowseButton.Size = New-Object System.Drawing.Size(110, 25); $shareBrowseButton.BackColor = [System.Drawing.Color]::Yellow; $shareBrowseButton.ForeColor = [System.Drawing.Color]::Black; $panel.Controls.Add($shareBrowseButton)
    $shareBrowseButton.Add_Click({
        $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderBrowser.Description = "Vyberte složku pro sdílení s VM"
        if ($folderBrowser.ShowDialog() -eq "OK") {
            $sharePathBox.Text = $folderBrowser.SelectedPath
        }
    })
    $yPos += 40
    $accel3dBox = New-Object System.Windows.Forms.CheckBox; $accel3dBox.Text = "Povolit 3D akceleraci"; $accel3dBox.Location = New-Object System.Drawing.Point(20, $yPos); $accel3dBox.Size = New-Object System.Drawing.Size(200, 20); $accel3dBox.Checked = $true; $accel3dBox.Font = $fontBold; $accel3dBox.ForeColor = $labelColor; $accel3dBox.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($accel3dBox)
    $yPos += 20
    $accel3dDesc = New-Object System.Windows.Forms.Label; $accel3dDesc.Text = "Zlepšuje grafický výkon v moderních desktopových prostředích."; $accel3dDesc.Location = New-Object System.Drawing.Point(20, $yPos); $accel3dDesc.Size = New-Object System.Drawing.Size(580, 20); $accel3dDesc.Font = $fontNormal; $accel3dDesc.ForeColor = $labelColor; $accel3dDesc.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($accel3dDesc)
    
    $yPos += 40
    $startButton = New-Object System.Windows.Forms.Button; $startButton.Text = "Spustit VM"; $startButton.Location = New-Object System.Drawing.Point(20, $yPos); $startButton.Size = New-Object System.Drawing.Size(120, 40); $startButton.BackColor = [System.Drawing.Color]::Yellow; $startButton.ForeColor = [System.Drawing.Color]::Black; $panel.Controls.Add($startButton)
    $closeButton = New-Object System.Windows.Forms.Button; $closeButton.Text = "Zavřít"; $closeButton.Location = New-Object System.Drawing.Point(150, $yPos); $closeButton.Size = New-Object System.Drawing.Size(120, 40); $closeButton.BackColor = [System.Drawing.Color]::Red; $closeButton.ForeColor = [System.Drawing.Color]::White; $panel.Controls.Add($closeButton)
    $closeButton.Add_Click({
        $form.Close()
    })
    
    $yPos += 60
    $statusLabel = New-Object System.Windows.Forms.Label; $statusLabel.Text = "Připraveno ke spuštění."; $statusLabel.Location = New-Object System.Drawing.Point(20, $yPos); $statusLabel.Size = New-Object System.Drawing.Size(590, 20); $panel.Controls.Add($statusLabel)
    $statusLabel.ForeColor = $labelColor; $statusLabel.BackColor = [System.Drawing.Color]::Transparent;
    $yPos += 20
    $progressBar = New-Object System.Windows.Forms.ProgressBar; $progressBar.Location = New-Object System.Drawing.Point(20, $yPos); $progressBar.Size = New-Object System.Drawing.Size(590, 20); $panel.Controls.Add($progressBar)
    
    $yPos += 30
    $logLabel = New-Object System.Windows.Forms.Label; $logLabel.Text = "Průběh akcí:"; $logLabel.Location = New-Object System.Drawing.Point(20, $yPos); $logLabel.Size = New-Object System.Drawing.Size(100, 20); $logLabel.Font = $fontBold; $logLabel.ForeColor = $labelColor; $logLabel.BackColor = [System.Drawing.Color]::Transparent; $panel.Controls.Add($logLabel)
    $yPos += 20
    $logBox = New-Object System.Windows.Forms.RichTextBox; $logBox.Location = New-Object System.Drawing.Point(20, $yPos); $logBox.Size = New-Object System.Drawing.Size(590, 80); $logBox.Multiline = $true; $logBox.ReadOnly = $true; $panel.Controls.Add($logBox)
    $logBox.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60);
    $logBox.ForeColor = [System.Drawing.Color]::White;

} catch {
    Write-Host "FATÁLNÍ CHYBA: Nepodařilo se vytvořit GUI. Skript bude ukončen." -ForegroundColor Red
    Write-Host "Detail chyby: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Stiskněte Enter pro ukončení"
    exit
}

# (Zbývající kód skriptu pro události a spouštění zůstává beze změny)
# ...
$form.Add_Shown({
    Refresh-VMAndDiskLists
    Add-Log "Čekám na spuštění VM..."
    Load-Config
})

$startButton.Add_Click({
    $startButton.Enabled = $false
    
    $sourceFile = $sourceFileBox.SelectedItem
    $isPhysicalDisk = ($sourceFile -eq "Fyzický disk")
    
    if ($isPhysicalDisk) {
        $diskIndex = ($diskBox.SelectedItem.Split(":")[0]).Trim()
        $vmdkPath = "$env:USERPROFILE\RAW_OS_Disk_$diskIndex.vmdk"
        $vmName = "RAW_OS_VM_$diskIndex"
    } elseif ($sourceFile.EndsWith(".iso", [System.StringComparison]::OrdinalIgnoreCase)) {
        $isoPath = $sourceFile
        $vmName = [System.IO.Path]::GetFileNameWithoutExtension($isoPath) + "-ISO"
    } else {
        $diskIndex = "File"
        $vmdkPath = $sourceFile
        $vmName = [System.IO.Path]::GetFileNameWithoutExtension($sourceFile)
    }

    Save-Config
    Update-Progress 0 "Probíhá inicializace..."

    try {
        if ($isPhysicalDisk) {
            Update-Progress 10 "Kontroluji fyzický disk..."
            Add-Log "Pokouším se detekovat operační systém na disku $diskIndex..."
            $osType = "Linux_64"
            if (Test-Path "\\.\PhysicalDrive$diskIndex\Windows\System32") {
                Add-Log "Detekován operační systém Windows.", "Blue"
                $osType = "Windows_64"
            } else {
                Add-Log "Detekován operační systém Linux.", "Blue"
            }

            Update-Progress 20 "Vytvářím virtuální disk..."
            Add-Log "Kontroluji existenci VMDK souboru: $vmdkPath"
            if (-not (Test-Path $vmdkPath)) {
                & "$vboxPath" internalcommands createrawvmdk -filename "$vmdkPath" -rawdisk "\\.\PhysicalDrive$diskIndex" | Out-Null
                if (-not (Test-Path $vmdkPath)) {
                    throw "Vytvoření VMDK souboru se nezdařilo. Zkontrolujte, zda máte administrátorská práva a disk není používán jiným procesem."
                }
                Add-Log "VMDK soubor byl úspěšně vytvořen." "Green" "SUCCESS"
            } else {
                Add-Log "VMDK soubor již existuje, přeskočuji vytvoření."
            }
        }
        
        Update-Progress 40 "Kontroluji VM..."
        $vmExists = (& "$vboxPath" list vms | Select-String $vmName)
        if (-not $vmExists) {
            Add-Log "VM s tímto názvem neexistuje. Vytvářím nový..."
            & "$vboxPath" createvm --name "$vmName" --register | Out-Null
            Add-Log "VM '$vmName' byl úspěšně vytvořen." "Green" "SUCCESS"
        } else {
            Add-Log "VM '$vmName' již existuje. Budu jej konfigurovat."
        }
        
        Update-Progress 60 "Konfiguruji parametry..."
        $graphicsController = "vmsvga"
        if ($osType -eq "Windows_64") { $graphicsController = "vboxsvga" }
        
        $accel3dValue = "off"
        if ($accel3dBox.Checked) {
             $accel3dValue = "on"
        }
        
        & "$vboxPath" modifyvm "$vmName" --memory $ramBox.Value --cpus $cpuBox.Value --nic1 $networkBox.SelectedItem.ToLower().Replace(" ", "") --vram 128 --accelerate3d $accel3dValue --graphicscontroller $graphicsController | Out-Null
        
        $sataExists = & "$vboxPath" showvminfo "$vmName" --machinereadable | Select-String "SATA"
        if ($sataExists) {
             Add-Log "Kontroler 'SATA' již existuje, odstraňuji ho pro opětovné připojení..." "Yellow"
             & "$vboxPath" storagectl "$vmName" --name "SATA" --remove | Out-Null
        }
        & "$vboxPath" storagectl "$vmName" --name "SATA" --add sata --controller IntelAhci | Out-Null

        if ($isPhysicalDisk -or ($vmdkPath -and -not $vmdkPath.EndsWith(".iso"))) {
             & "$vboxPath" storageattach "$vmName" --storagectl "SATA" --port 0 --device 0 --type hdd --medium "$vmdkPath" | Out-Null
        }
        if ($isoPath) {
             & "$vboxPath" storageattach "$vmName" --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium "$isoPath" | Out-Null
        }

        $sharedFolderExists = & "$vboxPath" showvminfo "$vmName" --machinereadable | Select-String "winshare"
        if ($sharedFolderExists) {
             Add-Log "Sdílená složka 'winshare' již existuje, odstraňuji ji..." "Yellow"
             & "$vboxPath" sharedfolder remove "$vmName" --name "winshare" | Out-Null
        }
        if (-not (Test-Path $sharePathBox.Text)) {
            New-Item -Path $sharePathBox.Text -ItemType Directory -Force | Out-Null
        }
        & "$vboxPath" sharedfolder add "$vmName" --name "winshare" --hostpath "$($sharePathBox.Text)" --automount | Out-Null
        
        Update-Progress 100 "Startuji virtuální stroj..."
        & "$vboxPath" startvm "$vmName" --type gui
        
        Add-Log "VM byla spuštěna." "Green" "SUCCESS"
        [System.Windows.Forms.MessageBox]::Show("VM byla úspěšně spuštěna.", "Hotovo", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    } catch {
        Handle-Error "V procesu spouštění VM došlo k neočekávané chybě." $_
        
        $dialogResult = [System.Windows.Forms.MessageBox]::Show("Virtuální stroj selhal při bootování. Chcete připojit bootovací ISO/DVD a zkusit to znovu?", "Chyba bootování VM", "YesNo", "Warning")
        if ($dialogResult -eq "Yes") {
            $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
            $fileDialog.Title = "Vyberte ISO soubor operačního systému"
            $fileDialog.Filter = "ISO soubory (*.iso)|*.iso|Všechny soubory (*.*)|*.*"
            
            if ($fileDialog.ShowDialog() -eq "OK") {
                $isoPath = $fileDialog.FileName
                Add-Log "Připojuji ISO soubor: $isoPath" "Blue"
                
                & "$vboxPath" storageattach "$vmName" --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium none | Out-Null
                & "$vboxPath" storageattach "$vmName" --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium "$isoPath" | Out-Null
                
                Add-Log "ISO úspěšně připojeno. Restartuji VM..." "Green"
                Update-Progress 0 "Restartuji..."
                & "$vboxPath" startvm "$vmName" --type gui
                Add-Log "VM byla úspěšně restartována s novým ISO." "Green" "SUCCESS"
            } else {
                Add-Log "Žádný ISO soubor nebyl vybrán. Ukončuji..." "Red"
            }
        }
    } finally {
        $startButton.Enabled = $true
        Update-Progress 0 "Připraveno ke spuštění."
    }
})

$linuxScriptContent = @'
#!/bin/bash
if [ -f /var/log/vbox_auto_done ]; then exit 0; fi
LOG="/var/log/vbox_auto_setup.log"
exec > >(tee -i $LOG) 2>&1
echo "Spouštím automatickou instalaci Guest Additions..."
sudo apt update
sudo apt install -y build-essential dkms linux-headers-$(uname -r)
sudo mkdir -p /mnt/vbox_cdrom
sudo mount /dev/cdrom /mnt/vbox_cdrom
sudo /mnt/vbox_cdrom/VBoxLinuxAdditions.run
sudo mkdir -p /mnt/windows_share
sudo usermod -aG vboxsf $(whoami)
grep -q "winshare" /etc/fstab || echo "winshare /mnt/windows_share vboxsf defaults 0 0" | sudo tee -a /etc/fstab
sudo umount /mnt/vbox_cdrom
sudo touch /var/log/vbox_auto_done
echo "Instalace a mount dokončen."
'@
$serviceFileContent = @'
[Unit]
Description=VBox Guest Additions Auto Setup
After=network.target
[Service]
Type=oneshot
ExecStart=/usr/local/bin/vbox_auto_setup.sh
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
'@

$tempPath = [System.IO.Path]::GetTempPath()
Set-Content -Path (Join-Path $tempPath "vbox_auto_setup.sh") -Value $linuxScriptContent
Set-Content -Path (Join-Path $tempPath "vbox_auto_setup.service") -Value $serviceFileContent

[void]$form.ShowDialog()
>>>>>>> 2d437cc2ae07a396d41a3b74e61ac94634aea845
