#!/bin/sh
# Checks that AGENTS.md exists at the repo root and actually carries the
# generalised update-bootstrap steps any AI agent needs -- not just that the
# file happens to exist -- and that README.md and CLAUDE.md point to it.
#
# Usage: sh .claude/tests/agents-doc.sh [repo-root]
#
# Exits 0 when every check passes, non-zero when any FAIL.

# An older updater leaks LH_UPDATE_RELOCATED and LH_UPDATE_ROOT into the checks
# it runs and never unsets them; clear both here, before anything else runs, so
# a nested update.sh call below can never mistake the founder's real folder
# for its own root.
unset LH_UPDATE_RELOCATED LH_UPDATE_ROOT

here=$(cd "$(dirname "$0")" && pwd) || exit 1
default_root=$(cd "$here/../.." && pwd) || exit 1
root=${1:-$default_root}
root=$(cd "$root" 2>/dev/null && pwd) || { echo "agents-doc: bad repo root: $1" >&2; exit 1; }

fail=0
ok() { if [ "$1" = 0 ]; then printf 'PASS  %s\n' "$2"; else printf 'FAIL  %s\n' "$2"; fail=1; fi; }

agents="$root/AGENTS.md"
skill="$root/.claude/skills/launchhouse-update/SKILL.md"

[ -f "$agents" ]
ok $? "AGENTS.md exists at the repo root"

if [ ! -f "$agents" ]; then
  printf '\nSome agents-doc checks failed.\n'
  exit 1
fi

# The canonical upstream address in AGENTS.md must be byte for byte the same
# one the older-copy path in the update skill already uses -- two different
# spellings of "the real Launchhouse source" is exactly the kind of thing an
# injected fake address could hide behind.
lh_canon_re='https://github\.com/Philm-moxywolf/launchhouse-founder-template\.git'
agents_canon=$(grep -ohE "$lh_canon_re" "$agents" | sort -u)
skill_canon=$(grep -ohE "$lh_canon_re" "$skill" 2>/dev/null | sort -u)
[ -n "$agents_canon" ] && [ "$agents_canon" = "$skill_canon" ]
ok $? "the canonical upstream address in AGENTS.md matches the one in the update skill"

grep -q 'launchhouse-upstream' "$agents"
ok $? "AGENTS.md names the trust check against .claude/launchhouse-upstream / the canonical address"

grep -q 'upstream address is not the Launchhouse original\|stop: tell the founder' "$agents"
ok $? "AGENTS.md says to stop rather than fetch or run anything when the upstream address does not match"

grep -q 'bootstrap' "$agents" && grep -q 'launchhouse/bootstrap' "$agents"
ok $? "AGENTS.md names the <gitdir>/launchhouse/bootstrap/ path"

grep -q 'update.sh' "$agents" && grep -q 'lib.sh' "$agents"
ok $? "AGENTS.md says to copy both update.sh and lib.sh from upstream"

grep -q "upstream/main:.claude/skills/launchhouse-update/SKILL.md" "$agents"
ok $? "AGENTS.md says to follow upstream's own SKILL.md, not the local copy"

grep -q '600000' "$agents"
ok $? "AGENTS.md names the 600000 ms (ten minute) timeout for --plan and --apply"

grep -q 'growth-engine' "$agents"
ok $? "AGENTS.md says growth-engine/ is never touched by an update"

# README.md and CLAUDE.md must each point an agent at AGENTS.md.
grep -q 'AGENTS.md' "$root/README.md" 2>/dev/null
ok $? "README.md points to AGENTS.md"

grep -q 'AGENTS.md' "$root/CLAUDE.md" 2>/dev/null
ok $? "CLAUDE.md points to AGENTS.md"

# The update skill's older-copy trigger must cover a present-but-stale
# update.sh, not only a missing one, so a founder on an old updater still
# gets the newest one instead of silently running their own copy forever.
grep -q 'differs from upstream' "$skill" 2>/dev/null
ok $? "SKILL.md's older-copy trigger covers update.sh differing from upstream, not only being missing"

# The founder only ever hears three outcomes from an update: plain success,
# success with an ordinary improvement held back for next time, and stopped
# with nothing changed. The held-back outcome is easy to drop when a skill
# is edited later, so it gets its own check, not just a general skim.
grep -q 'held=' "$skill" 2>/dev/null
ok $? "SKILL.md names the held=<note id> outcome from --apply"

grep -qi 'held back' "$skill" 2>/dev/null
ok $? "SKILL.md tells Claude to say plainly when an improvement was held back"

# Nothing here may ever tell Claude to hand the founder technical text to
# relay elsewhere (a check name, a log, a file path, a raw reason string) --
# that is exactly the kind of thing that turns "the update stopped" into a
# support burden the founder cannot carry. A few narrow, known-safe phrases
# that talk ABOUT this rule (not violations of it) are allowed through.
relay_hits=$(grep -inE 'copy (and paste|this|the (error|log|reason|output))|paste (this|it|the)|relay (this|it|the)|send (them|him|her) the log|read (them|him|her) the log|share the log' "$skill" 2>/dev/null | grep -vi 'never ask them to copy\|never .*relay')
[ -z "$relay_hits" ]
ok $? "SKILL.md never tells Claude to have the founder copy, paste, or relay technical output"

# A clean stop (result=reverted) and a failed undo (result=reverted-failed)
# are not the same thing, and SKILL.md must not describe them the same way:
# only the clean-stop paragraph may claim files are back as they were.
rf_para=$(awk -v RS='' '/reverted-failed/' "$skill" 2>/dev/null)
! printf '%s' "$rf_para" | grep -qi 'back as they were'
ok $? "SKILL.md's result=reverted-failed wording never claims files are back as they were"

r_para=$(awk -v RS='' '/`result=reverted`/ && !/reverted-failed/' "$skill" 2>/dev/null)
printf '%s' "$r_para" | grep -qi 'back as they were'
ok $? "SKILL.md's plain result=reverted wording still says files are back as they were"

printf '%s' "$rf_para" | grep -qi 'Slack'
ok $? "SKILL.md's result=reverted-failed wording sends the founder to the Slack channel"

if [ "$fail" = 0 ]; then
  printf '\nAll agents-doc checks passed.\n'
else
  printf '\nSome agents-doc checks failed.\n'
fi
exit "$fail"
