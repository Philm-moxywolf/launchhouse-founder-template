---
name: tool-pack-builder
description: Build or refresh a tool pack that makes Claude an expert on one tool the founder has connected, such as a CRM, a scheduler or a second inbox, beyond the four packs Launchhouse ships with. Trigger on "build a pack for", "make Claude an expert on", "I connected <tool>", "teach Claude <tool>", "refresh my <tool> pack", or when session context or a connector check says a connected tool has no expert pack yet.
---

# Tool pack builder

Turns one tool the founder has connected into a small, sourced knowledge pack, with a specialist, an expert skill, and deterministic guard tests, the same shape as the four packs Launchhouse ships with (GoHighLevel, Apollo, Gmail, Outlook).

**Who is reading this.** You, Claude. The founder never sees this skill's steps, never opens a terminal, and never runs a command. You run `sh .claude/scripts/tool-packs.sh ...` yourself, from inside this skill, and report the result in plain words.

**The line that does not move.** A pack you build can only make Claude more careful with a tool, never less. `policy.tsv` rows are `deny` or `ask` only. You can never write a row, or any other file in the pack, that lets a tool send to a real person, publish, bulk-send, spend or delete more freely than the six rules and `.claude/references/connections.md` already allow.

Read the full spec in `.claude/tool-packs/README.md` before the first pack you build in a session; it has the exact file shapes this skill fills in.

## 0. Check first

1. Read `.claude/tool-packs/registry.tsv`. If a row already exists for this tool (by name, not just id), say so and offer to refresh instead of building fresh. Refresh mode is steps 1 to 6 below, run again, then step 8 to show what changed; skip step 4 (no new registry row) unless the suffix set changed.
2. **Name the doubt.** In one line: connecting a tool to Claude, and now having Claude study it, can feel like handing over more keys than intended. Say plainly that this pack can only make Claude more careful with the tool, never less, and that nothing it writes can send, publish, spend or delete on its own.
3. **Ask what the founder wants it for**, with clickable choices (AskUserQuestion) where you can offer them, your best guess first: map their answer to Launchhouse jobs (publishing, outreach, list building, replies, scheduling, bookkeeping, or "something else" they name). If you cannot show choices, ask the same thing in plain text. This drives the `jobs` list in `pack.md` and the workflows section of `knowledge.md`.

## 1. Inventory

The tool must already be connected; a pack is never built from guesswork about tools nobody has seen.

