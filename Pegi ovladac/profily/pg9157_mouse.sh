#!/bin/bash
mkdir -p ~/gamepad_profiles

cat > ~/gamepad_profiles/pg9157_mouse.amgp << 'EOF'
{
  "version": 2,
  "controller": "Gamepad",
  "stickConfigs": {
    "0": {
      "xAxis": { "mouse": true },
      "yAxis": { "mouse": true }
    }
  },
  "mappings": {
    "0": { "click": 1 },
    "1": { "click": 3 },
    "4": { "scroll": -1 },
    "5": { "scroll": 1 }
  }
}
EOF

pkill antimicrox 2>/dev/null
antimicrox --profile ~/gamepad_profiles/pg9157_mouse.amgp --hidden &