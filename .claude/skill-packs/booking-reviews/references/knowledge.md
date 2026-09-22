# Booking and reviews — knowledge (guide pack)

## Mental model

Two separate jobs that share one shape: a founder needs a public link that a stranger can act on without talking to a person first. A booking link takes a click straight to a real slot on the founder's calendar. A review link takes a click straight to the box where a customer types a review of the founder's real business. Neither one is something Claude operates directly; Claude helps the founder set the link up once, checks the link actually resolves, and writes the copy that points at it. Everything after the click happens between the founder (or their calendar tool) and the other person.

The booking link is infrastructure other packs depend on. The Discovery booking pack's confirmation message, the DM qualify-and-book pack's last step, and the GoHighLevel snapshot's `[booking link]` placeholder in `ghl-values` all point at the same one link. Pick it once, put it in one place, and every pack that promises "book a time" is telling the truth.

The review link is the same shape for the reviews half: one link, from one verified Google Business Profile, that a happy customer can tap and land straight in the review box. The review request pack (in `ghl-workflows` and `ghl-values`) sends the ask; this pack is where the link that ask points at comes from, and where the founder learns how to answer what comes back.

## What Claude can do and what it needs first

**Booking.** Needs the founder's Brain (Track, and whichever tool they already use, if any) and their say-so on which of the four routes to pick. Claude cannot create the calendar itself in any of the four routes: it does not sign in to GoHighLevel, Cal.com, Google Calendar or Calendly on the founder's behalf for this job. It walks the founder through the clicks, in plain words, and once they say the link exists, checks the public page resolves with the `booking-reviews-checker` agent.

**Reviews.** Needs a Google Business Profile that is claimed and verified; Claude cannot verify a Google Business Profile for the founder, since Google's own verification methods (a mailed postcard, or a video call for some categories) require the founder themselves to receive mail or appear on camera. Once the founder has their profile and its review link, Claude checks the link resolves the same way, and can draft review replies once real reviews exist to answer.

**Recording the links.** Neither link is written into a growth-engine file by this pack directly. The booking link belongs in the Founder Brain's Channels section, updated by saying "update my brain," or as the `[booking link]` value in `engines/ops/ghl-values.md`, written by the `ghl-values` skill. This pack tells the founder which of those two is right for their case and hands off, rather than writing a third copy of the link somewhere new.

## Workflows for Launchhouse jobs

### Pick a booking route and connect the link

1. Read the Founder Brain's Channels section for what tool, if any, the founder already uses for booking.
2. If nothing is recorded, ask one question with clickable choices where the tool allows it: **GoHighLevel calendar (Recommended)**, **Cal.com**, **Google Calendar**, **Calendly**, **Something else**. Say the one-line reason for the recommendation from `pack.md`'s "When to pick this route."
3. Walk the founder through the clicks for whichever route they pick, in plain words, using this file's own steps below. Never ask them to run a command or open a terminal.
4. Once the founder says the booking link exists, call `booking-reviews-checker` to fetch the public page and report back whether it resolves to a real booking page (not a 404, not a sign-in wall, not an empty calendar with no availability showing).
5. If it resolves, tell the founder plainly, and ask whether the link goes in the Brain's Channels section ("update my brain") or as `engines/ops/ghl-values.md`'s `[booking link]` value (`ghl-values`, if their ops workflow is already built). Hand off to whichever skill they pick; this pack does not write either file itself.
6. If it does not resolve, say plainly what the checker found (a 404, a login wall, or a page with no bookable time) and ask the founder to fix that one thing before moving on.

**GoHighLevel calendar, the steps:**
- In the account, go to Calendars, then create a calendar (Personal or Standard covers a solo founder; the others are for teams and classes).
- Set availability: the days and hours the founder actually takes calls, plus a buffer between meetings and a minimum notice period so nobody books five minutes from now.
- Turn on the confirmation and reminder messages GoHighLevel offers (email and, if the plan includes SMS, a text) at sensible intervals, for example 24 hours and 2 hours before.
- Open the calendar, click the Share icon, and copy the booking link.

**Cal.com, free plan, the steps:**
- Sign up free, at cal.com.
- Set availability the same way: days, hours, buffer, minimum notice.
- Cal.com's free plan includes unlimited event types and calendars for one user, with email and SMS notifications, so the confirmation and reminder step needs no upgrade.
- Copy the event's booking link from the dashboard.

