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
grep -q 'git remote rename origin upstream' "$start" && grep -q 'Publish, never Fork' "$start"
ok $? "the start skill never pushes to the public original, and renames it instead of pushing"

# The four states, decided from git alone, in this exact order, and never by
# asking the founder what they did.
grep -q '\*\*State B, cloned the template itself\.\*\*' "$start" \
  && grep -q '\*\*State C, no remote at all\.\*\*' "$start" \
  && grep -q '\*\*State D, `origin` exists and its repo name is `launchhouse-founder-template`\*\*' "$start" \
  && grep -q '\*\*State A, followed the guide\.\*\*' "$start"
ok $? "the start skill names all four states, in order"

grep -q 'No lecture, no extra questions, nothing about forks or publishing' "$start"
ok $? "State A behaves with no lecture, exactly as the governing rule requires"

grep -q 'launchhouse-founder-template`\*\* (case-insensitively), under an owner that is not Philm-moxywolf' "$start" \
  && grep -q 'Never put this check in a hook: it runs here, in the skill, once, only in this state' "$start" \
  && grep -q 'api.github.com/repos/<owner>/<repo>' "$start"
ok $? "State D checks the fork-shaped repo name once, read only, in the skill and never a hook"

grep -q 'anyone can read their business there right now' "$start" \
  && grep -q 'delete that repository on GitHub and publish again privately, or switch it to private' "$start"
ok $? "State D tells a founder on a public fork plainly, and names the fix"

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
  && grep -qF '"enabledMcpjsonServers": ["highlevel"]' "$repo/.claude/settings.json"
conn_ok $? "no server is shipped, and the one connect-tools writes is approved when the app reopens"

# GoHighLevel's address is named only as the v2 connector address: every
# mention of leadconnectorhq.com/mcp/ under .claude (excluding tests) and in
# START-HERE.md is the same /mcp/anthropic/v2 address, never the old bare one.
ct="$repo/.claude/skills/connect-tools/SKILL.md"
mcp_lines=$(grep -rE --exclude-dir=tests 'leadconnectorhq\.com/mcp/' "$repo/.claude" "$repo/START-HERE.md" | wc -l)
mcp_v2_lines=$(grep -rE --exclude-dir=tests 'leadconnectorhq\.com/mcp/anthropic' "$repo/.claude" "$repo/START-HERE.md" | wc -l)
grep -qF 'services.leadconnectorhq.com/mcp/anthropic/v2' "$ct" \
  && grep -qF 'services.leadconnectorhq.com/mcp/anthropic/v2' "$repo/.claude/references/connections.md" \
  && [ "$mcp_lines" = "$mcp_v2_lines" ]
conn_ok $? "only the v2 GoHighLevel address is named anywhere"

! grep -qi 'connect \*\*HighLevel\*\*' "$repo/START-HERE.md" \
  && grep -qF '"connect my tools"' "$repo/START-HERE.md" \
  && grep -qF 'Add custom connector' "$repo/START-HERE.md" \
  && grep -qF 'Add custom connector' "$ct" \
  && grep -qF 'Keychain Access on a Mac or Credential Manager on a Windows PC' "$repo/START-HERE.md" \
  && ! grep -qF 'no key to paste' "$repo/START-HERE.md" \
  && grep -qF 'sh .claude/scripts/ghl-headers.sh --connect < /dev/null' "$ct"
conn_ok $? "START-HERE and connect-tools send the founder the same way to GoHighLevel: say connect my tools, no connector"
grep -qF 'this fallback is for Code only' "$ct" \
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

# ghl-values tries the account connector's custom values operation first, and
# no longer claims GoHighLevel has no custom values tool at all.
! grep -qF 'has no custom values tool at all' "$repo/.claude/skills/ghl-values/SKILL.md" \
  && grep -qF 'Try the connector first' "$repo/.claude/skills/ghl-values/SKILL.md"
conn_ok $? "ghl-values tries the connector before falling back to custom values by hand"

# Connect-tools mentions the disconnect step and asks the approval question,
# each with its own exact wording.
grep -qF 'ghl-headers.sh --disconnect < /dev/null' "$ct"
conn_ok $? "connect-tools tells them how to remove the fallback connection"

grep -qF 'Does GoHighLevel ask you before it posts or sends?' "$ct"
conn_ok $? "connect-tools asks whether GoHighLevel asks before it posts or sends"

# Cowork behaviour is documented in each founder-facing file, in that file's
# own words: none of the Launchhouse checks run there, so the founder's own
# connector setting is what stops a post or a send going out without asking.
grep -qF 'it must stay set to Needs approval' "$repo/CLAUDE.md"
conn_ok $? "CLAUDE.md says the connector setting must stay Needs approval in Cowork"

grep -qF 'your own connector setting for GoHighLevel, set to ask before it posts or sends' "$repo/START-HERE.md"
conn_ok $? "START-HERE says the founder's own connector setting keeps Cowork in their hands"

grep -qF 'in Cowork none of this folder' "$repo/.claude/skills/help/SKILL.md"
conn_ok $? "help says none of this folder's checks run in Cowork"

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

