#!/bin/sh
# Runs every purpose-based-update note's check, cumulatively across every
# .claude/updates/<release>/ folder, and fails closed for a safety note.
#
# Usage: sh .claude/tests/updates-checks.sh [repo-root]
#
# Rules (docs/purpose-based-updates.md sections 3 and 5; the note schema
# itself lives at .claude/updates/README.md, and the linter at
# .claude/scripts/updates-lint.sh):
#   - No .claude/updates/ folder, or one with no notes in it: an older tree.
#     Prints "notes=none" and exits 0 -- this must never fail an update or a
#     test run on a founder's copy that predates the notes tree.
#   - Otherwise runs the linter, .claude/scripts/updates-lint.sh, first (a
#     non-zero exit is a FAIL; a missing linter file, with notes present, is
#     also a FAIL -- fail closed, the linter is what proves the notes
#     themselves are well formed).
#   - Then, for every .claude/updates/<release>/<id>.md note (every release
#     folder, every note, never just the newest -- except README.md, which
#     is documentation, not a note), reads id/safety/check from its
#     frontmatter and runs the named check file, if any, as:
#       (cd "$root" && REPO_ROOT="$root" sh "<check-file>")
#     exit 0 = PASS, anything else = a problem. For a safety note: a
#     missing or unreadable check file, check: none, or any non-zero exit
#     (including a shell syntax error in the check script) is always a
#     FAIL, whatever kind of tree this is run against. This is the one
#     deliberate exception to this repo's hooks failing open (lib.sh line
#     3) -- a missing safety check gets no benefit of the doubt.
#   - A non-safety note's own check is advisory, but only once there is a
#     founder's own copy to be advisory about: in a FOUNDER copy (decided
#     exactly as .claude/tests/state.sh's own lh_layout_check does --
#     .claude/launchhouse-version tracked, or growth-engine/.state/profile.md
#     tracked), a failing non-safety check prints "WARN  <id>: <reason>"
#     and never fails the run. In the template repo (neither tracked --
#     nothing has been founded from it yet), the same failure is a FAIL,
#     the same as it always was, because there the note's own check is the
#     only thing proving Launchhouse's own shipped note actually works.
#   - Prints "PASS  <id>" / "WARN  <id>: <reason>" / "FAIL  <id>: <reason>"
#     lines, then a summary line, then -- only when something failed --
#     every failing check's own last-line hint=, so the founder-readable
#     reason survives a tail -60.
#   - Exits 0 when nothing FAILed (a WARN alone never fails the run).

# An older updater leaks LH_UPDATE_RELOCATED and LH_UPDATE_ROOT into the checks
# it runs and never unsets them; clear both here, before anything else runs, so
# a nested update.sh call below can never mistake the founder's real folder
# for its own root.
unset LH_UPDATE_RELOCATED LH_UPDATE_ROOT

here=$(cd "$(dirname "$0")" && pwd) || exit 1
default_root=$(cd "$here/../.." && pwd) || exit 1
root=${1:-$default_root}
root=$(cd "$root" 2>/dev/null && pwd) || { echo "updates-checks: bad repo root: $1" >&2; exit 1; }

updates_dir="$root/.claude/updates"

if [ ! -d "$updates_dir" ]; then
  printf 'notes=none\n'
  exit 0
fi

notes=$(find "$updates_dir" -mindepth 2 -maxdepth 2 -name '*.md' ! -name 'README.md' 2>/dev/null | LC_ALL=C sort)

if [ -z "$notes" ]; then
  printf 'notes=none\n'
  exit 0
fi

# Reads one simple "key: value" frontmatter line (id, safety, check -- never
# one of the list-shaped keys) from between the note's first pair of "---"
# lines. Strips a trailing \r so a CRLF checkout (Git for Windows) still
# reads cleanly, and strips a wrapping pair of double quotes if present.
get_field() {
  awk -v key="$2" '
    { sub(/\r$/, "") }
    NR == 1 && $0 == "---" { infm = 1; next }
    infm && $0 == "---" { exit }
    infm {
      line = $0
      sub(/^[ \t]*/, "", line)
      klen = length(key)
      if (substr(line, 1, klen) == key && substr(line, klen + 1, 1) == ":") {
        val = substr(line, klen + 2)
        sub(/^[ \t]*/, "", val)
        sub(/[ \t]*$/, "", val)
        if (val ~ /^".*"$/ && length(val) >= 2) { val = substr(val, 2, length(val) - 2) }
        print val
        exit
      }
    }
  ' "$1"
}

# Founder copy vs. the template repo, decided the exact same way
# .claude/tests/state.sh's own lh_layout_check does: a founder copy is one
# that has been through the start skill (which tracks
# growth-engine/.state/profile.md) or the updater (which tracks
# .claude/launchhouse-version) at least once. Anything else -- including a
# clone of the template itself, where nothing has been founded from it yet
# -- is the template, and a non-safety check failing there is exactly as
# real a problem as a safety check failing anywhere.
copy_mode=template
if git -C "$root" ls-files --error-unmatch .claude/launchhouse-version >/dev/null 2>&1 \
  || git -C "$root" ls-files --error-unmatch growth-engine/.state/profile.md >/dev/null 2>&1; then
  copy_mode=founder
