#!/bin/sh
# Runs the rules over the fixture files and prints pass or fail for each case.
#
# Usage: sh .claude/tests/run.sh
#
# A fixture named pass-*.md must produce no held line for the rule it is about.
# A fixture named hold-*.md must still be held. The rule a fixture is about is
# read from its first line, which is a comment of the form:
#   <!-- rule: dm.offered -->

# An older updater leaks LH_UPDATE_RELOCATED and LH_UPDATE_ROOT into the checks
# it runs and never unsets them; clear both here, before anything else runs, so
# a nested update.sh call below can never mistake the founder's real folder
# for its own root.
unset LH_UPDATE_RELOCATED LH_UPDATE_ROOT

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

# settings.json is read by CONTENT, never by line shape -- see json-flat.sh's
# own header. Flattened once and cached: every assertion below that reads
# settings.json queries this same cached table, never a literal grep on the
# file's own bytes.
LH_SETTINGS_FLAT_CACHE=""
lh_settings_flat() {
  if [ -z "$LH_SETTINGS_FLAT_CACHE" ]; then
    LH_SETTINGS_FLAT_CACHE=$(sh "$scripts/json-flat.sh" "$settings" 2>/dev/null)
    [ -n "$LH_SETTINGS_FLAT_CACHE" ] || LH_SETTINGS_FLAT_CACHE="$(printf '\t')"
  fi
  printf '%s\n' "$LH_SETTINGS_FLAT_CACHE"
}
lh_settings_has_value() {
  lh_settings_flat | awk -F '\t' -v want="$1" '$2 == want { found = 1 } END { exit !found }'
}
lh_settings_never_has() {
  ! lh_settings_flat | awk -F '\t' -v needle="$1" 'index($1, needle) || index($2, needle) { found = 1 } END { exit !found }'
}
lh_settings_mcp_matcher_routes_through() {
  lsm_want=$1
  lsm_count=$(lh_settings_flat | awk -F '\t' '$1 ~ /^\/hooks\/PreToolUse\/[0-9]+\/matcher$/ && $2 == "^mcp__" { c++ } END { print c + 0 }')
  [ "$lsm_count" = 1 ] || return 1
  lsm_idx=$(lh_settings_flat | awk -F '\t' '$1 ~ /^\/hooks\/PreToolUse\/[0-9]+\/matcher$/ && $2 == "^mcp__" { sub(/^\/hooks\/PreToolUse\//, "", $1); sub(/\/matcher$/, "", $1); print $1 }')
  lh_settings_flat | awk -F '\t' -v idx="$lsm_idx" -v want="$lsm_want" '$1 ~ ("^/hooks/PreToolUse/" idx "/hooks/[0-9]+/command$") && index($2, want) { found = 1 } END { exit !found }'
}
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
# Set once true (never reset) when a check in the settings-wiring block below
# (the mcp__ dispatcher wiring) fails, so the founder-readable hint about it
# can be printed as the very last lines of this whole file's output, after
# the pass/fail summary, where cmd_apply's tail -60 is sure to keep it.
settings_wiring_failed=0
checksw() { # name, then a test -- like check(), but also flags settings_wiring_failed
  n=$1; shift
  if "$@"; then printf 'PASS  %s\n' "$n"; else printf 'FAIL  %s\n' "$n"; fail=1; settings_wiring_failed=1; fi
}
has() { printf '%s' "$1" | grep -q "$2"; }
hasnt() { ! printf '%s' "$1" | grep -q "$2"; }
match_eq() { [ "$1" = "$2" ]; }

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

lh_settings_exactly_one_mcp_matcher() {
  [ "$(lh_settings_flat | awk -F '\t' '$1 ~ /^\/hooks\/PreToolUse\/[0-9]+\/matcher$/ && $2 == "^mcp__" { c++ } END { print c + 0 }')" = 1 ]
}
lh_settings_neither_retired_script_named() {
  lh_settings_never_has 'deny-mcp.sh' && lh_settings_never_has 'ask-mcp.sh'
}
checksw "settings.json carries exactly one mcp__ matcher, and it is the only one" lh_settings_exactly_one_mcp_matcher
checksw "it runs mcp-guard.sh" lh_settings_mcp_matcher_routes_through 'scripts/mcp-guard.sh'
checksw "deny-mcp.sh is gone" test ! -e "$scripts/deny-mcp.sh"
checksw "ask-mcp.sh is gone" test ! -e "$scripts/ask-mcp.sh"
checksw "neither is named in settings.json any more" lh_settings_neither_retired_script_named
checksw "ghl-op.sh is not named in settings.json, it is a sourced library now" lh_settings_never_has 'scripts/ghl-op.sh'

# The remote/branch/fetch allowlist that lets the start skill normalize
# remotes (rename the template to upstream, add or point origin, unset a
# stray upstream tracking branch) without a permission prompt mid-setup.
check "settings.json allows git remote get-url" lh_settings_has_value 'Bash(git remote get-url:*)'
check "settings.json allows git remote add" lh_settings_has_value 'Bash(git remote add:*)'
check "settings.json allows git remote remove" lh_settings_has_value 'Bash(git remote remove:*)'
check "settings.json allows git remote rename" lh_settings_has_value 'Bash(git remote rename:*)'
check "settings.json allows git remote set-url" lh_settings_has_value 'Bash(git remote set-url:*)'
check "settings.json allows git branch --unset-upstream" lh_settings_has_value 'Bash(git branch --unset-upstream)'
check "settings.json allows git fetch origin" lh_settings_has_value 'Bash(git fetch origin)'
check "settings.json allows git fetch upstream" lh_settings_has_value 'Bash(git fetch upstream)'
check "settings.json allows git ls-remote" lh_settings_has_value 'Bash(git ls-remote:*)' 

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
# an opportunity updated, a custom value created or updated.
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
ghlcask "updating a custom value asks, same tier as the other named GHL writes" mcp__highlevel__execute_operation '{"operationId":"locations_update-custom-value"}'
ghlcask "creating a custom value asks too" mcp__highlevel__execute_operation '{"operationId":"locations_create-custom-value"}'
ghlcdeny "deleting a custom value is still refused outright, never just asked" mcp__highlevel__execute_operation '{"operationId":"locations_delete-custom-value"}'

# Guide: every other write. Not blocked, not forced to a prompt, just noted.
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

# -------------------------------------------------------------- skill-packs.sh
# The pack validator, compiler and per-pack test runner, against the real
# .claude/skill-packs/. A pack still under construction by another worker
# shows up here as a real FAIL, same as any other missing piece — that is
# the point of running it in the suite.
tp="$here/../scripts/skill-packs.sh"
check "skill-packs.sh --validate all reports no problems" sh -c '"$1" --validate all >/dev/null 2>&1' _ "$tp"
check "skill-packs.sh --compile then --check-compiled agree" sh -c '"$1" --compile >/dev/null 2>&1 && "$1" --check-compiled >/dev/null 2>&1' _ "$tp"
check "skill-packs.sh --test all passes every pack's own tests" sh -c '"$1" --test all >/dev/null 2>&1' _ "$tp"

# ------------------------------------------------- skill-packs.sh: name safety
# Grammar enforcement and symlink/traversal defence on pack ids and on
# skill/agent/script names sourced from pack.md or the filesystem, against
# the throwaway $work copy of skill-packs.sh (so nothing here ever touches
# the real .claude/skill-packs/). A snapshot of $work's own file list, taken
# before and compared after, proves a refusal really did write nothing.
wtp="$work/.claude/scripts/skill-packs.sh"
wsnapshot() { find "$work" -type f 2>/dev/null | sort; }

snap_before=$(wsnapshot)
badidout=$( ( cd "$work" && sh .claude/scripts/skill-packs.sh --validate '../../escaped-pack' 2>&1 ) )
badidrc=$?
check "a pack id containing ../ is refused" test "$badidrc" -ne 0
check "and names the problem on stderr" has "$badidout" 'is not a valid name'
check "nothing was written anywhere under the fixture folder" match_eq "$(wsnapshot)" "$snap_before"

mkdir -p "$work/.claude/skill-packs/badnames/skills/ok-skill"
printf -- '---\nname: ok-skill\ndescription: fixture\n---\n\nbody\n' > "$work/.claude/skill-packs/badnames/skills/ok-skill/SKILL.md"
printf -- '---\nid: badnames\nname: Bad Names\nkind: guide\nskills: [foo/bar]\nagents: []\nscripts: []\ntracks: both\norigin: template\n---\n\nFixture pack whose pack.md names a skill with a slash in it.\n' \
  > "$work/.claude/skill-packs/badnames/pack.md"
snap_before=$(wsnapshot)
badnameout=$( ( cd "$work" && sh .claude/scripts/skill-packs.sh --install badnames 2>&1 ) )
badnamerc=$?
check "a skill name containing / in pack.md is refused" test "$badnamerc" -ne 0
check "and names the problem on stderr" has "$badnameout" 'is not a valid name'
check "nothing was installed to .claude/skills/ from it" test ! -e "$work/.claude/skills/foo"
check "nothing was written anywhere under the fixture folder" match_eq "$(wsnapshot)" "$snap_before"

