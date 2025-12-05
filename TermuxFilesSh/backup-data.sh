#!/bin/bash
# Skript pro zálohu konfigurace a dat

echo "📦 Ultimate Raspberry Pi 5 - Záloha dat"
echo "========================================"

BACKUP_DIR="$HOME/docker-stack/backups"
BACKUP_NAME="backup_$(date +%Y%m%d_%H%M%S)"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

echo "Zálohování do: $BACKUP_PATH"

# Vytvoření zálohovacího adresáře
mkdir -p "$BACKUP_PATH"

# Záloha konfigurace
echo "📋 Záloha konfigurace..."
cp -r ~/docker-stack/config "$BACKUP_PATH/"

# Záloha docker-compose.yml
echo "🐳 Záloha docker-compose.yml..."
cp ~/docker-stack/docker-compose.yml "$BACKUP_PATH/"

# Vytvoření informačního souboru
cat > "$BACKUP_PATH/backup-info.txt" << EOF
Záloha Ultimate Raspberry Pi 5
Datum: $(date)
Verze: $(git describe --tags 2>/dev/null || echo "unknown")
Adresář: $BACKUP_PATH
EOF

echo "✅ Záloha úspěšně vytvořena: $BACKUP_PATH"
echo ""
echo "📊 Velikost zálohy:"
du -sh "$BACKUP_PATH"