# ------------------------------------------------------------- desktop copies
# Desktop copies: a read-only folder of finished work on the founder's own
# Desktop. LH_DESKTOP stands in for the real Desktop throughout, so this test
# never comes near ~/Desktop. Every git repo below is throwaway, in the temp
# folder, with commit signing off so it works without the machine's own git
# identity configured.

if command -v git >/dev/null 2>&1; then

dt_repo=${TMPDIR:-/tmp}/lh-desktop-repo.$$
dt_desktop="${TMPDIR:-/tmp}/lh desktop - test.$$"
mkdir -p "$dt_repo/.claude" "$dt_repo/growth-engine/.state" "$dt_repo/growth-engine/brain" \
  "$dt_repo/growth-engine/engines/content" "$dt_repo/growth-engine/engines/outreach" \
  "$dt_repo/growth-engine/engines/audience" "$dt_repo/growth-engine/engines/ops" \
  "$dt_repo/growth-engine/engines/plan" "$dt_repo/growth-engine/export" \
  "$dt_repo/growth-engine/people" "$dt_repo/growth-engine/log" "$dt_repo/growth-engine/drafts" \
  "$dt_desktop" || exit 1
cp -R "$repo/.claude/scripts" "$dt_repo/.claude/" || exit 1
: > "$dt_repo/growth-engine/.launchhouse"
cp "$repo/.gitignore" "$dt_repo/.gitignore" 2>/dev/null

dt_g() { git -C "$dt_repo" -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false "$@" >/dev/null 2>&1; }
dt_run() { # extra args after the script name
  s=$1; shift
  CLAUDE_PROJECT_DIR="$dt_repo" LH_DESKTOP="$dt_desktop" sh "$dt_repo/.claude/scripts/$s" "$@" < /dev/null 2>/dev/null
}
dt_lh="$dt_desktop/My Launchhouse work"
dt_ok() { if [ "$1" = 0 ]; then printf 'PASS  %s\n' "$2"; else printf 'FAIL  %s\n' "$2"; fail=1; fi; }

dt_g init

# With nothing finished yet, not even a committed Brain, the Desktop folder
# must never be created at all.
dt_g add growth-engine/.launchhouse
dt_g commit -m "The folder exists, nothing is saved yet"
dt_run desktop-copy.sh >/dev/null
dt_ok $([ ! -e "$dt_lh" ] && echo 0 || echo 1) "no committed Brain means no Desktop folder is created"

cat > "$dt_repo/growth-engine/brain/founder-brain.md" <<'EOF'
# Founder Brain

- **Founder:** Dana Founder
- **Business:** Dana Works
- **Track:** b2b
- **Locked:** 2026-09-08

## Thesis
A long enough thesis line to be past the forty characters that are not spaces.

## Voice
A long enough voice line to be past the forty characters that are not spaces.
EOF
printf '# Thirty pieces\nA piece of content.\n' > "$dt_repo/growth-engine/engines/content/content-30.md"
printf 'content,platform,scheduled_date,media_note\n"A piece",linkedin,2026-10-01,none\n' > "$dt_repo/growth-engine/engines/content/content-30.csv"
printf '# Sequence\nRoute: by hand.\n' > "$dt_repo/growth-engine/engines/outreach/outreach-sequence.md"
printf '# Hooks\nnever copied for a b2b founder\n' > "$dt_repo/growth-engine/engines/audience/hook-bank.md"
printf '# Inbound\nnever copied for a b2b founder\n' > "$dt_repo/growth-engine/engines/audience/inbound-scripts.md"
printf '# Workflow\nThe bottleneck is quotes going out late.\n' > "$dt_repo/growth-engine/engines/ops/ops-workflow.md"
printf '# GoHighLevel values\ncustom values\n' > "$dt_repo/growth-engine/engines/ops/ghl-values.md"
printf '# 90 day plan\nweek one\n' > "$dt_repo/growth-engine/engines/plan/90-day-plan.md"
printf '%%PDF-1.4 a made up playbook insert\n' > "$dt_repo/growth-engine/export/playbook-insert.pdf"
printf 'kind: prospect\n' > "$dt_repo/growth-engine/people/sam.md"
printf 'email,first_name,company,first_line\nsam@example.com,Sam,Co,Hi\n' > "$dt_repo/growth-engine/engines/outreach/outreach-firstlines.csv"
dt_g add -A
dt_g add -f growth-engine/people/sam.md growth-engine/engines/outreach/outreach-firstlines.csv
dt_g commit -m "First saved work"

dt_out=$(dt_run desktop-copy.sh)

# LH_DESKTOP itself, with spaces and a " - " in its own name, was created; the
# script must still find it and only ever create Launchhouse inside it.
dt_ok $([ -d "$dt_lh" ] && echo 0 || echo 1) "the Desktop copies folder is created inside a Desktop path with spaces and a dash"
dt_ok $([ -f "$dt_lh/founder-brain.md" ] && echo 0 || echo 1) "once a Brain is committed, the folder appears with it"

for f in "brain/founder-brain.md founder-brain.md" "engines/content/content-30.md content-30.md" \
         "engines/content/content-30.csv content-30.csv" "engines/outreach/outreach-sequence.md outreach-sequence.md" \
         "engines/ops/ops-workflow.md ops-workflow.md" "engines/ops/ghl-values.md ghl-values.md" \
         "engines/plan/90-day-plan.md 90-day-plan.md" "export/playbook-insert.pdf playbook-insert.pdf"; do
  set -- $f
  dt_ok $([ -f "$dt_lh/$2" ] && echo 0 || echo 1) "the allowlisted file $2 is copied"
