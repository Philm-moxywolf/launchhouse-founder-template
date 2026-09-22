# Apollo knowledge

## Mental model

Apollo holds three kinds of object a Launchhouse founder cares about:

- **People and organizations.** Apollo's own database of roughly 240 million contacts and their companies (source: Apollo's product page, see Sources). A search returns a catalogue row: name with the surname hidden, title, company, and whether an email is likely. No email address. Turning that row into a real, usable contact is a separate step, **enrichment** (`apollo_people_match`, `apollo_people_bulk_match`), which is the one step that spends the founder's credits.
- **Contacts.** Once enriched, a person becomes a contact in the founder's own Apollo account, with an id Launchhouse stores in their person file as apollo contact id. Contacts carry custom fields, one of which Launchhouse always uses: `first_line`, the personalised opening sentence for that person.
- **Sequences (also called emailer campaigns in the API).** A sequence is a set of timed touches. It has an `active` flag. Launchhouse only ever creates or updates a sequence with `active: false`, and Apollo's own mailer never fires on an inactive sequence. Starting one, sending a message immediately, or approving a campaign are all separate, one-way actions the founder does themselves.

**States that matter:** a contact exists once created; a sequence exists once created, and is either paused (`active: false`, what Launchhouse always leaves it in) or running (`active: true`, a state Launchhouse never sets); a message inside a sequence is either not yet sent, sent, bounced, replied to, or the contact has opted out.

## Connecting and auth

