#!/bin/sh
# Maintains .claude/tool-packs/. POSIX sh + awk, no jq, no node, no python,
# same style as the rest of .claude/scripts.
#
# Subcommands:
#   --validate <id|all>   checks a pack's shape (files, frontmatter, headings,
#                          inventory cross-checks, policy and tests). Prints
#                          one plain line per problem, exits 1 on any.
#   --compile              writes compiled-policy.sh from registry.tsv and
#                          every pack's policy.tsv + policy.local.tsv.
#   --check-compiled       exits 1 if compiled-policy.sh is stale.
#   --test <id|all>        runs tests.tsv through the real mcp-guard.sh, in a
#                          throwaway fake active Launchhouse folder.
#   --list                 id, name, origin, installed yes/no.
#
# This script never touches the founder's own folder: --test and --compile's
# self-check both work in a temp folder under TMPDIR, same as .claude/tests/run.sh.

set -u
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
packs_dir="$root/.claude/tool-packs"
registry="$packs_dir/registry.tsv"
compiled="$packs_dir/compiled-policy.sh"

fail=0
problem() { # id, message
  printf '%s: %s\n' "$1" "$2"
  fail=1
}

# All scratch files this script creates live outside the repo, under
# TMPDIR, and are cleaned up on any exit (normal, error, or signal).
LH_TMP_FILES=""
lh_mktemp() {
  lh_mt_f=$(mktemp "${TMPDIR:-/tmp}/lh-tool-packs.XXXXXX") || {
    echo "could not create a temp file under \${TMPDIR:-/tmp}" >&2
    exit 1
  }
  LH_TMP_FILES="$LH_TMP_FILES $lh_mt_f"
  printf '%s' "$lh_mt_f"
}
lh_cleanup() {
  [ -n "$LH_TMP_FILES" ] && rm -f $LH_TMP_FILES
}
trap lh_cleanup EXIT INT TERM

# Every non-comment, non-blank line of registry.tsv after the header, as
# id\tname\tsuffix_regex\ttracks\torigin.
registry_rows() {
  [ -f "$registry" ] || return 0
  awk -F '\t' 'NR > 1 && $0 !~ /^#/ && NF >= 5 { print }' "$registry"
}

registry_ids() {
  registry_rows | awk -F '\t' '{ print $1 }'
}

# ------------------------------------------------------------------ helpers
# True (exit 0) if $1 is a syntactically valid POSIX ERE, tested against grep -E.
lh_valid_ere() {
  printf 'x\n' | grep -E -- "$1" >/dev/null 2>&1
  ec=$?
  [ "$ec" != 2 ]
}

# The tool suffix: the part of a tool name after its last "__".
lh_suffix_of() {
  printf '%s' "$1" | awk -F '__' '{ print $NF }'
}

