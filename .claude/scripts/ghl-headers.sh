#!/bin/sh
# The headersHelper for the highlevel server in .mcp.json. Claude Code runs it
# when it connects to GoHighLevel, and sends what it prints as the request
# headers. It never runs in the conversation for the key.
#
# The key lives in the computer's own password store, never in a file: the
# Keychain on a Mac, Credential Manager on Windows, in an item named
# "Launchhouse GoHighLevel". Its account or user name is the Location ID, its
# password the Private Integration key. See ghl-store.sh.
#
# It prints the key only for GoHighLevel's own address, and only when Claude
# Code asks for it as it connects. Anything else gets nothing.
#
# Three forms may run in the conversation, and none of them ever shows the key:
#   --check      says whether the item is there and in the right shape
#   --connect    the same check, then, when all is right, writes .mcp.json at
#                the top of this folder so the app connects to GoHighLevel
#                when it next opens. .mcp.json holds this computer's own path
#                to the folder, never the key, and git ignores it.
#   --disconnect removes .mcp.json, but only when it is the one this script
#                wrote (the founder's own account connector, or a founder's
#                own unrelated .mcp.json, is never touched).

here=$(cd "$(dirname "$0")" && pwd)
. "$here/ghl-store.sh" || exit 1
ghl=https://services.leadconnectorhq.com/mcp/anthropic/v2

check() {
  case $(ghl_system) in
    mac) where='the Keychain' ;;
    windows) where='Credential Manager' ;;
    *) printf 'key: this check works on a Mac or a Windows PC only.\n'; return 1 ;;
  esac
  ghl_store_read "$ghl_conn_item"
  if [ "$ghl_found" != yes ]; then
    printf 'key: not found. Expected an item named %s in %s.\n' "$ghl_conn_item" "$where"
    return 1
  fi
  printf 'key: found in %s\n' "$where"
  if [ "$ghl_allowed" != yes ]; then
    printf 'key: this Mac did not allow it to be read. Run the check again, and click Always Allow when the Mac asks.\n'
    return 1
  fi
  ok=0
  ghl_good_key "$ghl_key" && printf 'the password, the key: looks right\n' \
    || { printf 'the password, the key: missing, or has spaces or other characters\n'; ok=1; }
  ghl_good_loc "$ghl_loc" && printf 'the account name, the Location ID: looks right\n' \
    || { printf 'the account name, the Location ID: missing, or has spaces or other characters\n'; ok=1; }
  return $ok
}

# The path to this folder as the app will run it, in forward slashes.
root_path() {
  r=$(cd "$here/../.." && pwd)
  if command -v cygpath >/dev/null 2>&1; then r=$(cygpath -m "$r"); fi
  printf '%s' "$r"
}

connect() {
  root=$(cd "$here/../.." && pwd)
  mcp="$root/.mcp.json"
  if [ -f "$mcp" ] && ! { grep -q '"highlevel"' "$mcp" && grep -q 'ghl-headers\.sh' "$mcp"; }; then
    printf 'connection: not written. This folder already has a .mcp.json with something else in it. Ask for a hand in the Slack channel.\n'
    return 1
  fi
  p=$(root_path)
  # On a Mac the app finds sh itself. On Windows it starts the helper through
  # cmd.exe, which cannot find sh on a default Git for Windows install, so the
  # connection names the shell running this, by its full path.
  run_sh=sh
  if command -v cygpath >/dev/null 2>&1; then
    run_sh=$(cygpath -m "$(command -v sh)" 2>/dev/null)
    case $run_sh in
      ''|/*|*'"'*|*'\'*) printf 'connection: not written. Ask for a hand in the Slack channel.\n'; return 1 ;;
      *.exe|*.EXE) ;;
      *) run_sh="$run_sh.exe" ;;
    esac
    run_sh="\\\"$run_sh\\\""
  fi
  case $p in *'"'*|*'\'*) printf 'connection: not written. The folder path has a character the connection cannot hold. Move the folder somewhere plainer and try again.\n'; return 1 ;; esac
  cat > "$mcp.tmp.$$" <<EOF || { rm -f "$mcp.tmp.$$"; printf 'connection: not written. The folder could not be written to.\n'; return 1; }
{
  "mcpServers": {
    "highlevel": {
      "type": "http",
      "url": "$ghl",
      "headersHelper": "$run_sh \"$p/.claude/scripts/ghl-headers.sh\""
    }
  }
}
EOF
  mv -f "$mcp.tmp.$$" "$mcp" || { rm -f "$mcp.tmp.$$"; return 1; }
  printf 'connection: written. Quit the Claude app and open it again on this folder to connect.\n'
}

# Removes .mcp.json, but only the one connect() itself wrote: the same marker
# check connect() uses to decide whether it may overwrite a file that is
# already there, so this can never delete a founder's own unrelated
# .mcp.json, or one Claude wrote for something else.
disconnect() {
  root=$(cd "$here/../.." && pwd)
  mcp="$root/.mcp.json"
  if [ ! -f "$mcp" ]; then
    printf 'connection: nothing to remove. There is no .mcp.json here.\n'
    return 0
  fi
  if ! { grep -q '"highlevel"' "$mcp" && grep -q 'ghl-headers\.sh' "$mcp"; }; then
    printf 'connection: not removed. This .mcp.json was not written by this helper, so it is left alone.\n'
    return 1
  fi
  rm -f "$mcp" || { printf 'connection: not removed. The file could not be deleted.\n'; return 1; }
  printf 'connection: removed.\n'
}

case ${1:-} in
  --check) check; exit $? ;;
  --connect) check || { printf 'connection: not written, because the key is not right yet.\n'; exit 1; }
             connect; exit $? ;;
  --disconnect) disconnect; exit $? ;;
esac

# Only for GoHighLevel's own address, asked for by Claude Code as it connects.
case ${CLAUDE_CODE_MCP_SERVER_URL:-} in
  "$ghl"*) ;;
  *) exit 1 ;;
esac

ghl_store_read "$ghl_conn_item" || exit 1
ghl_good_key "$ghl_key" && ghl_good_loc "$ghl_loc" || exit 1

printf '{"Authorization": "Bearer %s", "locationId": "%s"}\n' "$ghl_key" "$ghl_loc"