Apollo connects as Claude's own account connector, named **Apollo.io**, added from Settings, then Connectors, then Browse connectors. The founder signs in to Apollo; nothing is pasted into the chat. The connector's OAuth 2.0 server metadata is published at `https://mcp.apollo.io/.well-known/oauth-authorization-server` (source: this session's own MCP server instructions). A standalone server also exists at `https://mcp.apollo.io/mcp` using Streamable HTTP transport, for clients outside the Claude connector flow (source: Apollo MCP docs).

The **free Apollo plan connects in full**: never tell a founder they need a paid plan to connect Apollo to Claude. What the paid plan buys is credits, sending volume and mailboxes, which the programme sets up with sending in Session 2 (source: `outreach-b2b` SKILL.md, Step 0).

**Sending mailbox.** A sequence needs a linked mailbox before anything can be added to it. Apollo's own help centre says linking a mailbox gives full functionality of email, sequences and conversations, and that Gmail is the preferred provider though others and custom mail servers are supported (source: Link Your Mailbox to Apollo). Launchhouse's own rule is stricter: it only ever uses Apollo on the Google route, because the mailbox itself is what carries deliverability, whichever tool sends through it. Check `apollo_email_accounts_index` before doing anything with a sequence; if it is empty, stop and send the founder to link a mailbox in Apollo.

**What breaks.** No Apollo tools after connecting: reconnect from Settings, Connectors, and start a new conversation. `apollo_users_api_profile` returning "not authorised": the sign-in expired; reconnect. A 429 or no response: Apollo is rate-limiting or briefly unavailable; wait a minute and try again (see Limits and quotas).

## Tool map

`class` is one of read, write, send, spend. A tool is `spend` when it consumes Apollo credits or the founder's money; `send` when it can put a message or file in front of a real person outside the founder's own Apollo account; `write` for any other create, update or delete; `read` for anything that only looks.

| tool | class | what it does | inputs that matter | gotchas |
|---|---|---|---|---|
| `apollo_accounts_bulk_create` | write | creates several company (account) records at once | a list of companies | creates many real records in one call; Launchhouse tightens this to ask, see policy.tsv |
| `apollo_accounts_create` | write | creates one company record | name, domain | |
| `apollo_accounts_update` | write | edits a company record | account id, fields to change | |
| `apollo_agent_analyze_performance` | read | summarises how a sequence, campaign or rep is doing | date range, target | a natural-language agent tool; still only reads |
| `apollo_agent_build_lead_scores` | write | builds or updates a lead-scoring model | scoring criteria | writes a model into the account, not a person's data |
| `apollo_agent_connect_mailbox` | write | walks through, or triggers, connecting a sending mailbox | mailbox details | Launchhouse's own mailbox connection happens in Apollo's own UI in `connect-tools`; do not use this to connect a mailbox on the founder's behalf without them present |
| `apollo_agent_draft_sequence_copy` | write | drafts sequence touch copy with Apollo's own AI | topic, audience | drafts only, never sends; Launchhouse writes its own sequence copy in `outreach-b2b` and never uses this to originate the founder's voice |
| `apollo_agent_explain_howto` | read | answers "how do I ... in Apollo" questions from Apollo's own help content | a question | good first stop for a founder's Apollo how-to question |
| `apollo_agent_find_prospects` | read (unverified for credits) | searches for people or companies matching criteria, in natural language | criteria | Apollo's own MCP docs say enrichment and bulk enrichment consume credits; this agent tool was not explicitly listed as free, so Launchhouse tightens it to ask, the same as enrichment, until proven otherwise on a real account |
| `apollo_agent_fix_email_deliverability` | read | diagnoses SPF, DKIM, DMARC and sending health issues | domain | diagnostic only; still send the founder to their domain provider to make any DNS change |
| `apollo_agent_manage_billing` | spend | reads or changes plan, billing and credit purchases | plan, seats | can spend the founder's money; Launchhouse denies it, see policy.tsv |
| `apollo_agent_plan_gtm_campaign` | write | drafts a go-to-market plan inside Apollo | goals, audience | planning only, not itself a send |
| `apollo_agent_research_and_analyze` | read | researches a company or person using Apollo's data and the open web | a target | read-only research |
| `apollo_agent_summarize_calls_meetings` | read | summarises recorded calls or meetings already in Apollo | a call or meeting id | needs Conversations data to exist already |
| `apollo_agent_workflow_automation` | write | sets up an automated workflow inside Apollo | a trigger and actions | could enrol, message or start something without the founder reading it first; Launchhouse denies it, see policy.tsv |
| `apollo_analytics_sync_report` | read | reads a saved analytics or sync report | report id | |
| `apollo_contacts_bulk_create` | write | creates several contact records at once | a list of people | creates many real people's records in one call; Launchhouse tightens this to ask, see policy.tsv |
| `apollo_contacts_create` | write | creates one contact | email, name, company | used after the founder has said yes to the list of 25 |
| `apollo_contacts_search` | read | searches existing contacts already in the account | filters | different from a people search: this only looks at contacts already saved |
| `apollo_contacts_update` | write | edits a contact, including custom fields | contact id, fields | this is how `first_line` gets set on a contact if the create call cannot set it |
| `apollo_context_center_create_product` | write | adds a product record to Apollo's context centre (used to ground AI features) | product details | |
| `apollo_context_center_create_profile` | write | adds a company or persona profile to the context centre | profile details | |
| `apollo_context_center_show` | read | reads the context centre's current profile | none | |
| `apollo_context_center_show_product` | read | reads one product record | product id | |
| `apollo_context_center_update_product` | write | edits a product record | product id, fields | |
| `apollo_context_center_update_profile` | write | edits the context centre's profile | fields | |
| `apollo_conversations_get_insights` | read | reads AI insights from a recorded call | conversation id | |
| `apollo_conversations_get_recording_links` | read | reads links to a call recording | conversation id | the link itself may need separate access in the recording tool |
| `apollo_conversations_get_transcript` | read | reads a call transcript | conversation id | |
| `apollo_conversations_search` | read | finds recorded calls or conversations | filters | |
| `apollo_deals_create` | write | creates a deal (opportunity) record | account, amount, stage | Launchhouse does not use Apollo as a CRM; GoHighLevel is the CRM here |
| `apollo_deals_search` | read | finds deals | filters | |
| `apollo_deals_show` | read | reads one deal | deal id | |
| `apollo_domain_purchase_index` | read | lists domains available to buy through Apollo | search term | the word "purchase" in this tool's own name is enough for the base guard to deny it outright; Launchhouse also lists it explicitly, see policy.tsv |
| `apollo_email_account_purchase_create` | spend | buys a mailbox through Apollo | plan, quantity | spends the founder's money; denied |
| `apollo_email_account_purchase_index` | read | lists mailboxes available to buy through Apollo | none | denied the same way as the domain index, since browsing a purchase flow is still part of spending |
| `apollo_email_accounts_index` | read | lists mailboxes already linked to send from | none | check this before creating or adding to any sequence |
| `apollo_emailer_campaigns_activity_feed` | read | reads what has happened in a sequence: sent, opened, bounced, replied | campaign id | the tool `apollo-sequence` uses for "how is it going" |
| `apollo_emailer_campaigns_add_contact_ids` | spend | adds contacts to a sequence, which schedules their first send | campaign id, contact ids, mailbox id | denied by the base guard's own named ask list as a credit- and sending-adjacent action; only ever called after a founder's yes |
| `apollo_emailer_campaigns_approve` | send | approves a campaign so it can send | campaign id | denied outright: this is the step Launchhouse never takes |
| `apollo_emailer_campaigns_remove_or_stop_contact_ids` | write | stops one or more contacts in a running or paused sequence | campaign id, contact ids | this is how a founder honours a "leave me alone" reply; asked, never silent |
| `apollo_emailer_campaigns_search` | read | finds sequences by name or filter | filters | |
| `apollo_emailer_campaigns_show` | read | reads one sequence's steps, schedule and active flag | campaign id | used to read back that a sequence is still paused before telling the founder it is ready |
| `apollo_emailer_messages_create` | send | writes and queues an individual message inside a campaign | recipient, body | denied outright |
| `apollo_emailer_messages_email_send_status` | read | reads whether a specific message sent, bounced or failed | message id | the word order (email, then send) keeps this out of the mailbox "send email" deny rule; it only reads a status |
| `apollo_emailer_messages_get_content` | read | reads the text of a message already in a sequence | message id | |
| `apollo_emailer_messages_search` | read | finds sent or queued messages | filters | |
| `apollo_emailer_messages_send_now` | send | sends one message immediately, outside any pause | message id | denied outright: this is the single tool that most directly breaks "Launchhouse never sends" |
| `apollo_emailer_schedules_index` | read | lists the sending schedules (days, hours, timezone) available to attach to a sequence | none | `apollo-sequence` reads this to pick a weekday business-hours schedule |
| `apollo_feedback_log` | write | logs feedback about Apollo itself back to Apollo | free text | not a Launchhouse job; only ever used if the founder explicitly asks to send Apollo feedback |
| `apollo_fields_index` | read | lists custom fields, including whether a contact field named `first_line` exists | none | `apollo-sequence` checks this before loading contacts |
| `apollo_labels_add_entity_ids_to_label_names` | write | adds a label to a set of records | label name, entity ids | used to tag the 25 as "Launchhouse 25" |
| `apollo_labels_create` | write | creates a label | name | |
| `apollo_labels_index` | read | lists labels | none | |
| `apollo_labels_remove_entity_ids_from_label_names` | write | removes a label from a set of records | label name, entity ids | |
| `apollo_labels_update` | write | edits a label | label id, fields | |
| `apollo_mixed_companies_search` | read | searches companies across Apollo's database | filters | does not spend credits: search itself is free, only enrichment is (source: Apollo API credit pricing) |
| `apollo_mixed_people_api_search` | read | searches people across Apollo's database, the catalogue step | filters | no email addresses come back from this call; free of charge |
| `apollo_organizations_bulk_enrich` | spend | enriches several companies' records at once | a list of company ids or domains | spends credits; asked |
| `apollo_organizations_enrich` | spend | enriches one company's record | company id or domain | spends credits; asked |
| `apollo_organizations_job_postings` | read | reads a company's open job postings | company id | can be a trigger signal for the ICP filters |
| `apollo_organizations_lookup` | read | looks up a company by domain or name | domain or name | |
| `apollo_people_bulk_match` | spend | finds and verifies several people's work emails at once, the main enrichment call Launchhouse uses | a list of names and companies | spends credits, 1 to 9 per person depending on what comes back (see Limits and quotas); asked, always after a founder's yes on the estimated cost |
| `apollo_people_match` | spend | finds and verifies one person's work email | name, company, title | same as bulk, one person at a time; asked |
| `apollo_phone_calls_create` | write | logs a phone call record | contact id, notes | Launchhouse does not place calls; this only logs one already made |
| `apollo_phone_calls_search` | read | finds logged calls | filters | |
| `apollo_phone_calls_update` | write | edits a logged call | call id, fields | |
| `apollo_sequences_create` | write | creates a sequence | name, steps, `active` | must always be called with `active: false`; the base guard denies any call carrying `active: true`, whatever tool built the input |
| `apollo_sequences_update` | write | edits a sequence, including switching `active` on | sequence id, fields | the same `active: true` deny applies here |
| `apollo_survey_submit` | write | submits an in-product survey response to Apollo | answers | not a Launchhouse job |
| `apollo_tasks_bulk_create` | write | creates several tasks at once | a list of tasks | |
| `apollo_tasks_complete` | write | marks a task done | task id | |
| `apollo_tasks_create` | write | creates one task | title, due date, contact | |
| `apollo_tasks_search` | read | finds tasks | filters | |
| `apollo_tasks_show` | read | reads one task | task id | |
| `apollo_tasks_skip` | write | skips a task | task id | |
| `apollo_tasks_update` | write | edits a task | task id, fields | |
| `apollo_usage_stats_credit_usage_stats` | read | reads the account's credit balance and recent usage | date range | the read the pack uses to check a balance before promising a spend estimate is accurate |
| `apollo_users_api_profile` | read | reads the signed-in user's own profile | none | `connect-tools` uses this to prove the connection: "Connected to Apollo as <email>"; checked against the real hook, this name lands on guide rather than silent (none of its words match the base guard's read-word list), which is harmless since guide never blocks a call |
| `apollo_users_search` | read | finds other users on the same Apollo team | filters | rarely needed for a solo founder |
| `apollo_webhook_result_show` | read | reads the result of a webhook Apollo fired | webhook id | Launchhouse does not set up Apollo webhooks |
| `apollo_website_visitor_domain_tracker_index` | read | lists visitors Apollo's tracker has identified on the founder's site | none | needs the tracker script installed first |
| `apollo_website_visitor_domain_tracker_install_script` | read | returns the tracking script to install on the founder's site | none | reading the script is safe; installing it is the founder's own step on their site |
| `apollo_website_visitor_domain_tracker_send_install_email` | send | emails the install script and instructions to someone, such as a developer | recipient email | this reaches a real person by tool; Launchhouse denies it, see policy.tsv, and shows the founder the script to send themselves |
| `apollo_website_visitor_domain_tracker_update` | write | changes tracker settings | settings | |
| `apollo_website_visitors_domain_aggregates` | read | reads aggregate visitor counts and trends | date range | |

