#!/bin/sh
# A library, sourced by mcp-guard.sh, for GoHighLevel's six-tool connector
# shape: mcp__*__execute_operation, mcp__*__fetch and mcp__*__search, on any
# server name or uuid. It defines one function, lh_ghl_classify, and never
# runs anything or prints anything on its own — mcp-guard.sh is the only
# caller, and the single PreToolUse dispatcher for every mcp__ tool.
#
# One tool of this shape can do anything from reading a location to
# refunding a payment, so the classification comes from the whole input,
# never the tool name alone.
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
# Four outcomes now, same as mcp-guard.sh's name classifier, in this order:
#   deny  (refuse outright, and the new "no descriptor" case)
#   ask   (a founder-facing prompt, even in auto mode: the small named set
#         below — conversations send, social post create/edit/publish, an
#         email template created, a contact touched, an opportunity updated)
#   guide (every other write: noted for Claude, no prompt forced)
#   silent (a clear read: no output at all)
# It never allows on doubt: an operation this script cannot read, an empty
# or non-object tool_input, or text carrying a Unicode escape it cannot
# safely read, all land on deny ("no descriptor") or guide, never silent.

# lh_ghl_classify tool_name tool_input_raw
# Sets lh_ghl_decision (deny|ask|guide|silent) and lh_ghl_reason. Never
# exits and never prints; mcp-guard.sh turns the result into the hook's own
# JSON output.
lh_ghl_classify() {
  _lhg_tool=$1
  _lhg_ti=$2
  lh_ghl_decision=guide
  lh_ghl_reason="Launchhouse: this GoHighLevel action could not be told apart as a plain read, so show the founder what it will do."

  # tool_input must be a genuine JSON object, not a list, a bare string, a
  # number, empty, or anything else. This is also the new "no operation
  # descriptor" deny case for the plainest form of it: nothing shaped like
  # an object to read a descriptor from at all.
  _lhg_trim=$(printf '%s' "$_lhg_ti" | LC_ALL=C awk '{ sub(/^[ \t\r\n]+/, ""); printf "%s", $0 }')
  case $_lhg_trim in
    "{"*) ;;
    *)
      lh_ghl_decision=deny
      lh_ghl_reason="Launchhouse: this GoHighLevel action carried no operation to read. Call describe_operation and pass the operation id it gives."
      return 0 ;;
  esac

  # A short, safe label for the reason text: the first operation-shaped
  # field tool_input carries, or else a slice of it. Capped and stripped to
  # a plain character set before it goes near JSON output, so a hostile or
  # garbage tool_input can never break the hook's own output.
  _lhg_op=$(lh_json_get operationId "$_lhg_ti") || _lhg_op=""
  [ -n "$_lhg_op" ] || _lhg_op=$(lh_json_get operation_id "$_lhg_ti") || _lhg_op=""
  [ -n "$_lhg_op" ] || _lhg_op=$(lh_json_get operation "$_lhg_ti") || _lhg_op=""
  [ -n "$_lhg_op" ] || _lhg_op=$(lh_json_get name "$_lhg_ti") || _lhg_op=""
  [ -n "$_lhg_op" ] || _lhg_op=$(lh_json_get id "$_lhg_ti") || _lhg_op=""
  [ -n "$_lhg_op" ] || _lhg_op=$(printf '%s' "$_lhg_ti" | cut -c1-80)
  _lhg_op=$(printf '%s' "$_lhg_op" | cut -c1-80 | tr -c 'A-Za-z0-9 _.-' ' ' | awk '{ $1=$1; print }')

  # Every scalar leaf of tool_input, path and value, tab separated. Malformed
  # or truncated JSON here leaves $_lhg_leaves empty, which lands on the same
  # "no descriptor" deny below as a genuinely empty object.
  _lhg_leaves=$(lh_json_leaves "$_lhg_ti") || _lhg_leaves=""

  # The descriptor: the value of every leaf whose own key names the shape of
  # the call (operationId, method, path, and the rest of the allowlist), or
  # whose key is id or name sitting right under an operation or request
  # object, itself never sitting under anything but a chain of operation or
  # request objects, all the way up to tool_input's own top level. Nothing
  # else contributes, key or value: a founder's own post copy, a note field,
  # or anything else typed into a form field, can never read as a refuse or
  # write word, however deep it sits.
  _lhg_described=$(printf '%s\n' "$_lhg_leaves" | LC_ALL=C awk -F '\t' '
    BEGIN {
      split("operationid operation op action method httpmethod path endpoint url route", a, " ")
      for (i in a) structural[a[i]] = 1
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
  _lhg_descriptor=$(printf '%s\n' "$_lhg_described" | LC_ALL=C awk -F '\t' '$1 == "D" { print $2 }')

  # No structural field found anywhere in tool_input: the new deny case.
  if [ -z "$_lhg_descriptor" ]; then
    lh_ghl_decision=deny
    lh_ghl_reason="Launchhouse: this GoHighLevel action carried no operation to read. Call describe_operation and pass the operation id it gives."
    return 0
  fi

  # A Unicode escape inside a descriptor leaf that this script cannot
  # normalise: never classified either way, guided instead.
  case $_lhg_descriptor in
    *UNIESCNONASCII*)
      lh_ghl_decision=guide
      lh_ghl_reason="Launchhouse: this GoHighLevel action's name carries text this hook cannot safely read. Show the founder what it will do. $_lhg_op"
      return 0 ;;
  esac

  _lhg_method_val=$(printf '%s\n' "$_lhg_described" | LC_ALL=C awk -F '\t' '$1 == "M" { print $2; exit }')
  _lhg_method_up=$(printf '%s' "$_lhg_method_val" | LC_ALL=C tr 'a-z' 'A-Z')

  _lhg_flat=" $(lh_ghl_flatten "$_lhg_descriptor") "

  # A clear read: at least one plain read word, no write verb (a leading
  # "post" or an explicit non-GET method counts as one), and if a method
  # field is present at all its value is GET.
  _lhg_write=0
  printf '%s' "$_lhg_flat" | grep -Eq ' (create|update|upsert|send|add|edit|schedule|publish|tag|untag|book|move|mark|set|reset|assign|unassign|merge|import|export|sync|restore|duplicate|clone|copy|start|stop|enable|disable|activate|deactivate|pause|resume|toggle|approve|reject|submit|upload|attach|detach|link|unlink|invite|register|apply|execute|run|trigger|generate|convert|save|write|change|reply|respond|confirm|verify|cancel) ' && _lhg_write=1
  case $_lhg_method_up in POST|PUT|PATCH) _lhg_write=1 ;; esac
  _lhg_first=$(printf '%s' "$_lhg_flat" | awk '{ print $1 }')
  [ "$_lhg_first" = post ] && _lhg_write=1

  _lhg_read_ok=0
  if printf '%s' "$_lhg_flat" | grep -Eq ' (get|list|search|find|fetch|count|stats|statistics|lookup) '; then
    if [ "$_lhg_write" != 1 ]; then
      case $_lhg_method_up in "" | GET) _lhg_read_ok=1 ;; esac
    fi
  fi

  _lhg_refuse=0
  printf '%s' "$_lhg_flat" | grep -Eq ' (payment|payments|billing|invoice|invoices|order|orders|subscription|subscriptions|transaction|transactions|coupon|coupons|product|products|price|prices|saas|rebilling|wallet|credit|credits|user|users|permission|permissions|role|roles|snapshot|snapshots|integration|integrations|webhook|webhooks|oauth|delete|remove|archive|void|refund|cancel|trash|purge|erase|destroy|wipe|charge|charges|capture|authorize|payout|payouts|transfer|transfers|checkout) ' && _lhg_refuse=1
  printf '%s' "$_lhg_flat" | grep -Eq ' api key(s)? ' && _lhg_refuse=1
  printf '%s' "$_lhg_flat" | grep -Eq ' custom code ' && _lhg_refuse=1
  case $_lhg_method_up in DELETE) _lhg_refuse=1 ;; esac
  if printf '%s' "$_lhg_flat" | grep -Eq ' phone number ' && printf '%s' "$_lhg_flat" | grep -Eq ' purchase '; then _lhg_refuse=1; fi
  if printf '%s' "$_lhg_flat" | grep -Eq ' (workflows?|campaigns?) ' && [ "$_lhg_read_ok" != 1 ]; then _lhg_refuse=1; fi
  printf '%s' "$_lhg_flat" | grep -Eq ' bulk ' && _lhg_refuse=1
  if printf '%s' "$_lhg_flat" | grep -Eq ' (agency|location) ' && printf '%s' "$_lhg_flat" | grep -Eq ' (create|delete) '; then _lhg_refuse=1; fi
  if printf '%s' "$_lhg_flat" | grep -Eq ' (funnel|funnels|website|websites) ' && printf '%s' "$_lhg_flat" | grep -Eq ' publish '; then _lhg_refuse=1; fi

  if [ "$_lhg_refuse" = 1 ]; then
    lh_ghl_decision=deny
    lh_ghl_reason="Launchhouse: this kind of GoHighLevel action is refused outright, never done from here. $_lhg_op"
    return 0
  fi

  if [ "$_lhg_read_ok" = 1 ]; then
    lh_ghl_decision=silent
    return 0
  fi

  if [ "$_lhg_write" = 1 ]; then
    # The small named set the owner chose a prompt for even in auto mode:
    # a message actually going out, a social post going live, a template
    # or contact being touched, or a deal moving.
    _lhg_ask=0
    # Any write that touches a conversation or a message asks, not only one
    # whose own name says "send": this is already inside the write==1
    # branch, so the word alone is enough (a create, an update, a
    # sendMessage under conversations all count the same way).
    if printf '%s' "$_lhg_flat" | grep -Eq ' (conversations?|messages?) '; then _lhg_ask=1; fi
    # "social" as its own word covers the hyphenated spelling
    # (social-media-posting_create-post -> social media posting create
    # post); the concatenated spelling some connections use
    # (socialmediaposting_create-post) never splits apart on a word
    # boundary, so it is also matched as a plain substring of the
    # descriptor, case-folded, never against a founder's own payload text
    # since $_lhg_descriptor only ever holds structural-field values.
    _lhg_social=0
    printf '%s' "$_lhg_flat" | grep -Eq ' social ' && _lhg_social=1
    printf '%s' "$_lhg_descriptor" | LC_ALL=C tr 'A-Z' 'a-z' | grep -q 'socialmedia' && _lhg_social=1
    if [ "$_lhg_social" = 1 ] && printf '%s' "$_lhg_flat" | grep -Eq ' post ' && printf '%s' "$_lhg_flat" | grep -Eq ' (create|edit|publish) '; then _lhg_ask=1; fi
    if printf '%s' "$_lhg_flat" | grep -Eq ' template ' && printf '%s' "$_lhg_flat" | grep -Eq ' create '; then _lhg_ask=1; fi
    if printf '%s' "$_lhg_flat" | grep -Eq ' contacts? ' && printf '%s' "$_lhg_flat" | grep -Eq ' (create|update|upsert|add|tag|untag) '; then _lhg_ask=1; fi
    if printf '%s' "$_lhg_flat" | grep -Eq ' opportunit[a-z]* ' && printf '%s' "$_lhg_flat" | grep -Eq ' update '; then _lhg_ask=1; fi

    if [ "$_lhg_ask" = 1 ]; then
      lh_ghl_decision=ask
      lh_ghl_reason="Launchhouse: this can change or send from the founder's GoHighLevel account. Show the founder exactly what it will do, and check they said yes. If it is a reply, check their conversation shows a message from them first: never a first message. $_lhg_op"
    else
      lh_ghl_decision=guide
      lh_ghl_reason="Launchhouse: this can change something in the founder's GoHighLevel account. Show the founder what it will do. $_lhg_op"
    fi
    return 0
  fi

  # Neither a clear read nor a clear write: guided, never silently allowed
  # and never asked outright, since it is not one of the named ask cases.
  lh_ghl_decision=guide
  lh_ghl_reason="Launchhouse: this GoHighLevel action could not be told apart as a plain read, so show the founder what it will do. $_lhg_op"
  return 0
}

