# =========================================================================
# Soubor: Installer.ps1
# Popis: Instalační skript pro VirtualBox RAW OS Launcher
# Verze: 6.0
# =========================================================================

# -------------------------------------------------------------------------
# 1. Kontrola oprávnění a závislostí
# -------------------------------------------------------------------------

Write-Host "Kontroluji oprávnění a závislosti..." -ForegroundColor Yellow

# Zkontrolovat, zda je skript spuštěn jako administrátor
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Chyba: Skript musí být spuštěn s administrátorskými právy." -ForegroundColor Red
    Read-Host "Stiskněte Enter pro ukončení"
    exit
}

# Zkontrolovat, zda je nainstalovaný VirtualBox
$vboxPath = (Get-Item "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" -ErrorAction SilentlyContinue).FullName
if (-not $vboxPath) {
    Write-Host "Chyba: VirtualBox (VBoxManage.exe) nebyl nalezen. Ujistěte se, že je nainstalován." -ForegroundColor Red
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $dialogResult = [System.Windows.Forms.MessageBox]::Show("VirtualBox nebyl nalezen. Chcete otevřít stránku pro stažení?", "Chyba", "YesNo", "Error")
        if ($dialogResult -eq [System.Windows.Forms.DialogResult]::Yes) {
            Start-Process "https://www.virtualbox.org/wiki/Downloads"
        }
    } catch {
        Write-Host "Nelze zobrazit dialog. Otevřete prohlížeč a stáhněte VirtualBox z https://www.virtualbox.org/wiki/Downloads" -ForegroundColor Cyan
    }
    Read-Host "Stiskněte Enter pro ukončení"
    exit
}
Write-Host "Kontrola dokončena. VirtualBox nalezen." -ForegroundColor Green

# -------------------------------------------------------------------------
# 2. Vytvoření souborů projektu a manuálu
# -------------------------------------------------------------------------

Write-Host "Vytvářím soubory projektu..." -ForegroundColor Yellow

# Získání cesty ke skriptu
$scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition

# Vytvoření složek
$dataDir = "$scriptPath\_data"
$resourcesDir = "$scriptPath\_resources"
$updatesDir = "$scriptPath\_updates"

if (-not (Test-Path $dataDir)) { New-Item -ItemType Directory -Path $dataDir | Out-Null }
if (-not (Test-Path $resourcesDir)) { New-Item -ItemType Directory -Path $resourcesDir | Out-Null }
if (-not (Test-Path $updatesDir)) { New-Item -ItemType Directory -Path $updatesDir | Out-Null }

Write-Host "Struktura složek vytvořena." -ForegroundColor Green

# Vytvoření souboru Manual.md (manuál)
$manualPath = "$scriptPath\_resources\Manual.md"
$manualContent = @'
# Uživatelský manuál: VirtualBox RAW OS Launcher
*Verze: 6.0*

Tento nástroj vám umožní jednoduše spouštět operační systémy, nainstalované na fyzických discích, v prostředí virtuálního stroje (VM) VirtualBox. Můžete také použít existující virtuální disky nebo ISO soubory.

### 1. Spuštění projektu
1.  Ujistěte se, že máte nainstalovaný VirtualBox.
2.  Spusťte soubor `Installer.ps1` s **administrátorskými právy** (pravé tlačítko myši -> Spustit jako administrátor).
3.  Instalační skript automaticky vytvoří potřebnou strukturu složek (`_data`, `_resources`, `_updates`) a uloží do nich všechny soubory.
4.  Po dokončení se automaticky spustí hlavní aplikace s grafickým rozhraním.

### 2. Práce s grafickým rozhraním
* **Vyberte zdroj pro VM:** Zvolte, zda chcete použít fyzický disk nebo existující virtuální soubor (`.vmdk`, `.vdi`, `.iso` atd.).
* **Vyberte fyzický disk:** (Pouze pokud zvolíte "Fyzický disk"). Zvolte disk, který chcete spustit. Bude pro něj vytvořeno virtuální zrcadlo (`.vmdk`), které se použije pro spuštění VM.
* **Správa VMDK disku:**
    * **Zálohovat VMDK:** Umožní vám zkopírovat vytvořené virtuální zrcadlo na jiné místo.
    * **Smazat VMDK:** Trvale smaže virtuální zrcadlo. Buďte opatrní!
* **Správa virtuálních strojů:** Můžete buď **Vytvořit novou VM** nebo použít existující.
* **Parametry VM:** Pokud vytváříte novou VM, nastavte si počet **RAM**, **CPU**, **síťový adaptér** a **rozlišení**.
* **Sdílená složka:** Zvolte složku, kterou chcete sdílet mezi hostitelem a VM. V Linuxu bude dostupná jako `/mnt/windows_share`. Pro Windows VM je nutné ji namapovat ručně.
* **3D akcelerace:** Povoluje 3D grafiku. Může zlepšit výkon grafických aplikací, ale může také způsobit nestabilitu.
* **Log:** V dolní části okna vidíte podrobný log o průběhu operací.

### 3. Automatická instalace doplňků pro Linux (Guest Additions)
Pokud spouštíte Linux, virtuální CD s Guest Additions je automaticky připojeno. K dokončení instalace doplňků a nastavení sdílených složek je nutné spustit přiložený skript `linux-auto-install.sh`. Můžete ho nalézt ve složce projektu.

Pro jeho spuštění uvnitř Linux VM:
1.  Otevřete terminál.
2.  Spusťte příkaz: `sudo /mnt/vbox_cdrom/VBoxLinuxAdditions.run`
3.  Pro zjednodušení můžete také skript přetáhnout do terminálu a spustit ho s `sudo`.
'@

Set-Content -Path $manualPath -Value $manualContent -Encoding UTF8

Write-Host "Soubory projektu vytvořeny." -ForegroundColor Green

# -------------------------------------------------------------------------
# 3. Spuštění hlavní aplikace
# -------------------------------------------------------------------------

Write-Host "Spouštím hlavní aplikaci..." -ForegroundColor Green

# Získání cesty k hlavnímu skriptu
$mainScriptPath = "$scriptPath\SpustitVM-v6.ps1" 
if (-not (Test-Path $mainScriptPath)) {
    Write-Host "Chyba: Hlavní skript ($mainScriptPath) nebyl nalezen." -ForegroundColor Red
    Read-Host "Stiskněte Enter pro ukončení"
    exit
}

# Spuštění hlavní aplikace v novém okně PowerShellu
Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$mainScriptPath`"" -Wait

Write-Host "Instalace a spuštění dokončeno." -ForegroundColor Green
