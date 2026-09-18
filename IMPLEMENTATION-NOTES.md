# Implementation notes: standalone system

Branch `standalone-system`. Nothing is committed. Checked on 17 September 2026.

## What changed

- Launchhouse now lives inside this folder, in `.claude/`. That means 19 skills, 14 commands, 4 agents, 4 references, 5 routines, 13 scripts, the rules file and the tests. Everything the plugin had is here, and nothing was dropped.
- The hooks moved from the plugin's `hooks.json` into `.claude/settings.json`. They now point at `$CLAUDE_PROJECT_DIR/.claude/scripts/`. All 5 of the plugin's hooks are there, plus 3 new ones: `refresh.sh` after every tool, `prompt-state.sh` on every message and `turn-end.sh` at the end of each turn.
- One script, `gate-state.sh`, now works out the gate state. It writes `growth-engine/.state/gate-state.md`, and the session line, the status and gate skills, the engine skills and the end of turn check all read that file.
- `park.sh`, together with `prompt-state.sh`, lets a founder say "park this" to stop the nudges for an engine.
- `rules.awk` now reads the heading or bold label above a message. A blank line no longer changes the result.
- Programme dates now live only in the cohort block in `.claude/references/gates.md`. `CLAUDE.md` no longer names the dates.
- `.gitignore` now also ignores `.state/gate-state.md` and `.state/nudges.md`.
- `README.md`, `START-HERE.md` and `CLAUDE.md` now say there is nothing to install.

## Results of the final check

1. **Standalone.** Nothing points at `CLAUDE_PLUGIN_ROOT` or a plugin cache, and every `.claude/` path the files mention exists. `settings.json` is valid JSON. All 15 shell scripts pass `sh -n`. I also ran the hooks by hand and got the expected results:
   - The write check refused a file name that is not a Launchhouse file.
   - The after-write check removed a draft that offered cold DM automation.
   - The Apollo send tool was refused.
   - The Apollo credit tool asked first.
2. **Tests.** `.claude/tests/run.sh` passed 6 of 6. `.claude/tests/state.sh` passed 16 of 16.
3. **Gate state on this folder** (`gate-state.sh --force`):

```
Track: not chosen yet
Engine in progress: brain
Paused: none

Gate A: 0 of 5 done
Gate B: 0 of 5 done
Gate C: 0 of 1 done

| A | brain-locked | The Brain is written and locked | not done | no Locked date in founder-brain.md | brain |
| A | track-chosen | A track is chosen | not done | no b2b or b2c on the Track line | brain |
| A | thesis | The thesis is written | not done | 0 characters under ## Thesis, 40 needed | brain |
| A | voice | The voice is captured | not done | 0 characters under ## Voice, 40 needed | brain |
| A | flags | The flags are answered honestly | ask | no answer recorded yet | brain |
| B | pieces | Thirty pieces are written | not done | 0 of 30 pieces in content-30.md | content |
| B | sheet | The posting sheet is written | not done | 0 of 30 rows in content-30.csv | content |
| B | refill | A source list for the refill exists | not done | rss-feeds.md is missing or nearly empty | content |
| B | approved | The pieces have been read and approved | not done | 0 of 30 approved in ledger.md | content |
| B | sounds-like | The pieces sound like the founder | ask | no answer recorded yet | content |
| C | track-first | Gate C cannot be checked yet | not done | no track chosen, so neither track's items are listed | brain |
```

   This is correct for an empty starter folder.

4. **Founder documents.** No document tells a founder to install a plugin or run a command. There are no em dashes or en dashes.
5. **Privacy.** `.gitignore` covers `people/` at any depth, `dm-openers.md` and `outreach-firstlines.csv`. As a test, I made a fake person file, an openers file and a first lines file. None of them showed in `git status --porcelain`. I then deleted all three.

## Issues this closes

- **#27 LH-028, standalone system:** partly closed. The folder now runs with no plugin. It is still open because the plugin is not built from this same source (see below).
- **#26 LH-027, one computed state and keeping the founder on track:** closed, subject to the hand check below. Points 1 to 7 are in place, and `state.sh` checks points 1, 3, 5 and 7.
- **#19 LH-020, index goes stale after a shell edit:** closed. `refresh.sh` runs after every tool, and the test "a shell change is picked up" passes.
- **#17 LH-018, the DM check depends on a blank line:** closed. The rule now reads the label above the message, and the three label test files pass.
- **#16 LH-017, hard-coded programme dates:** closed. All dates are in one cohort block, and a search found no programme dates left in the skills, routines or agents.

## Still open

- **#2 LH-001, a changed file shows as soon as the folder is opened:** not fixed.
  - `settings.json` still has its keys in the order the issue complains about: `extraKnownMarketplaces` first, and `defaultMode` before `allow`.
  - Also, the first hook run creates `growth-engine/.state/index.md`, which is not in the template, so a new file appears straight away. This file is meant to be in git (`.claude/references/state.md` line 142). Committing a starter copy with the template would stop it appearing.
- **Seven command names do not exist.** The skills and scripts offer `/growth-engine:start`, `status`, `save`, `gate`, `help`, `routines` and `add-files`, but there is no command file for any of them. A founder who types one gets nothing. The session line itself suggests `/growth-engine:start` (`.claude/scripts/state-block.sh` line 53).
  - The plugin had the same gap, so this change did not cause it.
  - The skills still respond to plain words, for example "start launchhouse".
  - To fix it, either add seven small command files or change the text to use plain words.
- **The plugin is not built from this folder.** LH-028 asks for the plugin to be built from this same source. There is no build step yet, so the plugin and this folder are two copies that can drift apart.
- **`settings.json` still names the old plugin's marketplace.** It lists `extraKnownMarketplaces` for `launchhouse-v3` and sets `growth-engine@launchhouse-v3` to false. The aim is to switch the old plugin off where it is installed. Even so, the founder's folder still refers to an outside marketplace.
- **The start skill's copy of `CLAUDE.md` is out of date.** The copy in `.claude/skills/start/references/scaffold.md` is missing the new "Where the system lives" section. It is only used when a folder has no `CLAUDE.md`.
- **Issues #3 to #15 and #18 to #25** were not part of this change.

## What a maintainer should check by hand

1. Open a fresh copy in the Claude desktop app on a Mac and on a Windows PC with Git for Windows. Confirm the session opens with the "Launchhouse founder folder" line, and that nothing asks to install or trust a marketplace.
2. Look at GitHub Desktop straight after opening. Note which files show as changed. This is LH-001.
3. Type `/growth-engine:` and confirm which commands appear.
4. With the old plugin also installed, confirm only one set of checks runs and that this folder's copy is the one in use.
5. Read each engine skill's opening check against the gate state. I confirmed every one mentions it, but I did not read the wording closely.
6. Say "park this" in the middle of an engine, then "pick it back up", and confirm the end of turn nudge stops and starts again.
