---
name: gate
description: Read the computed gate report and say which items are met, which are not, and which engines are locked, overridden or clear to run. Agent-facing: the report every engine skill reads before it starts. Trigger on "gate A", "gate B", "gate C", "gate report", or when an engine skill needs to check its own gate.
---

# Gate report

**What this is.** The computed picture of where a founder stands against the three gates, read straight from `growth-engine/.state/gate-state.md`. Engine skills read it to decide whether they are locked, overridden or clear to run. There is no form and nothing here is submitted anywhere. A founder asking in plain words where they stand gets the fuller picture from the `status` skill: "where am I up to".

**Who is reading.** Mostly another skill or agent, checking a gate before it starts. If a founder asks for this directly, they do not use a terminal, so never ask them to run a command.

## 1. Which gate, and which engine

- If asked about one gate, use it. If asked on behalf of an engine, use the gate that engine needs, from the mapping in `../../references/gates.md`.
- Otherwise report all three, in order A, B, C.

## 2. Read the state, never count

1. Read `growth-engine/.state/gate-state.md`, the computed state described in `../../references/state.md`. Do not count pieces, rows, people or approvals yourself, and do not ask the `status-checker` agent to count them again.
2. Use the `state` column as it stands. An item at `not done` is not done, even if the founder says it is.
3. Quote the `evidence` column when saying what is missing. It is already short and already plain.
4. For an engine's own lock state, read its row in the engine table at the bottom of `gate-state.md`: `done`, `overridden` or `locked` (`none` for the Brain).

List only this founder's track's items. Never list the other track's.

## 3. Self-reported items

For an item at `ask`:
- Ask it, one at a time.
- Record each new answer as a dated line in `growth-engine/.state/gate-answers.md`.
- Rebuild the state with `sh .claude/scripts/refresh.sh`, then read `gate-state.md` again.

## 4. Reporting to a founder

If a founder asks to see this directly rather than through an engine, give the gate they asked about, or all three, as a short plain list: what is done, what is not, and the one thing to do next. Never write it as a block to paste anywhere, and never say it goes anywhere outside this conversation. Point them at "where am I up to" for the fuller picture, gate by gate and engine by engine.
