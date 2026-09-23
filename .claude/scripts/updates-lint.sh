#!/bin/sh
# Validates every improvement note under .claude/updates/<release>/*.md
# (except README.md) against the note schema described in
# .claude/updates/README.md. POSIX sh + awk only -- no jq, no node, no
# python (lib.sh line 1's rule, extended to every script under .claude/).
#
# Usage: sh .claude/scripts/updates-lint.sh [repo-root]
# repo-root defaults to two directories up from this script's own folder
# (.claude/scripts/.. .. == the repo root), so it works from anywhere.
#
# Checks, per note:
#   - every required frontmatter key is present
#   - id matches the file name (without .md)
#   - a safety: true note names an existing check file
#   - every touches path exists in the repo
#   - no touches path is under growth-engine/
#
# Prints one "FAIL <note>: <reason>" line per problem found (note paths are
# repo-relative), and "notes=<n> ok" on success (n = notes checked). Exit 0
# when every note is valid, 1 when any FAIL line was printed.

set -u
here=$(cd "$(dirname "$0")" && pwd)
root=${1:-$(cd "$here/../.." && pwd)}
updates_dir="$root/.claude/updates"

fail=0
count=0

# All scratch files this script creates live outside the repo, under
# TMPDIR, and are cleaned up on any exit (normal, error, or signal). Used
# only to read a multi-line list back without a pipe's subshell, which
# would otherwise swallow changes to $fail made inside the loop.
#
# Every call site invokes lh_mktemp via a $(...) command substitution,
# which runs in a subshell in POSIX sh -- a shell VARIABLE assignment made
# inside that subshell never escapes it. So the registry has to be a FILE
# (real filesystem I/O, which does persist past the subshell exiting)
# rather than a shell variable, or every temp file lh_mktemp ever creates
# is silently leaked into ${TMPDIR:-/tmp} forever.
LH_TMP_REGISTRY=$(mktemp "${TMPDIR:-/tmp}/lh-updates-lint-registry.XXXXXX") || {
  echo "could not create a temp registry under \${TMPDIR:-/tmp}" >&2
  exit 1
}
lh_mktemp() {
  lh_mt_f=$(mktemp "${TMPDIR:-/tmp}/lh-updates-lint.XXXXXX") || {
    echo "could not create a temp file under \${TMPDIR:-/tmp}" >&2
    exit 1
  }
  printf '%s\n' "$lh_mt_f" >> "$LH_TMP_REGISTRY"
  printf '%s' "$lh_mt_f"
}
lh_cleanup() {
  [ -f "$LH_TMP_REGISTRY" ] || return 0
  while IFS= read -r lh_ctf; do
    [ -n "$lh_ctf" ] && rm -f "$lh_ctf"
  done < "$LH_TMP_REGISTRY"
  rm -f "$LH_TMP_REGISTRY"
}
trap lh_cleanup EXIT INT TERM

problem() { # note (repo-relative), reason
  printf 'FAIL %s: %s\n' "$1" "$2"
  fail=1
}

# ---------------------------------------------------------------- helpers

# A note's frontmatter block, as raw lines (no --- delimiters, and any
# trailing \r stripped so a CRLF file on a Windows checkout reads the same
# as an LF one), or the single line NOFRONT if it has none.
lh_note_frontmatter() { # file
  awk '
    { sub(/\r$/, "") }
    NR == 1 && $0 !~ /^---[ \t]*$/ { print "NOFRONT"; exit }
    NR == 1 { next }
    /^---[ \t]*$/ { exit }
    { print }
  ' "$1"
}

# One single-line key's value, trimmed of surrounding whitespace. Empty if
# the key is absent (also the empty-but-present case, which lh_note_fm_has
# tells apart).
lh_note_fm_scalar() { # frontmatter, key
  printf '%s\n' "$1" | awk -v k="$2" '
    $0 ~ "^" k ":" {
      line = $0
      sub("^" k ":", "", line)
      sub(/^[ \t]+/, "", line)
      sub(/[ \t]+$/, "", line)
      print line
      exit
    }
  '
}

# A list key's items, one per line, a wrapping pair of double quotes
# stripped from each. Empty output for "key: []" or a missing key. A list
# key's own items are the indented "  - item" lines straight after it.
lh_note_fm_list() { # frontmatter, key
  printf '%s\n' "$1" | awk -v k="$2" '
    BEGIN { inlist = 0 }
    inlist && /^[ \t]+-[ \t]/ {
      line = $0
      sub(/^[ \t]+-[ \t]*/, "", line)
      sub(/[ \t]+$/, "", line)
      print line
      next
    }
    inlist { inlist = 0 }
    $0 ~ "^" k ":" {
      rest = $0
      sub("^" k ":", "", rest)
      sub(/^[ \t]+/, "", rest)
      sub(/[ \t]+$/, "", rest)
      if (rest == "") { inlist = 1 }
      next
    }
  ' | sed -e 's/^"\(.*\)"$/\1/'
}

