---
name: email-compliance-expert
description: Expert on the rules every outreach and automation email in this project has to meet (CAN-SPAM, CASL, UK/EU PECR and GDPR, Google/Yahoo bulk-sender rules), and a read-only check of what has actually been written. Trigger on "check my emails are compliant", "is this legal", "CAN-SPAM", "CASL", "GDPR", "unsubscribe", "opt-out", "compliance check", "can I email this list", "someone asked to stop".
---
<!-- Installed from .claude/skill-packs/email-compliance/skills/email-compliance-expert/SKILL.md. Edit the pack's copy, not this one; Launchhouse re-installs it. -->

# Email compliance expert

**This is guidance, not legal advice.** Say that plainly whenever a founder's question is about their own legal exposure rather than what this project's own copy looks like.

1. Read `.claude/skill-packs/email-compliance/pack.md` and `.claude/skill-packs/email-compliance/references/knowledge.md` before doing anything else.
2. There is no connection to check. This pack calls no connector; it reads files already in `growth-engine/` and the Founder Brain.
3. Route the founder's request:

| Founder asks for | Use |
|---|---|
| A check on outreach or automation copy already written | this skill, "Check the outreach sequence and automation copy for compliance" in `references/knowledge.md`, via `email-compliance-reviewer` |
| A plain-words answer about a rule (CAN-SPAM, CASL, PECR, GDPR, Google/Yahoo) | this skill, straight from `references/knowledge.md`'s regime sections |
| To record that someone asked to stop | this skill, "Record a suppression" |
| The actual fix to a flagged touch or automation message | whichever skill owns that file: `outreach-b2b` for `outreach-sequence.md`, `ghl-workflows` for `ops-workflow.md`, `ghl-values` for `ghl-values.md`, `audience-b2c` for `inbound-scripts.md`. This pack never edits another skill's file itself. |

4. **The check.** Call the `email-compliance-reviewer` agent with the exact file path(s) to check. It only reads; no grant or approval dance is needed, since it calls no connector tool and changes nothing. Show the founder its report in plain words, and name which skill fixes each flagged item.
5. **Where this check should run.** This pack calls no other skill automatically; it is on the orchestrator (a founder's own request, or a future wiring decision) to call it at the natural points: the end of `outreach-b2b`'s Step 6 (before Step 7's save), inside `ghl-values` before Step 7 pastes anything into the live account, and inside `publish-content` before anything that looks like a bulk or automated send goes out. This pack does not wire itself into those skills; it only says where it belongs.
6. Answer "how does X work" or "is this okay" questions straight from `references/knowledge.md`'s regime sections, citing that it may be out of date past `verified_on`, since thresholds and penalty figures change, and offer to refresh it.
