---
id: ghl-install-link
title: One GoHighLevel install path everywhere
purpose: Say the same GoHighLevel install steps, in the same order, everywhere a founder reads them, so no copy tells them to skip the LeadConnector app install and land on a broken connector.
touches:
  - START-HERE.md
  - .claude/skills/connect-tools/SKILL.md
  - .claude/skills/help/SKILL.md
  - .claude/references/connections.md
  - .claude/skill-packs/ghl/skills/ghl-expert/SKILL.md
  - .claude/skill-packs/ghl/references/knowledge.md
  - .claude/skill-packs/ghl/references/evals.md
  - .claude/skills/ghl-expert/SKILL.md
adds: []
requires: []
safety: false
done-when:
  - "connections.md holds the GoHighLevel install-link URL exactly once, and every other copy of that URL, in START-HERE.md or anywhere under .claude/ (excluding .claude/tests/ and .claude/updates/), is byte-identical to it"
  - "START-HERE.md and .claude/skills/connect-tools/SKILL.md mention installing the LeadConnector app before they mention adding the custom connector in Claude, in that order"
check: ghl-install-link.check.sh
founder-data: false
---

## What changed and why

Founders were landing on a broken GoHighLevel connector: they added the
**HighLevel** connector in Claude and signed in, but no tools ever
appeared. The cause was order, not the connector itself. GoHighLevel's
own LeadConnector app has to be installed first, on LeadConnector's site
(GoHighLevel's own company), signed into with the founder's GoHighLevel
email and password, on the business's own sub-account, approved -- and
only then does adding the connector in Claude actually work. One file in
this folder described the old order (connect first, install second);
the rest already described the new one. A founder who read the wrong
file first, or whose own edited copy still carried the old order, hit
the same dead end.

This improvement is the install-link paragraph and its ordering, said
the same way, in the same order, everywhere a founder or Claude reads it:
`START-HERE.md`'s own walkthrough, `connect-tools`'s step-by-step (the
skill Claude actually runs to connect a founder), `help`'s "no tools
appear" answer, `connections.md`'s reference section that every skill
defers to, and the GoHighLevel pack's own expert skill and knowledge
file, which point back to `connect-tools` rather than repeat the steps.

Because this is a pure wording and ordering fix -- no new hook, no
settings change, nothing that touches a founder's own data -- it is not
a safety note. But it carries a check anyway: the install-link URL is
long, GoHighLevel-generated, and easy to garble in a retype, so the
check compares every copy byte-for-byte against the one in
`connections.md`, the file every other skill defers to, rather than
trusting a read-through to catch a one-character drift.

## What a stock file looks like after

`START-HERE.md`, in the GoHighLevel section, before the connector step:

> Before you add the connector below, open [GoHighLevel's install
> link](<the URL from connections.md>) in a browser. That page is on
> LeadConnector's site, which is GoHighLevel's own company, so you sign
> in there with the same email and password you use for GoHighLevel.
> Pick your business's sub-account, never the agency, and approve. Then
> come back here for the next step.
>
> Open **Settings** in the Claude app, then **Connectors**, then **Add
> custom connector**. Name it `HighLevel`, paste
> `https://services.leadconnectorhq.com/mcp/anthropic/v2` as the URL,
> and connect it. [...]

`.claude/skills/connect-tools/SKILL.md`, in its GoHighLevel walkthrough,
step 1 before the later "Choose **Add custom connector**" step:

> 1. Give them the install link (the full URL lives in
>    `../../references/connections.md`; paste it into the chat for them
>    to click, never ask them to type it). Say plainly that the page is
>    on LeadConnector's site, which is GoHighLevel's own company, so
>    they sign in there with the same email and password they use for
>    GoHighLevel. They pick their business's sub-account and not the
>    agency, and approve. Then they come back to Claude.

`.claude/references/connections.md`, under "GoHighLevel: the
connector":

> **The install comes first.** Before adding this connector in Claude,
> the founder opens GoHighLevel's own install link in a browser. [...]
> Without this step the sign-in window still finishes, but Claude never
> connects: no tools appear. The link:
>
> <one URL, the same one everywhere else copies it from>

`.claude/skills/help/SKILL.md` and the GoHighLevel pack's `ghl-expert`
skill and `knowledge.md` never repeat the steps; they point a founder or
Claude back to `connect-tools` (or, for `help`, name the install step as
the likely cause and give the same three-part fix: open the install
link, sign in and approve, then reconnect in Claude).
