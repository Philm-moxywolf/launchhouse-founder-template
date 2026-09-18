#!/bin/sh
# Checks the computed gate state against a made up folder, so a change to
# gate-state.sh cannot quietly start reading the files wrong.
#
# Usage: sh .claude/tests/state.sh
#
# It builds a throwaway folder in the system temp folder, runs the scripts over
# it, and prints pass or fail for each thing it expects to see. It never touches
# the founder's own growth-engine folder.

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
work=${TMPDIR:-/tmp}/lh-state-test.$$
fail=0

cleanup() { rm -rf "$work"; }
trap cleanup EXIT

mkdir -p "$work/.claude" "$work/growth-engine/.state" "$work/growth-engine/people" \
  "$work/growth-engine/drafts" "$work/growth-engine/inbox/uploads" "$work/growth-engine/brain/voice-samples" \
  "$work/growth-engine/brain" "$work/growth-engine/engines/content" "$work/growth-engine/engines/outreach" \
  "$work/growth-engine/engines/ops" "$work/growth-engine/log" || exit 1
cp -R "$repo/.claude/scripts" "$work/.claude/" || exit 1
cp -R "$repo/.claude/references" "$work/.claude/" || exit 1
: > "$work/growth-engine/.launchhouse"

# Exactly the header the Brain contract writes, bold labels and all, so a
# reader that cannot cope with the real shape of the file fails here.
cat > "$work/growth-engine/brain/founder-brain.md" <<'EOF'
# Founder Brain

- **Founder:** Test Founder
- **Business:** Test Works
- **Track:** b2b
- **Stage:** trading
- **Team:** just them
- **Locked:** 2026-09-08

## Thesis
A long enough thesis line to be past the forty characters that are not spaces.

## Voice
A long enough voice line to be past the forty characters that are not spaces.

## Flags
- [ ] Sending domain is new.
EOF

i=1
{
  printf '# Thirty pieces\n\n'
  while [ "$i" -le 30 ]; do printf '## %s. Piece %s\nA line of body text that is long enough to be real.\n\n' "$i" "$i"; i=$((i + 1)); done
} > "$work/growth-engine/engines/content/content-30.md"

i=1
{
  printf 'content,platform,scheduled_date,media_note\n'
  while [ "$i" -le 30 ]; do printf '"Piece %s body",linkedin,2026-10-01,none\n' "$i"; i=$((i + 1)); done
} > "$work/growth-engine/engines/content/content-30.csv"

i=1
{
  printf '# Ledger\n\n'
  while [ "$i" -le 30 ]; do printf 'C|%s|proof|post|organic|approved||2026-10-01\n' "$i"; i=$((i + 1)); done
} > "$work/growth-engine/log/ledger.md"

i=1
while [ "$i" -le 25 ]; do
  printf 'kind: prospect\nstatus: new\n' > "$work/growth-engine/people/p$i.md"
  i=$((i + 1))
done

i=1
{
  printf 'email,first_name,company,first_line\n'
  while [ "$i" -le 25 ]; do printf 'a%s@example.com,Name%s,Co%s,"A first line"\n' "$i" "$i" "$i"; i=$((i + 1)); done
} > "$work/growth-engine/engines/outreach/outreach-firstlines.csv"

printf '# Refill\n- A trade newsletter the founder already reads every week.\n' > "$work/growth-engine/engines/content/rss-feeds.md"

cat > "$work/growth-engine/engines/outreach/outreach-sequence.md" <<'EOF'
# Sequence

Route: by hand.

## Criteria
Tight: one kind of shop. Medium: the wider trade. Broad: anyone who quotes.

## Touch 1
Say no and I will stop.

## Touch 2
Say no and I will stop.

## Touch 3
Say no and I will stop.

## Touch 4
Say no and I will stop.
EOF

cat > "$work/growth-engine/engines/ops/ops-workflow.md" <<'EOF'
# Workflow
The bottleneck is quotes going out late.
The pack to publish first is Lead follow-up.
The copy is written below and reads like the founder.
EOF

state="$work/growth-engine/.state/gate-state.md"
CLAUDE_PROJECT_DIR="$work" sh "$work/.claude/scripts/gate-state.sh" --force

want() { # description, pattern
  if grep -q "$2" "$state" 2>/dev/null; then
    printf 'PASS  %s\n' "$1"
  else
    printf 'FAIL  %s\n' "$1"; fail=1
  fi
}

want "the track is read from the Brain" '^Track: b2b$'
want "the bold Locked date the contract writes is read" '| brain-locked |.*| done |'
want "gate A is four of five while a question is unanswered, and says so" '^Gate A: 4 of 5 done, 1 to confirm$'
want "thirty pieces count as done" '| pieces |.*| done |'
want "thirty approved count as done" '| approved |.*| done |'
want "the list of 25 counts as done" '| list |.*| done |'
want "an unanswered question waits on the founder" '| domain |.*| ask |'
# Fix 1, the core regression test: a gate with one row still at "ask" (nothing
# on file yet, the founder has not been asked or has not answered) must not
# lock the engine that gate gates. Answering was deliberately dropped as a
# gating requirement, so only a "not done" row may lock an engine.
want "the content engine is not locked by a self-reported item awaiting an answer" '| content | A | done |'
if grep -q '| openers |' "$state"; then printf 'FAIL  the other track is never listed\n'; fail=1; else printf 'PASS  the other track is never listed\n'; fi

# An answer on file turns a question into an answer, never into evidence.
# Through refresh.sh, the way the hook does it, with no --force: recording an
# answer has to change the stamp or the state is never rebuilt.
printf '2026-09-17 | flags | The domain is new, DKIM goes in today\n' >> "$work/growth-engine/.state/gate-answers.md"
CLAUDE_PROJECT_DIR="$work" sh "$work/.claude/scripts/refresh.sh"
want "an answer on file is recorded as an answer" '| flags |.*| answered |'
want "gate A is five of five once it is answered" '^Gate A: 5 of 5 done$'

# A change made with a shell command, not an editing tool, must still land.
sed 's/^C|1|proof|post|organic|approved/C|1|proof|post|organic|draft/' "$work/growth-engine/log/ledger.md" > "$work/ledger.tmp"
mv "$work/ledger.tmp" "$work/growth-engine/log/ledger.md"
CLAUDE_PROJECT_DIR="$work" sh "$work/.claude/scripts/refresh.sh"
want "a shell change is picked up" '| approved |.*29 of 30'

# Parking an engine, then picking it up again.
CLAUDE_PROJECT_DIR="$work" sh "$work/.claude/scripts/park.sh" pause content >/dev/null
want "a parked engine is recorded" '^Paused: content$'
CLAUDE_PROJECT_DIR="$work" sh "$work/.claude/scripts/park.sh" resume content >/dev/null
want "a picked up engine is no longer parked" '^Paused: none$'

# The end of turn check speaks once, then stays quiet.
first=$(printf '{}' | CLAUDE_PROJECT_DIR="$work" sh "$work/.claude/scripts/turn-end.sh")
second=$(printf '{}' | CLAUDE_PROJECT_DIR="$work" sh "$work/.claude/scripts/turn-end.sh")
case $first in
  *systemMessage*) printf 'PASS  the end of turn check says what is missing\n' ;;
  *) printf 'FAIL  the end of turn check says what is missing\n'; fail=1 ;;
