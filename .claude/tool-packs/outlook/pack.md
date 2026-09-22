---
id: outlook
name: Microsoft 365 (Outlook)
vendor_url: https://www.microsoft.com/microsoft-365/outlook/email-and-calendar-software-microsoft-outlook
tracks: b2b
jobs: [connect and prove, check for replies by search, record reply touches, draft the 25 touch-1 emails after a yes, draft follow-ups two at a time]
job_skills: [connect-tools, outreach-b2b]
specialist: outlook-specialist
expert_skill: outlook-expert
inventory_source: documented
verified_on: 2026-09-21
origin: template
---

## What it is for here

Microsoft 365 is the B2B founder's own mailbox when their work email is on Microsoft 365 rather than Google. On every account Launchhouse has connected so far, its working tools are `outlook_email_search` and `outlook_calendar_search`, both reads. `outlook_email_search` has proved useful for exactly one job: checking who has replied to the 25 outreach emails, by searching for mail from each person's address since the day their message went out. Anthropic's own connector security guide (see Sources) now documents a full set of write tools on this connector too, including `outlook_create_draft`; they are off by default and need a Microsoft Entra administrator to approve them and an organization owner to turn them on in Claude's connector tool permissions. For a solo founder that is usually their own click. Until that has happened, and been tried, the 25 go out by hand.

## When to pick this route

- **Outlook vs Gmail.** Pick this pack when the Brain's Channels section says the founder's work email is on Microsoft 365. Google founders use the `gmail` pack instead.
- **Outlook drafting vs the manual route for the 25.** If the founder's tool list shows `outlook_create_draft`, this pack drafts the 25 and their follow-ups the same way the Gmail pack does, one call per person, always shown to the founder first. If it does not, the 25 outreach emails, and their follow-ups, go out by hand, copied from each person's file in `growth-engine/people/`, exactly as the manual route in `outreach-b2b` already has the founder do. Checking which is true for a given founder is a look at their own tool list, not a guess.
- **Cost.** Connecting costs nothing beyond the Microsoft 365 plan the founder already has. The manual route costs nothing at all: no Apollo subscription, no sending credits.

## Connecting

Follow `../../references/connections.md` and the `connect-tools` skill: Settings, then Connectors, then Microsoft 365, signed in with the founder's **work** account. A personal Microsoft account (`@outlook.com`, `@hotmail.com`) cannot connect; it needs a Microsoft 365 business account. Prove it by searching their own sent mail for one message and reading back only the address it was sent from, never anyone else's details. If the search cannot show a from-address, say so and record `in progress`, per `connect-tools`. If the founder wants drafting, point them to their own Microsoft 365 admin center to approve the write-tool permission and to Claude's connector tool permissions to turn it on; that is a step they take themselves, not Claude.

## In Cowork

No hooks run there. The only guard is the connector's own approval setting in the founder's Claude account. Set `outlook_send_mail`, `outlook_forward_mail`, `outlook_send_draft`, `outlook_set_vacation`, `outlook_create_filter`, `outlook_create_draft` and `outlook_create_reply_draft` to **Needs approval** (or the nearest equivalent) there too, so a write tool that appears, now or once an administrator turns more on, cannot act without the founder's own yes, in any folder.

## Changing this pack

Founders edit `policy.local.tsv` in this pack's folder, never `policy.tsv`. A local rule may only tighten a decision (turn a guide or silent into ask or deny), never loosen one this file or `mcp-guard.sh` already reaches.
