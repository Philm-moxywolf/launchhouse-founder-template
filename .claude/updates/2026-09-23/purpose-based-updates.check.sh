#!/bin/sh
# Checks the purpose-based-updates note's purpose: update.sh supports
# --adapt-save and --restore-settings-plan, the update-adapter agent exists
# and carries only read-only tools, and updates-lint.sh passes on this
# tree.
#
# Run as `sh <this file>` with the repo root as the current directory
# (REPO_ROOT is also exported to the same path). Exit 0 means the purpose
# holds. POSIX sh + awk only.
#
# Usage: sh .claude/updates/2026-09-23/purpose-based-updates.check.sh [repo-root]

set -u
root=${REPO_ROOT:-${1:-$PWD}}
fail=0
problem() { printf 'FAIL %s\n' "$1"; fail=1; }

update_sh="$root/.claude/scripts/update.sh"
adapter="$root/.claude/agents/update-adapter.md"
lint="$root/.claude/scripts/updates-lint.sh"

for f in "$update_sh" "$adapter" "$lint"; do
  [ -f "$f" ] || problem "expected file is missing: $f"
done
if [ "$fail" != 0 ]; then
  printf 'hint=A file this improvement needs is missing. Choose "take the update" for the files this note touches; your own changes elsewhere are kept.\n'
  exit 1
fi

# ---------------------------------------------------- update.sh commands
grep -q -- '--adapt-save' "$update_sh" || problem "update.sh does not mention --adapt-save"
grep -q -- '--restore-settings-plan' "$update_sh" || problem "update.sh does not mention --restore-settings-plan"

# Each command must also actually be wired into the argument dispatch, not
# just mentioned in a comment.
grep -Eq '\-\-adapt-save\)' "$update_sh" || problem "update.sh never dispatches --adapt-save as a command"
grep -Eq '\-\-restore-settings-plan\)' "$update_sh" || problem "update.sh never dispatches --restore-settings-plan as a command"

# ---------------------------------------------------- update-adapter.md
# Frontmatter tools: line must list exactly Read, Grep, Glob (any order is
# fine, but nothing else -- especially never Write, Edit or Bash).
tools_line=$(awk '
  BEGIN { infm = 0 }
  /^---[ \t]*$/ { infm++; if (infm == 2) exit; next }
  infm == 1 && /^tools:/ { print; exit }
' "$adapter")

if [ -z "$tools_line" ]; then
  problem "update-adapter.md has no tools: line in its frontmatter"
else
  tools_value=$(printf '%s\n' "$tools_line" | sed 's/^tools:[ \t]*//')
  # Normalize: split on comma, trim spaces, sort, compare against the
  # expected set.
  normalized=$(printf '%s\n' "$tools_value" | tr ',' '\n' | sed 's/^[ \t]*//; s/[ \t]*$//' | sort | tr '\n' ',' | sed 's/,$//')
  expected=$(printf 'Glob\nGrep\nRead\n' | sort | tr '\n' ',' | sed 's/,$//')
  if [ "$normalized" != "$expected" ]; then
    problem "update-adapter.md tools: line is '$tools_value', expected only Read, Grep, Glob"
  fi
fi

# ------------------------------------------------------------- the linter
lint_out=$(sh "$lint" "$root" 2>&1)
lint_status=$?
if [ "$lint_status" != 0 ]; then
  problem "updates-lint.sh failed: $lint_out"
fi

if [ "$fail" = 0 ]; then
  printf 'PASS purpose-based-updates: update.sh supports --adapt-save and --restore-settings-plan, update-adapter.md is read-only, updates-lint.sh passes\n'
  exit 0
fi
printf 'hint=Your updater or the update-adapter agent has drifted from what this improvement needs. Choose "take the update" for the files this note touches; your own changes elsewhere are kept.\n'
exit 1