esac
if [ -z "$second" ]; then
  printf 'PASS  the end of turn check never repeats itself\n'
else
  printf 'FAIL  the end of turn check never repeats itself\n'; fail=1
fi

# A folder nobody has started. The end of turn check has nothing useful to say,
# so it says nothing and keeps its one line for when the Brain is part written.
fresh=${TMPDIR:-/tmp}/lh-state-fresh.$$
mkdir -p "$fresh/.claude" "$fresh/growth-engine/.state" || exit 1
cp -R "$repo/.claude/scripts" "$fresh/.claude/" || exit 1
cp -R "$repo/.claude/references" "$fresh/.claude/" || exit 1
: > "$fresh/growth-engine/.launchhouse"
CLAUDE_PROJECT_DIR="$fresh" sh "$fresh/.claude/scripts/refresh.sh"
fresh_out=$(printf '{}' | CLAUDE_PROJECT_DIR="$fresh" sh "$fresh/.claude/scripts/turn-end.sh")
if [ -z "$fresh_out" ]; then
  printf 'PASS  a folder nobody has started is never nudged\n'
else
  printf 'FAIL  a folder nobody has started is never nudged\n'; fail=1
fi
rm -rf "$fresh"

# Bug: resuming a parked engine must let the end of turn check speak about it
# again. "content" is still the engine in progress in $work (the sed change
# above left one piece at "draft" instead of "approved"), and the "first" call
# above already wrote it a line in nudges.md, so right now a further call
# would stay silent, same as "second" did. Park it, then pick it back up, and
# the next call must speak again, with a fresh line in nudges.md to show it.
nudges="$work/growth-engine/.state/nudges.md"
if [ -f "$nudges" ] && grep -q "| content |" "$nudges" 2>/dev/null; then
  printf 'PASS  the nudge line for content exists before it is parked\n'
else
  printf 'FAIL  the nudge line for content exists before it is parked\n'; fail=1
fi
CLAUDE_PROJECT_DIR="$work" sh "$work/.claude/scripts/park.sh" pause content >/dev/null
CLAUDE_PROJECT_DIR="$work" sh "$work/.claude/scripts/park.sh" resume content >/dev/null
if grep -q "| content |" "$nudges" 2>/dev/null; then
  printf 'FAIL  resuming an engine clears its old nudge line\n'; fail=1
else
  printf 'PASS  resuming an engine clears its old nudge line\n'
fi
third=$(printf '{}' | CLAUDE_PROJECT_DIR="$work" sh "$work/.claude/scripts/turn-end.sh")
case $third in
  *systemMessage*) printf 'PASS  a resumed engine is nudged again\n' ;;
  *) printf 'FAIL  a resumed engine is nudged again\n'; fail=1 ;;
esac
if grep -q "| content |" "$nudges" 2>/dev/null; then
  printf 'PASS  the fresh nudge for the resumed engine is recorded\n'
else
  printf 'FAIL  the fresh nudge for the resumed engine is recorded\n'; fail=1
fi

# Bug: an item at "not due" must count toward neither the done column nor the
# total. A fresh b2c folder, before the cohort's Saturday, has exactly this:
# the sends row is not due yet, so Gate C should read "0 of 6", not "0 of 7"
# with the not-due row silently counted as done, nor "0 of 7" some other way.
b2c=${TMPDIR:-/tmp}/lh-state-b2c.$$
mkdir -p "$b2c/.claude" "$b2c/growth-engine/.state" "$b2c/growth-engine/brain" || exit 1
cp -R "$repo/.claude/scripts" "$b2c/.claude/" || exit 1
cp -R "$repo/.claude/references" "$b2c/.claude/" || exit 1
: > "$b2c/growth-engine/.launchhouse"
cat > "$b2c/growth-engine/brain/founder-brain.md" <<'EOF'
# Founder Brain

- **Founder:** Test Founder
- **Business:** Test Works
- **Track:** b2c
EOF
CLAUDE_PROJECT_DIR="$b2c" sh "$b2c/.claude/scripts/gate-state.sh" --force
b2c_state="$b2c/growth-engine/.state/gate-state.md"
if grep -q '| sends |.*| not due |' "$b2c_state" 2>/dev/null; then
  printf 'PASS  the sends row is not due before the cohort Saturday\n'
else
  printf 'FAIL  the sends row is not due before the cohort Saturday\n'; fail=1
fi
if grep -q '^Gate C: 0 of 6 done, 1 to confirm$' "$b2c_state" 2>/dev/null; then
  printf 'PASS  a not due item counts toward neither the done nor the total\n'
else
  printf 'FAIL  a not due item counts toward neither the done nor the total\n'; fail=1
fi
rm -rf "$b2c"

# Fix 2: an item kept off GitHub, not present on this computer, must not lock
# an engine either, the same as an "ask" row. A b2b founder's second computer,
# where people/ and the first lines file are absent but were seen on the
# first one, carries their rows forward as unknown, never as missing and
# never as done. Everything else this founder needs for Gate B is done, so
# the outreach engine (which needs Gate B) must read done, not locked.
unk=${TMPDIR:-/tmp}/lh-state-unknown.$$
mkdir -p "$unk/.claude" "$unk/growth-engine/.state" "$unk/growth-engine/brain" \
  "$unk/growth-engine/engines/content" "$unk/growth-engine/engines/outreach" \
  "$unk/growth-engine/engines/ops" "$unk/growth-engine/log" "$unk/growth-engine/people" || exit 1
cp -R "$repo/.claude/scripts" "$unk/.claude/" || exit 1
cp -R "$repo/.claude/references" "$unk/.claude/" || exit 1
cp "$repo/.gitignore" "$unk/.gitignore" || exit 1
: > "$unk/growth-engine/.launchhouse"

cat > "$unk/growth-engine/brain/founder-brain.md" <<'EOF'
# Founder Brain

- **Founder:** Test Founder
- **Business:** Test Works
- **Track:** b2b
- **Stage:** trading
- **Team:** just them
- **Locked:** 2026-09-08

## Thesis
A long enough thesis line to be past the forty characters that are not spaces.

## Voice
A long enough voice line to be past the forty characters that are not spaces.

## Flags
- [ ] Sending domain is new.
EOF

i=1
{
  printf '# Thirty pieces\n\n'
  while [ "$i" -le 30 ]; do printf '## %s. Piece %s\nA line of body text that is long enough to be real.\n\n' "$i" "$i"; i=$((i + 1)); done
} > "$unk/growth-engine/engines/content/content-30.md"

i=1
{
  printf 'content,platform,scheduled_date,media_note\n'
  while [ "$i" -le 30 ]; do printf '"Piece %s body",linkedin,2026-10-01,none\n' "$i"; i=$((i + 1)); done
} > "$unk/growth-engine/engines/content/content-30.csv"

i=1
{
  printf '# Ledger\n\n'
  while [ "$i" -le 30 ]; do printf 'C|%s|proof|post|organic|approved||2026-10-01\n' "$i"; i=$((i + 1)); done
} > "$unk/growth-engine/log/ledger.md"

