# The starting contents of a Launchhouse folder

Create a file only when it is missing. Never overwrite one that exists.

## growth-engine/.launchhouse

```
This is a Launchhouse founder folder. Everything the growth engine makes lives in this growth-engine folder.
```

## growth-engine/log/ledger.md

```markdown
# Ledger

One row per content piece. Format: C|id|pillar|format|lane|status|post id|goes out
Status is draft, approved, scheduled, posted, failed or archived. A piece becomes approved only when the founder says so.
```

## growth-engine/log/memory.md

```markdown
# Memory

Curated. What matters, not everything. The full record is in ops-log.md.
Add one line per entry inside the marked blocks, dated. Anything under Notes is the founder's own.

## Decisions
<!-- GE:DECISIONS:START -->
<!-- GE:DECISIONS:END -->

## What worked
<!-- GE:WORKED:START -->
<!-- GE:WORKED:END -->

## What did not
<!-- GE:DIDNOT:START -->
<!-- GE:DIDNOT:END -->

## Voice notes
<!-- GE:VOICE:START -->
<!-- GE:VOICE:END -->

## Angles used
<!-- GE:ANGLES:START -->
<!-- GE:ANGLES:END -->

## Open threads
<!-- GE:THREADS:START -->
<!-- GE:THREADS:END -->

## Notes
Anything below this heading is the founder's own.
```

## growth-engine/log/ops-log.md

```markdown
# Ops log

Append only. Every day gets its own heading, as ## YYYY-MM-DD, then lines as - HH:MM decision|result|blocker|note: text
```

## growth-engine/people/README.md

```markdown
# people

One file per person the founder is selling to.

These files hold real people's names, companies and contact details. They are kept out of git on purpose and never shared.
```

## .gitignore, in the folder the founder opened

Add any of these lines that are missing. Keep whatever else is there.

```
# Real people's details. Never in git.
**/people/*
!growth-engine/people/README.md
**/outreach-firstlines.csv
**/dm-openers.md
# A copy unzipped in the wrong place, or twice.
growth-engine/growth-engine/
growth-engine */
# Working copies the Launchhouse checks keep for a moment.
growth-engine/.state/.pre/
# Worked out from the folder and rebuilt in seconds. Keeping them in git would
# make a conflict out of a file the founder must never edit.
growth-engine/.state/gate-state.md
growth-engine/.state/nudges.md
# Downloads from the app, once brought across.
*.zip
.lh-import/
.DS_Store
```

## .claude/, in the folder the founder opened

Launchhouse itself is the `.claude/` folder in the Launchhouse repository: the skills, the commands, the agents, the references, the routines, the checks that run on every write, and the `settings.json` that turns them on. It only works where that folder is.

- **The folder is a copy of the repository.** It already has `.claude/`. Leave it alone.
- **The folder is not a copy of the repository.** Copy the whole `.claude/` folder across from the founder's copy of the repository. Copy it, never retype it: a settings file written out by hand goes stale the moment a check is added, and the founder is told they are set up while half the checks never run.
- **There is no copy of the repository to hand.** Stop. Launchhouse runs inside a copy of the Launchhouse repository. Tell the founder in one sentence to open their Launchhouse folder instead, and tell a mentor if they do not have one.

If `.claude/settings.json` already exists in the folder they opened, leave it alone, and tell a mentor if the founder is being asked permission for everything.

## CLAUDE.md, in the folder the founder opened

Claude reads this at the start of every conversation in the folder, in Code and in Cowork. It carries the six rules and how to talk with the founder.
- **No `CLAUDE.md`:** create it with exactly this.
- **A `CLAUDE.md` that does not start with `# This is a Launchhouse founder folder`:** keep everything in it, and add this at the end, after one blank line.
- **Otherwise** leave it alone.

