---
name: gmail-expert
description: Claude's expert on the founder's connected Gmail mailbox: drafting the 25 outreach emails and their follow-ups, checking for replies, and answering how-it-works questions. Trigger on "Gmail", "connect Gmail", "connect my email", "how do I draft in Gmail", "check my Gmail connection", "put my outreach emails in my drafts", "who replied", "check for replies".
---

# Gmail expert

Makes Claude an expert on the founder's Gmail mailbox for the B2B outreach engine's manual route. Everything it knows comes from `.claude/skill-packs/gmail/pack.md` and `.claude/skill-packs/gmail/references/knowledge.md`; read both before answering anything.

**Who is reading.** A founder who does not use a terminal. Never ask them to run a command. Show plain words; never show a tool name or a suffix in chat.

## 1. Read the pack

Read `../../skill-packs/gmail/pack.md` and `../../skill-packs/gmail/references/knowledge.md`. If `verified_on` in `pack.md` is more than a few months old, say once that this pack may be out of date and offer to refresh it with the `skill-pack-builder` skill; carry on with what it knows either way.

## 2. Check the connection

Look for Gmail's tools (names ending `create_draft`, `search_threads`, and the rest in the pack's inventory). If they are not there, send the founder to `connect-tools` ("connect my email") rather than guessing at what is connected.

## 3. Route the request

| Founder asks for | Go to |
|---|---|
| Connecting or checking the connection | `connect-tools` |
| Writing the sequence, the list, or the first lines | `outreach-b2b` |
| Putting the 25 into drafts, or the follow-ups | `publish-content`'s "25 outreach emails" section, which calls this pack's tools |
| Who has replied | `outreach-b2b`'s "Checking for replies" section, which calls this pack's tools |
| "How does Gmail scheduled send work", "what's Gmail's sending limit", any how-it-works question | Answer from `knowledge.md` directly, in this skill |
| Anything about Apollo, or about a B2C founder's Instagram DMs | Not this pack. Say so and point to the right skill (`apollo-sequence`, `audience-b2c`) |

## 4. The approval dance

Whenever a job needs Gmail to change something (a draft, a label), this skill never calls a mail tool itself. It calls the `gmail-specialist` agent:

1. Call it with `PHASE: plan` and the job (draft the 25, draft two follow-ups, and so on).
2. Show the founder every proposed action from its `## Proposed actions`, exactly as it will appear: who, what, and in their own words, not tool language.
3. Wait for a clear yes covering exactly what was shown.
4. Grant it: `sh .claude/scripts/approve.sh --grant gmail create_draft:<count>` (or the exact suffix and count of what was just shown and approved).
5. Call the specialist again with `PHASE: execute` and the approved actions, verbatim.
6. Clear the grant: `sh .claude/scripts/approve.sh --clear gmail`.
7. Report back what happened, in the founder's plain words, and update the person files and `growth-engine/.state/tools.md` as the calling skill's own steps say.

Never skip the plan phase, and never show the founder anything the specialist did not actually propose. A read never needs a grant. If `approve.sh` refuses the grant, or the specialist reports a call was denied, that is the answer: say so plainly and do not try again with different wording.

## 5. Record the connection

Keep `growth-engine/.state/tools.md` current, in the shape in `../../references/contract.md`:

```
| gmail | Gmail | connected | b2b outreach | 2026-09-21 | read back address sam@northfield.io |
```

Update the row whenever this skill checks the connection or drafts something new.

## 6. Answer how-it-works questions

For "how does X work" questions about Gmail itself (scheduled send, search operators, sending limits, why a message might land in spam), answer from `knowledge.md`'s Limits and quotas, Failure modes and fixes, and Workflows sections, in plain words with no jargon. Say once that this file was last checked on `verified_on` and things vendors control can change, and offer to refresh it if the founder wants current numbers double-checked.

**Never draft or send anything from this step.** Answering how scheduled send works, for example, is just an explanation; it never means Claude does the scheduling. Gmail's own scheduled send is a button in the founder's own Gmail, not a Claude tool.

Deliverability depends on the sending domain's DNS records being correct (SPF, DKIM, DMARC). If the founder's outreach is landing in spam, send them to `domains-expert` (or `/growth-engine:domains`) to check and fix it.
