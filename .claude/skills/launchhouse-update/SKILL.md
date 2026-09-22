---
name: launchhouse-update
description: Bring a founder's Launchhouse folder up to date with the latest system, keeping their own changes and their work safe. Trigger on "update launchhouse", "get the latest version", "is there an update", "apply updates", "undo the update", and when the help skill diagnoses an outdated folder.
---

# Launchhouse update

Brings the system in `.claude/` up to date from the public Launchhouse original, while the founder's own `growth-engine/` folder is never touched, their own changes to the system are kept, and nothing changes unless every check passes.

**Who is reading this.** A founder who does not use a terminal. Run every command yourself, from inside this skill. Talk about "the latest version" and "your changes", never commits, branches or diffs, unless they ask to see one.

**Name their doubt first**, before step 1: an update can sound like it might wreck their work. Say plainly: their `growth-engine/` folder is never touched. Anything they changed in the system itself is kept, or held for them to choose. Nothing is applied unless every check passes. And it can be undone.

Every command below ends `< /dev/null` and is run by you, never shown to the founder unless they ask.

## First update on an older copy

Check first: does `.claude/scripts/update.sh` exist in this folder? Some copies were made before the updater shipped, so it will not be there yet. If it is missing, do this once, then carry on at step 0, running every `update.sh` command in this skill from `<gitdir>/launchhouse/bootstrap/update.sh` instead of `.claude/scripts/update.sh`, for the rest of this one update (the engine finds the real repository root correctly either way; `<gitdir>` is what `git rev-parse --absolute-git-dir < /dev/null` prints).

**Check the upstream address before touching anything fetched from it**, the same way `update.sh` itself always does: if an `upstream` remote already exists, compare its fetch URL (`git remote get-url upstream < /dev/null`) against the canonical address -- the contents of `.claude/launchhouse-upstream` as recorded in the committed HEAD tree (`git show HEAD:.claude/launchhouse-upstream < /dev/null`) if that file exists there, otherwise `https://github.com/Philm-moxywolf/launchhouse-founder-template.git` -- ignoring a trailing slash, a trailing `.git`, and letter case. If they differ, stop: tell the founder plainly that the upstream address is not the Launchhouse original, and do not fetch, copy, or run anything from it.

1. Add the upstream remote if it is not already there: `git remote add upstream https://github.com/Philm-moxywolf/launchhouse-founder-template.git < /dev/null` (an error here just means it already exists -- and the check above already confirmed it is the right one), then `git fetch upstream < /dev/null`.
2. Make `<gitdir>/launchhouse/bootstrap/`.
3. Copy the updater in from upstream's own current version, since this copy has none of its own: `git show upstream/main:.claude/scripts/update.sh > <gitdir>/launchhouse/bootstrap/update.sh` and the same for `lib.sh`, then make `update.sh` executable.
4. This older copy's own copy of this skill may be out of date, or missing. Read it as upstream has it instead: `git show upstream/main:.claude/skills/launchhouse-update/SKILL.md < /dev/null`, and follow that version, not this one, from here on.
5. In step 4 below, the `update-reviewer` agent may not exist in this older copy either. If dispatching it fails, read `git show upstream/main:.claude/agents/update-reviewer.md < /dev/null` instead and do that review yourself, inline, exactly as it describes, before showing the founder anything.

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

Run `sh .claude/scripts/update.sh --plan < /dev/null`.

- If it reports zero changes, say: "You are up to date." Stop here.
- Otherwise it has written `<gitdir>/launchhouse/update/plan.tsv`, diffs, and merged files. Do not read these to the founder yet.

## 4. Second read

Dispatch the `update-reviewer` agent with the plan path and the state dir (this folder). It is read-only. Read its report fully before showing the founder anything.

## 5. Combine the two into one decision

For every row in the plan, the final decision is the **more cautious** of the plan's own `proposed` value and the reviewer's `## Decisions` value, in this order from most to least cautious: `hold` > `keep-mine` > `apply`. (`take-theirs` is only ever chosen by the founder in step 6, never proposed here.)

