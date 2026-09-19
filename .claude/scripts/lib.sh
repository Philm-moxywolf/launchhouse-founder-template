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

# Every Launchhouse folder near the opened one, one per line. Also names the
# real folder when the opened one is a Desktop copies folder (it carries the
# .launchhouse-copies marker desktop-copy.sh writes), so opening that folder
# by mistake gets the same one-sentence redirect as opening any other wrong
# folder.
lh_near_all() {
  r=$(lh_root)
  {
    if [ -f "$r/.launchhouse-copies" ]; then
      tr -d '\r\n' < "$r/.launchhouse-copies" 2>/dev/null
      printf '\n'
    fi
    for cand in "$r"/*/growth-engine/.launchhouse "$r/../growth-engine/.launchhouse" "${HOME:-/nonexistent}/growth-engine/.launchhouse"; do
      [ -f "$cand" ] && (cd "$(dirname "$cand")/.." 2>/dev/null && pwd)
    done
  } | awk '!seen[$0]++ && $0 != ""'
  return 0
}

# The bookkeeping folder for the Desktop copies feature: .git/launchhouse/ (or
# the worktree's own git folder, followed properly if .git is a file), never
# under growth-engine/, never committed, never part of the gate-state stamp.
# Resolved straight off disk, no git process, so reading it (state-block.sh,
# on every message) never spawns one. Falls back to asking git itself only if
# the on-disk layout cannot be followed by hand.
lh_gitdir_raw() {
  r=$(lh_root)
  g="$r/.git"
  if [ -f "$g" ]; then
    gd=$(sed -n 's/^gitdir: *//p' "$g" | tr -d '\r\n')
    case $gd in
      /*|[A-Za-z]:*) printf '%s' "$gd" ;;
      *) (cd "$r" 2>/dev/null && cd "$gd" 2>/dev/null && pwd) ;;
    esac
  elif [ -d "$g" ]; then
    printf '%s' "$g"
  fi
}

lh_bk_dir() {
  gd=$(lh_gitdir_raw)
  [ -n "$gd" ] && [ -d "$gd" ] || gd=$(git -C "$(lh_root)" rev-parse --absolute-git-dir 2>/dev/null)
  [ -n "$gd" ] && printf '%s/launchhouse' "$gd"
}

# A cheap fingerprint of HEAD, read straight off disk with no git process: the
# content of HEAD plus whatever ref file or packed-refs line it names. It
# changes exactly when the commit HEAD points at changes (a save, a pull, a
# merge, a subagent commit), and nothing else. Empty when it cannot be read,
# which the caller treats as "something may have changed" rather than risk
# going stale silently.
lh_head_fingerprint() {
  gd=$(lh_gitdir_raw) || return 1
  [ -n "$gd" ] && [ -f "$gd/HEAD" ] || return 1
  h=$(cat "$gd/HEAD" 2>/dev/null)
  case $h in
    ref:*)
      ref=$(printf '%s' "${h#ref: }" | tr -d ' \t\r\n')
      cdir=$gd
      if [ -f "$gd/commondir" ]; then
        cd_rel=$(cat "$gd/commondir" 2>/dev/null | tr -d '\r\n')
        case $cd_rel in
          /*|[A-Za-z]:*) cdir=$cd_rel ;;
          *) cdir=$(cd "$gd" 2>/dev/null && cd "$cd_rel" 2>/dev/null && pwd) ;;
        esac
      fi
      if [ -f "$gd/$ref" ]; then
        cat "$gd/HEAD" "$gd/$ref" 2>/dev/null | cksum
      elif [ -n "$cdir" ] && [ -f "$cdir/$ref" ]; then
        cat "$gd/HEAD" "$cdir/$ref" 2>/dev/null | cksum
      elif [ -n "$cdir" ] && [ -f "$cdir/packed-refs" ]; then
        { cat "$gd/HEAD"; grep -F " $ref" "$cdir/packed-refs" 2>/dev/null; } | cksum
      else
        cat "$gd/HEAD" 2>/dev/null | cksum
      fi ;;
    *) printf '%s' "$h" | cksum ;;
  esac
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

# The raw, unparsed text of one top-level key's value from a JSON object —
# whatever shape it is, object, array, string or bare scalar, copied
# character for character. Used to pull tool_input out of the hook's stdin
# envelope before anything else touches it, so a value elsewhere in the
# envelope (cwd, transcript_path, the rest) never has a chance to be
# classified. Exits non-zero if $2 is not an object, the key is not found at
# the top level, or the JSON cannot be made sense of.
lh_json_get_raw() {
  printf '%s' "$2" | LC_ALL=C awk -v key="$1" '
    BEGIN { RS = "\001" }
    function skip_ws() {
      while (i <= n) {
        c = substr(s, i, 1)
        if (c == " " || c == "\t" || c == "\n" || c == "\r") i++
        else break
      }
    }
    function parse_string(   c, out) {
      i++
      out = ""
      while (i <= n) {
        c = substr(s, i, 1)
        if (c == "\\") {
          if (i + 1 > n) { err = 1; return out }
          i += 2
          continue
        }
        if (c == "\"") { i++; return out }
        out = out c
        i++
      }
      err = 1
      return out
    }
    function skip_container(openc, closec,   depth, c, instr, esc) {
      depth = 0; instr = 0; esc = 0
      while (i <= n) {
        c = substr(s, i, 1)
        if (instr) {
          if (esc) esc = 0
          else if (c == "\\") esc = 1
          else if (c == "\"") instr = 0
          i++
          continue
        }
        if (c == "\"") { instr = 1; i++; continue }
        if (c == openc) depth++
        else if (c == closec) { depth--; if (depth == 0) { i++; return } }
        i++
      }
      err = 1
    }
    function skip_value(   c) {
      skip_ws()
      if (i > n) { err = 1; return }
      c = substr(s, i, 1)
      if (c == "{") skip_container("{", "}")
      else if (c == "[") skip_container("[", "]")
      else if (c == "\"") parse_string()
      else {
        while (i <= n) {
          c = substr(s, i, 1)
          if (c == "," || c == "}" || c == "]" || c == " " || c == "\t" || c == "\n" || c == "\r") break
          i++
        }
      }
    }
    {
      s = $0; n = length(s); i = 1; err = 0
      skip_ws()
      if (i > n || substr(s, i, 1) != "{") exit 1
      i++
      skip_ws()
      if (i > n) exit 1
      if (substr(s, i, 1) == "}") exit 1
      for (;;) {
        skip_ws()
        if (i > n || substr(s, i, 1) != "\"") exit 1
        k = parse_string()
        if (err) exit 1
        skip_ws()
        if (i > n || substr(s, i, 1) != ":") exit 1
        i++
        skip_ws()
        vstart = i
        skip_value()
        if (err) exit 1
        vend = i - 1
        if (k == key) { printf "%s", substr(s, vstart, vend - vstart + 1); exit 0 }
        skip_ws()
        if (i > n) exit 1
        c = substr(s, i, 1)
        if (c == ",") { i++; continue }
        if (c == "}") exit 1
        exit 1
      }
    }
  '
}

# Every scalar leaf of a JSON value (object, array or bare scalar), as
# path<TAB>value lines: one line per string, number, true, false or null,
# never for an object or array itself. The path is the key names walked to
# reach it, joined with ".", with "[N]" appended for an array step (the
# number is just which step, not a meaningful index). Handles nesting of any
# depth and the escapes a JSON string can carry (\", \\, \n and the rest),
# the same way lh_json_get does, except an escaped newline, tab or return
# becomes a plain space, so a leaf's value can never break the
# one-line-per-leaf output. Exits non-zero, printing nothing that can be
# trusted, on anything that is not valid JSON — trailing garbage after the
# value included.
#
# ghl-op.sh uses this to walk tool_input and classify only the operation
# descriptor, never the payload text a founder typed into a post or message.
lh_json_leaves() {
  printf '%s' "$1" | LC_ALL=C awk '
    BEGIN { RS = "\001" }
    function skip_ws() {
      while (i <= n) {
        c = substr(s, i, 1)
        if (c == " " || c == "\t" || c == "\n" || c == "\r") i++
        else break
      }
    }
    # Turns a four character hex string into its decimal value, digit by
    # digit, with no dependence on a gawk-only builtin such as strtonum.
    function hex2dec(hx,   j, ch, v, digits) {
      digits = "0123456789abcdef"
      v = 0
      hx = tolower(hx)
      for (j = 1; j <= length(hx); j++) {
        ch = substr(hx, j, 1)
        v = v * 16 + index(digits, ch) - 1
      }
      return v
    }
    function parse_string(   c, out, d, hx, cp) {
      i++
      out = ""
      while (i <= n) {
        c = substr(s, i, 1)
        if (c == "\\") {
          if (i + 1 > n) { err = 1; return out }
          d = substr(s, i + 1, 1)
          if (d == "n" || d == "t" || d == "r" || d == "b" || d == "f") out = out " "
          else if (d == "u") {
            hx = substr(s, i + 2, 4)
            if (length(hx) != 4 || hx !~ /^[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$/) { err = 1; return out }
            cp = hex2dec(hx)
            # ASCII range decodes to the plain character it names; anything
            # above it becomes a marker instead of a guess, so the caller
            # can tell a descriptor leaf it cannot safely normalise apart
            # from one it can, rather than silently mangling either.
            if (cp <= 127) out = out sprintf("%c", cp)
            else out = out "UNIESCNONASCII"
            i += 4
          }
          else out = out d
          i += 2
          continue
        }
        if (c == "\"") { i++; return out }
        out = out c
        i++
      }
      err = 1
      return out
    }
    function parse_literal(   c, out) {
      out = ""
      while (i <= n) {
        c = substr(s, i, 1)
        if (c == "," || c == "}" || c == "]" || c == " " || c == "\t" || c == "\n" || c == "\r") break
        out = out c
        i++
      }
      if (out == "") err = 1
      return out
    }
    function parse_value(path,   c, v) {
      skip_ws()
      if (i > n) { err = 1; return }
      c = substr(s, i, 1)
      if (c == "{") parse_object(path)
      else if (c == "[") parse_array(path)
      else if (c == "\"") { v = parse_string(); if (!err) print path "\t" v }
      else { v = parse_literal(); if (!err) print path "\t" v }
    }
    function parse_object(path,   key, newpath, c) {
      i++
      skip_ws()
      if (i > n) { err = 1; return }
      if (substr(s, i, 1) == "}") { i++; return }
      for (;;) {
        skip_ws()
        if (i > n || substr(s, i, 1) != "\"") { err = 1; return }
        key = parse_string()
        if (err) return
        skip_ws()
        if (i > n || substr(s, i, 1) != ":") { err = 1; return }
        i++
        newpath = (path == "" ? key : path "." key)
        parse_value(newpath)
        if (err) return
        skip_ws()
        if (i > n) { err = 1; return }
        c = substr(s, i, 1)
        if (c == ",") { i++; continue }
        if (c == "}") { i++; return }
        err = 1; return
      }
    }
    function parse_array(path,   idx, newpath, c) {
      i++
      skip_ws()
      if (i > n) { err = 1; return }
      if (substr(s, i, 1) == "]") { i++; return }
      idx = 0
      for (;;) {
        newpath = path "[" idx "]"
        parse_value(newpath)
        if (err) return
        idx++
        skip_ws()
        if (i > n) { err = 1; return }
        c = substr(s, i, 1)
        if (c == ",") { i++; continue }
        if (c == "]") { i++; return }
        err = 1; return
      }
    }
    {
      s = $0; n = length(s); i = 1; err = 0
      parse_value("")
      if (!err) {
        skip_ws()
        if (i <= n) err = 1
      }
      if (err) exit 1
    }
  '
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

# Where each Launchhouse file lives inside growth-engine/, by its name. This is
# the file table in .claude/references/contract.md, and a test checks the two
# agree. Empty for a name that is not one of ours.
lh_place() {
  case $1 in
    founder-brain.md) printf 'brain/%s' "$1" ;;
    content-30.md|content-30.csv|rss-feeds.md|\
    content-30-[0-9][0-9][0-9][0-9]-[0-9][0-9].md|content-30-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9].md|\
    content-30-[0-9][0-9][0-9][0-9]-[0-9][0-9].csv|content-30-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9].csv) printf 'engines/content/%s' "$1" ;;
    outreach-sequence.md|outreach-firstlines.csv) printf 'engines/outreach/%s' "$1" ;;
    dm-openers.md|hook-bank.md|inbound-scripts.md) printf 'engines/audience/%s' "$1" ;;
    ops-workflow.md|ghl-values.md) printf 'engines/ops/%s' "$1" ;;
    90-day-plan.md) printf 'engines/plan/%s' "$1" ;;
    playbook-insert.md|playbook-insert.html|playbook-insert.pdf) printf 'export/%s' "$1" ;;
    ledger.md|memory.md|ops-log.md) printf 'log/%s' "$1" ;;
    .launchhouse) printf '%s' "$1" ;;
  esac
}

# Where each Launchhouse folder lives inside growth-engine/, by its old name.
lh_dir_place() {
  case $1 in
    uploads) printf 'inbox/uploads' ;;
    voice-samples) printf 'brain/voice-samples' ;;
  esac
}

# The Track line from the Founder Brain header, lower case, or empty.
lh_track() {
  b="$(lh_root)/growth-engine/brain/founder-brain.md"
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
  b="$(lh_root)/growth-engine/brain/founder-brain.md"
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

# Which track a Launchhouse file belongs to, by its name alone: b2b, b2c, both,
# or empty if it is not one of ours.
lh_base_track() {
  case $1 in
    outreach-sequence.md|outreach-firstlines.csv) printf b2b ;;
    dm-openers.md|hook-bank.md|inbound-scripts.md) printf b2c ;;
    *) [ -n "$(lh_place "$1")" ] && printf both ;;
  esac
  return 0
}

# Which track a deliverable belongs to, by its path inside growth-engine/: b2b,
# b2c, both, or empty if that path is not where one of ours lives.
lh_file_track() {
  [ -n "$1" ] && [ "$(lh_place "${1##*/}")" = "$1" ] && lh_base_track "${1##*/}"
  return 0
}

