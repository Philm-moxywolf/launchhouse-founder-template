#!/bin/sh
# Checks the gates-own-use note's purpose: gates.md no longer says a gate
# is checked at the start of the next session, the Founder Brain's Flags
# section no longer says the mentor team reads it, and the gate skill
# names the next unfinished engine and offers to start it.
#
# Run as `sh <this file>` with the repo root as the current directory
# (REPO_ROOT is also exported to the same path). Exit 0 means the purpose
# holds. POSIX sh + awk only.
#
# Usage: sh .claude/updates/2026-09-23/gates-own-use.check.sh [repo-root]

set -u
root=${REPO_ROOT:-${1:-$PWD}}
fail=0
problem() { printf 'FAIL %s\n' "$1"; fail=1; }

gates="$root/.claude/references/gates.md"
gateskill="$root/.claude/skills/gate/SKILL.md"
brain="$root/.claude/skills/founder-brain/SKILL.md"

for f in "$gates" "$gateskill" "$brain"; do
  [ -f "$f" ] || problem "expected file is missing: $f"
done
if [ "$fail" != 0 ]; then
  printf 'hint=A file this improvement needs is missing. Choose "take the update" for gates.md, gate/SKILL.md and founder-brain/SKILL.md; your own changes elsewhere are kept.\n'
  exit 1
fi

grep -q 'is checked at the start of the next session' "$gates" \
  && problem "gates.md still says a gate is checked at the start of the next session"

grep -q 'mentor team reads' "$brain" \
  && problem "the Founder Brain skill's Flags section still says the mentor team reads it"

grep -qi 'name the next unfinished engine' "$gateskill" \
  || problem "the gate skill does not say to name the next unfinished engine and offer to start it"

if [ "$fail" = 0 ]; then
  printf 'PASS gates-own-use: gates.md drops the checked-at-next-session framing, the Brain'"'"'s Flags no longer says the mentor team reads it, and the gate skill keeps the founder moving to the next engine\n'
  exit 0
fi
printf 'hint=A gate file still reads as a submission checked by someone else. Choose "take the update" for gates.md, gate/SKILL.md and founder-brain/SKILL.md; your own changes elsewhere are kept.\n'
exit 1
