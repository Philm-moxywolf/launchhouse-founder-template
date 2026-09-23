---
name: launchhouse-update
description: Bring a founder's Launchhouse folder up to date with the latest system, keeping their own changes and their work safe. Trigger on "update launchhouse", "get the latest version", "is there an update", "apply updates", "undo the update", and when the help skill diagnoses an outdated folder.
---

# Launchhouse update

Brings the system in `.claude/` up to date from the public Launchhouse original, while the founder's own `growth-engine/` folder is never touched, their own changes to the system are kept, and nothing changes unless every check passes.

**Who is reading this.** A founder who does not use a terminal. Run every command yourself, from inside this skill. Talk about "the latest version" and "your changes", never commits, branches or diffs, unless they ask to see one.

**Name their doubt first**, before step 1: an update can sound like it might wreck their work. Say plainly: their `growth-engine/` folder is never touched. Anything they changed in the system itself is kept, or brought forward with the improvement added on top, or held for them to choose. Nothing is applied unless every check passes. And it can be undone.

Every command below ends `< /dev/null` and is run by you, never shown to the founder unless they ask.

## First update on an older copy

Check first: does `.claude/scripts/update.sh` exist in this folder, and if it does, does it still match upstream's current version? Some copies were made before the updater shipped, so it will not be there yet; others already have one, but an older version than upstream's current one. Either way, this folder needs the newest updater and instructions before an update runs, not whatever older copy happens to already be here -- so if it is missing, or it differs from upstream's current `.claude/scripts/update.sh`, do this once, then carry on at step 0, running every `update.sh` command in this skill from `<gitdir>/launchhouse/bootstrap/update.sh` instead of `.claude/scripts/update.sh`, for the rest of this one update (the engine finds the real repository root correctly either way; `<gitdir>` is what `git rev-parse --absolute-git-dir < /dev/null` prints).

**Check the upstream address before touching anything fetched from it**, the same way `update.sh` itself always does: if an `upstream` remote already exists, compare its fetch URL (`git remote get-url upstream < /dev/null`) against the canonical address -- the contents of `.claude/launchhouse-upstream` as recorded in the committed HEAD tree (`git show HEAD:.claude/launchhouse-upstream < /dev/null`) if that file exists there, otherwise `https://github.com/Philm-moxywolf/launchhouse-founder-template.git` -- ignoring a trailing slash, a trailing `.git`, and letter case. If they differ, stop: tell the founder plainly that the upstream address is not the Launchhouse original, and do not fetch, copy, or run anything from it.

1. Add the upstream remote if it is not already there: `git remote add upstream https://github.com/Philm-moxywolf/launchhouse-founder-template.git < /dev/null` (an error here just means it already exists -- and the check above already confirmed it is the right one), then `git fetch upstream < /dev/null`.
2. If `.claude/scripts/update.sh` exists locally, compare it against upstream's current copy (for example `git show upstream/main:.claude/scripts/update.sh < /dev/null | diff - .claude/scripts/update.sh`). If they are identical, this whole section does not apply after all -- carry on at step 0 using `.claude/scripts/update.sh` as normal, not the bootstrap copy. If they differ, or the file was missing, continue below.
3. Make `<gitdir>/launchhouse/bootstrap/`.
4. Copy the updater in from upstream's own current version, since it is newer than whatever this copy has (or has none at all): `git show upstream/main:.claude/scripts/update.sh > <gitdir>/launchhouse/bootstrap/update.sh` and the same for `lib.sh`, then make `update.sh` executable.
5. This older copy's own copy of this skill may be out of date, or missing. Read it as upstream has it instead: `git show upstream/main:.claude/skills/launchhouse-update/SKILL.md < /dev/null`, and follow that version, not this one, from here on.
6. In step 6 below, the `update-reviewer` agent may not exist in this older copy either. If dispatching it fails, read `git show upstream/main:.claude/agents/update-reviewer.md < /dev/null` instead and do that review yourself, inline, exactly as it describes, before showing the founder anything.
7. This copy's routing check in step 3 ("Which way this update goes") assumes the `update-adapter` agent exists wherever notes.tsv and adapt.tsv do. If it is missing, or dispatching it fails, treat that the same as notes.tsv or adapt.tsv being absent after `--plan`: skip step 4 and step 5 entirely, go straight to step 6, then follow "Step 8, the old way" instead.

