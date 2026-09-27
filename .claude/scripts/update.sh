#!/bin/sh
# Brings a founder's copy of Launchhouse (this .claude folder) up to date with
# the public template, while never touching growth-engine/ and never losing
# the founder's own changes to .claude without asking. POSIX sh, portable to
# macOS and Git Bash on Windows: no readlink -f, no GNU-only flags, tag names
# without colons.
#
# State lives at $(git rev-parse --absolute-git-dir)/launchhouse/update/,
# never committed and never inside growth-engine/. Output is key=value lines
# or TSV for Claude to read; the launchhouse-update skill turns it into plain
# words for the founder.
#
# Subcommands: --status | --detect-base | --set-base <sha> | --plan |
#              --adapt-save <path> <body-file> <note-ids> | --restore-settings-plan |
#              --restore-settings-decline |
#              --apply <decisions.tsv> [--allow-no-checks] | --undo
#
# Every subcommand is meant to be called with < /dev/null (it never reads
# stdin itself). Equality checks below are CRLF-insensitive: a file is
# compared after stripping \r, never by raw blob sha alone.

set -u
here=$(cd "$(dirname "$0")" && pwd)
# The repository root. --apply copies this script into
# .git/launchhouse/update/run/ and re-execs it from there (so the update can
# safely replace the running script even mid-run), and at that point $here is
# inside .git itself, not the work tree, so neither "$here/../.." nor
# "git -C $here rev-parse --show-toplevel" can find the root any more. The
# first run exports LH_UPDATE_ROOT before it re-execs, so the relocated run
# just trusts that instead of working it out again.
if [ -n "${LH_UPDATE_ROOT:-}" ]; then
  root=$LH_UPDATE_ROOT
else
  root=$(git -C "$here" rev-parse --show-toplevel 2>/dev/null)
  if [ -z "$root" ]; then
    # git refuses --show-toplevel outright when $here sits inside a
    # directory literally named .git -- which is exactly where a founder
    # copy with no update.sh of its own runs this from, once bootstrapped
    # to .git/launchhouse/bootstrap/ (see the launchhouse-update skill's
    # "first update on an older copy"). Walk upward for the nearest
    # ancestor that itself has a .git entry: that is the real root,
    # whatever depth $here happens to be nested at.
    d=$here
    while [ -n "$d" ] && [ "$d" != "/" ]; do
      if [ -e "$d/.git" ]; then root=$d; break; fi
      d=$(dirname "$d")
    done
  fi
  [ -n "$root" ] || root=$(cd "$here/../.." && pwd)
fi
# shellcheck source=lib.sh
[ -f "$here/lib.sh" ] && . "$here/lib.sh"

DEFAULT_UPSTREAM_URL="https://github.com/Philm-moxywolf/launchhouse-founder-template.git"

cd "$root" 2>/dev/null || { echo "error could not reach the repository root" >&2; exit 1; }

# ------------------------------------------------------------------ helpers

git_dir() { git rev-parse --absolute-git-dir 2>/dev/null; }

state_dir() {
  gd=$(git_dir) || return 1
  [ -n "$gd" ] || return 1
  printf '%s/launchhouse/update' "$gd"
}

# Makes sure the "upstream" remote exists, pointed at the founder's recorded
# upstream (.claude/launchhouse-upstream) or the public default, and that its
# push URL is disabled so nothing here can ever push to it by accident.
# Prints the URL in use.
ensure_upstream_remote() {
  url=""
  [ -f "$root/.claude/launchhouse-upstream" ] && url=$(tr -d ' \t\r\n' < "$root/.claude/launchhouse-upstream")
  [ -n "$url" ] || url=$DEFAULT_UPSTREAM_URL
  if ! git remote get-url upstream >/dev/null 2>&1; then
    git remote add upstream "$url" >/dev/null 2>&1
  fi
  git remote set-url --push upstream DISABLED >/dev/null 2>&1
  printf '%s' "$url"
}

# The canonical Launchhouse upstream address: .claude/launchhouse-upstream as
# recorded in the committed HEAD tree (never the working tree -- a tampered
# checkout could edit that unnoticed and point the updater anywhere), falling
# back to the public default.
canonical_upstream_url() {
  url=$(git show HEAD:.claude/launchhouse-upstream 2>/dev/null | tr -d ' \t\r\n')
  [ -n "$url" ] || url=$DEFAULT_UPSTREAM_URL
  printf '%s' "$url"
}

# A comparable form of a git remote URL: trailing slash and trailing .git
# stripped, whole thing lowercased (case-insensitive host, and simplest safe
# way to ignore case differences generally).
normalize_url_for_compare() {
  u=$1
  case $u in */) u=${u%/} ;; esac
  case $u in *.git) u=${u%.git} ;; esac
  printf '%s' "$u" | tr '[:upper:]' '[:lower:]'
}

# Aborts, never silently rewrites, if the "upstream" remote is not pointed at
# the canonical Launchhouse address. Call this after ensure_upstream_remote,
# before any git fetch upstream. A missing remote is not this function's
# problem (ensure_upstream_remote always creates one pointed at canonical, so
# by the time this runs there is always a URL to check).
verify_upstream_trust() {
  actual=$(git remote get-url upstream 2>/dev/null) || return 0
  canon=$(canonical_upstream_url)
  if [ "$(normalize_url_for_compare "$actual")" != "$(normalize_url_for_compare "$canon")" ]; then
    echo "result=aborted"
    echo "reason=upstream address is not the Launchhouse original"
    printf 'upstream_url=%s\n' "$actual"
    exit 1
  fi
}

# The branch upstream's HEAD points at, best effort, with no network call
# beyond what a fetch already did.
upstream_default_branch() {
  b=$(git symbolic-ref -q --short refs/remotes/upstream/HEAD 2>/dev/null | sed 's#^upstream/##')
  if [ -n "$b" ]; then printf '%s' "$b"; return 0; fi
  r=$(git ls-remote --symref upstream HEAD 2>/dev/null | awk '/^ref:/{print $2; exit}' | sed 's#refs/heads/##')
  if [ -n "$r" ]; then printf '%s' "$r"; return 0; fi
  for cand in main master; do
    if git rev-parse -q --verify "refs/remotes/upstream/$cand" >/dev/null 2>&1; then
      printf '%s' "$cand"; return 0
    fi
  done
  return 1
}

recorded_base() {
  [ -f "$root/.claude/launchhouse-version" ] || return 0
  tr -d ' \t\r\n' < "$root/.claude/launchhouse-version"
}

# Clean means git status has nothing outside growth-engine/.state/ (which is
# excluded on purpose even though part of it is tracked) and nothing
# gitignored (git status --porcelain already leaves gitignored files out).
is_clean() {
  out=$(git status --porcelain 2>/dev/null | grep -v ' growth-engine/\.state/')
  [ -z "$out" ]
}

in_progress() {
  gd=$(git_dir) || return 1
  [ -f "$gd/MERGE_HEAD" ] || [ -d "$gd/rebase-merge" ] || [ -d "$gd/rebase-apply" ]
}

# The blob sha of a path at a commit, empty if it does not exist there.
blob_sha() { git rev-parse -q --verify "$1:$2" 2>/dev/null; }

# A CRLF-insensitive fingerprint of a path's content at a commit, empty if
# the path does not exist there.
norm_hash() { # commit, path
  s=$(blob_sha "$1" "$2") || return 0
  [ -n "$s" ] || return 0
  git show "$s" 2>/dev/null | tr -d '\r' | cksum | awk '{ print $1 "-" $2 }'
}

# --------------------------------------------------- install-marker helpers
# Small, standalone reimplementations of skill-packs.sh's own frontmatter
# readers (lh_frontmatter / lh_fm_value / lh_fm_list), operating on a plain
# file instead of skill-packs.sh's own $packs_dir layout: update.sh reads a
# pack.md's content straight out of a git blob, never off disk, and cannot
# safely source skill-packs.sh itself (its own argv dispatch at the bottom
# would run against update.sh's own arguments instead). Kept in lockstep
# with skill-packs.sh's originals by hand; both are small and this pairing
# is exercised by update-cases.sh.
lh_um_frontmatter() { # file
  awk '
    NR == 1 && $0 !~ /^---[ \t]*$/ { print "NOFRONT"; exit }
    NR == 1 { next }
    /^---[ \t]*$/ { exit }
    { print }
  ' "$1"
}
lh_um_fm_value() { # frontmatter text, key
  printf '%s\n' "$1" | awk -F ':' -v k="$2" '
    $0 ~ "^" k ":" { sub("^" k ":[ \t]*", ""); print; exit }
  '
}
lh_um_fm_list() { # frontmatter text, key
  v=$(lh_um_fm_value "$1" "$2")
  inner=$(printf '%s' "$v" | sed -n 's/^\[\(.*\)\]$/\1/p')
  [ -n "$inner" ] || return 0
  printf '%s\n' "$inner" | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | awk 'NF'
}

# The claimed pack-relative source path out of an install marker line, e.g.
# "skill-packs/demo/skills/demo-expert/SKILL.md" from
# "<!-- Installed from .claude/skill-packs/demo/skills/demo-expert/SKILL.md.
# Edit the pack's copy, not this one; Launchhouse re-installs it. -->".
# Empty if the line is not shaped exactly like a marker skill-packs.sh
# itself would write.
lh_marker_claimed_src() { # marker line
  printf '%s\n' "$1" | sed -n "s#^<!-- Installed from \.claude/\(.*\)\. Edit the pack's copy, not this one; Launchhouse re-installs it\. -->\$#\1#p"
}

# True (exit 0) only if the claimed source path is exactly the one
# skill-packs.sh's own install mapping would use for this destination path:
# same pack id embedded in it, skills vs agents matching the destination's
# own shape, and the destination's own name (the skill or agent name)
# reproduced exactly -- never a marker that merely starts with the right
# prefix. Sets lh_mm_id, lh_mm_kind and lh_mm_name on success.
lh_marker_maps_to() { # dest_path, claimed_rel_src
  mp_p=$1; mp_claimed=$2
  case $mp_p in
    .claude/skills/*/SKILL.md)
      mp_name=${mp_p#.claude/skills/}; mp_name=${mp_name%/SKILL.md}
      mp_kind=skills
      ;;
    .claude/agents/*.md)
      mp_name=${mp_p#.claude/agents/}; mp_name=${mp_name%.md}
      mp_kind=agents
      ;;
    *) return 1 ;;
  esac
  case $mp_claimed in
    skill-packs/*/"$mp_kind"/*) : ;;
    *) return 1 ;;
  esac
  mp_id=${mp_claimed#skill-packs/}
  mp_id=${mp_id%%/*}
  [ -n "$mp_id" ] || return 1
  if [ "$mp_kind" = skills ]; then
    mp_expected="skill-packs/$mp_id/skills/$mp_name/SKILL.md"
  else
    mp_expected="skill-packs/$mp_id/agents/$mp_name.md"
  fi
  [ "$mp_claimed" = "$mp_expected" ] || return 1
  lh_mm_id=$mp_id; lh_mm_kind=$mp_kind; lh_mm_name=$mp_name
  return 0
}

# True (exit 0) only if, at the given commit, the claimed pack source file
# actually exists AND that pack's own pack.md actually lists this exact
# name under the matching skills:/agents: key -- the last line of defence
# against a marker that merely has the right shape but names a pack id, or
# a name inside a real pack, that never claimed this file at all.
lh_marker_src_registered() { # commit, id, kind(skills|agents), name
  c=$1; id=$2; kind=$3; name=$4
  case $kind in
    skills) srcp=".claude/skill-packs/$id/skills/$name/SKILL.md" ;;
    agents) srcp=".claude/skill-packs/$id/agents/$name.md" ;;
    *) return 1 ;;
  esac
  git rev-parse -q --verify "$c:$srcp" >/dev/null 2>&1 || return 1
  pmd_sha=$(blob_sha "$c" ".claude/skill-packs/$id/pack.md") || return 1
  [ -n "$pmd_sha" ] || return 1
  msr_tmp="${TMPDIR:-/tmp}/lh-um-packmd.$$"
  git show "$pmd_sha" > "$msr_tmp" 2>/dev/null
  msr_fm=$(lh_um_frontmatter "$msr_tmp")
  rm -f "$msr_tmp"
  [ "$msr_fm" != NOFRONT ] && [ -n "$msr_fm" ] || return 1
  lh_um_fm_list "$msr_fm" "$kind" | grep -qxF -- "$name"
}

# ------------------------------------------------------------------ status

cmd_status() {
  url=$(ensure_upstream_remote)
  verify_upstream_trust
  base=$(recorded_base); [ -n "$base" ] || base=unknown
  db=$(upstream_default_branch) || db=""
  uh=""
  [ -n "$db" ] && uh=$(git rev-parse -q --verify "refs/remotes/upstream/$db" 2>/dev/null)
  [ -n "$uh" ] || uh=unknown
  clean=yes; is_clean || clean=no
  ip=no; in_progress && ip=yes
  printf 'upstream_url=%s\n' "$url"
  printf 'base=%s\n' "$base"
  printf 'upstream_head=%s\n' "$uh"
  printf 'clean=%s\n' "$clean"
  printf 'in_progress=%s\n' "$ip"
}

# -------------------------------------------------------------- detect-base

cmd_detect_base() {
  ensure_upstream_remote >/dev/null
  verify_upstream_trust
  if ! git fetch upstream >/dev/null 2>&1; then
    echo "error could not fetch upstream"
    exit 1
  fi
  rec=$(recorded_base)
  if [ -n "$rec" ]; then
    printf 'recorded %s\n' "$rec"
    exit 0
  fi
  db=$(upstream_default_branch) || { echo "error could not work out upstream's default branch"; exit 1; }
  if git merge-base HEAD "upstream/$db" >/dev/null 2>&1; then
    mb=$(git merge-base HEAD "upstream/$db")
    printf 'exact %s\n' "$mb"
    exit 0
  fi
  # No shared history: this is a "Use this template" copy. Find the upstream
  # commit whose .claude tree matches the founder's root commit.
  root_commit=$(git rev-list --max-parents=0 HEAD 2>/dev/null | tail -1)
  [ -n "$root_commit" ] || { echo "none"; exit 0; }
  root_tree=$(git rev-parse -q --verify "$root_commit:.claude" 2>/dev/null)
  [ -n "$root_tree" ] || { echo "none"; exit 0; }

  # Walk upstream's first-parent (mainline) history only, newest first. A
  # merge commit can have a tree identical to one of its parents (a PR that
  # touched nothing under .claude still produces a new merge commit), so more
  # than one upstream commit can carry the exact same .claude tree. Scoping
  # the scan to first-parent history and taking the first (i.e. newest) match
  # makes the choice deterministic instead of depending on git rev-list's
  # date-based ordering across side branches.
  best=""; best_n=""
  for c in $(git rev-list --first-parent "upstream/$db" 2>/dev/null); do
    ct=$(git rev-parse -q --verify "$c:.claude" 2>/dev/null) || continue
    if [ "$ct" = "$root_tree" ]; then
      printf 'exact %s\n' "$c"
      exit 0
    fi
    n=$(git diff --ignore-cr-at-eol --name-only "$c" "$root_commit" -- .claude 2>/dev/null | wc -l | tr -d ' ')
    [ -n "$n" ] || continue
    if [ -z "$best_n" ] || [ "$n" -lt "$best_n" ]; then best_n=$n; best=$c; fi
  done
  if [ -n "$best" ]; then
    printf 'closest %s %s\n' "$best" "$best_n"
  else
    printf 'none\n'
  fi
}

# ----------------------------------------------------------------- set-base

cmd_set_base() {
  sha=${1:-}
  [ -n "$sha" ] || { echo "error missing sha"; exit 1; }
  ensure_upstream_remote >/dev/null
  full=$(git rev-parse -q --verify "$sha^{commit}" 2>/dev/null) || { echo "error '$sha' is not a known commit"; exit 1; }
  ok=0
  for r in $(git for-each-ref --format='%(refname)' refs/remotes/upstream 2>/dev/null); do
    if git merge-base --is-ancestor "$full" "$r" 2>/dev/null; then ok=1; break; fi
  done
  [ "$ok" = 1 ] || { echo "error '$sha' is not a commit reachable from upstream; fetch upstream first"; exit 1; }
  mkdir -p "$root/.claude"
  printf '%s\n' "$full" > "$root/.claude/launchhouse-version"
  # Leaving this file written but uncommitted strands the working tree
  # dirty, which --apply's is_clean() then refuses (see the launchhouse-
  # update skill: step 0 saves the founder's work, then --detect-base /
  # --set-base run in step 2, before --apply). Commit it here, alone, so a
  # folder with no recorded version is never left unclean by --set-base
  # itself. Skip the commit when HEAD already carries this exact value
  # (repeat --set-base calls with the same sha are then no-ops).
  head_val=$(git show HEAD:.claude/launchhouse-version 2>/dev/null | tr -d ' \t\r\n')
  if [ "$head_val" != "$full" ]; then
    if ! git add -- .claude/launchhouse-version || \
       ! git commit -q -m "Record the Launchhouse version this folder started from" -- .claude/launchhouse-version; then
      echo "error could not record the base version"
      exit 1
    fi
  fi
  printf 'base=%s\n' "$full"
}

# ---------------------------------------------------------------------- plan

# Is a pattern from .launchhouse-update-ignore matching a path? A pattern
# ending in / is a prefix match (everything under that folder); anything else
# is matched as a shell glob against the whole path.
match_ignore_pattern() { # path, pattern
  p=$1; pat=$2
  case $pat in
    */) case $p in "$pat"*) return 0 ;; esac ;;
    *) case $p in $pat) return 0 ;; esac ;;
  esac
  return 1
}

