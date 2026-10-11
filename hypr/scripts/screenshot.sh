#!/bin/bash

SAVEDIR="$HOME/Screenshots"

# Cancel without capturing or notifying.
GEOMETRY=$(slurp) || exit 0
[ -n "$GEOMETRY" ] || exit 0

mkdir -p -- "$SAVEDIR" || exit 1
FILENAME="$SAVEDIR/$(date +'%Y-%m-%d-%H%M%S_screenshot.png')"
grim -g "$GEOMETRY" "$FILENAME" || exit 1
swappy -f "$FILENAME" -o "$FILENAME"
wl-copy < "$FILENAME" || exit 1
notify-send "Screenshot" "File saved as <i>'$FILENAME'</i> and copied to the clipboard." -i "$FILENAME"