**Google Calendar appointment schedule, the steps:**
- This needs Google Workspace Business Standard or a Google One Premium plan; a plain personal Gmail account can make one appointment schedule to try it, not more, so check which the founder has before promising more than one.
- In Google Calendar, click Create, then Appointment schedule. Set the title, duration, and available times.
- Click the schedule on the calendar grid, then Copy link.

**Calendly, free plan, the steps:**
- Sign up free, at calendly.com.
- The free plan gives one event type and one calendar connection, so pick the single most important meeting type (usually the Discovery call) rather than trying to cover more than one.
- Set availability the same way.
- Copy the event's scheduling link from the dashboard. Say plainly that there is no webhook or automation on the free plan, so a booking here never reaches GoHighLevel by itself; the founder, or their confirmation email, is the only thing that tells them it happened.

### Set up Google Business Profile and get the review link

1. Ask whether the founder already has a Google Business Profile. If they are not sure, have them search their own business name in Google Search or Maps; if a box with their business appears on the right, it likely already exists and needs claiming rather than creating.
2. **Creating or claiming.** At business.google.com, the founder signs in with the Google account they want to manage the profile from, searches their business name, and either creates a new profile or claims the one that already exists.
3. **Verification.** Google verifies ownership before the profile goes live in search results, most often by mailing a postcard with a 5-digit code to the business address (typically arriving in 5 to 14 days), or for some categories, a video call or video walkthrough proving the founder manages that real location. This step is the founder's own: Claude cannot receive the postcard or appear on the video for them.
4. **Getting the review link.** Once verified, the founder signs into the Google account that manages the profile, searches their business name in Google, and looks for an "Ask for reviews" option, which generates a short shareable link (commonly shaped like `https://g.page/r/<id>/review`). Google discontinued letting businesses create new custom short names for their profile, so an existing short name still works but a new one is not available; the "Ask for reviews" link is the current route and needs no short name.
5. Call `booking-reviews-checker` to fetch the review link and confirm it lands on a working "write a review" page for the right business, not a 404 or a mismatched listing.
6. Tell the founder where the link goes: `engines/ops/ghl-values.md`'s `Review Link` value, pasted over the example link in GoHighLevel's Reputation, Settings, Set Email Templates screen, exactly as `ghl-values` step 7 describes. This pack does not paste it in itself.

### Respond to reviews in the founder's voice

1. Ask the founder to paste in the review text (Claude has no connector to Google Business Profile and cannot read reviews directly).
2. Draft a reply in the founder's captured voice, from the Voice section of the Brain and their own writing in `brain/voice-samples/`. A short, specific, genuine reply beats a template: thank them for the specific thing they mentioned, and if it is a complaint, acknowledge it plainly and say what happens next, never argue in public.
3. Never write or suggest a reply that invents a fact about the interaction the founder did not give you (a name, a date, a fix that was not actually made).
4. Show the founder the draft and let them paste it in themselves at business.google.com or the Google Maps app; this pack has no tool that posts a reply for them.

## Limits and gotchas

- **Booking-reviews-checker only reads a public page.** It cannot see inside the founder's calendar or their Google Business Profile dashboard, only what a stranger following the link would see. A link that resolves to a real page is not the same as availability actually being open; if the checker reports a page with no bookable slots, say so plainly.
- **Calendly's free plan has no webhook.** A booking there never reaches Hub, GoHighLevel, or any other tool automatically. If the founder wants a booking to move a CRM stage or trigger a workflow, GoHighLevel's own calendar or Cal.com (whose free plan does include webhooks) is the honest recommendation over Calendly free.
- **Google Calendar's appointment schedule needs a paid Google plan** for more than the one trial schedule. Do not promise a founder on a plain personal Gmail account that they can set up more than one.
- **Verification timing.** The postcard route can take 5 to 14 days to arrive. If a founder is close to a session date and has not started verification, say so plainly and suggest they start it immediately, since nothing here can speed up the mail.
- **The review link only exists once the profile is verified.** Do not write copy that references a review link before the founder confirms verification is complete.
- **This pack never asks for, gates, or buys a review**, however the founder phrases the request. See Never, below.

## Failure modes and fixes

