#!/bin/sh
# Runs the rules over the fixture files and prints pass or fail for each case.
#
# Usage: sh .claude/tests/run.sh
#
# A fixture named pass-*.md must produce no held line for the rule it is about.
# A fixture named hold-*.md must still be held. The rule a fixture is about is
# read from its first line, which is a comment of the form:
#   <!-- rule: dm.offered -->

here=$(dirname "$0")
awkfile="$here/../scripts/rules.awk"
fail=0

for f in "$here"/fixtures/*.md; do
  [ -f "$f" ] || continue
  name=$(basename "$f")
  rule=$(sed -n '1s/.*rule:[[:space:]]*\([a-z.-]*\).*/\1/p' "$f")
  [ -n "$rule" ] || rule=dm.offered
  track=$(sed -n '1s/.*track:[[:space:]]*\(b2[bc]\).*/\1/p' "$f")
  [ -n "$track" ] || track=b2c
  held=$(awk -v track="$track" -v brain=0 -f "$awkfile" "$f" 2>/dev/null | grep -c "^HOLD	.*	$rule	")

  case $name in
    pass-*) want=0 ;;
    hold-*) want=1 ;;
    *) printf 'SKIP  %s (name it pass-... or hold-...)\n' "$name"; continue ;;
  esac

  if [ "$want" = 0 ] && [ "$held" = 0 ]; then
    printf 'PASS  %s  not held, as it should be\n' "$name"
  elif [ "$want" = 1 ] && [ "$held" -gt 0 ]; then
    printf 'PASS  %s  still held, as it should be\n' "$name"
  elif [ "$want" = 0 ]; then
    printf 'FAIL  %s  held, and it should not be\n' "$name"; fail=1
  else
    printf 'FAIL  %s  not held, and it should be\n' "$name"; fail=1
  fi
done

# ---------------------------------------------------------------- the hooks
# The write checks and the tool guards, run as Claude Code runs them, against a
# made up founder folder in the temp folder. Never the founder's own folder.

work=${TMPDIR:-/tmp}/lh-hook-test.$$
trap 'rm -rf "$work"' EXIT
scripts=$(cd "$here/../scripts" && pwd)
settings="$here/../settings.json"
mkdir -p "$work/.claude" "$work/growth-engine/.state" "$work/growth-engine/drafts" \
  "$work/growth-engine/inbox/uploads" "$work/growth-engine/brain/voice-samples" "$work/src" \
  "$work/growth-engine/engines/audience" "$work/growth-engine/export" || exit 1
cp -R "$scripts" "$work/.claude/" || exit 1
: > "$work/growth-engine/.launchhouse"
printf '# Founder Brain\n\n- **Track:** b2c\n\n## Thesis\nSmall batch bakery.\n' > "$work/growth-engine/brain/founder-brain.md"
cold='Use a bot to DM every new follower with the offer.'
ge="$work/growth-engine"

hook() { # script, tool, key, value (the value is put into the JSON as it is)
  printf '{"tool_name":"%s","tool_input":{"%s":"%s"}}' "$2" "$3" "$4" |
    CLAUDE_PROJECT_DIR="$work" sh "$work/.claude/scripts/$1" 2>/dev/null
}
hookraw() { # script, tool_name, json-tool-input-literal (for nested input shapes), [style: mac(default)|win]
  # Wraps tool_name/tool_input in a realistic hook envelope, the way Claude
  # Code actually sends it: session_id, transcript_path, cwd,
  # permission_mode and hook_event_name alongside them. ghl-op.sh's own test
  # cases (LH-042) need this shape, not the bare {tool_name, tool_input} of
  # the first pass, because the bug they cover is envelope fields leaking
  # into classification — a bare shape could never reproduce that. "win"
  # gives Windows-style backslash paths, to check both path styles never
  # matter, since they are never read in the first place.
  style=${4:-mac}
  if [ "$style" = win ]; then
    tp='C:\\Users\\jo\\.claude\\projects\\x.jsonl'; cwd_val='C:\\Users\\jo\\launchhouse'
  else
    tp='/Users/jo/.claude/projects/x.jsonl'; cwd_val='/Users/jo/launchhouse'
  fi
  printf '{"session_id":"abc","transcript_path":"%s","cwd":"%s","permission_mode":"acceptEdits","hook_event_name":"PreToolUse","tool_name":"%s","tool_input":%s}' \
    "$tp" "$cwd_val" "$2" "$3" |
    CLAUDE_PROJECT_DIR="$work" sh "$work/.claude/scripts/$1" 2>/dev/null
}
# A write made the way Claude Code makes it: the check before, the write, the check after.
write() { # path inside growth-engine, words
  hook guard-pre.sh Write file_path "$ge/$1" > /dev/null
  printf '%s\n' "$2" > "$ge/$1"
  hook guard-post.sh Write file_path "$ge/$1"
}
shell() { # command text, then the command itself runs as the rest of the arguments
  c=$1; shift
  hook guard-pre.sh Bash command "$c" > /dev/null
  "$@"
  hook guard-post.sh Bash command "$c"
}
check() { # name, then a test
  n=$1; shift
  if "$@"; then printf 'PASS  %s\n' "$n"; else printf 'FAIL  %s\n' "$n"; fail=1; fi
}
has() { printf '%s' "$1" | grep -q "$2"; }
hasnt() { ! printf '%s' "$1" | grep -q "$2"; }

# LH-029: folder name casing.
out=$(hook guard-pre.sh Write file_path "$work/Growth-Engine/drafts/offer.md")
check "Growth-Engine in the wrong case is refused" has "$out" '"deny"'
out=$(hook guard-pre.sh Write file_path "$ge/drafts/offer.md")
check "growth-engine in lower case is allowed" hasnt "$out" '"deny"'
upper=$(printf '%s' "$work" | tr 'a-z' 'A-Z')
out=$(hook guard-pre.sh Write file_path "$upper/growth-engine/stray.md")
check "the folder is recognised whatever the case of the path above it" has "$out" 'not one of the Launchhouse files'

# LH-029: uploads/ and voice-samples/ get the sending rules, not the voice or track rules.
# They hold the founder's own documents, so a finding there is raised, never removed.
out=$(write inbox/uploads/plan.md "$cold")
check "a cold DM offer written to uploads/ is raised with Claude" has "$out" 'already there, or were copied in'
check "and the upload is not removed" test -f "$ge/inbox/uploads/plan.md"
out=$(write brain/voice-samples/promise.md 'Replies are guaranteed within a week.')
check "a promised reply written to voice-samples/ is raised, not held" has "$out" 'DM\|repl'
check "and the voice sample is kept" test -f "$ge/brain/voice-samples/promise.md"
printf 'We promise a reply to every customer email within one business day.\n' > "$work/src/policies.md"
out=$(shell "cp src/policies.md growth-engine/inbox/uploads/policies.md" cp "$work/src/policies.md" "$ge/inbox/uploads/policies.md")
check "a founder upload with a promise, copied in by shell, is not held" hasnt "$out" 'HELD'
check "and it stays on disk" test -f "$ge/inbox/uploads/policies.md"
printf 'We guarantee you a reply within 24 hours.\n' > "$work/src/newsletter.md"
out=$(shell "cp src/newsletter.md growth-engine/brain/voice-samples/newsletter.md" cp "$work/src/newsletter.md" "$ge/brain/voice-samples/newsletter.md")
check "a voice sample with a reply promise, copied in by shell, is kept" test -f "$ge/brain/voice-samples/newsletter.md"
check "and Claude is told to leave it to the founder" has "$out" 'leave the choice to them'
out=$(write brain/voice-samples/post.md 'Come and find me on LinkedIn. We never touch Apollo. It is a game changer.')
check "the founder's own writing in voice-samples/ is not held for track words or style" hasnt "$out" 'HELD'
check "and it stays saved" test -f "$ge/brain/voice-samples/post.md"

