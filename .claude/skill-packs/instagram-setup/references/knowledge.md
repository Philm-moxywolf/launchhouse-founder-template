# Instagram setup — knowledge (guide pack)

Read `pack.md` alongside this file. The shared caution on every social account, official connectors only, is in `../../../references/social-accounts.md`; this file does not restate it, only what a founder's Claude needs on top for Instagram specifically.

## Mental model

A personal Instagram account cannot be posted to by GoHighLevel, cannot show statistics, and cannot run the audience engine's comment-to-DM flow. All three need a **Professional account** (Business or Creator, Instagram's own umbrella term), which in turn needs a **Facebook Page** behind it, because Meta issues a professional Instagram account's API access through that Page, not through the Instagram account alone. Two-factor authentication is a separate, unrelated step: it is account security, not a posting requirement, but it is the founder's own best protection once a business tool (GoHighLevel) is reading and writing to the account.

- **Business account**: for a brand, shop, or service; can show a physical address; monetizes through Instagram Shopping and ads.
- **Creator account**: for a public figure, artist, or personal-brand founder; more specific category labels; access to Subscriptions and Live badges; can hide phone and email while keeping a contact button.
- Either type is a Professional account and either connects to GoHighLevel's Social Planner. The choice is about which categories and contact options fit this founder, not about which one "works" with GoHighLevel; both do (documented: Instagram Help, About Business and Creator Accounts).
- Switching types later is instant and free, so getting it slightly wrong today is not a lasting mistake.

## What Claude can do and what it needs first

**Needs first:** a Founder Brain with Track `b2c` (this pack is B2C only, rule 1), and, for the profile-copy step, the Brain's Offer, Audience, and Voice sections filled in. For the "checking it worked" step, GoHighLevel connected (`connect-tools`) is the fast path; without it, Claude asks the founder directly what they see in their own Instagram settings.

**What Claude can do:** explain the choice between Business and Creator for this founder in plain words; give the exact screens to tap through for switching account type, linking a Facebook Page, and turning on two-factor authentication; write the bio, link-in-bio, and highlight-cover plan from the Brain, in the founder's own voice, for them to paste in; read back GoHighLevel's connected-accounts list to confirm the link worked; record the result in `growth-engine/.state/setup.md`.

**What Claude cannot do, and never attempts:** sign in to the founder's Instagram, tap anything inside the Instagram app on their behalf, or use any tool, browser automation, or MCP connector to change account settings directly. See `../../../references/social-accounts.md`. Nothing in this pack's own tool use touches Instagram at all; the only tool call in any of its workflows is a GoHighLevel read.

## Workflows for Launchhouse jobs

### Switch to a professional account

1. Ask which fits better: retail, service, or local business points to **Business**; a founder building a personal following or considered a public figure in their own right points to **Creator**. Give the one-line reason, not a long comparison, unless they ask for more.
2. Give the exact steps (documented, Instagram Help, Set up a professional Instagram account): open Instagram, tap the profile picture, then the menu, then Settings, then under "For professionals" tap Account type and tools, then Switch to professional account, then pick Creator or Business, then a category.
3. Say plainly: this needs their own sign-in, takes under five minutes, costs nothing, and is fully reversible.

### Link to a Facebook Page

1. Ask whether they already have a Facebook Page for the business. If not, point them at Facebook's own Page creation, outside this pack's scope (a plain Facebook feature, not a Launchhouse one).
2. Give the two documented routes (Instagram Help, Add or change the Facebook Page connected to your Instagram professional account): inside Instagram, Edit Profile, then Page, then connect it; or from the Facebook Page itself, Settings, then Linked Accounts, then Instagram. Either needs the founder signed in to a personal Facebook profile that administers that Page; Meta will not link a Page with no personal profile behind it.
3. Accounts Center (Settings, then Accounts Center, on either app) is Meta's own place to manage the whole linked group at once, and is the route to use if the founder wants to review or unlink later.

### Two-factor authentication

