---
id: gates-own-use
title: Gates are the founder's own checkpoints
purpose: The three gates are the founder's own checkpoints for their own use, not a submission checked or reviewed by anyone else; nothing is ever due, handed in, or read by a mentor team, and Claude's job at every gate is to say what is done and keep the founder moving to the next unfinished engine, then the 90 day plan.
touches:
  - .claude/references/gates.md
  - .claude/skills/gate/SKILL.md
  - .claude/skills/status/SKILL.md
  - .claude/skills/routines/SKILL.md
  - .claude/skills/founder-brain/SKILL.md
  - .claude/skills/save/SKILL.md
  - .claude/skills/help/SKILL.md
adds: []
requires: []
safety: false
done-when:
  - "gates.md no longer says a gate is checked at the start of the next session"
  - "the Founder Brain's Flags section no longer says the mentor team reads it"
  - "the gate skill names the next unfinished engine and offers to start it"
check: gates-own-use.check.sh
founder-data: false
---

## What changed and why

A founder's Claude had told her she had something due at a gate before
Friday, that her 90 day plan was to be handed in before Atlanta, and that
her checklist said to install the Launchhouse plugin. None of that is what
the gates are. They are the founder's own checkpoints, computed from her
own files, for her own use: nothing is submitted, handed in, checked by,
or reviewed by anyone else.

`gates.md`, `gate/SKILL.md`, `status/SKILL.md`, `routines/SKILL.md`,
`founder-brain/SKILL.md`, `save/SKILL.md` and `help/SKILL.md` are reworded
so no line implies a founder owes something to a mentor team or a
deadline: the "Checked" column becomes "Useful to read", the Founder
Brain's Flags section is a plain record for the founder's own use rather
than something "the mentor team reads before the session", and a "mentor
can connect it" pattern becomes "you can do this yourself, or ask in the
Slack channel if you want a hand". Programme dates stay exactly where they
were: the natural moment each piece of work becomes useful (the Saturday
the 25 messages go out, the Sunday the 90 day plan is built), never a
deadline. The engine locks, the gate-state computation, and every file
format are unchanged.

Claude's job at a gate stays proactive: after each piece of work, name the
next unfinished engine and offer to start it, until every engine is done,
then the 90 day plan, then the playbook insert.

## What a stock file looks like after

`.claude/references/gates.md`, opening:

> Three gates. They are the founder's own checkpoints, for their own use:
> nothing here is submitted, handed in, or reviewed by anyone else. Each
> is read at the start of the next session, so the founder can see their
> own progress while there is still time to build. They exist so the
> founder arrives in Atlanta ready to build, not so someone else can sign
> off on their work.
>
> Claude's job at every gate is the same: say what is done, name the next
> unfinished engine, and offer to start it. Keep the founder moving from
> one engine to the next until every engine is done, then to the 90 day
> plan, then to the playbook insert.

`.claude/skills/founder-brain/SKILL.md`, the Flags section:

> The Flags section is for the founder's own use: a plain record of what
> is still thin or unresolved, worth showing a mentor if they want a
> hand. Be honest in it. A brain that hides a problem is worse than one
> that names it.
