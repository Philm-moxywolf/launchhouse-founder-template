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
  "$work/growth-engine/drafts" "$work/growth-engine/uploads" "$work/growth-engine/voice-samples" || exit 1
cp -R "$repo/.claude/scripts" "$work/.claude/" || exit 1
cp -R "$repo/.claude/references" "$work/.claude/" || exit 1
: > "$work/growth-engine/.launchhouse"

# Exactly the header the Brain contract writes, bold labels and all, so a
# reader that cannot cope with the real shape of the file fails here.
cat > "$work/growth-engine/founder-brain.md" <<'EOF'
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
} > "$work/growth-engine/content-30.md"

i=1
{
  printf 'content,platform,scheduled_date,media_note\n'
  while [ "$i" -le 30 ]; do printf '"Piece %s body",linkedin,2026-10-01,none\n' "$i"; i=$((i + 1)); done
} > "$work/growth-engine/content-30.csv"

i=1
{
  printf '# Ledger\n\n'
  while [ "$i" -le 30 ]; do printf 'C|%s|proof|post|organic|approved||2026-10-01\n' "$i"; i=$((i + 1)); done
} > "$work/growth-engine/ledger.md"

i=1
while [ "$i" -le 25 ]; do
  printf 'kind: prospect\nstatus: new\n' > "$work/growth-engine/people/p$i.md"
  i=$((i + 1))
done

i=1
{
  printf 'email,first_name,company,first_line\n'
  while [ "$i" -le 25 ]; do printf 'a%s@example.com,Name%s,Co%s,"A first line"\n' "$i" "$i" "$i"; i=$((i + 1)); done
} > "$work/growth-engine/outreach-firstlines.csv"

printf '# Refill\n- A trade newsletter the founder already reads every week.\n' > "$work/growth-engine/rss-feeds.md"

cat > "$work/growth-engine/outreach-sequence.md" <<'EOF'
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

cat > "$work/growth-engine/ops-workflow.md" <<'EOF'
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
want "gate A is four of five while a question is unanswered" '^Gate A: 4 of 5 done$'
want "thirty pieces count as done" '| pieces |.*| done |'
want "thirty approved count as done" '| approved |.*| done |'
want "the list of 25 counts as done" '| list |.*| done |'
want "an unanswered question waits on the founder" '| domain |.*| ask |'
if grep -q '| openers |' "$state"; then printf 'FAIL  the other track is never listed\n'; fail=1; else printf 'PASS  the other track is never listed\n'; fi

# An answer on file turns a question into an answer, never into evidence.
# Through refresh.sh, the way the hook does it, with no --force: recording an
# answer has to change the stamp or the state is never rebuilt.
printf '2026-09-17 | flags | The domain is new, DKIM goes in today\n' >> "$work/growth-engine/.state/gate-answers.md"
CLAUDE_PROJECT_DIR="$work" sh "$work/.claude/scripts/refresh.sh"
want "an answer on file is recorded as an answer" '| flags |.*| answered |'
want "gate A is five of five once it is answered" '^Gate A: 5 of 5 done$'

# A change made with a shell command, not an editing tool, must still land.
sed 's/^C|1|proof|post|organic|approved/C|1|proof|post|organic|draft/' "$work/growth-engine/ledger.md" > "$work/ledger.tmp"
mv "$work/ledger.tmp" "$work/growth-engine/ledger.md"
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
mkdir -p "$b2c/.claude" "$b2c/growth-engine/.state" || exit 1
cp -R "$repo/.claude/scripts" "$b2c/.claude/" || exit 1
cp -R "$repo/.claude/references" "$b2c/.claude/" || exit 1
: > "$b2c/growth-engine/.launchhouse"
cat > "$b2c/growth-engine/founder-brain.md" <<'EOF'
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
if grep -q '^Gate C: 0 of 6 done$' "$b2c_state" 2>/dev/null; then
  printf 'PASS  a not due item counts toward neither the done nor the total\n'
else
  printf 'FAIL  a not due item counts toward neither the done nor the total\n'; fail=1
fi
rm -rf "$b2c"

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

# LH-014: a held data or credit claim in the content engine is asked, never rewritten on a guess.
ce="$repo/.claude/skills/content-engine/SKILL.md"
if grep -q 'A held `claim.data` or `claim.credit` line: ask the founder whether it is true, never rewrite it on a guess' "$ce"; then
  printf 'PASS  %s\n' "the content engine asks about a held data or credit claim"
