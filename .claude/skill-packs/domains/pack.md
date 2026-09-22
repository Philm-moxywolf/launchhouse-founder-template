---
id: domains
name: Domains and DNS
kind: guide
skills: [domains-expert, domains-website]
agents: [domains-checker, domains-specialist]
scripts: [dns-check.sh]
connectors: [cloudflare]
vendor_url: https://developers.cloudflare.com
tracks: both
jobs: [check a domain's DNS, connect a work mailbox's SPF/DKIM/DMARC, set up Apollo's tracking domain, set up GoHighLevel's dedicated sending domain, verify a domain in Resend, choose and set up a website, make a Cloudflare DNS change with a yes]
job_skills: [domains-expert, domains-website]
specialist: domains-specialist
expert_skill: domains-expert
inventory_source: documented
verified_on: 2026-09-22
origin: template
---

## What it is for here

Every founder needs one thing DNS decides for them without asking: does their work email land in the inbox or the spam folder, and does their domain point at the things they are building (GoHighLevel funnels, a website, Apollo's tracking, Resend's automations). This pack makes Claude useful on all of it without a terminal: it explains where DNS actually lives for a founder's domain, checks what is missing with `dns-check.sh`, gives click-by-click steps for their own registrar, and, only when the founder has connected Cloudflare, can make the change itself after a clear yes. It never buys a domain and never moves nameservers without saying what breaks first.

## When to pick this route

There is no alternative to DNS itself; every route below ends at the same records. The choice is who clicks:

- **Guided (default).** Claude runs `dns-check.sh`, says exactly what is missing, and gives the founder click-by-click steps for their own registrar. Costs nothing, works for every founder, and is the only route when Cloudflare is not connected or the domain is not on Cloudflare's nameservers.
- **Done for them.** Once the founder has DNS on Cloudflare and has connected Cloudflare (the official connector, OAuth) with permission to edit DNS, `domains-specialist` can add the exact records after showing them and getting a yes. Saves the founder the clicking, at the cost of handing Claude write access to their DNS, which some founders will not want even where it is possible.
- **A secondary "campaign" sending domain** for cold outreach is its own small decision inside this pack (see `knowledge.md`, Workflows): at 25 messages the authenticated main domain is enough, and a second domain is a real cost and weeks of warm-up, not a shortcut.

## Connecting

Nothing has to be connected for the guided route: `dns-check.sh` reads public DNS over HTTPS, the same way anyone on the internet can. Cloudflare only needs connecting for the done-for-them route or for Cloudflare Pages, and it connects as a Claude account connector like GoHighLevel and Apollo do, from Settings, then Connectors, with the founder's own yes to the scopes it asks for. This pack never assumes Cloudflare is connected; `domains-expert` checks first every time.

## In Cowork

No Launchhouse hooks run in Cowork, so `mcp-guard.sh` never sees a Cloudflare call there. The guided route (`dns-check.sh`, read-only) needs no guard at all. If Cloudflare is connected in Cowork, set any DNS write tool it offers to **Needs approval** in Settings, then Connectors, or the same equivalent Cloudflare's own connector screen offers; if Cowork's settings show no per-tool choice, say plainly that Cowork carries no Launchhouse guard here and the founder's own yes in chat is the only check before any record changes.

## Changing this pack

Founders and their Claude edit `.claude/skill-packs/domains/policy.local.tsv`, never `policy.tsv`. A local row may only add a `deny` or `ask`, never loosen a decision `policy.tsv` or `mcp-guard.sh` already reaches. Everything else here (`skills/`, `agents/`, `references/`, `scripts/dns-check.sh`) is edited directly in the pack's own folder; `sh .claude/scripts/skill-packs.sh --install domains` brings the installed copies back in line.
