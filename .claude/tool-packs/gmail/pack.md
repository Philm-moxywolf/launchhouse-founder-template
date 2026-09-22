---
id: gmail
name: Gmail
vendor_url: https://workspace.google.com/products/gmail/
tracks: b2b
jobs: [connect and prove, draft the 25 touch-1 emails after a yes, draft follow-ups two at a time, check for replies by search, record reply touches]
job_skills: [connect-tools, outreach-b2b, publish-content]
specialist: gmail-specialist
expert_skill: gmail-expert
inventory_source: observed
verified_on: 2026-09-21
origin: template
---

## What it is for here

Gmail is the B2B founder's own mailbox, connected so Claude can put the 25 outreach emails, and their follow-ups, into the founder's drafts folder and check who has replied. It is never the sender. The founder reads every draft and presses Send themselves, in their own Gmail.

## When to pick this route

- **Manual route (this pack) vs Apollo.** If the founder's outreach sequence (`engines/outreach/outreach-sequence.md`) records the Apollo route, Apollo sends through the founder's connected mailbox once they press start there, and there is nothing for this pack to draft. This pack is for the manual route: 25 messages, low volume, no sequencer, no monthly cost.
- **Gmail vs Microsoft 365.** Pick this pack when the Brain's Channels section says the founder's work email is Google (Gmail or Google Workspace). Microsoft 365 founders use the `outlook` pack instead, which today can search but, on the account Launchhouse has seen, cannot draft.
- **Cost.** Connecting Gmail costs nothing on the free or Workspace plan. The manual route itself costs nothing at all: no Apollo subscription, no sending credits.

## Connecting

Follow `../../references/connections.md` and the `connect-tools` skill: Settings, then Connectors, then Gmail (a Google Workspace connector), signed in with the founder's **work** email. Prove it by searching their own sent mail for one message and reading back only the address it was sent from, never anyone else's details.

## In Cowork

No hooks run there. The only guard is the connector's own approval setting in the founder's Claude account. Set `create_draft`, `update_draft`, `send_message`, `reply` and `forward` to **Needs approval** (or the nearest equivalent Cowork offers) so nothing leaves drafts without the founder's own yes, in any folder, not only this one.

## Changing this pack

Founders edit `policy.local.tsv` in this pack's folder, never `policy.tsv`. A local rule may only tighten a decision (turn a guide or silent into ask or deny), never loosen one this file or `mcp-guard.sh` already reaches. `send_message`, `reply` and `forward` are refused outright by `mcp-guard.sh` itself; no local edit can ever re-enable them.
