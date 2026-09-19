#!/bin/sh
# PreToolUse on Write, Edit and MultiEdit.
#
# Decides from the path alone, before anything is written:
#   - a Launchhouse file being written outside growth-engine/ (design rule 4)
#   - a path that climbs out of the folder
#   - a file in growth-engine/ that is not one of ours, or not where the contract puts it
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

# The GoHighLevel key lives in the computer's own password store, and is never
# read in the conversation. Only Claude Code's own connection reads it, through
# ghl-headers.sh, and ghl-values-api.sh sends the values token to GoHighLevel
# without printing it. So refuse any command that reads the store itself, and
# allow the helpers only in the forms that never show a key.
keymsg="Not run: that would show the founder's GoHighLevel key in the chat. The only commands allowed near it are sh .claude/scripts/ghl-headers.sh --check < /dev/null, the same with --connect, and ghl-values-api.sh with list, create or update. None of them shows the key."
# A Private Integration key starts pit- and eight hex characters. It never goes
# in a file here, where the next save would put it in git, or on a command line.
pitmsg="Not saved: that holds a GoHighLevel key. A key never goes in a file in this folder or in a command. It lives only in the computer's password store. Tell the founder in one plain sentence that the key stays in their password store and nowhere else."
pit='pit-[0-9A-Fa-f]{8}-'
nl=$(printf '\n\rx'); nl=${nl%x}
case $tool in
  Read|Grep|Glob) exit 0 ;;
  Write|Edit|MultiEdit)
    # What is being written, without the old text an edit replaces.
    printf '%s' "$input" | sed -E 's/"old_string"[[:space:]]*:[[:space:]]*"([^"\\]|\\.)*"//g' | grep -Eq "$pit" \
      && lh_deny_pre "$pitmsg" ;;
  Bash)
    kc=$(lh_json_get command "$input") || kc=""
    printf '%s' "$kc" | grep -Eq "$pit" && lh_deny_pre "$pitmsg"
    kl=$(printf '%s' "$kc" | tr 'A-Z' 'a-z')
    case $kl in
      *find-generic-password*|*find-internet-password*|*dump-keychain*|*credread*|*credenumerate*|\
      *passwordvault*|*-encodedcommand*|*ghl-store*|*ghl_store*|*"launchhouse gohighlevel"*|\
      *claude_code_mcp_server*) lh_deny_pre "$keymsg" ;;
    esac
    # The helpers run only from this folder, alone, on one line.
    case $kc in
      *ghl-headers*|*ghl-values-api*)
        case $kc in *[$nl]*|*';'*|*'&'*|*'|'*|*'`'*|*'$('*|*'>'*) lh_deny_pre "$keymsg" ;; esac ;;
    esac
    case $kc in
      *ghl-headers*)
        printf '%s' "$kc" | grep -Eqx 'sh (\.claude/scripts/ghl-headers\.sh|"\$CLAUDE_PROJECT_DIR/\.claude/scripts/ghl-headers\.sh") --(check|connect|disconnect)( < /dev/null)?' \
          || lh_deny_pre "$keymsg" ;;
    esac
    case $kc in
      *ghl-values-api*)
        printf '%s' "$kc" | grep -Eqx 'sh (\.claude/scripts/ghl-values-api\.sh|"\$CLAUDE_PROJECT_DIR/\.claude/scripts/ghl-values-api\.sh") (list|create|update [A-Za-z0-9]+)( < [A-Za-z0-9_./:~-]+)?' \
          || lh_deny_pre "$keymsg" ;;
    esac ;;
esac

