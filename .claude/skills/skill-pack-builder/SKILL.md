---
name: skill-pack-builder
description: Build or refresh a skill pack, a plugin-like bundle of skills, agents, scripts and reference material -- either an expert on one tool the founder has connected (a CRM, a scheduler, a second inbox), or a guide for a roadmap area with no single connector (local SEO, a pricing playbook), beyond the four tool packs Launchhouse ships with. Trigger on "build a pack for", "build a tool pack for", "build a guide pack for", "make Claude an expert on", "I connected <tool>", "teach Claude <tool>", "refresh my <tool> pack", "refresh my <tool> tool pack", or when session context or a connector check says a connected tool has no expert pack yet.
---

# Skill pack builder

Turns one tool the founder has connected, or one roadmap area with no single tool behind it, into a small, sourced bundle: skills, an agent when the job needs one, reference material, and (for a tool) deterministic guard tests -- the same shape as the four tool packs Launchhouse ships with (GoHighLevel, Apollo, Gmail, Outlook).

**Who is reading this.** You, Claude. The founder never sees this skill's steps, never opens a terminal, and never runs a command. You run `sh .claude/scripts/skill-packs.sh ...` yourself, from inside this skill, and report the result in plain words.

**The line that does not move.** A pack you build can only make Claude more careful, never less. A `policy.tsv` row, if the pack has one, is `deny` or `ask` only. You can never write a row, or any other file in the pack, that lets a tool send to a real person, publish, bulk-send, spend or delete more freely than the six rules and `.claude/references/connections.md` already allow.

Read the full spec in `.claude/skill-packs/README.md` before the first pack you build in a session; it has the exact file shapes this skill fills in, for both kinds.

## 0. Check first, and pick a kind

1. Read `.claude/skill-packs/registry.tsv`. If a row already exists for this tool or area (by name, not just id), say so and offer to refresh instead of building fresh. Refresh mode is steps 1 to 6 below, run again, then step 8 to show what changed; skip step 4 (no new registry row) unless the suffix set (tool kind) or jobs changed.
2. **Name the doubt.** In one line: connecting a tool to Claude, and now having Claude study it, can feel like handing over more keys than intended. Say plainly that this pack can only make Claude more careful, never less, and that nothing it writes can send, publish, spend or delete on its own.
3. **Which kind.** If the founder named a connected tool, it is `tool`. If they named a roadmap area with no single tool behind it (an example: local SEO, a pricing playbook, a bottleneck they described in their own words), it is `guide`. If it is not obvious, ask: "is there one specific tool this is about, or is it more a whole area to get right?" A `guide` pack skips step 1 (Inventory) entirely and step 4's `suffix_regex` is `-`.
4. **Ask what the founder wants it for**, with clickable choices (AskUserQuestion) where you can offer them, your best guess first: for a tool, map their answer to Launchhouse jobs (publishing, outreach, list building, replies, scheduling, bookkeeping, or "something else" they name); for a guide, ask what roadmap area this covers and the two or three jobs it should do for them. This drives the `jobs` list in `pack.md` and the workflows section of `knowledge.md`.

## 1. Inventory (tool kind only; skip entirely for a guide pack)

The tool must already be connected; a pack is never built from guesswork about tools nobody has seen.

