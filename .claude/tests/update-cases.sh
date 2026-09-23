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

# An older updater leaks LH_UPDATE_RELOCATED and LH_UPDATE_ROOT into the checks
# it runs and never unsets them; clear both here, before anything else runs, so
# a nested update.sh call below can never mistake the founder's real folder
# for its own root.
unset LH_UPDATE_RELOCATED LH_UPDATE_ROOT

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

# Installs .claude/scripts/json-valid.sh into a fixture founder repo (and
# COMMITS it there, since an untracked file under .claude/ would otherwise
# make is_clean() see the repo as dirty): the real validator, copied from
# this branch's own .claude/scripts/, once worker R's own interface has
# landed there; a stub that always exits 0 otherwise, so an adapt-save or
# post-landing-smoke case that touches a .json path here still exercises
# everything BUT real JSON validation until that merge. Callers that need
# to tell real from stub check `[ -f "$scripts/json-valid.sh" ]` themselves
# (this repo's own copy, never the fixture's).
install_json_valid_stub() { # founder repo root
  ijv_dest=$1
  mkdir -p "$ijv_dest/.claude/scripts"
  if [ -f "$scripts/json-valid.sh" ]; then
    cp "$scripts/json-valid.sh" "$ijv_dest/.claude/scripts/json-valid.sh"
  else
    printf '#!/bin/sh\nexit 0\n' > "$ijv_dest/.claude/scripts/json-valid.sh"
  fi
  chmod +x "$ijv_dest/.claude/scripts/json-valid.sh" 2>/dev/null
}

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
# set-base commits .claude/launchhouse-version itself (see the dedicated
# "set-base commits itself" cases below), so the tree is already clean
# here -- nothing left for the caller to commit.
check "set-base leaves the tree clean on its own" \
  match_eq "$( cd "$lufounder" && git status --porcelain )" ""

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

# ------------------------------------------------ set-base commits itself
#
# --set-base used to only write .claude/launchhouse-version, leaving it
# untracked/modified and the tree dirty -- which is exactly the state the
# launchhouse-update skill's own sequence (save the founder's work in step
# 0, THEN --detect-base / --set-base in step 2) hits on a folder with no
# recorded version, and --apply's is_clean() then refuses with "working
# tree is not clean". A fresh founder copy here, with no
# .claude/launchhouse-version at all, exercises the fix: set-base must
# leave the tree clean by committing the file itself.
lusb="$luwork/setbase"
mkdir -p "$lusb"
( cd "$luup" && git archive "$lubase" ) | ( cd "$lusb" && tar -x )
(
  cd "$lusb" && git init -q && git config user.name Founder && git config user.email f@example.com &&
  git add -A && git commit -q -m "Initial import from template" &&
  git remote add upstream "$luup"
)
mkdir -p "$lusb/.claude/scripts" "$lusb/.claude/tests"
cp "$scripts/update.sh" "$scripts/lib.sh" "$lusb/.claude/scripts/"
chmod +x "$lusb/.claude/scripts/update.sh"
printf '#!/bin/sh\nexit 0\n' > "$lusb/.claude/tests/run.sh"
chmod +x "$lusb/.claude/tests/run.sh"
( cd "$lusb" && git add -A && git commit -q -m "add the update engine under test, and a passing check stub" )

check "set-base fixture: starts with no recorded version" \
  match_eq "$( [ -f "$lusb/.claude/launchhouse-version" ] && echo yes || echo no )" no

lusb_prehead=$( cd "$lusb" && git rev-parse HEAD )
( cd "$lusb" && sh .claude/scripts/update.sh --detect-base < /dev/null >/dev/null )
sbout=$( ( cd "$lusb" && sh .claude/scripts/update.sh --set-base "$lubase" < /dev/null ) 2>&1 )
check "set-base still prints base=<sha>" has "$sbout" "base=$lubase"

# --- (a) a clean tree, and a commit touching only launchhouse-version
check "set-base on a folder with no version file leaves the tree clean" \
  match_eq "$( cd "$lusb" && git status --porcelain )" ""
lusb_posthead=$( cd "$lusb" && git rev-parse HEAD )
check "set-base actually made a new commit" \
  sh -c '[ "$1" != "$2" ]' _ "$lusb_posthead" "$lusb_prehead"
check "and that commit touches only .claude/launchhouse-version" \
  match_eq "$( cd "$lusb" && git diff --name-only HEAD~1 HEAD )" ".claude/launchhouse-version"
check "and records the sha it was given" \
  match_eq "$( cat "$lusb/.claude/launchhouse-version" | tr -d ' \t\r\n' )" "$lubase"

# --- (b) set-base with the same sha twice makes no second commit
sbout2=$( ( cd "$lusb" && sh .claude/scripts/update.sh --set-base "$lubase" < /dev/null ) 2>&1 )
check "set-base repeated with the same sha still reports base=<sha>" has "$sbout2" "base=$lubase"
check "set-base repeated with the same sha makes no second commit" \
  match_eq "$( cd "$lusb" && git rev-parse HEAD )" "$lusb_posthead"
check "and the tree is still clean" \
  match_eq "$( cd "$lusb" && git status --porcelain )" ""

# --- (c) status -> detect-base -> set-base -> plan -> apply reaches
# result=applied, on a folder that started with no version file at all,
# never touched by hand between --set-base and --apply.
lusb2="$luwork/setbase2"
mkdir -p "$lusb2"
( cd "$luup" && git archive "$lubase" ) | ( cd "$lusb2" && tar -x )
(
  cd "$lusb2" && git init -q && git config user.name Founder && git config user.email f@example.com &&
  git add -A && git commit -q -m "Initial import from template" &&
  git remote add upstream "$luup"
)
mkdir -p "$lusb2/.claude/scripts" "$lusb2/.claude/tests"
cp "$scripts/update.sh" "$scripts/lib.sh" "$lusb2/.claude/scripts/"
chmod +x "$lusb2/.claude/scripts/update.sh"
printf '#!/bin/sh\nexit 0\n' > "$lusb2/.claude/tests/run.sh"
chmod +x "$lusb2/.claude/tests/run.sh"
( cd "$lusb2" && git add -A && git commit -q -m "add the update engine under test, and a passing check stub" )

lusb2run() { ( cd "$lusb2" && sh .claude/scripts/update.sh "$@" < /dev/null ) 2>&1; }
statusout=$(lusb2run --status)
check "set-base pipeline: status reports base=unknown before set-base" has "$statusout" 'base=unknown'
check "set-base pipeline: status reports clean=yes before set-base" has "$statusout" 'clean=yes'
lusb2run --detect-base >/dev/null
lusb2run --set-base "$lubase" >/dev/null
check "set-base pipeline: the tree is clean right after set-base, with no manual commit" \
  match_eq "$( cd "$lusb2" && git status --porcelain )" ""
lusb2run --plan >/dev/null
cp "$luwork/decisions-none.tsv" "$luwork/decisions-setbase.tsv"
applyout3=$(lusb2run --apply "$luwork/decisions-setbase.tsv")
check "set-base pipeline: status -> detect-base -> set-base -> plan -> apply reaches applied" \
  has "$applyout3" 'result=applied'

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

# ------------------------------------------------------ notes.tsv / adapt.tsv
# --plan now also writes notes.tsv (every improvement note present upstream
# and absent at the founder's base, by presence -- never by the date on its
# own release folder) and adapt.tsv (one row per held path, with the three
# sides saved to disk for a founder-facing worker to adapt from).

lntwork=${TMPDIR:-/tmp}/lh-update-notes-test.$$
trap 'rm -rf "$lntwork"' EXIT
lntup="$lntwork/upstream"
lntfounder="$lntwork/founder"
mkdir -p "$lntup" "$lntfounder" || exit 1

( cd "$lntup" && git init -q && git config user.name Up && git config user.email up@example.com )

lntwrite() { # relative path, content
  mkdir -p "$lntup/$(dirname "$1")"
  printf '%s\n' "$2" > "$lntup/$1"
}

# --- commit 1: the founder's base. Carries one note already (an "old"
# note, present before the founder's copy started -- must never show up in
# notes.tsv).
lntwrite .claude/launchhouse-upstream "$lntup"
lntwrite .claude/updates/2026-01-01/old-note.md "---
id: old-note
title: Already here before the founder's base
purpose: >
  Prove a note already present at base never appears in notes.tsv.
touches:
  - .claude/conflict-me.md
adds: []
requires: []
safety: false
done-when:
  - \"never checked\"
check: none
founder-data: false
---

## What changed and why

Old note, already applied before this founder's copy exists."
lntwrite .claude/conflict-me.md "conflict v1"
lntwrite .claude/settings.json "settings v1"
( cd "$lntup" && git add -A && git commit -q -m commit1 )
lntbase=$( cd "$lntup" && git rev-parse HEAD )

# --- commit 2: upstream's further changes, plus a brand new note (added
# after the founder's base) touching the same conflicting file, and a
# second, safety note touching settings.json.
lntwrite .claude/conflict-me.md "conflict v2-upstream"
lntwrite .claude/settings.json "settings v2-upstream"
lntwrite .claude/updates/2026-02-01/new-note.md "---
id: new-note
title: A new improvement
purpose: >
  Test purpose text for the new note.
touches:
  - .claude/conflict-me.md
adds: []
requires: []
safety: false
done-when:
  - \"a sentence\"
check: new-note.check.sh
founder-data: false
---

## What changed and why

New note, added after this founder's base -- must appear in notes.tsv."
lntwrite .claude/updates/2026-02-01/new-note.check.sh "#!/bin/sh
# new-note's own check, for the notes/<id>.check.sh copy test only.
exit 0"
lntwrite .claude/updates/2026-02-01/settings-note.md "---
id: settings-note
title: A safety improvement touching settings
purpose: >
  Test purpose text for the safety note.
touches:
  - .claude/settings.json
adds: []
requires: []
safety: true
done-when:
  - \"a sentence\"
check: none
founder-data: false
---

## What changed and why

Safety note touching settings.json."
( cd "$lntup" && git add -A && git commit -q -m commit2 )

# --- the founder's copy: template-style, from commit1, with its own
# changes to both conflict-me.md and settings.json so both end up held.
( cd "$lntup" && git archive "$lntbase" ) | ( cd "$lntfounder" && tar -x )
(
  cd "$lntfounder" && git init -q && git config user.name Founder && git config user.email f@example.com &&
  git add -A && git commit -q -m "Initial import from template" &&
  git remote add upstream "$lntup"
)
mkdir -p "$lntfounder/.claude/scripts"
cp "$scripts/update.sh" "$scripts/lib.sh" "$lntfounder/.claude/scripts/"
chmod +x "$lntfounder/.claude/scripts/update.sh"
( cd "$lntfounder" && git add -A && git commit -q -m "add the update engine under test" )

printf 'conflict v2-founder\n' > "$lntfounder/.claude/conflict-me.md"
printf 'settings v2-founder\n' > "$lntfounder/.claude/settings.json"
( cd "$lntfounder" && git add -A && git commit -q -m "founder edits" )

lnt() { ( cd "$lntfounder" && sh .claude/scripts/update.sh "$@" < /dev/null ) 2>&1; }
lnt --detect-base >/dev/null
lnt --set-base "$lntbase" >/dev/null
( cd "$lntfounder" && git add -A && git commit -q -m "record the base version" )

lnt --plan >/dev/null
lntnotestsv="$lntfounder/.git/launchhouse/update/notes.tsv"
lntadapttsv="$lntfounder/.git/launchhouse/update/adapt.tsv"

check "notes.tsv never lists a note already present at the founder's base" \
  hasnt "$(cat "$lntnotestsv" 2>/dev/null)" 'old-note'
check "notes.tsv lists a note added after the founder's base" \
  has "$(cat "$lntnotestsv" 2>/dev/null)" 'new-note'
check "notes.tsv records the note's safety field" \
  has "$(grep '^new-note	' "$lntnotestsv" 2>/dev/null)" '	false	'
check "notes.tsv records the note's touches" \
  has "$(grep '^new-note	' "$lntnotestsv" 2>/dev/null)" '.claude/conflict-me.md'
check "notes.tsv lists the safety note too" \
  has "$(cat "$lntnotestsv" 2>/dev/null)" 'settings-note'
check "and records safety=true for it" \
  has "$(grep '^settings-note	' "$lntnotestsv" 2>/dev/null)" '	true	'

# --- notes.tsv column 2 is the note's own copy, relative to the STATE
# DIR (never the live .claude/updates/ path) -- --plan copies every
# applying note, and its check file when it names one other than "none",
# to $state/notes/<id>.md and $state/notes/<id>.check.sh.
lnt_newnote_col2=$(awk -F '\t' '$1 == "new-note" { print $2 }' "$lntnotestsv")
check "notes.tsv's own path column is relative to the state dir, not the repo" \
  match_eq "$lnt_newnote_col2" "notes/new-note.md"
check "and that copy actually exists, at the state dir" \
  test -f "$lntfounder/.git/launchhouse/update/$lnt_newnote_col2"
check "and it holds the upstream note's own content" \
  has "$(cat "$lntfounder/.git/launchhouse/update/$lnt_newnote_col2" 2>/dev/null)" 'New note, added after this founder'
