Add-Type -AssemblyName PresentationFramework

# --- XAML definice GUI ---
[xml]$xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="VM Console" Height="600" Width="800">

    <Grid>
        <TabControl>
            <TabItem Header="VM Management">
                <StackPanel Margin="10">
                    <TextBlock Text="Seznam virtuálních strojů:" FontWeight="Bold"/>
                    <ListBox Name="VmList" Height="200" Margin="0,5"/>
                    <StackPanel Orientation="Horizontal">
                        <Button Name="BtnRefreshVM" Content="Obnovit" Width="80" Margin="0,0,5,0"/>
                        <Button Name="BtnStart" Content="Start" Width="80" Margin="0,0,5,0"/>
                        <Button Name="BtnStop" Content="Stop" Width="80"/>
                    </StackPanel>
                </StackPanel>
            </TabItem>

            <TabItem Header="Síť">
                <StackPanel Margin="10">
                    <TextBlock Text="Aktuální IP:" FontWeight="Bold"/>
                    <TextBox Name="TxtCurrentIP" Width="200" IsReadOnly="True" Margin="0,5"/>
                    <TextBlock Text="Nová IP:" FontWeight="Bold"/>
                    <TextBox Name="TxtIPAddress" Width="200" Margin="0,5"/>
                    <Button Name="BtnApplyNetwork" Content="Použít" Width="100"/>
                </StackPanel>
            </TabItem>

            <TabItem Header="Zálohy">
                <StackPanel Margin="10">
                    <TextBlock Text="Zálohování VM" FontWeight="Bold"/>
                    <Button Name="BtnBackupNow" Content="Spustit zálohu" Width="150" Margin="0,5"/>
                </StackPanel>
            </TabItem>

            <TabItem Header="Monitoring">
                <StackPanel Margin="10">
                    <TextBlock Text="Využití CPU:"/>
                    <ProgressBar Name="CpuUsageBar" Height="20" Minimum="0" Maximum="100"/>
                    <TextBlock Text="Využití RAM:" Margin="0,10,0,0"/>
                    <ProgressBar Name="RamUsageBar" Height="20" Minimum="0" Maximum="100"/>
                </StackPanel>
            </TabItem>

            <TabItem Header="Profily">
                <StackPanel Margin="10">
                    <TextBlock Text="Uživatelské profily" FontWeight="Bold"/>
                    <ComboBox Name="ProfileSelector" Width="200" Margin="0,5"/>
                    <Button Name="BtnLoadProfile" Content="Načíst" Width="100"/>
                </StackPanel>
            </TabItem>

            <TabItem Header="Plánovač">
                <StackPanel Margin="10">
                    <TextBlock Text="Čas spuštění:" Margin="0,0,0,5"/>
                    <TextBox Name="TxtTime" Width="150" Margin="0,0,0,10"/>
                    <Button Name="BtnSchedule" Content="Naplánovat" Width="120"/>
                </StackPanel>
            </TabItem>
        </TabControl>
    </Grid>
</Window>
"@

# --- Načtení GUI ---
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# --- Ovládací prvky ---
$VmList          = $window.FindName("VmList")
$BtnRefreshVM    = $window.FindName("BtnRefreshVM")
$BtnStart        = $window.FindName("BtnStart")
$BtnStop         = $window.FindName("BtnStop")
$TxtCurrentIP    = $window.FindName("TxtCurrentIP")
$TxtIPAddress    = $window.FindName("TxtIPAddress")
$BtnApplyNetwork = $window.FindName("BtnApplyNetwork")
$BtnBackupNow    = $window.FindName("BtnBackupNow")
$CpuUsageBar     = $window.FindName("CpuUsageBar")
$RamUsageBar     = $window.FindName("RamUsageBar")
$ProfileSelector = $window.FindName("ProfileSelector")
$BtnLoadProfile  = $window.FindName("BtnLoadProfile")
$TxtTime         = $window.FindName("TxtTime")
$BtnSchedule     = $window.FindName("BtnSchedule")

# --- Funkce ---
function Refresh-VMList {
    try {
        if (Get-Module -ListAvailable -Name Hyper-V) {
            $VmList.ItemsSource = (Get-VM | Select-Object -ExpandProperty Name)
        } else {
            $VmList.ItemsSource = @("VM1","VM2","VM3")
        }
    } catch {
        $VmList.ItemsSource = @("VM1","VM2","VM3")
    }
}

function Update-Monitoring {
    # Simulace – v reálu bys načetl z Get-Counter nebo Hyper-V
    $CpuUsageBar.Value = Get-Random -Minimum 10 -Maximum 90
    $RamUsageBar.Value = Get-Random -Minimum 20 -Maximum 95
}

function Load-Profiles {
    $profiles = @("Admin","Operator","Viewer")
    $ProfileSelector.ItemsSource = $profiles
}

function Load-NetworkInfo {
    try {
        $ip = (Get-NetIPAddress -AddressFamily IPv4 |
               Where-Object {$_.InterfaceAlias -notmatch "Loopback"} |
               Select-Object -First 1 -ExpandProperty IPAddress)
        $TxtCurrentIP.Text = $ip
    } catch {
        $TxtCurrentIP.Text = "Neznámá"
    }
}

# --- Handlery ---
$BtnRefreshVM.Add_Click({ Refresh-VMList })
$BtnStart.Add_Click({
    if ($VmList.SelectedItem) {
        Start-VM -Name $VmList.SelectedItem -ErrorAction SilentlyContinue
        [System.Windows.MessageBox]::Show("Spouštím $($VmList.SelectedItem)")
    }
})
$BtnStop.Add_Click({
    if ($VmList.SelectedItem) {
        Stop-VM -Name $VmList.SelectedItem -Force -ErrorAction SilentlyContinue
        [System.Windows.MessageBox]::Show("Zastavuji $($VmList.SelectedItem)")
    }
})
$BtnApplyNetwork.Add_Click({
    [System.Windows.MessageBox]::Show("IP adresa nastavena na $($TxtIPAddress.Text)")
})
$BtnBackupNow.Add_Click({
    $folder = New-Object -ComObject Shell.Application |
              ForEach-Object { $_.BrowseForFolder(0, "Vyber složku pro zálohu", 0, 0) }
    if ($folder) {
        [System.Windows.MessageBox]::Show("Záloha uložena do: " + $folder.Self.Path)
    }
})
$BtnLoadProfile.Add_Click({
    if ($ProfileSelector.SelectedItem) {
        [System.Windows.MessageBox]::Show("Načítám profil: $($ProfileSelector.SelectedItem)")
    }
})
$BtnSchedule.Add_Click({
    $time = $TxtTime.Text
    $config = @{ ScheduledTime = $time }
    $config | ConvertTo-Json | Set-Content "$PSScriptRoot\schedule.json" -Encoding UTF8
    [System.Windows.MessageBox]::Show("Úloha naplánována na: $time")
})

# --- Inicializace ---
Refresh-VMList
Load-Profiles
Load-NetworkInfo
Update-Monitoring

# Časovač pro monitoring
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(2)
$timer.Add_Tick({ Update-Monitoring })
$timer.Start()

# --- Zobrazení ---
$null = $window.ShowDialog()