fi

pass=0
warn=0
fail=0
hints=

# -------------------------------------------------------------- the linter
linter="$root/.claude/scripts/updates-lint.sh"
if [ -f "$linter" ]; then
  lint_out=$(sh "$linter" "$root" 2>&1)
  lint_rc=$?
  if [ "$lint_rc" = 0 ]; then
    pass=$((pass + 1))
    printf 'PASS  updates-lint\n'
  else
    fail=$((fail + 1))
    printf 'FAIL  updates-lint: notes failed the linter\n'
    [ -n "$lint_out" ] && printf '%s\n' "$lint_out"
  fi
else
  fail=$((fail + 1))
  printf 'FAIL  updates-lint: .claude/scripts/updates-lint.sh is missing, and notes exist\n'
fi

# --------------------------------------------------------- every note's check
# Fed from a scratch file, not a pipe: a pipeline's while runs in a subshell
# in POSIX sh, and pass/fail/hints set inside it would never reach this
# shell. Reading from a redirected file keeps the loop in this shell.
#
# The scratch file lives under ${TMPDIR:-/tmp}, never inside .claude/ (a
# founder's own tree, which this script has no business writing into just
# to run itself). This is also the one place in this script that fails
# CLOSED rather than open: every other hook in this repo lets a write
# through when it cannot tell what is going on (lib.sh line 3), but a
# scratch file this script cannot create or read would otherwise make the
# while loop below silently see zero notes -- quietly skipping every
# safety note's own check, never printing a FAIL for it. That is worse
# than refusing to run at all.
noteslist=$(mktemp "${TMPDIR:-/tmp}/lh-updates-checks-notes.XXXXXX" 2>/dev/null) || {
  printf 'FAIL updates-checks: could not create a scratch file under ${TMPDIR:-/tmp}\n'
  exit 1
}
trap 'rm -f "$noteslist"' EXIT

if ! printf '%s\n' "$notes" > "$noteslist" 2>/dev/null || [ ! -r "$noteslist" ]; then
  printf 'FAIL updates-checks: could not write or read the scratch file under ${TMPDIR:-/tmp}\n'
  exit 1
fi

while IFS= read -r note; do
  [ -n "$note" ] || continue

  id=$(get_field "$note" id)
  [ -n "$id" ] || id=$(basename "$note" .md)

  safety_raw=$(get_field "$note" safety)
  case $safety_raw in
    true) is_safety=1 ;;
    false) is_safety=0 ;;
    *) is_safety=1 ;; # malformed or missing: fail closed, treat as safety
  esac

  checkfile=$(get_field "$note" check)

  if [ -z "$checkfile" ] || [ "$checkfile" = none ]; then
    if [ "$is_safety" = 1 ]; then
      fail=$((fail + 1))
      printf 'FAIL  %s: safety note names no check file\n' "$id"
      hints="$hints
hint=The update \"$id\" is a safety fix with nothing to prove it landed. Choose \"take the update\" so its check comes back."
    else
      pass=$((pass + 1))
      printf 'PASS  %s\n' "$id"
    fi
    continue
  fi

  checkpath=$(dirname "$note")/$checkfile
  if [ ! -f "$checkpath" ] || [ ! -r "$checkpath" ]; then
    if [ "$is_safety" = 0 ] && [ "$copy_mode" = founder ]; then
      warn=$((warn + 1))
      printf 'WARN  %s: check file missing or unreadable (%s)\n' "$id" "$checkfile"
    else
      fail=$((fail + 1))
      printf 'FAIL  %s: check file missing or unreadable (%s)\n' "$id" "$checkfile"
      if [ "$is_safety" = 1 ]; then
        hints="$hints
hint=The update \"$id\" is a safety fix and its check file is missing. Choose \"take the update\" so the check comes back."
      fi
    fi
    continue
  fi

  check_out=$( (cd "$root" && REPO_ROOT="$root" sh "$checkpath") 2>&1 )
  check_rc=$?
  if [ "$check_rc" = 0 ]; then
    pass=$((pass + 1))
    printf 'PASS  %s\n' "$id"
  elif [ "$is_safety" = 0 ] && [ "$copy_mode" = founder ]; then
    warn=$((warn + 1))
    printf 'WARN  %s: check exited %s\n' "$id" "$check_rc"
  else
    fail=$((fail + 1))
    printf 'FAIL  %s: check exited %s\n' "$id" "$check_rc"
    hintline=$(printf '%s\n' "$check_out" | tail -1)
    case $hintline in
      hint=*) hints="$hints
$hintline" ;;
    esac
  fi
done < "$noteslist"
rm -f "$noteslist"

printf 'updates-checks: %s passed, %s failed, %s warned\n' "$pass" "$fail" "$warn"

if [ "$fail" -gt 0 ] && [ -n "$hints" ]; then
  printf '%s\n' "$hints"
fi

[ "$fail" = 0 ]
