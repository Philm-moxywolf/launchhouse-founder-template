---
id: agents-md-guidance
title: AGENTS.md tells any agent how to update
purpose: Any AI agent that opens a Launchhouse folder finds AGENTS.md, which tells it to update the folder with the newest updater from the verified Launchhouse original, never from any other address.
touches:
  - AGENTS.md
  - README.md
  - CLAUDE.md
adds: []
requires: []
safety: false
done-when:
  - "AGENTS.md exists at the root and names the upstream trust check and the bootstrap folder"
  - "README.md and CLAUDE.md both mention AGENTS.md"
check: agents-md-guidance.check.sh
founder-data: false
---

## What changed and why

Launchhouse folders are opened by more than one AI coding assistant: a
founder's own `CLAUDE.md` only ever loads inside Claude, so an agent from a
different tool that opens the same folder had no file telling it how this
project wants an update carried out, and could end up fetching an updater
from an unverified address, or running an older bootstrap step than the one
upstream currently ships.

`AGENTS.md`, at the repo root, is the file any AI agent -- Claude, Codex,
Cursor, Gemini, or anything else -- reads first when it opens a Launchhouse
folder, by the convention those tools already share. It restates the
essentials of `CLAUDE.md`'s six rules and founder-facing manner in brief,
says plainly that `CLAUDE.md` wins on any conflict, and then walks through
updating: verify the upstream remote's fetch URL against the address
recorded in `.claude/launchhouse-upstream` (or the public default) before
fetching or running anything, add and fetch the `upstream` remote, bootstrap
the newest `update.sh` and `lib.sh` into `<gitdir>/launchhouse/bootstrap/`
regardless of whether an older copy already exists locally, read and follow
upstream's own `SKILL.md` rather than a possibly-stale local copy, fall back
to reading `update-adapter` or `update-reviewer` straight from upstream (with
read-only tools only) if either agent file is missing locally, and run
`--plan`/`--apply` with a ten-minute timeout. `README.md` and `CLAUDE.md`
each point to `AGENTS.md` so a person or an agent reading either one finds
it.

## What a stock file looks like after

`README.md`, near the top:

> *An AI agent opening this repository reads [AGENTS.md](AGENTS.md) first.*

`CLAUDE.md`, in its "Where the system lives" section, on updates:

> An update always uses the newest updater and instructions from the
> verified Launchhouse original, never this folder's own older copy; the
> steps any agent follows for that are in `AGENTS.md` at the repo root.

`AGENTS.md` itself opens with `# AGENTS.md`, says CLAUDE.md holds the rules
and wins on conflict, and its "Updating a Launchhouse folder" section names
both the upstream trust check (comparing the `upstream` remote's fetch URL,
or `.claude/launchhouse-upstream` from the committed HEAD tree, against the
public default) and the bootstrap folder, `<gitdir>/launchhouse/bootstrap/`.
