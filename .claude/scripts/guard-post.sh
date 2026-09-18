#!/bin/sh
# PostToolUse on Write, Edit and MultiEdit, and on Bash.
#
# Reads the file as it now stands and runs rules.awk over it. If a new or
# changed line is held, the file is put back exactly as it was before the write
# (or removed, if it did not exist), and Claude is told which line, why, and
# what to do. So a held file never stays on disk, which is what the app's gate
# promised.
#
# A line that was already in the file before the write is never held: it may be
# the founder's own words. Claude is told about it once, to mention to the
# founder, and it is left exactly as it is.
#
# After a shell command, every judged file the command changed is checked the
# same way, against the copies guard-pre.sh kept before it ran. A new file it
# brings in is an existing document, so it is kept and reported, never removed.
# Nothing in inbox/uploads/ or brain/voice-samples/ is ever held, removed or put back.
#
# Notes do not stop anything. They go back to Claude as context, folded so a
# founder never reads thirty of them.

. "$(dirname "$0")/lib.sh" 2>/dev/null || exit 0
lh_active || exit 0

input=$(cat) || exit 0
root=$(lh_root)
here=$(dirname "$0")
pre="$root/growth-engine/.state/.pre"

finish() {
  sh "$here/index.sh" >/dev/null 2>&1
  exit 0
}

# The track a file is judged on.
track_for() {
  if [ "$1" = brain/founder-brain.md ]; then t=$(lh_track_of "$2"); else t=$(lh_track); fi
  case $t in b2b|b2c) printf '%s' "$t" ;; esac
}

# Lines like "Line 4: "quote" why. ", for the first three findings on stdin.
lines_of() {
  awk -F '\t' 'NR <= 3 { printf "Line %s: \"%s\" %s ", $2, $4, $5 }'
}

# One sentence for Claude about held lines that were already in the file
# ($2, OLD findings), said once until they change. $1 inner path, $3 key.
existing() {
  if [ -z "$2" ]; then rm -f "$pre/$3.told"; return 0; fi
  if [ -f "$pre/$3.told" ] && [ "$(cat "$pre/$3.told")" = "$2" ]; then return 0; fi
  printf '%s\n' "$2" > "$pre/$3.told" 2>/dev/null
  printf 'In growth-engine/%s, some lines that were already there, or were copied in, break a Launchhouse rule. %sThey were left exactly as they are, because they may be the founder'"'"'s own words. Tell the founder in one plain sentence which line and why, and leave the choice to them. Change it only if they ask. ' "$1" "$(printf '%s\n' "$2" | lines_of)"
}

# A GoHighLevel key, pit- and eight hex characters, is never repeated back.
pit='pit-[0-9A-Fa-f]{8}-'
unkey() { printf '%s' "$1" | sed -E 's/pit-[0-9A-Fa-f]{8}-[A-Za-z0-9-]*/(a key, not shown)/g'; }
json_nokey() { lh_json_escape "$(unkey "$1")"; }

tool=$(lh_json_get tool_name "$input") || tool=""

