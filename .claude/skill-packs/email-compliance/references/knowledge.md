# Email compliance — knowledge (guide pack)

**This is guidance, not legal advice.** It is a plain-words summary of rules that change, and that apply differently depending on where the founder and their recipients are. A founder with a real question about their own exposure, a borderline case, or a jurisdiction not covered here should ask a lawyer, not this pack.

## Mental model

Every email this project sends is one of exactly two kinds, and the rules that bind it depend on which kind it is:

- **Cold.** The 25 B2B touches, sent by hand from the founder's own mailbox, to people who have never heard from the founder and never asked to. No consent exists yet, by definition, until someone replies. CAN-SPAM applies to every one of these in the US; CASL and PECR/GDPR apply too, if any recipient is in Canada, the UK, or the EU, and each of those regimes treats a first, unsolicited business email differently, covered below.
- **Opted-in.** Everything else: the GoHighLevel workflow follow-ups (Lead follow-up, Discovery booking, Proposal chase, Review request) that a snapshot sends to someone who already gave the founder their email, by filling in a form, booking a call, or becoming a customer. These need a real record of how and when consent was given, not just an assumption that a form submission counts everywhere.

Two more things sit underneath both kinds, because they are not about the message's wording, they are about the pipes it travels through and the list it goes to:

- **Deliverability rules from the inbox providers themselves.** Google and Yahoo do not wait for a complaint; they refuse or spam-folder mail from senders who fail their bulk-sender requirements. This binds every sender crossing their volume threshold, cold or opted-in.
- **List hygiene.** Every regime here assumes the list is real: people the founder found and can name a reason for reaching, never a purchased or scraped list. `outreach-b2b`'s own build-to-35-cut-to-25 process already does this; this pack checks the result, it does not build the list.

## What Claude can do and what it needs first

Needs a written file to check against: `engines/outreach/outreach-sequence.md`, `engines/audience/inbound-scripts.md`, `engines/ops/ops-workflow.md`, `engines/ops/ghl-values.md`, or any other automation copy a skill has written. It also needs the Founder Brain, for the postal address and for the Track. Claude reports what it finds; it never rewrites another skill's file itself. The skill that owns the file (`outreach-b2b`, `ghl-workflows`, `ghl-values`, `publish-content`) makes the actual fix, because those are the skills that know the copy's full context and the founder's yes.

## Workflows for Launchhouse jobs

### Check the outreach sequence and automation copy for compliance

1. Read the file (or files) the caller names.
2. Read the Founder Brain for the founder's postal address (Channels or a dedicated field, wherever it is recorded) and the Track.
3. Call `email-compliance-reviewer` to do the actual read-only check. It reports, per touch or per message: whether an opt-out or unsubscribe line is present, whether a postal address is present (from the Brain) or missing, whether the subject line is honest about the content, and whether any claim in the copy looks invented rather than sourced from the Brain.
4. Show the founder the report in plain words: what passed, what needs a fix, and where. Never fix the copy in this pack; say which skill (`outreach-b2b`, `ghl-workflows`, `ghl-values`) owns the file and route them there.
5. If asked, answer the "why" behind any flagged item straight from this file's own sections below.

### Answer a compliance question

Answer from this file's Mental model, and the specific regime section under Workflows below, citing the Sources list. If the question is about the founder's own legal exposure rather than what this project's own copy looks like, say plainly this is guidance, not legal advice, and suggest a lawyer.

### Record a suppression

