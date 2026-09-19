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

# LH-029: every Apollo tool asks first unless it only reads.
matcher=$(sed -n 's/.*"matcher": "\(mcp__[^"]*apollo_\.\*|[^"]*\)".*/\1/p' "$settings")
for t in apollo_agent_manage_billing apollo_website_visitor_domain_tracker_send_install_email apollo_labels_create; do
  check "the ask check is wired to $t" sh -c '[ -n "$2" ] && printf "%s" "mcp__x__$1" | grep -Eq "^($2)\$"' _ "$t" "$matcher"
  out=$(hook ask-mcp.sh "mcp__x__$t" x y)
  check "$t asks the founder first" has "$out" '"ask"'
done
out=$(hook ask-mcp.sh mcp__x__apollo_contacts_search x y)
check "apollo_contacts_search, a read, does not ask" test -z "$out"
out=$(hook deny-mcp.sh mcp__x__apollo_emailer_messages_send_now x y)
check "apollo_emailer_messages_send_now is still refused" has "$out" '"deny"'
out=$(hook deny-mcp.sh mcp__x__apollo_email_account_purchase_create x y)
check "apollo_email_account_purchase_create is still refused" has "$out" '"deny"'

# LH-025 and LH-026: GoHighLevel's general tool asks, and the mailbox never sends.
deny=$(sed -n 's/.*"matcher": "\(mcp__[^"]*apollo_emailer_messages_send_now[^"]*\)".*/\1/p' "$settings")
for t in mcp__286d__send_message mcp__plugin_small-business_gmail__reply mcp__x__forward; do
  check "the refusal is wired to $t" sh -c 'printf "%s" "$1" | grep -Eq "^($2)"' _ "$t" "$deny"
  out=$(hook deny-mcp.sh "$t" x y)
  check "$t is refused" has "$out" '"deny"'
done
out=$(hook deny-mcp.sh mcp__286d__create_draft x y)
check "create_draft is not refused" test -z "$out"
for t in mcp__286d__create_draft mcp__x__socialmediaposting_create-post; do
  check "the ask check is wired to $t" sh -c 'printf "%s" "$1" | grep -Eq "^($2)"' _ "$t" "$matcher"
  out=$(hook ask-mcp.sh "$t" x y)
  check "$t asks the founder first" has "$out" '"ask"'
done
out=$(hook ask-mcp.sh mcp__leadconnector__list_locations x y)
check "list_locations, a read, does not ask" test -z "$out"
out=$(hook ask-mcp.sh mcp__leadconnector__execute_operation x y)
check "execute_operation no longer asks through ask-mcp.sh, it goes to ghl-op.sh instead" test -z "$out"

# LH-034: mcp__.*__execute_operation, __fetch and __search go to ghl-op.sh, not
# ask-mcp.sh, because one execute_operation call can do anything from reading
# a location to refunding a payment, so the whole input has to be read, not
# just the tool name. The PreToolUse entry for it is its own matcher.
ghlmatcher=$(sed -n 's/.*"matcher": "\([^"]*execute_operation[^"]*\)".*/\1/p' "$settings")
check "ghl-op.sh has its own PreToolUse matcher in settings.json" test -n "$ghlmatcher"
for t in mcp__highlevel__execute_operation mcp__leadconnector-abc123__execute_operation mcp__gdrive__fetch mcp__notion__search; do
  check "$t is routed to ghl-op.sh" sh -c 'printf "%s" "$1" | grep -Eq "^($2)$"' _ "$t" "$ghlmatcher"
  check "and not to ask-mcp.sh's matcher" sh -c '[ -z "$2" ] || ! printf "%s" "$1" | grep -Eq "^($2)$"' _ "$t" "$matcher"
done
check "list_locations is not one of ghl-op.sh's matched tool names" sh -c '! printf "%s" "mcp__highlevel__list_locations" | grep -Eq "^($1)$"' _ "$ghlmatcher"

# LH-043: the matcher is anchored both ends, so it only ever catches
# GoHighLevel's own tool names, never a Drive/Notion/Gmail tool whose name
# happens to contain "search" or "fetch" as a substring, or end in a
# hyphenated variant like notion-search.
for t in mcp__1b3d__execute_operation mcp__1b3d__execute_operation_batch mcp__highlevel__fetch mcp__highlevel__search; do
  check "$t matches the anchored ghl-op.sh matcher" sh -c 'printf "%s" "$1" | grep -Eq "^($2)$"' _ "$t" "$ghlmatcher"
