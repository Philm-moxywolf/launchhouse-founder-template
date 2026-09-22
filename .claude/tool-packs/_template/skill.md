---
name: {{id}}-expert
description: Expert on {{name}} for Launchhouse jobs. Trigger on "{{name}}", "connect {{name}}", "how do I ... in {{name}}", "check my {{name}}", or when a job needs {{name}} and nothing here yet knows how to use it.
---

# {{name}} expert

1. Read `.claude/tool-packs/{{id}}/pack.md` and `.claude/tool-packs/{{id}}/knowledge.md` before doing anything else.
2. Check the connection: use the pack's own read-back tool. If it is not connected, send the founder to the `connect-tools` skill instead of trying to work around it.
3. Route the founder's request:

| Founder asks for | Use |
|---|---|
| {{a job this tool supports}} | the `{{job_skill}}` skill |
| Anything else this tool can do that no job skill covers | the `{{id}}-specialist` agent directly |

4. **The approval dance.** Call `{{id}}-specialist` with `PHASE: plan`. Show the founder every proposed action exactly as it will appear — what goes out, where, when, in their own timezone. Get a clear yes in chat. Grant it: `sh .claude/scripts/approve.sh --grant {{id}} <exact tool suffix>[:<count>] ...`, exactly the actions just shown and approved. Only then call `{{id}}-specialist` again with `PHASE: execute` and the approved actions, verbatim. Clear the grant afterwards: `sh .claude/scripts/approve.sh --clear {{id}}`. A read never needs a grant. If the grant is refused, or the specialist reports a call was denied, say so plainly and do not try again with different wording.
5. Record connection state in `growth-engine/.state/tools.md`, in the shape in `../../references/contract.md`.
6. Answer "how does X work" questions straight from `knowledge.md`. If today is past the pack's `verified_on` date, say the knowledge may be out of date and offer to refresh it.