`settings` rows always go to the founder as a held choice, unless the founder never changed `settings.json` from the point this copy started (the reviewer's `## Waterfall` says so either way).

## 6. Show the founder and get their yes

In this order, in plain words:

1. **What is new.** The reviewer's `## What is new` bullets.
2. **Kept as you made it.** A count and the plain names of what is being kept exactly as the founder has it (their own edits to files the update also touched, or anything unchanged for them).
3. **Each held item**, one AskUserQuestion per item (or a batch if the tool allows more than one), using the reviewer's plain sentence, with exactly two options:
   - **Keep mine**: recommended, unless the reviewer's reason says the update fixes a safety rule, in which case **Take the update (yours kept safe)** is recommended instead, and say why in one sentence.
4. **Any migrations**, each as a separate yes or no. Say plainly these run only after the update is applied, by a named skill, never during it, and only with their yes.
5. **One clear yes to apply everything above as decided.**

If they say no, or don't answer, stop here. Nothing has changed yet.

## 7. Write decisions and apply

Write `decisions.tsv` (`path<TAB>decision`, one row per plan path; a path with no explicit choice is `hold`) into the state dir the engine expects. Run:

```
sh .claude/scripts/update.sh --apply <decisions.tsv path> < /dev/null
```

This tags a checkpoint, builds and tests in a scratch worktree, and only fast-forwards the live folder if every check passes. Read `result` from its output.

## 8. Say what happened

**`result=applied`:**
1. If a remote exists and it is not under `Philm-moxywolf` (the same check the save skill and start skill use), push: `git push origin < /dev/null`.
2. Tell them, in plain words: quit the Claude app completely and open it again in this folder, so the new version loads.
3. List what changed, in plain words, from `## What is new`.
4. Mention "undo the update" is there if anything looks wrong.
5. If there were migrations they said yes to, do them now, by their named skill, and say what changed in the founder's own files when done.

**`result=aborted`:**
1. Say, in one sentence, that nothing changed.
2. Say, in plain words, what failed (from the engine's own output; `unchanged=yes` confirms nothing moved).
3. Two reasons need their own handling, not just "try again":
   - **`reason=folder changed since the plan; plan again`**: something in the folder moved since step 3's plan was taken (their own save, another update attempt, anything). Say so in one plain sentence, then go back to step 3 and plan again.
   - **`reason=no checks to run`**: this copy has no checks of its own to prove the update is safe before it lands. Tell the founder plainly: there is nothing here to test the update against, so applying it is a little more trust than usual. Ask them, with AskUserQuestion, whether to go ahead anyway (recommended: no, wait and ask a mentor first) or apply without that safety net. Only on a clear yes, re-run step 7 with `--allow-no-checks` added after the decisions file path.
4. For any other reason, offer to try again later, or say a mentor can help.

## Undo the update

On "undo the update", confirm what will happen in one sentence, then run:

```
sh .claude/scripts/update.sh --undo < /dev/null
```

This reverses only the update itself, as a new commit; anything they changed since, in `growth-engine/` or in the system, is kept exactly as they left it. Nothing is lost either way. Read `result` from its output:

- **`result=undone`**: push the same way as step 8, then tell them to quit and reopen the app.
- **`result=noop`**: say plainly there is nothing left to undo; the update was already backed out.
- **`result=none`**: say plainly there is no update on record to undo.
- **`result=aborted` with `reason=later changes overlap the update`**: say plainly, in this order: nothing was undone, their work is untouched; then name what they have changed since the update, in plain words, from the paths it lists (a skill's own file is "one of your skills", a script under `.claude/scripts/` is "part of the system's own tools", `.claude/settings.json` is "your settings", something under `.claude/tool-packs/` is "one of your tool packs", `.claude/agents/` is "one of your helpers", `.claude/commands/` is "one of your commands"; for anything else, name the file plainly); then offer to help them reach their mentor about it, since undoing past their own change needs a person's judgement, not this engine's.

## Hard rules

- Never edit anything under `growth-engine/`.
- Never force, reset or rebase.
- Never resolve a conflict by hand-editing a file outside the engine's own `--apply` step.
- Never apply anything without the founder's yes.
- Never show conflict markers or a raw diff unless they ask to see one.
