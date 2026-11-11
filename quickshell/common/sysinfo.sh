#!/bin/sh
# Prints one `name|field|...` line per status segment. Sys.qml reads it
# every tick. A segment whose tool or hardware is missing prints nothing,
# so its chip is hidden.

echo "kernel|$(cat /proc/sys/kernel/osrelease)"
echo "desktop|${XDG_CURRENT_DESKTOP:-${XDG_SESSION_DESKTOP:-Hyprland}}"

for b in BAT0 BAT1 BAT; do
    d=/sys/class/power_supply/$b
    if [ -d "$d" ]; then
        echo "battery|$(cat "$d/status")|$(cat "$d/capacity")"
        break
    fi
done

awk '/^MemTotal:/ {t = $2} /^MemAvailable:/ {a = $2}
     END {if (t) printf "ram|%d\n", t - a}' /proc/meminfo

# CPU: busy share over 0.2s, from two reads of the aggregate line of
# /proc/stat. The total is user + nice + system + idle, as before.
read -r _ u1 n1 s1 i1 _ < /proc/stat
sleep 0.2
read -r _ u2 n2 s2 i2 _ < /proc/stat
t1=$((u1 + n1 + s1 + i1))
t2=$((u2 + n2 + s2 + i2))
if [ "$t2" -gt "$t1" ]; then
    echo "cpu|$(( 100 * ((t2 - t1) - (i2 - i1)) / (t2 - t1) ))"
fi

keymap=$(hyprctl devices -j 2>/dev/null \
    | grep -o '"active_keymap": *"[^"]*"' | head -n 1 \
    | sed 's/.*: *"//; s/"$//')
[ -n "$keymap" ] && echo "keyboard|$keymap"

for n in /sys/class/net/wl*; do
    [ -e "$n" ] || continue
    echo "network|$(cat "$n/operstate")"
    break
done

if command -v pactl >/dev/null 2>&1; then
    mute=$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | awk '{print $2}')
    vol=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null \
        | awk 'NR == 1 {gsub("%", "", $5); print $5}')
    [ -n "$vol" ] && echo "volume|$mute|$vol"
fi

day=$(date +%-d)
case $day in
    1|21|31) suffix=st ;;
    2|22) suffix=nd ;;
    3|23) suffix=rd ;;
    *) suffix=th ;;
esac
echo "clock|$day$suffix $(date '+%b %Y')|$(date '+%I:%M %P')"
