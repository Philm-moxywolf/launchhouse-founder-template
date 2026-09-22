#!/bin/sh
# Exercises .claude/scripts/update.sh (the Launchhouse update engine) against
# a made-up upstream and a made-up founder copy, both throwaway git repos
# built under $TMPDIR, never the real repository.
#
# Standalone: this file defines its own check/has/hasnt/match_eq helpers and
# prints PASS/FAIL lines in the same style as .claude/tests/run.sh, which
# calls this file (sh .claude/tests/update-cases.sh) and folds its result and
# its PASS/FAIL lines into its own overall pass/fail. It can also be run on
# its own:
#   sh .claude/tests/update-cases.sh
#
# update.sh no longer has a test-only override for the checks it runs after
# an apply (there is no LH_UPDATE_CHECK_CMD any more): it always runs
# whatever checks actually exist in the updated tree. So instead of mocking
# the check command, the cases below place a real, throwaway
# .claude/tests/run.sh stub (one that exits 0 or 1) in the fake founder
# repo, and let update.sh discover and run it for real, the same way it
# would discover the founder's own real .claude/tests/run.sh.
#
# An optional real-history case, against a clone of the actual public
# Launchhouse template repository, runs only when LH_UPDATE_REAL=1 is set:
# it needs network access and takes much longer than the rest of this file.

here=$(cd "$(dirname "$0")" && pwd)
scripts=$(cd "$here/../scripts" && pwd)
fail=0

check() { # name, then a test
  n=$1; shift
  if "$@"; then printf 'PASS  %s\n' "$n"; else printf 'FAIL  %s\n' "$n"; fail=1; fi
}
has() { printf '%s' "$1" | grep -q "$2"; }
hasnt() { ! printf '%s' "$1" | grep -q "$2"; }
match_eq() { [ "$1" = "$2" ]; }
cksum_of() { cksum "$1" 2>/dev/null | awk '{print $1, $2}'; }

# -------------------------------------------------------- the update engine
# The founder copy is made "Use this template"-style: a fresh git init, the
# files from the upstream's first commit, one commit, no shared history.

luwork=${TMPDIR:-/tmp}/lh-update-test.$$
trap 'rm -rf "$luwork"' EXIT
luup="$luwork/upstream"
lufounder="$luwork/founder"
mkdir -p "$luup" "$lufounder" || exit 1

( cd "$luup" && git init -q && git config user.name Up && git config user.email up@example.com )

luwrite() { # relative path, content
  mkdir -p "$luup/$(dirname "$1")"
  printf '%s\n' "$2" > "$luup/$1"
}

# --- commit 1: the version the founder's copy starts from
# .claude/launchhouse-upstream records this fake local upstream as the
# canonical address, since update.sh now refuses to fetch from any
# "upstream" remote that does not match it (or the real public URL, for a
# copy with no such file). Every founder-copy fixture below archives from
# this commit, so it inherits the same recorded canonical address that its
# own "upstream" remote is also pointed at.
luwrite .claude/launchhouse-upstream "$luup"
luwrite .claude/take-me.md "take v1"
luwrite .claude/keep-me.md "keep v1"
luwrite .claude/merge-me.md "a
b
c"
luwrite .claude/conflict-me.md "conflict v1"
luwrite .claude/delete-me.md "delete v1"
luwrite .claude/gone-upstream-kept.md "kept v1"
luwrite .claude/skill-packs/registry.tsv "id	name	kind	suffix_regex	tracks	origin"
luwrite .launchhouse-update-ignore "docs/"
luwrite docs/ignored.md "ignored v1"
luwrite growth-engine/founder-work.md "should never move"
( cd "$luup" && git add -A && git commit -q -m commit1 )
lubase=$( cd "$luup" && git rev-parse HEAD )

# --- commit 2: upstream's own further changes
luwrite .claude/take-me.md "take v2"
luwrite .claude/merge-me.md "a
b
c-upstream"
luwrite .claude/conflict-me.md "conflict v2-upstream"
rm -f "$luup/.claude/delete-me.md"
rm -f "$luup/.claude/gone-upstream-kept.md"
luwrite .claude/addme-upstream.md "brand new upstream file"
luwrite .claude/addconflict.md "upstream add-conflict"
luwrite docs/ignored.md "ignored v2, never seen"
luwrite growth-engine/founder-work.md "still should never move"
( cd "$luup" && git add -A && git commit -q -m commit2 )
luhead=$( cd "$luup" && git rev-parse HEAD )

# --- the founder's copy: template-style, unrelated history, from commit1.
# The scripts under test, plus a check stub, go in as a SEPARATE, second
# commit, so the root commit's .claude tree is byte-for-byte what commit1
# actually had -- which is what --detect-base's exact match compares
# against.
( cd "$luup" && git archive "$lubase" ) | ( cd "$lufounder" && tar -x )
(
  cd "$lufounder" && git init -q && git config user.name Founder && git config user.email f@example.com &&
  git add -A && git commit -q -m "Initial import from template" &&
  git remote add upstream "$luup"
)
mkdir -p "$lufounder/.claude/scripts" "$lufounder/.claude/tests"
cp "$scripts/update.sh" "$scripts/lib.sh" "$scripts/skill-packs.sh" "$lufounder/.claude/scripts/"
chmod +x "$lufounder/.claude/scripts/update.sh" "$lufounder/.claude/scripts/skill-packs.sh"
printf '#!/bin/sh\nexit 0\n' > "$lufounder/.claude/tests/run.sh"
chmod +x "$lufounder/.claude/tests/run.sh"
( cd "$lufounder" && git add -A && git commit -q -m "add the update engine under test, and a passing check stub" )

lufwrite() { # relative path, content
  mkdir -p "$lufounder/$(dirname "$1")"
  printf '%s\n' "$2" > "$lufounder/$1"
}
lufwrite .claude/merge-me.md "a-founder
b
c"
lufwrite .claude/conflict-me.md "conflict v2-founder"
lufwrite .claude/keep-me.md "keep v2-founder"
lufwrite .claude/gone-upstream-kept.md "kept v2-founder"
lufwrite .claude/addconflict.md "founder add-conflict"
lufwrite .claude/local-only.md "only the founder has this"
lufwrite growth-engine/founder-work.md "the founder's own business, never touched"
( cd "$lufounder" && git add -A && git commit -q -m "founder edits" )

lu() { ( cd "$lufounder" && sh .claude/scripts/update.sh "$@" < /dev/null ) 2>&1; }

# detect-base: exact, since this is a template-style copy of commit1
dbout=$(lu --detect-base)
check "detect-base finds the exact commit a template copy started from" has "$dbout" "exact $lubase"

lu --set-base "$lubase" >/dev/null
# set-base only writes the file; committing it is on whoever calls it (the
# launchhouse-update skill, via save), same as it would be for real.
( cd "$lufounder" && git add -A && git commit -q -m "record the base version" )

planout=$(lu --plan)
plantsv="$lufounder/.git/launchhouse/update/plan.tsv"
row() { grep -F "$(printf '%s\t' "$1")" "$plantsv"; }
check "plan: take-me.md is a plain take" has "$(row .claude/take-me.md)" 'take'
check "plan: keep-me.md is a plain keep" has "$(row .claude/keep-me.md)" 'keep'
check "plan: merge-me.md merges cleanly" has "$(row .claude/merge-me.md)" 'merged-clean'
check "plan: conflict-me.md is a real conflict" has "$(row .claude/conflict-me.md)" 'conflict'
check "plan: addme-upstream.md is a plain add" has "$(row .claude/addme-upstream.md)" 'add'
check "plan: addconflict.md is an add-conflict" has "$(row .claude/addconflict.md)" 'add-conflict'
check "plan: delete-me.md is a delete" has "$(row .claude/delete-me.md)" 'delete'
check "plan: gone-upstream-kept.md is deleted-upstream-kept" has "$(row .claude/gone-upstream-kept.md)" 'deleted-upstream-kept'
check "plan.tsv never lists an ignored path" hasnt "$(cat "$plantsv" 2>/dev/null)" 'docs/ignored.md'
check "plan.tsv never lists a growth-engine path" hasnt "$(cat "$plantsv" 2>/dev/null)" 'growth-engine/'
check "plan.tsv never lists a local-only file" hasnt "$(cat "$plantsv" 2>/dev/null)" 'local-only.md'

