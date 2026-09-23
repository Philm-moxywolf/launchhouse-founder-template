---
name: outlook-expert
description: 'Claude''s expert on the founder''s connected Microsoft 365 mailbox: checking for replies, drafting once the founder''s admin has turned write tools on, and answering how-it-works questions. Trigger on "Outlook", "Microsoft 365", "connect Outlook", "connect my email", "how do I check Outlook", "check my Outlook connection", "who replied", "check for replies", "put my outreach emails in my drafts".'
---

# Microsoft 365 (Outlook) expert

Makes Claude an expert on the founder's Microsoft 365 mailbox for the B2B outreach engine. Everything it knows comes from `.claude/skill-packs/outlook/pack.md` and `.claude/skill-packs/outlook/references/knowledge.md`; read both before answering anything.

**Who is reading.** A founder who does not use a terminal. Never ask them to run a command. Show plain words; never show a tool name or a suffix in chat.

**Say this once, early, whenever drafting comes up.** On every account Launchhouse has connected so far, this connector only reads mail. Anthropic's own connector documentation now lists draft tools on it too, but they are off by default: a Microsoft Entra administrator has to approve them and turn them on in Claude's connector tool permissions before they exist on a given account. For a solo founder that is usually their own click, in their own Microsoft 365 admin settings, not a step someone else has to do. Check the founder's own tool list before assuming either way. If drafting is not on, the 25 outreach emails, and every follow-up, go out by hand: the founder copies each person's finished text from their file in `growth-engine/people/` into a new email in their own Outlook, exactly as `outreach-b2b`'s manual route already describes.

## 1. Read the pack

Read `../../skill-packs/outlook/pack.md` and `../../skill-packs/outlook/references/knowledge.md`. If `verified_on` in `pack.md` is more than a few months old, say once that this pack may be out of date and offer to refresh it with the `skill-pack-builder` skill; carry on with what it knows either way.

## 2. Check the connection

Look for a tool whose name ends `outlook_email_search`. If it is not there, send the founder to `connect-tools` ("connect my email") rather than guessing at what is connected. Also note, without needing it for the connection check itself, whether `outlook_create_draft` or `outlook_create_reply_draft` appear: that tells you whether drafting is on for this founder today.

## 3. Route the request

| Founder asks for | Go to |
|---|---|
| Connecting or checking the connection | `connect-tools` |
| Writing the sequence, the list, or the first lines | `outreach-b2b` |
| Putting the 25 into drafts | If `outlook_create_draft` is in the founder's tool list, run the approval dance below and draft them. If it is not, say plainly that drafting is off until their Microsoft 365 administrator turns write tools on (often their own click), and point to the manual route in `outreach-b2b` (copy from each person's file, send from their own Outlook) |
| Who has replied | `outreach-b2b`'s "Checking for replies" section, which calls this pack's `outlook_email_search` |
| "How does scheduled send work in Outlook", any how-it-works question | Answer from `knowledge.md` directly, in this skill |
| Anything about Apollo, or about a B2C founder's Instagram DMs | Not this pack. Say so and point to the right skill (`apollo-sequence`, `audience-b2c`) |

## 4. The approval dance

This skill never calls a mail or calendar tool itself. It calls the `outlook-specialist` agent:

1. Call it with `PHASE: plan`. For a reply check this returns read results only, nothing to approve. For a draft request it returns a `## Proposed actions` list: one entry per person, each with the exact recipient, subject and body.
2. If `## Proposed actions` is empty, nothing needs a yes or a grant; carry straight to `PHASE: execute` and report the read results.
3. If it proposes drafts (or any other write, such as a calendar change), show the founder exactly what it proposes, in plain words, in their own timezone where a time is involved, and wait for a clear yes.
4. Grant it: `sh .claude/scripts/approve.sh --grant outlook <exact tool suffix>[:<count>] ...`, exactly the actions just shown and approved.
5. Call `PHASE: execute` with those actions verbatim.
6. Clear the grant: `sh .claude/scripts/approve.sh --clear outlook`.
7. Never let the specialist call `outlook_send_mail`, `outlook_forward_mail` or `outlook_send_draft`. They are denied by this pack's own policy: Claude drafts, the founder presses Send. If `approve.sh` refuses the grant, or the specialist reports a call was denied, that is the answer: say so plainly and do not try again with different wording.

## 5. Record the connection

Keep `growth-engine/.state/tools.md` current, in the shape in `../../references/contract.md`:

```
| outlook | Microsoft 365 (Outlook) | connected | b2b outreach, reply check, drafts once write tools are on | 2026-09-21 | read back address sam@northfield.io |
```

## 6. Answer how-it-works questions

For "how does X work" questions about Microsoft 365 itself (scheduled send, sending limits, why a message might land in Junk, how an admin turns write tools on), answer from `knowledge.md`'s Limits and quotas, Failure modes and fixes, and Workflows sections, in plain words. Say once that this file was last checked on `verified_on` and offer to refresh it if the founder wants current numbers double-checked.

**Never send or forward anything from this step, and never draft speculatively.** Only propose a draft when the caller's own tool list actually shows `outlook_create_draft` or `outlook_create_reply_draft`; otherwise say plainly that drafting is off today and point to the manual route.

Deliverability depends on the sending domain's DNS records being correct (SPF, DKIM, DMARC) in Microsoft 365. If the founder's outreach is landing in Junk, send them to `domains-expert` (or `/growth-engine:domains`) to check and fix it.
