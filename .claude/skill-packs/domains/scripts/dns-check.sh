#!/bin/sh
# Checks a domain's public DNS for the records this project's founders care
# about: mail delivery and authentication (MX, SPF, DKIM, DMARC), Apollo's
# tracking subdomain, GoHighLevel's LC Email sending subdomain, Resend's
# verification records, and a plain website (A/AAAA/CNAME on apex and www).
#
# POSIX sh. No jq, no node, no python. Reads DNS over HTTPS with curl
# (Cloudflare first, Google as a fallback), and parses the small JSON it gets
# back with awk/sed only. Works the same on macOS and Git Bash.
#
# Usage:
#   sh .claude/skill-packs/domains/scripts/dns-check.sh <domain> [--mailbox google|microsoft|other]
#     [--apollo-tracking <host>] [--ghl-sending <sub>] [--resend]
#     [--json] [--record]
#
# --record additionally writes growth-engine/.state/domain.md: counts-only
# pass/warn/fail per check, the domain name, and the date. No DNS record
# values or any other detail go into that file.
#
# Never writes anything except that one file, and only with --record.
#
# Offline testing: with LH_DNS_TESTING=1 and LH_DNS_FIXTURE_DIR set to a
# folder of canned DoH JSON responses, no network call is made. Fixture files
# are named "<queried name>__<TYPE>.json", for example
# "example.com__MX.json" or "_dmarc.example.com__TXT.json". A missing fixture
# file is treated as an empty answer (Status 0, no Answer array), the same as
# a real NXDOMAIN-shaped "record not there yet" response.

domain=""
mailbox=""
apollo_tracking=""
ghl_sending=""
want_resend=0
want_json=0
want_record=0

while [ $# -gt 0 ]; do
  case "$1" in
    --mailbox) mailbox=$2; shift 2 ;;
    --apollo-tracking) apollo_tracking=$2; shift 2 ;;
    --ghl-sending) ghl_sending=$2; shift 2 ;;
    --resend) want_resend=1; shift ;;
    --json) want_json=1; shift ;;
    --record) want_record=1; shift ;;
    -*) printf 'Unknown flag: %s\n' "$1" >&2; exit 2 ;;
    *) domain=$1; shift ;;
  esac
done

if [ -z "$domain" ]; then
  printf 'Usage: sh dns-check.sh <domain> [--mailbox google|microsoft|other] [--apollo-tracking <host>] [--ghl-sending <sub>] [--resend] [--json] [--record]\n' >&2
  exit 2
fi

# ---------------------------------------------------------- domain validation
# A literal newline, used below to reject one embedded in the domain
# argument before it ever reaches a command or a path. $(printf '\n') would
# not work here: command substitution strips the trailing newline it prints,
# leaving nothing to compare against.
lh_dc_nl='
'

# True (exit 0) only if $1 is a proper DNS hostname: letters, digits and
# hyphens in each label, labels joined by single dots, no label starting or
# ending with a hyphen, no empty label, 1-63 characters per label, 1-253
# characters total. Rejects everything else outright, including embedded
# whitespace, newlines and pipe characters, before the domain is used in any
# command or path.
lh_valid_hostname() { # domain
  hn=$1
  case "$hn" in *"$lh_dc_nl"*) return 1 ;; esac
  case "$hn" in *'|'*) return 1 ;; esac
  printf '%s' "$hn" | awk '
    {
      d = tolower($0)
      if (length(d) < 1 || length(d) > 253) exit 1
      if (d !~ /^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$/) exit 1
      n = split(d, labels, ".")
      for (i = 1; i <= n; i++) {
        if (length(labels[i]) < 1 || length(labels[i]) > 63) exit 1
      }
      exit 0
    }
  '
}

if ! lh_valid_hostname "$domain"; then
  printf 'Error: "%s" is not a valid hostname (letters, digits, hyphens and dots only, no empty or over-long label, 253 characters total at most).\n' "$domain" >&2
  exit 2
fi
domain=$(printf '%s' "$domain" | tr '[:upper:]' '[:lower:]')

