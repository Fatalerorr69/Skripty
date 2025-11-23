<<<<<<< HEAD
#!/bin/bash
# === StarkOS: Kontrola BIOS ===

BIOS_DIR="$HOME/HerniRezim/bios"
mkdir -p "$BIOS_DIR"

declare -A bios_files=(
  ["SCPH1001.BIN"]="PSX"
  ["gba_bios.bin"]="GBA"
)

echo "🔎 Kontroluji přítomnost BIOS souborů:"

for file in "${!bios_files[@]}"; do
  if [[ -f "$BIOS_DIR/$file" ]]; then
    echo "✅ ${bios_files[$file]} BIOS nalezen: $file"
  else
    echo "❌ ${bios_files[$file]} BIOS chybí: $file"
  fi
=======
#!/bin/bash
# === StarkOS: Kontrola BIOS ===

BIOS_DIR="$HOME/HerniRezim/bios"
mkdir -p "$BIOS_DIR"

declare -A bios_files=(
  ["SCPH1001.BIN"]="PSX"
  ["gba_bios.bin"]="GBA"
)

echo "🔎 Kontroluji přítomnost BIOS souborů:"

for file in "${!bios_files[@]}"; do
  if [[ -f "$BIOS_DIR/$file" ]]; then
    echo "✅ ${bios_files[$file]} BIOS nalezen: $file"
  else
    echo "❌ ${bios_files[$file]} BIOS chybí: $file"
  fi
>>>>>>> 2d437cc2ae07a396d41a3b74e61ac94634aea845
done