check "the note's own check file was copied alongside it" \
  test -f "$lntfounder/.git/launchhouse/update/notes/new-note.check.sh"
check "and it holds the upstream check's own content" \
  has "$(cat "$lntfounder/.git/launchhouse/update/notes/new-note.check.sh" 2>/dev/null)" "new-note's own check"
check "a note whose check is \"none\" never gets a copied check file" \
  test ! -f "$lntfounder/.git/launchhouse/update/notes/settings-note.check.sh"

check "adapt.tsv holds a row for the conflicting file" \
  has "$(cat "$lntadapttsv" 2>/dev/null)" '.claude/conflict-me.md'
check "adapt.tsv links the conflict row to the note that touches it" \
  has "$(grep '^\.claude/conflict-me\.md	' "$lntadapttsv" 2>/dev/null)" 'new-note'
check "adapt.tsv holds a row for settings.json" \
  has "$(cat "$lntadapttsv" 2>/dev/null)" '.claude/settings.json'
check "adapt.tsv links the settings row to the safety note" \
  has "$(grep '^\.claude/settings\.json	' "$lntadapttsv" 2>/dev/null)" 'settings-note'

lnt_conflict_row=$(grep '^\.claude/conflict-me\.md	' "$lntadapttsv")
lnt_base_field=$(printf '%s' "$lnt_conflict_row" | awk -F '\t' '{print $3}')
lnt_theirs_field=$(printf '%s' "$lnt_conflict_row" | awk -F '\t' '{print $4}')
lnt_mine_field=$(printf '%s' "$lnt_conflict_row" | awk -F '\t' '{print $5}')
check "adapt.tsv's base-copy field names a real saved file" \
  test -f "$lntfounder/.git/launchhouse/update/$lnt_base_field"
check "and it holds the base version" \
  match_eq "$(cat "$lntfounder/.git/launchhouse/update/$lnt_base_field" 2>/dev/null)" 'conflict v1'
check "adapt.tsv's theirs-copy field holds the upstream version" \
  match_eq "$(cat "$lntfounder/.git/launchhouse/update/$lnt_theirs_field" 2>/dev/null)" 'conflict v2-upstream'
check "adapt.tsv's mine-copy field holds the founder's own version" \
  match_eq "$(cat "$lntfounder/.git/launchhouse/update/$lnt_mine_field" 2>/dev/null)" 'conflict v2-founder'

# --- adapt-save validation: a path outside adapt.tsv, and a growth-engine
# path, are both refused outright.
lnt_dummy="$lntwork/dummy-body.txt"
printf 'dummy\n' > "$lnt_dummy"
lnt_outside=$(lnt --adapt-save .claude/launchhouse-upstream "$lnt_dummy" -)
check "adapt-save refuses a path that is not a held row in adapt.tsv" has "$lnt_outside" 'result=refused'
check "and names why" has "$lnt_outside" 'not a held path'
lnt_ge=$(lnt --adapt-save growth-engine/founder-work.md "$lnt_dummy" -)
check "adapt-save refuses a growth-engine/ path outright" has "$lnt_ge" 'result=refused'

# --- adapt-save's third argument (note ids): a body that claims a note id
# not actually listed for that path in adapt.tsv is refused; the real,
# approved note id ("new-note", the one adapt.tsv itself links to
# conflict-me.md above) is accepted and recorded.
lnt_bad_note=$(lnt --adapt-save .claude/conflict-me.md "$lnt_dummy" bogus-note-id)
check "adapt-save refuses a note id not listed for that path in adapt.tsv" has "$lnt_bad_note" 'result=refused'
check "and names why" has "$lnt_bad_note" 'note id'

lnt_good_note=$(lnt --adapt-save .claude/conflict-me.md "$lnt_dummy" new-note)
check "adapt-save accepts a note id that adapt.tsv actually lists for the path" has "$lnt_good_note" 'saved=.claude/conflict-me.md'
lntadaptedtsv="$lntfounder/.git/launchhouse/update/adapted.tsv"
check "adapted.tsv records the approved note id alongside the path" \
  has "$(grep '^\.claude/conflict-me\.md	' "$lntadaptedtsv" 2>/dev/null)" 'new-note'

rm -rf "$lntwork"

# --------------------------------------------- adapt-save: symlink refused
# A held path whose upstream or founder side is a symlink (git mode
# 120000) is never eligible for adaptation, whichever side carries it.

lhsymwork=${TMPDIR:-/tmp}/lh-update-adapt-symlink-test.$$
trap 'rm -rf "$lhsymwork"' EXIT
lhsymup="$lhsymwork/upstream"
lhsymfounder="$lhsymwork/founder"
mkdir -p "$lhsymup" "$lhsymfounder" || exit 1

( cd "$lhsymup" && git init -q && git config user.name Up && git config user.email up@example.com )
mkdir -p "$lhsymup/.claude"
printf '%s\n' "$lhsymup" > "$lhsymup/.claude/launchhouse-upstream"
printf 'sym-target v1\n' > "$lhsymup/.claude/sym-me.md"
printf 'v1\n' > "$lhsymup/.claude/sym-me3.md"
( cd "$lhsymup" && git add -A && git commit -q -m commit1 )
lhsymbase=$( cd "$lhsymup" && git rev-parse HEAD )

# Upstream turns sym-me.md into a symlink; sym-me3.md stays plain text.
( cd "$lhsymup" && rm -f .claude/sym-me.md && ln -s launchhouse-upstream .claude/sym-me.md )
printf 'v2-upstream\n' > "$lhsymup/.claude/sym-me3.md"
( cd "$lhsymup" && git add -A && git commit -q -m "commit2: upstream makes one a symlink" )

( cd "$lhsymup" && git archive "$lhsymbase" ) | ( cd "$lhsymfounder" && tar -x )
(
  cd "$lhsymfounder" && git init -q && git config user.name Founder && git config user.email f@example.com &&
  git add -A && git commit -q -m "Initial import from template" &&
  git remote add upstream "$lhsymup"
)
mkdir -p "$lhsymfounder/.claude/scripts"
cp "$scripts/update.sh" "$scripts/lib.sh" "$lhsymfounder/.claude/scripts/"
chmod +x "$lhsymfounder/.claude/scripts/update.sh"
( cd "$lhsymfounder" && git add -A && git commit -q -m "add the update engine under test" )

# The founder changed sym-me.md too (plain text) -- genuinely held, both
# sides changed since base, and upstream's own side is a symlink. The
# founder turns sym-me3.md into a symlink locally instead.
printf 'sym-target v2-founder\n' > "$lhsymfounder/.claude/sym-me.md"
( cd "$lhsymfounder" && rm -f .claude/sym-me3.md && ln -s some-target .claude/sym-me3.md )
( cd "$lhsymfounder" && git add -A && git commit -q -m "founder edits" )

lhsym() { ( cd "$lhsymfounder" && sh .claude/scripts/update.sh "$@" < /dev/null ) 2>&1; }
lhsym --detect-base >/dev/null
lhsym --set-base "$lhsymbase" >/dev/null
( cd "$lhsymfounder" && git add -A && git commit -q -m "record the base version" )
lhsym --plan >/dev/null

lhsym_dummy="$lhsymwork/dummy.txt"
printf 'dummy\n' > "$lhsym_dummy"
lhsymsaveout=$(lhsym --adapt-save .claude/sym-me.md "$lhsym_dummy" -)
check "adapt-save refuses when the upstream side is a symlink" has "$lhsymsaveout" 'result=refused'
check "and names why" has "$lhsymsaveout" 'symlink'

lhsymsaveout2=$(lhsym --adapt-save .claude/sym-me3.md "$lhsym_dummy" -)
check "adapt-save refuses when the founder's own side is a symlink" has "$lhsymsaveout2" 'result=refused'
check "and names why" has "$lhsymsaveout2" 'symlink'

rm -rf "$lhsymwork"

# ------------------------------- adapt-save: CRLF, and the adapted decision
# The stored body's line endings are made to match the founder's own copy,
# never left at whatever the adapting worker's plain-LF text used. And a
# decision of "adapted" with no saved body is refused, never silently
# no-op'd like an unrecognised decision would be.

lhadwork=${TMPDIR:-/tmp}/lh-update-adapt-test.$$
trap 'rm -rf "$lhadwork"' EXIT
lhadup="$lhadwork/upstream"
lhadfounder="$lhadwork/founder"
mkdir -p "$lhadup" "$lhadfounder" || exit 1

( cd "$lhadup" && git init -q && git config user.name Up && git config user.email up@example.com )
mkdir -p "$lhadup/.claude"
printf '%s\n' "$lhadup" > "$lhadup/.claude/launchhouse-upstream"
printf 'held v1\n' > "$lhadup/.claude/held-me.md"
( cd "$lhadup" && git add -A && git commit -q -m commit1 )
lhadbase=$( cd "$lhadup" && git rev-parse HEAD )

printf 'held v2-upstream\n' > "$lhadup/.claude/held-me.md"
( cd "$lhadup" && git add -A && git commit -q -m commit2 )

( cd "$lhadup" && git archive "$lhadbase" ) | ( cd "$lhadfounder" && tar -x )
(
  cd "$lhadfounder" && git init -q && git config user.name Founder && git config user.email f@example.com &&
  git add -A && git commit -q -m "Initial import from template" &&
  git remote add upstream "$lhadup"
)
mkdir -p "$lhadfounder/.claude/scripts" "$lhadfounder/.claude/tests"
cp "$scripts/update.sh" "$scripts/lib.sh" "$lhadfounder/.claude/scripts/"
chmod +x "$lhadfounder/.claude/scripts/update.sh"
printf '#!/bin/sh\nexit 0\n' > "$lhadfounder/.claude/tests/run.sh"
chmod +x "$lhadfounder/.claude/tests/run.sh"
( cd "$lhadfounder" && git add -A && git commit -q -m "add the update engine under test" )

# The founder's own copy is CRLF -- a Windows founder's line endings.
printf 'held v2-founder\r\n' > "$lhadfounder/.claude/held-me.md"
( cd "$lhadfounder" && git add -A && git commit -q -m "founder edits, CRLF" )

lhad() { ( cd "$lhadfounder" && sh .claude/scripts/update.sh "$@" < /dev/null ) 2>&1; }
lhad --detect-base >/dev/null
lhad --set-base "$lhadbase" >/dev/null
( cd "$lhadfounder" && git add -A && git commit -q -m "record the base version" )
lhad --plan >/dev/null

lhadadapttsv="$lhadfounder/.git/launchhouse/update/adapt.tsv"
check "held-me.md is a held row ready to adapt" has "$(cat "$lhadadapttsv" 2>/dev/null)" '.claude/held-me.md'

cat > "$lhadwork/decisions-adapted.tsv" <<EOF
.claude/held-me.md	adapted
EOF

lhadmissout=$( ( cd "$lhadfounder" && sh .claude/scripts/update.sh --apply "$lhadwork/decisions-adapted.tsv" < /dev/null ) 2>&1 )
check "apply refuses an 'adapted' decision with no saved body" has "$lhadmissout" 'result=aborted'
check "and names why" has "$lhadmissout" 'no adapted body was saved'
check "and never moves HEAD" match_eq "$( cd "$lhadfounder" && git rev-parse HEAD )" "$( cd "$lhadfounder" && git log --format=%H -1 )"

# --- an empty adapted body is refused outright, never saved as an empty
# file a founder would then land.
lhad_empty="$lhadwork/empty-body.txt"
: > "$lhad_empty"
lhademptyout=$(lhad --adapt-save .claude/held-me.md "$lhad_empty" -)
check "adapt-save refuses an empty body" has "$lhademptyout" 'result=refused'
check "and names why" has "$lhademptyout" 'empty'

lhad_body="$lhadwork/adapted-body.txt"
printf 'held, adapted: keeps the founders v2 note and brings in the upstream change\n' > "$lhad_body"

lhadsaveout=$(lhad --adapt-save .claude/held-me.md "$lhad_body" -)
check "adapt-save reports saved" has "$lhadsaveout" 'saved=.claude/held-me.md'

lhadmerged="$lhadfounder/.git/launchhouse/update/merged/.claude/held-me.md"
check "adapt-save wrote the merged body" test -f "$lhadmerged"
lhad_cr=$(printf '\r')
check "adapt-save matched the founder's own CRLF line endings, not the plain LF body it was given" \
  grep -q "$lhad_cr" "$lhadmerged"

lhadapplyout=$( ( cd "$lhadfounder" && sh .claude/scripts/update.sh --apply "$lhadwork/decisions-adapted.tsv" < /dev/null ) 2>&1 )
check "apply succeeds once the adapted body is saved" has "$lhadapplyout" 'result=applied'
check "held-me.md now carries the adapted content" \
  has "$(cat "$lhadfounder/.claude/held-me.md" 2>/dev/null)" 'keeps the founders v2 note'
check "and it is still CRLF on disk, matching the founder's own copy" \
  grep -q "$lhad_cr" "$lhadfounder/.claude/held-me.md"

rm -rf "$lhadwork"

# --------------------------------------------------- adapt-save: JSON validity
# For a path ending in .json, adapt-save runs .claude/scripts/json-valid.sh
# on the body and refuses anything that fails it; if the validator itself
# is not present on this founder's copy at all, a .json body is refused
# outright (fail closed) rather than risk writing something broken.

