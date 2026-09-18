#!/bin/sh
# Parks an engine, or picks it up again.
#
#   sh park.sh pause  [engine]   the end of turn check goes quiet for it
#   sh park.sh resume [engine]   it counts again
#
# With no engine it uses the one in progress in .state/gate-state.md. Engines
# are brain, content, outreach, audience, ops and plan. The record is a dated
# line in growth-engine/.state/paused.md, newest line wins.

. "$(dirname "$0")/lib.sh" 2>/dev/null || exit 0
lh_active || exit 0
root=$(lh_root)
ge="$root/growth-engine"
state="$ge/.state/gate-state.md"

what=$1
engine=$2
[ -n "$engine" ] || engine=$(awk -F ': ' '/^Engine in progress:/ { print $2; exit }' "$state" 2>/dev/null)
[ -n "$engine" ] || engine=none
[ "$engine" = none ] && exit 0

case $what in
  pause) word=paused ;;
  resume) word=running ;;
  *) exit 0 ;;
esac

mkdir -p "$ge/.state" 2>/dev/null || exit 0
f="$ge/.state/paused.md"
if [ ! -f "$f" ]; then
  {
    printf '# Parked engines\n\n'
    printf 'One line each time an engine is put down or picked up. Newest line wins.\n'
    printf 'Format: date | engine | paused or running\n\n'
  } > "$f" 2>/dev/null || exit 0
fi
printf '%s | %s | %s\n' "$(date '+%Y-%m-%d')" "$engine" "$word" >> "$f" 2>/dev/null

# Picking an engine back up must let the end of turn check speak about it
# again. That check goes quiet forever once it has said something about an
# engine, recorded as a "| engine |" line in nudges.md, so resuming has to
# clear that line or the founder would do more work and never hear the
# reminder. Pausing never touches this file.
if [ "$word" = running ]; then
  nudges="$ge/.state/nudges.md"
  if [ -f "$nudges" ]; then
    tmp="$nudges.tmp.$$"
    if grep -v "| $engine |" "$nudges" > "$tmp" 2>/dev/null; then
      mv "$tmp" "$nudges" 2>/dev/null
    else
      rm -f "$tmp" 2>/dev/null
    fi
  fi
fi

sh "$(dirname "$0")/gate-state.sh" --force >/dev/null 2>&1
if [ "$word" = paused ]; then
  printf 'Parked the %s engine. Say pick this back up when you want to start it again.\n' "$engine"
else
  printf 'Picked the %s engine back up.\n' "$engine"
fi
exit 0