1. When the founder says someone asked to stop (an opt-out reply, a "remove me," a bounce that looks permanent), find that person's file in `growth-engine/people/`.
2. Set their `status` to `stopped` (B2B prospect) per the contract's status list, and add a touch line: `- YYYY-MM-DD <email|dm> in: asked to stop`, plus a note line recording it as a suppression: `- YYYY-MM-DD suppression: asked to be removed, honour within [the regime's own window, see below]`.
3. Tell the founder plainly that this person must not receive another touch, on any list, on this or a future campaign, and remind them the touch log and note line are the record if it is ever asked about.
4. This pack writes nothing else; the person file update is the whole action.

## Regimes, in plain words

**US, CAN-SPAM.** Applies to every commercial email sent from or to the US, cold or opted-in, B2B or B2C. Requirements: accurate "From," "To," and routing headers; a subject line that is not deceptive; the message identified as an ad where its content is promotional; the sender's valid physical postal address in the message; a clear and conspicuous opt-out mechanism; and every opt-out honoured within 10 business days. Penalty: up to $53,088 per separate email in violation, and the FTC has brought real cases at that scale (a $2.95 million fine against Verkada in 2024).

**Canada, CASL.** Applies to any commercial electronic message sent to a recipient in Canada. Needs consent, sender identification, and an unsubscribe mechanism in every message. B2B messages get a real but limited exemption: implied consent exists where there is an existing business relationship from a transaction within the last two years, or where the recipient has conspicuously published their own address as relevant to their role (a business card, a "contact us" page naming them). A cold email to a Canadian business contact whose address was only ever found in an Apollo-style database, with no prior relationship and no publicly conspicuous business reason to expect it, does not automatically clear this bar; treat it the same as any other cold touch and make sure it carries the opt-out line and identification CAN-SPAM already requires. Penalties run to CAD $10,000,000 for an organization.

**UK and EU, PECR and GDPR.** PECR's consent rule for marketing email does not apply to a "corporate subscriber," meaning a UK or EU company's own general business address, so a B2B cold email to a company address is not blocked by PECR's consent requirement the way a consumer email would be. But GDPR still applies underneath it, because a named individual's work email is still personal data: the founder needs a GDPR lawful basis, most often legitimate interest, which the ICO says can support B2B marketing when the message is genuinely relevant to that person's role. Legitimate interest is not a free pass; the ICO expects it to be considered and, where used at any real volume, recorded (a short legitimate interests assessment: why this message, why this person, why no alternative). A right to object (an opt-out) must be offered regardless of which lawful basis is used.

**Google and Yahoo, bulk sender requirements.** Since February 2024, any sender pushing more than 5,000 emails a day to Gmail or Yahoo Mail addresses must: authenticate with SPF, DKIM, and DMARC (DMARC at minimum policy `p=none`); support one-click unsubscribe (an `RFC 8058` `List-Unsubscribe` header with a URL, not only a mailto link); honour an unsubscribe within two days; and keep spam complaint rates under 0.3%, with under 0.1% recommended. The 25 cold touches, and most opted-in follow-up volumes at this stage of a founder's business, sit well under the 5,000-a-day threshold, so this specific rule set does not bind them directly yet. It still matters for two reasons: first, `outreach-b2b`'s own deliverability brief already requires SPF, DKIM, and DMARC regardless of volume, because inboxes filter on authentication long before the bulk-sender threshold; second, a founder whose GoHighLevel automations grow past 5,000 a day (unlikely at this stage, but worth naming) crosses into this rule set for real and needs one-click unsubscribe on every bulk message from that point on.

## Limits and gotchas

- **This file is not a jurisdiction map.** It covers the US, Canada, the UK, and the EU because those are the geographies this programme's founders and their prospects are most likely to sit in. A founder targeting recipients elsewhere (Australia's Spam Act, for instance) needs guidance this pack does not have; say so plainly rather than guessing.
- **CASL's B2B exemption is narrower than founders assume.** "It's a business email" is not itself the exemption; the exemption needs an actual existing relationship or a conspicuously published address tied to the person's role. Do not wave a Canadian recipient through as B2B-exempt without checking which condition actually applies.
- **PECR's corporate-subscriber carve-out is a UK/EU-specific fact, not a general B2B exemption.** It does not apply in the US or Canada, and it does not remove the GDPR lawful-basis requirement underneath it.
- **A bounce is not automatically a suppression.** A single soft bounce can be temporary. Only a hard bounce, or an explicit stop request, gets recorded as a suppression per the Record a suppression workflow above.
- **`email-compliance-reviewer` only reads what is in `growth-engine/`.** It cannot see what actually left the founder's mailbox, only what was drafted. A founder who edits an email by hand after the check, in their own Gmail draft, needs to run the check again or accept it is unverified past that point.

## Failure modes and fixes

| Symptom | Cause | Fix |
|---|---|---|
| `email-compliance-reviewer` flags "no opt-out line" on every touch | `outreach-b2b`'s sequence was written before this pack existed, or a touch was edited afterward without re-adding the line | Route to `outreach-b2b` to add the plain-language opt-out sentence to the flagged touch, per its own Step 2 rule |
| "No postal address" flagged, but the founder has one in the Brain | The Brain's address field is missing, in the wrong section, or the copy step never pulled it in | Check the Brain's Channels section (or wherever the founder's address is recorded); if missing, ask the founder for it and record it there, then re-run the check |
| A flagged claim turns out to be true | The copy stated a real figure or fact, but with no dated, checked entry in the Brain's Proof section backing it | Have the founder confirm the figure and date it in the Brain's Proof section (`- <figure>, checked by me on YYYY-MM-DD`), then re-run the check; a true but unrecorded claim still fails this check on purpose, since the record is what makes it checkable later |
| Founder asks "can I just buy a list and email it" | A purchased or scraped list is not something any regime here treats kindly, and it is also outside what `outreach-b2b`'s own list-building process produces | Refuse. Say plainly a purchased or scraped list is out of scope for this project on every regime this file covers, and point back to `outreach-b2b`'s own list-building steps |
| A GoHighLevel automation email sends with the word PLACEHOLDER still in the postal address line | `ghl-values` step 7's pasting step was skipped or the address line was never filled | Route to `ghl-values`; this pack only checks drafted copy in `growth-engine/`, not what is live in the account |
| Founder wants to keep emailing someone who said stop | Same as any other suppression request; the ten-business-day CAN-SPAM clock, and the general expectation under CASL and GDPR/PECR, all point the same way | Refuse to help draft or send anything further to that person; record the suppression per the workflow above and remind the founder this is not optional under any of the regimes this file covers |

## Rules that apply here

The six rules in the root `CLAUDE.md` bind this pack directly:

- **Rule 3, B2B outreach is 25 messages,** is the volume ceiling that keeps the cold touches well under the Google/Yahoo bulk-sender threshold; this pack does not raise or lower that number, only checks the copy sent at it.
- **Rule 5, never invent proof,** is enforced here specifically as "no claim without a dated, checked Brain entry," which is stricter than any regime in this file requires, on purpose.
- **Rule 6, the voice is the founder's,** is not weakened by any compliance requirement here: an opt-out line or a postal address still has to read like the founder wrote it, not like a boilerplate legal footer pasted on top.

## Never

- Never advise skipping the opt-out line, on any touch, for any reason a founder gives.
- Never advise using a purchased, scraped, or otherwise non-consensual list.
- Never advise hiding that a message is promotional, or writing a subject line that misrepresents the content.
- Never advise continuing to email someone who has asked to stop, on any list, under any framing ("just this once," "it's a different campaign").
- Never state a jurisdiction's rule as more permissive than this file's own sourced summary, or invent a rule this file does not cover; say plainly when a question falls outside this pack's scope.
- Never claim this pack's guidance is a substitute for a lawyer's advice on the founder's own specific exposure.

## Sources

- Federal Trade Commission, CAN-SPAM Act: A Compliance Guide for Business: <https://www.ftc.gov/business-guidance/resources/can-spam-act-compliance-guide-business> (checked 2026-09-22)
- Federal Trade Commission, Complying with the CAN-SPAM Act (full guide PDF): <https://www.ftc.gov/media/71413> (checked 2026-09-22)
- CRTC, Canada's Anti-Spam Legislation, Guidance on Implied Consent: <https://crtc.gc.ca/eng/com500/guide.htm> (checked 2026-09-22)
- CRTC, Frequently Asked Questions about Canada's Anti-Spam Legislation: <https://crtc.gc.ca/eng/com500/faq500.htm> (checked 2026-09-22)
- Innovation, Science and Economic Development Canada, Getting consent to send email: <https://ised-isde.canada.ca/site/canada-anti-spam-legislation/en/getting-consent-send-email> (checked 2026-09-22)
- ICO, Business-to-business marketing: <https://ico.org.uk/for-organisations/direct-marketing-and-privacy-and-electronic-communications/business-to-business-marketing/> (checked 2026-09-22)
- ICO, Sending direct marketing: Choosing your lawful basis: <https://ico.org.uk/for-organisations/direct-marketing-and-privacy-and-electronic-communications/sending-direct-marketing-choosing-your-lawful-basis/> (checked 2026-09-22)
- Google Workspace Admin Help / Resend, Gmail and Yahoo's bulk sending requirements for 2024: <https://resend.com/blog/gmail-and-yahoo-bulk-sending-requirements-for-2024> (checked 2026-09-22)
- docs/free-stack-design.md, section 4, "Why Resend never touches the cold 25," citing Resend's Acceptable Use Policy: <https://resend.com/legal/acceptable-use> (checked 2026-09-22)

## Refreshing this pack

Re-check every source above still resolves and still says what this file claims, especially the CAN-SPAM penalty figure (it adjusts for inflation) and the Google/Yahoo spam-rate and volume thresholds, which the providers can change without notice. Run `sh .claude/scripts/skill-packs.sh --validate email-compliance`. Update `verified_on` in `pack.md` once done.