path_ignored() { # path (relative to repo root)
  p=$1
  case $p in growth-engine/*) return 0 ;; esac
  # .claude/updates/** is always Launchhouse-owned (see process_path's own
  # special case for it) regardless of what the founder's own .gitignore or
  # .launchhouse-update-ignore says -- a broad ".claude/" ignore line must
  # never make a deleted safety note or check look "ignored" and so never
  # reach the case in process_path that would otherwise restore it.
  case $p in .claude/updates/*) return 1 ;; esac
  git check-ignore -q -- "$p" 2>/dev/null && return 0
  if [ -n "${ignore_patterns:-}" ]; then
    while IFS= read -r pat; do
      [ -n "$pat" ] || continue
      case $pat in '#'*) continue ;; esac
      match_ignore_pattern "$p" "$pat" && return 0
    done <<EOF
$ignore_patterns
EOF
  fi
  return 1
}

write_row() { # path, class, proposed, detail
  printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> "$state/plan.tsv"
}

write_diffs() { # path
  p=$1
  wd_base=${pp_base:-$basecommit}
  d="$state/diffs/$(dirname "$p")"
  mkdir -p "$d" 2>/dev/null
  git diff "$wd_base" "$uh" -- "$p" > "$state/diffs/$p.base-upstream.diff" 2>/dev/null
  git diff "$wd_base" HEAD -- "$p" > "$state/diffs/$p.base-local.diff" 2>/dev/null
}

try_merge_file() { # path, bsha, hsha, usha
  p=$1; bsha=$2; hsha=$3; usha=$4
  tb="$state/.tmp.base.$$"; tl="$state/.tmp.local.$$"; tr_="$state/.tmp.remote.$$"
  git show "$bsha" > "$tb" 2>/dev/null
  git show "$hsha" > "$tl" 2>/dev/null
  git show "$usha" > "$tr_" 2>/dev/null
  if git merge-file -p "$tl" "$tb" "$tr_" > "$state/.tmp.out.$$" 2>/dev/null; then
    mkdir -p "$state/merged/$(dirname "$p")" 2>/dev/null
    cp "$state/.tmp.out.$$" "$state/merged/$p"
    write_row "$p" merged-clean apply "three-way merge was clean"
  else
    write_row "$p" conflict hold "three-way merge left conflict markers"
  fi
  rm -f "$tb" "$tl" "$tr_" "$state/.tmp.out.$$"
}

build_registry_merge() { # path, hsha, usha
  p=$1; hsha=$2; usha=$3
  mkdir -p "$state/merged/$(dirname "$p")" 2>/dev/null
  {
    git show "$usha" 2>/dev/null
    [ -n "$hsha" ] && git show "$hsha" 2>/dev/null | tail -n +2 | awk -F '\t' '$6 == "local"'
  } > "$state/merged/$p"
  write_row "$p" registry-merge apply "union: upstream rows plus local-origin rows"
}

# The first body line right after a blob's frontmatter's closing ---, or
# empty if the blob has no frontmatter or no such line. Used only to pull
# out a candidate marker line for lh_carries_install_marker to check
# structurally; finding this line proves nothing on its own.
lh_first_body_line() { # commit, path
  s=$(blob_sha "$1" "$2") || return 1
  [ -n "$s" ] || return 1
  git show "$s" 2>/dev/null | awk '
    NR == 1 && $0 !~ /^---[ \t]*$/ { exit 1 }
    NR == 1 { infm = 1; next }
    infm && /^---[ \t]*$/ {
      infm = 0
      if ((getline nextline) > 0) { print nextline }
      exit 0
    }
    infm { next }
    END { if (infm) exit 1 }
  '
}

# True (exit 0) only if the path's blob at a given commit is a skill or
# agent file skill-packs.sh --install writes (frontmatter, then a first
# body line shaped like an install marker) AND that marker names EXACTLY
# the pack source path skill-packs.sh's own mapping would install to this
# destination: same pack id, skills vs agents matching the destination's
# own shape, the destination's own name reproduced exactly, the claimed
# source file actually present at this commit, and that pack's own pack.md
# at this commit actually listing this name. A marker that merely starts
# with the right prefix -- forged, foreign, or naming a pack id or name
# that never claimed this file -- fails this, the same as no marker at all;
# it is never trusted by shape alone.
lh_carries_install_marker() { # commit, path
  cim_c=$1; cim_p=$2
  cim_line=$(lh_first_body_line "$cim_c" "$cim_p") || return 1
  case $cim_line in
    '<!-- Installed from .claude/skill-packs/'*) : ;;
    *) return 1 ;;
  esac
  cim_claimed=$(lh_marker_claimed_src "$cim_line")
  [ -n "$cim_claimed" ] || return 1
  lh_marker_maps_to "$cim_p" "$cim_claimed" || return 1
  lh_marker_src_registered "$cim_c" "$lh_mm_id" "$lh_mm_kind" "$lh_mm_name"
}

# True (exit 0) only if the path at a commit is, content-wise, exactly what
# skill-packs.sh --install would produce right now from that SAME commit's
# own pack source for this path (the source blob's content, with the
# marker line spliced in right after the frontmatter's closing ---),
# compared CRLF-insensitively like every other equality check in this
# script. Never called on a path lh_carries_install_marker has not already
# confirmed carries a structurally valid marker at this commit.
lh_matches_install_output() { # commit, path
  mio_c=$1; mio_p=$2
  mio_dest_sha=$(blob_sha "$mio_c" "$mio_p") || return 1
  [ -n "$mio_dest_sha" ] || return 1
  mio_line=$(lh_first_body_line "$mio_c" "$mio_p") || return 1
  mio_claimed=$(lh_marker_claimed_src "$mio_line")
  [ -n "$mio_claimed" ] || return 1
  mio_src_sha=$(blob_sha "$mio_c" ".claude/$mio_claimed") || return 1
  [ -n "$mio_src_sha" ] || return 1
  mio_src="${TMPDIR:-/tmp}/lh-um-mio-src.$$"
  mio_out="${TMPDIR:-/tmp}/lh-um-mio-out.$$"
  mio_dest="${TMPDIR:-/tmp}/lh-um-mio-dest.$$"
  git show "$mio_src_sha" > "$mio_src" 2>/dev/null
  awk -v marker="$mio_line" '
    NR == 1 && $0 !~ /^---[ \t]*$/ { print; nofront = 1; next }
    NR == 1 { print; infm = 1; next }
    infm && /^---[ \t]*$/ { print; if (!nofront) print marker; infm = 0; next }
    { print }
  ' "$mio_src" > "$mio_out"
  git show "$mio_dest_sha" > "$mio_dest" 2>/dev/null
  mio_a=$(tr -d '\r' < "$mio_out" | cksum)
  mio_b=$(tr -d '\r' < "$mio_dest" | cksum)
  rm -f "$mio_src" "$mio_out" "$mio_dest"
  [ "$mio_a" = "$mio_b" ]
}

# Is this an "installed-path" shape at all: the generic location
# skill-packs.sh --install writes a pack's skills and agents to. Content
# (the marker check above), not this shape alone, is what actually decides
# generated vs conflict -- this only narrows which paths bother checking.
lh_installed_path_shape() { # path
  case $1 in
    .claude/skills/*/SKILL.md|.claude/agents/*.md) return 0 ;;
    *) return 1 ;;
  esac
}

# Ordinarily the plan-wide $basecommit -- but a path a held note touches
# (recorded in $state/.heldbase.tsv, built once in cmd_plan from held.tsv's
# own recorded base) is classified, merged and saved against that note's
# own base instead, so it comes back as a real pending change (and adapt.tsv
# saves the note's own actual base) rather than a false "keep" once today's
# basecommit has already moved past it. See the .heldbase.tsv build in
# cmd_plan for why. Shared by process_path (which passes the result on to
# try_merge_file as its own bsha argument) and write_adapt_row, so both ever
# agree on which base a given held path is judged against.
held_base_for_path() { # path
  hbfp_p=$1
  hbfp_base=$basecommit
  if [ -s "$state/.heldbase.tsv" ]; then
    hbfp_ov=$(awk -F '\t' -v pp="$hbfp_p" '$1 == pp { print $2; exit }' "$state/.heldbase.tsv")
    [ -n "$hbfp_ov" ] && hbfp_base=$hbfp_ov
  fi
  printf '%s\n' "$hbfp_base"
}

process_path() { # path
  p=$1
  path_ignored "$p" && return 0

  pp_base=$(held_base_for_path "$p")

  bsha=$(blob_sha "$pp_base" "$p")
  hsha=$(blob_sha HEAD "$p")
  usha=$(blob_sha "$uh" "$p")
  bn=""; hn=""; un=""
  [ -n "$bsha" ] && bn=$(norm_hash "$pp_base" "$p")
  [ -n "$hsha" ] && hn=$(norm_hash HEAD "$p")
  [ -n "$usha" ] && un=$(norm_hash "$uh" "$p")

  case $p in
    .claude/updates/*)
      # Launchhouse-owned: an improvement note and its check file are never
      # the founder's to hold, keep or edit -- whatever a founder did to one
      # (hand-edited it, deleted it) is always overwritten by upstream on
      # the next --plan, so a deleted safety note or check comes straight
      # back. Never held, never "kept".
      if [ -n "$usha" ]; then
        [ "$hn" = "$un" ] && return 0
        write_row "$p" take take "launchhouse-owned update note or check: always taken from upstream"
      else
        [ -z "$hsha" ] && return 0
        write_row "$p" delete delete "launchhouse-owned update note or check: removed upstream, always follows upstream"
      fi
      write_diffs "$p"
      return 0
      ;;
  esac

  if lh_installed_path_shape "$p" && [ -n "$usha" ] && lh_carries_install_marker "$uh" "$p"; then
    # Upstream now ships this exact path as a skill-pack install: it is
    # regenerated by skill-packs.sh --install all (after --compile) in the
    # apply worktree, never taken, merged or held as an ordinary file --
    # but only once two things are both true, not merely because the path
    # and the upstream marker line up. First, the founder's own copy at
    # HEAD (if any) must itself carry a structurally valid marker; a file
    # that exists, was changed since base, and carries no marker (or a
    # forged/foreign one -- lh_carries_install_marker fails those exactly
    # the same as no marker at all) is a real collision with the founder's
    # own work, held for review. Second, even a genuinely marked file must
    # still match what skill-packs.sh --install would produce from HEAD's
    # own pack source right now: a founder can hand-edit an installed copy
    # after install without ever touching the marker line itself, and that
    # drift must never be silently regenerated away.
    founder_conflict=0
    conflict_reason=""
    if [ -n "$hsha" ]; then
      if lh_carries_install_marker HEAD "$p"; then
        if ! lh_matches_install_output HEAD "$p"; then
          founder_conflict=1
          conflict_reason="the installed copy carries the pack's own marker but no longer matches what the pack would produce; it looks like the founder edited it after install"
        fi
      elif [ "$hn" != "$bn" ]; then
        founder_conflict=1
        conflict_reason="upstream now generates this from a skill pack, but the founder's own copy carries no install marker (or an untrustworthy one) and was changed locally"
      fi
    fi
    if [ "$founder_conflict" = 1 ]; then
      write_row "$p" conflict hold "$conflict_reason"
    else
      write_row "$p" generated regenerate "regenerated by skill-packs.sh --install all after --compile in the apply worktree"
    fi
    write_diffs "$p"
    return 0
  fi

  if [ -z "$bsha" ]; then
    # Not tracked at base.
    if [ -n "$usha" ] && [ -z "$hsha" ]; then
      write_row "$p" add add "new upstream file"
      write_diffs "$p"
    elif [ -n "$usha" ] && [ -n "$hsha" ]; then
      if [ "$hn" = "$un" ]; then
        return 0
      fi
      write_row "$p" add-conflict hold "new upstream file, and a different local file already exists"
      write_diffs "$p"
    fi
    # local-only (absent at base and upstream): never listed.
    return 0
  fi

  local_changed=1; [ "$hn" = "$bn" ] && local_changed=0
  upstream_changed=1; [ "$un" = "$bn" ] && upstream_changed=0

  if [ "$local_changed" = 0 ] && [ "$upstream_changed" = 0 ]; then
    return 0
  fi

  if [ "$p" = ".claude/skill-packs/compiled-policy.sh" ]; then
    write_row "$p" generated regenerate "compiled from registry.tsv and every pack's policy; regenerated on apply"
    write_diffs "$p"
    return 0
  fi

  if [ "$upstream_changed" = 1 ] && [ "$local_changed" = 0 ]; then
    if [ -z "$usha" ]; then
      write_row "$p" delete delete "deleted upstream, unchanged locally"
    else
      write_row "$p" take take "changed upstream, unchanged locally"
    fi
    write_diffs "$p"
    return 0
  fi

  if [ "$local_changed" = 1 ] && [ "$upstream_changed" = 0 ]; then
    write_row "$p" keep keep "changed locally only"
    write_diffs "$p"
    return 0
  fi

  # Both changed.
  if [ -z "$usha" ]; then
    write_row "$p" deleted-upstream-kept hold "deleted upstream, changed locally"
  elif [ "$p" = ".claude/skill-packs/registry.tsv" ]; then
    build_registry_merge "$p" "$hsha" "$usha"
  elif [ "$p" = ".claude/settings.json" ]; then
    write_row "$p" settings hold "settings.json changed on both sides; always held for review"
  elif [ -z "$hsha" ]; then
    write_row "$p" conflict hold "deleted locally, changed upstream"
  else
    try_merge_file "$p" "$bsha" "$hsha" "$usha"
  fi
  write_diffs "$p"
}

# ------------------------------------------------------- notes and adapting
# Purpose-based updates (docs/purpose-based-updates.md section 4): notes.tsv
# lists every improvement note that applies (present upstream, absent at the
# founder's base commit); adapt.tsv lists every held path a founder-facing
# worker may adapt, with the three sides (base/theirs/mine) saved to disk for
# it to read. Both are plan-time only, rebuilt fresh on every --plan.

# A list under a frontmatter key, one item per line, given as indented
# "  - item" lines (never the inline "[a, b]" shape lh_um_fm_list reads) --
# the shape .claude/updates/<release>/<id>.md's own keys use, per
# .claude/updates/README.md: touches, adds, requires, done-when are all
# this shape.
lh_note_fm_list() { # frontmatter text, key
  printf '%s\n' "$1" | awk -v k="$2" '
    $0 ~ "^" k ":[ \t]*$" { inkey = 1; next }
    inkey && /^[ \t]*-[ \t]*/ { line = $0; sub(/^[ \t]*-[ \t]*/, "", line); print line; next }
    inkey && /^[^ \t]/ { inkey = 0 }
  '
}