printf '# Refill\n- A trade newsletter the founder already reads every week.\n' > "$unk/growth-engine/engines/content/rss-feeds.md"

cat > "$unk/growth-engine/engines/outreach/outreach-sequence.md" <<'EOF'
# Sequence

Route: by hand.

## Criteria
Tight: one kind of shop. Medium: the wider trade. Broad: anyone who quotes.

## Touch 1
Say no and I will stop.

## Touch 2
Say no and I will stop.

## Touch 3
Say no and I will stop.

## Touch 4
Say no and I will stop.
EOF

cat > "$unk/growth-engine/engines/ops/ops-workflow.md" <<'EOF'
# Workflow
The bottleneck is quotes going out late.
The pack to publish first is Lead follow-up.
The copy is written below and reads like the founder.
EOF

printf '2026-09-17 | flags | Domain is old, SPF DKIM DMARC all set\n2026-09-17 | domain | Domain is old, sending has started\n' \
  > "$unk/growth-engine/.state/gate-answers.md"

i=1
while [ "$i" -le 25 ]; do
  printf 'kind: prospect\nstatus: candidate\n' > "$unk/growth-engine/people/p$i.md"
  i=$((i + 1))
done
i=1
{
  printf 'email,first_name,company,first_line\n'
  while [ "$i" -le 25 ]; do printf 'a%s@example.com,Name%s,Co%s,"A first line"\n' "$i" "$i" "$i"; i=$((i + 1)); done
} > "$unk/growth-engine/engines/outreach/outreach-firstlines.csv"

( cd "$unk" && git init >/dev/null 2>&1 )
CLAUDE_PROJECT_DIR="$unk" sh "$unk/.claude/scripts/gate-state.sh" --force >/dev/null 2>&1

# Pretend this is a different computer from the one that last saw the private
# files: overwrite the "seen here" marker with a host that is not this one, so
# index.sh's carry-forward treats a now-missing private file as unknown rather
# than as really gone.
mkdir -p "$unk/growth-engine/.state/.pre"
printf 'a-different-computer\n' > "$unk/growth-engine/.state/.pre/private-seen"
rm -rf "$unk/growth-engine/people" "$unk/growth-engine/engines/outreach/outreach-firstlines.csv"
mkdir -p "$unk/growth-engine/people"

unk_state="$unk/growth-engine/.state/gate-state.md"
CLAUDE_PROJECT_DIR="$unk" sh "$unk/.claude/scripts/gate-state.sh" --force >/dev/null 2>&1

want() { # local helper against $unk_state, same shape as the one above
  if grep -q "$2" "$unk_state" 2>/dev/null; then printf 'PASS  %s\n' "$1"; else printf 'FAIL  %s\n' "$1"; fail=1; fi
}
want "the list is unknown on a second computer, not missing and not done" '| list |.*| unknown |'
want "first lines are unknown on a second computer, not missing and not done" '| firstlines |.*| unknown |'
want "the outreach engine is not locked by an unknown row" '| outreach | B | done |'
rm -rf "$unk"

# Bug: the change fingerprint (Stamp) must be stable across repeated runs when
# nothing under growth-engine has changed, on this machine's own stat. Two
# forced runs back to back, no edits in between, must produce the same stamp.
CLAUDE_PROJECT_DIR="$work" sh "$work/.claude/scripts/gate-state.sh" --force
stamp1=$(awk -F ': ' '/^Stamp:/ { print $2; exit }' "$state")
CLAUDE_PROJECT_DIR="$work" sh "$work/.claude/scripts/gate-state.sh" --force
stamp2=$(awk -F ': ' '/^Stamp:/ { print $2; exit }' "$state")
if [ -n "$stamp1" ] && [ "$stamp1" = "$stamp2" ]; then
  printf 'PASS  the stamp is stable across repeated runs with no changes\n'
else
  printf 'FAIL  the stamp is stable across repeated runs with no changes\n'; fail=1
fi

# Bug: "park this" and its kin must only fire at the start of a message or of
# a sentence within it, and never when a "don't", "do not" or "not" opens that
# same sentence. Checked straight against prompt-state.sh, in a folder of its
# own so the founder's questions never touch $work's own state or nudges.
prompt_dir=${TMPDIR:-/tmp}/lh-state-prompt.$$
mkdir -p "$prompt_dir/.claude" "$prompt_dir/growth-engine/.state" || exit 1
cp -R "$repo/.claude/scripts" "$prompt_dir/.claude/" || exit 1
cp -R "$repo/.claude/references" "$prompt_dir/.claude/" || exit 1
: > "$prompt_dir/growth-engine/.launchhouse"
CLAUDE_PROJECT_DIR="$prompt_dir" sh "$prompt_dir/.claude/scripts/refresh.sh"

# description, message, "park"/"resume"/"none" for what must show in the output
prompt_case() {
  desc=$1; msg=$2; want=$3
  json=$(printf '%s' "$msg" | sed 's/\\/\\\\/g; s/"/\\"/g')
  out=$(printf '{"prompt":"%s"}' "$json" | CLAUDE_PROJECT_DIR="$prompt_dir" sh "$prompt_dir/.claude/scripts/prompt-state.sh" 2>/dev/null)
  case $want in
    park) hit=$(printf '%s' "$out" | grep -c '^Parked the') ;;
    resume) hit=$(printf '%s' "$out" | grep -c '^Picked the') ;;
    none) hit=$(printf '%s' "$out" | grep -Ec '^(Parked the|Picked the)') ;;
  esac
  ok=0
  case $want in
    none) [ "$hit" = 0 ] && ok=1 ;;
    *) [ "$hit" -gt 0 ] && ok=1 ;;
  esac
  if [ "$ok" = 1 ]; then printf 'PASS  %s\n' "$desc"; else printf 'FAIL  %s\n' "$desc"; fail=1; fi
}

prompt_case "a question containing park the is not a park" \
  "can we park the Apollo question for later" none
prompt_case "don't pause this is not a park" \
  "don't pause this" none
prompt_case "do not park this yet is not a park" \
  "do not park this yet" none
prompt_case "I don't want to park this is not a park" \
  "I don't want to park this" none
prompt_case "park this parks" \
  "park this" park
prompt_case "Park this please parks, sentence start, mixed case" \
  "Park this please" park
prompt_case "a park phrase after a sentence boundary parks" \
  "let's talk about something else. park this for now" park
prompt_case "pick it back up resumes" \
  "pick it back up" resume
prompt_case "don't pick this back up yet does not resume" \
  "don't pick this back up yet" none

rm -rf "$prompt_dir"

# The founder's voice and first run. These read the files the founder and
# Claude read, so a later edit cannot quietly undo them.
ok() { if [ "$1" = 0 ]; then printf 'PASS  %s\n' "$2"; else printf 'FAIL  %s\n' "$2"; fail=1; fi; }

style="$repo/.claude/output-styles/launchhouse-guide.md"
grep -q '^name: Launchhouse Guide$' "$style" 2>/dev/null && grep -q '^keep-coding-instructions: true$' "$style"
ok $? "the Launchhouse Guide output style is in place"