# Deliverables the rules read. Bookkeeping files and people are not judged.
# The text files in inbox/uploads/ and brain/voice-samples/ are judged for the
# sending rules only (see lh_scope).
lh_is_judged() {
  case $1 in
    log/ledger.md|log/memory.md|log/ops-log.md|.launchhouse|*.pdf) return 1 ;;
    people/*|.state/*) return 1 ;;
    inbox/uploads/*.md|inbox/uploads/*.txt|inbox/uploads/*.csv|brain/voice-samples/*.md|brain/voice-samples/*.txt|brain/voice-samples/*.csv) return 0 ;;
    inbox/uploads/*|brain/voice-samples/*) return 1 ;;
    drafts/*) return 0 ;;
  esac
  [ -n "$(lh_file_track "$1")" ]
}

# How much of the rules a file gets. inbox/uploads/ and brain/voice-samples/
# hold the founder's own documents and writing, so only the two rules about
# messages that go out apply there: no cold DM automation and no promised
# replies. Their words, track and voice are never judged. Everything else gets
# every rule.
lh_scope() {
  case $1 in inbox/uploads/*|brain/voice-samples/*) printf send ;; *) printf all ;; esac
}

# Findings for one file, as rules.awk prints them.
# $1 the file to read, $2 its path inside growth-engine, $3 the track.
lh_findings() {
  if [ "$(lh_scope "$2")" = send ]; then
    awk -v track= -v brain=0 -f "$(dirname "$0")/rules.awk" "$1" 2>/dev/null |
      awk -F '\t' '$1 == "HOLD" && ($3 == "dm.offered" || $3 == "prose.promise-reply")'
    return 0
  fi
  b=0; [ "$2" = brain/founder-brain.md ] && b=1
  awk -v track="$3" -v brain="$b" -f "$(dirname "$0")/rules.awk" "$1" 2>/dev/null
}

# The findings for a file after a write, judged against its copy from before
# the write ($2, empty for a new file). A held line that was already there,
# word for word in full, is marked OLD instead of HOLD: it is left alone, and the
# founder is told, because it may be their own words. Only new or changed
# lines are held. $1 file, $2 earlier copy, $3 path inside growth-engine, $4 track.
#
# inbox/uploads/ and brain/voice-samples/ hold the founder's own documents and
# writing, so nothing there is ever held, removed or put back: every finding is OLD.
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

# Same shape as lh_deny_pre, but asks the founder instead of refusing
# outright. Used where a tool can do something ordinary or something that
# needs a yes, and the hook cannot always tell which from the tool name alone.
lh_ask_pre() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$(lh_json_escape "$1")"
  exit 0
}

# The third outcome: neither deny nor ask, just a note added to Claude's own
# context for the call, with no permissionDecision key at all (so it reads
# the same as staying silent to Claude Code itself, on any build old or new
# — the tool call runs through the session's own permission mode exactly as
# it would with no hook here). Used for every tool whose name signals a side
# effect but is not one of the small deny or ask sets: mcp-guard.sh calls
# this "guide".
lh_guide_pre() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"%s"}}\n' "$(lh_json_escape "$1")"
  exit 0
}

# The mode-aware sentence a guide note ends with, built from the
# permission_mode the hook input carries (empty or unrecognised falls to the
# same wording as auto/dontAsk/bypassPermissions, the cautious assumption).
lh_mode_note() {
  case $1 in
    default|acceptEdits|plan) printf 'The founder will also see a permission prompt.' ;;
    *) printf 'No prompt will appear in this mode, so the founder'"'"'s yes in chat is the only check.' ;;
  esac
}

# Flattens raw text, tool name and tool input together, JSON and all, into one
# lower case, space separated line. JSON's own punctuation and the separators
# a name is written with (-, _, ., /, :) become spaces, and so does a
# camelCase boundary (sendMessage -> send message), all done before the text
# is lower cased so the boundary is still visible.
#
# ghl-op.sh needs this because lh_json_get only ever reads the first flat
# string match for one key, which is easy to steer around by nesting the
# thing it is looking for ({"operation":{"id":"contacts_delete-contact"}}).
# Flattening the whole input and matching word lists on the result, with a
# space on each side of every word so a match is a whole word or phrase and
# never a bare substring, works whatever shape the input arrives in.
lh_ghl_flatten() {
  printf '%s' "$1" | LC_ALL=C awk '
    BEGIN { RS = "\001" }
    {
      s = $0; n = length(s); out = ""
      for (i = 1; i <= n; i++) {
        c = substr(s, i, 1)
        if (i > 1) {
          p = substr(s, i - 1, 1)
          if (p ~ /[a-z0-9]/ && c ~ /[A-Z]/) out = out " "
        }
        out = out c
      }
      # A second pass over that result splits an acronym run from the
      # titlecase word right after it (HTTPMethod -> HTTP Method,
      # APIKeys -> API Keys, XMLParser -> XML Parser): wherever an upper
      # case letter is itself preceded by an upper case letter and
      # followed by a lower case one, the boundary sits right before it,
      # so the space goes there, before the last upper case letter of the
      # run. This runs before the text is lower cased, same as the first
      # pass, because both need to still see the casing to find it.
      n2 = length(out); out2 = ""
      for (i = 1; i <= n2; i++) {
        c = substr(out, i, 1)
        if (i > 1 && i < n2) {
          p = substr(out, i - 1, 1)
          nx = substr(out, i + 1, 1)
          if (p ~ /[A-Z]/ && c ~ /[A-Z]/ && nx ~ /[a-z]/) out2 = out2 " "
        }
        out2 = out2 c
      }
      out = out2
      s = tolower(out)
      gsub(/\{/, " ", s); gsub(/\}/, " ", s); gsub(/\[/, " ", s); gsub(/\]/, " ", s)
      gsub(/"/, " ", s);  gsub(/,/, " ", s);  gsub(/\(/, " ", s); gsub(/\)/, " ", s)
      gsub(/\\/, " ", s); gsub(/_/, " ", s);  gsub(/\./, " ", s); gsub(/\//, " ", s)
      gsub(/:/, " ", s);  gsub(/=/, " ", s);  gsub(/</, " ", s);  gsub(/>/, " ", s)
      gsub(/\|/, " ", s); gsub(/;/, " ", s);  gsub(/\+/, " ", s); gsub(/\*/, " ", s)
      gsub(/\?/, " ", s); gsub(/#/, " ", s);  gsub(/@/, " ", s);  gsub(/%/, " ", s)
      gsub(/\^/, " ", s); gsub(/&/, " ", s);  gsub(/~/, " ", s);  gsub(/`/, " ", s)
      gsub(/!/, " ", s);  gsub(/-/, " ", s)
      gsub(/[ \t\r\n]+/, " ", s)
      gsub(/^ +| +$/, "", s)
      printf "%s", s
    }'
}

# Decodes a raw JSON string value, quotes and all, the way lh_json_get_raw
# hands one back: backslash escapes are resolved properly, including \uXXXX,
# which is decoded to the real character when it names one in the ASCII
# range and left as a literal marker (UNIESCNONASCII) otherwise, the same
# convention lh_json_leaves uses. Never called as $(...) by its caller,
# because that would run it in a subshell and lose the flag below: it sets
# two globals instead, lh_unescape_result (the decoded text) and
# lh_unescape_nonascii (1 whenever that marker appears anywhere in the
# result), so a caller that cannot trust a name it could not fully read (a
# tool name hiding a word behind a \u escape outside ASCII, say) can tell
# doubt apart from a plain decode. A value that is not a quoted JSON string
# (missing key, a number, an object) leaves lh_unescape_result empty and
# lh_unescape_nonascii at 0.
lh_unescape_json_string() {
  lh_unescape_nonascii=0
  lh_unescape_result=$(printf '%s' "$1" | LC_ALL=C awk '
    BEGIN { RS = "\001" }
    function hex2dec(hx,   j, ch, v, digits) {
      digits = "0123456789abcdef"
      v = 0
      hx = tolower(hx)
      for (j = 1; j <= length(hx); j++) {
        ch = substr(hx, j, 1)
        v = v * 16 + index(digits, ch) - 1
      }
      return v
    }
    {
      s = $0; n = length(s)
      if (n < 2 || substr(s, 1, 1) != "\"" || substr(s, n, 1) != "\"") { exit 1 }
      i = 2; out = ""
      while (i < n) {
        c = substr(s, i, 1)
        if (c == "\\") {
          d = substr(s, i + 1, 1)
          if (d == "n") out = out "\n"
          else if (d == "t") out = out "\t"
          else if (d == "r") out = out "\r"
          else if (d == "b" || d == "f") out = out " "
          else if (d == "u") {
            hx = substr(s, i + 2, 4)
            if (length(hx) != 4 || hx !~ /^[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$/) { exit 1 }
            cp = hex2dec(hx)
            if (cp <= 127) out = out sprintf("%c", cp)
            else out = out "UNIESCNONASCII"
            i += 4
          }
          else out = out d
          i += 2
          continue
        }
        out = out c
        i++
      }
      printf "%s", out
    }') || { lh_unescape_result=""; return 1; }
  case $lh_unescape_result in *UNIESCNONASCII*) lh_unescape_nonascii=1 ;; esac
  return 0
}

# A short stable name for a path, used for the pre-write copy.
lh_key() {
  printf '%s' "$1" | cksum | awk '{ print $1 }'
}