# LH-029: a shell copy is checked like a write.
printf '%s\n' "$cold" > "$work/src/offer.md"
printf 'Bake on Sunday, post on Monday.\n' > "$work/src/plan.md"
out=$(shell "cp src/offer.md growth-engine/drafts/offer.md" cp "$work/src/offer.md" "$ge/drafts/offer.md")
check "a new file with a cold DM offer copied in with cp is not deleted" test -f "$ge/drafts/offer.md"
check "and Claude is told, for the founder to decide" has "$out" 'already there, or were copied in'
mkdir -p "$work/.lh-import/growth-engine"
printf '# Hooks\n\n%s\n' "$cold" > "$work/.lh-import/growth-engine/hook-bank.md"
out=$(shell "cp -R .lh-import/growth-engine/. growth-engine/" cp "$work/.lh-import/growth-engine/hook-bank.md" "$ge/engines/audience/hook-bank.md")
check "an imported piece with a held line stays on disk" test -f "$ge/engines/audience/hook-bank.md"
check "and it is reported, not removed" hasnt "$out" 'HELD'
rm -f "$ge/engines/audience/hook-bank.md" "$ge/drafts/offer.md"
out=$(shell "cp src/plan.md growth-engine/drafts/plan.md" cp "$work/src/plan.md" "$ge/drafts/plan.md")
check "a harmless file copied in with cp is not held" hasnt "$out" 'HELD'
check "and it stays" test -f "$ge/drafts/plan.md"
out=$(shell "cp src/offer.md growth-engine/drafts/plan.md" cp "$work/src/offer.md" "$ge/drafts/plan.md")
check "a file overwritten by cp with a cold DM offer is put back" grep -q 'Bake on Sunday' "$ge/drafts/plan.md"
out=$(shell "git restore growth-engine/drafts/plan.md" cp "$work/src/offer.md" "$ge/drafts/plan.md")
check "a plain git command bringing back saved work is not undone" grep -q 'DM every new follower' "$ge/drafts/plan.md"
printf 'Bake on Sunday, post on Monday.\n' > "$ge/drafts/plan.md"
out=$(shell 'git restore growth-engine/drafts/plan.md\ncp src/offer.md growth-engine/drafts/plan.md' cp "$work/src/offer.md" "$ge/drafts/plan.md")
check "a two-line command that starts with git is still checked" grep -q 'Bake on Sunday' "$ge/drafts/plan.md"
out=$(shell "git apply /private/tmp/x.patch" cp "$work/src/offer.md" "$ge/drafts/plan.md")
check "git apply is still checked" grep -q 'Bake on Sunday' "$ge/drafts/plan.md"

# A file swapped for a link to a file outside the folder is removed, and put back.
printf 'Hook one: fresh bread.\n' > "$ge/drafts/hooks.md"
out=$(shell "ln -sf src/offer.md growth-engine/drafts/hooks.md" ln -sf "$work/src/offer.md" "$ge/drafts/hooks.md")
check "a file replaced by a link is held" has "$out" 'HELD'
check "and the link is gone and the file put back" sh -c '[ ! -L "$1" ] && grep -q "fresh bread" "$1"' _ "$ge/drafts/hooks.md"

# LH-031: a line that was already there is left alone, and said once.
printf '# Notes\n\n%s\n' "$cold" > "$ge/drafts/notes.md"
out=$(write drafts/notes.md "$(printf '# Notes\n\n%s\n\nBake on Sunday.' "$cold")")
check "an unrelated edit to a file with an old held line is saved" hasnt "$out" 'HELD'
check "and the old line is still there, untouched" grep -q 'DM every new follower' "$ge/drafts/notes.md"
check "and Claude is told about the old line" has "$out" 'already there'
out=$(write drafts/notes.md "$(printf '# Notes\n\n%s\n\nBake on Sunday.\n\nPost on Monday.' "$cold")")
check "the old line is not raised again on the next edit" hasnt "$out" 'already there'
out=$(write drafts/notes.md "$(printf '# Notes\n\n%s\n\nBake on Sunday.\n\nPost on Monday.\n\nHave a bot DM everyone who follows you.' "$cold")")
check "a new held line in the same file is still held" has "$out" 'HELD'
check "and the file is put back as it was" hasnt "$(cat "$ge/drafts/notes.md")" 'everyone who follows'

# LH-031: a new held sentence in a paragraph that already holds one is still held.
printf 'We guarantee you a reply within a day.\n' > "$ge/drafts/promise.md"
out=$(write drafts/promise.md 'We guarantee you a reply within a day. And we promise replies from every single owner you contact.')
check "a new promise beside an old one in the same paragraph is held" has "$out" 'HELD'
printf 'Have a bot DM everyone who follows you.\n' > "$ge/drafts/bot.md"
out=$(write drafts/bot.md 'Have a bot DM everyone who follows you. Then set a scheduler to message every new follower each morning.')
check "a new cold DM sentence beside an old one is held" has "$out" 'HELD'
long='Our weekly notes on the bakery, the ovens, the flour we buy, the people who come in on Saturday mornings, the cakes we test on Thursdays, and a line that mentions Apollo'
printf '%s.\n' "$long" > "$ge/drafts/long.md"
out=$(write drafts/long.md "$long; now we load every lead into an Apollo cold email sequence.")
check "a change past the quoted part of a long old line is held" has "$out" 'HELD'

# -------------------------------------------------------- mcp-guard.sh
# One dispatcher for every mcp__ tool call, matcher "^mcp__" in
# settings.json, running mcp-guard.sh. It routes GoHighLevel's connector
# shape (execute_operation, and a GoHighLevel-shaped fetch/search) to
# lh_ghl_classify in ghl-op.sh (now a sourced library, never run on its
# own), and every other tool name to its own fast classifier. Four
# outcomes: deny (blocks in every mode), ask (a founder-facing prompt even
# in auto mode, for the small named set the owner chose), guide
# (additionalContext only, no permissionDecision key, mode-aware wording),
# and silent (a clear read, no output at all).

mgmatch=$(sed -n 's/.*"matcher": "\(\^mcp__[^"]*\)".*/\1/p' "$settings")
check "settings.json carries exactly one mcp__ matcher" test "$mgmatch" = '^mcp__'
check "and it is the only one" test "$(grep -c '"matcher": "\^mcp__' "$settings")" = 1
check "it runs mcp-guard.sh" grep -q 'scripts/mcp-guard.sh' "$settings"
check "deny-mcp.sh is gone" test ! -e "$scripts/deny-mcp.sh"
check "ask-mcp.sh is gone" test ! -e "$scripts/ask-mcp.sh"
check "neither is named in settings.json any more" sh -c '! grep -qE "deny-mcp|ask-mcp" "$1"' _ "$settings"
check "ghl-op.sh is not named in settings.json, it is a sourced library now" sh -c '! grep -q "scripts/ghl-op.sh" "$1"' _ "$settings"

# The remote/branch/fetch allowlist that lets the start skill normalize
# remotes (rename the template to upstream, add or point origin, unset a
# stray upstream tracking branch) without a permission prompt mid-setup.
check "settings.json allows git remote get-url" grep -qF '"Bash(git remote get-url:*)"' "$settings"
check "settings.json allows git remote add" grep -qF '"Bash(git remote add:*)"' "$settings"
check "settings.json allows git remote remove" grep -qF '"Bash(git remote remove:*)"' "$settings"
check "settings.json allows git remote rename" grep -qF '"Bash(git remote rename:*)"' "$settings"
check "settings.json allows git remote set-url" grep -qF '"Bash(git remote set-url:*)"' "$settings"
check "settings.json allows git branch --unset-upstream" grep -qF '"Bash(git branch --unset-upstream)"' "$settings"
check "settings.json allows git fetch origin" grep -qF '"Bash(git fetch origin)"' "$settings"
check "settings.json allows git fetch upstream" grep -qF '"Bash(git fetch upstream)"' "$settings"
check "settings.json allows git ls-remote" grep -qF '"Bash(git ls-remote:*)"' "$settings"