```markdown
# This is a Launchhouse founder folder

Claude reads this file at the start of every conversation in this folder. The founder can read it too.

## Who you are working with

A founder on the Launchhouse Atlanta programme, building their business. They are not a developer and they do not use a terminal. Every programme date is in the cohort block in `.claude/references/gates.md`, and nowhere else.

**Talking with them**
- They use the Claude desktop app, in Code or Cowork, on a Mac or a Windows PC. Never ask them to open a terminal, type or run a command. Run what needs running yourself, then say what you did in one plain sentence.
- If a command is not available on this computer, do the job with your own file tools instead. If `git` is missing on a Windows PC, the computer needs Git for Windows (an ordinary installer from git-scm.com); `/growth-engine:start` walks them through it.
- Offer plain words or the `/growth-engine:` name of a skill, never a bare slash command.
- How replies sound is set by the Launchhouse Guide style in `.claude/output-styles/`. Where it is not in use, such as in Cowork: short plain sentences, name their doubt, end on the next thing to do.
- Helpers (subagents) never see that style. A helper reports back in a few lines, with the evidence and anything left undone, never a narrative.

## Where their work lives

**Location.** Everything the growth engine makes goes in `growth-engine/`, inside this folder. Never write Launchhouse work anywhere else, not in your memory, not in a temporary folder. Anything outside `growth-engine/` will not be found later.

**Desktop copies.** Their finished work also appears as read-only copies in a "My Launchhouse work" folder on their Desktop, updated each time their work is saved.

**Saving.** The folder is saved with git. When a piece of work is finished, commit it with a short plain message, and push if there is a GitHub remote. Never push to a remote under `Philm-moxywolf`: that is the public original every founder copies. Any earlier version can be brought back.

**Real people.** `growth-engine/people/`, `growth-engine/engines/outreach/outreach-firstlines.csv` and `growth-engine/engines/audience/dm-openers.md` hold real people's names, emails or handles. They are kept out of git on purpose. Never paste them anywhere public, and never copy a person's details into any other file.

**Cowork.** Cowork can work in this same folder, for dropping in documents and photos and for planning. Whatever either one saves into `growth-engine/`, the other sees.

## Where the system lives

This folder carries Launchhouse itself, in `.claude/`: the skills, the agents, the checks that run on every write, the references they read and the routines. Nothing is installed from a marketplace, so there is never a plugin to add or update. If the founder has the old `growth-engine` plugin installed as well, this folder's copy is the one in use: `.claude/settings.json` switches the old `growth-engine` plugin off inside this folder, so there are never two copies.

## The Founder Brain comes first

`growth-engine/brain/founder-brain.md` is the record of the business: what they sell, who to, what they can prove, and how they write. Read it before writing anything for them.

If it does not exist, the next step is the Founder Brain (`/growth-engine:brain`). If the folder is not set up, start with `/growth-engine:start`.

## The six rules

These hold everywhere in this folder, including when publishing through GoHighLevel or building sequences in Apollo.

1. **One track.** The founder is B2B or B2C. The track is set once, in the Founder Brain intake, and recorded on the Brain's Track line. Never ask it again anywhere else. Everything adapts to it. Never write, offer or mention the other track's material.
2. **No Instagram DM automation, ever.** Automated cold DMs get accounts restricted, and that cannot be undone. Cold DMs are sent by hand, 25 of them, spread out. Automation is only for replying to people who wrote first.
3. **B2B outreach is 25 messages.** Low volume, to a list the founder built and can explain. Never promise replies. Replies depend on the list, the offer and the timing.
4. **Everything is made and kept in `growth-engine/`.** The one exception: a read-only copy of finished work is placed in a "My Launchhouse work" folder on the Desktop, automatically, by the Launchhouse checks. Claude never writes there itself, and never puts anything else there.
5. **Never invent proof.** No made-up numbers, customers, results or testimonials. If proof is thin, write from point of view and observation. A real figure goes in the Brain first.
6. **The voice is the founder's.** Topics can come from other sources. The voice comes only from their own writing in `growth-engine/brain/voice-samples/` and the Voice section of the Brain.

## What the tools never do here

**GoHighLevel**
- Only ever reply to someone who wrote first. Before sending, read their conversation and check it holds a message from them. Show the founder the reply and get a yes.
- A first message to someone who has not written is never sent by a tool. It goes by hand, from the founder's own phone.
- In Cowork, none of these checks run. The founder's own connector setting is what stops a post or a send going out without asking: it must stay set to Needs approval.

**Apollo**
- Build sequences paused.
- Never activate or send. The founder presses start themselves.
- Never buy anything.
- Show the credit cost before any enrichment, and wait for a yes.

**Publishing**
- Show exactly what will go out, where and when, in their timezone.
- Wait for a yes before anything goes out.

**Every connected tool, not only these three.** One check runs before any tool from a connector (GoHighLevel, Apollo, the mailbox, or any other the founder has connected) does anything. A small, fixed list of actions is refused outright, always: spending the founder's money, sending or connecting to a real person in bulk or cold, GoHighLevel's own refused list, and a mailbox rule. A short further list (a message actually going out, a calendar change, an Apollo credit spend, and a few named GoHighLevel actions) asks the founder first even when their own Claude setting would not otherwise ask. Everything else that changes or sends something is noted for Claude, in plain words, but never held up on its own: most founders run in a mode with no prompts at all, so their own yes in chat, before Claude ever reaches for the tool, is what has to carry it. A plain read is never even mentioned.

The Launchhouse checks enforce most of this automatically. When a file is held or a tool is stopped, tell the founder in one plain sentence what happened and what to do, never as an error.
```
