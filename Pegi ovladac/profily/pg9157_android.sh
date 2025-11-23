#!/bin/bash
mkdir -p ~/gamepad_profiles

cat > ~/gamepad_profiles/pg9157_android.amgp << 'EOF'
{
  "version": 2,
  "controller": "Gamepad",
  "mappings": {
    "0": { "keys": ["HOME"] },
    "1": { "keys": ["ESC"] },
    "2": { "keys": ["LCTRL", "A"] },
    "3": { "keys": ["LCTRL", "B"] },
    "6": { "keys": ["MENU"] },
    "7": { "keys": ["BACKSPACE"] },
    "11": { "keys": ["UP"] },
    "12": { "keys": ["DOWN"] },
    "13": { "keys": ["LEFT"] },
    "14": { "keys": ["RIGHT"] }
  }
}
EOF

pkill antimicrox 2>/dev/null
antimicrox --profile ~/gamepad_profiles/pg9157_android.amgp --hidden &