# ------------------------------------------------------------- DNS over HTTPS

# Prints the raw DoH JSON response for one name/type query, or a harmless
# empty-answer shape if nothing could be read. Never fails the whole script:
# a resolver problem is reported as "could not check", not as a missing
# record, by the caller.
dns_raw() { # name, type
  name=$1
  type=$2
  if [ "$LH_DNS_TESTING" = 1 ] && [ -n "$LH_DNS_FIXTURE_DIR" ]; then
    f="$LH_DNS_FIXTURE_DIR/${name}__${type}.json"
    if [ -f "$f" ]; then cat "$f"; else printf '{"Status":0,"Answer":[]}'; fi
    return 0
  fi
  out=$(curl -s -m 8 -H 'accept: application/dns-json' \
    "https://cloudflare-dns.com/dns-query?name=${name}&type=${type}" 2>/dev/null)
  if [ -z "$out" ] || ! printf '%s' "$out" | grep -q '"Status"'; then
    out=$(curl -s -m 8 -H 'accept: application/dns-json' \
      "https://dns.google/resolve?name=${name}&type=${type}" 2>/dev/null)
  fi
  if [ -z "$out" ] || ! printf '%s' "$out" | grep -q '"Status"'; then
    printf '{"Status":-1,"Answer":[]}'
  else
    printf '%s' "$out"
  fi
}

# Prints one string field's value per occurrence in a JSON blob, quotes
# stripped, one per line. Handles a backslash-escaped character inside the
# value (passed through literally) but not full JSON unicode escapes, which
# never appear in the record types this script reads.
json_field() { # field name; JSON on stdin
  # Prints each occurrence of "<field>":"<value>" with JSON's own backslash
  # escapes resolved (\" becomes ", \\ becomes \). Cloudflare's DoH data
  # field for a TXT record carries the record's own quote characters inside
  # that value (escaped), which dns_data() strips separately below, since
  # that is the DNS answer's own quoting, not JSON's.
  field=$1
  awk -v f="\"${field}\":\"" '
    { s = $0 }
    {
      while ((i = index(s, f)) > 0) {
        s = substr(s, i + length(f))
        out = ""
        j = 1
        n = length(s)
        while (j <= n) {
          c = substr(s, j, 1)
          if (c == "\\") { out = out substr(s, j + 1, 1); j += 2; continue }
          if (c == "\"") { break }
          out = out c
          j++
        }
        print out
        s = substr(s, j)
      }
    }'
}

# Every "data" value from a DoH response's Answer array, one per line, empty
# if there were none or the query failed outright. A TXT record's data comes
# back from Cloudflare/Google with the DNS character-string's own quote marks
# still around it (for example a record whose real value is v=spf1 ... shows
# up as the JSON string "v=spf1 ..." once JSON-unescaped) so one leading and
# one trailing literal quote, if present, are stripped here too. MX, CNAME, A
# and AAAA data never carry these, so stripping is harmless for them.
dns_data() { # name, type
  dns_raw "$1" "$2" | tr -d '\n' | json_field data | sed 's/^"//; s/"$//'
}

# Whether the query itself failed (resolver error), distinct from a clean
# "no records" answer. 1 = failed, 0 = answered (even with zero records).
dns_failed() { # name, type
  st=$(dns_raw "$1" "$2" | tr -d '\n' | awk '{
    i = index($0, "\"Status\":")
    if (i == 0) { print -1; exit }
    s = substr($0, i + 9)
    n = 0
    while (n < length(s)) {
      c = substr(s, n + 1, 1)
      if (c !~ /[-0-9]/) break
      n++
    }
    print substr(s, 1, n) + 0
  }')
  [ "$st" = "-1" ]
}

# --------------------------------------------------------------------- state

# A literal newline, safe to embed in a variable. $(printf '\n') would work
# too except command substitution strips the trailing newline it prints,
# leaving nothing to join with, so a real newline character has to be
# assigned directly instead.
nl='
'

