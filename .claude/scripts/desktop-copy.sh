#!/bin/sh
# Keeps a read-only folder of copies of the founder's FINISHED work on their
# Desktop, so they can see it without opening Claude: <Desktop>/My Launchhouse work/.
#
# Named "My Launchhouse work", never plain "Launchhouse": the README tells a
# founder to name their real, working clone "launchhouse", and both Mac and
# Windows filesystems are case-insensitive, so ~/Desktop/launchhouse (a real
# founder folder someone put on their Desktop) and a plain ~/Desktop/Launchhouse
# would have been the same folder.
#
# Every copy is the SAVED version, "HEAD:./growth-engine/<path>", read straight
# from git, never the working tree, so unsaved edits (in Cowork, or mid-turn)
# never appear until they are actually saved. The allowlist is fixed in this
# script and keyed off the track on the HEAD copy of the Brain: nothing that
# is not named below is ever copied, however it got into git.
#
# Run two ways:
#   sh desktop-copy.sh --hook     the SessionStart and Stop hooks. Skips
#                                 straight away, with no git process at all,
#                                 when HEAD has not moved since the last sync.
#   sh desktop-copy.sh            on demand, pre-approved in settings.json.
#                                 Always re-checks every file, even when HEAD
#                                 has not moved, so a copy that failed last
#                                 time (open in Excel, folder claimed by
#                                 someone else) gets another try.
#
# Fails open like every other hook here: any doubt and it does nothing and
# exits 0. It never prints to the founder directly; notes for them go in
# .git/launchhouse/desktop-note, which state-block.sh prints once and clears.

. "$(dirname "$0")/lib.sh" 2>/dev/null || exit 0
lh_active || exit 0

# Nobody is watching a routine run in the cloud, and there is no Desktop there
# to write to anyway.
case ${CLAUDE_CODE_SESSION_ATTENDED-1} in 1|true|yes) ;; *) exit 0 ;; esac
command -v git >/dev/null 2>&1 || exit 0

root=$(lh_root)
ge="$root/growth-engine"
hook_mode=0
[ "$1" = --hook ] && hook_mode=1

bk=$(lh_bk_dir) || exit 0
[ -n "$bk" ] || exit 0

# The fast path: on the hooks, do nothing at all, not even a git process,
# unless HEAD has actually moved since the copies were last written.
if [ "$hook_mode" = 1 ]; then
  fp=$(lh_head_fingerprint) || fp=""
  if [ -n "$fp" ] && [ -f "$bk/synced-head" ] && [ "$fp" = "$(cat "$bk/synced-head" 2>/dev/null)" ]; then
    exit 0
  fi
fi

mkdir -p "$bk/managed" 2>/dev/null || exit 0

# A note for the founder, queued for state-block.sh to say once and clear. A
# line already waiting there is never repeated, so a sync that is blocked
# every turn (a foreign folder, a folder too close to their own) says so once,
# not on every single Stop.
note_add() {
  msg=$1
  [ -f "$bk/desktop-note" ] && grep -qxF "$msg" "$bk/desktop-note" 2>/dev/null && return 0
  printf '%s\n' "$msg" >> "$bk/desktop-note" 2>/dev/null
}

# --- the Desktop path --------------------------------------------------------

lh_is_windows() {
  case $(uname 2>/dev/null) in MINGW*|MSYS*|CYGWIN*) return 0 ;; esac
  return 1
}

desktop=""
if [ -n "$LH_DESKTOP" ]; then
  desktop=$LH_DESKTOP
elif lh_is_windows; then
  cached=""
  [ -f "$bk/desktop-path" ] && cached=$(cat "$bk/desktop-path" 2>/dev/null)
  if [ -n "$cached" ] && [ -d "$cached" ]; then
    desktop=$cached
  else
    reg=$(reg query "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\User Shell Folders" /v Desktop 2>/dev/null)
    raw=$(printf '%s\n' "$reg" | awk '/Desktop/ { for (i = 1; i <= NF; i++) if ($i ~ /^%/ || $i ~ /^[A-Za-z]:/) v = $i; if (v == "") v = $NF; print v; exit }')
    exp=$(printf '%s' "$raw" | sed "s#%USERPROFILE%#$USERPROFILE#")
    if [ -n "$exp" ] && command -v cygpath >/dev/null 2>&1; then
      desktop=$(cygpath -u "$exp" 2>/dev/null)
    fi
    if [ -z "$desktop" ] || [ ! -d "$desktop" ]; then
      if [ -n "$USERPROFILE" ] && command -v cygpath >/dev/null 2>&1; then
        desktop=$(cygpath -u "$USERPROFILE" 2>/dev/null)/Desktop
      else
        desktop="$HOME/Desktop"
      fi
    fi
    [ -d "$desktop" ] && printf '%s' "$desktop" > "$bk/desktop-path" 2>/dev/null
  fi