lhjvwork=${TMPDIR:-/tmp}/lh-update-adapt-json-test.$$
trap 'rm -rf "$lhjvwork"' EXIT
lhjvup="$lhjvwork/upstream"
mkdir -p "$lhjvup" || exit 1
( cd "$lhjvup" && git init -q && git config user.name Up && git config user.email up@example.com )
mkdir -p "$lhjvup/.claude"
printf '%s\n' "$lhjvup" > "$lhjvup/.claude/launchhouse-upstream"
printf '{ "v": 1 }\n' > "$lhjvup/.claude/held.json"
( cd "$lhjvup" && git add -A && git commit -q -m commit1 )
lhjvbase=$( cd "$lhjvup" && git rev-parse HEAD )
printf '{ "v": 2 }\n' > "$lhjvup/.claude/held.json"
( cd "$lhjvup" && git add -A && git commit -q -m commit2 )

lhjv_valid_body="$lhjvwork/valid-body.json"
printf '{ "v": "merged" }\n' > "$lhjv_valid_body"
lhjv_invalid_body="$lhjvwork/invalid-body.json"
printf '{ "v": "unterminated\n' > "$lhjv_invalid_body"

# --- fixture A: no json-valid.sh present at all -- a .json body is
# refused outright (fail closed), whatever it contains.
lhjvnovf="$lhjvwork/no-validator"
mkdir -p "$lhjvnovf"
( cd "$lhjvup" && git archive "$lhjvbase" ) | ( cd "$lhjvnovf" && tar -x )
(
  cd "$lhjvnovf" && git init -q && git config user.name Founder && git config user.email f@example.com &&
  git add -A && git commit -q -m "Initial import from template" &&
  git remote add upstream "$lhjvup"
)
mkdir -p "$lhjvnovf/.claude/scripts"
cp "$scripts/update.sh" "$scripts/lib.sh" "$lhjvnovf/.claude/scripts/"
chmod +x "$lhjvnovf/.claude/scripts/update.sh"
( cd "$lhjvnovf" && git add -A && git commit -q -m "add the update engine under test, no json-valid.sh" )
printf 'founder edit\n' > "$lhjvnovf/.claude/held.json"
( cd "$lhjvnovf" && git add -A && git commit -q -m "founder edits" )

lhjvnov() { ( cd "$lhjvnovf" && sh .claude/scripts/update.sh "$@" < /dev/null ) 2>&1; }
lhjvnov --detect-base >/dev/null
lhjvnov --set-base "$lhjvbase" >/dev/null
( cd "$lhjvnovf" && git add -A && git commit -q -m "record the base version" )
lhjvnov --plan >/dev/null

lhjvnovout=$(lhjvnov --adapt-save .claude/held.json "$lhjv_valid_body" -)
check "adapt-save refuses a .json body outright when json-valid.sh is not present (fail closed)" \
  has "$lhjvnovout" 'result=refused'
check "and names why" has "$lhjvnovout" 'json-valid.sh is not available'

# --- fixture B: json-valid.sh present (the real one, once worker R's own
# interface has landed on this branch; a stub otherwise) -- a valid JSON
# body is always accepted.
lhjvokf="$lhjvwork/with-validator"
mkdir -p "$lhjvokf"
( cd "$lhjvup" && git archive "$lhjvbase" ) | ( cd "$lhjvokf" && tar -x )
(
  cd "$lhjvokf" && git init -q && git config user.name Founder && git config user.email f@example.com &&
  git add -A && git commit -q -m "Initial import from template" &&
  git remote add upstream "$lhjvup"
)
mkdir -p "$lhjvokf/.claude/scripts"
cp "$scripts/update.sh" "$scripts/lib.sh" "$lhjvokf/.claude/scripts/"
chmod +x "$lhjvokf/.claude/scripts/update.sh"
install_json_valid_stub "$lhjvokf"
( cd "$lhjvokf" && git add -A && git commit -q -m "add the update engine under test, with json-valid.sh" )
printf 'founder edit\n' > "$lhjvokf/.claude/held.json"
( cd "$lhjvokf" && git add -A && git commit -q -m "founder edits" )

lhjvok() { ( cd "$lhjvokf" && sh .claude/scripts/update.sh "$@" < /dev/null ) 2>&1; }
lhjvok --detect-base >/dev/null
lhjvok --set-base "$lhjvbase" >/dev/null
( cd "$lhjvokf" && git add -A && git commit -q -m "record the base version" )
lhjvok --plan >/dev/null

lhjvokout=$(lhjvok --adapt-save .claude/held.json "$lhjv_valid_body" -)
check "adapt-save accepts a valid JSON body once json-valid.sh is present" has "$lhjvokout" 'saved=.claude/held.json'

# Invalid JSON is only asserted for real once the real validator has
# landed on this branch (worker R's own interface, a separate PR); the
# stub used until then accepts everything, so asserting a refusal against
# it would be testing the stub, not the fix. This prints SKIP, not a
# FAIL, so the merge does not need to come back here to un-break it.
if [ -f "$scripts/json-valid.sh" ]; then
  lhjvbadout=$(lhjvok --adapt-save .claude/held.json "$lhjv_invalid_body" -)
  check "adapt-save refuses invalid JSON once json-valid.sh is real" has "$lhjvbadout" 'result=refused'
else
  printf 'SKIP  invalid-json refused (validator not present on this branch)\n'
fi

rm -rf "$lhjvwork"

# --- fixture C: adapt-save must validate against UPSTREAM's own copy of
# json-valid.sh (saved into state at --plan time), never the founder's live
# copy -- a founder's live copy could have been altered (by the founder, or
# anything running on their machine) to always exit 0, silently defeating
# this safety check. Upstream carries the real validator; the founder's
# live .claude/scripts/json-valid.sh is a stub that always passes. If
# adapt-save used the live copy, an invalid JSON body would be wrongly
# accepted; using upstream's own copy, it is refused.

lhjcwork=${TMPDIR:-/tmp}/lh-update-adapt-json-upstream-test.$$
trap 'rm -rf "$lhjcwork"' EXIT
lhjcup="$lhjcwork/upstream"
lhjcfounder="$lhjcwork/founder"
mkdir -p "$lhjcup" "$lhjcfounder" || exit 1

( cd "$lhjcup" && git init -q && git config user.name Up && git config user.email up@example.com )
mkdir -p "$lhjcup/.claude/scripts"
printf '%s\n' "$lhjcup" > "$lhjcup/.claude/launchhouse-upstream"
printf '{ "v": 1 }\n' > "$lhjcup/.claude/held.json"
# Upstream ships the REAL json-valid.sh (this repo's own copy) from the
# very first commit onward.
cp "$scripts/json-valid.sh" "$lhjcup/.claude/scripts/json-valid.sh"
chmod +x "$lhjcup/.claude/scripts/json-valid.sh"
( cd "$lhjcup" && git add -A && git commit -q -m commit1 )
lhjcbase=$( cd "$lhjcup" && git rev-parse HEAD )
printf '{ "v": 2 }\n' > "$lhjcup/.claude/held.json"
( cd "$lhjcup" && git add -A && git commit -q -m "commit2: upstream changes held.json" )

( cd "$lhjcup" && git archive "$lhjcbase" ) | ( cd "$lhjcfounder" && tar -x )
(
  cd "$lhjcfounder" && git init -q && git config user.name Founder && git config user.email f@example.com &&
  git add -A && git commit -q -m "Initial import from template" &&
  git remote add upstream "$lhjcup"
)
mkdir -p "$lhjcfounder/.claude/scripts"
cp "$scripts/update.sh" "$scripts/lib.sh" "$lhjcfounder/.claude/scripts/"
chmod +x "$lhjcfounder/.claude/scripts/update.sh"
( cd "$lhjcfounder" && git add -A && git commit -q -m "add the update engine under test" )

# The founder's own LIVE json-valid.sh (whatever got imported from
# upstream's base) is now replaced with a stub that always exits 0 --
# standing in for "altered, by the founder or anything running on their
# machine, to always pass".
printf '#!/bin/sh\nexit 0\n' > "$lhjcfounder/.claude/scripts/json-valid.sh"
chmod +x "$lhjcfounder/.claude/scripts/json-valid.sh"
printf 'founder edit\n' > "$lhjcfounder/.claude/held.json"
( cd "$lhjcfounder" && git add -A && git commit -q -m "founder's live json-valid.sh always passes, and founder edits held.json" )

lhjc() { ( cd "$lhjcfounder" && sh .claude/scripts/update.sh "$@" < /dev/null ) 2>&1; }
lhjc --detect-base >/dev/null
lhjc --set-base "$lhjcbase" >/dev/null
( cd "$lhjcfounder" && git add -A && git commit -q -m "record the base version" )
lhjc --plan >/dev/null

lhjc_invalid_body="$lhjcwork/invalid-body.json"
printf '{ "v": "unterminated\n' > "$lhjc_invalid_body"
lhjcout=$(lhjc --adapt-save .claude/held.json "$lhjc_invalid_body" -)
check "adapt-save uses upstream's own json-valid.sh, not a founder copy that always passes" \
  has "$lhjcout" 'result=refused'
check "and gives a JSON reason, proving the real validator (not the live all-pass stub) ran" \
  has "$lhjcout" 'not valid JSON'

rm -rf "$lhjcwork"

# ------------------------------------------------- restore-settings-plan
# The post-bridge re-adaptation: a founder customized settings.json before
# a later update took it wholesale (take-theirs); --restore-settings-plan
# finds that moment and offers the founder's customisation back, as its
# own ordinary held row.

lhrswork=${TMPDIR:-/tmp}/lh-update-restore-test.$$
trap 'rm -rf "$lhrswork"' EXIT
lhrsup="$lhrswork/upstream"
lhrsfounder="$lhrswork/founder"
mkdir -p "$lhrsup" "$lhrsfounder" || exit 1

( cd "$lhrsup" && git init -q && git config user.name Up && git config user.email up@example.com )
mkdir -p "$lhrsup/.claude"
printf '%s\n' "$lhrsup" > "$lhrsup/.claude/launchhouse-upstream"
printf '{"v":"1"}\n' > "$lhrsup/.claude/settings.json"
( cd "$lhrsup" && git add -A && git commit -q -m commit1 )
lhrsbase=$( cd "$lhrsup" && git rev-parse HEAD )

printf '{"v":"2-upstream"}\n' > "$lhrsup/.claude/settings.json"
( cd "$lhrsup" && git add -A && git commit -q -m commit2 )

( cd "$lhrsup" && git archive "$lhrsbase" ) | ( cd "$lhrsfounder" && tar -x )
(
  cd "$lhrsfounder" && git init -q && git config user.name Founder && git config user.email f@example.com &&
  git add -A && git commit -q -m "Initial import from template" &&
  git remote add upstream "$lhrsup"
)
mkdir -p "$lhrsfounder/.claude/scripts" "$lhrsfounder/.claude/tests"
cp "$scripts/update.sh" "$scripts/lib.sh" "$lhrsfounder/.claude/scripts/"
chmod +x "$lhrsfounder/.claude/scripts/update.sh"
printf '#!/bin/sh\nexit 0\n' > "$lhrsfounder/.claude/tests/run.sh"
chmod +x "$lhrsfounder/.claude/tests/run.sh"
install_json_valid_stub "$lhrsfounder"
( cd "$lhrsfounder" && git add -A && git commit -q -m "add the update engine under test" )

# The founder customises settings.json early, before any update -- the
# same situation a founder on one of the template's first public releases
# was actually in.
printf '{"v":"1","founder":"tweak"}\n' > "$lhrsfounder/.claude/settings.json"
( cd "$lhrsfounder" && git add -A && git commit -q -m "founder customises settings.json" )

lhrs() { ( cd "$lhrsfounder" && sh .claude/scripts/update.sh "$@" < /dev/null ) 2>&1; }
lhrs --detect-base >/dev/null
lhrs --set-base "$lhrsbase" >/dev/null
( cd "$lhrsfounder" && git add -A && git commit -q -m "record the base version" )
lhrs --plan >/dev/null

cat > "$lhrswork/decisions-bridge.tsv" <<EOF
.claude/settings.json	take-theirs
EOF
lhrsbridgeout=$( ( cd "$lhrsfounder" && sh .claude/scripts/update.sh --apply "$lhrswork/decisions-bridge.tsv" < /dev/null ) 2>&1 )
check "restore fixture: the bridge update (take-theirs on settings.json) applies" has "$lhrsbridgeout" 'result=applied'

lhrsbridgetag=$( cd "$lhrsfounder" && git tag -l 'launchhouse-pre-update-*' | head -1 )
check "restore fixture: a pre-update tag was left behind" test -n "$lhrsbridgetag"

lhrsrestoreout=$(lhrs --restore-settings-plan)
check "restore-settings-plan finds the customised settings copy" has "$lhrsrestoreout" 'restore=found'
check "and names the settings path" has "$lhrsrestoreout" 'path=.claude/settings.json'
check "and names the tag it found" has "$lhrsrestoreout" "from_tag=$lhrsbridgetag"

