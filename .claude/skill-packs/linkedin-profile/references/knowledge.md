# LinkedIn profile — knowledge (guide pack)

Read `pack.md` alongside this file. The shared caution on every social account, official connectors only, is in `../../../references/social-accounts.md`; this file does not restate it, only what a founder's Claude needs on top for LinkedIn specifically.

## Mental model

A B2B founder's LinkedIn profile is the page the 25 outreach messages and the content engine's posts send people back to. A **profile** carries a headline, an About section, Featured items (pinned posts, links, or media), an Experience list, a banner image, and an optional custom URL; **Creator mode** changes how the profile displays (a follow button in place of connect, topics shown under the name, and access to newsletters and LinkedIn Live) without changing the underlying account. A **company page** is a separate object from a personal profile, with its own About, banner, and posts, administered by one or more personal profiles.

Unlike GoHighLevel or Apollo, there is no connector this pack ever calls to read or change any of this. The one thing in this environment that looks like a LinkedIn connector, an unofficial MCP server (tool suffixes `get_my_profile`, `search_people`, `send_message`, `connect_with_person`, and the rest listed in `policy.tsv`), is not an official LinkedIn integration, is not listed among LinkedIn's own Marketing Partners, and using it at all risks the founder's account (see "Rules that apply here", below). This pack polices it; it does not use it.

## What Claude can do and what it needs first

**Needs first:** a Founder Brain with Track `b2b` (this pack is B2B only, rule 1), its Offer, Audience, Proof, and Voice sections filled in, and the founder's own LinkedIn export added to the folder with `/growth-engine:add-files`: their profile saved as a PDF ("Save to PDF" from their own profile page), and, for company-page and fuller-history work, their "Get a copy of your data" archive from LinkedIn's own Settings, then Data privacy.

**What Claude can do:** read that export (through `linkedin-profile-reviewer`) and the Brain, and draft headline, About, Featured, Experience, banner, and company-page copy in the founder's own voice, plus custom-URL and Creator-mode notes, for the founder to paste in themselves. Recommend only LinkedIn-partnered or LinkedIn's own tools (Sales Navigator, LinkedIn's own post-scheduling inside the composer, or a partner listed in LinkedIn's own Marketing Partners directory), always sourced.

**What Claude cannot do, and never attempts:** sign in to LinkedIn, read or change a live LinkedIn profile through any tool, or call any of the unofficial LinkedIn MCP tools this pack's `policy.tsv` covers beyond the rare, founder-approved read `policy.tsv` still gates behind an explicit ask. See `../../../references/social-accounts.md`.

## Workflows for Launchhouse jobs

### Add the export

1. If the founder has not already, send them to `/growth-engine:add-files`.
2. Tell them exactly what to bring: from their own profile page, More, then Save to PDF; and, for the fuller picture (positions, skills, and company-page history if they administer one), Settings, then Data privacy, then Get a copy of your data, choosing the larger archive if they want everything, which LinkedIn emails a download link for within about 24 hours (documented, LinkedIn Help, Download your account data, below).
3. `add-files` converts the PDF to readable text and stores both under `growth-engine/inbox/uploads/`, read for facts only, the same as any other uploaded document (`../../../references/contract.md`).

### Review the export and draft profile copy