else
  desktop="$HOME/Desktop"
fi

# Never create the Desktop itself, on any platform, and never invent one on
# Linux where there usually is none.
[ -n "$desktop" ] && [ -d "$desktop" ] || exit 0

# --- hard safety guard, before any write of any kind -------------------------
#
# Never write into, on top of, or around the founder's own folder: not the
# same folder, not inside it, not a parent that contains it, and not a folder
# that itself looks like a git checkout or a Launchhouse folder (carries
# growth-engine/.launchhouse or .git). Every comparison uses the resolved,
# physical path (symlinks followed) and is done case-insensitively, because
# both Mac and Windows treat different case as the same folder. This is a
# silent skip: there is nothing useful to tell the founder about a path that
# should never have been possible in the first place.

lh_real_path() {
  ( cd -P "$1" 2>/dev/null && pwd -P )
}
lh_lc() { printf '%s' "$1" | LC_ALL=C tr 'A-Z' 'a-z'; }

root_real=$(lh_real_path "$root")
[ -n "$root_real" ] || root_real=$root
root_lc=$(lh_lc "$root_real")

desktop_real=$(lh_real_path "$desktop")
[ -n "$desktop_real" ] || desktop_real=$desktop

copies="$desktop_real/My Launchhouse work"
marker="$copies/.launchhouse-copies"

