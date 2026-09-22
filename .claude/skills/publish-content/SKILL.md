---
name: publish-content
description: Publish the founder's approved content through their GoHighLevel connector, as drafts or scheduled posts on the accounts they choose, after showing exactly what will go out, where and when, and getting a yes. Records every post in the ledger. Also shows what has gone out and how it did. Also puts a B2B founder's 25 outreach emails into their own Gmail drafts, never sending them. Trigger on "publish my posts", "post the next five pieces", "schedule my content", "put my posts into GoHighLevel", "what did I publish", "how did my posts do", "put my outreach emails in my drafts".
---

# Publish content

Puts approved pieces from `engines/content/content-30.md` into GoHighLevel's Social Planner, on the founder's own account.

**Who is reading.** A founder who does not use a terminal. Never ask them to run a command.

**Tools.** GoHighLevel's tools come in two shapes. `../../references/connections.md` says which tool does each job named here. Use it for every step below. **Every GoHighLevel and Gmail call goes through `ghl-specialist` or `gmail-specialist`.** A read is `PHASE: plan`. A change is: plan → show the founder exactly what it will do → a clear yes → `sh .claude/scripts/approve.sh --grant <ghl|gmail> <tool suffix>[:<count>] ...` for exactly the actions just approved → the specialist again with `PHASE: execute` and `APPROVED ACTIONS:` verbatim → `sh .claude/scripts/approve.sh --clear <ghl|gmail>` → record the result. Where a step below already shows the founder the exact thing and gets a yes, that moment is the approval. A grant `approve.sh` refuses is not a rule to work around: say plainly that it was not granted, and return to the main conversation.

**The promise.** Nothing goes out that the founder has not read, approved, and said yes to publishing, with the account, the time and the words in front of them.

## 0. Before starting

**Check the gate first.** Read `growth-engine/.state/gate-state.md`. Publishing reads the Gate B rows `pieces` and `approved`. If either is `not done`, say in one plain sentence what is missing, using the row's evidence, then offer to carry on and publish whatever is approved. Never hold a founder up for working out of order.

1. **Check the folder.** Read the session context. If it says this is not the founder folder, stop and tell them which folder to open.
2. **Check GoHighLevel is connected,** in either shape. If it is not, stop and run `/growth-engine:connect`.
3. **Read these:**
   - `growth-engine/brain/founder-brain.md`, for the track
   - `growth-engine/engines/content/content-30.md`
   - the `C|` rows in `growth-engine/log/ledger.md`
   - `growth-engine/.state/profile.md`, for their timezone
4. **If there is no content,** send them to `/growth-engine:content`.
5. **If there is no timezone,** ask where they are before scheduling anything.

## 1. Choose the pieces

Only pieces at `approved` can be published.

If the founder asks for "the next five", take the first five approved rows that have no post id, in ledger order.

A row's id says where its words are: a plain number is that piece in `engines/content/content-30.md`, and `<suffix>-<n>` is piece n in `engines/content/content-30-<suffix>.md`. Always publish the words from that file, exactly as they are there.

If a piece's words have changed since its row was approved, the approval no longer matches the words. Say so, show the piece again, and publish it only if they approve it as it now reads.

**If they name pieces that are still `draft`:**
1. Show each one in full.
2. Ask whether they have read it and approve it.
3. Approve only those they say yes to, by setting the row to `approved`.

Reading a piece in this conversation and saying yes is approving it. Silence is not.

**Pictures.**
- A piece whose lane is `media` is still waiting on a clip or photo. Ask whether they have it now and it is in their GoHighLevel Media Library. If not, leave it out and say which ones wait for pictures. If they have it, set the lane to `text`.
- A piece with a `media_note` naming a picture they have goes out as a draft, so they attach the picture in Social Planner before it goes live. Say that plainly.

## 2. Check the words again

The founder may have edited pieces by hand since they were written. Use the `rules-reviewer` agent on the chosen pieces only.

**If it holds a line:**
- Show it.
- Leave that piece out of this batch.
- Offer to fix it: a figure goes in the Brain if it is real, otherwise the line is rewritten.

## 3. Choose where and when

1. **Get the accounts to post to,** and match each piece to the right accounts by its `platform` in the matching sheet: `engines/content/content-30.csv` for a plain id, `engines/content/content-30-<suffix>.csv` for an archived one.
   - B2B pieces usually go to LinkedIn.
   - B2C pieces go to Instagram and the Facebook Page.
   - If a platform is not connected, say so, and do not post that piece there.
2. **Ask draft or scheduled.**
   - **Draft** is the default. It puts the post in Social Planner for them to check and send.
   - **Scheduled** needs a date and time for each piece. Suggest a spread of no more than one post a day per account, at a time that suits their audience, and let them change it.
3. **Times.** Take every time the founder gives as their own time, in the timezone from their profile. If the tool asks for UTC, convert it, and check the conversion across any clock change.

## 4. Plan it, show exactly what will happen, then wait

1. **Plan it.** Call `ghl-specialist` with `PHASE: plan` and the chosen pieces, their accounts, and draft-or-scheduled times. It searches for the right create-post operation, reads what it needs, and returns the exact proposed action for each post.
2. **Show a table**, one row per post, from the plan's own preview:

