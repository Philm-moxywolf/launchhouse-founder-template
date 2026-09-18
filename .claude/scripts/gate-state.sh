#!/bin/sh
# One computed picture of where the founder is against the gates.
#
# Reads growth-engine/ and the gate definitions in ../references/gates.md, and
# writes growth-engine/.state/gate-state.md. Everything else that needs to know
# what is done reads that file instead of counting for itself, so the session
# header, the end of turn check, the status skill and the gate skill can never
# disagree with each other.
#
# Rules it keeps:
#  - A file-backed item is done only when the file shows it.
#  - A self-reported item is never evidence. Its answer comes from
#    growth-engine/.state/gate-answers.md, and with no answer it is "ask".
#  - One track only. The other track's items are never written out.
#
# It fails open like every other hook here: if it cannot work something out it
# leaves the old file alone and exits 0.
#
# Run it with --force to rebuild even when nothing has changed.

. "$(dirname "$0")/lib.sh" 2>/dev/null || exit 0
lh_active || exit 0

root=$(lh_root)
ge="$root/growth-engine"
here=$(dirname "$0")
mkdir -p "$ge/.state" 2>/dev/null || exit 0
out="$ge/.state/gate-state.md"

# Which stat this machine has: BSD (-f, a custom format string) or GNU (-c).
# Probed once, here, against this script itself, which always exists, rather
# than inside listing()'s own find -exec: GNU stat treats -f as "show
# filesystem status", a different mode entirely, not a failure, so trying the
# BSD form first and falling back on a nonzero exit is not reliable on Git for
# Windows. Every byte the probe writes, including its own error text, goes to
# /dev/null so nothing from it can leak into the fingerprint or the script's
# own output.
if stat -f '%m' "$0" >/dev/null 2>&1; then
  lh_stat_bsd=1
else
  lh_stat_bsd=0
fi

# Every file under growth-engine, leaving out only the two files this script
# writes itself and the working copies folder. The answer files under .state/
# are counted, because recording an answer has to change the stamp or this
# script would stop early and the answer would never be read.
# Prints "<changed at> <size> <path>" a line at a time.
listing() {
  if [ "$lh_stat_bsd" = 1 ]; then
    find "$ge" -type f \
      ! -path "$ge/.state/.pre/*" \
      ! -path "$ge/.state/gate-state.md" \
      ! -path "$ge/.state/index.md" \
      -exec stat -f '%m %z %N' {} + 2>/dev/null
  else
    find "$ge" -type f \
      ! -path "$ge/.state/.pre/*" \
      ! -path "$ge/.state/gate-state.md" \
      ! -path "$ge/.state/index.md" \
      -exec stat -c '%Y %s %n' {} + 2>/dev/null
  fi
}
all_files=$(listing)
new_line=$(printf '%s\n' "$all_files" | sort -nr | head -1)
new_epoch=${new_line%% *}
new_path=${new_line#* }
new_path=${new_path#* }
case $new_epoch in ''|*[!0-9]*) new_epoch=0 ;; esac
# The stamp covers when every file changed, how big it is, and how many files
# there are, so a file deleted or rewritten in the same second is still caught.
stamp=$(printf '%s\n' "$all_files" | sort | cksum | awk '{ print $1 "-" $2 }')

# Nothing has changed since the last run, so the old answer still stands.
if [ "$1" != "--force" ] && [ -f "$out" ]; then
  had=$(awk -F ': ' '/^Stamp:/ { print $2; exit }' "$out" 2>/dev/null)
  [ -n "$had" ] && [ "$had" = "$stamp" ] && exit 0
fi

sh "$here/index.sh" >/dev/null 2>&1
index="$ge/.state/index.md"

# Every programme date lives in one place, the cohort block in
# ../references/gates.md. Nothing here carries a date of its own. Read the
# Saturday row from it, as a number to compare and as words to print.
sat_line=""
[ -f "$here/../references/gates.md" ] && sat_line=$(awk -F '|' '
  BEGIN { split("january february march april may june july august september october november december", mn, " ") }
  tolower($0) ~ /^\|[[:space:]]*the saturday/ {
    v = $3
    n = split(v, w, /[^0-9A-Za-z]+/)
    for (i = 1; i <= n; i++) {
      if (w[i] ~ /^[0-9][0-9][0-9][0-9]$/) year = w[i] + 0
      else if (w[i] ~ /^[0-9]+$/) { if (day == 0) day = w[i] + 0 }
      else { lw = tolower(w[i]); for (m = 1; m <= 12; m++) if (length(lw) >= 3 && index(mn[m], lw) == 1) mon = m }
    }
    if (day > 0 && mon > 0 && year > 0)
      printf "%04d%02d%02d Saturday %d %s\n", year, mon, day, day, toupper(substr(mn[mon], 1, 1)) substr(mn[mon], 2)
    exit
  }' "$here/../references/gates.md" 2>/dev/null)
saturday=${sat_line%% *}
saturday_words=${sat_line#* }
case $saturday in ''|*[!0-9]*) saturday=""; saturday_words="" ;; esac
track=$(lh_track)
case $track in b2b|b2c) ;; *) track= ;; esac

