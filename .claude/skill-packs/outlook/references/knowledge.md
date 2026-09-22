# Microsoft 365 (Outlook) — knowledge

## Mental model

Outlook's mailbox holds messages, organized by folder (Inbox, Sent Items, Junk, and any custom folder or category the founder has), plus a calendar of events. On the two tools Launchhouse has ever actually used, `outlook_email_search` and `outlook_calendar_search`, a "search" is a read: mail search looks across the primary mailbox, archive folders, and any shared mailbox the founder has delegate access to, and returns matching messages with sender and date filters. There is no thread object the way Gmail has one; a "conversation" in Outlook is a chain of messages sharing a subject, and this pack treats each message it finds as its own unit: who sent it, and when. A draft, once drafting is on for a founder, is the same idea as Gmail's: an unsent message sitting until the founder opens it and presses Send. A category is Outlook's rough equivalent of a Gmail label: a tag a message or thread can carry, applied with `outlook_modify_labels` or `outlook_modify_thread_labels`.

## Connecting and auth

Connector name: **Microsoft 365**, signed in from the Claude app's Settings, then Connectors, with the founder's own work Microsoft 365 account. It needs a Microsoft Entra tenant tied to a Microsoft 365 business plan; a personal account (`@outlook.com`, `@hotmail.com`) cannot connect. Source: the Microsoft 365 connector's own product page (see Sources).

Read tools (`Mail.Read`, `Mail.ReadBasic`, `Mail.Read.Shared`) work without any extra step once the founder signs in. Write tools were reported added 2026-07-07 and are **off by default**, per Anthropic's own security guide, for every connector, including one already in use before they existed. Turning them on needs a Microsoft Entra administrator to approve the added permission, and an organization owner to enable the write tools in Claude's own connector tool permissions; "Always allow" is not supported for the send, forward, send-draft or event tools specifically, so even once enabled, those keep asking. For a solo founder, the administrator and the organization owner are usually the same person: the founder themselves, in their own Microsoft 365 admin center and their own Claude connector settings. Source: Microsoft 365 connector security guide (see Sources).

What breaks: signing in with a personal account instead of the work Microsoft 365 one (the connector will not connect at all); a revoked consent (tools disappear, reconnect from Settings, then Connectors); an administrator who has not approved the connector for the organization (the founder needs to ask whoever runs their Microsoft 365, which is often the founder themselves in a small business); write tools staying invisible because they were never separately turned on in Claude's own connector tool permissions, even once the Microsoft Entra side is approved.

## Tool map

