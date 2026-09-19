---
name: ghl-workflows
description: Build the operations engine. Runs a bottleneck diagnostic, names the GoHighLevel snapshot the founder's track decides, and writes all the copy that goes inside it, ready to load at the clinic. Both tracks. Trigger on "build my ops engine", "which workflow should I automate", "my bottleneck", "pick a snapshot", "operations engine".
---

# Operations Engine

One workflow running on the founder's own business before they leave Atlanta.

**The workflow is a pre-built GoHighLevel snapshot.** It is loaded into the founder's own account at the clinic, and every message inside it arrives without the founder's words. This skill does the two things that actually need thinking: choosing the right one, and writing the words inside it.

**Founders do not build workflows.** If a founder starts describing a bespoke automation, bring them back to the library. A custom build cannot be loaded and tested in one clinic session; a snapshot can.

**Who is reading.** A founder who does not use a terminal. Never ask them to run a command.

**Dates.** Every programme date comes from the cohort block in `../../references/gates.md`. Take today's date from the founder's own computer. Once a date in that block has passed, do not announce it as though it is still ahead: say "your clinic session" or "the Saturday of your programme" instead.

**Before the questions, offer to look instead:** follow `../../references/sources.md`.

## Prerequisites

1. **Check the folder.** Read the session context. If it says this is not the founder folder, stop and tell them which folder to open.
2. **Read the Brain.** Read `./growth-engine/brain/founder-brain.md`.
   - If it genuinely does not exist, do not leave them stuck. Say in one plain sentence that this engine writes from their Founder Brain, about an hour of their own answers that every engine reads, and offer to build it with them now. If they say yes, follow the `founder-brain` skill, then come back here. If not now, give them the one next step for when they are ready: `/growth-engine:brain`, or say "build my founder brain".
   - Do not ask them to describe their business again from scratch, and do not guess at their offer, audience or voice.
3. **Use the Brain** for track, model, stage, offer and goal.
4. **When the Brain is not enough.** If something this engine needs is missing or thin, do not guess and do not stop. Ask for it, one question at a time, and say in a few words why you are asking. Make it easy to answer: a sentence in their own words, a pick from two or three options you suggest, something they already wrote pasted in, a file added with `/growth-engine:add-files`, or "not sure yet", which you note as a gap and work around. Never suggest a number, a result or a customer: those only ever come from them. If what they tell you belongs in the Brain, say so, and that "update my brain" puts it there.
5. **Check the gate this builds on.** Run `sh .claude/scripts/refresh.sh < /dev/null`, then read `growth-engine/.state/gate-state.md` and check the `ops` row in its engine table. This engine needs Gate B, from the mapping in `../../references/gates.md`.

   If there is no `ops` row, no track is chosen yet. Treat it as locked: what is missing is the track, from the Founder Brain.

   If the row reads `locked`, or is still missing after the refresh, this engine does not start. Say in one or two plain sentences what is missing, using the `not done` Gate B rows' evidence, and offer to do that first. Before offering to go ahead anyway, check `growth-engine/.state/gate-overrides.md` for a line already naming `ops`. If one is there, treat the row as overridden and carry on; do not add a second line.

   Otherwise, only record an override when the founder says, in their own words, to go ahead anyway. A no, or "later", is not consent. If it is unclear, ask once: "Build it without that?" Then add a line to `growth-engine/.state/gate-overrides.md`: `<today's date> | B | ops | <their exact words>`, run `sh .claude/scripts/refresh.sh < /dev/null`, and carry on.

   If the row reads `done` or `overridden`, carry straight on.
6. **Check for an existing workflow.** If `engines/ops/ops-workflow.md` already exists, the bottleneck is already found, so do not run the diagnostic again.
   - The pack it names is the pack to publish first, even when the file calls it a snapshot, as files from the app do (Comment-to-DM capture is the Comment to DM pack).
   - Keep the file as it is. Ask whether they want to change the copy or put a different pack first, and go straight there.
   - Change only what they ask for, and never replace their copy without their yes. The other packs get their words from the values step, not here.

## Step 1: bottleneck diagnostic

Before asking, offer to look instead (`../../references/sources.md`): their own notes or email, if a source that might show where things go quiet is connected.

Find the one repetitive task that costs the most time or leaks the most revenue. Ask:

1. What do you do every week that you resent doing?
2. Where do people go quiet on you, and what happens next?
3. What do you forget to do, and what does it cost when you forget?
4. If one repetitive job disappeared on Monday, which one?

Then name the bottleneck in one sentence, in their words. Confirm it with them before moving on. Getting this wrong means automating the wrong thing.

**If they cannot pick one, do not stall.** Offer the pack most founders on their track start with: Lead follow-up on B2B, and on B2C, DM qualify and book when people book a service with them, otherwise Comment to DM. Say they can put a different pack first later, because every pack is in their snapshot anyway.

## Step 2: name their snapshot, then order the packs

**The founder does not choose a snapshot.** Their Brain does. Read the `Track` line and the hybrid flag, say which one they have, and move on.

| In the Brain | Snapshot | What is in it |
|---|---|---|
| B2B | **B2B** | Essentials B2B, Lead follow-up, Discovery booking, Proposal chase |
| B2C | **B2C** | Essentials B2C, Comment to DM, DM qualify and book, Review request |
| Either, hybrid | **Hybrid** | B2C Essentials (on either track), plus all six packs, on a board of its own |

Every pack arrives as drafts. Nothing runs until the founder publishes it, so what the bottleneck decides is **which pack they publish first, and whose words get written first.**

### B2B packs

