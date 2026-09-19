#!/bin/sh
# PreToolUse on every mcp__ tool call, whatever connector it belongs to. One
# script, one settings.json entry (matcher "^mcp__"), so exactly one hook
# ever decides a given call: this replaces the old deny-mcp.sh, ask-mcp.sh
# and ghl-op.sh's own settings.json entries. ghl-op.sh remains, but only as
# a sourced library now (lh_ghl_classify, lh_ghl_shaped), never run on its
# own — it is sourced unconditionally below, before anything can call
# either function, whichever path a tool takes.
#
# Four outcomes, always in this order of precedence: deny beats ask beats
# guide beats silent.
#   deny   permissionDecision "deny", blocks the call in every mode,
#          including bypassPermissions. Only the small, fixed set tied to
#          the six rules: money leaving the founder's account, and a tool
#          that sends or connects to a real person without them seeing it
#          first.
#   ask    permissionDecision "ask". The owner chose a forced prompt for a
#          few actions even in auto mode: they reach a real person or spend
#          money, and are common enough to name.
#   guide  hookSpecificOutput with additionalContext only, no
#          permissionDecision key at all, so a call is never held up by
#          this hook that the founder's own mode would otherwise let
#          through. This is Launchhouse's "enrich, never hinder" tier: it
#          tells Claude the rule, mode-aware, and leaves the decision to
#          the session's own permission mode.
#   silent no output at all: a tool this hook can positively tell is a
#          read, and nothing about it also reads as a deny, ask or write
#          signal — those are all checked first, independently of whether
#          a read word also appears in the name, so "read_and_send_email"
#          never slips past send_email's own deny just because it also
#          says "read".
#
# Never "ask" outside the small named set above, and this hook never adds a
# prompt on top of the founder's mode by itself: bypassPermissions plus
# auto plus dontAsk are what most founders run in, and a hook that piles on
# asks in that mode is the exact complaint that started this rewrite.
#
# Only in a Launchhouse folder, or one right next to it (the wrong-folder
# case). And even then, deny and ask only fire when the folder actually
# carries the marker (lh_active): a folder that merely looks like one
# nearby never gets blocked or prompted, only guided at most.

. "$(dirname "$0")/lib.sh" 2>/dev/null || exit 0
. "$(dirname "$0")/ghl-op.sh" 2>/dev/null || exit 0
lh_active && lh_mg_active=1 || lh_mg_active=0
if [ "$lh_mg_active" != 1 ] && [ -z "$(lh_near)" ]; then exit 0; fi

input=$(cat) || exit 0

# tool_name and permission_mode are read structurally, top level only
# (lh_json_get_raw walks the envelope as one JSON object and skips whole
# nested containers without ever looking inside them for a key), never by
# the first textual match anywhere in the envelope: a tool_input carrying
# its own nested "tool_name" or "permission_mode" field, however deep, can
# never spoof either one. Each is also properly unescaped, \uXXXX included,
# rather than the lossy "?" placeholder lh_json_get itself uses for \u: a
# tool name hiding a word (buy, purchase, send) behind an ASCII \u escape
# is read correctly, and one hiding behind a \u escape this hook cannot
# safely resolve to ASCII is never silently trusted either way — the whole
# call is asked about instead, further down.
tool_raw=$(lh_json_get_raw tool_name "$input" 2>/dev/null) || tool_raw=""
lh_unescape_json_string "$tool_raw"
tool=$lh_unescape_result
tool_nonascii=$lh_unescape_nonascii
[ -n "$tool" ] || exit 0

mode_raw=$(lh_json_get_raw permission_mode "$input" 2>/dev/null) || mode_raw=""
lh_unescape_json_string "$mode_raw"
mode=$lh_unescape_result

decision=guide
reason="Launchhouse: this changes or sends something outside the founder's folder. Show the founder exactly what it will do and get a yes in chat first, unless they already said yes to exactly this."

if [ "$tool_nonascii" = 1 ]; then
  # A tool name this hook could not fully read: never silent, never guide,
  # never trusted enough to run its own word lists against a partly
  # unreadable name. Always a prompt.
  decision=ask
  reason="Launchhouse: this tool's own name carries text this hook cannot safely read, so check with the founder before it runs."
else

# Route GoHighLevel's connector shape (execute_operation on any server name
# or uuid, and fetch/search when the input looks GoHighLevel-shaped) to the
# classifier that reads the whole input. Everything else goes to the name
# classifier below, which never walks tool_input except for the one Apollo
# field it is allowed to read.
ghl=0
case $tool in
  *__execute_operation*) ghl=1 ;;
  *__fetch|*__search)
    tool_input_peek=$(lh_json_get_raw tool_input "$input" 2>/dev/null) || tool_input_peek=""
    lh_ghl_shaped "$tool_input_peek" && ghl=1 ;;
