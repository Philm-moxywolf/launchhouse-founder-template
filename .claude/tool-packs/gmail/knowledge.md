# Gmail — knowledge

## Mental model

Gmail holds three things Launchhouse cares about: **messages** (one email), **threads** (a message and its replies, grouped), and **drafts** (an unsent message sitting in the Drafts folder until the founder opens it and presses Send). Labels are Gmail's folders: a message can carry several at once (`INBOX`, `SPAM`, a custom label), and moving something to Trash or Spam is really just adding a label, not deleting it outright, which is why it can be pulled back with `untrash_message` or `unmark_message_spam`.

For Launchhouse, a draft is the unit of work: one draft per person, one send button, which only the founder ever presses. A thread is the unit of reply-checking: searching finds threads, and a thread that now holds a message from the prospect is a reply.

## Connecting and auth

Connector name: **Gmail**, one of the Google Workspace connectors. Signed in from the Claude app's Settings, then Connectors, with the founder's own **work** Google account (personal Gmail works too, since the free plan connects in full). No key, no paste. The same connection works in Code, Cowork, the browser and on a phone.

Scopes cover reading, drafting, and, if the founder later allows it in their Connectors settings, sending, replying and forwarding. Launchhouse never uses the last three: `mcp-guard.sh` refuses them outright inside this folder regardless of what the account itself allows, and `connect-tools` asks the founder to set them to **Needs approval** in their own Connectors settings too, so the same protection holds everywhere, including Cowork.

What breaks: signing in with the wrong Google account (drafts land in the wrong mailbox: check the read-back address); a revoked or expired connection (tools disappear, reconnect from Settings, then Connectors); a very large mailbox (search and read may be slower, per Anthropic's own note that performance can vary).

## Tool map

| tool | class | what it does | inputs that matter | gotchas |
|---|---|---|---|---|
| `apply_sensitive_message_label` | write | Marks one message with Gmail's sensitivity label (e.g. confidential). | message id, label | Launchhouse has no job that needs this. Never call it on a prospect's message. |
| `apply_sensitive_thread_label` | write | Same, for a whole thread. | thread id, label | As above. |
| `create_draft` | write | Creates a new draft email. | to, subject, body, thread id (to reply in-thread) | This is the core tool for outreach: one call per person, never send. |
| `create_label` | write | Makes a new Gmail label. | label name | Launchhouse has no job that needs a new label; do not invent an organizing scheme the founder did not ask for. |
| `delete_draft` | write | Permanently deletes a draft, not moved to Trash. | draft id | Cannot be undone. Never delete a draft the founder did not name. |
| `delete_label` | write | Permanently deletes a label. | label id | Removes it from every message that carried it. Never call without the founder naming the label. |
| `forward` | send | Forwards a message to someone else. | message id, to | Refused outright by `mcp-guard.sh`. Never call it. |
| `get_draft` | read | Reads one draft back. | draft id | Used to confirm a draft was written as intended. |
| `get_message` | read | Reads one message. | message id | |
| `get_thread` | read | Reads a whole thread, with every message in it. | thread id | |
| `label_message` | write | Adds an existing label to a message. | message id, label | |
| `label_thread` | write | Adds an existing label to a thread. | thread id, label | |
| `list_drafts` | read | Lists drafts in the mailbox. | (paging only) | Used to confirm what has already been drafted before drafting more. |
| `list_labels` | read | Lists the mailbox's labels. | none | |
| `mark_message_spam` | write | Marks a message as spam. | message id | Could hide a genuine reply from being found by search. Never call it while checking for replies. |
| `mark_thread_spam` | write | Marks a whole thread as spam. | thread id | As above. |
| `reply` | send | Sends a reply in an existing thread. | thread id, body | Refused outright by `mcp-guard.sh`. Never call it. |
| `search_threads` | read | Searches the mailbox with Gmail's own search operators. | query string | This is the reply-check tool. See Workflows below for the queries to use. |
| `send_message` | send | Sends a new message. | to, subject, body | Refused outright by `mcp-guard.sh`. Never call it, however the founder asks. |
| `trash_message` | write | Moves a message to Trash. | message id | Recoverable with `untrash_message`, but Gmail empties Trash after 30 days on its own. Never call it on a prospect's mail. |
| `trash_thread` | write | Moves a whole thread to Trash. | thread id | As above. |
| `unlabel_message` | write | Removes a label from a message. | message id, label | |
| `unlabel_thread` | write | Removes a label from a thread. | thread id, label | |
| `unmark_message_spam` | write | Un-marks a message as spam. | message id | |
| `unmark_thread_spam` | write | Un-marks a thread as spam. | thread id | |
| `untrash_message` | write | Restores a message from Trash. | message id | |
| `untrash_thread` | write | Restores a thread from Trash. | thread id | |
| `update_draft` | write | Edits an existing draft. | draft id, new body/subject | Used when the founder wants a drafted email changed before they send it. |
| `update_label` | write | Renames or recolors a label. | label id, new name/color | |
| `update_message_labels` | write | Sets the full label list on a message in one call. | message id, labels | Overwrites the whole label set; read it first with `get_message` so nothing already on the message is lost by accident. |

## Workflows for Launchhouse jobs

### Connect and prove

1. `search_threads` for the founder's own sent mail (Gmail's `in:sent` operator).
2. `get_message` on the top result and read back only the address it was sent from.
3. Say "Connected to the mailbox `<address>`. Is that your work email?" and record the row in `growth-engine/.state/tools.md` (state `connected`, evidence the address read back).