| Symptom | Cause | Fix |
|---|---|---|
| `booking-reviews-checker` reports a 404 on the booking link | The founder copied the wrong link, or the calendar was deleted or renamed after the link was copied | Have the founder re-open their calendar tool, re-copy the link from the Share option, and check again |
| `booking-reviews-checker` reports a sign-in wall instead of a public page | The link copied was an internal editing link, not the public share link | In GoHighLevel, use the Share icon's link, not the browser address bar; in Cal.com, Google Calendar or Calendly, use the explicit "copy link" or "share" action, not the dashboard URL |
| The booking page loads but shows no available times | Availability was never set, or every slot is already booked out past the minimum notice window | Ask the founder to open their calendar tool and check the availability settings and existing bookings |
| The review link 404s | The founder is not yet verified, so Google has not generated an "Ask for reviews" link yet | Confirm verification status at business.google.com before trying again |
| The review link resolves but to the wrong business | Two profiles exist for the same address (a common duplicate-listing problem), and the wrong one got verified | Tell the founder to search Google Business Profile Help's guidance on duplicate listings, or flag it for a mentor; this pack does not merge or remove listings |
| A founder asks Claude to post a review reply directly | This pack has no connector to Google Business Profile | Draft the reply, and have the founder paste it in themselves; never claim this was posted |
| A founder asks for the review count to go in a post or email | The Brain may not record a real, checked number | Only use a figure that is in the Brain's Proof section with a checked date; otherwise write the ask around the specific work done for that customer instead of a count |

## Rules that apply here

The six rules in the root `CLAUDE.md` bind this pack directly, and two of them are the whole reason it exists in its current, narrow shape:

- **Rule 5, never invent proof,** governs every review reply and every mention of a review count: only a figure the Brain records, checked and dated, is ever used, and a reply never claims a fact about the interaction the founder did not actually give.
- **Rule 6, the voice is the founder's,** governs every review reply this pack drafts: from the Brain's Voice section and `brain/voice-samples/`, never generic customer-service language.
- Where the booking route is GoHighLevel, `../../../references/connections.md`'s shared connector rules apply in full; this file does not restate them.

## Never

- Never write, edit, buy, gate, or incentivise a review, in any wording a founder asks for it in (see the evals below for the shapes this refusal takes).
- Never claim a review count, a star rating, or "join our happy customers" figure the Brain does not hold, checked and dated.
- Never post a reply to a review, or anything else, to Google Business Profile directly; there is no connector for it, and the founder always does the posting.
- Never verify, claim, or merge a Google Business Profile listing on the founder's behalf; verification is the founder's own step.
- Never promise a booking on the free Calendly plan will reach GoHighLevel or any other tool automatically.
- Never write the booking or review link into any file other than the Founder Brain's Channels section or `engines/ops/ghl-values.md`, whichever the founder's own workflow step calls for.

## Sources

- HighLevel Support, Getting Started: Setup a Booking Calendar: <https://help.gohighlevel.com/support/solutions/articles/155000005061-getting-started-setup-a-booking-calendar> (checked 2026-09-22)
- Cal.com, Pricing: <https://cal.com/pricing> (checked 2026-09-22)
- Google Calendar Help, Create an appointment schedule: <https://support.google.com/calendar/answer/10729749> (checked 2026-09-22)
- Google Calendar Help, Share your appointment schedule: <https://support.google.com/calendar/answer/10733297> (checked 2026-09-22)
- Calendly, Pricing: <https://calendly.com/pricing> (checked 2026-09-22)
- Google Business Profile Help, Verify your business on Google: <https://support.google.com/business/answer/7107242> (checked 2026-09-22)
- Google Business Profile Help community, How do I create a short URL: <https://support.google.com/business/thread/169872666/how-do-i-create-a-short-url> (checked 2026-09-22)
- Federal Trade Commission, Federal Trade Commission Announces Final Rule Banning Fake Reviews and Testimonials: <https://www.ftc.gov/news-events/news/press-releases/2024/08/federal-trade-commission-announces-final-rule-banning-fake-reviews-testimonials> (checked 2026-09-22)
- Federal Register, Trade Regulation Rule on the Use of Consumer Reviews and Testimonials: <https://www.federalregister.gov/documents/2024/08/22/2024-18519/trade-regulation-rule-on-the-use-of-consumer-reviews-and-testimonials> (checked 2026-09-22)

## Refreshing this pack

Re-check every source above still resolves and still says what this file claims, especially the FTC rule's effective date and the free-plan limits for Cal.com, Google Calendar and Calendly, which vendors change without notice. Run `sh .claude/scripts/skill-packs.sh --validate booking-reviews`. Update `verified_on` in `pack.md` once done.