Once this update lands, the folder has its own updater again at the usual path, so this whole section is skipped next time.

## 0. Save first

Run `sh .claude/scripts/update.sh --status < /dev/null`.

- If it prints `result=aborted` with `reason=upstream address is not the Launchhouse original`, stop. Say plainly: this folder's own record of where updates come from does not match the Launchhouse original, so nothing was checked or changed, and a mentor can help work out why.
- Otherwise, read `clean` and `in_progress` from the key=value output.
  - If `in_progress=yes`, stop. Say plainly: an earlier update did not finish. Do not start a new one; offer to try `--undo` if they want to back out, or say a mentor can help.
  - If `clean=no`, save their work first, the same way the save skill does it (`git status --short`, say in one line what is being saved, `git add -A`, commit with a short plain message, push if `origin` exists). Then re-run `--status`.

## 1. Check for an update

From the same `--status` output:
- `upstream_url`: if it looks unreachable, or the command failed to reach it, say plainly the update could not be checked right now (no internet, or the source is down), and stop.
- `base` and `upstream_head`: read on.

## 2. Find where this copy started

Run `sh .claude/scripts/update.sh --detect-base < /dev/null`.

- **`recorded <sha>`**: already known. Carry on to step 3.
- **`exact <sha>`**: this copy matches a known point exactly. Run `sh .claude/scripts/update.sh --set-base <sha> < /dev/null` so it is recorded, then carry on.
- **`closest <sha> <n>`**: no exact match. Ask with AskUserQuestion, showing the candidate's date and a one-line summary of what it is (recommended, first), and a second option "not sure". If they are not sure, stop and say a mentor can help work out where their copy started; do not guess.
- **`none`**: cannot place this copy at all. Stop and say plainly the update cannot tell where this folder started, so it cannot safely compare it, and a mentor can help.

## 3. Plan

Run `sh .claude/scripts/update.sh --plan < /dev/null` with the Bash tool's maximum timeout (600000 ms, ten minutes), never the default: the checks this runs can take longer than a default timeout allows on a slower computer. If it is cut off anyway, run the exact same `--plan` command again; the engine clears any leftover from the cut-off run itself, so a retry is always safe.

- If it reports zero changes, say: "You are up to date." Stop here.
- Otherwise it has written `<gitdir>/launchhouse/update/plan.tsv`, diffs, and merged files. Do not read these to the founder yet.

**Which way this update goes.** Check whether `<gitdir>/launchhouse/update/notes.tsv` and `<gitdir>/launchhouse/update/adapt.tsv` both exist.

- **Both exist:** this copy's updater knows each improvement's own purpose. Carry on to step 4 below, then step 5, then step 6, then "Step 8, the new way".
- **Either is missing:** this copy's updater predates that, so there is nothing to adapt against yet. Skip step 4 and step 5 entirely, go straight to step 6, then follow "Step 8, the old way" instead of "the new way". Once this update lands (step 10), tell the founder plainly that their next update will be able to bring an improvement in on top of their own changes instead of only asking them to choose; nothing to do about it now, it just works better from here on.

## 4. Ask about each improvement

Skip this step entirely on the old way (above). Nothing has been adapted yet at this point -- ask purely from each note's own saved purpose, before any file is touched.

For every note in `<gitdir>/launchhouse/update/notes.tsv` that has at least one row in `<gitdir>/launchhouse/update/adapt.tsv` naming it (a note with no held row for it needs no question here; it is already covered by "What is new" in step 8): read the note's id, title and safety flag from `notes.tsv`, and its file at the path that column gives, relative to the state dir -- `<gitdir>/launchhouse/update/<note-path>`, for example `<gitdir>/launchhouse/update/notes/<id>.md` -- never the upstream release copy the note came from, since a founder's own tree may have edited or removed it. Read the note's purpose and done-when there for what it does for them.

Use AskUserQuestion, batched where the tool allows more than one:

