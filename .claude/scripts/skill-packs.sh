#!/bin/sh
# Maintains .claude/skill-packs/. POSIX sh + awk, no jq, no node, no python,
# same style as the rest of .claude/scripts.
#
# A skill pack is a plugin-like bundle: its own skills/, agents/, scripts/
# and references/ (knowledge, evals, and for a tool pack an inventory),
# plus policy.tsv/policy.local.tsv/tests.tsv at the pack root. Two kinds,
# set by pack.md's kind: field: "tool" (tied to one connector, detected by
# tool suffix) or "guide" (a roadmap area with no single connector, whose
# suffix_regex in registry.tsv is "-", meaning nothing is ever detected for
# it).
#
# Subcommands:
#   --validate <id|all>   checks a pack's shape (files, frontmatter, headings,
#                          inventory cross-checks, skills/agents/scripts
#                          cross-checks, name uniqueness, policy and tests).
#                          Prints one plain line per problem, exits 1 on any.
#   --compile              writes compiled-policy.sh from registry.tsv and
#                          every pack's policy.tsv + policy.local.tsv. Output
#                          shape is unchanged from before skill packs carried
#                          their own skills and agents.
#   --check-compiled       exits 1 if compiled-policy.sh is stale.
#   --test <id|all>        runs tests.tsv through the real mcp-guard.sh, in a
#                          throwaway fake active Launchhouse folder.
#   --list                 id, name, kind, origin, installed yes/no.
#   --install <id|all>     copies each pack's skills to .claude/skills/<name>/
#                          SKILL.md and agents to .claude/agents/<name>.md,
#                          with a marker line. Refuses to overwrite an
#                          installed copy that has drifted from what the pack
#                          would produce; never silently clobbers a founder's
#                          own edit.
#   --adopt <id>            copies a drifted installed copy's current content
#                          back into the pack's own source, marker stripped.
#   --check-installed       exits 1 if any pack's skill or agent is missing
#                          from .claude/skills or .claude/agents, or installed
#                          but drifted from the pack's own copy.
#
# This script never touches the founder's own folder: --test and --compile's
# self-check both work in a temp folder under TMPDIR, same as .claude/tests/run.sh.
# --install and --adopt do write into .claude/skills/ and .claude/agents/,
# which is the point of those two subcommands, but never into growth-engine/.

set -u
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
packs_dir="$root/.claude/skill-packs"
registry="$packs_dir/registry.tsv"
compiled="$packs_dir/compiled-policy.sh"
lh_marker_prefix="<!-- Installed from "
lh_marker_suffix=". Edit the pack's copy, not this one; Launchhouse re-installs it. -->"

fail=0
problem() { # id, message
  printf '%s: %s\n' "$1" "$2"
  fail=1
}