| tool | class | what it does | inputs that matter | gotchas |
|---|---|---|---|---|
| `outlook_email_search` | read | Searches mail with sender and date filters, across the primary mailbox and any shared mailbox the founder can access. | sender, date range, keywords | The tool Launchhouse has actually seen connected on a founder's account, used for the reply check. If it cannot show who a message is from, say so plainly and ask the founder. |
| `outlook_calendar_search` | read | Searches calendar events. | date range, keywords | Observed on a connected account. Launchhouse has no job that needs this today. |
| `find_meeting_availability` | read | Finds open meeting times across one or more calendars. | attendees, date range | Documented, not observed. Not covered by this pack's own policy (its suffix does not begin with the word "outlook"); Launchhouse has no job that needs it. |
| `outlook_send_mail` | send | Sends an email as the founder. | to, subject, body | Documented, not observed. Denied by this pack's own policy outright: Launchhouse never sends from a founder's mailbox by tool, whatever an administrator turns on. |
| `outlook_forward_mail` | send | Forwards an existing message. | message id, to | Documented, not observed. Denied by this pack's own policy outright, same as above. |
| `outlook_send_draft` | send | Sends an existing draft as-is. | draft id | Documented, not observed. Denied by this pack's own policy outright: a draft is for the founder's own Send, never this tool's. |
| `outlook_create_draft` | write | Creates a new draft email. | to, subject, body | Documented, not observed working on any Launchhouse founder's account yet. Once the caller's tool list actually shows this suffix, treat it like Gmail's `create_draft`: one call per person, show the founder first, never followed by `outlook_send_draft`. Anthropic's guide notes attachments are rejected by every write tool. |
| `outlook_create_reply_draft` | write | Creates a draft reply to one message. | message id, body | Documented, not observed. Same drafting rule as above; used for a reply-in-thread the founder wants to send themselves. |
| `outlook_create_reply_all_draft` | write | Creates a draft reply-all to one message. | message id, body | Documented, not observed. Launchhouse has no outreach job that replies to more than one person at once; only use if the founder explicitly asks for a reply-all draft. |
| `outlook_update_draft` | write | Edits an existing draft. | draft id, new body/subject | Documented, not observed. Used when the founder wants a drafted email changed before they send it. |
| `outlook_delete_draft` | write | Permanently deletes a draft. | draft id | Documented, not observed. Cannot be undone. Never delete a draft the founder did not name. |
| `outlook_trash_thread` | write | Moves a thread to Deleted Items. | thread id | Documented, not observed. Recoverable with `outlook_untrash_thread` until the founder empties Deleted Items themselves. Never call it on a prospect's mail. |
| `outlook_untrash_thread` | write | Restores a thread from Deleted Items. | thread id | Documented, not observed. |
| `outlook_batch_delete_messages` | write | Deletes several messages in one call. | message ids | Documented, not observed. Denied by this pack's own policy outright: Launchhouse never deletes a founder's mail in bulk from here. |
| `outlook_create_label` | write | Creates a new category. | category name | Documented, not observed. Launchhouse has no job that needs a new category; do not invent an organizing scheme the founder did not ask for. |
| `outlook_update_label` | write | Renames or recolors a category. | label id, new name/color | Documented, not observed. |
| `outlook_delete_label` | write | Deletes a category. | label id | Documented, not observed. Removes it from every message that carried it. Never call without the founder naming the category. |
| `outlook_modify_labels` | write | Applies or changes categories on one message. | message id, category | Documented, not observed. Launchhouse has no job that needs this today. |
| `outlook_modify_thread_labels` | write | Same, for a whole thread. | thread id, category | Documented, not observed. |
| `outlook_batch_modify_labels` | write | Applies or changes categories on several messages at once. | message ids, category | Documented, not observed. Denied by this pack's own policy outright: Launchhouse never relabels a founder's mail in bulk from here. |
| `outlook_create_event` | write | Creates a calendar event. | subject, start, end, attendees | Documented, not observed. Launchhouse has no scheduling job today; only use if the founder explicitly asks and confirms the details. |
| `outlook_update_event` | write | Edits a calendar event. | event id, changed fields | Documented, not observed. |
| `outlook_delete_event` | write | Deletes a calendar event. | event id | Documented, not observed. May remove something another person is expecting; always show the founder first. |
| `outlook_respond_to_event` | write | Accepts, declines or tentatively answers an invite. | event id, response | Documented, not observed. Answers an invite for the founder; always show them first. |
| `outlook_set_vacation` | write | Turns the mailbox's automatic-reply (out-of-office) on or off. | enabled, message text | Documented, not observed. Denied by this pack's own policy outright: an auto-reply answers real people, including prospects who wrote first, without the founder seeing each one. If the founder wants one, they set it themselves in Outlook. |
| `outlook_create_filter` | write | Creates a mail rule (e.g. move mail matching a condition to a folder). | condition, action | Documented, not observed. Denied by this pack's own policy outright, the same as every mailbox's create_filter tool: Launchhouse never sets up mail rules, which can move or file a founder's mail without them seeing it. |
| `outlook_delete_filter` | write | Deletes a mail rule. | filter id | Documented, not observed. Launchhouse never sets rules up, but might need to remove one the founder names; always show them first. |

## Workflows for Launchhouse jobs

### Connect and prove

1. `outlook_email_search` for the founder's own recent sent mail.
2. Read back only the address the top result was sent from.
3. Say "Connected to the mailbox `<address>`. Is that your work email?" and record the row in `growth-engine/.state/tools.md` (state `connected`, evidence the address read back). If the search cannot show a from-address at all, record `in progress` with what it did return, and say so plainly, per `connect-tools`.

### Check for replies by search

Follows `outreach-b2b`'s "Checking for replies" section, using this pack's `outlook_email_search` in place of Gmail's `search_threads`.

1. For each person at `status: contacted_ok`, with the date of their `email out` touch line, from `growth-engine/people/`.
2. `outlook_email_search` with that person's address as the sender filter and a date range starting the day their touch 1 went out.
3. Read only who wrote and when. Never open or summarize the content of their reply beyond what is needed to record it.
4. If the search returns nothing usable, or cannot show a clear sender for a result, stop and say so plainly rather than guessing; ask the founder who has replied and record it from what they say, exactly as `outreach-b2b` describes for when no mailbox is connected.

### Record reply touches

Identical to the Gmail pack's version of this job, with the source named as Microsoft 365 instead of Gmail:
1. Set the person's `status` to `replied`.
2. Add a touch line: `- YYYY-MM-DD reply in: found in Microsoft 365`.
3. If they asked to be left alone, add a note line saying so.
4. Add one result line to `log/ops-log.md` with the count only, never a name.
5. Tell the founder who replied and remind them to cancel that person's scheduled follow-ups.

