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

  best=""; best_n=""
  for c in $(git rev-list "upstream/$db" 2>/dev/null); do
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
  d="$state/diffs/$(dirname "$p")"
  mkdir -p "$d" 2>/dev/null
  git diff "$basecommit" "$uh" -- "$p" > "$state/diffs/$p.base-upstream.diff" 2>/dev/null
  git diff "$basecommit" HEAD -- "$p" > "$state/diffs/$p.base-local.diff" 2>/dev/null
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
    [ -n "$hsha" ] && git show "$hsha" 2>/dev/null | tail -n +2 | awk -F '\t' '$5 == "local"'
  } > "$state/merged/$p"
  write_row "$p" registry-merge apply "union: upstream rows plus local-origin rows"
}

process_path() { # path
  p=$1
  path_ignored "$p" && return 0

  bsha=$(blob_sha "$basecommit" "$p")
  hsha=$(blob_sha HEAD "$p")
  usha=$(blob_sha "$uh" "$p")
  bn=""; hn=""; un=""
  [ -n "$bsha" ] && bn=$(norm_hash "$basecommit" "$p")
  [ -n "$hsha" ] && hn=$(norm_hash HEAD "$p")
  [ -n "$usha" ] && un=$(norm_hash "$uh" "$p")

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

  if [ "$p" = ".claude/tool-packs/compiled-policy.sh" ]; then
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
  elif [ "$p" = ".claude/tool-packs/registry.tsv" ]; then
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

  rm -rf "$state/plan.tsv" "$state/diffs" "$state/merged" "$state/meta"
  mkdir -p "$state/diffs" "$state/merged"
  : > "$state/plan.tsv"

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

  {
    printf 'base=%s\n' "$basecommit"
    printf 'upstream=%s\n' "$uh"
    printf 'head=%s\n' "$(git rev-parse HEAD)"
    printf 'time=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date)"
  } > "$state/meta"

  awk -F '\t' '{ c[$2]++ } END { for (k in c) print k "=" c[k] }' "$state/plan.tsv" | sort
}

# --------------------------------------------------------------------- apply

run_checks_in() { # dir
  d=$1
  (
    cd "$d" || exit 1
    # Only the checks that exist in the updated tree are run. A test
    # harness proves this by placing its own stub .claude/tests/run.sh (one
    # that exits 0 or 1) in the fake founder/upstream trees it builds --
    # never by an env var, which could otherwise silently skip the real
    # checks in production.
    ran=0
    if [ -f .claude/tests/run.sh ]; then
      ran=1
      sh .claude/tests/run.sh || exit 1
    fi
    if [ -f .claude/tests/state.sh ]; then
      ran=1
      sh .claude/tests/state.sh || exit 1
    fi
    if [ -f .claude/scripts/tool-packs.sh ]; then
      ran=1
      sh .claude/scripts/tool-packs.sh --validate all || exit 1
      sh .claude/scripts/tool-packs.sh --check-compiled || exit 1
    fi
    [ "$ran" = 1 ] || echo "checks=none"
    exit 0
  )
}

decision_for() { # path, decisions file
  awk -F '\t' -v p="$1" '$1 == p { d = $2 } END { if (d != "") print d }' "$2"
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

  # Every row of a held class needs an explicit decision.
  missing=""
  while IFS='	' read -r path class proposed detail; do
    [ -n "$path" ] || continue
    case $class in
      conflict|add-conflict|deleted-upstream-kept|settings)
        d=$(decision_for "$path" "$decisions")
        [ -n "$d" ] || missing="$missing$path
"
        ;;
    esac
  done < "$state/plan.tsv"
  if [ -n "$missing" ]; then
    echo "result=aborted"
    echo "reason=missing an explicit decision for:"
    printf '%s' "$missing"
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
      ( cd "$wt" && git add -- "$p" ) >/dev/null 2>&1
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
      ( cd "$wt" && git add -- "$p" ) >/dev/null 2>&1
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
    esac
  done < "$state/plan.tsv"

  ( cd "$wt" && sh .claude/scripts/tool-packs.sh --compile ) >/dev/null 2>&1
  ( cd "$wt" && git add -- .claude/tool-packs/compiled-policy.sh ) >/dev/null 2>&1

  short=$(printf '%s' "$cur_upstream" | cut -c1-12)
  mkdir -p "$wt/.claude"
  printf '%s\n' "$cur_upstream" > "$wt/.claude/launchhouse-version"
  ( cd "$wt" && git add -- .claude/launchhouse-version ) >/dev/null 2>&1

  aborted=0; abort_reason=""; checks_out=""
  if ! ( cd "$wt" && git diff --cached --quiet ); then
    if ! ( cd "$wt" && git commit -q -m "Launchhouse update to $short" ); then
      aborted=1; abort_reason="could not commit the update in the worktree"
    fi
  else
    aborted=1; abort_reason="nothing to apply (every row was held or already matched)"
  fi

  if [ "$aborted" = 0 ]; then
    checks_out=$(run_checks_in "$wt" 2>&1)
    checks_rc=$?
    if [ "$checks_rc" != 0 ]; then
      aborted=1
      abort_reason="checks failed inside the worktree"
    elif printf '%s\n' "$checks_out" | grep -q '^checks=none$' && [ "$allow_no_checks" != "--allow-no-checks" ]; then
      aborted=1
      abort_reason="no checks to run"
    fi
  fi

  if [ "$aborted" = 1 ]; then
    git worktree remove --force "$wt" >/dev/null 2>&1
    git branch -D "$branch" >/dev/null 2>&1
    git tag -d "$tag" >/dev/null 2>&1
    echo "result=aborted"
    echo "reason=$abort_reason"
    [ -n "$checks_out" ] && printf '%s\n' "$checks_out" | tail -60
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
    echo "result=applied"
    printf '%s' "$changed_paths" | awk 'NF'
    printf '%s\n' "$checks_out" | grep '^checks=none$'
    exit 0
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

