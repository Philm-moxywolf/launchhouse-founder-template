---
name: import-from-app
description: Bring a founder's work across from the Launchhouse app into this folder, then tidy it for the new setup without rewriting anything they wrote. Handles the downloaded zip, a download the Mac already unzipped, a folder unzipped one level too deep, or files dropped loose. Saves an untouched copy first, adjusts files to the current format, checks them against the rules, and saves again. Trigger on "bring my work across", "import from the app", "I downloaded my files", "move my work over", "here is my zip", or when the session context says there is work from the app in the folder.
---

# Bring work across from the app

The founder built their Brain, and maybe their content and engines, in the Launchhouse app. They have downloaded it. This skill brings it into their folder and hands over to the new setup.

**The promise to the founder:** your work arrives as it was, gets tidied, and nothing you wrote is rewritten without your yes. Never re-interview them for anything that already exists.

**Who is reading.** No terminal. Run commands yourself, then say in plain words what you did.

The full format every file should end up in is in `../../references/contract.md`, relative to this skill. Read it before step 4.

## 1. Find what they brought

Look in the folder they opened, and in `growth-engine/`, for any of these:

- **A zip file**, usually `growth-engine.zip`.
  - If there is more than one, use the newest by its date on disk, and tell them that date before unpacking.
  - If there is none, ask where it saved. It is often the Downloads folder.
  - If they say Downloads, look for `growth-engine*.zip` there. Show them what you found, and copy it into this folder once they say yes.
- **An unzipped download.** Safari on a Mac unzips downloads by itself, so there may be no zip at all. Look in Downloads for a folder whose name is `growth-engine` or starts with `growth-engine` (such as `growth-engine 2`) and holds `README-your-files.md`, and in this folder for one whose name starts with `growth-engine ` (such as `growth-engine 2`). If you find more than one, use the newest, and tell them the date on its `Downloaded` line before copying anything. Show them what is in it, and once they say yes copy its contents into `.lh-import/growth-engine/`, then carry on exactly as for a zip. Never move or delete the original: for `people/`, `engines/outreach/outreach-firstlines.csv` and `engines/audience/dm-openers.md` it is the undo point, as the zip would be.
- **A folder** called `growth-engine` inside `growth-engine`: unzipped one level too deep.
- **Loose files** such as `founder-brain.md` or `content-30.md` sitting in the folder they opened rather than in `growth-engine/`. Each goes to its path in the contract table.
- **Files already in the right place**: `growth-engine/brain/founder-brain.md` and friends.
- **Files dropped straight into `growth-engine/`** in the app's flat layout, such as `growth-engine/founder-brain.md` beside `README-your-files.md`.
- **A folder they already used in Claude** with the older Launchhouse toolkit, before this copy existed. Ask where it is. The work is the `growth-engine` folder inside it, so if they name the outer folder, use its `growth-engine` folder, and never copy the outer folder's own files, such as `.claude/` or `CLAUDE.md`. Show them what is in it, and once they say yes copy the contents of that `growth-engine` folder into `.lh-import/growth-engine/`, then carry on exactly as for a zip. Never move or delete the original.

If you cannot find anything, ask them to download everything again. In the app: open Files, press the button that downloads everything. Then drag the file into this folder. If their Mac opens it into a folder instead, that is fine: look for it in Downloads as above. Stop until they have.

**Unpack a zip into a holding folder, never straight into growth-engine:**
- Make `.lh-import/`.
- Run `unzip -o <zip> -d .lh-import`.
- If `unzip` is not available (usual on Windows), run `powershell -NoProfile -Command Expand-Archive -LiteralPath "'<zip>'" -DestinationPath .lh-import -Force`. The double quotes keep the single quotes for PowerShell, so a name with a space, such as `growth-engine (1).zip`, still works.
- If neither works, ask the founder to right-click the zip, choose Extract All, and tell you when it is done.
- The app's zip has a `growth-engine/` folder at its top. Use that folder's contents.