- **A safety improvement**: the note's title and a plain account of what it does for them, from its purpose. Two options, never a third: **Apply** (the only sensible default; do not mark anything else recommended) and **Tell me more**, which shows the note's own "What changed and why" in plain words, then asks Apply again. Never offer to skip a safety improvement.
- **A non-safety improvement**: the note's title and a plain account of what it does for them, from its purpose. Two options: **Take this update** (recommended), **Keep mine as it is**.

Record each note's answer. Step 5 adapts only the files behind a note the founder approved here; step 8 reports what came of it, and gets one final yes before anything is actually applied.

## 5. Adapt what the founder changed

Skip this step entirely on the old way.

`<gitdir>/launchhouse/update/adapt.tsv` has one row per file the founder changed that an improvement also touches: `path`, `note-ids` (comma-separated, or `-` if no current improvement note names this path), then `base`, `theirs`, `mine`: each is a path *relative to `<gitdir>/launchhouse/update/`* (for example `adapt/base/<path>`), so read it at `<gitdir>/launchhouse/update/<that column's value>`; a column of `-` means that side does not exist.

For every row, work out what to adapt it for:

- If `note-ids` is not `-`, keep only the id(s) the founder approved in step 4. If none of its notes were approved, do not dispatch the adapter for this row at all -- it is not touched here; step 8 reports it as held, exactly as the founder left it.
- If `note-ids` is `-`, there is no note to ask about; always attempt this one, using `git diff <base> <upstream_head> -- "<path>"` and `git log --oneline <base>..<upstream_head> -- "<path>"` for that one path as the purpose, given to the adapter inline.

For every row left after that filter, in one batch of concurrent dispatches where you can:

1. Dispatch `update-adapter` with: the path; the three copy files to read, each resolved from the state dir as above (skip any column that is `-`); and either the approved id(s), each one's title, purpose, and done-when read from `<gitdir>/launchhouse/update/notes.tsv` plus the note file itself at `<gitdir>/launchhouse/update/<note-path>` (id, title, purpose, done-when, and the note's own body) -- or, when `note-ids` was `-`, the diff and log gathered above, standing in for a purpose.
2. If it returns an adapted body: save it to a scratch file under `<gitdir>/launchhouse/update/adapt/out/<path>` (matching the same relative path), then run `sh .claude/scripts/update.sh --adapt-save "<path>" "<gitdir>/launchhouse/update/adapt/out/<path>" "<the approved note ids for this path, comma-separated, or - when note-ids was ->" < /dev/null`. Read the result: `saved=<path>` means it is stored and ready to offer. `result=refused` with a `reason=` means do not retry it: never retry blindly. If any note approved for this path is a safety note, this path becomes `take-theirs` (their own copy is kept safe, and comes back through the restore step later); otherwise it becomes `hold`. Keep the reason plain, for step 8.
3. If it returns `cannot-adapt: <reason>`, keep the path and the reason; nothing is saved for it, for the same handling as above.

Nothing here is shown to the founder yet. This just gets every path ready to be reported in step 8, alongside the second read.

## 6. Second read

Dispatch the `update-reviewer` agent with the plan path and the state dir (this folder). It is read-only. Read its report fully before showing the founder anything. If step 5 ran, the reviewer also reads every path you saved through `--adapt-save` against the improvement's own purpose, and can say a given adaptation reads wrong even though it was saved; treat any such path exactly as `cannot-adapt`, using the reviewer's own reason, regardless of what `update-adapter` itself returned for it, and regardless of the approval given in step 4 -- the reviewer's read always wins, and a row it flags this way is never offered as `adapted`.

## 7. Combine the two into one decision (the old way only)

Skip this step on the new way; step 8 below covers it instead.

For every row in the plan, the final decision is the **more cautious** of the plan's own `proposed` value and the reviewer's `## Decisions` value, in this order from most to least cautious: `hold` > `keep-mine` > `apply`. (`take-theirs` is only ever chosen by the founder in step 8, never proposed here.)