else
  printf 'FAIL  %s\n' "the content engine asks about a held data or credit claim"; fail=1
fi

# The connections and the playbook insert. No unproven HighLevel address is
# shipped, and the check that an insert is out of date must spot a source file
# changed after it was built.
conn_ok() { if [ "$1" = 0 ]; then printf 'PASS  %s\n' "$2"; else printf 'FAIL  %s\n' "$2"; fail=1; fi; }

[ ! -e "$repo/.mcp.json" ] && ! grep -rqF --exclude-dir=tests 'mcp/anthropic' "$repo/.claude" "$repo/START-HERE.md"
conn_ok $? "no unproven HighLevel server address is shipped, so nothing asks for approval on first open"

grep -q 'Find \*\*HighLevel\*\* and connect it' "$repo/.claude/skills/connect-tools/SKILL.md" \
  && grep -q 'Connect \*\*HighLevel\*\*' "$repo/START-HERE.md"
conn_ok $? "START-HERE and connect-tools send the founder to the same HighLevel connector"

grep -q 'Microsoft 365 reads mail but cannot write drafts' "$repo/.claude/references/connections.md" \
  && grep -qF 'Never call a tool that does' "$repo/.claude/references/connections.md" \
  && grep -q 'drafts only, never send' "$repo/.claude/skills/publish-content/SKILL.md"
conn_ok $? "the mailbox is drafts only, and never sends"

pb="$repo/.claude/skills/playbook-export/SKILL.md"
grep -q 'git diff --name-only <version> --' "$pb" && grep -q 'built-from:' "$pb" && grep -q 'playbook-insert.html' "$pb"
conn_ok $? "the playbook skill stamps the insert and checks it before handing it over"

pbdir=${TMPDIR:-/tmp}/lh-state-playbook.$$
mkdir -p "$pbdir/growth-engine" || exit 1
(
  cd "$pbdir" || exit 1
  g() { git -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false "$@" >/dev/null 2>&1; }
  g init
  printf 'brain\n' > growth-engine/founder-brain.md
  printf 'pieces\n' > growth-engine/content-30.md
  g add growth-engine && g commit -m "Before the playbook insert"
  version=$(git rev-parse --short HEAD)
  files="growth-engine/founder-brain.md growth-engine/content-30.md"
  # Nothing changed yet: the insert is current.
  [ -z "$(git diff --name-only "$version" -- $files)" ] || exit 1
  # An edit not yet saved is caught.
  printf 'pieces, fixed\n' > growth-engine/content-30.md
  [ "$(git diff --name-only "$version" -- $files)" = growth-engine/content-30.md ] || exit 2
  # And still caught once it is saved.
  g add growth-engine && g commit -m "Fixed a piece"
  [ "$(git diff --name-only "$version" -- $files)" = growth-engine/content-30.md ] || exit 3
  exit 0
)
conn_ok $? "a source file changed after the insert was built marks it out of date"
rm -rf "$pbdir"

# Without git, as on a Windows PC with no Git for Windows or a shared Cowork
# folder, git diff fails. The skill must then fall back to file dates, and a
# founder who turns down a rebuild must still get the insert.
nogit=${TMPDIR:-/tmp}/lh-state-nogit.$$
mkdir -p "$nogit/growth-engine" && printf 'brain\n' > "$nogit/growth-engine/founder-brain.md"
( cd "$nogit" && GIT_CEILING_DIRECTORIES="$nogit/.." git diff --name-only none -- growth-engine/founder-brain.md >/dev/null 2>&1 )
nogit_rc=$?
rm -rf "$nogit"
[ "$nogit_rc" != 0 ] && grep -q 'use `none` as the version' "$pb" \
  && grep -q 'look at the date each file on the line was last changed' "$pb" \
  && grep -q 'If they say no, hand it over' "$pb" && ! grep -q 'do not hand it over' "$pb"
conn_ok $? "with no git the insert is checked by file dates, and a founder who says no to a rebuild still gets it"

if [ "$fail" = 0 ]; then
  printf '\nAll state checks passed.\n'
else
  printf '\nSome state checks failed.\n'
fi
exit "$fail"
