# Domains and DNS — knowledge (guide pack)

## Mental model

A domain is a name the founder owns (bought from a **registrar**: GoDaddy, Namecheap, Cloudflare, Squarespace Domains, Porkbun, IONOS, and others). DNS is the phone book that says where that name points: mail servers (MX), which servers are allowed to send mail as that domain (SPF), a signature proving mail really came from that domain (DKIM), a policy for what to do with mail that fails both (DMARC), and which server answers when someone visits the domain in a browser (A, AAAA or CNAME).

**Three things can be true independently, and founders conflate them:**
1. **Who the domain is registered with** (the registrar, who gets paid to renew it).
2. **Who hosts the DNS** (the nameservers: often the registrar, sometimes Cloudflare, sometimes GoHighLevel or Squarespace if the whole site lives there). This is the one that decides who can make a change and how.
3. **Where the work mailbox lives** (Google Workspace or Microsoft 365) — a separate account from both of the above, that DNS has to be told about.

A founder can have all three in one place (bought the domain and hosts DNS at GoDaddy, mailbox at Google Workspace) or split across three logins. The first job in any conversation is working out which is which, because the click path depends entirely on where DNS lives, not on where the domain was bought.

**Subdomains matter.** `mail.example.com`, `mg.example.com`, `track.example.com` are all separate names DNS can point differently from the root `example.com`. GoHighLevel's sending domain and Apollo's tracking domain are both subdomains on purpose, so a problem with one never touches the root domain's own mail or site.

## What Claude can do and what it needs first

**Always available, no connection needed:** `dns-check.sh` reads any domain's public DNS records over HTTPS (DNS-over-HTTPS, the same protocol a browser's own DNS-over-HTTPS setting uses) and reports what is missing. This needs nothing from the founder except the domain name.

**Needs the Founder Brain first,** only for the workflows that write into `growth-engine/` (recording that domain setup evidence, deciding on a secondary sending domain): read `brain/founder-brain.md` for the Track and the work email provider in Channels before offering those.

**Needs a decision only the founder can make, before any route starts:**
- Which registrar they use, and whether they can log in to it right now (guided route needs this).
- Whether they want Claude to make DNS changes directly, which needs Cloudflare connected with DNS edit permission (done-for-them route). Most founders will not have this, and that is fine: the guided route works for everyone.
- Whether they want a website at all, and which option (see `domains-website` skill) if they have none.

**Needs Cloudflare connected, with DNS edit permission,** only for: the done-for-them route, and Cloudflare Pages (a website option). Check by looking for tools whose names plausibly belong to a Cloudflare connector before ever proposing this route; if none are there, stay on the guided route and say so.

## Workflows for Launchhouse jobs

### Check a domain's DNS