# ---------------------------------------------------------------- validate
validate_pack() {
  id=$1
  dir="$packs_dir/$id"
  if [ ! -d "$dir" ]; then
    problem "$id" "pack directory missing ($dir)"
    return
  fi

  for f in pack.md knowledge.md inventory.txt policy.tsv tests.tsv evals.md; do
    [ -f "$dir/$f" ] || problem "$id" "missing $f"
  done

  # ------------------------------------------------------------ pack.md
  if [ -f "$dir/pack.md" ]; then
    fm=$(awk '
      NR == 1 && $0 !~ /^---[ \t]*$/ { print "NOFRONT"; exit }
      NR == 1 { next }
      /^---[ \t]*$/ { exit }
      { print }
    ' "$dir/pack.md")
    if [ "$fm" = NOFRONT ] || [ -z "$fm" ]; then
      problem "$id" "pack.md has no --- frontmatter block"
    else
      for key in id name vendor_url tracks jobs job_skills specialist expert_skill inventory_source verified_on origin; do
        printf '%s\n' "$fm" | grep -Eq "^${key}:" || problem "$id" "pack.md frontmatter is missing '$key:'"
      done
    fi
  fi

  # --------------------------------------------------------- knowledge.md
  km="$dir/knowledge.md"
  if [ -f "$km" ]; then
    headings=$(grep -E '^## ' "$km")
    required='## Mental model
## Connecting and auth
## Tool map
## Workflows for Launchhouse jobs
## Limits and quotas
## Failure modes and fixes
## Rules that apply here
## Sources
## Refreshing this pack'
    last_pos=0
    ok=1
    headings_tmp=$(lh_mktemp)
    printf '%s\n' "$required" | while IFS= read -r want; do
      [ -n "$want" ] || continue
      pos=$(printf '%s\n' "$headings" | grep -nxF "$want" | head -1 | cut -d: -f1)
      if [ -z "$pos" ]; then
        printf 'MISSING\t%s\n' "$want"
      else
        printf 'POS\t%s\t%s\n' "$pos" "$want"
      fi
    done > "$headings_tmp" 2>/dev/null || true
    if [ -s "$headings_tmp" ]; then
      while IFS='	' read -r kind a b; do
        if [ "$kind" = MISSING ]; then
          problem "$id" "knowledge.md is missing the heading '$a'"
        fi
      done < "$headings_tmp"
      prev=0
      out_of_order=0
      while IFS='	' read -r kind a b; do
        [ "$kind" = POS ] || continue
        if [ "$a" -lt "$prev" ]; then out_of_order=1; fi
        prev=$a
      done < "$headings_tmp"
      [ "$out_of_order" = 1 ] && problem "$id" "knowledge.md's required headings are not in the required order"
    fi
    rm -f "$headings_tmp"

    # ---------------------------------------------------- inventory cross-check
    if [ -f "$dir/inventory.txt" ]; then
      inv=$(awk '!/^#/ && NF { print $1 }' "$dir/inventory.txt")

      # Tool map section only: between "## Tool map" and the next "## ".
      toolmap_section=$(awk '
        /^## Tool map/ { on = 1; next }
        /^## / { on = 0 }
        on { print }
      ' "$km")
      toolmap_tools=$(printf '%s\n' "$toolmap_section" | grep -E '^\|' | \
        sed -n 's/^| *`\([^`]*\)`.*/\1/p')

      inv_tmp=$(lh_mktemp)
      printf '%s\n' "$inv" | while IFS= read -r t; do
        [ -n "$t" ] || continue
        printf '%s\n' "$toolmap_tools" | grep -qxF -- "$t" || \
          printf 'inventory tool `%s` does not appear in the Tool map\n' "$t"
      done > "$inv_tmp" 2>/dev/null || true
      if [ -s "$inv_tmp" ]; then
        while IFS= read -r line; do problem "$id" "$line"; done < "$inv_tmp"
      fi
      rm -f "$inv_tmp"

      printf '%s\n' "$toolmap_tools" | awk 'NF' | sort | uniq -c | awk '$1 > 1 { print $2 }' | \
      while IFS= read -r t; do
        problem "$id" "Tool map lists \`$t\` more than once"
      done

      printf '%s\n' "$toolmap_tools" | while IFS= read -r t; do
        [ -n "$t" ] || continue
        printf '%s\n' "$inv" | grep -qxF -- "$t" || \
          problem "$id" "Tool map names \`$t\`, which is not in inventory.txt"
      done

      # Any other backticked token in knowledge.md, policy.tsv or tests.tsv
      # that MATCHES THIS PACK'S OWN suffix_regex (so it is tool-shaped for
      # this pack specifically, not just alnum-and-hyphen) but that
      # inventory.txt does not carry.
      pack_suffix_regex=$(registry_rows | awk -F '\t' -v id="$id" '$1 == id { print $3; exit }')
      all_backticked=$( { grep -o '`[^`]*`' "$km" "$dir/policy.tsv" "$dir/tests.tsv" 2>/dev/null; } | sed 's/^[^:]*:`/`/; s/^`//; s/`$//' )
      bt_tmp=$(lh_mktemp)
      if [ -n "$pack_suffix_regex" ]; then
        printf '%s\n' "$all_backticked" | while IFS= read -r t; do
          [ -n "$t" ] || continue
          case $t in *[!A-Za-z0-9_-]*) continue ;; esac
          printf '%s\n' "$t" | grep -Eq -- "$pack_suffix_regex" || continue
          printf '%s\n' "$inv" | grep -qxF -- "$t" || \
            printf 'the tool-shaped token `%s` in knowledge.md/policy.tsv/tests.tsv is not in inventory.txt\n' "$t"
        done | sort -u > "$bt_tmp" 2>/dev/null || true
      fi
      if [ -s "$bt_tmp" ]; then
        while IFS= read -r line; do problem "$id" "$line"; done < "$bt_tmp"
      fi
      rm -f "$bt_tmp"
    fi

    # -------------------------------------------------------------- Sources
    sources_section=$(awk '
      /^## Sources/ { on = 1; next }
      /^## / { on = 0 }
      on { print }
    ' "$km")
    src_lines=$(printf '%s\n' "$sources_section" | grep -E '^- ')
    if [ -n "$src_lines" ]; then
      src_tmp=$(lh_mktemp)
      printf '%s\n' "$src_lines" | while IFS= read -r line; do
        [ -n "$line" ] || continue
        printf '%s' "$line" | grep -q 'https' || printf 'a Sources line is missing an https URL: %s\n' "$line"
        printf '%s' "$line" | grep -Eq '[0-9]{4}-[0-9]{2}-[0-9]{2}' || printf 'a Sources line is missing a checked YYYY-MM-DD date: %s\n' "$line"
      done > "$src_tmp" 2>/dev/null || true
      if [ -s "$src_tmp" ]; then
        while IFS= read -r line; do problem "$id" "$line"; done < "$src_tmp"
      fi
      rm -f "$src_tmp"
    fi
  fi

  # ------------------------------------------------------------- policy.tsv
  policy_rows="" # regex<TAB>decision<TAB>reason, from policy.tsv and policy.local.tsv
  for pf in policy.tsv policy.local.tsv; do
    [ -f "$dir/$pf" ] || continue
    while IFS='	' read -r regex decision reason; do
      case $regex in ''|'#'*) continue ;; esac
      [ -n "$decision" ] || continue
      case $decision in
        deny|ask) ;;
        *) problem "$id" "$pf: '$decision' is not a valid decision (deny or ask only), for $regex" ;;
      esac
      lh_valid_ere "$regex" || problem "$id" "$pf: '$regex' is not a valid regular expression"
      policy_rows="$policy_rows$regex	$decision	$reason