# ---------------------------------------------------------------- shell
if [ "$tool" = Bash ]; then
  sums="$pre/shell.sums"
  [ -f "$sums" ] || exit 0
  ge="$root/growth-engine"
  lh_judged_files | lh_sums "$ge" > "$pre/shell.now"
  awk 'NR == FNR { was[$0] = 1; next }
       !($0 in was) { sub(/^[0-9]+ [0-9]+ /, ""); print }' "$sums" "$pre/shell.now" > "$pre/shell.changed"
  awk '{ sub(/^[0-9]+ [0-9]+ /, ""); print }' "$sums" > "$pre/shell.had"
  msg=""; told=""
  # A link in place of a file shows words from outside the folder, unchecked.
  # It never stays: it is removed, and the file it replaced is put back.
  ( cd "$ge" && find . \( -path ./people -o -path ./.state \) -prune -o -type l -print 2>/dev/null ) |
    sed 's|^\./||' > "$pre/shell.links"
  while IFS= read -r f; do
    [ -n "$f" ] && [ -L "$ge/$f" ] || continue
    rm -f "$ge/$f"
    how="It has been removed."
    if [ -f "$pre/shell/$f" ] && [ ! -L "$pre/shell/$f" ]; then
      cp -p "$pre/shell/$f" "$ge/$f" 2>/dev/null && how="The file it replaced has been put back."
    fi
    msg="${msg}HELD, NOT SAVED: growth-engine/$f was made a link to another file by a shell command. $how "
  done < "$pre/shell.links"
  while IFS= read -r f; do
    [ -n "$f" ] && [ -f "$ge/$f" ] && [ ! -L "$ge/$f" ] || continue
    old=""; [ -f "$pre/shell/$f" ] && old="$pre/shell/$f"
    # A key never stays in a file here, where the next save would put it in git.
    if grep -Eq "$pit" "$ge/$f" 2>/dev/null; then
      if [ -n "$old" ]; then cp -p "$old" "$ge/$f" 2>/dev/null; else rm -f "$ge/$f"; fi
      msg="${msg}HELD, NOT SAVED: growth-engine/$f had a GoHighLevel key put in it by a shell command, so it was taken out again. A key never goes in a file in this folder. It lives only in the computer's password store. "
      continue
    fi
    findings=$(lh_judge "$ge/$f" "$old" "$f" "$(track_for "$f" "$ge/$f")") || continue
    # A new file a shell command brings in is an existing document, such as the
    # founder's work copied across from the app. It is kept, and its held lines
    # go to the founder to decide, like lines that were already there.
    if [ -z "$old" ] && ! grep -Fqx "$f" "$pre/shell.had"; then
      findings=$(printf '%s\n' "$findings" | awk -F '\t' -v OFS='\t' '$1 == "HOLD" { $1 = "OLD" } { print }')
    fi
    key=$(lh_key "$f")
    told="$told$(existing "$f" "$(printf '%s\n' "$findings" | awk -F '\t' '$1 == "OLD"')" "$key")"
    holds=$(printf '%s\n' "$findings" | grep '^HOLD')
    [ -n "$holds" ] || continue
    if [ -n "$old" ]; then
      cp -p "$old" "$ge/$f" 2>/dev/null
      how="It has been put back exactly as it was before the command."
    else
      how="There was no earlier copy to put back, so the file still holds the new words. Rewrite the lines below straight away."
    fi
    msg="${msg}HELD, NOT SAVED: growth-engine/$f was changed by a shell command. $how $(printf '%s\n' "$holds" | lines_of)"
  done < "$pre/shell.changed"
  rm -rf "$pre/shell" "$pre/shell.sums" "$pre/shell.list" "$pre/shell.now" "$pre/shell.changed" "$pre/shell.had" "$pre/shell.links"
  if [ -n "$msg" ]; then
    msg="$msg Write those files with the editing tools instead, and fix those lines. Tell the founder in one plain sentence what was held and why, never as an error code. $told"
    printf '{"decision":"block","reason":"%s"}\n' "$(json_nokey "$msg")"
  elif [ -n "$told" ]; then
    printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$(json_nokey "$told")"
  fi
  finish
fi

# ---------------------------------------------------------------- one file
path=$(lh_json_get file_path "$input") || exit 0
[ -n "$path" ] || exit 0
rel=$(lh_rel "$path")
case $rel in growth-engine/*) ;; *) exit 0 ;; esac
inner=${rel#growth-engine/}
file="$root/$rel"

lh_is_judged "$inner" || finish
[ -f "$file" ] || finish

key=$(lh_key "$inner")
old=""; [ -f "$pre/$key" ] && old="$pre/$key"
findings=$(lh_judge "$file" "$old" "$inner" "$(track_for "$inner" "$file")") || finish
told=$(existing "$inner" "$(printf '%s\n' "$findings" | awk -F '\t' '$1 == "OLD"')" "$key")

holds=$(printf '%s\n' "$findings" | grep '^HOLD')
if [ -n "$holds" ]; then
  if [ -f "$pre/$key" ]; then
    cp -p "$pre/$key" "$file" 2>/dev/null
    how="It has been put back exactly as it was before this write."
  elif [ -f "$pre/$key.new" ]; then
    rm -f "$file"
    how="It was a new file, so it has been removed."
  else
    how="There was no earlier copy to put back, so the file still holds the new words. Rewrite the lines below straight away."
  fi
  rm -f "$pre/$key" "$pre/$key.new"
  reason=$(printf '%s\n' "$holds" | lines_of)
  more=$(printf '%s\n' "$holds" | grep -c '^HOLD')
  extra=""
  [ "$more" -gt 3 ] && extra=" There are $((more - 3)) more held lines in this file."
  msg="HELD, NOT SAVED: growth-engine/$inner. $how $reason$extra Fix those lines and write the file again. Tell the founder in one plain sentence what was held and why, never as an error code. $told"
  printf '{"decision":"block","reason":"%s"}\n' "$(json_nokey "$msg")"
  sh "$here/index.sh" >/dev/null 2>&1
  exit 0
fi

rm -f "$pre/$key" "$pre/$key.new"

notes=$(printf '%s\n' "$findings" | awk -F '\t' '
  $1 == "NOTE" { n++; if (n <= 3) printf "Line %s: \"%s\" %s ", $2, $4, $5 }
  $1 == "MORE" { more += $5 }
  END { if (more > 0) printf "There are %d more like these in this file.", more }')
ctx=""
if [ -n "$notes" ]; then
  ctx="Saved growth-engine/$inner. Notes from the Launchhouse checks, not errors: $notes Fix these quietly if they are clearly wrong. Mention them to the founder only if a figure or claim needs their say. "
fi
ctx="$ctx$told"
if [ -n "$ctx" ]; then
  printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$(json_nokey "$ctx")"
fi
finish
