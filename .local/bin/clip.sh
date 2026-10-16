#!/usr/bin/env bash
DIR="/home/ulysse/Vidéos/Clip"
mkdir -p "$DIR"

case "$1" in
  start)
    # Ne relance pas si déjà actif
    pgrep -f "gpu-screen-recorder" >/dev/null && exit 0
    exec gpu-screen-recorder \
      -w screen \
      -f 60 \
      -a "default_output|default_input" \
      -c mp4 \
      -r 30 \
      -replay-storage ram \
      -o "$DIR"
    ;;
  save)
    if pkill -SIGUSR1 -f "gpu-screen-recorder"; then
      notify-send "Clip" "Les 30 dernières secondes ont été sauvegardées"
    else
      notify-send "Clip" "Le replay n'est pas lancé"
    fi
    ;;
  *)
    echo "Usage: $0 {start|save}"
    ;;
esac