done
dt_ok $([ -f "$dt_lh/0 READ ME.md" ] && echo 0 || echo 1) "the read me is written"
dt_ok $([ -f "$dt_lh/.launchhouse-copies" ] && echo 0 || echo 1) "the ownership marker is written"
dt_ok $([ "$(cat "$dt_lh/.launchhouse-copies" 2>/dev/null)" = "$dt_repo" ] && echo 0 || echo 1) "the marker names the founder's own folder"

dt_ok $([ ! -e "$dt_lh/hook-bank.md" ] && [ ! -e "$dt_lh/inbound-scripts.md" ] && echo 0 || echo 1) "the other track's files are never copied"
dt_ok $([ ! -e "$dt_lh/sam.md" ] && [ ! -e "$dt_lh/outreach-firstlines.csv" ] && echo 0 || echo 1) "a force-added private file is never copied, even off the allowlist by name"
[ -w "$dt_lh/founder-brain.md" ] && dt_writable=1 || dt_writable=0
dt_ok $([ "$dt_writable" = 0 ] && echo 0 || echo 1) "a copy is written read-only"

# Unsaved (dirty) changes are never copied: the working tree has a change that
# was never committed, so the copy must still read the old, saved words.
printf '# Thirty pieces\nAn UNSAVED change that must never reach the Desktop.\n' > "$dt_repo/growth-engine/engines/content/content-30.md"
dt_run desktop-copy.sh >/dev/null
dt_ok $(grep -q UNSAVED "$dt_lh/content-30.md" 2>/dev/null && echo 1 || echo 0) "an unsaved change in the working tree is never copied"
dt_g checkout -- growth-engine/engines/content/content-30.md

# The founder edits a copy on their own Desktop: it must be moved into "Your
# edits", and a note queued for state-block.sh to say once, then clear.
chmod u+w "$dt_lh/ops-workflow.md" 2>/dev/null
printf 'the founder typed something here\n' > "$dt_lh/ops-workflow.md"
dt_out=$(dt_run desktop-copy.sh)
dt_ok $([ -d "$dt_lh/Your edits" ] && [ -n "$(ls "$dt_lh/Your edits" 2>/dev/null)" ] && echo 0 || echo 1) "a founder-edited copy is moved into Your edits"
dt_ok $([ -f "$dt_lh/ops-workflow.md" ] && grep -q 'bottleneck' "$dt_lh/ops-workflow.md" 2>/dev/null && echo 0 || echo 1) "a fresh, correct copy is written in its place"
dt_note_line=$(CLAUDE_PROJECT_DIR="$dt_repo" sh "$dt_repo/.claude/scripts/state-block.sh" < /dev/null 2>/dev/null)
dt_ok $(printf '%s' "$dt_note_line" | grep -q 'Desktop copies:' && echo 0 || echo 1) "state-block.sh says the note once"
dt_note_line2=$(CLAUDE_PROJECT_DIR="$dt_repo" sh "$dt_repo/.claude/scripts/state-block.sh" < /dev/null 2>/dev/null)
dt_ok $(printf '%s' "$dt_note_line2" | grep -q 'Desktop copies:' && echo 1 || echo 0) "and never says it again"

# A deleted source moves its copy to Earlier/, never deleting it outright.
rm "$dt_repo/growth-engine/engines/ops/ghl-values.md"
dt_g add -A; dt_g commit -m "Dropped the values file"
dt_run desktop-copy.sh >/dev/null
dt_ok $([ ! -e "$dt_lh/ghl-values.md" ] && [ -n "$(ls "$dt_lh/Earlier"/ghl-values*.md 2>/dev/null)" ] && echo 0 || echo 1) "a deleted source moves its copy to Earlier, and does not delete it"

# Bring the values file back so later assertions about the allowlist are not
# thrown off, and confirm the second run with no new commit writes nothing:
# no git process is spawned by the hook path when HEAD has not moved.
dt_fakebin=${TMPDIR:-/tmp}/lh-desktop-fakebin.$$
mkdir -p "$dt_fakebin"
dt_gitlog="$dt_fakebin/git-calls.log"
cat > "$dt_fakebin/git" <<EOF
#!/bin/sh
echo "\$@" >> "$dt_gitlog"
exec $(command -v git) "\$@"
EOF
chmod +x "$dt_fakebin/git"
: > "$dt_gitlog"
PATH="$dt_fakebin:$PATH" CLAUDE_PROJECT_DIR="$dt_repo" LH_DESKTOP="$dt_desktop" \
  sh "$dt_repo/.claude/scripts/desktop-copy.sh" --hook < /dev/null >/dev/null 2>&1
dt_ok $([ ! -s "$dt_gitlog" ] && echo 0 || echo 1) "the hook path spawns no git process when HEAD has not moved"
rm -rf "$dt_fakebin"

