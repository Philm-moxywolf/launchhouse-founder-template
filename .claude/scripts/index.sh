#!/bin/sh
# Rebuilds growth-engine/.state/index.md from what is actually on disk.
# Never trusted, always rebuilt. Rows fork on the Brain's Track line, so a
# founder never sees the other track's files listed.
#
# Status: missing, empty (under 40 characters that are not spaces), or ok.
# Count: the numbers the gates need, counted here once so no agent has to count
# quoted CSV records or person files by eye.
#
# Files kept off GitHub on purpose (people/, engines/outreach/outreach-firstlines.csv,
# engines/audience/dm-openers.md) are absent from any copy of the folder but the computer they
# were written on. When one is absent but git ignores it and the last index had
# it, its row is carried forward as "unknown, kept off GitHub", so a routine
# does not report it missing and nothing reports it done either.

. "$(dirname "$0")/lib.sh" 2>/dev/null || exit 0
lh_active || exit 0

root=$(lh_root)
ge="$root/growth-engine"
mkdir -p "$ge/.state" 2>/dev/null || exit 0
track=$(lh_track)
old="$ge/.state/index.md"

rows="brain/founder-brain.md|gate A
engines/content/content-30.md|gate B
engines/content/content-30.csv|gate B
engines/content/rss-feeds.md|gate B"
case $track in
  b2b) rows="$rows
engines/outreach/outreach-sequence.md|gate C
engines/outreach/outreach-firstlines.csv|gate C" ;;
  b2c) rows="$rows
engines/audience/dm-openers.md|gate C
engines/audience/hook-bank.md|gate C
engines/audience/inbound-scripts.md|gate C" ;;
esac
rows="$rows
engines/ops/ops-workflow.md|gate C
engines/ops/ghl-values.md|-
engines/plan/90-day-plan.md|-
export/playbook-insert.md|-
log/ledger.md|-
log/memory.md|-
log/ops-log.md|-"

# Quote-aware CSV record count, header excluded.
csv_records() {
  awk 'BEGIN { q = 0; n = 0; started = 0 }
    {
      line = $0; sub(/\r$/, "", line)
      if (!started && line ~ /^[[:space:]]*$/) next
      started = 1
      c = gsub(/"/, "\"", line)
      if (q == 0) n++
      if (c % 2 == 1) q = !q
    }
    END { if (n > 0) n--; print n }' "$1"
}

# Pieces in content-30.md: numbered headings if there are any, else numbered
# list items that open with a bold label (the app's format), else numbered items.
pieces() {
  h=$(grep -Ec '^#+[[:space:]]*[0-9]+[.)]' "$1")
  if [ "$h" -gt 0 ]; then printf '%s' "$h"; return; fi
  b=$(grep -Ec '^[0-9]+[.)][[:space:]]+\*\*' "$1")
  if [ "$b" -gt 0 ]; then printf '%s' "$b"; return; fi
  grep -Ec '^[0-9]+[.)][[:space:]]' "$1"
}

openers() {
  h=$(grep -Ec '^#+[[:space:]]*[0-9]+[.)]' "$1")
  if [ "$h" -gt 0 ]; then printf '%s' "$h"; return; fi
  grep -Ec '^[0-9]+[.)][[:space:]]' "$1"
}

count_for() {
  f="$ge/$1"
  [ -f "$f" ] || { printf -- '-'; return; }
  case $1 in
    engines/content/content-30.md) printf '%s pieces' "$(pieces "$f")" ;;
    engines/content/content-30.csv|engines/outreach/outreach-firstlines.csv) printf '%s rows' "$(csv_records "$f")" ;;
    engines/audience/dm-openers.md) printf '%s openers' "$(openers "$f")" ;;
    log/ledger.md)
      awk -F '|' '/^C\|/ { n++; if ($6 == "approved" || $6 == "scheduled" || $6 == "posted") a++ }
        END { printf "%d pieces, %d approved", n, a }' "$f" ;;
    *) printf -- '-' ;;
  esac
}

ignored() {
  command -v git >/dev/null 2>&1 || return 1
  (cd "$root" && git check-ignore -q "growth-engine/$1") 2>/dev/null
}

previous_row() {
  [ -f "$old" ] || return 1
  grep -F "| $1 |" "$old" | head -1
}

# The files kept off GitHub were seen here, so this is the computer they were
# written on: from now on a missing one really is missing. The marker lives in
# .state/.pre/, which is itself kept off GitHub, and it carries the name of this
# computer, so a folder copied whole to another machine is not mistaken for it.
host=$(uname -n 2>/dev/null); [ -n "$host" ] || host=unknown
if [ -f "$ge/engines/outreach/outreach-firstlines.csv" ] || [ -f "$ge/engines/audience/dm-openers.md" ] || [ "$(ls "$ge/people/" 2>/dev/null | grep -c '\.md$' | tr -d ' ')" -gt 1 ]; then
  mkdir -p "$ge/.state/.pre" 2>/dev/null && printf '%s\n' "$host" > "$ge/.state/.pre/private-seen" 2>/dev/null
