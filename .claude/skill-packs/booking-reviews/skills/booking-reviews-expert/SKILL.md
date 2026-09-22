---
name: booking-reviews-expert
description: Expert on getting a working booking link and a working Google review link, and on answering reviews once they arrive. Trigger on "booking link", "set up my calendar", "Cal.com", "Calendly", "Google Business Profile", "my review link", "respond to a review", "we got a review", or when another pack needs a booking or review link and nothing here yet knows how to get one.
---

# Booking and reviews expert

1. Read `.claude/skill-packs/booking-reviews/pack.md` and `.claude/skill-packs/booking-reviews/references/knowledge.md` before doing anything else.
2. There is no connection to check. This pack calls no connector; it reads the Founder Brain, walks the founder through clicks in their own browser, and checks a public page.
3. Route the founder's request:

| Founder asks for | Use |
|---|---|
| A booking link, or to pick or change the booking route | this skill, "Pick a booking route and connect the link" in `references/knowledge.md` |
| A Google Business Profile, or a review link | this skill, "Set up Google Business Profile and get the review link" |
| A reply to a real review | this skill, "Respond to reviews in the founder's voice" |
| The booking link recorded somewhere | the `founder-brain` skill ("update my brain") for the Channels section, or the `ghl-values` skill for the `[booking link]` custom value, whichever the founder's own setup calls for |
| The review link pasted into the GoHighLevel snapshot | the `ghl-values` skill, which pastes it into the Review Link field per its own Step 7 |

4. **Checking a link.** Once the founder says a booking or review link exists, call the `booking-reviews-checker` agent with the exact link. It only reads the public page; no grant or approval dance is needed, since it calls no connector tool and changes nothing. Report back plainly what it found.
5. **Reviews are never written, incentivised, or gated by Claude.** If a founder asks for any of that, however it is phrased, refuse in one plain line and say why, per `references/knowledge.md`'s Never section. Offer the honest alternative (real review request copy, sent to real customers) instead of arguing the point twice.
6. Answer "how does X work" questions straight from `references/knowledge.md`. If today is past the pack's `verified_on` date, say the knowledge may be out of date, especially free-plan limits, which vendors change without notice, and offer to refresh it.
