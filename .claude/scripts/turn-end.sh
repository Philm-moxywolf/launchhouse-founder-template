#!/bin/sh
# Stop. At the end of a turn, one line about what the engine the founder is on
# still needs, and an offer to carry on.
#
# It never blocks, it never repeats itself for the same engine, and it says
# nothing at all about an engine the founder has parked. It speaks only about an
# engine that is part built: something under it is done and something is not. An
# engine nobody has started yet is left alone, so the one useful nudge is not
# spent before the founder has written a word. What it has already said is
# recorded in growth-engine/.state/nudges.md.

. "$(dirname "$0")/lib.sh" 2>/dev/null || exit 0

# Before any early exit below, so a synced Desktop folder never depends on the
# founder still being mid-engine or attended in the way the rest of this
# script cares about. desktop-copy.sh does its own checks and fails open.
sh "$(dirname "$0")/desktop-copy.sh" --hook >/dev/null 2>&1

lh_active || exit 0

here=$(dirname "$0")
input=$(cat 2>/dev/null)
# Never answer our own continuation.
case $input in *'"stop_hook_active": true'*|*'"stop_hook_active":true'*) exit 0 ;; esac
# Nobody is watching a routine run in the cloud, so a nudge written there would
# be spent on no one and the founder would never be told on their own computer.
case ${CLAUDE_CODE_SESSION_ATTENDED-1} in 1|true|yes) ;; *) exit 0 ;; esac

sh "$here/refresh.sh" >/dev/null 2>&1

root=$(lh_root)
ge="$root/growth-engine"
state="$ge/.state/gate-state.md"
[ -f "$state" ] || exit 0

engine=$(awk -F ': ' '/^Engine in progress:/ { print $2; exit }' "$state")
[ -n "$engine" ] || exit 0
[ "$engine" = none ] && exit 0

paused=$(awk -F ': ' '/^Paused:/ { print $2; exit }' "$state")
case ", $paused," in *", $engine,"*) exit 0 ;; esac

nudges="$ge/.state/nudges.md"
if [ -f "$nudges" ] && grep -q "| $engine |" "$nudges" 2>/dev/null; then exit 0; fi

missing=$(awk -F '|' -v e="$engine" '
  /^\| / {
    for (i = 1; i <= NF; i++) { f = $i; gsub(/^[ \t]+|[ \t]+$/, "", f); c[i] = f }
    if (c[7] != e) next
    if (c[5] == "done" || c[5] == "answered") { d++; next }
    if (c[5] != "not done" && c[5] != "ask") next
    n++
    item = c[4]
    # Mid sentence, so the first letter only goes down.
    item = tolower(substr(item, 1, 1)) substr(item, 2)
    if (n <= 2) out = out (out == "" ? "" : ", ") item
  }
  END {
    # Part built, or not a word written yet. Only the first is worth a line.
    if (n == 0 || d == 0) exit 1
    if (n > 2) out = out ", and " (n - 2) " more"
    else if (n == 2) sub(/, /, " and ", out)
    print out
  }' "$state") || exit 0
[ -n "$missing" ] || exit 0

name=$(printf '%s' "$engine" | sed 's/brain/Founder Brain/; s/content/content engine/; s/outreach/outreach engine/; s/audience/audience engine/; s/^ops$/operations engine/; s/^plan$/90 day plan/')

mkdir -p "$ge/.state" 2>/dev/null
if [ ! -f "$nudges" ]; then
  {
    printf '# What the end of turn check has already said\n\n'
    printf 'One line per engine, so the founder is asked once and never nagged.\n'
    printf 'Format: date | engine | what was still missing\n\n'
  } > "$nudges" 2>/dev/null
fi
printf '%s | %s | %s\n' "$(date '+%Y-%m-%d')" "$engine" "$missing" >> "$nudges" 2>/dev/null

msg="Still to do on the $name: $missing. Say carry on to keep going, or park this to put it down for now."
printf '{"systemMessage":"%s"}\n' "$(lh_json_escape "$msg")"
exit 0