mg() { # tool_name, tool_input-json, mode (default acceptEdits)
  m=${3:-acceptEdits}
  printf '{"session_id":"abc","transcript_path":"/Users/jo/.claude/projects/x.jsonl","cwd":"/Users/jo/launchhouse","permission_mode":"%s","hook_event_name":"PreToolUse","tool_name":"%s","tool_input":%s}' \
    "$m" "$1" "$2" |
    CLAUDE_PROJECT_DIR="$work" sh "$work/.claude/scripts/mcp-guard.sh" 2>/dev/null
}
isguide() { printf '%s' "$1" | grep -q additionalContext && ! printf '%s' "$1" | grep -q permissionDecision; }
mgdeny()   { n=$1; shift; out=$(mg "$@"); check "$n" has "$out" '"deny"'; }
mgask()    { n=$1; shift; out=$(mg "$@"); check "$n" has "$out" '"ask"'; }
mgguide()  { n=$1; shift; out=$(mg "$@"); check "$n" isguide "$out"; }
mgsilent() { n=$1; shift; out=$(mg "$@"); check "$n" test -z "$out"; }

# Deterministic by outcome, not by mode: deny, ask and silent never change
# with permission_mode, only guide's own wording does. One representative
# tool per row, checked in all three modes an owner is likely to run in.
for mode in default auto bypassPermissions; do
  mgdeny  "buy_domain is refused in $mode"                    mcp__vercel__buy_domain '{}' "$mode"
  mgdeny  "gmail send_message is refused in $mode"             mcp__286d__send_message '{}' "$mode"
  mgdeny  "resend send-broadcast is refused in $mode"          mcp__resend__send-broadcast '{}' "$mode"
  mgdeny  "linkedin connect_with_person is refused in $mode"   mcp__linkedin__connect_with_person '{}' "$mode"
  mgask   "drive share_file asks in $mode"                     mcp__39f8__share_file '{}' "$mode"
  mgask   "calendar create_event asks in $mode"                mcp__cal__create_event '{}' "$mode"
  mgask   "apollo people_match asks in $mode"                  mcp__apollo__apollo_people_match '{}' "$mode"
  mgguide "gmail create_draft is guided, not blocked, in $mode" mcp__286d__create_draft '{}' "$mode"
  mgguide "supabase execute_sql is guided in $mode"            mcp__supa__execute_sql '{}' "$mode"
  mgsilent "drive search_files is silent in $mode"             mcp__39f8__search_files '{}' "$mode"
  mgsilent "gmail search_threads is silent in $mode"           mcp__286d__search_threads '{}' "$mode"
done

# No "ask" outside the small named set, whatever the mode: deny, ask, guide
# and silent are the only four shapes this hook ever prints, and a mode
# never turns a guide into an ask or a deny.
for mode in default plan acceptEdits auto dontAsk bypassPermissions someUnknownMode; do
  out=$(mg mcp__286d__create_draft '{}' "$mode")
  check "create_draft never asks, in $mode" hasnt "$out" '"ask"'
  check "create_draft is never denied, in $mode" hasnt "$out" '"deny"'
done

# Guide's own wording is mode-aware: a prompt is coming in default/plan/
# acceptEdits, and none will appear in auto/dontAsk/bypassPermissions or an
# unrecognised mode.
out=$(mg mcp__286d__create_draft '{}' default)
check "default mode's guide note mentions the prompt the founder will see" has "$out" 'permission prompt'
out=$(mg mcp__286d__create_draft '{}' acceptEdits)
check "acceptEdits reads the same way" has "$out" 'permission prompt'
out=$(mg mcp__286d__create_draft '{}' auto)
check "auto mode's guide note says no prompt will appear" has "$out" 'No prompt will appear'
out=$(mg mcp__286d__create_draft '{}' bypassPermissions)
check "bypassPermissions reads the same way" has "$out" 'No prompt will appear'
out=$(mg mcp__286d__create_draft '{}' totallyMadeUp)
check "an unrecognised mode falls to the cautious no-prompt wording" has "$out" 'No prompt will appear'

# The full table of real tool names from this account, one row each,
# checked in a fast mode (auto) and a manual one (default), since the
# outcome itself must not move between them.
tbl='
mcp__286d__send_message|{}|deny
mcp__286d__reply|{}|deny
mcp__286d__forward|{}|deny
mcp__286d__create_draft|{}|guide
mcp__286d__search_threads|{}|silent
mcp__286d__mark_message_spam|{}|guide
mcp__resend__send-email|{}|deny
mcp__resend__send-batch-emails|{}|deny
mcp__resend__send-broadcast|{}|deny
mcp__resend__reply-to-inbox-thread-email|{}|ask
mcp__resend__forward-inbox-thread-email|{}|ask
mcp__resend__share-email|{}|ask
mcp__resend__compose-broadcast|{}|guide
mcp__resend__create-inbox-draft|{}|guide
mcp__resend__list-emails|{}|silent
mcp__MCP_Server_for_LinkedIn__send_message|{}|deny
mcp__MCP_Server_for_LinkedIn__connect_with_person|{}|deny
mcp__MCP_Server_for_LinkedIn__get_inbox|{}|silent
mcp__zapier__execute_zapier_write_action|{}|guide
mcp__zapier__execute_zapier_read_action|{}|silent
mcp__cal__create_event|{}|ask
mcp__cal__update_event|{}|ask
mcp__cal__respond_to_event|{}|ask
mcp__cal__list_events|{}|silent
mcp__qbo__send_invoice|{}|ask
mcp__qbo__send_estimate|{}|ask
mcp__qbo__send_payment_link|{}|ask
mcp__qbo__get_invoices|{}|silent
mcp__39f8__search_files|{}|silent
mcp__39f8__create_file|{}|guide
mcp__39f8__trash_file|{}|guide
mcp__39f8__share_file|{}|ask
mcp__notion__notion-search|{}|silent
mcp__notion__notion-create-pages|{}|guide
mcp__notion__notion-create-comment|{}|guide
mcp__shopify__graphql_mutation|{}|guide
mcp__shopify__run-analytics-query|{}|silent
mcp__supa__execute_sql|{}|guide
mcp__supa__list_tables|{}|silent
mcp__vercel__buy_domain|{}|deny
mcp__vercel__deploy|{}|guide
mcp__vercel__list_projects|{}|silent
mcp__apollo__apollo_mixed_people_api_search|{}|silent
mcp__apollo__apollo_emailer_messages_email_send_status|{}|ask
'
IFS='
'
for row in $tbl; do
  [ -n "$row" ] || continue
  t=${row%%|*}; rest=${row#*|}; ti=${rest%%|*}; want=${rest##*|}
  for mode in auto default; do
    out=$(mg "$t" "$ti" "$mode")
    case $want in
      deny)   check "$t is deny in $mode" has "$out" '"deny"' ;;
      ask)    check "$t is ask in $mode" has "$out" '"ask"' ;;
      guide)  check "$t is guide in $mode" isguide "$out" ;;
      silent) check "$t is silent in $mode" test -z "$out" ;;
    esac
  done
done
unset IFS

# Apollo purchase/send/sequence tools, active true and false, by name alone.
mgdeny  "apollo_email_account_purchase_create is refused" mcp__apollo__apollo_email_account_purchase_create '{}'
mgdeny  "apollo_emailer_messages_send_now is refused" mcp__apollo__apollo_emailer_messages_send_now '{}'
mgdeny  "apollo_sequences_create with active true is refused" mcp__apollo__apollo_sequences_create '{"active":true}'
mgguide "apollo_sequences_create with active false is guided, not refused" mcp__apollo__apollo_sequences_create '{"active":false}'
mgguide "apollo_sequences_create with no active field at all is guided" mcp__apollo__apollo_sequences_create '{"name":"Cold outreach"}'
mgdeny  "apollo_sequences_update with active true is refused too" mcp__apollo__apollo_sequences_update '{"active":true}'
out=$(mg mcp__apollo__apollo_sequences_create '{"active":false,"steps":[{"body":"active true would be great, right?"}]}')
check "'active':true only counts as the tool_input's own top-level field, never inside a step body the founder wrote" hasnt "$out" '"deny"'