# --- small readers -----------------------------------------------------------

# The count column of a row in the index, or empty.
idx_count() {
  [ -f "$index" ] || return 0
  grep -F "| $1 |" "$index" 2>/dev/null | head -1 | awk -F '|' '{ v = $6; gsub(/^[ \t]+|[ \t]+$/, "", v); print v }'
}

# The status column of a row in the index, or empty.
idx_status() {
  [ -f "$index" ] || return 0
  grep -F "| $1 |" "$index" 2>/dev/null | head -1 | awk -F '|' '{ v = $4; gsub(/^[ \t]+|[ \t]+$/, "", v); print v }'
}

# The leading number of a count string ("30 pieces" -> 30).
num() { printf '%s' "$1" | awk '{ print $1 + 0 }'; }

# The second number of a count string ("30 pieces, 12 approved" -> 12).
num2() { printf '%s' "$1" | awk -F ',' '{ print $2 + 0 }'; }

# Characters that are not spaces in a whole file.
chars() { [ -f "$1" ] || { printf 0; return; }; tr -d ' \t\r\n' < "$1" | wc -c | tr -d ' '; }

# Characters that are not spaces under one "## Heading", to the next one.
section_chars() {
  [ -f "$1" ] || { printf 0; return; }
  awk -v want="$2" '
    BEGIN { on = 0; n = 0 }
    /^##[[:space:]]/ {
      line = tolower($0); sub(/^#+[[:space:]]*/, "", line); sub(/[[:space:]]+$/, "", line)
      on = (line == tolower(want))
      next
    }
    on { s = $0; gsub(/[ \t\r]/, "", s); n += length(s) }
    END { print n + 0 }' "$1"
}

has() { [ -f "$1" ] && grep -Eiq "$2" "$1" 2>/dev/null; }

# A file is present if it is on disk, or the index carried its row forward
# because it is kept off GitHub. Carried forward is never proof: this copy of
# the folder cannot see the file, so nothing here may call it done.
present() {
  [ -f "$ge/$1" ] && return 0
  carried "$1"
}

# The index carried this row forward: the file is kept off GitHub and is not in
# this copy of the folder. It may be on the founder's own computer, or it may
# never have been written. Nothing here can tell, so nothing here says done.
carried() {
  case "$(idx_status "$1")" in *"kept off GitHub"*) return 0 ;; esac
  return 1
}

# Self-reported answers. The newest line whose second column is the item key.
ans_file="$ge/.state/gate-answers.md"
answer() {
  [ -f "$ans_file" ] || return 1
  a=$(awk -v k="$1" '
    {
      line = $0
      sub(/^[ \t]*\|/, "", line)          # a leading pipe, if it was written as a table row
      n = split(line, c, "|")
      for (i = 1; i <= n; i++) gsub(/^[ \t]+|[ \t]+$/, "", c[i])
      if (n >= 3 && tolower(c[2]) == tolower(k)) last = c[3] " (" c[1] ")"
    }
    END { if (last != "") print last }' "$ans_file" 2>/dev/null)
  [ -n "$a" ] || return 1
  printf '%s' "$a"
}

# An engine whose gate is not met still has a way through: the founder can say
# to go ahead anyway, recorded as a dated line in
# growth-engine/.state/gate-overrides.md: "<date> | <gate> | <engine> | <words>".
# This is never evidence that the gate is met. It only lets that one engine run.
ovr_file="$ge/.state/gate-overrides.md"
overridden_for() {
  [ -f "$ovr_file" ] || return 1
  awk -v e="$1" '
    {
      line = $0
      sub(/^[ \t]*\|/, "", line)
      n = split(line, c, "|")
      for (i = 1; i <= n; i++) gsub(/^[ \t]+|[ \t]+$/, "", c[i])
      if (n >= 4 && tolower(c[3]) == tolower(e)) found = 1
    }
    END { exit (found ? 0 : 1) }' "$ovr_file" 2>/dev/null
}

rows="$ge/.state/gate-state.rows.$$"
: > "$rows" || exit 0
row() { printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" "$6" >> "$rows"; }

# An item the founder has to answer. Done when there is an answer on file.
self_row() {
  if a=$(answer "$2"); then row "$1" "$2" "$3" answered "$a" "$4"
  else row "$1" "$2" "$3" ask "no answer recorded yet" "$4"; fi
}

# --- gate A, the Founder Brain ----------------------------------------------

brain="$ge/brain/founder-brain.md"
# The contract writes it as "- **Locked:** 2026-09-08", so read it the way
# lib.sh reads every other Brain label: strip the asterisks first.
d=""
[ -f "$brain" ] && d=$(lh_brain_label Locked)
case $d in [0-9][0-9][0-9][0-9]-*) ;; *) d="" ;; esac
if [ -n "$d" ]; then
  row A brain-locked "The Brain is written and locked" done "Locked: $d" brain
