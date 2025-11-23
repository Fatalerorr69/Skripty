#!/bin/bash
mkdir -p ~/gamepad_profiles

cat > ~/gamepad_profiles/pg9157_keyboard.amgp << 'EOF'
{
  "version": 2,
  "controller": "Gamepad",
  "mappings": {
    "0": { "keys": ["ENTER"] },
    "1": { "keys": ["ESC"] },
    "2": { "keys": ["C", "LCTRL"] },
    "3": { "keys": ["V", "LCTRL"] },
    "6": { "keys": ["TAB"] },
    "7": { "keys": ["LALT", "TAB"] },
    "11": { "keys": ["UP"] },
    "12": { "keys": ["DOWN"] },
    "13": { "keys": ["LEFT"] },
    "14": { "keys": ["RIGHT"] }
  }
}
EOF

pkill antimicrox 2>/dev/null
antimicrox --profile ~/gamepad_profiles/pg9157_keyboard.amgp --hidden &