# The name classifier never walks tool_input at all, except that one
# top-level Apollo field: a large draft or message body in tool_input never
# slows a call down or changes its outcome.
biggish=$(awk 'BEGIN { printf "{\"body\":\""; for (i = 0; i < 5000; i++) printf "x"; printf "\"}" }')
out=$(mg mcp__286d__create_draft "$biggish")
check "a large tool_input on an ordinary tool still classifies (guide), fast" isguide "$out"

# ------------------------------------------------- lh_active vs lh_near
# deny and ask only fire in a folder that actually carries the marker;
# a folder merely near one (the wrong-folder case) is guided at most.
near="${work}-near"
mkdir -p "$near/.claude" "$near/sibling/growth-engine"
cp -R "$scripts" "$near/.claude/"
: > "$near/sibling/growth-engine/.launchhouse"
out=$(printf '{"session_id":"a","permission_mode":"auto","hook_event_name":"PreToolUse","tool_name":"mcp__286d__send_message","tool_input":{}}' |
  CLAUDE_PROJECT_DIR="$near" sh "$near/.claude/scripts/mcp-guard.sh" 2>/dev/null)
check "a wrong-folder open (lh_near only) never denies, it guides at most" hasnt "$out" '"deny"'
check "and it does carry a note" isguide "$out"
rm -rf "$near"

# --------------------------------------------------- GoHighLevel routing
# execute_operation is always classified through the GoHighLevel path,
# whatever the server name. fetch and search go there too, but only when
# the input looks GoHighLevel-shaped (a structural field, leadconnector,
# highlevel, or a locationId) — otherwise they fall to the name classifier
# instead, same as any other connector's fetch or search.
out=$(mg mcp__gdrive__fetch '{"id":"1a2b3c4d","name":"quarterly-report.pdf"}')
check "a Google-Drive-shaped fetch never reaches the GoHighLevel classifier" test -z "$out"
out=$(mg mcp__gdrive__fetch '{"locationId":"LOC1","operationId":"users_get-user"}')
check "a fetch carrying a locationId is routed to the GoHighLevel classifier, and users is refused there" has "$out" '"deny"'
out=$(mg mcp__notion__search '{"query":"invoice"}')
check "a plain Notion search, not GoHighLevel-shaped, is not routed there either" test -z "$out"

# ---------------------------------------------- lh_ghl_classify (library)
# ghl-op.sh is a sourced library now: lh_ghl_classify sets lh_ghl_decision
# to one of deny, ask, guide or silent, and never prints or exits on its
# own. refuse beats write beats read beats everything else, and it never
# allows on doubt: an unreadable operation, an empty or non-object
# tool_input, or a Unicode escape it cannot safely read all land on deny or
# guide, never silent.
ghlc() { # tool_name, tool_input-json
  sh -c '. "$1/.claude/scripts/lib.sh" && . "$1/.claude/scripts/ghl-op.sh" && lh_ghl_classify "$2" "$3" && printf "%s" "$lh_ghl_decision"' _ "$work" "$1" "$2"
}
ghlcdeny()   { n=$1; shift; out=$(ghlc "$@"); check "$n" test "$out" = deny; }
ghlcask()    { n=$1; shift; out=$(ghlc "$@"); check "$n" test "$out" = ask; }
ghlcguide()  { n=$1; shift; out=$(ghlc "$@"); check "$n" test "$out" = guide; }
ghlcsilent() { n=$1; shift; out=$(ghlc "$@"); check "$n" test "$out" = silent; }

# Deny: payments, deletes, workflow changes, refunds, phone numbers, users,
# api keys, webhooks, snapshots, the nested delete-contact shape, and the
# new no-descriptor case.
ghlcdeny "payments list orders is refused" mcp__highlevel__execute_operation '{"operationId":"payments_list-orders"}'
ghlcdeny "contacts delete-contact is refused" mcp__highlevel__execute_operation '{"operationId":"contacts_delete-contact"}'
ghlcdeny "the nested operation.id delete-contact shape is refused the same way" mcp__highlevel__execute_operation '{"operation":{"id":"contacts_delete-contact"}}'
ghlcdeny "adding a contact to a workflow is refused" mcp__highlevel__execute_operation '{"operationId":"workflows_add-contact-to-workflow"}'
ghlcdeny "a refund is refused" mcp__highlevel__execute_operation '{"operationId":"payments_refund-transaction"}'
ghlcdeny "buying a phone number is refused" mcp__highlevel__execute_operation '{"operation":"phone-number.purchase"}'
ghlcdeny "a users operation is refused" mcp__highlevel__execute_operation '{"operationId":"users_get-user"}'
ghlcdeny "an api key operation is refused" mcp__highlevel__execute_operation '{"operationId":"generate_api_key"}'
ghlcdeny "a webhooks operation is refused" mcp__highlevel__execute_operation '{"operationId":"webhooks_create-webhook"}'
ghlcdeny "a snapshot operation is refused" mcp__highlevel__execute_operation '{"operationId":"snapshots_share-snapshot"}'
ghlcdeny "an explicit DELETE method is refused, not just guided" mcp__highlevel__execute_operation '{"method":"DELETE","path":"/contacts/123"}'
ghlcdeny "empty input carries no descriptor, so it is refused with a next step" mcp__highlevel__execute_operation '{}'
ghlcdeny "a scalar tool_input (a bare JSON string, not an object) carries no descriptor either" mcp__highlevel__execute_operation '"getContacts"'
ghlcdeny "every leaf sitting under body and nothing outside it is also an empty descriptor" mcp__highlevel__execute_operation '{"body":{"x":"get"}}'

# Ask: the small named set — conversations send, social post create/edit/
# publish (either spelling), an email template created, a contact touched,
# an opportunity updated.
ghlcask "sendMessage in camelCase, under conversations, asks" mcp__highlevel__execute_operation '{"operation":"conversations.sendMessage"}'
ghlcask "creating a post asks (hyphenated spelling)" mcp__highlevel__execute_operation '{"operationId":"social-media-posting_create-post"}'
ghlcask "editing a post asks (hyphenated spelling)" mcp__highlevel__execute_operation '{"operationId":"social-media-posting_edit-post"}'
ghlcask "creating a post asks (concatenated spelling too)" mcp__highlevel__execute_operation '{"operationId":"socialmediaposting_create-post"}'
ghlcask "creating an email template asks" mcp__highlevel__execute_operation '{"operationId":"emails_create-template"}'
ghlcask "adding a tag to a contact asks" mcp__highlevel__execute_operation '{"operationId":"contacts_add-tag"}'
ghlcask "creating a contact asks" mcp__highlevel__execute_operation '{"operationId":"contacts_create-contact"}'
ghlcask "updating an opportunity asks" mcp__highlevel__execute_operation '{"operationId":"opportunities_update-opportunity"}'
ghlcask "fetch with a HighLevel op id updating a contact asks" mcp__highlevel__fetch '{"locationId":"LOC123","operation":"update-contact"}'
ghlcask "a create-post body.summary in the founder's own words still only asks, never denies on leaked payload text" \
  mcp__highlevel__execute_operation '{"operationId":"social-media-posting_create-post","body":{"summary":"Order your cake today, prices from 20"}}'
ghlcask "a send-message body/text mentioning refund in the founder's own words still only asks" \
  mcp__highlevel__execute_operation '{"operation":"conversations.sendMessage","body":{"text":"sorry about the refund delay, it is on its way"}}'