mkdir -p "$work/elsewhere/foo"
printf -- '---\nname: foo\ndescription: fixture\n---\n\nbody, reached only by following the symlink\n' > "$work/elsewhere/foo/SKILL.md"
mkdir -p "$work/.claude/skill-packs/symlinkpack"
printf -- '---\nid: symlinkpack\nname: Symlink Pack\nkind: guide\nskills: [foo]\nagents: []\nscripts: []\ntracks: both\norigin: template\n---\n\nFixture pack whose skills/ directory is a symlink.\n' \
  > "$work/.claude/skill-packs/symlinkpack/pack.md"
ln -s "$work/elsewhere" "$work/.claude/skill-packs/symlinkpack/skills"
snap_before=$(wsnapshot)
symlinkout=$( ( cd "$work" && sh .claude/scripts/skill-packs.sh --install symlinkpack 2>&1 ) )
symlinkrc=$?
check "a symlinked skill directory presented as a pack source is refused" test "$symlinkrc" -ne 0
check "and names it as a symlink on stderr" has "$symlinkout" 'symlink'
check "nothing was installed to .claude/skills/foo through the symlink" test ! -e "$work/.claude/skills/foo"
check "nothing new was written outside what this fixture set up itself" \
  match_eq "$(wsnapshot | grep -v '^'"$work"'/elsewhere/\|^'"$work"'/\.claude/skill-packs/symlinkpack/')" \
  "$(printf '%s\n' "$snap_before" | grep -v '^'"$work"'/elsewhere/\|^'"$work"'/\.claude/skill-packs/symlinkpack/')"

rm -rf "$work/.claude/skill-packs" "$work/elsewhere"

# ------------------------------------------- mcp-guard.sh: compiled-policy
# fallback. mcp-guard.sh prefers .claude/skill-packs/compiled-policy.sh, and
# must fall back to the legacy .claude/tool-packs/compiled-policy.sh both
# when the new path is simply absent AND when it exists but fails its own
# sh -n syntax check (a corrupt or half-written file) -- never silently
# source nothing in the second case just because a file happens to be
# sitting at the new path. A fixture folder of its own, never $work, so a
# broken compiled-policy.sh here can never bleed into any other test.
mgfb=${TMPDIR:-/tmp}/lh-mcpguard-fallback-test.$$
mkdir -p "$mgfb/.claude/scripts" "$mgfb/growth-engine"
cp -R "$scripts" "$mgfb/.claude/"
: > "$mgfb/growth-engine/.launchhouse"

mgfb_legacy_policy() {
  mkdir -p "$mgfb/.claude/tool-packs"
  cat > "$mgfb/.claude/tool-packs/compiled-policy.sh" <<'EOF'
#!/bin/sh
LH_PACK_DETECT_RULES=''
LH_PACK_DENY_RULES=''
LH_PACK_ASK_RULES=''
lh_pack_detect() { lh_pack_id=""; lh_pack_name=""; }
lh_pack_policy() {
  suffix=$1
  lh_pack_decision=""
  lh_pack_reason=""
  case "$suffix" in
    legacy_fallback_tool) lh_pack_decision=deny; lh_pack_reason="Synthetic: legacy fallback pack test." ;;
  esac
}
EOF
}

mgfb_call() { # tool suffix
  printf '{"tool_name":"mcp__test__%s","tool_input":{}}' "$1" |
    CLAUDE_PROJECT_DIR="$mgfb" sh "$mgfb/.claude/scripts/mcp-guard.sh" 2>/dev/null
}

# Case 1: the new path is simply absent, the legacy path is present and
# valid -- falls back, the legacy pack's own deny rule is honoured.
rm -rf "$mgfb/.claude/skill-packs" "$mgfb/.claude/tool-packs"
mgfb_legacy_policy
out=$(mgfb_call legacy_fallback_tool)
check "compiled-policy.sh absent at the new path falls back to the legacy path" has "$out" '"deny"'

# Case 2: the new path exists but is broken (fails sh -n) -- still falls
# back to the legacy path, rather than silently sourcing nothing.
mkdir -p "$mgfb/.claude/skill-packs"
printf 'this is not valid POSIX sh ((( \n' > "$mgfb/.claude/skill-packs/compiled-policy.sh"
out=$(mgfb_call legacy_fallback_tool)
check "a syntactically broken compiled-policy.sh at the new path also falls back to the legacy path" has "$out" '"deny"'

# Confirmed broken, so the fallback in case 2 really was exercised and not
# skipped because the new file happened to be syntactically fine.
check "and the new path's own file really does fail sh -n"   sh -c '! sh -n "$1" 2>/dev/null' _ "$mgfb/.claude/skill-packs/compiled-policy.sh"

rm -rf "$mgfb"

# ---------------------------------------------------------- prompt-state.sh
# Connection planning: a verb (connect, set up, integrate, ...) followed
# later in the same sentence by a skill-packs registry name, or by a generic
# word for one (tool, app, crm, connector, integration, account).
mkdir -p "$work/.claude/skill-packs"
cp "$here/../skill-packs/registry.tsv" "$work/.claude/skill-packs/registry.tsv"

promptcheck() { # description, prompt text, match|nomatch
  desc=$1; ptext=$2; expect=$3
  pout=$(printf '{"prompt":"%s","permission_mode":"default"}' "$ptext" |
    CLAUDE_PROJECT_DIR="$work" sh "$work/.claude/scripts/prompt-state.sh" 2>/dev/null)
  if [ "$expect" = match ]; then
    check "$desc" has "$pout" 'Connection planning'
  else
    check "$desc" hasnt "$pout" 'Connection planning'
  fi
}

promptcheck "connect + Apollo names Apollo's own expert pack" "can you connect Apollo for me" match
promptcheck "set up + Gmail names Gmail's own expert pack" "I want to set up Gmail" match
promptcheck "integrate + CRM is a generic connection-planning note" "let's integrate a new CRM" match
promptcheck "a name with no verb near it never fires" "Apollo was a Greek god" nomatch
promptcheck "a verb with no tool noun near it never fires" "I use my phone a lot" nomatch
promptcheck "'use' the app in ordinary talk never fires, use is dropped and app is dropped" "I use the app every day" nomatch
promptcheck "'set up' my account in ordinary talk never fires, account is dropped as a bare generic noun" "I set up my account yesterday" nomatch

# ---------------------------------------------- a pack can never loosen
# A synthetic pack, in $work only, never the real registry: one policy row
# for a suffix mcp-guard.sh already denies by name (send_message), and one
# for a suffix it would otherwise read as a plain, silent read
# (search_threads). Both ask for less than mcp-guard already gives, so the
# first must stay deny and the second must still tighten to ask, never fall
# back to silent just because the pack's own row says ask instead of deny.
rm -rf "$work/.claude/skill-packs"
mkdir -p "$work/.claude/skill-packs/loosen"
printf 'id\tname\tkind\tsuffix_regex\ttracks\torigin\n' > "$work/.claude/skill-packs/registry.tsv"
printf 'loosen\tLoosen Test\ttool\t^(send_message|search_threads)$\tboth\ttemplate\n' >> "$work/.claude/skill-packs/registry.tsv"
{
  printf '^send_message$\task\tSynthetic: must never loosen what mcp-guard already denies.\n'
  printf '^search_threads$\task\tSynthetic: a plain read still gets asked when a pack says so.\n'
} > "$work/.claude/skill-packs/loosen/policy.tsv"
sh "$work/.claude/scripts/skill-packs.sh" --compile >/dev/null 2>&1

out=$(mg mcp__test__send_message '{}')
check "a pack's own 'ask' can never loosen a deny mcp-guard already reaches" has "$out" '"deny"'
out=$(mg mcp__test__search_threads '{}')
check "a pack's own 'ask' still tightens a plain read past silent" has "$out" '"ask"'

# ------------------------------------------------ specialist approval grants
# Claude Code's PreToolUse input carries a top-level agent_type (and
# agent_id) for a subagent call. mcp-guard.sh reads it structurally, the
# same safe reader tool_name itself uses, and gates every non-silent,
# non-deny decision for an agent_type ending "-specialist" behind a live
# grant written by approve.sh. $work is a real git repo by this point (the
# LH-003 push-to-original cases above already ran "git -C "$work" init"),
# so lh_bk_dir resolves inside it the same way it does for the founder's
# own folder.

mgagent() { # tool_name, tool_input-json, agent_type, mode (default acceptEdits)
  m=${4:-acceptEdits}
  printf '{"session_id":"abc","transcript_path":"/Users/jo/.claude/projects/x.jsonl","cwd":"/Users/jo/launchhouse","permission_mode":"%s","hook_event_name":"PreToolUse","agent_type":"%s","agent_id":"ag1","tool_name":"%s","tool_input":%s}' \
    "$m" "$3" "$1" "$2" |
    CLAUDE_PROJECT_DIR="$work" sh "$work/.claude/scripts/mcp-guard.sh" 2>/dev/null
}
approve() { CLAUDE_PROJECT_DIR="$work" sh "$work/.claude/scripts/approve.sh" "$@" >/dev/null 2>&1; }
bkdir=$(CLAUDE_PROJECT_DIR="$work" sh -c '. "$1/.claude/scripts/lib.sh" && lh_bk_dir' _ "$work")

