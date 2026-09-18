# The computed state

One file answers "where is this founder up to". Everything else reads it instead
of counting for itself, so the session header, the end of turn check, the status
skill and the gate skill can never disagree.

## Where it is

`growth-engine/.state/gate-state.md`

It is rebuilt from the folder. Never edit it, and never write anything a founder
typed into it. If it is missing, the folder has not been set up yet, or the
founder is looking at a cloud copy of it.

## What it holds

A short header, then one row per gate item for this founder's track only.

```
Computed: 2026-09-17 17:15
Newest change: growth-engine/engines/content/content-30.md, 2026-09-17 16:02
Stamp: 2317745611-1204
Track: b2b
Engine in progress: content
Paused: ops

Gate A: 5 of 5 done
Gate B: 3 of 5 done
Gate C: 5 of 6 done

| gate | key | item | state | evidence | engine |
|---|---|---|---|---|---|
| B | approved | The pieces have been read and approved | not done | 29 of 30 approved in ledger.md | content |

| engine | needs | state |
|---|---|---|
| outreach | B | locked |
```

- **gate** is A, B or C.
- **key** is the stable name for the item. Match on this, never on the wording.
- **state** is one of:
  - `done` - the files prove it
  - `not done` - the files do not prove it
  - `ask` - waiting on the founder, nothing in the folder can prove it
  - `answered` - the founder answered it, and their answer is the evidence
  - `unknown` - the file is kept off GitHub and is not in this copy of the
    folder, so nothing here can say either way. Never counted as done
  - `not due` - it is not owed yet, like the B2C sends before the Saturday
- **evidence** is the short fact that decided it, with a count where there is one.
- **engine** is the engine the item belongs to: `brain`, `content`, `outreach`,
  `audience`, `ops` or `plan`.

Below the item table is a second table, one row per engine on this founder's
track, with the gate it needs (from the mapping in `gates.md`) and its own
state: `done`, `overridden` or `locked` (`none` for the Brain, which needs no
gate). An engine skill reads its own row here to decide whether it starts.

## Gate lock and override

The gates are a guardrail, not paperwork. An engine whose gate is not met does
not start on its own. The engine skill says in one or two plain sentences what
is missing, using that gate's `not done` rows, and offers to do that first. If
the founder says to go ahead anyway, the engine records an override and runs.

An override is recorded as a dated line in
`growth-engine/.state/gate-overrides.md`, one line each:

```
2026-09-17 | A | content | Let's just get started, I will fill the brain in later
```

Date, then the gate, then the engine, then the founder's own words. It is
never evidence that the gate itself is met: `gate-state.md` still reports the
gate's items exactly as the files show them. It only changes that one
engine's row in the engine table, from `locked` to `overridden`. Saying yes to
run content anyway never unlocks outreach, audience or ops, and never touches
the gate for another founder or another engine.

`Computed` and `Newest change` say when it was worked out and the newest file it
looked at. If `Newest change` is older than a file you just wrote, the state is
stale: run the refresh script below. `Stamp` is how the scripts themselves tell:
it covers when every file under `growth-engine` last changed and how big it is,
so a file rewritten or deleted in the same second is still caught. It counts the
answer files under `.state/` too, so recording an answer rebuilds the state; the
only files left out are the two this script writes itself, `gate-state.md` and
`index.md`.

## The keys

Gate A: `brain-locked`, `track-chosen`, `thesis`, `voice`, `flags`.

Gate B: `pieces`, `sheet`, `refill`, `approved`, `sounds-like`.

Gate C, B2B: `sequence`, `criteria`, `list`, `firstlines`, `workflow`, `domain`.

Gate C, B2C: `openers`, `targets`, `hooks`, `inbound`, `workflow`, `account`,
`sends`.

With no track chosen there is one Gate C row, `track-first`, and neither track's
items are listed.

## How a skill or an agent should read it

1. Read `growth-engine/.state/gate-state.md`. Do not count pieces, rows, people
   or approvals yourself, and do not ask the `status-checker` agent to count
   again when this file already says.
2. Use the `state` column as it stands. An item at `not done` is not done, even
   if the founder says it is.
3. Quote the `evidence` column when telling the founder what is missing. It is
   already short and already plain.
4. Only ask about an item at `ask`. Record the answer as described below, then
   read the file again.

## Self-reported answers

An answer is never evidence. Answers live in
`growth-engine/.state/gate-answers.md`, one line each, newest line wins:

```
2026-09-17 | flags | Domain is three weeks old, SPF set, DKIM going in today
```

Date, then the key, then what they said. A leading pipe is fine, so a markdown
table row works too. Write the answer, then rebuild the state.

## Parking an engine

A founder can say "park this" and the engine is put down. Nothing asks them
about it again until they pick it up. That is recorded in
`growth-engine/.state/paused.md`:

```
2026-09-17 | content | paused
2026-09-18 | content | running
```

Newest line wins, and the header of the state file lists what is parked. The
hook on every message catches the plain words, so a skill does not have to. To
do it from a skill:

```
sh .claude/scripts/park.sh pause  content
sh .claude/scripts/park.sh resume content
```

With no engine named it uses the engine in progress. Never tell the founder to
run either of these: they do not use a terminal.

## The scripts behind it

| Script | When it runs | What it does |
|---|---|---|
| `gate-state.sh` | after any tool, and at session start | works the state out and writes `gate-state.md`. Stops straight away if nothing under `growth-engine` has changed. `--force` rebuilds anyway |
| `index.sh` | same | rebuilds `.state/index.md`, the file counts the state is built from |
| `refresh.sh` | after every tool call | runs both of the above. It runs after every tool, not only after the editing tools, so a change made with a shell command cannot leave the state stale |
| `state-block.sh` | session start, and every message | prints the short block Claude sees: track, gates, what is made, what is next |
| `turn-end.sh` | end of every turn | one line on what the engine in progress still needs, once per engine, never blocking. What it has said is in `.state/nudges.md` |
| `park.sh` | when the founder parks or picks up an engine | writes `.state/paused.md` |

## Checking it still works

`sh .claude/tests/state.sh` builds a made up folder in the temp folder, runs the
scripts over it, and prints pass or fail for each thing it expects. It never
touches a founder's own folder.

## What never happens here

- No file under `.state/` holds a real person's name, email or handle.
- `gate-state.md` and `nudges.md` are kept out of git. They are worked out
  from the folder, so a second computer rebuilds them in seconds rather than
  pulling a conflict on a file nobody may edit.
- `index.md` stays in git, still rebuilt automatically and never hand-edited.
  The cloud routines (`countdown.md`, `monday-plan.md`) read it from the
  founder's GitHub copy, and it is the only source for the people count once
  there, because `people/` itself never goes to GitHub. It carries no date, so
  a fresh copy opens clean and it only changes when the founder's own work
  changes.
- Nothing in here counts replies.
- Nothing in here lists the other track's items.
- An override in `gate-overrides.md` never marks a gate itself as met, and
  never unlocks any engine beyond the one it names.
