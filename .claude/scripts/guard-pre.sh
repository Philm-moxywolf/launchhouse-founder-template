#!/bin/sh
# PreToolUse on Write, Edit and MultiEdit.
#
# Decides from the path alone, before anything is written:
#   - a Launchhouse file being written outside growth-engine/ (design rule 4)
#   - a path that climbs out of the folder
#   - a file at the top of growth-engine/ that is not one of ours
#   - the other track's file, or a track file before a track is chosen (rule 1)
#   - a person file whose name is not a plain slug
# Then keeps a copy of the file as it was, so guard-post.sh can put it back if
# the new words break a rule.
#
# Also PreToolUse on Bash: a shell command (cp, mv, a redirect) can write under
# growth-engine/ without the editing tools, so before it runs, keep a copy of
# every judged file. guard-post.sh then checks whatever the command changed.

. "$(dirname "$0")/lib.sh" 2>/dev/null || exit 0

input=$(cat) || exit 0

tool=$(lh_json_get tool_name "$input") || tool=""
if [ "$tool" = Bash ]; then
  lh_active || exit 0
  pre="$(lh_root)/growth-engine/.state/.pre"
  rm -rf "$pre/shell" "$pre/shell.sums" "$pre/shell.list" 2>/dev/null
  cmd=$(lh_json_get command "$input") || cmd=""
  # Never push to the public original every founder copies (LH-003).
  lh_push_to_original "$cmd" && lh_deny_pre "Not pushed: that copy on GitHub is the public Launchhouse original, so the founder's work would be public. Tell the founder in one plain sentence that their work is saved on this computer, and that their own private copy on GitHub is where it should go."
  # Bringing back work already saved in this folder is not checked again: an
  # undo must never be undone. Only these exact forms, on one line.
  nl=$(printf '\n\rx'); nl=${nl%x}
  case $cmd in
    *[$nl]*|*'>'*|*'<'*|*'|'*|*';'*|*'&'*|*'`'*|*'$('*) ;;
    'git restore '*|'git checkout '*' -- '*|'git pull --no-rebase'|'git merge --abort') exit 0 ;;
  esac
  mkdir -p "$pre/shell" 2>/dev/null || exit 0
  ge="$(lh_root)/growth-engine"
  lh_judged_files > "$pre/shell.list" 2>/dev/null || exit 0
  if [ -s "$pre/shell.list" ]; then
    ( cd "$ge" && tar -cf - -T "$pre/shell.list" ) 2>/dev/null | ( cd "$pre/shell" && tar -xf - ) 2>/dev/null
    sums=$(lh_sums "$ge" < "$pre/shell.list")
    # Fail open: if the copy is not exact, check nothing rather than risk
    # removing a file that could not be put back.
    [ "$sums" = "$(lh_sums "$pre/shell" < "$pre/shell.list")" ] || { rm -rf "$pre/shell" "$pre/shell.list"; exit 0; }
    printf '%s\n' "$sums" > "$pre/shell.sums"
  else
    : > "$pre/shell.sums"
  fi
  exit 0
fi

path=$(lh_json_get file_path "$input") || exit 0
[ -n "$path" ] || exit 0

