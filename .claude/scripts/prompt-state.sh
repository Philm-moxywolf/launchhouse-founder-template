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
# 4. Connection planning. A verb (connect, hook up, set up, integrate, link,
#    sign in to, add, switch to, use) followed, later in the same sentence,
#    by a tool-packs registry name or a generic word for a tool (tool, app,
#    crm, connector, integration, account) reads as the founder planning a
#    connection. Verb-anchored, same idea as lh_sentence_match above but
#    the noun can sit anywhere after the verb, not only at the sentence's
#    own start: "can you connect Apollo for me" fires, "Apollo was a Greek
#    god" never does, because "was" is not one of the verbs.

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

# Connection planning verbs and the generic nouns that count for any tool,
# not just the four registry packs. A registry name (Apollo, Gmail, ...) is
# specific enough that it keeps the full verb list, "switch to" included. A
# bare generic noun (tool, crm, connector, integration) is common enough in
# ordinary talk ("I use the app every day", "I set up my account yesterday")
# that it needs a narrower, more deliberate verb set, and the bare nouns
# "app" and "account" are dropped from it entirely: too generic on their own
# to mean a tool connection. "use" is dropped from both lists outright — it
# almost never signals planning a new connection.
lh_connect_verbs='connect
hook up
set up
integrate
link
sign in to
add
switch to'

lh_connect_generic_verbs='connect
hook up
integrate
link
sign in to
set up
add'

lh_connect_generic_nouns='tool
crm
connector
integration'

# id\tname\tflattened-name, one per registry.tsv row: the name lower cased
# and its punctuation flattened the same way the sentence text below is, so
# "Microsoft 365 (Outlook)" and "microsoft 365 outlook" in a founder's own
# sentence compare equal.
lh_registry_nouns=""
lh_registry="$here/../tool-packs/registry.tsv"
if [ -f "$lh_registry" ]; then
  lh_registry_nouns=$(awk -F '\t' 'NR > 1 && $0 !~ /^#/ && NF >= 2 {
    name = tolower($2)
    gsub(/[,:;()"]/, " ", name)
    gsub(/  +/, " ", name)
    gsub(/^ +| +$/, "", name)
    if (name != "") print $1 "\t" $2 "\t" name
  }' "$lh_registry")
fi

lh_connection_note=""
if [ -n "$low" ]; then
  lh_cm=$(printf '%s\n' "$low" | VERBS="$lh_connect_verbs" GVERBS="$lh_connect_generic_verbs" GENERIC="$lh_connect_generic_nouns" REG="$lh_registry_nouns" awk '
    BEGIN {
      vn = split(ENVIRON["VERBS"], varr, "\n")
      gvn = split(ENVIRON["GVERBS"], gvarr, "\n")
      gn = split(ENVIRON["GENERIC"], garr, "\n")
      rn = split(ENVIRON["REG"], rarr, "\n")
    }
    { buf = buf $0 "\n" }
    END {
      gsub(/[.!?]/, "&\n", buf)
      sn = split(buf, sarr, "\n")
      for (i = 1; i <= sn; i++) {
        s = " " sarr[i] " "
        gsub(/[,:;()"]/, " ", s)
        gsub(/  +/, " ", s)
        vpos = 0
        for (j = 1; j <= vn; j++) {
          v = varr[j]
          if (v == "") continue
          p = index(s, " " v " ")
          if (p > 0 && (vpos == 0 || p < vpos)) vpos = p
        }
        gvpos = 0
        for (j = 1; j <= gvn; j++) {
          v = gvarr[j]
          if (v == "") continue
          p = index(s, " " v " ")
          if (p > 0 && (gvpos == 0 || p < gvpos)) gvpos = p
        }
        if (vpos > 0) {
          for (k = 1; k <= rn; k++) {
            if (rarr[k] == "") continue
            split(rarr[k], f, "\t")
            if (f[3] == "") continue
            p = index(s, " " f[3] " ")
            if (p > vpos) { print "SPECIFIC\t" f[1] "\t" f[2]; exit }
          }
        }
        if (gvpos > 0) {
          for (k = 1; k <= gn; k++) {
            nw = garr[k]
            if (nw == "") continue
            p = index(s, " " nw " ")
            if (p > gvpos) { print "GENERIC"; exit }
          }
        }
        if (vpos == 0 && gvpos == 0) continue
      }
      print "NONE"
    }')
  case $lh_cm in
    SPECIFIC*)
      lh_pack_id_hit=$(printf '%s' "$lh_cm" | awk -F '\t' '{ print $2 }')
      lh_pack_name_hit=$(printf '%s' "$lh_cm" | awk -F '\t' '{ print $3 }')
      lh_connection_note="Connection planning: $lh_pack_name_hit has an expert pack; use the $lh_pack_id_hit-expert skill."
      ;;
    GENERIC)
      lh_connection_note="Connection planning: if the tool they mean has no pack in .claude/tool-packs/registry.tsv, offer to build one with the tool-pack-builder skill once it is connected, and record it as planned in growth-engine/.state/tools.md."
      ;;
  esac
fi

sh "$here/refresh.sh" >/dev/null 2>&1
[ -n "$parked" ] && printf '%s\n' "$parked"
[ -n "$mode_note" ] && printf '%s\n' "$mode_note"
[ -n "$lh_connection_note" ] && printf '%s\n' "$lh_connection_note"
sh "$here/state-block.sh" 2>/dev/null
exit 0
