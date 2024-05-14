#!/bin/bash

# Define the save directory
SAVEDIR="/home/maxgreene/Screenshots"

# Create the directory if it does not exist
mkdir -p -- "$SAVEDIR"

# Format the filename with date and time
FILENAME="$SAVEDIR/$(date +'%Y-%m-%d-%H%M%S_screenshot.png')"

# Use grim to capture the screenshot, slurp to select the area
grim -g "$(slurp)" "$FILENAME"

# Open the screenshot with swappy for editing
swappy -f "$FILENAME" -o "$FILENAME"

# Copy the screenshot to the clipboard
wl-copy < "$FILENAME"

# Send a notification
notify-send "Screenshot" "File saved as <i>'$FILENAME'</i> and copied to the clipboard." -i "$FILENAME"
