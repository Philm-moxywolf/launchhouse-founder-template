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

if [ "$fail" = 0 ]; then
  printf '\nAll agents-doc checks passed.\n'
else
  printf '\nSome agents-doc checks failed.\n'
fi
exit "$fail"
