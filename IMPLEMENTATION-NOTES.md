# Implementation notes: standalone system

Branch `standalone-system`. The standalone change is committed (`bdadb23`). The wave A changes below are not committed yet. Checked on 17 September 2026.

## What changed in the standalone change

- Launchhouse now lives inside this folder, in `.claude/`. That means 19 skills, 21 commands, 4 agents, 5 references, 5 routines, 13 scripts, the rules file and the tests. Nothing the plugin had was dropped.
- The hooks moved from the plugin's `hooks.json` into `.claude/settings.json`. They now point at `$CLAUDE_PROJECT_DIR/.claude/scripts/`. All 5 of the plugin's hooks are there, plus 3 new ones: `refresh.sh` after every tool, `prompt-state.sh` on every message and `turn-end.sh` at the end of each turn.
- One script, `gate-state.sh`, works out the gate state. It writes `growth-engine/.state/gate-state.md`, and the session line, the status and gate skills, the engine skills and the end of turn check all read that file.
- `park.sh`, together with `prompt-state.sh`, lets a founder say "park this" to stop the nudges for an engine.
- `rules.awk` reads the heading or bold label above a message. A blank line no longer changes the result.
- Programme dates live only in the cohort block in `.claude/references/gates.md`.
- `.gitignore` also ignores `.state/gate-state.md` and `.state/nudges.md`.
- `README.md`, `START-HERE.md` and `CLAUDE.md` say there is nothing to install.

## What changed in wave A