1. Ask the domain (and, for outreach, whether they use Google or Microsoft 365 for their work email — the Brain's Channels section usually already has this).
2. Call `domains-checker` with the domain and provider. It runs `dns-check.sh <domain> --mailbox <provider>` and returns the parsed result.
3. Report what is missing in plain words, grouped by what it affects: "your email will land in spam because there's no DKIM record yet", not "dkim=fail".
4. Offer the guided route: click-by-click steps for their registrar (below). Offer the done-for-them route only if Cloudflare is connected and the domain's nameservers are Cloudflare's own.
5. On request, re-run the check and say what changed.

### Connect a work mailbox's SPF, DKIM, DMARC (Google Workspace or Microsoft 365)

Order matters: SPF and DKIM first, both authenticating for at least 24 to 48 hours, then DMARC starting at `p=none` (monitor only, never a founder's mail blocked by it) before ever moving to `quarantine` or `reject`. Never propose starting straight at `p=reject`; a founder blocking their own mail because of one wrong record is a worse outcome than mail sitting in this state a few weeks longer.

**Google Workspace**
- **MX** (only if Workspace hosts their mail): a single record, host `@`, points to `smtp.google.com`, priority `1` (the current recommended single-record setup). The older five-record set (`ASPMX.L.GOOGLE.COM` priority 1, `ALT1`/`ALT2.ASPMX.L.GOOGLE.COM` priority 5, `ALT3`/`ALT4.ASPMX.L.GOOGLE.COM` priority 10) still works if that is what is already there; never remove a working legacy set just to "modernize" it without the founder asking.
- **SPF**: one TXT record, host `@`, value `v=spf1 include:_spf.google.com ~all` if Google Workspace is the only sender. If Apollo, GoHighLevel's LC Email, or anything else also sends as this domain, add its own `include:` to the *same* single SPF record rather than creating a second one — a domain must never have two SPF TXT records (see Failure modes).
- **DKIM**: generated per domain inside Google Admin console (Apps, then Google Workspace, then Gmail, then Authenticate email), which gives a TXT record at a selector such as `google._domainkey`, value starting `v=DKIM1; k=rsa; p=...`. Turn DKIM signing on in the Admin console only after the record is confirmed live.
- **DMARC**: TXT record at `_dmarc`, start with `v=DMARC1; p=none; rua=mailto:<an address the founder reads>`. SPF has up to 10 `include:` lookups before it breaks (see Limits).

**Microsoft 365** (documented against Microsoft Learn, checked 2026-09-22)
- **MX**: host `@`, points to the tenant's own `<tenant>.mail.protection.outlook.com`, priority `0`.
- **Autodiscover CNAME**: host `autodiscover`, points to `autodiscover.outlook.com`. Optional but strongly recommended; without it, Outlook clients cannot auto-configure.
- **SPF**: TXT record, host `@`, value `v=spf1 include:spf.protection.outlook.com -all`. If an SPF record already exists (from a previous provider, or from Apollo/GoHighLevel), add `include:spf.protection.outlook.com` into that *same* record rather than creating a second one.
- **DKIM**: two CNAME records, hosts `selector1._domainkey` and `selector2._domainkey`, each pointing to a value the Microsoft 365 admin center displays once DKIM is enabled for the domain (Defender portal, or the domain's DNS records page). Optional but recommended.
- **DMARC**: TXT record at `_dmarc`, start with `v=DMARC1; p=none; rua=mailto:<an address the founder reads>`, then step through `p=quarantine` and `p=reject`, each with a monitoring period, using `pct=` to ramp gradually (`pct=10`, `25`, `50`, `75`, `100`) rather than jumping straight to 100% enforcement.

**Either provider:** never remove an existing MX record for the other provider without the founder confirming mail has fully moved; if the domain is switching providers, either delete the old MX or make sure the new one has a lower (higher-priority) number.

### Set up Apollo's tracking domain

Apollo's tracking subdomain routes open and click tracking pixels so they never touch the founder's main site. In Apollo: Settings, then Team email & sequences, then Tracking Subdomains, then Create Subdomain. Apollo recommends a short, brand-friendly name (`track.example.com` or `go.example.com`), never special characters or numbers. Apollo can add the CNAME automatically if the founder authorizes it against their registrar, or the founder copies one CNAME record by hand. Propagation: 2 to 24 hours (Apollo's own stated range). `dns-check.sh --apollo-tracking <host>` confirms the CNAME resolves once it is live.

### Set up GoHighLevel's dedicated sending domain (LC Email)

In GoHighLevel: Settings, then Email Services, then Dedicated Domain and IP, then Add Domain. GoHighLevel generates the exact records for that founder's account (5 total, documented as 2 TXT, 2 MX, 1 CNAME, but the exact values are generated per account and never the same twice, so never invent them — always read them from what GoHighLevel's own screen shows). Use a subdomain never used for anything else, such as `mg.example.com` — never the same subdomain used for Google Workspace or Microsoft 365 mail, since LC Email's own MX records would then conflict with the mailbox's MX records on the same name. Propagation: minutes typically, up to 24 to 48 hours. Warm up a brand-new sending domain before any large send.

GoHighLevel's own website, funnel and calendar custom domains are a separate setup, at Settings, then Domains, then Add Domain: usually one CNAME record on the chosen subdomain, occasionally an A record if GoHighLevel's own instructions for that account specifically say so (never assume A over CNAME). If the domain's DNS is on Cloudflare, the CNAME's proxy status must be **DNS only** (grey cloud, not orange) or GoHighLevel's own SSL certificate issuance can fail.

### Verify a domain in Resend

Resend is for the founder's own opted-in automations only (see `docs/free-stack-design.md`: Resend's Acceptable Use Policy prohibits cold outreach, so Resend is never the route for the 25 cold messages). In Resend: Domains, then Add Domain, on a sending subdomain such as `send.example.com` (Resend's own default pattern). Resend generates an MX record (for bounces), an SPF TXT record, and a DKIM TXT record at `resend._domainkey`; it verifies with just those three, DMARC is not required for verification but is still worth adding at `p=none` to start. Propagation: up to 24 hours. `dns-check.sh --resend` checks the `resend._domainkey` TXT record.

### Choose and set up a website, if the founder has none

See the `domains-website` skill for the full decision and the DNS each option needs.

### A secondary "campaign" sending domain for cold outreach — the honest trade-off

At 25 messages (rule 3), the founder's authenticated main domain, with SPF, DKIM and DMARC in place, is enough. A second domain is a real decision with real costs, not a free upgrade:
- **Cost**: the domain itself (typically $10 to $20/year, more for some TLDs), the founder's own purchase, never Claude's.
- **Its own SPF, DKIM and DMARC**, set up exactly like the main domain, from nothing.
- **A redirect to the main site**, so a prospect who clicks through lands somewhere real.
- **2 to 4 weeks of warm-up** (sending small, increasing volumes) before it can carry real cold volume without landing in spam, which is longer than most founders will send their first 25 messages over.

Only bring this up if the founder specifically asks about "reputation risk" to their main domain, or already sends high volume from it for other things. Otherwise say plainly that at 25 messages it is not worth the cost or the wait.

## Limits and gotchas

- **SPF: exactly one record per domain, ever.** Two SPF TXT records on the same name is worse than none: mail systems reject or ignore both (`permerror`). Every new sender's include has to be merged into the single existing SPF record, never added as a second one. `dns-check.sh` flags a second SPF record as a fail, not a warn.
- **SPF: 10 DNS lookups max.** Each `include:`, `a`, `mx`, `ptr`, `exists` and `redirect` mechanism costs one lookup, and nested includes count too. Past 10, SPF fails to evaluate (`permerror`) even though it looks fine to read. `dns-check.sh` counts `include:` occurrences as an approximation and warns above that count; it cannot follow nested includes, so a warning here is a prompt to check by hand, not a precise count.
- **DNS propagation** is genuinely up to 24 to 48 hours for any provider, sometimes faster. Never tell a founder something is broken minutes after they saved a record; say to check back later, and offer to re-run the check.
- **DMARC alignment** (`aspf`/`adkim`) defaults to relaxed, which is right for almost every founder here; strict alignment breaks legitimate subdomain senders (GoHighLevel, Apollo, Resend all sending as subdomains) unless each one is set up with care. Never propose strict alignment unless the founder specifically asks and understands the trade-off.
- **DKIM selectors are provider-specific** and cannot be guessed reliably: Google uses `google._domainkey` by default but a founder can pick a different one; Microsoft 365 uses `selector1._domainkey` and `selector2._domainkey`; Resend uses `resend._domainkey`. `dns-check.sh` checks the selector for the provider the founder names.
- **Cloudflare proxy (orange cloud) breaks other providers' SSL.** GoHighLevel, and most site builders, need their DNS records set to **DNS only** (grey cloud) in Cloudflare, not proxied, or their own certificate issuance fails.
- **Bulk sender rules (Google, Yahoo, Microsoft, 2026):** senders of 5,000+ messages a day to one of these providers must have SPF, DKIM and DMARC (at least `p=none`) or mail can be rejected outright. A Launchhouse founder's 25 messages, or 30 pieces of content, sits nowhere near this threshold; mention it only if a founder asks about scaling outreach well past the programme's own numbers.
- **A domain's nameservers, not its registrar, decide who can edit DNS.** A domain bought at GoDaddy but pointed at Cloudflare's nameservers has its real DNS control at Cloudflare, not GoDaddy; check nameservers before assuming where a change has to be made.

## Failure modes and fixes

| Symptom | Cause | Fix |
|---|---|---|
| Outreach emails land in spam or promotions | Missing or broken SPF, DKIM or DMARC on the sending domain | Run `dns-check.sh --mailbox <provider>`, add whichever of SPF/DKIM/DMARC is missing, wait for propagation, re-check |
| SPF fails even though a record exists | Two SPF TXT records on the same name (`permerror`) | Merge both `v=spf1 ...` records into one, keeping every `include:` from both, delete the duplicate |
| Emails "look fine" but still fail SPF for one sender | More than 10 DNS lookups in the SPF chain | Remove an unused `include:`, or ask that sender for a "flattened" SPF value with fewer lookups |
| GoHighLevel sending domain never goes green | The chosen subdomain also carries the mailbox's own MX records, so LC Email's MX records conflict | Move LC Email to an unused subdomain (for example `mg.` instead of reusing `mail.`) |
| GoHighLevel funnel or site shows an SSL error after connecting the domain | The CNAME is proxied (orange cloud) in Cloudflare | Set that one record to **DNS only** (grey cloud) in Cloudflare, leave the rest of the domain's proxy settings alone |
| A DNS change was saved but `dns-check.sh` still shows it missing | Normal propagation delay, up to 24 to 48 hours | Wait, then re-run the check; if still missing after 48 hours, re-check the record was saved on the right name and the right zone |
| DMARC set to `p=reject` immediately blocks legitimate mail | Skipped the `p=none` monitoring period, or SPF/DKIM were not both correctly aligned first | Drop back to `p=none`, monitor aggregate reports for at least a week or two, then step through `quarantine` before `reject` |
| Apollo tracking subdomain never verifies | CNAME points to the wrong target, or was added on the wrong subdomain | Re-check the exact value Apollo's own screen shows for that subdomain, re-add it exactly, re-check |
| A founder's whole site goes down after a DNS change | An existing A or CNAME record for the root or `www` was deleted or overwritten by mistake | Never delete or replace an existing record without naming what it does and confirming with the founder first; if it happened, restore the original value from the registrar's own change history if it has one |

## Rules that apply here

The six rules bind this pack the same as every other: **rule 5** (never invent proof) means never state a specific record value for GoHighLevel's LC Email or Apollo's tracking CNAME as if it is fixed, since both are generated per account; always say "read the exact value from your own GoHighLevel/Apollo screen." **Rule 6** (the founder's own voice) does not apply to DNS technical steps, but the plain-words explanation of what is missing and why does. See `../../../references/connections.md` for how any Cloudflare connector call is checked: a plain read is silent, and any DNS write this pack's `domains-specialist` proposes is shown to the founder and confirmed before it runs, granted through the same two-phase, grant-script protocol every other specialist in this project uses (the grant script is named in `domains-specialist.md`).

## Never

- Never buy a domain, a website plan, or anything else. The founder buys; Claude shows the cost and the click path.
- Never move a domain's nameservers without naming, in plain words, what can stop working if the existing records are not copied across first (usually: email).
- Never delete or replace an existing DNS record without saying exactly what it does and getting a clear yes; this applies doubly to an MX or SPF record, since a mistake there can take down a founder's whole mailbox.
- Never invent a DNS record value for a tool that generates one per account (GoHighLevel's LC Email, Apollo's tracking CNAME, a DKIM public key). Always say to read it from that tool's own screen.
- Never propose Resend for the 25 cold outreach messages. Resend's own Acceptable Use Policy prohibits cold outreach; the manual Gmail/Outlook drafts route or Apollo (`connections.md`) is what the 25 use.
- Never claim a DNS change has taken effect before `dns-check.sh` (or the founder's own check) confirms it; propagation is real and takes real time.
- Never make a live Cloudflare DNS change without the founder having seen the exact records (type, name, value, TTL) and said yes.

## Sources

- Set up SPF | Google Workspace: <https://knowledge.workspace.google.com/admin/security/set-up-spf> (checked 2026-09-22)
- Set up DKIM | Google Workspace: <https://support.google.com/a/answer/174124> (checked 2026-09-22)
- Set up DMARC | Google Workspace: <https://support.google.com/a/answer/10032674> (checked 2026-09-22)
- Google Workspace MX record setup: <https://knowledge.workspace.google.com/kb/how-to-update-your-mx-records-to-work-with-gmail-000005563> (checked 2026-09-22, unverified: current single-record `smtp.google.com` value cross-checked via secondary sources, not fetched directly from Google's own MX page)
- Connect your domain by adding DNS records — Microsoft 365 admin | Microsoft Learn: <https://learn.microsoft.com/en-us/microsoft-365/admin/get-help-with-domains/create-dns-records-at-any-dns-hosting-provider> (checked 2026-09-22, page dated 2026-04-23/2026-08-20)
- Set up DMARC to validate email in Microsoft 365 | Microsoft Learn: <https://learn.microsoft.com/en-us/defender-office-365/email-authentication-dmarc-configure> (checked 2026-09-22, page dated 2026-07-03/2026-07-17)
- Set Up a Custom Tracking Subdomain — Apollo: <https://knowledge.apollo.io/hc/en-us/articles/4415240542733-Set-Up-a-Custom-Tracking-Subdomain> (checked 2026-09-22)
- How to Set Up a Dedicated Sending Domain (LC Email) — HighLevel Support: <https://help.gohighlevel.com/support/solutions/articles/48001226115-dedicated-email-sending-domains-overview-setup> (checked 2026-09-22, exact record values confirmed generated per account, not published as fixed values)
- How to set up Root Domain/Subdomain for your Funnels/Websites — HighLevel Support: <https://help.gohighlevel.com/support/solutions/articles/48001153720-how-to-set-up-root-domain-subdomain-for-your-funnels-websites-> (checked 2026-09-22, unverified: summarized via secondary sources, not fetched directly)
- Implementing DMARC — Resend: <https://resend.com/docs/dashboard/domains/dmarc> (checked 2026-09-22, unverified: DKIM selector and MX-for-bounces summarized via secondary sources, not fetched directly)
- Resend Acceptable Use Policy: <https://resend.com/legal/acceptable-use> (checked 2026-09-22, quoted in `docs/free-stack-design.md`)
- Custom domains · Cloudflare Pages docs: <https://developers.cloudflare.com/pages/configuration/custom-domains/> (checked 2026-09-22)
- Cloudflare Workers platform limits: <https://developers.cloudflare.com/workers/platform/limits/> (checked 2026-09-22, referenced from `docs/free-stack-design.md`)
- Bulk Email Sender Rules For Google, Yahoo, Microsoft & Apple (2026), PowerDMARC: <https://powerdmarc.com/bulk-email-sender-requirements/> (checked 2026-09-22, third-party summary of vendor policy, not Google's own page directly; treat the 5,000/day threshold and `p=none` minimum as (unverified) against Google's own current wording)

## Refreshing this pack

Re-check every source above still resolves and still says what this file claims, especially anything Google, Microsoft, Apollo, GoHighLevel or Resend can change without notice (record values, thresholds, selectors). Re-run `dns-check.sh` against a real domain to confirm the parsing still matches each provider's current DNS-over-HTTPS response shape. Run `sh .claude/scripts/skill-packs.sh --validate domains` and `sh .claude/scripts/skill-packs.sh --test domains`. Update `verified_on` in `pack.md` once done.
