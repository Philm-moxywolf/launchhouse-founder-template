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
#
# Skill packs (.claude/skill-packs/) can add their own extra rules on top of
# everything below, one pack per connected tool. compiled-policy.sh, built
# by skill-packs.sh --compile, is sourced here if it is present and parses
# cleanly (checked with sh -n first, since a syntax error inside a sourced
# script is otherwise fatal to this one too, and this hook fails open on
# any doubt). A pack can only ever tighten this hook's own decision, never
# loosen it: see the application further down, just above the wrong-folder
# downgrade.

. "$(dirname "$0")/lib.sh" 2>/dev/null || exit 0
. "$(dirname "$0")/ghl-op.sh" 2>/dev/null || exit 0
lh_compiled_policy="$(dirname "$0")/../skill-packs/compiled-policy.sh"
# One-release fallback: a folder updated from before the tool-packs ->
# skill-packs rename may still only have the old directory. Prefer the new
# path; fall back to the old one when the new one is either not there yet
# OR present but broken (fails its own sh -n syntax check) -- a corrupt or
# half-written compiled-policy.sh at the new path must not silently source
# nothing when a good one still exists at the old path.
lh_compiled_policy_legacy="$(dirname "$0")/../tool-packs/compiled-policy.sh"
if { [ ! -f "$lh_compiled_policy" ] || ! sh -n "$lh_compiled_policy" 2>/dev/null; } \
   && [ -f "$lh_compiled_policy_legacy" ] && sh -n "$lh_compiled_policy_legacy" 2>/dev/null; then
  lh_compiled_policy="$lh_compiled_policy_legacy"
fi
if [ -f "$lh_compiled_policy" ] && sh -n "$lh_compiled_policy" 2>/dev/null; then
  . "$lh_compiled_policy" 2>/dev/null || true
fi
# A short, bounded mkdir-based lock guarding a grant file's read-check-
# decrement-write, so two concurrent specialist calls can never both read
# "1 remaining" and both proceed: mkdir is atomic, unlike a check-then-write
# race on the file itself. A lock dir older than 60 seconds is treated as
# abandoned (a crashed writer) and cleared before retrying, so one dead
# process can never wedge every future grant. Bounded: the caller denies
# rather than wait past a handful of short retries, which is the safe
# answer for an approval gate. approve.sh takes the same lock, on the same
# path, before it grants or clears, so the two scripts never race each other
# either.
lh_mg_lock() {
  ld=$1
  n=0
  while [ "$n" -lt 30 ]; do
    if mkdir "$ld" 2>/dev/null; then
      lts=$(date +%s 2>/dev/null) && printf '%s' "$lts" > "$ld/ts" 2>/dev/null
      return 0
    fi
    if [ -f "$ld/ts" ]; then
      ts=$(cat "$ld/ts" 2>/dev/null)
      case $ts in ''|*[!0-9]*) ts=0 ;; esac
      now2=$(date +%s 2>/dev/null) || now2=0
      case $now2 in ''|*[!0-9]*) now2=0 ;; esac
      if [ "$now2" -gt 0 ] && [ "$ts" -gt 0 ] && [ $((now2 - ts)) -gt 60 ]; then
        rm -rf "$ld" 2>/dev/null
        continue
      fi
    fi
    n=$((n + 1))
    sleep 0.1 2>/dev/null || :
  done
  return 1
}

lh_mg_unlock() {
  rm -rf "$1" 2>/dev/null
}

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

# Skill packs: apply the strictest pack policy for this tool's suffix, but
# only when it is stricter than the decision already reached above (deny >
# ask > guide > silent). A pack's own compiled rules can only tighten this
# hook, never loosen it. Skipped for a name this hook could not fully read
# (tool_nonascii), the same doubt that already forced decision=ask above.
if [ "$tool_nonascii" != 1 ] && command -v lh_pack_policy >/dev/null 2>&1; then
  suffix=${tool##*__}
  lh_pack_policy "$suffix"
  if [ -n "$lh_pack_decision" ]; then
    apply=0
    case $lh_pack_decision in
      deny) case $decision in deny) ;; *) apply=1 ;; esac ;;
      ask) case $decision in deny|ask) ;; *) apply=1 ;; esac ;;
    esac
    [ "$apply" = 1 ] && { decision=$lh_pack_decision; reason=$lh_pack_reason; }
  fi
fi

# Skill packs: point Claude at the pack that covers this connector, or, when
# none does, offer to build one. Only said when there is something to say
# about at all (decision is not silent): a plain read never gets a note.
if [ "$tool_nonascii" != 1 ] && [ "$decision" != silent ] && command -v lh_pack_detect >/dev/null 2>&1; then
  suffix=${tool##*__}
  lh_pack_detect "$suffix"
  if [ -n "$lh_pack_id" ]; then
    reason="$reason The $lh_pack_name expert pack is at .claude/skill-packs/$lh_pack_id/: read its references/knowledge.md before acting."
  else
    reason="$reason No Launchhouse expert pack covers this connector yet: once in this conversation, offer the founder to build one with the skill-pack-builder skill."
  fi
fi

# Only a Launchhouse folder that actually carries the marker gets held up:
# a folder merely near one (the wrong-folder case) is guided at most.
if [ "$lh_mg_active" != 1 ]; then
  case $decision in deny|ask) decision=guide ;; esac
fi