ge_before=$(cksum_of "$lufounder/growth-engine/founder-work.md")
lo_before=$(cksum_of "$lufounder/.claude/local-only.md")

cat > "$luwork/decisions.tsv" <<EOF
.claude/take-me.md	apply
.claude/keep-me.md	apply
.claude/merge-me.md	apply
.claude/conflict-me.md	hold
.claude/addme-upstream.md	apply
.claude/addconflict.md	keep-mine
.claude/delete-me.md	apply
.claude/gone-upstream-kept.md	hold
EOF

# --- a failing check chain aborts cleanly and leaves the repo untouched.
# Run this BEFORE the real apply below: --apply always tags HEAD first, and
# --undo always picks the newest such tag, so a failed attempt's tag must
# never end up newer than the one the successful apply leaves behind. The
# founder's own check stub is swapped to a failing one for this case, then
# swapped back before the real apply. Each stub swap is its own commit, so
# the plan is re-taken right after it (the plan now records the HEAD it was
# taken against, and --apply refuses a plan taken against an earlier HEAD).
printf '#!/bin/sh\nexit 1\n' > "$lufounder/.claude/tests/run.sh"
( cd "$lufounder" && git add -A && git commit -q -m "founder breaks the check stub, for the failing-checks case" )
lu --plan >/dev/null
pre_head=$( cd "$lufounder" && git rev-parse HEAD )
pre_status=$( cd "$lufounder" && git status --porcelain )
pretags=$( cd "$lufounder" && git tag -l 'launchhouse-pre-update-*' | wc -l | tr -d ' ' )
failout=$( ( cd "$lufounder" && sh .claude/scripts/update.sh --apply "$luwork/decisions.tsv" < /dev/null ) 2>&1 )
check "a failing check chain reports aborted" has "$failout" 'result=aborted'
check "a failing check chain says the repo is unchanged" has "$failout" 'unchanged=yes'
post_head=$( cd "$lufounder" && git rev-parse HEAD )
post_status=$( cd "$lufounder" && git status --porcelain )
check "a failing check chain never moves HEAD" match_eq "$post_head" "$pre_head"
check "a failing check chain never leaves the working tree dirty" match_eq "$post_status" "$pre_status"
posttags=$( cd "$lufounder" && git tag -l 'launchhouse-pre-update-*' | wc -l | tr -d ' ' )
check "a failed apply leaves no pre-update tag behind" match_eq "$posttags" "$pretags"

printf '#!/bin/sh\nexit 0\n' > "$lufounder/.claude/tests/run.sh"
( cd "$lufounder" && git add -A && git commit -q -m "founder fixes the check stub" )
lu --plan >/dev/null

applyout=$( ( cd "$lufounder" && sh .claude/scripts/update.sh --apply "$luwork/decisions.tsv" < /dev/null ) 2>&1 )
check "apply reports success" has "$applyout" 'result=applied'
check "apply: take-me.md now reads the upstream version" has "$(cat "$lufounder/.claude/take-me.md" 2>/dev/null)" 'take v2'
check "apply: keep-me.md keeps the founder's own words" has "$(cat "$lufounder/.claude/keep-me.md" 2>/dev/null)" 'keep v2-founder'
check "apply: merge-me.md carries both sides' edits" has "$(cat "$lufounder/.claude/merge-me.md" 2>/dev/null)" 'a-founder'
check "apply: merge-me.md carries both sides' edits (upstream's too)" has "$(cat "$lufounder/.claude/merge-me.md" 2>/dev/null)" 'c-upstream'
check "apply: a held conflict leaves the founder's file exactly as it was" has "$(cat "$lufounder/.claude/conflict-me.md" 2>/dev/null)" 'conflict v2-founder'
check "apply: addme-upstream.md was added" has "$(cat "$lufounder/.claude/addme-upstream.md" 2>/dev/null)" 'brand new upstream file'
check "apply: keep-mine on an add-conflict keeps the founder's file" has "$(cat "$lufounder/.claude/addconflict.md" 2>/dev/null)" 'founder add-conflict'
check "apply: delete-me.md is gone" hasnt "$(ls "$lufounder/.claude" 2>/dev/null)" 'delete-me.md'
check "apply: a held deleted-upstream-kept file survives" has "$(cat "$lufounder/.claude/gone-upstream-kept.md" 2>/dev/null)" 'kept v2-founder'
check "apply: growth-engine/ is byte-identical after" match_eq "$(cksum_of "$lufounder/growth-engine/founder-work.md")" "$ge_before"
check "apply: the founder's local-only file is byte-identical after" match_eq "$(cksum_of "$lufounder/.claude/local-only.md")" "$lo_before"
check "apply: launchhouse-version now records the new upstream head" has "$(cat "$lufounder/.claude/launchhouse-version" 2>/dev/null)" "$luhead"
check "apply: checks actually ran (not checks=none)" hasnt "$applyout" 'checks=none'

replanout=$(lu --plan)
replantsv=$(cat "$plantsv" 2>/dev/null)
check "re-plan after apply proposes no take, add, delete or merge" hasnt "$replantsv" '	take	'
nothing_pending=1
printf '%s\n' "$replantsv" | while IFS='	' read -r p c rest; do
  [ -n "$p" ] || continue
  case $c in keep) ;; *) echo pending ;; esac
done | grep -q pending && nothing_pending=0
check "re-plan after apply leaves nothing but already-resolved keeps" match_eq "$nothing_pending" 1

# --- undo reverses only the update commit itself, as a new commit, never
# any founder change made after the update. The founder keeps working
# first: a brand new file, and an edit to a file the update never touched.
printf 'founder added this after the update\n' > "$lufounder/.claude/founder-added-after.md"
printf 'keep v2-founder, with a further founder edit\n' > "$lufounder/.claude/keep-me.md"
( cd "$lufounder" && git add -A && git commit -q -m "founder work after the update" )
new_before=$(cksum_of "$lufounder/.claude/founder-added-after.md")
keep_before=$(cksum_of "$lufounder/.claude/keep-me.md")

undoout=$( ( cd "$lufounder" && sh .claude/scripts/update.sh --undo < /dev/null ) 2>&1 )
check "undo reports success" has "$undoout" 'result=undone'
check "undo brings back delete-me.md" has "$(cat "$lufounder/.claude/delete-me.md" 2>/dev/null)" 'delete v1'
check "undo brings back take-me.md's pre-update words" has "$(cat "$lufounder/.claude/take-me.md" 2>/dev/null)" 'take v1'
check "undo is a new commit, made with git revert, not a rewound history" has "$(cd "$lufounder" && git log --format=%s -1)" 'Revert "Launchhouse update'
check "undo never touches growth-engine/" match_eq "$(cksum_of "$lufounder/growth-engine/founder-work.md")" "$ge_before"
check "undo leaves the founder's new file byte-identical" match_eq "$(cksum_of "$lufounder/.claude/founder-added-after.md")" "$new_before"
check "and it is still there" test -f "$lufounder/.claude/founder-added-after.md"
check "undo leaves the founder's later edit to an untouched file byte-identical" match_eq "$(cksum_of "$lufounder/.claude/keep-me.md")" "$keep_before"

# --- undo run again with nothing left to reverse is a noop, not an error.
noopout=$( ( cd "$lufounder" && sh .claude/scripts/update.sh --undo < /dev/null ) 2>&1 )
check "undoing an already-undone update reports noop" has "$noopout" 'result=noop'

