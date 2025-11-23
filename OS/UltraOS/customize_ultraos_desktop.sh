#!/usr/bin/env bash
# customize_ultraos_desktop.sh
# Skript pro automatickou úpravu plochy UltraOS (témata, ikony, pozadí, dock, kompozitor)
# Měl by být spuštěn UŽIVATELEM (např. pi), NE jako root, a IDEÁLNĚ V GRAFICKÉM PROSTŘEDÍ.

set -euo pipefail

# ─── Barvy ─────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ─── Proměnné ──────────────────────────────────────────────────────────
WALLPAPER_URL="http://googleusercontent.com/image_generation_content/0"
WALLPAPER_FILENAME="ultraos_wallpaper.png"
WALLPAPER_DIR="${HOME}/.local/share/backgrounds" # Doporučené místo pro uživatelská pozadí
LOG_FILE="${HOME}/customize_ultraos_desktop.log"

# --- Funkce pro logování ---
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[VAROVÁNÍ]${NC} $1" | tee -a "$LOG_FILE" >&2
}

log_error() {
    echo -e "${RED}[CHYBA]${NC} $1" | tee -a "$LOG_FILE" >&2
    exit 1
}

# --- Kontrola uživatele ---
if [ "$EUID" -eq 0 ]; then
  log_warn "Skript je spuštěn jako root. Pro úpravy plochy se doporučuje spustit ho jako běžný uživatel (např. 'pi'). Pokračuji, ale nastavení nemusí být aplikována na aktuální uživatelskou plochu."
  sleep 3
fi

log_info "Spouštím skript pro přizpůsobení plochy UltraOS…"

# ─── 1. Instalace potřebných balíčků pro GUI úpravy ─────────────────────
log_info "Instaluji nástroje pro úpravy GUI (wget, feh, papirus-icon-theme, plank, picom)…"
# feh - pro nastavení pozadí, pokud pcmanfm nefunguje konzistentně
# papirus-icon-theme - populární sada ikon
# lxappearance - GUI nástroj pro vzhled (už je většinou v RPi OS)
# plank - minimalistický dock
# picom - kompozitor pro vizuální efekty (průhlednost, stíny)
sudo apt update || log_warn "Nepodařilo se aktualizovat apt. Může to ovlivnit instalaci balíčků."
sudo apt install -y wget feh papirus-icon-theme plank picom || log_warn "Nepodařilo se nainstalovat všechny balíčky pro GUI úpravy. Pokračuji bez nich."

# ─── 2. Nastavení pozadí plochy "UltraOS" ──────────────────────────────
log_info "Stahuji a nastavuji pozadí plochy 'UltraOS'…"
mkdir -p "$WALLPAPER_DIR" || log_error "Nepodařilo se vytvořit adresář pro pozadí: $WALLPAPER_DIR"

if wget -O "$WALLPAPER_DIR/$WALLPAPER_FILENAME" "$WALLPAPER_URL"; then
    log_info "Pozadí staženo do: $WALLPAPER_DIR/$WALLPAPER_FILENAME"

    # Pokus o nastavení pozadí pro LXDE/LXQt (PCManFM)
    # Zde se předpokládá, že uživatel je v grafickém prostředí a má PCManFM (výchozí správce souborů RPi OS)
    # Tato metoda nemusí fungovat vždy spolehlivě z CLI skriptu, pokud GUI není plně spuštěno
    if command -v pcmanfm &>/dev/null; then
        pcmanfm --set-wallpaper="$WALLPAPER_DIR/$WALLPAPER_FILENAME" --wallpaper-mode=fit || \
        log_warn "Nepodařilo se nastavit pozadí přes pcmanfm. Zkuste to ručně, nebo restartujte GUI."
    elif command -v feh &>/dev/null; then
        # feh je spolehlivější pro nastavení pozadí z skriptu
        feh --bg-fill "$WALLPAPER_DIR/$WALLPAPER_FILENAME" || \
        log_warn "Nepodařilo se nastavit pozadí přes feh. Zkuste to ručně."
    else
        log_warn "Ani pcmanfm ani feh nebyly nalezeny pro automatické nastavení pozadí."
    fi
    log_info "Pozadí 'UltraOS' by mělo být nastaveno. Možná bude potřeba restartovat GUI nebo se odhlásit/přihlásit."
else
    log_warn "Nepodařilo se stáhnout pozadí z URL: $WALLPAPER_URL"
fi

