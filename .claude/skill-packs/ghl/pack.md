---
id: ghl
name: GoHighLevel
vendor_url: https://www.gohighlevel.com
kind: tool
skills: [ghl-expert]
agents: [ghl-specialist]
scripts: []
connectors: [ghl]
tracks: both
jobs: [connect and prove, social publishing, post stats, reply to someone who wrote first, contacts read, custom values, snapshot and workflow copy]
job_skills: [connect-tools, publish-content, ghl-workflows, ghl-values, audience-b2c]
specialist: ghl-specialist
expert_skill: ghl-expert
inventory_source: documented
verified_on: 2026-09-21
origin: template
---

## What it is for here

GoHighLevel is the one CRM every founder on the programme gets, B2B and B2C alike. It publishes the founder's content through Social Planner, holds their contacts and conversations, runs the operations snapshot loaded at the clinic, and carries the custom values that fill in that snapshot's blank messages. Everything a founder does with GoHighLevel in this folder goes through one of the two connector shapes `../../references/connections.md` documents: the account connector's six general tools, or the older one-per-job fallback. No tool in this pack was observed live in this session; every fact below is `documented` against GoHighLevel's own help and API pages, dated below.

## When to pick this route

There is no alternative route for this job. GoHighLevel is the one platform the programme buys for every founder (Session 2, Starter plan), and Social Planner, Custom Values and Conversations only exist there. The only choice a founder makes is which of the two connector shapes reaches it (the account connector, signed in from Settings then Connectors, or the fallback key in the password store, Code only) and, for custom values, whether to paste them in by hand or use the founder's own separate Private Integration token through `ghl-values-api.sh`. By hand is the route `ghl-values` recommends; the API route costs the founder a second token they make and delete themselves and needs no GHL account cost, only their own ten minutes.

## Connecting

Follow `connect-tools` step 1 in full: it is the source of truth for signing in, the fallback, and proving the connection works. This pack never repeats those steps, only what a founder's Claude needs once it is connected: the tool map below, and the operations the project's skills actually call. `growth-engine/.state/setup.md` (via `growth-engine/.state/tools.md`, see the spec's contract) is where connection state gets recorded, not this file.

## In Cowork

No hooks run there. `mcp-guard.sh` is a Claude Code hook and never fires in Cowork, so GoHighLevel's own connector setting is the only guard left. Set `execute_operation` to **Needs approval** in Settings, then Connectors, before doing any GoHighLevel work in Cowork, and confirm it is still set that way whenever a founder says "check my connections" from Cowork. The `search`, `fetch`, `list_locations`, `search_operations` and `describe_operation` tools are reads and do not need this setting, but `execute_operation` covers every write GoHighLevel can make, so it is the one tool this matters for.

## Changing this pack

Founders (or a maintainer working with them) edit `policy.local.tsv` in this same folder, never `policy.tsv`, which is the template's own file and gets overwritten on an update. A local addition may only tighten: `deny` or `ask` rows layered on top of what `ghl-op.sh` and `mcp-guard.sh` already decide. It can never loosen a decision `ghl-op.sh` or `policy.tsv` already made, and mcp-guard.sh enforces that by only ever taking the stricter of the two.
