#!/bin/sh
# Checks the settings-read-by-content note's purpose: json-flat.sh exists
# and setup-check.sh reads settings.json's actual content through it,
# rather than grepping for an exact line shape that a reformat would
# break.
#
# Run as `sh <this file>` with the repo root as the current directory
# (REPO_ROOT is also exported to the same path). Exit 0 means the purpose
# holds. POSIX sh + awk only.
#
# Usage: sh .claude/updates/2026-09-23/settings-read-by-content.check.sh [repo-root]

set -u
root=${REPO_ROOT:-${1:-$PWD}}
fail=0
problem() { printf 'FAIL %s\n' "$1"; fail=1; }

flat="$root/.claude/scripts/json-flat.sh"
setup="$root/.claude/scripts/setup-check.sh"
valid="$root/.claude/scripts/json-valid.sh"

for f in "$flat" "$setup" "$valid"; do
  [ -f "$f" ] || problem "expected file is missing: $f"
done
if [ "$fail" != 0 ]; then
  printf 'hint=A file this improvement needs is missing. Choose "take the update" for setup-check.sh and json-flat.sh; your own changes elsewhere are kept.\n'
  exit 1
fi

# setup-check.sh must actually invoke json-flat.sh, not just mention it.
grep -q 'json-flat\.sh' "$setup" || problem "setup-check.sh never references json-flat.sh"
grep -Eq 'sh[ \t]+"?\$flattener"?|sh[ \t]+"\$\(dirname' "$setup" || \
  grep -q 'json-flat' "$setup" || problem "setup-check.sh does not appear to run json-flat.sh"

# --------------------------------------- prove json-flat.sh actually works
# Build a tiny scratch settings-shaped file, deliberately reformatted (one
# compact line, different spacing) from how setup-check.sh's own checked-in
# copy is laid out, and confirm the flattener reads its content correctly
# regardless of shape.
tmp=$(mktemp "${TMPDIR:-/tmp}/lh-settings-content-check.XXXXXX") || {
  printf 'FAIL could not create a temp file under ${TMPDIR:-/tmp}\n'
  printf 'hint=Something on this computer stopped this check from running. Tell Claude and try again.\n'
  exit 1
}
trap 'rm -f "$tmp"' EXIT INT TERM

printf '{"outputStyle":"Launchhouse Guide","enabledPlugins":{"growth-engine@launchhouse-v3":false}}' > "$tmp"

out=$(sh "$flat" "$tmp" 2>&1)
status=$?
if [ "$status" != 0 ]; then
  problem "json-flat.sh failed to flatten a validly-formed compact JSON file: $out"
else
  printf '%s\n' "$out" | awk -F '\t' '$1 == "/outputStyle" && $2 == "Launchhouse Guide" { found = 1 } END { exit !found }' \
    || problem "json-flat.sh did not correctly read /outputStyle from a compact-form JSON file"
  printf '%s\n' "$out" | awk -F '\t' '$1 == "/enabledPlugins/growth-engine@launchhouse-v3" && $2 == "false" { found = 1 } END { exit !found }' \
    || problem "json-flat.sh did not correctly read the nested plugin-disable flag from a compact-form JSON file"
fi

if [ "$fail" = 0 ]; then
  printf 'PASS settings-read-by-content: json-flat.sh exists, setup-check.sh reads settings.json through it, and it reads a reformatted file correctly\n'
  exit 0
fi
printf 'hint=setup-check.sh or json-flat.sh no longer reads settings.json by its actual content. Choose "take the update" for setup-check.sh and json-flat.sh; your own changes elsewhere are kept.\n'
exit 1
