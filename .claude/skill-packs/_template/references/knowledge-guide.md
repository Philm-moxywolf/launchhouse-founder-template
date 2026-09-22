# {{name}} — knowledge (guide pack)

Use this template instead of `knowledge.md` when `pack.md`'s `kind` is `guide`:
a roadmap area with no single connector (an example: local SEO, or a pricing
playbook), rather than a tool. A guide pack has no `inventory.txt` and no
`connectors` to detect from a tool suffix; `policy.tsv` and `tests.tsv` are
optional, only present if this pack's skills or agents call a connector tool
that needs its own extra rule.

## Mental model

{{How this area of the business actually works, in the founder's own terms: what "good" looks like, the handful of concepts that matter, and how they connect.}}

## What Claude can do and what it needs first

{{What this pack lets Claude do for the founder, and what has to exist first: a Founder Brain, a connected tool, a decision only the founder can make.}}

## Workflows for Launchhouse jobs

### {{job_1}}

{{Step by step: what Claude reads, what it writes to growth-engine/, where the founder's yes is needed.}}

## Limits and gotchas

{{What trips founders up in this area, and the limits on what Claude can responsibly do here. Mark anything not checked (unverified).}}

## Failure modes and fixes

| Symptom | Cause | Fix |
|---|---|---|
| {{symptom}} | {{cause}} | {{fix}} |

## Rules that apply here

{{How the six rules in the root CLAUDE.md bind this area specifically. Link ../../../references/connections.md for the shared connector rules if this pack's skills call one.}}

## Never

{{A plain list of what this pack must never do or claim, the same shape as the six rules: invented proof, the wrong track's material, anything the six rules already forbid restated for this area.}}

## Sources

- {{title}}: {{https URL}} (checked {{YYYY-MM-DD}})

## Refreshing this pack

Re-check every source above still resolves and still says what this file claims. Run `sh .claude/scripts/skill-packs.sh --validate {{id}}` and, if this pack has tests, `sh .claude/scripts/skill-packs.sh --test {{id}}`. Update `verified_on` in `pack.md` once done.