# Saves a path's content at a commit to dest, returns 1 (no output) if the
# path does not exist there. mkdir -p's dest's parent as needed.
save_side() { # commit, path, dest
  sc=$1; sp=$2; sdest=$3
  ssha=$(blob_sha "$sc" "$sp")
  [ -n "$ssha" ] || return 1
  mkdir -p "$(dirname "$sdest")" 2>/dev/null
  git show "$ssha" > "$sdest" 2>/dev/null
}

# True (exit 0) only if the path is recorded as a symlink (git mode 120000)
# at the given commit.
is_symlink_at() { # commit, path
  m=$(git ls-tree "$1" -- "$2" 2>/dev/null | awk '{ print $1; exit }')
  [ "$m" = 120000 ]
}

# Mirrors the git-tree file mode ("100755" -> executable, anything else ->
# plain 644) recorded for a path at a commit onto a file already written
# into the worktree. git records the mode a working-tree file actually has
# at `git add` time, never the mode a blob's content alone implies -- so
# writing a blob's bytes with `git show` (apply_take, apply_merged,
# restore_path_to_head, all in cmd_apply) always leaves a brand-new file at
# plain 644 unless this runs first, which is exactly the bug this fixes: a
# new upstream script shipped 100755 landed 644 in the founder's own copy
# and failed "Permission denied" the moment anything tried to exec it
# directly. A symlink (mode 120000) is left untouched: its "content" is a
# target string, not something chmod has any business changing, and none of
# this script's write paths ever produce one (is_symlink_at already refuses
# an adapted body for a symlink path).
set_path_mode() { # commit, path, file
  spm_m=$(git ls-tree "$1" -- "$2" 2>/dev/null | awk '{ print $1; exit }')
  case $spm_m in
    100755) chmod 755 "$3" 2>/dev/null ;;
    120000) : ;;
    *) chmod 644 "$3" 2>/dev/null ;;
  esac
}

# Sets the git INDEX mode for a path just `git add`-ed in a worktree, to
# match the tree mode set_path_mode just read (left in $spm_m by the call
# immediately before this one -- every caller uses the two back to back).
# `git add` alone is not enough: with core.filemode=false (Git for
# Windows' own default), git never looks at the working tree's executable
# bit at all when deciding the index mode, so a plain `chmod 755` +
# `git add` here would still stage the file 644 -- the founder's own `git
# ls-files -s` would show it non-executable even though the file on disk
# really is, and anything that clones or re-checks-out the repo elsewhere
# would get it wrong. `git update-index --chmod` sets the index bit
# directly, independent of core.filemode.
stage_index_mode() { # worktree-dir, path
  sim_wt=$1; sim_p=$2
  case $spm_m in
    100755) ( cd "$sim_wt" && git update-index --chmod=+x -- "$sim_p" ) >/dev/null 2>&1 ;;
    120000) : ;;
    *) ( cd "$sim_wt" && git update-index --chmod=-x -- "$sim_p" ) >/dev/null 2>&1 ;;
  esac
}