# Whether a key line (scalar or list) is present at all in the frontmatter.
lh_note_fm_has() { # frontmatter, key
  printf '%s\n' "$1" | grep -q "^$2:"
}

# Strips one wrapping pair of matching quotes (double or single) from a
# value, for the emptiness test only -- lh_note_fm_scalar's raw return
# value is relied on unchanged by its other callers (id/note_id
# comparison, safety/founder-data case-matching, check_name file lookup),
# so this is intentionally a separate helper, not a change to
# lh_note_fm_scalar itself.
lh_strip_wrapping_quotes() { # value
  printf '%s' "$1" | sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\\(.*\\)'\$/\\1/"
}

# ------------------------------------------------------------------- lint

[ -d "$updates_dir" ] || { printf 'notes=0 ok\n'; exit 0; }

for release_dir in "$updates_dir"/*/; do
  [ -d "$release_dir" ] || continue
  for note in "$release_dir"*.md; do
    [ -f "$note" ] || continue
    base=$(basename "$note")
    [ "$base" = "README.md" ] && continue
    count=$((count + 1))

    case "$note" in
      "$root"/*) relnote=${note#"$root"/} ;;
      *) relnote=$note ;;
    esac

    fm=$(lh_note_frontmatter "$note")
    if [ "$fm" = NOFRONT ]; then
      problem "$relnote" "no --- frontmatter block at the top of the file"
      continue
    fi

    missing=
    for key in id title purpose touches adds requires safety done-when check founder-data; do
      lh_note_fm_has "$fm" "$key" || missing="$missing $key"
    done
    if [ -n "$missing" ]; then
      problem "$relnote" "missing frontmatter key(s):$missing"
      continue
    fi

    # A key that is present but carries nothing after its colon is as
    # broken as the key being absent outright: an empty purpose says
    # nothing an adapting worker or a founder can act on, and a blank
    # check: or safety: line is never a valid value for either.
    empty=
    for key in id title purpose safety check founder-data; do
      val=$(lh_note_fm_scalar "$fm" "$key")
      stripped=$(lh_strip_wrapping_quotes "$val")
      [ -n "$stripped" ] || empty="$empty $key"
    done
    if [ -n "$empty" ]; then
      problem "$relnote" "empty frontmatter key(s), present but with no value:$empty"
      continue
    fi

    # touches and done-when are the two list keys this note has no "[] if
    # none" escape hatch for (README.md reserves that shape for adds and
    # requires only): a note that touches nothing changed nothing, and a
    # note with no done-when statement gives update-reviewer and a safety
    # note's own check nothing to judge the result against.
    touches_tmp=$(lh_mktemp)
    lh_note_fm_list "$fm" touches | awk 'NF' > "$touches_tmp"
    [ -s "$touches_tmp" ] || problem "$relnote" "touches has no items -- a note must touch at least one file"

    donewhen_tmp=$(lh_mktemp)
    lh_note_fm_list "$fm" done-when | awk 'NF' > "$donewhen_tmp"
    [ -s "$donewhen_tmp" ] || problem "$relnote" "done-when has no items -- a note needs at least one statement that must hold once it is applied"

    note_id=$(lh_note_fm_scalar "$fm" id)
    id_from_name=${base%.md}
    if [ "$note_id" != "$id_from_name" ]; then
      problem "$relnote" "id '$note_id' does not match its file name '$id_from_name'"
    fi

    safety=$(lh_note_fm_scalar "$fm" safety)
    case "$safety" in
      true|false) : ;;
      *) problem "$relnote" "safety must be true or false, not '$safety'" ;;
    esac

    founder_data=$(lh_note_fm_scalar "$fm" founder-data)
    case "$founder_data" in
      true|false) : ;;
      *) problem "$relnote" "founder-data must be true or false, not '$founder_data'" ;;
    esac

    check_name=$(lh_note_fm_scalar "$fm" check)
    if [ "$safety" = "true" ]; then
      if [ "$check_name" = "none" ]; then
        problem "$relnote" "safety: true but check: none -- a safety note must name an existing check file"
      elif [ ! -f "$release_dir$check_name" ]; then
        problem "$relnote" "safety: true but its check file '$check_name' does not exist in $(dirname "$relnote")"
      elif [ ! -s "$donewhen_tmp" ]; then
        problem "$relnote" "safety: true but done-when has no items -- a safety note's check has nothing to prove"
      fi
    fi

    while IFS= read -r t; do
      [ -n "$t" ] || continue
      case "$t" in
        growth-engine/*|growth-engine)
          problem "$relnote" "touches path is under growth-engine/: $t"
          ;;
      esac
      [ -e "$root/$t" ] || problem "$relnote" "touches path does not exist in the repo: $t"
    done < "$touches_tmp"
  done
done

if [ "$fail" = 0 ]; then
  printf 'notes=%s ok\n' "$count"
  exit 0
fi
exit 1