"
    done < "$dir/$pf"
  done

  # -------------------------------------------------------------- tests.tsv
  test_rows=""
  if [ -f "$dir/tests.tsv" ]; then
    while IFS='	' read -r tool_name expected tool_input note; do
      case $tool_name in ''|'#'*) continue ;; esac
      [ -n "$expected" ] || continue
      case $expected in
        deny|ask|guide|silent) ;;
        *) problem "$id" "tests.tsv: '$expected' is not a valid expectation (deny|ask|guide|silent), for $tool_name" ;;
      esac
      test_rows="$test_rows$tool_name	$expected
"
    done < "$dir/tests.tsv"
  fi

  # Every policy row needs a test whose tool suffix it matches.
  if [ -n "$policy_rows" ]; then
    cov_tmp=$(lh_mktemp)
    printf '%s' "$policy_rows" | while IFS='	' read -r regex decision reason; do
      [ -n "$regex" ] || continue
      matched=0
      if [ -n "$test_rows" ]; then
        printf '%s' "$test_rows" | while IFS='	' read -r tool_name expected; do
          [ -n "$tool_name" ] || continue
          suf=$(lh_suffix_of "$tool_name")
          printf '%s\n' "$suf" | grep -Eq -- "$regex" && { echo yes; break; }
        done | grep -q yes && matched=1
      fi
      [ "$matched" = 1 ] || printf 'no test in tests.tsv covers the policy row for %s\n' "$regex"
    done > "$cov_tmp" 2>/dev/null || true
    if [ -s "$cov_tmp" ]; then
      while IFS= read -r line; do problem "$id" "$line"; done < "$cov_tmp"
    fi
    rm -f "$cov_tmp"
  fi

  # ---------------------------------------------------------------- evals.md
  if [ -f "$dir/evals.md" ]; then
    n=$(grep -Ec '^### ' "$dir/evals.md")
    [ "$n" -ge 8 ] || problem "$id" "evals.md has only $n scenario(s) (### headings); needs at least 8"
  fi
}

