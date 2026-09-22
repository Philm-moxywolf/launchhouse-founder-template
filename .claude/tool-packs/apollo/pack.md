---
id: apollo
name: Apollo
vendor_url: https://www.apollo.io
tracks: b2b
jobs: [connect and prove, list of 25 from criteria, enrichment with shown credit cost, paused sequence with first_line field, sequence health read]
job_skills: [connect-tools, outreach-b2b, apollo-sequence]
specialist: apollo-specialist
expert_skill: apollo-expert
inventory_source: observed
verified_on: 2026-09-21
origin: template
---

## What it is for here

Apollo is the B2B founder's list-building and cold-sequencing tool. It finds people who fit the ICP, turns a few of them into verified work emails, and holds the four to five touch sequence the outreach engine wrote, paused, ready for the founder to start by hand. Launchhouse never uses Apollo to send, start a sequence, or buy anything. It is B2B only: a B2C founder never sees Apollo, and their DMs are sent by hand from their own phone (rule 2).

## When to pick this route

Apollo is the route when the founder's work email is on Google (Gmail or Google Workspace). Their mailbox connects to Apollo in a two-minute sign-in, and Apollo's sequences handle the follow-up touches with stop-on-reply on by default. On Microsoft 365, or any other provider, the founder sends the 25 by hand from their own mailbox instead: no new account, no cost, and it still meets the 25-message promise (rule 3). The free Apollo plan connects in full at no cost; a paid plan (see knowledge.md, Limits and quotas) buys the credits and sending volume that a real send needs, and is set up with sending in Session 2. Never say the paid plan is needed to connect.

## Connecting

Apollo connects as Claude's own account connector, named **Apollo.io**, in Settings, then Connectors, then Browse connectors: the founder signs in, there is nothing to paste. `connect-tools` walks them through it and proves the connection by reading their own profile and mailbox list back to them. Full details, including the free-plan note and the refusal table, are in `.claude/skills/connect-tools/SKILL.md` and `.claude/references/connections.md`.

## In Cowork

No hooks run in Cowork, so `mcp-guard.sh` never sees an Apollo call there. The only check left is the founder's own Apollo connector setting in Settings, then Connectors: set `apollo_emailer_messages_send_now`, `apollo_emailer_campaigns_approve`, `apollo_email_account_purchase_create` and `apollo_domain_purchase_index` to **Never allow** if that choice is offered, and enrichment tools (`apollo_people_match`, `apollo_people_bulk_match`, `apollo_organizations_enrich`, `apollo_organizations_bulk_enrich`) and `apollo_emailer_campaigns_add_contact_ids` to **Ask each time**. If their settings do not offer a per-tool choice, say plainly that Cowork carries no Launchhouse guard for Apollo and the founder's own yes in chat is the only check before anything is created or spent.

## Changing this pack

Founders and their Claude edit `.claude/tool-packs/apollo/policy.local.tsv`, never `policy.tsv`, which is the shipped template file. A local row may only add a `deny` or `ask`, tighter than what is here; it can never loosen a row in `policy.tsv`, and `mcp-guard.sh` only ever applies the stricter of the two.