# --- a further update, then a founder edit that overlaps it: undo must
# abort cleanly, reversing nothing, rather than clobbering the founder's
# later edit to the same file.
luwrite .claude/take-me.md "take v3"
( cd "$luup" && git add -A && git commit -q -m commit3 )

lu --plan >/dev/null
check "the next plan proposes take-me.md again, now at v3 upstream" has "$(row .claude/take-me.md)" 'take'

applyout2=$( ( cd "$lufounder" && sh .claude/scripts/update.sh --apply "$luwork/decisions.tsv" < /dev/null ) 2>&1 )
check "the second apply reports success" has "$applyout2" 'result=applied'
check "the second apply carries take-me.md to v3" has "$(cat "$lufounder/.claude/take-me.md" 2>/dev/null)" 'take v3'

printf 'take v3, with a founder note added right after the update\n' > "$lufounder/.claude/take-me.md"
( cd "$lufounder" && git add -A && git commit -q -m "founder edits a file the second update just changed" )

pre2_head=$( cd "$lufounder" && git rev-parse HEAD )
pre2_status=$( cd "$lufounder" && git status --porcelain )
undoout2=$( ( cd "$lufounder" && sh .claude/scripts/update.sh --undo < /dev/null ) 2>&1 )
check "undo aborts when a later founder edit overlaps the update" has "$undoout2" 'result=aborted'
check "and names the reason" has "$undoout2" 'reason=later changes overlap the update'
check "and lists the conflicting path" has "$undoout2" '.claude/take-me.md'
post2_head=$( cd "$lufounder" && git rev-parse HEAD )
post2_status=$( cd "$lufounder" && git status --porcelain )
check "the aborted undo leaves HEAD exactly where it was" match_eq "$post2_head" "$pre2_head"
check "the aborted undo leaves the working tree exactly as it was" match_eq "$post2_status" "$pre2_status"
check "and the founder's overlapping edit is untouched" has "$(cat "$lufounder/.claude/take-me.md" 2>/dev/null)" 'founder note added'

# ---------------------------------------------------------- checks=none
# A founder copy with no check of any kind (no .claude/tests/run.sh, no
# .claude/scripts/skill-packs.sh) still applies, and says so plainly rather
# than silently skipping.
lunone="$luwork/none"
mkdir -p "$lunone"
( cd "$luup" && git archive "$lubase" ) | ( cd "$lunone" && tar -x )
(
  cd "$lunone" && git init -q && git config user.name Founder && git config user.email f@example.com &&
  git add -A && git commit -q -m "Initial import from template" &&
  git remote add upstream "$luup"
)
mkdir -p "$lunone/.claude/scripts"
cp "$scripts/update.sh" "$scripts/lib.sh" "$lunone/.claude/scripts/"
chmod +x "$lunone/.claude/scripts/update.sh"
( cd "$lunone" && git add -A && git commit -q -m "add the update engine under test, no checks at all" )
( cd "$lunone" && sh .claude/scripts/update.sh --detect-base < /dev/null >/dev/null )
( cd "$lunone" && sh .claude/scripts/update.sh --set-base "$lubase" < /dev/null >/dev/null )
( cd "$lunone" && git add -A && git commit -q -m "record the base version" )
( cd "$lunone" && sh .claude/scripts/update.sh --plan < /dev/null >/dev/null )
cat > "$luwork/decisions-none.tsv" <<EOF
.claude/take-me.md	apply
.claude/keep-me.md	apply
.claude/merge-me.md	apply
.claude/conflict-me.md	hold
.claude/addme-upstream.md	apply
.claude/addconflict.md	keep-mine
.claude/delete-me.md	apply
.claude/gone-upstream-kept.md	hold
EOF
noneout=$( ( cd "$lunone" && sh .claude/scripts/update.sh --apply "$luwork/decisions-none.tsv" < /dev/null ) 2>&1 )
check "a copy with no checks at all refuses to apply without --allow-no-checks" has "$noneout" 'result=aborted'
check "and names the reason" has "$noneout" 'reason=no checks to run'
check "and leaves no pre-update tag behind" \
  match_eq "$( cd "$lunone" && git tag -l 'launchhouse-pre-update-*' | wc -l | tr -d ' ' )" 0

noneout2=$( ( cd "$lunone" && sh .claude/scripts/update.sh --apply "$luwork/decisions-none.tsv" --allow-no-checks < /dev/null ) 2>&1 )
check "a copy with no checks at all applies once --allow-no-checks is passed" has "$noneout2" 'result=applied'
check "and says plainly that no checks ran" has "$noneout2" 'checks=none'

# -------------------------------------------------- bootstrap: an older
# copy with no updater of its own at all
#
# README.md sends a founder on a copy made before the updater shipped to
# ask Claude to fetch update.sh and lib.sh from upstream into
# .git/launchhouse/bootstrap/, then run the updater from there. This proves
# update.sh works when run from that location: it must still find the real
# repository root (not the .git directory it is sitting inside) and behave
# exactly as it would from .claude/scripts/.

luboot="$luwork/bootstrap-founder"
mkdir -p "$luboot"
( cd "$luup" && git archive "$lubase" ) | ( cd "$luboot" && tar -x )
(
  cd "$luboot" && git init -q && git config user.name Founder && git config user.email f@example.com &&
  git add -A && git commit -q -m "Initial import from template, before the updater shipped" &&
  git remote add upstream "$luup"
)
check "a pre-updater copy really has no update.sh of its own" \
  match_eq "$( [ -f "$luboot/.claude/scripts/update.sh" ] && echo yes || echo no )" no

bootdir=$( cd "$luboot" && git rev-parse --absolute-git-dir )/launchhouse/bootstrap
mkdir -p "$bootdir"
cp "$scripts/update.sh" "$scripts/lib.sh" "$bootdir/"
chmod +x "$bootdir/update.sh"

bootstatusout=$( sh "$bootdir/update.sh" --status < /dev/null 2>&1 )
check "update.sh run from .git/launchhouse/bootstrap/ still reports status" has "$bootstatusout" 'upstream_url='

bootdbout=$( ( cd "$luboot" && sh "$bootdir/update.sh" --detect-base < /dev/null ) 2>&1 )
check "and finds the exact base commit from that location too" has "$bootdbout" "exact $lubase"

( cd "$luboot" && sh "$bootdir/update.sh" --set-base "$lubase" < /dev/null >/dev/null )
( cd "$luboot" && git add -A && git commit -q -m "record the base version" )
check "the base it recorded landed in the real repository, not .git/launchhouse/bootstrap" \
  has "$(cat "$luboot/.claude/launchhouse-version" 2>/dev/null)" "$lubase"

bootplanout=$( sh "$bootdir/update.sh" --plan < /dev/null 2>&1 )
check "and --plan run from the bootstrap location finds real changes" has "$bootplanout" '='
check "and the plan state landed under the real repository's .git, not a nested one" \
  test -f "$luboot/.git/launchhouse/update/plan.tsv"

# ------------------------------------------ detect-base: identical trees
# A merge commit can have a .claude tree byte-identical to one of its
# parents -- a PR that never touches .claude still produces a brand new
# merge commit on the mainline. More than one upstream commit can then
# carry the exact same .claude tree, and --detect-base's scan (a template
# copy, no shared history) must still say "exact" and pick one
# deterministically: the newest matching commit on upstream's first-parent
# history, never whichever one git happened to visit first.

dtwork="$luwork/dup-tree"
dtup="$dtwork/upstream"
mkdir -p "$dtup"
( cd "$dtup" && git init -q && git config user.name Up && git config user.email up@example.com )
mkdir -p "$dtup/.claude"
printf '%s
' "$dtup" > "$dtup/.claude/launchhouse-upstream"
printf 'v1
' > "$dtup/.claude/foo.md"
printf 'root
' > "$dtup/README.md"
( cd "$dtup" && git add -A && git commit -q -m "commit A: the base .claude tree" )
dtbase=$( cd "$dtup" && git rev-parse HEAD )

