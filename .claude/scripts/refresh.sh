#!/bin/sh
# Rebuilds the index and the gate state when anything under growth-engine has
# changed. Cheap enough to run after every tool call: index.sh only writes when
# the table really changed, and gate-state.sh stops straight away when nothing
# under growth-engine is newer than the state it already wrote.
#
# This runs after every tool, not only after the editing tools, because a change
# made with a shell command used to leave the state stale. That really happened:
# the ledger said 30 approved while the index still said none.

. "$(dirname "$0")/lib.sh" 2>/dev/null || exit 0
lh_active || exit 0
here=$(dirname "$0")
sh "$here/index.sh" >/dev/null 2>&1
sh "$here/gate-state.sh" >/dev/null 2>&1
exit 0