# 1. A specialist write with no grant at all is refused, and the reason
# sends it back to the main conversation's own two-phase protocol.
out=$(mgagent mcp__286d__create_draft '{}' gmail-specialist)
check "a gmail-specialist create_draft call with no grant is denied" has "$out" '"deny"'
check "and the reason points back to PHASE: plan and approve.sh" has "$out" 'PHASE: plan'

# 2. A grant lets exactly that decision through (guide here, not loosened
# to silent), and is consumed: a second call with nothing left denies again.
approve --grant gmail create_draft
out=$(mgagent mcp__286d__create_draft '{}' gmail-specialist)
check "with a live grant, create_draft is guided, the decision mcp-guard.sh already reached" isguide "$out"
out=$(mgagent mcp__286d__create_draft '{}' gmail-specialist)
check "the same suffix called again, with the grant now spent, is denied" has "$out" '"deny"'

# 3. An expired grant (written straight to the approvals file, past its own
# expiry) is treated the same as no grant at all.
mkdir -p "$bkdir/approvals"
printf 'create_draft\t1\t1\n' > "$bkdir/approvals/gmail"
out=$(mgagent mcp__286d__create_draft '{}' gmail-specialist)
check "an expired grant denies, the same as an absent one" has "$out" '"deny"'
rm -f "$bkdir/approvals/gmail"

# 4. A plain read by a specialist is never gated: still silent, grant or no
# grant. list_drafts, not search_threads: the "a pack can never loosen"
# fixture just above compiled a synthetic policy that turns search_threads
# into an "ask" for the rest of this run, on purpose, so it is not a clean
# read to test against here.
out=$(mgagent mcp__286d__list_drafts '{}' gmail-specialist)
check "a specialist's own read is silent, ungated" test -z "$out"

# 5. A grant never loosens a deny: mcp-guard.sh's own name classifier
# refuses send_message outright, before this gate is ever reached.
approve --grant gmail send_message
out=$(mgagent mcp__286d__send_message '{}' gmail-specialist)
check "a deny tool stays denied for a specialist even with a live grant" has "$out" '"deny"'
approve --clear gmail

# 6. The main thread (no agent_type at all) is unaffected by any of this.
out=$(mg mcp__286d__create_draft '{}')
check "an ordinary main-thread call is guided with no grant needed" isguide "$out"

# 7. A subagent that is not a "-specialist" (agent_type non-empty) is routed
# to deny on any non-silent, non-deny connector call: it cannot show the
# founder a live prompt either, and only a *-specialist runs the two-phase
# plan/execute/grant protocol that makes an unattended call safe. A plain
# read stays silent; a call the classifier already denies by name stays
# denied.
out=$(mgagent mcp__286d__create_draft '{}' general-purpose)
check "a non-specialist subagent's connector write is denied, not guided" has "$out" '"deny"'
check "and it points at that tool's own specialist" has "$out" 'specialist'
out=$(mgagent mcp__286d__list_drafts '{}' general-purpose)
check "a non-specialist subagent's own read is silent, unaffected" test -z "$out"
out=$(mgagent mcp__286d__send_message '{}' general-purpose)
check "a non-specialist subagent's already-denied call stays denied" has "$out" '"deny"'

# 8. Fail closed, not open: a specialist call in a folder with no git repo
# at all (so lh_bk_dir cannot resolve an approvals folder) is denied, never
# silently let through the way every other doubt-case in this hook is.
nogit="${work}-nogit"
mkdir -p "$nogit/.claude" "$nogit/growth-engine"
cp -R "$scripts" "$nogit/.claude/"
: > "$nogit/growth-engine/.launchhouse"
out=$(printf '{"session_id":"a","permission_mode":"acceptEdits","hook_event_name":"PreToolUse","agent_type":"gmail-specialist","tool_name":"mcp__286d__create_draft","tool_input":{}}' |
  CLAUDE_PROJECT_DIR="$nogit" sh "$nogit/.claude/scripts/mcp-guard.sh" 2>/dev/null)
check "a specialist call with no resolvable approvals folder fails closed (deny), not open" has "$out" '"deny"'
rm -rf "$nogit"

# 9. A 1-count grant consumed by two calls at once: the mkdir-based lock
# around the read-check-decrement-write means exactly one of them sees the
# live grant and the other finds it already spent, never both seeing
# "1 remaining" and both going through.
approve --grant gmail create_draft
race1="$work/race1.out"; race2="$work/race2.out"
mgagent mcp__286d__create_draft '{}' gmail-specialist > "$race1" 2>/dev/null &
racepid1=$!
mgagent mcp__286d__create_draft '{}' gmail-specialist > "$race2" 2>/dev/null &
racepid2=$!
wait "$racepid1" "$racepid2" 2>/dev/null
nondeny=0
has "$(cat "$race1" 2>/dev/null)" '"deny"' || nondeny=$((nondeny + 1))
has "$(cat "$race2" 2>/dev/null)" '"deny"' || nondeny=$((nondeny + 1))
check "a 1-count grant hit by two concurrent calls lets exactly one through" match_eq "$nondeny" 1
rm -f "$race1" "$race2"
approve --clear gmail

# 10. A lock already held (another writer mid-update) denies rather than
# read a file that might be half-written or race that writer's own
# decrement. The lock dir carries a fresh timestamp, so this is the
# contested-not-stale path, not the abandoned-lock cleanup path.
approve --grant gmail create_draft
heldlock="$bkdir/approvals/gmail.lock"
mkdir -p "$heldlock"
date +%s > "$heldlock/ts" 2>/dev/null
out=$(mgagent mcp__286d__create_draft '{}' gmail-specialist)
check "a lock already held by another writer denies this call" has "$out" '"deny"'
rm -rf "$heldlock"
approve --clear gmail

# 11. date +%s failing (or returning something not a plain integer) denies a
# specialist call outright rather than trust an unreadable clock to judge a
# grant's expiry. Simulated with a PATH stub ahead of the real date.
approve --grant gmail create_draft
baddate="$work-baddate"
mkdir -p "$baddate"
printf '#!/bin/sh\nexit 1\n' > "$baddate/date"
chmod +x "$baddate/date"
out=$(printf '{"session_id":"abc","transcript_path":"/Users/jo/.claude/projects/x.jsonl","cwd":"/Users/jo/launchhouse","permission_mode":"acceptEdits","hook_event_name":"PreToolUse","agent_type":"gmail-specialist","agent_id":"ag1","tool_name":"mcp__286d__create_draft","tool_input":{}}' |
  CLAUDE_PROJECT_DIR="$work" PATH="$baddate:$PATH" sh "$work/.claude/scripts/mcp-guard.sh" 2>/dev/null)
check "a broken date command denies a specialist call rather than trust it" has "$out" '"deny"'
rm -rf "$baddate"
approve --clear gmail

# ------------------------------------------ a subagent can never self-grant
# approve.sh (see above) is the only writer of a specialist's approval
# grants, at $(git rev-parse --git-dir)/launchhouse/approvals/<pack>. Every
# subagent holds Bash, Write, Edit and MultiEdit, so without a check in
# guard-pre.sh (PreToolUse on those tools) it could run approve.sh itself,
# or write straight into the approvals folder. $work is a real git repo by
# this point, the same one the specialist-approval cases above used.

gpagent() { # tool_name, tool_input-json, agent_type (empty for the main thread)
  at=$3
  if [ -n "$at" ]; then atfield="\"agent_type\":\"$at\","; else atfield=""; fi
  printf '{%s"session_id":"abc","transcript_path":"/Users/jo/.claude/projects/x.jsonl","cwd":"/Users/jo/launchhouse","permission_mode":"acceptEdits","hook_event_name":"PreToolUse","tool_name":"%s","tool_input":%s}' \
    "$atfield" "$1" "$2" |
    CLAUDE_PROJECT_DIR="$work" sh "$work/.claude/scripts/guard-pre.sh" 2>/dev/null
}

out=$(gpagent Bash '{"command":"sh .claude/scripts/approve.sh --grant ghl execute_operation"}' ghl-specialist)
check "a subagent running approve.sh itself is denied" has "$out" '"deny"'

out=$(gpagent Bash '{"command":"printf '"'"'x'"'"' > .git/launchhouse/approvals/ghl"}' ghl-specialist)
check "a subagent writing straight into the approvals folder via Bash is denied" has "$out" '"deny"'

out=$(gpagent Write "{\"file_path\":\"$work/.git/launchhouse/approvals/ghl\",\"content\":\"x\"}" ghl-specialist)
check "a subagent's Write straight into the approvals folder is denied" has "$out" '"deny"'

out=$(gpagent Bash '{"command":"sh .claude/scripts/approve.sh --grant ghl execute_operation"}' "")
check "the main thread running approve.sh is unaffected (allowed)" test -z "$out"

out=$(gpagent Write "{\"file_path\":\"$work/.git/launchhouse/approvals/ghl\",\"content\":\"x\"}" "")
check "even the main thread's own Write straight into the approvals folder is denied (approve.sh only)" has "$out" '"deny"'

out=$(gpagent Bash '{"command":"git status"}' ghl-specialist)
check "a specialist's ordinary Bash command is denied too, not only the approve.sh pattern" has "$out" '"deny"'