# --- an interrupted offer (no apply, no decline in between) is offered
# again on the next call: nothing has decided this tag yet, so it must
# never be silently burned into restore-offered just for having been
# planned once. Only an actual decline (--restore-settings-decline) or a
# successful --apply of this same restore plan ever resolves it.
lhrsrestoreout2=$(lhrs --restore-settings-plan)
check "restore-settings-plan: an interrupted offer (no apply, no decline) is offered again on the next call" \
  has "$lhrsrestoreout2" 'restore=found'
check "and it is the same tag as before" has "$lhrsrestoreout2" "from_tag=$lhrsbridgetag"

lhrsadapttsv="$lhrsfounder/.git/launchhouse/update/adapt.tsv"
lhrsrow=$(grep '^\.claude/settings\.json	' "$lhrsadapttsv")
lhrs_base=$(printf '%s' "$lhrsrow" | awk -F '\t' '{print $3}')
lhrs_theirs=$(printf '%s' "$lhrsrow" | awk -F '\t' '{print $4}')
lhrs_mine=$(printf '%s' "$lhrsrow" | awk -F '\t' '{print $5}')
check "restore-settings-plan's mine-copy is the founder's original customisation" \
  match_eq "$(cat "$lhrsfounder/.git/launchhouse/update/$lhrs_mine" 2>/dev/null)" '{"v":"1","founder":"tweak"}'
check "restore-settings-plan's theirs-copy is the current live settings.json" \
  match_eq "$(cat "$lhrsfounder/.git/launchhouse/update/$lhrs_theirs" 2>/dev/null)" '{"v":"2-upstream"}'
check "restore-settings-plan's base-copy is that update's own base version" \
  match_eq "$(cat "$lhrsfounder/.git/launchhouse/update/$lhrs_base" 2>/dev/null)" '{"v":"1"}'

lhrs_body="$lhrswork/restore-adapted-body.txt"
printf '{"v":"2-upstream","founder":"tweak"}\n' > "$lhrs_body"
lhrssaveout=$(lhrs --adapt-save .claude/settings.json "$lhrs_body" -)
check "adapt-save accepts the restore's adapted settings.json body" has "$lhrssaveout" 'saved=.claude/settings.json'

cat > "$lhrswork/decisions-restore.tsv" <<EOF
.claude/settings.json	adapted
EOF
lhrsrestoreapplyout=$( ( cd "$lhrsfounder" && sh .claude/scripts/update.sh --apply "$lhrswork/decisions-restore.tsv" < /dev/null ) 2>&1 )
check "the restore plan applies as its own recorded update" has "$lhrsrestoreapplyout" 'result=applied'
check "settings.json now carries the re-adapted body" \
  has "$(cat "$lhrsfounder/.claude/settings.json" 2>/dev/null)" '"founder":"tweak"'
check "applied: a successful --apply of the restore plan resolves its pending tag into restore-offered" \
  grep -qxF "$lhrsbridgetag" "$lhrsfounder/.git/launchhouse/update/restore-offered"
check "applied: and the pending marker is cleared" \
  test ! -f "$lhrsfounder/.git/launchhouse/update/restore-pending"

lhrs_tags_after=$( cd "$lhrsfounder" && git tag -l 'launchhouse-pre-update-*' | wc -l | tr -d ' ' )
check "the restore's own apply left a second, distinct pre-update tag behind" match_eq "$lhrs_tags_after" 2

lhrsundoout=$( ( cd "$lhrsfounder" && sh .claude/scripts/update.sh --undo < /dev/null ) 2>&1 )
check "the restore's own update is itself undoable" has "$lhrsundoout" 'result=undone'
check "undo brings back the bridge-taken settings.json, not the founder's original" \
  match_eq "$(cat "$lhrsfounder/.claude/settings.json" 2>/dev/null)" '{"v":"2-upstream"}'

# --- no customisation to restore: --restore-settings-plan on a fresh
# founder copy with no pre-update tags at all says so plainly.
lhrs2work="$lhrswork-none"
mkdir -p "$lhrs2work"
( cd "$lhrsup" && git archive "$lhrsbase" ) | ( cd "$lhrs2work" && tar -x )
(
  cd "$lhrs2work" && git init -q && git config user.name Founder && git config user.email f@example.com &&
  git add -A && git commit -q -m "Initial import from template" &&
  git remote add upstream "$lhrsup"
)
mkdir -p "$lhrs2work/.claude/scripts"
cp "$scripts/update.sh" "$scripts/lib.sh" "$lhrs2work/.claude/scripts/"
chmod +x "$lhrs2work/.claude/scripts/update.sh"
( cd "$lhrs2work" && git add -A && git commit -q -m "add the update engine under test" )
lhrs2out=$( ( cd "$lhrs2work" && sh .claude/scripts/update.sh --restore-settings-plan < /dev/null ) 2>&1 )
check "restore-settings-plan says none when there is nothing to restore" has "$lhrs2out" 'restore=none'
rm -rf "$lhrs2work"

# --- restore=none when the adaptation would equal the current file: if
# what is live today already matches the founder's original customisation
# at the tag, word for word, there is nothing to restore -- this says
# restore=none rather than offering a pointless no-op change.
lhrs3work="$lhrswork-noop"
mkdir -p "$lhrs3work"
( cd "$lhrsup" && git archive "$lhrsbase" ) | ( cd "$lhrs3work" && tar -x )
(
  cd "$lhrs3work" && git init -q && git config user.name Founder && git config user.email f@example.com &&
  git add -A && git commit -q -m "Initial import from template" &&
  git remote add upstream "$lhrsup"
)
mkdir -p "$lhrs3work/.claude/scripts" "$lhrs3work/.claude/tests"
cp "$scripts/update.sh" "$scripts/lib.sh" "$lhrs3work/.claude/scripts/"
chmod +x "$lhrs3work/.claude/scripts/update.sh"
printf '#!/bin/sh\nexit 0\n' > "$lhrs3work/.claude/tests/run.sh"
chmod +x "$lhrs3work/.claude/tests/run.sh"
( cd "$lhrs3work" && git add -A && git commit -q -m "add the update engine under test" )

printf 'settings v1, with a founder tweak\n' > "$lhrs3work/.claude/settings.json"
( cd "$lhrs3work" && git add -A && git commit -q -m "founder customises settings.json" )

lhrs3() { ( cd "$lhrs3work" && sh .claude/scripts/update.sh "$@" < /dev/null ) 2>&1; }
lhrs3 --detect-base >/dev/null
lhrs3 --set-base "$lhrsbase" >/dev/null
( cd "$lhrs3work" && git add -A && git commit -q -m "record the base version" )
lhrs3 --plan >/dev/null

cat > "$lhrswork/decisions-bridge-noop.tsv" <<EOF
.claude/settings.json	take-theirs
EOF
lhrs3bridgeout=$( ( cd "$lhrs3work" && sh .claude/scripts/update.sh --apply "$lhrswork/decisions-bridge-noop.tsv" < /dev/null ) 2>&1 )
check "restore-noop fixture: the bridge update applies" has "$lhrs3bridgeout" 'result=applied'

# The founder manually puts their old customisation straight back, by
# hand, never through update.sh -- what is live now already IS the tag's
# own customisation, word for word.
printf 'settings v1, with a founder tweak\n' > "$lhrs3work/.claude/settings.json"
( cd "$lhrs3work" && git add -A && git commit -q -m "founder manually restores their own tweak by hand" )

lhrs3restoreout=$(lhrs3 --restore-settings-plan)
check "restore-settings-plan says none when the adaptation would equal the current file" \
  has "$lhrs3restoreout" 'restore=none'

rm -rf "$lhrs3work"

# --- declined: the founder says no to a found offer.
# --restore-settings-decline resolves whatever tag is pending, into
# restore-offered, so it is never offered again -- the same permanence a
# successful apply gets, just reached by the other path.
lhrs4work="$lhrswork-declined"
mkdir -p "$lhrs4work"
( cd "$lhrsup" && git archive "$lhrsbase" ) | ( cd "$lhrs4work" && tar -x )
(
  cd "$lhrs4work" && git init -q && git config user.name Founder && git config user.email f@example.com &&
  git add -A && git commit -q -m "Initial import from template" &&
  git remote add upstream "$lhrsup"
)
mkdir -p "$lhrs4work/.claude/scripts" "$lhrs4work/.claude/tests"
cp "$scripts/update.sh" "$scripts/lib.sh" "$lhrs4work/.claude/scripts/"
chmod +x "$lhrs4work/.claude/scripts/update.sh"
printf '#!/bin/sh\nexit 0\n' > "$lhrs4work/.claude/tests/run.sh"
chmod +x "$lhrs4work/.claude/tests/run.sh"
( cd "$lhrs4work" && git add -A && git commit -q -m "add the update engine under test" )

printf '{"v":"1","founder":"declined-tweak"}\n' > "$lhrs4work/.claude/settings.json"
( cd "$lhrs4work" && git add -A && git commit -q -m "founder customises settings.json" )

lhrs4() { ( cd "$lhrs4work" && sh .claude/scripts/update.sh "$@" < /dev/null ) 2>&1; }
lhrs4 --detect-base >/dev/null
lhrs4 --set-base "$lhrsbase" >/dev/null
( cd "$lhrs4work" && git add -A && git commit -q -m "record the base version" )
lhrs4 --plan >/dev/null

cat > "$lhrswork/decisions-bridge-declined.tsv" <<EOF
.claude/settings.json	take-theirs
EOF
lhrs4bridgeout=$( ( cd "$lhrs4work" && sh .claude/scripts/update.sh --apply "$lhrswork/decisions-bridge-declined.tsv" < /dev/null ) 2>&1 )
check "declined fixture: the bridge update applies" has "$lhrs4bridgeout" 'result=applied'

lhrs4tag=$( cd "$lhrs4work" && git tag -l 'launchhouse-pre-update-*' | head -1 )
check "declined fixture: a pre-update tag was left behind" test -n "$lhrs4tag"

lhrs4findout=$(lhrs4 --restore-settings-plan)
check "declined fixture: restore-settings-plan finds the customised settings copy" \
  has "$lhrs4findout" 'restore=found'

lhrs4declineout=$(lhrs4 --restore-settings-decline)
check "declined: --restore-settings-decline reports the declined tag" \
  has "$lhrs4declineout" "declined=$lhrs4tag"

lhrs4afterdeclineout=$(lhrs4 --restore-settings-plan)
check "declined: after a decline, the same tag is never offered again" \
  has "$lhrs4afterdeclineout" 'restore=none'

lhrs4declinenoneout=$(lhrs4 --restore-settings-decline)
check "declined: declining again with nothing pending reports declined=none" \
  has "$lhrs4declinenoneout" 'declined=none'

rm -rf "$lhrs4work"

rm -rf "$lhrswork"

# --------------------------------------------------- post-landing fail-safe
# A check that only ever runs once the update is actually live -- never
# inside the throwaway apply worktree -- fails: the update is undone
# automatically, the same guarded path --undo uses, and the founder is
# told plainly rather than left in a half-updated folder.

# --- hook checks: run against a throwaway copy, never the live folder
# (growth-engine/ must never move, not even as a side effect of proving a
# hook still starts); "failed to start" is never decided by a guard's own
# stderr wording (exit 2 with a noisy "not found" message must still land);
# a genuinely missing script must still revert. Each round below adds one
# new upstream commit AFTER the previous round's apply -- never all up
# front -- so each --plan actually sees only that round's own change,
# the same way a founder would meet these one release at a time.

lhhkwork=${TMPDIR:-/tmp}/lh-update-postsmoke-hooks-test.$$
trap 'rm -rf "$lhhkwork"' EXIT
lhhkup="$lhhkwork/upstream"
lhhkfounder="$lhhkwork/founder"
mkdir -p "$lhhkup" "$lhhkfounder" || exit 1

( cd "$lhhkup" && git init -q && git config user.name Up && git config user.email up@example.com )
mkdir -p "$lhhkup/.claude/scripts"

lhhk_settings_for() { # hook-script-name -> writes $lhhkup/.claude/settings.json
  cat > "$lhhkup/.claude/settings.json" <<EOF
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "sh \"\$CLAUDE_PROJECT_DIR/.claude/scripts/$1\""
          }
        ]
      }
    ]
  }
}
EOF
}

cat > "$lhhkup/.claude/scripts/hook-good.sh" <<'SCRIPT'
#!/bin/sh
mkdir -p "$CLAUDE_PROJECT_DIR/growth-engine/.state" 2>/dev/null
printf 'touched by hook-good.sh\n' >> "$CLAUDE_PROJECT_DIR/growth-engine/.state/index.md" 2>/dev/null
exit 0
SCRIPT
cat > "$lhhkup/.claude/scripts/hook-noisy.sh" <<'SCRIPT'
#!/bin/sh
echo "thing not found, continuing anyway" >&2
exit 2
SCRIPT

# --- commit 1: the founder's base. settings.json wires up hook-good.sh,
# which actually writes under growth-engine/ (relative to
# $CLAUDE_PROJECT_DIR) when it runs -- the exact shape of a real hook.
printf '%s\n' "$lhhkup" > "$lhhkup/.claude/launchhouse-upstream"
printf 'take v1\n' > "$lhhkup/.claude/take-me.md"
lhhk_settings_for hook-good.sh
( cd "$lhhkup" && git add -A && git commit -q -m commit1 )
lhhkbase=$( cd "$lhhkup" && git rev-parse HEAD )