# The start skill writes this copy into a folder with no CLAUDE.md, so it must
# never drift from the real one.
awk '/^```markdown$/ { buf = ""; f = 1; next } /^```$/ { if (f) last = buf; f = 0; next } f { buf = buf $0 "\n" } END { printf "%s", last }' \
  "$repo/.claude/skills/start/references/scaffold.md" | cmp -s - "$repo/CLAUDE.md"
ok $? "the start skill's copy of CLAUDE.md matches the real one"

dashes=$(printf '\342\200\224|\342\200\223|!')
grep -Eq "$dashes" "$style" "$repo/CLAUDE.md" "$repo/README.md" "$repo/START-HERE.md"
[ $? = 1 ]; ok $? "founder-facing text has no em or en dashes and no exclamation points"

start="$repo/.claude/skills/start/SKILL.md"
grep -q 'Philm-moxywolf.*do not push' "$start"
ok $? "the start skill never pushes to the public original"

grep -q 'AskUserQuestion' "$start" && grep -q 'Pacific time, like Los Angeles or San Diego' "$start" && ! grep -q 'the Europe/London time' "$start"
ok $? "the start skill offers choices and names the timezone the everyday way"

grep -q 'follow the `founder-brain` skill straight away' "$start"
ok $? "a fresh start goes straight into the Founder Brain"

grep -q 'set once, in the Founder Brain intake' "$repo/CLAUDE.md" && ! grep -q 'never ask them which track' "$repo/CLAUDE.md"
ok $? "rule 1 lets the Brain intake ask the track once"

# LH-004 and LH-008: the Brain asks the track and Model with choices, and
# confirms the track it took from "who pays you" before asking it afresh.
brain="$repo/.claude/skills/founder-brain/SKILL.md"
grep -q 'The track and the Model question have predictable answers, so ask them with clickable choices (the AskUserQuestion tool)' "$brain" &&
  grep -q 'If you cannot show choices, as in Cowork, ask the same questions in plain text' "$brain" &&
  grep -q 'ask one more question, with choices' "$brain"
ok $? "the Brain asks the track and Model with choices"

grep -q 'Say the track you took from it in one plain sentence and ask them to confirm it' "$brain" &&
  grep -q 'Ask the full question only when Group 1 did not settle it' "$brain"
ok $? "the Brain confirms the track from who pays them before asking it afresh"

grep -Eq "$dashes" "$brain"
[ $? = 1 ]; ok $? "the Brain skill has no em or en dashes and no exclamation points"

# LH-014: a held data or credit claim in the content engine is asked, never rewritten on a guess.
ce="$repo/.claude/skills/content-engine/SKILL.md"
if grep -q 'A held `claim.data` or `claim.credit` line: ask the founder whether it is true, never rewrite it on a guess' "$ce"; then
  printf 'PASS  %s\n' "the content engine asks about a held data or credit claim"
else
  printf 'FAIL  %s\n' "the content engine asks about a held data or credit claim"; fail=1
fi

# The connections and the playbook insert. No server is shipped: connect-tools
# writes GoHighLevel's when the founder connects, and the key lives in the
# computer's own password store, never a file. The check that an insert is out
# of date must spot a source file changed after it was built.
conn_ok() { if [ "$1" = 0 ]; then printf 'PASS  %s\n' "$2"; else printf 'FAIL  %s\n' "$2"; fail=1; fi; }

[ ! -e "$repo/.mcp.json" ] \
  && ! git -C "$repo" ls-files --error-unmatch .mcp.json >/dev/null 2>&1 \
  && grep -qF '"enabledMcpjsonServers": ["highlevel"]' "$repo/.claude/settings.json" \
  && ! grep -rqF --exclude-dir=tests 'mcp/anthropic' "$repo/.claude" "$repo/START-HERE.md"
conn_ok $? "no server is shipped, and the one connect-tools writes is approved when the app reopens"

ct="$repo/.claude/skills/connect-tools/SKILL.md"
! grep -qi 'connect \*\*HighLevel\*\*' "$repo/START-HERE.md" \
  && grep -qF '"connect my tools"' "$repo/START-HERE.md" \
  && grep -qF 'Claude walks you through GoHighLevel' "$repo/START-HERE.md" \
  && grep -qF 'Keychain Access on a Mac, Credential Manager on a Windows PC' "$repo/START-HERE.md" \
  && ! grep -qF 'no key to paste' "$repo/START-HERE.md" \
  && grep -qF 'sh .claude/scripts/ghl-headers.sh --connect < /dev/null' "$ct"
conn_ok $? "START-HERE and connect-tools send the founder the same way to GoHighLevel: say connect my tools, no connector"
grep -qF 'If this is Cowork, or the check says it works on a Mac or a Windows PC only, stop this part.' "$ct" \
  && grep -qF 'GoHighLevel is connected from Code on this folder, not from Cowork' "$ct" \
  && grep -qF "this check works on a Mac or a Windows PC only" "$repo/.claude/scripts/ghl-headers.sh"
conn_ok $? "in Cowork, connect-tools says GoHighLevel connects from Code and carries on"

# One item name, everywhere it is written.
grep -qF "In **Keychain Item Name**, type \`Launchhouse GoHighLevel\`" "$ct" \
  && grep -qF "In **Internet or network address**, type \`Launchhouse GoHighLevel\`" "$ct" \
  && grep -qF 'The item is named exactly `Launchhouse GoHighLevel`' "$repo/.claude/references/connections.md" \
  && grep -qF "ghl_conn_item='Launchhouse GoHighLevel'" "$repo/.claude/scripts/ghl-store.sh" \
  && grep -qF "ghl_values_item='Launchhouse GoHighLevel values'" "$repo/.claude/scripts/ghl-store.sh" \
  && grep -qF 'the name is exactly `Launchhouse GoHighLevel values`' "$repo/.claude/skills/ghl-values/SKILL.md"
conn_ok $? "connect-tools, ghl-values, the reference and the helper name the same password store items"

# The store is read with what ships with the computer, and never in the chat.
grep -q 'security find-generic-password' "$repo/.claude/scripts/ghl-store.sh" \
  && grep -q 'powershell.exe -NoProfile -NonInteractive -EncodedCommand' "$repo/.claude/scripts/ghl-store.sh" \
  && ! grep -qiE 'Install-Module|Import-Module|CredentialManager' "$repo/.claude/scripts/ghl-store.sh" \
  && grep -qF '"Bash(security find-generic-password:*)"' "$repo/.claude/settings.json" \
  && grep -qF 'never read the password store yourself' "$ct" \
  && grep -qF 'Never read the password store yourself, by any command' "$repo/.claude/references/connections.md"
conn_ok $? "the key is read only with built-in tools, and Claude never reads the store"

# A Private Integration key does not expire on its own (GoHighLevel's help
# pages), so no skill may say it stops after 90 days, and the troubleshooting
# table covers a key that stopped working.
! grep -rqiE 'stops working 90 days|expires? (after|in) 90 days' "$repo/.claude/skills" "$repo/.claude/references" \
  && grep -qF 'does not expire on its own' "$ct" \
  && grep -qF 'do not expire on their own' "$repo/.claude/skills/ghl-values/SKILL.md" \
  && grep -qF '| The key stopped working |' "$ct"
conn_ok $? "connect-tools and ghl-values agree the key does not run out on its own"