out=$(gpagent Bash '{"command":"echo hi"}' ghl-specialist)
check "a specialist cannot even echo: no shell at all, string match or not" has "$out" '"deny"'

out=$(gpagent Bash '{"command":"git status"}' general-purpose)
check "a non-specialist subagent's ordinary Bash command is unaffected (allowed)" test -z "$out"

# A specialist never writes a file directly either: it reports back to its
# caller, which is what writes into growth-engine/. Write, Edit and
# MultiEdit are all refused outright for a "-specialist" agent_type, the
# same footing as Bash above, and unaffected for every other caller.
out=$(gpagent Write "{\"file_path\":\"$work/growth-engine/people/sam-example-com.md\",\"content\":\"x\"}" ghl-specialist)
check "a specialist's Write is denied outright" has "$out" '"deny"'

out=$(gpagent Edit "{\"file_path\":\"$work/growth-engine/people/sam-example-com.md\",\"old_string\":\"x\",\"new_string\":\"y\"}" gmail-specialist)
check "a specialist's Edit is denied outright" has "$out" '"deny"'

out=$(gpagent MultiEdit "{\"file_path\":\"$work/growth-engine/people/sam-example-com.md\",\"edits\":[]}" apollo-specialist)
check "a specialist's MultiEdit is denied outright" has "$out" '"deny"'

out=$(gpagent Write "{\"file_path\":\"$work/growth-engine/people/sam-example-com.md\",\"content\":\"x\"}" general-purpose)
check "a non-specialist subagent's Write is unaffected (allowed)" test -z "$out"

out=$(gpagent Write "{\"file_path\":\"$work/growth-engine/people/sam-example-com.md\",\"content\":\"x\"}" "")
check "the main thread's own Write is unaffected too (allowed)" test -z "$out"

# ------------------------------------------------------------- dns-check.sh
# The domains pack's DNS checker, run offline against canned DoH JSON
# responses (LH_DNS_TESTING=1, LH_DNS_FIXTURE_DIR), so these tests need no
# network and never depend on a real domain's DNS staying the same. Fixtures
# live under the pack itself: .claude/skill-packs/domains/scripts/fixtures/dns/.

dns_script=$(cd "$here/../skill-packs/domains/scripts" 2>/dev/null && pwd)/dns-check.sh
dns_fixtures=$(cd "$here/../skill-packs/domains/scripts/fixtures/dns" 2>/dev/null && pwd)

dnscheck() { # fixture dir name, then dns-check.sh's own arguments (domain first)
  fx=$1; shift
  LH_DNS_TESTING=1 LH_DNS_FIXTURE_DIR="$dns_fixtures/$fx" sh "$dns_script" "$@" 2>/dev/null
}

if [ -n "$dns_fixtures" ] && { [ -x "$dns_script" ] || [ -f "$dns_script" ]; }; then
  out=$(dnscheck pass example.com --mailbox google)
  check "pass fixture: overall status is pass" has "$out" 'status=pass'
  check "pass fixture: mx passes" has "$out" 'mx=pass'
  check "pass fixture: spf passes" has "$out" 'spf=pass'
  check "pass fixture: dkim passes" has "$out" 'dkim=pass'
  check "pass fixture: dmarc passes" has "$out" 'dmarc=pass'
  check "pass fixture: no todo lines" hasnt "$out" '^todo='
  dnscheck pass example.com --mailbox google > /dev/null
  check "pass fixture: exit code is 0" test "$?" = 0

  out=$(dnscheck missing-dkim example.com --mailbox google)
  check "missing-dkim fixture: dkim fails" has "$out" 'dkim=fail'
  check "missing-dkim fixture: spf still passes" has "$out" 'spf=pass'
  check "missing-dkim fixture: names the selector in its todo" has "$out" 'google._domainkey.example.com'
  dnscheck missing-dkim example.com --mailbox google > /dev/null
  check "missing-dkim fixture: exit code is 1" test "$?" = 1

  out=$(dnscheck dup-spf example.com --mailbox google)
  check "dup-spf fixture: spf fails (two records, not a warn)" has "$out" 'spf=fail'
  check "dup-spf fixture: todo says merge, not add" has "$out" 'more than one SPF record'

  out=$(dnscheck no-dmarc example.com --mailbox google)
  check "no-dmarc fixture: dmarc fails" has "$out" 'dmarc=fail'
  check "no-dmarc fixture: spf and dkim still pass" has "$out" 'spf=pass'
  check "no-dmarc fixture: dkim still passes" has "$out" 'dkim=pass'

  out=$(dnscheck microsoft-selectors example.com --mailbox microsoft)
  check "microsoft-selectors fixture: dkim passes" has "$out" 'dkim=pass'
  check "microsoft-selectors fixture: selector2 passes" has "$out" 'dkim_selector2=pass'
  check "microsoft-selectors fixture: overall status is pass" has "$out" 'status=pass'

  # A resolver failure (Status -1 in the canned DoH JSON, distinct from a
  # clean "no records" answer) must degrade overall status to at least
  # warn, never leave it at pass, and the script must exit non-zero.
  out=$(dnscheck resolver-failure example.com --mailbox google)
  check "resolver-failure fixture: mx reads unknown, not pass or fail" has "$out" 'mx=unknown'
  check "resolver-failure fixture: overall status degrades to warn" has "$out" 'status=warn'
  check "resolver-failure fixture: names the failed check in its todo" has "$out" 'Could not check MX'
  dnscheck resolver-failure example.com --mailbox google > /dev/null
  check "resolver-failure fixture: exit code is non-zero" test "$?" != 0

  # A failed Microsoft selector2 DKIM lookup (its own CNAME query fails)
  # must never be recorded as a pass -- it reads unknown, degrades overall
  # to at least warn, and exits non-zero, the same as any other resolver
  # failure.
  out=$(dnscheck selector2-lookup-failed example.com --mailbox microsoft)
  check "selector2-lookup-failed fixture: selector2 reads unknown, never pass" has "$out" 'dkim_selector2=unknown'
  check "and never pass" hasnt "$out" 'dkim_selector2=pass'
  check "selector2-lookup-failed fixture: the main dkim selector still passes on its own" has "$out" 'dkim=pass'
  check "selector2-lookup-failed fixture: overall status degrades to warn" has "$out" 'status=warn'
  dnscheck selector2-lookup-failed example.com --mailbox microsoft > /dev/null
  check "selector2-lookup-failed fixture: exit code is non-zero" test "$?" != 0

  # A domain argument carrying a newline or a pipe is rejected outright,
  # before it is ever used in a command or a path.
  baddomain_nl=$(printf 'example.com\nrm -rf /')
  out=$(LH_DNS_TESTING=1 LH_DNS_FIXTURE_DIR="$dns_fixtures/pass" sh "$dns_script" "$baddomain_nl" --mailbox google 2>&1)
  check "a domain with an embedded newline is refused" has "$out" 'is not a valid hostname'
  LH_DNS_TESTING=1 LH_DNS_FIXTURE_DIR="$dns_fixtures/pass" sh "$dns_script" "$baddomain_nl" --mailbox google >/dev/null 2>&1
  check "and exits non-zero" test "$?" != 0
  out=$(LH_DNS_TESTING=1 LH_DNS_FIXTURE_DIR="$dns_fixtures/pass" sh "$dns_script" 'example.com|touch /tmp/lh-dns-pwned' --mailbox google 2>&1)
  check "a domain with a pipe character is refused" has "$out" 'is not a valid hostname'

  # --json produces well-formed-looking output with every field, not a
  # truncated object (this caught a real bug: a missing trailing newline
  # before piping into the read loop silently dropped the last field).
  out=$(dnscheck pass example.com --mailbox google --json)
  check "--json includes website_www (the last field)" has "$out" '"website_www":"pass"'
  check "--json includes an empty todo array when nothing is wrong" has "$out" '"todo":\[\]'

  # --record writes growth-engine/.state/domain.md, counts only, no record
  # values. Uses the shared $work fixture folder from earlier in this file.
  ( cd "$work" && LH_DNS_TESTING=1 LH_DNS_FIXTURE_DIR="$dns_fixtures/pass" CLAUDE_PROJECT_DIR="$work"       sh "$dns_script" example.com --mailbox google --record > /dev/null 2>&1 )
  check "--record writes growth-engine/.state/domain.md" test -f "$ge/.state/domain.md"
  domainmd=$(cat "$ge/.state/domain.md" 2>/dev/null)
  check "--record's file names the domain" has "$domainmd" 'example.com'
  check "--record's file holds no DNS record values (no v=spf1, no DKIM key text)" hasnt "$domainmd" 'v=spf1'
  rm -f "$ge/.state/domain.md"
else
  printf 'SKIP  dns-check.sh tests (script not found at %s)\n' "$dns_script"
fi

# --------------------------------------------------- json-valid.sh fixtures
# A real JSON parser, never a brace count: settings.json is the file that
# switches every safety hook on, so this is tested hard before anything
# else leans on it.
jvw=${TMPDIR:-/tmp}/lh-json-valid-test.$$
mkdir -p "$jvw" || exit 1
jvfile="$scripts/json-valid.sh"