# Guide: every other write. Not blocked, not forced to a prompt, just noted.
ghlcguide "updating a custom value is a write, but not one of the named ask cases" mcp__highlevel__execute_operation '{"operationId":"locations_update-custom-value"}'
ghlcguide "creating a blog post is a write, but not one of the named ask cases" mcp__highlevel__execute_operation '{"operationId":"blogs_create-blog-post"}'
ghlcguide "a POST method with a GET-looking name is still a write, and still not the named ask set" mcp__highlevel__execute_operation '{"method":"POST","operation":"get-contact-details"}'
ghlcask "a GET method with a send-ish name touches a message, so it asks, not just guides" mcp__highlevel__execute_operation '{"method":"GET","operation":"send-message-status"}'
ghlcguide "an unrecognised operation is guided, never silently allowed" mcp__highlevel__execute_operation '{"operationId":"something_nobody_has_seen_before"}'
ghlcask "markConversationAsRead is a write (mark) touching a conversation, so it asks, not a read just because read is in its name" mcp__highlevel__execute_operation '{"operationId":"markConversationAsRead"}'
ghlcguide "createPost with cancel-my-subscription in its own payload field only guides, never denies on leaked payload text" \
  mcp__highlevel__execute_operation '{"operationId":"createPost","post":"Please cancel my subscription"}'
ghlcguide "a method-shaped word inside an excluded payload leaf's own value never leaks in either" \
  mcp__highlevel__execute_operation '{"operationId":"createPost","body":{"note":"method: POST please, right away"}}'

# Silent: clear reads, no output at all (checked at the mcp-guard.sh level
# too, further up, and here directly against the classifier).
ghlcsilent "getting a location is silent" mcp__highlevel__execute_operation '{"operationId":"locations_get-location"}'
ghlcsilent "listing social accounts is silent" mcp__highlevel__execute_operation '{"operationId":"social-media-posting_get-accounts"}'
ghlcsilent "getting posts is silent, post alone is neutral" mcp__highlevel__execute_operation '{"operationId":"social-media-posting_get-posts"}'
ghlcsilent "post statistics is silent, post alone is neutral" mcp__highlevel__execute_operation '{"operationId":"social-media-posting_get-post-statistics"}'
ghlcsilent "searching contacts with a GET method is silent" mcp__leadconnector__execute_operation '{"method":"GET","operationId":"contacts_search"}'
ghlcsilent "getWorkflows is still a clear read, workflow alone does not refuse a read" mcp__highlevel__execute_operation '{"operationId":"getWorkflows"}'
ghlcsilent "a method field buried inside body, not a structural field at all, is ignored for classification" \
  mcp__highlevel__execute_operation '{"operationId":"getContact","body":{"method":"DELETE"}}'
check "getHTTPMethod flattens the acronym boundary apart from the titlecase word after it" \
  sh -c '. "$1/.claude/scripts/lib.sh"; [ "$(lh_ghl_flatten getHTTPMethod)" = "get http method" ]' _ "$work"
ghlcsilent "getHTTPMethod is a clear read once flattened, get is a read word and nothing else fires" mcp__highlevel__execute_operation '{"operationId":"getHTTPMethod"}'

# Five confirmed bugs the old blacklist let through or got wrong stay fixed.
ghlcdeny "a users operation, getUser, is refused, singular now included" mcp__highlevel__execute_operation '{"operationId":"getUser"}'
ghlcdeny "listAPIKeys is refused, refuse beats the read-looking list" mcp__highlevel__execute_operation '{"operationId":"listAPIKeys"}'
ghlcdeny "a fetch with a bare DELETE method and path is refused, not silently allowed" mcp__highlevel__fetch '{"method":"DELETE","path":"/contacts/123"}'
ghlcdeny "trashContact is refused, trash is a new refuse word" mcp__highlevel__execute_operation '{"operationId":"trashContact"}'
ghlcdeny "createCharge is refused, charge is a new refuse word" mcp__highlevel__execute_operation '{"operationId":"createCharge"}'
ghlcdeny "activateWorkflow is refused outright, not just guided" mcp__highlevel__execute_operation '{"operationId":"activateWorkflow"}'

# LH-042: classification reads only tool_input, never the envelope around
# it (checked here through mcp-guard.sh itself, envelope and all).
out=$(mg mcp__1b3d__execute_operation '{"operationId":"locations_get-location"}')
check "a clean read is silent even though the envelope's own cwd and transcript_path say /Users/jo, which used to trip the 'users' refuse word" test -z "$out"

# A malformed or unreadable envelope, or trailing garbage after it closes,
# is the same doubt as a missing operation: deny with the describe_operation
# next step, never a silent allow.
out=$(printf '{"session_id":"abc","transcript_path":"/Users/jo/.claude/projects/x.jsonl","cwd":"/Users/jo/launchhouse","permission_mode":"acceptEdits","hook_event_name":"PreToolUse","tool_name":"mcp__highlevel__execute_operation","tool_input":{not json at all' |
  CLAUDE_PROJECT_DIR="$work" sh "$work/.claude/scripts/mcp-guard.sh" 2>/dev/null)
check "malformed JSON denies with the describe_operation next step, rather than crashing or asking" has "$out" '"deny"'
check "and it names describe_operation" has "$out" 'describe_operation'
out=$(printf '{"session_id":"abc","transcript_path":"/Users/jo/.claude/projects/x.jsonl","cwd":"/Users/jo/launchhouse","permission_mode":"acceptEdits","hook_event_name":"PreToolUse","tool_name":"mcp__highlevel__execute_operation","tool_input":{"operationId":"getUser"}}GARBAGE' |
  CLAUDE_PROJECT_DIR="$work" sh "$work/.claude/scripts/mcp-guard.sh" 2>/dev/null)
check "garbage trailing after the envelope's own JSON closes denies too, rather than trusting the tool_input found before it" has "$out" '"deny"'

# A large junk operation name, still valid JSON: must not crash, and must
# still come out safe (guided, on a name nothing can classify).
junk=$(awk 'BEGIN { for (i = 0; i < 20000; i++) printf "x" }')
out=$(mg mcp__highlevel__execute_operation "{\"operationId\":\"$junk\"}")
check "a 20KB junk operation name comes back, so the hook did not hang or crash" test -n "$out"
check "and it classifies safely, guiding rather than guessing" isguide "$out"

# fetch and search: judged only when the input looks GoHighLevel-shaped
# (checked here directly against the shape helper).
check "a Google-Drive-style fetch of a bare id, no method/path/operation shape and no HighLevel markers, is not GoHighLevel-shaped" \
  sh -c '. "$1/.claude/scripts/lib.sh"; . "$1/.claude/scripts/ghl-op.sh"; ! lh_ghl_shaped "{\"id\":\"doc123\"}"' _ "$work"
check "a locationId makes it GoHighLevel-shaped" \
  sh -c '. "$1/.claude/scripts/lib.sh"; . "$1/.claude/scripts/ghl-op.sh"; lh_ghl_shaped "{\"locationId\":\"LOC1\"}"' _ "$work"

# LH-025: mail rules are refused outright, and a mailbox read never asks or
# denies.
out=$(mg mcp__286d__create_filter '{}')
check "a mailbox rule is refused" has "$out" '"deny"'
out=$(mg mcp__claude_ai_Microsoft_365__outlook_email_search '{}')
check "outlook_email_search, a read, is silent" test -z "$out"

# ------------------------------------------- ten reproduced bugs, fixed
# Each case failed a specific way before the fix (noted) and must pass now.
bks=$(printf '\134')  # a literal backslash, built at runtime: typing \u
                       # directly in this file risks the same kind of
                       # decode-before-it-runs that these bugs are about,
                       # so the escape sequences below are assembled, never
                       # written out whole.

# 1. A tool whose name ends __fetch, not GoHighLevel-shaped, used to crash
# with "lh_ghl_shaped: command not found" (ghl-op.sh was only sourced on
# the branch that needed it) and printed a guide note instead of nothing.
out=$(mg mcp__browser__fetch '{"url":"https://example.com"}' 2>/tmp/lh-bug1-stderr.$$)
check "bug 1: a plain fetch is silent, not guided" test -z "$out"
check "bug 1: and it never wrote to stderr" test ! -s /tmp/lh-bug1-stderr.$$
rm -f /tmp/lh-bug1-stderr.$$

# 2. tool_name and permission_mode are read from the TOP LEVEL only. A
# nested, spoofed "tool_name" inside tool_input used to win a first-match
# text search and hide a real send_message behind a harmless-looking read.
out=$(mg mcp__286d__send_message '{"tool_name":"mcp__drive__get_file"}')
check "bug 2: a nested tool_name inside tool_input never overrides the real, top-level one" has "$out" '"deny"'