# All scratch files this script creates live outside the repo, under
# TMPDIR, and are cleaned up on any exit (normal, error, or signal).
LH_TMP_FILES=""
lh_mktemp() {
  lh_mt_f=$(mktemp "${TMPDIR:-/tmp}/lh-skill-packs.XXXXXX") || {
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
# id\tname\tkind\tsuffix_regex\ttracks\torigin.
registry_rows() {
  [ -f "$registry" ] || return 0
  awk -F '\t' 'NR > 1 && $0 !~ /^#/ && NF >= 6 { print }' "$registry"
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

# pack.md's own frontmatter block, as raw lines (no --- delimiters), or the
# single line NOFRONT if it has none.
lh_frontmatter() { # pack.md path
  awk '
    NR == 1 && $0 !~ /^---[ \t]*$/ { print "NOFRONT"; exit }
    NR == 1 { next }
    /^---[ \t]*$/ { exit }
    { print }
  ' "$1"
}

# One frontmatter key's raw value (the text after "key:"), trimmed, empty if
# the key is absent. Only single-line values are supported, which is all
# pack.md ever uses.
lh_fm_value() { # frontmatter text, key
  printf '%s\n' "$1" | awk -F ':' -v k="$2" '
    $0 ~ "^" k ":" { sub("^" k ":[ \t]*", ""); print; exit }
  '
}

# A frontmatter list value like "[a, b, c]" or "[]", as one item per line.
# Empty output for "[]" or a missing/malformed key.
lh_fm_list() { # frontmatter text, key
  v=$(lh_fm_value "$1" "$2")
  inner=$(printf '%s' "$v" | sed -n 's/^\[\(.*\)\]$/\1/p')
  [ -n "$inner" ] || return 0
  printf '%s\n' "$inner" | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | awk 'NF'
}

# --------------------------------------------------------- name/path safety
# The Launchhouse slug grammar every pack id, skill name and agent name must
# satisfy: lowercase letters, digits and hyphens, starting with a letter or
# digit, 1-63 characters. These names go straight into paths under
# .claude/skill-packs/, .claude/skills/ and .claude/agents/ (registry.tsv,
# pack.md's own frontmatter, or a directory listing), so a name shaped like
# "../../etc" or carrying a "/" is refused here before it ever reaches a
# path, never silently sanitised or skipped.
lh_valid_slug() { # candidate name
  printf '%s' "$1" | grep -Eq '^[a-z0-9][a-z0-9-]{0,62}$'
}

# The grammar for a script file name: a valid slug plus a literal ".sh".
lh_valid_script_slug() { # candidate name
  printf '%s' "$1" | grep -Eq '^[a-z0-9][a-z0-9-]{0,59}\.sh$'
}

# Refuses (plain stderr message, exit 2) unless $2 satisfies the slug
# grammar ($3 = script switches to the script grammar).
lh_require_slug() { # kind label, candidate, script (optional)
  rq_kind=$1; rq_name=$2; rq_shape=${3:-}
  if [ "$rq_shape" = script ]; then
    lh_valid_script_slug "$rq_name" && return 0
    printf 'Error: %s '"'"'%s'"'"' is not a valid script file name (lowercase letters, digits and hyphens, ending in .sh, 1-63 characters total).\n' "$rq_kind" "$rq_name" >&2
  else
    lh_valid_slug "$rq_name" && return 0
    printf 'Error: %s '"'"'%s'"'"' is not a valid name (lowercase letters, digits and hyphens only, starting with a letter or digit, 1-63 characters).\n' "$rq_kind" "$rq_name" >&2
  fi
  exit 2
}

# lh_require_slug over a newline list of names, e.g. pack.md's own skills:
# frontmatter list or a directory scan. A pipe (name | lh_require_slug_list
# ...) would run the loop in a subshell, where "exit" only ends that
# subshell and the bad name would slip through unnoticed -- this reads the
# list by heredoc instead, in the calling shell, so a refusal here really
# does stop the whole run.
lh_require_slug_list() { # kind label, list (newline separated), script (optional)
  rsl_kind=$1; rsl_list=$2; rsl_shape=${3:-}
  while IFS= read -r rsl_n; do
    [ -n "$rsl_n" ] || continue
    lh_require_slug "$rsl_kind" "$rsl_n" "$rsl_shape"
  done <<EOF
$rsl_list
EOF
}

# Refuses (plain stderr message, exit 2) if $2, or any of its path
# components down to $1, is a symlink, or if $2 is not actually contained
# inside $1. Call this right before reading from or writing to any path
# under .claude/skill-packs/, .claude/skills/ or .claude/agents/ that was
# built by concatenating an already slug-checked pack id, skill name, agent
# name or script name -- defence in depth on top of the grammar check above,
# which already rules out "/", ".." and a leading "." or "~" in any one
# component, but never on its own proves a symlink was not spliced in
# further up the tree.
lh_refuse_symlink_path() { # base_dir, candidate_path
  rsp_base=$1; rsp_path=$2
  case $rsp_path in
    "$rsp_base") : ;;
    "$rsp_base"/*) : ;;
    *) printf 'Error: %s is not contained in %s.\n' "$rsp_path" "$rsp_base" >&2; exit 2 ;;
  esac
  rsp_p=$rsp_path
  while [ "$rsp_p" != "$rsp_base" ] && [ "$rsp_p" != "/" ] && [ -n "$rsp_p" ] && [ "$rsp_p" != "." ]; do
    if [ -L "$rsp_p" ]; then
      printf 'Error: %s is a symlink; refusing to read or write through it.\n' "$rsp_p" >&2
      exit 2
    fi
    rsp_p=$(dirname "$rsp_p")
  done
}

# ---------------------------------------------------------------- validate
validate_pack() {
  id=$1
  lh_require_slug "pack id" "$id"
  dir="$packs_dir/$id"
  lh_refuse_symlink_path "$packs_dir" "$dir"
  if [ ! -d "$dir" ]; then
    problem "$id" "pack directory missing ($dir)"
    return
  fi

  # ------------------------------------------------------------ pack.md, kind
  kind=""
  if [ ! -f "$dir/pack.md" ]; then
    problem "$id" "missing pack.md"
  else
    fm=$(lh_frontmatter "$dir/pack.md")
    if [ "$fm" = NOFRONT ] || [ -z "$fm" ]; then
      problem "$id" "pack.md has no --- frontmatter block"
    else
      kind=$(lh_fm_value "$fm" kind)
      case $kind in
        tool|guide) ;;
        *) problem "$id" "pack.md's kind is '$kind', must be tool or guide"; kind=tool ;;
      esac
      common_keys="id name kind tracks jobs job_skills skills agents scripts connectors verified_on origin"
      for key in $common_keys; do
        printf '%s\n' "$fm" | grep -Eq "^${key}:" || problem "$id" "pack.md frontmatter is missing '$key:'"
      done
      if [ "$kind" = tool ]; then
        for key in vendor_url specialist expert_skill inventory_source; do
          printf '%s\n' "$fm" | grep -Eq "^${key}:" || problem "$id" "pack.md frontmatter is missing '$key:' (required for a tool pack)"
        done
      fi
    fi
  fi
  [ -n "$kind" ] || kind=tool

  km="$dir/references/knowledge.md"
  evm="$dir/references/evals.md"
  invf="$dir/references/inventory.txt"

  # ------------------------------------------------------------ required files
  for f in "$dir/pack.md" "$km" "$evm"; do
    [ -f "$f" ] || problem "$id" "missing ${f#"$dir"/}"
  done
  if [ "$kind" = tool ]; then
    [ -f "$invf" ] || problem "$id" "missing references/inventory.txt (required for a tool pack)"
    [ -f "$dir/policy.tsv" ] || problem "$id" "missing policy.tsv (required for a tool pack)"
    [ -f "$dir/tests.tsv" ] || problem "$id" "missing tests.tsv (required for a tool pack)"
  else
    [ -f "$invf" ] && problem "$id" "references/inventory.txt exists on a guide pack, which has no single tool to inventory"
  fi

  # --------------------------------------------------------- knowledge.md
  if [ -f "$km" ]; then
    headings=$(grep -E '^## ' "$km")
    if [ "$kind" = tool ]; then
      required='## Mental model
## Connecting and auth
## Tool map
## Workflows for Launchhouse jobs
## Limits and quotas
## Failure modes and fixes
## Rules that apply here
## Sources
## Refreshing this pack'
    else
      required='## Mental model
## What Claude can do and what it needs first
## Workflows for Launchhouse jobs
## Limits and gotchas
## Failure modes and fixes
## Rules that apply here
## Never
## Sources
## Refreshing this pack'
    fi
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
      while IFS='	' read -r kind_line a b; do
        if [ "$kind_line" = MISSING ]; then
          problem "$id" "references/knowledge.md is missing the heading '$a'"
        fi
      done < "$headings_tmp"
      prev=0
      out_of_order=0
      while IFS='	' read -r kind_line a b; do
        [ "$kind_line" = POS ] || continue
        if [ "$a" -lt "$prev" ]; then out_of_order=1; fi
        prev=$a
      done < "$headings_tmp"
      [ "$out_of_order" = 1 ] && problem "$id" "references/knowledge.md's required headings are not in the required order"
    fi
    rm -f "$headings_tmp"

    # ---------------------------------------------------- inventory cross-check
    if [ "$kind" = tool ] && [ -f "$invf" ]; then
      inv=$(awk '!/^#/ && NF { print $1 }' "$invf")

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
          problem "$id" "Tool map names \`$t\`, which is not in references/inventory.txt"
      done

      # Any other backticked token in knowledge.md, policy.tsv or tests.tsv
      # that MATCHES THIS PACK'S OWN suffix_regex (so it is tool-shaped for
      # this pack specifically, not just alnum-and-hyphen) but that
      # inventory.txt does not carry.
      pack_suffix_regex=$(registry_rows | awk -F '\t' -v id="$id" '$1 == id { print $4; exit }')
      all_backticked=$( { grep -o '`[^`]*`' "$km" "$dir/policy.tsv" "$dir/tests.tsv" 2>/dev/null; } | sed 's/^[^:]*:`/`/; s/^`//; s/`$//' )
      bt_tmp=$(lh_mktemp)
      if [ -n "$pack_suffix_regex" ] && [ "$pack_suffix_regex" != "-" ]; then
        printf '%s\n' "$all_backticked" | while IFS= read -r t; do
          [ -n "$t" ] || continue
          case $t in *[!A-Za-z0-9_-]*) continue ;; esac
          printf '%s\n' "$t" | grep -Eq -- "$pack_suffix_regex" || continue
          printf '%s\n' "$inv" | grep -qxF -- "$t" || \
            printf 'the tool-shaped token `%s` in references/knowledge.md/policy.tsv/tests.tsv is not in references/inventory.txt\n' "$t"
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
  if [ -f "$evm" ]; then
    n=$(grep -Ec '^### ' "$evm")
    [ "$n" -ge 8 ] || problem "$id" "references/evals.md has only $n scenario(s) (### headings); needs at least 8"
    gr=$(grep -Ec '^### .*\(guard rail\)' "$evm")
    [ "$gr" -ge 3 ] || problem "$id" "references/evals.md has only $gr scenario(s) tagged '(guard rail)'; needs at least 3"
  fi

  # ----------------------------------------------------- skills/agents/scripts
  if [ -f "$dir/pack.md" ] && [ "$fm" != NOFRONT ] && [ -n "${fm:-}" ]; then
    listed_skills=$(lh_fm_list "$fm" skills)
    listed_agents=$(lh_fm_list "$fm" agents)
    listed_scripts=$(lh_fm_list "$fm" scripts)

    on_disk_skills=""
    [ -d "$dir/skills" ] && on_disk_skills=$(find "$dir/skills" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sort)
    on_disk_agents=""
    [ -d "$dir/agents" ] && on_disk_agents=$(find "$dir/agents" -mindepth 1 -maxdepth 1 -name '*.md' -exec basename {} .md \; 2>/dev/null | sort)
    on_disk_scripts=""
    [ -d "$dir/scripts" ] && on_disk_scripts=$(find "$dir/scripts" -mindepth 1 -maxdepth 1 -name '*.sh' -exec basename {} \; 2>/dev/null | sort)

    # Every skill, agent and script name, whether pack.md names it or it was
    # simply found on disk, must satisfy the slug grammar before anything
    # below builds a path out of it: these names are exactly what
    # --install and --adopt later splice into .claude/skills/<name>/ and
    # .claude/agents/<name>.md.
    lh_require_slug_list "pack.md's skill name" "$listed_skills"
    lh_require_slug_list "pack.md's agent name" "$listed_agents"
    lh_require_slug_list "pack.md's script name" "$listed_scripts" script
    lh_require_slug_list "the skills/ directory name" "$on_disk_skills"
    lh_require_slug_list "the agents/ directory name" "$on_disk_agents"
    lh_require_slug_list "the scripts/ directory name" "$on_disk_scripts" script

    cross_tmp=$(lh_mktemp)
    : > "$cross_tmp"
    printf '%s\n' "$listed_skills" | while IFS= read -r s; do
      [ -n "$s" ] || continue
      [ -f "$dir/skills/$s/SKILL.md" ] || printf 'pack.md lists skill '"'"'%s'"'"', but skills/%s/SKILL.md does not exist\n' "$s" "$s"
    done >> "$cross_tmp"
    printf '%s\n' "$on_disk_skills" | while IFS= read -r s; do
      [ -n "$s" ] || continue
      printf '%s\n' "$listed_skills" | grep -qxF -- "$s" || printf 'skills/%s/SKILL.md exists but is not listed in pack.md'"'"'s skills:\n' "$s"
    done >> "$cross_tmp"

    printf '%s\n' "$listed_agents" | while IFS= read -r a; do
      [ -n "$a" ] || continue
      [ -f "$dir/agents/$a.md" ] || printf 'pack.md lists agent '"'"'%s'"'"', but agents/%s.md does not exist\n' "$a" "$a"
    done >> "$cross_tmp"
    printf '%s\n' "$on_disk_agents" | while IFS= read -r a; do
      [ -n "$a" ] || continue
      printf '%s\n' "$listed_agents" | grep -qxF -- "$a" || printf 'agents/%s.md exists but is not listed in pack.md'"'"'s agents:\n' "$a"
    done >> "$cross_tmp"

    printf '%s\n' "$listed_scripts" | while IFS= read -r sc; do
      [ -n "$sc" ] || continue
      [ -f "$dir/scripts/$sc" ] || printf 'pack.md lists script '"'"'%s'"'"', but scripts/%s does not exist\n' "$sc" "$sc"
    done >> "$cross_tmp"
    printf '%s\n' "$on_disk_scripts" | while IFS= read -r sc; do
      [ -n "$sc" ] || continue
      printf '%s\n' "$listed_scripts" | grep -qxF -- "$sc" || printf 'scripts/%s exists but is not listed in pack.md'"'"'s scripts:\n' "$sc"
    done >> "$cross_tmp"

    if [ -s "$cross_tmp" ]; then
      while IFS= read -r line; do problem "$id" "$line"; done < "$cross_tmp"
    fi
    rm -f "$cross_tmp"
  fi
}

# Skill and agent names must be unique across every registered pack, and
# must not collide with a skill or agent that lives outside any pack. Run
# once, against the whole registry, regardless of which id --validate was
# asked for: uniqueness is a property of the registry as a whole, not of one
# pack in isolation.
validate_uniqueness() {
  skills_seen=$(lh_mktemp)
  agents_seen=$(lh_mktemp)
  : > "$skills_seen"
  : > "$agents_seen"
  for pid in $(registry_ids); do
    pdir="$packs_dir/$pid"
    [ -f "$pdir/pack.md" ] || continue
    pfm=$(lh_frontmatter "$pdir/pack.md")
    [ "$pfm" != NOFRONT ] && [ -n "$pfm" ] || continue
    lh_fm_list "$pfm" skills | while IFS= read -r s; do
      [ -n "$s" ] || continue
      printf '%s\t%s\n' "$s" "$pid" >> "$skills_seen"
    done
    lh_fm_list "$pfm" agents | while IFS= read -r a; do
      [ -n "$a" ] || continue
      printf '%s\t%s\n' "$a" "$pid" >> "$agents_seen"
    done
  done

  dup_tmp=$(lh_mktemp)
  awk -F '\t' '{ c[$1]++; if (c[$1] == 1) { first[$1] = $2 } else { print $1 "\t" first[$1] "\t" $2 } }' "$skills_seen" > "$dup_tmp"
  while IFS='	' read -r name pack1 pack2; do
    [ -n "$name" ] || continue
    problem "$pack1" "skill '$name' is also claimed by pack '$pack2'; skill names must be unique across every pack (recommend prefixing with '<id>-')"
  done < "$dup_tmp"
  awk -F '\t' '{ c[$1]++; if (c[$1] == 1) { first[$1] = $2 } else { print $1 "\t" first[$1] "\t" $2 } }' "$agents_seen" > "$dup_tmp"
  while IFS='	' read -r name pack1 pack2; do
    [ -n "$name" ] || continue
    problem "$pack1" "agent '$name' is also claimed by pack '$pack2'; agent names must be unique across every pack (recommend prefixing with '<id>-')"
  done < "$dup_tmp"
  rm -f "$dup_tmp"

  # A pack's skill or agent name must not collide with something outside
  # any pack: a top-level .claude/skills/<name> or .claude/agents/<name>.md
  # this --install would never have written (no marker line) and that no
  # pack claims.
  while IFS='	' read -r name pid; do
    [ -n "$name" ] || continue
    f="$root/.claude/skills/$name/SKILL.md"
    [ -f "$f" ] || continue
    mk=$(lh_installed_marker "$f")
    case $mk in
      *"skill-packs/$pid/"*) : ;;
      *) problem "$pid" "skill '$name' collides with an installed copy this pack does not own ($f)" ;;
    esac
  done < "$skills_seen"
  while IFS='	' read -r name pid; do
    [ -n "$name" ] || continue
    f="$root/.claude/agents/$name.md"
    [ -f "$f" ] || continue
    mk=$(lh_installed_marker "$f")
    case $mk in
      *"skill-packs/$pid/"*) : ;;
      *) problem "$pid" "agent '$name' collides with an installed copy this pack does not own ($f)" ;;
    esac
  done < "$agents_seen"

  rm -f "$skills_seen" "$agents_seen"
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
  validate_uniqueness
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

  registry_rows | while IFS='	' read -r lhwc_id lhwc_name lhwc_kind lhwc_suffix_regex lhwc_tracks lhwc_origin; do
    [ -n "$lhwc_id" ] || continue
    # A guide pack's suffix_regex is "-": no connector to detect a tool
    # suffix against, so it is never a candidate row here. This is the only
    # way a guide pack's row differs from a tool pack's in the compiled
    # output; everything else below is unchanged from before packs carried
    # their own skills and agents.
    [ "$lhwc_suffix_regex" != "-" ] || continue
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
    printf '# GENERATED by skill-packs.sh --compile from registry.tsv and every pack'"'"'s\n'
    printf '# policy.tsv + policy.local.tsv. Do not hand-edit: run\n'
    printf '# sh .claude/scripts/skill-packs.sh --compile again instead. Sourced by\n'
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
    printf 'compiled-policy.sh is stale; run: sh .claude/scripts/skill-packs.sh --compile\n'
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

  work=${TMPDIR:-/tmp}/lh-skillpack-test.$$
  trap 'rm -rf "$work"' EXIT
  mkdir -p "$work/.claude" "$work/growth-engine" || exit 1
  cp -R "$here" "$work/.claude/scripts"
  cp -R "$packs_dir" "$work/.claude/skill-packs"
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
    printf '\nAll skill-pack tests passed.\n'
  else
    printf '\nSome skill-pack tests failed.\n'
  fi
  exit $tfail
}

# --------------------------------------------------------------------- list
cmd_list() {
  printf 'id\tname\tkind\torigin\tinstalled\n'
  registry_rows | while IFS='	' read -r id name kind suffix_regex tracks origin; do
    [ -n "$id" ] || continue
    installed=no
    [ -f "$packs_dir/$id/pack.md" ] && installed=yes
    printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$name" "$kind" "$origin" "$installed"
  done
}

# ------------------------------------------------------------------ install
# The marker line a pack's own skill or agent gets, as the first line right
# after its frontmatter's closing ---, wherever --install writes it.
lh_marker_for() { # rel_src_path (e.g. skill-packs/ghl/skills/ghl-expert/SKILL.md)
  printf '%s.claude/%s%s' "$lh_marker_prefix" "$1" "$lh_marker_suffix"
}

# The marker line of an already-installed file, if it carries one as the
# first line after its frontmatter. Empty (and failure) if it does not.
lh_installed_marker() { # dest path
  awk '
    NR == 1 && $0 !~ /^---[ \t]*$/ { exit }
    NR == 1 { infm = 1; next }
    infm && /^---[ \t]*$/ { infm = 0; getline nextline; if (nextline ~ /^<!-- Installed from /) { print nextline }; exit }
    infm { next }
  ' "$1" 2>/dev/null
}

# Prints what --install would write for one source file, marker inserted as
# the first line after the frontmatter's closing ---.
lh_produce_installed() { # src_path, marker_text
  src=$1; marker=$2
  awk -v marker="$marker" '
    NR == 1 && $0 !~ /^---[ \t]*$/ { print; nofront = 1; next }
    NR == 1 { print; infm = 1; next }
    infm && /^---[ \t]*$/ { print; if (!nofront) print marker; infm = 0; next }
    { print }
  ' "$src"
}

# Installs (or refuses to overwrite) one source file at one destination.
# Returns 0 on install or already-matching, 1 on a refusal.
lh_install_one() { # pack_id, rel_src (relative to .claude/, for the marker), src_abs, dest_abs
  ii_pid=$1; ii_rel=$2; ii_src=$3; ii_dest=$4
  lh_refuse_symlink_path "$root/.claude" "$ii_src"
  lh_refuse_symlink_path "$root/.claude" "$ii_dest"
  [ -f "$ii_src" ] || { problem "$ii_pid" "pack.md names $ii_rel, but that file does not exist"; return 1; }
  ii_marker=$(lh_marker_for "$ii_rel")
  ii_produced=$(lh_mktemp)
  lh_produce_installed "$ii_src" "$ii_marker" > "$ii_produced"
  if [ -f "$ii_dest" ]; then
    if diff -q "$ii_produced" "$ii_dest" >/dev/null 2>&1; then
      printf 'unchanged  %s\n' "${ii_dest#"$root"/}"
      return 0
    fi
    printf 'REFUSED  %s  differs from what the pack would produce. Pack source: %s. Run --adopt %s to take the installed copy'"'"'s own changes back into the pack, or remove the installed copy and re-run --install.\n' \
      "${ii_dest#"$root"/}" "${ii_src#"$root"/}" "$ii_pid"
    fail=1
    return 1
  fi
  mkdir -p "$(dirname "$ii_dest")" 2>/dev/null
  cp "$ii_produced" "$ii_dest"
  printf 'installed  %s\n' "${ii_dest#"$root"/}"
  return 0
}

install_pack() { # id
  ip_id=$1
  lh_require_slug "pack id" "$ip_id"
  ip_dir="$packs_dir/$ip_id"
  lh_refuse_symlink_path "$packs_dir" "$ip_dir"
  [ -f "$ip_dir/pack.md" ] || { problem "$ip_id" "pack directory missing or has no pack.md"; return 1; }
  ip_fm=$(lh_frontmatter "$ip_dir/pack.md")
  [ "$ip_fm" != NOFRONT ] && [ -n "$ip_fm" ] || { problem "$ip_id" "pack.md has no frontmatter to install from"; return 1; }
  ip_skills=$(lh_mktemp)
  ip_agents=$(lh_mktemp)
  lh_fm_list "$ip_fm" skills > "$ip_skills"
  lh_fm_list "$ip_fm" agents > "$ip_agents"
  lh_require_slug_list "pack.md's skill name" "$(cat "$ip_skills")"
  lh_require_slug_list "pack.md's agent name" "$(cat "$ip_agents")"
  while IFS= read -r s; do
    [ -n "$s" ] || continue
    lh_install_one "$ip_id" "skill-packs/$ip_id/skills/$s/SKILL.md" \
      "$ip_dir/skills/$s/SKILL.md" "$root/.claude/skills/$s/SKILL.md"
  done < "$ip_skills"
  while IFS= read -r a; do
    [ -n "$a" ] || continue
    lh_install_one "$ip_id" "skill-packs/$ip_id/agents/$a.md" \
      "$ip_dir/agents/$a.md" "$root/.claude/agents/$a.md"
  done < "$ip_agents"
  rm -f "$ip_skills" "$ip_agents"
  return 0
}

cmd_install() {
  want=${1:-all}
  if [ "$want" = all ]; then
    ids=$(registry_ids)
  else
    ids=$want
  fi
  [ -n "$ids" ] || { echo "no packs to install (registry.tsv is empty)"; exit 0; }
  for id in $ids; do install_pack "$id"; done
  exit $fail
}

# -------------------------------------------------------------------- adopt
cmd_adopt() {
  aid=${1:-}
  [ -n "$aid" ] || { echo "usage: skill-packs.sh --adopt <id>" >&2; exit 2; }
  lh_require_slug "pack id" "$aid"
  adir="$packs_dir/$aid"
  lh_refuse_symlink_path "$packs_dir" "$adir"
  [ -f "$adir/pack.md" ] || { echo "$aid: pack directory missing or has no pack.md"; exit 1; }
  afm=$(lh_frontmatter "$adir/pack.md")
  [ "$afm" != NOFRONT ] && [ -n "$afm" ] || { echo "$aid: pack.md has no frontmatter"; exit 1; }
  lh_require_slug_list "pack.md's skill name" "$(lh_fm_list "$afm" skills)"
  lh_require_slug_list "pack.md's agent name" "$(lh_fm_list "$afm" agents)"

  adopt_one() { # src_abs, dest_abs, label
    ao_src=$1; ao_dest=$2; ao_label=$3
    lh_refuse_symlink_path "$root/.claude" "$ao_src"
    lh_refuse_symlink_path "$root/.claude" "$ao_dest"
    if [ ! -f "$ao_dest" ]; then
      printf 'skip  %s  nothing installed to adopt\n' "$ao_label"
      return 0
    fi
    # Strip a marker line only if it is the first line after the
    # frontmatter's closing ---; anything else in the installed copy is the
    # founder's own change, kept exactly.
    awk '
      NR == 1 && $0 !~ /^---[ \t]*$/ { print; nofront = 1; next }
      NR == 1 { print; infm = 1; next }
      infm && /^---[ \t]*$/ {
        print; infm = 0
        if ((getline nextline) > 0) {
          if (nextline !~ /^<!-- Installed from /) print nextline
        }
        next
      }
      { print }
    ' "$ao_dest" > "$ao_src.adopt.$$"
    mv "$ao_src.adopt.$$" "$ao_src"
    printf 'adopted  %s -> %s\n' "$ao_label" "${ao_src#"$root"/}"
  }

  lh_fm_list "$afm" skills | while IFS= read -r s; do
    [ -n "$s" ] || continue
    adopt_one "$adir/skills/$s/SKILL.md" "$root/.claude/skills/$s/SKILL.md" "skill $s"
  done
  lh_fm_list "$afm" agents | while IFS= read -r a; do
    [ -n "$a" ] || continue
    adopt_one "$adir/agents/$a.md" "$root/.claude/agents/$a.md" "agent $a"
  done
}

# -------------------------------------------------------------- check-installed
cmd_check_installed() {
  ci_fail=0
  ci_collect=$(lh_mktemp)
  for id in $(registry_ids); do
    dir="$packs_dir/$id"
    [ -f "$dir/pack.md" ] || continue
    fm=$(lh_frontmatter "$dir/pack.md")
    [ "$fm" != NOFRONT ] && [ -n "$fm" ] || continue
    lh_fm_list "$fm" skills | while IFS= read -r s; do
      [ -n "$s" ] || continue
      src="$dir/skills/$s/SKILL.md"
      dest="$root/.claude/skills/$s/SKILL.md"
      [ -f "$src" ] || continue
      marker=$(lh_marker_for "skill-packs/$id/skills/$s/SKILL.md")
      produced=$(lh_mktemp)
      lh_produce_installed "$src" "$marker" > "$produced"
      if [ ! -f "$dest" ]; then
        printf 'missing  %s\n' "${dest#"$root"/}"
        echo ci_fail_marker
      elif ! diff -q "$produced" "$dest" >/dev/null 2>&1; then
        printf 'drifted  %s\n' "${dest#"$root"/}"
        echo ci_fail_marker
      fi
    done
    lh_fm_list "$fm" agents | while IFS= read -r a; do
      [ -n "$a" ] || continue
      src="$dir/agents/$a.md"
      dest="$root/.claude/agents/$a.md"
      [ -f "$src" ] || continue
      marker=$(lh_marker_for "skill-packs/$id/agents/$a.md")
      produced=$(lh_mktemp)
      lh_produce_installed "$src" "$marker" > "$produced"
      if [ ! -f "$dest" ]; then
        printf 'missing  %s\n' "${dest#"$root"/}"
        echo ci_fail_marker
      elif ! diff -q "$produced" "$dest" >/dev/null 2>&1; then
        printf 'drifted  %s\n' "${dest#"$root"/}"
        echo ci_fail_marker
      fi
    done
  done > "$ci_collect" 2>&1
  grep -v '^ci_fail_marker$' "$ci_collect"
  grep -q '^ci_fail_marker$' "$ci_collect" && ci_fail=1
  rm -f "$ci_collect"
  if [ "$ci_fail" = 0 ]; then
    printf 'Every pack skill and agent is installed and matches its pack.\n'
  fi
  exit $ci_fail
}

case ${1:-} in
  --validate) cmd_validate "${2:-all}" ;;
  --compile) cmd_compile ;;
  --check-compiled) cmd_check_compiled ;;
  --test) cmd_test "${2:-all}" ;;
  --list) cmd_list ;;
  --install) cmd_install "${2:-all}" ;;
  --adopt) cmd_adopt "${2:-}" ;;
  --check-installed) cmd_check_installed ;;
  *)
    echo "usage: skill-packs.sh --validate <id|all> | --compile | --check-compiled | --test <id|all> | --list | --install <id|all> | --adopt <id> | --check-installed" >&2
    exit 2
    ;;
esac
