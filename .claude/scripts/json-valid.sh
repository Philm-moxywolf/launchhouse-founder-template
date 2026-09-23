#!/bin/sh
# A genuine JSON syntax checker: a real recursive-descent parser over the
# file's own bytes, never a brace count or a line-shape guess. This is the
# one thing every other safety check in this folder leans on to know
# .claude/settings.json -- the file that switches every safety hook on --
# is not simply broken JSON before it trusts anything it reads from it.
#
# Usage: sh .claude/scripts/json-valid.sh <file>
#   exit 0  the file is one syntactically valid JSON value, and nothing
#           else: object/array nesting, strings (with escapes, including
#           \uXXXX), numbers (with fractions and exponents), true/false/
#           null, no trailing commas, nothing after the top-level value.
#           A leading UTF-8 BOM and CRLF line endings are both tolerated.
#   exit 1  invalid, with a last line `reason=<plain sentence>`.
#
# POSIX sh + awk only, and the awk half is plain enough (no gawk-only
# extensions -- no gensub, no strtonum, no FUNCTAB, only %c in printf and
# the octal-escape/associative-array features every awk implementation
# already provides) to run the same way under gawk, mawk and BSD awk.

set -u

file=${1:-}
if [ -z "$file" ]; then
  printf 'reason=no file was given to check\n'
  exit 1
fi
if [ ! -f "$file" ] || [ ! -r "$file" ]; then
  printf 'reason=the file is missing or cannot be read: %s\n' "$file"
  exit 1
fi

LC_ALL=C awk '
BEGIN {
  # Every C0 control character (0x00-0x1F): a JSON string may only carry
  # one of these escaped, never literal.
  for (ci = 0; ci < 32; ci++) ctrl[sprintf("%c", ci)] = 1
}
{
  sub(/\r$/, "")
  buf = buf $0 "\n"
}
END {
  # A leading UTF-8 BOM (EF BB BF) is three ordinary bytes to awk; drop
  # them before parsing starts, same as a text editor would.
  if (substr(buf, 1, 3) == "\357\273\277") buf = substr(buf, 4)
  n = length(buf)
  pos = 1
  err = ""

  skipws()
  if (pos > n) {
    err = "the file has no content"
  } else {
    parseValue()
    if (err == "") {
      skipws()
      if (pos <= n) err = "there is content after the top-level JSON value"
    }
  }

  if (err == "") exit 0
  printf "reason=%s\n", err
  exit 1
}

function skipws(   c) {
  while (pos <= n) {
    c = substr(buf, pos, 1)
    if (c == " " || c == "\t" || c == "\n" || c == "\r") pos++
    else break
  }
}

function parseValue(   c) {
  if (err != "") return
  if (pos > n) { err = "an expected value is missing near the end of the file"; return }
  c = substr(buf, pos, 1)
  if (c == "\"") { parseString(); return }
  if (c == "{") { parseObject(); return }
  if (c == "[") { parseArray(); return }
  if (c == "-" || (c >= "0" && c <= "9")) { parseNumber(); return }
  if (substr(buf, pos, 4) == "true") { pos += 4; return }
  if (substr(buf, pos, 5) == "false") { pos += 5; return }
  if (substr(buf, pos, 4) == "null") { pos += 4; return }
  err = "an unexpected character sits where a value should start, near position " pos
}

function parseObject(   c) {
  pos++
  skipws()
  if (pos > n) { err = "an object is never closed with a }"; return }
  c = substr(buf, pos, 1)
  if (c == "}") { pos++; return }
  while (1) {
    skipws()
    if (pos > n) { err = "an object is never closed with a }"; return }
    c = substr(buf, pos, 1)
    if (c != "\"") { err = "an object key must be a quoted string, near position " pos; return }
    parseString()
    if (err != "") return
    skipws()
    if (pos > n || substr(buf, pos, 1) != ":") { err = "an object key is missing its :, near position " pos; return }
    pos++
    skipws()
    parseValue()
    if (err != "") return
    skipws()
    if (pos > n) { err = "an object is never closed with a }"; return }
    c = substr(buf, pos, 1)
    if (c == ",") {
      pos++
      skipws()
      if (pos <= n && substr(buf, pos, 1) == "}") { err = "a trailing comma sits before a }, near position " pos; return }
      continue
    } else if (c == "}") {
      pos++
      return
    } else {
      err = "an object is missing a , or a }, near position " pos
      return
    }
  }
}

function parseArray(   c) {
  pos++
  skipws()
  if (pos > n) { err = "an array is never closed with a ]"; return }
  c = substr(buf, pos, 1)
  if (c == "]") { pos++; return }
  while (1) {
    skipws()
    parseValue()
    if (err != "") return
    skipws()
    if (pos > n) { err = "an array is never closed with a ]"; return }
    c = substr(buf, pos, 1)
    if (c == ",") {
      pos++
      skipws()
      if (pos <= n && substr(buf, pos, 1) == "]") { err = "a trailing comma sits before a ], near position " pos; return }
      continue
    } else if (c == "]") {
      pos++
      return
    } else {
      err = "an array is missing a , or a ], near position " pos
      return
    }
  }
}

function parseString(   c, hex) {
  pos++
  while (1) {
    if (pos > n) { err = "a string is never closed with a matching quote"; return }
    c = substr(buf, pos, 1)
    if (c == "\"") { pos++; return }
    if (c == "\\") {
      pos++
      if (pos > n) { err = "a string ends in the middle of an escape sequence"; return }
      c = substr(buf, pos, 1)
      if (c == "\"" || c == "\\" || c == "/" || c == "b" || c == "f" || c == "n" || c == "r" || c == "t") {
        pos++
        continue
      }
      if (c == "u") {
        hex = substr(buf, pos + 1, 4)
        if (length(hex) != 4 || hex !~ /^[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]$/) {
          err = "a \\u escape in a string is not four hex digits, near position " pos
          return
        }
        pos += 5
        continue
      }
      err = "a string carries an escape sequence that is not one JSON allows, near position " pos
      return
    }
    if (c in ctrl) { err = "a string carries a raw control character that must be escaped, near position " pos; return }
    pos++
  }
}

function parseNumber(   c, start, hasdigit) {
  start = pos
  if (substr(buf, pos, 1) == "-") pos++
  if (pos > n) { err = "a number is cut off, near position " start; return }
  c = substr(buf, pos, 1)
  if (c == "0") {
    pos++
  } else if (c >= "1" && c <= "9") {
    pos++
    while (pos <= n) {
      c = substr(buf, pos, 1)
      if (c >= "0" && c <= "9") pos++
      else break
    }
  } else {
    err = "an invalid number starts near position " start
    return
  }
  if (pos <= n && substr(buf, pos, 1) == ".") {
    pos++
    hasdigit = 0
    while (pos <= n) {
      c = substr(buf, pos, 1)
      if (c >= "0" && c <= "9") { pos++; hasdigit = 1 }
      else break
    }
    if (!hasdigit) { err = "a number is missing digits after its ., near position " start; return }
  }
  if (pos <= n) {
    c = substr(buf, pos, 1)
    if (c == "e" || c == "E") {
      pos++
      if (pos <= n) {
        c = substr(buf, pos, 1)
        if (c == "+" || c == "-") pos++
      }
      hasdigit = 0
      while (pos <= n) {
        c = substr(buf, pos, 1)
        if (c >= "0" && c <= "9") { pos++; hasdigit = 1 }
        else break
      }
      if (!hasdigit) { err = "a number is missing digits in its exponent, near position " start; return }
    }
  }
}
' "$file"
