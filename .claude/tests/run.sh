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
  "$work/growth-engine/uploads" "$work/growth-engine/voice-samples" "$work/src" || exit 1
cp -R "$scripts" "$work/.claude/" || exit 1
: > "$work/growth-engine/.launchhouse"
printf '# Founder Brain\n\n- **Track:** b2c\n\n## Thesis\nSmall batch bakery.\n' > "$work/growth-engine/founder-brain.md"
cold='Use a bot to DM every new follower with the offer.'
ge="$work/growth-engine"

hook() { # script, tool, key, value (the value is put into the JSON as it is)
  printf '{"tool_name":"%s","tool_input":{"%s":"%s"}}' "$2" "$3" "$4" |
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
out=$(write uploads/plan.md "$cold")
check "a cold DM offer written to uploads/ is raised with Claude" has "$out" 'already there, or were copied in'
check "and the upload is not removed" test -f "$ge/uploads/plan.md"
out=$(write voice-samples/promise.md 'Replies are guaranteed within a week.')
check "a promised reply written to voice-samples/ is raised, not held" has "$out" 'DM\|repl'
check "and the voice sample is kept" test -f "$ge/voice-samples/promise.md"
printf 'We promise a reply to every customer email within one business day.\n' > "$work/src/policies.md"
out=$(shell "cp src/policies.md growth-engine/uploads/policies.md" cp "$work/src/policies.md" "$ge/uploads/policies.md")
check "a founder upload with a promise, copied in by shell, is not held" hasnt "$out" 'HELD'
check "and it stays on disk" test -f "$ge/uploads/policies.md"
printf 'We guarantee you a reply within 24 hours.\n' > "$work/src/newsletter.md"
out=$(shell "cp src/newsletter.md growth-engine/voice-samples/newsletter.md" cp "$work/src/newsletter.md" "$ge/voice-samples/newsletter.md")
check "a voice sample with a reply promise, copied in by shell, is kept" test -f "$ge/voice-samples/newsletter.md"
check "and Claude is told to leave it to the founder" has "$out" 'leave the choice to them'
out=$(write voice-samples/post.md 'Come and find me on LinkedIn. We never touch Apollo. It is a game changer.')
check "the founder's own writing in voice-samples/ is not held for track words or style" hasnt "$out" 'HELD'
check "and it stays saved" test -f "$ge/voice-samples/post.md"

# LH-029: a shell copy is checked like a write.
printf '%s\n' "$cold" > "$work/src/offer.md"
printf 'Bake on Sunday, post on Monday.\n' > "$work/src/plan.md"
out=$(shell "cp src/offer.md growth-engine/drafts/offer.md" cp "$work/src/offer.md" "$ge/drafts/offer.md")
check "a new file with a cold DM offer copied in with cp is not deleted" test -f "$ge/drafts/offer.md"
check "and Claude is told, for the founder to decide" has "$out" 'already there, or were copied in'
mkdir -p "$work/.lh-import/growth-engine"
printf '# Hooks\n\n%s\n' "$cold" > "$work/.lh-import/growth-engine/hook-bank.md"
out=$(shell "cp -R .lh-import/growth-engine/. growth-engine/" cp "$work/.lh-import/growth-engine/hook-bank.md" "$ge/hook-bank.md")
check "an imported piece with a held line stays on disk" test -f "$ge/hook-bank.md"
check "and it is reported, not removed" hasnt "$out" 'HELD'
rm -f "$ge/hook-bank.md" "$ge/drafts/offer.md"
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
for t in mcp__leadconnector__execute_operation mcp__286d__create_draft mcp__x__socialmediaposting_create-post; do
  check "the ask check is wired to $t" sh -c 'printf "%s" "$1" | grep -Eq "^($2)"' _ "$t" "$matcher"
  out=$(hook ask-mcp.sh "$t" x y)
  check "$t asks the founder first" has "$out" '"ask"'
done
out=$(hook ask-mcp.sh mcp__leadconnector__list_locations x y)
check "list_locations, a read, does not ask" test -z "$out"

# LH-023: the printable insert is an allowed, checked file.
out=$(hook guard-pre.sh Write file_path "$ge/playbook-insert.html")
check "writing playbook-insert.html is allowed" hasnt "$out" '"deny"'
out=$(write playbook-insert.html "<p>$cold</p>")
check "and it is checked" has "$out" 'HELD'

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

if [ "$fail" = 0 ]; then
  printf '\nAll cases passed.\n'
else
  printf '\nSome cases failed.\n'
fi
exit $fail
