# GoHighLevel knowledge

The SME reference for GoHighLevel inside this folder. Read `pack.md` alongside this file. The shared rules and the two connector shapes are documented once, in `../../../references/connections.md`; this file does not restate them, only points to them and adds what a founder's Claude needs on top.

## Mental model

GoHighLevel is one CRM per business, called a **location** (a sub-account, under an **agency**). Everything a founder does here hangs off that one location id.

- A **contact** is a person in the CRM: name, phone, email, tags, custom fields. Contacts move through **opportunities** in a **pipeline**, stage by stage, but Launchhouse never touches opportunity stages beyond the ask-gated update case in the tool map below.
- A **conversation** is the thread of messages with one contact, across SMS, email, and the connected social channels. Launchhouse only ever replies inside one that already holds a message from that contact (never opens one).
- **Social Planner** holds the connected social accounts (Facebook Page, Instagram Business or Creator, LinkedIn, and others) and the posts made against them: drafts, scheduled, and published, each with its own post id and per-account status.
- A **custom value** is one named, reusable piece of text the account keeps once, referenced by name inside workflow messages and templates. `ghl-values` writes and pastes these.
- A **workflow** is an automation: a trigger, a sequence of steps, and an exit. Launchhouse never creates, edits, or triggers one; the whole operations engine works by loading a pre-built **snapshot** (a packaged set of workflows, pipelines, and other account objects) at the clinic and only ever filling in its custom values and publishing it.
- An **operation**, in the account connector's own vocabulary, is one named unit of API behaviour (for instance, "get conversation messages" or "create a contact"). `execute_operation` runs exactly one operation at a time, with the inputs `describe_operation` said it needs.

## Connecting and auth

The sub-account install through GoHighLevel's own link comes first, before the connector is added in Claude; `../../../references/connections.md` holds the link. That install page is on LeadConnector's site, which is GoHighLevel's own company, so the founder signs in there with the same email and password they use for GoHighLevel.

The connector is named **HighLevel**, added from Settings, then Connectors, then Add custom connector, at `https://services.leadconnectorhq.com/mcp/anthropic/v2`, and signed in with OAuth: the founder reviews and approves a scope list on GoHighLevel's own consent screen, and only the operations those scopes cover are ever available to `execute_operation`. It works the same way in Claude Code, Cowork, the browser, and on a phone (documented: HighLevel MCP for Claude help page).