**Before moving anything,** list what came across to the founder, grouped:
- the Brain
- content
- engine 2
- operations
- plan
- people (count only, never names)
- documents and writing samples (counts)

## 2. Move it into place

**Before copying anything,** compare what arrived with what is already in `growth-engine/`, and settle every file that exists in both places using the rules below. Only then copy.

**Put them in the current layout first.** The app, and the older toolkit, kept every file at the top of `growth-engine/`, with `uploads/` and `voice-samples/` beside them. This folder keeps them in folders by kind, as the contract table says. Run `sh .claude/scripts/move-layout.sh .lh-import/growth-engine < /dev/null` on the holding folder, or with `growth-engine/growth-engine` in place of `.lh-import/growth-engine` for a folder unzipped one level too deep. It only moves files into their places and never overwrites or deletes. If the files were dropped straight into `growth-engine/`, run `sh .claude/scripts/move-layout.sh < /dev/null` instead, before the clear out below.

Move the app's files into `growth-engine/`, keeping their paths. Copy the whole holding folder with `cp -R` when nothing clashes. When something does, copy file by file, skipping the ones the rules below keep. Then remove `.lh-import/`.

Then tidy up the copies that came with it, so nothing is found twice:
- remove a nested `growth-engine/growth-engine/` once its files are in place
- remove loose copies of Launchhouse files left in the folder they opened
- leave the zip where it is. `.gitignore` keeps zips out of git, and step 3 records that the import is done.

When a file exists in both places:

- **Starting files from the template** (`log/ledger.md`, `log/memory.md`, `log/ops-log.md`, `people/README.md`, `.launchhouse`): the app's version wins, except `.launchhouse`, which stays.
- **`.state/index.md`** clashes on every import. Ignore it: it is rebuilt from the folder after the next change.
- **If this is a second import** (`growth-engine/.state/imported.md` exists): the folder's own `log/ledger.md`, `log/memory.md` and `log/ops-log.md` win, because they hold approvals, posts and notes made since. Only bring across files that are new or that the founder names.
- **Anything the founder already made in this folder**, such as a new Brain: stop and ask which to keep. Show both Locked dates and the first lines. Never merge two Brains yourself.

Then clear out what only the app needed:

- `growth-engine/README-your-files.md`
- `growth-engine/.state/HOME`, which points at a folder on the app's server
- `growth-engine/.state/snapshots/`, `growth-engine/.state/log.bytes`, `growth-engine/.state/memory.lock`, and any file with `.ge-tmp.` in its name
- `growth-engine/.gitignore`. The app's version hides `.state/`, which this setup keeps. The folder-level `.gitignore` already keeps `people/` out of git. Check it has those lines, and add them from the start skill's scaffold if not.

## 3. Save it exactly as it arrived

First write `growth-engine/.state/imported.md` in the shape in the contract, with the zip or folder name and today's date. Then run `git add -A` and `git commit -m "Your work from the app, as it was"`, so both land in one save.

This is the undo point for everything after. If git needs a name and email, follow step 4 of the `start` skill first.

`people/`, `engines/outreach/outreach-firstlines.csv` and `engines/audience/dm-openers.md` are kept out of git on purpose, so this save does not hold them. For those files, the zip, or the folder they came from, is the undo point. Tell the founder to keep it until they are happy with the move.

## 4. Adjust to the current format

Change only what is listed below, so each file matches its shape in `../../references/contract.md`. Keep every word the founder wrote.

### The Founder Brain

**Header**
- If the `Track` line is missing, or is not exactly `b2b` or `b2c`, ask the one question that decides it: "does your revenue come mostly from businesses or from individual consumers?" Set it.
- If the track is `b2c` and there is no `Model` line, ask: "do people book a service from you, or buy products?" Record `service` or `ecommerce`. Never add `Model` for B2B.
- If `Locked` is missing, use the date of the zip.