cmd_validate() {
  want=${1:-all}
  if [ "$want" = all ]; then
    ids=$(registry_ids)
  else
    ids=$want
  fi
  [ -n "$ids" ] || { echo "no packs to validate (registry.tsv is empty)"; exit 0; }
  for id in $ids; do validate_pack "$id"; done
  if [ "$fail" = 0 ]; then
    printf 'All packs valid.\n'
  fi
  exit $fail
}

# ------------------------------------------------------------------ compile
# Escapes a string for embedding inside a single-quoted POSIX sh string:
# every ' becomes '"'"'.
lh_sq_escape() {
  printf '%s' "$1" | sed "s/'/'\"'\"'/g"
}

# Writes a fresh compiled-policy.sh to the path given as $1. Every local
# name here is unique to this function (lhwc_*) on purpose: it is called
# from both cmd_compile and cmd_check_compiled, and POSIX sh has no block
# scoping, so a name shared with a caller would get clobbered.
lh_write_compiled() {
  lhwc_dest=$1

  lhwc_detect_tmp=$(lh_mktemp)
  lhwc_deny_tmp=$(lh_mktemp)
  lhwc_ask_tmp=$(lh_mktemp)

  registry_rows | while IFS='	' read -r lhwc_id lhwc_name lhwc_suffix_regex lhwc_tracks lhwc_origin; do
    [ -n "$lhwc_id" ] || continue
    printf '%s\t%s\t%s\n' "$lhwc_id" "$lhwc_name" "$lhwc_suffix_regex"
  done > "$lhwc_detect_tmp"

  : > "$lhwc_deny_tmp"
  : > "$lhwc_ask_tmp"
  for lhwc_id in $(registry_ids); do
    lhwc_dir="$packs_dir/$lhwc_id"
    for lhwc_pf in policy.tsv policy.local.tsv; do
      [ -f "$lhwc_dir/$lhwc_pf" ] || continue
      while IFS='	' read -r lhwc_regex lhwc_decision lhwc_reason; do
        case $lhwc_regex in ''|'#'*) continue ;; esac
        [ -n "$lhwc_decision" ] || continue
        case $lhwc_decision in
          deny) printf '%s\t%s\n' "$lhwc_regex" "$lhwc_reason" >> "$lhwc_deny_tmp" ;;
          ask) printf '%s\t%s\n' "$lhwc_regex" "$lhwc_reason" >> "$lhwc_ask_tmp" ;;
        esac
      done < "$lhwc_dir/$lhwc_pf"
    done
  done

  lhwc_detect_rules=$(cat "$lhwc_detect_tmp" 2>/dev/null)
  lhwc_deny_rules=$(cat "$lhwc_deny_tmp" 2>/dev/null)
  lhwc_ask_rules=$(cat "$lhwc_ask_tmp" 2>/dev/null)
  rm -f "$lhwc_detect_tmp" "$lhwc_deny_tmp" "$lhwc_ask_tmp"

  lhwc_detect_esc=$(lh_sq_escape "$lhwc_detect_rules")
  lhwc_deny_esc=$(lh_sq_escape "$lhwc_deny_rules")
  lhwc_ask_esc=$(lh_sq_escape "$lhwc_ask_rules")

  lhwc_tmp=$(lh_mktemp)
  {
    printf '#!/bin/sh\n'
    printf '# GENERATED by tool-packs.sh --compile from registry.tsv and every pack'"'"'s\n'
    printf '# policy.tsv + policy.local.tsv. Do not hand-edit: run\n'
    printf '# sh .claude/scripts/tool-packs.sh --compile again instead. Sourced by\n'
    printf '# mcp-guard.sh, which fails open if this file is missing or broken.\n'
    printf '#\n'
    printf '# Both functions below spawn exactly one awk process per call, and read\n'
    printf '# nothing off disk: the rule tables are the shell variables right here,\n'
    printf '# written fresh by every --compile run.\n\n'
    printf 'LH_PACK_DETECT_RULES='"'"'%s'"'"'\n\n' "$lhwc_detect_esc"
    printf 'LH_PACK_DENY_RULES='"'"'%s'"'"'\n\n' "$lhwc_deny_esc"
    printf 'LH_PACK_ASK_RULES='"'"'%s'"'"'\n\n' "$lhwc_ask_esc"
    cat <<'EOF'
# Which pack a tool suffix belongs to, first match in registry order. Sets
# lh_pack_id and lh_pack_name, both empty when nothing matches.
lh_pack_detect() {
  suffix=$1
  lh_pack_id=""
  lh_pack_name=""
  lh_pd_out=$(printf '%s' "$suffix" | RULES="$LH_PACK_DETECT_RULES" awk -F '\t' '
    BEGIN { n = split(ENVIRON["RULES"], arr, "\n") }
    {
      s = $0
      for (i = 1; i <= n; i++) {
        if (arr[i] == "") continue
        split(arr[i], f, "\t")
        if (f[3] != "" && s ~ f[3]) { print f[1] "\t" f[2]; exit }
      }
    }')
  [ -n "$lh_pd_out" ] || return 0
  lh_pd_tab=$(printf '\t')
  lh_pack_id=${lh_pd_out%%"$lh_pd_tab"*}
  lh_pack_name=${lh_pd_out#*"$lh_pd_tab"}
}

# The strictest pack policy for a tool suffix: deny beats ask. Sets
# lh_pack_decision (deny, ask, or empty) and lh_pack_reason.
lh_pack_policy() {
  suffix=$1
  lh_pack_decision=""
  lh_pack_reason=""
  lh_pp_out=$(printf '%s' "$suffix" | DENY="$LH_PACK_DENY_RULES" ASK="$LH_PACK_ASK_RULES" awk -F '\t' '
    BEGIN {
      dn = split(ENVIRON["DENY"], darr, "\n")
      an = split(ENVIRON["ASK"], aarr, "\n")
    }
    {
      s = $0
      for (i = 1; i <= dn; i++) {
        if (darr[i] == "") continue
        split(darr[i], f, "\t")
        if (f[1] != "" && s ~ f[1]) { print "deny\t" f[2]; exit }
      }
      for (i = 1; i <= an; i++) {
        if (aarr[i] == "") continue
        split(aarr[i], f, "\t")
        if (f[1] != "" && s ~ f[1]) { print "ask\t" f[2]; exit }
      }
    }')
  [ -n "$lh_pp_out" ] || return 0
  lh_pp_tab=$(printf '\t')
  lh_pack_decision=${lh_pp_out%%"$lh_pp_tab"*}
  lh_pack_reason=${lh_pp_out#*"$lh_pp_tab"}
}
EOF
  } > "$lhwc_tmp"
  mv "$lhwc_tmp" "$lhwc_dest"
  chmod +x "$lhwc_dest" 2>/dev/null || true
}

cmd_compile() {
  lh_write_compiled "$compiled"
  printf 'Compiled %s.\n' "$compiled"
}

cmd_check_compiled() {
  cc_candidate=$(lh_mktemp)
  lh_write_compiled "$cc_candidate"
  if [ ! -f "$compiled" ]; then
    echo "compiled-policy.sh does not exist; run --compile"
    rm -f "$cc_candidate"
    exit 1
  fi
  if diff -q "$cc_candidate" "$compiled" >/dev/null 2>&1; then
    printf 'compiled-policy.sh is up to date.\n'
    rm -f "$cc_candidate"
    exit 0
  else
    printf 'compiled-policy.sh is stale; run: sh .claude/scripts/tool-packs.sh --compile\n'
    rm -f "$cc_candidate"
    exit 1
  fi
}

# --------------------------------------------------------------------- test
cmd_test() {
  want=${1:-all}
  if [ "$want" = all ]; then
    ids=$(registry_ids)
  else
    ids=$want
  fi
  [ -n "$ids" ] || { echo "no packs to test (registry.tsv is empty)"; exit 0; }

  cmd_compile >/dev/null

  work=${TMPDIR:-/tmp}/lh-toolpack-test.$$
  trap 'rm -rf "$work"' EXIT
  mkdir -p "$work/.claude" "$work/growth-engine" || exit 1
  cp -R "$here" "$work/.claude/scripts"
  cp -R "$packs_dir" "$work/.claude/tool-packs"
  : > "$work/growth-engine/.launchhouse"

  tfail=0
  for id in $ids; do
    dir="$packs_dir/$id"
    if [ ! -f "$dir/tests.tsv" ]; then
      printf 'SKIP  %s  no tests.tsv\n' "$id"
      continue
    fi
    while IFS='	' read -r tool_name expected tool_input note; do
      case $tool_name in ''|'#'*) continue ;; esac
      [ -n "$expected" ] || continue
      ti=${tool_input:-'{}'}
      out=$(printf '{"session_id":"abc","transcript_path":"/tmp/x.jsonl","cwd":"%s","permission_mode":"default","hook_event_name":"PreToolUse","tool_name":"%s","tool_input":%s}' \
        "$work" "$tool_name" "$ti" | CLAUDE_PROJECT_DIR="$work" sh "$work/.claude/scripts/mcp-guard.sh" 2>/dev/null)
      got=silent
      case $out in
        *'"deny"'*) got=deny ;;
        *'"ask"'*) got=ask ;;
        *additionalContext*) got=guide ;;
        '') got=silent ;;
        *) got=other ;;
      esac
      if [ "$got" = "$expected" ]; then
        printf 'PASS  %s  %s (%s)\n' "$id" "$tool_name" "$expected"
      else
        printf 'FAIL  %s  %s  expected %s, got %s%s\n' "$id" "$tool_name" "$expected" "$got" "${note:+ -- $note}"
        tfail=1
      fi
    done < "$dir/tests.tsv"
  done
  if [ "$tfail" = 0 ]; then
    printf '\nAll tool-pack tests passed.\n'
  else
    printf '\nSome tool-pack tests failed.\n'
  fi
  exit $tfail
}

# --------------------------------------------------------------------- list
cmd_list() {
  printf 'id\tname\torigin\tinstalled\n'
  registry_rows | while IFS='	' read -r id name suffix_regex tracks origin; do
    [ -n "$id" ] || continue
    installed=no
    [ -f "$packs_dir/$id/pack.md" ] && installed=yes
    printf '%s\t%s\t%s\t%s\n' "$id" "$name" "$origin" "$installed"
  done
}

case ${1:-} in
  --validate) cmd_validate "${2:-all}" ;;
  --compile) cmd_compile ;;
  --check-compiled) cmd_check_compiled ;;
  --test) cmd_test "${2:-all}" ;;
  --list) cmd_list ;;
  *)
    echo "usage: tool-packs.sh --validate <id|all> | --compile | --check-compiled | --test <id|all> | --list" >&2
    exit 2
    ;;
esac
