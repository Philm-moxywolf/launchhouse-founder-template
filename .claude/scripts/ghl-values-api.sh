#!/bin/sh
# Custom values over GoHighLevel's API, for ghl-values only, and only when the
# founder chose that route over pasting by hand.
#
# The token is read from the computer's own password store, in an item named
# "Launchhouse GoHighLevel values", whose account or user name is the Location
# ID. The founder adds it by clicking and deletes it when the job is done. It
# goes to GoHighLevel in curl's settings on its standard input, never on the
# command line, and is never printed. Only GoHighLevel's answer is printed.
#
#   sh .claude/scripts/ghl-values-api.sh list < /dev/null
#   sh .claude/scripts/ghl-values-api.sh create < body.json
#   sh .claude/scripts/ghl-values-api.sh update <custom value id> < body.json
#
# The body is GoHighLevel's own JSON, {"name": "...", "value": "..."}.

here=$(cd "$(dirname "$0")" && pwd)
. "$here/ghl-store.sh" || exit 1

ghl_store_read "$ghl_values_item"
if [ "$ghl_found" != yes ]; then
  printf 'token: not found. Expected an item named %s.\n' "$ghl_values_item"; exit 1
fi
if [ "$ghl_allowed" != yes ]; then
  printf 'token: this Mac did not allow it to be read. Try again, and click Always Allow when the Mac asks.\n'; exit 1
fi
ghl_good_key "$ghl_key" && ghl_good_loc "$ghl_loc" || {
  printf 'token: the password or the Location ID in the item is missing, or has spaces or other characters.\n'; exit 1; }

url="https://services.leadconnectorhq.com/locations/$ghl_loc/customValues"
case ${1:-} in
  list) method=GET ;;
  create) method=POST ;;
  update)
    case ${2:-} in ''|*[!A-Za-z0-9]*) printf 'update needs the custom value id.\n'; exit 1 ;; esac
    method=PUT; url="$url/$2" ;;
  *) printf 'Use list, create, or update <id>.\n'; exit 1 ;;
esac

body=
if [ "$method" != GET ]; then
  body=$(mktemp "${TMPDIR:-/tmp}/lh-values.XXXXXX") || exit 1
  trap 'rm -f "$body"' EXIT
  cat > "$body"
  [ -s "$body" ] || { printf 'No body was given.\n'; exit 1; }
fi
# On Windows, curl reads the path from its settings as a Windows path.
bodyarg=$body
if [ -n "$body" ] && command -v cygpath >/dev/null 2>&1; then bodyarg=$(cygpath -m "$body"); fi

# The settings, the token among them, go to curl on its standard input.
{
  printf 'header = "Authorization: Bearer %s"\n' "$ghl_key"
  printf 'header = "Version: 2021-07-28"\n'
  printf 'header = "Accept: application/json"\n'
  [ -n "$body" ] && printf 'header = "Content-Type: application/json"\ndata-binary = "@%s"\n' "$bodyarg"
} | curl -sS -K - -X "$method" "$url" -w '\nstatus: %{http_code}\n'