### Draft the 25 touch-1 emails, after a yes

Follows `publish-content`'s "25 outreach emails, into the founder's drafts" section exactly; this pack supplies the tool calls it uses.

1. Confirm the fit: track is `b2b`, `engines/outreach/outreach-sequence.md` records the manual route (not Apollo), and this pack's read-back has already run.
2. Gather each candidate from `growth-engine/people/`: `kind: prospect`, not `cut`, not yet sent to. Take their email and the finished touch 1 from their `## Opener` block, and the subject line from touch 1 in `outreach-sequence.md`.
3. Show the founder a table (name, company, subject, first line) and wait for a clear yes covering exactly that table.
4. For each person, `create_draft` with their address as `to`, the subject, and the Opener block body exactly as written. Never `send_message`.
5. `get_draft` back what was written and check it matches before moving to the next person.
6. Add a touch line to that person's file: `- YYYY-MM-DD email drafted: touch 1 in Gmail drafts`.

### Draft follow-ups, two at a time

The manual route in `outreach-b2b` schedules only two touches at a time, never all four, so there are only two to cancel if someone replies.

1. Take the next two touches due, per the wait intervals in `outreach-sequence.md`, for people at `status: contacted_ok` who have not replied.
2. Show the founder each one (recipient, which touch, the words, same thread or new) and wait for a yes.
3. `create_draft` for each, with `thread id` set when the touch replies in the same thread (the default), so it threads under touch 1 instead of starting a new conversation.
4. Record the touch line the same way as above, naming the touch number.

### Check for replies by search

Follows `outreach-b2b`'s "Checking for replies" section.

1. For each person at `status: contacted_ok`, with the date of their `email out` touch line.
2. `search_threads` with a query built from that person's address and date, for example:
   - `from:sam@example.com after:2026/09/14` — mail from them since the day touch 1 went out.
   - Add `newer_than:21d` instead of `after:` for a rolling window when an exact send date is awkward to compute.
3. For each thread returned, `get_thread` to confirm it holds a message actually from that address, not just one that mentions it.
4. Read only who wrote and when. Never open or summarize the content of their reply beyond what is needed to record it.

### Record reply touches

For each person confirmed to have replied:
1. Set their `status` to `replied`.
2. Add a touch line: `- YYYY-MM-DD reply in: found in Gmail`.
3. If they asked to be left alone, add a note line saying so.
4. Add one result line to `log/ops-log.md` with the count only, never a name: `- HH:MM result: 2 replies recorded`.
5. Tell the founder who replied and remind them to cancel that person's scheduled follow-ups. They answer each reply in their own Gmail; never answer for them.

## Limits and quotas

- **Free Gmail account:** 500 recipients a day, counting To, Cc and Bcc together. Source: Google Workspace admin help, "Gmail sending limits in Google Workspace" (see Sources). At 25 drafts, one per recipient, this is nowhere close to the cap.
- **Google Workspace account:** 2,000 recipients a day for an established account; a brand new Workspace account can start lower, often 500 a day, and ramp up over the first weeks. (unverified: Google's own admin help page does not state the exact ramp schedule; treated here as the consistent figure across deliverability sources, not Google's own documentation.)
- **Google's bulk sender rules (from February 2024):** apply only to a domain sending 5,000 or more messages a day to Gmail addresses. 25 messages is far under this threshold, so Launchhouse founders are never "bulk senders" in Google's own sense, and none of the one-click-unsubscribe requirements bind them. Authenticating the domain (SPF, DKIM, DMARC) is still worth doing at any volume, because unauthenticated mail is filtered regardless of the sender's size. Source: Google's "Email sender guidelines FAQ" (see Sources).
- **Claude's own Gmail connector:** "Rate limits apply per Google's API quotas," per Anthropic's own connector help page, with no specific number given there. (unverified beyond that line.) At 25 to 35 draft calls in a session this has never been a practical limit for Launchhouse.
- **Scheduled send, from the founder's own Gmail (not a Claude tool):** up to 100 emails can be scheduled at once. Source: Gmail Help, "Schedule emails to send" (see Sources).