todos=""
add_todo() { todos="${todos}${todos:+$nl}$1"; }

results=""
add_result() { results="${results}${results:+$nl}$1=$2"; }

overall=pass
bump() { # warn|fail
  case "$1" in
    fail) overall=fail ;;
    warn) [ "$overall" = fail ] || overall=warn ;;
  esac
}

# A resolver failure (dns_failed) is never recorded as a plain result and
# left to fall through: it always degrades overall to at least warn, is
# remembered so the exit code below can be non-zero for it even when
# nothing else failed outright, and gets its own todo line.
had_unknown=0
mark_unknown() { # result_key, todo_text
  add_result "$1" unknown
  bump warn
  had_unknown=1
  add_todo "$2"
}

# ------------------------------------------------------------------------ MX

mx_vals=$(dns_data "$domain" MX)
mx_count=$(printf '%s\n' "$mx_vals" | grep -c .)
if dns_failed "$domain" MX; then
  mark_unknown mx "Could not check MX for $domain (the DNS check itself failed; try again)."
elif [ "$mx_count" -gt 0 ]; then
  add_result mx pass
else
  add_result mx fail
  bump fail
  add_todo "Add an MX record so mail addressed to $domain has somewhere to go."
fi

# ----------------------------------------------------------------------- SPF

txt_vals=$(dns_data "$domain" TXT)
spf_lines=$(printf '%s\n' "$txt_vals" | grep -c '^v=spf1' 2>/dev/null)
[ -n "$spf_lines" ] || spf_lines=0
if dns_failed "$domain" TXT; then
  mark_unknown spf "Could not check SPF for $domain (the DNS check itself failed; try again)."
else
  if [ "$spf_lines" -eq 0 ]; then
    add_result spf fail
    bump fail
    add_todo "Add an SPF TXT record at $domain so mail servers know who is allowed to send as this domain."
  elif [ "$spf_lines" -gt 1 ]; then
    add_result spf fail
    bump fail
    add_todo "There is more than one SPF record at $domain. Merge them into one; two SPF records break SPF for everyone."
  else
    spf_record=$(printf '%s\n' "$txt_vals" | grep '^v=spf1' | head -1)
    includes=$(printf '%s' "$spf_record" | grep -o 'include:' | grep -c .)
    add_result spf_includes "$includes"
    if [ "$mailbox" = google ] && ! printf '%s' "$spf_record" | grep -q '_spf.google.com'; then
      add_todo "The SPF record at $domain does not include _spf.google.com. Add it to the existing record; never create a second one."
    fi
    if [ "$mailbox" = microsoft ] && ! printf '%s' "$spf_record" | grep -q 'spf.protection.outlook.com'; then
      add_todo "The SPF record at $domain does not include spf.protection.outlook.com. Add it to the existing record; never create a second one."
    fi
    if [ "$includes" -gt 10 ]; then
      add_result spf warn
      bump warn
      add_todo "The SPF record at $domain has more than 10 include: lookups (an approximate count; nested includes count too and this script cannot follow them). SPF can silently fail past 10 lookups; check it by hand."
    else
      add_result spf pass
    fi
  fi
fi

# ---------------------------------------------------------------------- DKIM

dkim_selector=""
case "$mailbox" in
  google) dkim_selector="google._domainkey" ;;
  microsoft) dkim_selector="selector1._domainkey" ;;
esac

