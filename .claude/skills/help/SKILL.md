---
name: help
description: Answer a founder's question about how Launchhouse works, check they are set up properly, and diagnose a problem. Checks the folder, the skills, git, the connections and the time-critical items, and knows the common problems. Trigger on "help", "check my setup", "am I set up right", "something is broken", "is this working", "doctor", "which folder should I use", "cowork or claude code", "update launchhouse", or whenever another skill reports it cannot find the Founder Brain.
---

# Help

The founder's first stop when something is not working, or they are not sure what to do next.

Be plain and unhurried. Many founders on this programme are not technical and will already feel behind. Never ask them to run a command. Run what needs running yourself, and say what you found.

## Two ways in

- **They asked for help.** Work out what they are trying to do, answer it, and point them at the one thing to do next.
- **Something is broken.** Start by asking what is happening, in their own words. Then run only the checks most likely to be relevant, rather than all of them in order.

**Two tries at most.** If two attempts do not resolve it, stop and tell them to post in the Slack channel, saying what they were doing and what they saw. Someone will sort it individually. A founder stuck alone for an hour is worse than a founder who asked for help after ten minutes.

## The checks

### The folder's own setup check

"Check my setup" means run this in full, not just read the top of the conversation.

Run `sh .claude/scripts/setup-check.sh --full < /dev/null`. It checks git is installed, this is a git folder with a name and email set for saving, the origin is not the public Launchhouse original, `.claude/settings.json` has the Launchhouse checks and the Launchhouse Guide voice switched on and the old plugin switched off, and the growth-engine scaffold is in place. It prints one plain line per problem it finds, or says there is nothing wrong. Read each line out in your own plain words, and offer to fix it (most of these are exactly what `/growth-engine:start` fixes). It also names, once, what to check with ToolSearch for GoHighLevel, and for Apollo and a mailbox if the founder is B2B: do that and say what you find.

**If Bash is not available, as it can be in Cowork,** run the same checks by hand instead: read `.git/config` for `[user]` name and email and for `remote "origin"`'s url (never Philm-moxywolf), read `.claude/settings.json` for `"hooks"`, `"outputStyle": "Launchhouse Guide"` and `"growth-engine@launchhouse-v3": false`, and check `growth-engine/.launchhouse` and `growth-engine/log/ledger.md` exist. Say the same things in the same plain words.

### 1. The folder

This is the single most common problem.

**Read the session context at the top of the conversation.**
- If it says this is not the founder folder, tell them which folder to open, and that nothing is lost.
- If it says nothing about Launchhouse, look for `growth-engine/.launchhouse` in this folder, one folder down, the parent folder, and the home folder.

**If you find more than one Launchhouse folder** (the session context names them):
1. Show each location and what it contains, from its `growth-engine/.state/index.md`.
2. Help them decide which is the real one.
3. Do not merge them and do not delete anything. Tell them to move the others aside.

**If there is none,** the folder is not set up. Offer `/growth-engine:start`.

### 2. The skills and the checks

If this skill is running, the Launchhouse system in this folder is loaded. Say so plainly, because founders often assume something is broken when it is not. Nothing has to be installed: the skills, the checks and the routines are files in the `.claude` folder here.

The Launchhouse checks run separately. If this folder has `growth-engine/.launchhouse` and the top of the conversation has no line starting "Launchhouse", they are not running on this computer. In a folder that is not set up yet, no such line is expected: offer `/growth-engine:start` instead. When the checks are not running, run `git --version`. On a Windows PC, if that fails, the computer needs Git for Windows: git-scm.com, Download for Windows, press Next on every screen, then quit and reopen the Claude app. On a Mac, quit and reopen the app.

### 3. Saving

1. Run `git status --short` and `git log -1 --format="%cd %s"`.
2. Say when their work was last saved.
3. If there are unsaved changes, offer to save them (`/growth-engine:save`).
4. If `git remote -v` shows nothing, their work is saved on this computer only. Say so without alarm. A mentor can connect it to GitHub.

### 4. Connections

Read `growth-engine/.state/setup.md`.
- If GoHighLevel or Apollo is not done, and they are trying to publish or build a sequence, send them to `/growth-engine:connect`.
- Apollo is B2B only. A B2C founder not seeing Apollo is correct.
- GoHighLevel connects two ways: a connector, signed in from Settings, then Connectors, and this folder's own fallback, for Code only, when sign-in does not work. If a founder's connector setting lets sending and posting through without asking, that is on them to fix, because in Cowork none of this folder's checks run: `/growth-engine:connect` sets it, and "check my connections" checks it again.

### 5. Progress

Hand off to `/growth-engine:status` rather than duplicating it here.

### 6. Time-critical items

