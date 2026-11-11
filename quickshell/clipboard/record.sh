#!/bin/sh
# Records one clipboard entry, read from stdin, in the history file that
# the clipboard picker shows. Same format as fleximenu_clip: one entry per
# line, newlines stored as <NEWLINE>, trailing newlines dropped, empty
# entries and entries already in the file skipped, newest appended last.

hist="$HOME/.cache/cliphist"
mkdir -p "$(dirname "$hist")"
touch "$hist"

# command substitution drops trailing newlines, as the Rust version did
entry=$(cat)
[ -n "$entry" ] || exit 0

entry=$(printf '%s' "$entry" | awk 'BEGIN { ORS = "" } NR > 1 { printf "<NEWLINE>" } { printf "%s", $0 }')

if ! grep -qxF -- "$entry" "$hist"; then
    printf '%s\n' "$entry" >> "$hist"
fi