( cd "$lhhkup" && git archive "$lhhkbase" ) | ( cd "$lhhkfounder" && tar -x )
(
  cd "$lhhkfounder" && git init -q && git config user.name Founder && git config user.email f@example.com &&
  git add -A && git commit -q -m "Initial import from template" &&
  git remote add upstream "$lhhkup"
)
mkdir -p "$lhhkfounder/.claude/scripts" "$lhhkfounder/.claude/tests"
cp "$scripts/update.sh" "$scripts/lib.sh" "$lhhkfounder/.claude/scripts/"
chmod +x "$lhhkfounder/.claude/scripts/update.sh"
printf '#!/bin/sh\nexit 0\n' > "$lhhkfounder/.claude/tests/run.sh"
chmod +x "$lhhkfounder/.claude/tests/run.sh"
( cd "$lhhkfounder" && git add -A && git commit -q -m "add the update engine under test" )

# The founder's own real growth-engine work: a tracked
# growth-engine/.state/index.md, so a hook that actually ran a refresh
# against the LIVE folder would have changed it.
mkdir -p "$lhhkfounder/growth-engine/.state"
printf '# Index\n\nfounder state, must never move\n' > "$lhhkfounder/growth-engine/.state/index.md"
: > "$lhhkfounder/growth-engine/.launchhouse"
( cd "$lhhkfounder" && git add -A && git commit -q -m "founder's own growth-engine work" )

lhhk() { ( cd "$lhhkfounder" && sh .claude/scripts/update.sh "$@" < /dev/null ) 2>&1; }
lhhk --detect-base >/dev/null
lhhk --set-base "$lhhkbase" >/dev/null
( cd "$lhhkfounder" && git add -A && git commit -q -m "record the base version" )

ge_index_before=$(cksum_of "$lhhkfounder/growth-engine/.state/index.md")

# --- round A: commit2, an ordinary change, hook-good.sh already wired up
# from base. Proves the good path, and growth-engine isolation.
printf 'take v2\n' > "$lhhkup/.claude/take-me.md"
( cd "$lhhkup" && git add -A && git commit -q -m commit2 )

lhhk --plan >/dev/null
cat > "$lhhkwork/decisions-a.tsv" <<EOF
.claude/take-me.md	apply
EOF
lhhkout_a=$( ( cd "$lhhkfounder" && sh .claude/scripts/update.sh --apply "$lhhkwork/decisions-a.tsv" < /dev/null ) 2>&1 )
check "post-landing smoke: a good update with a real growth-engine-writing hook still applies" has "$lhhkout_a" 'result=applied'
check "post-landing smoke: no revert on the good update" hasnt "$lhhkout_a" 'result=reverted'
check "post-landing smoke: growth-engine/.state/index.md is byte-identical after -- the hook is never actually run at all, only its script path checked" \
  match_eq "$(cksum_of "$lhhkfounder/growth-engine/.state/index.md")" "$ge_index_before"

# --- round B: commit3, settings.json now runs hook-noisy.sh, which prints
# a "not found" message and exits 2 -- must land, not revert.
printf 'take v3\n' > "$lhhkup/.claude/take-me.md"
lhhk_settings_for hook-noisy.sh
( cd "$lhhkup" && git add -A && git commit -q -m commit3 )

lhhk --plan >/dev/null
cat > "$lhhkwork/decisions-b.tsv" <<EOF
.claude/take-me.md	apply
.claude/settings.json	apply
EOF
lhhkout_b=$( ( cd "$lhhkfounder" && sh .claude/scripts/update.sh --apply "$lhhkwork/decisions-b.tsv" < /dev/null ) 2>&1 )
check "post-landing smoke: a hook that prints 'not found' but exits 2 still lands" has "$lhhkout_b" 'result=applied'
check "post-landing smoke: no revert just because a hook's own message mentions 'not found'" hasnt "$lhhkout_b" 'result=reverted'
check "post-landing smoke: growth-engine/.state/index.md is still byte-identical" \
  match_eq "$(cksum_of "$lhhkfounder/growth-engine/.state/index.md")" "$ge_index_before"

# --- round C: commit4, settings.json now names a hook script that is
# never shipped anywhere -- a genuine "cannot start", must revert.
printf 'take v4\n' > "$lhhkup/.claude/take-me.md"
lhhk_settings_for hook-missing.sh
( cd "$lhhkup" && git add -A && git commit -q -m commit4 )

lhhk --plan >/dev/null
cat > "$lhhkwork/decisions-c.tsv" <<EOF
.claude/take-me.md	apply
.claude/settings.json	apply
EOF
lhhkout_c=$( ( cd "$lhhkfounder" && sh .claude/scripts/update.sh --apply "$lhhkwork/decisions-c.tsv" < /dev/null ) 2>&1 )
check "post-landing smoke: a hook naming a script that does not exist reports reverted" has "$lhhkout_c" 'result=reverted'
check "and the automatic undo brings take-me.md back to its pre-this-update value" \
  has "$(cat "$lhhkfounder/.claude/take-me.md" 2>/dev/null)" 'take v3'
check "and settings.json is back to running hook-noisy.sh" \
  has "$(cat "$lhhkfounder/.claude/settings.json" 2>/dev/null)" 'hook-noisy.sh'
check "post-landing smoke: growth-engine/.state/index.md is still byte-identical after the revert" \
  match_eq "$(cksum_of "$lhhkfounder/growth-engine/.state/index.md")" "$ge_index_before"

# --- round D: commit5, settings.json now runs a hook that -- IF it were
# actually executed -- leaves an unmistakable marker file directly under
# the live folder root, outside growth-engine entirely. It exists, is
# readable, and has no syntax error, so post-landing smoke has nothing to
# fail on; the point of this round is proving it is never run at all.
cat > "$lhhkup/.claude/scripts/hook-dangerous.sh" <<'SCRIPT'
#!/bin/sh
: > "$CLAUDE_PROJECT_DIR/hook-actually-ran.marker"
exit 0
SCRIPT
printf 'take v5\n' > "$lhhkup/.claude/take-me.md"
lhhk_settings_for hook-dangerous.sh
( cd "$lhhkup" && git add -A && git commit -q -m commit5 )

lhhk --plan >/dev/null
cat > "$lhhkwork/decisions-d.tsv" <<EOF
.claude/take-me.md	apply
.claude/settings.json	apply
.claude/scripts/hook-dangerous.sh	apply
EOF
lhhkout_d=$( ( cd "$lhhkfounder" && sh .claude/scripts/update.sh --apply "$lhhkwork/decisions-d.tsv" < /dev/null ) 2>&1 )
check "post-landing smoke: a hook that exists and is syntactically fine still lands" has "$lhhkout_d" 'result=applied'
check "post-landing smoke: the hook's own marker file (proof it would leave if executed) was never created -- it is never run" \
  test ! -f "$lhhkfounder/hook-actually-ran.marker"

rm -rf "$lhhkwork"

# --------------------------------------------- post-landing smoke: settings.json JSON validity
# Once json-valid.sh actually exists on a founder's copy, post_landing_smoke
# also proves settings.json itself is still valid JSON once the update has
# actually landed -- a corrupting change here reverts, the same as any
# other post-landing failure. Asserted for real only once the real
# validator has landed on this branch (worker R's own interface); until
# then this is a SKIP, not a FAIL, exactly like the adapt-save JSON case.

if [ -f "$scripts/json-valid.sh" ]; then
  lhsjwork=${TMPDIR:-/tmp}/lh-update-postsmoke-json-test.$$
  trap 'rm -rf "$lhsjwork"' EXIT
  lhsjup="$lhsjwork/upstream"
  lhsjfounder="$lhsjwork/founder"
  mkdir -p "$lhsjup" "$lhsjfounder" || exit 1

  ( cd "$lhsjup" && git init -q && git config user.name Up && git config user.email up@example.com )
  mkdir -p "$lhsjup/.claude"
  printf '%s\n' "$lhsjup" > "$lhsjup/.claude/launchhouse-upstream"
  printf '{ "stock": "v1" }\n' > "$lhsjup/.claude/settings.json"
  ( cd "$lhsjup" && git add -A && git commit -q -m commit1 )
  lhsjbase=$( cd "$lhsjup" && git rev-parse HEAD )

  # Upstream's own release ships genuinely broken JSON -- must never land.
  printf '{ "stock": "v2", unterminated\n' > "$lhsjup/.claude/settings.json"
  ( cd "$lhsjup" && git add -A && git commit -q -m commit2 )

  ( cd "$lhsjup" && git archive "$lhsjbase" ) | ( cd "$lhsjfounder" && tar -x )
  (
    cd "$lhsjfounder" && git init -q && git config user.name Founder && git config user.email f@example.com &&
    git add -A && git commit -q -m "Initial import from template" &&
    git remote add upstream "$lhsjup"
  )
  mkdir -p "$lhsjfounder/.claude/scripts"
  cp "$scripts/update.sh" "$scripts/lib.sh" "$lhsjfounder/.claude/scripts/"
  chmod +x "$lhsjfounder/.claude/scripts/update.sh"
  install_json_valid_stub "$lhsjfounder"
  ( cd "$lhsjfounder" && git add -A && git commit -q -m "add the update engine under test" )

  lhsj() { ( cd "$lhsjfounder" && sh .claude/scripts/update.sh "$@" < /dev/null ) 2>&1; }
  lhsj --detect-base >/dev/null
  lhsj --set-base "$lhsjbase" >/dev/null
  ( cd "$lhsjfounder" && git add -A && git commit -q -m "record the base version" )
  lhsj --plan >/dev/null

  cat > "$lhsjwork/decisions.tsv" <<EOF
.claude/settings.json	apply
EOF
  lhsjout=$( ( cd "$lhsjfounder" && sh .claude/scripts/update.sh --apply "$lhsjwork/decisions.tsv" --allow-no-checks < /dev/null ) 2>&1 )
  check "post-landing smoke: settings.json landing as invalid JSON reverts" has "$lhsjout" 'result=reverted'
  check "and names the reason" has "$lhsjout" 'settings.json is not valid JSON'

  rm -rf "$lhsjwork"
else
  printf 'SKIP  post-landing settings.json JSON-validity revert (validator not present on this branch)\n'
fi

# ------------------------------------- post-landing smoke: check 3 recovers
# If the checkout-time line-ending/newline check fires, the tracked .claude/
# files are reset to HEAD before the automatic undo runs, so a checkout
# artifact never makes the undo's own is_clean guard refuse for no real
# reason. Reproduced with a one-shot broken content filter, keyed to the
# NEW content only, so it fires exactly once -- on the real landing
# checkout at the repository root -- and is gone by the time the reset
# re-checks out that same path a second time, proving the reset is what
# lets the automatic undo actually succeed.

lhc3work=${TMPDIR:-/tmp}/lh-update-postsmoke-checkout-test.$$
trap 'rm -rf "$lhc3work"' EXIT
lhc3up="$lhc3work/upstream"
lhc3founder="$lhc3work/founder"
mkdir -p "$lhc3up" "$lhc3founder" || exit 1

( cd "$lhc3up" && git init -q && git config user.name Up && git config user.email up@example.com )
mkdir -p "$lhc3up/.claude"
printf '%s\n' "$lhc3up" > "$lhc3up/.claude/launchhouse-upstream"
printf 'take v1\n' > "$lhc3up/.claude/take-me.md"
( cd "$lhc3up" && git add -A && git commit -q -m commit1 )
lhc3base=$( cd "$lhc3up" && git rev-parse HEAD )

printf 'take v2\n' > "$lhc3up/.claude/take-me.md"
( cd "$lhc3up" && git add -A && git commit -q -m commit2 )

( cd "$lhc3up" && git archive "$lhc3base" ) | ( cd "$lhc3founder" && tar -x )
(
  cd "$lhc3founder" && git init -q && git config user.name Founder && git config user.email f@example.com &&
  git add -A && git commit -q -m "Initial import from template" &&
  git remote add upstream "$lhc3up"
)
mkdir -p "$lhc3founder/.claude/scripts"
cp "$scripts/update.sh" "$scripts/lib.sh" "$lhc3founder/.claude/scripts/"
chmod +x "$lhc3founder/.claude/scripts/update.sh"
( cd "$lhc3founder" && git add -A && git commit -q -m "add the update engine under test" )

# A broken content filter on take-me.md, keyed to the new upstream content
# ("take v2") and a one-shot marker file: the FIRST time git materializes
# "take v2" through this filter, it appends an extra line the committed
# blob never had -- exactly a checkout producing bytes that do not match
# what was recorded. Every later materialization of that same content
# passes through unchanged, so a reset-and-recheckout genuinely recovers.
lhc3marker="$lhc3work/.smudge-v2-fired"
cat > "$lhc3work/smudge-filter.sh" <<EOF
#!/bin/sh
in=\$(cat)
if [ "\$in" = "take v2" ] && [ ! -f "$lhc3marker" ]; then
  : > "$lhc3marker"
  printf '%s\n' "\$in"
  printf 'appended-by-checkout-once\n'