# Two Earlier moves of the same file name must both survive: dated names, and
# a numbered suffix if the two moves land in the same minute.
printf '# GoHighLevel values\nbrought back\n' > "$dt_repo/growth-engine/engines/ops/ghl-values.md"
dt_g add -A; dt_g commit -m "Brought the values file back"
dt_run desktop-copy.sh >/dev/null
dt_ok $([ -f "$dt_lh/ghl-values.md" ] && echo 0 || echo 1) "the values file is copied again once it is back in HEAD"
rm "$dt_repo/growth-engine/engines/ops/ghl-values.md"
dt_g add -A; dt_g commit -m "Dropped the values file again"
dt_run desktop-copy.sh >/dev/null
dt_earlier_count=$(ls "$dt_lh/Earlier"/ghl-values*.md 2>/dev/null | wc -l | tr -d ' ')
dt_ok $([ "$dt_earlier_count" -ge 2 ] && echo 0 || echo 1) "a second file dropped under the same name does not overwrite the first Earlier copy"

# Two founder folders sharing one Desktop: the second one's marker check must
# refuse to write while the first folder still exists, and take over once it
# is gone, never mixing the two folders' files together.
dt_repo2=${TMPDIR:-/tmp}/lh-desktop-repo2.$$
mkdir -p "$dt_repo2/.claude" "$dt_repo2/growth-engine/.state" "$dt_repo2/growth-engine/brain" || exit 1
cp -R "$repo/.claude/scripts" "$dt_repo2/.claude/" || exit 1
: > "$dt_repo2/growth-engine/.launchhouse"
cat > "$dt_repo2/growth-engine/brain/founder-brain.md" <<'EOF'
# Founder Brain

- **Founder:** Other Founder
- **Track:** b2c
EOF
git -C "$dt_repo2" -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false init >/dev/null 2>&1
git -C "$dt_repo2" -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false add -A >/dev/null 2>&1
git -C "$dt_repo2" -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false commit -m "Other founder" >/dev/null 2>&1
CLAUDE_PROJECT_DIR="$dt_repo2" LH_DESKTOP="$dt_desktop" sh "$dt_repo2/.claude/scripts/desktop-copy.sh" < /dev/null >/dev/null 2>&1
dt_ok $([ "$(cat "$dt_lh/.launchhouse-copies" 2>/dev/null)" = "$dt_repo" ] && echo 0 || echo 1) "a foreign marker whose folder still exists blocks the second folder from writing"
dt2_bk_note=$(git -C "$dt_repo2" rev-parse --absolute-git-dir 2>/dev/null)
dt_ok $([ -n "$dt2_bk_note" ] && [ -s "$dt2_bk_note/launchhouse/desktop-note" ] && echo 0 || echo 1) "and a note is queued for the second folder, naming the clash"
dt_note_count_before=$(wc -l < "$dt2_bk_note/launchhouse/desktop-note" 2>/dev/null | tr -d ' ')
CLAUDE_PROJECT_DIR="$dt_repo2" LH_DESKTOP="$dt_desktop" sh "$dt_repo2/.claude/scripts/desktop-copy.sh" < /dev/null >/dev/null 2>&1
dt_note_count_after=$(wc -l < "$dt2_bk_note/launchhouse/desktop-note" 2>/dev/null | tr -d ' ')
dt_ok $([ "$dt_note_count_before" = "$dt_note_count_after" ] && echo 0 || echo 1) "a repeated blocked run queues the same note only once"

rm -rf "$dt_repo"
CLAUDE_PROJECT_DIR="$dt_repo2" LH_DESKTOP="$dt_desktop" sh "$dt_repo2/.claude/scripts/desktop-copy.sh" < /dev/null >/dev/null 2>&1
dt_ok $([ "$(cat "$dt_lh/.launchhouse-copies" 2>/dev/null)" = "$dt_repo2" ] && echo 0 || echo 1) "a marker whose folder is gone is taken over by the next founder folder"
rm -rf "$dt_repo2" "$dt_desktop"

# A folder already called "My Launchhouse work" on the Desktop, with no marker
# in it, was not made by this script (the founder made one themselves, or
# dragged one there). It is foreign: nothing in it is ever touched, and a note
# is queued once, never repeated on every run.
dt_desktop4=${TMPDIR:-/tmp}/lh-desktop4.$$
dt_repo4=${TMPDIR:-/tmp}/lh-desktop-repo4.$$
mkdir -p "$dt_desktop4/My Launchhouse work" "$dt_repo4/.claude" "$dt_repo4/growth-engine/brain" || exit 1
printf 'a file the founder put here themselves\n' > "$dt_desktop4/My Launchhouse work/their-own-file.txt"
cp -R "$repo/.claude/scripts" "$dt_repo4/.claude/" || exit 1
: > "$dt_repo4/growth-engine/.launchhouse"
printf '# Founder Brain\n\n- **Track:** b2b\n' > "$dt_repo4/growth-engine/brain/founder-brain.md"
git -C "$dt_repo4" -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false init >/dev/null 2>&1
git -C "$dt_repo4" -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false add -A >/dev/null 2>&1
git -C "$dt_repo4" -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false commit -m "Markerless folder test" >/dev/null 2>&1
dt_before_snapshot=$(find "$dt_desktop4" -print | sort)
CLAUDE_PROJECT_DIR="$dt_repo4" LH_DESKTOP="$dt_desktop4" sh "$dt_repo4/.claude/scripts/desktop-copy.sh" < /dev/null >/dev/null 2>&1
dt_ok $([ "$dt_before_snapshot" = "$(find "$dt_desktop4" -print | sort)" ] && echo 0 || echo 1) "a markerless pre-existing folder is left completely untouched"
dt4_bk=$(git -C "$dt_repo4" rev-parse --absolute-git-dir 2>/dev/null)
dt_ok $([ -n "$dt4_bk" ] && [ -s "$dt4_bk/launchhouse/desktop-note" ] && [ "$(wc -l < "$dt4_bk/launchhouse/desktop-note" | tr -d ' ')" = 1 ] && echo 0 || echo 1) "and exactly one note is queued about it"
CLAUDE_PROJECT_DIR="$dt_repo4" LH_DESKTOP="$dt_desktop4" sh "$dt_repo4/.claude/scripts/desktop-copy.sh" < /dev/null >/dev/null 2>&1
dt_ok $([ "$(wc -l < "$dt4_bk/launchhouse/desktop-note" | tr -d ' ')" = 1 ] && echo 0 || echo 1) "and running it again does not queue the note a second time"
rm -rf "$dt_desktop4" "$dt_repo4"

