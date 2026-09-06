#!/bin/bash

# Toggle the vibrance screen shader.
#
# damage_tracking has to drop to 0 alongside it: at the default level 2 only
# damaged regions get re-rendered through the screen shader, so undamaged areas
# keep their unshaded pixels and the whole screen flickers. Level 0 forces a
# full re-render every frame, which fixes it but costs GPU time -- so it goes
# back to 2 when the shader comes off.
#
# Note the option is set via `hyprctl eval`, not `hyprctl keyword`: Hyprland's
# Lua config parser rejects keyword outright ("keyword can't work with
# non-legacy parsers. Use eval.").

set_damage() {
    hyprctl eval "hl.config({ debug = { damage_tracking = $1 } })" > /dev/null
}

case "$1" in
    on)
        hyprshade on vibrance || exit 1
        set_damage 0
        ;;
    off)
        # Force damage_tracking to 0 first: a config reload resets it to the
        # default 2, and dropping the shader under level 2 leaves undamaged
        # regions showing their old *shaded* pixels until something happens to
        # repaint them. Level 0 repaints everything, so hold it there long
        # enough for a few frames to land (60Hz side needs ~17ms each) before
        # handing damage tracking back.
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
