---
id: {{id}}
name: {{name}}
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

{{One or two sentences: which Launchhouse jobs this tool does, in plain words.}}

## When to pick this route

{{The alternatives a founder might reach for instead, and the cost of each: time, credits, money, risk. Say when this tool is the better route and when it is not.}}

## Connecting

{{How the founder connects this tool: connector name, where to click, what a working connection looks like. Link ../../references/connections.md if the shared steps apply.}}

## In Cowork

No hooks run there. The only guard is the connector's own approval setting. Say which tool or tools to set to "Needs approval" (or the nearest equivalent) so nothing goes out without the founder's own yes.

## Changing this pack

Founders edit `policy.local.tsv` in this pack's folder, never `policy.tsv`. A local rule may only tighten a decision (turn a guide or silent into ask or deny), never loosen one `policy.tsv` or `mcp-guard.sh` already reaches.
