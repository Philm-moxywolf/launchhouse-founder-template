---
id: booking-reviews
name: Booking and reviews
kind: guide
skills: [booking-reviews-expert]
agents: [booking-reviews-checker]
scripts: []
connectors: []
tracks: both
jobs: [pick a booking route and connect the link, set up Google Business Profile and get the review link, respond to reviews in the founder's voice]
job_skills: [founder-brain, ghl-values]
specialist: booking-reviews-checker
expert_skill: booking-reviews-expert
verified_on: 2026-09-22
origin: template
---

## What it is for here

Every pack that promises a founder a meeting or a message back needs somewhere real for that to land: the Discovery booking and DM qualify-and-book packs, and the link in bio, all point at one booking link, and the review request pack points at one review link. This pack helps a founder pick or confirm the booking route, get both links working, and answer reviews once they start coming in. It never books the founder's calendar itself and never writes or manages a review on their behalf.

## When to pick this route

**Booking.** Four routes, cheapest and least-new-account first:
- **GoHighLevel calendar.** Already included in the plan every founder is already paying for. Pick this by default: it is the only route that talks to the rest of the account (the CRM contact, the pipeline stage, the confirmation and reminder messages) without a second connection.
- **Cal.com, free plan.** Pick this when the founder is not yet on GoHighLevel, or wants a booking page fast while the account is still being set up. Free.
- **Google Calendar appointment schedule.** Pick this when the founder is already living in Google Calendar and wants zero new accounts. Needs Google Workspace Business Standard or a Google One Premium plan; a personal Gmail account can make one appointment schedule to try it, not more.
- **Calendly, free plan.** Pick this only when the founder already uses Calendly and does not want to move. The free plan is thin: one event type, one calendar connection, no webhooks or automations, so it cannot hand a booking back into GoHighLevel on its own.

**Reviews.** There is only one route: Google Business Profile. It is free, and it is what shows up next to the founder's business in Google Search and Maps, which is where a prospect actually goes looking. Nothing else in this pack's scope substitutes for it.

## Connecting

**Nothing here is a Claude connector.** This pack never signs in to the founder's calendar tool or their Google Business Profile. It reads the founder's own account state, checks a public link works, and writes plain guidance and copy. The founder does the clicking, in their own browser, the same as any first message to someone who has not written.

Where the booking route is GoHighLevel, `connect-tools` already connects the **HighLevel** connector this pack's guidance assumes is in place; see `../../references/connections.md`.

## In Cowork

No hooks run there, and this pack calls no connector tool, so there is nothing to set to Needs approval for this pack specifically. If the booking route is GoHighLevel, GoHighLevel's own connector setting still applies as `../../references/connections.md` describes.

## Changing this pack

Founders edit `policy.local.tsv` in this pack's folder if they ever add one; this pack ships with no `policy.tsv`, since none of its skills or agents call a connector tool that needs an extra rule. Everything else, `skills/`, `agents/`, `references/`, is edited directly in the pack's own folder, and Launchhouse re-installs the skills and agents from here, never the other way around.