else
  printf '%s\n' "\$in"
fi
EOF
chmod +x "$lhc3work/smudge-filter.sh"
( cd "$lhc3founder" && git config filter.lh-test-broken.smudge "sh \"$lhc3work/smudge-filter.sh\"" )
( cd "$lhc3founder" && git config filter.lh-test-broken.clean "cat" )
printf '.claude/take-me.md filter=lh-test-broken\n' >> "$lhc3founder/.git/info/attributes"

lhc3() { ( cd "$lhc3founder" && sh .claude/scripts/update.sh "$@" < /dev/null ) 2>&1; }
lhc3 --detect-base >/dev/null
lhc3 --set-base "$lhc3base" >/dev/null
( cd "$lhc3founder" && git add -A && git commit -q -m "record the base version" )
lhc3 --plan >/dev/null

cat > "$lhc3work/decisions.tsv" <<EOF
.claude/take-me.md	apply
EOF
lhc3out=$( ( cd "$lhc3founder" && sh .claude/scripts/update.sh --apply "$lhc3work/decisions.tsv" --allow-no-checks < /dev/null ) 2>&1 )
check "post-landing smoke: a checkout-time content mismatch reverts, not reverted-failed" has "$lhc3out" 'result=reverted'
check "and never reverted-failed (the reset let the automatic undo actually proceed)" hasnt "$lhc3out" 'result=reverted-failed'
check "and take-me.md is genuinely back to its pre-update value" \
  match_eq "$(cat "$lhc3founder/.claude/take-me.md" 2>/dev/null)" "take v1"
check "and the working tree is clean afterward" \
  match_eq "$( cd "$lhc3founder" && git status --porcelain )" ""

rm -rf "$lhc3work"

# ------------------------------------------- do_undo: post-revert verification
# A `git revert` that reports success (or reports nothing left to revert)
# is never trusted on its own -- do_undo verifies every path the update
# touched actually matches the pre-update tag before ever saying "undone"
# or "noop". Reproduced with a no-op custom merge driver: it "resolves"
# any real three-way merge on the path by leaving the current content
# exactly as it is, so git reports the merge succeeded (or that there was
# nothing left to do) without the file ever actually reverting.

lhpvwork=${TMPDIR:-/tmp}/lh-update-verify-undo-test.$$
trap 'rm -rf "$lhpvwork"' EXIT
lhpvup="$lhpvwork/upstream"
lhpvfounder="$lhpvwork/founder"
mkdir -p "$lhpvup" "$lhpvfounder" || exit 1

( cd "$lhpvup" && git init -q && git config user.name Up && git config user.email up@example.com )
mkdir -p "$lhpvup/.claude"
printf '%s\n' "$lhpvup" > "$lhpvup/.claude/launchhouse-upstream"
printf 'verify v1\n' > "$lhpvup/.claude/verify-me.md"
( cd "$lhpvup" && git add -A && git commit -q -m commit1 )
lhpvbase=$( cd "$lhpvup" && git rev-parse HEAD )

printf 'verify v2\n' > "$lhpvup/.claude/verify-me.md"
( cd "$lhpvup" && git add -A && git commit -q -m commit2 )

( cd "$lhpvup" && git archive "$lhpvbase" ) | ( cd "$lhpvfounder" && tar -x )
(
  cd "$lhpvfounder" && git init -q && git config user.name Founder && git config user.email f@example.com &&
  git add -A && git commit -q -m "Initial import from template" &&
  git remote add upstream "$lhpvup"
)
mkdir -p "$lhpvfounder/.claude/scripts"
cp "$scripts/update.sh" "$scripts/lib.sh" "$lhpvfounder/.claude/scripts/"
chmod +x "$lhpvfounder/.claude/scripts/update.sh"
( cd "$lhpvfounder" && git add -A && git commit -q -m "add the update engine under test" )

lhpv() { ( cd "$lhpvfounder" && sh .claude/scripts/update.sh "$@" < /dev/null ) 2>&1; }
lhpv --detect-base >/dev/null
lhpv --set-base "$lhpvbase" >/dev/null
( cd "$lhpvfounder" && git add -A && git commit -q -m "record the base version" )
lhpv --plan >/dev/null

cat > "$lhpvwork/decisions.tsv" <<EOF
.claude/verify-me.md	apply
EOF
lhpvapplyout=$( ( cd "$lhpvfounder" && sh .claude/scripts/update.sh --apply "$lhpvwork/decisions.tsv" --allow-no-checks < /dev/null ) 2>&1 )
check "verify-undo fixture: the update applies" has "$lhpvapplyout" 'result=applied'
check "verify-undo fixture: verify-me.md now reads v2" has "$(cat "$lhpvfounder/.claude/verify-me.md" 2>/dev/null)" 'verify v2'

# The founder edits verify-me.md again after the update, forcing a real
# three-way merge on --undo (never a trivial fast-forward one) -- and rigs
# a no-op merge driver on that path, so any such merge silently "resolves"
# by keeping the current content, whichever way git reports the outcome.
printf 'verify v2, with a founder edit after the update\n' > "$lhpvfounder/.claude/verify-me.md"
( cd "$lhpvfounder" && git add -A && git commit -q -m "founder edits after the update" )
( cd "$lhpvfounder" && git config merge.lh-test-noop.driver true )
printf '.claude/verify-me.md merge=lh-test-noop\n' >> "$lhpvfounder/.git/info/attributes"

lhpvundoout=$( ( cd "$lhpvfounder" && sh .claude/scripts/update.sh --undo < /dev/null ) 2>&1 )
check "post-revert verification: a no-op merge driver making the merge falsely look resolved is never reported as undone" \
  hasnt "$lhpvundoout" 'result=undone'
check "and never reported as noop either" hasnt "$lhpvundoout" 'result=noop'
check "and names the mismatched path" has "$lhpvundoout" 'verify-me.md'
check "verify-me.md still carries the founder's post-update edit -- the driver's silent \"resolution\" was refused, not landed" \
  has "$(cat "$lhpvfounder/.claude/verify-me.md" 2>/dev/null)" 'founder edit after the update'

rm -rf "$lhpvwork"

# --------------------------------------------- .claude/updates/ is launchhouse-owned
# A path under .claude/updates/ (a note or its check file) is never held,
# kept, or "deleted-upstream-kept" like an ordinary file -- it always
# follows upstream exactly, whatever the founder did to their own copy: a
# hand-edit is overwritten, and a deletion (of a note OR its check
# script) is restored, rather than silently letting a safety check stay
# gone.

lhupwork=${TMPDIR:-/tmp}/lh-update-notes-owned-test.$$
trap 'rm -rf "$lhupwork"' EXIT
lhupup="$lhupwork/upstream"
lhupfounder="$lhupwork/founder"
mkdir -p "$lhupup" "$lhupfounder" || exit 1

( cd "$lhupup" && git init -q && git config user.name Up && git config user.email up@example.com )
mkdir -p "$lhupup/.claude/updates/2026-01-01"
printf '%s\n' "$lhupup" > "$lhupup/.claude/launchhouse-upstream"
printf 'note-x v1\n' > "$lhupup/.claude/updates/2026-01-01/note-x.md"
printf 'check-x v1\n' > "$lhupup/.claude/updates/2026-01-01/note-x.check.sh"
printf 'note-y v1\n' > "$lhupup/.claude/updates/2026-01-01/note-y.md"
( cd "$lhupup" && git add -A && git commit -q -m commit1 )
lhupbase=$( cd "$lhupup" && git rev-parse HEAD )

# Upstream's own further release: note-x unchanged, note-y removed
# entirely (retired/superseded).
rm -f "$lhupup/.claude/updates/2026-01-01/note-y.md"
( cd "$lhupup" && git add -A && git commit -q -m "commit2: upstream retires note-y" )

( cd "$lhupup" && git archive "$lhupbase" ) | ( cd "$lhupfounder" && tar -x )
(
  cd "$lhupfounder" && git init -q && git config user.name Founder && git config user.email f@example.com &&
  git add -A && git commit -q -m "Initial import from template" &&
  git remote add upstream "$lhupup"
)
mkdir -p "$lhupfounder/.claude/scripts"
cp "$scripts/update.sh" "$scripts/lib.sh" "$lhupfounder/.claude/scripts/"
chmod +x "$lhupfounder/.claude/scripts/update.sh"
( cd "$lhupfounder" && git add -A && git commit -q -m "add the update engine under test" )

# The founder hand-edits note-x.md, deletes note-x's own check file, and
# hand-edits note-y.md (the one upstream is about to retire).
printf 'note-x, hand-edited by the founder\n' > "$lhupfounder/.claude/updates/2026-01-01/note-x.md"
rm -f "$lhupfounder/.claude/updates/2026-01-01/note-x.check.sh"
printf 'note-y, hand-edited by the founder\n' > "$lhupfounder/.claude/updates/2026-01-01/note-y.md"
( cd "$lhupfounder" && git add -A && git commit -q -m "founder tampers with update notes" )

lhup() { ( cd "$lhupfounder" && sh .claude/scripts/update.sh "$@" < /dev/null ) 2>&1; }
lhup --detect-base >/dev/null
lhup --set-base "$lhupbase" >/dev/null
( cd "$lhupfounder" && git add -A && git commit -q -m "record the base version" )
lhup --plan >/dev/null

lhupplantsv="$lhupfounder/.git/launchhouse/update/plan.tsv"
lhuprow() { grep -F "$(printf '%s\t' "$1")" "$lhupplantsv"; }

check "a hand-edited note under .claude/updates/ is always taken from upstream, never held or kept" \
  has "$(lhuprow .claude/updates/2026-01-01/note-x.md)" 'take'
check "a founder-deleted check file under .claude/updates/ is restored (taken), never silently left gone" \
  has "$(lhuprow .claude/updates/2026-01-01/note-x.check.sh)" 'take'
check "a note retired upstream is always deleted, even though the founder edited their own copy" \
  has "$(lhuprow .claude/updates/2026-01-01/note-y.md)" 'delete'
check "and never classified deleted-upstream-kept, the ordinary-file treatment" \
  hasnt "$(lhuprow .claude/updates/2026-01-01/note-y.md)" 'deleted-upstream-kept'

cat > "$lhupwork/decisions.tsv" <<EOF
.claude/updates/2026-01-01/note-x.md	apply
.claude/updates/2026-01-01/note-x.check.sh	apply
.claude/updates/2026-01-01/note-y.md	apply
EOF
lhupapplyout=$( ( cd "$lhupfounder" && sh .claude/scripts/update.sh --apply "$lhupwork/decisions.tsv" --allow-no-checks < /dev/null ) 2>&1 )
check "the launchhouse-owned update applies" has "$lhupapplyout" 'result=applied'
check "note-x.md is back to the stock upstream wording" \
  match_eq "$(cat "$lhupfounder/.claude/updates/2026-01-01/note-x.md" 2>/dev/null)" "note-x v1"
check "note-x.check.sh is restored" \
  match_eq "$(cat "$lhupfounder/.claude/updates/2026-01-01/note-x.check.sh" 2>/dev/null)" "check-x v1"
check "note-y.md is gone, following upstream's own retirement" \
  test ! -f "$lhupfounder/.claude/updates/2026-01-01/note-y.md"

rm -rf "$lhupwork"

# ----------------------------- .claude/updates/ is never ignored by the founder's own .gitignore
# path_ignored() (consulted by process_path before the .claude/updates/*
# special case above ever runs) must never let the founder's own
# .gitignore -- or .launchhouse-update-ignore -- hide a path under
# .claude/updates/: that folder is always Launchhouse-owned, regardless of
# what the founder's ignore rules say.
#
# git itself only ever treats an UNTRACKED path as "ignored" (a path
# already committed is never reported ignored by `git check-ignore`,
# whatever .gitignore says -- that is how git's own ignore machinery
# works). So the scenario that actually exercises this is a brand new note
# a release adds that the founder's copy has never seen at all: still
# untracked at plan time, and exactly the shape `git check-ignore` would
# flag under a broad ignore line. The founder's copy is built from a base
# that predates the note entirely, never one that already carries it.

lhuiwork=${TMPDIR:-/tmp}/lh-update-notes-ignore-test.$$
trap 'rm -rf "$lhuiwork"' EXIT
lhuiup="$lhuiwork/upstream"
lhuifounder="$lhuiwork/founder"
mkdir -p "$lhuiup" "$lhuifounder" || exit 1

( cd "$lhuiup" && git init -q && git config user.name Up && git config user.email up@example.com )
mkdir -p "$lhuiup/.claude"
printf '%s\n' "$lhuiup" > "$lhuiup/.claude/launchhouse-upstream"
( cd "$lhuiup" && git add -A && git commit -q -m commit1 )
lhuibase=$( cd "$lhuiup" && git rev-parse HEAD )

# Upstream's own further release: a brand new note the founder's copy has
# never had at all.
mkdir -p "$lhuiup/.claude/updates/2026-03-01"
printf 'note-z v1\n' > "$lhuiup/.claude/updates/2026-03-01/note-z.md"
( cd "$lhuiup" && git add -A && git commit -q -m "commit2: upstream adds a new note" )

