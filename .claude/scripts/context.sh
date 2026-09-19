#!/bin/sh
# SessionStart. Prints a short picture of the founder's folder, which Claude
# Code adds to the conversation: who, which track, what exists, what is next.
# With --compact it adds the instruction not to start again after a summary.
#
# It replaces the app's run header and turn prefix. It never prints a command
# for the founder to run in a terminal.

. "$(dirname "$0")/lib.sh" 2>/dev/null || exit 0

root=$(lh_root)
ge="$root/growth-engine"

# The SessionStart hook's own JSON, read only to pull session_id out of it for
# setup-check.sh's say-it-once sentinel, and only when stdin is not a
# terminal, so a manual run of this script (or the test suite, run by hand in
# a real terminal) never blocks waiting on input that will never come. In
# production the harness always pipes this hook JSON on stdin.
session_id=""
if [ ! -t 0 ]; then
  hook_input=$(cat 2>/dev/null)
  session_id=$(lh_json_get session_id "$hook_input" 2>/dev/null)
fi

if ! lh_active; then
  # The single most common failure: Claude opened one folder up or one down.
  all=$(lh_near_all)
  n=$(printf '%s' "$all" | grep -c .)
  if [ "$n" -gt 1 ]; then
    printf 'Launchhouse: this is not the founder folder, and there are %s Launchhouse folders nearby:\n%s\nBefore doing any Launchhouse work, show the founder these, ask which is the real one (the /growth-engine:help skill compares them), and tell them to open it. Never merge or delete either.\n' "$n" "$all"
    exit 0
  elif [ "$n" = 1 ]; then
    printf 'Launchhouse: this is not the founder folder. Their Launchhouse folder is %s. Before doing any Launchhouse work, tell the founder in one sentence to open that folder instead, because files written here will not be found later.\n' "$all"
    exit 0
  fi
  if [ -f "$root/growth-engine/brain/founder-brain.md" ] || [ -f "$root/growth-engine/founder-brain.md" ] || [ -f "$root/growth-engine/README-your-files.md" ]; then
    printf 'Launchhouse: this folder has Launchhouse files but has not been set up. If the founder wants to work on Launchhouse, start with /growth-engine:start.\n'
  elif [ "$1" != --compact ]; then
    sh "$(dirname "$0")/setup-check.sh" "$session_id" 2>/dev/null
  fi
  exit 0
fi

sh "$(dirname "$0")/refresh.sh" >/dev/null 2>&1
sh "$(dirname "$0")/desktop-copy.sh" --hook >/dev/null 2>&1

founder=$(lh_brain_label Founder)
business=$(lh_brain_label Business)
track=$(lh_track)
model=$(lh_brain_label Model)

tz=""
if [ -f "$ge/.state/profile.md" ]; then
  tz=$(awk -F ':' 'tolower($0) ~ /timezone/ { v = $0; sub(/^[^:]*:[[:space:]]*/, "", v); gsub(/\*/, "", v); gsub(/[[:space:]]/, "", v); print v; exit }' "$ge/.state/profile.md")
  [ -n "$founder" ] || founder=$(awk -F ':' 'tolower($0) ~ /founder/ { v = $0; sub(/^[^:]*:[[:space:]]*/, "", v); gsub(/\*/, "", v); print v; exit }' "$ge/.state/profile.md")
fi
if [ -n "$tz" ]; then
  today=$(TZ="$tz" date '+%A %e %B %Y, %H:%M' 2>/dev/null | tr -s ' ')
  today="$today in $tz"
else
  today=$(date '+%A %e %B %Y, %H:%M' 2>/dev/null | tr -s ' ')
  today="$today (timezone not recorded yet)"
fi

printf 'Launchhouse founder folder. All work lives in growth-engine/ and nowhere else.\n'
printf 'Founder: %s. Business: %s.\n' "${founder:-not recorded yet}" "${business:-not recorded yet}"
if [ -n "$track" ]; then
  printf 'Track: %s' "$track"
  [ -n "$model" ] && printf ', model: %s' "$model"
  printf '. Never write, offer or mention the other track'"'"'s material.\n'
else
  printf 'Track: not chosen yet. Do not assume either track.\n'
fi
printf 'Today: %s.\n' "$today"
# The same short block the hook on every message prints, so the two never differ.
sh "$(dirname "$0")/state-block.sh" 2>/dev/null
printf 'The founder does not use a terminal. Never ask them to run a command; offer the plain words or the /growth-engine: name instead.\n'

# Silent when all is well; on startup/resume/clear only, never on compact,
# which just re-shows the same picture of an already-checked session.
[ "$1" != --compact ] && sh "$(dirname "$0")/setup-check.sh" "$session_id" 2>/dev/null

if [ "$1" = "--compact" ]; then
  printf 'The conversation was just summarised. Do not start again and do not re-ask anything already answered. Read the files in growth-engine/ before assuming anything is missing.\n'
fi
exit 0
