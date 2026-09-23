#!/bin/sh
# Flattens a JSON file into path<TAB>value lines, one per string/number/
# boolean/null leaf, so a check can read a JSON document by its actual
# content -- key names and values -- and never by how it happens to be
# laid out on disk. Indentation, line breaks, key order, CRLF endings, a
# compact one-line file, all read identically: they are not what a
# founder's own edits or a jq re-format change, so a check keyed on them
# would fail on shape alone, never on meaning.
#
# This is the same recursive-descent walk connector-safety-routing.check.sh
# used to carry inline: factored out here so every check that reads
# .claude/settings.json (or any other JSON file) by content shares one
# flattener, rather than each keeping its own copy to drift out of sync.
#
# Usage: sh .claude/scripts/json-flat.sh <file>
#   exit 0  one line per leaf, `path<TAB>value`, to stdout. path starts
#           with / for the top-level container's own children (an object
#           key or an array index); a key that itself contains a literal
#           "/" or "\" is escaped (\/ and \\) before it is joined into the
#           path, so a key named "hooks/PreToolUse/0/matcher" can never be
#           read back as the nested path /hooks/PreToolUse/0/matcher.
#           true/false/null leaves flatten to the literal strings "true",
#           "false" and "null"; a number leaf flattens to its own digits,
#           unchanged. A leaf that is itself the whole document (the file
#           is just "true", or just a bare string) flattens to path "".
#   exit 1  the file is not valid JSON (checked with json-valid.sh first):
#           nothing is printed to stdout, and a last line `reason=<why>`
#           goes to stdout, same wording json-valid.sh itself reports.
#
# POSIX sh + awk only, and the awk half runs the same way under gawk, mawk
# and BSD awk (no gawk-only extensions).

set -u

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
file=${1:-}

if [ -z "$file" ]; then
  printf 'reason=no file was given to flatten\n'
  exit 1
fi
if [ ! -f "$file" ] || [ ! -r "$file" ]; then
  printf 'reason=the file is missing or cannot be read: %s\n' "$file"
  exit 1
fi

validator="$here/json-valid.sh"
if [ ! -f "$validator" ]; then
  printf 'reason=the JSON validator is missing: %s\n' "$validator"
  exit 1
fi
if ! jv_out=$(sh "$validator" "$file" 2>&1); then
  printf '%s\n' "$jv_out" | grep '^reason=' || printf 'reason=%s is not valid JSON\n' "$file"
  exit 1
fi

LC_ALL=C awk '
{
  sub(/\r$/, "")
  buf = buf $0 "\n"
}
END {
  if (substr(buf, 1, 3) == "\357\273\277") buf = substr(buf, 4)
  n = length(buf)
  pos = 1
  ok = 1
  leaf_is_scalar = 0
  parseValue("")
  if (leaf_is_scalar) {
    printf "%s\t%s\n", "", leaf[""]
  } else {
    for (p in leaf) printf "%s\t%s\n", p, leaf[p]
  }
}

function skipws(   c) {
  while (pos <= n) {
    c = substr(buf, pos, 1)
    if (c == " " || c == "\t" || c == "\n" || c == "\r") pos++
    else break
  }
}

function parseValue(path,   c, start) {
  if (!ok) return
  if (pos > n) { ok = 0; return }
  c = substr(buf, pos, 1)
  if (c == "\"") { parseString(); setleaf(path, strval); return }
  if (c == "{") { parseObject(path); return }
  if (c == "[") { parseArray(path); return }
  if (c == "-" || (c >= "0" && c <= "9")) { start = pos; skipNumber(); setleaf(path, substr(buf, start, pos - start)); return }
  if (substr(buf, pos, 4) == "true") { pos += 4; setleaf(path, "true"); return }
  if (substr(buf, pos, 5) == "false") { pos += 5; setleaf(path, "false"); return }
  if (substr(buf, pos, 4) == "null") { pos += 4; setleaf(path, "null"); return }
  ok = 0
}

function setleaf(path, val) {
  leaf[path] = val
  if (path == "") leaf_is_scalar = 1
}

function parseObject(path,   c, key) {
  pos++
  skipws()
  if (pos > n) { ok = 0; return }
  if (substr(buf, pos, 1) == "}") { pos++; return }
  while (ok) {
    skipws()
    if (pos > n || substr(buf, pos, 1) != "\"") { ok = 0; return }
    parseString()
    key = strval
    # A key own string value can legitimately contain "/" or "\" -- escape
    # both (the escape character first, so the escaping stays reversible
    # and unambiguous) before the key is ever joined into a flattened
    # path, so a literal "/" from the key name itself can never be
    # mistaken for the "/" this flattener inserts as a path separator. See
    # the module comment above for the spoofing this closes.
    gsub(/\\/, "\\\\", key)
    gsub(/\//, "\\/", key)
    skipws()
    if (pos > n || substr(buf, pos, 1) != ":") { ok = 0; return }
    pos++
    skipws()
    parseValue(path "/" key)
    if (!ok) return
    skipws()
    if (pos > n) { ok = 0; return }
    c = substr(buf, pos, 1)
    if (c == ",") { pos++; continue }
    if (c == "}") { pos++; return }
    ok = 0
    return
  }
}

function parseArray(path,   c, idx) {
  pos++
  skipws()
  if (pos > n) { ok = 0; return }
  if (substr(buf, pos, 1) == "]") { pos++; return }
  idx = 0
  while (ok) {
    skipws()
    parseValue(path "/" idx)
    if (!ok) return
    idx++
    skipws()
    if (pos > n) { ok = 0; return }
    c = substr(buf, pos, 1)
    if (c == ",") { pos++; continue }
    if (c == "]") { pos++; return }
    ok = 0
    return
  }
}

function parseString(   c, hex, out) {
  pos++
  out = ""
  while (1) {
    if (pos > n) { ok = 0; strval = out; return }
    c = substr(buf, pos, 1)
    if (c == "\"") { pos++; strval = out; return }
    if (c == "\\") {
      pos++
      if (pos > n) { ok = 0; strval = out; return }
      c = substr(buf, pos, 1)
      if (c == "\"" || c == "\\" || c == "/") { out = out c; pos++; continue }
      if (c == "b") { out = out "\b"; pos++; continue }
      if (c == "f") { out = out "\f"; pos++; continue }
      if (c == "n") { out = out "\n"; pos++; continue }
      if (c == "r") { out = out "\r"; pos++; continue }
      if (c == "t") { out = out "\t"; pos++; continue }
      if (c == "u") {
        hex = substr(buf, pos + 1, 4)
        out = out "?"
        pos += 5
        continue
      }
      ok = 0; strval = out; return
    }
    out = out c
    pos++
  }
}

function skipNumber(   c) {
  if (substr(buf, pos, 1) == "-") pos++
  while (pos <= n) {
    c = substr(buf, pos, 1)
    if ((c >= "0" && c <= "9") || c == "." || c == "e" || c == "E" || c == "+" || c == "-") pos++
    else break
  }
}
' "$file"