Read the Flags section of `growth-engine/brain/founder-brain.md` if it exists.
- **B2B:** is the sending domain sorted, with SPF, DKIM and DMARC configured? If the Brain flags a fresh domain and nothing has happened, raise it now.
- **B2C:** is Instagram converted to Business or Creator and linked to a Facebook Page? Nothing publishes or captures inbound without it.

Raise these even if the founder asked about something else. They are the two items that quietly break the weekend.

## Their Desktop folder

Finished work also appears as read-only copies in a "My Launchhouse work" folder on their Desktop, updated each time they save in Claude. It is for finding files, not for working in: changes happen in their real folder, in Claude, never in the Desktop one.

## Where they work

**Claude Code, in the desktop app,** opened on their Launchhouse folder. This is where the engines run: interviews, writing, publishing, sequences.

**Cowork, on the same folder.** Good for dropping in documents and photos, reading and summarising, and thinking things through. Anything saved into `growth-engine/` is seen by both. If Cowork does not seem to know about Launchhouse, check it is open on this same folder.

If they are unsure, tell them to use the Code tab for the engines. Nothing in this programme needs a terminal.

## Updating Launchhouse

Updates are not automatic. The system is the `.claude` folder in this repository, so an update is a normal update of the folder.

1. In GitHub Desktop, fetch and pull the folder.
2. Quit and reopen the Claude app so the new files load.

Updating never touches the founder's `growth-engine/` folder. Their work lives there, apart from the system. Say this if they hesitate.

If a founder reports behaviour that does not match what they were told in a session, updating the folder is the first thing to try. The same goes for a command they were told about that their app does not offer, such as `/growth-engine:values`: it arrived later, so update the folder, then quit and reopen the app.

## Common problems

**"The commands are not there."** If this skill is running, the system is loaded in this folder, so the usual cause is the prefix: every command starts with `/growth-engine:`, for example `/growth-engine:status`, and plain language works too. If they mean a different folder, the system only works in the Launchhouse folder, because it lives in that folder's `.claude`: open the Launchhouse folder. If it still does not show, quit and reopen the app.

**"It asked me about my business again."** They are in the wrong folder. Run check 1. Their Brain is almost certainly intact somewhere else.

**"It gave me LinkedIn posts and I sell to consumers."** The Track line in their Brain is wrong.
1. Tell them to say "change my track", which reopens the Founder Brain on that one line.
2. Then regenerate the content.

Do not edit the Track line yourself outside that flow.

**"My files disappeared."** Almost never true.
1. Run check 1.
2. Then run `git log --oneline -10 -- growth-engine`, which shows every save.
3. Any earlier version of a saved file can be brought back with `/growth-engine:save`. `people/`, `engines/outreach/outreach-firstlines.csv` and `engines/audience/dm-openers.md` are kept out of git on purpose, so those have no history.

**"It said a file was held."** The Launchhouse checks found a line that offers to automate cold DMs, promises replies, or uses the other track's material. The file was put back as it was, so nothing is lost. The message names the line, and the line gets rewritten.

**"It said a figure was worth a look."** The rules reviewer checks every figure against what the founder has told it. If the figure is real, it goes in the Proof section of the Founder Brain first. Otherwise the line gets rewritten.

It is a backstop, not a guarantee. They still read their own work before it goes out.

**"It will not let me automate Instagram DMs."** Correct behaviour, not a bug. Instagram only opens a reply window once somebody has written to you first, and the accounts that get round that are the ones that get restricted. Say that plainly, then take them to the inbound side and build it with them (`/growth-engine:audience`).

**"It will not send my Apollo sequence."** Also correct. Sequences are built paused, and starting one is a button the founder presses in Apollo, having read it.

**"It is asking permission for everything."** Their folder's settings let Claude save work without asking. If they opened a folder that is not their copy of the Launchhouse repository, the settings are missing. `/growth-engine:start` creates them when they are missing. Some things always ask, on purpose: publishing, spending Apollo credits, and adding people to a sequence.

**"My Desktop folder is out of date."** It shows the last save. Unsaved changes, or changes made only in Cowork, appear there after the next save in Claude.

**"It's connected but no tools appear."** Disconnect and connect again, from inside a chat: open Settings, then Connectors, disconnect **HighLevel**, then connect it again the way `/growth-engine:connect` sets out. Starting a new conversation afterwards often clears it on its own.

**"Windows won't keep the connection."** Some Windows setups lose the connector's sign-in between sessions. Use the fallback instead: it is Code only, and `/growth-engine:connect` walks through it under "If signing in does not work on this computer."

**"I cannot get any of this working."** Do not keep troubleshooting past two failed attempts. Send them to the Slack channel.

## Before you finish

End by naming one thing to do next, and the words that start it. Then name the plain way to check where they stand, "where am I up to", so they know it is there. If something else fits better than that, name that instead: "save my work", "add a file", or "set up my routines". One, once, in plain words.

## What this skill does not do

It does not change any founder content. It diagnoses and repairs setup only.
