#!/bin/sh
# SessionStart (startup/resume/clear only, called by context.sh, never on
# compact). Also run in full by the help skill for "check my setup".
#
# Checks that this computer, this folder and its settings are ready to run
# Launchhouse, and prints nothing when everything is fine: silence is the
# normal case, every turn, for every founder. When something is wrong it
# prints one plain line per problem, addressed to Claude, not the founder:
# "mention this once, in plain words, and offer to fix it." Claude reads that
# line and does the talking; this script never talks to the founder itself.
#
# Fails open like every other hook here: any doubt (git missing, the folder
# not a git repo, a file that cannot be read) and the check for that one item
# is simply skipped, never guessed at.
#
# Usage:
#   sh setup-check.sh [session_id]          normal mode, say-it-once per
#                                            session_id, called from context.sh
#   sh setup-check.sh --full [session_id]   the help skill's "check my setup":
#                                            ignores the say-it-once sentinel
#                                            and always prints something, an
#                                            all-clear line when nothing is wrong
#
# session_id comes from the SessionStart hook's own JSON on stdin. context.sh
# reads it carefully, only when stdin is not a terminal, so a manual run of
# this script or of the test suite never blocks waiting on one. Empty is fine:
# it just means this run's notices are not deduplicated against another.

. "$(dirname "$0")/lib.sh" 2>/dev/null || exit 0

full=0
if [ "$1" = --full ]; then
  full=1
  shift
fi
session_id=$1

root=$(lh_root)

# ---------------------------------------------------------------- say once --
# One sentinel file per session_id, under .git/launchhouse/ (never committed,
# never under growth-engine/), holding one line per notice kind already said
# this session: setup, cloud, connectors-ghl, connectors-b2b. --full ignores
# it entirely, because a founder who just asked "check my setup" wants the
# real answer, not silence because a hook already said it once already.
bk=$(lh_bk_dir 2>/dev/null)
seen_file=""
if [ "$full" = 0 ] && [ -n "$bk" ]; then
  mkdir -p "$bk/setup-seen" 2>/dev/null
  key=$(printf '%s' "${session_id:-none}" | cksum | awk '{ print $1 }')
  seen_file="$bk/setup-seen/$key"
fi
lh_setup_seen() {
  [ -n "$seen_file" ] && [ -f "$seen_file" ] && grep -qx "$1" "$seen_file" 2>/dev/null
}
lh_setup_mark() {
  [ -n "$seen_file" ] && printf '%s\n' "$1" >> "$seen_file" 2>/dev/null
}

# ------------------------------------------------------------ cloud session --
# A cloud routine (CLAUDE_CODE_REMOTE=true): the founder's own computer, and
# their private lists (people, first lines, DM openers, never sent to
# GitHub), are not here, and anything saved lands on a side branch, not their
# real folder. Nothing else below applies, so say only this, once, and stop.
case ${CLAUDE_CODE_REMOTE-} in
  true|1)
    if [ "$full" = 1 ] || ! lh_setup_seen cloud; then
      printf 'Setup: this is a cloud session. The files on the founder'"'"'s own computer, and their private lists (people, first lines, DM openers), are not here, and anything saved lands on a side branch rather than their real folder. Mention this once, in plain words, and suggest their own computer for engine work.\n'
      lh_setup_mark cloud
    fi
    exit 0
    ;;
esac

problems=""
add_problem() {
  problems="$problems$1
"
}

# --------------------------------------------------------------------- git --
have_git=1
command -v git >/dev/null 2>&1 || have_git=0

if [ "$have_git" = 0 ]; then
  add_problem 'Setup: git is not installed on this computer, so Launchhouse cannot save work or run its checks. Mention this once, in plain words, and offer to walk them through installing it: Git for Windows from git-scm.com on a Windows PC, or the developer tools prompt Xcode offers on a Mac.'
