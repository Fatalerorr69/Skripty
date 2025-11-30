# 1️⃣ Načtení všech dostupných distribucí WSL
$DistrosRaw = wsl --list --quiet
$Distros = $DistrosRaw | ForEach-Object { $_.Trim() -replace '\0','' } 

if (-not $Distros -or $Distros.Count -eq 0) {
    Write-Error "Nebyla nalezena žádná WSL distribuce!"
    exit
}

# 2️⃣ Vyber distribuční název, např. první v seznamu
$DistroName = $Distros[0]
Write-Host "Používám distribuci: '$DistroName'"

# 3️⃣ Nastavení cest pro home a zálohu
$TargetHome = Join-Path -Path "W:\" -ChildPath "$DistroName\home_starko"
$BackupDir = Join-Path -Path "W:\WSL_Backups" -ChildPath "$DistroName"

# 4️⃣ Vytvoření adresářů, pokud neexistují
foreach ($dir in @($TargetHome, $BackupDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir | Out-Null
        Write-Host "Vytvořen adresář: $dir"
    }
}

# 5️⃣ Testovací export distribuce
$BackupFile = Join-Path -Path $BackupDir -ChildPath "$DistroName_$(Get-Date -Format 'yyyyMMdd_HHmmss').tar"
Write-Host "Export distribuce do souboru: $BackupFile"

wsl --export $DistroName $BackupFile
Write-Host "Export dokončen ✅"