cmd_undo() {
  state=$(state_dir) || { echo "result=aborted"; echo "reason=not inside a git repository"; exit 1; }

  # Undo only ever reverts the exact commit --apply recorded in
  # <state>/applied -- never a commit merely located by message or by
  # "newest pre-update tag", either of which a founder's own later commit
  # (or a stray tag) could make point at the wrong thing.
  [ -f "$state/applied" ] || { echo "result=none"; echo "reason=no update recorded to undo"; exit 1; }
  applied_tag=$(awk -F= '$1 == "tag" { print $2 }' "$state/applied")
  applied_commit=$(awk -F= '$1 == "commit" { print $2 }' "$state/applied")
  [ -n "$applied_tag" ] && [ -n "$applied_commit" ] || { echo "result=none"; echo "reason=no update recorded to undo"; exit 1; }

  is_clean || { echo "result=aborted"; echo "reason=working tree is not clean"; exit 1; }
  if in_progress; then echo "result=aborted"; echo "reason=a merge or rebase is already in progress"; exit 1; fi

  if ! git rev-parse -q --verify "$applied_commit^{commit}" >/dev/null 2>&1 \
     || ! git merge-base --is-ancestor "$applied_commit" HEAD 2>/dev/null; then
    echo "result=none"; echo "reason=the recorded update commit is no longer present"; exit 1
  fi
  git rev-parse -q --verify "refs/tags/$applied_tag" >/dev/null 2>&1 \
    || { echo "result=none"; echo "reason=the recorded pre-update tag $applied_tag is gone"; exit 1; }

  # The recorded commit must actually look like one --apply made: its
  # message starts the way cmd_apply always writes it, and its direct parent
  # is exactly the commit the recorded tag points at (nothing snuck in
  # between the tag and the update commit).
  msg=$(git log -1 --format=%s "$applied_commit" 2>/dev/null)
  case $msg in
    "Launchhouse update to"*) : ;;
    *) echo "result=aborted"; echo "reason=the recorded update commit does not look like an update commit"; exit 1 ;;
  esac
  parent=$(git rev-parse -q --verify "$applied_commit^" 2>/dev/null)
  tag_commit=$(git rev-parse -q --verify "refs/tags/$applied_tag^{commit}" 2>/dev/null)
  if [ -z "$parent" ] || [ "$parent" != "$tag_commit" ]; then
    echo "result=aborted"
    echo "reason=the recorded update commit's history does not match the pre-update tag"
    exit 1
  fi

  # Never undo a commit that touches growth-engine/ -- --apply never writes
  # there, so a commit recorded as an update that does touch it cannot be
  # trusted as one.
  touched_ge=$(git diff --name-only "$applied_commit^" "$applied_commit" -- growth-engine/ 2>/dev/null)
  if [ -n "$touched_ge" ]; then
    echo "result=aborted"
    echo "reason=the recorded update commit touches growth-engine/; refusing to undo"
    exit 1
  fi

  update_commit=$applied_commit
  tag=$applied_tag

  pre_head=$(git rev-parse HEAD)
  pre_status=$(git status --porcelain)

  out=$(git revert --no-edit "$update_commit" 2>&1)
  rc=$?

  if [ "$rc" = 0 ]; then
    echo "result=undone"
    printf 'tag=%s\n' "$tag"
    exit 0
  fi

  # Non-zero without conflict markers means git itself refused, because the
  # revert would be empty: the update's own changes are already gone (a
  # noop), never a partial commit. git leaves nothing applied in that case,
  # so there is nothing to abort.
  conflicts=$(git status --porcelain 2>/dev/null | grep -E '^(UU|AA|DU|UD|AU|UA) ')
  if [ -z "$conflicts" ]; then
    git revert --abort >/dev/null 2>&1
    echo "result=noop"
    printf 'tag=%s\n' "$tag"
    echo "reason=already matches that save"
    exit 0
  fi

  # A real conflict: later changes overlap the update's own hunks. Abort
  # cleanly, never leave a partial revert applied.
  git revert --abort >/dev/null 2>&1
  post_head=$(git rev-parse HEAD)
  post_status=$(git status --porcelain)
  if [ "$post_head" != "$pre_head" ] || [ "$post_status" != "$pre_status" ]; then
    echo "result=aborted"
    echo "reason=could not cleanly back out the revert attempt"
    exit 1
  fi
  echo "result=aborted"
  echo "reason=later changes overlap the update"
  printf '%s\n' "$conflicts" | awk '{ print $2 }'
  exit 1
}

# ------------------------------------------------------------------- dispatch

cmd=${1:-}
case $cmd in
  --status) cmd_status ;;
  --detect-base) cmd_detect_base ;;
  --set-base) cmd_set_base "${2:-}" ;;
  --plan) cmd_plan ;;
  --apply) cmd_apply "${2:-}" "${3:-}" ;;
  --undo) cmd_undo ;;
  *)
    echo "usage: update.sh --status | --detect-base | --set-base <sha> | --plan | --apply <decisions.tsv> [--allow-no-checks] | --undo" >&2
    exit 2
    ;;
esac