else
  row A brain-locked "The Brain is written and locked" "not done" "no Locked date in founder-brain.md" brain
fi
if [ -n "$track" ]; then
  row A track-chosen "A track is chosen" done "Track: $track" brain
else
  row A track-chosen "A track is chosen" "not done" "no b2b or b2c on the Track line" brain
fi
n=$(section_chars "$brain" Thesis)
if [ "$n" -ge 40 ]; then row A thesis "The thesis is written" done "$n characters under ## Thesis" brain
else row A thesis "The thesis is written" "not done" "$n characters under ## Thesis, 40 needed" brain; fi
n=$(section_chars "$brain" Voice)
if [ "$n" -ge 40 ]; then row A voice "The voice is captured" done "$n characters under ## Voice" brain
else row A voice "The voice is captured" "not done" "$n characters under ## Voice, 40 needed" brain; fi
self_row A flags "The flags are answered honestly" brain

# --- gate B, the content engine ---------------------------------------------

c=$(num "$(idx_count engines/content/content-30.md)")
if [ "$c" -ge 30 ]; then row B pieces "Thirty pieces are written" done "$c pieces in content-30.md" content
else row B pieces "Thirty pieces are written" "not done" "$c of 30 pieces in content-30.md" content; fi

csv="$ge/engines/content/content-30.csv"
c=$(num "$(idx_count engines/content/content-30.csv)")
head_ok=0
[ -f "$csv" ] && head -1 "$csv" | tr -d ' \r' | grep -qi '^content,platform,scheduled_date,media_note$' && head_ok=1
if [ "$head_ok" = 1 ] && [ "$c" -ge 30 ]; then
  row B sheet "The posting sheet is written" done "$c rows in content-30.csv" content
elif [ "$head_ok" = 0 ] && present engines/content/content-30.csv; then
  row B sheet "The posting sheet is written" "not done" "content-30.csv does not start with the four column header" content
else
  row B sheet "The posting sheet is written" "not done" "$c of 30 rows in content-30.csv" content
fi

n=$(chars "$ge/engines/content/rss-feeds.md")
if [ "$n" -ge 40 ]; then row B refill "A source list for the refill exists" done "$n characters in rss-feeds.md" content
else row B refill "A source list for the refill exists" "not done" "rss-feeds.md is missing or nearly empty" content; fi

a=$(num2 "$(idx_count log/ledger.md)")
if [ "$a" -ge 30 ]; then row B approved "The pieces have been read and approved" done "$a approved in ledger.md" content
else row B approved "The pieces have been read and approved" "not done" "$a of 30 approved in ledger.md" content; fi

self_row B sounds-like "The pieces sound like the founder" content

# --- gate C ------------------------------------------------------------------

seq="$ge/engines/outreach/outreach-sequence.md"
ops="$ge/engines/ops/ops-workflow.md"

ops_row() {
  if [ ! -f "$ops" ] || [ "$(chars "$ops")" -lt 40 ]; then
    row C workflow "The workflow is built" "not done" "ops-workflow.md is missing or nearly empty" ops
    return
  fi
  if has "$ops" 'bottleneck' && has "$ops" 'lead follow.?up|discovery booking|proposal chase|comment.?to.?dm|dm qualify|review request'; then
    row C workflow "The workflow is built" done "ops-workflow.md names the bottleneck and the pack" ops
  elif has "$ops" 'bottleneck'; then
    row C workflow "The workflow is built" "not done" "ops-workflow.md names the bottleneck but no pack" ops
  else
    row C workflow "The workflow is built" "not done" "ops-workflow.md does not name the bottleneck" ops
  fi
}

