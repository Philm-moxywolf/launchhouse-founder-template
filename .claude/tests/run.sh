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

if [ "$fail" = 0 ]; then
  printf '\nAll cases passed.\n'
else
  printf '\nSome cases failed.\n'
fi
exit $fail