## Workflows for Launchhouse jobs

**Connect and prove.** `connect-tools` calls `apollo_users_api_profile` and reads back "Connected to Apollo as <email>". It then calls `apollo_email_accounts_index`; if a mailbox is linked, it records the address, otherwise it tells the founder to link one in Apollo. Nothing is written to the folder here beyond `growth-engine/.state/setup.md`.

**List of 25 from criteria.** `apollo-sequence` runs `apollo_mixed_people_api_search` with the tight criteria from the outreach engine, free of charge. If under 35 good matches, it widens to medium then broad, saying which it used. About 35 candidates are shown to the founder as a table, and cut to 30 with them: a first pass on fit, before any credit is spent. Nothing is written to Apollo yet; the 30 become person files in `growth-engine/people/`. The second cut, 30 down to the final 25, happens after enrichment below, once addresses that will not verify are already gone.

**Enrichment with shown credit cost.** Before any call to `apollo_people_bulk_match` or `apollo_people_match`, the founder is told the estimated credit cost for the people who do not already have an address, and only enriched after a clear yes. When the response carries an `mcp_credits` block, that estimate, and after the call the credits used and new balance, are always said unprompted, per this connector's own MCP server instructions. People with no deliverable address are cut. If more than 25 remain, the founder cuts to 25 with the file kept, never deleted.

