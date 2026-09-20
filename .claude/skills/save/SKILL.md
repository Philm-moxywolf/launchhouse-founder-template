---
name: save
description: Save the founder's Launchhouse work, show what changed, and bring back an earlier version of a file, in plain words, using the git history of their folder. Never deletes history. Trigger on "save my work", "save", "what changed", "what have I changed", "undo that", "bring back the old version", "I deleted something", "put it back", "back up to GitHub".
---

# Save

The founder's folder keeps a history of every save. This skill is how they use it without knowing it is git.

**Who is reading.** A founder who does not use a terminal. Run every command yourself. Talk about "saves" and "earlier versions", never commits, branches or hashes.

**What this never does**
- Rewrite or delete history.
- Force push.
- Reset the folder.
- Delete a file the founder did not name.

Any of those can lose work, and none of them is ever needed here.

## Save my work

1. Run `git status --short`.
   - If nothing changed, say everything is already saved, and when: `git log -1 --format=%cd`.
2. Say in one line what is being saved, in words: "your content file and 3 new writing samples".
3. Run `git add -A`.
   - `.gitignore` keeps `people/` and downloaded zips out.
   - If `git status` shows a person file, a zip, `engines/outreach/outreach-firstlines.csv`, `engines/audience/dm-openers.md`, or any `.csv` with an email column about to be added, stop. Run `git restore --staged` on it, fix `.gitignore` from the start skill's scaffold, and only then save.
4. Commit with a short plain message that says what the work was: `git commit -m "<what changed>"`.
5. **Push.**
   - If `git remote -v` shows an `origin`, run `git push origin`, naming it explicitly, never a bare `git push`. `origin` is the only remote this folder ever saves to.
   - If the push is refused because GitHub has newer saves (for example, a routine drafted something), run `git pull --no-rebase origin`, then push again.
   - If the only conflict is `growth-engine/.state/index.md`, that file is worked out from the folder, not written by anyone. Run `git checkout --ours growth-engine/.state/index.md`, add it, finish the merge, and let it rebuild itself.
   - If the pull stops on any other conflict, do not resolve it by guessing. Run `git merge --abort`, say their work is saved on this computer, and tell them a mentor will sort the GitHub copy.
   - If the push asks for a login or fails another way, say their work is saved on this computer, and it goes up to GitHub with one button: open GitHub Desktop and press **Push origin**. If they do not use GitHub Desktop, a mentor can connect it.

6. End by saying what to do next, and name the plain way to check where they stand: say "where am I up to". If they have not seen them yet, "set up my routines" or "add a file" can be the one you name instead. One, once.

After a save, the copies in their Desktop Launchhouse folder refresh on their own at the end of the turn. Nothing more to do or say unless they ask.

**If git has no name or email set,** ask for the email they want on their saves, and set both for this folder only, as in the start skill.

**If `git` itself does not work,** the computer cannot save history yet. On a Windows PC, send them through step 0 of the start skill to install Git for Windows. Their files are still safe in the folder meanwhile.

## What changed

- **Since the last save:** `git status --short` and `git diff --stat`. Describe it in words.
- **Over a period:** `git log --since="<when>" --format="%ad %s" --date=short -- growth-engine`. List the saves in plain words.
- **In one file:** `git diff HEAD -- growth-engine/<file>`. Show the few lines that changed, not the whole diff.

## Bring back an earlier version

1. **Find the file and the version.** Run `git log --format="%h %ad %s" --date=format:"%a %d %b %H:%M" -- growth-engine/<file>`.
2. **Show them the saves** as a short numbered list of dates and messages. Do not show the hashes.
3. **Show what they would get back.** Run `git show <hash>:growth-engine/<file>`, and show the first lines, or the part they care about.
4. **Ask for a yes.**
5. **Save first.** If there are unsaved changes to that file, save them, so nothing is lost by going back.
6. **Restore the file.** Run `git restore --source <hash> -- growth-engine/<file>`.
7. **Save it.** Run `git add -- growth-engine/<file>` and `git commit -m "Brought back <file> from <date>"`. The newer version stays in the history, so they can change their mind.

If the file was deleted, find the last save that had it with `git log --diff-filter=D --format="%h %ad" -- growth-engine/<file>`. Restore from the save before that one.

**Undo that.** The founder means the last thing that changed:
- **A file change that is not saved yet:** show it, and on a yes run `git restore -- growth-engine/<file>`.
- **Already saved:** bring back the version from the save before, as above.

**Never** undo more than they asked for.

## Restoring the Founder Brain

Before restoring `brain/founder-brain.md`, compare the `Track:` line of the version coming back with the current one. If they differ, say so plainly before the yes: "that version is on the B2B track, and you are on B2C now, so everything would switch back". After restoring, the Launchhouse checks and the session context follow the restored track.

## What history cannot bring back

`people/`, `engines/outreach/outreach-firstlines.csv` and `engines/audience/dm-openers.md` are kept out of git, so they have no earlier versions here. If one of those is lost, say so honestly. People can be found again in Apollo, or from the founder's own list.

## What a restore makes out of date

A restored file is a changed file, so anything built from it no longer matches. Check it against the table in `../../references/contract.md`, under "When one file changes, what goes stale". Name what is now out of date in plain words, and offer to rebuild it. Never rebuild it quietly, and never leave it unsaid. Bringing back `brain/founder-brain.md` is the widest: the content files, the track's engine 2 files, the operations workflow, the plan and the playbook insert were all built from it.

## Update my desktop folder / where are my files

Run `sh .claude/scripts/desktop-copy.sh < /dev/null`, then say where the folder is in plain words: a "My Launchhouse work" folder on their Desktop, holding copies of their finished work. Claude never copies files there by hand.

## Content approvals

If a restored file is `engines/content/content-30.md`, any piece whose words changed goes back to `draft` in `log/ledger.md`, because approval is of the words as they read. Say which.