copies_lc=$(lh_lc "$copies")
case $copies_lc in "$root_lc"|"$root_lc"/*) exit 0 ;; esac
case $root_lc in "$copies_lc"/*) exit 0 ;; esac
if [ -d "$copies" ]; then
  copies_real=$(lh_real_path "$copies")
  [ -n "$copies_real" ] || copies_real=$copies
  copies_real_lc=$(lh_lc "$copies_real")
  case $copies_real_lc in "$root_lc"|"$root_lc"/*) exit 0 ;; esac
  case $root_lc in "$copies_real_lc"/*) exit 0 ;; esac
  [ -e "$copies/growth-engine/.launchhouse" ] && exit 0
  [ -e "$copies/.git" ] && exit 0
fi

# --- the allowlist, from the track on the HEAD copy of the Brain -------------
#
# Read here, before ownership, so the folder is never created for a founder
# folder with nothing finished yet: brain_exists says whether even the Brain
# is in HEAD, which every other allowlisted file depends on (the track that
# adds them comes from reading it).

brain_tmp="$bk/tmp-brain.$$"
brain_exists=0
if git -C "$root" show "HEAD:./growth-engine/brain/founder-brain.md" > "$brain_tmp" 2>/dev/null; then
  brain_exists=1
  track=$(lh_track_of "$brain_tmp")
else
  track=""
fi
rm -f "$brain_tmp"

to_copy="brain/founder-brain.md"
if [ -n "$track" ]; then
  to_copy="$to_copy engines/content/content-30.md engines/content/content-30.csv engines/ops/ops-workflow.md engines/ops/ghl-values.md engines/plan/90-day-plan.md export/playbook-insert.pdf"
  case $track in
    b2b) to_copy="$to_copy engines/outreach/outreach-sequence.md" ;;
    b2c) to_copy="$to_copy engines/audience/hook-bank.md engines/audience/inbound-scripts.md" ;;
  esac
fi

# --- ownership ----------------------------------------------------------

if [ -d "$copies" ]; then
  if [ -f "$marker" ]; then
    src=$(tr -d '\r\n' < "$marker" 2>/dev/null)
    if [ -n "$src" ] && [ "$src" != "$root" ]; then
      if [ -d "$src" ]; then
        note_add "Your Desktop \"My Launchhouse work\" folder already holds copies made from another Launchhouse folder ($src). Nothing was written there this time; ask Claude before using the same Desktop folder for two founder folders."
        exit 0
      else
        printf '%s' "$root" > "$marker" 2>/dev/null
      fi
    fi
  else
    # A folder already sitting there with no marker was not made by this
    # script. It may be the founder's own thing, so nothing in it is ever
    # touched, moved or overwritten.
    note_add "There is already a folder called My Launchhouse work on your Desktop that Launchhouse did not make, so nothing was copied. Rename or move it, and your copies will appear."
    exit 0
  fi
else
  # Nothing finished yet (not even the Brain saved): never create the Desktop
  # folder for an empty founder folder. Exit without recording synced-head,
  # so the next SessionStart or Stop, once something is actually saved,
  # tries again rather than believing this "sync" already covered it.
  [ "$brain_exists" = 1 ] || exit 0
  mkdir -p "$copies" 2>/dev/null || exit 0
  printf '%s' "$root" > "$marker" 2>/dev/null
fi

# --- read/write helpers, portable read-only ----------------------------------

lh_make_writable() {
  f=$1
  [ -e "$f" ] || return 0
  if lh_is_windows && command -v cmd.exe >/dev/null 2>&1 && command -v cygpath >/dev/null 2>&1; then
    wp=$(cygpath -w "$f" 2>/dev/null)
    [ -n "$wp" ] && cmd.exe /c "attrib -R \"$wp\"" >/dev/null 2>&1
  fi
  chmod u+w "$f" 2>/dev/null
}

lh_make_readonly() {
  f=$1
  [ -e "$f" ] || return 0
  if lh_is_windows && command -v cmd.exe >/dev/null 2>&1 && command -v cygpath >/dev/null 2>&1; then
    wp=$(cygpath -w "$f" 2>/dev/null)
    [ -n "$wp" ] && cmd.exe /c "attrib +R \"$wp\"" >/dev/null 2>&1
  fi
  chmod 444 "$f" 2>/dev/null
}

# A destination in $1 named "<name> <when>.<ext>" that never overwrites one
# already there: " 2", " 3" and so on are added until the name is free. Used
# for both Your edits and Earlier, so two edits or two removals of the same
# file on the same day both survive.
lh_unique_target() {
  dir=$1; nm=$2; wh=$3; ex=$4
  if [ -n "$ex" ]; then cand="$nm $wh.$ex"; else cand="$nm $wh"; fi
  if [ ! -e "$dir/$cand" ]; then printf '%s' "$dir/$cand"; return 0; fi
  n=2
  while :; do
    if [ -n "$ex" ]; then cand="$nm $wh $n.$ex"; else cand="$nm $wh $n"; fi
    [ -e "$dir/$cand" ] || { printf '%s' "$dir/$cand"; return 0; }
    n=$((n + 1))
  done
}

# --- copy each allowed file, from HEAD only ----------------------------------

manifest_new="$bk/tmp-manifest.$$"
: > "$manifest_new" 2>/dev/null || exit 0

# Moves the current copy of $1 (base name) into Earlier/, never overwriting
# one already there.
lh_to_earlier() {
  b=$1; d="$copies/$b"
  [ -f "$d" ] || return 0
  mkdir -p "$copies/Earlier" 2>/dev/null
  nm=${b%.*}; ex=${b##*.}; [ "$ex" = "$b" ] && ex=""
  when=$(date '+%Y-%m-%d %H%M' 2>/dev/null)
  target=$(lh_unique_target "$copies/Earlier" "$nm" "$when" "$ex")
  lh_make_writable "$d"
  mv -f "$d" "$target" 2>/dev/null
}

sync_one() {
  relpath=$1
  base=${relpath##*/}
  dest="$copies/$base"
  rec="$bk/managed/$base"
  stampfile="$bk/managed/$base.stamp"
  content_tmp="$bk/tmp-content.$$"

  if ! git -C "$root" show "HEAD:./growth-engine/$relpath" > "$content_tmp" 2>/dev/null; then
    rm -f "$content_tmp"
    lh_to_earlier "$base"
    rm -f "$rec" "$stampfile"
    return
  fi

  new_sum=$(cksum < "$content_tmp" | awk '{ print $1 "-" $2 }')

  # Founder edited the copy: its size or its mtime no longer match what was
  # recorded the moment this script last wrote it. Move it aside before
  # anything else touches it, and say so once.
  if [ -f "$dest" ] && [ -f "$rec" ]; then
    rec_size=$(awk -F '\t' '{ print $1 }' "$rec")
    cur_size=$(wc -c < "$dest" 2>/dev/null | tr -d ' ')
    edited=0
    [ "$cur_size" != "$rec_size" ] && edited=1
    if [ -f "$stampfile" ]; then
      { [ "$dest" -nt "$stampfile" ] || [ "$dest" -ot "$stampfile" ]; } && edited=1
    fi
    if [ "$edited" = 1 ]; then
      mkdir -p "$copies/Your edits" 2>/dev/null
      name=${base%.*}
      ext=${base##*.}
      [ "$ext" = "$base" ] && ext=""
      when=$(date '+%Y-%m-%d %H%M' 2>/dev/null)
      target=$(lh_unique_target "$copies/Your edits" "$name" "$when" "$ext")
      lh_make_writable "$dest"
      if mv -f "$dest" "$target" 2>/dev/null; then
        note_add "Your edits to $base were moved into the \"Your edits\" folder, and a fresh copy of what is saved in Claude was written in its place."
      fi
      rm -f "$rec" "$stampfile"
    fi
  fi

  # Nothing changed: the copy already holds this exact saved content and the
  # founder has not touched it. Leave it alone, so nothing is ever rewritten
  # for no reason.
  if [ -f "$dest" ] && [ -f "$rec" ]; then
    rec_sum=$(awk -F '\t' '{ print $2 }' "$rec")
    rec_size=$(awk -F '\t' '{ print $1 }' "$rec")
    cur_size=$(wc -c < "$dest" 2>/dev/null | tr -d ' ')
    if [ "$rec_sum" = "$new_sum" ] && [ "$cur_size" = "$rec_size" ]; then
      rm -f "$content_tmp"
      printf '%s\n' "$base" >> "$manifest_new"
      return
    fi
  fi

  lh_make_writable "$dest"
  wrote=0
  cp -f "$content_tmp" "$dest" 2>/dev/null && wrote=1
  if [ "$wrote" != 1 ]; then
    # One retry, immediately: the usual cause is the founder has it open, and
    # a second try a moment later in the same run rarely helps more than this.
    lh_make_writable "$dest"
    cp -f "$content_tmp" "$dest" 2>/dev/null && wrote=1
  fi
  rm -f "$content_tmp"
  if [ "$wrote" != 1 ]; then
    note_add "$base could not be copied to your Desktop folder, maybe because it is open somewhere. It will be tried again next time your work is saved."
    return
  fi
  lh_make_readonly "$dest"
  sz=$(wc -c < "$dest" 2>/dev/null | tr -d ' ')
  printf '%s\t%s\n' "$sz" "$new_sum" > "$rec" 2>/dev/null
  touch -r "$dest" "$stampfile" 2>/dev/null
  printf '%s\n' "$base" >> "$manifest_new"
}