# LH-004: the last predictable questions are asked with clickable choices.
grep -qF 'ask with clickable choices (the AskUserQuestion tool): **Yes**, **Not yet**, **Not sure**' "$ct" \
  && grep -qF '**Google (Gmail or Google Workspace)**, **Microsoft 365**, **Something else**' "$repo/.claude/skills/outreach-b2b/SKILL.md" \
  && grep -qF 'Ask each with clickable choices (the AskUserQuestion tool), **Yes** and **No**' "$repo/.claude/skills/apollo-sequence/SKILL.md"
conn_ok $? "connect-tools, outreach-b2b and apollo-sequence ask their predictable questions with choices"

dashes=$(printf '\342\200\224|\342\200\223|!')
! grep -Eq "$dashes" "$ct" "$repo/.claude/references/connections.md" "$repo/.claude/skills/ghl-values/SKILL.md" \
    "$repo/.claude/skills/apollo-sequence/SKILL.md" "$repo/.claude/skills/outreach-b2b/SKILL.md"
conn_ok $? "the connection skills have no em or en dashes and no exclamation points"

grep -qF '### Checking for replies' "$repo/.claude/skills/outreach-b2b/SKILL.md" \
  && grep -qF 'This only reads' "$repo/.claude/skills/outreach-b2b/SKILL.md" \
  && grep -qF 'set their `status` to `replied`' "$repo/.claude/skills/outreach-b2b/SKILL.md" \
  && grep -qF '`outlook_email_search`' "$repo/.claude/references/connections.md" \
  && grep -qF '`search_threads`' "$repo/.claude/references/connections.md"
conn_ok $? "replies are checked read only in Gmail or Microsoft 365 and recorded in the person file"

sed -n '/^| GoHighLevel |/,/^| The mailbox |/p' "$repo/.claude/references/connections.md" | grep -q '| \*\*Apollo.io\*\* |' \
  && grep -q '\*\*Gmail\*\* for Google' "$repo/.claude/references/connections.md" \
  && grep -q '\*\*Microsoft 365\*\* for Microsoft 365' "$repo/.claude/references/connections.md"
conn_ok $? "Apollo, Gmail and Microsoft 365 use Claude's own connectors, named exactly"

grep -q 'Microsoft 365 reads mail but cannot write drafts' "$repo/.claude/references/connections.md" \
  && grep -qF 'Never call a tool that does' "$repo/.claude/references/connections.md" \
  && grep -q 'drafts only, never send' "$repo/.claude/skills/publish-content/SKILL.md"
conn_ok $? "the mailbox is drafts only, and never sends"

pb="$repo/.claude/skills/playbook-export/SKILL.md"
grep -q 'git diff --name-only <version> --' "$pb" && grep -q 'built-from:' "$pb" && grep -q 'playbook-insert.html' "$pb"
conn_ok $? "the playbook skill stamps the insert and checks it before handing it over"

pbdir=${TMPDIR:-/tmp}/lh-state-playbook.$$
mkdir -p "$pbdir/growth-engine/brain" "$pbdir/growth-engine/engines/content" || exit 1
(
  cd "$pbdir" || exit 1
  g() { git -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false "$@" >/dev/null 2>&1; }
  g init
  printf 'brain\n' > growth-engine/brain/founder-brain.md
  printf 'pieces\n' > growth-engine/engines/content/content-30.md
  g add growth-engine && g commit -m "Before the playbook insert"
  version=$(git rev-parse --short HEAD)
  files="growth-engine/brain/founder-brain.md growth-engine/engines/content/content-30.md"
  # Nothing changed yet: the insert is current.
  [ -z "$(git diff --name-only "$version" -- $files)" ] || exit 1
  # An edit not yet saved is caught.
  printf 'pieces, fixed\n' > growth-engine/engines/content/content-30.md
  [ "$(git diff --name-only "$version" -- $files)" = growth-engine/engines/content/content-30.md ] || exit 2
  # And still caught once it is saved.
  g add growth-engine && g commit -m "Fixed a piece"
  [ "$(git diff --name-only "$version" -- $files)" = growth-engine/engines/content/content-30.md ] || exit 3
  exit 0
)
conn_ok $? "a source file changed after the insert was built marks it out of date"
rm -rf "$pbdir"

# Without git, as on a Windows PC with no Git for Windows or a shared Cowork
# folder, git diff fails. The skill must then fall back to file dates, and a
# founder who turns down a rebuild must still get the insert.
nogit=${TMPDIR:-/tmp}/lh-state-nogit.$$
mkdir -p "$nogit/growth-engine/brain" && printf 'brain\n' > "$nogit/growth-engine/brain/founder-brain.md"
( cd "$nogit" && GIT_CEILING_DIRECTORIES="$nogit/.." git diff --name-only none -- growth-engine/brain/founder-brain.md >/dev/null 2>&1 )
nogit_rc=$?
rm -rf "$nogit"
[ "$nogit_rc" != 0 ] && grep -q 'use `none` as the version' "$pb" \
  && grep -q 'look at the date each file on the line was last changed' "$pb" \
  && grep -q 'If they say no, hand it over' "$pb" && ! grep -q 'do not hand it over' "$pb"
conn_ok $? "with no git the insert is checked by file dates, and a founder who says no to a rebuild still gets it"

# LH-028: the folder is standalone. There is no plugin build, and the old
# growth-engine plugin stays switched off here so a founder never gets two copies.
[ ! -e "$repo/.claude/build" ] \
  && grep -q '"growth-engine@launchhouse-v3": false' "$repo/.claude/settings.json" \
  && grep -q 'switches the old `growth-engine` plugin off' "$repo/CLAUDE.md"
ok $? "the folder is standalone: no plugin build, and the old plugin is switched off here"
! grep -q 'extraKnownMarketplaces' "$repo/.claude/settings.json" \
  && ! grep -q 'Philm-moxywolf' "$repo/.claude/settings.json"
ok $? "the settings name no marketplace and nothing from the public original"