# 3. A mailbox-style send, any spelling: send_email and send-email deny the
# same way __send_message already did. Resend's send-email included.
mgdeny "bug 3: mcp__286d__send_email denies, same as send_message" mcp__286d__send_email '{}'
mgdeny "bug 3: resend's send-email (hyphenated) denies too" mcp__resend__send-email '{}'

# 4. Precedence: a deny signal is checked before any read word can exempt
# it. read_and_send_email used to reach "guide" because "read" made it look
# like a read before the send/email check ever ran.
mgdeny "bug 4: read_and_send_email still denies, read never exempts a send" mcp__286d__read_and_send_email '{}'

# 5. A cold send, whichever tool: "cold" next to a send verb is cold
# outreach, refused outright, never left to a tool to run on its own.
mgdeny "bug 5: send_cold_email denies, cold outreach is never sent by a tool" mcp__x__send_cold_email '{}'

# 6. Turning a sequence or campaign on, by name, denies the same way
# active:true already did for Apollo's own sequences_create/update.
mgdeny "bug 6: apollo_sequences_activate denies, the founder starts it themselves" mcp__2bc3__apollo_sequences_activate '{}'

# 7. GoHighLevel: any write touching a conversation or a message asks, not
# only one whose own name happens to say "send".
ghlcask "bug 7: conversations_messages_create asks, not just a send-named op" mcp__highlevel__execute_operation '{"operationId":"conversations_messages_create"}'

# 8. Deleting something that reaches a real person (a calendar event, a
# contact, a post already out) asks, rather than being quietly guided.
mgask "bug 8: delete_event asks, it can remove something someone else already has" mcp__c954__delete_event '{}'

# 9. A tool name hiding a word behind a \u escape: decoded when it is
# plain ASCII (so buy/purchase/checkout and the rest of the word lists
# still catch it), and never trusted when it is not, in which case the
# whole call is asked about, never silently allowed and never merely
# guided.
hidden_purchase="mcp__v__${bks}u0070urch${bks}u0061se_item"  # decodes to mcp__v__purchase_item
env_json="{\"session_id\":\"a\",\"permission_mode\":\"auto\",\"hook_event_name\":\"PreToolUse\",\"tool_name\":\"$hidden_purchase\",\"tool_input\":{}}"
out=$(printf '%s' "$env_json" | CLAUDE_PROJECT_DIR="$work" sh "$work/.claude/scripts/mcp-guard.sh" 2>/dev/null)
check "bug 9: a \\u-escaped, plain-ASCII 'purchase' in the tool name is still denied" has "$out" '"deny"'
unreadable="mcp__v__weird${bks}u00e9item"  # é is outside ASCII: this hook cannot safely resolve it
env_json2="{\"session_id\":\"a\",\"permission_mode\":\"auto\",\"hook_event_name\":\"PreToolUse\",\"tool_name\":\"$unreadable\",\"tool_input\":{}}"
out=$(printf '%s' "$env_json2" | CLAUDE_PROJECT_DIR="$work" sh "$work/.claude/scripts/mcp-guard.sh" 2>/dev/null)
check "bug 9: a tool name carrying an unreadable \\u escape asks" has "$out" '"ask"'
check "bug 9: and it is never silent" test -n "$out"
check "bug 9: and it is never merely guided" hasnt "$out" additionalContext

# 10. The fetch/search shape gate only counts a real GoHighLevel marker
# (an operation id field, locationId, leadconnector, highlevel), never a
# bare structural-sounding key like "url" that any connector's tools carry.
out=$(mg mcp__gdrive__fetch '{"url":"https://example.com/report.pdf"}')
check "bug 10: a fetch carrying only a url is not routed to the GoHighLevel classifier" test -z "$out"
big=$(awk 'BEGIN { printf "{\"url\":\"https://example.com/"; for (i = 0; i < 8000; i++) printf "x"; printf "\"}" }')
out=$(mg mcp__gdrive__fetch "$big")
check "bug 10: the shape check on a large tool_input still returns promptly and silently" test -z "$out"

# LH-025: the GoHighLevel key lives in the computer's own password store and
# reaches only GoHighLevel, only as Claude Code connects. The checks never show
# it. The store is faked here: never a real Keychain or Credential Manager, and
# never a real key.
fb="$work/fakebin"
store="$work/fakestore"
mkdir -p "$fb" "$store"
cat > "$fb/uname" <<'EOF'
#!/bin/sh
printf '%s\n' "${LH_FAKE_OS:-Darwin}"
EOF
cat > "$fb/security" <<'EOF'
#!/bin/sh
# A fake Keychain: one file per item, line 1 the account, line 2 the password.
s= w=
while [ $# -gt 0 ]; do
  case $1 in -s) s=$2; shift ;; -w) w=1 ;; esac; shift
done
f="$LH_FAKE_STORE/$s"
[ -f "$f" ] || { echo 'security: The specified item could not be found in the keychain.' >&2; exit 44; }
if [ -n "$w" ]; then
  [ -n "$LH_FAKE_DENY" ] && exit 51
  sed -n 2p "$f"; exit 0
