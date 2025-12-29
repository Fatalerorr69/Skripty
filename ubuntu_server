#!/bin/bash
# ========================================
# Ubuntu Server Automatická Instalace
# Všechny základní služby, MFA, firewall, zálohy
# ========================================

set -e

# --- Barvy pro výpis ---
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}[*] Začínám automatickou instalaci a konfiguraci Ubuntu Server...${NC}"

# --- 1. Aktualizace systému ---
echo -e "${GREEN}[*] Aktualizuji systém...${NC}"
sudo apt update && sudo apt upgrade -y
sudo apt autoremove -y

# --- 2. Firewall ---
echo -e "${GREEN}[*] Nastavuji firewall...${NC}"
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable

# --- 3. Uživatelé a skupiny ---
echo -e "${GREEN}[*] Konfiguruji uživatele a skupiny...${NC}"
sudo groupadd webadmin || true
sudo usermod -aG webadmin $USER

# --- 4. Instalace služeb ---
echo -e "${GREEN}[*] Instalace základních služeb...${NC}"
sudo apt install -y nginx mariadb-server samba vsftpd netdata docker.io docker-compose
sudo systemctl enable --now nginx mariadb vsftpd netdata docker

# --- 5. MFA pro SSH ---
echo -e "${GREEN}[*] Instalace a konfigurace MFA (Google Authenticator)...${NC}"
sudo apt install -y libpam-google-authenticator
google-authenticator -t -d -f -r 3 -R 30 -w 3

# PAM konfigurace
echo "auth required pam_google_authenticator.so" | sudo tee -a /etc/pam.d/sshd
sudo sed -i 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart sshd

# --- 6. Automatické zálohy ---
echo -e "${GREEN}[*] Nastavuji automatické zálohy...${NC}"
mkdir -p /opt/ubuntu-setup/backups
echo "0 2 * * * root tar -czf /opt/ubuntu-setup/backups/etc_backup_\$(date +\%F).tar.gz /etc" | sudo tee /etc/cron.d/etc-backup

# --- 7. Dokončení ---
echo -e "${GREEN}[*] Instalace a konfigurace dokončena!${NC}"
echo -e "${GREEN}[*] Stav služeb:${NC}"
sudo systemctl status nginx mariadb vsftpd netdata docker --no-pager

echo -e "${GREEN}[*] Firewall:${NC}"
sudo ufw status

echo -e "${GREEN}[*] Zálohy budou ukládány do /opt/ubuntu-setup/backups${NC}"
echo -e "${GREEN}[*] Přihlaste se přes SSH a ověřte MFA přihlášení.${NC}"