# The hard safety guard: a copies path that resolves to the founder's own
# folder root writes nothing at all, silently, no note needed.
dt_desktop5=${TMPDIR:-/tmp}/lh-desktop5.$$
dt_repo5="$dt_desktop5/My Launchhouse work"
mkdir -p "$dt_repo5/.claude" "$dt_repo5/growth-engine/brain" || exit 1
cp -R "$repo/.claude/scripts" "$dt_repo5/.claude/" || exit 1
: > "$dt_repo5/growth-engine/.launchhouse"
printf '# Founder Brain\n\n- **Track:** b2b\n' > "$dt_repo5/growth-engine/brain/founder-brain.md"
git -C "$dt_repo5" -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false init >/dev/null 2>&1
git -C "$dt_repo5" -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false add -A >/dev/null 2>&1
git -C "$dt_repo5" -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false commit -m "Root equals the copies path" >/dev/null 2>&1
CLAUDE_PROJECT_DIR="$dt_repo5" LH_DESKTOP="$dt_desktop5" sh "$dt_repo5/.claude/scripts/desktop-copy.sh" < /dev/null >/dev/null 2>&1
dt_ok $([ ! -e "$dt_repo5/0 READ ME.md" ] && [ ! -e "$dt_repo5/.launchhouse-copies" ] && echo 0 || echo 1) "a copies path equal to the founder's own root writes nothing"
rm -rf "$dt_desktop5"

# The hard safety guard: a copies folder that is itself a real Launchhouse
# folder (carries growth-engine/.launchhouse) writes nothing, and this is not
# the "foreign folder" case, so no note is queued either.
dt_desktop6=${TMPDIR:-/tmp}/lh-desktop6.$$
mkdir -p "$dt_desktop6/My Launchhouse work/growth-engine"
: > "$dt_desktop6/My Launchhouse work/growth-engine/.launchhouse"
dt_repo6=${TMPDIR:-/tmp}/lh-desktop-repo6.$$
mkdir -p "$dt_repo6/.claude" "$dt_repo6/growth-engine/brain" || exit 1
cp -R "$repo/.claude/scripts" "$dt_repo6/.claude/" || exit 1
: > "$dt_repo6/growth-engine/.launchhouse"
printf '# Founder Brain\n\n- **Track:** b2b\n' > "$dt_repo6/growth-engine/brain/founder-brain.md"
git -C "$dt_repo6" -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false init >/dev/null 2>&1
git -C "$dt_repo6" -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false add -A >/dev/null 2>&1
git -C "$dt_repo6" -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false commit -m "Copies folder is itself a Launchhouse folder" >/dev/null 2>&1
CLAUDE_PROJECT_DIR="$dt_repo6" LH_DESKTOP="$dt_desktop6" sh "$dt_repo6/.claude/scripts/desktop-copy.sh" < /dev/null >/dev/null 2>&1
dt_ok $([ ! -e "$dt_desktop6/My Launchhouse work/founder-brain.md" ] && [ ! -e "$dt_desktop6/My Launchhouse work/.launchhouse-copies" ] && echo 0 || echo 1) "a copies folder that is itself a real Launchhouse folder writes nothing"
dt6_bk=$(git -C "$dt_repo6" rev-parse --absolute-git-dir 2>/dev/null)
dt_ok $([ -n "$dt6_bk" ] && [ ! -s "$dt6_bk/launchhouse/desktop-note" ] && echo 0 || echo 1) "and no note is queued for it, since nothing could safely be said"
rm -rf "$dt_desktop6" "$dt_repo6"