# A side branch that never touches .claude at all.
( cd "$dtup" && git checkout -q -b topic )
printf 'root, with a topic branch edit
' > "$dtup/README.md"
( cd "$dtup" && git add -A && git commit -q -m "commit B: a topic branch edit outside .claude" )

# Merge it back with --no-ff, forcing a real merge commit whose own tree
# (and .claude subtree) comes out identical to commit A's, since neither
# side touched .claude between them.
( cd "$dtup" && git checkout -q main 2>/dev/null || git checkout -q master )
dtmergeout=$( cd "$dtup" && git merge -q --no-ff -m "commit C: merge the topic branch, .claude untouched" topic 2>&1 )
dtmerge=$( cd "$dtup" && git rev-parse HEAD )
check "identical-tree fixture: the merge commit's .claude tree matches commit A's" \
  match_eq "$( cd "$dtup" && git rev-parse "$dtmerge:.claude" )" "$( cd "$dtup" && git rev-parse "$dtbase:.claude" )"
check "identical-tree fixture: the merge commit is not commit A itself" \
  hasnt "$dtmerge" "$dtbase"

dtfounder="$dtwork/founder"
mkdir -p "$dtfounder"
( cd "$dtup" && git archive "$dtbase" ) | ( cd "$dtfounder" && tar -x )
(
  cd "$dtfounder" && git init -q && git config user.name Founder && git config user.email f@example.com &&
  git add -A && git commit -q -m "Initial import from template" &&
  git remote add upstream "$dtup"
)
mkdir -p "$dtfounder/.claude/scripts"
cp "$scripts/update.sh" "$scripts/lib.sh" "$dtfounder/.claude/scripts/"
chmod +x "$dtfounder/.claude/scripts/update.sh"

dtdbout=$( ( cd "$dtfounder" && sh .claude/scripts/update.sh --detect-base < /dev/null ) 2>&1 )
check "detect-base reports exact when two upstream commits share an identical .claude tree" \
  has "$dtdbout" "exact "
check "detect-base picks the newest identical-tree commit, not the oldest" \
  has "$dtdbout" "exact $dtmerge"

rm -rf "$dtwork"

# ------------------------------------------------------------ upstream trust
# The "upstream" remote must point at the canonical Launchhouse address
# before any fetch. A copy whose remote was pointed somewhere else (by hand,
# or by a tampered checkout) is refused, not silently rewritten.

lupoison="$luwork/poison"
mkdir -p "$lupoison"
( cd "$luup" && git archive "$lubase" ) | ( cd "$lupoison" && tar -x )
(
  cd "$lupoison" && git init -q && git config user.name Founder && git config user.email f@example.com &&
  git add -A && git commit -q -m "Initial import from template" &&
  git remote add upstream "https://example.invalid/not-launchhouse.git"
)
mkdir -p "$lupoison/.claude/scripts"
cp "$scripts/update.sh" "$scripts/lib.sh" "$lupoison/.claude/scripts/"
chmod +x "$lupoison/.claude/scripts/update.sh"
( cd "$lupoison" && git add -A && git commit -q -m "add the update engine under test" )

poison_pre_head=$( cd "$lupoison" && git rev-parse HEAD )
poison_pre_status=$( cd "$lupoison" && git status --porcelain )

poisonstatusout=$( ( cd "$lupoison" && sh .claude/scripts/update.sh --status < /dev/null ) 2>&1 )
check "a poisoned upstream remote aborts --status" has "$poisonstatusout" 'result=aborted'
check "and names the reason" has "$poisonstatusout" 'reason=upstream address is not the Launchhouse original'

poisonplanout=$( ( cd "$lupoison" && sh .claude/scripts/update.sh --plan < /dev/null ) 2>&1 )
check "a poisoned upstream remote also aborts --plan, before any fetch" has "$poisonplanout" 'result=aborted'

poison_post_head=$( cd "$lupoison" && git rev-parse HEAD )
poison_post_status=$( cd "$lupoison" && git status --porcelain )
check "nothing changed in the poisoned copy" match_eq "$poison_post_head" "$poison_pre_head"
check "and its working tree is still exactly as it was" match_eq "$poison_post_status" "$poison_pre_status"

# --------------------------------------------------------------- stale plan
# --apply refuses a plan taken against an earlier HEAD than the one it is
# now being run against, rather than applying a plan that no longer
# describes the folder in front of it.

lustale="$luwork/stale"
mkdir -p "$lustale"
( cd "$luup" && git archive "$lubase" ) | ( cd "$lustale" && tar -x )
(
  cd "$lustale" && git init -q && git config user.name Founder && git config user.email f@example.com &&
  git add -A && git commit -q -m "Initial import from template" &&
  git remote add upstream "$luup"
)
mkdir -p "$lustale/.claude/scripts" "$lustale/.claude/tests"
cp "$scripts/update.sh" "$scripts/lib.sh" "$scripts/skill-packs.sh" "$lustale/.claude/scripts/"
chmod +x "$lustale/.claude/scripts/update.sh" "$lustale/.claude/scripts/skill-packs.sh"
printf '#!/bin/sh\nexit 0\n' > "$lustale/.claude/tests/run.sh"
chmod +x "$lustale/.claude/tests/run.sh"
( cd "$lustale" && git add -A && git commit -q -m "add the update engine under test" )
( cd "$lustale" && sh .claude/scripts/update.sh --detect-base < /dev/null >/dev/null )
( cd "$lustale" && sh .claude/scripts/update.sh --set-base "$lubase" < /dev/null >/dev/null )
( cd "$lustale" && git add -A && git commit -q -m "record the base version" )
( cd "$lustale" && sh .claude/scripts/update.sh --plan < /dev/null >/dev/null )

printf 'a change committed after the plan was taken\n' > "$lustale/.claude/local-only.md"
( cd "$lustale" && git add -A && git commit -q -m "founder commits again after the plan" )

cat > "$luwork/decisions-stale.tsv" <<EOF
.claude/take-me.md	apply
EOF
staleout=$( ( cd "$lustale" && sh .claude/scripts/update.sh --apply "$luwork/decisions-stale.tsv" < /dev/null ) 2>&1 )
check "apply refuses a plan taken against an earlier HEAD" has "$staleout" 'result=aborted'
check "and names the reason" has "$staleout" 'reason=folder changed since the plan; plan again'

# -------------------------------------------------------- undo trust: only
# the exact commit --apply recorded, never one merely found by tag and
# commit message. A commit a founder (or anything else) wrote by hand, with
# a message that happens to start "Launchhouse update to", must never be
# reverted by "undo the update" -- there is no recorded applied state
# pointing at it, so undo has nothing to trust.

luspoof="$luwork/spoof"
mkdir -p "$luspoof"
( cd "$luup" && git archive "$lubase" ) | ( cd "$luspoof" && tar -x )
(
  cd "$luspoof" && git init -q && git config user.name Founder && git config user.email f@example.com &&
  git add -A && git commit -q -m "Initial import from template" &&
  git remote add upstream "$luup"
)
mkdir -p "$luspoof/.claude/scripts"
cp "$scripts/update.sh" "$scripts/lib.sh" "$luspoof/.claude/scripts/"
chmod +x "$luspoof/.claude/scripts/update.sh"
( cd "$luspoof" && git add -A && git commit -q -m "add the update engine under test" )

git -C "$luspoof" tag launchhouse-pre-update-fake HEAD >/dev/null 2>&1
printf 'not really an update, just named like one\n' > "$luspoof/.claude/spoofed.md"
( cd "$luspoof" && git add -A && git commit -q -m "Launchhouse update to deadbeef" )

