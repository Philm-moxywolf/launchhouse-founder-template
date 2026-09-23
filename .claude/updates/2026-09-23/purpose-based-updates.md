---
id: purpose-based-updates
title: Updates land improvement by improvement
purpose: Updates now arrive improvement by improvement, each with its own note; files a founder never changed take the new version, files they changed are adapted by Claude to bring the improvement in while keeping their own changes, and the founder approves each improvement in plain words.
touches:
  - .claude/scripts/update.sh
  - .claude/scripts/updates-lint.sh
  - .claude/scripts/json-valid.sh
  - .claude/skills/launchhouse-update/SKILL.md
  - .claude/agents/update-adapter.md
  - .claude/agents/update-reviewer.md
  - .claude/skills/start/references/scaffold.md
adds:
  - "the update-adapter agent"
  - "the --adapt-save command"
  - "the --restore-settings-plan command"
  - "the --restore-settings-decline command"
requires: []
safety: false
done-when:
  - "update.sh supports --adapt-save"
  - "update.sh supports --restore-settings-plan"
  - ".claude/agents/update-adapter.md exists and lists only the tools Read, Grep, Glob"
  - "updates-lint.sh passes on this tree"
check: purpose-based-updates.check.sh
founder-data: false
---

## What changed and why

Before this, an update was one all-or-nothing bundle: a founder either took
every change in a release or held the whole thing back, and a file they had
customized was simply skipped, with no way to bring in a fix that landed
inside it without losing their own wording. That left safety fixes stranded
in a founder's own edited copy of `.claude/settings.json` or a skill file,
because taking the fix meant discarding their changes and holding it meant
staying unpatched.

This improvement breaks a release into individual improvement notes, one per
purpose, each with its own `touches`, `done-when` and `check`. `update.sh
--plan` now sorts every touched path into two kinds: a file the founder never
changed takes the new upstream version outright, and a file they did change
is held for a per-path decision. For a held path, the `update-adapter` agent
(read-only: Read, Grep, Glob, nothing that can write) is given the base
copy, the founder's own copy, and the new copy, plus only the notes the
founder has already approved for that path, and returns a complete adapted
file that brings the purpose in while keeping everything else the founder
added. `update.sh --adapt-save` validates and stores that adapted body
(refusing anything that is not valid JSON when the path is a `.json` file,
and refusing to widen a permission or drop a hook in `.claude/settings.json`)
so the `launchhouse-update` skill can offer it to the founder as its own
small, named step, never silently applied.

A safety note can still never be declined, but when a safety fix lands
inside a file the founder customized and the founder's most recent past
update had to take their settings file as upstream stood then (because the
adaptation could not yet be offered), `update.sh --restore-settings-plan`
finds what the founder changed since and offers it back as its own small
update -- applied on top of every improvement since, never overwriting them.
`--restore-settings-decline` records that the founder said no to that
restore, so it is asked once, not forever.

`updates-lint.sh` and `json-valid.sh` are the schema and JSON-syntax checks
the whole notes system leans on: every note under `.claude/updates/*/*.md`
is checked for its required frontmatter, and any check script that needs to
judge `.claude/settings.json` by what it actually says (never how it happens
to be formatted) parses it with a real recursive-descent JSON parser rather
than counting braces. `.claude/skills/launchhouse-update/SKILL.md` is the
walkthrough that ties all of this together for a founder-facing update run,
and `.claude/skills/start/references/scaffold.md` is where a new founder's
`CLAUDE.md` picks up the one line that says an update always uses the
newest updater from the verified Launchhouse original.

## What a stock file looks like after

`.claude/scripts/update.sh`'s own usage line lists every subcommand this
improvement adds:

```
--status | --detect-base | --set-base <sha> | --plan |
--adapt-save <path> <body-file> <note-ids> | --restore-settings-plan |
--restore-settings-decline |
--apply <decisions.tsv> [--allow-no-checks] | --undo
```

`.claude/agents/update-adapter.md` opens with frontmatter that lists only
read-only tools:

```yaml
---
name: update-adapter
description: '...'
tools: Read, Grep, Glob
model: sonnet
---
```

and its body never writes a file itself -- it returns the adapted body in
its reply for the calling skill to save through `--adapt-save`.

`.claude/skills/launchhouse-update/SKILL.md` dispatches `update-adapter` for
each held path, saves what it returns with `--adapt-save`, then always runs
`update.sh --restore-settings-plan` after a safety note has had to take a
founder's settings file, offering back what they had changed since as its
own small update, with `--restore-settings-decline` as the one-time "no" for
that offer.
