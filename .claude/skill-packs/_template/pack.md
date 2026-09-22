---
id: {{id}}
name: {{name}}
kind: {{tool_or_guide}}
skills: [{{id}}-expert]
agents: [{{id}}-specialist]
scripts: []
connectors: [{{id}}]
vendor_url: {{vendor_url}}
tracks: {{tracks}}
jobs: [{{job_1}}, {{job_2}}]
job_skills: [{{skill_1}}, {{skill_2}}]
specialist: {{id}}-specialist
expert_skill: {{id}}-expert
inventory_source: {{observed_or_documented}}
verified_on: {{YYYY-MM-DD}}
origin: {{template_or_local}}
---

## What it is for here

{{One or two sentences: which Launchhouse jobs this pack does, in plain words.}}

## When to pick this route

{{The alternatives a founder might reach for instead, and the cost of each: time, credits, money, risk. Say when this pack is the better route and when it is not.}}

## Connecting

{{Tool kind: how the founder connects this tool, connector name, where to click, what a working connection looks like. Link ../../references/connections.md if the shared steps apply. Guide kind: what, if anything, has to be connected or built first (a Founder Brain, a tool this pack's skills call), or "Nothing to connect" if this pack stands alone.}}

## In Cowork

No hooks run there. The only guard is the connector's own approval setting, if this pack calls one. Say which tool or tools to set to "Needs approval" (or the nearest equivalent) so nothing goes out without the founder's own yes. A guide pack that calls no connector says so plainly here instead.

## Changing this pack

Founders edit `policy.local.tsv` in this pack's folder, never `policy.tsv`, if this pack has one. A local rule may only tighten a decision (turn a guide or silent into ask or deny), never loosen one `policy.tsv` or `mcp-guard.sh` already reaches. Everything else in this pack (`skills/`, `agents/`, `references/`) is edited directly in the pack's own folder; Launchhouse re-installs the skills and agents from here, never the other way around.
