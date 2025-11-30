# --------------------------------------------
# WSL FÁZE 1 — FULL AUTO PREP v6 + SNAPSHOT/Backup
# Automatická příprava distribucí, uživatel starko, přesun HOME, zálohy
# --------------------------------------------

$DefaultUser = "starko"
$DefaultPass = "1234"
$TargetDrive = "W:"
$BackupRoot = Join-Path $TargetDrive "WSL_Backups"

Write-Host "=== WSL FÁZE 1 — FULL AUTO PREP v6 ===" -ForegroundColor Cyan

# Získat seznam nainstalovaných distribucí
$distros = wsl.exe --list --quiet | Where-Object { $_ -ne "" }

if (-not $distros) {
    Write-Error "Žádné nainstalované distribuce WSL nebyly nalezeny!"
    exit
}

Write-Host "`nNalezené distribuce:"
$distros | ForEach-Object { Write-Host " - $_" }
Write-Host "`n----------------------------------------------"

foreach ($distro in $distros) {

    Write-Host "`nZpracovávám distribuci: $distro" -ForegroundColor Yellow

    # 1️⃣ Kontrola uživatele
    $userCheck = wsl.exe -d $distro -u root -- bash -c "id -u ${DefaultUser} >/dev/null 2>&1 && echo OK || echo NO"
    if ($userCheck -match "NO") {
        Write-Host "→ Uživatelský účet '$DefaultUser' neexistuje. Vytvářím..." -ForegroundColor Green
        wsl.exe -d $distro -u root -- bash -c "useradd -m -s /bin/bash ${DefaultUser} && echo '${DefaultUser}:${DefaultPass}' | chpasswd"
    } else {
        Write-Host "→ Uživatelský účet '$DefaultUser' již existuje." -ForegroundColor Green
    }

    # 2️⃣ Přesun HOME uživatele do W:<distro>\home_<user>
    $TargetRoot = Join-Path $TargetDrive $distro
    $TargetHome = Join-Path $TargetRoot "home_${DefaultUser}"

    if (-not (Test-Path $TargetHome)) {
        Write-Host "→ Vytvářím cílový adresář $TargetHome" -ForegroundColor Cyan
        New-Item -Path $TargetHome -ItemType Directory | Out-Null
    }

    Write-Host "→ Přesouvám HOME uživatele $DefaultUser do $TargetHome" -ForegroundColor Cyan
    try {
        wsl.exe -d $distro -u root -- bash -c "mv /home/${DefaultUser} '${TargetHome//\:/\\:}' || echo 'Adresář /home/${DefaultUser} neexistuje, pokračuji.'"
        wsl.exe -d $distro -u root -- bash -c "ln -s '${TargetHome//\:/\\:}' /home/${DefaultUser}"
    } catch {
        Write-Error "Chyba při přesunu HOME: $_"
    }

    # 3️⃣ Inicializace distribuce
    Write-Host "→ Inicializuji distribuci (update + základní nástroje)" -ForegroundColor Cyan
    wsl.exe -d $distro -u root -- bash -c "apt update && apt upgrade -y; apt install -y curl wget git tar unzip sudo"

    # 4️⃣ Backup / snapshot do tar
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $BackupDir = Join-Path $BackupRoot $distro
    if (-not (Test-Path $BackupDir)) { New-Item -Path $BackupDir -ItemType Directory | Out-Null }
    $BackupFile = Join-Path $BackupDir "${distro}_${timestamp}.tar"

    Write-Host "→ Vytvářím backup distribuce do $BackupFile" -ForegroundColor Magenta
    wsl.exe --export $distro $BackupFile

    Write-Host "----------------------------------------------"
}

# 5️⃣ Globální optimalizace WSL
Write-Host "Aplikuji WSL globální optimalizaci..." -ForegroundColor Cyan
foreach ($distro in $distros) {
    wsl.exe --distribution $distro --status
}

# 6️⃣ Restart WSL
Write-Host "Restartuji WSL..." -ForegroundColor Cyan
wsl.exe --shutdown

Write-Host "=== FÁZE 1 — KOMPLETNĚ HOTOVO ===" -ForegroundColor Green
Write-Host "WSL nyní připraveno pro FÁZI 2 (WebGUI, centrální správa)."
Write-Host "Všechny distribuce jsou zálohované do $BackupRoot"