### Draft the 25 touch-1 emails, after a yes (once write tools are on)

Mirrors the Gmail pack's own version of this job, using `outlook_create_draft` in place of `create_draft`. Only runs when the caller's tool list actually shows `outlook_create_draft`; otherwise skip straight to the manual route below.

1. Confirm the fit: track is `b2b`, `engines/outreach/outreach-sequence.md` records the manual route (not Apollo), and this pack's read-back has already run.
2. Gather each candidate from `growth-engine/people/`: `kind: prospect`, not `cut`, not yet sent to. Take their email and the finished touch 1 from their `## Opener` block, and the subject line from touch 1 in `outreach-sequence.md`.
3. Show the founder a table (name, company, subject, first line) and wait for a clear yes covering exactly that table.
4. For each person, `outlook_create_draft` with their address as `to`, the subject, and the Opener block body exactly as written. Never `outlook_send_draft` or `outlook_send_mail`.
5. Add a touch line to that person's file: `- YYYY-MM-DD email drafted: touch 1 in Microsoft 365 drafts`.

### Draft follow-ups, two at a time (once write tools are on)

Same shape as Gmail's version, using `outlook_create_reply_draft` when the touch replies in the same conversation.

1. Take the next two touches due, per the wait intervals in `outreach-sequence.md`, for people at `status: contacted_ok` who have not replied.
2. Show the founder each one (recipient, which touch, the words, same conversation or new) and wait for a yes.
3. `outlook_create_reply_draft` for each, with the original message id, when the touch replies in the same conversation; `outlook_create_draft` for a fresh one.
4. Record the touch line the same way as above, naming the touch number.

### The 25, and their follow-ups, by hand (write tools off)

The route Launchhouse has actually run so far, and the fallback whenever `outlook_create_draft` is not in the caller's tool list: the founder copies each person's finished `## Opener` block from their file in `growth-engine/people/` into a new email in their own Outlook, exactly as `outreach-b2b`'s manual route already has them do. Nothing here needs a Claude tool call. Once a founder's organization turns on `outlook_create_draft` and this pack's `outlook-specialist` has actually drafted successfully on that account, switch that founder to the drafting workflow above; until it is confirmed working, this manual route stays the default even if the tool appears to exist.

## Limits and quotas

- **Exchange Online per-user sending:** 10,000 recipients in any rolling 24-hour window, 500 recipients per message by default (an administrator can raise this to 1,000), and 30 messages a minute. Source: Microsoft Learn, "Exchange Online limits" (see Sources). At 25 messages, whether drafted or sent by hand, none of this is a practical constraint.
- **Tenant-level external recipient limits, from April 2025:** Microsoft also caps how many external recipients a whole organization's tenant can email in a rolling 24 hours, based on the number of Exchange Online or Exchange Online Protection licenses the tenant holds; more licenses raise the cap, at a decreasing rate per license. Source: Microsoft Tech Community, "Introducing Exchange Online Tenant Outbound Email Limits" (see Sources). (unverified: the exact figures per license band were not confirmed against Microsoft's own documentation in this pass; treat any specific number a founder is quoted as needing its own check with their Microsoft 365 admin.)
- **Scheduled send, from the founder's own Outlook (not a Claude tool):** in the desktop Outlook app, a message set with Delay Delivery sits in the Outbox until the delivery time, and only actually goes if Outlook is running then; in Outlook on the web and the new Outlook for Windows, Schedule Send is handled by Microsoft's own cloud service, so it still sends even if the founder's computer is off. Source: Microsoft Support, "Delay or schedule sending email messages in Outlook" (see Sources).
- **Claude's own Microsoft 365 connector:** "Rate limits apply per user," per Anthropic's security guide, with no specific number given there. (unverified beyond that line.)

## Failure modes and fixes