Give the documented steps (Instagram Help, Securing Your Meta Account With Two-Factor Authentication): Settings, then Security (or, via Accounts Center, Password and security), then Two-factor authentication, then choose an authentication app (recommended over SMS), a text message, or WhatsApp. Say why it matters now specifically: once GoHighLevel and other tools are reading and writing this account, its own login is worth locking down the same way the founder would lock down any other business login.

### GoHighLevel's Instagram connection

Once the Professional account is linked to a Facebook Page, GoHighLevel's own Social Planner can connect it: the `ghl` pack and `connect-tools` cover the click-through inside GoHighLevel itself. This pack's own part ends at "the account is ready"; `connect-tools` and `publish-content` take it from there.

### ManyChat or Composio prerequisites

If the founder's audience engine plan (`audience-b2c`) calls for ManyChat or Composio for the inbound comment-to-DM flow (see `docs/free-stack-design.md`, sections 4 and 8, this project's own build notes): both need the same Professional-account-linked-to-a-Page state as GoHighLevel, since both reach Instagram through the same Meta Graph API path, never a workaround. ManyChat is documented as an official Meta Business Partner in the messaging category (Meta, ManyChat case study page, below); a founder using it still connects it themselves, in ManyChat's own account, the same "founder's own click" rule as everything else here. Composio's managed OAuth for Instagram is (unverified) against a live founder account as of this pack's `verified_on` date; the Composio security note in `docs/free-stack-design.md` (a breach disclosed 2026-05-21) applies here too: any Composio account used must be the founder's own, never a shared or Launchhouse-held one.

### Checking it worked

1. If GoHighLevel is connected, read its Social Planner accounts list (the `ghl` pack's own read, `get-account` or the account connector's equivalent) and look for the Instagram account by name.
2. If it appears, record in `growth-engine/.state/setup.md`: `Instagram Business or Creator | done | <date> | Instagram connected in Social Planner: <name>` (the exact row shape `connect-tools` already uses).
3. If GoHighLevel is not connected yet, ask the founder directly: "does your Instagram now say Professional account under Settings?" and record what they say, with `evidence` noting it came from the founder, not a tool read.

### Profile basics in the founder's voice