done
for t in mcp__39f8__search_files mcp__drive__search_files mcp__notion__notion-search mcp__notion__notion-fetch \
         mcp__286d__search_threads mcp__x__search_operations mcp__x__describe_operation mcp__x__list_locations mcp__x__fetch_page; do
  check "$t does not match the anchored ghl-op.sh matcher" sh -c '! printf "%s" "$1" | grep -Eq "^($2)$"' _ "$t" "$ghlmatcher"
done

# LH-043: ghl-op.sh's own default branch is a backstop, so even if a tool
# name like this were ever routed to it directly, it exits clean, no ask
# and no deny.
out=$(hookraw ghl-op.sh mcp__39f8__search_files '{"query":"invoice"}')
check "an unrecognised tool name like search_files reaches ghl-op.sh's default branch and gives no output at all" test -z "$out"

# ghl-op.sh: classifies the whole input, refuse beats write beats read beats
# ask, and it never allows on doubt. Three or more input shapes: a flat
# operationId string, a nested {"operation":{"id":...}}, a method-and-path
# shape, and camelCase operation names.
ghlop() { hookraw ghl-op.sh "$1" "$2" "$3"; } # tool_name, json-tool-input-literal, [style]
ghlask() { n=$1; shift; out=$(ghlop "$@"); check "$n" has "$out" '"ask"'; }
ghldeny() { n=$1; shift; out=$(ghlop "$@"); check "$n" has "$out" '"deny"'; }
ghlallow() { n=$1; shift; out=$(ghlop "$@"); check "$n" test -z "$out"; }

# Deny: payments, deletes, workflow changes, refunds, phone numbers, users,
# api keys, webhooks, snapshots, and the nested delete-contact shape.
ghldeny "payments list orders is refused" mcp__highlevel__execute_operation '{"operationId":"payments_list-orders"}'
ghldeny "contacts delete-contact is refused" mcp__highlevel__execute_operation '{"operationId":"contacts_delete-contact"}'
ghldeny "the nested operation.id delete-contact shape is refused the same way" mcp__highlevel__execute_operation '{"operation":{"id":"contacts_delete-contact"}}'
ghldeny "adding a contact to a workflow is refused" mcp__highlevel__execute_operation '{"operationId":"workflows_add-contact-to-workflow"}'
ghldeny "a refund is refused" mcp__highlevel__execute_operation '{"operationId":"payments_refund-transaction"}'
ghldeny "buying a phone number is refused" mcp__highlevel__execute_operation '{"operation":"phone-number.purchase"}'
ghldeny "a users operation is refused" mcp__highlevel__execute_operation '{"operationId":"users_get-user"}'
ghldeny "an api key operation is refused" mcp__highlevel__execute_operation '{"operationId":"generate_api_key"}'
ghldeny "a webhooks operation is refused" mcp__highlevel__execute_operation '{"operationId":"webhooks_create-webhook"}'
ghldeny "a snapshot operation is refused" mcp__highlevel__execute_operation '{"operationId":"snapshots_share-snapshot"}'
ghldeny "an explicit DELETE method is refused, not just asked" mcp__highlevel__execute_operation '{"method":"DELETE","path":"/contacts/123"}'

# Ask: writes of every kind, method+path and camelCase shapes included.
ghlask "creating a post asks" mcp__highlevel__execute_operation '{"operationId":"social-media-posting_create-post"}'
ghlask "editing a post asks" mcp__highlevel__execute_operation '{"operationId":"social-media-posting_edit-post"}'
ghlask "sendMessage in camelCase asks" mcp__highlevel__execute_operation '{"operation":"conversations.sendMessage"}'
ghlask "updating a custom value asks" mcp__highlevel__execute_operation '{"operationId":"locations_update-custom-value"}'
ghlask "adding a tag asks" mcp__highlevel__execute_operation '{"operationId":"contacts_add-tag"}'
ghlask "a POST method with a GET-looking name still asks" mcp__highlevel__execute_operation '{"method":"POST","operation":"get-contact-details"}'
ghlask "a GET method with a send-ish name still asks, the write verb wins" mcp__highlevel__execute_operation '{"method":"GET","operation":"send-message-status"}'
ghlask "an unrecognised operation asks, never allows on doubt" mcp__highlevel__execute_operation '{"operationId":"something_nobody_has_seen_before"}'
ghlask "empty input asks" mcp__highlevel__execute_operation '{}'
ghlask "fetch with a HighLevel op id and a write verb asks" mcp__highlevel__fetch '{"locationId":"LOC123","operation":"update-contact"}'