| Symptom | Cause | Fix |
|---|---|---|
| No Outlook tools appear after connecting | The connection did not finish, or an administrator has not approved the connector for the organization | Reconnect from Settings, then Connectors; if it still fails, the founder asks whoever administers their Microsoft 365, which may be themselves. |
| Sign-in fails immediately | A personal Microsoft account (`@outlook.com`, `@hotmail.com`) was used instead of a work Microsoft 365 account | Sign in again choosing the work account. |
| `outlook_email_search` returns no from-address, or an unclear one | The connector's search output does not carry that field the way Gmail's does | Say so plainly. Do not guess who sent a message. Ask the founder directly who has replied, and record it from what they say. |
| The reply check finds nothing for someone who did reply | The date range is too narrow, or their reply is in a folder the search does not cover | Widen the date range; if still nothing, ask the founder to check their inbox directly. |
| Founder expects a drafted email and `outlook_create_draft` is not in the tool list | Write tools are not enabled: a Microsoft Entra administrator has not approved them, or an organization owner has not turned them on in Claude's connector tool permissions | Remind them the 25, and every follow-up, go out by hand from their own Outlook, copying the finished text from their person file. If they want drafting, point them to their own Microsoft 365 admin settings and Claude's connector tool permissions; for a solo founder this is usually their own click. |
| A draft tool now appears but drafting has never been tried on this account | Write tools were just turned on | Draft one, read it back with the specialist, and show the founder before treating the route as proven; keep the manual route as the fallback until it has actually worked. |
| Founder asks to send, forward, set an auto-reply, or set up a mail rule | These stay refused by this pack's own policy no matter what an administrator has turned on | Say plainly that Launchhouse never sends, forwards, auto-replies or sets mail rules from here; the founder does each of these themselves, in their own Outlook. |
| Emails sent by hand from a fresh Microsoft 365 domain are landing in the recipient's Junk folder | No sending history yet, or SPF/DKIM/DMARC not fully set up | Point to the deliverability brief in `outreach-b2b` Step 5: authenticate the domain, warm a fresh one with normal sending first, verify every address, and turn tracking off. |

## Rules that apply here

The shared rules for the mailbox live in `../../../references/connections.md` under "The mailbox" — read them there rather than here. In short, for this pack specifically:

1. **One track.** This pack only ever runs for a `b2b` founder.
2. **No Instagram DM automation.** Not this tool's concern; named here only because it is one of the six rules that binds every pack.
3. **B2B outreach is 25 messages.** This pack's jobs, checking replies and (once write tools are on) drafting, only ever cover the 25 the outreach engine built and their follow-ups.
4. **Everything is made and kept in `growth-engine/`.** What this pack writes to the folder is the touch log in each person's file; mail itself stays in Outlook.
5. **Never invent proof.** This pack never writes outreach copy. Drafts use the founder's own finished text from their person file, verbatim.
6. **The voice is the founder's.** Every draft this pack ever writes is the founder's own `## Opener` block, unchanged; this pack never generates new wording.

**Never send, forward, or auto-reply from here, whatever an administrator has turned on.** `outlook_send_mail`, `outlook_forward_mail`, `outlook_send_draft` and `outlook_set_vacation` are denied by this pack's own policy outright, the same as Gmail's send_message, reply and forward tools are denied by `mcp-guard.sh` itself. `outlook_create_draft` and `outlook_create_reply_draft` are not denied, because a draft is the desired outcome once write tools are on, but nothing here claims they work on a given account until the caller's own tool list actually shows the suffix: say plainly when drafting is off, and default to the manual route the founder already knows.

## Sources

- Microsoft 365 connector for Claude (product page): https://claude.com/connectors/microsoft-365 (checked 2026-09-21)
- Set up the Microsoft 365 connector: https://support.claude.com/en/articles/12542951-set-up-the-microsoft-365-connector (checked 2026-09-21)
- Microsoft 365 connector security guide: https://support.claude.com/en/articles/12684923-microsoft-365-connector-security-guide (checked 2026-09-21)
- Exchange Online limits (Service Descriptions): https://learn.microsoft.com/en-us/office365/servicedescriptions/exchange-online-service-description/exchange-online-limits (checked 2026-09-21)
- Introducing Exchange Online Tenant Outbound Email Limits: https://techcommunity.microsoft.com/blog/exchange/introducing-exchange-online-tenant-outbound-email-limits/4372797 (checked 2026-09-21)
- Delay or schedule sending email messages in Outlook: https://support.microsoft.com/en-us/outlook/mail/delay-or-schedule-sending-email-messages-in-outlook (checked 2026-09-21)
- Schedule send for Outlook on the web: https://support.microsoft.com/en-us/outlook/schedule-send-for-outlook-on-the-web (checked 2026-09-21)

## Refreshing this pack

Drafting on this connector is documented but still unverified against a real founder account. The single most valuable refresh is to try `outlook_create_draft` (and `outlook_email_search` for the reply check) on an actual connected Microsoft 365 account where write tools are on, and record whether it works; update this file and `../../../references/connections.md` with whatever is actually found, never before. Otherwise: re-check every source above still resolves and still says what this file claims, and re-run ToolSearch on a connected account to see which write tools actually appear for that founder. Run `sh .claude/scripts/skill-packs.sh --validate outlook`, `sh .claude/scripts/skill-packs.sh --compile` and `sh .claude/scripts/skill-packs.sh --test outlook`. Update `verified_on` in `pack.md` once done.