# Specialist approval grants. Claude Code's PreToolUse input carries a
# top-level agent_type (and agent_id) when the call comes from a subagent
# (https://code.claude.com/docs/en/hooks). Read structurally, the same safe
# top-level reader tool_name itself uses above, so a tool_input field a
# founder's own data happens to name agent_type can never spoof this.
#
# A specialist (an agent_type ending in "-specialist") can only run a tool
# call the main conversation has already granted with approve.sh, once the
# founder has said yes to the specialist's own PHASE: plan. A specialist
# never talks to the founder itself, so it cannot be the one asking, or the
# one deciding a guide note is enough: every non-silent, non-deny decision
# for a specialist needs a live grant, ask and guide alike. A grant only
# ever unblocks a call this hook would otherwise hold up waiting on a live
# prompt the subagent cannot show — it never turns a deny into anything
# else, and it never turns the found decision into something looser than
# mcp-guard.sh already reached on its own.
#
# Any other subagent (agent_type non-empty, not a "-specialist"): it cannot
# show the founder a live prompt any more than a specialist can, and it is
# not built to run the two-phase plan/execute/grant protocol that makes an
# unattended connector call safe. So a non-silent, non-deny decision for one
# of these is routed to deny too, sending the change through that tool's own
# specialist instead — never left at ask or guide, which this subagent has
# no way to make the founder actually see. Only the main thread (agent_type
# empty) keeps the decision the classifier above reached on its own.
if [ "$tool_nonascii" != 1 ]; then
  agent_type_raw=$(lh_json_get_raw agent_type "$input" 2>/dev/null) || agent_type_raw=""
  lh_unescape_json_string "$agent_type_raw"
  agent_type=$lh_unescape_result

  case $agent_type in
    *-specialist)
      case $decision in
        deny|silent) ;;  # unchanged, exactly as mcp-guard.sh already decided
        *)
          pack_id=${agent_type%-specialist}
          approve_reason="This specialist can only make changes the founder approved in chat. Return to the main conversation with PHASE: plan; the main conversation grants the approved actions with approve.sh before PHASE: execute."
          bk=$(lh_bk_dir 2>/dev/null) || bk=""
          if [ -z "$bk" ]; then
            # The approvals folder itself could not even be resolved (no
            # git dir found): fail closed for a specialist, never fail
            # open here, unlike every other doubt-case in this hook.
            decision=deny
            reason=$approve_reason
          else
            approve_file="$bk/approvals/$pack_id"
            suffix=${tool##*__}
            now=$(date +%s 2>/dev/null) || now=""
            case $now in ''|*[!0-9]*) now="" ;; esac
            if [ -z "$now" ]; then
              # date +%s failed, or the shell running it returned something
              # that is not a plain integer: never trust an unreadable
              # clock to judge an expiry. Deny rather than risk treating an
              # expired grant as live.
              decision=deny
              reason=$approve_reason
            else
              lock="$approve_file.lock"
              if lh_mg_lock "$lock"; then
                granted_line=""
                if [ -f "$approve_file" ] 2>/dev/null; then
                  # A malformed line (remaining or expiry not a plain
                  # integer, from a hand-edited file or a partial write
                  # this lock did not catch) is skipped, never treated as
                  # a live grant.
                  granted_line=$(awk -F '\t' -v s="$suffix" -v now="$now" '
                    $1 == s {
                      rem = $2; expv = $3
                      if (rem !~ /^[0-9]+$/ || expv !~ /^[0-9]+$/) next
                      if (rem + 0 > 0 && expv + 0 > now) { print; exit }
                    }
                  ' "$approve_file" 2>/dev/null)
                fi
                if [ -n "$granted_line" ]; then
                  # A live grant: decrement it, the only write this hook
                  # ever makes, and only on this path, under the same lock
                  # that guarded the read above — so two concurrent calls
                  # for the same 1-count grant can never both read
                  # "1 remaining" and both proceed. The decision already
                  # reached (ask or guide) stays exactly as it is — a grant
                  # never loosens it to silent, and never converts an ask
                  # into an allow: the founder's own prompt for that call
                  # is what mitigates a grant being keyed by tool suffix
                  # alone (not by input), so an approved "ask" tool still
                  # shows the founder the real call before it runs.
                  rem=$(printf '%s' "$granted_line" | awk -F '\t' '{ print $2 - 1 }')
                  expv=$(printf '%s' "$granted_line" | awk -F '\t' '{ print $3 }')
                  tmp="$approve_file.tmp.$$"
                  if awk -F '\t' -v OFS='\t' -v s="$suffix" -v rem="$rem" -v expv="$expv" '
                    BEGIN { done = 0 }
                    $1 == s && done == 0 { done = 1; if (rem > 0) print s, rem, expv; next }
                    { print }
                  ' "$approve_file" > "$tmp" 2>/dev/null && mv "$tmp" "$approve_file" 2>/dev/null; then
                    :
                  else
                    # The write failed: never leave the grant looking
                    # spent when it was not actually consumed. Remove the
                    # half-written temp file and deny this call; the grant
                    # itself is untouched, so a retry can still use it.
                    rm -f "$tmp" 2>/dev/null
                    decision=deny
                    reason=$approve_reason
                  fi
                else
                  decision=deny
                  reason=$approve_reason
                fi
                lh_mg_unlock "$lock"
              else
                # Could not take the lock within the bounded retry: another
                # call is mid-write. Deny rather than read a file that
                # might be half-written, or race that call's own decrement.
                decision=deny
                reason=$approve_reason
              fi
            fi
          fi
          ;;
      esac
      ;;
    "")
      ;;  # the main thread: unaffected
    *)
      case $decision in
        deny|silent) ;;  # a read stays silent; a deny is never loosened
        *)
          decision=deny
          reason="Connector changes from a helper go through that tool's specialist, after the founder's yes."
          ;;
      esac
      ;;
  esac
fi

case $decision in
  deny) lh_deny_pre "$reason" ;;
  ask) lh_ask_pre "$reason" ;;
  guide) lh_guide_pre "$reason $(lh_mode_note "$mode")" ;;
  *) exit 0 ;;
esac
