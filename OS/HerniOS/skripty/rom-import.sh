<<<<<<< HEAD
#!/bin/bash
# === StarkOS: Automatický import ROM ===
# Detekuje typ souboru a přesune do příslušné složky

DEST="$HOME/HerniRezim/roms"
IMPORT_DIR="$HOME/Downloads/rom-import"

mkdir -p "$IMPORT_DIR"
cd "$IMPORT_DIR"

for file in *; do
  if [[ -f "$file" ]]; then
    ext="${file##*.}"
    name="${file%.*}"
    lower=$(echo "$ext" | tr 'A-Z' 'a-z')

    case "$lower" in
      bin|cue|iso)
        echo "🧠 Detekováno: PSX - $file"
        mkdir -p "$DEST/psx/$name"
        mv "$file" "$DEST/psx/$name/"
        ;;
      zip|7z|rar)
        echo "📦 Archiv – ruční kontrola: $file"
        ;;
      apk)
        echo "🤖 Detekováno: Android - $file"
        mkdir -p "$DEST/android/$name"
        mv "$file" "$DEST/android/$name/"
        ;;
      sh)
        echo "🖥️ Detekováno: PC hra - $file"
        mkdir -p "$DEST/pc/$name"
        mv "$file" "$DEST/pc/$name/"
        ;;
      *)
        echo "❓ Neznámý typ: $file"
        ;;
    esac
  fi
done

=======
#!/bin/bash
# === StarkOS: Automatický import ROM ===
# Detekuje typ souboru a přesune do příslušné složky

DEST="$HOME/HerniRezim/roms"
IMPORT_DIR="$HOME/Downloads/rom-import"

mkdir -p "$IMPORT_DIR"
cd "$IMPORT_DIR"

for file in *; do
  if [[ -f "$file" ]]; then
    ext="${file##*.}"
    name="${file%.*}"
    lower=$(echo "$ext" | tr 'A-Z' 'a-z')

    case "$lower" in
      bin|cue|iso)
        echo "🧠 Detekováno: PSX - $file"
        mkdir -p "$DEST/psx/$name"
        mv "$file" "$DEST/psx/$name/"
        ;;
      zip|7z|rar)
        echo "📦 Archiv – ruční kontrola: $file"
        ;;
      apk)
        echo "🤖 Detekováno: Android - $file"
        mkdir -p "$DEST/android/$name"
        mv "$file" "$DEST/android/$name/"
        ;;
      sh)
        echo "🖥️ Detekováno: PC hra - $file"
        mkdir -p "$DEST/pc/$name"
        mv "$file" "$DEST/pc/$name/"
        ;;
      *)
        echo "❓ Neznámý typ: $file"
        ;;
    esac
  fi
done

>>>>>>> 2d437cc2ae07a396d41a3b74e61ac94634aea845
echo "✅ Import dokončen."