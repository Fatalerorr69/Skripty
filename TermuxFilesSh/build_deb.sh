#!/bin/bash
set -e

PKG_NAME="twisteros-supermanager"
VERSION="1.0.0"
ARCH="arm64"

ROOT="$(pwd)"
BUILD_DIR="$ROOT/build"
DEBIAN_DIR="$BUILD_DIR/$PKG_NAME"
INSTALL_DIR="$DEBIAN_DIR/usr"
OPT_DIR="$DEBIAN_DIR/opt/twisteros_supermanager"

echo "======================================================="
echo " TWISTEROS SUPER MANAGER – GENERÁTOR .deb BALÍČKU"
echo "======================================================="

# 1) ČIŠTĚNÍ
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$DEBIAN_DIR/DEBIAN"

echo "[1] Příprava adresářů…"
mkdir -p "$OPT_DIR/api"
mkdir -p "$OPT_DIR/scripts"
mkdir -p "$OPT_DIR/dashboard"
mkdir -p "$INSTALL_DIR/bin"
mkdir -p "$DEBIAN_DIR/etc/systemd/system"

# 2) KOPÍROVÁNÍ PROJEKTU
echo "[2] Kopíruji projekt…"
cp -r api/* "$OPT_DIR/api/"
cp -r scripts/* "$OPT_DIR/scripts/"
cp -r dashboard/* "$OPT_DIR/dashboard/"

# 3) KOPÍROVÁNÍ SYSTEMD SLUŽBY
echo "[3] Kopíruji systemd službu…"
cp debian/supermanager.service "$DEBIAN_DIR/etc/systemd/system/"

# 4) VYTVOŘENÍ SPUŠTĚCÍHO PŘÍKAZU
echo "[4] Vytvářím /usr/bin/supermanager…"
cat << 'EOF' > "$INSTALL_DIR/bin/supermanager"
#!/bin/bash
cd /opt/twisteros_supermanager/api
/usr/bin/python3 app.py
EOF
chmod +x "$INSTALL_DIR/bin/supermanager"

# 5) VYTVOŘENÍ KONTROLNÍHO SOUBORU CONTROL
echo "[5] Generuji debian/control…"
cat << EOF > "$DEBIAN_DIR/DEBIAN/control"
Package: $PKG_NAME
Version: $VERSION
Section: utils
Priority: optional
Architecture: $ARCH
Maintainer: Starko <root@localhost>
Description: TwisterOS SuperManager – API, dashboard, ROM/BIOS/NAS, MHS displej
Depends: python3, python3-flask, python3-pip, rsync, retroarch, systemd
EOF

# 6) POSTINST SKRIPT
echo "[6] Přidávám postinst…"
cat << 'EOF' > "$DEBIAN_DIR/DEBIAN/postinst"
#!/bin/bash
set -e

echo "[SuperManager] Dokončuji instalaci…"
mkdir -p /home/starko/Games/ROMs
mkdir -p /home/starko/Games/BIOS
mkdir -p /home/starko/Games/NAS/ROMs
mkdir -p /home/starko/Games/NAS/BIOS
mkdir -p /home/starko/Games/RetroArch/roms

chown -R starko:starko /home/starko/Games

pip3 install flask flask-cors --break-system-packages || true

if [ -f /opt/twisteros_supermanager/scripts/mhs_detect.sh ]; then
    bash /opt/twisteros_supermanager/scripts/mhs_detect.sh --auto
fi

systemctl daemon-reload
systemctl enable supermanager.service
systemctl restart supermanager.service || true

exit 0
EOF
chmod 755 "$DEBIAN_DIR/DEBIAN/postinst"

# 7) PRERM
echo "[7] Přidávám prerm…"
cat << 'EOF' > "$DEBIAN_DIR/DEBIAN/prerm"
#!/bin/bash
systemctl stop supermanager.service || true
systemctl disable supermanager.service || true
exit 0
EOF
chmod 755 "$DEBIAN_DIR/DEBIAN/prerm"

# 8) PRÁVA
echo "[8] Nastavuji práva…"
chmod -R 755 "$OPT_DIR"
chmod -R 755 "$INSTALL_DIR/bin"

# 9) VYTVOŘENÍ .deb
DEB_FILE="$BUILD_DIR/${PKG_NAME}_${VERSION}_${ARCH}.deb"

echo "[9] Stavím balíček…"
dpkg-deb --build "$DEBIAN_DIR" "$DEB_FILE"

echo "======================================================="
echo " HOTOVO!"
echo " Instalační balíček:"
echo "   $DEB_FILE"
echo "======================================================="
