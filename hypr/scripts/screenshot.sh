#!/bin/bash

# Define the save directory
SAVEDIR="/home/maxgreene/Screenshots"

# Create the directory if it does not exist
mkdir -p -- "$SAVEDIR"

# Format the filename with date and time
FILENAME="$SAVEDIR/$(date +'%Y-%m-%d-%H%M%S_screenshot.png')"

# Select the area first. If slurp is cancelled (Escape / right-click) it exits
# non-zero and prints nothing, so bail out instead of handing grim an empty
# geometry and then notifying about a file that was never written.
GEOMETRY=$(slurp) || exit 0
[ -n "$GEOMETRY" ] || exit 0

# Use grim to capture the selected area
grim -g "$GEOMETRY" "$FILENAME" || exit 1

# Open the screenshot with swappy for editing
swappy -f "$FILENAME" -o "$FILENAME"

# Copy the screenshot to the clipboard
wl-copy < "$FILENAME"

# Send a notification
notify-send "Screenshot" "File saved as <i>'$FILENAME'</i> and copied to the clipboard." -i "$FILENAME"