| Pack | Runs on | Publish this one first when |
|---|---|---|
| Lead follow-up | Email | Inbound leads are not chased consistently |
| Discovery booking | Email | Booking a call takes too many messages |
| Proposal chase | Email | Proposals go quiet and nobody follows up |

### B2C packs

| Pack | Runs on | Publish this one first when |
|---|---|---|
| Comment to DM | Instagram | Content gets engagement but no conversation |
| DM qualify and book | Instagram | DMs arrive but conversion is manual and slow |
| Review request | Email | Reviews are never asked for |

**The list is deliberately small.** If the founder's bottleneck falls outside these six (onboarding, reactivation, abandoned checkout, win-back):
- name the nearest pack and adapt the message copy to it
- note the gap in the output file, so a mentor can help individually
- do not invent a pack that does not exist, and do not attempt a bespoke build

**Name the platform from the table, never from memory.** A B2C pack runs on Instagram, or on email. Saying one runs on LinkedIn puts the other track's platform in front of a founder who is not on it, and it sends them to the wrong place on the day.

A B2C founder with `Model: ecommerce` usually publishes review request or comment to DM first. With `Model: service`, DM qualify and book is usually the one. If a Flag says the Model is only the nearest fit, go by the bottleneck instead. Recommend, never force.

Name the pack that answers their bottleneck, say why, and let them override. That one pack is what the output file records as the chosen snapshot, exactly as files from the app do. The rest of their snapshot stays as drafts until they want it.

## Step 3: write the copy

The snapshot is the plumbing. The copy is the founder's.

For the pack they publish first, write every message it sends: emails with subject lines, SMS, DM replies, internal notifications, and for an Instagram pack its public comment replies and the words on its buttons. Write in the captured voice, matched to track.

**Reuse what exists.** For the two DM packs, if `engines/audience/inbound-scripts.md` already holds the comment to DM or qualify and book copy, use that copy, fitted to the pack's steps, rather than writing a second version. Say so in the file.

**Placeholders in plain words.** The snapshot brings its own trigger, stages, tags and fields, and their exact names are only known once it loads at the clinic. Write personal details as plain placeholders, `[first name]`, `[business name]`, `[booking link]`, never merge-field code, and describe tags and stages in plain words. They are matched to the snapshot's own fields when it is loaded, and the values step takes the placeholders out, because the workflow step writes the greeting and the first name itself.

Also specify:
- the trigger
- the wait intervals between steps
- the exit condition
- which tags get applied

Keep waits realistic. Chasing someone four times in two days annoys them.

**On the two DM packs, check the trigger before you write a word.** Both start with something the other person did: a comment on a post, or a message they sent in. Write the copy as the answer to that, and label each message with what triggers it, for example "Reply, sent when they comment:". If you find yourself writing to somebody who has done neither, the trigger is wrong, and no amount of rewriting the copy fixes it.

**No message claims a result the Brain does not record.** A review request that says "join our 200 happy customers" is an invented number, sent to a real customer who can count. If the Brain has no number, ask for the review on the work the founder actually did for that person, and name the work.

## Step 4: n8n escape hatch

Only if the data lives outside GoHighLevel: Stripe to a spreadsheet, Shopify to Airtable, a legacy system, multi-API orchestration.

Most founders do not need this. If the founder does not clearly need it, do not raise it. If they do, note the requirement in the output file and flag it for one-to-one support rather than trying to solve it here.

## Step 5: export

Write `./growth-engine/engines/ops/ops-workflow.md` containing:
- the named bottleneck
- the chosen snapshot, meaning the pack to publish first, and why
- all message copy
- the trigger, the timings, the exit condition and the tags
- any gap in the library, or n8n requirement, for a mentor

**If you are changing this file after it was written,** the values in `engines/ops/ghl-values.md` that reuse this copy, and `export/playbook-insert.md`, were built from it and no longer match. Say which of them exist and are now out of date, and offer to rebuild them. Never rebuild one quietly, and never leave it unsaid.

## Step 6: check and save

First add one line to the Decisions block of `growth-engine/log/memory.md`: `- YYYY-MM-DD ops workflow: <pack>, for <bottleneck in a few words>`.

1. **Check.** Use the `rules-reviewer` agent on `engines/ops/ops-workflow.md`. Give it every figure the founder gave in this conversation.
2. **Fix what it holds.** Ask about any held figure rather than guessing. Do this at most twice.
3. **Save.** Run `git add growth-engine` then `git commit -m "Operations engine: <pack>"`. Push if there is a remote. If the push fails, say it is saved on this computer.

## Before and at the clinic

The founder loads the snapshot at the clinic. Loading brings every workflow and the names of the message slots, not the words. Each slot arrives empty or holding the word PLACEHOLDER, and either way it sends exactly as it is until the founder's words are pasted in.

So the words are written first, before the clinic, usually the evening after Session 3, with `/growth-engine:values`, or by saying "fill my custom values". At the clinic they are pasted in as custom values, and on B2C and Hybrid the two review emails go into their review templates. That step fills the Essentials slots every founder gets as well as the snapshot's own, so the copy written here is part of the list rather than all of it. Publishing and the first live test come after that, because a published pack with empty values sends blank emails to real people. Only the packs whose words were written are published, Essentials among them, and the rest stay as drafts.

**Do not put this copy into their account yet, anywhere.** The snapshot brings the slots but not the words, and the values step fills them. An email template made now is a second copy that no workflow reads, and the founder ends up typing the same words twice.

Never create, change or switch on a workflow. The snapshot does that.

## Gate

- bottleneck named in one sentence
- snapshot named, and the pack to publish first chosen
- all copy written

Tell the founder which of these are done and which one to do next. Then tell them, once, that saying "where am I up to" shows where they stand at any time.