# fetch and search are shared tool-name endings: other connectors (Google
# Drive, Notion, and so on) also expose tools that end this way. For these
# two, mcp-guard.sh should only send the call here when tool_input carries
# an actual GoHighLevel marker: a locationId, the word leadconnector or
# highlevel, or an operation descriptor field named operationId,
# operation_id or operation. A plain structural-sounding key alone (url,
# method, path, id, name — the kind of field almost any connector's tools
# carry) is never enough on its own; without this, an ordinary Drive or
# web fetch of a {"url": ...} would misroute here just because "url" is
# also one of GoHighLevel's own descriptor field names. This helper is the
# shape gate; it is not the classification itself, so unlike
# lh_ghl_classify it is allowed to see all of tool_input, payload included,
# for its own marker words — but only ever the first 4KB of it, so a long
# draft or message body sitting in tool_input can never make this check
# slow. execute_operation is always judged, no shape gate: mcp-guard.sh
# routes it here on tool name alone.
lh_ghl_shaped() {
  _lhg_shape_cap=$(printf '%s' "$1" | cut -c1-4096)
  case $_lhg_shape_cap in
    *'"operationId"'*|*'"operation_id"'*|*'"operation"'*) return 0 ;;
  esac
  _lhg_shape_flat=" $(lh_ghl_flatten "$_lhg_shape_cap") "
  printf '%s' "$_lhg_shape_flat" | grep -Eq ' (location id|leadconnector|highlevel) '
}
