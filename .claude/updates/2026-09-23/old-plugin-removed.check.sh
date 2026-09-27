#!/bin/sh
# Checks the old-plugin-removed note's purpose: settings.json names no
# growth-engine plugin, CLAUDE.md does not mention an old plugin to switch
# off, and setup-check.sh no longer checks for a disabled plugin flag.
#
# Run as `sh <this file>` with the repo root as the current directory
# (REPO_ROOT is also exported to the same path). Exit 0 means the purpose
# holds. POSIX sh + awk only.
#
# Usage: sh .claude/updates/2026-09-23/old-plugin-removed.check.sh [repo-root]

set -u
root=${REPO_ROOT:-${1:-$PWD}}
fail=0
problem() { printf 'FAIL %s\n' "$1"; fail=1; }

settings="$root/.claude/settings.json"
claudemd="$root/CLAUDE.md"
setup="$root/.claude/scripts/setup-check.sh"

for f in "$settings" "$claudemd" "$setup"; do
  [ -f "$f" ] || problem "expected file is missing: $f"
done
if [ "$fail" != 0 ]; then
  printf 'hint=A file this improvement needs is missing. Choose "take the update" for settings.json, CLAUDE.md and setup-check.sh; your own changes elsewhere are kept.\n'
  exit 1
fi

# Only the old plugin's own id is a fail. A founder's own unrelated
# enabledPlugins entry (a different plugin they installed themselves) is
# theirs to keep -- enabledPlugins itself is never checked for.
grep -q 'growth-engine@launchhouse-' "$settings" \
  && problem "settings.json still names the old growth-engine plugin"

grep -qi 'growth-engine.*plugin\|old.*plugin\|plugin.*switch' "$claudemd" \
  && problem "CLAUDE.md still describes an old growth-engine plugin to switch off"

grep -q 'enabledPlugins\|growth-engine@launchhouse-v3' "$setup" \
  && problem "setup-check.sh still checks for a disabled growth-engine plugin flag"

if [ "$fail" = 0 ]; then
  printf 'PASS old-plugin-removed: settings.json names no plugin, CLAUDE.md does not describe one to switch off, and setup-check.sh no longer checks for it\n'
  exit 0
fi
printf 'hint=A file still mentions the old growth-engine plugin. Choose "take the update" for settings.json, CLAUDE.md and setup-check.sh; your own changes elsewhere are kept.\n'
exit 1
