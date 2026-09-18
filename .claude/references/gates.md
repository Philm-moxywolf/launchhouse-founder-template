# The gates

Three gates. Each is checked at the start of the next session, so the work done between sessions is looked at while there is still time to fix it. They exist so nobody arrives in Atlanta unable to build.

## This cohort and its dates

Every date the programme uses is written here, once. A new cohort is one edit to this block. Nothing else in the references, and no skill, should carry a programme date of its own.

| What | When |
|---|---|
| Cohort | Launchhouse Atlanta, September 2026 |
| Session 1 | Mon 7 or Tue 8 September 2026 |
| Session 2 | Mon 14 or Tue 15 September 2026 |
| Session 3 | Mon 21 or Tue 22 September 2026 |
| The clinic | Wed 23 September 2026 |
| Atlanta starts | Fri 25 September 2026 |
| The Saturday, when the 25 messages go by hand | Sat 26 September 2026 |
| The Sunday, when the 90 day plan is built | Sun 27 September 2026 |

The computed state reads **The Saturday** row from this table, so the B2C sends row is never checked against a date written anywhere else. If that row is missing or cannot be read, the sends row says it is not recorded here rather than guessing.

Dates written inside example files elsewhere in the references show the shape of a file. They are not programme dates, so leave them alone when the cohort changes.

### How a skill should talk about dates

Work out today's date from the founder's own computer, and their timezone from `growth-engine/.state/profile.md`. Then:

- **Before the programme.** Name the next thing by day and date, and say how far away it is. "Session 2 is Monday 14 September, six days away."
- **During the programme.** Name today's session, and the next one by day. "Today is the clinic. On the Saturday your 25 messages go out."
- **After the programme, or once a date in the block has passed.** Never announce a date that has gone as though it is still ahead, and never ask the founder which cohort they were on. Use relative words instead: "your clinic session", "the Saturday of your programme", "after your third session". A gate whose date has passed is still checked the same way and still reported as done or not done. Say it plainly: the programme dates have passed, so this is the work itself now, not a deadline.

Never invent a date for a cohort that is not in this block. If the block does not say, say it is not recorded here and comes from their mentor.

## The three gates

| Gate | What | Built | Checked |
|---|---|---|---|
| A | The Founder Brain | Session 1 | End of Session 1 |
| B | The content engine | After Session 1 | Session 2 |
| C | Engine 2 and the operations workflow | After Session 2 | Session 3 |

Also in the programme, with no gate:
- **The clinic:** the one GoHighLevel snapshot loaded, and the Brain proved to work in Claude.
- **The 90 day plan:** built in Atlanta on the Sunday.
- **The playbook insert:** made after Session 3, and again after the Sunday plan.

## Which gate an engine needs

The one mapping. It lives here, and every engine skill reads it from here rather than carrying its own copy.

| Engine | Needs |
|---|---|
| The Founder Brain | none |
| The content engine | Gate A |
| The outreach engine (B2B) | Gate B |
| The audience engine (B2C) | Gate B |
| The operations engine | Gate B |
| The 90 day plan | Gate C |

**How this behaves.** An engine whose gate is not met does not start. Say in one or two plain sentences what is missing, from the `not done` rows for that gate in `growth-engine/.state/gate-state.md`, and offer to do that first. If the founder says to go ahead anyway, record an override for that one engine, then run it. Overrides never mark a gate as met, and never reach beyond the one engine they were recorded for. How an override is recorded, and how `gate-state.md` reports a locked, overridden or done engine, is in `state.md`.

With no track chosen yet, `gate-state.md` writes no row at all for the outreach, audience or ops engines: only `content`, `brain` and `plan` get rows. Treat "no row for this engine" the same as `locked`. What is missing is the track, which comes from the Founder Brain.

## How an item is proved

Every item is one of two kinds:

- **file-backed.** A file proves it. Check the file. Never mark it done because the founder says so.
- **self-reported.** Nothing in the folder can prove it. Ask the founder, and record the answer in `.state/gate-answers.md` as an answer, not as evidence.

**Thresholds**
- **Missing:** the file does not exist.
- **Nearly empty:** a file or section with fewer than 40 characters that are not spaces. Say so, and do not count it.
- **Counts:** the numbers below are the minimum.

## Gate A

| Item | Proved by | How |
|---|---|---|
| The Brain exists and is locked | file-backed | `brain/founder-brain.md` has a `Locked:` date |
| A track is chosen | file-backed | the `Track:` line is exactly `b2b` or `b2c` |
| The thesis is written | file-backed | `## Thesis` is not nearly empty |
| The voice is captured | file-backed | `## Voice` is not nearly empty |
| The flags are answered honestly | self-reported | read `## Flags`, then ask |

The flag that matters most:
- **B2B:** the sending domain, its age, and whether SPF, DKIM and DMARC are set.
- **B2C:** the Instagram account type.

## Gate B

| Item | Proved by | How |
|---|---|---|
| Thirty pieces are written | file-backed | `engines/content/content-30.md` is not nearly empty, and holds 30 pieces |
| The posting sheet is written | file-backed | `engines/content/content-30.csv` has the header `content,platform,scheduled_date,media_note` and 30 rows |
| A source list for the refill exists | file-backed | `engines/content/rss-feeds.md` is not nearly empty |
| The pieces have been read and approved | file-backed | at least 30 `C|` rows in `log/ledger.md` at `approved`, `scheduled` or `posted` |
| The pieces sound like the founder | self-reported | ask |

A piece the founder has read but not approved counts as not done, on purpose.

## Gate C, B2B

| Item | Proved by | How |
|---|---|---|
| The route is chosen and the sequence is written | file-backed | `engines/outreach/outreach-sequence.md` names the route (Apollo or by hand) and holds 4 or 5 touches, each with an opt-out line |
| The list criteria are written down | file-backed | `engines/outreach/outreach-sequence.md` holds tight, medium and broad criteria |
| The list is built | file-backed | at least 25 files in `people/` with `kind: prospect` and a status other than `cut` |
| First lines exist for the 25 | file-backed | `engines/outreach/outreach-firstlines.csv` has the header `email,first_name,company,first_line` and 25 rows |
| The workflow is built | file-backed | `engines/ops/ops-workflow.md` names the bottleneck and the pack to publish first, and holds its copy |
| Domain setup is done and sending has started | self-reported | ask |

Twenty five messages, low volume, to a list the founder built and can explain. Nothing anywhere counts replies.

## Gate C, B2C

| Item | Proved by | How |
|---|---|---|
| Twenty five openers are written | file-backed | `engines/audience/dm-openers.md` holds 25 numbered openers, each against a handle |
| Twenty five targets are recorded | file-backed | at least 25 files in `people/` with `kind: target` |
| A hook bank with offer tests exists | file-backed | `engines/audience/hook-bank.md` has its six categories and an `Offer tests` heading |
| Inbound scripts exist | file-backed | `engines/audience/inbound-scripts.md` is not nearly empty |
| The workflow is built | file-backed | `engines/ops/ops-workflow.md` names the bottleneck and the pack to publish first, and holds its copy |
| The account is Business or Creator, linked to a Page | self-reported, or read from GoHighLevel | `.state/setup.md` if the connector read it, otherwise ask |
| The messages have been sent | at the event, not counted at Gate C | people at `status: sent`, `replied`, `booked` or `no_reply`, from the Saturday of the programme |

**The sends.** The 25 go by hand, from the founder's own phone, spread out, on the Saturday in Atlanta. So they are not due at Gate C, and nothing reports them missing before then. When the founder says they have sent one, set that person's status to `sent` and add a touch line. That is what turns a send into evidence.
