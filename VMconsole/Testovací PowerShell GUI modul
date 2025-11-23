Add-Type -AssemblyName PresentationFramework

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Testovací modul" Height="300" Width="400">
    <StackPanel Margin="10">
        <TextBlock Text="Test GUI komponent" FontWeight="Bold" FontSize="14"/>
        <Button Name="BtnTestVM" Content="Test VM modul" Margin="0,5"/>
        <Button Name="BtnTestDisk" Content="Test diskového modulu" Margin="0,5"/>
        <Button Name="BtnTestLog" Content="Test logování" Margin="0,5"/>
        <Button Name="BtnTestValidace" Content="Test validace vstupů" Margin="0,5"/>
        <TextBlock Name="TxtStatus" Text="Stav: Čekám na akci..." Margin="10,10,0,0"/>
    </StackPanel>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$BtnTestVM       = $window.FindName("BtnTestVM")
$BtnTestDisk     = $window.FindName("BtnTestDisk")
$BtnTestLog      = $window.FindName("BtnTestLog")
$BtnTestValidace = $window.FindName("BtnTestValidace")
$TxtStatus       = $window.FindName("TxtStatus")

function Test-VMModule {
    try {
        if (Get-Module -ListAvailable -Name Hyper-V) {
            $vms = Get-VM
            $TxtStatus.Text = "VM modul OK: Nalezeno $($vms.Count) VM"
        } else {
            $TxtStatus.Text = "VM modul není dostupný"
        }
    } catch {
        $TxtStatus.Text = "Chyba při testu VM: $_"
    }
}

function Test-DiskModule {
    try {
        $disks = Get-Disk
        $TxtStatus.Text = "Disk modul OK: Nalezeno $($disks.Count) disků"
    } catch {
        $TxtStatus.Text = "Chyba při testu disku: $_"
    }
}

function Test-LogModule {
    try {
        $logPath = "$PSScriptRoot\logs"
        if (-not (Test-Path $logPath)) { New-Item -Path $logPath -ItemType Directory | Out-Null }
        "Test logovací zpráva" | Out-File "$logPath\test.log" -Append
        $TxtStatus.Text = "Logování OK: Zapsáno do test.log"
    } catch {
        $TxtStatus.Text = "Chyba při logování: $_"
    }
}

function Test-Validace {
    try {
        $text = "Příliš žluťoučký kůň úpěl ďábelské ódy"
        if ($text -match '[\u00C0-\u017F]') {
            $TxtStatus.Text = "Validace OK: Diakritika detekována"
        } else {
            $TxtStatus.Text = "Validace selhala: Bez diakritiky"
        }
    } catch {
        $TxtStatus.Text = "Chyba při validaci: $_"
    }
}

$BtnTestVM.Add_Click({ Test-VMModule })
$BtnTestDisk.Add_Click({ Test-DiskModule })
$BtnTestLog.Add_Click({ Test-LogModule })
$BtnTestValidace.Add_Click({ Test-Validace })

$null = $window.ShowDialog()