**Sections**
- If `## Thesis` is missing, compose one from `## Offer` and `## Audience`. Show it to them, and write it only when they say it is right.
- If `## Numbers` is missing, add it after `## Channels`. Fill each line from what the Brain already says, or write `unknown`.
  - `Customers now:`
  - `Average monthly value:`
  - `Target in 90 days:`
  - Ask one question only if the Brain says nothing either way.

If more than two things are missing, say so, and offer the full `founder-brain` skill in update mode rather than asking question after question.

**If the Brain that arrived replaced one this folder already had,** the files built from the old one no longer match it. The "When one file changes, what goes stale" table in `../../references/contract.md` says which. Name them in plain words, say they are now out of date, and offer to rebuild each one. Never rebuild quietly.

### Content (if `engines/content/content-30.md` exists)

- **Ledger.** If `log/ledger.md` has no `C|` rows, add one row per piece:
  - Format: `C|<n>|<pillar number>|<format>|<lane>|draft|-|-`
  - `<n>` is the piece number.
  - `<pillar number>` is 1 to 4, from the pillar heading it sits under.
  - `<format>` is a short slug: `short-post`, `long-post`, `cta-post`, `video-script`, `carousel` or `caption`.
  - `<lane>` is `media` only if the piece has a note saying it still needs a clip or photo the founder has not got. Otherwise `text`.
  - Every row is `draft`. Nothing is approved on import, because approval is the founder reading each piece and saying so.
- **CSV.** Check `engines/content/content-30.csv` has exactly the header `content,platform,scheduled_date,media_note`, and the same number of pieces as `engines/content/content-30.md`.
  - If it does not, tell them, and offer to rebuild the CSV from the markdown. Rebuild only if they say yes.

### B2B first lines

If `engines/outreach/outreach-firstlines.csv` has a `status` column, or quotes around every field, rewrite it with the unquoted header `email,first_name,company,first_line`, quoting only fields that hold a comma or a quote. Keep every row. This file stays out of git, because it holds real people's details.

Then, if `people/` holds fewer `kind: prospect` files than the CSV has rows, write a person file for each row whose email has none, named by the slug of the email, in the prospect shape in the contract. Set `key` and `email` to the address, with `kind: prospect`, `status: candidate`, `source: import`, `created` today, and `first_name` and `company` from the row. Put the row's `first_line` inside the Opener block. Never change a person file that already exists.

### B2C openers

If `people/` holds fewer `kind: target` files than `engines/audience/dm-openers.md` has openers, write a target file for each handle that has none, named by the slug of `ig:<handle>`, in the target shape in the contract. Set `key: ig:<handle>`, with `kind: target`, `status: opener_written`, `platform: ig`, `handle` without the `@`, `source: import` and `created` today. Put that opener inside the Opener block. Never change a person file that already exists. An opener with no handle against it gets no file: tell the founder how many there are, and that each one is recorded once they add the handle. These files stay out of git, because they hold real people's details.

### Refill archives

Rename any `content-30-<month name>.md` to `engines/content/content-30-YYYY-MM.md`.

### Wording from the app, inside the deliverables

Search the files for:
- "in the app"
- "open Files"
- "from Files"
- "download everything"
- "Launchhouse app"

List any lines found, and ask once whether to remove them. Remove only the words about the app, keeping the rest of the sentence reading properly, and show each changed line before and after. Change nothing else.

### The bookkeeping headers

The app wrote these files through a tool that no longer exists, and their headers say not to edit them by hand. Every engine now edits them, so replace only those header lines:
- **memory.md:** if a line mentions `ge remember`, replace it with "Add one line per entry inside the marked blocks, dated. Anything under Notes is the founder's own."
- **ledger.md:** replace the line mentioning `ge ledger` with the two header lines from the start skill's scaffold. Keep every `C|` row.
- **ops-log.md:** replace the line mentioning `ge log` with the header line from the start skill's scaffold. Keep every entry.
- **memory.md, under Notes:** replace "ge never writes here" with "Anything below this heading is the founder's own."
- **people/README.md:** replace it with the start skill's scaffold version, which no longer mentions a tool.
- **Each person file:** replace the first line, `<!-- Written by ge person. ... -->`, with nothing, and under `## Yours` remove the line "Anything below this heading is yours. ge never writes here." if it is there. Change nothing else in the file.