if [ "$track" = b2b ]; then
  touches=0
  if [ -f "$seq" ]; then
    touches=$(grep -Eic '^#+[[:space:]]*(touch|email|step|day)[^0-9]*[0-9]' "$seq")
    [ "$touches" = 0 ] && touches=$(grep -Eic '^[0-9]+[.)][[:space:]]' "$seq")
  fi
  optouts=0
  [ -f "$seq" ] && optouts=$(grep -Eic 'opt.?out|unsubscribe|reply stop|no thanks|say no|not interested' "$seq")
  if [ "$touches" -ge 4 ] && [ "$touches" -le 5 ] && has "$seq" 'apollo|by hand' && [ "$optouts" -ge "$touches" ]; then
    row C sequence "The route is chosen and the sequence is written" done "$touches touches in outreach-sequence.md, each with a way out" outreach
  elif [ ! -f "$seq" ]; then
    row C sequence "The route is chosen and the sequence is written" "not done" "outreach-sequence.md is missing" outreach
  else
    row C sequence "The route is chosen and the sequence is written" "not done" "$touches touches, $optouts opt out lines, route named: $(has "$seq" 'apollo|by hand' && echo yes || echo no)" outreach
  fi
  if has "$seq" 'tight' && has "$seq" 'medium' && has "$seq" 'broad'; then
    row C criteria "The list criteria are written down" done "tight, medium and broad are all in outreach-sequence.md" outreach
  else
    row C criteria "The list criteria are written down" "not done" "outreach-sequence.md does not hold all three criteria" outreach
  fi
  p=$(num "$(idx_count people/)")
  if carried "people/"; then
    row C list "The list is built" unknown "kept off GitHub, so it cannot be checked on this computer" outreach
  elif [ "$p" -ge 25 ]; then row C list "The list is built" done "$p prospects in people/" outreach
  else row C list "The list is built" "not done" "$p of 25 prospects in people/" outreach; fi
  fl="$ge/engines/outreach/outreach-firstlines.csv"
  c=$(num "$(idx_count engines/outreach/outreach-firstlines.csv)")
  head_ok=0
  [ -f "$fl" ] && head -1 "$fl" | tr -d ' \r' | grep -qi '^email,first_name,company,first_line$' && head_ok=1
  if carried engines/outreach/outreach-firstlines.csv; then
    row C firstlines "First lines exist for the 25" unknown "kept off GitHub, so it cannot be checked on this computer" outreach
  elif [ "$head_ok" = 1 ] && [ "$c" -ge 25 ]; then
    row C firstlines "First lines exist for the 25" done "$c rows in outreach-firstlines.csv" outreach
  else
    row C firstlines "First lines exist for the 25" "not done" "$c of 25 rows in outreach-firstlines.csv" outreach
  fi
  ops_row
  self_row C domain "Domain setup is done and sending has started" outreach
