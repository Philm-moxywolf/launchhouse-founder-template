---
name: domains-website
description: Help a founder with no website choose one and set up its DNS. Trigger on "I don't have a website", "I need a website", "how do I get a website", "which website builder", "GoHighLevel site vs Squarespace", or when another skill finds no live site for the founder's domain.
---

# Choosing and setting up a website

**Who is reading.** A founder who does not use a terminal. Never ask them to open one; run any DNS check yourself.

## 1. Read first

Read `.claude/skill-packs/domains/pack.md` and `.claude/skill-packs/domains/references/knowledge.md`.

## 2. Ask what they actually want

A website choice is a real decision, not a default. Ask, briefly:
- Do they want to edit it themselves later, or have it built and mostly left alone?
- Is a GoHighLevel plan already bought (Session 2, Starter)? If so its own site builder costs nothing extra.
- Do they want something that looks hand-built and branded (a page builder), or is a simple one-pager enough to start?

## 3. The options, with real costs

| Option | Cost | Best for | DNS it needs |
|---|---|---|---|
| GoHighLevel's own site/funnel builder | Included in the plan already bought | A founder who wants everything in one place and does not mind GoHighLevel's own editor | One CNAME (occasionally an A record, only if GoHighLevel's own instructions for that account say so) on the chosen subdomain or root, from GoHighLevel's Domains screen |
| Carrd | Free tier, or about $19/year Pro | A single clean landing page, fast to set up, not much upkeep | A records/CNAME Carrd's own custom-domain screen shows |
| Framer | Free tier (Framer subdomain), roughly $10 to $30/month for a custom domain with more features | A founder who wants a polished, editable site and expects to keep editing it | CNAME Framer's own custom-domain screen shows |
| Squarespace | From about $16/month (billed annually), varies by plan | A founder who wants a well-known, all-in-one builder with support | Depends on whether the domain is bought through Squarespace (nameservers) or elsewhere (A/CNAME records Squarespace's own screen shows) |
| A simple static site Claude builds, deployed to Cloudflare Pages | Free (Cloudflare Pages free tier) | A founder who wants a plain one-pager, is comfortable Claude maintains the code, and either already has Cloudflare connected or is willing to connect it | One CNAME on the chosen subdomain pointing at the project's own `*.pages.dev` address, added either by the founder (guided) or by `domains-specialist` once Cloudflare is connected (done-for-them), and the domain registered as a custom domain inside the Cloudflare Pages project itself — a CNAME alone, without that registration, will not resolve |

Costs above are approximate and change; say so, and point to each vendor's own current pricing page rather than promising an exact figure.

## 4. Building the static option

Only when the founder picks it: build a small static site (their offer, proof, and a way to book or contact them, from the Founder Brain) as plain HTML/CSS, no framework needed for a one-pager. Deploy it to Cloudflare Pages. If Cloudflare is not connected, say plainly this option needs it, and either connect it now or pick a different option. Never invent page content; pull the offer, proof and voice from `brain/founder-brain.md`, and never state a number or claim that is not in `## Proof`.

## 5. DNS, whichever option

Once the founder has picked and set the site up on the vendor's side, call `domains-checker` to confirm the apex and `www` resolve (`dns-check.sh`'s website check). Report plainly whether it is live yet, and that propagation can take up to 24 to 48 hours.

## 6. What this never does

- Never picks the option for the founder without asking what they want.
- Never buys a plan, a domain, or anything else.
- Never claims a site is live before the DNS check (or the founder's own visit to the URL) confirms it.