fi
# Anywhere else, a missing private file cannot be told apart from one that was
# never written, so its row is carried forward as unknown rather than as ok.
elsewhere() { ! grep -qxF "$host" "$ge/.state/.pre/private-seen" 2>/dev/null; }

tmp="$ge/.state/index.md.tmp.$$"
{
  printf '# Index\n\n'
  printf 'Rebuilt from the folder after every change. Do not edit by hand.\n\n'
  if [ -z "$track" ]; then
    printf 'No track chosen yet, so only the files every founder needs are listed.\n\n'
  else
    printf 'Track: %s\n\n' "$track"
  fi
  printf '| file | gate | status | bytes | count |\n|---|---|---|---|---|\n'
  printf '%s\n' "$rows" | while IFS='|' read -r name gate; do
    f="$ge/$name"
    if [ -f "$f" ]; then
      bytes=$(wc -c < "$f" | tr -d ' ')
      real=$(tr -d ' \t\r\n' < "$f" | wc -c | tr -d ' ')
      if [ "$real" -lt 40 ]; then status=empty; else status=ok; fi
      printf '| %s | %s | %s | %s | %s |\n' "$name" "$gate" "$status" "$bytes" "$(count_for "$name")"
    else
      prev=$(previous_row "$name")
      case $prev in
        *"| ok"*|*"kept off GitHub"*)
          if ignored "$name" && elsewhere; then
            printf '%s\n' "$prev" | sed -e 's/| ok, on the founder'"'"'s computer |/| unknown, kept off GitHub |/' -e 's/| ok |/| unknown, kept off GitHub |/'
            continue
          fi ;;
      esac
      printf '| %s | %s | missing | 0 | - |\n' "$name" "$gate"
    fi
  done

  # People: counted by kind. Absent in any copy but the one they were written
  # in, so the last row is carried forward as unknown.
  if ls "$ge/people/"*.md >/dev/null 2>&1 && [ "$(ls "$ge/people/"*.md | grep -vc '/README\.md$')" -gt 0 ]; then
    prospects=$(grep -l '^kind: prospect' "$ge/people/"*.md 2>/dev/null | while read -r p; do grep -q '^status: cut' "$p" || printf 'x\n'; done | wc -l | tr -d ' ')
    cut=$(grep -l '^kind: prospect' "$ge/people/"*.md 2>/dev/null | while read -r p; do grep -q '^status: cut' "$p" && printf 'x\n'; done | wc -l | tr -d ' ')
    targets=$(grep -l '^kind: target' "$ge/people/"*.md 2>/dev/null | wc -l | tr -d ' ')
    sent=$(grep -l '^kind: target' "$ge/people/"*.md 2>/dev/null | while read -r p; do grep -Eq '^status: (sent|replied|booked|no_reply)' "$p" && printf 'x\n'; done | wc -l | tr -d ' ')
    case $track in
      b2b) printf '| people/ | gate C | ok | - | %s prospects, %s cut |\n' "$prospects" "$cut" ;;
      b2c) printf '| people/ | gate C | ok | - | %s targets, %s sent |\n' "$targets" "$sent" ;;
      *) printf '| people/ | - | ok | - | %s prospects, %s targets |\n' "$prospects" "$targets" ;;
    esac
  else
    prev=$(previous_row "people/")
    case $prev in
      *"| ok"*|*"kept off GitHub"*) if elsewhere; then printf '%s\n' "$prev" | sed -e 's/| ok, on the founder'"'"'s computer |/| unknown, kept off GitHub |/' -e 's/| ok |/| unknown, kept off GitHub |/'; else printf '| people/ | gate C | missing | - | 0 |\n'; fi ;;
      *) printf '| people/ | gate C | missing | - | 0 |\n' ;;
    esac
  fi

  for d in inbox/uploads brain/voice-samples drafts; do
    n=$(ls -A "$ge/$d" 2>/dev/null | grep -vc '^\.gitkeep$' | tr -d ' ')
    printf '| %s/ | - | - | - | %s files |\n' "$d" "$n"
  done
} > "$tmp" 2>/dev/null || { rm -f "$tmp"; exit 0; }

if [ -f "$old" ] && cmp -s "$tmp" "$old"; then
  rm -f "$tmp"
else
  mv "$tmp" "$old"
fi
exit 0