1. Use ToolSearch to list the tools this connector exposes (search by the connector's likely name or `mcp__`). Read each tool's suffix: the part of its name after the last `__`.
2. If the connector is not there yet, tell the founder in plain words that it needs connecting first, and send them to `connect-tools` (or "connect my tools"). Stop here unless they ask you to work from vendor docs instead (documented mode): if so, mark every fact "documented", never "observed", and say plainly this pack has not been checked against the founder's own account yet.
3. Write `.claude/skill-packs/<id>/references/inventory.txt`, one suffix per line, headed by `# source: observed via ToolSearch <today>` or `# source: documented <url> checked <today>`. Pick `<id>` as a short lower-case word, a-z0-9 and hyphen only, from the tool's own name.

## 2. Research

Tool kind: dispatch the `tool-researcher` agent with the vendor name, the inventory list from step 1, and the jobs from step 0. It is read-only and returns sourced facts in a fixed shape; treat anything it did not source as unverified and never repeat it as fact. Guide kind: there is no vendor to research; ground `knowledge.md` in the Founder Brain, the shared references (`connections.md`, `contract.md`), and anything the founder told you directly in step 0, marking anything you cannot source `(unverified)`.

## 3. Generate the pack

Copy `.claude/skill-packs/_template/` into `.claude/skill-packs/<id>/`, keeping its bundle shape (`pack.md`, `skills/<id>-expert/SKILL.md`, `agents/<id>-specialist.md` if this pack needs one, `references/`, and for a tool kind `policy.tsv`/`tests.tsv`). Fill each file, following the exact shapes in `.claude/skill-packs/README.md` (headings, columns, tab-separated files, frontmatter keys). Do not invent a shape of your own. For a guide pack, drop `references/inventory.txt`, and drop `policy.tsv`/`tests.tsv` unless this pack's own skill or agent genuinely calls a connector tool that needs an extra rule.

- **`pack.md`** — frontmatter with `id`, `name`, `kind` (`tool` or `guide`), `skills: [<id>-expert]`, `agents: [<id>-specialist]` (or `[]` if this pack needs no agent), `scripts: []` unless you actually add one, `connectors` (the MCP connector id this pack depends on, or `[]` for a guide pack that calls none), `tracks`, `jobs` (from step 0), `job_skills` (existing skills this pack's jobs route to, or empty), `verified_on: <today>`, `origin: local`, and, for a tool pack only, `vendor_url`, `specialist: <id>-specialist`, `expert_skill: <id>-expert`, `inventory_source` (`observed` or `documented`). Sections: What it is for here, When to pick this route, Connecting, In Cowork, Changing this pack (say plainly: founders edit `policy.local.tsv` if the pack has one, never `policy.tsv`; everything else is edited in the pack's own folder, never the installed copy).
- **`references/knowledge.md`** — the nine H2 headings from the README for this pack's kind, in that exact order. Tool kind: the Tool map table holds every inventory tool exactly once, classed read, write, send or spend, and no tool outside the inventory appears anywhere in the file. Guide kind: no Tool map or inventory section at all; a `Never` section instead of a ninth Sources-adjacent heading, per the README. Every fact in Limits/Failure modes/Sources comes from the researcher's sourced output (tool kind) or the sources you actually checked (guide kind); mark anything unsourced `(unverified)`.
- **`policy.tsv`** (tool kind, or a guide pack whose skill/agent calls a connector) — one row per inventory tool that sends to a real person, publishes, bulk-sends, spends, deletes, or changes an automation: `deny` when the six rules or `connections.md`'s tiers rule it out outright (the same shapes CLAUDE.md and connections.md already deny for the shipped packs), `ask` otherwise. Reads need no row. `decision` is only `deny` or `ask`.
- **`tests.tsv`** — one test per policy row, plus at least one read tool expected `silent`. Omit entirely if the pack has no `policy.tsv`.
- **`references/evals.md`** — at least 8 numbered scenarios, at least 3 of them tagged `(guard rail)` in the heading itself (the validator counts that literal tag): a cold send, a spend, a bulk action, starting an automation, the other track's material, or whatever this pack's own version of "do not do this" looks like.
- **`agents/<id>-specialist.md`** (tool kind, or any guide pack whose jobs genuinely need an unattended plan/execute step) and **`skills/<id>-expert/SKILL.md`** — follow the README's contracts exactly (two-phase plan/execute for the specialist, with the approvals-script grant step described before `PHASE: execute`; connect (or "what has to exist first" for a guide pack), route, approve, grant, record, answer for the expert skill). A pure guide pack with no connector calls may skip the agent entirely -- leave `agents: []` in `pack.md` and skip this file.
- **`.claude/commands/growth-engine/<id>.md`** — the one-line command shim shape.

## 4. Registry row

Append one row to `.claude/skill-packs/registry.tsv`: `id`, `name`, `kind`, a `suffix_regex` (tool kind: built from the actual inventory suffixes, anchored so it cannot also match a different vendor's tools, never a bare generic verb like `^send` or `^get`; guide kind: literally `-`, meaning nothing is ever detected for it), `tracks`, `origin local`.

## 5. Install and validate

Run, yourself, never asking the founder to:
```
sh .claude/scripts/skill-packs.sh --validate <id>
sh .claude/scripts/skill-packs.sh --compile
sh .claude/scripts/skill-packs.sh --install <id>
sh .claude/scripts/skill-packs.sh --test <id>
```
`--test <id>` prints `SKIP` with no failure if the pack has no `tests.tsv` (a guide pack with no policy rows). Fix what fails and re-run, at most twice more. If it is still failing after that, stop and tell the founder plainly, in one or two sentences, what is left broken and that the pack is not finished yet. Never mark a pack done while validation, install or its own tests fail.

## 6. Second read

Use the `rules-reviewer` agent on `references/knowledge.md` and `references/evals.md`. Fix anything it holds before calling the pack finished.

## 7. Record the tool (tool kind only)

Add or update a row for this tool in `growth-engine/.state/tools.md`, in the shape in `.claude/references/contract.md`: status `connected` or `verified`, with evidence that is only what a tool actually returned. A guide pack has nothing to record here.

## 8. Save

`growth-engine/people/`, `outreach-firstlines.csv` and `dm-openers.md` hold real people and are never staged. Stage only the new pack paths: `.claude/skill-packs/<id>/` (the pack's own source), `.claude/skills/<id>-expert/SKILL.md` and, if this pack has one, `.claude/agents/<id>-specialist.md` (the installed copies `--install` just wrote), `.claude/commands/growth-engine/<id>.md`, the updated `.claude/skill-packs/registry.tsv` and `compiled-policy.sh`, and `growth-engine/.state/tools.md` for a tool pack. Commit with a short plain message. Push if a remote exists and it is not under `Philm-moxywolf`.

## 9. Hand back

Tell the founder, in plain words, in this order:
1. What Claude now knows, in a sentence, not a file list.
2. What it will never do (the deny rows, or for a guide pack the `Never` list, said in plain words).
3. The one next thing to do, such as trying "how do I ... in <tool>" or the new expert skill by name.

## Refresh mode

When a pack already exists, re-run steps 1 to 6 (re-inventory for a tool pack, re-research, regenerate, re-install, re-validate, second read), then show the founder what changed: new tools or dropped ones (tool kind), changed limits, changed policy rows. Never loosen a `policy.tsv` row on refresh, even if the vendor's own docs suggest it: a loosening is always a Launchhouse template change, not something this skill makes on a founder's machine.