# ─── 3. Nastavení témat a ikon ──────────────────────────────────────────
# Toto jsou konfigurační soubory pro LXAppearance/GTK.
# Změny se projeví až po restartu session nebo manuálním nastavení přes GUI.

log_info "Nastavuji témata GTK a ikony (Papirus)…"

# Nastavení GTK2 témat
mkdir -p "${HOME}/.gtkrc-2.0"
cat > "${HOME}/.gtkrc-2.0" << EOF
gtk-theme-name="Adwaita" # Nebo "PiXflat", "Arc" pokud je nainstalováno
gtk-icon-theme-name="Papirus"
gtk-font-name="Roboto 10" # Pokud je nainstalováno
EOF

# Nastavení GTK3 témat (pro novější aplikace)
mkdir -p "${HOME}/.config/gtk-3.0"
cat > "${HOME}/.config/gtk-3.0/settings.ini" << EOF
[Settings]
gtk-theme-name=Adwaita # Můžete zkusit "Arc-Dark" nebo "Nordic"
gtk-icon-theme-name=Papirus
gtk-font-name=Roboto 10
EOF

# Nastavení pro LXDE (jeho vlastní konfigurační soubor)
LXDE_CONFIG_FILE="${HOME}/.config/lxsession/LXDE-pi/desktop.conf"
if [ -f "$LXDE_CONFIG_FILE" ]; then
    log_info "Upravuji konfigurační soubor LXDE desktopu: $LXDE_CONFIG_FILE"
    sed -i 's/^wallpaper=.*/wallpaper='"$WALLPAPER_DIR\/$WALLPAPER_FILENAME"'/g' "$LXDE_CONFIG_FILE"
    sed -i 's/^wallpaper_mode=.*/wallpaper_mode=1/g' "$LXDE_CONFIG_FILE" # 1 = Fit
    # Témata LXDE jsou často řízena přes GTK nastavení nebo přímo v panelu
else
    log_warn "Konfigurační soubor LXDE desktopu nebyl nalezen: $LXDE_CONFIG_FILE. Některá nastavení nemusí být aplikována."
fi

# ─── 4. Instalace a konfigurace Plank Docku ────────────────────────────
log_info "Nastavuji Plank Dock…"
# Přidání Planku do autostartu
mkdir -p "${HOME}/.config/autostart"
cat > "${HOME}/.config/autostart/plank.desktop" << EOF
[Desktop Entry]
Type=Application
Exec=plank
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Plank
Comment=Lightweight dock
EOF

log_info "Plank by se měl spustit automaticky po příštím přihlášení. Můžete ho spustit ručně příkazem 'plank'."

# ─── 5. Instalace a konfigurace Picom Kompozitoru ──────────────────────
log_info "Nastavuji Picom Kompozitor pro vizuální efekty…"
# Konfigurace Picomu (minimalistická, pro základní efekty)
mkdir -p "${HOME}/.config/picom"
cat > "${HOME}/.config/picom/picom.conf" << EOF
backend = "glx"; # Může být i "xrender" pro starší hardware
vsync = true;
shadow = true;
shadow-radius = 7;
shadow-opacity = 0.75;
shadow-offset-x = -7;
shadow-offset-y = -7;
fading = true;
fade-delta = 4;
fade-in-step = 0.03;
fade-out-step = 0.03;
opacity-rule = [
  "80:class_g = 'Alacritty'" # Příklad: průhlednost pro Alacritty terminál
];
EOF

# Přidání Picomu do autostartu
cat > "${HOME}/.config/autostart/picom.desktop" << EOF
[Desktop Entry]
Type=Application
Exec=picom --config ~/.config/picom/picom.conf
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Picom
Comment=A lightweight compositor
EOF

log_info "Picom by se měl spustit automaticky po příštím přihlášení. Můžete ho spustit ručně příkazem 'picom --config ~/.config/picom/picom.conf'."

# ─── Závěr ─────────────────────────────────────────────────────────────
log_info "${GREEN}Skript pro přizpůsobení plochy UltraOS dokončen!${NC}"
echo -e "${YELLOW}
Většina změn se projeví po odhlášení a opětovném přihlášení, nebo po restartu Raspberry Pi.
Některá nastavení (např. přesný font, nebo specifické chování panelů) možná bude nutné doladit manuálně v 'Appearance Settings' (Nastavení vzhledu) nebo v nastavení Plank/Picom.

Užijte si svůj nový, originální a efektivní UltraOS desktop!
${NC}"