---
id: linkedin-profile
name: LinkedIn profile
kind: guide
skills: [linkedin-profile-expert]
agents: [linkedin-profile-reviewer]
scripts: []
connectors: []
tracks: b2b
jobs: [review the founder's own LinkedIn export, draft headline/about/featured/experience/banner copy, custom URL and creator mode notes, company page basics, point to LinkedIn-partnered tools only]
job_skills: [add-files, outreach-b2b, founder-brain]
origin: template
verified_on: 2026-09-22
---

## What it is for here

A B2B founder's LinkedIn profile and company page are what the 25 outreach messages and the content engine's posts point back to. This pack never logs in to LinkedIn and never automates anything there. It reads the founder's own downloaded export (their profile as a PDF, and, for the fuller picture, their "Get a copy of your data" archive), and drafts headline, About, Featured, Experience, banner, and company-page copy from the Founder Brain in their own voice, for them to paste in themselves, exactly the way `linkedin-profile` names the route in the pack brief. It is B2B only (rule 1); a B2C founder never sees this pack.

## When to pick this route

There is no tool route to editing a LinkedIn profile, ever, from here. LinkedIn's own User Agreement bars both unauthorized automated access and any script, bot, or browser add-on that scrapes or copies the service (`../../references/social-accounts.md`, and this pack's own `references/knowledge.md`). The only route in is the founder's own export, added with `/growth-engine:add-files`, and their own paste-in once the copy is drafted. Where a founder wants a tool beyond that, this pack only ever points at LinkedIn's own Marketing Partners directory (Sales Navigator, LinkedIn's own scheduling inside Campaign Manager, or a listed partner) and always says the founder connects it themselves, in LinkedIn's own account settings.

This project's environment also carries an **unofficial LinkedIn MCP connector** (tool names such as `get_my_profile`, `search_people`, `send_message`, `connect_with_person`). This pack's `policy.tsv` exists specifically to keep every one of its tools out of ordinary use: every write, send, or connect call is denied outright, and every read is still asked about, with the ban risk named, before it ever runs. See "Rules that apply here" in `references/knowledge.md`.

## Connecting

Nothing to connect. This pack reads the founder's own export files, once added to `growth-engine/inbox/uploads/` by `add-files`, and the Founder Brain. If a founder asks how to add their export, send them to `/growth-engine:add-files`.

## In Cowork

No hooks run there, and this pack calls no connector of its own; the unofficial LinkedIn MCP tools this pack polices are covered by `mcp-guard.sh` in Claude Code only. In Cowork, if that unofficial connector is ever present, the founder's own connector "Needs approval" (or "Never allow", if offered) setting is the only guard: set every write, send, and connect tool on it to Never allow, and every read to Needs approval, the same shape this pack's `policy.tsv` enforces in Claude Code.

## Changing this pack

Founders edit `.claude/skill-packs/linkedin-profile/policy.local.tsv`, never `policy.tsv`, which is this template's own shipped file. A local row may only tighten further (turn an `ask` into a `deny`); it can never loosen what `policy.tsv` or `mcp-guard.sh` already reaches. Everything else here (`skills/`, `agents/`, `references/`) is edited directly in this pack's own folder, and Launchhouse re-installs the skill and agent from here.

## Shared suffixes, noted once

This pack's `policy.tsv` matches tool suffixes by name alone (`get_my_profile`, `search_people`, `send_message`, and so on), not by connector, because policy can only ever tighten (`.claude/skill-packs/README.md`). `send_message` already exists, and is already denied outright, on the Gmail connector (the base `mcp-guard.sh` denies any `*__send_message` by name); this pack's own `send_message` row simply makes that explicit for the LinkedIn case too, and changes nothing about Gmail's own behaviour. `search_people`, `get_conversation`, `get_feed`, and the other bare, generic suffixes here could in principle exist on a future connector this pack was never written for; if that ever happens, the same row still only ever tightens that connector's own call from whatever `mcp-guard.sh` and its own pack would otherwise decide, never loosens it.