if [ "$tool" = Bash ]; then
  lh_active || exit 0
  pre="$(lh_root)/growth-engine/.state/.pre"
  rm -rf "$pre/shell" "$pre/shell.sums" "$pre/shell.list" 2>/dev/null
  cmd=$(lh_json_get command "$input") || cmd=""

  # Real people's names, emails and handles stay in this folder. A shell copy
  # or archive naming people/, the outreach first lines or the DM openers is
  # refused when it names a destination outside the project: home, a drive
  # letter, or a Desktop folder. desktop-copy.sh is the one thing allowed to
  # put anything on the Desktop, and it never goes through cp/mv/tar for this:
  # it reads git history straight into a fixed, safe set of file names.
  cl=$(printf '%s' "$cmd" | tr 'A-Z' 'a-z')
  if printf '%s' "$cl" | grep -Eq '(^|[;&|]|&&|\|\|)[[:space:]]*(cp|mv|rsync|tar|zip|ditto|robocopy|xcopy|copy-item)([[:space:]]|$)' \
      && printf '%s' "$cl" | grep -Eq 'people/|outreach-firstlines|dm-openers'; then
    dest=$(printf '%s' "$cl" | awk '{ print $NF }' | sed "s/^[\"']//; s/[\"']\$//")
    outside=0
    case $dest in
      '~'*|*'$home'*|*'${home}'*|/users/*|/home/*|*desktop*|[a-z]:[/\\]*|*'%userprofile%'*) outside=1 ;;
    esac
    if [ "$outside" = 1 ]; then
      r=$(printf '%s' "$(lh_root)" | LC_ALL=C tr 'A-Z' 'a-z')
      case $dest in "$r"/*|"$r") outside=0 ;; esac
    fi
    [ "$outside" = 1 ] && lh_deny_pre "Not run: that would copy real people's details out of this folder. Their names, emails and handles stay in growth-engine/ and nowhere else."
  fi

  # Never push to the public original every founder copies (LH-003).
  lh_push_to_original "$cmd" && lh_deny_pre "Not pushed: that copy on GitHub is the public Launchhouse original, so the founder's work would be public. Tell the founder in one plain sentence that their work is saved on this computer, and that their own private copy on GitHub is where it should go."
  # Bringing back work already saved in this folder is not checked again: an
  # undo must never be undone. Only these exact forms, on one line.
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
  if [ -n "$near" ] && [ -n "$(lh_base_track "$base")" ] && [ "$base" != ".launchhouse" ]; then
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
    ftrack=$(lh_base_track "$base")
    if [ -n "$ftrack" ] && [ "$base" != ".launchhouse" ]; then
      track=$(lh_track)
      if { [ "$ftrack" = b2b ] || [ "$ftrack" = b2c ]; } && [ "$track" != "$ftrack" ]; then
        lh_deny_pre "Not written: $base is part of the $(printf '%s' "$ftrack" | tr 'bc' 'BC') method, and this founder is not on that track. Never write the other track's files, here or anywhere."
      fi
      lh_deny_pre "Not written: $base belongs inside the growth-engine folder, and every Launchhouse file lives there so nothing gets lost. Write it to growth-engine/$(lh_place "$base") instead."
    fi
    exit 0 ;;
esac

inner=${rel#growth-engine/}

case "/$inner/" in
  */../*|*/./*) lh_deny_pre "Not written: $rel climbs out of the growth-engine folder. Keep every path inside growth-engine/." ;;
esac

# Where each file goes is the table in .claude/references/contract.md, which
# lh_place in lib.sh mirrors. The folders that take any file are people/,
# drafts/, inbox/uploads/, brain/voice-samples/ and .state/.
place=$(lh_place "$base")
case $inner in
  people/*)
    case $base in
      README.md) ;;
      *)
        slug=${base%.md}
        if [ "$slug" = "$base" ] || ! printf '%s' "$slug" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' || [ ${#slug} -gt 60 ]; then
          lh_deny_pre "Not written: person files are named as a plain slug, lower case letters, digits and single dashes, ending .md, for example sam-example-com.md. Rename it and write it again."
        fi ;;
    esac ;;
  drafts/*|inbox/uploads/*|brain/voice-samples/*|.state/*) ;;
  uploads/*|voice-samples/*)
    lh_deny_pre "Not written: growth-engine/${inner%%/*}/ has moved to growth-engine/$(lh_dir_place "${inner%%/*}")/. Write it to growth-engine/$(lh_dir_place "${inner%%/*}")/${inner#*/} instead." ;;
  *)
    if [ -n "$place" ] && [ "$place" != "$inner" ]; then
      lh_deny_pre "Not written: $base lives at growth-engine/$place, not growth-engine/$inner. Write it there instead."
    fi
    ftrack=$(lh_file_track "$inner")
    if [ -z "$ftrack" ]; then
      case $inner in
        */*) lh_deny_pre "Not written: growth-engine/$inner is not one of the Launchhouse files. Put work in progress in growth-engine/drafts/, documents in growth-engine/inbox/uploads/, and the founder's own writing in growth-engine/brain/voice-samples/, or use the file name the engine asks for." ;;
        *) lh_deny_pre "Not written: $inner is not one of the Launchhouse files. Put work in progress in growth-engine/drafts/ instead, or use the file name the engine asks for." ;;
      esac
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
