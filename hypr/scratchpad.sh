#!/bin/sh
# Toggles a scratchpad window, without a special workspace, so the windows
# behind it stay clickable. The scratchpad lives on a hidden workspace; showing
# it moves it to the workspace you're on and focuses it, and hiding moves it back.
#
#   scratchpad.sh CLASS HIDDEN_WORKSPACE COMMAND...
#
# If no window of CLASS exists, COMMAND starts one and it's shown once mapped.

class=$1
hidden=$2
shift 2
cmd=$*

addr_of() {
    hyprctl clients -j | jq -r --arg c "$class" \
        '[.[] | select(.class == $c)][0].address // empty'
}

addr=$(addr_of)
if [ -z "$addr" ]; then
    sh -c "$cmd" >/dev/null 2>&1 &
    # wait for the new window to map (its rule has put it on the hidden workspace)
    i=0
    while [ -z "$addr" ] && [ $i -lt 40 ]; do
        sleep 0.05
        addr=$(addr_of)
        i=$((i + 1))
    done
    [ -z "$addr" ] && exit 1
fi

active=$(hyprctl activeworkspace -j | jq -r '.id')
ws=$(hyprctl clients -j | jq -r --arg a "$addr" \
    '.[] | select(.address == $a) | .workspace.id')

if [ "$ws" = "$active" ]; then
    hyprctl dispatch "hl.dsp.window.move({ workspace = $hidden, follow = false, window = \"address:$addr\" })" >/dev/null
else
    hyprctl dispatch "hl.dsp.window.move({ workspace = $active, follow = false, window = \"address:$addr\" })" >/dev/null
    hyprctl dispatch "hl.dsp.focus({ window = \"address:$addr\" })" >/dev/null
fi
