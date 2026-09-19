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
# field (body, text, summary and the rest lh_json_leaves' caller below
# excludes) — a founder's own post copy can say "order" or "cancel" without
# that ever reading as a refuse or a deny. lh_json_leaves (in lib.sh) walks
# tool_input to every scalar leaf with its key path; a leaf under a payload
# key contributes nothing at all, key names or value, to what gets matched.
#
# The surviving descriptor is flattened to one lower case line
# (lh_ghl_flatten, in lib.sh) and matched with word lists on word
# boundaries, never a bare substring test, so "post" inside "posting" or
# "get" inside "target" cannot fire a rule by accident.
#
# Precedence, always: refuse beats write beats read beats ask.
#   refuse (deny, no discussion): payments, billing, deletes, workflow
#     changes, users, permissions, snapshots, integrations, and the rest of
#     the list below.
#   write (ask the founder): a write verb, or a POST/PUT/PATCH method.
#   read (let it go quietly): a read verb, or a GET method, and nothing
#     above fired.
#   ask: anything this script cannot tell apart, including an unknown
#     operation, empty input, and JSON it cannot make sense of at all. It
#     never allows on doubt, and a parsing failure never becomes a crash, a
#     silent allow, or a line of broken JSON.

. "$(dirname "$0")/lib.sh" 2>/dev/null || exit 0
lh_active || [ -n "$(lh_near)" ] || exit 0

input=$(cat) || exit 0
tool=$(lh_json_get tool_name "$input") || tool=""

# The only part of the envelope anything below ever looks at. Everything
# else in $input (cwd, transcript_path, session_id, permission_mode, ...)
# stops here. If tool_input is missing or the envelope itself is not valid
# JSON, tool_input comes back empty, which lands the same as an empty
# descriptor below: ask, never allow, never deny.
tool_input=$(lh_json_get_raw tool_input "$input") || tool_input=""

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

# fetch and search are shared tool-name endings: other connectors (Google
# Drive, Notion, and so on) also expose tools that end this way. For these
# two, judge only when tool_input looks GoHighLevel-shaped: an operation id,
# a locationId, or the word leadconnector or highlevel somewhere in it.
# Anything else is not even a GoHighLevel call, so it goes through in
# complete silence, no ask and no deny. This is a shape gate, not the
# classification itself, so unlike the descriptor below it is allowed to see
# all of tool_input, payload included. execute_operation is always judged,
# on every server name.
case $tool in
  *__fetch|*__search)
    shapeflat=" $(lh_ghl_flatten "$tool_input") "
    printf '%s' "$shapeflat" | grep -Eq ' (operation id|location id|leadconnector|highlevel) ' || exit 0 ;;
esac

# The descriptor: every scalar leaf of tool_input whose key path never
# passes through a payload/container key at any level (case-insensitive
# match against the list below). A surviving leaf contributes both its key
# names and its value; an excluded leaf contributes nothing at all. This is
# what keeps a founder's own post copy, or anything else typed into a form
# field, from ever being read as a refuse or write word — only the shape of
# the call itself (its operation id, method, ids) can do that.
leaves=$(lh_json_leaves "$tool_input") && leaves_ok=1 || leaves_ok=0
descriptor=""
if [ "$leaves_ok" = 1 ] && [ -n "$leaves" ]; then
  descriptor=$(printf '%s\n' "$leaves" | LC_ALL=C awk -F '\t' '
    BEGIN {
      split("params parameters arguments args body data input payload query fields values value content message messages text summary caption title description html attachments media", a, " ")
      for (i in a) payload[a[i]] = 1
      # Built by concatenation rather than as one bracket-expression
      # literal, so two square brackets never sit side by side in this
      # scripts own text: the house bashism check looks for exactly that,
      # anywhere in a POSIX-sh file, awk source included, and would
      # otherwise mistake this for a bash double-bracket test.
      idxpat = "[" "[0-9]+" "]"
    }
    {
      path = $1; val = $2
      under = 0; out = ""
      m = split(path, segs, ".")
      for (i = 1; i <= m; i++) {
        seg = segs[i]
        gsub(idxpat, "", seg)
        if (tolower(seg) in payload) under = 1
        out = (out == "" ? seg : out " " seg)
      }
      if (!under) printf "%s %s\n", out, val
    }')
fi

# Flatten the surviving descriptor, padded so every word list below can
# match with a plain grep for " word " and be sure of a real word boundary.
# Empty tool_input or an all-payload tool_input both collapse to an empty
# descriptor here, which matches nothing, refuse, write or read alike, and
# falls through to the final ask.
flat=" $(lh_ghl_flatten "$descriptor") "

refuse=0
printf '%s' "$flat" | grep -Eq ' (payment|payments|billing|invoice|invoices|order|orders|subscription|subscriptions|transaction|transactions|coupon|coupons|product|products|price|prices|saas|rebilling|wallet|credit|credits|users|permissions|snapshot|snapshots|integration|integrations|webhook|webhooks|oauth|delete|remove|archive|void|refund|cancel) ' && refuse=1
printf '%s' "$flat" | grep -Eq ' api key(s)? ' && refuse=1
printf '%s' "$flat" | grep -Eq ' custom code ' && refuse=1
printf '%s' "$flat" | grep -Eq ' method delete ' && refuse=1
if printf '%s' "$flat" | grep -Eq ' phone number ' && printf '%s' "$flat" | grep -Eq ' purchase '; then refuse=1; fi
if printf '%s' "$flat" | grep -Eq ' workflows? ' && printf '%s' "$flat" | grep -Eq ' (create|update|trigger|add) '; then refuse=1; fi
if printf '%s' "$flat" | grep -Eq ' campaigns? ' && printf '%s' "$flat" | grep -Eq ' add '; then refuse=1; fi
printf '%s' "$flat" | grep -Eq ' bulk ' && refuse=1
if printf '%s' "$flat" | grep -Eq ' (agency|location) ' && printf '%s' "$flat" | grep -Eq ' (create|delete) '; then refuse=1; fi
if printf '%s' "$flat" | grep -Eq ' (funnel|funnels|website|websites) ' && printf '%s' "$flat" | grep -Eq ' publish '; then refuse=1; fi

if [ "$refuse" = 1 ]; then
  lh_deny_pre "Launchhouse: this kind of GoHighLevel action is refused outright, never done from here. $op"
fi

write=0
printf '%s' "$flat" | grep -Eq ' (create|update|upsert|send|add|edit|schedule|publish|tag|book|move) ' && write=1
printf '%s' "$flat" | grep -Eq ' method (post|put|patch) ' && write=1

if [ "$write" = 1 ]; then
  lh_ask_pre "Launchhouse: this can change or send from the founder's GoHighLevel account. Show the founder exactly what it will do, and check they said yes. If it is a reply, check their conversation shows a message from them first: never a first message. $op"
fi

read_ok=0
printf '%s' "$flat" | grep -Eq ' (get|list|search|read|find|fetch|stats|statistics) ' && read_ok=1
printf '%s' "$flat" | grep -Eq ' method get ' && read_ok=1

[ "$read_ok" = 1 ] && exit 0

lh_ask_pre "Launchhouse: this GoHighLevel action could not be told apart as a plain read, so check with the founder before it runs. $op"
