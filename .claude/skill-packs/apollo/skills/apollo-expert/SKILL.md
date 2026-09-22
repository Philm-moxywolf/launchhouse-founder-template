---
name: apollo-expert
description: Answer a founder's question about Apollo, or route a job that needs it to the right skill, or run one directly through the apollo-specialist agent. Trigger on "Apollo", "apollo.io", "connect Apollo", "how do I ... in Apollo", "check my Apollo", "my Apollo sequence", "my 25", "credits", or any Apollo question this pack can answer. B2B track only.
---

# Apollo expert

**Who is reading.** A founder who does not use a terminal. Never ask them to run a command.

**Track.** Apollo is B2B only. If the founder's Founder Brain has no Track yet, do not ask which track they are on; say plainly that this needs the Founder Brain built first, and offer `/growth-engine:brain`. If the Track is `b2c`, say Apollo is not part of their track and send them to `/growth-engine:audience`. Never connect or use Apollo for a B2C founder.

## 1. Read first

Read `.claude/skill-packs/apollo/pack.md` and `.claude/skill-packs/apollo/references/knowledge.md` before answering anything or routing anywhere.

## 2. Check the connection

Look for tools whose names end in `apollo_users_api_profile` and `apollo_mixed_people_api_search`. If neither is there, send the founder to `connect-tools` (`/growth-engine:connect`, or say "connect my tools") before doing anything else that needs Apollo.

## 3. Route the founder's request

| Founder asks for | Go to |
|---|---|
| Connecting or checking the Apollo connection | `connect-tools` |
| Choosing the outreach route, writing the sequence copy, the list criteria, or the first lines | `outreach-b2b` |
| Building the list of 25 in Apollo, enriching addresses, or loading the paused sequence | `apollo-sequence` |
| How the sequence is doing, or who replied | `apollo-sequence`'s "Afterwards" step, or call `apollo-specialist` directly for a one-off read, below |
| Stopping one person who asked to be left alone | Call `apollo-specialist` directly, below |
| A plain "how does X work in Apollo" or "what will this cost" question | Answer from `knowledge.md`, below |

## 4. The approval dance, for anything the specialist runs directly

1. Call `apollo-specialist` with `PHASE: plan` and the job.
2. Show the founder every proposed action exactly as the plan wrote it: the tool, the input, and the preview of what will be created, added or spent, including any credit cost, in plain words.
3. Wait for a clear yes. A yes covers exactly what was shown; if the cost or the list changes, show it again.
4. Grant it: `sh .claude/scripts/approve.sh --grant apollo <exact tool suffix>[:<count>] ...`, exactly the actions just shown and approved.
5. Call `apollo-specialist` with `PHASE: execute` and `APPROVED ACTIONS:` followed by the plan's actions verbatim.
6. Clear the grant: `sh .claude/scripts/approve.sh --clear apollo`.
7. Report back to the founder in plain words: what happened, any ids, and credits used and balance left when a call spent any.

Never skip the plan phase, even for something that feels small. Never show the founder raw tool JSON; translate it into the plain words `outreach-b2b` and `apollo-sequence` already use. Never call an enrichment tool, `apollo_people_match`, `apollo_people_bulk_match`, `apollo_organizations_enrich` or `apollo_organizations_bulk_enrich`, "just to check" something; use `apollo_users_api_profile` or `apollo_email_accounts_index` for that. A read never needs a grant. If `approve.sh` refuses the grant, or the specialist reports a call was denied, that is the answer: say so plainly and do not try again with different wording.

## 5. Record connection state

After proving or changing a connection, write or update the row in `growth-engine/.state/tools.md`:

| tool | name | status | route | date | evidence |
|---|---|---|---|---|---|
| apollo | Apollo | connected | b2b outreach | <date> | <what the tool actually returned, such as "signed in as sam@northfield.io"> |

`status` is one of `planned`, `connected`, `verified`, `dropped`. Evidence is only ever what a tool returned, or "founder planned it" for `planned`. This is separate from `growth-engine/.state/setup.md`, which `connect-tools` owns in full; this row is this pack's own short record.

## 6. Answering "how does X work" or "what will this cost" questions

Answer from `knowledge.md`'s Mental model, Tool map, Limits and quotas, and Failure modes sections. Say plainly that this pack was last checked on `verified_on` in `pack.md`, and that Apollo's own docs, pricing and credit allowances can move past that date; offer to refresh the pack (its Refreshing steps) if the founder's own account behaves differently from what is written here, especially anything marked `(unverified)`.

**Never guess at a credit cost, a rate limit or a price this file does not carry as sourced.** If the founder's question needs something the pack does not know, say so plainly, and either look it up (Apollo's own current docs) or send them to `apollo_usage_stats_credit_usage_stats` for their own account's real numbers, rather than inventing an answer that sounds right.

Apollo's tracking domain and the connected mailbox both depend on working DNS (SPF, DKIM, DMARC and the rest). If emails are landing in spam, opens aren't tracking, or Apollo flags the domain as unverified, send the founder to `domains-expert` (or `/growth-engine:domains`) to check and fix it.

## What this pack will never do

Say this plainly whenever a founder connects Apollo or asks what it can do, in their own words, not a tool list:

- It will never start their sequence, send a message, or approve a campaign. They read it and press start themselves, in Apollo.
- It will never spend their money: no buying a mailbox, a domain, or more credits, and no changing their plan.
- It will never enrich anyone's contact details without first saying the estimated credit cost and getting a clear yes.
- It will never write the founder's sequence copy or first lines for them with Apollo's own AI; those are written in their own voice, in the outreach engine.

## In Cowork

No Launchhouse hooks run there. The only guard left is the founder's own Apollo connector settings in Settings, then Connectors: `apollo_emailer_messages_send_now`, `apollo_emailer_campaigns_approve`, `apollo_email_account_purchase_create` and `apollo_domain_purchase_index` should be **Never allow**, and enrichment tools plus `apollo_emailer_campaigns_add_contact_ids` should be **Ask each time**, if their settings offer a per-tool choice. If not, say plainly that Cowork carries no Launchhouse guard for Apollo and the founder's own yes in chat is the only check before anything is created or spent.
