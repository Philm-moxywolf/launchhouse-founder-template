#!/bin/sh
# Checks the connector-safety-routing note's purpose: every connected-tool
# call (any mcp__ tool) is routed through one dispatcher, mcp-guard.sh, and
# neither retired script it replaced (deny-mcp.sh, ask-mcp.sh) is still
# named anywhere in the hook wiring. A settings.json that still points at
# either retired script has, without meaning to, turned off the connector
# safety net: the call is neither denied nor guided, it is just never
# checked.
#
# This reads settings.json's actual JSON content, never its line shape --
# it passes whether the file is pretty-printed at 2 spaces, 4 spaces,
# written as one compact line, or saved with CRLF endings, because a
# founder's own editor or a Windows checkout can reformat the file without
# changing what it means. It flattens the file with the shared
# .claude/scripts/json-flat.sh (which itself checks the file is valid JSON
# first, via json-valid.sh): a broken settings.json is the one case this
# check cannot make sense of, and a broken settings.json is itself the
# thing a safety note must never wave through. If json-flat.sh is not
# present at all, this check fails closed rather than falling back to a
# weaker, line-shaped read of its own.
#
# Usage: sh .claude/updates/2026-09-23/connector-safety-routing.check.sh [repo-root]

set -u
root=${REPO_ROOT:-${1:-$PWD}}
fail=0
problem() { printf 'FAIL %s\n' "$1"; fail=1; }

settings="$root/.claude/settings.json"
guard="$root/.claude/scripts/mcp-guard.sh"
flattener="$root/.claude/scripts/json-flat.sh"

fail_with_hint() {
  printf 'hint=Your settings file still points at safety scripts that no longer exist, or is not valid JSON. Choose "take the update" for .claude/settings.json; your own copy is kept safe and your changes are brought back on the next update.\n'
  exit 1
}

[ -f "$settings" ] || { printf 'FAIL settings.json is missing: %s\n' "$settings"; fail_with_hint; }
[ -f "$guard" ] || problem "mcp-guard.sh does not exist: $guard"

if [ ! -f "$flattener" ]; then
  problem "the shared JSON flattener is missing: $flattener"
  fail_with_hint
fi

# ---------------------------------------------------- flatten the JSON
# Delegated to the shared flattener (see its own header for what "path"
# means, and how a key literally containing "/" is escaped so it can
# never be mistaken for a real nested path).
if ! extract_out=$(sh "$flattener" "$settings" 2>&1); then
  problem "settings.json is not valid JSON"
  fail_with_hint
fi

# ---------------------------------------------------------- the assertions

# Exactly one PreToolUse array entry has matcher EXACTLY "^mcp__" -- a
# variant such as "^mcp__ghl" being the only mcp__ matcher must fail here,
# never be mistaken for the real dispatcher's own matcher.
matcher_paths=$(printf '%s\n' "$extract_out" | awk -F '\t' '
  $1 ~ /^\/hooks\/PreToolUse\/[0-9]+\/matcher$/ && $2 == "^mcp__" { print $1 }
')
matcher_count=$(printf '%s\n' "$matcher_paths" | grep -c '.')

if [ "$matcher_count" != 1 ]; then
  problem "settings.json's PreToolUse block has $matcher_count entr(y/ies) whose matcher is exactly ^mcp__, expected exactly 1"
else
  # The matched entry's own index, and whether any of its own hooks'
  # command values runs mcp-guard.sh.
  idx=$(printf '%s\n' "$matcher_paths" | sed -n 's#^/hooks/PreToolUse/\([0-9][0-9]*\)/matcher$#\1#p')
  mg_hit=$(printf '%s\n' "$extract_out" | awk -F '\t' -v idx="$idx" '
    $1 ~ ("^/hooks/PreToolUse/" idx "/hooks/[0-9]+/command$") && $2 ~ /mcp-guard\.sh/ { found = 1 }
    END { print found + 0 }
  ')
  [ "$mg_hit" = 1 ] || problem "the ^mcp__ matcher's own hooks do not run mcp-guard.sh"
fi

# No "command" value anywhere in the whole file, at any depth, names
# either retired script.
bad_cmds=$(printf '%s\n' "$extract_out" | awk -F '\t' '
  $1 ~ /\/command$/ && ($2 ~ /deny-mcp\.sh/ || $2 ~ /ask-mcp\.sh/) { print }
')
if [ -n "$bad_cmds" ]; then
  problem "settings.json still names a retired script (deny-mcp.sh or ask-mcp.sh) in a hook command"
fi

if [ "$fail" = 0 ]; then
  printf 'PASS connector-safety-routing: settings.json routes every mcp__ call through mcp-guard.sh, and names neither retired script\n'
  exit 0
fi
fail_with_hint