`settings` rows always go to the founder as a held choice, unless the founder never changed `settings.json` from the point this copy started (the reviewer's `## Waterfall` says so either way).

## 8. Show the founder and get their yes

### Step 8, the new way

In this order, in plain words:

1. **What is new.** The reviewer's `## What is new` bullets.
2. **Kept as you made it.** A count and the plain names of what is being kept exactly as the founder has it (their own edits the update never touches, or anything unchanged for them).
3. **What each changed file will look like.** For every path adapted and saved in step 5 whose note the founder approved in step 4, and that step 6 did not flag: one short plain sentence of what it does for them, from `update-adapter`'s own "What changes for the founder" lines. This is a report, not a new question -- the founder already said Apply or Take this update in step 4; item 6 below is where they give the one yes that actually applies it. For a path whose note was approved but that turned out `cannot-adapt`, was refused, or was flagged in step 6: say so plainly, in one sentence, using the reason given. A safety note's file is kept safe now and offered again once it can be safely combined, on a later update; a non-safety note's file is simply kept as the founder has it, with nothing lost.
4. **Paths with no note** (`note-ids` was `-` in `adapt.tsv`, the "earlier changes" group): ask about each one individually, the same shape as item 3 of "Step 8, the old way" just below (the reviewer's own plain sentence, **Keep mine** recommended unless the reviewer says the change fixes a safety rule, in which case **Take the update (yours kept safe)** is recommended, and say why in one sentence).
5. **Any migrations**, each as a separate yes or no. Say plainly these run only after the update is applied, by a named skill, never during it, and only with their yes.
6. **One clear yes to apply everything above as decided.**

If they say no, or don't answer, stop here. Nothing has changed yet.

Turn all of that into decisions: for a path whose note was approved (or forced-safety) in step 4 and saved in step 5, the decision is `adapted`; for a path whose note was declined in step 4, or that was `cannot-adapt` and not safety, `hold`; for a path that was `cannot-adapt` and safety, `take-theirs`. For the "earlier changes" group asked about in item 4, a plain **Keep mine** is `keep-mine` (or `hold` if it was `cannot-adapt`), **Take the update** is `adapted` when a body was saved for it, `take-theirs` otherwise.

### Step 8, the old way

1. **What is new.** The reviewer's `## What is new` bullets.
2. **Kept as you made it.** A count and the plain names of what is being kept exactly as the founder has it (their own edits to files the update also touched, or anything unchanged for them).
3. **Each held item**, one AskUserQuestion per item (or a batch if the tool allows more than one), using the reviewer's plain sentence, with exactly two options:
   - **Keep mine**: recommended, unless the reviewer's reason says the update fixes a safety rule, in which case **Take the update (yours kept safe)** is recommended instead, and say why in one sentence.
4. **Any migrations**, each as a separate yes or no. Say plainly these run only after the update is applied, by a named skill, never during it, and only with their yes.
5. **One clear yes to apply everything above as decided.**

If they say no, or don't answer, stop here. Nothing has changed yet.

## 9. Write decisions and apply

Write `decisions.tsv` (`path<TAB>decision`, one row per plan path; a path with no explicit choice is `hold`) into the state dir the engine expects, using `adapted`, `take-theirs`, `keep-mine`, or `hold` for the founder's own answers from step 8 as worked out above, and `apply` for everything else the plan or step 7 already resolved. Run:

```
sh .claude/scripts/update.sh --apply <decisions.tsv path> < /dev/null
```

Run this with the Bash tool's maximum timeout (600000 ms, ten minutes), never the default: it builds and tests in a scratch worktree, and that can run long on a slower computer. If it is cut off anyway, run the exact same `--apply` command again with the same decisions.tsv; the engine clears the leftover worktree from the cut-off run itself before it starts, so a retry is always safe, never "could not create a worktree".

This tags a checkpoint, builds and tests in a scratch worktree, checks the improvements just applied actually hold, and only fast-forwards the live folder if every check passes. Read `result` from its output.

## 10. Say what happened

**`result=applied`:**
1. If a remote exists and it is not under `Philm-moxywolf` (the same check the save skill and start skill use), push: `git push origin < /dev/null`.
2. Tell them, in plain words: quit the Claude app completely and open it again in this folder, so the new version loads.
3. List what changed, in plain words, from `## What is new`.
4. Mention "undo the update" is there if anything looks wrong.
5. If there were migrations they said yes to, do them now, by their named skill, and say what changed in the founder's own files when done.
6. Then, always, run `sh .claude/scripts/update.sh --restore-settings-plan < /dev/null`.
   - **`restore=none`**: nothing further, stop here.
   - **`restore=found`**, with `path=` (always `.claude/settings.json`) and `from_tag=`: it has written a fresh `plan.tsv`, `notes.tsv` and `adapt.tsv` of their own, one held row for that path, the same shape a normal `--plan` writes. Say plainly: an earlier update had to take their settings as they stood then, and this brings back what they had changed since, on top of everything since applied. Offer it now as its own small update: go back to step 4, then step 5, then step 6, then step 8 (the new way; it always has a note for this row), then this step again. It never needs a further restore check of its own once it lands. If the founder says no to this offer, run `sh .claude/scripts/update.sh --restore-settings-decline < /dev/null` before moving on: this records the tag as resolved (declined) so it is never offered again, rather than leaving it pending forever.

**`result=reverted`:**
1. Say plainly, in one sentence: nothing changed, their files are back as they were before the update, and a record of what was tried stays in their saved history.
2. Say why, in plain words, from `reason`.
3. Tell them to post in the Slack channel, saying what they were trying to update and what this said, so someone can look at why the update itself did not hold up once it landed.

**`result=reverted-failed`:**
1. Say plainly, in one sentence: nothing was supposed to change, but the automatic undo could not finish on its own, so a mentor needs to look at this folder directly.
2. Give them the tag name from `pre_update_tag` in the output, and tell them to include it when they post in the Slack channel; a maintainer uses it to find exactly where the folder stands.
3. Change nothing else: do not retry, do not run `--undo` yourself, do not touch `.claude/` or `growth-engine/` again this session.

**`result=aborted`:**
1. Say, in one sentence, that nothing changed.
2. Say, in plain words, what failed (from the engine's own output; `unchanged=yes` confirms nothing moved).
3. Two reasons need their own handling, not just "try again":
   - **`reason=folder changed since the plan; plan again`**: something in the folder moved since step 3's plan was taken (their own save, another update attempt, anything). Say so in one plain sentence, then go back to step 3 and plan again.
   - **`reason=no checks to run`**: this copy has no checks of its own to prove the update is safe before it lands. Tell the founder plainly: there is nothing here to test the update against, so applying it is a little more trust than usual. Ask them, with AskUserQuestion, whether to go ahead anyway (recommended: no, wait and ask a mentor first) or apply without that safety net. Only on a clear yes, re-run step 9 with `--allow-no-checks` added after the decisions file path.
4. For any other reason, offer to try again later, or say a mentor can help.

## Undo the update

On "undo the update", confirm what will happen in one sentence, then run:

```
sh .claude/scripts/update.sh --undo < /dev/null
```

This reverses only the update itself, as a new commit; anything they changed since, in `growth-engine/` or in the system, is kept exactly as they left it. Nothing is lost either way. Read `result` from its output:

- **`result=undone`**: push the same way as the `result=applied` step above, then tell them to quit and reopen the app.
- **`result=noop`**: say plainly there is nothing left to undo; the update was already backed out.
- **`result=none`**: say plainly there is no update on record to undo.
- **`result=aborted` with `reason=later changes overlap the update`**: say plainly, in this order: nothing was undone, their work is untouched; then name what they have changed since the update, in plain words, from the paths it lists (a skill's own file is "one of your skills", a script under `.claude/scripts/` is "part of the system's own tools", `.claude/settings.json` is "your settings", something under `.claude/skill-packs/` is "one of your skill packs", `.claude/agents/` is "one of your helpers", `.claude/commands/` is "one of your commands"; for anything else, name the file plainly); then offer to help them reach their mentor about it, since undoing past their own change needs a person's judgement, not this engine's.

## Hard rules

- Never edit anything under `growth-engine/`.
- Never force, reset or rebase.
- Never resolve a conflict by hand-editing a file outside the engine's own `--apply` step.
- Never apply anything without the founder's yes.
- Never offer "skip" for a safety improvement; only "Apply" or "Tell me more".
- Never write `adapted` for a path the founder was not asked about, and never write it for a path the reviewer flagged as reading wrong.
- Never show conflict markers, a raw diff, or an adapted file's own text unless they ask to see it.