else
  is_repo=0
  [ -d "$root/.git" ] || [ -f "$root/.git" ] && is_repo=1

  if [ "$is_repo" = 0 ]; then
    add_problem 'Setup: this folder is not saved with git yet, so nothing here is backed up or undoable. Mention this once, in plain words, and offer to set it up (git init), the way the start skill does.'
  else
    # One call for both keys, so a founder's own global config still counts
    # (only a test isolates it), and the check costs a single git process.
    identity=$(git -C "$root" config --get-regexp '^user\.(name|email)$' 2>/dev/null)
    name_set=0; email_set=0
    case $identity in *"user.name "*) name_set=1 ;; esac
    case $identity in *"user.email "*) email_set=1 ;; esac
    if [ "$name_set" = 0 ] || [ "$email_set" = 0 ]; then
      add_problem 'Setup: git does not have a name and email set for saving work in this folder, so saves may not be attributed to the founder. Mention this once, in plain words, and offer to set them from the name they gave you and the email you want on your saves.'
    fi

    # The public original every founder's copy comes from. Skip when an
    # untracked .git/launchhouse/maintainer file says this copy is meant to
    # stay pointed at it (the maintainer's own working copy).
    if [ -z "$bk" ] || [ ! -f "$bk/maintainer" ]; then
      origin=$(git -C "$root" config --get remote.origin.url 2>/dev/null)
      case $(printf '%s' "$origin" | LC_ALL=C tr 'A-Z' 'a-z') in
        *philm-moxywolf*)
          add_problem 'Setup: this folder'"'"'s origin still points at the public Launchhouse original (Philm-moxywolf), not the founder'"'"'s own copy, so saving here would never reach their own GitHub. Mention this once, in plain words, and offer to rename that remote to upstream and publish a fresh copy from GitHub Desktop, never a fork.'
          ;;
      esac
    fi

    # No copy on GitHub at all: no backup, no moving between computers, and
    # the scheduled routines cannot run against a folder that is not there.
    # Its own mention-once key, separate from "setup", so it still says its
    # piece even in a session that already reported (and dropped) another
    # setup problem. Suppressed entirely once the founder has said, through
    # the start skill, that they do not want a GitHub copy (an untracked
    # .git/launchhouse/no-github marker).
    if [ -z "$bk" ] || [ ! -f "$bk/no-github" ]; then
      remotes=$(git -C "$root" remote 2>/dev/null)
      if [ -z "$remotes" ] && { [ "$full" = 1 ] || ! lh_setup_seen no-github; }; then
        no_github_problem='Setup: this folder has no copy on GitHub yet, so there is no backup, it cannot move between computers, and the scheduled routines cannot run. Mention this once, in plain words, and offer to walk them through putting it on GitHub.'
        lh_setup_mark no-github
      fi
    fi
  fi
fi

# ------------------------------------------------------------ settings.json --
settings="$root/.claude/settings.json"
if [ ! -f "$settings" ]; then
  add_problem 'Setup: this folder has no .claude/settings.json, so none of the Launchhouse checks or the Launchhouse Guide voice are switched on. Mention this once, in plain words, and offer to run start launchhouse, which writes it.'
else
  ok_hooks=1; ok_style=1; ok_plugin=1
  grep -qF '"SessionStart"' "$settings" 2>/dev/null || ok_hooks=0
  grep -qF '"outputStyle": "Launchhouse Guide"' "$settings" 2>/dev/null || ok_style=0
  grep -qF '"growth-engine@launchhouse-v3": false' "$settings" 2>/dev/null || ok_plugin=0
  if [ "$ok_hooks" = 0 ] || [ "$ok_style" = 0 ] || [ "$ok_plugin" = 0 ]; then
    add_problem 'Setup: this folder'"'"'s .claude/settings.json is missing a piece Launchhouse needs (its checks, the Launchhouse Guide voice, or switching the old growth-engine plugin off), so behaviour may not match what the founder was told. Mention this once, in plain words, and offer to update the folder from the Launchhouse repository (fetch and pull in GitHub Desktop, then quit and reopen Claude).'
  fi
fi

# ------------------------------------------------------------------ scaffold --
if [ ! -f "$root/growth-engine/.launchhouse" ] || [ ! -f "$root/growth-engine/log/ledger.md" ]; then
  add_problem 'Setup: this folder does not have the growth-engine scaffold Launchhouse needs yet. Mention this once, in plain words, and offer to run start launchhouse.'
fi

# The "setup" notice is said once per session no matter what it finds, so a
# quiet first check is never followed by a noisier one later in the same
# session: resume and clear can each fire this hook again for a session that
# is already under way.
if [ "$full" = 1 ] || ! lh_setup_seen setup; then
  if [ -n "$problems" ]; then
    printf '%s' "$problems"
  elif [ "$full" = 1 ] && [ -z "$no_github_problem" ]; then
    printf 'Setup: checked git, this folder, the settings and the scaffold. Nothing wrong.\n'
  fi
  lh_setup_mark setup
fi

# The no-github notice has its own mention-once key (set above), so it still
# says its piece even in a session where the "setup" key was already marked
# by an earlier, unrelated problem (or by a clean check).
if [ -n "$no_github_problem" ]; then
  printf '%s\n' "$no_github_problem"
fi

# ------------------------------------------------------------- connectors --
# A connector can only be seen from inside the conversation, never by this
# script, so this just tells Claude to look, once, at the start of its own
# reply, and to mention only what the founder's track actually needs.
if lh_active; then
  if [ "$full" = 1 ] || ! lh_setup_seen connectors-ghl; then
    printf 'Connectors: at your first reply, use ToolSearch to look for a GoHighLevel tool in your own tool list (one ending execute_operation or list_locations, or the fallback'"'"'s locations_get-location). If none is found, mention it once, in plain words, and offer "connect my tools".\n'
    lh_setup_mark connectors-ghl
  fi
  track=$(lh_track)
  if [ "$track" = b2b ] && { [ "$full" = 1 ] || ! lh_setup_seen connectors-b2b; }; then
    printf 'Connectors: this founder is B2B, so also use ToolSearch for Apollo tools (apollo_) and a mailbox (Gmail or Microsoft 365 mail tools). If one their track needs is missing, mention it once, in plain words, and offer "connect my tools".\n'
    lh_setup_mark connectors-b2b
  fi
fi

exit 0
