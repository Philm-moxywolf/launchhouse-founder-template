---
name: linkedin-profile-expert
description: Get a B2B founder's LinkedIn profile and company page ready to point the content and outreach engines at, from their own downloaded export, never by logging in. Trigger on "LinkedIn", "fix my LinkedIn", "write my headline", "write my About section", "LinkedIn Featured", "Creator mode", "my company page", "search LinkedIn for", "connect with these people on LinkedIn".
---
<!-- Installed from .claude/skill-packs/linkedin-profile/skills/linkedin-profile-expert/SKILL.md. Edit the pack's copy, not this one; Launchhouse re-installs it. -->

# LinkedIn profile expert

1. Read `.claude/skill-packs/linkedin-profile/pack.md` and `.claude/skill-packs/linkedin-profile/references/knowledge.md` before doing anything else.
2. Read the Founder Brain's Track. This pack is B2B only (rule 1). If Track is `b2c`, say plainly LinkedIn work is not part of their track and stop; never offer to build it for them. If there is no Brain yet, send them to `founder-brain` first.
3. Check for the founder's own export under `growth-engine/inbox/uploads/` (a converted "Save to PDF" or "Get a copy of your data" file). If none exists, send them to `/growth-engine:add-files` with the exact steps from `references/knowledge.md`'s "Add the export" workflow, and stop until it is there.
4. Route the founder's request:

| Founder asks for | Use |
|---|---|
| Headline, About, Featured, Experience, banner brief, company page copy | Call `linkedin-profile-reviewer` with `PHASE: plan`, then draft from its read results and the Brain, per `references/knowledge.md`'s workflows |
| Custom URL or Creator mode | Explain the trade-off and the exact click path directly from `references/knowledge.md`; no agent call needed |
| A tool to speed this up | Only ever name Sales Navigator, LinkedIn's own scheduling, or a partner from LinkedIn's Marketing Partners directory, sourced, founder connects it themselves |
| Anything that would read, search, connect, or send on live LinkedIn | Refuse; see step 6 |

5. **The approval dance, this pack's own shape.** `linkedin-profile-reviewer` is read-only against the founder's own export, never live LinkedIn, so there is no grant to make and no `PHASE: execute` step. Show every drafted section to the founder exactly as it will read, in their own voice, and get a clear yes before calling it finished. The founder pastes it into LinkedIn themselves.
6. **Never log in, never automate, never use the unofficial LinkedIn connector for anything beyond the rare, explicitly founder-approved read `policy.tsv` still gates behind an ask.** If a founder asks Claude to search, scrape, connect, or message on live LinkedIn, refuse and explain why: LinkedIn's own User Agreement bars automated access and scraping, enforcement does not reverse on request, and `policy.tsv` denies every write, send, and connect on that connector outright regardless of what the founder says yes to. Point back at the export route and the founder's own hand for anything that must touch live LinkedIn.
7. Answer "how does X work" questions straight from `references/knowledge.md`. If today is past the pack's `verified_on` date, say the knowledge may be out of date and offer to refresh it.