printf '{"a":1,"nested":{"b":[1,2,{"c":"d\\"quoted\\" {not a brace}"}]},"e":true,"f":null,"g":-1.5e10}' > "$jvw/valid.json"
sh "$jvfile" "$jvw/valid.json" >/dev/null 2>&1
check "json-valid: a valid document with escapes, exponents and nesting passes" test $? = 0

printf '{}' > "$jvw/empty-obj.json"
sh "$jvfile" "$jvw/empty-obj.json" >/dev/null 2>&1
check "json-valid: an empty object passes" test $? = 0

printf '[]' > "$jvw/empty-arr.json"
sh "$jvfile" "$jvw/empty-arr.json" >/dev/null 2>&1
check "json-valid: an empty array passes" test $? = 0

printf '{"a":1,}' > "$jvw/trailing-comma.json"
out=$(sh "$jvfile" "$jvw/trailing-comma.json" 2>&1); rc=$?
check "json-valid: a trailing comma is refused" test "$rc" != 0
check "json-valid: and its last line is reason=" has "$out" '^reason='

printf '{"a": "unterminated' > "$jvw/unclosed-string.json"
sh "$jvfile" "$jvw/unclosed-string.json" >/dev/null 2>&1
check "json-valid: an unclosed string is refused" test $? != 0

printf '{"a":1 "b":2}' > "$jvw/missing-comma.json"
sh "$jvfile" "$jvw/missing-comma.json" >/dev/null 2>&1
check "json-valid: a missing comma between members is refused" test $? != 0

printf '{"a":1}{"b":2}' > "$jvw/duplicate-top.json"
sh "$jvfile" "$jvw/duplicate-top.json" >/dev/null 2>&1
check "json-valid: a duplicated top-level value (content after the first) is refused" test $? != 0

printf '{"a":{"b":{"c":[1,2,[3,4,{"d":"e"}]]}}}' > "$jvw/nested.json"
sh "$jvfile" "$jvw/nested.json" >/dev/null 2>&1
check "json-valid: deeply nested objects and arrays pass" test $? = 0

printf '{\r\n  "a": 1,\r\n  "b": [1, 2]\r\n}\r\n' > "$jvw/crlf.json"
sh "$jvfile" "$jvw/crlf.json" >/dev/null 2>&1
check "json-valid: CRLF line endings are tolerated" test $? = 0

printf '\357\273\277{"a":1}' > "$jvw/bom.json"
sh "$jvfile" "$jvw/bom.json" >/dev/null 2>&1
check "json-valid: a leading UTF-8 BOM is tolerated" test $? = 0

printf '{"matcher":"^mcp__","hooks":[{"type":"command","command":"x"}]}' > "$jvw/compact.json"
sh "$jvfile" "$jvw/compact.json" >/dev/null 2>&1
check "json-valid: a compact one-line document passes" test $? = 0

sh "$jvfile" "$settings" >/dev/null 2>&1
check "json-valid: this repo's own settings.json passes" test $? = 0

out=$(sh "$jvfile" "$jvw/does-not-exist.json" 2>&1); rc=$?
check "json-valid: a missing file is refused, not crashed on" test "$rc" != 0
check "json-valid: and it still gives a reason=" has "$out" 'reason='

rm -rf "$jvw"

# ------------------------------------------------- updates-lint.sh fixtures
ulw=${TMPDIR:-/tmp}/lh-updates-lint-test.$$
rm -rf "$ulw"; mkdir -p "$ulw/.claude/updates/2026-01-01" || exit 1
cp "$scripts/updates-lint.sh" "$ulw/lint.sh" 2>/dev/null
: > "$ulw/dummy-file.md"