# CLAUDE_CODE_SESSION_ATTENDED=0 (a cloud routine): never writes to the
# Desktop, because nobody is there to see it and it may not even exist there.
dt_repo3=${TMPDIR:-/tmp}/lh-desktop-repo3.$$
dt_desktop3=${TMPDIR:-/tmp}/lh-desktop3.$$
mkdir -p "$dt_repo3/.claude" "$dt_repo3/growth-engine/brain" "$dt_desktop3" || exit 1
cp -R "$repo/.claude/scripts" "$dt_repo3/.claude/" || exit 1
: > "$dt_repo3/growth-engine/.launchhouse"
printf '# Founder Brain\n\n- **Track:** b2b\n' > "$dt_repo3/growth-engine/brain/founder-brain.md"
git -C "$dt_repo3" -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false init >/dev/null 2>&1
git -C "$dt_repo3" -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false add -A >/dev/null 2>&1
git -C "$dt_repo3" -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false commit -m "Attended test" >/dev/null 2>&1
CLAUDE_CODE_SESSION_ATTENDED=0 CLAUDE_PROJECT_DIR="$dt_repo3" LH_DESKTOP="$dt_desktop3" \
  sh "$dt_repo3/.claude/scripts/desktop-copy.sh" < /dev/null >/dev/null 2>&1
dt_ok $([ ! -e "$dt_desktop3/My Launchhouse work" ] && echo 0 || echo 1) "an unattended session (a cloud routine) never writes to the Desktop"

# A missing Desktop is skipped, and never created.
dt_desktop_missing="$dt_desktop3/does-not-exist-Desktop"
CLAUDE_PROJECT_DIR="$dt_repo3" LH_DESKTOP="$dt_desktop_missing" \
  sh "$dt_repo3/.claude/scripts/desktop-copy.sh" < /dev/null >/dev/null 2>&1
dt_ok $([ ! -e "$dt_desktop_missing" ] && echo 0 || echo 1) "a Desktop path that does not exist is skipped, and never created"
rm -rf "$dt_repo3" "$dt_desktop3"

fi

# ghl-op.sh: it exists, is plain POSIX sh, is sourced as a library by
# mcp-guard.sh (the one PreToolUse ^mcp__ dispatcher named in settings.json),
# and ghl-headers.sh points at the v2 endpoint everywhere it names
# GoHighLevel's address.
ghlop="$repo/.claude/scripts/ghl-op.sh"
[ -f "$ghlop" ] && head -1 "$ghlop" | grep -qx '#!/bin/sh'
conn_ok $? "ghl-op.sh exists and starts with a plain POSIX shebang"
! grep -Eq '\[\[|\barray\b|\blocal\b' "$ghlop"
conn_ok $? "ghl-op.sh has no bashisms"
[ "$(grep -c '"matcher": "\^mcp__"' "$repo/.claude/settings.json")" = 1 ] \
  && grep -A 4 '"matcher": "\^mcp__"' "$repo/.claude/settings.json" | grep -qF 'mcp-guard.sh' \
  && grep -qF 'ghl-op.sh' "$repo/.claude/scripts/mcp-guard.sh" \
  && ! grep -q 'deny-mcp.sh\|ask-mcp.sh' "$repo/.claude/settings.json"
conn_ok $? "settings.json routes every mcp__ call through mcp-guard.sh, which sources ghl-op.sh, with no leftover deny-mcp.sh/ask-mcp.sh routing"
grep -qF 'ghl=https://services.leadconnectorhq.com/mcp/anthropic/v2' "$repo/.claude/scripts/ghl-headers.sh"
conn_ok $? "ghl-headers.sh points the fallback connection at the v2 endpoint"

# --------------------------------------------------------------------------
# setup-check.sh: silent when the folder is fine, one plain instruction line
# per problem when it is not, mention-once per session id, a cloud session
# says only the cloud line, and the whole check is fast. Isolated from the
# developer's own git config with GIT_CONFIG_GLOBAL and GIT_CONFIG_SYSTEM
# pointed at /dev/null, so a global identity on this machine cannot mask a
# missing one in the test repo.
sc_ok() { if [ "$1" = 0 ]; then printf 'PASS  %s\n' "$2"; else printf 'FAIL  %s\n' "$2"; fail=1; fi; }

sc_dir=${TMPDIR:-/tmp}/lh-setup-check.$$
mkdir -p "$sc_dir/.claude" "$sc_dir/growth-engine/.state" "$sc_dir/growth-engine/log" "$sc_dir/growth-engine/brain" || exit 1
cp -R "$repo/.claude/scripts" "$sc_dir/.claude/" || exit 1
cp "$repo/.claude/settings.json" "$sc_dir/.claude/settings.json" || exit 1
: > "$sc_dir/growth-engine/.launchhouse"
: > "$sc_dir/growth-engine/log/ledger.md"
(
  cd "$sc_dir" || exit 1
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
  git init -q
  git config user.name "Test Founder"
  git config user.email "test@example.com"
  git add -A
  git -c commit.gpgsign=false commit -q -m "baseline"
  git remote add origin https://github.com/test-founder/launchhouse-founder-template.git
) >/dev/null 2>&1

sc_run() { # session_id [more env, e.g. CLAUDE_CODE_REMOTE=true]
  sid=$1; shift
  ( cd "$sc_dir" && GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
      CLAUDE_PROJECT_DIR="$sc_dir" env "$@" sh .claude/scripts/setup-check.sh "$sid" < /dev/null 2>/dev/null )
}
sc_run_full() { # session_id, --full mode, bypasses the once-per-session sentinel
  sid=$1
  ( cd "$sc_dir" && GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
      CLAUDE_PROJECT_DIR="$sc_dir" sh .claude/scripts/setup-check.sh --full "$sid" < /dev/null 2>/dev/null )
}