# LH-022: folders by kind. The contract table is the one list of paths, and
# lh_place in lib.sh must agree with it row for row.
(
  . "$repo/.claude/scripts/lib.sh" || exit 1
  rows=$(awk -F'|' 'NF > 6 { n = $2; p = $3; gsub(/[ `]/, "", n); gsub(/[ `]/, "", p)
    if (n ~ /^[a-z0-9-]+\.[a-z]+$/ && p ~ /\//) print n, p }' "$repo/.claude/references/contract.md")
  [ "$(printf '%s\n' "$rows" | grep -c .)" = 18 ] || exit 1
  printf '%s\n' "$rows" | while read -r n p; do
    [ "$(lh_place "$n")" = "$p" ] || { echo "$n"; exit 1; }
  done | grep -q . && exit 1
  [ "$(lh_place content-30-2026-09.md)" = engines/content/content-30-2026-09.md ] || exit 1
  exit 0
)
ok $? "the contract table and the checks agree on where every file lives"

# A fresh folder, as the template ships it, is already in the new layout.
tracked=$(git -C "$repo" ls-files growth-engine | sort | tr '\n' ' ')
[ "$tracked" = "growth-engine/.launchhouse growth-engine/.state/.gitkeep growth-engine/.state/index.md growth-engine/brain/voice-samples/.gitkeep growth-engine/drafts/.gitkeep growth-engine/inbox/uploads/.gitkeep growth-engine/log/ledger.md growth-engine/log/memory.md growth-engine/log/ops-log.md growth-engine/people/README.md " ]
ok $? "a fresh folder ships in the new layout, folders by kind"

# index.md is rebuilt by the hooks, but it stays in git: the cloud routines
# read it from the founder's GitHub copy, and it is the only source for the
# people count there, since people/ itself never goes to GitHub. It carries no
# date, so a fresh copy opens clean rather than showing changed on a later day.
git -C "$repo" ls-files growth-engine/.state/index.md | grep -q . \
  && ! ( cd "$repo" && git check-ignore -q --no-index growth-engine/.state/index.md ) \
  && ! grep -Eq '[0-9]{4}-[0-9]{2}-[0-9]{2}' "$repo/growth-engine/.state/index.md"
ok $? "the status file is tracked and carries no date, so a fresh copy opens clean"

# Regenerating index.md twice in a row over an unchanged folder must produce
# the exact same file: nothing in it may vary run to run.
idx_dir=${TMPDIR:-/tmp}/lh-state-idx.$$
mkdir -p "$idx_dir/.claude" "$idx_dir/growth-engine/.state" "$idx_dir/growth-engine/log" || exit 1
cp -R "$repo/.claude/scripts" "$idx_dir/.claude/" || exit 1
: > "$idx_dir/growth-engine/.launchhouse"
: > "$idx_dir/growth-engine/log/ledger.md"
( cd "$idx_dir" && CLAUDE_PROJECT_DIR="$idx_dir" sh .claude/scripts/index.sh </dev/null >/dev/null 2>&1 )
sum1=$(cksum "$idx_dir/growth-engine/.state/index.md" 2>/dev/null)
( cd "$idx_dir" && CLAUDE_PROJECT_DIR="$idx_dir" sh .claude/scripts/index.sh </dev/null >/dev/null 2>&1 )
sum2=$(cksum "$idx_dir/growth-engine/.state/index.md" 2>/dev/null)
[ -n "$sum1" ] && [ "$sum1" = "$sum2" ]
ok $? "regenerating index.md twice over an unchanged folder gives byte for byte the same file"
rm -rf "$idx_dir"

old=0
for f in founder-brain.md content-30.md ledger.md memory.md ops-log.md uploads voice-samples; do
  [ -e "$repo/growth-engine/$f" ] && old=1
done
[ "$old" = 0 ] && ! grep -Eq '^\| (founder-brain|ledger|uploads)' "$repo/growth-engine/.state/index.md" \
  && grep -q '^| log/ledger.md |' "$repo/growth-engine/.state/index.md"
ok $? "nothing in the template is left in the flat layout, and its starter index uses the new paths"

# Real people's details stay out of git at their new paths, and at any depth.
( cd "$repo" && git check-ignore -q --no-index growth-engine/engines/outreach/outreach-firstlines.csv \
  && git check-ignore -q --no-index growth-engine/engines/audience/dm-openers.md \
  && git check-ignore -q --no-index growth-engine/people/sam-example-com.md \
  && git check-ignore -q --no-index growth-engine/outreach-firstlines.csv \
  && ! git check-ignore -q --no-index growth-engine/people/README.md \
  && ! git check-ignore -q --no-index growth-engine/brain/founder-brain.md \
  && ! git check-ignore -q --no-index growth-engine/log/ledger.md )
ok $? "git keeps people, first lines and DM openers out at their new paths, and keeps the rest"

# The move from the older, flat layout. A throwaway git folder with every old
# file in it: tracked files move with git, private ones with a plain move.
mv_dir=${TMPDIR:-/tmp}/lh-state-move.$$
mkdir -p "$mv_dir/.claude" || exit 1
cp -R "$repo/.claude/scripts" "$mv_dir/.claude/" || exit 1
cp "$repo/.gitignore" "$mv_dir/.gitignore" || exit 1
g() { git -C "$mv_dir" -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false "$@" >/dev/null 2>&1; }
mge="$mv_dir/growth-engine"
mkdir -p "$mge/.state" "$mge/people" "$mge/drafts" "$mge/uploads" "$mge/voice-samples" || exit 1
: > "$mge/.launchhouse"
for f in founder-brain.md content-30.md content-30.csv rss-feeds.md hook-bank.md inbound-scripts.md \
         ops-workflow.md ghl-values.md 90-day-plan.md playbook-insert.md playbook-insert.html \
         ledger.md memory.md content-30-2026-08.md; do
  printf 'the founder made %s\n' "$f" > "$mge/$f"
done
printf '# Ops log\n' > "$mge/ops-log.md"
printf 'secret opener for @someone\n' > "$mge/dm-openers.md"
printf 'email,first_name,company,first_line\nsam@example.com,Sam,Co,Hi\n' > "$mge/outreach-firstlines.csv"
printf 'key: sam@example.com\n' > "$mge/people/sam-example-com.md"
printf 'people\n' > "$mge/people/README.md"
printf 'notes from a call\n' > "$mge/uploads/call-notes.md"
: > "$mge/uploads/.gitkeep"
printf 'my newsletter\n' > "$mge/voice-samples/newsletter.md"
printf 'draft\n' > "$mge/drafts/idea.md"
printf 'profile\n' > "$mge/.state/profile.md"
g init; g add -A; g commit -m "The old layout"
ignored_before=$(git -C "$mv_dir" status --porcelain --ignored | grep -c '^!!')

out=$(cd "$mv_dir" && CLAUDE_PROJECT_DIR="$mv_dir" sh .claude/scripts/move-layout.sh < /dev/null)
moved_ok=0
for p in brain/founder-brain.md engines/content/content-30.md engines/content/content-30.csv engines/content/rss-feeds.md \
         engines/content/content-30-2026-08.md engines/audience/hook-bank.md engines/audience/inbound-scripts.md \
         engines/audience/dm-openers.md engines/outreach/outreach-firstlines.csv engines/ops/ops-workflow.md \
         engines/ops/ghl-values.md engines/plan/90-day-plan.md export/playbook-insert.md export/playbook-insert.html \
         log/ledger.md log/memory.md log/ops-log.md inbox/uploads/call-notes.md inbox/uploads/.gitkeep \
         brain/voice-samples/newsletter.md people/sam-example-com.md drafts/idea.md .state/profile.md; do
  [ -f "$mge/$p" ] || { moved_ok=1; printf '  missing after the move: %s\n' "$p"; }
done
[ "$moved_ok" = 0 ] && [ ! -e "$mge/founder-brain.md" ] && [ ! -e "$mge/uploads" ] && [ ! -e "$mge/voice-samples" ] \
  && grep -q 'the founder made founder-brain.md' "$mge/brain/founder-brain.md"
ok $? "the move puts every file of an old folder in its place, word for word"

git -C "$mv_dir" status --porcelain | grep -q '^R  growth-engine/founder-brain.md -> growth-engine/brain/founder-brain.md$' \
  && [ "$(git -C "$mv_dir" status --porcelain | grep -c '^R ')" -ge 15 ]
ok $? "files git keeps are moved with git, so their history follows them"

[ "$(git -C "$mv_dir" status --porcelain --ignored | grep -c '^!!')" = "$ignored_before" ] \
  && ! git -C "$mv_dir" status --porcelain --untracked-files=all | grep -Eq 'dm-openers|firstlines|people/sam' \
  && git -C "$mv_dir" check-ignore -q growth-engine/engines/audience/dm-openers.md \
  && git -C "$mv_dir" check-ignore -q growth-engine/engines/outreach/outreach-firstlines.csv \
  && grep -q 'secret opener' "$mge/engines/audience/dm-openers.md"
ok $? "the private files are moved too, and stay out of git after the move"

grep -q 'note: moved 19 files into folders by kind' "$mge/log/ops-log.md" && grep -q '^# Ops log' "$mge/log/ops-log.md" \
  && printf '%s' "$out" | grep -q 'Moved 19 files'
ok $? "the move leaves one plain note in the ops log and says what it moved"

snap() { ( cd "$mge" && find . -print | sort && find . -type f -exec cksum {} \; | sort ); git -C "$mv_dir" status --porcelain --ignored; }
before=$(snap)
out=$(cd "$mv_dir" && CLAUDE_PROJECT_DIR="$mv_dir" sh .claude/scripts/move-layout.sh < /dev/null)
[ "$before" = "$(snap)" ] && printf '%s' "$out" | grep -q 'Nothing to move'
ok $? "a second run of the move changes nothing"

state_line=$(CLAUDE_PROJECT_DIR="$mv_dir" sh "$mv_dir/.claude/scripts/state-block.sh" < /dev/null)
! printf '%s' "$state_line" | grep -q 'move their files'
ok $? "once moved, the session no longer asks for the move"

# A partial folder: some files already moved, one in both places. Nothing is
# overwritten, and the one in both places is named and left for the founder.
rm -rf "$mv_dir/.git" "$mge"
mkdir -p "$mge/log" "$mge/brain" "$mge/.state" || exit 1
: > "$mge/.launchhouse"
printf 'new brain\n' > "$mge/brain/founder-brain.md"
printf 'old brain\n' > "$mge/founder-brain.md"
printf 'old ledger\n' > "$mge/ledger.md"
printf '# Ops log\n' > "$mge/log/ops-log.md"
g init; g add -A; g commit -m "Half moved"
state_line=$(CLAUDE_PROJECT_DIR="$mv_dir" sh "$mv_dir/.claude/scripts/state-block.sh" < /dev/null)
printf '%s' "$state_line" | grep -q 'move their files'
ok $? "a folder in the older layout is pointed at the start skill, never moved by itself"
out=$(cd "$mv_dir" && CLAUDE_PROJECT_DIR="$mv_dir" sh .claude/scripts/move-layout.sh < /dev/null)
grep -q 'new brain' "$mge/brain/founder-brain.md" && grep -q 'old brain' "$mge/founder-brain.md" \
  && grep -q 'old ledger' "$mge/log/ledger.md" && [ ! -e "$mge/ledger.md" ] \
  && printf '%s' "$out" | grep -q 'founder-brain.md (growth-engine/brain/founder-brain.md is already there)'
ok $? "a partial folder: the rest moves, and a file in both places is never overwritten"
before=$(snap)
out=$(cd "$mv_dir" && CLAUDE_PROJECT_DIR="$mv_dir" sh .claude/scripts/move-layout.sh < /dev/null)
[ "$before" = "$(snap)" ] && ! printf '%s' "$out" | grep -q 'Moved'
ok $? "a second run of a partial move changes nothing"

# Work brought across from the app: the holding folder is put in the new layout
# before it is copied in. It gets no ops log note: it is not the founder's folder yet.
rm -rf "$mv_dir/.git" "$mge"
mkdir -p "$mge/log" "$mge/.state" || exit 1
: > "$mge/.launchhouse"
printf '# Ops log\n' > "$mge/log/ops-log.md"
g init; g add -A; g commit -m "Set up"
hold="$mv_dir/.lh-import/growth-engine"
mkdir -p "$hold/.state" "$hold/people" "$hold/uploads" "$hold/voice-samples" || exit 1
printf 'readme\n' > "$hold/README-your-files.md"
printf '/tmp/ge/abc\n' > "$hold/.state/HOME"
for f in founder-brain.md content-30.md ledger.md memory.md ops-log.md dm-openers.md hook-bank.md; do
  printf 'from the app: %s\n' "$f" > "$hold/$f"
done
printf 'key: ig:helen\n' > "$hold/people/ig-helen.md"
printf 'a menu\n' > "$hold/uploads/menu-pdf.md"
printf 'a caption I wrote\n' > "$hold/voice-samples/caption.md"
out=$(cd "$mv_dir" && CLAUDE_PROJECT_DIR="$mv_dir" sh .claude/scripts/move-layout.sh .lh-import/growth-engine < /dev/null)
[ -f "$hold/brain/founder-brain.md" ] && [ -f "$hold/engines/content/content-30.md" ] && [ -f "$hold/log/ledger.md" ] \
  && [ -f "$hold/engines/audience/dm-openers.md" ] && [ -f "$hold/inbox/uploads/menu-pdf.md" ] \
  && [ -f "$hold/brain/voice-samples/caption.md" ] && [ -f "$hold/people/ig-helen.md" ] \
  && [ -f "$hold/README-your-files.md" ] && [ -f "$hold/.state/HOME" ] \
  && ! grep -q 'moved' "$mge/log/ops-log.md" && printf '%s' "$out" | grep -q 'Moved 9 files'
ok $? "an app import is put in the new layout in its holding folder, and the founder's own log is untouched"
before=$(cd "$hold" && find . -print | sort)
out=$(cd "$mv_dir" && CLAUDE_PROJECT_DIR="$mv_dir" sh .claude/scripts/move-layout.sh .lh-import/growth-engine < /dev/null)
[ "$before" = "$(cd "$hold" && find . -print | sort)" ] && printf '%s' "$out" | grep -q 'Nothing to move'
ok $? "a second run on the import changes nothing"
rm -rf "$mv_dir"

grep -q 'sh .claude/scripts/move-layout.sh < /dev/null' "$repo/.claude/skills/start/SKILL.md" \
  && grep -q 'never by itself at the start of a session' "$repo/.claude/skills/start/SKILL.md" \
  && grep -q 'sh .claude/scripts/move-layout.sh .lh-import/growth-engine < /dev/null' "$repo/.claude/skills/import-from-app/SKILL.md"
ok $? "the start skill runs the move, and the import puts the app's work in the new layout"

# Gates lock, with a way through. A fresh folder with no Brain at all: the
# content engine's gate (A) is not met, so its row in the engine table reads
# locked, and so does ops, which needs Gate B, also not met, and has no
# override on file.
lockdir=${TMPDIR:-/tmp}/lh-state-lock.$$
mkdir -p "$lockdir/.claude" "$lockdir/growth-engine/.state" "$lockdir/growth-engine/brain" || exit 1
cp -R "$repo/.claude/scripts" "$lockdir/.claude/" || exit 1
cp -R "$repo/.claude/references" "$lockdir/.claude/" || exit 1
: > "$lockdir/growth-engine/.launchhouse"
cat > "$lockdir/growth-engine/brain/founder-brain.md" <<'EOF'
# Founder Brain

- **Founder:** Test Founder
- **Business:** Test Works
- **Track:** b2b
EOF
lock_state="$lockdir/growth-engine/.state/gate-state.md"
CLAUDE_PROJECT_DIR="$lockdir" sh "$lockdir/.claude/scripts/gate-state.sh" --force
want() { # local helper against $lock_state, same shape as the one above
  if grep -q "$2" "$lock_state" 2>/dev/null; then printf 'PASS  %s\n' "$1"; else printf 'FAIL  %s\n' "$1"; fail=1; fi
}
want "an unmet gate reports its engine as locked" '| content | A | locked |'
want "a second engine on an unmet gate is locked too, with no override" '| ops | B | locked |'

# Recording an override for one engine only reads that engine as overridden,
# and leaves every other locked engine exactly as it was.
printf '2026-09-18 | A | content | Let us just get started, I will fill in the brain later\n' \
  >> "$lockdir/growth-engine/.state/gate-overrides.md"
CLAUDE_PROJECT_DIR="$lockdir" sh "$lockdir/.claude/scripts/gate-state.sh" --force
want "an override makes its own engine read overridden" '| content | A | overridden |'
want "an override for one engine leaves another engine locked" '| ops | B | locked |'
if grep -q '| A | brain-locked |.*| done |' "$lock_state"; then
  printf 'FAIL  an override never marks the gate itself as done\n'; fail=1
else
  printf 'PASS  an override never marks the gate itself as done\n'
fi

# A gate that is actually met reads its engine as done, override or not.
cat > "$lockdir/growth-engine/brain/founder-brain.md" <<'EOF'
# Founder Brain

- **Founder:** Test Founder
- **Business:** Test Works
- **Track:** b2b
- **Locked:** 2026-09-08

## Thesis
A long enough thesis line to be past the forty characters that are not spaces.

## Voice
A long enough voice line to be past the forty characters that are not spaces.

## Flags
- [ ] Sending domain is new.
EOF
printf '2026-09-18 | flags | Domain is new, DKIM going in today\n' >> "$lockdir/growth-engine/.state/gate-answers.md"
CLAUDE_PROJECT_DIR="$lockdir" sh "$lockdir/.claude/scripts/gate-state.sh" --force
want "a gate that is actually met reads its engine as done" '| content | A | done |'
rm -rf "$lockdir"

# Fix 4, the shell-testable half: an override already on file reads the engine
# as overridden. (The other half, that a skill never adds a second line for
# an engine that already has one, is skill-level behaviour, enforced by the
# wording in each skill's gate-check paragraph, not by this script. There is
# nothing here for a shell test to check beyond gate-state.sh correctly
# reporting "overridden" once a line exists, which the lockdir tests above
# already do: "an override makes its own engine read overridden".)

# Fix 3: with no track chosen, gate-state.md must write no row at all for
# outreach, audience or ops, only content, brain and plan. This is existing,
# intentional behaviour, now written down in gates.md; this test guards it.
notrack=${TMPDIR:-/tmp}/lh-state-notrack.$$
mkdir -p "$notrack/.claude" "$notrack/growth-engine/.state" "$notrack/growth-engine/brain" || exit 1
cp -R "$repo/.claude/scripts" "$notrack/.claude/" || exit 1
cp -R "$repo/.claude/references" "$notrack/.claude/" || exit 1
: > "$notrack/growth-engine/.launchhouse"
cat > "$notrack/growth-engine/brain/founder-brain.md" <<'EOF'
# Founder Brain

- **Founder:** Test Founder
- **Business:** Test Works
EOF
CLAUDE_PROJECT_DIR="$notrack" sh "$notrack/.claude/scripts/gate-state.sh" --force
notrack_state="$notrack/growth-engine/.state/gate-state.md"
want() { # local helper against $notrack_state, same shape as the one above
  if grep -q "$2" "$notrack_state" 2>/dev/null; then printf 'PASS  %s\n' "$1"; else printf 'FAIL  %s\n' "$1"; fail=1; fi
}
if grep -qE '^\| (outreach|audience|ops) \|' "$notrack_state"; then
  printf 'FAIL  no engine row for outreach, audience or ops with no track chosen\n'; fail=1
else
  printf 'PASS  no engine row for outreach, audience or ops with no track chosen\n'
fi
want "the content engine still gets a row with no track chosen" '^| content | A |'
want "the plan engine still gets a row with no track chosen" '^| plan | C |'
rm -rf "$notrack"

# Fix 5: the five gated skills carry the identical refresh-then-read sentence,
# byte for byte apart from the engine name, so they can never drift apart
# again the way they had before this fix.
shared_sentence='Run `sh .claude/scripts/refresh.sh < /dev/null`, then read `growth-engine/.state/gate-state.md`'
skill_miss=0
for f in content-engine outreach-b2b audience-b2c ghl-workflows growth-plan; do
  sf="$repo/.claude/skills/$f/SKILL.md"
  grep -qF "$shared_sentence" "$sf" || { printf 'FAIL  %s carries the shared refresh-then-read sentence\n' "$f"; skill_miss=1; fail=1; }
done
[ "$skill_miss" = 0 ] && printf 'PASS  all five gated skills carry the identical refresh-then-read sentence\n'

# Fix 6: none of the five skills carry the old, unhooked "carry straight on"
# escape when gate-state.md is simply missing.
if grep -rqF 'is not there at all, carry straight on' \
  "$repo/.claude/skills/content-engine/SKILL.md" "$repo/.claude/skills/outreach-b2b/SKILL.md" \
  "$repo/.claude/skills/audience-b2c/SKILL.md" "$repo/.claude/skills/ghl-workflows/SKILL.md" \
  "$repo/.claude/skills/growth-plan/SKILL.md"; then
  printf 'FAIL  no gated skill carries straight on when gate-state.md is missing\n'; fail=1
else
  printf 'PASS  no gated skill carries straight on when gate-state.md is missing\n'
fi

# The settings allow list lets refresh.sh run without a permission prompt, in
# exactly the command form the skills above use.
if grep -qF 'Bash(sh .claude/scripts/refresh.sh < /dev/null)' "$repo/.claude/settings.json"; then
  printf 'PASS  refresh.sh is in the settings allow list\n'
else
  printf 'FAIL  refresh.sh is in the settings allow list\n'; fail=1
fi

# No file anywhere in the repo talks about a form, a hand-off to a mentor, or
# pasting a block into anything: the gates lock and unlock in this folder,
# nowhere else. This test file itself has to hold the patterns to look for
# them, so it is the one file left out of its own search.
form_hits=$(grep -rIn --exclude-dir=.git --exclude=state.sh -i \
  -e 'gate form' -e 'form link' -e 'mentor submission' -e 'gate submission' -e 'gate block' \
  "$repo" 2>/dev/null)
if [ -z "$form_hits" ]; then
  printf 'PASS  %s\n' "no file mentions a gate form, a form link, or pasting a gate block"
else
  printf 'FAIL  %s\n' "no file mentions a gate form, a form link, or pasting a gate block"
  printf '%s\n' "$form_hits"
  fail=1
fi

if [ "$fail" = 0 ]; then
  printf '\nAll state checks passed.\n'
else
  printf '\nSome state checks failed.\n'
fi
exit "$fail"
