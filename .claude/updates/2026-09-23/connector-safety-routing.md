---
id: connector-safety-routing
title: One dispatcher for every connector tool call
purpose: Route every connector tool call through one dispatcher script, mcp-guard.sh, so a connector's write, send, or spend is always classified by that one hook, never by a per-connector script that can go missing or drift out of date.
touches:
  - .claude/settings.json
  - .claude/scripts/mcp-guard.sh
adds:
  - "one PreToolUse hook entry, matcher ^mcp__, running mcp-guard.sh"
requires: []
safety: true
done-when:
  - ".claude/settings.json is valid JSON"
  - "the PreToolUse hook list in .claude/settings.json has exactly one entry whose matcher is EXACTLY ^mcp__ (never a variant such as ^mcp__ghl), and its own command runs mcp-guard.sh"
  - "no hook command anywhere in .claude/settings.json names deny-mcp.sh or ask-mcp.sh"
  - "mcp-guard.sh exists at .claude/scripts/mcp-guard.sh"
check: connector-safety-routing.check.sh
founder-data: false
---

## What changed and why

Two retired scripts, `deny-mcp.sh` and `ask-mcp.sh`, were replaced by one
dispatcher, `mcp-guard.sh`, that classifies every connector call the same
way (deny, ask, guide, or silent) regardless of which tool it belongs to.
A founder's `.claude/settings.json` that still names either retired
script under `PreToolUse` is running a hook that points at a file which
no longer exists: the tool call is neither denied nor guided, it is just
never checked. That is a real hole in the six rules this project promises
founders, not a cosmetic drift, so this note is `safety: true` -- it
cannot be declined, and both its `done-when` statements are executable,
checked by `connector-safety-routing.check.sh` rather than judged by an
agent's prose reading of the resulting file.

## What a stock file looks like after

`.claude/settings.json`, inside `"hooks": { "PreToolUse": [ ... ] }`,
carries exactly one entry with `"matcher": "^mcp__"`, whose own `"hooks"`
array runs `mcp-guard.sh`:

```json
{
  "matcher": "^mcp__",
  "hooks": [
    {
      "type": "command",
      "command": "sh \"$CLAUDE_PROJECT_DIR/.claude/scripts/mcp-guard.sh\""
    }
  ]
}
```

No entry anywhere in the file names `deny-mcp.sh` or `ask-mcp.sh`.
`.claude/scripts/mcp-guard.sh` exists and sources `ghl-op.sh` as a
library for GoHighLevel's own connector shape; `ghl-op.sh` is never run
on its own and is never named directly in `settings.json`.

## Migration

None. This note changes `.claude/settings.json` and
`.claude/scripts/mcp-guard.sh` only, never `growth-engine/`.