# A fresh, correctly set up folder still gets the every-session Connectors
# guidance (a script can never see a connector itself), so "silent" here
# means no "Setup:" problem line, not a wholly empty reply.
out=$(sc_run sess-good-1)
! printf '%s' "$out" | grep -q '^Setup:'
sc_ok $? "a correctly set up folder prints no Setup problem line"

git -C "$sc_dir" config --unset user.email
out=$(sc_run sess-noemail)
case $out in *'does not have a name and email set'*) r=0 ;; *) r=1 ;; esac
sc_ok $r "a missing git identity prints its line"
git -C "$sc_dir" config user.email "test@example.com"
out=$(sc_run sess-email-restored)
! printf '%s' "$out" | grep -q '^Setup:'
sc_ok $? "restoring the identity leaves no Setup problem line, in a fresh session"

git -C "$sc_dir" remote set-url origin https://github.com/Philm-moxywolf/launchhouse-founder-template.git
out=$(sc_run sess-origin-https)
case $out in *'Philm-moxywolf'*) r=0 ;; *) r=1 ;; esac
sc_ok $r "an origin pointed at the public original (https) prints its line"

git -C "$sc_dir" remote set-url origin git@github.com:PHILM-MOXYWOLF/launchhouse-founder-template.git
out=$(sc_run sess-origin-ssh)
case $out in *'Philm-moxywolf'*) r=0 ;; *) r=1 ;; esac
sc_ok $r "the origin check matches case-insensitively, and an ssh form"

sc_bk=$(git -C "$sc_dir" rev-parse --absolute-git-dir 2>/dev/null)/launchhouse
mkdir -p "$sc_bk"
: > "$sc_bk/maintainer"
out=$(sc_run sess-maintainer)
case $out in *'Philm-moxywolf'*) r=1 ;; *) r=0 ;; esac
sc_ok $r "an untracked maintainer marker suppresses the origin warning"
rm -f "$sc_bk/maintainer"
git -C "$sc_dir" remote set-url origin https://github.com/test-founder/launchhouse-founder-template.git

# No copy on GitHub at all: no remote named origin (or any remote) prints the
# new line, --full bypasses the once-per-session sentinel the same way the
# other setup-check cases above do.
git -C "$sc_dir" remote remove origin
out=$(sc_run_full sess-no-origin)
case $out in *'no copy on GitHub yet'*) r=0 ;; *) r=1 ;; esac
sc_ok $r "no remote at all prints the no-copy-on-GitHub line"

# Suppressed once an untracked .git/launchhouse/no-github marker exists (the
# start skill writes this when a founder says not now to GitHub).
: > "$sc_bk/no-github"
out=$(sc_run_full sess-no-origin-declined)
case $out in *'no copy on GitHub yet'*) r=1 ;; *) r=0 ;; esac
sc_ok $r "the no-github marker suppresses the no-copy-on-GitHub line"
rm -f "$sc_bk/no-github"
git -C "$sc_dir" remote add origin https://github.com/test-founder/launchhouse-founder-template.git

# The public-original problem line now points at publishing, never a mentor.
git -C "$sc_dir" remote set-url origin https://github.com/Philm-moxywolf/launchhouse-founder-template.git
out=$(sc_run_full sess-origin-publish)
case $out in *'Philm-moxywolf'*'publish'*) r=0 ;; *) r=1 ;; esac
sc_ok $r "the public-original line points at publishing a fresh copy"
case $out in *mentor*) r=1 ;; *) r=0 ;; esac
sc_ok $r "and it no longer tells them to show a mentor"
git -C "$sc_dir" remote set-url origin https://github.com/test-founder/launchhouse-founder-template.git

# State A, unambiguous: a founder's own, differently named private repo.
# setup-check is a hook, and State D's fork check only ever runs inside the
# start skill, so a hook must never print anything about GitHub here.
git -C "$sc_dir" remote set-url origin https://github.com/sam-founder/my-launchhouse.git
out=$(sc_run_full sess-state-a)
case $out in *GitHub*|*Philm-moxywolf*) r=1 ;; *) r=0 ;; esac
sc_ok $r "State A: a founder's own repo prints nothing about GitHub from the hook"
git -C "$sc_dir" remote set-url origin https://github.com/test-founder/launchhouse-founder-template.git

cp "$sc_dir/.claude/settings.json" "$sc_dir/.claude/settings.json.bak"
sed 's/Launchhouse Guide/Something Else/' "$sc_dir/.claude/settings.json.bak" > "$sc_dir/.claude/settings.json"
out=$(sc_run sess-style-bad)
case $out in *"settings.json is missing a piece"*) r=0 ;; *) r=1 ;; esac
sc_ok $r "settings.json not selecting the output style prints its line"
mv "$sc_dir/.claude/settings.json.bak" "$sc_dir/.claude/settings.json"

