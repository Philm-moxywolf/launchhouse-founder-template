---
name: playbook-export
description: Compile the founder's personalised playbook insert from their own files, four to six pages, delivered as a PDF alongside the generic Growth Engine playbook body. Made after Session 3, and again after the Sunday plan. Checks the insert still matches those files before handing it over. Trigger on "generate my playbook", "playbook insert", "print my playbook", "make my playbook PDF", "send my playbook to my mentor".
---

# Playbook Export

Produces the four to six page personalised insert that goes with the printed generic playbook.

**Who is reading.** A founder who does not use a terminal. Never ask them to run a command.

## Prerequisites

**Check the gate first.** Read `./growth-engine/.state/gate-state.md`. The insert compiles whatever exists, so name in one plain sentence the engines whose rows are `not done`, using their evidence, say those sections will be thin or left out, then offer to carry on anyway. Never hold a founder up for working out of order.

1. **Check the folder.** Read the session context. If it says this is not the founder folder, stop and tell them which folder to open.
2. **Read every file in `./growth-engine/`,** except `people/`, `inbox/uploads/`, `.state/`, `engines/outreach/outreach-firstlines.csv` and `engines/audience/dm-openers.md`. Those last ones hold real people's details, and none of them belongs in the insert.
3. **If `brain/founder-brain.md` does not exist,** there is nothing to compile yet. Say so plainly, and offer to build the Brain with them now. If they say yes, follow the `founder-brain` skill, then come back here. If not now, give them the one next step for when they are ready: `/growth-engine:brain`, or say "build my founder brain".

**This is a compilation task, not a generation task.** Do not invent content that is not already in the founder's own files. If a section has no source file, leave it out and say so, rather than writing filler, and name the engine that would fill it.

## Contents

1. **Cover.** Founder name, business, track.
2. **Your Brain.** Offer, audience, proof and voice, in one page.
3. **Your content.** The pillars, and the first line of each of the 30 pieces, not the full text.
4. **Your engine 2.**
   - B2B: the sequence.
   - B2C: the hook bank and inbound scripts.
   - Never include the people list or anyone's details.
5. **Your ops.** Bottleneck, snapshot, the pack to publish first, and its message copy.
6. **Your 90 days.** The plan, the number, Monday's three actions, kill criteria. The plan is built in Atlanta on the Sunday, so at Session 3 this section is left out. Say so, and offer to compile the insert again after the Sunday.

## Output

1. **Save first,** so the insert can be matched to the files it was built from. Run `git add growth-engine` then `git commit -m "Before the playbook insert"`. If there is nothing to save, carry on. Then run `git rev-parse --short HEAD`. That is the version the insert is built from. If git is not available or gives an error, use `none` as the version.
2. **Write `./growth-engine/export/playbook-insert.md`,** formatted for print:
   - clean headings, no clutter, generous white space
   - a page break between sections, as a line holding only `<div style="page-break-after: always"></div>`
3. **Stamp it.** The last lines of the cover say when it was built and from what:
   - `Built on <date, as 17 September 2026> from <each file that fed a section, by its path inside growth-engine>.`
   - under it, a line holding only `<!-- built-from: <version> | <the same paths, such as brain/founder-brain.md, separated by spaces> -->`
4. **Write `./growth-engine/export/playbook-insert.html`,** the same words and stamp as one printable web page, so any computer can print it or save it as a PDF with its own web browser:
   - everything in the one file: no outside fonts, pictures, scripts or links to load
   - black text on white, 11 point, margins of about 18 mm, set with `@page`
   - each section starts on a new page, with `break-before: page`

**Limits.** Six pages maximum. About 450 words fill a printed page at that size, so keep the whole insert under 2,700 words. No wide tables, and no colour dependence.

## Check and save

1. **Check.** Use the `rules-reviewer` agent on `export/playbook-insert.md`. It should find nothing new, because it only compiles. Anything it holds came from a source file, so fix it there, then compile again.
2. **Save.** Run `git add growth-engine` then `git commit -m "Playbook insert"`. Push if there is a remote.

## Is it current

Check this before handing the insert over in any form: when they ask for it, want to print it or send it, and before the PDF.

1. Read the `built-from` line in `export/playbook-insert.md`. If there is none, it is out of date.
2. Run `git diff --name-only <version> -- <each file on that line, with growth-engine/ in front>`. Every file it lists has changed since the insert was built.
3. If the version is `none`, or git is not available or gives an error, look at the date each file on the line was last changed instead. A file changed after the date on the stamp has changed. Say plainly that this could not be fully checked.
4. It is also out of date if a file the Contents would now use exists and is not on the line, such as the plan after the Sunday.

**If it is out of date,** say which files changed since it was built, in plain words, and offer to build it again now. It takes a few minutes. If they say no, hand it over, with one plain sentence naming the files that changed since it was built. If it is current, say it matches their files as of the date on it.

## The PDF

**The personalised insert is delivered as a PDF, not printed.** The generic playbook body is printed in two variants, B2B and B2C. Founders receive the insert digitally before Atlanta, and can print it themselves if they want a hard copy.

Their web browser makes the PDF, on a Mac or a Windows PC, with nothing to install.

1. **Check it is current,** as above.
2. **Tell them:**
   - Open `playbook-insert.html` in the `export` folder inside their growth-engine folder. It opens in their web browser.
   - Press Command and P on a Mac, or Control and P on Windows.
   - Choose **Save as PDF** as the printer. On Windows it may be called **Microsoft Print to PDF**.
   - Save it in that same `export` folder, named `playbook-insert.pdf`.
3. **Check the page count.** When they say it is saved, read `growth-engine/export/playbook-insert.pdf` and count its pages.
   - Six or fewer: say how many.
   - More than six: say plainly how many pages over it is, and which section is longest. Offer to shorten that section and build it again. Never hand over an insert that runs over without saying so.
4. **Save.** Run `git add growth-engine` then `git commit -m "Playbook insert PDF"`. Push if there is a remote.

Then name the next step, which is compiling it again after the Sunday plan, and say that "where am I up to" shows where they stand.
