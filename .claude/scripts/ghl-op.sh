#!/bin/sh
# PreToolUse on GoHighLevel's six-tool connector shape: mcp__*__execute_operation,
# mcp__*__fetch and mcp__*__search, on any server name or uuid. The old
# one-per-job tool names (contacts_create-contact and so on, from the fallback
# connection) still go through ask-mcp.sh and deny-mcp.sh; this hook is for
# the new unified shape, where a single tool can do anything from reading a
# location to refunding a payment, so the classification comes from the
# whole input, never the tool name alone.
#
# Only tool_input is ever classified, never the whole hook envelope: cwd,
# transcript_path and the rest of what Claude Code sends alongside it are
# read every time (a founder's own file paths, for one, routinely contain
# words like "users"), and none of that is the founder's action. And within
# tool_input, only the operation descriptor is classified, never a payload
# field. The descriptor is built from an ALLOWLIST of structural fields, not
# a blacklist of payload container keys: a leaf only ever counts when its own
# key is one of a short list of shape words (operationId, method, path, and
# the rest below), or is an id/name sitting right under an operation/request
# object. Everything else a founder ever typed into a form field — post
# copy, a message body, a note — is never even walked into the descriptor,
# whatever it says and whatever key it sits under.
#
# The surviving descriptor is flattened to one lower case line
# (lh_ghl_flatten, in lib.sh) and matched with word lists on word
# boundaries, never a bare substring test, so "post" inside "posting" or
# "get" inside "target" cannot fire a rule by accident. The flattener splits
# camelCase (sendMessage -> send message) and an acronym run ahead of a
# titlecase word (getHTTPMethod -> get HTTP Method -> get http method), so
# an operation id in either style reads the same way.
#
# Precedence, always: refuse beats write beats read beats ask.
#   refuse (deny, no discussion): payments, billing, deletes, workflow and
#     campaign changes, users, permissions, roles, snapshots, integrations,
#     an explicit DELETE method, and the rest of the list below.
#   write (ask the founder): a write verb, a POST/PUT/PATCH method, or a
#     leading "post".
#   read (let it go quietly): a clear read word, and nothing above fired,
#     and no method field present that is not GET.
#   ask: anything this script cannot tell apart, including an unknown
#     operation, empty input, a malformed envelope, and text carrying a
#     Unicode escape this script cannot safely read. It never allows on
#     doubt, and a parsing failure never becomes a crash, a silent allow, or
#     a line of broken JSON.

. "$(dirname "$0")/lib.sh" 2>/dev/null || exit 0
lh_active || [ -n "$(lh_near)" ] || exit 0

input=$(cat) || exit 0
tool=$(lh_json_get tool_name "$input") || tool=""

# The envelope itself must be one well formed JSON object with nothing
# trailing after it closes. A truncated, doubled up, or garbage-tailed
# envelope is doubt, same as anything else this script cannot make sense
# of, so it asks rather than guessing at what tool_input even was.
lh_json_leaves "$input" >/dev/null 2>&1 ||
  lh_ask_pre "Launchhouse: this GoHighLevel action arrived in a shape this hook could not read, so check with the founder before it runs."

# The only part of the envelope anything below ever looks at. Everything
# else in $input (cwd, transcript_path, session_id, permission_mode, ...)
# stops here. If tool_input is missing or the envelope itself is not valid
# JSON, tool_input comes back empty, which lands the same as an empty
# descriptor below: ask, never allow, never deny.
tool_input=$(lh_json_get_raw tool_input "$input") || tool_input=""

# tool_input must itself be a genuine JSON object, not a list, a bare
# string, a number, or anything else. Leading space is allowed and ignored;
# anything whose first real character is not "{" is doubt, so it asks.
ti_trim=$(printf '%s' "$tool_input" | LC_ALL=C awk '{ sub(/^[ \t\r\n]+/, ""); printf "%s", $0 }')
case $ti_trim in
  "{"*) ;;
  *) lh_ask_pre "Launchhouse: this GoHighLevel action's input was not a plain set of fields, so check with the founder before it runs." ;;
esac

# A short, safe label for the ask/deny message: the first operation-shaped
# field tool_input carries, or else a slice of it. Capped at 80 characters
# and stripped to a plain character set before it goes near JSON output, so
# a hostile or garbage tool_input can never break the hook's own output or
# reach the founder unfiltered.
op=$(lh_json_get operationId "$tool_input") || op=""
[ -n "$op" ] || op=$(lh_json_get operation_id "$tool_input") || op=""
[ -n "$op" ] || op=$(lh_json_get operation "$tool_input") || op=""
[ -n "$op" ] || op=$(lh_json_get name "$tool_input") || op=""
[ -n "$op" ] || op=$(lh_json_get id "$tool_input") || op=""
[ -n "$op" ] || op=$(printf '%s' "$tool_input" | cut -c1-80)
op=$(printf '%s' "$op" | cut -c1-80 | tr -c 'A-Za-z0-9 _.-' ' ' | awk '{ $1=$1; print }')