spoof_pre_head=$( cd "$luspoof" && git rev-parse HEAD )
spoof_pre_status=$( cd "$luspoof" && git status --porcelain )
spoofout=$( ( cd "$luspoof" && sh .claude/scripts/update.sh --undo < /dev/null ) 2>&1 )
check "undo never reverts a commit found only by tag and message" has "$spoofout" 'result=none'
spoof_post_head=$( cd "$luspoof" && git rev-parse HEAD )
spoof_post_status=$( cd "$luspoof" && git status --porcelain )
check "nothing was reverted" match_eq "$spoof_post_head" "$spoof_pre_head"
check "and the working tree is unchanged" match_eq "$spoof_post_status" "$spoof_pre_status"
check "and the spoofed commit's file still exists" test -f "$luspoof/.claude/spoofed.md"

# ------------------------------------------------ generated skill/agent paths
# A skill or agent path shaped like .claude/skills/<name>/SKILL.md or
# .claude/agents/<name>.md, carrying the skill-packs.sh --install marker as
# its first body line, is classified "generated" -- regenerated by
# skill-packs.sh --install all in the apply worktree, never taken, merged
# or held like an ordinary file. The one exception: a founder's own file at
# that exact path, changed since base, that carries no marker at all -- that
# is a real collision with something the founder wrote themselves, and is
# held as a "conflict" for explicit review rather than silently clobbered.

lugiwork=${TMPDIR:-/tmp}/lh-update-geninstall-test.$$
trap 'rm -rf "$lugiwork"' EXIT
lugiup="$lugiwork/upstream"
lugifounder="$lugiwork/founder"
mkdir -p "$lugiup" "$lugifounder" || exit 1

( cd "$lugiup" && git init -q && git config user.name Up && git config user.email up@example.com )

lugiwrite() { # relative path, content
  mkdir -p "$lugiup/$(dirname "$1")"
  printf '%s\n' "$2" > "$lugiup/$1"
}

# --- commit 1: the version the founder's copy starts from. No demo pack
# yet, at either path.
lugiwrite .claude/launchhouse-upstream "$lugiup"
lugiwrite .claude/skill-packs/registry.tsv "id	name	kind	suffix_regex	tracks	origin"
( cd "$lugiup" && git add -A && git commit -q -m commit1 )
lugibase=$( cd "$lugiup" && git rev-parse HEAD )

# --- commit 2: upstream ships a new, fully valid "demo" skill pack (one
# skill, one agent), plus both of their already-installed copies -- the
# same way a real release commits an installed skill or agent alongside its
# pack, same as compiled-policy.sh.
lugiwrite .claude/skill-packs/registry.tsv "id	name	kind	suffix_regex	tracks	origin
demo	Demo	tool	^demo_	both	template"
lugiwrite .claude/skill-packs/demo/pack.md "---
id: demo
name: Demo
kind: tool
skills: [demo-expert]
agents: [demo-specialist]
scripts: []
connectors: [demo]
vendor_url: https://example.invalid
tracks: both
jobs: [demo]
job_skills: []
specialist: demo-specialist
expert_skill: demo-expert
inventory_source: documented
verified_on: 2026-09-22
origin: template
---

Fixture pack for the generated/conflict classification tests only."
lugiwrite .claude/skill-packs/demo/skills/demo-expert/SKILL.md "---
name: demo-expert
description: A demo pack skill, for the generated/conflict classification tests only.
---

Demo skill body."
lugiwrite .claude/skills/demo-expert/SKILL.md "---
name: demo-expert
description: A demo pack skill, for the generated/conflict classification tests only.
---
<!-- Installed from .claude/skill-packs/demo/skills/demo-expert/SKILL.md. Edit the pack's copy, not this one; Launchhouse re-installs it. -->

Demo skill body."
lugiwrite .claude/skill-packs/demo/agents/demo-specialist.md "---
name: demo-specialist
description: A demo pack agent, for the generated/conflict classification tests only.
model: sonnet
---

Demo agent body."
lugiwrite .claude/agents/demo-specialist.md "---
name: demo-specialist
description: A demo pack agent, for the generated/conflict classification tests only.
model: sonnet
---
<!-- Installed from .claude/skill-packs/demo/agents/demo-specialist.md. Edit the pack's copy, not this one; Launchhouse re-installs it. -->

Demo agent body."
lugiwrite .claude/skill-packs/demo/references/knowledge.md "# Demo

## Mental model
Demo.

## Connecting and auth
Demo.

## Tool map