## Failure modes and fixes

| Symptom | Cause | Fix |
|---|---|---|
| No Gmail tools appear after connecting | The connection did not finish, or this conversation started before it did | Disconnect and reconnect from Settings, then Connectors; start a new conversation in this folder afterwards. |
| The read-back address is not their work email | They signed in with a personal or wrong Google account | Disconnect in Settings, then Connectors, and connect again choosing the work account. |
| A draft never appears in Gmail | `create_draft` returned an id but the founder is looking in the wrong account, or the draft was later deleted | `get_draft` with the id it returned to confirm it exists; if it does, the founder is in the wrong Gmail account. |
| `search_threads` finds nothing for someone who did reply | The date filter is too narrow, or their reply landed in Spam or Promotions | Widen the date with `newer_than:` instead of an exact `after:` date; if still nothing, ask the founder to check Spam. |
| A reply search returns threads that are not actually from the prospect | A forwarded or CC'd message matched the `from:` text loosely | `get_thread` and check the actual from-address on each message before recording a reply. |
| Drafting stops partway through a batch | One call failed (bad address, connection dropped) | Say which person failed and why, in plain words; carry on with the rest only if the founder says so, the same rule `publish-content` uses for GoHighLevel posts. |
| The founder says a drafted email never sent | They have not opened Gmail and pressed Send yet, since Launchhouse never sends | Remind them: drafts wait in the Drafts folder until they open and send each one themselves. |
| Emails to a fresh domain are landing in Spam | No sending history yet, or SPF/DKIM/DMARC not fully set up | Point to the deliverability brief in `outreach-b2b` Step 5: authenticate the domain, warm a fresh one with normal sending first, verify every address, and turn tracking off. |

## Rules that apply here

The shared rules for the mailbox live in `../../references/connections.md` under "The mailbox" — read them there rather than here. In short, for this pack specifically:

1. **One track.** This pack only ever runs for a `b2b` founder. It is never offered to a B2C founder, whose track has no mailbox job at all.
2. **No Instagram DM automation.** Not this tool's concern; named here only because it is one of the six rules that binds every pack.
3. **B2B outreach is 25 messages.** This pack drafts, at most, the 25 touch-1 emails plus their scheduled follow-ups. It never drafts to a list larger than the 25 the outreach engine built.
4. **Everything is made and kept in `growth-engine/`.** Drafts themselves live in Gmail, not in this folder; what this folder keeps is the touch log in each person's file, which is the record of what was drafted and when.
5. **Never invent proof.** Draft bodies come verbatim from each person's `## Opener` block, which the outreach engine wrote from the Founder Brain. This pack never writes new copy of its own.
6. **The voice is the founder's.** Same reason: the words in a draft are whatever `outreach-b2b` already wrote in their voice, never rephrased by this pack.

**Drafts only, always.** `send_message`, `reply` and `forward` are refused outright by `mcp-guard.sh`, in every permission mode, including bypass. No policy file, local or otherwise, can re-enable them. A first message to someone who has not written first is only ever sent by the founder's own hand, from their own Send button. That is also how this pack, and the outreach engine behind it, respects the rule that automated cold contact never happens without a human pressing the button.

## Sources

- Use Google Workspace connectors: https://support.claude.com/en/articles/10166901-use-google-workspace-connectors (checked 2026-09-21)
- Gmail sending limits in Google Workspace: https://knowledge.workspace.google.com/admin/gmail/gmail-sending-limits-in-google-workspace (checked 2026-09-21)
- Email sender guidelines FAQ (Google bulk sender rules, Feb 2024): https://support.google.com/a/answer/14229414?hl=en (checked 2026-09-21)
- Schedule emails to send (Gmail Help): https://support.google.com/mail/answer/9214606?hl=en&co=GENIE.Platform%3DDesktop (checked 2026-09-21)
- Refine searches in Gmail (search operators): https://support.google.com/mail/answer/7190?hl=en (checked 2026-09-21)

## Refreshing this pack

Re-run ToolSearch to confirm this inventory still matches what Gmail's connector offers; do not call any mail tool while doing it. Re-check every source above still resolves and still says what this file claims, especially the sending-limit and bulk-sender figures, which vendors revise. Run `sh .claude/scripts/tool-packs.sh --validate gmail` and `sh .claude/scripts/tool-packs.sh --test gmail` once that script exists in this repo. Update `verified_on` in `pack.md` once done.