**Paused sequence with the `first_line` field.** `apollo_fields_index` checks for a contact custom field named exactly `first_line`; if missing, the founder is asked to create it in Apollo's settings first, because a mismatch between the CSV column, the field and the sequence variable fails silently otherwise. After a yes, `apollo_contacts_bulk_create` (or `apollo_contacts_create` one at a time) adds the 25 with `first_line` set, followed by `apollo_labels_create` and `apollo_labels_add_entity_ids_to_label_names` to tag them "Launchhouse 25". `apollo_emailer_schedules_index` picks a weekday business-hours schedule the founder confirms. `apollo_sequences_create` is called with `active: false` and the touches from `outreach-sequence.md` exactly as written. `apollo_emailer_campaigns_show` reads it back to confirm it is not active, the steps match, and stop-on-reply is on. After a final yes, `apollo_emailer_campaigns_add_contact_ids` adds the 25 with the mailbox as the sending account. Starting the sequence is a button the founder presses in Apollo; nothing here can press it, and `apollo_emailer_messages_send_now` and `apollo_emailer_campaigns_approve` are both denied outright.

**Sequence health read.** `apollo_emailer_campaigns_activity_feed` and `apollo_emailer_messages_search` read what has happened: sent, bounced, opted out, replied. The `sequence-health` routine runs on the same read-only tool names on a schedule and only ever writes into `growth-engine/drafts/`. Anyone who asks to be left alone is stopped with `apollo_emailer_campaigns_remove_or_stop_contact_ids`, after telling the founder, never silently.