if [ -n "$dkim_selector" ]; then
  dkim_name="${dkim_selector}.${domain}"
  dkim_vals=$(dns_data "$dkim_name" TXT)
  dkim_cname=$(dns_data "$dkim_name" CNAME)
  dkim_ok=0
  printf '%s\n' "$dkim_vals" | grep -qi 'DKIM1' && dkim_ok=1
  [ "$(printf '%s\n' "$dkim_cname" | grep -c .)" -gt 0 ] && dkim_ok=1
  if dns_failed "$dkim_name" TXT && dns_failed "$dkim_name" CNAME; then
    mark_unknown dkim "Could not check DKIM for $domain (the DNS check itself failed; try again)."
  elif [ "$dkim_ok" = 1 ]; then
    add_result dkim pass
  else
    add_result dkim fail
    bump fail
    add_todo "No DKIM record found at ${dkim_selector}.$domain. Turn on DKIM signing in the mailbox provider's admin console and add the record it gives you."
  fi
  if [ "$mailbox" = microsoft ]; then
    sel2="selector2._domainkey.${domain}"
    sel2_cname=$(dns_data "$sel2" CNAME)
    if dns_failed "$sel2" CNAME; then
      mark_unknown dkim_selector2 "Could not check Microsoft 365's selector2 DKIM record for $domain (the DNS check itself failed; try again)."
    elif [ "$(printf '%s\n' "$sel2_cname" | grep -c .)" -gt 0 ]; then
      add_result dkim_selector2 pass
    else
      add_result dkim_selector2 fail
      bump fail
      add_todo "Microsoft 365 DKIM needs both selector1 and selector2 CNAME records; selector2._domainkey.$domain is missing."
    fi
  fi
else
  add_result dkim skip
fi

# --------------------------------------------------------------------- DMARC

dmarc_name="_dmarc.${domain}"
dmarc_vals=$(dns_data "$dmarc_name" TXT)
dmarc_record=$(printf '%s\n' "$dmarc_vals" | grep '^v=DMARC1' | head -1)
if dns_failed "$dmarc_name" TXT; then
  mark_unknown dmarc "Could not check DMARC for $domain (the DNS check itself failed; try again)."
elif [ -n "$dmarc_record" ]; then
  add_result dmarc pass
  policy=$(printf '%s' "$dmarc_record" | sed -n 's/.*p=\([a-zA-Z]*\).*/\1/p' | tr 'A-Z' 'a-z')
  [ -n "$policy" ] || policy=none
  add_result dmarc_policy "$policy"
else
  add_result dmarc fail
  bump fail
  add_todo "No DMARC record at _dmarc.$domain. Start with v=DMARC1; p=none once SPF and DKIM have both been live for a day or two."
fi

# --------------------------------------------------------------- Apollo, GHL

if [ -n "$apollo_tracking" ]; then
  at_vals=$(dns_data "$apollo_tracking" CNAME)
  if dns_failed "$apollo_tracking" CNAME; then
    mark_unknown apollo_tracking "Could not check the Apollo tracking subdomain ($apollo_tracking); try again."
  elif [ "$(printf '%s\n' "$at_vals" | grep -c .)" -gt 0 ]; then
    add_result apollo_tracking pass
  else
    add_result apollo_tracking fail
    bump fail
    add_todo "The Apollo tracking subdomain ($apollo_tracking) has no CNAME yet. Add the exact value Apollo's own Tracking Subdomains screen shows."
  fi
else
  add_result apollo_tracking skip
fi

if [ -n "$ghl_sending" ]; then
  gh_mx=$(dns_data "$ghl_sending" MX)
  gh_txt=$(dns_data "$ghl_sending" TXT)
  if dns_failed "$ghl_sending" MX && dns_failed "$ghl_sending" TXT; then
    mark_unknown ghl_sending "Could not check the GoHighLevel sending subdomain ($ghl_sending); try again."
  elif [ "$(printf '%s\n' "$gh_mx" | grep -c .)" -gt 0 ] || [ "$(printf '%s\n' "$gh_txt" | grep -c .)" -gt 0 ]; then
    add_result ghl_sending pass
  else
    add_result ghl_sending fail
    bump fail
    add_todo "The GoHighLevel sending subdomain ($ghl_sending) has none of its records yet. Add the 5 records GoHighLevel's own Add Domain screen shows."
  fi
else
  add_result ghl_sending skip
fi