# Every scalar leaf of tool_input, path and value, tab separated. Malformed
# or truncated JSON here (trailing garbage inside tool_input included, since
# lh_json_leaves errors unless the whole string is one clean value) leaves
# $leaves empty and $leaves_ok at 0, which lands the same as an empty
# descriptor below.
leaves=$(lh_json_leaves "$tool_input") && leaves_ok=1 || leaves_ok=0
[ "$leaves_ok" = 1 ] || leaves=""

# The descriptor: the value of every leaf whose own key names the shape of
# the call (operationId, method, path, and the rest of the allowlist), or
# whose key is id or name sitting right under an operation or request
# object, itself never sitting under anything but a chain of operation or
# request objects, all the way up to tool_input's own top level. Nothing
# else contributes, key or value: a founder's own post copy, a note field,
# or anything else typed into a form field, can never read as a refuse or
# write word, however deep it sits, and a structural-named field (method,
# for one) buried inside a payload or body object is not read as one
# either, only a genuine one at the top or right under operation/request.
# When an included leaf sits under an "operation" or "request" object,
# those two words are folded in too (never any other ancestor), so
# {"request":{"operationId":"contacts_delete-contact"}} still reads.
described=$(printf '%s\n' "$leaves" | LC_ALL=C awk -F '\t' '
  BEGIN {
    split("operationid operation op action method httpmethod path endpoint url route", a, " ")
    for (i in a) structural[a[i]] = 1
    # Built by concatenation, not one bracket-expression literal, so two
    # square brackets never sit side by side anywhere in this file.
    idxpat = "[" "[0-9]+" "]"
  }
  function normkey(k,   t) { t = tolower(k); gsub(/[_-]/, "", t); return t }
  NF < 2 { next }
  {
    path = $1; val = $2
    m = split(path, segs, ".")
    for (i = 1; i <= m; i++) { seg = segs[i]; gsub(idxpat, "", seg); segs[i] = seg }
    through = 1
    for (i = 1; i < m; i++) {
      p = tolower(segs[i])
      if (p != "operation" && p != "request") { through = 0; break }
    }
    final = normkey(segs[m])
    include = 0
    if (through) {
      if (final in structural) include = 1
      else if (m > 1 && (final == "id" || final == "name")) include = 1
    }
    if (!include) next
    anc = ""
    for (i = 1; i < m; i++) {
      p = tolower(segs[i])
      anc = (anc == "" ? p : anc " " p)
    }
    print "D\t" (anc == "" ? val : anc " " val)
    if (final == "method" || final == "httpmethod") print "M\t" val
  }')
descriptor=$(printf '%s\n' "$described" | LC_ALL=C awk -F '\t' '$1 == "D" { print $2 }')

# A Unicode escape inside a descriptor leaf that this script cannot
# normalise (anything outside the ASCII range) never gets classified: it
# comes back from lh_json_leaves as this exact marker, in place of a
# guessed character, and its presence here means ask, not a guess either
# way.
case $descriptor in
  *UNIESCNONASCII*)
    lh_ask_pre "Launchhouse: this GoHighLevel action's name carries text this hook cannot safely read, so check with the founder before it runs. $op" ;;
esac

# The method field's own value, whichever of its allowlisted spellings it
# used (method or httpMethod), read directly rather than through the word
# lists below, so a POST or DELETE is never missed for want of a "method"
# word sitting next to it in the flattened text. It is found the same way
# as the rest of the descriptor above, top level or right under
# operation/request only, so a method value buried in a payload or body
# object (not a structural field at all) is never read as one.
method_val=$(printf '%s\n' "$described" | LC_ALL=C awk -F '\t' '$1 == "M" { print $2; exit }')
method_up=$(printf '%s' "$method_val" | LC_ALL=C tr 'a-z' 'A-Z')