elif [ "$track" = b2c ]; then
  o=$(num "$(idx_count engines/audience/dm-openers.md)")
  if carried engines/audience/dm-openers.md; then
    row C openers "Twenty five openers are written" unknown "kept off GitHub, so it cannot be checked on this computer" audience
  elif [ "$o" -ge 25 ]; then row C openers "Twenty five openers are written" done "$o openers in dm-openers.md" audience
  else row C openers "Twenty five openers are written" "not done" "$o of 25 openers in dm-openers.md" audience; fi
  t=$(num "$(idx_count people/)")
  if carried "people/"; then
    row C targets "Twenty five targets are recorded" unknown "kept off GitHub, so it cannot be checked on this computer" audience
  elif [ "$t" -ge 25 ]; then row C targets "Twenty five targets are recorded" done "$t targets in people/" audience
  else row C targets "Twenty five targets are recorded" "not done" "$t of 25 targets in people/" audience; fi
  if has "$ge/engines/audience/hook-bank.md" '^#+[[:space:]]*offer tests'; then
    row C hooks "A hook bank with offer tests exists" done "hook-bank.md has an Offer tests heading" audience
  else
    row C hooks "A hook bank with offer tests exists" "not done" "hook-bank.md is missing its Offer tests heading" audience
  fi
  n=$(chars "$ge/engines/audience/inbound-scripts.md")
  if [ "$n" -ge 40 ]; then row C inbound "Inbound scripts exist" done "$n characters in inbound-scripts.md" audience
  else row C inbound "Inbound scripts exist" "not done" "inbound-scripts.md is missing or nearly empty" audience; fi
  ops_row
  if has "$ge/.state/setup.md" 'instagram.*done'; then
    row C account "The account is Business or Creator, linked to a Page" done "read from GoHighLevel into .state/setup.md" audience
  else
    self_row C account "The account is Business or Creator, linked to a Page" audience
  fi
  # The 25 go out by hand on the Saturday in Atlanta, so nothing reports them
  # missing before then. The date comes from the cohort block, never from here.
  today=$(date '+%Y%m%d')
  sent=$(num2 "$(idx_count people/)")
  if [ -z "$saturday" ]; then
    row C sends "The messages have been sent" "not due" "the Saturday is not recorded in the cohort block in references/gates.md" audience
  elif [ "$today" -lt "$saturday" ]; then
    row C sends "The messages have been sent" "not due" "they go out by hand from $saturday_words" audience
  elif carried "people/"; then
    row C sends "The messages have been sent" unknown "kept off GitHub, so it cannot be checked on this computer" audience
  elif [ "$sent" -ge 25 ]; then
    row C sends "The messages have been sent" done "$sent people at sent or later" audience
  elif [ "$sent" = 0 ]; then
    row C sends "The messages have been sent" ask "nobody is marked sent yet" audience
  else
    row C sends "The messages have been sent" "not done" "$sent of 25 people at sent or later" audience
  fi
else
  row C track-first "Gate C cannot be checked yet" "not done" "no track chosen, so neither track's items are listed" brain
fi

# --- the engine the founder is on -------------------------------------------

paused="$ge/.state/paused.md"
is_paused() { [ -f "$paused" ] && awk -F '|' -v e="$1" '{ g = $2; gsub(/^[ \t]+|[ \t]+$/, "", g); s = $3; gsub(/^[ \t]+|[ \t]+$/, "", s); if (tolower(g) == tolower(e)) last = tolower(s) } END { exit (last == "paused" ? 0 : 1) }' "$paused"; }

# The engine they are on is the first one with work still to do in the files.
# A question they have not answered yet only counts once no file is short, so a
# single unanswered question does not hold them at gate A while they build.
engine_open() { awk -F '\t' -v e="$1" -v want="$2" '$6 == e && $4 == want { n++ } END { exit (n > 0 ? 0 : 1) }' "$rows"; }

engines=""
for e in brain content outreach audience ops; do
  case $track:$e in b2b:audience|b2c:outreach) continue ;; esac
  case $track:$e in :outreach|:audience|:ops) continue ;; esac
  engines="$engines $e"
done
engine=""
for e in $engines; do
  if engine_open "$e" "not done"; then engine=$e; break; fi
done
if [ -z "$engine" ]; then
  for e in $engines; do
    if engine_open "$e" ask; then engine=$e; break; fi
  done
fi
if [ -z "$engine" ] && [ "$(chars "$ge/engines/plan/90-day-plan.md")" -lt 40 ]; then engine=plan; fi
[ -n "$engine" ] || engine=none

paused_list=$(
  [ -f "$paused" ] && awk -F '|' '{ g = $2; gsub(/^[ \t]+|[ \t]+$/, "", g); s = tolower($3); gsub(/[ \t]/, "", s); if (g != "") state[g] = s }
    END { out = ""; for (g in state) if (state[g] == "paused") out = out (out == "" ? "" : ", ") g; print out }' "$paused"
)
[ -n "$paused_list" ] || paused_list=none

# --- which gate an engine needs ----------------------------------------------

# The one mapping, kept in step with the table in ../references/gates.md:
# content needs Gate A; outreach, audience and ops need Gate B; the plan needs
# Gate C. The Brain needs no gate. An engine that is not on this founder's
# track (outreach for a b2c founder, audience for a b2b one) is left out.
gate_for_engine() {
  case "$1" in
    brain) printf '' ;;
    content) printf A ;;
    outreach|audience|ops) printf B ;;
    plan) printf C ;;
  esac
}