if [ "$want_resend" = 1 ]; then
  rs_name="resend._domainkey.${domain}"
  rs_vals=$(dns_data "$rs_name" TXT)
  if dns_failed "$rs_name" TXT; then
    mark_unknown resend "Could not check Resend's DKIM record; try again."
  elif [ "$(printf '%s\n' "$rs_vals" | grep -c .)" -gt 0 ]; then
    add_result resend pass
  else
    add_result resend fail
    bump fail
    add_todo "No Resend DKIM record at resend._domainkey.$domain. Add the records Resend's own Add Domain screen shows for its sending subdomain."
  fi
else
  add_result resend skip
fi

# ------------------------------------------------------------------- website

for label_host in "apex:${domain}" "www:www.${domain}"; do
  label=${label_host%%:*}
  host=${label_host#*:}
  a=$(dns_data "$host" A)
  aaaa=$(dns_data "$host" AAAA)
  cname=$(dns_data "$host" CNAME)
  key="website_${label}"
  if dns_failed "$host" A && dns_failed "$host" AAAA && dns_failed "$host" CNAME; then
    mark_unknown "$key" "Could not check the website ($host); try again."
  elif [ "$(printf '%s\n' "$a" | grep -c .)" -gt 0 ] || [ "$(printf '%s\n' "$aaaa" | grep -c .)" -gt 0 ] || [ "$(printf '%s\n' "$cname" | grep -c .)" -gt 0 ]; then
    add_result "$key" pass
  else
    add_result "$key" fail
    bump fail
    add_todo "No website found at $host yet."
  fi
done

# -------------------------------------------------------------------- output

if [ "$want_json" = 1 ]; then
  printf '{'
  printf '"domain":"%s",' "$domain"
  printf '"status":"%s",' "$overall"
  printf '%s\n' "$results" | while IFS='=' read -r k v; do
    [ -n "$k" ] || continue
    printf '"%s":"%s",' "$k" "$v"
  done
  printf '"todo":['
  first=1
  printf '%s\n' "$todos" | while IFS= read -r t; do
    [ -n "$t" ] || continue
    [ "$first" = 1 ] || printf ','
    t_escaped=$(printf '%s' "$t" | sed 's/\\/\\\\/g; s/"/\\"/g')
    printf '"%s"' "$t_escaped"
    first=0
  done
  printf ']}\n'
else
  printf 'domain=%s\n' "$domain"
  printf '%s\n' "$results"
  if [ -n "$todos" ]; then
    printf '%s\n' "$todos" | while IFS= read -r t; do
      [ -n "$t" ] || continue
      printf 'todo=%s\n' "$t"
    done
  fi
  printf 'status=%s\n' "$overall"
fi

# --------------------------------------------------------------- --record

if [ "$want_record" = 1 ]; then
  ge=""
  if [ -n "$CLAUDE_PROJECT_DIR" ] && [ -d "$CLAUDE_PROJECT_DIR/growth-engine" ]; then
    ge="$CLAUDE_PROJECT_DIR/growth-engine"
  elif [ -d "./growth-engine" ]; then
    ge="./growth-engine"
  fi
  if [ -n "$ge" ]; then
    mkdir -p "$ge/.state" 2>/dev/null
    out="$ge/.state/domain.md"
    tmp="$out.tmp.$$"
    {
      printf '# Domain check\n\n'
      printf 'Written by dns-check.sh --record. Counts only: no DNS record values, no people.\n\n'
      # printf -- protects a format string starting with "-" from being
      # read as an option flag by the shell's own printf builtin.
      printf -- '- Domain: %s\n' "$domain"
      printf -- '- Checked: %s\n\n' "$(date '+%Y-%m-%d')"
      printf '| check | state |\n|---|---|\n'
      printf '%s\n' "$results" | while IFS='=' read -r k v; do
        [ -n "$k" ] || continue
        printf '| %s | %s |\n' "$k" "$v"
      done
      printf '\nOverall: %s\n' "$overall"
    } > "$tmp" 2>/dev/null && mv "$tmp" "$out" 2>/dev/null
  fi
fi

case "$overall" in
  pass) exit 0 ;;
  warn) [ "$had_unknown" = 1 ] && exit 1; exit 0 ;;
  fail) exit 1 ;;
esac