# Allow, silently: clear reads, no output at all.
ghlallow "getting a location is allowed" mcp__highlevel__execute_operation '{"operationId":"locations_get-location"}'
ghlallow "listing social accounts is allowed" mcp__highlevel__execute_operation '{"operationId":"social-media-posting_get-accounts"}'
ghlallow "getting posts is allowed, post alone is neutral" mcp__highlevel__execute_operation '{"operationId":"social-media-posting_get-posts"}'
ghlallow "post statistics is allowed, post alone is neutral" mcp__highlevel__execute_operation '{"operationId":"social-media-posting_get-post-statistics"}'
ghlallow "searching contacts with a GET method is allowed" mcp__leadconnector__execute_operation '{"method":"GET","operationId":"contacts_search"}'

# fetch and search: judged only when the input looks GoHighLevel-shaped.
out=$(ghlop mcp__gdrive__fetch '{"id":"1a2b3c4d","name":"quarterly-report.pdf"}')
check "fetch with a Google-Drive-shaped input gives no output at all" test -z "$out"
check "and it is not an ask" hasnt "$out" '"ask"'
check "and it is not a deny" hasnt "$out" '"deny"'

# Malformed JSON never crashes, never allows, and its own output is always
# valid JSON when it prints anything at all. A realistic envelope around it,
# broken only inside tool_input.
out=$(printf '{"session_id":"abc","transcript_path":"/Users/jo/.claude/projects/x.jsonl","cwd":"/Users/jo/launchhouse","permission_mode":"acceptEdits","hook_event_name":"PreToolUse","tool_name":"mcp__highlevel__execute_operation","tool_input":{not json at all' |
  CLAUDE_PROJECT_DIR="$work" sh "$work/.claude/scripts/ghl-op.sh" 2>/dev/null)
check "malformed JSON asks rather than crashing" has "$out" '"ask"'
check "and it is never allowed through" hasnt "$out" '"deny"'

# LH-042: classification reads only tool_input, never the envelope around
# it, and within tool_input only the operation descriptor, never a payload
# field a founder's own words could land in.
ghlallow "a clean read is allowed even though the envelope's own cwd and transcript_path say /Users/jo, which used to trip the 'users' refuse word" \
  mcp__1b3d__execute_operation '{"operationId":"locations_get-location"}'
ghlask "a create-post whose body.summary happens to contain refuse-list words in the founder's own copy still only asks, never denies" \
  mcp__highlevel__execute_operation '{"operationId":"social-media-posting_create-post","body":{"summary":"Order your cake today, prices from 20"}}'
ghlask "a create-post body/text with delete, cancel your order and users love it in the payload still only asks" \
  mcp__highlevel__execute_operation '{"operationId":"social-media-posting_create-post","body":{"text":"delete. cancel your order. users love it."}}'
ghlask "a send-message body/text mentioning refund in the founder's own words still only asks" \
  mcp__highlevel__execute_operation '{"operation":"conversations.sendMessage","body":{"text":"sorry about the refund delay, it is on its way"}}' win
ghldeny "payments in the operation id itself, not the payload, is still refused" \
  mcp__highlevel__execute_operation '{"operationId":"payments_list-orders","body":{}}' win
ghldeny "a nested descriptor is still found and refused, and the word get inside body.note never flips it to allow" \
  mcp__highlevel__execute_operation '{"request":{"operationId":"contacts_delete-contact","body":{"note":"get"}}}'
ghlask "tool_input with every leaf under body and nothing outside it is an empty descriptor, so it only asks" \
  mcp__highlevel__execute_operation '{"body":{"x":"get"}}'

# A large junk operation name, still valid JSON: must not crash, and must
# still come out safe (ask, on a name nothing can classify).
junk=$(awk 'BEGIN { for (i = 0; i < 20000; i++) printf "x" }')
out=$(hookraw ghl-op.sh mcp__highlevel__execute_operation "{\"operationId\":\"$junk\"}")
check "a 20KB junk operation name comes back, so the hook did not hang or crash" test -n "$out"
check "and it classifies safely, asking rather than guessing" has "$out" '"ask"'

# ghl-op.sh: the descriptor is an allowlist of structural fields, not a
# blacklist of payload container keys. Five confirmed bugs the blacklist let
# through or got wrong, and the new refuse/write words and rules that fix
# them.
ghldeny "a users operation, getUser, is refused, singular now included" mcp__highlevel__execute_operation '{"operationId":"getUser"}'
ghlask "markConversationAsRead is a write (mark), not a read just because read is in its name" mcp__highlevel__execute_operation '{"operationId":"markConversationAsRead"}'
ghldeny "listAPIKeys is refused, refuse beats the read-looking list" mcp__highlevel__execute_operation '{"operationId":"listAPIKeys"}'
ghlask "createPost with cancel-my-subscription in its own payload field only asks, never denies on leaked payload text" \
  mcp__highlevel__execute_operation '{"operationId":"createPost","post":"Please cancel my subscription"}'
