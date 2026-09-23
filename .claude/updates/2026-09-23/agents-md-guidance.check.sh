#!/bin/sh
# Checks the agents-md-guidance note's purpose: AGENTS.md exists at the
# repo root and names the upstream trust check and the bootstrap folder,
# and README.md and CLAUDE.md both point to it.
#
# Run as `sh <this file>` with the repo root as the current directory
# (REPO_ROOT is also exported to the same path). Exit 0 means the purpose
# holds. POSIX sh + awk only.
#
# Usage: sh .claude/updates/2026-09-23/agents-md-guidance.check.sh [repo-root]

set -u
root=${REPO_ROOT:-${1:-$PWD}}
fail=0
problem() { printf 'FAIL %s\n' "$1"; fail=1; }

agents="$root/AGENTS.md"
readme="$root/README.md"
claudemd="$root/CLAUDE.md"

for f in "$agents" "$readme" "$claudemd"; do
  [ -f "$f" ] || problem "expected file is missing: $f"
done
if [ "$fail" != 0 ]; then
  printf 'hint=A file this improvement needs is missing. Choose "take the update" for AGENTS.md, README.md and CLAUDE.md; your own changes elsewhere are kept.\n'
  exit 1
fi

# ------------------------------------------------------------- AGENTS.md
# Names the upstream trust check: a mention of the upstream remote / trust
# / verify, together with the canonical upstream address or the file that
# records it.
if ! grep -q -i 'upstream' "$agents"; then
  problem "AGENTS.md never mentions the upstream remote at all"
fi
if ! grep -q -i 'launchhouse-upstream\|verify.*upstream\|upstream.*trust\|trust.*upstream' "$agents"; then
  problem "AGENTS.md does not name the upstream trust check"
fi
if ! grep -q 'launchhouse/bootstrap' "$agents"; then
  problem "AGENTS.md does not name the bootstrap folder (launchhouse/bootstrap)"
fi

# ---------------------------------------------------- README and CLAUDE.md
grep -q 'AGENTS\.md' "$readme" || problem "README.md never mentions AGENTS.md"
grep -q 'AGENTS\.md' "$claudemd" || problem "CLAUDE.md never mentions AGENTS.md"

if [ "$fail" = 0 ]; then
  printf 'PASS agents-md-guidance: AGENTS.md exists and names the upstream trust check and bootstrap folder; README.md and CLAUDE.md both point to it\n'
  exit 0
fi
printf 'hint=AGENTS.md is missing a piece of the update guidance, or README.md or CLAUDE.md no longer points to it. Choose "take the update" for AGENTS.md, README.md and CLAUDE.md; your own changes elsewhere are kept.\n'
exit 1