full=$(printf '%s' "$path" | tr '\\' '/')
base=${full##*/}

# Opened in the wrong folder: a Launchhouse file written here would be lost.
if ! lh_active; then
  near=$(lh_near_all)
  if [ -n "$near" ] && [ -n "$(lh_file_track "$base")" ] && [ "$base" != ".launchhouse" ]; then
    if [ "$(printf '%s\n' "$near" | grep -c .)" -gt 1 ]; then
      lh_deny_pre "Not written: this is not the founder's Launchhouse folder, so $base would be lost here. There are several Launchhouse folders nearby: $(printf '%s' "$near" | tr '\n' ';' | sed 's/;$//; s/;/, /g'). Ask the founder which is the real one, and tell them to open it."
    fi
    lh_deny_pre "Not written: this is not the founder's Launchhouse folder, so $base would be lost here. Their folder is $near. Tell the founder in one sentence to open that folder instead, then do the work there."
  fi
  exit 0
fi

rel=$(lh_rel "$path")

# The folder is growth-engine in lower case. On a Mac, Growth-Engine/ is the
# same folder, but the checks below would not see it as ours.
top=${rel%%/*}
if [ "$top" != growth-engine ] && [ "$(printf '%s' "$top" | LC_ALL=C tr 'A-Z' 'a-z')" = growth-engine ]; then
  lh_deny_pre "Not written: the folder is called growth-engine, all in lower case. Write it to growth-engine/${rel#*/} instead."
fi

case $rel in
  growth-engine/*) ;;
  *)
    ftrack=$(lh_file_track "$base")
    if [ -n "$ftrack" ] && [ "$base" != ".launchhouse" ]; then
      track=$(lh_track)
      if { [ "$ftrack" = b2b ] || [ "$ftrack" = b2c ]; } && [ "$track" != "$ftrack" ]; then
        lh_deny_pre "Not written: $base is part of the $(printf '%s' "$ftrack" | tr 'bc' 'BC') method, and this founder is not on that track. Never write the other track's files, here or anywhere."
      fi
      lh_deny_pre "Not written: $base belongs inside the growth-engine folder, and every Launchhouse file lives there so nothing gets lost. Write it to growth-engine/$base instead."
    fi
    exit 0 ;;
esac

inner=${rel#growth-engine/}

case "/$inner/" in
  */../*|*/./*) lh_deny_pre "Not written: $rel climbs out of the growth-engine folder. Keep every path inside growth-engine/." ;;
esac

case $inner in
  */*)
    top=${inner%%/*}
    case $top in
      people)
        case $base in
          README.md) ;;
          *)
            slug=${base%.md}
            if [ "$slug" = "$base" ] || ! printf '%s' "$slug" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' || [ ${#slug} -gt 60 ]; then
              lh_deny_pre "Not written: person files are named as a plain slug, lower case letters, digits and single dashes, ending .md, for example sam-example-com.md. Rename it and write it again."
            fi ;;
        esac ;;
      uploads|voice-samples|drafts|.state) ;;
      *) lh_deny_pre "Not written: growth-engine/$top/ is not one of the Launchhouse folders. Use drafts/ for work in progress, uploads/ for documents, voice-samples/ for the founder's own writing." ;;
    esac ;;
  *)
    ftrack=$(lh_file_track "$inner")
    if [ -z "$ftrack" ]; then
      lh_deny_pre "Not written: $inner is not one of the Launchhouse files. Put work in progress in growth-engine/drafts/ instead, or use the file name the engine asks for."
    fi
    if [ "$ftrack" = b2b ] || [ "$ftrack" = b2c ]; then
      track=$(lh_track)
      case $track in
        b2b|b2c) ;;
        *) lh_deny_pre "Not written: $inner is for one track only, and the Founder Brain does not have a track yet. Build or finish the Founder Brain first (/growth-engine:brain)." ;;
      esac
      if [ "$track" != "$ftrack" ]; then
        other=$(printf '%s' "$ftrack" | tr 'bc' 'BC')
        lh_deny_pre "Not written: $inner is part of the $other method, and this founder is on the $(printf '%s' "$track" | tr 'bc' 'BC') track. Never write the other track's files."
      fi
    fi ;;
esac

# Keep the file as it was, for guard-post.sh.
if lh_is_judged "$inner"; then
  pre="$(lh_root)/growth-engine/.state/.pre"
  mkdir -p "$pre" 2>/dev/null || exit 0
  key=$(lh_key "$inner")
  file="$(lh_root)/$rel"
  if [ -f "$file" ]; then
    cp -p "$file" "$pre/$key" 2>/dev/null && rm -f "$pre/$key.new"
  else
    : > "$pre/$key.new" 2>/dev/null && rm -f "$pre/$key"
  fi
fi
exit 0
