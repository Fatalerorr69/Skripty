<<<<<<< HEAD
#!/bin/bash
set -e

echo "=== Odstranění starého repozitáře Adoptium ==="
sudo rm -f /etc/apt/sources.list.d/adoptium.list

echo "=== Vytvoření adresáře pro GPG klíče ==="
sudo mkdir -p /etc/apt/keyrings

echo "=== Stažení a uložení GPG klíče Adoptium ==="
wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public > /tmp/adoptium-key.asc
sudo gpg --dearmor --yes --output /etc/apt/keyrings/adoptium.gpg /tmp/adoptium-key.asc
rm /tmp/adoptium-key.asc
sudo chmod 644 /etc/apt/keyrings/adoptium.gpg

echo "=== Přidání repozitáře Adoptium pro $(awk -F= '/^VERSION_CODENAME/{print $2}' /etc/os-release) ==="
echo "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb \
$(awk -F= '/^VERSION_CODENAME/{print $2}' /etc/os-release) main" \
  | sudo tee /etc/apt/sources.list.d/adoptium.list

echo "=== Aktualizace seznamu balíků ==="
sudo apt update

echo "=== Instalace Temurin 17 JDK ==="
sudo apt install -y temurin-17-jdk

echo "=== Ověření verze Javy ==="
java -version

echo "✅ Instalace dokončena."
=======
#!/bin/bash
set -e

echo "=== Odstranění starého repozitáře Adoptium ==="
sudo rm -f /etc/apt/sources.list.d/adoptium.list

echo "=== Vytvoření adresáře pro GPG klíče ==="
sudo mkdir -p /etc/apt/keyrings

echo "=== Stažení a uložení GPG klíče Adoptium ==="
wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public > /tmp/adoptium-key.asc
sudo gpg --dearmor --yes --output /etc/apt/keyrings/adoptium.gpg /tmp/adoptium-key.asc
rm /tmp/adoptium-key.asc
sudo chmod 644 /etc/apt/keyrings/adoptium.gpg

echo "=== Přidání repozitáře Adoptium pro $(awk -F= '/^VERSION_CODENAME/{print $2}' /etc/os-release) ==="
echo "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb \
$(awk -F= '/^VERSION_CODENAME/{print $2}' /etc/os-release) main" \
  | sudo tee /etc/apt/sources.list.d/adoptium.list

echo "=== Aktualizace seznamu balíků ==="
sudo apt update

echo "=== Instalace Temurin 17 JDK ==="
sudo apt install -y temurin-17-jdk

echo "=== Ověření verze Javy ==="
java -version

echo "✅ Instalace dokončena."
>>>>>>> 2d437cc2ae07a396d41a3b74e61ac94634aea845
