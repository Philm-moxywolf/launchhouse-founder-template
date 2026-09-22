#!/bin/sh
# The main conversation's own tool: grants a specialist subagent temporary
# permission to run specific tool-suffix actions, once the founder has said
# yes in chat. mcp-guard.sh is the enforcement side — it reads what this
# script writes and decrements it; this script is the only writer.
#
# Two-phase protocol: a specialist agent (see .claude/tool-packs/README.md
# and .claude/references/connections.md) first runs PHASE: plan, read-only,
# and returns a numbered list of proposed actions. The main conversation
# shows those to the founder, gets a yes, then grants exactly the approved
# actions with this script before running PHASE: execute. A grant never
# loosens what mcp-guard.sh would otherwise decide (deny stays deny; ask
# stays ask, it is simply no longer blocked waiting on a live prompt inside
# the subagent, which cannot ask the founder itself) — it only lets a call
# through that mcp-guard.sh would otherwise refuse for lack of a grant.
#
# Storage: $(git rev-parse --git-dir)/launchhouse/approvals/<pack-id>, one
# line per suffix: suffix<TAB>remaining<TAB>expires_epoch. Never under
# growth-engine/ — that folder is git-tracked, synced to the founder's
# Desktop copies, and read by other tools; approvals are session bookkeeping,
# the same footing as the Desktop-copies state lh_bk_dir already keeps there.
#
# Usage:
#   sh approve.sh --grant <pack-id> <suffix>[:<count>] [<suffix>[:<count>] ...]
#   sh approve.sh --clear <pack-id>
#   sh approve.sh --show <pack-id>
#
# <count> defaults to 1 if omitted or not a plain number. Every grant expires
# 1800 seconds (30 minutes) after it is written, whether or not it is used.
# A second --grant for a suffix already granted replaces that suffix's own
# line, it never stacks on top of it.

. "$(dirname "$0")/lib.sh" 2>/dev/null || exit 1

lh_approve_dir() {
  bk=$(lh_bk_dir 2>/dev/null) || return 1
  [ -n "$bk" ] || return 1
  printf '%s/approvals' "$bk"
}

lh_valid_pack_id() {
  case $1 in
    '') return 1 ;;
    *[!a-z0-9-]*) return 1 ;;
  esac
  return 0
}

# The same short, bounded mkdir-based lock mcp-guard.sh takes before it
# reads, checks and decrements a grant, on the same "<approvals file>.lock"
# path, so a grant, a clear and a consuming read can never land on top of
# each other. See mcp-guard.sh's own lh_mg_lock for the reasoning; this is
# the same logic, duplicated rather than sourced, since approve.sh and
# mcp-guard.sh are separate processes with no shared library between them
# for this.
lh_ap_lock() {
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

lh_ap_unlock() {
  rm -rf "$1" 2>/dev/null
}

usage() {
  cat >&2 <<'EOF'
Usage:
  sh .claude/scripts/approve.sh --grant <pack-id> <suffix>[:<count>] ...
  sh .claude/scripts/approve.sh --clear <pack-id>
  sh .claude/scripts/approve.sh --show <pack-id>
EOF
}

action=$1
[ $# -gt 0 ] && shift

case $action in
  --grant)
    pack=$1
    [ $# -gt 0 ] && shift
    if ! lh_valid_pack_id "$pack"; then
      printf 'approve.sh: bad pack id "%s" (lower case a-z, 0-9 and hyphen only)\n' "$pack" >&2
      exit 1
    fi
    if [ $# -lt 1 ]; then
      printf 'approve.sh: --grant needs at least one suffix\n' >&2
      exit 1
    fi
    dir=$(lh_approve_dir) || { printf 'approve.sh: could not resolve the approvals folder (not a git repo?)\n' >&2; exit 1; }
    case "$dir" in
      */growth-engine/*|*/growth-engine)
        printf 'approve.sh: refusing to write approvals inside growth-engine/\n' >&2
        exit 1 ;;
    esac
    mkdir -p "$dir" || exit 1
    file="$dir/$pack"
    lock="$file.lock"
    if ! lh_ap_lock "$lock"; then
      printf 'approve.sh: could not get a lock on %s; try again\n' "$file" >&2
      exit 1
    fi
    exp=$(($(date +%s) + 1800))
    tmp="$file.tmp.$$"
    if [ -f "$file" ]; then cp "$file" "$tmp" || : > "$tmp"; else : > "$tmp"; fi
    granted=""
    for arg in "$@"; do
      suffix=${arg%%:*}
      case $arg in
        *:*) count=${arg#*:} ;;
        *) count=1 ;;
      esac
      case $count in ''|*[!0-9]*) count=1 ;; esac
      [ -n "$suffix" ] || continue
      awk -v s="$suffix" -F '\t' 'BEGIN { OFS = "\t" } $1 != s { print }' "$tmp" > "$tmp.f" 2>/dev/null && mv "$tmp.f" "$tmp"
      printf '%s\t%s\t%s\n' "$suffix" "$count" "$exp" >> "$tmp"
      granted="$granted $suffix:$count"
    done
    if mv "$tmp" "$file"; then
      lh_ap_unlock "$lock"
      printf 'Granted in %s (expires in 30 minutes):%s\n' "$pack" "$granted"
    else
      rm -f "$tmp" 2>/dev/null
      lh_ap_unlock "$lock"
      printf 'approve.sh: could not write %s\n' "$file" >&2
      exit 1
    fi
    ;;
  --clear)
    pack=$1
    if ! lh_valid_pack_id "$pack"; then
      printf 'approve.sh: bad pack id "%s" (lower case a-z, 0-9 and hyphen only)\n' "$pack" >&2
      exit 1
    fi
    dir=$(lh_approve_dir) || { printf 'approve.sh: could not resolve the approvals folder (not a git repo?)\n' >&2; exit 1; }
    file="$dir/$pack"
    lock="$file.lock"
    if ! lh_ap_lock "$lock"; then
      printf 'approve.sh: could not get a lock on %s; try again\n' "$file" >&2
      exit 1
    fi
    rm -f "$file"
    lh_ap_unlock "$lock"
    printf 'Cleared approvals for %s\n' "$pack"
    ;;
  --show)
    pack=$1
    if ! lh_valid_pack_id "$pack"; then
      printf 'approve.sh: bad pack id "%s" (lower case a-z, 0-9 and hyphen only)\n' "$pack" >&2
      exit 1
    fi
    dir=$(lh_approve_dir) || { printf 'approve.sh: could not resolve the approvals folder (not a git repo?)\n' >&2; exit 1; }
    file="$dir/$pack"
    if [ -f "$file" ]; then
      cat "$file"
    else
      printf '(no approvals for %s)\n' "$pack"
    fi
    ;;
  *)
    usage
    exit 1 ;;
esac
