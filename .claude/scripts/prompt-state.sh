#!/bin/sh
# UserPromptSubmit. Two jobs, both small.
#
# 1. "park this". If the founder asks to put the engine down, or to pick it back
#    up, that is recorded here, so it works in plain words with no skill needed.
#    A phrase only counts at the start of the message, or at the start of a
#    sentence within it (after a ".", "!", "?" or a newline), and never when
#    that sentence opens with "don't", "do not" or "not" - so a question like
#    "can we park the Apollo question for later" or a "don't park this yet"
#    is left alone. See lh_sentence_match below.
# 2. The short state block, refreshed and printed on every message, so a long
#    session never works from what the folder looked like an hour ago.
# 3. The mode notice: one line, only when permission_mode is auto, dontAsk or
#    bypassPermissions, saying most tools run with no prompt in this mode and
#    naming the one check that is still there. Nothing in any other mode. If
#    this hook's own input does not carry permission_mode at all, nothing is
#    printed either — never a guess at what mode the session is in.

. "$(dirname "$0")/lib.sh" 2>/dev/null || exit 0
lh_active || exit 0

here=$(dirname "$0")
input=$(cat 2>/dev/null)
prompt=$(lh_json_get prompt "$input" 2>/dev/null)
low=$(printf '%s' "$prompt" | tr 'A-Z' 'a-z')
mode=$(lh_json_get permission_mode "$input" 2>/dev/null) || mode=""
mode_note=""
case $mode in
  auto|dontAsk|bypassPermissions)
    mode_note="Permission mode $mode: most tools run with no prompt. Before any tool that changes or sends something outside the folder, show the founder what it will do and get a yes in chat."
    ;;
esac

# Does any of the newline separated phrases in $2 open a sentence in $1 (the
# already-lowered prompt)? A sentence is the start of the string, or whatever
# follows a ".", "!", "?" or a newline, with its own leading spaces trimmed.
# A sentence that itself opens with "don't", "do not" or "not" never counts,
# no matter where the phrase sits in it, so a plain negation is always safe.
# A phrase must also end at a word boundary, so "park this" cannot fire off
# the front of some longer word like "parking thistle".
lh_sentence_match() {
  # The phrase list is passed through the environment, not -v: a -v
  # assignment with a real (unescaped) newline in it breaks BSD awk's
  # argument parsing, and this list is naturally one phrase per line.
  printf '%s\n' "$1" | PHRASES="$2" awk '
    BEGIN { pn = split(ENVIRON["PHRASES"], parr, "\n") }
    { buf = buf $0 "\n" }
    END {
      gsub(/[.!?]/, "&\n", buf)
      sn = split(buf, sarr, "\n")
      for (i = 1; i <= sn; i++) {
        s = sarr[i]
        gsub(/^[ \t]+/, "", s)
        if (s == "") continue
        if (s ~ /^(don.t|do not|not)([ \t]|$)/) continue
        for (j = 1; j <= pn; j++) {
          p = parr[j]
          if (p == "") continue
          pl = length(p)
          if (substr(s, 1, pl) != p) continue
          rest = substr(s, pl + 1, 1)
          if (rest ~ /^[a-z0-9]$/) continue
          print "yes"; exit
        }
      }
      print "no"
    }'
}

unpark_phrases='un-park
unpark
pick it back up
pick this back up
pick that back up
picking it back up
unpause'

park_phrases='park this
park it
park that
park the
pause this
pause it for now
put this down
put it down for now
on hold for now
shelve this
come back to this later
come back to it later'

parked=""
if [ "$(lh_sentence_match "$low" "$unpark_phrases")" = yes ]; then
  parked=$(sh "$here/park.sh" resume 2>/dev/null)
elif [ "$(lh_sentence_match "$low" "$park_phrases")" = yes ]; then
  parked=$(sh "$here/park.sh" pause 2>/dev/null)
fi

sh "$here/refresh.sh" >/dev/null 2>&1
[ -n "$parked" ] && printf '%s\n' "$parked"
[ -n "$mode_note" ] && printf '%s\n' "$mode_note"
sh "$here/state-block.sh" 2>/dev/null
exit 0
