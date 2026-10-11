#!/bin/bash

# Full redraw prevents shader flicker; restore damage tracking when disabled.
# Lua configs require eval instead of keyword.

set_damage() {
    hyprctl eval "hl.config({ debug = { damage_tracking = $1 } })" > /dev/null
}

case "$1" in
    on)
        hyprshade on vibrance || exit 1
        set_damage 0
        ;;
    off)
        # Repaint both monitors before restoring damage tracking, including after reloads.
        set_damage 0
        hyprshade off || exit 1
        sleep 0.25
        set_damage 2
        ;;
    *)
        echo "usage: ${0##*/} on|off" >&2
        exit 1
        ;;
esac
