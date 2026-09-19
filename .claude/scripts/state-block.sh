#!/bin/sh
# The short state block. The session start hook prints it, and so does the
# hook on every message, so what Claude believes about the folder can never
# drift in the middle of a long session.
#
# It is deliberately a handful of lines. It is injected on every single message.

. "$(dirname "$0")/lib.sh" 2>/dev/null || exit 0
lh_active || exit 0

root=$(lh_root)
ge="$root/growth-engine"
state="$ge/.state/gate-state.md"
track=$(lh_track)

# A file counts as made when it has real content in this copy of the folder.
# A file kept off GitHub that is not here cannot be checked from here, so it is
# never counted as made: saying it is made when it is not is the worse mistake.
made() {
  p=$(lh_place "$1"); [ -n "$p" ] && [ -f "$ge/$p" ] && [ "$(tr -d ' \t\r\n' < "$ge/$p" | wc -c | tr -d ' ')" -ge 40 ]
}

present=""; absent=""
list="founder-brain.md content-30.md content-30.csv rss-feeds.md"
case $track in
  b2b) list="$list outreach-sequence.md outreach-firstlines.csv" ;;
  b2c) list="$list dm-openers.md hook-bank.md inbound-scripts.md" ;;
esac
list="$list ops-workflow.md 90-day-plan.md"
# Only once it exists: the words go in after the snapshot loads at the clinic, so
# listing it as not made yet would read as a job they are late on for weeks.
[ -f "$ge/engines/ops/ghl-values.md" ] && list="$list ghl-values.md"
for f in $list; do
  if made "$f"; then present="$present $(lh_place "$f")"; else absent="$absent $(lh_place "$f")"; fi
done

leftovers=""
[ -f "$ge/README-your-files.md" ] && leftovers=1
[ -d "$ge/growth-engine" ] && leftovers=1
grep -q '/tmp/ge/' "$ge/.state/HOME" 2>/dev/null && leftovers=1
if [ ! -f "$ge/.state/imported.md" ]; then
  for z in "$root"/*.zip "$ge"/*.zip; do
    [ -f "$z" ] && leftovers=1
  done
  for d in "$root"/growth-engine\ */; do
    [ -f "${d}README-your-files.md" ] && leftovers=1
  done
fi

# Files still in the older, flat layout. Nothing moves them by itself: the start
# skill does, when the founder says so.
older=""
for f in founder-brain.md content-30.md ledger.md memory.md ops-log.md uploads voice-samples; do
  [ -e "$ge/$f" ] && older=1
done

if [ -n "$leftovers" ]; then
  next="bring their work across from the app (/growth-engine:import)"
elif [ -n "$older" ]; then
  next="move their files into the new folders, which the start skill does (/growth-engine:start)"
elif [ ! -f "$ge/.state/profile.md" ]; then
  next="set the folder up (/growth-engine:start)"
elif [ ! -f "$ge/brain/founder-brain.md" ]; then
  next="build the Founder Brain (/growth-engine:brain)"
elif [ -z "$track" ]; then
  next="finish the Founder Brain, which has no track yet (/growth-engine:brain)"
elif ! made content-30.md; then
  next="build the content engine (/growth-engine:content)"
elif [ "$track" = b2b ] && ! made outreach-sequence.md; then
  next="build the outreach engine (/growth-engine:outreach)"
elif [ "$track" = b2c ] && ! made dm-openers.md; then
  next="build the audience engine (/growth-engine:audience)"
elif ! made ops-workflow.md; then
  next="build the operations engine (/growth-engine:ops)"
elif ! made 90-day-plan.md; then
  next="connect the tools if not done (/growth-engine:connect), then publish approved pieces (/growth-engine:publish). Before the clinic, write the words the snapshot arrives without (/growth-engine:values), then paste them in once it loads there. The 90 day plan (/growth-engine:plan) is built in Atlanta on the Sunday"
else
  next="ask where they are up to, and pick up from there"
fi

gates=$(awk '/^Gate [ABC]: / { g = $0; sub(/^Gate /, "", g); sub(/: /, " ", g); sub(/ done$/, "", g); out = out (out == "" ? "" : ", ") "gate " g } END { print out }' "$state" 2>/dev/null)
engine=$(awk -F ': ' '/^Engine in progress:/ { print $2; exit }' "$state" 2>/dev/null)
paused=$(awk -F ': ' '/^Paused:/ { print $2; exit }' "$state" 2>/dev/null)

printf 'Launchhouse state (growth-engine/.state/gate-state.md): track %s' "${track:-not chosen yet}"
[ -n "$gates" ] && printf ', %s. Working on: %s' "$gates" "${engine:-none}"
printf '.\n' 
printf 'Made:%s\n' "${present:- nothing yet}"
[ -n "$absent" ] && printf 'Not made yet:%s\n' "$absent"
drafts=$(ls "$ge/drafts" 2>/dev/null | grep -vc '^\.gitkeep$' | tr -d ' ')
[ "${drafts:-0}" -gt 0 ] && printf 'Drafts waiting for the founder to read in growth-engine/drafts/: %s.\n' "$drafts"
[ -n "$paused" ] && [ "$paused" != none ] && printf 'Parked for now, do not push them on it: %s.\n' "$paused"

# A note from the Desktop copies feature (moved to Your edits, another folder
# owns the Desktop copies, a copy could not be written), printed once and
# cleared, so it is never said twice.
bk=$(lh_bk_dir 2>/dev/null)
if [ -n "$bk" ] && [ -s "$bk/desktop-note" ]; then
  note=$(tr '\n' ' ' < "$bk/desktop-note" 2>/dev/null)
  rm -f "$bk/desktop-note" 2>/dev/null
  [ -n "$note" ] && printf 'Desktop copies: %s\n' "$note"
fi

printf 'Most likely next step: %s.\n' "$next"
exit 0