fi
printf 'keychain: "/fake/login.keychain-db"\nattributes:\n    "acct"<blob>="%s"\n    "svce"<blob>="%s"\n' "$(sed -n 1p "$f")" "$s"
EOF
cat > "$fb/powershell.exe" <<'EOF'
#!/bin/sh
# A fake Windows PowerShell: decodes the program, finds the item it reads.
enc=
while [ $# -gt 0 ]; do [ "$1" = -EncodedCommand ] && enc=$2; shift; done
prog=$(printf '%s' "$enc" | base64 --decode | iconv -f UTF-16LE -t UTF-8)
printf '%s' "$prog" > "$LH_FAKE_STORE/.last-program"
t=$(printf '%s\n' "$prog" | sed -n "s/.*::Read('\(.*\)').*/\1/p")
f="$LH_FAKE_STORE/$t"
[ -f "$f" ] || exit 3
printf '%s\r\n%s\r\n' "$(sed -n 1p "$f")" "$(sed -n 2p "$f")"
EOF
cat > "$fb/curl" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" > "$LH_FAKE_STORE/.curl-args"
cat > "$LH_FAKE_STORE/.curl-config"
printf '{"customValues": []}\nstatus: 200\n'
EOF
chmod +x "$fb/uname" "$fb/security" "$fb/powershell.exe" "$fb/curl"

fake='pit-test-0000-not-a-real-key'
vfake='pit-test-1111-values-not-real'
printf 'LOCtest123\n%s\n' "$fake" > "$store/Launchhouse GoHighLevel"
printf 'LOCtest123\n%s\n' "$vfake" > "$store/Launchhouse GoHighLevel values"
helper="$work/.claude/scripts/ghl-headers.sh"
vhelper="$work/.claude/scripts/ghl-values-api.sh"
ghlurl=https://services.leadconnectorhq.com/mcp/anthropic/v2
run() { PATH="$fb:$PATH" LH_FAKE_STORE="$store" "$@" < /dev/null; }
want="{\"Authorization\": \"Bearer $fake\", \"locationId\": \"LOCtest123\"}"

for os in Darwin MINGW64_NT-10.0-19045; do
  export LH_FAKE_OS=$os
  out=$(run env CLAUDE_CODE_MCP_SERVER_URL=$ghlurl sh "$helper")
  check "$os: the helper gives GoHighLevel the key and Location ID as headers" test "$out" = "$want"
  out=$(run env CLAUDE_CODE_MCP_SERVER_URL=https://example.com/mcp/ sh "$helper")
  check "$os: it gives any other address nothing" test -z "$out"
  out=$(run sh "$helper")
  check "$os: it gives nothing when no connection asked for it" test -z "$out"
  out=$(run sh "$helper" --check)
  check "$os: the check finds the item in the right shape" has "$out" 'the Location ID: looks right'
  check "$os: and never shows the key" hasnt "$out" "$fake"
done
check "on Windows it reads Credential Manager with the built-in credential reader" \
  grep -q "CredReadW" "$store/.last-program"
LH_FAKE_OS=Darwin

out=$(LH_FAKE_DENY=1 run sh "$helper" --check)
check "a Mac that refused to read the item is told to click Always Allow" has "$out" 'Always Allow'
check "and the key is not shown" hasnt "$out" "$fake"

# The connection file is not shipped. --connect writes it once the key checks out.
check ".mcp.json is not shipped in the folder" test ! -e "$here/../../.mcp.json"
check "git ignores .mcp.json" grep -qx '/.mcp.json' "$here/../../.gitignore"
mv "$store/Launchhouse GoHighLevel" "$store/away"
out=$(run sh "$helper" --connect)
check "with no item, the check says it is not found" has "$out" 'not found'
check "and no connection is written" test ! -e "$work/.mcp.json"
mv "$store/away" "$store/Launchhouse GoHighLevel"
out=$(run sh "$helper" --connect)
check "--connect writes the connection when the key is right" has "$out" 'connection: written'
check "and never shows the key" hasnt "$out" "$fake"
mcp="$work/.mcp.json"
check "the connection is GoHighLevel's documented address" grep -qF "\"url\": \"$ghlurl\"" "$mcp"
check "with one server, highlevel" test "$(grep -c '"url"' "$mcp")" = 1 -a "$(grep -c '"highlevel"' "$mcp")" = 1
check "and no key or Location ID in it" sh -c '! grep -qiE "bearer|pit-|LOCtest|authorization" "$1"' _ "$mcp"
hh=$(sed -n 's/^ *"headersHelper": "\(.*\)"$/\1/p' "$mcp" | sed 's/\\"/"/g')
check "its helper is named by this folder's own path" has "$hh" '/.claude/scripts/ghl-headers.sh"$'
check "and on a Mac it is run with plain sh" has "$hh" '^sh "/'
out=$(cd / && run env CLAUDE_CODE_MCP_SERVER_URL=$ghlurl sh -c "$hh")
check "and run as written, from anywhere, it gives GoHighLevel the headers" test "$out" = "$want"
# On Windows the app starts the helper through cmd.exe, which cannot find a bare
# sh, so the connection names Git's sh.exe by its full path.
fbw="$work/fakebin-win"
mkdir -p "$fbw"
cat > "$fbw/cygpath" <<'EOF'
#!/bin/sh
case $2 in */sh) printf 'C:/Program Files/Git/usr/bin/sh\n' ;; *) printf 'C:%s\n' "$2" ;; esac
EOF
chmod +x "$fbw/cygpath"
rm -f "$mcp"
out=$(LH_FAKE_OS=MINGW64_NT-10.0-19045 run env PATH="$fbw:$fb:$PATH" sh "$helper" --connect)
check "on Windows --connect writes the connection too" has "$out" 'connection: written'
hh=$(sed -n 's/^ *"headersHelper": "\(.*\)"$/\1/p' "$mcp" | sed 's/\\"/"/g')
check "and names Git's sh.exe by its full path, quoted" test "$hh" = "\"C:/Program Files/Git/usr/bin/sh.exe\" \"C:$(cd "$work" && pwd)/.claude/scripts/ghl-headers.sh\""
printf '{"mcpServers": {"other": {"type": "http", "url": "https://example.com/"}}}\n' > "$mcp"
out=$(run sh "$helper" --connect)
check "--connect never overwrites a .mcp.json it did not write" has "$out" 'not written'
check "and leaves it as it was" grep -q '"other"' "$mcp"
rm -f "$mcp"

# --disconnect removes only a .mcp.json this helper itself wrote, using the
# same "highlevel" plus "ghl-headers.sh" marker --connect already checks
# before it will overwrite anything.
out=$(run sh "$helper" --disconnect)
check "--disconnect with nothing there says so, and does nothing destructive" has "$out" 'nothing to remove'
out=$(run sh "$helper" --connect)
check "--connect writes the connection again, to set up the disconnect test" has "$out" 'connection: written'
check "and the file exists" test -e "$mcp"
out=$(run sh "$helper" --disconnect)
check "--disconnect removes the connection it wrote" has "$out" 'connection: removed'
check "and the file is gone" test ! -e "$mcp"
printf '{"mcpServers": {"other": {"type": "http", "url": "https://example.com/"}}}\n' > "$mcp"
out=$(run sh "$helper" --disconnect)
check "--disconnect leaves a founder's own unrelated .mcp.json alone" has "$out" 'not removed'
check "and the file is unchanged" grep -q '"other"' "$mcp"
rm -f "$mcp"

# ghl-values sends its own token from its own item, on curl's standard input.
out=$(run sh "$vhelper" list)
check "the values helper prints GoHighLevel's answer" has "$out" 'customValues'
check "and never the token" hasnt "$out" "$vfake"
check "the token is never on curl's command line" sh -c '! grep -q "pit-" "$1"' _ "$store/.curl-args"
check "it goes in curl's settings, from the values item, not the connection's" grep -q "Authorization: Bearer $vfake" "$store/.curl-config"
check "to the location's custom values" grep -q 'locations/LOCtest123/customValues' "$store/.curl-args"
out=$(run sh "$vhelper" update 'x;y')
check "the values helper refuses an id that is not plain" has "$out" 'needs the custom value id'

# Nothing in the chat may read the store, or run a helper for its key.
# The address check above is no guard here, because a command can set it.
for c in 'CLAUDE_CODE_MCP_SERVER_URL=https://services.leadconnectorhq.com/mcp/ sh .claude/scripts/ghl-headers.sh < /dev/null' \
         'sh .claude/scripts/ghl-headers.sh' \
         'sh .claude/scripts/ghl-headers.sh --check; security find-generic-password -s x -w' \
         'security find-generic-password -s \"Launchhouse GoHighLevel\" -w' \
         'security dump-keychain -d' \
         'powershell -EncodedCommand AAAA' \
         'powershell -Command [Windows.Security.Credentials.PasswordVault]::new()' \
         'sh -c \". .claude/scripts/ghl-store.sh; ghl_store_read x\"' \
         'sh .claude/scripts/ghl-values-api.sh list | cat; env' \
         'export CLAUDE_CODE_MCP_SERVER_URL=x' \
         'sh .claude/scripts/ghl-headers.sh --check < /dev/null\nsh -x .claude/scripts/ghl-headers.sh --check < /dev/null' \
         'sh .claude/scripts/ghl-values-api.sh list < /dev/null\nsh -x .claude/scripts/ghl-values-api.sh list < /dev/null' \
         'sh /private/tmp/lh-wave-c/evil/ghl-headers.sh --check < /dev/null' \
         'sh /private/tmp/lh-wave-c/evil/ghl-values-api.sh list < /dev/null'; do
  out=$(hook guard-pre.sh Bash command "$c")
  check "refused: $c" has "$out" '"deny"'
done
for c in 'sh .claude/scripts/ghl-headers.sh --check < /dev/null' \
         'sh .claude/scripts/ghl-headers.sh --connect < /dev/null' \
         'sh .claude/scripts/ghl-headers.sh --disconnect < /dev/null' \
         'sh \"$CLAUDE_PROJECT_DIR/.claude/scripts/ghl-headers.sh\" --check < /dev/null' \
         'sh .claude/scripts/ghl-values-api.sh list < /dev/null' \
         'sh .claude/scripts/ghl-values-api.sh update abc123 < /private/tmp/lh-value.json'; do
  out=$(hook guard-pre.sh Bash command "$c")
  check "allowed: $c" hasnt "$out" '"deny"'
done
out=$(hook guard-pre.sh Read file_path "$ge/brain/founder-brain.md")
check "reading a file is allowed" hasnt "$out" '"deny"'