- **How Claude talks (#31).** New output style `.claude/output-styles/launchhouse-guide.md`, selected for every founder with `"outputStyle": "Launchhouse Guide"` in `settings.json`. `CLAUDE.md` and the start skill's copy of it now point at the style, keep a one line fallback for Cowork, and tell helpers to report back in a few lines.
- **The public original (#3).** A push to any remote under `Philm-moxywolf` is refused by the write check (`guard-pre.sh`, `lh_push_to_original` in `lib.sh`), including a push at the end of a save. The start skill and `CLAUDE.md` say the same in plain words. `README.md` tells the founder Claude never sends their work there.
- **Starting (#4, #5, #6).** The start skill asks its questions as clickable choices, all in one go, with plain text where choices cannot be shown. The name is offered from git. The timezone is asked by its everyday name and two cities; the full name goes only in the saved file. The earlier work question is asked in the same go. A founder starting fresh goes straight into the Founder Brain, with no second question. `START-HERE.md` says so.
- **The track rule (#8).** Rule 1 in `CLAUDE.md` now says the track is set once, in the Founder Brain intake, and never asked again anywhere else.
- **Model (#7).** When neither service nor ecommerce fits, the Brain records the nearer one plus a Flag. The ops pack choice (`ghl-workflows`) goes by the bottleneck when that Flag is there. `contract.md` says the same.
- **More than one founder (#12).** The Brain's `Team` line records who runs which part of the selling. The consumer engine says it builds for the whole team, names who runs the customer voice, and keeps the 25 DMs by hand from that person's account.
- **Claims the founder must confirm (#13).** The rules reviewer holds any line about what the product does with data (`claim.data`) or who built it when there is more than one founder (`claim.credit`). The Brain and content engine ask the founder, never rewrite on a guess, and record a confirmed claim under `## Proof`.
- **Ways past the write checks (#28).** A folder written in the wrong case, such as `Growth-Engine/`, is refused. `uploads/` and `voice-samples/` are checked for the sending rules, and a problem is raised with Claude, not removed. Shell commands (`cp`, `mv`, redirects) are now checked before and after they run. Every Apollo tool now asks first, except a named list of tools that only read. Sending and buying stay refused.
- **Word rules (#29).** The promise check catches "replies are guaranteed", "we guarantee you a reply" and "a reply is promised". "No problem" no longer counts as a negation: the negation must be at most three words before the term. "Connect with me on LinkedIn" is no longer held on the consumer track. Fixtures cover each, both ways.
- **The founder's own lines (#30).** `guard-post.sh` holds only lines that are new or changed. An old line that breaks a rule is left alone, raised once, and left for the founder to decide.
- **The playbook insert (#22).** The insert is stamped with the date, the git version and the files it was built from. Before it is handed over, the skill checks those files and says plainly which have changed, then offers to rebuild. A printable `playbook-insert.html` sits beside it, so the founder's own browser makes the PDF on a Mac or a Windows PC. The skill counts the PDF's pages and says plainly when it runs over six.
- **Connections (#24, #25).** New `.claude/references/connections.md` names each connector exactly as it appears in the Claude app, handles both shapes of GoHighLevel's tools, and says no key is ever pasted or saved. `connect-tools` adds the mailbox for B2B founders: Gmail or Microsoft 365, chosen from the Brain, proved by reading back the sending address, and recorded in `.state/setup.md`. `publish-content` can put the 25 outreach emails into the founder's Gmail drafts after a yes. The mailbox's send, reply and forward tools are refused, and writing a draft asks first.

## Results of the final check for wave A

1. **Tests.** `.claude/tests/run.sh` passed 87 of 87. `.claude/tests/state.sh` passed 46 of 46. Both exit 0.
2. **Syntax.** All 13 scripts in `.claude/scripts/` and both test scripts pass `sh -n`. `settings.json` is valid JSON. The output style file exists, has `name`, `description` and `keep-coding-instructions: true`, and `settings.json` selects it by that name.
3. **Secrets and privacy.** A search of every tracked and untracked file found no token, key or secret. `git status --porcelain` shows nothing under `people/`, `dm-openers` or `firstlines`.

## Where each wave A issue stands

- **#31 LH-032, output style:** closed, subject to hand check 7.
- **#3 LH-003, the public original:** closed.
- **#5 LH-005, timezone city:** closed.
- **#6 LH-006, straight into the Founder Brain:** closed.
- **#7 LH-007, Model for a subscription app:** closed.
- **#12 LH-013, more than one founder:** closed.
- **#13 LH-014, product and privacy claims:** closed. The reviewer is a model, so this rests on hand check 8.
- **#28 LH-029, four ways past the write checks:** closed.
- **#30 LH-031, the founder's own lines:** closed.
- **#22 LH-023, the playbook insert:** closed, subject to hand check 9. One choice differs from the issue: when the insert is out of date and the founder says no to a rebuild, it is still handed over, with a sentence naming the changed files, rather than refused.
- **#4 LH-004, clickable choices:** partly done. The start skill uses them. The Founder Brain intake still asks its predictable questions, the track fork and Model, as plain text.
- **#8 LH-008, rule 1 against the track fork:** partly done. Rule 1 is reworded. The intake's Group 2 still asks the track afresh, instead of confirming what the founder already said about who pays them in Group 1.
- **#29 LH-030, word rules:** partly done. Left: "we guarantee it", with no reply word, still passes the word rules. Invented proof such as "412 clients, 312 percent growth" still has no word rule and rests on the reviewer alone, and there is no fixture for it.
- **#24 LH-025, tools not shipped:** partly done. Each connector is named exactly and set out in one place, but nothing is shipped ready to connect. A founder still goes to Settings, Connectors, and a founder with no HighLevel in that list still meets GoHighLevel's developer guide. A server definition was left out on purpose: an unproven address would ask for approval the first time the folder opens (test "no unproven HighLevel server address is shipped").
- **#25 LH-026, the mailbox:** partly done. Left: replies are not checked or recorded against the person's file, and on Microsoft 365 there is no draft tool, so the 25 still go by hand. The Microsoft 365 tool name used to spot the connection (`outlook_email_search`) has not been seen on a real account.

## Still open

- **#2 LH-001, a changed file shows as soon as the folder is opened:** not confirmed fixed.
  - `growth-engine/.state/index.md` is now in git, and running the hooks and both test suites left it unchanged.
  - `settings.json` already has its keys in the order the issue says the app writes. Wave A added `outputStyle`, and nobody has yet seen where the app puts that key. Hand check 2 settles it.
- **#27 LH-028, standalone system:** partly done. The plugin is not built from this folder. There is no build step, so the plugin and this folder are two copies that can drift apart.
- **`settings.json` still names the old plugin's marketplace.** It lists `extraKnownMarketplaces` for `launchhouse-v3` and sets `growth-engine@launchhouse-v3` to false, to switch the old plugin off where it is installed. The founder's folder still refers to an outside marketplace.
- **The rest of wave A:** #4, #8, #24, #25 and #29, as above.
- **Not yet worked on:** #9, #10, #11, #14, #15, #18, #20, #21 and #23.
- **Marked closed by the standalone change, still open on GitHub:** #16, #17, #19 and #26. #26 rests on hand check 6.

## What a maintainer should check by hand

1. Open a fresh copy in the Claude desktop app on a Mac and on a Windows PC with Git for Windows. Confirm the session opens with the "Launchhouse founder folder" line, and that nothing asks to install or trust a marketplace.
2. Look at GitHub Desktop straight after opening. Note which files show as changed, and whether the app moved `outputStyle` in `settings.json`. This is LH-001.
3. Type `/growth-engine:` and confirm all 21 commands appear.
4. With the old plugin also installed, confirm only one set of checks runs and that this folder's copy is the one in use.
5. Read each engine skill's opening check against the gate state. Each one mentions it, but the wording was not read closely.
6. Say "park this" in the middle of an engine, then "pick it back up", and confirm the end of turn nudge stops and starts again.
7. Restart the session and run `/output-style`. Confirm Launchhouse Guide is listed and selected, and that replies change. Try `keep-coding-instructions` both true and false, confirm saving still works, and keep whichever works. Check whether Cowork honours the style.
8. Write a piece that says "no personal text leaves the device", and one where a co-founder says "as the one building this". Confirm the reviewer holds both and the founder is asked.
9. Build the playbook insert, open `playbook-insert.html` and save it as a PDF, on a Mac and on a Windows PC. Confirm the page count check reads it, and that changing a source file marks the insert out of date.
10. Say "start launchhouse" in a fresh copy. Confirm the questions appear as clickable choices, the timezone is named the everyday way, and a founder starting fresh goes straight into the Founder Brain.
11. With Gmail connected on a B2B test folder, say "put my outreach emails in my drafts". Confirm only drafts are written, after a yes, and that asking Claude to send one is refused. Connect Microsoft 365 once and note the real tool names.
