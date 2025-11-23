<<<<<<< HEAD
Add-Type -AssemblyName PresentationFramework

# Cesta k XAML
$xamlPath = Join-Path $PSScriptRoot 'VMConsoleGUI.xaml'

# Načtení XAML v UTF-8
[xml]$xaml = Get-Content $xamlPath -Raw -Encoding UTF8
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# --- Napojení ovládacích prvků ---
$VmList          = $window.FindName("VmList")
$BtnStart        = $window.FindName("BtnStart")
$BtnStop         = $window.FindName("BtnStop")
$BtnApplyNetwork = $window.FindName("BtnApplyNetwork")
$BtnBackupNow    = $window.FindName("BtnBackupNow")
$CpuUsageBar     = $window.FindName("CpuUsageBar")
$RamUsageBar     = $window.FindName("RamUsageBar")
$ProfileSelector = $window.FindName("ProfileSelector")
$BtnLoadProfile  = $window.FindName("BtnLoadProfile")
$TxtTime         = $window.FindName("TxtTime")
$BtnSchedule     = $window.FindName("BtnSchedule")

# --- Ukázková data ---
$VmList.ItemsSource = @("VM1","VM2","VM3")

# --- Funkce ovládacích prvků ---
$BtnStart.Add_Click({
    if ($VmList.SelectedItem) {
        [System.Windows.MessageBox]::Show("Spouštím $($VmList.SelectedItem)")
    }
})

$BtnStop.Add_Click({
    if ($VmList.SelectedItem) {
        [System.Windows.MessageBox]::Show("Zastavuji $($VmList.SelectedItem)")
    }
})

$BtnApplyNetwork.Add_Click({
    [System.Windows.MessageBox]::Show("IP adresa nastavena na $($window.FindName('TxtIPAddress').Text)")
})

$BtnBackupNow.Add_Click({
    [System.Windows.MessageBox]::Show("Spouštím zálohu…")
})

$BtnLoadProfile.Add_Click({
    $selected = $ProfileSelector.SelectedItem.Content
    [System.Windows.MessageBox]::Show("Načítám profil: $selected")
})

$BtnSchedule.Add_Click({
    [System.Windows.MessageBox]::Show("Úloha naplánována na čas: $($TxtTime.Text)")
})

# --- Zobrazení okna ---
=======
Add-Type -AssemblyName PresentationFramework

# Cesta k XAML
$xamlPath = Join-Path $PSScriptRoot 'VMConsoleGUI.xaml'

# Načtení XAML v UTF-8
[xml]$xaml = Get-Content $xamlPath -Raw -Encoding UTF8
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# --- Napojení ovládacích prvků ---
$VmList          = $window.FindName("VmList")
$BtnStart        = $window.FindName("BtnStart")
$BtnStop         = $window.FindName("BtnStop")
$BtnApplyNetwork = $window.FindName("BtnApplyNetwork")
$BtnBackupNow    = $window.FindName("BtnBackupNow")
$CpuUsageBar     = $window.FindName("CpuUsageBar")
$RamUsageBar     = $window.FindName("RamUsageBar")
$ProfileSelector = $window.FindName("ProfileSelector")
$BtnLoadProfile  = $window.FindName("BtnLoadProfile")
$TxtTime         = $window.FindName("TxtTime")
$BtnSchedule     = $window.FindName("BtnSchedule")

# --- Ukázková data ---
$VmList.ItemsSource = @("VM1","VM2","VM3")

# --- Funkce ovládacích prvků ---
$BtnStart.Add_Click({
    if ($VmList.SelectedItem) {
        [System.Windows.MessageBox]::Show("Spouštím $($VmList.SelectedItem)")
    }
})

$BtnStop.Add_Click({
    if ($VmList.SelectedItem) {
        [System.Windows.MessageBox]::Show("Zastavuji $($VmList.SelectedItem)")
    }
})

$BtnApplyNetwork.Add_Click({
    [System.Windows.MessageBox]::Show("IP adresa nastavena na $($window.FindName('TxtIPAddress').Text)")
})

$BtnBackupNow.Add_Click({
    [System.Windows.MessageBox]::Show("Spouštím zálohu…")
})

$BtnLoadProfile.Add_Click({
    $selected = $ProfileSelector.SelectedItem.Content
    [System.Windows.MessageBox]::Show("Načítám profil: $selected")
})

$BtnSchedule.Add_Click({
    [System.Windows.MessageBox]::Show("Úloha naplánována na čas: $($TxtTime.Text)")
})

# --- Zobrazení okna ---
>>>>>>> 2d437cc2ae07a396d41a3b74e61ac94634aea845
$null = $window.ShowDialog()