| tool | class | what it does | inputs that matter | gotchas |
|---|---|---|---|---|
| \`demo_thing\` | read | Demo. | none | none |

## Workflows for Launchhouse jobs

### demo

Demo.

## Limits and quotas
Demo.

## Failure modes and fixes

| Symptom | Cause | Fix |
|---|---|---|
| Demo | Demo | Demo |

## Rules that apply here
Demo.

## Sources
- Demo: https://example.invalid (checked 2026-09-22)

## Refreshing this pack
Demo."
lugiwrite .claude/skill-packs/demo/references/evals.md "# Demo evals

### 1. one
Founder says: \"x\"
Expected: x

### 2. two
Founder says: \"x\"
Expected: x

### 3. three
Founder says: \"x\"
Expected: x

### 4. four
Founder says: \"x\"
Expected: x

### 5. five (guard rail)
Founder says: \"x\"
Expected: refuse

### 6. six (guard rail)
Founder says: \"x\"
Expected: refuse

### 7. seven (guard rail)
Founder says: \"x\"
Expected: refuse

### 8. eight
Founder says: \"x\"
Expected: x"
lugiwrite .claude/skill-packs/demo/references/inventory.txt "# source: documented https://example.invalid checked 2026-09-22
demo_thing"
lugiwrite .claude/skill-packs/demo/policy.tsv ""
lugiwrite .claude/skill-packs/demo/tests.tsv ""
( cd "$lugiup" && git add -A && git commit -q -m commit2 )
lugihead=$( cd "$lugiup" && git rev-parse HEAD )

# --- the founder's copy: template-style, from commit1, same as the main
# fixture above. The founder separately wrote their OWN agent at the exact
# path the pack will later claim -- unrelated to the pack, no marker.
( cd "$lugiup" && git archive "$lugibase" ) | ( cd "$lugifounder" && tar -x )
(
  cd "$lugifounder" && git init -q && git config user.name Founder && git config user.email f@example.com &&
  git add -A && git commit -q -m "Initial import from template" &&
  git remote add upstream "$lugiup"
)
mkdir -p "$lugifounder/.claude/agents"
printf '%s\n' "---
name: demo-specialist
description: The founder's own agent, written before the demo pack existed, unrelated to it.
model: sonnet
---

The founder's own words, never a pack's." > "$lugifounder/.claude/agents/demo-specialist.md"
( cd "$lugifounder" && git add -A && git commit -q -m "founder's own agent at a path the pack will later claim" )

lugi() { ( cd "$lugifounder" && sh .claude/scripts/update.sh "$@" < /dev/null ) 2>&1; }
mkdir -p "$lugifounder/.claude/scripts"
cp "$scripts/update.sh" "$scripts/lib.sh" "$scripts/skill-packs.sh" "$lugifounder/.claude/scripts/"
chmod +x "$lugifounder/.claude/scripts/update.sh" "$lugifounder/.claude/scripts/skill-packs.sh"
( cd "$lugifounder" && git add -A && git commit -q -m "add the update engine and skill-packs.sh under test" )

lugi --detect-base >/dev/null
lugi --set-base "$lugibase" >/dev/null
( cd "$lugifounder" && git add -A && git commit -q -m "record the base version" )

lugiplanout=$(lugi --plan)
lugiplantsv="$lugifounder/.git/launchhouse/update/plan.tsv"
lugirow() { grep -F "$(printf '%s\t' "$1")" "$lugiplantsv"; }

check "a brand new upstream-marked skill path is classified generated, not add" \
  has "$(lugirow .claude/skills/demo-expert/SKILL.md)" 'generated'
check "and never add" \
  hasnt "$(lugirow .claude/skills/demo-expert/SKILL.md)" '	add	'
check "a founder's own unmarked file at a path upstream now generates is held as a conflict" \
  has "$(lugirow .claude/agents/demo-specialist.md)" 'conflict'
check "and never silently regenerated" \
  hasnt "$(lugirow .claude/agents/demo-specialist.md)" '	generated	'

# Holding the conflict (keeping the founder's own file exactly as it is) is
# a valid resolution on its own, already proven at the plan level above:
# skill-packs.sh --validate all (which apply's own checks run) correctly
# refuses to call that state clean, since the founder's file now collides
# with a name the pack claims -- proving the conflict is real, not a false
# positive, is the other half of what this fixture is for.
cat > "$lugiwork/decisions-hold.tsv" <<EOF
.claude/skill-packs/registry.tsv	apply
.claude/skill-packs/demo/pack.md	apply
.claude/skill-packs/demo/skills/demo-expert/SKILL.md	apply
.claude/skill-packs/demo/agents/demo-specialist.md	apply
.claude/skill-packs/demo/references/knowledge.md	apply
.claude/skill-packs/demo/references/evals.md	apply
.claude/skill-packs/demo/references/inventory.txt	apply
.claude/skill-packs/demo/policy.tsv	apply
.claude/skill-packs/demo/tests.tsv	apply
.claude/agents/demo-specialist.md	hold
EOF
lugiholdout=$( ( cd "$lugifounder" && sh .claude/scripts/update.sh --apply "$lugiwork/decisions-hold.tsv" --allow-no-checks < /dev/null ) 2>&1 )
check "holding the conflict is refused by the pack validator's own collision check, proving the held state is a real collision" \
  has "$lugiholdout" 'collides with an installed copy this pack does not own'
check "holding the conflict never moves HEAD" \
  match_eq "$( cd "$lugifounder" && git rev-parse HEAD )" "$( cd "$lugifounder" && git log --format=%H -1 )"
check "and the founder's own agent is untouched" \
  has "$(cat "$lugifounder/.claude/agents/demo-specialist.md" 2>/dev/null)" "The founder's own words, never a pack's."

# The other resolution: the founder accepts the pack's own version instead
# (take-theirs). Now nothing collides, the checks pass, and the generated
# skill (which was never in question) lands the same way either time.
cat > "$lugiwork/decisions-take.tsv" <<EOF
.claude/skill-packs/registry.tsv	apply
.claude/skill-packs/demo/pack.md	apply
.claude/skill-packs/demo/skills/demo-expert/SKILL.md	apply
.claude/skill-packs/demo/agents/demo-specialist.md	apply
.claude/skill-packs/demo/references/knowledge.md	apply
.claude/skill-packs/demo/references/evals.md	apply
.claude/skill-packs/demo/references/inventory.txt	apply
.claude/skill-packs/demo/policy.tsv	apply
.claude/skill-packs/demo/tests.tsv	apply
.claude/agents/demo-specialist.md	take-theirs
EOF
lugi --plan >/dev/null
lugitakeout=$( ( cd "$lugifounder" && sh .claude/scripts/update.sh --apply "$lugiwork/decisions-take.tsv" --allow-no-checks < /dev/null ) 2>&1 )
check "apply succeeds once the conflict is resolved with take-theirs" has "$lugitakeout" 'result=applied'
check "the generated skill file now exists, regenerated by --install all" \
  test -f "$lugifounder/.claude/skills/demo-expert/SKILL.md"
check "and carries the install marker" \
  has "$(cat "$lugifounder/.claude/skills/demo-expert/SKILL.md" 2>/dev/null)" 'Installed from .claude/skill-packs/demo/skills/demo-expert/SKILL.md'
check "the resolved conflict now carries the pack's own agent, marker included" \
  has "$(cat "$lugifounder/.claude/agents/demo-specialist.md" 2>/dev/null)" 'Installed from .claude/skill-packs/demo/agents/demo-specialist.md'

rm -rf "$lugiwork"

# ------------------------------------------------ founder-edited-after-install
# A path shaped like an installed skill, upstream-marked and genuinely owned
# by a real pack, but whose content at HEAD no longer matches what
# skill-packs.sh --install would produce from HEAD's own pack source: the
# founder hand-edited the installed copy's body after it was installed,
# without touching the marker line at all. This must be held as a
# "conflict", never silently regenerated over the edit, and the file on
# disk must come out of an apply byte-for-byte unchanged when that conflict
# is held.

ludrwork=${TMPDIR:-/tmp}/lh-update-drift-test.$$
trap 'rm -rf "$ludrwork"' EXIT
ludrup="$ludrwork/upstream"
ludrfounder="$ludrwork/founder"
mkdir -p "$ludrup" "$ludrfounder" || exit 1

( cd "$ludrup" && git init -q && git config user.name Up && git config user.email up@example.com )

ludrwrite() { # relative path, content
  mkdir -p "$ludrup/$(dirname "$1")"
  printf '%s\n' "$2" > "$ludrup/$1"
}

ludrwrite .claude/launchhouse-upstream "$ludrup"
ludrwrite .claude/skill-packs/registry.tsv "id	name	kind	suffix_regex	tracks	origin
drift	Drift	tool	^drift_	both	template"
ludrwrite .claude/skill-packs/drift/pack.md "---
id: drift
name: Drift
kind: tool
skills: [drift-expert]
agents: []
scripts: []
connectors: [drift]
vendor_url: https://example.invalid
tracks: both
jobs: [drift]
job_skills: []
specialist: none
expert_skill: drift-expert
inventory_source: documented
verified_on: 2026-09-22
origin: template
---

Fixture pack for the drift-after-install classification test only."
ludrwrite .claude/skill-packs/drift/skills/drift-expert/SKILL.md "---
name: drift-expert
description: A drift pack skill, for the drift-after-install classification test only.
---

Original skill body, as the pack itself has it."
ludrwrite .claude/skills/drift-expert/SKILL.md "---
name: drift-expert
description: A drift pack skill, for the drift-after-install classification test only.
---
<!-- Installed from .claude/skill-packs/drift/skills/drift-expert/SKILL.md. Edit the pack's copy, not this one; Launchhouse re-installs it. -->

Original skill body, as the pack itself has it."
( cd "$ludrup" && git add -A && git commit -q -m commit1 )
ludrbase=$( cd "$ludrup" && git rev-parse HEAD )

# The founder's copy: template-style, from that same commit. No
# skill-packs.sh in this fixture at all -- the classification the fix makes
# lives entirely in update.sh's own git-blob reads, never needs
# skill-packs.sh to run, and leaving it out means apply's own checks find
# nothing to run and this fixture can use --allow-no-checks, the same way
# the "checks=none" fixture above does, instead of having to build out a
# whole second valid pack (knowledge.md, evals.md, policy.tsv, tests.tsv)
# just to satisfy --validate all.
( cd "$ludrup" && git archive "$ludrbase" ) | ( cd "$ludrfounder" && tar -x )
(
  cd "$ludrfounder" && git init -q && git config user.name Founder && git config user.email f@example.com &&
  git add -A && git commit -q -m "Initial import from template" &&
  git remote add upstream "$ludrup"
)
mkdir -p "$ludrfounder/.claude/scripts"
cp "$scripts/update.sh" "$scripts/lib.sh" "$ludrfounder/.claude/scripts/"
chmod +x "$ludrfounder/.claude/scripts/update.sh"
( cd "$ludrfounder" && git add -A && git commit -q -m "add the update engine under test" )

# The founder edits the INSTALLED copy's body by hand, keeping the marker
# line exactly as it was -- this is the drift the fix must catch.
printf '%s\n' "---
name: drift-expert
description: A drift pack skill, for the drift-after-install classification test only.
---
<!-- Installed from .claude/skill-packs/drift/skills/drift-expert/SKILL.md. Edit the pack's copy, not this one; Launchhouse re-installs it. -->

The founder's own hand-edit, made after install, never touching the marker." > "$ludrfounder/.claude/skills/drift-expert/SKILL.md"
( cd "$ludrfounder" && git add -A && git commit -q -m "founder hand-edits the installed copy after install" )

# commit2: a harmless, unrelated upstream change, so this fixture also
# proves an apply can go through and land an ordinary upstream change while
# the drift conflict stays held next to it, rather than only ever seeing
# "nothing to apply" once the one conflicting row is held.
ludrwrite NOTES.md "upstream notes, v2"
( cd "$ludrup" && git add -A && git commit -q -m commit2 )

ludr() { ( cd "$ludrfounder" && sh .claude/scripts/update.sh "$@" < /dev/null ) 2>&1; }
ludr --detect-base >/dev/null
ludr --set-base "$ludrbase" >/dev/null
( cd "$ludrfounder" && git add -A && git commit -q -m "record the base version" )

ludrplanout=$(ludr --plan)
ludrplantsv="$ludrfounder/.git/launchhouse/update/plan.tsv"
ludrrow() { grep -F "$(printf '%s\t' "$1")" "$ludrplantsv"; }

check "an installed copy the founder hand-edited after install, marker intact, is held as a conflict" \
  has "$(ludrrow .claude/skills/drift-expert/SKILL.md)" 'conflict'
check "and never silently regenerated" \
  hasnt "$(ludrrow .claude/skills/drift-expert/SKILL.md)" '	generated	'

ludr_before=$(cksum_of "$ludrfounder/.claude/skills/drift-expert/SKILL.md")
cat > "$ludrwork/decisions-hold.tsv" <<EOF
.claude/skills/drift-expert/SKILL.md	hold
NOTES.md	apply
EOF
ludrapplyout=$( ( cd "$ludrfounder" && sh .claude/scripts/update.sh --apply "$ludrwork/decisions-hold.tsv" --allow-no-checks < /dev/null ) 2>&1 )
check "holding the drift conflict still applies (nothing else was pending)" has "$ludrapplyout" 'result=applied'
check "and the founder's hand-edited file is byte-for-byte unchanged" \
  match_eq "$(cksum_of "$ludrfounder/.claude/skills/drift-expert/SKILL.md")" "$ludr_before"

rm -rf "$ludrwork"

# --------------------------------------------------------- spoofed marker
# A file that merely starts with the install-marker prefix but names a pack
# source that does not actually exist anywhere in the repository must never
# be trusted as "generated": it falls through to whatever this codebase
# already does with an ordinary new upstream file (here, a plain "add"),
# never silently regenerated or treated as pack-owned.

luspwork=${TMPDIR:-/tmp}/lh-update-spoof-marker-test.$$
trap 'rm -rf "$luspwork"' EXIT
luspup="$luspwork/upstream"
luspfounder="$luspwork/founder"
mkdir -p "$luspup" "$luspfounder" || exit 1

( cd "$luspup" && git init -q && git config user.name Up && git config user.email up@example.com )

luspwrite() { # relative path, content
  mkdir -p "$luspup/$(dirname "$1")"
  printf '%s\n' "$2" > "$luspup/$1"
}

luspwrite .claude/launchhouse-upstream "$luspup"
luspwrite .claude/skill-packs/registry.tsv "id	name	kind	suffix_regex	tracks	origin"
( cd "$luspup" && git add -A && git commit -q -m commit1 )
luspbase=$( cd "$luspup" && git rev-parse HEAD )

( cd "$luspup" && git archive "$luspbase" ) | ( cd "$luspfounder" && tar -x )
(
  cd "$luspfounder" && git init -q && git config user.name Founder && git config user.email f@example.com &&
  git add -A && git commit -q -m "Initial import from template" &&
  git remote add upstream "$luspup"
)
mkdir -p "$luspfounder/.claude/scripts"
cp "$scripts/update.sh" "$scripts/lib.sh" "$luspfounder/.claude/scripts/"
chmod +x "$luspfounder/.claude/scripts/update.sh"
( cd "$luspfounder" && git add -A && git commit -q -m "add the update engine under test" )

luspr() { ( cd "$luspfounder" && sh .claude/scripts/update.sh "$@" < /dev/null ) 2>&1; }
luspr --detect-base >/dev/null
luspr --set-base "$luspbase" >/dev/null
( cd "$luspfounder" && git add -A && git commit -q -m "record the base version" )

# commit2: upstream ships a file shaped exactly like an installed skill,
# with a marker-shaped first body line, but the pack it names
# (skill-packs/nonexistent/skills/spoofed-expert/SKILL.md) does not exist
# anywhere in the repository -- forged or simply wrong, either way never a
# pack this repository actually owns.
luspwrite .claude/skills/spoofed-expert/SKILL.md "---
name: spoofed-expert
description: A file shaped like an installed skill, with a marker naming a pack source that does not exist.
---
<!-- Installed from .claude/skill-packs/nonexistent/skills/spoofed-expert/SKILL.md. Edit the pack's copy, not this one; Launchhouse re-installs it. -->

Never actually produced by any real pack."
( cd "$luspup" && git add -A && git commit -q -m "commit2: a file with a spoofed install marker" )

luspplanout=$(luspr --plan)
luspplantsv="$luspfounder/.git/launchhouse/update/plan.tsv"
lusprow() { grep -F "$(printf '%s\t' "$1")" "$luspplantsv"; }

check "a spoofed marker naming a pack source that does not exist is never classified generated" \
  hasnt "$(lusprow .claude/skills/spoofed-expert/SKILL.md)" '	generated	'
check "it falls through to this codebase's own category for a plain new upstream file" \
  has "$(lusprow .claude/skills/spoofed-expert/SKILL.md)" '	add	'

rm -rf "$luspwork"

# -------------------------------------------------------------- real-history
# Optional: clones the actual public Launchhouse template repository and
# runs a status / detect-base / plan / apply cycle against it, with all
# conflicts held. Needs network access, so it only runs when LH_UPDATE_REAL=1.

if [ "${LH_UPDATE_REAL:-0}" = 1 ]; then
  # Unset before doing anything else in this block. --apply below runs the
  # real upstream tree's own .claude/tests/run.sh inside its worktree, and
  # that real run.sh in turn shells out to its own copy of this very
  # update-cases.sh (see run.sh's "own self-contained suite" call). An
  # exported LH_UPDATE_REAL=1 is inherited by every child process, so
  # without this it leaks into that nested invocation, which clones the
  # public repo and runs a whole extra real-history cycle of its own --
  # whose nested run.sh does the same again, unbounded. Real-history is a
  # property of this top-level run only; every check --apply triggers must
  # run as an ordinary, non-real-history pass.
  unset LH_UPDATE_REAL
  rhwork=${TMPDIR:-/tmp}/lh-update-real-test.$$
  rm -rf "$rhwork"
  mkdir -p "$rhwork"
  rhclone="$rhwork/clone"
  rhfounder="$rhwork/founder"

  if ! git clone -q https://github.com/Philm-moxywolf/launchhouse-founder-template.git "$rhclone" 2>/tmp/lh-real-clone-err.$$; then
    check "real-history: could clone the public template repository" match_eq 1 0
    cat /tmp/lh-real-clone-err.$$ >&2
    rm -f /tmp/lh-real-clone-err.$$
  else
    rm -f /tmp/lh-real-clone-err.$$
    head_sha=$( cd "$rhclone" && git rev-parse HEAD )
    base_sha=$( cd "$rhclone" && git log --format=%H -n 1 --skip=7 HEAD 2>/dev/null )
    if [ -z "$base_sha" ]; then
      base_sha=$( cd "$rhclone" && git rev-list --max-parents=0 HEAD | tail -1 )
    fi
    check "real-history: found a base commit 5-10 commits behind HEAD" match_eq "$( [ -n "$base_sha" ] && echo yes || echo no )" yes

    mkdir -p "$rhfounder"
    ( cd "$rhclone" && git archive "$base_sha" ) | ( cd "$rhfounder" && tar -x )
    (
      cd "$rhfounder" && git init -q && git config user.name Founder && git config user.email f@example.com &&
      git add -A && git commit -q -m "Initial import from template" &&
      git remote add upstream "$rhclone"
    )

    # Record the local clone as the canonical upstream address, since
    # update.sh refuses to fetch from an "upstream" remote that does not
    # match .claude/launchhouse-upstream (or the real public URL, absent
    # that file) -- the real repository's own tree has no such file yet, and
    # this fixture's remote is a local clone path, not the public URL.
    mkdir -p "$rhfounder/.claude"
    printf '%s\n' "$rhclone" > "$rhfounder/.claude/launchhouse-upstream"

    # a founder customisation: an edit to CLAUDE.md, and a local skill.
    printf '\n## A founder note\nAdded by the founder, never upstream.\n' >> "$rhfounder/CLAUDE.md"
    mkdir -p "$rhfounder/.claude/skills/my-local-skill"
    printf -- '---\nname: my-local-skill\ndescription: A founder-added local skill, never upstream.\n---\n\n# My local skill\n' \
      > "$rhfounder/.claude/skills/my-local-skill/SKILL.md"
    mkdir -p "$rhfounder/growth-engine/brain" "$rhfounder/growth-engine/log"
    printf '# Founder Brain\n\n- **Track:** b2c\n\n## Thesis\nA real-history test fixture.\n' \
      > "$rhfounder/growth-engine/brain/founder-brain.md"
    printf '# Ledger\n\n- test entry\n' > "$rhfounder/growth-engine/log/ledger.md"
    : > "$rhfounder/growth-engine/.launchhouse"
    ge_real_before_brain=$(cksum_of "$rhfounder/growth-engine/brain/founder-brain.md")
    ge_real_before_ledger=$(cksum_of "$rhfounder/growth-engine/log/ledger.md")
    ( cd "$rhfounder" && git add -A && git commit -q -m "founder customisation and growth-engine files" )

    mkdir -p "$rhfounder/.claude/scripts"
    cp "$scripts/update.sh" "$scripts/lib.sh" "$rhfounder/.claude/scripts/"
    chmod +x "$rhfounder/.claude/scripts/update.sh"
    ( cd "$rhfounder" && git add -A && git commit -q -m "add the update engine under test" )

    rhstatusout=$( ( cd "$rhfounder" && sh .claude/scripts/update.sh --status < /dev/null ) 2>&1 )
    check "real-history: --status reaches the real upstream" has "$rhstatusout" 'upstream_url='

    rhdbout=$( ( cd "$rhfounder" && sh .claude/scripts/update.sh --detect-base < /dev/null ) 2>&1 )
    # A merge commit can have a .claude tree identical to one of its
    # parents (a PR that never touched .claude still produces a new merge
    # commit upstream), so more than one upstream commit can be an equally
    # correct "exact" base -- not only the literal $base_sha this fixture
    # happened to pick with --skip=7. What matters is that --detect-base
    # reports "exact" at all, and that whatever commit it names carries the
    # very same .claude tree as $base_sha, not that it names $base_sha
    # itself byte for byte.
    rhdb_reported_sha=$(printf '%s
' "$rhdbout" | awk '$1=="exact"{print $2; exit}')
    rhdb_reported_tree=$( [ -n "$rhdb_reported_sha" ] && ( cd "$rhclone" && git rev-parse -q --verify "$rhdb_reported_sha:.claude" 2>/dev/null ) )
    rhdb_expected_tree=$( cd "$rhclone" && git rev-parse -q --verify "$base_sha:.claude" 2>/dev/null )
    check "real-history: --detect-base reports exact" has "$rhdbout" "exact "
    check "real-history: --detect-base's exact commit carries the same .claude tree as the base" \
      match_eq "$rhdb_reported_tree" "$rhdb_expected_tree"

    ( cd "$rhfounder" && sh .claude/scripts/update.sh --set-base "$base_sha" < /dev/null >/dev/null )
    ( cd "$rhfounder" && git add -A && git commit -q -m "record the base version" )

    rhplanout=$( ( cd "$rhfounder" && sh .claude/scripts/update.sh --plan < /dev/null ) 2>&1 )
    printf 'real-history: plan class counts:\n%s\n' "$rhplanout"
    check "real-history: --plan produced class counts" has "$rhplanout" '='

    # decisions.tsv needs the literal words --apply understands (apply |
    # hold | keep-mine | take-theirs), not the plan's own "proposed" column
    # (whose held classes literally read "hold", but whose safe classes
    # read their own class name -- "take", "add", "delete", "keep" -- which
    # --apply's dispatch does not recognise as a decision at all and would
    # silently no-op). So every row not in a held class gets the literal
    # decision "apply" here; every conflict|add-conflict|
    # deleted-upstream-kept|settings row gets "hold" -- "all conflicts
    # held", the rest let through, the same shape the launchhouse-update
    # skill's own decisions.tsv takes when the reviewer raises nothing.
    rhplantsv="$rhfounder/.git/launchhouse/update/plan.tsv"
    : > "$rhwork/decisions-real.tsv"
    if [ -f "$rhplantsv" ]; then
      while IFS='	' read -r p c proposed rest; do
        [ -n "$p" ] || continue
        case $c in
          conflict|add-conflict|deleted-upstream-kept|settings) d=hold ;;
          *) d=apply ;;
        esac
        printf '%s\t%s\n' "$p" "$d" >> "$rhwork/decisions-real.tsv"
      done < "$rhplantsv"
    fi
    check "real-history: every held-class row's decision is actually hold" \
      hasnt "$(awk -F '\t' '$2=="conflict"||$2=="add-conflict"||$2=="deleted-upstream-kept"||$2=="settings" {print $1}' "$rhplantsv" 2>/dev/null | while IFS= read -r hp; do [ -n "$hp" ] || continue; grep -F "$(printf '%s\t' "$hp")" "$rhwork/decisions-real.tsv" | grep -v 'hold$'; done)" .

    rhapplyout=$( ( cd "$rhfounder" && sh .claude/scripts/update.sh --apply "$rhwork/decisions-real.tsv" < /dev/null ) 2>&1 )
    printf 'real-history: apply result:\n%s\n' "$rhapplyout"
    check "real-history: --apply does not report an unexpected internal failure" \
      hasnt "$rhapplyout" 'reason=could not'
    check "real-history: growth-engine/brain/founder-brain.md is byte-identical after" \
      match_eq "$(cksum_of "$rhfounder/growth-engine/brain/founder-brain.md")" "$ge_real_before_brain"
    check "real-history: growth-engine/log/ledger.md is byte-identical after" \
      match_eq "$(cksum_of "$rhfounder/growth-engine/log/ledger.md")" "$ge_real_before_ledger"
    check "real-history: the founder's CLAUDE.md note survives" \
      has "$(cat "$rhfounder/CLAUDE.md" 2>/dev/null)" "Added by the founder, never upstream."
    check "real-history: the founder's local skill survives" \
      test -f "$rhfounder/.claude/skills/my-local-skill/SKILL.md"

    if has "$rhapplyout" 'result=applied'; then
      echo "real-history: checks ran and passed (result=applied)"
    else
      echo "real-history: checks did not report applied -- see reason= above"
    fi
  fi
  rm -rf "$rhwork"
fi

if [ "$fail" = 0 ]; then
  printf '\nAll update cases passed.\n'
else
  printf '\nSome update cases failed.\n'
fi
exit $fail