# A key pasted into the chat never goes into a file here, where a save would
# put it in git. Split in two so this file never holds the shape itself.
pk="pit-0a1b2c3d""-1111-2222-3333-444455556666"
out=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"GoHighLevel key: %s"}}' "$ge/drafts/ghl-setup.md" "$pk" |
  CLAUDE_PROJECT_DIR="$work" sh "$work/.claude/scripts/guard-pre.sh" 2>/dev/null)
check "writing a GoHighLevel key into a file is refused" has "$out" '"deny"'
check "and the refusal never repeats the key" hasnt "$out" "$pk"
out=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s","old_string":"key: %s","new_string":"key: in the password store"}}' "$ge/drafts/ghl-setup.md" "$pk" |
  CLAUDE_PROJECT_DIR="$work" sh "$work/.claude/scripts/guard-pre.sh" 2>/dev/null)
check "an edit that takes a key out of a file is allowed" hasnt "$out" '"deny"'
c="echo 'GoHighLevel key: $pk' > growth-engine/drafts/ghl-setup.md"
out=$(hook guard-pre.sh Bash command "$c")
check "a shell command holding a key is refused" has "$out" '"deny"'
out=$(shell "$c" sh -c 'printf "GoHighLevel key: %s\n" "$1" > "$2"' _ "$pk" "$ge/drafts/ghl-setup.md")
check "a key a shell command put in drafts/ is taken out again" test ! -e "$ge/drafts/ghl-setup.md"
check "and the key is never quoted back" hasnt "$out" "$pk"
check "and Claude is told why" has "$out" 'password store'
out=$(write drafts/ghl-note.md "GoHighLevel key: $pk")
check "a note about a line never quotes a key back" hasnt "$out" "$pk"
rm -f "$ge/drafts/ghl-note.md"

# No key file anywhere: the key is never kept in a file.
check "no key file is named anywhere in the folder" \
  sh -c '! grep -rqiE "gohighlevel-key|Documents/launchhouse|key\.txt" "$1/.claude" "$1/START-HERE.md" "$1/README.md" "$1/CLAUDE.md" "$1/.gitignore" --exclude-dir=tests' _ "$here/../.."
unset LH_FAKE_OS

# LH-023: the printable insert is an allowed, checked file.
out=$(hook guard-pre.sh Write file_path "$ge/export/playbook-insert.html")
check "writing playbook-insert.html is allowed" hasnt "$out" '"deny"'
out=$(write export/playbook-insert.html "<p>$cold</p>")
check "and it is checked" has "$out" 'HELD'

# LH-022: every file has one place, in folders by kind.
out=$(hook guard-pre.sh Write file_path "$ge/founder-brain.md")
check "the Brain at the top of growth-engine is refused" has "$out" 'lives at growth-engine/brain/founder-brain.md'
out=$(hook guard-pre.sh Write file_path "$ge/engines/ops/content-30.md")
check "a file in the wrong engine folder is refused" has "$out" 'lives at growth-engine/engines/content/content-30.md'
out=$(hook guard-pre.sh Write file_path "$ge/uploads/menu.md")
check "the old uploads folder is refused, naming the new one" has "$out" 'growth-engine/inbox/uploads/menu.md'
out=$(hook guard-pre.sh Write file_path "$ge/engines/content/notes.md")
check "a stray file in an engine folder is refused" has "$out" 'not one of the Launchhouse files'
for p in brain/founder-brain.md engines/content/content-30.md engines/content/content-30-2026-08.md \
         engines/audience/hook-bank.md engines/ops/ops-workflow.md engines/plan/90-day-plan.md \
         export/playbook-insert.md log/ledger.md inbox/uploads/menu.md brain/voice-samples/post.md; do
  out=$(hook guard-pre.sh Write file_path "$ge/$p")
  check "writing growth-engine/$p is allowed" hasnt "$out" '"deny"'
done
out=$(hook guard-pre.sh Write file_path "$work/content-30.md")
check "a Launchhouse file outside the folder is sent to its place inside" has "$out" 'growth-engine/engines/content/content-30.md'

# LH-003: never push to the public original.
if command -v git >/dev/null 2>&1; then
  git -C "$work" init -q 2>/dev/null
  git -C "$work" remote add origin https://github.com/Philm-moxywolf/launchhouse-founder-template.git
  out=$(hook guard-pre.sh Bash command "git push")
  check "pushing to an origin that is the public original is refused" has "$out" '"deny"'
  out=$(hook guard-pre.sh Bash command "git add growth-engine && git commit -m Saved && git push origin main")
  check "and so is a push at the end of a save" has "$out" '"deny"'
  git -C "$work" remote set-url origin https://github.com/sam-bakes/my-launchhouse.git
  git -C "$work" remote add upstream https://github.com/philm-moxywolf/launchhouse-founder-template.git
  out=$(hook guard-pre.sh Bash command "git push")
  check "pushing to a private origin is allowed while the original is an upstream" hasnt "$out" '"deny"'
  out=$(hook guard-pre.sh Bash command "git push upstream main")
  check "pushing to that upstream is refused" has "$out" '"deny"'

  # KNOWN LIMITATION, documented not fixed here: lh_push_to_original only
  # pattern-matches "philm-moxywolf" in the resolved remote's URL. A GitHub
  # fork keeps the same repo name under a different, non-philm-moxywolf
  # owner, so this guard has no way to tell a fork from any other founder's
  # private copy and lets a push to one through. The mitigation for a fork
  # is the UI-level "Publish, never Fork" intervention in the start skill
  # (fix #1), not this guard, which cannot see GitHub's fork relationship at
  # all from a git remote URL alone.
  git -C "$work" remote set-url origin https://github.com/some-random-founder/launchhouse-founder-template.git
  out=$(hook guard-pre.sh Bash command "git push")
  check "KNOWN LIMITATION: a push to a fork-shaped URL under a non-philm-moxywolf owner is NOT refused" hasnt "$out" '"deny"'
  # A push to the template itself, any owner-case spelling, is still refused:
  # the fork-vs-template line is drawn on the owner name in the URL alone.
  git -C "$work" remote set-url origin https://github.com/Philm-Moxywolf/launchhouse-founder-template.git
  out=$(hook guard-pre.sh Bash command "git push")
  check "a push to the template itself, any case, is still refused" has "$out" '"deny"'
  # Restore origin to what it was before this block, since nothing later in
  # this file should see the fork or template URL left behind.
  git -C "$work" remote set-url origin https://github.com/sam-bakes/my-launchhouse.git
fi

# Desktop copies privacy guard: a shell copy of real people's details out of
# the project is refused; the same file copied within the project is fine,
# and so is desktop-copy.sh's own on-demand invocation.
out=$(hook guard-pre.sh Bash command "cp growth-engine/people/sam.md ~/Desktop/sam.md")
check "cp of a person file to the Desktop is refused" has "$out" '"deny"'
out=$(hook guard-pre.sh Bash command "cp growth-engine/engines/audience/dm-openers.md ~/Desktop/openers.md")
check "cp of dm-openers.md to the Desktop is refused" has "$out" '"deny"'
out=$(hook guard-pre.sh Bash command "cp growth-engine/engines/outreach/outreach-firstlines.csv /Users/sam/Desktop/firstlines.csv")
check "cp of outreach-firstlines.csv to an absolute Desktop path is refused" has "$out" '"deny"'
out=$(hook guard-pre.sh Bash command "cp $ge/people/sam.md $ge/drafts/sam-copy.md")
check "cp of a person file to another folder inside the project is allowed" hasnt "$out" '"deny"'
out=$(hook guard-pre.sh Bash command "cp $ge/drafts/plan.md ~/Desktop/plan.md")
check "cp of a harmless file to the Desktop is allowed" hasnt "$out" '"deny"'
out=$(hook guard-pre.sh Bash command "sh .claude/scripts/desktop-copy.sh < /dev/null")
check "desktop-copy.sh's own on-demand run is never refused by the privacy guard" hasnt "$out" '"deny"'

if [ "$fail" = 0 ]; then
  printf '\nAll cases passed.\n'
else
  printf '\nSome cases failed.\n'
fi
exit $fail