**If a change is held by the Launchhouse checks,** the hook tells you which line and why. Do not try to force the change through. That is the check finding something already in their work. Note it for step 5 and move on.

## 5. Check the rules, do not rewrite

Use the `rules-reviewer` agent on every deliverable in `growth-engine/`. Tell it:
- the files were imported from the app
- the figures the founder gave: none, unless they told you some during this import

Then tell the founder what it found:

- **Nothing held.** Say their work is clean against the Launchhouse checks.
- **Held lines.** List each as "worth a look", with the file, the line, and the reason in plain words. The app already stopped the worst cases, so these are usually small. Offer to fix them one at a time. Change a line only after they say yes to that line.
- **Notes.** Mention the count and offer to show them.

## 6. Check it against the live accounts

Offer this once, in plain words: this work came from the app, and the founder's live accounts may have moved on since. Say Claude can look at what is connected and say where the two disagree, and that this changes nothing by itself.

**Only check what is actually connected.** Before saying a connector is missing, use ToolSearch for its tools: a connected connector's tools are often deferred, not absent, until searched for. If nothing is connected at all, say so in one line and offer "connect my tools" instead of running any check below.

Every check here is read-only. Nothing is changed, sent, activated or bought by this step, whatever it finds.

**GoHighLevel, if connected.**
- Read `growth-engine/engines/ops/ghl-values.md` for the custom values it names, and read the account's own custom values back, following `../../references/connections.md` for how to search for and run that job. Say which named values are missing from the account, and which are present but still hold `PLACEHOLDER` or are empty.
- Read the accounts to post to, and name which social accounts are connected.
- For any workflow their imports describe, say whether the account's copy is live or draft. Report only. Never turn one on, off, or edit it.

**Apollo, B2B only, if connected.** Say whether a sequence matching their imported outreach exists in the account, whether it is active or paused, and how many people are in it. Never start, activate or add to it.

**Mailbox, B2B only, if connected.** There is nothing in their imported files to compare it against. Just say whether it can write drafts.

Report back as a short list: what matches, what differs, what is missing. For each difference, offer the one plain next step and wait for a yes before doing any of it:
- custom values missing or holding `PLACEHOLDER`: "fill my custom values"
- no matching Apollo sequence: "build my Apollo sequence"
- nothing connected, or a connector missing: "connect my tools"

**The rules, stated plainly:** this step only ever reads. It never sends a message, never activates a workflow or a sequence, never buys anything. A live workflow or an active sequence is reported to the founder, never touched. Their imported files are the source of truth for the words. The account is the source of truth for what is actually live.

**If their imported work predates their account setup,** say plainly that nothing is wrong: the account simply has not been set up yet. Point them at the clinic steps for setting it up.

## 7. Save, and hand on

1. Run `git add -A` then `git commit -m "Adjusted to the new setup"`.
2. If `git remote -v` shows a remote, run `git push`. If that fails, say their work is saved on this computer and GitHub can be sorted later.
3. Tell them in three short lines:
   - what came across
   - what was adjusted
   - what is next, from the list below

**What is next:**
- no content yet: build the content engine
- B2B with no `engines/outreach/outreach-sequence.md`: build the outreach engine
- B2C with no `engines/audience/dm-openers.md`: build the audience engine
- no `engines/ops/ops-workflow.md`: build the operations engine
- `engines/ops/ops-workflow.md` but no `engines/ops/ghl-values.md`: write the GoHighLevel words, before the clinic ("fill my custom values")
- all of those done: connect GoHighLevel, and Apollo for B2B, then publish

4. Say once how they check where they stand at any point: "where am I up to" lists every gate item, what is done and what is still open.

End with: "You do not need the app any more. Everything is here, and it is saved."
