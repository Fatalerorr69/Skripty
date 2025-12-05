#!/data/data/com.termux/files/usr/bin/bash
# ============================================
# Termux: Automatické AI opravy + GitHub upload
# ============================================

set -e

# --- Kontrola argumentů ---
ZIPFILE=$1
if [ -z "$ZIPFILE" ]; then
  echo "❌ Použití: $0 mujprojekt.zip"
  exit 1
fi

# --- Nastavení pracovního adresáře ---
WORKDIR="workdir_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$WORKDIR/src"
mkdir -p "$WORKDIR/backup"

echo "📦 Rozbaluji ZIP..."
unzip -q "$ZIPFILE" -d "$WORKDIR/src"

# --- Instalace Git a jq ---
pkg update -y && pkg upgrade -y
pkg install -y git jq unzip zip

# --- Nastavení GitHub uživatele ---
read -p "GitHub uživatelské jméno: " GHUSER
read -p "GitHub e-mail: " GHEMAIL
git config --global user.name "$GHUSER"
git config --global user.email "$GHEMAIL"

read -p "GitHub Personal Access Token (ghp_...): " GHTOKEN
git config --global credential.helper store
echo "https://$GHUSER:$GHTOKEN@github.com" > $HOME/.git-credentials
chmod 600 $HOME/.git-credentials

# --- AI oprava souborů ---
FILES=$(find "$WORKDIR/src" -type f \( -name "*.sh" -o -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.html" -o -name "*.css" -o -name "*.txt" \))

for file in $FILES; do
  echo "🔍 Zpracovávám: $file"
  cp "$file" "$WORKDIR/backup/"

  CONTENT=$(cat "$file")

  if [ -n "$OPENAI_API_KEY" ]; then
    RESPONSE=$(curl -s https://api.openai.com/v1/chat/completions \
      -H "Authorization: Bearer $OPENAI_API_KEY" \
      -H "Content-Type: application/json" \
      -d "{
        \"model\": \"gpt-4.1-mini\",
        \"messages\": [
          {\"role\": \"system\", \"content\": \"Jsi zkušený programátor. Oprav chyby, optimalizuj výkon, přidej komentáře a zachovej funkčnost.\"},
          {\"role\": \"user\", \"content\": \"Oprav a optimalizuj následující soubor:\\n$CONTENT\"}
        ]
      }" | jq -r '.choices[0].message.content')
  else
    RESPONSE=$(curl -s http://localhost:11434/api/generate \
      -H "Content-Type: application/json" \
      -d "{
        \"model\": \"llama3\",
        \"prompt\": \"Oprav a optimalizuj následující soubor. Přidej komentáře a zachovej funkčnost:\\n$CONTENT\"
      }" | jq -r '.response')
  fi

  if [ -n "$RESPONSE" ] && [ "$RESPONSE" != "null" ]; then
    echo "$RESPONSE" > "$file"
    echo "✅ Opraveno: $file"
  else
    echo "⚠️ Nepodařilo se opravit $file"
  fi
done

# --- ZIP opraveného projektu ---
FIXED_ZIP="${ZIPFILE%.zip}_fixed.zip"
cd "$WORKDIR/src" && zip -qr "../../$FIXED_ZIP" . && cd ../..

echo "📦 Upravený ZIP: $FIXED_ZIP"
echo "💾 Zálohy: $WORKDIR/backup"

# --- Git inicializace a push ---
cd "$WORKDIR/src"
git init
git add .
git commit -m "AI oprava a optimalizace projektu"
read -p "GitHub repozitář URL (https://github.com/user/repo.git): " GHREPO
git remote add origin "$GHREPO"
git branch -M main
git push -u origin main

echo "🎉 Hotovo! Projekt je opravený a nahraný na GitHub!"