ulw_note() { # id, body(printed as-is after a leading blank line's worth of headers already written by caller)
  :
}
# Writes a minimal, otherwise-valid note whose frontmatter has been passed
# through one sed-style substitution, so each case below changes exactly
# one thing about an otherwise well-formed note.
ulw_write() { # id, sed-expr (or "" for none)
  id=$1; expr=$2
  {
    printf -- '---\n'
    printf 'id: %s\n' "$id"
    printf 'title: A title\n'
    printf 'purpose: A purpose sentence.\n'
    printf 'touches:\n  - dummy-file.md\n'
    printf 'adds: []\n'
    printf 'requires: []\n'
    printf 'safety: false\n'
    printf 'done-when:\n  - "it holds"\n'
    printf 'check: none\n'
    printf 'founder-data: false\n'
    printf -- '---\n\n## What changed and why\ntest fixture only\n\n## What a stock file looks like after\ntest fixture only\n'
  } > "$ulw/.claude/updates/2026-01-01/$id.md.tmp"
  if [ -n "$expr" ]; then
    sed "$expr" "$ulw/.claude/updates/2026-01-01/$id.md.tmp" > "$ulw/.claude/updates/2026-01-01/$id.md"
    rm -f "$ulw/.claude/updates/2026-01-01/$id.md.tmp"
  else
    mv "$ulw/.claude/updates/2026-01-01/$id.md.tmp" "$ulw/.claude/updates/2026-01-01/$id.md"
  fi
}
ulw_clear() { rm -f "$ulw/.claude/updates/2026-01-01"/*.md "$ulw/.claude/updates/2026-01-01"/*.check.sh; }
ulw_run() { ( cd "$ulw" && sh lint.sh . ) 2>&1; }

ulw_clear
ulw_write case-good ""
out=$(ulw_run); rc=$?
check "updates-lint: a well-formed note passes" test "$rc" = 0
ulw_clear

ulw_write case-empty-title 's/^title: A title$/title:/'
out=$(ulw_run)
check "updates-lint: an empty title fails" has "$out" 'empty frontmatter key'
ulw_clear

ulw_write case-empty-purpose 's/^purpose: A purpose sentence.$/purpose:/'
out=$(ulw_run)
check "updates-lint: an empty purpose fails" has "$out" 'empty frontmatter key'
ulw_clear

ulw_write case-empty-check 's/^check: none$/check:/'
out=$(ulw_run)
check "updates-lint: an empty check field fails" has "$out" 'empty frontmatter key'
ulw_clear

ulw_write case-no-touches 's/^touches:$/touches: []/; /^  - dummy-file.md$/d'
out=$(ulw_run)
check "updates-lint: touches with no items fails" has "$out" 'touches has no items'
ulw_clear

ulw_write case-no-donewhen 's/^done-when:$/done-when: []/; /^  - "it holds"$/d'
out=$(ulw_run)
check "updates-lint: done-when with no items fails" has "$out" 'done-when has no items'
ulw_clear

ulw_write case-bad-safety 's/^safety: false$/safety: yes/'
out=$(ulw_run)
check "updates-lint: safety: yes (not true/false) fails" has "$out" 'safety must be true or false'
ulw_clear

ulw_write case-bad-founder-data 's/^founder-data: false$/founder-data: nope/'
out=$(ulw_run)
check "updates-lint: founder-data: nope (not true/false) fails" has "$out" 'founder-data must be true or false'
ulw_clear

ulw_write case-id-mismatch ""
mv "$ulw/.claude/updates/2026-01-01/case-id-mismatch.md" "$ulw/.claude/updates/2026-01-01/renamed.md" 2>/dev/null
sed -i.bak 's/^id: case-id-mismatch$/id: renamed/' "$ulw/.claude/updates/2026-01-01/renamed.md" 2>/dev/null
rm -f "$ulw/.claude/updates/2026-01-01/renamed.md.bak"
mv "$ulw/.claude/updates/2026-01-01/renamed.md" "$ulw/.claude/updates/2026-01-01/case-id-mismatch.md"
out=$(ulw_run)
check "updates-lint: an id that does not match the file name fails" has "$out" 'does not match its file name'
ulw_clear

ulw_write case-touches-ge 's#- dummy-file.md#- growth-engine/brain/founder-brain.md#'
out=$(ulw_run)
check "updates-lint: a touches path under growth-engine/ fails" has "$out" 'touches path is under growth-engine/'
ulw_clear

ulw_write case-touches-missing 's#- dummy-file.md#- this/path/does/not/exist.md#'
out=$(ulw_run)
check "updates-lint: a touches path that does not exist in the repo fails" has "$out" 'touches path does not exist in the repo'
ulw_clear

ulw_write case-safety-no-check 's/^safety: false$/safety: true/'
out=$(ulw_run)
check "updates-lint: safety: true with check: none fails" has "$out" 'a safety note must name an existing check file'
ulw_clear

ulw_write case-safety-missing-check 's/^safety: false$/safety: true/; s/^check: none$/check: no-such-file.check.sh/'
out=$(ulw_run)
check "updates-lint: safety: true naming a check file that does not exist fails" has "$out" 'does not exist in'
ulw_clear

printf '#!/bin/sh\nexit 0\n' > "$ulw/.claude/updates/2026-01-01/case-safety-good.check.sh"
ulw_write case-safety-good 's/^safety: false$/safety: true/; s/^check: none$/check: case-safety-good.check.sh/'
out=$(ulw_run); rc=$?
check "updates-lint: a well-formed safety note (existing check, a done-when) passes" test "$rc" = 0
ulw_clear
rm -f "$ulw/.claude/updates/2026-01-01/case-safety-good.check.sh"

# A quoted-empty scalar ("" or '') carries no real content and must be
# treated the same as the key being blank outright.
ulw_write case-quoted-empty-purpose 's/^purpose: A purpose sentence.$/purpose: ""/'
out=$(ulw_run)
check "updates-lint: a double-quoted empty purpose fails" has "$out" 'empty frontmatter key'
ulw_clear

ulw_write case-quoted-empty-title "s/^title: A title\$/title: ''/"
out=$(ulw_run)
check "updates-lint: a single-quoted empty title fails" has "$out" 'empty frontmatter key'
ulw_clear

# An explicit empty-array touches/done-when value must still be rejected.
ulw_write case-touches-empty-array 's/^touches:$/touches: []/; /^  - dummy-file.md$/d'
out=$(ulw_run)
check "updates-lint: touches: [] (explicit empty array) fails" has "$out" 'touches has no items'
ulw_clear

# A list item line that is only whitespace after the dash carries no real
# item, and must not be counted as one (nor flow into the path-exists
# check as a blank path, which would always "exist" as the repo root).
ulw_write case-touches-blank-item 's/^  - dummy-file.md$/  -   /'
out=$(ulw_run)
check "updates-lint: a blank-only touches item fails" has "$out" 'touches has no items'
ulw_clear

ulw_write case-donewhen-empty-array 's/^done-when:$/done-when: []/; /^  - "it holds"$/d'
out=$(ulw_run)
check "updates-lint: done-when: [] (explicit empty array) fails" has "$out" 'done-when has no items'
ulw_clear

ulw_write case-donewhen-blank-item 's/^  - "it holds"$/  -   /'
out=$(ulw_run)
check "updates-lint: a blank-only done-when item fails" has "$out" 'done-when has no items'
ulw_clear

# The linter creates scratch temp files (lh_mktemp, called via command
# substitution) once per note per touches/done-when check. Every one of
# them must actually be cleaned up on exit, not silently leaked into
# TMPDIR forever.
ulw_write case-tmp-leak-check ""
lhtmp_check_dir=$(mktemp -d "${TMPDIR:-/tmp}/lh-updates-lint-tmpcheck.XXXXXX")
( TMPDIR="$lhtmp_check_dir" sh "$ulw/lint.sh" "$ulw" ) >/dev/null 2>&1
lhtmp_leftover=$(ls -A "$lhtmp_check_dir" 2>/dev/null)
check "updates-lint: leaves no scratch files behind under TMPDIR" test -z "$lhtmp_leftover"
rm -rf "$lhtmp_check_dir"
ulw_clear

rm -rf "$ulw"

# ------------------------------------ connector-safety-routing.check.sh
csrw=${TMPDIR:-/tmp}/lh-csr-test.$$
rm -rf "$csrw"; mkdir -p "$csrw/.claude/scripts" "$csrw/.claude/updates/2026-09-23" || exit 1
cp -R "$scripts"/. "$csrw/.claude/scripts/" 2>/dev/null
cp "$here/../updates/2026-09-23/connector-safety-routing.check.sh" "$csrw/.claude/updates/2026-09-23/"

csr_run() { # settings-file
  cp "$1" "$csrw/.claude/settings.json"
  ( cd "$csrw" && REPO_ROOT="$csrw" sh .claude/updates/2026-09-23/connector-safety-routing.check.sh ) 2>&1
}

out=$(csr_run "$settings"); rc=$?
check "connector-safety-routing: this repo's own settings.json passes" test "$rc" = 0

# Strip all whitespace outside strings, for a compact one-line fixture, and
# re-indent to a few different widths -- content-based judging must not
# care which of these it is handed.
awk '
{ sub(/\r$/, ""); buf = buf $0 "\n" }
END {
  n = length(buf); out = ""; instr = 0; esc = 0
  for (i = 1; i <= n; i++) {
    c = substr(buf, i, 1)
    if (instr) {
      out = out c
      if (esc) esc = 0
      else if (c == "\\") esc = 1
      else if (c == "\"") instr = 0
      continue
    }
    if (c == "\"") { instr = 1; out = out c; continue }
    if (c == " " || c == "\t" || c == "\n" || c == "\r") continue
    out = out c
  }
  printf "%s", out
}' "$settings" > "$csrw/compact.json"
out=$(csr_run "$csrw/compact.json"); rc=$?
check "connector-safety-routing: a compact one-line settings.json passes" test "$rc" = 0

awk '{
  line = $0; n = 0
  while (substr(line, n + 1, 1) == " ") n++
  half = int(n / 2); indent = ""
  for (i = 0; i < half; i++) indent = indent " "
  print indent substr(line, n + 1)
}' "$settings" > "$csrw/2space.json"
out=$(csr_run "$csrw/2space.json"); rc=$?
check "connector-safety-routing: settings.json re-indented to 2 spaces passes" test "$rc" = 0

awk '{
  line = $0; n = 0
  while (substr(line, n + 1, 1) == " ") n++
  extra = n * 2; indent = ""
  for (i = 0; i < extra; i++) indent = indent " "
  print indent substr(line, n + 1)
}' "$settings" > "$csrw/8space.json"
out=$(csr_run "$csrw/8space.json"); rc=$?
check "connector-safety-routing: settings.json re-indented wider (8 spaces) passes" test "$rc" = 0

awk '{ sub(/\r$/, ""); printf "%s\r\n", $0 }' "$settings" > "$csrw/crlf.json"
out=$(csr_run "$csrw/crlf.json"); rc=$?
check "connector-safety-routing: a CRLF settings.json passes" test "$rc" = 0

sed 's/"\^mcp__"/"^mcp__ghl"/' "$settings" > "$csrw/variant-only.json"
out=$(csr_run "$csrw/variant-only.json"); rc=$?
check "connector-safety-routing: only a ^mcp__ variant matcher (never the exact one) fails" test "$rc" != 0

sed 's/mcp-guard\.sh/deny-mcp.sh/' "$settings" > "$csrw/names-deny.json"
out=$(csr_run "$csrw/names-deny.json"); rc=$?
check "connector-safety-routing: a hook command naming deny-mcp.sh fails" test "$rc" != 0

sed 's/mcp-guard\.sh/ask-mcp.sh/' "$settings" > "$csrw/names-ask.json"
out=$(csr_run "$csrw/names-ask.json"); rc=$?
check "connector-safety-routing: a hook command naming ask-mcp.sh fails" test "$rc" != 0

# A minimal, hand-built settings.json with two exact ^mcp__ matchers: valid
# JSON, but the count must still be exactly one.
cat > "$csrw/two-matchers.json" <<'JSONEOF'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "^mcp__",
        "hooks": [
          { "type": "command", "command": "sh \"$CLAUDE_PROJECT_DIR/.claude/scripts/mcp-guard.sh\"" }
        ]
      },
      {
        "matcher": "^mcp__",
        "hooks": [
          { "type": "command", "command": "sh \"$CLAUDE_PROJECT_DIR/.claude/scripts/mcp-guard.sh\"" }
        ]
      }
    ]
  }
}
JSONEOF
out=$(csr_run "$csrw/two-matchers.json"); rc=$?
check "connector-safety-routing: two exact ^mcp__ matchers fails, expects exactly one" test "$rc" != 0

# The matcher is exact, but its own command never runs mcp-guard.sh.
cat > "$csrw/wrong-command.json" <<'JSONEOF'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "^mcp__",
        "hooks": [
          { "type": "command", "command": "sh \"$CLAUDE_PROJECT_DIR/.claude/scripts/some-other-script.sh\"" }
        ]
      }
    ]
  }
}
JSONEOF
out=$(csr_run "$csrw/wrong-command.json"); rc=$?
check "connector-safety-routing: an exact matcher whose own command is not mcp-guard.sh fails" test "$rc" != 0

printf '{ this is not json' > "$csrw/bad.json"
out=$(csr_run "$csrw/bad.json"); rc=$?
check "connector-safety-routing: invalid JSON fails (via json-valid.sh)" test "$rc" != 0

# A decoy top-level key literally named "hooks/PreToolUse/0/matcher" (a
# JSON key whose own string content contains "/") must never be mistaken
# for the real nested path with the same spelling. Here the real
# hooks.PreToolUse array has only a non-exact matcher (no ^mcp__ entry at
# all), so this must fail -- if the flattener let the decoy key's slash
# be read as a path separator, it would spoof both the matcher check and
# (via a second decoy key) the mcp-guard.sh command check too.
cat > "$csrw/spoofed-matcher.json" <<'JSONEOF'
{
  "hooks/PreToolUse/0/matcher": "^mcp__",
  "hooks/PreToolUse/0/hooks/0/command": "sh \"$CLAUDE_PROJECT_DIR/.claude/scripts/mcp-guard.sh\"",
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "^mcp__ghl",
        "hooks": [
          { "type": "command", "command": "sh \"$CLAUDE_PROJECT_DIR/.claude/scripts/some-other-script.sh\"" }
        ]
      }
    ]
  }
}
JSONEOF
out=$(csr_run "$csrw/spoofed-matcher.json"); rc=$?
check "connector-safety-routing: a decoy top-level key spoofing a hook path fails (real PreToolUse lacks the mcp__ entry)" test "$rc" != 0

# Guard against the escaping fix above breaking real nested paths: this
# repo's own settings.json must still pass after it.
out=$(csr_run "$settings"); rc=$?
check "connector-safety-routing: the real settings.json still passes after key-escaping" test "$rc" = 0

rm -rf "$csrw"

# --------------------- settings.json content-only judging: full-suite proof
# json-flat.sh based assertions, here and in state.sh, must never care how
# settings.json is laid out on disk. Proven end to end: the real
# settings.json is re-serialized in a compact one-line form and a
# jq-style "exploded array" form (jq's default 2-space pretty-print
# explodes a short inline array like ["highlevel"] onto three lines,
# which is exactly the shape a literal-line grep on that array could
# never survive), dropped into a full scratch copy of the repo, and
# state.sh itself is run against that copy end to end -- not just the one
# check that already had its own fixtures above.
lh_toplevel_srf=$(git rev-parse --show-toplevel 2>/dev/null)
case $lh_toplevel_srf in
  */launchhouse/update/wt)
    printf 'PASS  settings.json content-only judging: full-suite proof (run in the template before release; skipped inside a founder'"'"'s update)\n'
    ;;
  *)
  srfw=${TMPDIR:-/tmp}/lh-settings-reformat.$$
  rm -rf "$srfw"; mkdir -p "$srfw/repo" || exit 1
  repo_root=$(cd "$here/../.." && pwd)
  # The whole working tree (not just .claude and growth-engine): state.sh's
  # own fixtures read other top-level files too (.gitignore, for one), and a
  # partial copy would abort state.sh on an unrelated missing file rather
  # than prove anything about settings.json.
  ( cd "$repo_root" && tar -cf - --exclude=.git --exclude=./.claude/worktrees . ) | ( cd "$srfw/repo" && tar -xf - ) || exit 1
  ( cd "$srfw/repo" && git init -q && git config user.name t && git config user.email t@e \
      && git add -A && git -c commit.gpgsign=false commit -q -m t ) >/dev/null 2>&1

  # Compact one-line (same whitespace-outside-strings stripper as the
  # connector-safety-routing fixture above).
  awk '
  { sub(/\r$/, ""); buf = buf $0 "\n" }
  END {
    n = length(buf); out = ""; instr = 0; esc = 0
    for (i = 1; i <= n; i++) {
      c = substr(buf, i, 1)
      if (instr) {
        out = out c
        if (esc) esc = 0
        else if (c == "\\") esc = 1
        else if (c == "\"") instr = 0
        continue
      }
      if (c == "\"") { instr = 1; out = out c; continue }
      if (c == " " || c == "\t" || c == "\n" || c == "\r") continue
      out = out c
    }
    printf "%s", out
  }' "$settings" > "$srfw/compact.json"

  # jq-style exploded array: the one short inline array in this file,
  # enabledMcpjsonServers, split across three lines the way jq's or any
  # ordinary pretty-printer's default array layout would.
  awk '
  {
    if (match($0, /^[ 	]*/)) indent = substr($0, RSTART, RLENGTH); else indent = ""
    if ($0 ~ /"enabledMcpjsonServers": \[[^]]*\],?/) {
      trail = ($0 ~ /,$/) ? "," : ""
      print indent "\"enabledMcpjsonServers\": ["
      print indent "  \"highlevel\""
      print indent "]" trail
    } else {
      print
    }
  }' "$settings" > "$srfw/jq-2space-exploded.json"

  for srf_name in compact jq-2space-exploded; do
    cp "$srfw/$srf_name.json" "$srfw/repo/.claude/settings.json"
    srf_out=$( cd "$srfw/repo" && sh .claude/tests/state.sh 2>&1 )
    srf_rc=$?
    srf_fails=$(printf '%s\n' "$srf_out" | grep -c '^FAIL')
    check "state.sh passes in full against a repo whose settings.json is re-serialized ($srf_name)" \
      test "$srf_rc" = 0 -a "$srf_fails" = 0
  done
  ( cd "$srfw/repo" && git checkout -q -- .claude/settings.json ) >/dev/null 2>&1

  # And the same two forms, missing the highlevel entry or the ^mcp__ guard
  # wiring, must still FAIL state.sh -- content-based judging closes the
  # layout hole without opening a "always pass" one.
  sed -E 's/"enabledMcpjsonServers"[[:space:]]*:[[:space:]]*\["highlevel"\]/"enabledMcpjsonServers": []/' "$settings" > "$srfw/no-highlevel.json"
  cp "$srfw/no-highlevel.json" "$srfw/repo/.claude/settings.json"
  srf_out=$( cd "$srfw/repo" && sh .claude/tests/state.sh 2>&1 )
  check "state.sh still fails when the highlevel entry is missing, even reformatted" \
    test "$(printf '%s\n' "$srf_out" | grep -c '^FAIL')" -gt 0

  sed 's/mcp-guard\.sh/deny-mcp.sh/' "$srfw/jq-2space-exploded.json" > "$srfw/jq-2space-no-guard.json"
  cp "$srfw/jq-2space-no-guard.json" "$srfw/repo/.claude/settings.json"
  srf_out=$( cd "$srfw/repo" && sh .claude/tests/state.sh 2>&1 )
  check "state.sh still fails when the guard wiring is swapped for a retired script, even reformatted" \
    test "$(printf '%s\n' "$srf_out" | grep -c '^FAIL')" -gt 0

  rm -rf "$srfw"
    ;;