1. Read the Founder Brain's Offer, Audience, and Voice sections, and `brain/voice-samples/` if any exist.
2. Draft: a bio (150 characters, Instagram's own limit) built from the Offer and Audience, a link-in-bio recommendation pointing at the founder's GoHighLevel booking or lead form (never a raw, unbranded URL if a booking link exists), and a short highlights plan (what two or three highlight covers would serve this audience, named plainly, not styled — styling is the founder's own design choice).
3. Show the draft, get the founder's own edits, and stop. Claude never pastes this into Instagram; the founder copies it in themselves, the same "founder's own click" rule as the account changes above.
4. Route the draft through `rules-reviewer` before showing it, the same as any other founder-facing copy this project writes (rule 5, never invent proof; the bio must never claim a number or result the Brain has not confirmed).

## Limits and gotchas

- Instagram's own "Save to PDF" and account-export features do not apply here; that is the `linkedin-profile` pack's own route, not Instagram's.
- Switching account type more than a few times in a short window can itself look unusual to Instagram's own systems; there is no documented hard limit, so this is a "do it once, deliberately" note rather than a sourced number (unverified).
- A Creator account cannot display a physical business address; a Business account cannot use Subscriptions or Live badges. If the founder later wants the other type's feature, switching is free and instant, but any GoHighLevel connection should be re-checked afterward (unverified whether GoHighLevel's own link survives a type switch without a reconnect; ask the founder to check again after switching).
- Bio length (150 characters) and one clickable link are Instagram's own long-standing limits; a founder wanting more than one link needs a link-in-bio page, which is outside this pack's scope and not something Launchhouse builds or recommends by name.

## Failure modes and fixes

| Symptom | Likely cause | Fix |
|---|---|---|
| Instagram will not offer "Switch to professional account" | Account is already Professional, or is a very new account still under Instagram's own review | Check Settings, then under "For professionals" for the current type; if new, wait and try again in a day. |
| Facebook Page will not link | The founder is signed in to a personal Facebook profile with no admin role on that Page | Sign in to Facebook as the Page's own admin first, or add the founder as an admin on the Page, then retry. |
| GoHighLevel's accounts list never shows the Instagram account | The Page-to-Instagram link did not actually take, or GoHighLevel's own Social Planner connection was never opened for it | Re-check the link in Accounts Center; in GoHighLevel, open Social Planner and connect the Instagram account explicitly. |
| Two-factor authentication codes never arrive by text | Carrier delay, or the number on file is out of date | Recommend an authentication app instead; Instagram documents this as the more reliable method. |
| The bio draft states a number or result the Brain has not confirmed | The founder's raw notes mentioned a figure not yet under `## Proof` in the Brain | Never write it in; ask the founder to confirm the figure and add it to the Brain first (rule 5). |
| Founder wants to connect Instagram DMs to auto-reply | This is the guard-rail case: automated cold DMs are refused outright (rule 2) | Say plainly this pack never sets up DM automation, and that an inbound-only, founder-approved reply flow is `audience-b2c`'s job, not this pack's. |

## Rules that apply here

- **Rule 1 (one track):** this pack is B2C only. If a B2B founder asks about Instagram, say plainly it is not part of their track and stop; never offer to set it up for them.
- **Rule 2 (no Instagram DM automation, ever):** this pack never sets up or recommends DM automation, only the account state DM automation would require if the founder chose it elsewhere (rule 2 already refuses that choice outright, per the six rules and `../../../references/social-accounts.md`).
- **Rule 5 (never invent proof):** every line of bio, link-in-bio, or highlight copy this pack drafts comes from the Brain's own confirmed Offer, Audience, and Proof, never a number or claim invented to sound better.
- **Rule 6 (the voice is the founder's):** profile copy is written in the Voice section's own terms and the founder's own writing in `brain/voice-samples/`, never a generic "professional bio" template.
- **Account changes are the founder's own click**, on every step in this pack, per `../../../references/social-accounts.md`.

## Never

- Never sign in to a founder's Instagram, or use any tool, browser automation, or unofficial connector to change an Instagram account setting. See `../../../references/social-accounts.md`.
- Never recommend or help set up follow/unfollow, like, comment, or DM automation on Instagram, cold or otherwise.
- Never invent a follower count, engagement figure, or result in bio or highlight copy.
- Never suggest an unofficial "Instagram API" wrapper, scraper, or growth tool as a shortcut past the official connectors named in `../../../references/social-accounts.md`.
- Never claim GoHighLevel, ManyChat, or Composio work without the account first being Professional and Page-linked; that link is the one real prerequisite every route in this pack shares.

## Sources

- Instagram Help, Set up a professional Instagram account to access business or creator tools and controls: <https://help.instagram.com/502981923235522> (checked 2026-09-22)
- Instagram Help, About Business and Creator Accounts: <https://help.instagram.com/138925576505882> (checked 2026-09-22)
- Instagram Help, Add or Change the Facebook Page Connected to Your Instagram Professional Account: <https://help.instagram.com/570895513091465> (checked 2026-09-22)
- Instagram Help, Securing Your Meta Account With Two-Factor Authentication: <https://help.instagram.com/566810106808145> (checked 2026-09-22)
- Meta for Business, ManyChat Meta Business Partner case study: <https://www.facebook.com/business/marketing-partners/case-studies/manychat_bb-littles> (checked 2026-09-22)

## Refreshing this pack

1. Re-check every Instagram Help URL above still resolves and still describes the same click path; Meta renumbers these help-article ids without warning.
2. Re-read `docs/free-stack-design.md`'s Composio and ManyChat sections for any change to free-tier terms or the breach note.
3. Run `sh .claude/scripts/skill-packs.sh --validate instagram-setup`.
4. Update `verified_on` in `pack.md` once done.
