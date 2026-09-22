# Social accounts: the shared caution

One rule, for every social account a founder connects or runs, on every platform, not only the two `.claude/skill-packs/` guide packs (`instagram-setup`, `linkedin-profile`) that link to this file. Where a tool pack or a job skill touches a founder's own social account, this file is the caution it points back to.

## The rule

**Official connectors and platform-approved partners only.** Claude reaches a founder's social accounts through GoHighLevel's own Social Planner connection, Meta's own tools (Accounts Center, Meta Business Suite, the Instagram and Facebook Graph APIs), a partner listed in LinkedIn's own Marketing Partners directory, or ManyChat as a Meta Business Partner. Nothing else.

**Never:**
- Unofficial automation tools, "growth" tools, or browser extensions that act on a founder's account (auto-follow, auto-like, auto-comment, auto-connect, view-bots, engagement pods).
- Browser bots or headless-browser scripts that click around a platform as if they were the founder.
- Scraping a platform's pages or its API without that platform's own written permission.
- Password sharing, or handing a founder's login to any tool that is not that platform's own approved connector or partner.
- Session-cookie or token extraction: copying a founder's logged-in session out of their browser so a tool can act as them without a real sign-in.
- Follow, unfollow, like, connect, or DM automation of any kind, on any platform. Rule 2 already refuses Instagram DM automation outright; this extends the same refusal to every other platform's equivalent action (LinkedIn connection requests, LinkedIn or Instagram auto-DMs, Facebook auto-friend-requests, and anything similar on a platform not listed here yet).

**Account changes are the founder's own click.** Claude drafts, explains, and points at the right screen. The founder signs in and makes the change themselves, on every platform, not only LinkedIn. Claude never signs in to a founder's social account on their behalf outside an approved connector's own OAuth flow.

## Why

A platform's own enforcement against unofficial automation is not appealable in any way Launchhouse can promise to reverse. A restricted or banned account, once it happens, does not come back on request: LinkedIn's own help pages describe account restriction or closure as the consequence, not a warning that precedes one (LinkedIn Help, Prohibited software and extensions, below). The founder is building a business on that account; a Launchhouse shortcut that costs them the account is a cost this programme has no way to undo.

## LinkedIn is the strictest of the three

LinkedIn's own User Agreement (Section 8.2, LinkedIn Help's own summary below) explicitly bars two separate things: bots or unauthorized automated methods that access the service, add or download contacts, or send or redirect messages; and software, scripts, or browser add-ons that scrape or copy the service, including profiles and other data. LinkedIn has enforced this since well before 2026; what has changed is enforcement intensity, not the underlying rule. This is why `linkedin-profile` never logs in and never uses an unofficial LinkedIn MCP tool for anything but a read the founder explicitly reviews (see that pack's `policy.tsv`), and why the profile and company-page work routes through the founder's own downloaded export instead.

Instagram and Facebook (Meta) carry the same shape of rule, one written prohibition covering both: automated data collection or automated action on the platform needs Meta's own prior written permission, which a founder's Launchhouse Claude does not have and cannot grant on Meta's behalf (Meta, Automated Data Collection Terms, below). GoHighLevel's own Social Planner connection, and Meta's own Accounts Center and Business Suite, are how a founder's Instagram and Facebook stay inside that permission; anything else is not.

## Sources

- LinkedIn Help, Prohibited software and extensions: <https://www.linkedin.com/help/linkedin/answer/a1341387> (checked 2026-09-22)
- LinkedIn Marketing Partners, official directory: <https://business.linkedin.com/advertise/partners> (checked 2026-09-22)
- Meta, Automated Data Collection Terms (effective 2024-10-07): <https://www.facebook.com/legal/automated_data_collection_terms> (checked 2026-09-22)
- Instagram Help, Set up a professional Instagram account: <https://help.instagram.com/502981923235522> (checked 2026-09-22)
- Instagram Help, About Business and Creator Accounts: <https://help.instagram.com/138925576505882> (checked 2026-09-22)

## Refreshing this file

Platform terms change without notice, more often than this template's own release cycle. Re-check every URL above still resolves and still says what this file claims before relying on it for a founder who asks, and update the dates when it is re-checked. If a platform's own terms page has moved, search that platform's own help centre for the current one rather than linking a third party's summary of it.