# One shared counting pass per gate, so gate_done() (whether an engine may
# run) and the "Gate X: n of n done" summary line can never disagree about
# what a row means. Prints four numbers: not-done count, total count (every
# row for this gate except "not due"), done count (done + answered), and
# to-confirm count (ask + unknown).
#
# Only "not done" rows block an engine. "ask", "answered" and "unknown" are
# all self-reported or off-this-computer states, never proof that something
# is wrong, so none of them may hold an engine locked. An answer was
# deliberately dropped as a gating requirement by this project's owner, so
# treating "ask" as blocking would put it straight back as paperwork.
gate_counts() {
  awk -F '\t' -v g="$1" '
    $1 == g && $4 != "not due" {
      t++
      if ($4 == "not done") nd++
      else if ($4 == "done" || $4 == "answered") d++
      else if ($4 == "ask" || $4 == "unknown") tc++
    }
    END { printf "%d %d %d %d\n", nd + 0, t + 0, d + 0, tc + 0 }' "$rows"
}

# An engine's gate is met only when the gate has at least one row and none of
# them are "not done". "ask" and "unknown" rows do not block: this is the
# fix for the bug where a self-reported question awaiting an answer, or a
# row hidden by gitignore on a second computer, could lock an engine forever.
gate_done() {
  set -- $(gate_counts "$1")
  gd_nd=$1
  gd_t=$2
  [ "$gd_t" -gt 0 ] && [ "$gd_nd" = 0 ]
}

engine_state() {
  g=$(gate_for_engine "$1")
  if [ -z "$g" ]; then printf 'none'; return; fi
  if gate_done "$g"; then printf 'done'
  elif overridden_for "$1"; then printf 'overridden'
  else printf 'locked'; fi
}

erows="$ge/.state/gate-state.erows.$$"
: > "$erows" || exit 0
for e in brain content outreach audience ops plan; do
  case $track:$e in b2b:audience|b2c:outreach) continue ;; esac
  case $track:$e in :outreach|:audience|:ops) continue ;; esac
  g=$(gate_for_engine "$e")
  printf '%s\t%s\t%s\n' "$e" "${g:-none}" "$(engine_state "$e")" >> "$erows"
done

# --- write it out ------------------------------------------------------------

when=$(date '+%Y-%m-%d %H:%M')
newest_rel=$(printf '%s' "$new_path" | sed "s|^$root/||")
newest_when=$(date -r "$new_path" '+%Y-%m-%d %H:%M' 2>/dev/null || printf -- '-')

tmp="$out.tmp.$$"
{
  printf '# Gate state\n\n'
  printf 'Computed from the folder. Do not edit by hand. What it holds and how to read it: .claude/references/state.md\n\n'
  printf 'Computed: %s\n' "$when"
  printf 'Newest change: %s, %s\n' "${newest_rel:--}" "$newest_when"
  printf 'Stamp: %s\n' "$stamp"
  printf 'Track: %s\n' "${track:-not chosen yet}"
  printf 'Engine in progress: %s\n' "$engine"
  printf 'Paused: %s\n\n' "$paused_list"
  for g in A B C; do
    set -- $(gate_counts "$g")
    gs_nd=$1
    gs_t=$2
    gs_d=$3
    gs_tc=$4
    if [ "$gs_tc" -gt 0 ]; then
      printf 'Gate %s: %s of %s done, %s to confirm\n' "$g" "$gs_d" "$gs_t" "$gs_tc"
    else
      printf 'Gate %s: %s of %s done\n' "$g" "$gs_d" "$gs_t"
    fi
  done
  printf '\n| gate | key | item | state | evidence | engine |\n|---|---|---|---|---|---|\n'
  awk -F '\t' '{ printf "| %s | %s | %s | %s | %s | %s |\n", $1, $2, $3, $4, $5, $6 }' "$rows"
  printf '\nState is done, not done, ask (waiting on the founder), answered (they told us), unknown (kept off GitHub, not in this copy) or not due.\n'
  printf 'An answer is never evidence. Answers live in .state/gate-answers.md.\n'
  printf '\n| engine | needs | state |\n|---|---|---|\n'
  awk -F '\t' '{ printf "| %s | %s | %s |\n", $1, $2, $3 }' "$erows"
  printf '\nEngine state is done, overridden or locked (none for an engine that needs no gate). A locked engine does not start. An override in .state/gate-overrides.md unlocks one engine only, never the gate for every engine that reads it.\n'
} > "$tmp" 2>/dev/null || { rm -f "$tmp" "$rows" "$erows"; exit 0; }

mv "$tmp" "$out" 2>/dev/null
rm -f "$rows" "$erows"
exit 0