# Every note id in $state/notes.tsv whose touches list names this path,
# comma-joined, or "-" if none. Requires $state/notes.tsv to already exist
# (an empty or missing file just means "-" for everything).
notes_touching() { # path
  ntp=$1
  ids=""
  [ -f "$state/notes.tsv" ] || { printf '%s' '-'; return 0; }
  while IFS='	' read -r nid _npath _nsafety ntouches; do
    [ -n "$nid" ] || continue
    if printf '%s' ",$ntouches," | grep -qF ",$ntp,"; then
      ids="$ids,$nid"
    fi
  done < "$state/notes.tsv"
  ids=${ids#,}
  if [ -n "$ids" ]; then printf '%s' "$ids"; else printf '%s' '-'; fi
}

# Rebuilds $state/notes.tsv: every .claude/updates/<release>/<id>.md that
# exists in $uh's tree and did not exist in $basecommit's tree (by presence,
# never by date on the folder -- docs/purpose-based-updates.md step 1), one
# row `id<TAB>note-path<TAB>safety<TAB>touches-comma-separated`, oldest
# release first (a plain path sort already achieves this: the release
# folder is a YYYY-MM-DD name, so lexicographic order is chronological
# order). A note with no readable frontmatter is skipped, not fatal.
#
# note-path (column 2) is RELATIVE TO THE STATE DIR, never the repo -- the
# skill and its agents read a note only from $state/notes/<id>.md, never
# from the live .claude/updates/ tree (which a founder's own copy may not
# even carry the exact release folder for). --plan also copies the note's
# own check file (its "check" frontmatter key, sitting beside the note in
# the same release folder) to $state/notes/<id>.check.sh, when it names one
# other than "none" -- a founder-facing worker reading a note can read its
# check alongside it, without ever reaching into the upstream tree itself.
build_notes_tsv() {
  : > "$state/notes.tsv"
  rm -rf "$state/notes"
  mkdir -p "$state/notes"
  # $state/held.tsv (id<TAB>plain reason) is never cleared by --plan -- it is
  # the standing record of a note a past --apply held back (cmd_apply's own
  # HOLD BACK step). A note listed there is offered again here regardless of
  # base presence: it never actually landed in the founder's own copy, so
  # "present at basecommit" (the ordinary "new since base" test below) is no
  # signal at all for it -- basecommit only ever tracks an UPSTREAM commit,
  # which already contains the note the moment it shipped, whether or not
  # the founder ever actually took it.
  bnt_held_ids=""
  [ -f "$state/held.tsv" ] && bnt_held_ids=$(awk -F '\t' '{ print $1 }' "$state/held.tsv")
  note_paths=$(git ls-tree -r --name-only "$uh" -- .claude/updates 2>/dev/null |
    grep -E '^\.claude/updates/[^/]+/[^/]+\.md$' | sort)
  printf '%s\n' "$note_paths" | while IFS= read -r np; do
    [ -n "$np" ] || continue
    nf="$state/.tmp.note.$$"
    git show "$uh:$np" > "$nf" 2>/dev/null || { rm -f "$nf"; continue; }
    fm=$(lh_um_frontmatter "$nf")
    rm -f "$nf"
    [ "$fm" != NOFRONT ] && [ -n "$fm" ] || continue
    nid=$(lh_um_fm_value "$fm" id)
    [ -n "$nid" ] || nid=$(basename "$np" .md)

    is_new=1
    [ -z "$(blob_sha "$basecommit" "$np")" ] || is_new=0
    is_held=0
    if [ -n "$bnt_held_ids" ] && printf '%s\n' "$bnt_held_ids" | grep -qxF "$nid"; then
      is_held=1
    fi
    [ "$is_new" = 1 ] || [ "$is_held" = 1 ] || continue

    nsafety=$(lh_um_fm_value "$fm" safety)
    ntouches=$(lh_note_fm_list "$fm" touches | tr '\n' ',' | sed 's/,$//')
    ncheck=$(lh_um_fm_value "$fm" check)
    save_side "$uh" "$np" "$state/notes/$nid.md" || continue
    if [ -n "$ncheck" ] && [ "$ncheck" != none ]; then
      save_side "$uh" "$(dirname "$np")/$ncheck" "$state/notes/$nid.check.sh"
    fi
    printf '%s\t%s\t%s\t%s\n' "$nid" "notes/$nid.md" "$nsafety" "$ntouches" >> "$state/notes.tsv"
  done
}

# One adapt.tsv row for a held path, using the standard plan-time sides:
# base=held_base_for_path (a held note's own recorded base when one touches
# this path, else the plan-wide $basecommit -- the SAME base process_path
# and try_merge_file just classified and merged this path against, never
# the plan-wide $basecommit on its own), theirs=$uh, mine=HEAD. Saves each
# side that exists under $state/adapt/{base,theirs,mine}/<path>; a missing
# side is recorded "-".
write_adapt_row() { # path
  wap=$1
  wa_note_ids=$(notes_touching "$wap")
  wa_base_commit=$(held_base_for_path "$wap")
  wa_base="-"; save_side "$wa_base_commit" "$wap" "$state/adapt/base/$wap" && wa_base="adapt/base/$wap"
  wa_theirs="-"; save_side "$uh" "$wap" "$state/adapt/theirs/$wap" && wa_theirs="adapt/theirs/$wap"
  wa_mine="-"; save_side HEAD "$wap" "$state/adapt/mine/$wap" && wa_mine="adapt/mine/$wap"
  printf '%s\t%s\t%s\t%s\t%s\n' "$wap" "$wa_note_ids" "$wa_base" "$wa_theirs" "$wa_mine" >> "$state/adapt.tsv"
}

# Rebuilds $state/adapt.tsv: one row per plan.tsv row whose class is held
# (conflict, add-conflict, deleted-upstream-kept, settings).
build_adapt_tsv() {
  : > "$state/adapt.tsv"
  rm -rf "$state/adapt"
  awk -F '\t' '$2 == "conflict" || $2 == "add-conflict" || $2 == "deleted-upstream-kept" || $2 == "settings" { print $1 }' "$state/plan.tsv" |
  while IFS= read -r hp; do
    [ -n "$hp" ] || continue
    write_adapt_row "$hp"
  done
}

# Saves upstream's OWN copy of .claude/scripts/json-valid.sh into state, so
# --adapt-save can validate a .json body against it later rather than the
# founder's live copy (which could have been altered, silently, to always
# pass). Called from both cmd_plan and cmd_restore_settings_plan, right
# after each works out its own $uh -- never duplicated between them. Only
# kept if git show actually produced a real, non-empty file: upstream might
# not ship one at this commit, or the show could fail, and either way a
# stale or empty file must never linger as a false "we have upstream's
# copy" signal for cmd_adapt_save to trust.
save_upstream_json_validator() { # uh ; uses $state
  sujv_uh=$1
  mkdir -p "$state/tools" 2>/dev/null
  git show "$sujv_uh:.claude/scripts/json-valid.sh" > "$state/tools/json-valid.sh" 2>/dev/null
  [ -s "$state/tools/json-valid.sh" ] || rm -f "$state/tools/json-valid.sh"
}

cmd_plan() {
  state=$(state_dir) || { echo "error not inside a git repository"; exit 1; }
  ensure_upstream_remote >/dev/null
  verify_upstream_trust
  if ! git fetch upstream >/dev/null 2>&1; then
    echo "error could not fetch upstream"
    exit 1
  fi
  basecommit=$(recorded_base)
  [ -n "$basecommit" ] || { echo "error no base set; run --detect-base and --set-base first"; exit 1; }
  git rev-parse -q --verify "$basecommit^{commit}" >/dev/null 2>&1 || { echo "error the recorded base $basecommit is not a known commit"; exit 1; }

  db=$(upstream_default_branch) || { echo "error could not work out upstream's default branch"; exit 1; }
  uh=$(git rev-parse -q --verify "refs/remotes/upstream/$db" 2>/dev/null)
  [ -n "$uh" ] || { echo "error could not read upstream's head"; exit 1; }
  save_upstream_json_validator "$uh"

  rm -rf "$state/plan.tsv" "$state/diffs" "$state/merged" "$state/meta" \
    "$state/notes.tsv" "$state/notes" "$state/adapt.tsv" "$state/adapt" "$state/adapted.tsv" \
    "$state/.heldbase.tsv"
  mkdir -p "$state/diffs" "$state/merged"
  : > "$state/plan.tsv"

  # build_notes_tsv is run BEFORE the per-path classification loop below
  # (it used to run after; nothing in it needs plan.tsv, only
  # build_adapt_tsv does) so a held note's own touches are already known
  # when the held-base override map right after it is built.
  build_notes_tsv

  # A held note (held.tsv's 3rd column: the basecommit it was held
  # against, see cmd_apply's own held.tsv comment) needs its touched paths
  # classified against THAT base, never today's basecommit -- by the time
  # it is offered again, .claude/launchhouse-version has already advanced
  # to the upstream commit that shipped the note, so comparing the
  # founder's own (reverted) file against today's basecommit would compare
  # mine and theirs at the very same commit and read as a harmless
  # local-only edit ("keep"), never reapplied. One path can only carry one
  # override; the newest held.tsv row for it wins (file order).
  : > "$state/.heldbase.tsv"
  if [ -f "$state/held.tsv" ]; then
    while IFS='	' read -r hbid _hbreason hbbase; do
      [ -n "$hbid" ] || continue
      [ -n "$hbbase" ] || continue
      hbpaths=$(awk -F '\t' -v id="$hbid" '$1 == id { print $4 }' "$state/notes.tsv")
      printf '%s\n' "$hbpaths" | tr ',' '\n' | awk 'NF' | while IFS= read -r hbp; do
        printf '%s\t%s\n' "$hbp" "$hbbase" >> "$state/.heldbase.tsv"
      done
    done < "$state/held.tsv"
  fi

  ignore_patterns=""
  ignore_patterns=$(git show "$uh:.launchhouse-update-ignore" 2>/dev/null | grep -v '^#' | grep -v '^[[:space:]]*$')

  all_paths=$(
    { git ls-tree -r --name-only "$basecommit" 2>/dev/null
      git ls-tree -r --name-only HEAD 2>/dev/null
      git ls-tree -r --name-only "$uh" 2>/dev/null
    } | grep -v '^growth-engine/' | sort -u
  )

  printf '%s\n' "$all_paths" | while IFS= read -r p; do
    [ -n "$p" ] || continue
    process_path "$p"
  done

  build_adapt_tsv

  {
    printf 'base=%s\n' "$basecommit"
    printf 'upstream=%s\n' "$uh"
    printf 'head=%s\n' "$(git rev-parse HEAD)"
    printf 'time=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date)"
  } > "$state/meta"

  awk -F '\t' '{ c[$2]++ } END { for (k in c) print k "=" c[k] }' "$state/plan.tsv" | sort
}

# ------------------------------------------------------------- adapt-save

# Validates and stores an adapted file body for one held path, returned by
# the read-only adapting worker (docs/purpose-based-updates.md section 4
# step 3). Never trusts the worker's own restraint: every check here is
# deterministic. Line endings are made to match the founder's own copy of
# the file (mine), never normalized to LF outright (section 6, Windows).
#
# The third argument is the comma-separated list of note ids this adapted
# body brings in (the notes the founder actually approved for this path),
# or "-" for a held path adapted with no note behind it (e.g. the
# restore-settings-plan bridge row). Recorded in $state/adapted.tsv as
# path<TAB>note-ids. Omitted (an older caller) is treated the same as "-".
cmd_adapt_save() {
  asp=${1:-}
  asbody=${2:-}
  asnoteids=${3:-}
  [ -n "$asnoteids" ] || asnoteids="-"
  state=$(state_dir) || { echo "result=refused"; echo "reason=not inside a git repository"; exit 1; }
  if [ -z "$asp" ] || [ -z "$asbody" ]; then
    echo "result=refused"; echo "reason=usage: --adapt-save <path> <body-file> <note-ids>"; exit 1
  fi
  [ -f "$state/adapt.tsv" ] || { echo "result=refused"; echo "reason=no plan found; run --plan first"; exit 1; }

  if [ ! -f "$asbody" ] || [ ! -r "$asbody" ]; then
    echo "result=refused"; echo "reason=body file not found or unreadable: $asbody"; exit 1
  fi
  if [ ! -s "$asbody" ]; then
    echo "result=refused"; echo "reason=the adapted body is empty"; exit 1
  fi

  asrow=$(awk -F '\t' -v p="$asp" '$1 == p { print; exit }' "$state/adapt.tsv")
  if [ -z "$asrow" ]; then
    echo "result=refused"; echo "reason=$asp is not a held path in the current plan"; exit 1
  fi
  as_notefield=$(printf '%s' "$asrow" | awk -F '\t' '{ print $2 }')

  case $asp in
    growth-engine/*)
      echo "result=refused"; echo "reason=growth-engine/ is never touched by an update"; exit 1
      ;;
  esac

  uh=$(awk -F '=' '$1 == "upstream" { print $2 }' "$state/meta" 2>/dev/null)
  ignore_patterns=""
  [ -n "$uh" ] && ignore_patterns=$(git show "$uh:.launchhouse-update-ignore" 2>/dev/null | grep -v '^#' | grep -v '^[[:space:]]*$')
  if path_ignored "$asp"; then
    echo "result=refused"; echo "reason=$asp is ignored by this update"; exit 1
  fi

  if is_symlink_at HEAD "$asp"; then
    echo "result=refused"; echo "reason=$asp is a symlink in the founder's own copy"; exit 1
  fi
  if [ -n "$uh" ] && is_symlink_at "$uh" "$asp"; then
    echo "result=refused"; echo "reason=$asp is a symlink upstream"; exit 1
  fi

  if [ "$asnoteids" != "-" ]; then
    as_bad=$(printf '%s\n' "$asnoteids" | tr ',' '\n' | while IFS= read -r aid; do
      [ -n "$aid" ] || continue
      printf '%s' ",$as_notefield," | grep -qF ",$aid," || printf '%s ' "$aid"
    done)
    if [ -n "$as_bad" ]; then
      echo "result=refused"
      echo "reason=note id(s) not listed for $asp in the current plan: $as_bad"
      exit 1
    fi
  fi

  case $asp in
    *.json)
      # Upstream's own copy, saved into state at plan time, is preferred
      # over the founder's live copy: the live one could have been altered
      # (by the founder, or anything running on their machine) to always
      # exit 0, silently defeating this check. Falls back to the live copy
      # only when no state copy was saved (an older plan, or upstream
      # ships none at this commit), and still refuses outright, exactly as
      # before, if neither is present -- fail closed either way.
      as_jv="$state/tools/json-valid.sh"
      [ -s "$as_jv" ] || as_jv="$root/.claude/scripts/json-valid.sh"
      if [ ! -f "$as_jv" ]; then
        echo "result=refused"
        echo "reason=$asp is JSON but json-valid.sh is not available to check it; refusing rather than risk writing broken JSON"
        exit 1
      fi
      as_jv_out=$(sh "$as_jv" "$asbody" 2>&1)
      as_jv_rc=$?
      if [ "$as_jv_rc" != 0 ]; then
        as_jv_reason=$(printf '%s\n' "$as_jv_out" | grep '^reason=' | tail -1 | sed 's/^reason=//')
        echo "result=refused"
        if [ -n "$as_jv_reason" ]; then
          echo "reason=the adapted body is not valid JSON: $as_jv_reason"
        else
          echo "reason=the adapted body is not valid JSON"
        fi
        exit 1
      fi
      ;;
  esac

  mkdir -p "$state/merged/$(dirname "$asp")" 2>/dev/null
  as_cr=$(printf '\r')
  as_mine_ref="$state/adapt/mine/$asp"
  [ -f "$as_mine_ref" ] || as_mine_ref="$root/$asp"
  as_crlf=0
  [ -f "$as_mine_ref" ] && grep -q "$as_cr" "$as_mine_ref" 2>/dev/null && as_crlf=1

  as_tmp="$state/.tmp.adaptsave.$$"
  tr -d '\r' < "$asbody" > "$as_tmp" 2>/dev/null
  if [ "$as_crlf" = 1 ]; then
    sed "s/\$/${as_cr}/" "$as_tmp" > "$state/merged/$asp"
  else
    cp "$as_tmp" "$state/merged/$asp"
  fi
  rm -f "$as_tmp"

  as_rec="$state/.tmp.adapted.$$"
  if [ -f "$state/adapted.tsv" ]; then
    awk -F '\t' -v p="$asp" '$1 != p' "$state/adapted.tsv" > "$as_rec"
  else
    : > "$as_rec"
  fi
  printf '%s\t%s\n' "$asp" "$asnoteids" >> "$as_rec"
  mv "$as_rec" "$state/adapted.tsv"

  echo "saved=$asp"
}

# ------------------------------------------------------ restore-settings-plan

# The post-bridge re-adaptation (docs/purpose-based-updates.md section 8):
# finds the most recent launchhouse-pre-update-* tag at which the founder's
# settings.json was customized away from that update's own base, while the
# live settings.json today still equals whatever that update took wholesale
# -- meaning the founder never touched it again since. If found, writes a
# one-row plan the founder goes through the ordinary adapt/approve/--apply
# flow with, same as any other held row.
cmd_restore_settings_plan() {
  state=$(state_dir) || { echo "error not inside a git repository"; exit 1; }
  ensure_upstream_remote >/dev/null
  verify_upstream_trust
  if ! git fetch upstream >/dev/null 2>&1; then
    echo "error could not fetch upstream"
    exit 1
  fi
  db=$(upstream_default_branch) || { echo "error could not work out upstream's default branch"; exit 1; }
  uh=$(git rev-parse -q --verify "refs/remotes/upstream/$db" 2>/dev/null)
  [ -n "$uh" ] || { echo "error could not read upstream's head"; exit 1; }
  save_upstream_json_validator "$uh"

  rsp=.claude/settings.json
  found_tag=""
  found_update_commit=""
  found_base=""

  # Every tag a past call already offered (result=found), read once --
  # never offered a second time, whatever it would resolve to this time.
  rs_offered=""
  [ -f "$state/restore-offered" ] && rs_offered=$(cat "$state/restore-offered")

  # Walk HEAD's own history, newest commit first (git rev-list's default
  # order), and take the first (so: most recent) pre-update tag reached
  # that satisfies the condition below. Never sorted by tag creator-date:
  # two tags made back to back in the same automated run can carry the
  # exact same timestamp, which makes creator-date order ambiguous: commit
  # ancestry never is.
  rs_commits=$(git rev-list HEAD 2>/dev/null)
  for rtc in $rs_commits; do
    rs_here_tags=$(git tag --points-at "$rtc" 2>/dev/null | grep '^launchhouse-pre-update-')
    [ -n "$rs_here_tags" ] || continue
    for rt in $rs_here_tags; do
      if [ -n "$rs_offered" ] && printf '%s\n' "$rs_offered" | grep -qxF "$rt"; then
        continue
      fi
      ruc=$(git rev-list --ancestry-path --reverse "$rtc..HEAD" 2>/dev/null | head -1)
      [ -n "$ruc" ] || continue
      rmsg=$(git log -1 --format=%s "$ruc" 2>/dev/null)
      case $rmsg in "Launchhouse update to"*) : ;; *) continue ;; esac
      rparent=$(git rev-parse -q --verify "$ruc^" 2>/dev/null)
      [ "$rparent" = "$rtc" ] || continue

      rbase=$(git show "$rtc:.claude/launchhouse-version" 2>/dev/null | tr -d ' \t\r\n')
      [ -n "$rbase" ] || continue
      git rev-parse -q --verify "$rbase^{commit}" >/dev/null 2>&1 || continue

      rtag_hash=$(norm_hash "$rtc" "$rsp")
      rbase_hash=$(norm_hash "$rbase" "$rsp")
      [ -n "$rtag_hash" ] || continue
      [ "$rtag_hash" != "$rbase_hash" ] || continue

      rupdate_hash=$(norm_hash "$ruc" "$rsp")
      rlive_hash=$(norm_hash HEAD "$rsp")
      if [ -n "$rupdate_hash" ] && [ "$rupdate_hash" = "$rlive_hash" ]; then
        # Only a tag where that update took settings.json wholesale is a
        # candidate to restore from. When $ruc's own apply recorded (see
        # cmd_apply) that this path was "adapted" instead, the founder's
        # customisation was already folded into the merged body rather
        # than dropped -- restoring the pre-update copy from $rt would
        # hand back a stale customisation and silently drop whatever else
        # that merge also kept, so this tag is skipped rather than
        # offered. No record at all (a tag from before this apply-time
        # bookkeeping existed) keeps the older, permissive behaviour:
        # treated as taken.
        rs_mode=$(awk -F '\t' -v t="$rt" -v p="$rsp" '$1 == t && $2 == p { m = $3 } END { print m }' "$state/settings-resolutions" 2>/dev/null)
        if [ "$rs_mode" = adapted ]; then
          continue
        fi
        found_tag=$rt
        found_update_commit=$ruc
        found_base=$rbase
        break
      fi
    done
    [ -n "$found_tag" ] && break
  done

  if [ -z "$found_tag" ]; then
    echo "restore=none"
    exit 0
  fi

  mkdir -p "$state"

  # Nothing to adapt if the founder's original customisation (at the tag
  # itself) is already exactly what is live today -- restoring would be a
  # no-op, so this is reported the same as "nothing found" rather than
  # offering a pointless restore. This candidate is settled right now,
  # nothing left for the founder to decide, so it is recorded straight into
  # restore-offered (never offered again) rather than left pending.
  if [ "$(norm_hash "$found_tag" "$rsp")" = "$(norm_hash HEAD "$rsp")" ]; then
    printf '%s\n' "$found_tag" >> "$state/restore-offered"
    rm -f "$state/restore-pending"
    echo "restore=none"
    exit 0
  fi

  # A real offer is about to be made: record it as pending, not settled.
  # Only --restore-settings-decline (the founder said no) or a successful
  # --apply of this same restore plan (cmd_apply, on restore_from_tag in
  # meta) ever moves this tag into restore-offered. An interrupted session
  # -- neither of those having happened -- must find this same tag again
  # next time, never restore=none: this is the founder's only path back to
  # a settings.json customisation an earlier update overwrote, and losing
  # it to an interruption would be a real loss, not a safe default.
  printf '%s\n' "$found_tag" > "$state/restore-pending"

  rm -rf "$state/plan.tsv" "$state/diffs" "$state/merged" "$state/meta" \
    "$state/notes.tsv" "$state/notes" "$state/adapt.tsv" "$state/adapt" "$state/adapted.tsv"
  mkdir -p "$state/diffs" "$state/merged"

  basecommit=$found_base

  : > "$state/plan.tsv"
  write_row "$rsp" settings hold "settings.json was taken wholesale during the $found_tag update; restoring the founder's customisation from before that point"
  write_diffs "$rsp"

  build_notes_tsv

  : > "$state/adapt.tsv"
  rm -rf "$state/adapt"
  rs_note_ids=$(notes_touching "$rsp")
  rs_base="-"; save_side "$found_base" "$rsp" "$state/adapt/base/$rsp" && rs_base="adapt/base/$rsp"
  rs_theirs="-"; save_side HEAD "$rsp" "$state/adapt/theirs/$rsp" && rs_theirs="adapt/theirs/$rsp"
  rs_mine="-"; save_side "$found_tag" "$rsp" "$state/adapt/mine/$rsp" && rs_mine="adapt/mine/$rsp"
  printf '%s\t%s\t%s\t%s\t%s\n' "$rsp" "$rs_note_ids" "$rs_base" "$rs_theirs" "$rs_mine" > "$state/adapt.tsv"

  {
    printf 'base=%s\n' "$found_base"
    printf 'upstream=%s\n' "$uh"
    printf 'head=%s\n' "$(git rev-parse HEAD)"
    printf 'time=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date)"
    printf 'restore_from_tag=%s\n' "$found_tag"
  } > "$state/meta"

  echo "restore=found"
  printf 'path=%s\n' "$rsp"
  printf 'from_tag=%s\n' "$found_tag"
}

# The founder said no to a pending restore offer (or the calling skill is
# moving on without one). Resolves whatever tag --restore-settings-plan last
# left in $state/restore-pending: recorded as offered (never offered again)
# and the pending marker cleared. If nothing is pending, this is a no-op
# that still reports plainly rather than erroring, since the calling skill
# may call this defensively even when it knows nothing was offered.
cmd_restore_settings_decline() {
  state=$(state_dir) || { echo "error not inside a git repository"; exit 1; }
  if [ -s "$state/restore-pending" ]; then
    rd_tag=$(cat "$state/restore-pending")
    mkdir -p "$state"
    printf '%s\n' "$rd_tag" >> "$state/restore-offered"
    rm -f "$state/restore-pending"
    echo "declined=$rd_tag"
  else
    echo "declined=none"
  fi
}

# --------------------------------------------------------------------- apply

# Only what protects the founder can stop an update. Two different kinds of
# check run here, and only one of them can abort:
#
#   GATING (decides the apply; a failure here aborts): the update notes'
#   own safety checks (.claude/tests/updates-checks.sh, which already fails
#   closed for a safety note and only ever WARNs -- never fails -- on a
#   non-safety note once this is a founder copy, so its own exit code IS
#   the safety-note signal); settings.json still being valid JSON; every
#   hook command settings.json names still resolving to a real, syntax-
#   clean script; and growth-engine/ in the worktree still being byte-
#   identical to the founder's own HEAD (an update never touches it, and
#   this is the fail-closed proof of that, not a courtesy). And, whenever
#   this plan carries a safety: true note at all: updates-checks.sh,
#   settings.json and json-valid.sh (preferring the upstream copy --plan
#   saved into state, else the worktree's own) must each actually EXIST --
#   gate_failed=safety-checks-missing / settings-missing / validator-missing
#   the moment one is not, never treated as "nothing to check".
#
#   NOT GATING (recorded, never stops anything): the full maintainer test
#   suite -- .claude/tests/run.sh, .claude/tests/state.sh, skill-packs.sh
#   --validate/--check-compiled. Its complete output is written to
#   $state/last-checks.log (overwritten every apply, with a header) purely
#   for a maintainer to read later; a failure there never aborts and is
#   never shown to the founder as an error.
#
# Prints "gate_failed=<name>" to stdout, once per failed gating check, and
# "checks=none" if the maintainer suite found nothing at all to run (no
# run.sh, no state.sh, no skill-packs.sh) -- cmd_apply still refuses THAT
# case unless --allow-no-checks, same as before this split. Returns 1 the
# moment any gating check fails, 0 otherwise; the maintainer suite's own
# result never changes the return code.
run_checks_in() { # dir
  d=$1
  rci_fail=0

  # Fail CLOSED, never open, the moment any update note this plan carries is
  # safety: true (column 3 of $state/notes.tsv, "true" for a safety note):
  # the machinery that note's own safety depends on -- updates-checks.sh to
  # actually run it, settings.json to run it against, json-valid.sh to
  # trust settings.json is even well-formed -- being merely ABSENT must
  # never look the same as "nothing to check". Each one missing is its own
  # named gate failure, exactly like a check that ran and failed.
  rci_has_safety=0
  if [ -f "$state/notes.tsv" ] && awk -F '\t' '$3 == "true" { f = 1 } END { exit !f }' "$state/notes.tsv"; then
    rci_has_safety=1
  fi

  if [ -f "$d/.claude/tests/updates-checks.sh" ]; then
    if ! ( cd "$d" && unset LH_UPDATE_RELOCATED LH_UPDATE_ROOT && sh .claude/tests/updates-checks.sh ) >/dev/null 2>&1; then
      echo "gate_failed=updates-checks.sh"
      rci_fail=1
    fi
  elif [ "$rci_has_safety" = 1 ]; then
    echo "gate_failed=safety-checks-missing"
    rci_fail=1
  fi

  # Which copy of json-valid.sh settings.json is checked against: the
  # upstream copy --plan saved into state (save_upstream_json_validator,
  # trusted over a founder's own live copy that could have been altered to
  # always pass) when one was saved, else the worktree's own copy. Used
  # both for the ordinary settings.json-changed check below and for the
  # safety gate beneath it.
  rci_jv=""
  if [ -n "${state:-}" ] && [ -s "$state/tools/json-valid.sh" ]; then
    rci_jv="$state/tools/json-valid.sh"
  elif [ -f "$d/.claude/scripts/json-valid.sh" ]; then
    rci_jv="$d/.claude/scripts/json-valid.sh"
  fi

  if [ -f "$d/.claude/settings.json" ] && [ -n "$rci_jv" ]; then
    if ! ( cd "$d" && sh "$rci_jv" .claude/settings.json ) >/dev/null 2>&1; then
      echo "gate_failed=settings.json"
      rci_fail=1
    fi
  fi

  if [ "$rci_has_safety" = 1 ]; then
    if [ ! -f "$d/.claude/settings.json" ]; then
      echo "gate_failed=settings-missing"
      rci_fail=1
    fi
    if [ -z "$rci_jv" ]; then
      echo "gate_failed=validator-missing"
      rci_fail=1
    fi
  fi

  if [ -f "$d/.claude/settings.json" ]; then
    rci_hookfail=0
    rci_cmds=$(extract_hook_commands "$d/.claude/settings.json")
    while IFS= read -r rci_hc; do
      [ -n "$rci_hc" ] || continue
      rci_hs=$(hook_script_relpath "$rci_hc")
      [ -n "$rci_hs" ] || continue
      rci_hf="$d/$rci_hs"
      if [ ! -f "$rci_hf" ] || [ ! -r "$rci_hf" ] || ! sh -n "$rci_hf" >/dev/null 2>&1; then
        rci_hookfail=1
      fi
    done <<EOF
$rci_cmds
EOF
    if [ "$rci_hookfail" = 1 ]; then
      echo "gate_failed=hook-script"
      rci_fail=1
    fi
  fi

  rci_ge_wt=$(git -C "$d" rev-parse -q --verify HEAD:growth-engine 2>/dev/null)
  rci_ge_root=$(git rev-parse -q --verify HEAD:growth-engine 2>/dev/null)
  if [ "$rci_ge_wt" != "$rci_ge_root" ]; then
    echo "gate_failed=growth-engine"
    rci_fail=1
  fi

  rci_full=$( {
    printf 'Launchhouse update checks\n'
    printf 'date: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date)"
    printf 'base: %s\n' "${basecommit:-unknown}"
    printf 'upstream: %s\n' "${cur_upstream:-unknown}"
    printf '\n'
    rci_ran=0
    if [ -f "$d/.claude/tests/run.sh" ]; then
      rci_ran=1
      printf -- '--- .claude/tests/run.sh ---\n'
      ( cd "$d" && unset LH_UPDATE_RELOCATED LH_UPDATE_ROOT && sh .claude/tests/run.sh ) 2>&1
      printf '(exit %s)\n' "$?"
    fi
    if [ -f "$d/.claude/tests/state.sh" ]; then
      rci_ran=1
      printf -- '--- .claude/tests/state.sh ---\n'
      ( cd "$d" && unset LH_UPDATE_RELOCATED LH_UPDATE_ROOT && sh .claude/tests/state.sh ) 2>&1
      printf '(exit %s)\n' "$?"
    fi
    if [ -f "$d/.claude/scripts/skill-packs.sh" ]; then
      rci_ran=1
      printf -- '--- skill-packs.sh --validate all ---\n'
      ( cd "$d" && sh .claude/scripts/skill-packs.sh --validate all ) 2>&1
      printf '(exit %s)\n' "$?"
      printf -- '--- skill-packs.sh --check-compiled ---\n'
      ( cd "$d" && sh .claude/scripts/skill-packs.sh --check-compiled ) 2>&1
      printf '(exit %s)\n' "$?"
    fi
    [ "$rci_ran" = 1 ] || echo "checks=none"
  } 2>&1 )

  if [ -n "${state:-}" ]; then
    mkdir -p "$state" 2>/dev/null
    printf '%s\n' "$rci_full" > "$state/last-checks.log"
  fi
  printf '%s\n' "$rci_full" | grep -q '^checks=none$' && echo "checks=none"

  [ "$rci_fail" = 0 ]
}

decision_for() { # path, decisions file
  awk -F '\t' -v p="$1" '$1 == p { d = $2 } END { if (d != "") print d }' "$2"
}

# --------------------------------------------------- post-landing fail-safe
# Runs once the update commit is already live in $root (after the ff-only
# merge), never inside the throwaway worktree: this is the last check, on
# the actual folder a founder will next open Claude in.

# Every "command" value out of a settings.json hooks block, one per line,
# unescaped (settings.json quotes an embedded $CLAUDE_PROJECT_DIR path as
# \"...\", which this un-escapes back to a plain ").
extract_hook_commands() { # settings-file
  ehc_f=$1
  [ -f "$ehc_f" ] || return 0
  grep '"command"[[:space:]]*:' "$ehc_f" |
    sed -n 's/^[[:space:]]*"command"[[:space:]]*:[[:space:]]*"\(.*\)"[,]*[[:space:]]*$/\1/p' |
    sed 's/\\"/"/g'
}

# The script path a hook command names, relative to $CLAUDE_PROJECT_DIR,
# for a command of the exact shape every hook in this repo's own
# settings.json uses: sh "$CLAUDE_PROJECT_DIR/<path>"[ <extra args>]. Empty
# for anything else (a founder's own pack could in principle wire a hook up
# differently; this only ever narrows what post_landing_smoke can check
# beforehand, it is never what decides whether the command is run). Plain
# shell prefix/suffix matching throughout, never a regex -- "$" is not
# special in a glob pattern, so this needs no escaping at all.
hook_script_relpath() { # command string
  case $1 in
    'sh "$CLAUDE_PROJECT_DIR/'*)
      hsr=${1#*'$CLAUDE_PROJECT_DIR/'}
      hsr=${hsr%%\"*}
      printf '%s' "$hsr"
      ;;
  esac
}

# Sets smoke_reason/smoke_detail and returns 1 the moment any of the four
# live checks fails; returns 0 once all pass. $root is already the live,
# just-landed folder (cwd throughout this script, outside the worktree).
# smoke_needs_reset is set to 1 only when check 3 is what failed -- a
# checkout-time change to a TRACKED file under .claude/, which leaves the
# working tree not clean and would otherwise make the automatic undo's own
# is_clean guard refuse for no real reason.
post_landing_smoke() {
  smoke_reason=""
  smoke_detail=""
  smoke_needs_reset=0

  # 1. The notes' own purpose checks, run for real against the live folder
  # -- only if this founder's copy carries .claude/tests/updates-checks.sh
  # at all; an older copy without it yet has nothing here to fail.
  if [ -f "$root/.claude/tests/updates-checks.sh" ]; then
    pls_out=$( (cd "$root" && sh .claude/tests/updates-checks.sh) 2>&1 )
    pls_rc=$?
    if [ "$pls_rc" != 0 ]; then
      smoke_reason="the update notes' own checks failed once the update actually landed"
      smoke_detail=$(printf '%s\n' "$pls_out" | tail -20)
      return 1
    fi
  fi

  # 2. settings.json itself is still valid JSON, once the update actually
  # landed -- only if this founder's copy carries json-valid.sh yet; an
  # older copy without it has nothing here to fail.
  pls_settings="$root/.claude/settings.json"
  if [ -f "$root/.claude/scripts/json-valid.sh" ] && [ -f "$pls_settings" ]; then
    pls_jv_out=$( (cd "$root" && sh .claude/scripts/json-valid.sh .claude/settings.json) 2>&1 )
    pls_jv_rc=$?
    if [ "$pls_jv_rc" != 0 ]; then
      smoke_reason="settings.json is not valid JSON once the update actually landed"
      smoke_detail=$(printf '%s\n' "$pls_jv_out" | tail -20)
      return 1
    fi
  fi

  # 3. Every hook command named in the live settings.json resolves to a
  # real, readable script with no shell syntax error -- NEVER actually run.
  # Several hooks (context.sh, refresh.sh, prompt-state.sh, turn-end.sh,
  # guard-post.sh) write founder state under growth-engine/ when they
  # actually run, and an update must never touch growth-engine/, not even
  # as a side effect of a check -- so this only resolves the script path
  # each hook command names and checks it exists, is readable, and has no
  # syntax error. Nothing is executed, and no throwaway copy of .claude/ is
  # needed to run anything in.
  if [ -f "$pls_settings" ]; then
    pls_cmds="$state/.tmp.hookcmds.$$"
    extract_hook_commands "$pls_settings" > "$pls_cmds"
    hookfail=""
    while IFS= read -r hc; do
      [ -n "$hc" ] || continue
      hc_script=$(hook_script_relpath "$hc")
      if [ -n "$hc_script" ]; then
        hc_full="$root/$hc_script"
        if [ ! -f "$hc_full" ] || [ ! -r "$hc_full" ]; then
          hookfail="$hookfail$hc :: script missing or unreadable: $hc_script
"
          continue
        fi
        hc_synerr=$(sh -n "$hc_full" 2>&1)
        if [ -n "$hc_synerr" ]; then
          hookfail="$hookfail$hc :: syntax error: $hc_synerr
"
          continue
        fi
      fi
    done < "$pls_cmds"
    rm -f "$pls_cmds"
    if [ -n "$hookfail" ]; then
      smoke_reason="a hook command in settings.json names a script that is missing, unreadable, or has a syntax error"
      smoke_detail=$(printf '%s\n' "$hookfail" | head -10)
      return 1
    fi
  fi

  # 4. No tracked file under .claude/ lost its trailing newline or had its
  # line endings flipped relative to what the update commit actually
  # recorded (a checkout-time normalization, never caught by the
  # CRLF-insensitive comparisons used everywhere else in this script on
  # purpose). If this fires, the tracked files are reset back to HEAD by
  # the caller before it undoes, so the checkout artifact itself never
  # makes the automatic undo's own clean-tree guard refuse.
  pls_led=$(cd "$root" && git diff --name-only HEAD -- .claude/ 2>/dev/null)
  if [ -n "$pls_led" ]; then
    smoke_reason="a file under .claude/ no longer matches what the update commit recorded (line endings or a trailing newline may have changed on checkout)"
    smoke_detail=$pls_led
    smoke_needs_reset=1
    return 1
  fi

  return 0
}

# True (exit 0) if $1 is empty or names no live process -- i.e. a lock
# holding this pid is stale and safe to clear.
apply_lock_is_stale() { # pid
  als_pid=$1
  [ -n "$als_pid" ] || return 0
  kill -0 "$als_pid" 2>/dev/null && return 1
  return 0
}

# Clears a worktree (and its branch) left behind by an --apply that was cut
# off mid-run -- a Bash tool timeout, a killed process, the machine
# sleeping -- rather than leaving every apply after that one failing
# forever with "could not create a worktree" (the old engine, and this one
# both before this fix, always used the same fixed path, $state/wt, so a
# stale worktree there blocks every future apply, not just a retry of the
# same one). Only ever acts when no OTHER apply is genuinely running right
# now: a lock file under $state holds the pid of whichever apply currently
# owns $state/wt, and a lock whose own pid is no longer alive is itself
# stale (the process that wrote it is gone), cleared the same way a stale
# worktree is. Claims the lock for this run before returning; the caller
# is responsible for releasing it (a trap on EXIT, set right after this
# call, covers every exit path -- success, an aborted apply, or this
# process itself being killed in turn).
heal_stale_apply_worktree() { # ; uses $state
  hsaw_lock="$state/apply.lock"
  if [ -f "$hsaw_lock" ]; then
    hsaw_pid=$(cat "$hsaw_lock" 2>/dev/null)
    if ! apply_lock_is_stale "$hsaw_pid"; then
      echo "result=aborted"
      echo "reason=another update apply is already running (pid $hsaw_pid); wait for it to finish, or if it is truly gone, remove $hsaw_lock by hand and try again"
      exit 1
    fi
    rm -f "$hsaw_lock"
  fi

  hsaw_wt="$state/wt"
  hsaw_registered=$(git worktree list --porcelain 2>/dev/null | awk -v p="$hsaw_wt" '$1 == "worktree" && $2 == p { print "1"; exit }')
  if [ -d "$hsaw_wt" ] || [ -n "$hsaw_registered" ]; then
    git worktree remove --force "$hsaw_wt" >/dev/null 2>&1
    git worktree prune >/dev/null 2>&1
    rm -rf "$hsaw_wt" 2>/dev/null
  fi

  # Any launchhouse-update-wt-* branch not checked out in any worktree
  # right now (a prior run's own branch, named from a $$ that means
  # nothing any more) is safe to delete outright: this branch name is
  # never the founder's own, it only ever backs one throwaway apply
  # worktree.
  hsaw_checked_out=$(git worktree list --porcelain 2>/dev/null | awk -F 'refs/heads/' '/^branch /{ print $2 }')
  git branch --list 'launchhouse-update-wt-*' 2>/dev/null | tr -d ' *' | while IFS= read -r hsaw_b; do
    [ -n "$hsaw_b" ] || continue
    printf '%s\n' "$hsaw_checked_out" | grep -qxF "$hsaw_b" && continue
    git branch -D "$hsaw_b" >/dev/null 2>&1
  done

  mkdir -p "$state" 2>/dev/null
  printf '%s' "$$" > "$hsaw_lock"
}

cmd_apply() {
  decisions=${1:-}
  allow_no_checks=${2:-}
  [ -n "$decisions" ] || { echo "result=aborted"; echo "reason=missing decisions file"; exit 1; }
  case $decisions in
    /*|[A-Za-z]:*) : ;;
    *) decisions=$(cd "$(dirname "$decisions")" 2>/dev/null && pwd)/$(basename "$decisions") ;;
  esac
  [ -f "$decisions" ] || { echo "result=aborted"; echo "reason=decisions file not found: $decisions"; exit 1; }

  state=$(state_dir) || { echo "result=aborted"; echo "reason=not inside a git repository"; exit 1; }

  # Copy the running script somewhere the update itself can never replace out
  # from under it, and re-exec from there, once.
  if [ "${LH_UPDATE_RELOCATED:-0}" != 1 ]; then
    mkdir -p "$state/run"
    cp "$here/update.sh" "$state/run/update.sh" 2>/dev/null
    [ -f "$here/lib.sh" ] && cp "$here/lib.sh" "$state/run/lib.sh" 2>/dev/null
    chmod +x "$state/run/update.sh" 2>/dev/null
    LH_UPDATE_RELOCATED=1
    LH_UPDATE_ROOT=$root
    export LH_UPDATE_RELOCATED LH_UPDATE_ROOT
    exec sh "$state/run/update.sh" --apply "$decisions" $allow_no_checks < /dev/null
  fi

  heal_stale_apply_worktree
  trap 'rm -f "$state/apply.lock"' EXIT

  ensure_upstream_remote >/dev/null
  verify_upstream_trust

  is_clean || { echo "result=aborted"; echo "reason=working tree is not clean"; exit 1; }
  if in_progress; then echo "result=aborted"; echo "reason=a merge or rebase is already in progress"; exit 1; fi
  [ -f "$state/meta" ] && [ -f "$state/plan.tsv" ] || { echo "result=aborted"; echo "reason=no plan found; run --plan first"; exit 1; }

  planned_upstream=$(awk -F '=' '$1 == "upstream" { print $2 }' "$state/meta")
  basecommit=$(awk -F '=' '$1 == "base" { print $2 }' "$state/meta")
  planned_head=$(awk -F '=' '$1 == "head" { print $2 }' "$state/meta")
  cur_head=$(git rev-parse HEAD)
  if [ -n "$planned_head" ] && [ "$planned_head" != "$cur_head" ]; then
    echo "result=aborted"; echo "reason=folder changed since the plan; plan again"; exit 1
  fi
  if ! git fetch upstream >/dev/null 2>&1; then
    echo "result=aborted"; echo "reason=could not fetch upstream"; exit 1
  fi
  db=$(upstream_default_branch) || db=""
  cur_upstream=""
  [ -n "$db" ] && cur_upstream=$(git rev-parse -q --verify "refs/remotes/upstream/$db" 2>/dev/null)
  if [ -z "$cur_upstream" ] || [ "$planned_upstream" != "$cur_upstream" ]; then
    echo "result=aborted"; echo "reason=upstream has moved since the plan was made; run --plan again"; exit 1
  fi

  # Every row of a held class needs an explicit decision. A decision of
  # "adapted" additionally needs a saved body from --adapt-save: the
  # founder's yes is not enough on its own (docs/purpose-based-updates.md
  # section 6) if there is nothing adapted to write. And "adapted" is only
  # ever a meaningful decision on a held row to begin with -- on any other
  # class it used to be silently skipped (the per-row apply loop below has
  # no "adapted" branch for a non-held class), which could look to a caller
  # like the decision was honoured when nothing happened at all. Refused
  # outright here, before anything is touched.
  # Every value decisions.tsv actually names for a row must be one this
  # apply understands -- hold, keep-mine, take-theirs, apply, adapted (the
  # same set the per-row loop below switches on). Anything else (a typo
  # like "take" or "add" for "take-theirs"/"apply") fell through every case
  # arm in that loop with no default branch, so the row was silently
  # skipped rather than acted on -- indistinguishable, from the founder's
  # side, from a decision that was honoured. Refused outright here, before
  # anything is touched, rather than left to surface later as a confusing
  # "unchanged" apply or an unrelated safety abort.
  unknown=""
  missing=""
  bad_adapted=""
  bad_class_adapted=""
  while IFS='	' read -r path class proposed detail; do
    [ -n "$path" ] || continue
    d=$(decision_for "$path" "$decisions")
    if [ -n "$d" ]; then
      case $d in
        hold|keep-mine|take-theirs|apply|adapted) : ;;
        *) unknown="$unknown$path	$d
" ;;
      esac
    fi
    case $class in
      conflict|add-conflict|deleted-upstream-kept|settings)
        [ -n "$d" ] || missing="$missing$path
"
        if [ "$d" = adapted ] && [ ! -f "$state/merged/$path" ]; then
          bad_adapted="$bad_adapted$path
"
        fi
        ;;
      *)
        if [ "$d" = adapted ]; then
          bad_class_adapted="$bad_class_adapted$path
"
        fi
        ;;
    esac
  done < "$state/plan.tsv"
  if [ -n "$unknown" ]; then
    echo "result=aborted"
    echo "failed=unknown-decision"
    printf '%s' "$unknown" | while IFS='	' read -r ud_path ud_value; do
      [ -n "$ud_path" ] || continue
      echo "reason=$ud_path has an unrecognised decision \"$ud_value\" (must be hold, keep-mine, take-theirs, apply, or adapted)"
    done
    echo "unchanged=yes"
    exit 1
  fi
  if [ -n "$missing" ]; then
    echo "result=aborted"
    echo "reason=missing an explicit decision for:"
    printf '%s' "$missing"
    exit 1
  fi
  if [ -n "$bad_adapted" ]; then
    echo "result=aborted"
    echo "reason=no adapted body was saved for:"
    printf '%s' "$bad_adapted"
    exit 1
  fi
  if [ -n "$bad_class_adapted" ]; then
    echo "result=aborted"
    echo "reason=an 'adapted' decision is only valid for a held row (conflict, add-conflict, deleted-upstream-kept, settings):"
    printf '%s' "$bad_class_adapted"
    exit 1
  fi

  pre_head=$(git rev-parse HEAD)
  pre_status=$(git status --porcelain)

  today=$(date -u +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)
  tag="launchhouse-pre-update-$today"
  n=2
  while git rev-parse -q --verify "refs/tags/$tag" >/dev/null 2>&1; do
    tag="launchhouse-pre-update-$today-$n"
    n=$((n + 1))
  done
  git tag "$tag" HEAD >/dev/null 2>&1 || { echo "result=aborted"; echo "reason=could not create the pre-update tag"; exit 1; }

  wt="$state/wt"
  rm -rf "$wt"
  branch="launchhouse-update-wt-$$"
  git branch -D "$branch" >/dev/null 2>&1
  if ! git worktree add -q -b "$branch" "$wt" HEAD >/dev/null 2>&1; then
    echo "result=aborted"; echo "reason=could not create a worktree to apply the update in"; exit 1
  fi

  changed_paths=""
  apply_take() { # path
    p=$1
    mkdir -p "$wt/$(dirname "$p")" 2>/dev/null
    if git show "$cur_upstream:$p" > "$wt/$p" 2>/dev/null; then
      set_path_mode "$cur_upstream" "$p" "$wt/$p"
      ( cd "$wt" && git add -- "$p" ) >/dev/null 2>&1
      stage_index_mode "$wt" "$p"
      changed_paths="$changed_paths$p
"
    fi
  }
  apply_merged() { # path
    p=$1
    src="$state/merged/$p"
    if [ -f "$src" ]; then
      mkdir -p "$wt/$(dirname "$p")" 2>/dev/null
      cp "$src" "$wt/$p"
      # The merged content's own shape (executable or not) follows upstream
      # -- that is what every merge, adaptation and registry-union here is
      # ultimately reconciling towards. A path deleted upstream but kept
      # through adaptation (deleted-upstream-kept, settings) has nothing to
      # read there any more; the founder's own HEAD mode is the only
      # meaningful source left for those.
      if git rev-parse -q --verify "$cur_upstream:$p" >/dev/null 2>&1; then
        set_path_mode "$cur_upstream" "$p" "$wt/$p"
      else
        set_path_mode HEAD "$p" "$wt/$p"
      fi
      ( cd "$wt" && git add -- "$p" ) >/dev/null 2>&1
      stage_index_mode "$wt" "$p"
      changed_paths="$changed_paths$p
"
    fi
  }
  apply_delete() { # path
    p=$1
    if [ -f "$wt/$p" ]; then
      ( cd "$wt" && git rm -f -q -- "$p" ) >/dev/null 2>&1
      changed_paths="$changed_paths$p
"
    fi
  }
  backup_mine() { # path
    p=$1
    [ -f "$wt/$p" ] || return 0
    mkdir -p "$state/mine/$(dirname "$p")" 2>/dev/null
    cp "$wt/$p" "$state/mine/$p"
  }
  # Writes a path's founder-HEAD content back into the worktree (or removes
  # it, if the founder never had it) -- used only by hold_back_failing_notes
  # below, to back a held note's touches out of an apply that otherwise
  # lands. HEAD's own recorded mode goes with it: this is the founder's own
  # file exactly as it already was, never upstream's shape.
  # Returns 1 the moment any git step fails, so a caller can abort rather
  # than pretend a restore succeeded when it did not.
  restore_path_to_head() { # path
    p=$1
    rph_hsha=$(blob_sha HEAD "$p")
    if [ -n "$rph_hsha" ]; then
      mkdir -p "$wt/$(dirname "$p")" 2>/dev/null
      git show "$rph_hsha" > "$wt/$p" 2>/dev/null || return 1
      set_path_mode HEAD "$p" "$wt/$p"
      ( cd "$wt" && git add -- "$p" ) >/dev/null 2>&1 || return 1
      stage_index_mode "$wt" "$p"
    elif [ -f "$wt/$p" ]; then
      ( cd "$wt" && git rm -f -q -- "$p" ) >/dev/null 2>&1 || return 1
    fi
    return 0
  }

  # Purpose-based updates' HOLD BACK step: after the update commit below,
  # tests every non-safety note that actually has a check AND touched at
  # least one path this apply just changed. A note whose own check fails
  # against the worktree has its touched paths reset back to the founder's
  # own HEAD content (never upstream's), so the rest of the update still
  # lands instead of the whole apply aborting over one improvement. A path
  # shared with a note that is NOT being held is never restored -- "if
  # unsure, hold both notes" -- and neither is a path any SAFETY note also
  # touches, whatever else wants it back; a safety note can only ever be
  # dealt with by aborting the whole apply (see run_checks_in), never held.
  #
  # A held note whose OWN touched path cannot actually be restored (it is
  # shared with a safety note, so restoring it is refused outright) is never
  # reported as held while its change quietly stays live -- that would be a
  # lie: "held" has to mean "reverted". Instead the whole apply is aborted
  # (see $hb_abort below), the same as any other founder-safety gate
  # failure, rather than landing with an unreverted change under a "held"
  # label.
  #
  # Sets $hb_held (newline list of note ids held THIS apply, "" if none) and
  # $hb_resolved (newline list of tested notes that passed outright, so a
  # standing held.tsv row for them can come off) and, when it restores
  # anything, amends the worktree's own update commit and rewrites
  # $changed_paths to drop the restored paths. Only ever called with the
  # update commit already made in $wt.
  #
  # $hb_abort (0/1), $hb_abort_ids (comma-joined note ids or a step name)
  # and $hb_abort_reason: set instead of restoring/amending when the whole
  # apply must be aborted rather than land with a hold-back it cannot
  # honour honestly. The caller (cmd_apply) checks $hb_abort right after
  # calling this function and never runs run_checks_in when it is set.
  hold_back_failing_notes() {
    hb_held=""
    hb_resolved=""
    hb_abort=0
    hb_abort_ids=""
    hb_abort_reason=""
    [ -f "$state/notes.tsv" ] || return 0

    hb_t="$state/.tmp.hb.$$"
    hb_changed="$hb_t.changed"
    printf '%s' "$changed_paths" | awk 'NF' > "$hb_changed"

    hb_candidates="$hb_t.candidates"
    : > "$hb_candidates"
    while IFS='	' read -r hnid _hnpath hnsafety hntouches; do
      [ -n "$hnid" ] || continue
      [ "$hnsafety" = true ] && continue
      [ -f "$state/notes/$hnid.check.sh" ] || continue
      printf '%s\n' "$hntouches" | tr ',' '\n' | awk 'NF' > "$hb_t.tp"
      if grep -qFxf "$hb_t.tp" "$hb_changed" 2>/dev/null; then
        printf '%s\n' "$hnid" >> "$hb_candidates"
      fi
      rm -f "$hb_t.tp"
    done < "$state/notes.tsv"

    if [ ! -s "$hb_candidates" ]; then
      rm -f "$hb_changed" "$hb_candidates"
      return 0
    fi

    hb_final="$hb_t.final"
    : > "$hb_final"
    while IFS= read -r hnid; do
      [ -n "$hnid" ] || continue
      if ( cd "$wt" && REPO_ROOT="$wt" sh "$state/notes/$hnid.check.sh" ) >/dev/null 2>&1; then
        hb_resolved="$hb_resolved$hnid
"
      else
        printf '%s\n' "$hnid" >> "$hb_final"
      fi
    done < "$hb_candidates"

    if [ ! -s "$hb_final" ]; then
      rm -f "$hb_changed" "$hb_candidates" "$hb_final"
      return 0
    fi

    # Fixed-point widen: any other, not-yet-held, non-safety note that also
    # touches a path a currently-held note touches gets pulled in too, and
    # this repeats until nothing new is added. A safety note is never
    # pulled in this way (never held) -- see the safe-paths filter below.
    hb_grew=1
    while [ "$hb_grew" = 1 ]; do
      hb_grew=0
      : > "$hb_t.paths"
      while IFS= read -r hnid; do
        [ -n "$hnid" ] || continue
        awk -F '\t' -v id="$hnid" '$1 == id { print $4 }' "$state/notes.tsv" |
          tr ',' '\n' | awk 'NF' >> "$hb_t.paths"
      done < "$hb_final"
      sort -u "$hb_t.paths" -o "$hb_t.paths"
      while IFS='	' read -r onid _op osafety otouches; do
        [ -n "$onid" ] || continue
        [ "$osafety" = true ] && continue
        grep -qxF "$onid" "$hb_final" && continue
        printf '%s\n' "$otouches" | tr ',' '\n' | awk 'NF' > "$hb_t.otp"
        if grep -qFxf "$hb_t.otp" "$hb_t.paths" 2>/dev/null; then
          printf '%s\n' "$onid" >> "$hb_final"
          hb_grew=1
        fi
        rm -f "$hb_t.otp"
      done < "$state/notes.tsv"
    done
    rm -f "$hb_t.paths"
    sort -u "$hb_final" -o "$hb_final"
    # A note that passed its own check and then got widened back into
    # $hb_final (because it shares a touched path with a note that failed)
    # must come off $hb_resolved: it is held too now, not resolved.
    if printf '%s' "$hb_resolved" | grep -q .; then
      hb_resolved_filtered="$hb_t.resolvedf"
      printf '%s\n' "$hb_resolved" | awk 'NF' > "$hb_t.resolved0"
      grep -vxFf "$hb_final" "$hb_t.resolved0" > "$hb_resolved_filtered" 2>/dev/null || cp "$hb_t.resolved0" "$hb_resolved_filtered"
      hb_resolved=$(cat "$hb_resolved_filtered")
      [ -n "$hb_resolved" ] && hb_resolved="$hb_resolved
"
      rm -f "$hb_t.resolved0" "$hb_resolved_filtered"
    fi
    rm -f "$hb_candidates"

    : > "$hb_t.restore"
    while IFS= read -r hnid; do
      [ -n "$hnid" ] || continue
      awk -F '\t' -v id="$hnid" '$1 == id { print $4 }' "$state/notes.tsv" |
        tr ',' '\n' | awk 'NF' >> "$hb_t.restore"
    done < "$hb_final"
    sort -u "$hb_t.restore" -o "$hb_t.restore"
    # Only ever restore a path this apply actually changed.
    grep -Fxf "$hb_changed" "$hb_t.restore" > "$hb_t.restore2" 2>/dev/null || : > "$hb_t.restore2"
    mv "$hb_t.restore2" "$hb_t.restore"

    # A path any safety note also touches can never be restored -- but if
    # that leaves a held note's own change quietly live while it is
    # reported "held" (as if reverted), that is dishonest: abort the whole
    # apply instead of pretending. $hb_t.restore before this filter is
    # therefore "everything hold-back NEEDS to restore"; after it, "what it
    # is actually willing to restore" -- the difference between the two is
    # exactly what cannot be honoured.
    cp "$hb_t.restore" "$hb_t.needed"
    : > "$hb_t.safepaths"
    while IFS='	' read -r snid _sp ssafety stouches; do
      [ -n "$snid" ] || continue
      [ "$ssafety" = true ] || continue
      printf '%s\n' "$stouches" | tr ',' '\n' | awk 'NF' >> "$hb_t.safepaths"
    done < "$state/notes.tsv"
    if [ -s "$hb_t.safepaths" ]; then
      sort -u "$hb_t.safepaths" -o "$hb_t.safepaths"
      grep -vFxf "$hb_t.safepaths" "$hb_t.restore" > "$hb_t.restore2" 2>/dev/null || : > "$hb_t.restore2"
      mv "$hb_t.restore2" "$hb_t.restore"
    fi
    rm -f "$hb_t.safepaths"

    hb_diff_unrestorable=$(grep -vFxf "$hb_t.restore" "$hb_t.needed" 2>/dev/null)
    rm -f "$hb_t.needed"
    if [ -n "$hb_diff_unrestorable" ]; then
      printf '%s\n' "$hb_diff_unrestorable" > "$hb_t.blocked"
      hb_abort_ids=""
      while IFS= read -r hnid; do
        [ -n "$hnid" ] || continue
        awk -F '\t' -v id="$hnid" '$1 == id { print $4 }' "$state/notes.tsv" |
          tr ',' '\n' | awk 'NF' > "$hb_t.htp"
        if grep -qFxf "$hb_t.htp" "$hb_t.blocked" 2>/dev/null; then
          hb_abort_ids="$hb_abort_ids$hnid,"
        fi
      done < "$hb_final"
      rm -f "$hb_t.htp" "$hb_t.blocked"
      hb_abort=1
      hb_abort_ids=${hb_abort_ids%,}
      hb_abort_reason="its own check failed, but it touches a path a founder-safety note also touches, which is never reverted -- holding it back would leave its change live while reporting it held, so the whole update is aborted instead"
      rm -f "$hb_changed" "$hb_candidates" "$hb_final" "$hb_t.restore"
      return 0
    fi

    hb_restore_failed=0
    while IFS= read -r hp; do
      [ -n "$hp" ] || continue
      restore_path_to_head "$hp" || hb_restore_failed=1
    done < "$hb_t.restore"

    if [ "$hb_restore_failed" = 1 ]; then
      hb_abort=1
      hb_abort_ids="hold-back-restore"
      hb_abort_reason="could not restore a held note's own touched path back to the founder's pre-update content inside the worktree"
      rm -f "$hb_changed" "$hb_final" "$hb_t.restore"
      return 0
    fi

    # A restored path under a skill pack's own source (never the compiled
    # .claude/skill-packs/compiled-policy.sh or the registry itself, both
    # handled on their own terms) means the compiled/installed outputs the
    # apply already staged above no longer match what is now back in the
    # worktree -- recompile and reinstall before amending, so a held pack
    # source never leaves a stale generated file landed against it.
    hb_pack_source=0
    while IFS= read -r hp; do
      [ -n "$hp" ] || continue
      case $hp in
        .claude/skill-packs/compiled-policy.sh|.claude/skill-packs/registry.tsv) : ;;
        .claude/skill-packs/*) hb_pack_source=1 ;;
      esac
    done < "$hb_t.restore"
    if [ "$hb_pack_source" = 1 ] && [ -f "$wt/.claude/scripts/skill-packs.sh" ]; then
      # --install REFUSES to overwrite a destination that already exists
      # and does not already match what the (now-restored) source would
      # produce (lh_install_one's own REFUSED case) -- exactly the
      # generated copy this apply's first compile/install pass just wrote
      # from the upstream source that was just reverted away. Remove the
      # same generated paths $gen_paths named the very first time (still
      # in scope from earlier in this apply; compiled-policy.sh is
      # rewritten in place, never removed) so --install finds a clean slot
      # to regenerate into, instead of comparing against its own now-stale
      # output and refusing.
      printf '%s\n' "$gen_paths" | while IFS= read -r hb_gp; do
        [ -n "$hb_gp" ] || continue
        case $hb_gp in .claude/skill-packs/compiled-policy.sh) continue ;; esac
        rm -f "$wt/$hb_gp"
      done
      ( cd "$wt" && sh .claude/scripts/skill-packs.sh --compile ) >/dev/null 2>&1
      ( cd "$wt" && git add -- .claude/skill-packs/compiled-policy.sh ) >/dev/null 2>&1
      ( cd "$wt" && sh .claude/scripts/skill-packs.sh --install all ) >/dev/null 2>&1
      [ -d "$wt/.claude/skills" ] && ( cd "$wt" && git add -A -- .claude/skills ) >/dev/null 2>&1
      [ -d "$wt/.claude/agents" ] && ( cd "$wt" && git add -A -- .claude/agents ) >/dev/null 2>&1
      hb_regen=$( ( cd "$wt" && git diff --cached --name-only -- \
        .claude/skill-packs/compiled-policy.sh .claude/skills .claude/agents ) 2>/dev/null )
      if [ -n "$hb_regen" ]; then
        printf '%s\n' "$hb_regen" >> "$hb_t.restore"
        sort -u "$hb_t.restore" -o "$hb_t.restore"
      fi
    fi

    if [ -s "$hb_t.restore" ]; then
      grep -vFxf "$hb_t.restore" "$hb_changed" > "$hb_t.newchanged" 2>/dev/null || cp "$hb_changed" "$hb_t.newchanged"
      changed_paths=$(cat "$hb_t.newchanged")
      [ -n "$changed_paths" ] && changed_paths="$changed_paths
"
      if ! ( cd "$wt" && git commit -q --amend --no-edit ) >/dev/null 2>&1; then
        hb_abort=1
        hb_abort_ids="hold-back-commit"
        hb_abort_reason="could not amend the update commit in the worktree after holding a note back"
        rm -f "$hb_t.newchanged" "$hb_changed" "$hb_final" "$hb_t.restore"
        return 0
      fi
      rm -f "$hb_t.newchanged"
    fi

    hb_held=$(cat "$hb_final")

    rm -f "$hb_changed" "$hb_final" "$hb_t.restore"
  }

  while IFS='	' read -r path class proposed detail; do
    [ -n "$path" ] || continue
    case $path in growth-engine/*) continue ;; esac
    case $class in generated) continue ;; esac
    d=$(decision_for "$path" "$decisions")
    [ -n "$d" ] || d=hold
    case $d in
      hold|keep-mine) continue ;;
      take-theirs)
        backup_mine "$path"
        case $class in
          take|add) apply_take "$path" ;;
          merged-clean|registry-merge) apply_merged "$path" ;;
          delete) apply_delete "$path" ;;
          conflict|add-conflict|deleted-upstream-kept|settings) apply_take "$path" ;;
        esac
        ;;
      apply)
        case $class in
          take|add) apply_take "$path" ;;
          merged-clean|registry-merge) apply_merged "$path" ;;
          delete) apply_delete "$path" ;;
          keep) : ;;
          conflict|add-conflict|deleted-upstream-kept|settings)
            backup_mine "$path"
            apply_take "$path"
            ;;
        esac
        ;;
      adapted)
        # Reuses apply_merged outright: --adapt-save already wrote the
        # founder-approved adapted body to $state/merged/$path, the exact
        # same place a clean three-way merge's own result lives. The
        # pre-flight gate above already refused this whole apply if that
        # body is missing.
        case $class in
          conflict|add-conflict|deleted-upstream-kept|settings)
            backup_mine "$path"
            apply_merged "$path"
            ;;
        esac
        ;;
    esac

    # settings.json's own resolution this apply, keyed by this apply's
    # pre-update tag: "taken" when the row's decision left upstream's copy
    # wholesale (apply or take-theirs, both of which call apply_take for a
    # settings-class row), "adapted" when it kept a merged body that folds
    # the founder's customisation in (apply_merged, via decision "adapted").
    # cmd_restore_settings_plan reads this back so it only ever offers a
    # restore for a tag where settings.json was taken wholesale -- an
    # adapted resolution already carries the founder's customisation
    # forward, so offering to restore it from before that point would hand
    # back a stale copy and silently drop whatever upstream also added.
    if [ "$class" = settings ]; then
      case $d in
        take-theirs|apply) printf '%s\t%s\ttaken\n' "$tag" "$path" >> "$state/settings-resolutions" ;;
        adapted) printf '%s\t%s\tadapted\n' "$tag" "$path" >> "$state/settings-resolutions" ;;
      esac
    fi
  done < "$state/plan.tsv"

  # Rows classed "generated" (compiled-policy.sh, and any skill or agent
  # path upstream now ships as a skill-pack install) were skipped by the
  # per-row loop above on purpose: they are regenerated here, once, from
  # whatever the worktree's own pack sources now are, never taken, merged
  # or held like an ordinary file. A generated skill/agent path is removed
  # first so --install always finds a clean slot to write into, rather than
  # comparing against whatever stale copy the worktree started with and
  # refusing on a difference that update.sh itself is about to resolve.
  gen_paths=$(awk -F '\t' '$2 == "generated" { print $1 }' "$state/plan.tsv")
  printf '%s\n' "$gen_paths" | while IFS= read -r gp; do
    [ -n "$gp" ] || continue
    case $gp in .claude/skill-packs/compiled-policy.sh) continue ;; esac
    rm -f "$wt/$gp"
  done
  if [ -f "$wt/.claude/scripts/skill-packs.sh" ]; then
    ( cd "$wt" && sh .claude/scripts/skill-packs.sh --compile ) >/dev/null 2>&1
    ( cd "$wt" && git add -- .claude/skill-packs/compiled-policy.sh ) >/dev/null 2>&1
    # A non-zero exit here is never treated as fatal to the whole update: it
    # means --install refused to overwrite one drifted path (most often the
    # very path a "conflict" row above just held for the founder's own
    # review), and the loop inside --install already moved on to every
    # other skill and agent regardless of that one refusal. Aborting the
    # entire update over one already-flagged path would block every other
    # generated file from landing along with it. sh .claude/scripts/
    # skill-packs.sh --check-installed remains the after-the-fact audit for
    # anything left missing or drifted once the update is applied.
    ( cd "$wt" && sh .claude/scripts/skill-packs.sh --install all ) >/dev/null 2>&1
    # Added separately: "git add -A -- a b" fails outright, adding NEITHER
    # path, the moment one pathspec matches nothing -- and a founder copy
    # can genuinely have no .claude/agents (or no .claude/skills) at all.
    [ -d "$wt/.claude/skills" ] && ( cd "$wt" && git add -A -- .claude/skills ) >/dev/null 2>&1
    [ -d "$wt/.claude/agents" ] && ( cd "$wt" && git add -A -- .claude/agents ) >/dev/null 2>&1

    # These compiled/installed outputs never went through apply_take or
    # apply_merged (the per-row loop above skips class "generated" on
    # purpose), so $changed_paths would otherwise never list them at all --
    # neither hold_back_failing_notes (which only ever restores a path
    # already IN $changed_paths) nor --apply's own final report of what
    # actually changed would ever see them. Fold in everything the compile
    # and install steps just staged as different from the worktree's own
    # pre-update HEAD.
    gen_changed=$( ( cd "$wt" && git diff --cached --name-only -- \
      .claude/skill-packs/compiled-policy.sh .claude/skills .claude/agents ) 2>/dev/null )
    if [ -n "$gen_changed" ]; then
      changed_paths="$changed_paths$gen_changed
"
    fi
  fi

  short=$(printf '%s' "$cur_upstream" | cut -c1-12)
  mkdir -p "$wt/.claude"
  printf '%s\n' "$cur_upstream" > "$wt/.claude/launchhouse-version"
  ( cd "$wt" && git add -- .claude/launchhouse-version ) >/dev/null 2>&1

  aborted=0; abort_reason=""; checks_out=""; hb_held=""; hb_resolved=""; hb_abort=0; hb_abort_ids=""
  if ! ( cd "$wt" && git diff --cached --quiet ); then
    if ! ( cd "$wt" && git commit -q -m "Launchhouse update to $short" ); then
      aborted=1; abort_reason="could not commit the update in the worktree"
    fi
  else
    aborted=1; abort_reason="nothing to apply (every row was held or already matched)"
  fi

  if [ "$aborted" = 0 ]; then
    # Purpose-based updates' HOLD BACK step, before the gate below runs:
    # a failing non-safety note's own touches are reset in the worktree
    # (and the commit above amended) so the rest of this apply is judged,
    # and can still land, without them. hold_back_failing_notes can itself
    # decide the whole apply must abort ($hb_abort) rather than land with a
    # hold-back it cannot honour honestly (see its own comment) -- that is
    # checked before run_checks_in ever runs, same as any other gate.
    hold_back_failing_notes

    if [ "$hb_abort" = 1 ]; then
      aborted=1
      abort_reason="$hb_abort_reason"
    else
      checks_out=$(run_checks_in "$wt" 2>&1)
      checks_rc=$?
      if [ "$checks_rc" != 0 ]; then
        aborted=1
        abort_reason="a founder-safety check failed inside the worktree"
      elif printf '%s\n' "$checks_out" | grep -q '^checks=none$' && [ "$allow_no_checks" != "--allow-no-checks" ]; then
        aborted=1
        abort_reason="no checks to run"
      fi
    fi
  fi

  if [ "$aborted" = 1 ]; then
    git worktree remove --force "$wt" >/dev/null 2>&1
    git branch -D "$branch" >/dev/null 2>&1
    git tag -d "$tag" >/dev/null 2>&1
    echo "result=aborted"
    printf '%s\n' "$checks_out" | grep '^gate_failed=' | sed 's/^gate_failed=/failed=/'
    if [ -n "$hb_abort_ids" ]; then
      printf '%s\n' "$hb_abort_ids" | tr ',' '\n' | awk 'NF' | sed 's/^/failed=/'
    fi
    echo "reason=$abort_reason"
    [ -f "$state/last-checks.log" ] && printf 'log=%s\n' "$state/last-checks.log"
    post_head=$(git rev-parse HEAD)
    post_status=$(git status --porcelain)
    if [ "$post_head" = "$pre_head" ] && [ "$post_status" = "$pre_status" ]; then
      echo "unchanged=yes"
    else
      echo "unchanged=no"
    fi
    exit 1
  fi

  if git merge --ff-only -q "$branch" >/dev/null 2>&1; then
    git worktree remove "$wt" >/dev/null 2>&1
    git branch -D "$branch" >/dev/null 2>&1
    applied_commit=$(git rev-parse HEAD)
    {
      printf 'tag=%s\n' "$tag"
      printf 'commit=%s\n' "$applied_commit"
      printf 'upstream=%s\n' "$cur_upstream"
    } > "$state/applied"

    # The post-landing fail-safe: everything above only ever proved the
    # update was fine inside a throwaway worktree. Prove it once more on
    # the actual folder, now that it is actually live -- and if it is not,
    # undo automatically rather than leave a founder sitting in a broken
    # folder. $state/applied above already records exactly what do_undo
    # needs; this is the same guarded path --undo uses, never a second one.
    if post_landing_smoke; then
      # If the plan just applied was a restore-settings-plan (cmd_plan
      # never writes this key into meta; only cmd_restore_settings_plan
      # does), the restore has now actually landed: resolve its pending tag
      # for good, same as a decline does, so an interrupted-then-later-
      # successful restore is never offered again.
      restore_from_tag=$(awk -F '=' '$1 == "restore_from_tag" { print $2 }' "$state/meta" 2>/dev/null)
      if [ -n "$restore_from_tag" ]; then
        mkdir -p "$state"
        printf '%s\n' "$restore_from_tag" >> "$state/restore-offered"
        if [ "$(cat "$state/restore-pending" 2>/dev/null)" = "$restore_from_tag" ]; then
          rm -f "$state/restore-pending"
        fi
      fi
      # A standing held id this apply's hold-back logic never even
      # considered (it only ever tests a note that HAS a check file AND
      # touches a path this apply changed) still needs to come off held.tsv
      # once it has actually landed, or it is re-offered, and misclassified
      # against its own recorded base, forever. Resolved here when either:
      # (a) the id is still in THIS plan's own notes.tsv, is not being held
      # again this apply (in $hb_held), and at least one of its touched
      # paths is in the final $changed_paths -- it genuinely landed, check
      # or no check; or (b) it has no check file at all (a checked note
      # that never touched a changed path was correctly never tested, and
      # must stay held) and every one of its touched paths, in the real
      # repository this apply just landed, now matches what upstream
      # actually ships -- the founder's own copy already agreed with
      # upstream, so the path never shows up in $changed_paths even though
      # the note is, in truth, no longer pending.
      hb_standing_resolved=""
      if [ -s "$state/held.tsv" ] && [ -f "$state/notes.tsv" ]; then
        hb_ch="$state/.tmp.hbch.$$"
        printf '%s' "$changed_paths" | awk 'NF' > "$hb_ch"
        while IFS='	' read -r hoid _horeason _hobase; do
          [ -n "$hoid" ] || continue
          printf '%s\n' "$hb_held" | grep -qxF "$hoid" && continue
          printf '%s\n' "$hb_standing_resolved" | grep -qxF "$hoid" && continue
          hn_touches=$(awk -F '	' -v id="$hoid" '$1 == id { print $4; exit }' "$state/notes.tsv")
          [ -n "$hn_touches" ] || continue
          printf '%s\n' "$hn_touches" | tr ',' '\n' | awk 'NF' > "$hb_ch.tp"
          if grep -qFxf "$hb_ch.tp" "$hb_ch" 2>/dev/null; then
            hb_standing_resolved="$hb_standing_resolved$hoid
"
          elif [ ! -f "$state/notes/$hoid.check.sh" ]; then
            hb_all_match=1
            while IFS= read -r hn_tp; do
              [ -n "$hn_tp" ] || continue
              hn_h=$(norm_hash HEAD "$hn_tp")
              hn_u=$(norm_hash "$cur_upstream" "$hn_tp")
              [ "$hn_h" = "$hn_u" ] || { hb_all_match=0; break; }
            done < "$hb_ch.tp"
            [ "$hb_all_match" = 1 ] && hb_standing_resolved="$hb_standing_resolved$hoid
"
          fi
          rm -f "$hb_ch.tp"
        done < "$state/held.tsv"
        rm -f "$hb_ch"
      fi

      # Fold this apply's hold-back outcome into the standing held.tsv (id
      # <TAB> plain reason <TAB> base-sha, never cleared by --plan): a note
      # this apply just held is (re)written; a note this apply just proved
      # fine again, or that $hb_standing_resolved just worked out landed on
      # its own, comes off; anything this apply never touched at all is
      # left exactly as it was, still waiting -- base-sha and all. Run
      # whenever held.tsv actually has rows, never only when something was
      # held or resolved THIS apply -- $hb_standing_resolved above already
      # had to read held.tsv to find anything to resolve, so the update
      # below has to run for that to ever take effect.
      #
      # base-sha is the basecommit THIS plan classified paths against
      # (recorded in $state/meta, read into $basecommit above) -- the
      # commit before the held note's own content first appeared upstream.
      # The next --plan uses it (see cmd_plan's held-base override) instead
      # of the founder's now-advanced .claude/launchhouse-version to
      # classify the note's touched paths, because by the time this note is
      # offered again .claude/launchhouse-version already points at
      # $cur_upstream: comparing the founder's reverted file against THAT
      # would compare mine against theirs at the very same commit (once
      # upstream itself has not moved further), which reads as a harmless
      # local-only edit ("keep") and the note would never be reapplied.
      # Classified against the older, recorded base instead, the real
      # upstream change shows up again, exactly like any other pending
      # update. That base-sha is used ONLY the first time a note is held:
      # a note already standing in held.tsv keeps the base it was first
      # held against -- today's $basecommit already contains the upstream
      # content this note is trying to reintroduce (that is exactly why it
      # is being held again), so overwriting its base with today's
      # $basecommit would make its own touched paths classify as an
      # unremarkable "keep" against that base next time, and it could never
      # re-apply.
      if [ -s "$state/held.tsv" ] || printf '%s' "$hb_held" | grep -q .; then
        hb_new="$state/.tmp.heldnew.$$"
        : > "$hb_new"
        if [ -f "$state/held.tsv" ]; then
          while IFS='	' read -r hoid horeason hobase; do
            [ -n "$hoid" ] || continue
            printf '%s\n' "$hb_resolved" | grep -qxF "$hoid" && continue
            printf '%s\n' "$hb_standing_resolved" | grep -qxF "$hoid" && continue
            printf '%s\n' "$hb_held" | grep -qxF "$hoid" && continue
            printf '%s\t%s\t%s\n' "$hoid" "$horeason" "$hobase" >> "$hb_new"
          done < "$state/held.tsv"
        fi
        printf '%s\n' "$hb_held" | awk 'NF' > "$hb_new.ids"
        while IFS= read -r hnid; do
          [ -n "$hnid" ] || continue
          hnb=$(awk -F '	' -v id="$hnid" '$1 == id { print $3; exit }' "$state/held.tsv" 2>/dev/null)
          [ -n "$hnb" ] || hnb=$basecommit
          printf '%s\treview needed: its own check failed once applied, or it shares a changed path with a note whose check failed\t%s\n' "$hnid" "$hnb" >> "$hb_new"
        done < "$hb_new.ids"
        rm -f "$hb_new.ids"
        mv "$hb_new" "$state/held.tsv"
      fi
      echo "result=applied"
      printf '%s\n' "$hb_held" | awk 'NF' | sed 's/^/held=/'
      printf '%s' "$changed_paths" | awk 'NF'
      printf '%s\n' "$checks_out" | grep '^checks=none$'
      exit 0
    fi

    # smoke check 4 (a checkout-time line-ending/newline change to a
    # TRACKED file under .claude/) leaves the working tree looking dirty
    # even though nothing the founder did caused it -- reset those tracked
    # files back to HEAD first, so the automatic undo's own clean-tree
    # guard (is_clean, inside do_undo) can actually proceed instead of
    # refusing over a checkout artifact.
    if [ "$smoke_needs_reset" = 1 ]; then
      git checkout -- .claude/ >/dev/null 2>&1
    fi

    undo_out=$(do_undo)
    undo_rc=$?
    if [ "$undo_rc" = 0 ]; then
      echo "result=reverted"
      printf 'reason=%s\n' "$smoke_reason"
      [ -n "$smoke_detail" ] && printf '%s\n' "$smoke_detail"
      exit 1
    fi

    # The automatic undo itself failed -- never leave the folder half
    # changed and never guess further. Say exactly what a human needs to
    # recover by hand: the pre-update tag this update was taken from.
    echo "result=reverted-failed"
    printf 'reason=%s\n' "$smoke_reason"
    printf 'pre_update_tag=%s\n' "$tag"
    undo_reason=$(printf '%s\n' "$undo_out" | grep '^reason=' | head -1 | sed 's/^reason=//')
    [ -n "$undo_reason" ] && printf 'undo_reason=%s\n' "$undo_reason"
    [ -n "$smoke_detail" ] && printf '%s\n' "$smoke_detail"
    exit 1
  fi

  git worktree remove --force "$wt" >/dev/null 2>&1
  git branch -D "$branch" >/dev/null 2>&1
  git tag -d "$tag" >/dev/null 2>&1
  echo "result=aborted"
  echo "reason=the fast-forward merge into the real repository failed"
  post_head=$(git rev-parse HEAD)
  post_status=$(git status --porcelain)
  if [ "$post_head" = "$pre_head" ] && [ "$post_status" = "$pre_status" ]; then
    echo "unchanged=yes"
  else
    echo "unchanged=no"
  fi
  exit 1
}

# ---------------------------------------------------------------------- undo

# Every path an update commit touched (outside growth-engine/, which an
# update never writes anyway) whose current HEAD content does not match the
# given tag's content, one per line -- empty when everything matches. Used
# by do_undo to make sure a `git revert` that reports success, or reports
# nothing left to revert, actually restored the founder's pre-update files:
# neither an exit code nor an empty resulting diff is trusted on its own, a
# stray or corrupted merge driver on a path can make git report either
# outcome without the content actually matching what the pre-update tag
# saved.
undo_mismatched_paths() { # update_commit, tag
  ump_c=$1; ump_t=$2
  git diff --name-only "$ump_c^" "$ump_c" 2>/dev/null | while IFS= read -r ump_p; do
    [ -n "$ump_p" ] || continue
    case $ump_p in growth-engine/*) continue ;; esac
    ump_h=$(norm_hash HEAD "$ump_p")
    ump_g=$(norm_hash "$ump_t" "$ump_p")
    [ "$ump_h" = "$ump_g" ] || printf '%s\n' "$ump_p"
  done
}

# The actual undo logic, as a function that RETURNS instead of exiting the
# process -- so the post-landing fail-safe in cmd_apply can call it in
# place, on the very commit it just landed, and still keep control of the
# process (echoing its own result=... lines) whichever way it comes out.
# cmd_undo below is the thin, exiting, founder-facing wrapper.
do_undo() {
  state=$(state_dir) || { echo "result=aborted"; echo "reason=not inside a git repository"; return 1; }

  # Undo only ever reverts the exact commit --apply recorded in
  # <state>/applied -- never a commit merely located by message or by
  # "newest pre-update tag", either of which a founder's own later commit
  # (or a stray tag) could make point at the wrong thing.
  [ -f "$state/applied" ] || { echo "result=none"; echo "reason=no update recorded to undo"; return 1; }
  applied_tag=$(awk -F= '$1 == "tag" { print $2 }' "$state/applied")
  applied_commit=$(awk -F= '$1 == "commit" { print $2 }' "$state/applied")
  [ -n "$applied_tag" ] && [ -n "$applied_commit" ] || { echo "result=none"; echo "reason=no update recorded to undo"; return 1; }

  is_clean || { echo "result=aborted"; echo "reason=working tree is not clean"; return 1; }
  if in_progress; then echo "result=aborted"; echo "reason=a merge or rebase is already in progress"; return 1; fi

  if ! git rev-parse -q --verify "$applied_commit^{commit}" >/dev/null 2>&1 \
     || ! git merge-base --is-ancestor "$applied_commit" HEAD 2>/dev/null; then
    echo "result=none"; echo "reason=the recorded update commit is no longer present"; return 1
  fi
  git rev-parse -q --verify "refs/tags/$applied_tag" >/dev/null 2>&1 \
    || { echo "result=none"; echo "reason=the recorded pre-update tag $applied_tag is gone"; return 1; }

  # The recorded commit must actually look like one --apply made: its
  # message starts the way cmd_apply always writes it, and its direct parent
  # is exactly the commit the recorded tag points at (nothing snuck in
  # between the tag and the update commit).
  msg=$(git log -1 --format=%s "$applied_commit" 2>/dev/null)
  case $msg in
    "Launchhouse update to"*) : ;;
    *) echo "result=aborted"; echo "reason=the recorded update commit does not look like an update commit"; return 1 ;;
  esac
  parent=$(git rev-parse -q --verify "$applied_commit^" 2>/dev/null)
  tag_commit=$(git rev-parse -q --verify "refs/tags/$applied_tag^{commit}" 2>/dev/null)
  if [ -z "$parent" ] || [ "$parent" != "$tag_commit" ]; then
    echo "result=aborted"
    echo "reason=the recorded update commit's history does not match the pre-update tag"
    return 1
  fi

  # Never undo a commit that touches growth-engine/ -- --apply never writes
  # there, so a commit recorded as an update that does touch it cannot be
  # trusted as one.
  touched_ge=$(git diff --name-only "$applied_commit^" "$applied_commit" -- growth-engine/ 2>/dev/null)
  if [ -n "$touched_ge" ]; then
    echo "result=aborted"
    echo "reason=the recorded update commit touches growth-engine/; refusing to undo"
    return 1
  fi

  update_commit=$applied_commit
  tag=$applied_tag

  pre_head=$(git rev-parse HEAD)
  pre_status=$(git status --porcelain)

  out=$(git revert --no-edit "$update_commit" 2>&1)
  rc=$?

  if [ "$rc" = 0 ]; then
    # git said the revert committed cleanly -- never trusted on its own. A
    # corrupted or custom merge driver on a touched path can make git
    # report success while quietly leaving that path exactly as the update
    # left it. Verify every path the update touched actually matches the
    # pre-update tag before ever saying "undone"; if it does not, the
    # revert commit is backed out and this is a failure, never success.
    mismatch=$(undo_mismatched_paths "$update_commit" "$tag")
    if [ -n "$mismatch" ]; then
      git reset --hard "$pre_head" >/dev/null 2>&1
      echo "result=aborted"
      echo "reason=git revert reported success but the result does not match the pre-update save"
      printf '%s\n' "$mismatch"
      return 1
    fi
    echo "result=undone"
    printf 'tag=%s\n' "$tag"
    return 0
  fi

  # Non-zero without conflict markers means git itself refused, because the
  # revert would be empty: the update's own changes are already gone (a
  # noop), never a partial commit. git leaves nothing applied in that case,
  # so there is nothing to abort. Same rule as above: a merge driver can
  # make git call an unresolved path "no change needed" without its content
  # actually matching the pre-update tag, so this is verified too, never
  # assumed from the empty diff alone.
  conflicts=$(git status --porcelain 2>/dev/null | grep -E '^(UU|AA|DU|UD|AU|UA) ')
  if [ -z "$conflicts" ]; then
    git revert --abort >/dev/null 2>&1
    mismatch=$(undo_mismatched_paths "$update_commit" "$tag")
    if [ -n "$mismatch" ]; then
      echo "result=aborted"
      echo "reason=git revert reported nothing left to revert, but the result does not match the pre-update save"
      printf '%s\n' "$mismatch"
      return 1
    fi
    echo "result=noop"
    printf 'tag=%s\n' "$tag"
    echo "reason=already matches that save"
    return 0
  fi

  # A real conflict: later changes overlap the update's own hunks. Abort
  # cleanly, never leave a partial revert applied.
  git revert --abort >/dev/null 2>&1
  post_head=$(git rev-parse HEAD)
  post_status=$(git status --porcelain)
  if [ "$post_head" != "$pre_head" ] || [ "$post_status" != "$pre_status" ]; then
    echo "result=aborted"
    echo "reason=could not cleanly back out the revert attempt"
    return 1
  fi
  echo "result=aborted"
  echo "reason=later changes overlap the update"
  printf '%s\n' "$conflicts" | awk '{ print $2 }'
  return 1
}

cmd_undo() {
  do_undo
  exit $?
}

# ------------------------------------------------------------------- dispatch

cmd=${1:-}
case $cmd in
  --status) cmd_status ;;
  --detect-base) cmd_detect_base ;;
  --set-base) cmd_set_base "${2:-}" ;;
  --plan) cmd_plan ;;
  --adapt-save) cmd_adapt_save "${2:-}" "${3:-}" "${4:-}" ;;
  --restore-settings-plan) cmd_restore_settings_plan ;;
  --restore-settings-decline) cmd_restore_settings_decline ;;
  --apply) cmd_apply "${2:-}" "${3:-}" ;;
  --undo) cmd_undo ;;
  *)
    echo "usage: update.sh --status | --detect-base | --set-base <sha> | --plan | --adapt-save <path> <body-file> <note-ids> | --restore-settings-plan | --restore-settings-decline | --apply <decisions.tsv> [--allow-no-checks] | --undo" >&2
    exit 2
    ;;
esac
