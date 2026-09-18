#!/bin/sh
# Moves a growth-engine folder from the older flat layout into folders by kind,
# the layout in .claude/references/contract.md (lh_place in lib.sh mirrors it).
#
# Usage:
#   sh .claude/scripts/move-layout.sh < /dev/null
#       the founder's own growth-engine folder. The start skill runs it.
#   sh .claude/scripts/move-layout.sh .lh-import/growth-engine < /dev/null
#       a holding folder, such as work brought across from the app, before it
#       is copied in. import-from-app runs it.
#
# What it promises:
#   - A file git keeps is moved with git mv, so its history follows it. A file
#     git does not keep, such as the private files, is moved with a plain mv
#     and stays out of git at its new path.
#   - It never overwrites. If the new path is already taken, the old file is
#     left where it is and named in the output.
#   - It never deletes anything the founder made. The only thing it drops is an
#     empty .gitkeep placeholder whose new folder already has one, and an old
#     folder once it is empty.
#   - A second run changes nothing.
#   - For the founder's own folder, it adds one plain line to log/ops-log.md
#     saying what moved and why.
#
# people/, drafts/ and .state/ never move.

here=$(dirname "$0")
. "$here/lib.sh" 2>/dev/null || { echo "Could not load lib.sh."; exit 1; }

if [ -n "$1" ]; then
  ge=$1
  own=0
else
  ge="$(lh_root)/growth-engine"
  own=1
fi
[ -d "$ge" ] || { printf 'Nothing to move: %s is not there.\n' "$ge"; exit 0; }
ge=$(cd "$ge" && pwd)

moved=0; kept=0
moves=""; clashes=""

tracked() {
  command -v git >/dev/null 2>&1 || return 1
  ( cd "$ge" && git ls-files --error-unmatch -- "$1" ) >/dev/null 2>&1
}

# $1 old path, $2 new path, both inside growth-engine.
move_one() {
  if [ -e "$ge/$2" ] || [ -L "$ge/$2" ]; then
    if [ "${1##*/}" = .gitkeep ] && [ ! -s "$ge/$1" ]; then
      if tracked "$1"; then ( cd "$ge" && git rm -q -- "$1" ) >/dev/null 2>&1 || rm -f "$ge/$1"
      else rm -f "$ge/$1"; fi
      return 0
    fi
    kept=$((kept + 1))
    clashes="$clashes
- $1 (growth-engine/$2 is already there)"
    return 0
  fi
  mkdir -p "$(dirname "$ge/$2")" || return 0
  if tracked "$1"; then
    ( cd "$ge" && git mv -- "$1" "$2" ) >/dev/null 2>&1 || mv "$ge/$1" "$ge/$2" || return 0
  else
    mv "$ge/$1" "$ge/$2" || return 0
  fi
  [ "${1##*/}" = .gitkeep ] && return 0
  moved=$((moved + 1))
  moves="$moves
- $1 to $2"
}

list=$(mktemp 2>/dev/null) || list="${TMPDIR:-/tmp}/lh-move.$$"
trap 'rm -f "$list"' EXIT

# Loose files at the top that have a place in a folder.
( cd "$ge" && find . -maxdepth 1 \( -type f -o -type l \) -print ) | sed 's|^\./||' | sort > "$list"
while IFS= read -r f; do
  p=$(lh_place "$f")
  [ -n "$p" ] && [ "$p" != "$f" ] && move_one "$f" "$p"
done < "$list"

# The two folders that moved, with everything inside them.
for d in uploads voice-samples; do
  [ -d "$ge/$d" ] || continue
  nd=$(lh_dir_place "$d")
  ( cd "$ge" && find "$d" \( -type f -o -type l \) -print ) | sort > "$list"
  while IFS= read -r f; do
    move_one "$f" "$nd/${f#*/}"
  done < "$list"
  # Only folders left empty go. Anything still inside keeps its folder.
  find "$ge/$d" -depth -type d -exec rmdir {} \; 2>/dev/null
done

if [ "$moved" = 0 ] && [ "$kept" = 0 ]; then
  printf 'Nothing to move. The folder is already in the new layout.\n'
  exit 0
fi

if [ "$moved" -gt 0 ]; then
  printf 'Moved %s files into folders by kind. Nothing was deleted or rewritten.%s\n' "$moved" "$moves"
fi
if [ "$kept" -gt 0 ]; then
  printf 'Left %s files where they were, because a file with the same name is already in the new place. Nothing was overwritten.%s\n' "$kept" "$clashes"
fi

# The plain note, for the founder's own folder only.
if [ "$own" = 1 ] && [ "$moved" -gt 0 ]; then
  log="$ge/log/ops-log.md"
  if [ ! -f "$log" ]; then
    mkdir -p "$ge/log"
    printf '# Ops log\n\nAppend only. Every day gets its own heading, as ## YYYY-MM-DD, then lines as - HH:MM decision|result|blocker|note: text\n' > "$log"
  fi
  today=$(date +%Y-%m-%d)
  last=$(grep '^## ' "$log" | tail -1)
  [ "$last" = "## $today" ] || printf '\n## %s\n' "$today" >> "$log"
  printf -- '- %s note: moved %s files into folders by kind, so what is yours, what the engines made and what you hand over each have their own place. Nothing was deleted or rewritten.\n' "$(date +%H:%M)" "$moved" >> "$log"
fi
exit 0