1. Use ToolSearch to list the tools this connector exposes (search by the connector's likely name or `mcp__`). Read each tool's suffix: the part of its name after the last `__`.
2. If the connector is not there yet, tell the founder in plain words that it needs connecting first, and send them to `connect-tools` (or "connect my tools"). Stop here unless they ask you to work from vendor docs instead (documented mode): if so, mark every fact "documented", never "observed", and say plainly this pack has not been checked against the founder's own account yet.
3. Write `.claude/tool-packs/<id>/inventory.txt`, one suffix per line, headed by `# source: observed via ToolSearch <today>` or `# source: documented <url> checked <today>`. Pick `<id>` as a short lower-case word, a-z0-9 and hyphen only, from the tool's own name.

## 2. Research

Dispatch the `tool-researcher` agent with: the vendor name, the inventory list from step 1, and the jobs from step 0. It is read-only and returns sourced facts in a fixed shape; treat anything it did not source as unverified and never repeat it as fact.

## 3. Generate the pack

Copy `.claude/tool-packs/_template/` into `.claude/tool-packs/<id>/` and fill each file. Follow the exact shapes in `.claude/tool-packs/README.md` (headings, columns, tab-separated files). Do not invent a shape of your own.

- **`pack.md`** — frontmatter with `id`, `name`, `vendor_url`, `tracks`, `jobs` (from step 0), `job_skills` (existing skills this pack's jobs route to, or empty), `specialist: <id>-specialist`, `expert_skill: <id>-expert`, `inventory_source` (`observed` or `documented`), `verified_on: <today>`, `origin: local`. Sections: What it is for here, When to pick this route, Connecting, In Cowork, Changing this pack (say plainly: edit `policy.local.tsv`, never `policy.tsv`, and a local edit can only tighten).
- **`knowledge.md`** — the nine H2 headings from the README, in that exact order. The Tool map table holds every inventory tool exactly once, classed read, write, send or spend, and no tool outside the inventory appears anywhere in the file. Every fact in Limits, Failure modes and Sources comes from the researcher's sourced output; mark anything it could not source `(unverified)`.
- **`policy.tsv`** — one row per inventory tool that sends to a real person, publishes, bulk-sends, spends, deletes, or changes an automation: `deny` when the six rules or `connections.md`'s tiers rule it out outright (the same shapes CLAUDE.md and connections.md already deny for the shipped packs), `ask` otherwise. Reads need no row. `decision` is only `deny` or `ask`.
- **`tests.tsv`** — one test per policy row, plus at least one read tool expected `silent`.
- **`evals.md`** — at least 8 numbered scenarios, at least 3 of them refusals or guard-rail cases (a cold send, a spend, a bulk action, starting an automation, the other track's material).
- **`.claude/agents/<id>-specialist.md`** and **`.claude/skills/<id>-expert/SKILL.md`** — follow the README's contracts exactly (two-phase plan/execute for the specialist, with the `approve.sh` grant step described before `PHASE: execute`; connect, route, approve, grant, record, answer for the expert skill).
- **`.claude/commands/growth-engine/<id>.md`** — the one-line command shim shape.

## 4. Registry row

Append one row to `.claude/tool-packs/registry.tsv`: `id`, `name`, a `suffix_regex` built from the actual inventory suffixes (anchor it so it cannot also match a different vendor's tools, and never a bare generic verb like `^send` or `^get`), `tracks`, `origin local`.

## 5. Validate

Run, yourself, never asking the founder to:
```
sh .claude/scripts/tool-packs.sh --validate <id>
sh .claude/scripts/tool-packs.sh --compile
sh .claude/scripts/tool-packs.sh --test <id>
```
Fix what fails and re-run, at most twice more. If it is still failing after that, stop and tell the founder plainly, in one or two sentences, what is left broken and that the pack is not finished yet. Never mark a pack done while validation fails.

## 6. Second read

Use the `rules-reviewer` agent on `knowledge.md` and `evals.md`. Fix anything it holds before calling the pack finished.

## 7. Record the tool

Add or update a row for this tool in `growth-engine/.state/tools.md`, in the shape in `.claude/references/contract.md`: status `connected` or `verified`, with evidence that is only what a tool actually returned.

## 8. Save

`growth-engine/people/`, `outreach-firstlines.csv` and `dm-openers.md` hold real people and are never staged. Stage only the new pack paths: `.claude/tool-packs/<id>/`, `.claude/agents/<id>-specialist.md`, `.claude/skills/<id>-expert/SKILL.md`, `.claude/commands/growth-engine/<id>.md`, the updated `.claude/tool-packs/registry.tsv`, and `growth-engine/.state/tools.md`. Commit with a short plain message. Push if a remote exists and it is not under `Philm-moxywolf`.

## 9. Hand back

Tell the founder, in plain words, in this order:
1. What Claude now knows about the tool, in a sentence, not a file list.
2. What it will never do with it (the deny rows, said in plain words).
3. The one next thing to do, such as trying "how do I ... in <tool>" or the new expert skill by name.

## Refresh mode

When a pack already exists, re-run steps 1 to 6 (re-inventory, re-research, regenerate, re-validate, second read), then show the founder what changed: new tools, dropped tools, changed limits, changed policy rows. Never loosen a `policy.tsv` row on refresh, even if the vendor's own docs suggest it: a loosening is always a Launchhouse template change, not something this skill makes on a founder's machine.