ghldeny "a fetch with a bare DELETE method and path is refused, not silently allowed" mcp__highlevel__fetch '{"method":"DELETE","path":"/contacts/123"}'
ghldeny "trashContact is refused, trash is a new refuse word" mcp__highlevel__execute_operation '{"operationId":"trashContact"}'
ghldeny "createCharge is refused, charge is a new refuse word" mcp__highlevel__execute_operation '{"operationId":"createCharge"}'
ghldeny "activateWorkflow is refused outright, not just asked" mcp__highlevel__execute_operation '{"operationId":"activateWorkflow"}'
ghlallow "getWorkflows is still a clear read and is allowed, workflow alone does not refuse a read" mcp__highlevel__execute_operation '{"operationId":"getWorkflows"}'

out=$(hookraw ghl-op.sh mcp__highlevel__execute_operation '"getContacts"')
check "a scalar tool_input (a bare JSON string, not an object) asks" has "$out" '"ask"'
check "and never allows" hasnt "$out" '"deny"'

out=$(printf '{"session_id":"abc","transcript_path":"/Users/jo/.claude/projects/x.jsonl","cwd":"/Users/jo/launchhouse","permission_mode":"acceptEdits","hook_event_name":"PreToolUse","tool_name":"mcp__highlevel__execute_operation","tool_input":{"operationId":"getUser"}}GARBAGE' |
  CLAUDE_PROJECT_DIR="$work" sh "$work/.claude/scripts/ghl-op.sh" 2>/dev/null)
check "garbage trailing after the envelope's own JSON closes asks, rather than trusting the tool_input found before it" has "$out" '"ask"'
check "and never denies" hasnt "$out" '"deny"'

check "getHTTPMethod flattens the acronym boundary apart from the titlecase word after it" \
  sh -c '. "$1/.claude/scripts/lib.sh"; [ "$(lh_ghl_flatten getHTTPMethod)" = "get http method" ]' _ "$work"
ghlallow "getHTTPMethod is a clear read once flattened, get is a read word and nothing else fires" mcp__highlevel__execute_operation '{"operationId":"getHTTPMethod"}'

ghlallow "a method field buried inside body, not a structural field at all, is ignored for classification: without this a DELETE hiding in there would wrongly refuse a plain read" \
  mcp__highlevel__execute_operation '{"operationId":"getContact","body":{"method":"DELETE"}}'
ghlask "a method-shaped word inside an excluded payload leaf's own value never leaks in either" \
  mcp__highlevel__execute_operation '{"operationId":"createPost","body":{"note":"method: POST please, right away"}}'

out=$(ghlop mcp__gdrive__fetch '{"id":"doc123"}')
check "a Google-Drive-style fetch of a bare id, no method/path/operation shape and no HighLevel markers, gives no output at all" test -z "$out"

# LH-025: the tools on the shipped HighLevel connection that change a contact,
# which can start a workflow that sends, or post a blog, ask first. Mail rules
# are refused.
for t in mcp__highlevel__contacts_add-tags mcp__highlevel__contacts_create-contact mcp__highlevel__contacts_upsert-contact \
         mcp__highlevel__contacts_update-contact mcp__highlevel__opportunities_update-opportunity \
         mcp__highlevel__blogs_create-blog-post mcp__highlevel__blogs_update-blog-post mcp__highlevel__socialmediaposting_create-post; do
  check "the ask check is wired to $t" sh -c 'printf "%s" "$1" | grep -Eq "^($2)"' _ "$t" "$matcher"
  out=$(hook ask-mcp.sh "$t" x y)
  check "$t asks the founder first" has "$out" '"ask"'
done
for t in mcp__highlevel__contacts_get-contacts mcp__highlevel__locations_get-location mcp__highlevel__conversations_get-messages; do
  out=$(hook ask-mcp.sh "$t" x y)
  check "$t, a read, does not ask" test -z "$out"
done
check "the refusal is wired to create_filter" sh -c 'printf "%s" "$1" | grep -Eq "^($2)"' _ mcp__286d__create_filter "$deny"
out=$(hook deny-mcp.sh mcp__286d__create_filter x y)
check "a mailbox rule is refused" has "$out" '"deny"'
out=$(hook deny-mcp.sh mcp__claude_ai_Microsoft_365__outlook_email_search x y)
check "outlook_email_search, a read, is not refused" test -z "$out"
out=$(hook ask-mcp.sh mcp__claude_ai_Microsoft_365__outlook_email_search x y)
check "and does not ask" test -z "$out"

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