| # | First line | Account | Draft or scheduled | When, their time |
|---|---|---|---|---|

3. Then say: "Nothing goes out until you say yes. Shall I put these into GoHighLevel?"
4. **Wait for a clear yes.** A yes covers exactly this table. If they change anything, plan it again and show the table again.

## 5. Publish

**Grant it.** `sh .claude/scripts/approve.sh --grant ghl <the exact suffix the plan proposed>:<count>` for exactly the posts just shown and approved.

For each post, one at a time:

1. **Create the post.** Call `ghl-specialist` with `PHASE: execute` and `APPROVED ACTIONS:` verbatim from the plan, with the piece's words exactly as approved, the chosen accounts, and draft or the scheduled time. If the tool cannot do what the table promised (a draft, a scheduled time, an account), stop, say what it cannot do, and ask what they would like instead.
2. **Read it back.** Call `ghl-specialist` with `PHASE: plan` to read the post with the id it returned, and check the words and the time match.
4. **Update the ledger row:**
   - post id: the id GoHighLevel returned
   - status: `scheduled` for a scheduled post. A draft stays `approved` with the post id set, because it has not been scheduled yet.
   - goes out: the scheduled time in their timezone, as `2026-09-25T09:00`, or `-` for a draft
5. **Record the result** as a line in `log/ops-log.md`: `- HH:MM result: scheduled piece 7 to LinkedIn for 25 Sep 09:00`.

**If a call fails,**
- set that row's status to `failed`
- say which piece, and the reason in plain words
- carry on with the rest only if the founder says so

**Never** delete, move or edit a post the founder did not name. To change a post already in GoHighLevel, show the change and edit the post only after a yes.

**Clear the grant.** `sh .claude/scripts/approve.sh --clear ghl`, once every post in the batch has been created or has failed.

## 6. Save and report

1. Run `git add growth-engine` then `git commit -m "Published pieces <numbers>"`. Push if there is a remote.
2. Tell them in three lines:
   - what went in
   - what waits for a picture or a fix
   - how many approved pieces are left to publish
3. Name what to do next, and say that "where am I up to" shows what is left.

## What went out, and how it did

When they ask what was published:
- Read the ledger rows at `scheduled` and `posted`.
- Call `ghl-specialist` with `PHASE: plan` to check any past their time against the posts GoHighLevel returns.
- A scheduled post that has gone out becomes `posted`.

When they ask how posts did:
- Call `ghl-specialist` with `PHASE: plan` to read how the posts did from GoHighLevel.
- Report what it returns, in plain words. Never invent a figure it did not return, and never compare it to a benchmark nobody gave you.
- If something clearly worked or clearly did not, offer to note it in the What worked or What did not block of `log/memory.md`, dated, so the next refill uses it.

## The 25 outreach emails, into the founder's drafts

B2B only. This puts each person's finished first email into the founder's own Gmail drafts, so they read it and press Send, instead of copying and pasting. Follow the mailbox rules in `../../references/connections.md`: **drafts only, never send.**

1. **Check it fits.**
   - The Brain's track is `b2b`, and `engines/outreach/outreach-sequence.md` records the manual route. On the Apollo route, Apollo sends the sequence through their mailbox once they start it, so there is nothing to draft. Say so.
   - Gmail is connected: call `gmail-specialist` with `PHASE: plan` and check for a tool whose name ends in `create_draft`. If not, run `/growth-engine:connect`. On Microsoft 365 there is no draft tool, so say plainly that the 25 go by hand from each person's file.
2. **Gather the emails.** For each person in `people/` at `kind: prospect`, not at `cut`, and not yet sent to, take their email address and the finished touch 1 in their Opener block. Take the subject line from touch 1 in `engines/outreach/outreach-sequence.md`. Skip anyone with no address or no Opener block, and say who.
3. **Plan it.** Call `gmail-specialist` with `PHASE: plan` and the gathered people, and get back the exact proposed `create_draft` action for each.
4. **Show, then wait.** Show a table, one row per email: first name, company, subject, the first line. Say: "These go into your Gmail drafts, not out. You read each one and press Send yourself. Shall I put them in?" Wait for a clear yes. A yes covers exactly this table.
5. **Grant it.** `sh .claude/scripts/approve.sh --grant gmail create_draft:<count>`, for exactly the count just shown and approved.
6. **Draft them.** Call `gmail-specialist` with `PHASE: execute` and `APPROVED ACTIONS:` verbatim from the plan, one `create_draft` per person, to that one person, with the subject and the Opener block exactly as written. Never send, reply or forward.
7. **Clear the grant.** `sh .claude/scripts/approve.sh --clear gmail`.
8. **Record it** in each person's file as a touch line: `- YYYY-MM-DD email drafted: touch 1 in Gmail drafts`. Leave their status as it is: nothing is sent until they press Send. When they say they have sent to someone, record it the way the outreach engine says.
9. **Tell them** in two lines how many drafts went in and who was skipped. Person files stay out of git, so there is nothing to save.
