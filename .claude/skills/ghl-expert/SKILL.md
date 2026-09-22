---
name: ghl-expert
description: Answer a founder's question about GoHighLevel, or route a job that needs it to the right skill, or run one directly through the ghl-specialist agent. Trigger on "GoHighLevel", "HighLevel", "connect GoHighLevel", "how do I ... in GoHighLevel", "check my GoHighLevel", "post to GoHighLevel", "reply in GoHighLevel", "custom values", "my snapshot", or any GoHighLevel question this pack can answer.
---
<!-- Installed from .claude/skill-packs/ghl/skills/ghl-expert/SKILL.md. Edit the pack's copy, not this one; Launchhouse re-installs it. -->

# GoHighLevel expert

**Who is reading.** A founder who does not use a terminal. Never ask them to run a command.

## 1. Read first

Read `.claude/skill-packs/ghl/pack.md` and `.claude/skill-packs/ghl/references/knowledge.md` before answering anything or routing anywhere.

## 2. Check the connection

Look at the tools available. The account connector gives six tools (`list_locations`, `search_operations`, `describe_operation`, `execute_operation`, `search`, `fetch`); the fallback gives one tool per job, named in the pack's tool map. If neither is there, send the founder to `connect-tools` (`/growth-engine:connect`, or say "connect my tools") before doing anything else that needs GoHighLevel.

## 3. Route the founder's request

| Founder asks for | Go to |
|---|---|
| Connecting or checking the connection | `connect-tools` |
| Publishing, scheduling, or checking approved content | `publish-content` |
| How posts did | `publish-content` |
| Choosing a bottleneck, a snapshot, or writing operations copy | `ghl-workflows` |
| Filling in or pasting custom values | `ghl-values` |
| Writing or checking the Instagram inbound scripts that later become custom values | `audience-b2c` (its inbound-scripts step) |
| Replying to someone who wrote in, or a one-off read (one contact, one post, one stat) not covered by a job skill above | Call `ghl-specialist` directly, below |
| A plain "how does X work in GoHighLevel" question | Answer from `knowledge.md`, below |

## 4. The approval dance, for anything the specialist runs directly

1. Call `ghl-specialist` with `PHASE: plan` and the job.
2. Show the founder every proposed action exactly as the plan wrote it: the tool, the input, and the preview of what will go out or change, in their own timezone.
3. Wait for a clear yes. A yes covers exactly what was shown; if anything changes, show it again.
4. Grant it: `sh .claude/scripts/approve.sh --grant ghl <exact tool suffix>[:<count>] ...`, exactly the actions just shown and approved.
5. Call `ghl-specialist` with `PHASE: execute` and `APPROVED ACTIONS:` followed by the plan's actions verbatim.
6. Clear the grant: `sh .claude/scripts/approve.sh --clear ghl`.
7. Report back to the founder in plain words: what happened, and any evidence (an id, a read-back).

Never skip the plan phase, even for something that feels small. Never show the founder raw tool JSON; translate it into the plain words the pack's `publish-content` and `connect-tools` skills already use. A read never needs a grant. If `approve.sh` refuses the grant, or the specialist reports a call was denied, that is the answer: say so plainly and do not try again with different wording.

## 5. Record connection state

After proving or changing a connection, write or update the row in `growth-engine/.state/tools.md`:

| tool | name | status | route | date | evidence |
|---|---|---|---|---|---|
| ghl | GoHighLevel | connected | <the job it was proven for> | <date> | <what the tool actually returned> |

`status` is one of `planned`, `connected`, `verified`, `dropped`. Evidence is only ever what a tool returned, or "founder planned it" for `planned`. This is separate from `growth-engine/.state/setup.md`, which `connect-tools` owns in full; this row is this pack's own short record.

## 6. Answering "how does X work" questions

Answer from `knowledge.md`'s Mental model, Tool map, Limits and quotas, and Failure modes sections. Say plainly that this pack was last checked on `verified_on` in `pack.md`, and that GoHighLevel's own docs can move past that date; offer to refresh the pack (re-run its Refreshing steps) if the founder's own account behaves differently from what is written here.

**Never guess at an operation id or a limit this file does not carry.** If the founder's question needs something the pack does not know, say so plainly, and either look it up (search GoHighLevel's own current docs) or send them to the Slack channel, rather than inventing an answer that sounds right.

## In Cowork

No Launchhouse hooks run there. The only guard left is the founder's own connector setting: `execute_operation` must stay **Needs approval** in Settings, then Connectors. Say this plainly whenever GoHighLevel work starts in Cowork, and confirm the setting is still right when the founder says "check my connections" from there.