esac

# --------------------------------------------- updates-checks.sh fixtures
# Exercises .claude/tests/updates-checks.sh (the purpose-based-update check
# runner) against tiny throwaway repos under $TMPDIR, never this repo's own
# tree. A stub linter (a script that just exits 0) stands in for
# .claude/scripts/updates-lint.sh so these fixtures do not depend on the
# real linter existing.
ucw=${TMPDIR:-/tmp}/lh-updates-checks-test.$$
trap 'rm -rf "$work" "$ucw"' EXIT
rm -rf "$ucw"
mkdir -p "$ucw" || exit 1

# Writes a note at .claude/updates/<release>/<id>.md in the throwaway repo.
# safety is "true" or "false"; check is a check-file name or "none".
ucw_note() {
  rel=$1; id=$2; saf=$3; chk=$4
  d="$ucw/repo/.claude/updates/$rel"
  mkdir -p "$d" || exit 1
  {
    printf -- '---\n'
    printf 'id: %s\n' "$id"
    printf 'title: %s\n' "$id"
    printf 'purpose: >\n  test purpose, fixture only\n'
    printf 'touches:\n  - foo.txt\n'
    printf 'adds: []\n'
    printf 'requires: []\n'
    printf 'safety: %s\n' "$saf"
    printf 'done-when:\n  - "it holds"\n'
    printf 'check: %s\n' "$chk"
    printf 'founder-data: false\n'
    printf -- '---\n\n## What changed and why\ntest fixture only\n'
  } > "$d/$id.md"
}
# Clears the throwaway repo back to just a stub linter (exit 0), no notes.
ucw_reset() {
  rm -rf "$ucw/repo"
  mkdir -p "$ucw/repo/.claude/scripts" || exit 1
  printf '#!/bin/sh\nexit 0\n' > "$ucw/repo/.claude/scripts/updates-lint.sh"
}
runuc() { sh "$here/updates-checks.sh" "$ucw/repo" 2>&1; }

# No .claude/updates directory at all: an older founder tree.
ucw_reset
out=$(runuc); rc=$?
check "updates-checks: no updates directory at all prints notes=none" test "$out" = 'notes=none'
check "updates-checks: and exits 0" test "$rc" = 0

# .claude/updates/ exists but holds no notes (only a README): same as none.
mkdir -p "$ucw/repo/.claude/updates/2026-01-01" || exit 1
printf 'Not a note, just documentation.\n' > "$ucw/repo/.claude/updates/2026-01-01/README.md"
out=$(runuc); rc=$?
check "updates-checks: a release folder with only a README still prints notes=none" test "$out" = 'notes=none'
check "updates-checks: and exits 0" test "$rc" = 0

# A safety note whose check exits 0 -> PASS, run exits 0.
ucw_reset
ucw_note 2026-01-01 safety-pass true safety-pass.check.sh
printf '#!/bin/sh\nexit 0\n' > "$ucw/repo/.claude/updates/2026-01-01/safety-pass.check.sh"
out=$(runuc); rc=$?
check "updates-checks: a safety note whose check exits 0 is PASS" has "$out" 'PASS  safety-pass'
check "updates-checks: and the run exits 0" test "$rc" = 0

# A safety note with check: none -> FAIL, fail closed.
ucw_reset
ucw_note 2026-01-01 safety-nocheck true none
out=$(runuc); rc=$?
check "updates-checks: a safety note with check: none is FAIL" has "$out" 'FAIL  safety-nocheck'
check "updates-checks: and the run exits non-zero" test "$rc" != 0

# A safety note whose check file is named but never written -> FAIL.
ucw_reset
ucw_note 2026-01-01 safety-missing true safety-missing.check.sh
out=$(runuc); rc=$?
check "updates-checks: a safety note whose check file is missing is FAIL" has "$out" 'FAIL  safety-missing'
check "updates-checks: and the run exits non-zero" test "$rc" != 0

