---
name: gate
description: Produce the founder's gate submission, a short plain-text block to paste into the gate form, checked against their files rather than taken on their word. Trigger on "my gate submission", "gate form", "submit my gate", "what do I paste into the form", "gate A", "gate B", "gate C".
---

# Gate submission

**What this makes.** A short block the founder pastes into the Google Form for their gate. Mentors read it before the session. It has to be accurate, because a gate marked done that is not done is found on the day, when there is no time to fix it.

**Who is reading.** A founder who does not use a terminal. Never ask them to run a command.

## 1. Which gate

- If they named a gate, use it.
- Otherwise use the first gate that is not complete, checked in order A, B, C. Every programme date comes from the cohort block in `../../references/gates.md`, never from memory. Once a date there has passed, never announce it as though it is still ahead: say "your clinic session" or "the Saturday of your programme" instead, and check the gate the same way.
- If every gate is complete, say so, and ask which one they want a block for.
- If it is unclear, ask in one line.

## 2. Check the files

1. Read `growth-engine/.state/gate-state.md`, the computed state described in `../../references/state.md`, and use the rows for that gate. Do not count pieces, rows, people or approvals yourself, and do not ask the `status-checker` agent to count them again.
2. Take the `state` column as it stands. An item at `not done` is not done, even if the founder says it is.
3. Quote the `evidence` column when saying what is missing. It is already short and already plain.

## 3. Ask the self-reported items

For each item in that gate at `ask`:
- Ask it, one at a time.
- Record each new answer as a dated line in `growth-engine/.state/gate-answers.md`, then save it: `git add growth-engine` and `git commit -m "Gate answers"`.
- Read `growth-engine/.state/gate-state.md` again afterwards, so the block uses the rebuilt state.

## 4. The block

Keep it under 20 lines, so it pastes cleanly. Plain text, with no markdown symbols the form would show literally.

```
Launchhouse gate <A|B|C>, <date>
Founder: <name>. Business: <business>. Track: <b2b|b2c>.
Files: <file names that exist, comma separated>
<item>: DONE
<item>: NOT DONE, <what is missing in a few words>
<self-reported item>: <their answer>
Flags: <unresolved flags from the Brain, especially the domain for B2B or the Instagram account type for B2C, or none>
```

List only this founder's track's items. Never list the other track's.

## 5. Hand it over

1. Show the block in a code block, so it copies cleanly.
2. Print the **Gate form link** row from the cohort block in `../../references/gates.md` underneath it, so they do not have to go looking. While that row says `not recorded yet`, say plainly that the link comes from their mentor, and hand over the block anyway. Never guess a link, and never send the block anywhere for them.
3. If anything is NOT DONE, name the one thing to do first, and the words that start it.
4. End by naming the plain way to check where they stand at any time: say "where am I up to".
