<<<<<<< HEAD
#!/bin/bash
# === StarkOS: Vytvoření launcheru run.sh ===

GAME_DIR="$1"
cd "$GAME_DIR" || exit 1

if [[ -f *.cue ]]; then
  cue=$(ls *.cue | head -n1)
  echo -e "#!/bin/bash\npcsxr \"$cue\"" > run.sh
elif [[ -f *.apk ]]; then
  apk=$(ls *.apk | head -n1)
  echo -e "#!/bin/bash\nwaydroid app install \"$apk\"\nwaydroid app launch $(basename "$apk" .apk)" > run.sh
elif [[ -f *.sh && "$GAME_DIR" != *run.sh* ]]; then
  echo -e "#!/bin/bash\nbash *.sh" > run.sh
else
  echo "❗ Neznámý formát v $GAME_DIR – launcher nevytvořen"
  exit 1
fi

chmod +x run.sh
=======
#!/bin/bash
# === StarkOS: Vytvoření launcheru run.sh ===

GAME_DIR="$1"
cd "$GAME_DIR" || exit 1

if [[ -f *.cue ]]; then
  cue=$(ls *.cue | head -n1)
  echo -e "#!/bin/bash\npcsxr \"$cue\"" > run.sh
elif [[ -f *.apk ]]; then
  apk=$(ls *.apk | head -n1)
  echo -e "#!/bin/bash\nwaydroid app install \"$apk\"\nwaydroid app launch $(basename "$apk" .apk)" > run.sh
elif [[ -f *.sh && "$GAME_DIR" != *run.sh* ]]; then
  echo -e "#!/bin/bash\nbash *.sh" > run.sh
else
  echo "❗ Neznámý formát v $GAME_DIR – launcher nevytvořen"
  exit 1
fi

chmod +x run.sh
>>>>>>> 2d437cc2ae07a396d41a3b74e61ac94634aea845
echo "✅ Launcher vytvořen: $GAME_DIR/run.sh"