# fetch and search are shared tool-name endings: other connectors (Google
# Drive, Notion, and so on) also expose tools that end this way. For these
# two, judge only when tool_input looks GoHighLevel-shaped: it carries a
# structural descriptor field (the same allowlist as above), or the word
# leadconnector or highlevel, or a locationId, somewhere in the raw input.
# Anything else is not even a GoHighLevel call, so it goes through in
# complete silence, no ask and no deny. This is a shape gate, not the
# classification itself, so unlike the descriptor above it is allowed to
# see all of tool_input, payload included, for its own marker words.
# execute_operation is always judged, on every server name, no shape gate:
# a variant like execute_operation_batch is still always classified.
#
# The settings.json matcher that routes a tool name into this hook at all
# is meant to be anchored so that only GoHighLevel's own tool names ever
# reach here: an execute_operation variant, fetch, or search, each sitting
# right after a server name's own double underscore. But Drive, Notion,
# Gmail and other connectors expose tools whose names also carry the words
# "fetch" and "search" somewhere in them — search_files, notion-search,
# search_threads, and the rest — and if that matcher is ever widened again,
# a tool name like that can land here anyway. So as a backstop of its own,
# any tool name this case statement does not recognise falls to a default
# branch that exits clean, no ask and no deny, rather than being carried
# on into classification below on the strength of a name alone.
case $tool in
  *__execute_operation*) ;;
  *__fetch|*__search)
    if [ -z "$descriptor" ]; then
      shapeflat=" $(lh_ghl_flatten "$tool_input") "
      printf '%s' "$shapeflat" | grep -Eq ' (location id|leadconnector|highlevel) ' || exit 0
    fi ;;
  *) exit 0 ;;
esac

# Flatten the surviving descriptor, padded so every word list below can
# match with a plain grep for " word " and be sure of a real word boundary.
# Empty tool_input or an all-payload tool_input both collapse to an empty
# descriptor above, which matches nothing, refuse, write or read alike, and
# falls through to the final ask.
flat=" $(lh_ghl_flatten "$descriptor") "

# A clear read: at least one plain read word, no write verb (a leading
# "post" or an explicit non-GET method counts as one), and if a method
# field is present at all its value is GET. "read" itself is never one of
# these words: a name that merely contains it, like markConversationAsRead,
# is not a read just because the word shows up in it.
write=0
printf '%s' "$flat" | grep -Eq ' (create|update|upsert|send|add|edit|schedule|publish|tag|untag|book|move|mark|set|reset|assign|unassign|merge|import|export|sync|restore|duplicate|clone|copy|start|stop|enable|disable|activate|deactivate|pause|resume|toggle|approve|reject|submit|upload|attach|detach|link|unlink|invite|register|apply|execute|run|trigger|generate|convert|save|write|change|reply|respond|confirm|verify|cancel) ' && write=1
case $method_up in POST|PUT|PATCH) write=1 ;; esac
firstword=$(printf '%s' "$flat" | awk '{ print $1 }')
[ "$firstword" = post ] && write=1

read_ok=0
if printf '%s' "$flat" | grep -Eq ' (get|list|search|find|fetch|count|stats|statistics|lookup) '; then
  if [ "$write" != 1 ]; then
    case $method_up in "" | GET) read_ok=1 ;; esac
  fi
fi

refuse=0
printf '%s' "$flat" | grep -Eq ' (payment|payments|billing|invoice|invoices|order|orders|subscription|subscriptions|transaction|transactions|coupon|coupons|product|products|price|prices|saas|rebilling|wallet|credit|credits|user|users|permission|permissions|role|roles|snapshot|snapshots|integration|integrations|webhook|webhooks|oauth|delete|remove|archive|void|refund|cancel|trash|purge|erase|destroy|wipe|charge|charges|capture|authorize|payout|payouts|transfer|transfers|checkout) ' && refuse=1
printf '%s' "$flat" | grep -Eq ' api key(s)? ' && refuse=1
printf '%s' "$flat" | grep -Eq ' custom code ' && refuse=1
case $method_up in DELETE) refuse=1 ;; esac
if printf '%s' "$flat" | grep -Eq ' phone number ' && printf '%s' "$flat" | grep -Eq ' purchase '; then refuse=1; fi
if printf '%s' "$flat" | grep -Eq ' (workflows?|campaigns?) ' && [ "$read_ok" != 1 ]; then refuse=1; fi
printf '%s' "$flat" | grep -Eq ' bulk ' && refuse=1
if printf '%s' "$flat" | grep -Eq ' (agency|location) ' && printf '%s' "$flat" | grep -Eq ' (create|delete) '; then refuse=1; fi
if printf '%s' "$flat" | grep -Eq ' (funnel|funnels|website|websites) ' && printf '%s' "$flat" | grep -Eq ' publish '; then refuse=1; fi

if [ "$refuse" = 1 ]; then
  lh_deny_pre "Launchhouse: this kind of GoHighLevel action is refused outright, never done from here. $op"
fi

if [ "$write" = 1 ]; then
  lh_ask_pre "Launchhouse: this can change or send from the founder's GoHighLevel account. Show the founder exactly what it will do, and check they said yes. If it is a reply, check their conversation shows a message from them first: never a first message. $op"
fi

[ "$read_ok" = 1 ] && exit 0

lh_ask_pre "Launchhouse: this GoHighLevel action could not be told apart as a plain read, so check with the founder before it runs. $op"
