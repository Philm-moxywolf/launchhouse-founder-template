# {{name}} — knowledge

## Mental model

{{How the tool thinks: its objects, their ids, their states, described in the founder's own business terms rather than the vendor's engineering terms.}}

## Connecting and auth

{{Connector name, how sign-in works, the scopes it asks for, any fallback route, and what breaks when the connection is wrong (expired token, wrong account, missing scope).}}

## Tool map

| tool | class | what it does | inputs that matter | gotchas |
|---|---|---|---|---|
| `{{tool_suffix}}` | read | {{what it does}} | {{inputs}} | {{gotchas}} |

## Workflows for Launchhouse jobs

### {{job_1}}

{{Step by step: which tools, in what order, where the founder's yes is needed, and what gets written to growth-engine/.}}

## Limits and quotas

{{Rate limits, credits, daily caps, plan differences. Each line sourced. Mark anything not checked (unverified).}}

## Failure modes and fixes

| Symptom | Cause | Fix |
|---|---|---|
| {{symptom}} | {{cause}} | {{fix}} |

## Rules that apply here

{{How the six rules in the root CLAUDE.md bind this tool specifically. Link ../../../references/connections.md for the shared rules rather than restating them here.}}

## Sources

- {{title}}: {{https URL}} (checked {{YYYY-MM-DD}})

## Refreshing this pack

Re-run ToolSearch to confirm the inventory still matches what is connected. Re-check every source above still resolves and still says what this file claims. Run `sh .claude/scripts/skill-packs.sh --validate {{id}}` and `sh .claude/scripts/skill-packs.sh --test {{id}}`. Update `verified_on` in `pack.md` once done.
