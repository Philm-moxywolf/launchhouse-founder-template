---
name: instagram-setup-expert
description: Get a B2C founder's Instagram into professional shape for GoHighLevel, ManyChat or Composio, and draft profile copy in their voice. Trigger on "set up Instagram", "switch Instagram to professional/business/creator", "link my Facebook Page", "Instagram two-factor", "write my Instagram bio", "did my Instagram connect", or when a job needs a Professional Instagram account and nothing here yet knows how to use it.
---
<!-- Installed from .claude/skill-packs/instagram-setup/skills/instagram-setup-expert/SKILL.md. Edit the pack's copy, not this one; Launchhouse re-installs it. -->

# Instagram setup expert

1. Read `.claude/skill-packs/instagram-setup/pack.md` and `.claude/skill-packs/instagram-setup/references/knowledge.md` before doing anything else.
2. Read the Founder Brain's Track. This pack is B2C only (rule 1). If Track is `b2b`, say plainly Instagram is not part of their track and stop; never offer to set it up for them and never ask which track they are on. If there is no Brain yet, send them to `founder-brain` first.
3. Route the founder's request:

| Founder asks for | Use |
|---|---|
| Switching account type, linking a Facebook Page, or two-factor authentication | Walk them through it directly from `references/knowledge.md`'s Workflows section; no specialist needed, since no tool call is involved |
| Checking whether the Instagram connection worked | The `instagram-setup-checker` agent, `PHASE: plan` only (it is read-only; there is no execute phase in this pack) |
| Writing the bio, link-in-bio, or highlights plan | The `instagram-setup-profile` skill |
| GoHighLevel's own posting or statistics, once the account is ready | Hand off to `connect-tools` or `publish-content` (the `ghl` pack's own jobs); this pack's part is done once the account is Professional and Page-linked |

4. **Account changes are always the founder's own click.** Give the exact screens and taps from `references/knowledge.md`; never use a tool, browser automation, or credential to change an Instagram setting. See `../../../references/social-accounts.md`.
5. **Checking the connection.** Call `instagram-setup-checker` with `PHASE: plan`. It only reads GoHighLevel's Social Planner accounts list (a silent read under `mcp-guard.sh`, no grant needed) and reports what it found; there is nothing to approve and no execute phase, since this pack writes nothing to any connector. If GoHighLevel is not connected, ask the founder directly what their own Instagram settings show.
6. Record connection state in `growth-engine/.state/setup.md`, in the shape in `../../references/contract.md`: the `Instagram Business or Creator` row `connect-tools` already uses.
7. Answer "how does X work" questions straight from `references/knowledge.md`. If today is past the pack's `verified_on` date, say the knowledge may be out of date and offer to refresh it.
8. Never set up, recommend, or help configure DM automation, follow/unfollow automation, or any unofficial Instagram tool (rule 2, `../../../references/social-accounts.md`). This refusal holds even if the founder says yes.
