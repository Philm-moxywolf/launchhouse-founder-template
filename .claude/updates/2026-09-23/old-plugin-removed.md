---
id: old-plugin-removed
title: The old growth-engine plugin is gone
purpose: No founder ever installed the old growth-engine marketplace plugin, so every mention of switching it off, checking for it, or working around it is removed from guidance and from the functional switch-off in settings.json, so Claude never tells a founder to install something that does not exist.
touches:
  - .claude/settings.json
  - .claude/scripts/setup-check.sh
  - .claude/scripts/lib.sh
  - .claude/tests/state.sh
  - CLAUDE.md
  - .claude/README.md
  - .claude/skills/help/SKILL.md
  - .claude/skills/start/references/scaffold.md
  - .claude/updates/2026-09-23/settings-read-by-content.md
  - .claude/updates/2026-09-23/settings-read-by-content.check.sh
adds: []
requires: []
safety: false
done-when:
  - "settings.json names no growth-engine plugin"
  - "CLAUDE.md does not mention an old growth-engine plugin to switch off"
  - "setup-check.sh no longer checks for a disabled growth-engine plugin"
check: old-plugin-removed.check.sh
founder-data: false
---

## What changed and why

A founder's Claude told her that her checklist said to install the
Launchhouse plugin. No founder ever installed the old `growth-engine`
marketplace plugin: Launchhouse has always shipped as this folder's own
`.claude/`, with nothing to add from a marketplace. The `enabledPlugins`
switch-off, the setup-check for it, and every mention in guidance were
leftover scaffolding for a plugin nobody has, and telling a founder about
it only raises a question ("do I need to install something?") that has no
good answer.

`.claude/settings.json` no longer carries `enabledPlugins` at all (it was
its only entry). `setup-check.sh` no longer checks for the disabled
plugin flag, and its problem message names only the checks and voice it
still verifies. `CLAUDE.md`, `.claude/README.md`,
`.claude/skills/help/SKILL.md` and the embedded `CLAUDE.md` copy in
`start/references/scaffold.md` drop every sentence about the old plugin.
`lib.sh`'s comment calling the hooks "the plugin" now names Launchhouse
instead. The `settings-read-by-content` improvement note and its check
script, which quoted the old plugin flag as their worked example, now use
a plugin-free example. `.claude/tests/state.sh`'s LH-028 check is updated
to confirm settings.json names no plugin and CLAUDE.md does not describe
one to switch off, rather than confirming the old switch-off is present.

Every other safety check (the connector-safety routing, the six rules,
the tool checks) is unaffected: this improvement only removes guidance and
a settings.json entry for a plugin that was never installed.

## What a stock file looks like after

`.claude/settings.json`, no `enabledPlugins` key at all:

```json
  "outputStyle": "Launchhouse Guide",
  "enabledMcpjsonServers": ["highlevel"],
  "hooks": {
```

`CLAUDE.md`, "Where the system lives":

> This folder carries Launchhouse itself, in `.claude/`: the skills, the
> agents, the checks that run on every write, the references they read
> and the routines. Nothing is installed from a marketplace, so there is
> never anything to add or update beyond this folder.
