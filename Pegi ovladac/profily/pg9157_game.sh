#!/bin/bash
mkdir -p ~/gamepad_profiles

cat > ~/gamepad_profiles/pg9157_game.amgp << 'EOF'
{
  "version": 2,
  "controller": "Gamepad",
  "mappings": {
    "0": { "keys": ["SPACE"] },
    "1": { "keys": ["LCTRL"] },
    "2": { "keys": ["R"] },
    "3": { "keys": ["E"] },
    "4": { "keys": ["Q"] },
    "5": { "keys": ["F"] },
    "6": { "keys": ["1"] },
    "7": { "keys": ["2"] },
    "11": { "keys": ["W"] },
    "12": { "keys": ["S"] },
    "13": { "keys": ["A"] },
    "14": { "keys": ["D"] }
  }
}
EOF

pkill antimicrox 2>/dev/null
antimicrox --profile ~/gamepad_profiles/pg9157_game.amgp --hidden &