mv "$sc_dir/growth-engine/log/ledger.md" "$sc_dir/growth-engine/log/ledger.md.bak"
out=$(sc_run sess-scaffold-bad)
case $out in *'growth-engine scaffold'*) r=0 ;; *) r=1 ;; esac
sc_ok $r "a missing scaffold file prints its line and offers start launchhouse"
mv "$sc_dir/growth-engine/log/ledger.md.bak" "$sc_dir/growth-engine/log/ledger.md"

# Mention-once: the same session id never repeats the setup notice, even once
# a new problem appears in the same session (resume or clear firing again).
out1=$(sc_run sess-once)
[ -z "$out1" ] || printf 'note: baseline was not clean going into the mention-once test\n'
git -C "$sc_dir" config --unset user.email
out2=$(sc_run sess-once)
git -C "$sc_dir" config user.email "test@example.com"
[ -z "$out2" ]
sc_ok $? "the same session id says the setup notice at most once"

# A different session id is not deduplicated against another.
git -C "$sc_dir" config --unset user.email
out3=$(sc_run sess-fresh-for-dedup)
git -C "$sc_dir" config user.email "test@example.com"
case $out3 in *'does not have a name and email set'*) r=0 ;; *) r=1 ;; esac
sc_ok $r "a different session id gets its own notice"

# Cloud: only the one line, nothing else, even with a broken identity.
git -C "$sc_dir" config --unset user.email
out=$(sc_run sess-cloud CLAUDE_CODE_REMOTE=true)
git -C "$sc_dir" config user.email "test@example.com"
case $out in
  *'this is a cloud session'*"$(printf '\n')") lines=$(printf '%s' "$out" | grep -c .); [ "$lines" = 1 ] && r=0 || r=1 ;;
  *'this is a cloud session'*) lines=$(printf '%s' "$out" | grep -c .); [ "$lines" = 1 ] && r=0 || r=1 ;;
  *) r=1 ;;
esac
sc_ok $r "a cloud session prints only the one cloud line, nothing else"

# --full (the help skill): ignores the say-it-once sentinel and always says
# something, an all-clear line when nothing is wrong.
out=$( ( cd "$sc_dir" && GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
    CLAUDE_PROJECT_DIR="$sc_dir" sh .claude/scripts/setup-check.sh --full sess-once 2>/dev/null ) )
[ -n "$out" ]
sc_ok $? "check my setup (--full) always says something, even for an already-seen session"

# Timing: the whole check, cold, well under a second.
sc_t0=$(date +%s%N 2>/dev/null || date +%s)
sc_run sess-timing >/dev/null
sc_t1=$(date +%s%N 2>/dev/null || date +%s)
if printf '%s' "$sc_t0" | grep -q '.\{10,\}'; then
  sc_ms=$(( (sc_t1 - sc_t0) / 1000000 ))
  [ "$sc_ms" -lt 1000 ]
  sc_ok $? "setup-check.sh runs in under a second"
else
  printf 'PASS  setup-check.sh runs in under a second (coarse clock, not measured)\n'
fi

rm -rf "$sc_dir"

grep -qF 'sh "$(dirname "$0")/setup-check.sh"' "$repo/.claude/scripts/context.sh"
conn_ok $? "context.sh calls setup-check.sh"

# Behavioural: a folder with a broken setup (no git identity) says so on a
# plain SessionStart, but says nothing extra on --compact, which only adds
# the do-not-restart note.
cc_dir=${TMPDIR:-/tmp}/lh-compact-check.$$
mkdir -p "$cc_dir/.claude" "$cc_dir/growth-engine/.state" "$cc_dir/growth-engine/log" "$cc_dir/growth-engine/brain" || exit 1
cp -R "$repo/.claude/scripts" "$cc_dir/.claude/" || exit 1
cp "$repo/.claude/settings.json" "$cc_dir/.claude/settings.json" || exit 1
: > "$cc_dir/growth-engine/.launchhouse"
: > "$cc_dir/growth-engine/log/ledger.md"
(
  cd "$cc_dir" || exit 1
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
  git init -q
  git remote add origin https://github.com/test-founder/launchhouse-founder-template.git
  git add -A
  git -c commit.gpgsign=false -c user.name=Test -c user.email=test@example.com commit -q -m baseline
) >/dev/null 2>&1
cc_plain=$( cd "$cc_dir" && GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null CLAUDE_PROJECT_DIR="$cc_dir" sh .claude/scripts/context.sh < /dev/null 2>/dev/null )
cc_compact=$( cd "$cc_dir" && GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null CLAUDE_PROJECT_DIR="$cc_dir" sh .claude/scripts/context.sh --compact < /dev/null 2>/dev/null )
printf '%s' "$cc_plain" | grep -q '^Setup: git does not have a name and email set'
conn_ok $? "a plain SessionStart reports the broken identity through context.sh"
! printf '%s' "$cc_compact" | grep -q '^Setup:'
conn_ok $? "context.sh never calls setup-check.sh on a compact SessionStart"
rm -rf "$cc_dir"
grep -qF 'check my setup' "$repo/.claude/skills/help/SKILL.md" 2>/dev/null || grep -qF 'setup-check.sh' "$repo/.claude/skills/help/SKILL.md"
conn_ok $? "the help skill runs the setup check in full"

if [ "$fail" = 0 ]; then
  printf '\nAll state checks passed.\n'
else
  printf '\nSome state checks failed.\n'
fi
exit "$fail"
