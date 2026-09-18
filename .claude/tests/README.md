# Checks on the checks

These are small test files. Each one is a few lines of markdown that the write
checks should either let through or hold.

To run them, from this folder:

    sh .claude/tests/run.sh

It prints pass or fail for each file and says at the end whether they all
passed.

A file named `pass-...` must not be held. A file named `hold-...` must still be
held. The first line of each file says which rule it is about and which track to
read it on.

## The state checks

`state.sh` is a different kind of check. It builds a made up founder folder in
the temp folder, runs the state scripts over it, and prints pass or fail for
each thing it expects to see: the gates counted right, a question waiting on the
founder, a change made with a shell command picked up, an engine parked and
picked up again, and the end of turn check speaking once and then staying quiet.

To run it, from this folder:

    sh .claude/tests/state.sh

It never touches a founder's own growth-engine folder.