The fallback, Code only, uses a Private Integration key the founder makes themselves in the location's own Settings, then Private Integrations, stored in the computer's own password store and read by `.claude/scripts/ghl-headers.sh`, never pasted into a file or the chat. Private Integration keys do not expire on their own; they stop only when deleted or rotated, and GoHighLevel recommends rotating one every 90 days as good practice (documented: connections.md, citing GoHighLevel's own help pages).

GoHighLevel's own two pages disagree about the key route. The Claude help page (help.gohighlevel.com article 155000008360, checked 2026-09-22) says a Private Integration key is passed as `Authorization: Bearer pit-...` to the same `/mcp/anthropic/v2` address this folder already uses, and notes a key carries fewer scopes than signing in. The developer docs page (marketplace.gohighlevel.com/docs/other/mcp/, checked 2026-09-22) says that address is sign-in only, and documents keys instead against the plain MCP endpoint, without the `/anthropic/v2` ending. This pack follows the Claude help page. Nothing in the fallback above changes on account of this, and it stays unproven until a founder's own key is checked against it.

Full connecting and proving steps, both shapes, live in `connect-tools`, step 1. This pack never repeats them.

**What breaks:** signing in with the agency account rather than the sub-account gives the wrong scopes and the wrong data; the account connector needs to be reconnected (disconnect, reconnect, new conversation) after some scope or session changes; a Private Integration key made in the agency rather than the location fails every call with "not authorised."

## Tool map

Every tool in `inventory.txt` appears here exactly once. `class` is one of read, write, send, spend; nothing in this pack spends money, so no row is class spend.

| tool | class | what it does | inputs that matter | gotchas |
|---|---|---|---|---|
| `list_locations` | read | Lists the sub-accounts (locations) this connection can reach. The job that proves the connection: reading the business back to the founder. | none required | Silent under `mcp-guard.sh`; a clear read by name. |
| `search_operations` | read | Finds the right operation for a job, by domain and keyword, across the connector's full catalog (documented: 550+ to 625 operations across roughly 38 to 40 domains, HighLevel help and marketplace docs disagree on the exact count). | a keyword or domain, e.g. "custom values", "conversations send message" | Never skip this step for an operation id remembered from a previous session; GoHighLevel's own operation names can change (connections.md). |
| `describe_operation` | read | Reads what a named operation needs: its required and optional inputs, and (documented) the scopes and safety notes tied to it. | the operation id `search_operations` returned | Run this every time before `execute_operation`, even for an operation used before. |
| `execute_operation` | write | Runs one named operation, with only the inputs `describe_operation` listed. This is GoHighLevel's one general-purpose write tool, and the only one that can reach payments, deletes, or workflows if misused, so `ghl-op.sh` classifies the whole input, never the tool name, on every call. | the operation id, and only the fields `describe_operation` named | Never pass a field `describe_operation` did not list. Classified deny, ask, guide, or silent by `ghl-op.sh`; see Rules that apply here. |
| `search` | read | A general-purpose read across the account's records (contacts, conversations, and more), by free text. | a search term | Only routed to the GoHighLevel classifier when the input carries a GoHighLevel marker (`lh_ghl_shaped` in `ghl-op.sh`); otherwise it is judged like any other connector's `search`. |
| `fetch` | read | Retrieves the full detail of one record `search` returned. | a record id or reference from `search`'s own result | Same shape gate as `search`. |
| `locations_get-location` | read | Fallback shape's one-per-job equivalent of reading the business back. | none required | Only present when the fallback connection is in use, not the account connector. |
| `get-account` | read | Reads the Social Planner accounts connected for posting (the platforms and account names available to post to). | none required | Fallback shape. |
| `create-post` | write | Creates a Social Planner post, as a draft or scheduled, on one or more connected accounts. | the account id(s), the post text, media if any, draft or a scheduled time | Fallback shape. Never call without first showing the founder the exact table `publish-content` builds and getting a yes (Ask, this pack's policy.tsv). |
| `edit-post` | write | Edits a post already created, by its post id. | post id, the changed field(s) | Fallback shape. Only ever a post the founder named, per `publish-content`. |
| `get-post` | read | Reads one post back by its id, to confirm what actually went in. | post id | Fallback shape. |
| `get-posts` | read | Lists posts, for reviewing what is scheduled or has gone out. | filters such as account or date range | Fallback shape. |
| `get-social-media-statistics` | read | Reads how posts performed: engagement figures GoHighLevel returns for a date range. | account id(s), a date range (defaults to the last 7 days versus the previous 7, documented: Get Statistics endpoint) | Fallback shape. Never invented or compared to a benchmark nobody gave; report only what it returns. |
| `conversations_send-a-new-message` | send | Sends a message inside an existing conversation thread with one contact. | conversation or contact id, the message body | Fallback shape. Only ever a reply, only after reading the conversation and confirming it holds a message from that contact first (never a first message). |
| `contacts_get-contacts` | read | Reads contacts back, used to prove contacts are readable and, more generally, to look one up. | none required for the read-back; a search filter otherwise | Fallback shape. Never show a contact's full details when the job is only proving the connection. |

### The domains the account connector actually reaches (documented, not exhaustive)

When the account connector is in use, `search_operations` and `execute_operation` reach far more than the fallback's nine named tools: contacts, conversations, opportunities, calendars, payments, products, invoices, Social Planner, blogs, emails, forms, funnels, workflows, and more (documented: HighLevel MCP help page says 625 operations across 40 domains; GoHighLevel's own marketplace docs say 550+ across 38, as of the dates below). This pack's jobs only ever use a handful of them, listed in the Workflows section's operations sub-table. Never call an operation this pack's jobs do not name without first showing the founder what it does and why.

## Workflows for Launchhouse jobs

Every job below follows `../../../references/connections.md`'s rules in full: never hard-code an operation id, search then describe then execute, and show the founder exactly what will go out, where, and when before any write. The job skill named for each is the one to run; this pack does not repeat its steps, only names where the founder's yes sits and what lands in the folder.

**Connect and prove.** `connect-tools`. Reads `list_locations` (or `locations_get-location`), the Social Planner accounts, and one contact. No founder yes needed; these are reads. Writes `growth-engine/.state/setup.md`.

**Social publishing.** `publish-content`. Shows the founder a table of every piece, account, and time before anything is created (`create-post` / the account connector's post-create operation). Founder's yes covers exactly that table. Writes post ids and status back into `engines/content/content-30.md`'s matching ledger rows and `log/ops-log.md`.

**Post stats.** `publish-content`, "how did my posts do". Reads `get-social-media-statistics` (or the account connector's statistics operation). No write, no yes needed; report only what GoHighLevel returns.

**Reply to someone who wrote first.** `publish-content` and, more generally, any skill handling an inbound reply. Reads the conversation first and checks it holds a message from that contact. Only then shows the founder the exact reply text and waits for a yes before `conversations_send-a-new-message` (or the account connector's conversation-message-create operation). Never a first message to someone who has not written; that always goes by the founder's own hand.

**Contacts read.** Any job proving contacts are readable, or looking one up before a reply. `contacts_get-contacts`, or the account connector's contact-search or contact-get operation. Read only; never shown to the founder as more than "contacts are readable" unless the job specifically needs the one contact's own details.

**Custom values.** `ghl-values`, step 7. Reads what already exists, shows the founder the whole create-and-update list before anything is written, and one yes covers every create and change on that list. Prefers the account connector: `search_operations` for a custom-values operation, `describe_operation` to read what it needs, then `execute_operation` following that shape. Falls back to `ghl-values-api.sh` (a separate, founder-made Private Integration token, never the connection's own key) only when the account connector has nothing for custom values or is not connected. Writes `engines/ops/ghl-values.md` and, once pasted in, the account itself.

**Snapshot and workflow copy.** `ghl-workflows` and `audience-b2c` (its inbound-scripts step). Neither one calls a GoHighLevel tool. They write the copy that later gets pasted into the snapshot's own message slots by hand, or by the custom-values job above. Never create, edit, or trigger a workflow from here, ever; the snapshot brings the workflow.

### GoHighLevel operations these jobs use via `execute_operation`

Named by domain and job, never by a fixed operation id, because GoHighLevel's operation names can change (`connections.md`). Before any of these, run `search_operations` for the keywords in the middle column, then `describe_operation` on whatever it returns.

| Job | Search for (domain / keywords) | Class | Founder's yes |
|---|---|---|---|
| Read back the business | locations, get location | read | none |
| Social accounts to post to | social planner, accounts | read | none |
| Create or edit a post | social planner, post, create / edit | write | yes, on the exact table |
| Read a post back | social planner, post, get | read | none |
| How posts did | social planner, statistics | read | none |
| Reply to someone who wrote first | conversations, send message | send | yes, and the conversation must already hold a message from them |
| Look up or read a contact | contacts, search / get | read | none |
| Custom values, create or update | locations, custom values, create / update | write | yes, on the whole list before any write |

## Limits and quotas

- **API rate limits (documented, GoHighLevel developer docs, Rate Limits page):** a burst limit of 100 requests per 10 seconds, and a daily limit of 200,000 requests, each per Marketplace app per resource (location or agency). A single location's own jobs here are nowhere near this, but a founder running several skills back to back that each re-read the same data could still see a burst throttle; if a call fails with a rate-limit error, wait roughly a minute and try again (this matches the "too many requests" row in `connect-tools`'s own table).
- **Social Planner statistics date range (documented, Get Statistics endpoint):** defaults to the last 7 days versus the previous 7 when no range is given.
- **Claude account connector plan limit (documented, Claude help, custom connectors):** the free Claude plan connects one custom connector; that is all GoHighLevel needs, so a founder on the free plan never needs to upgrade just to connect it.
- **Custom values per snapshot (this project's own count, `references/values.md`):** 28 to 51 values depending on track and hybrid flag; not a GoHighLevel limit, a Launchhouse one.
- **Private Integration key scope (documented, GoHighLevel help):** a key only reaches what its own ticked permissions cover; it never auto-refreshes and is rotated by hand.

## Failure modes and fixes

| Symptom | Likely cause | Fix |
|---|---|---|
| No GoHighLevel tools appear after connecting | Most often the sub-account install through GoHighLevel's own link was never done, so the sign-in window in Claude finishes but nothing comes back; less often, the account connector session did not finish, or needs a fresh conversation to pick it up | Open the install link in `../../../references/connections.md`, pick the business's sub-account (never the agency), and approve; then connect **HighLevel** again in Settings, then Connectors, in a new conversation in this folder. |
| No GoHighLevel tools after reopening (fallback) | The key or the connection file did not take, or the app did not start the fallback server | Run `sh .claude/scripts/ghl-headers.sh --check < /dev/null`, fix what it names, then `--connect`; quit and reopen the app, saying yes to the **highlevel** server if asked. |
| `execute_operation` returns "not authorised" | Wrong sub-account (agency instead of location), or the OAuth scope for that operation was never granted | Reconnect signed in to the correct sub-account; on the fallback, remake the Private Integration key in the location, not the agency. |
| `execute_operation` fails with "too many requests" | The burst or daily rate limit was hit | Wait roughly a minute (burst) or the rest of the day (daily) and retry; never loop retries immediately. |
| A reply never sends | `ghl-op.sh` classified it `ask` (every conversations write does) and the founder had not yet said yes, or the conversation held no message from that contact | Show the founder the reply and the conversation, get a clear yes, and only reply to someone who wrote first. |
| A post, contact change, or custom-value write is asked about even in auto mode | This is by design: conversations/messages, a social post create or edit, a template create, a contact touch, and an opportunity update are the small named `ask` set `ghl-op.sh` and `policy.tsv` both hold to, regardless of permission mode | Show the founder exactly what it will do and get a yes; this is not a bug to route around. |
| A payments, delete, or workflow-shaped call is refused outright | `ghl-op.sh`'s refuse word list matched (payments, billing, delete, workflow create/edit/trigger, and more), or this pack's `policy.tsv` matched | This is a hard stop by design. Never retry with different wording to route around it; if the founder genuinely needs it, they do it themselves in GoHighLevel. |
| Custom values paste in but a workflow still sends PLACEHOLDER | The value's name was changed after the snapshot built its key from it, or a different pack's value was pasted into the wrong slot | Never rename a custom value once made; re-paste into the correctly named slot. See `ghl-values` step 8. |

## Rules that apply here

The six rules in `CLAUDE.md`, and the guard behaviour, are documented once in `../../../references/connections.md` ("How a tool call is checked" and the GoHighLevel section). This pack does not restate them; three points specific to GoHighLevel worth naming:

- **Rule 2 and 3 (no cold DM automation, B2B is 25 messages):** GoHighLevel's own conversations tool can send, but Launchhouse only ever routes it at a reply to someone who already wrote first (`ghl-op.sh`'s ask case), never a first message; the 25 always go out by the founder's own hand, on whichever channel.
- **Rule 5 (never invent proof):** applies to every custom value and every workflow message this pack's jobs write, before it ever reaches the account; `ghl-values` and `ghl-workflows` both route their output through the `rules-reviewer` agent.
- **The refused and asked sets are GoHighLevel-specific and fixed** by `ghl-op.sh`: refused outright covers payments, billing, deletes, and anything workflow- or campaign-shaped that is not a plain read; asked even in auto mode covers conversations and messages, a social post create or edit, a template create, a contact touch, and an opportunity update. See `tests.tsv` for the exact cases this pack checked against the real hook.

## Sources

- HighLevel Support, MCP multi-account support for Claude: <https://help.gohighlevel.com/support/solutions/articles/155000008360-highlevel-mcp-multi-account-support-for-claude> (checked 2026-09-21)
- HighLevel developer docs, LeadConnector MCP server: <https://marketplace.gohighlevel.com/docs/other/mcp/> (checked 2026-09-21)
- HighLevel developer docs, Rate Limits: <https://marketplace.gohighlevel.com/docs/other/rate-limits/> (checked 2026-09-21)
- HighLevel developer docs, Social Planner, Create post: <https://marketplace.gohighlevel.com/docs/ghl/social-planner/create-post/index.html> (checked 2026-09-21)
- HighLevel developer docs, Social Planner, Get Social Media Statistics: <https://marketplace.gohighlevel.com/docs/ghl/social-planner/get-statistics/> (checked 2026-09-21)
- HighLevel developer docs, Locations, Create/Update/Get Custom Value: <https://marketplace.gohighlevel.com/docs/ghl/locations/create-custom-value/index.html>, <https://marketplace.gohighlevel.com/docs/ghl/locations/update-custom-value/>, <https://marketplace.gohighlevel.com/docs/ghl/locations/get-custom-values/index.html> (checked 2026-09-21)
- HighLevel developer docs, Private Integrations Token: <https://marketplace.gohighlevel.com/docs/Authorization/PrivateIntegrationsToken/> (checked 2026-09-21)
- Claude Help, Get started with custom connectors: <https://support.claude.com/en/articles/11175166-get-started-with-custom-connectors-using-remote-mcp> (checked 2026-09-21)
- The install-link route, via <https://marketplace.leadconnectorhq.com>, confirmed working with a real founder on 2026-09-22, and its scope list checked against GoHighLevel's own published list. Reported by Launchhouse, not GoHighLevel documentation.
- HighLevel Support, MCP multi-account support for Claude: <https://help.gohighlevel.com/support/solutions/articles/155000008360-highlevel-mcp-multi-account-support-for-claude> (checked 2026-09-22)
- HighLevel developer docs, LeadConnector MCP server: <https://marketplace.gohighlevel.com/docs/other/mcp/> (checked 2026-09-22)

Every operation count, rate limit figure, and endpoint name above is marked `documented` because no live HighLevel connector was visible via ToolSearch in this build session. The tool map's fallback rows and the `class` column follow `connections.md`'s own account of what each shape gives, which is this project's own source, not GoHighLevel's; treat those as `(unverified)` against a live account until `connect-tools` proves the connection.

## Refreshing this pack

1. Re-run ToolSearch for a HighLevel connector (`list_locations`, `execute_operation`, and the rest) to see whether this session can now observe it live; if so, update `inventory.txt`'s source line to `observed` and re-check every row in the tool map against what the connector actually returns from `describe_operation`.
2. Re-check every URL in Sources; GoHighLevel updates its own docs without notice, and the operation-count figures in this file already disagree between two of GoHighLevel's own pages.
3. Re-read `.claude/scripts/ghl-op.sh` and `.claude/scripts/mcp-guard.sh` in full; if either has changed, re-derive the refuse and ask word lists in "Rules that apply here" and the Failure modes table from the current script, not from memory of this file.
4. Run `sh .claude/tests/run.sh` (or however this project's test runner is invoked) and confirm every row in `tests.tsv` still matches; update any that no longer do, and say so in the pack's own change history if one exists.
5. Update `verified_on` in `pack.md`'s frontmatter to the date this refresh was done.