1. Call `linkedin-profile-reviewer` with `PHASE: plan`. It reads the export and the Brain, and returns what the profile currently says versus what the Brain and Voice would suggest, plus a numbered set of proposed draft sections. It calls no tool, changes nothing, and there is no `PHASE: execute` for this pack.
2. Draft, in the founder's own voice: a headline (220 characters, LinkedIn's own limit), About (2,600 characters), two or three Featured items to pin (the founder's own proof or a strong post, never invented), Experience bullet points for the current business, and a banner-image brief (what it should say and show, not a styled file; design is the founder's own choice).
3. Route the draft through `rules-reviewer` before showing it (rule 5: never invent proof, every claim traces to the Brain's own confirmed Proof section).
4. Show the draft and stop. The founder pastes it into LinkedIn themselves; this pack never touches a live profile.

### Custom URL and Creator mode notes

Explain, do not do: a custom URL is set from the founder's own profile, Edit public profile & URL; Creator mode is turned on from the founder's own profile, under the Resources or Creator mode section of Settings. Both are the founder's own click, and both are optional; note the trade-off (Creator mode swaps Connect for Follow as the primary action, which changes how a cold viewer from an outreach message can respond) so the founder decides with it in view.

### Company page basics

If the founder administers a company page, draft its About text, banner brief, and a short "what to post here vs. the personal profile" note from the Brain, the same voice and proof rules as the personal profile. Claude never creates or administers a company page itself; a founder without one yet creates it themselves from LinkedIn's own "Create a company page" flow, outside this pack's scope.

### Recommending a tool beyond the free profile

Only ever point at: **Sales Navigator** (LinkedIn's own paid search and outreach-tracking product), **LinkedIn's own scheduling** inside the post composer, or a partner listed in **LinkedIn's Marketing Partners directory** (`business.linkedin.com/advertise/partners`, categories include Content & Creative, Audiences, Page Management, and more). Always name the source and note the founder connects it themselves, in their own LinkedIn account settings, never through this pack.

## Limits and gotchas

- LinkedIn's own "Save to PDF" is not available in the LinkedIn mobile app, only works when the profile's language is set to English, and is capped at 200 PDF downloads a month (documented, LinkedIn Help, Save a profile as a PDF, below); a founder on the app needs to switch to a browser for this step.
- The larger "Get a copy of your data" archive can take up to 24 hours to arrive by email, and the download link is only live for 72 hours once it does (documented, LinkedIn Help, Download your account data, below); tell the founder to request it a day before they plan to work from it, not the same session.
- Headline (220 characters) and About (2,600 characters) limits are LinkedIn's own; a draft that runs long gets trimmed before it is shown, never handed over for the founder to cut themselves.
- This pack has no way to check a draft "looks right" once pasted in, since it never reads a live profile; ask the founder to say back what changed, or bring a fresh export next time they want another review.

## Failure modes and fixes

| Symptom | Cause | Fix |
|---|---|---|
| Founder cannot find "Save to PDF" | They are on the LinkedIn mobile app, where the feature does not exist | Tell them to open linkedin.com in a browser instead. |
| The PDF export reads oddly or is missing sections once converted | A dense two-column PDF layout can confuse plain-text conversion | Ask the founder to confirm what a section actually says before drafting anything from it, rather than guessing at a garbled line. |
| "Get a copy of your data" email never arrives | Can take up to 24 hours; spam filtering; or the founder requested the wrong (smaller) category by mistake | Wait the full 24 hours before treating it as failed; check spam; confirm they selected the larger archive if that is what the job needs. |
| Founder asks Claude to just check their profile directly instead of exporting | They are used to a tool reading things live | Explain plainly why: no official connector reaches a personal LinkedIn profile, and the unofficial one this environment carries is refused for exactly this job (see Rules, below). The export route is the only route. |
| Draft profile copy states a number the Brain has not confirmed | The founder's own notes mentioned a figure not yet under the Brain's Proof section | Never write it in; ask the founder to confirm it and add it to the Brain first (rule 5). |
| Founder wants Claude to send connection requests from a scraped or found list | This is the guard-rail case: LinkedIn automation is refused outright | Say plainly this pack never connects, sends, or automates on LinkedIn, and that connection requests and messages are sent by the founder's own hand, from LinkedIn itself. |

## Rules that apply here

- **Rule 1 (one track):** this pack is B2B only. If a B2C founder asks about LinkedIn, say it is not part of their track and stop.
- **Rule 5 (never invent proof):** every line of headline, About, Featured, Experience, or company-page copy traces to the Brain's own confirmed Offer, Audience, and Proof; nothing here is ever a generic LinkedIn template.
- **Rule 6 (the voice is the founder's):** copy is written from the Voice section and the founder's own writing in `brain/voice-samples/`, never a stock "LinkedIn About section" formula.
- **The owner's own policy on LinkedIn specifically** (this pack's reason for existing): never directly manipulate a LinkedIn profile, because the chance of the account being restricted or banned is real and LinkedIn does not reverse that on request. Recommend only profile exports and guidance, or LinkedIn-partnered third-party tools, and hold every other social account to the same caution, just less strictly than LinkedIn's own (`../../../references/social-accounts.md`).
- **The unofficial LinkedIn MCP connector, specifically:** every write, send, or connect tool on it is denied outright by `policy.tsv`, with no founder yes able to override a deny (denies are absolute, per `../../references/connections.md`). Every read on it is asked about, not silent, with the ban risk named and the export route offered every time, even for the founder's own profile. See `policy.tsv` and `tests.tsv` for the exact rows and confirmed decisions.

## Never

- Never sign in to LinkedIn, or use any tool, browser automation, or unofficial connector to read or change a live LinkedIn profile or company page.
- Never call `connect_with_person` or `send_message` on the unofficial LinkedIn MCP connector, or any equivalent on a future connector; both are denied outright by `policy.tsv`, and a founder's yes never overrides a deny.
- Never call a read on the unofficial LinkedIn MCP connector without first asking the founder and naming the ban risk, even for the founder's own profile; `policy.tsv` holds every one of these at `ask`, never silent.
- Never scrape, search, or bulk-collect LinkedIn data by any means, official or not, beyond the founder's own downloaded export.
- Never invent a number, result, or claim in headline, About, Featured, Experience, or company-page copy.
- Never suggest an unofficial LinkedIn automation, connection, or messaging tool as a shortcut past LinkedIn's own Marketing Partners directory or Sales Navigator.

## Sources

- LinkedIn Help, Prohibited software and extensions: <https://www.linkedin.com/help/linkedin/answer/a1341387> (checked 2026-09-22)
- LinkedIn Marketing Partners, official directory: <https://business.linkedin.com/advertise/partners> (checked 2026-09-22)
- LinkedIn Help, Save a profile as a PDF: <https://www.linkedin.com/help/linkedin/answer/a541960> (checked 2026-09-22)
- LinkedIn Help, Download your account data: <https://www.linkedin.com/help/linkedin/answer/a1339364/downloading-your-account-data> (checked 2026-09-22)

## Refreshing this pack

1. Re-check every LinkedIn Help URL above still resolves and still describes the same click path and the same limits; LinkedIn renumbers these help-article ids without warning.
2. Re-run ToolSearch for the unofficial LinkedIn MCP connector's tool list; if a suffix was added, removed, or renamed, update `policy.tsv` and `tests.tsv` to match, following the same deny-write/ask-read split.
3. Run `sh .claude/scripts/skill-packs.sh --validate linkedin-profile` and `sh .claude/scripts/skill-packs.sh --test linkedin-profile`.
4. Update `verified_on` in `pack.md` once done.
