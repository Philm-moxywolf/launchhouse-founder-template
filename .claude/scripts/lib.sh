# Shared helpers for the Launchhouse hooks. POSIX sh, no jq, no node, no python.
#
# Every hook FAILS OPEN. A script that cannot work out what is going on exits 0
# and lets the write through, because a hook that blocks every write in a room
# of 130 founders stops the event. The rules-reviewer agent is the second layer.

# The founder's project folder. Claude Code sets CLAUDE_PROJECT_DIR for hooks.
lh_root() {
  r=${CLAUDE_PROJECT_DIR:-$PWD}
  printf '%s' "$r" | tr '\\' '/'
}

# A folder is a Launchhouse folder only if it carries the marker. Everywhere
# else these hooks do nothing, so the plugin is inert in a founder's other work.
lh_active() {
  [ -f "$(lh_root)/growth-engine/.launchhouse" ]
}

# The path of a Launchhouse folder near the opened one: one folder down, the
# parent, or the home folder. Empty if none. Used when the founder opened the
# wrong folder, which is the most common failure of all.
lh_near() {
  lh_near_all | head -1
}

# Every Launchhouse folder near the opened one, one per line.
lh_near_all() {
  r=$(lh_root)
  for cand in "$r"/*/growth-engine/.launchhouse "$r/../growth-engine/.launchhouse" "${HOME:-/nonexistent}/growth-engine/.launchhouse"; do
    [ -f "$cand" ] && (cd "$(dirname "$cand")/.." 2>/dev/null && pwd)
  done | awk '!seen[$0]++'
  return 0
}

# Read one JSON string value by key from the hook input (stdin, passed as $2).
# Handles the escapes a path can carry. Only ever used for short values.
lh_json_get() {
  printf '%s' "$2" | awk -v key="$1" '
    BEGIN { RS = "\001" }
    {
      pat = "\"" key "\"[ \t\r\n]*:[ \t\r\n]*\""
      if (!match($0, pat)) exit 1
      s = substr($0, RSTART + RLENGTH); out = ""; i = 1; n = length(s)
      while (i <= n) {
        c = substr(s, i, 1)
        if (c == "\\") {
          d = substr(s, i + 1, 1)
          if (d == "n") out = out "\n"
          else if (d == "t") out = out "\t"
          else if (d == "r") out = out "\r"
          else if (d == "u") { out = out "?"; i += 4 }
          else out = out d
          i += 2; continue
        }
        if (c == "\"") break
        out = out c; i++
      }
      printf "%s", out
    }'
}

# Escape a string for use inside a JSON string. Newlines become spaces.
lh_json_escape() {
  printf '%s' "$1" | awk 'BEGIN { RS = "\001" } {
    gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); gsub(/\t/, " "); gsub(/\r/, ""); gsub(/\n/, " ")
    printf "%s", $0 }'
}

# Path of a file relative to the project root, forward slashes. Empty if the
# file sits outside the project. The root is compared ignoring case, because the
# Mac and Windows file systems treat /Users/x and /users/x as the same folder.
lh_rel() {
  p=$(printf '%s' "$1" | tr '\\' '/')
  root=$(lh_root)
  case $p in
    "$root"/*) printf '%s' "${p#"$root"/}" ;;
    /*|[A-Za-z]:/*)
      printf '%s\n%s\n' "$root" "$p" | LC_ALL=C awk '
        NR == 1 { r = tolower($0) "/"; next }
        NR == 2 && tolower(substr($0, 1, length(r))) == r { printf "%s", substr($0, length(r) + 1) }' ;;
    ./*) printf '%s' "${p#./}" ;;
    *) printf '%s' "$p" ;;
  esac
}

# The Track line from the Founder Brain header, lower case, or empty.
lh_track() {
  b="$(lh_root)/growth-engine/founder-brain.md"
  [ -f "$b" ] || return 0
  lh_track_of "$b"
}

lh_track_of() {
  awk '
    /^## / { exit }
    {
      line = tolower($0)
      gsub(/\*/, "", line)
      if (match(line, /^[-[:space:]]*track[[:space:]]*:[[:space:]]*/)) {
        v = substr(line, RSTART + RLENGTH)
        sub(/[[:space:]].*$/, "", v)
        print v
        exit
      }
    }' "$1"
}

# A header label from the Brain, as written (first match, trimmed).
lh_brain_label() {
  b="$(lh_root)/growth-engine/founder-brain.md"
  [ -f "$b" ] || return 0
  awk -v want="$1" '
    /^## / { exit }
    {
      line = $0
      gsub(/\*/, "", line)
      low = tolower(line)
      if (match(low, "^[-[:space:]]*" tolower(want) "[[:space:]]*:[[:space:]]*")) {
        v = substr(line, RSTART + RLENGTH)
        sub(/[[:space:]]+$/, "", v)
        print v
        exit
      }
    }' "$b"
}

# Which track a deliverable belongs to: b2b, b2c, both, or empty if unlisted.
lh_file_track() {
  case $1 in
    founder-brain.md|content-30.md|content-30.csv|rss-feeds.md|ops-workflow.md|ghl-values.md|90-day-plan.md|playbook-insert.md|playbook-insert.html|ledger.md|memory.md|ops-log.md|.launchhouse) printf both ;;
    outreach-sequence.md|outreach-firstlines.csv) printf b2b ;;
    dm-openers.md|hook-bank.md|inbound-scripts.md) printf b2c ;;
    content-30-[0-9][0-9][0-9][0-9]-[0-9][0-9].md|content-30-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9].md|content-30-[0-9][0-9][0-9][0-9]-[0-9][0-9].csv|content-30-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9].csv|playbook-insert.pdf) printf both ;;
    *) printf '' ;;
  esac
}

