#!/bin/sh
# Checks the ghl-install-link note's purpose: one GoHighLevel install-link
# URL, copied byte-identical everywhere a founder or Claude reads it, and
# the install step always mentioned before "Add custom connector" in the
# two files that walk a founder through connecting.
#
# Run as `sh <this file>` with the repo root as the current directory
# (REPO_ROOT is also exported to the same path). Exit 0 means the purpose
# holds. POSIX sh + awk only.
#
# Usage: sh .claude/updates/2026-09-23/ghl-install-link.check.sh [repo-root]

set -u
root=${REPO_ROOT:-${1:-$PWD}}
fail=0

connections="$root/.claude/references/connections.md"
starthere="$root/START-HERE.md"
connect_skill="$root/.claude/skills/connect-tools/SKILL.md"

problem() { printf 'FAIL %s\n' "$1"; fail=1; }

# A CRLF checkout (Git for Windows) never changes what a file says, only
# how its lines end. Every grep below reads a file through this instead of
# the file itself, so a trailing \r is never part of a matched URL and
# never shifts a line's own content (only grep -n's own line count, which
# is already CRLF-proof: it counts newlines, not carriage returns).
strip_cr() { awk '{ sub(/\r$/, ""); print }' "$1" 2>/dev/null; }

for f in "$connections" "$starthere" "$connect_skill"; do
  [ -f "$f" ] || problem "expected file is missing: $f"
done
[ "$fail" = 0 ] || {
  printf 'hint=A file this check needs is missing. Choose "take the update" for the files this note touches; your own changes elsewhere are kept.\n'
  exit 1
}

# --------------------------------------------- one canonical install URL
# The URL's own characters only (letters, digits, and : / ? = & % + . _ -),
# so a trailing ")" from markdown link syntax is never swept in.
url_pat='https://marketplace\.leadconnectorhq\.com/v2/oauth/chooselocation[A-Za-z0-9:/?=&%+._-]*'

canon_urls=$(strip_cr "$connections" | grep -Eo "$url_pat")
canon_count=$(printf '%s\n' "$canon_urls" | grep -c '.')
canon_url=$(printf '%s\n' "$canon_urls" | head -n 1)

if [ "$canon_count" != 1 ]; then
  problem "connections.md holds $canon_count copies of the install-link URL, expected exactly 1"
fi

# ---------------------------------- every other copy matches it exactly
# Scan START-HERE.md and everything under .claude/, except .claude/tests/
# (ordinary test fixtures) and .claude/updates/ (this note's own copy of
# the touched files, and any other release's notes) -- a founder-facing or
# Claude-facing file, never a fixture or a note about one.
tmp=$(mktemp "${TMPDIR:-/tmp}/lh-ghl-install-check.XXXXXX") || {
  printf 'FAIL could not create a temp file under ${TMPDIR:-/tmp}\n'
  printf 'hint=Something on this computer stopped this check from running. Tell Claude and try again.\n'
  exit 1
}
trap 'rm -f "$tmp"' EXIT INT TERM

strip_cr "$starthere" | grep -Eo "$url_pat" | awk -v p="$starthere" '{ print p "\t" $0 }' >> "$tmp"

find "$root/.claude" -type f \
  ! -path "$root/.claude/tests/*" \
  ! -path "$root/.claude/tests" \
  ! -path "$root/.claude/updates/*" \
  ! -path "$root/.claude/updates" \
  -print 2>/dev/null |
while IFS= read -r f; do
  strip_cr "$f" | grep -Eo "$url_pat" | awk -v p="$f" '{ print p "\t" $0 }'
done >> "$tmp"

while IFS="$(printf '\t')" read -r path url; do
  [ -n "$url" ] || continue
  if [ "$url" != "$canon_url" ]; then
    relpath=${path#"$root"/}
    problem "$relpath carries an install-link URL that differs from connections.md's copy"
  fi
done < "$tmp"

# --------------------------------- the install is mentioned before "Add
# custom connector" in the two files that walk a founder through it
for f in "$starthere" "$connect_skill"; do
  [ -f "$f" ] || continue
  install_line=$(strip_cr "$f" | grep -n -i 'install link' | head -n 1 | cut -d: -f1)
  connector_line=$(strip_cr "$f" | grep -n 'Add custom connector' | head -n 1 | cut -d: -f1)
  relpath=${f#"$root"/}
  if [ -z "$install_line" ]; then
    problem "$relpath never mentions the install link at all"
  elif [ -z "$connector_line" ]; then
    problem "$relpath never mentions Add custom connector at all"
  elif [ "$install_line" -ge "$connector_line" ]; then
    problem "$relpath mentions Add custom connector (line $connector_line) before the install link (line $install_line)"
  fi
done

if [ "$fail" = 0 ]; then
  printf 'PASS ghl-install-link: one install-link URL, repeated identically, install always mentioned first\n'
  exit 0
fi
printf 'hint=Your GoHighLevel install-link copy has drifted from the one in connections.md, or a file now tells founders to add the connector before installing the app. Choose "take the update" for the touched files; your own changes elsewhere are kept.\n'
exit 1