## Limits and quotas

- **Rate limits are per team, per endpoint, across three windows at once (per minute, per hour, per day), and scale with plan.** Free: 50/min, 200/hour, 600/day. Basic and Professional: 200/min, 400/hour, 2,000/day. Organization: 200/min, 600/hour, 6,000/day. Enrichment endpoints get a higher per-minute allowance (up to 1,000/min on paid plans), but the credit balance still caps how much can actually be enriched. Search endpoints allow up to 50,000 requests a day on paid plans. A call over any one window returns HTTP 429 with a `retry-after` header. (Source: Apollo Rate Limits.)
- **Credits are activity-based, not a flat per-call charge.** Create, update, list and manage calls cost 0 credits. Organization search and news search cost 1 credit per page. People enrichment costs 1 to 9 credits per person, depending on what comes back: roughly 1 for basic work-email data, and up to 9 more if a mobile number is included. Organization enrichment costs 1 credit. (Source: API Pricing and Credits.)
- **Plan credit allowances (unverified against this founder's own account; figures vary by source and Apollo changes them).** Independent pricing writeups describe a free plan with a small monthly credit allowance and a limited yearly cap, and paid plans (Basic, Professional, Organization) with monthly allowances in the low thousands. Apollo's own docs say to read the exact number for the founder's plan from Settings, then Billing and credits, or from `apollo_usage_stats_credit_usage_stats`, rather than quoting a fixed figure here. **(unverified)**
- **The Apollo MCP connector inherits the workspace's own credit system**, and Apollo's own MCP docs recommend requiring approval before a credit-intensive tool runs, which is exactly what this pack's ask rows do.
- Free personal Apollo accounts cannot use people or company search or enrichment at all (source: Apollo MCP docs); if search or enrichment tools are missing, that is the likely cause, not a broken connection.

## Failure modes and fixes

| Symptom | Likely cause | Fix |
|---|---|---|
| No Apollo tools appear after connecting | The sign-in did not complete, or the session started before it did | Reconnect from Settings, Connectors, then start a new conversation in this folder |
| `apollo_users_api_profile` returns not authorised | The Apollo sign-in expired or was revoked | Reconnect the Apollo.io connector from Settings, Connectors |
| A search or enrichment tool is missing entirely | The connected Apollo account is a free personal account, which cannot use search or enrichment | Tell the founder search and enrichment need at least a paid Apollo seat; sending on the manual route needs no Apollo plan at all |
| `apollo_people_bulk_match` returns far fewer emails than people sent in | Not every match verifies a deliverable work email | Report the true count found, cut people with no address, never pad the list |
| A 429 or "too many requests" response | The team's per-minute, per-hour or per-day rate limit was hit | Wait a minute and try again; do not retry in a tight loop |
| The sequence shows `active: true` after creation | A tool call was made without `active: false`, or a later update flipped it | The base guard denies any call carrying `active: true`; if one somehow lands active, tell the founder immediately and have them pause it in Apollo before doing anything else |
| First lines do not show up in the sequence preview | The contact custom field is not named exactly `first_line`, or the create call did not set it | Check `apollo_fields_index` for the exact field name, then set it with `apollo_contacts_update` if the create call could not |
| `apollo_emailer_campaigns_add_contact_ids` fails with no mailbox found | No mailbox is linked in Apollo, or the mailbox id passed does not match a linked one | Check `apollo_email_accounts_index` first and use the id it returns |

## Rules that apply here

Apollo sits under the same six rules as every connected tool (`CLAUDE.md`) and the same connector tiers as every other tool (`.claude/references/connections.md`). In short, for Apollo specifically:

- **Rule 1 (one track).** Apollo only ever appears for a B2B founder. A B2C founder's Track is `b2c`; this pack, its specialist and its skill are never offered to them.
- **Rule 2 (no automated cold DMs).** Does not apply to Apollo directly, since Apollo sends cold email, not Instagram DMs; the parallel rule here is Rule 3.
- **Rule 3 (25 messages).** The sequence and the list are both built to match this: a paused sequence, and 25 contacts, never more sent by tool.
- **Rule 4 (kept in `growth-engine/`).** Person files, `outreach-firstlines.csv` and everything about the sequence's content live in the folder, never only in Apollo.
- **Rule 5 (never invent proof).** Touch 2's proof, and every first line, comes from the Brain and the founder's own words, never from Apollo's data alone.
- **Rule 6 (the founder's voice).** Apollo's own AI drafting tool (`apollo_agent_draft_sequence_copy`) is never used to originate the founder's sequence copy; that is written in `outreach-b2b` from the Brain's Voice section.

See `.claude/references/connections.md` for the full connector tiers (refused outright, asks first, guided, silent) that apply to every tool, Apollo included.

## Sources

- Apollo MCP: <https://docs.apollo.io/docs/apollo-mcp> (checked 2026-09-21)
- Apollo MCP product page: <https://www.apollo.io/product/mcp> (checked 2026-09-21)
- API Pricing and Credits: <https://docs.apollo.io/docs/api-pricing> (checked 2026-09-21)
- Rate Limits: <https://docs.apollo.io/reference/rate-limits> (checked 2026-09-21)
- View API Usage Stats and Rate Limits: <https://docs.apollo.io/reference/view-api-usage-stats> (checked 2026-09-21)
- Link Your Mailbox to Apollo: <https://knowledge.apollo.io/hc/en-us/articles/4409127806093-Link-Your-Mailbox-to-Apollo> (checked 2026-09-21)
- Configure a Sequence Sending Schedule: <https://knowledge.apollo.io/hc/en-us/articles/4409477927309-Configure-a-Sequence-Sending-Schedule> (checked 2026-09-21)
- Use Custom Dynamic Variables: <https://knowledge.apollo.io/hc/en-us/articles/4409494161677-Use-Custom-Dynamic-Variables> (checked 2026-09-21)
- Create a Custom Field: <https://docs.apollo.io/reference/create-a-custom-field> (checked 2026-09-21)
- Create Custom Account Fields: <https://knowledge.apollo.io/hc/en-us/articles/4412498754445-Create-Custom-Account-Fields> (checked 2026-09-21)
- Create a Sequence: <https://docs.apollo.io/reference/create-sequence.md> (checked 2026-09-21)
- Activate a Sequence: <https://docs.apollo.io/reference/activate-sequence.md> (checked 2026-09-21)
- Send Email Now: <https://docs.apollo.io/reference/send-email-now.md> (checked 2026-09-21)
- Apollo MCP OAuth server metadata: `https://mcp.apollo.io/.well-known/oauth-authorization-server` (this session's own MCP server instructions, checked 2026-09-21)
- Apollo Rate Limits, third-party mirror with the same figures as the docs page above: <https://apis.io/rate-limits/apollo/apollo-rate-limits/> (checked 2026-09-21)

Plan credit allowances and per-plan pricing figures are marked **(unverified)** above: several independent pricing writeups disagree on exact numbers and Apollo's own docs point to the account's own billing page instead of a fixed figure, so none is repeated here as fact.

## Refreshing this pack

1. Re-run ToolSearch for the Apollo connector's tools to get the current live suffix list, and diff it against `inventory.txt`. Add new suffixes, and mark any that disappeared rather than deleting their row outright, so a founder mid-refresh can see what changed.
2. Re-check every URL in Sources still resolves and still says what is quoted here; update `verified_on` in `pack.md` regardless of whether anything changed.
3. Re-run the validator and the test suite once they exist in this repository (`sh .claude/scripts/tool-packs.sh --validate apollo`, `--compile`, `--test apollo`), or, until then, replay the `tests.tsv` cases directly against `.claude/scripts/mcp-guard.sh` the way `.claude/tests/run.sh` replays its own fixtures.
4. Re-run the `rules-reviewer` agent on this file and `evals.md` before calling the refresh done.