# Deliverables the rules read. Bookkeeping files and people are not judged.
# The text files in uploads/ and voice-samples/ are judged for the sending
# rules only (see lh_scope).
lh_is_judged() {
  case $1 in
    ledger.md|memory.md|ops-log.md|.launchhouse|*.pdf) return 1 ;;
    people/*|.state/*) return 1 ;;
    uploads/*.md|uploads/*.txt|uploads/*.csv|voice-samples/*.md|voice-samples/*.txt|voice-samples/*.csv) return 0 ;;
    uploads/*|voice-samples/*) return 1 ;;
    drafts/*) return 0 ;;
  esac
  [ -n "$(lh_file_track "$1")" ]
}

# How much of the rules a file gets. uploads/ and voice-samples/ hold the
# founder's own documents and writing, so only the two rules about messages
# that go out apply there: no cold DM automation and no promised replies. Their
# words, track and voice are never judged. Everything else gets every rule.
lh_scope() {
  case $1 in uploads/*|voice-samples/*) printf send ;; *) printf all ;; esac
}

# Findings for one file, as rules.awk prints them.
# $1 the file to read, $2 its path inside growth-engine, $3 the track.
lh_findings() {
  if [ "$(lh_scope "$2")" = send ]; then
    awk -v track= -v brain=0 -f "$(dirname "$0")/rules.awk" "$1" 2>/dev/null |
      awk -F '\t' '$1 == "HOLD" && ($3 == "dm.offered" || $3 == "prose.promise-reply")'
    return 0
  fi
  b=0; [ "$2" = founder-brain.md ] && b=1
  awk -v track="$3" -v brain="$b" -f "$(dirname "$0")/rules.awk" "$1" 2>/dev/null
}

# The findings for a file after a write, judged against its copy from before
# the write ($2, empty for a new file). A held line that was already there,
# word for word in full, is marked OLD instead of HOLD: it is left alone, and the
# founder is told, because it may be their own words. Only new or changed
# lines are held. $1 file, $2 earlier copy, $3 path inside growth-engine, $4 track.
#
# uploads/ and voice-samples/ hold the founder's own documents and writing, so
# nothing there is ever held, removed or put back: every finding is OLD.
lh_judge() {
  lh_keep=0; [ "$(lh_scope "$3")" = send ] && lh_keep=1
  lh_new=$(lh_findings "$1" "$3" "$4") || return 1
  lh_old=""
  if [ -n "$2" ] && [ -f "$2" ]; then lh_old=$(lh_findings "$2" "$3" "$4"); fi
  { printf '%s\n' "$lh_old" | awk -F '\t' -v OFS='\t' '$1 == "HOLD" { $1 = "OLDF"; print }'
    printf '%s\n' "$lh_new"; } | awk -F '\t' -v OFS='\t' -v keep="$lh_keep" '
    $1 == "OLDF" { seen[$3 FS $6] = 1; next }
    $1 == "HOLD" && (keep == 1 || ($3 FS $6) in seen) { $1 = "OLD" }
    NF { print }'
}

# The judged files under growth-engine/, one path per line, relative to it.
# Never lists people/ or .state/. Links are listed too, so a file swapped for a
# link is seen.
lh_judged_files() {
  ( cd "$(lh_root)/growth-engine" 2>/dev/null &&
    find . \( -path ./people -o -path ./.state \) -prune -o \( -type f -o -type l \) -print 2>/dev/null ) |
  sed 's|^\./||' | while IFS= read -r f; do
    lh_is_judged "$f" && printf '%s\n' "$f"
  done
  return 0
}

# A checksum line for each file named on stdin, read from folder $1.
lh_sums() {
  tr '\n' '\000' | ( cd "$1" 2>/dev/null && xargs -0 cksum 2>/dev/null )
  return 0
}

# True if the shell command $1 runs a git push whose remote is under
# Philm-moxywolf, the public original. The remote is the one named, or else the
# branch's own remote, or else origin. A remote only named elsewhere, such as an
# upstream, does not count.
lh_push_to_original() {
  printf '%s\n' "$1" | tr '\r;&|' '\n\n\n\n' | awk '
    { for (i = 1; i < NF; i++) if ($i == "git" || $i ~ /\/git$/) {
        for (j = i + 1; j <= NF && $j ~ /^-/; j++) if ($j == "-C" || $j == "-c") j++
        if ($j != "push") continue
        r = ""
        for (k = j + 1; k <= NF; k++) {
          if ($k ~ /^-/) { if ($k == "-o" || $k == "--push-option" || $k == "--repo") k++; continue }
          r = $k; break
        }
        print (r == "" ? "-" : r)
      } }' | while IFS= read -r r; do
    if [ "$r" = - ]; then
      b=$(git -C "$(lh_root)" symbolic-ref --short -q HEAD 2>/dev/null)
      r=$(git -C "$(lh_root)" config "branch.$b.remote" 2>/dev/null) || r=""
      [ -n "$r" ] || r=origin
    fi
    u=$(git -C "$(lh_root)" remote get-url --push "$r" 2>/dev/null) || u=$r
    case $(printf '%s' "$u" | LC_ALL=C tr 'A-Z' 'a-z') in *philm-moxywolf*) echo x ;; esac
  done | grep -q x
}

lh_deny_pre() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$(lh_json_escape "$1")"
  exit 0
}

# A short stable name for a path, used for the pre-write copy.
lh_key() {
  printf '%s' "$1" | cksum | awk '{ print $1 }'
}