# A safety note whose check has a shell syntax error -> FAIL, not a crash.
ucw_reset
ucw_note 2026-01-01 safety-syntax true safety-syntax.check.sh
printf 'if [ 1 = 1\n' > "$ucw/repo/.claude/updates/2026-01-01/safety-syntax.check.sh"
out=$(runuc); rc=$?
check "updates-checks: a safety note whose check has a syntax error is FAIL" has "$out" 'FAIL  safety-syntax'
check "updates-checks: and the run exits non-zero" test "$rc" != 0

# A non-safety note with check: none -> PASS (only safety notes fail closed).
ucw_reset
ucw_note 2026-01-01 plain-nocheck false none
out=$(runuc); rc=$?
check "updates-checks: a non-safety note with check: none is PASS" has "$out" 'PASS  plain-nocheck'
check "updates-checks: and the run exits 0" test "$rc" = 0

# A failing check's hint= line survives as the very last line of output,
# so a founder-facing tail -60 always keeps it.
ucw_reset
ucw_note 2026-01-01 with-hint true with-hint.check.sh
printf '#!/bin/sh\necho FAIL something\necho "hint=Do the thing yourself."\nexit 1\n' > "$ucw/repo/.claude/updates/2026-01-01/with-hint.check.sh"
out=$(runuc)
lastline=$(printf '%s\n' "$out" | tail -1)
check "updates-checks: a failing check's hint= line is the very last line of output" test "$lastline" = 'hint=Do the thing yourself.'

# Notes exist but the linter script itself is missing -> FAIL, fail closed.
rm -rf "$ucw/repo"
mkdir -p "$ucw/repo/.claude/updates/2026-01-01" || exit 1
ucw_note 2026-01-01 plain-nolinter false none
out=$(runuc); rc=$?
check "updates-checks: notes with no updates-lint.sh at all is FAIL" has "$out" 'FAIL  updates-lint'
check "updates-checks: and the run exits non-zero" test "$rc" != 0

rm -rf "$ucw"

# ---------------------------------- updates-checks.sh: founder WARN vs FAIL
# A non-safety note's own check is advisory once there is a founder's own
# copy to be advisory about: the same failing check prints WARN and leaves
# the run green in a founder copy, but still FAILs the run in the template
# repo, where the check is the only proof the shipped note actually works.
# lh_layout_check's own founder test needs a real git repo to read, so
# these throwaway repos are git-initialized, unlike the ones above.
wcw=${TMPDIR:-/tmp}/lh-updates-checks-warn-test.$$
rm -rf "$wcw"

wcw_build() { # dir, founder(yes|no), safety(true|false)
  d=$1; f=$2; saf=$3
  rm -rf "$d"
  mkdir -p "$d/.claude/scripts" "$d/.claude/updates/2026-01-01" "$d/growth-engine/.state" || exit 1
  printf '#!/bin/sh\nexit 0\n' > "$d/.claude/scripts/updates-lint.sh"
  {
    printf -- '---\n'
    printf 'id: plain-fails\ntitle: A title\npurpose: A purpose sentence.\n'
    printf 'touches:\n  - foo.txt\n'
    printf 'adds: []\nrequires: []\n'
    printf 'safety: %s\n' "$saf"
    printf 'done-when:\n  - "it holds"\n'
    printf 'check: plain-fails.check.sh\nfounder-data: false\n'
    printf -- '---\n\n## What changed and why\ntest fixture only\n'
  } > "$d/.claude/updates/2026-01-01/plain-fails.md"
  printf '#!/bin/sh\nexit 1\n' > "$d/.claude/updates/2026-01-01/plain-fails.check.sh"
  : > "$d/foo.txt"
  ( cd "$d" && git init -q && git -c user.email=t@e -c user.name=t -c commit.gpgsign=false commit -q --allow-empty -m init ) || exit 1
  if [ "$f" = yes ]; then
    : > "$d/.claude/launchhouse-version"
    ( cd "$d" && git add .claude/launchhouse-version && git -c user.email=t@e -c user.name=t -c commit.gpgsign=false commit -q -m founder ) || exit 1
  fi
}

wcw_build "$wcw/founder" yes false
out=$(sh "$here/updates-checks.sh" "$wcw/founder" 2>&1); rc=$?
check "updates-checks: founder copy, failing non-safety check prints WARN" has "$out" 'WARN  plain-fails'
check "updates-checks: founder copy, the run still exits 0" test "$rc" = 0
check "updates-checks: founder copy, never a FAIL line for that note" hasnt "$out" 'FAIL  plain-fails'

wcw_build "$wcw/template" no false
out=$(sh "$here/updates-checks.sh" "$wcw/template" 2>&1); rc=$?
check "updates-checks: template repo, the same failing non-safety check FAILs" has "$out" 'FAIL  plain-fails'
check "updates-checks: template repo, the run exits non-zero" test "$rc" != 0

wcw_build "$wcw/founder-profile" no false
: > "$wcw/founder-profile/growth-engine/.state/profile.md"
( cd "$wcw/founder-profile" && git add growth-engine/.state/profile.md && git -c user.email=t@e -c user.name=t -c commit.gpgsign=false commit -q -m profile )
out=$(sh "$here/updates-checks.sh" "$wcw/founder-profile" 2>&1); rc=$?
check "updates-checks: founder copy via a tracked profile.md, WARN not FAIL" has "$out" 'WARN  plain-fails'
check "updates-checks: founder copy via a tracked profile.md, run exits 0" test "$rc" = 0

wcw_build "$wcw/founder-safety" yes true
out=$(sh "$here/updates-checks.sh" "$wcw/founder-safety" 2>&1); rc=$?
check "updates-checks: founder copy, a failing SAFETY check still FAILs, never just WARNs" has "$out" 'FAIL  plain-fails'
check "updates-checks: founder copy, the run still exits non-zero for a safety fail" test "$rc" != 0

# The one place this script fails CLOSED rather than open: its own scratch
# file (the note list it feeds the while loop from) lives under
# ${TMPDIR:-/tmp}, never inside .claude/, and a TMPDIR that cannot be
# written to must refuse to run rather than silently see zero notes.
out=$(TMPDIR=/lh-does-not-exist-anywhere sh "$here/updates-checks.sh" "$wcw/template" 2>&1); rc=$?
check "updates-checks: a scratch file that cannot be created fails closed" has "$out" 'could not create a scratch file'
check "updates-checks: and the run exits non-zero" test "$rc" != 0

rm -rf "$wcw"

# -------------------------------------------------------- the update engine
# .claude/scripts/update.sh has its own self-contained suite, since it needs
# throwaway git repos of its own rather than the single fixture $work this
# file builds. Its PASS/FAIL lines and its own pass/fail are folded in here.
#
# Skipped when this run.sh is itself running INSIDE an update's own apply
# worktree (both the old engine, at the public template's 29e42a2, and
# this one put that worktree at the same fixed path,
# <gitdir>/launchhouse/update/wt -- see update.sh's own state_dir() and
# wt="$state/wt"): update-cases.sh is the UPDATER's own self-test, built
# and run against throwaway fixture repos of its own, and it is what the
# template itself runs before a release ships, not something a founder's
# own apply needs to run again against fixtures that have nothing to do
# with their folder. It is roughly half of this whole file's own running
# time, and an apply's own checks already run the rest of this suite
# (including update-cases.sh's real-repo behaviour, exercised indirectly
# by every other case here) against the founder's actual updated tree.
# Detected structurally, from git itself, never from an env var a founder
# or an older updater could leave set by accident: `git rev-parse
# --show-toplevel` inside an apply worktree IS that worktree's own root,
# so it ends in exactly this path.
lh_toplevel=$(git rev-parse --show-toplevel 2>/dev/null)
case $lh_toplevel in
  */launchhouse/update/wt)
    printf 'PASS  updater self-tests (run in the template before release; skipped inside a founder'"'"'s update)\n'
    ;;
  *)
    updateout=$(sh "$here/update-cases.sh" 2>&1)
    updaterc=$?
    printf '%s\n' "$updateout"
    [ "$updaterc" = 0 ] || fail=1
    ;;
esac

# -------------------------------------------------- purpose-based updates
# Runs near the end on purpose: updates-checks.sh prints any failing note's
# hint= line last, and this keeps those lines inside the tail -60 of this
# whole file's output that cmd_apply shows a founder on an abort.
updatescheckout=$(sh "$here/updates-checks.sh" 2>&1)
updatescheckrc=$?
printf '%s\n' "$updatescheckout"
[ "$updatescheckrc" = 0 ] || fail=1

# ----------------------------------------------------------- agents-doc.sh
# Another worker is landing this file separately; once it exists, its own
# checks run here too. Until then this is a no-op.
if [ -f "$here/agents-doc.sh" ]; then sh "$here/agents-doc.sh" || fail=1; fi

if [ "$fail" = 0 ]; then
  printf '\nAll cases passed.\n'
else
  printf '\nSome cases failed.\n'
fi

# The settings-wiring hint is printed last of all, after the pass/fail
# summary line above -- a founder only ever sees the tail -60 of this
# file's output, and this is the one line that tells them exactly what to
# do about a customised settings.json that still names a retired script.
if [ "$settings_wiring_failed" = 1 ]; then
  printf 'hint=Your settings file still points at safety scripts that no longer exist. Choose "take the update" for .claude/settings.json; your own copy is kept safe and your changes are brought back on the next update.\n'
fi

exit $fail