esac

if [ "$ghl" = 1 ]; then
  # The whole envelope must parse as one clean JSON object, nothing
  # trailing after it closes. This is only worth the full parse on the
  # GoHighLevel path (the name classifier below never pays this cost), and
  # a failure here is the same doubt as an unreadable tool_input: no
  # operation to read, so deny with the same "call describe_operation"
  # guidance, never a silent allow.
  if ! lh_json_leaves "$input" >/dev/null 2>&1; then
    decision=deny
    reason="Launchhouse: this GoHighLevel action arrived in a shape this hook could not read. Call describe_operation and pass the operation id it gives."
  else
    tool_input=$(lh_json_get_raw tool_input "$input" 2>/dev/null) || tool_input=""
    lh_ghl_classify "$tool" "$tool_input"
    decision=$lh_ghl_decision
    reason=$lh_ghl_reason
  fi
else
  # The name classifier: fast, reads only tool_name and permission_mode,
  # and tool_input's top-level "active" field for Apollo sequences only
  # (never anything else in tool_input, and never a nested or payload
  # field), so a call carrying a large draft or a long message body is
  # never walked into for this.
  flat=" $(lh_ghl_flatten "$tool") "

  is_read=0
  printf '%s' "$flat" | grep -Eq ' (get|list|search|find|fetch|read|describe|show|lookup|count|index|query|status) ' && is_read=1
  case $tool in *_read_*) is_read=1 ;; esac

  decided=0

  # ---------------------------------------------------------------- deny
  # Every deny check below runs whether or not a read word also appears in
  # the name: is_read is only ever used later, to decide between silent
  # and guide once deny and ask have both had their say. Otherwise a name
  # like "read_and_send_email" reads its way past a send check that only
  # fired when nothing looked like a read.
  case $tool in
    *__send_message|*__reply|*__forward|*__send_inbox_draft|*__send_email|*__send-email)
      decision=deny
      reason="Launchhouse never sends from the founder's mailbox. Claude writes drafts only, and the founder presses Send themselves."
      decided=1 ;;
    *__create_filter)
      decision=deny
      reason="Launchhouse never sets up mail rules, which can forward or file the founder's mail without them seeing it. If they want one, they make it in their mail app themselves."
      decided=1 ;;
    *apollo_emailer_messages_send_now|*apollo_emailer_messages_create|*apollo_emailer_campaigns_approve)
      decision=deny
      reason="Launchhouse builds the Apollo sequence paused and stops there. The founder reads it and presses start in Apollo themselves."
      decided=1 ;;
    *apollo_email_account_purchase_create)
      decision=deny
      reason="Launchhouse never buys anything on the founder's account. If they want a mailbox, they buy it in Apollo themselves."
      decided=1 ;;
  esac

  # Any tool whose name says it sends an email, whichever connector: a
  # mailbox tool, Resend, or anything else. "send" immediately followed by
  # "email" (send_email, send-email, "send an email", read_and_send_email)
  # is Launchhouse's mailbox rule, drafts only, wherever it shows up in the
  # name. Word order matters here on purpose, so a read-only status check
  # like "email_send_status" (email before send) is not swept in by this.
  if [ "$decided" != 1 ] && printf '%s' "$flat" | grep -Eq ' send email '; then
    decision=deny
    reason="Launchhouse never sends email from here. Claude writes drafts only, and the founder presses Send themselves."
    decided=1
  fi

  # A cold send: "cold" beside a send word is cold outreach by a tool,
  # which Launchhouse never does. Cold messages go out by hand.
  if [ "$decided" != 1 ] && printf '%s' "$flat" | grep -Eq ' cold ' && printf '%s' "$flat" | grep -Eq ' send '; then
    decision=deny
    reason="Launchhouse never sends a cold message by tool. Cold outreach is sent by hand, by the founder, spread out."
    decided=1
  fi

  # Turning a sequence or campaign on: the founder presses start
  # themselves, in the vendor's own app, having read it. This is the same
  # rule as the Apollo active:true check further down, by name alone, for
  # any tool that says it activates, enables, starts or resumes one.
  if [ "$decided" != 1 ] && printf '%s' "$flat" | grep -Eq ' (sequences?|campaigns?) ' && printf '%s' "$flat" | grep -Eq ' (activate|enable|start|resume) '; then
    decision=deny
    reason="Launchhouse builds sequences and campaigns paused. The founder switches one on themselves, in the vendor's own app, having read it."
    decided=1
  fi

  if [ "$decided" != 1 ]; then
    case $tool in
      *apollo_sequences_create|*apollo_sequences_update)
        seq_ti=$(lh_json_get_raw tool_input "$input" 2>/dev/null) || seq_ti=""
        if [ -n "$seq_ti" ]; then
          seq_leaves=$(lh_json_leaves "$seq_ti" 2>/dev/null)
          if printf '%s\n' "$seq_leaves" | awk -F '\t' '$1 == "active" { v = tolower($2); if (v == "true") { print "yes"; exit } }' | grep -q yes; then
            decision=deny
            reason="Launchhouse builds sequences paused, with active set to false. The founder switches the sequence on in Apollo themselves, having read it. Make the same call with active false."
            decided=1
          fi
        fi ;;
    esac
  fi

  if [ "$decided" != 1 ] && printf '%s' "$tool" | grep -qi 'linkedin'; then
    case $tool in
      *__send_message|*__connect_with_person)
        decision=deny
        reason="Launchhouse never sends or connects on LinkedIn from here. Cold DMs are sent by hand, by the founder, from LinkedIn itself."
        decided=1 ;;
    esac
  fi

  if [ "$decided" != 1 ] && printf '%s' "$flat" | grep -Eq ' (buy|purchase|checkout) '; then
    decision=deny
    reason="Launchhouse never spends the founder's money from here. If they want this, they buy it themselves in the vendor's own app."
    decided=1
  fi

  if [ "$decided" != 1 ] && printf '%s' "$flat" | grep -Eq ' (broadcast|batch|bulk) ' && printf '%s' "$flat" | grep -Eq ' (send|email) '; then
    decision=deny
    reason="Launchhouse never sends bulk or broadcast email from here. If the founder wants this sent, they send it from the vendor's own app."
    decided=1
  fi

  # ----------------------------------------------------------------- ask
  if [ "$decided" != 1 ]; then
    case $tool in
      *__create_event|*__update_event|*__respond_to_event)
        decision=ask
        reason="Launchhouse: this changes the founder's calendar or answers an invite for them. Show them what it will do and check they said yes."
        decided=1 ;;
      *apollo_people_match|*apollo_people_bulk_match|*apollo_organizations_enrich|*apollo_organizations_bulk_enrich|*apollo_emailer_campaigns_add_contact_ids)
        decision=ask
        reason="Launchhouse: this spends Apollo credits, or adds people to a sequence. Check the founder has seen the cost and said yes."
        decided=1 ;;
    esac
  fi

  # Deleting, removing or cancelling something that reaches a real person:
  # a calendar event, a contact, a post already out. Not a Launchhouse
  # refuse case on its own (that is GoHighLevel's own named list), but
  # never silent and never just noted either, since someone else may
  # already have that event, or be expecting that post.
  if [ "$decided" != 1 ] && printf '%s' "$flat" | grep -Eq ' (delete|remove|cancel) ' && printf '%s' "$flat" | grep -Eq ' (event|events|contact|contacts|post|posts) '; then
    decision=ask
    reason="Launchhouse: this removes something that may reach or already have reached a real person. Show the founder what it will do and check they said yes."
    decided=1
  fi

  if [ "$decided" != 1 ] && printf '%s' "$flat" | grep -Eq ' (send|reply|forward|share|invite|publish|post) '; then
    decision=ask
    reason="Launchhouse: this can send or publish something outside the founder's folder. Show the founder exactly what goes out, where and when, and get their yes. Reply only to someone who wrote first."
    decided=1
  fi

  # -------------------------------------------------------- silent / guide
  if [ "$decided" != 1 ]; then
    nonread=0
    printf '%s' "$flat" | grep -Eq ' (create|update|upsert|edit|send|post|publish|schedule|invite|share|add|remove|delete|trash|archive|move|upload|write|trigger|approve|book|reply|submit|tag|assign|connect|import|sync|forward|buy|purchase|checkout|broadcast|batch|bulk|merge|duplicate|clone|copy|start|stop|enable|disable|activate|deactivate|pause|resume|toggle|reject|attach|detach|link|unlink|register|apply|generate|convert|save|change|respond|confirm|verify|cancel|set|reset|unassign|restore|mark|patch|put|deploy|promote|rollback|invalidate|provision|install|uninstall|revoke|issue|transfer|rotate) ' && nonread=1
    if [ "$is_read" = 1 ] && [ "$nonread" != 1 ]; then
      decision=silent
    else
      decision=guide
      reason="Launchhouse: this changes or sends something outside the founder's folder. Show the founder exactly what it will do and get a yes in chat first, unless they already said yes to exactly this."
    fi
  fi
fi
fi

# Only a Launchhouse folder that actually carries the marker gets held up:
# a folder merely near one (the wrong-folder case) is guided at most.
if [ "$lh_mg_active" != 1 ]; then
  case $decision in deny|ask) decision=guide ;; esac
fi

case $decision in
  deny) lh_deny_pre "$reason" ;;
  ask) lh_ask_pre "$reason" ;;
  guide) lh_guide_pre "$reason $(lh_mode_note "$mode")" ;;
  *) exit 0 ;;
esac