for relpath in $to_copy; do
  sync_one "$relpath"
done

# A file that left the allowlist entirely (the track changed, dropping a file
# that used to be copied) is not visited by sync_one above, so anything the
# last run managed that this run did not touch moves to Earlier/ too.
old_manifest="$bk/manifest"
if [ -f "$old_manifest" ]; then
  while IFS= read -r b; do
    [ -n "$b" ] || continue
    grep -qxF "$b" "$manifest_new" 2>/dev/null && continue
    lh_to_earlier "$b"
    rm -f "$bk/managed/$b" "$bk/managed/$b.stamp"
  done < "$old_manifest"
fi
mv -f "$manifest_new" "$bk/manifest" 2>/dev/null

# --- the read me, rewritten only when it would actually change --------------

readme="$copies/0 READ ME.md"
readme_tmp="$bk/tmp-readme.$$"
{
  printf 'These are copies of your finished Launchhouse work.\n\n'
  printf 'They update on their own each time your work is saved in Claude.\n\n'
  printf 'To change something, ask Claude in your Launchhouse folder, not here.\n\n'
  printf 'Please do not open this folder in Claude. It is not your Launchhouse folder;\n'
  printf 'it is just a read-only copy of it.\n\n'
  printf 'If you edit one of these files, your version is kept safe in "Your edits"\n'
  printf 'instead of being lost the next time your work is saved.\n'
} > "$readme_tmp" 2>/dev/null
if [ ! -f "$readme" ] || ! cmp -s "$readme_tmp" "$readme" 2>/dev/null; then
  lh_make_writable "$readme"
  if mv -f "$readme_tmp" "$readme" 2>/dev/null; then
    lh_make_readonly "$readme"
  fi
else
  rm -f "$readme_tmp"
fi

# --- remember where HEAD was, so the hooks can skip cheaply next time -------

fp=$(lh_head_fingerprint) || fp=""
[ -n "$fp" ] && printf '%s' "$fp" > "$bk/synced-head" 2>/dev/null
exit 0