( cd "$lhuiup" && git archive "$lhuibase" ) | ( cd "$lhuifounder" && tar -x )
(
  cd "$lhuifounder" && git init -q && git config user.name Founder && git config user.email f@example.com &&
  git add -A && git commit -q -m "Initial import from template" &&
  git remote add upstream "$lhuiup"
)
mkdir -p "$lhuifounder/.claude/scripts"
cp "$scripts/update.sh" "$scripts/lib.sh" "$lhuifounder/.claude/scripts/"
chmod +x "$lhuifounder/.claude/scripts/update.sh"
# The founder's own .gitignore hides the whole updates/ folder -- something
# a broad ".claude/" ignore line, or one explicitly naming this folder,
# would equally do. git check-ignore must not be allowed to make this path
# disappear from the plan.
printf '.claude/updates/\n' > "$lhuifounder/.gitignore"
( cd "$lhuifounder" && git add -A && git commit -q -m "add the update engine under test, with a .gitignore hiding updates/" )

lhui() { ( cd "$lhuifounder" && sh .claude/scripts/update.sh "$@" < /dev/null ) 2>&1; }
lhui --detect-base >/dev/null
lhui --set-base "$lhuibase" >/dev/null
( cd "$lhuifounder" && git add -A && git commit -q -m "record the base version" )
lhui --plan >/dev/null

lhuiplantsv="$lhuifounder/.git/launchhouse/update/plan.tsv"
lhuirow=$(grep -F "$(printf '%s\t' .claude/updates/2026-03-01/note-z.md)" "$lhuiplantsv")
check "plan: a new .claude/updates/* note is never ignored by the founder's own .gitignore" \
  has "$lhuirow" 'take'
check "and its class is also take, not silently skipped" \
  has "$lhuirow" "$(printf 'take\ttake')"

rm -rf "$lhuiwork"

# ------------------------------------------- apply: adapted on a non-held row
# An "adapted" decision only ever means something on a held row (conflict,
# add-conflict, deleted-upstream-kept, settings) -- on any other class it
# is refused outright at the pre-apply gate, never silently skipped as if
# the decision had been honoured.

lhaawork=${TMPDIR:-/tmp}/lh-update-adapted-nonheld-test.$$
trap 'rm -rf "$lhaawork"' EXIT
lhaaup="$lhaawork/upstream"
lhaafounder="$lhaawork/founder"
mkdir -p "$lhaaup" "$lhaafounder" || exit 1

( cd "$lhaaup" && git init -q && git config user.name Up && git config user.email up@example.com )
mkdir -p "$lhaaup/.claude"
printf '%s\n' "$lhaaup" > "$lhaaup/.claude/launchhouse-upstream"
printf 'take v1\n' > "$lhaaup/.claude/take-me.md"
( cd "$lhaaup" && git add -A && git commit -q -m commit1 )
lhaabase=$( cd "$lhaaup" && git rev-parse HEAD )

printf 'take v2\n' > "$lhaaup/.claude/take-me.md"
( cd "$lhaaup" && git add -A && git commit -q -m commit2 )

( cd "$lhaaup" && git archive "$lhaabase" ) | ( cd "$lhaafounder" && tar -x )
(
  cd "$lhaafounder" && git init -q && git config user.name Founder && git config user.email f@example.com &&
  git add -A && git commit -q -m "Initial import from template" &&
  git remote add upstream "$lhaaup"
)
mkdir -p "$lhaafounder/.claude/scripts"
cp "$scripts/update.sh" "$scripts/lib.sh" "$lhaafounder/.claude/scripts/"
chmod +x "$lhaafounder/.claude/scripts/update.sh"
( cd "$lhaafounder" && git add -A && git commit -q -m "add the update engine under test" )

lhaa() { ( cd "$lhaafounder" && sh .claude/scripts/update.sh "$@" < /dev/null ) 2>&1; }
lhaa --detect-base >/dev/null
lhaa --set-base "$lhaabase" >/dev/null
( cd "$lhaafounder" && git add -A && git commit -q -m "record the base version" )
lhaa --plan >/dev/null

lhaa_pre_head=$( cd "$lhaafounder" && git rev-parse HEAD )
cat > "$lhaawork/decisions.tsv" <<EOF
.claude/take-me.md	adapted
EOF
lhaaout=$( ( cd "$lhaafounder" && sh .claude/scripts/update.sh --apply "$lhaawork/decisions.tsv" --allow-no-checks < /dev/null ) 2>&1 )
check "apply refuses an 'adapted' decision on a plain take row, not just silently skips it" has "$lhaaout" 'result=aborted'
check "and names why" has "$lhaaout" "adapted"
check "and never moves HEAD" match_eq "$( cd "$lhaafounder" && git rev-parse HEAD )" "$lhaa_pre_head"
check "and take-me.md was never touched" \
  match_eq "$(cat "$lhaafounder/.claude/take-me.md" 2>/dev/null)" "take v1"

rm -rf "$lhaawork"

# --- updates-checks.sh: a failing (non-corrupting) check still reverts
# cleanly.

lhucwork=${TMPDIR:-/tmp}/lh-update-checks-revert-test.$$
trap 'rm -rf "$lhucwork"' EXIT
lhucup="$lhucwork/upstream"
lhucfounder="$lhucwork/founder"
mkdir -p "$lhucup" "$lhucfounder" || exit 1

( cd "$lhucup" && git init -q && git config user.name Up && git config user.email up@example.com )
mkdir -p "$lhucup/.claude"
printf '%s\n' "$lhucup" > "$lhucup/.claude/launchhouse-upstream"
printf 'take v1\n' > "$lhucup/.claude/take-me.md"
( cd "$lhucup" && git add -A && git commit -q -m commit1 )
lhucbase=$( cd "$lhucup" && git rev-parse HEAD )

printf 'take v2\n' > "$lhucup/.claude/take-me.md"
mkdir -p "$lhucup/.claude/tests"
printf '#!/bin/sh\nexit 1\n' > "$lhucup/.claude/tests/updates-checks.sh"
( cd "$lhucup" && git add -A && git commit -q -m "commit2: ship a failing updates-checks.sh, no side effects" )

( cd "$lhucup" && git archive "$lhucbase" ) | ( cd "$lhucfounder" && tar -x )
(
  cd "$lhucfounder" && git init -q && git config user.name Founder && git config user.email f@example.com &&
  git add -A && git commit -q -m "Initial import from template" &&
  git remote add upstream "$lhucup"
)
mkdir -p "$lhucfounder/.claude/scripts" "$lhucfounder/.claude/tests"
cp "$scripts/update.sh" "$scripts/lib.sh" "$lhucfounder/.claude/scripts/"
chmod +x "$lhucfounder/.claude/scripts/update.sh"
printf '#!/bin/sh\nexit 0\n' > "$lhucfounder/.claude/tests/run.sh"
chmod +x "$lhucfounder/.claude/tests/run.sh"
( cd "$lhucfounder" && git add -A && git commit -q -m "add the update engine under test" )

lhuc() { ( cd "$lhucfounder" && sh .claude/scripts/update.sh "$@" < /dev/null ) 2>&1; }
lhuc --detect-base >/dev/null
lhuc --set-base "$lhucbase" >/dev/null
( cd "$lhucfounder" && git add -A && git commit -q -m "record the base version" )
lhuc --plan >/dev/null

cat > "$lhucwork/decisions.tsv" <<EOF
.claude/take-me.md	apply
.claude/tests/updates-checks.sh	apply
EOF
lhucout=$( ( cd "$lhucfounder" && sh .claude/scripts/update.sh --apply "$lhucwork/decisions.tsv" < /dev/null ) 2>&1 )
check "post-landing smoke: a failing (non-corrupting) updates-checks.sh reports reverted" has "$lhucout" 'result=reverted'
check "and names the reason" has "$lhucout" "reason=the update notes' own checks failed once the update actually landed"
check "the automatic undo brings take-me.md back to its pre-this-update value" \
  has "$(cat "$lhucfounder/.claude/take-me.md" 2>/dev/null)" 'take v1'
check "and the failing updates-checks.sh itself was also reverted away" \
  test ! -f "$lhucfounder/.claude/tests/updates-checks.sh"

rm -rf "$lhucwork"

# --- updates-checks.sh: a failing check that ALSO corrupts a tracked live
# file makes the automatic undo's own is_clean guard refuse -- proving
# result=reverted-failed without any test-only switch in update.sh.

lhrfwork=${TMPDIR:-/tmp}/lh-update-reverted-failed-test.$$
trap 'rm -rf "$lhrfwork"' EXIT
lhrfup="$lhrfwork/upstream"
lhrffounder="$lhrfwork/founder"
mkdir -p "$lhrfup" "$lhrffounder" || exit 1

( cd "$lhrfup" && git init -q && git config user.name Up && git config user.email up@example.com )
mkdir -p "$lhrfup/.claude"
printf '%s\n' "$lhrfup" > "$lhrfup/.claude/launchhouse-upstream"
printf 'take v1\n' > "$lhrfup/.claude/take-me.md"
( cd "$lhrfup" && git add -A && git commit -q -m commit1 )
lhrfbase=$( cd "$lhrfup" && git rev-parse HEAD )

printf 'take v2\n' > "$lhrfup/.claude/take-me.md"
mkdir -p "$lhrfup/.claude/tests"
cat > "$lhrfup/.claude/tests/updates-checks.sh" <<'SCRIPT'
#!/bin/sh
printf '\ncorrupted by updates-checks.sh\n' >> .claude/tests/run.sh
exit 1
SCRIPT
( cd "$lhrfup" && git add -A && git commit -q -m "commit2: ship a failing AND corrupting updates-checks.sh" )

( cd "$lhrfup" && git archive "$lhrfbase" ) | ( cd "$lhrffounder" && tar -x )
(
  cd "$lhrffounder" && git init -q && git config user.name Founder && git config user.email f@example.com &&
  git add -A && git commit -q -m "Initial import from template" &&
  git remote add upstream "$lhrfup"
)
mkdir -p "$lhrffounder/.claude/scripts" "$lhrffounder/.claude/tests"
cp "$scripts/update.sh" "$scripts/lib.sh" "$lhrffounder/.claude/scripts/"
chmod +x "$lhrffounder/.claude/scripts/update.sh"
printf '#!/bin/sh\nexit 0\n' > "$lhrffounder/.claude/tests/run.sh"
chmod +x "$lhrffounder/.claude/tests/run.sh"
( cd "$lhrffounder" && git add -A && git commit -q -m "add the update engine under test" )

lhrf() { ( cd "$lhrffounder" && sh .claude/scripts/update.sh "$@" < /dev/null ) 2>&1; }
lhrf --detect-base >/dev/null
lhrf --set-base "$lhrfbase" >/dev/null
( cd "$lhrffounder" && git add -A && git commit -q -m "record the base version" )
lhrf --plan >/dev/null

cat > "$lhrfwork/decisions.tsv" <<EOF
.claude/take-me.md	apply
.claude/tests/updates-checks.sh	apply
EOF
lhrfout=$( ( cd "$lhrffounder" && sh .claude/scripts/update.sh --apply "$lhrfwork/decisions.tsv" < /dev/null ) 2>&1 )
check "post-landing smoke: an undo the guard itself refuses reports reverted-failed" has "$lhrfout" 'result=reverted-failed'
check "and names a reason" has "$lhrfout" 'reason='
lhrf_tag=$(printf '%s\n' "$lhrfout" | grep '^pre_update_tag=' | sed 's/^pre_update_tag=//')
check "and names a pre-update tag" test -n "$lhrf_tag"
lhrf_tag_commit=$( cd "$lhrffounder" && git rev-parse -q --verify "refs/tags/$lhrf_tag^{commit}" 2>/dev/null )
check "and that tag actually exists" test -n "$lhrf_tag_commit"
lhrf_post_head=$( cd "$lhrffounder" && git rev-parse HEAD )
check "the update commit is still landed -- the undo itself was refused, nothing reverted" \
  sh -c '[ "$1" != "$2" ]' _ "$lhrf_post_head" "$lhrf_tag_commit"
check "and run.sh still carries the corruption -- nothing further was changed after the refusal" \
  has "$(cat "$lhrffounder/.claude/tests/run.sh" 2>/dev/null)" 'corrupted by updates-checks.sh'

rm -rf "$lhrfwork"

# ---------------------------------------------------------------- end-to-end
# A founder-shaped folder: a customised skill, a customised settings.json
# taken from the template's own first public release (a real historical
# customisation, not an invented one), and saved growth-engine work --
# updated with founder-approved adapted bodies for every held row, landing
# clean with growth-engine byte-for-byte unchanged.

lheework=${TMPDIR:-/tmp}/lh-update-e2e-test.$$
trap 'rm -rf "$lheework"' EXIT
mkdir -p "$lheework"
# A byte-for-byte saved copy of the template's own first public release
# settings.json (a real historical customisation, not an invented one),
# read from this tests folder, never from this repo's git history -- a
# founder's own folder has no history to read it from.
lhee_settings_src="$here/fixtures/settings-first-release.json"
if [ ! -s "$lhee_settings_src" ]; then
  check "end-to-end: the first public release's settings.json fixture is present" match_eq 1 0
fi

lheeup="$lheework/upstream"
lheefounder="$lheework/founder"
mkdir -p "$lheeup" "$lheefounder" || exit 1

( cd "$lheeup" && git init -q && git config user.name Up && git config user.email up@example.com )

lheewrite() { # relative path, content
  mkdir -p "$lheeup/$(dirname "$1")"
  printf '%s\n' "$2" > "$lheeup/$1"
}

lheewrite .claude/launchhouse-upstream "$lheeup"
lheewrite .claude/settings.json "{ \"stock\": \"settings v1\" }"
lheewrite .claude/skills/some-skill/SKILL.md "---
name: some-skill
description: A stock skill, for the end-to-end test only.
---

Stock body v1."
( cd "$lheeup" && git add -A && git commit -q -m commit1 )
lheebase=$( cd "$lheeup" && git rev-parse HEAD )

lheewrite .claude/settings.json "{ \"stock\": \"settings v2-upstream, with the connector fix\" }"
lheewrite .claude/skills/some-skill/SKILL.md "---
name: some-skill
description: A stock skill, for the end-to-end test only.
---

Stock body v2-upstream."
lheewrite .claude/updates/2026-09-23/settings-fix.md "---
id: settings-fix
title: A settings fix, for the end-to-end test only
purpose: >
  Test purpose text for the settings fix.
touches:
  - .claude/settings.json
adds: []
requires: []
safety: true
done-when:
  - \"a sentence\"
check: none
founder-data: false
---

## What changed and why

Test note."
lheewrite .claude/updates/2026-09-23/skill-wording.md "---
id: skill-wording
title: A wording fix, for the end-to-end test only
purpose: >
  Test purpose text for the wording fix.
touches:
  - .claude/skills/some-skill/SKILL.md
adds: []
requires: []
safety: false
done-when:
  - \"a sentence\"
check: none
founder-data: false
---

## What changed and why

Test note."
( cd "$lheeup" && git add -A && git commit -q -m commit2 )

# --- the founder's copy: template-style, from commit1, with their own
# customisations: a hand-edited skill, settings.json wholesale replaced by
# a real founder's customisation from the template's own first public
# release, and saved growth-engine work.
( cd "$lheeup" && git archive "$lheebase" ) | ( cd "$lheefounder" && tar -x )
(
  cd "$lheefounder" && git init -q && git config user.name Founder && git config user.email f@example.com &&
  git add -A && git commit -q -m "Initial import from template" &&
  git remote add upstream "$lheeup"
)
mkdir -p "$lheefounder/.claude/scripts" "$lheefounder/.claude/tests"
cp "$scripts/update.sh" "$scripts/lib.sh" "$lheefounder/.claude/scripts/"
chmod +x "$lheefounder/.claude/scripts/update.sh"
printf '#!/bin/sh\nexit 0\n' > "$lheefounder/.claude/tests/run.sh"
chmod +x "$lheefounder/.claude/tests/run.sh"
install_json_valid_stub "$lheefounder"
( cd "$lheefounder" && git add -A && git commit -q -m "add the update engine under test" )

cp "$lhee_settings_src" "$lheefounder/.claude/settings.json"
printf '%s\n' "---
name: some-skill
description: A stock skill, for the end-to-end test only.
---

The founder's own hand-edit." > "$lheefounder/.claude/skills/some-skill/SKILL.md"
mkdir -p "$lheefounder/growth-engine/brain" "$lheefounder/growth-engine/log"
printf '# Founder Brain\n\nSaved growth-engine work, must never move.\n' > "$lheefounder/growth-engine/brain/founder-brain.md"
printf '# Ledger\n\n- an entry\n' > "$lheefounder/growth-engine/log/ledger.md"
: > "$lheefounder/growth-engine/.launchhouse"
( cd "$lheefounder" && git add -A && git commit -q -m "founder customisations and saved growth-engine work" )

ge_ee_brain_before=$(cksum_of "$lheefounder/growth-engine/brain/founder-brain.md")
ge_ee_ledger_before=$(cksum_of "$lheefounder/growth-engine/log/ledger.md")

lhee() { ( cd "$lheefounder" && sh .claude/scripts/update.sh "$@" < /dev/null ) 2>&1; }
lhee --detect-base >/dev/null
lhee --set-base "$lheebase" >/dev/null
( cd "$lheefounder" && git add -A && git commit -q -m "record the base version" )
lhee --plan >/dev/null

lheeplantsv="$lheefounder/.git/launchhouse/update/plan.tsv"
lheerow() { grep -F "$(printf '%s\t' "$1")" "$lheeplantsv"; }
check "end-to-end: the customised skill is held" has "$(lheerow .claude/skills/some-skill/SKILL.md)" 'conflict'
check "end-to-end: settings.json is held" has "$(lheerow .claude/settings.json)" 'settings'
check "end-to-end: growth-engine work is never listed in the plan" \
  hasnt "$(cat "$lheeplantsv" 2>/dev/null)" 'growth-engine/'

lheenotestsv="$lheefounder/.git/launchhouse/update/notes.tsv"
check "end-to-end: notes.tsv lists the settings fix" has "$(cat "$lheenotestsv" 2>/dev/null)" 'settings-fix'
check "end-to-end: notes.tsv lists the wording fix" has "$(cat "$lheenotestsv" 2>/dev/null)" 'skill-wording'

lheeadapttsv="$lheefounder/.git/launchhouse/update/adapt.tsv"
check "end-to-end: adapt.tsv links settings.json to the settings-fix note" \
  has "$(grep '^\.claude/settings\.json	' "$lheeadapttsv" 2>/dev/null)" 'settings-fix'
check "end-to-end: adapt.tsv links the skill to the wording-fix note" \
  has "$(grep '^\.claude/skills/some-skill/SKILL\.md	' "$lheeadapttsv" 2>/dev/null)" 'skill-wording'

# The founder-approved adapted bodies (in a real run, written by the
# update-adapter agent; supplied directly here since this suite cannot run
# an agent of its own).
lhee_settings_body="$lheework/settings-adapted.txt"
printf '{ "stock": "settings v2-upstream, with the connector fix", "founder": "kept from the original customisation" }\n' > "$lhee_settings_body"
lhee_skill_body="$lheework/skill-adapted.txt"
printf '%s\n' "---
name: some-skill
description: A stock skill, for the end-to-end test only.
---

The founder's own hand-edit, with the upstream wording fix folded in." > "$lhee_skill_body"

lheesaveout1=$(lhee --adapt-save .claude/settings.json "$lhee_settings_body" settings-fix)
check "end-to-end: adapt-save accepts the settings.json body, with its approved note id" has "$lheesaveout1" 'saved=.claude/settings.json'
lheesaveout2=$(lhee --adapt-save .claude/skills/some-skill/SKILL.md "$lhee_skill_body" skill-wording)
check "end-to-end: adapt-save accepts the skill body, with its approved note id" has "$lheesaveout2" 'saved=.claude/skills/some-skill/SKILL.md'
lheeadaptedtsv="$lheefounder/.git/launchhouse/update/adapted.tsv"
check "end-to-end: adapted.tsv records the settings note id" \
  has "$(grep '^\.claude/settings\.json	' "$lheeadaptedtsv" 2>/dev/null)" 'settings-fix'
check "end-to-end: adapted.tsv records the skill note id" \
  has "$(grep '^\.claude/skills/some-skill/SKILL\.md	' "$lheeadaptedtsv" 2>/dev/null)" 'skill-wording'

cat > "$lheework/decisions.tsv" <<EOF
.claude/settings.json	adapted
.claude/skills/some-skill/SKILL.md	adapted
EOF
lheeapplyout=$( ( cd "$lheefounder" && sh .claude/scripts/update.sh --apply "$lheework/decisions.tsv" < /dev/null ) 2>&1 )
check "end-to-end: the update applies cleanly" has "$lheeapplyout" 'result=applied'
check "end-to-end: settings.json carries the adapted body" \
  has "$(cat "$lheefounder/.claude/settings.json" 2>/dev/null)" 'kept from the original customisation'
check "end-to-end: the skill carries the adapted body" \
  has "$(cat "$lheefounder/.claude/skills/some-skill/SKILL.md" 2>/dev/null)" 'upstream wording fix folded in'
check "end-to-end: growth-engine/brain/founder-brain.md is byte-identical after" \
  match_eq "$(cksum_of "$lheefounder/growth-engine/brain/founder-brain.md")" "$ge_ee_brain_before"
check "end-to-end: growth-engine/log/ledger.md is byte-identical after" \
  match_eq "$(cksum_of "$lheefounder/growth-engine/log/ledger.md")" "$ge_ee_ledger_before"

rm -rf "$lheework"

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

# ------------------------------------------- apply: self-heals a stale worktree
# A cut-off apply (a Bash tool timeout, a killed process, the machine
# sleeping) used to leave $state/wt registered as a worktree, with its own
# launchhouse-update-wt-<pid> branch, forever -- both engines always use
# this same fixed path, so every apply after that one failed with "could
# not create a worktree", not just a retry of the cut-off one. --apply now
# heals this itself at the start, as long as no OTHER apply is genuinely
# running (a lock file, holding the running apply's own pid).

shwork=${TMPDIR:-/tmp}/lh-update-selfheal-test.$$
shup="$shwork/upstream"
shfounder="$shwork/founder"
mkdir -p "$shup" "$shfounder" || exit 1

( cd "$shup" && git init -q && git config user.name Up && git config user.email up@example.com )
mkdir -p "$shup/.claude"
printf '%s\n' "$shup" > "$shup/.claude/launchhouse-upstream"
printf 'take v1\n' > "$shup/.claude/take-me.md"
( cd "$shup" && git add -A && git commit -q -m commit1 )
shbase=$( cd "$shup" && git rev-parse HEAD )
printf 'take v2\n' > "$shup/.claude/take-me.md"
( cd "$shup" && git add -A && git commit -q -m "commit2: upstream changes take-me.md" )

( cd "$shup" && git archive "$shbase" ) | ( cd "$shfounder" && tar -x )
(
  cd "$shfounder" && git init -q && git config user.name Founder && git config user.email f@example.com &&
  git add -A && git commit -q -m "Initial import from template" &&
  git remote add upstream "$shup"
)
mkdir -p "$shfounder/.claude/scripts" "$shfounder/.claude/tests"
cp "$scripts/update.sh" "$scripts/lib.sh" "$shfounder/.claude/scripts/"
chmod +x "$shfounder/.claude/scripts/update.sh"
install_json_valid_stub "$shfounder"
printf '#!/bin/sh\nexit 0\n' > "$shfounder/.claude/tests/run.sh"
chmod +x "$shfounder/.claude/tests/run.sh"
( cd "$shfounder" && git add -A && git commit -q -m "add the update engine under test, and a passing check stub" )

shrun() { ( cd "$shfounder" && sh .claude/scripts/update.sh "$@" < /dev/null ) 2>&1; }
shrun --detect-base >/dev/null
shrun --set-base "$shbase" >/dev/null
( cd "$shfounder" && git add -A && git commit -q -m "record the base version" )
shrun --plan >/dev/null

shgitdir=$( cd "$shfounder" && git rev-parse --absolute-git-dir )
shstate="$shgitdir/launchhouse/update"
: > "$shwork/decisions-noop.tsv"

# --- case (a): a killed apply's leftovers, no lock (the process that held
# it is long gone) -- the next apply must heal past them and succeed.
( cd "$shfounder" && git worktree add -q -b launchhouse-update-wt-999999999 "$shstate/wt" HEAD ) >/dev/null 2>&1
check "self-heal fixture: the stale worktree is actually registered before healing" \
  test -d "$shstate/wt"
check "self-heal fixture: its branch actually exists before healing" \
  sh -c 'cd "$1" && git rev-parse -q --verify refs/heads/launchhouse-update-wt-999999999 >/dev/null 2>&1' _ "$shfounder"

shhealout=$(shrun --apply "$shwork/decisions-noop.tsv")
check "self-heal: an apply behind a killed apply's leftover worktree still succeeds" \
  has "$shhealout" 'result=applied'
check "self-heal: the stale branch is gone afterward" \
  sh -c '! ( cd "$1" && git rev-parse -q --verify refs/heads/launchhouse-update-wt-999999999 >/dev/null 2>&1 )' _ "$shfounder"
check "self-heal: the lock is released once the apply that claimed it finishes" \
  test ! -f "$shstate/apply.lock"

# --- case (b): a genuinely live lock (this test's own shell, definitely
# alive) must stop a second, concurrent apply, with a plain reason -- and
# must never touch the worktree a real running apply owns.
shrun --plan >/dev/null
mkdir -p "$shstate"
printf '%s' "$$" > "$shstate/apply.lock"
shlockout=$(shrun --apply "$shwork/decisions-noop.tsv")
check "self-heal: a live lock (this shell's own, alive pid) stops a concurrent apply" \
  has "$shlockout" 'result=aborted'
check "and names the reason plainly" \
  has "$shlockout" 'already running'
rm -f "$shstate/apply.lock"

rm -rf "$shwork"

if [ "$fail" = 0 ]; then
  printf '\nAll update cases passed.\n'
else
  printf '\nSome update cases failed.\n'
fi
exit $fail
