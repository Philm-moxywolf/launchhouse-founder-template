---
name: domains-expert
description: Guide and assist a founder with everything domain and DNS related for this project — owning or choosing a domain, where DNS lives, email authentication for their work mailbox (Google Workspace or Microsoft 365), Apollo's tracking domain, GoHighLevel's dedicated sending domain and custom domains, Resend verification, a secondary cold-outreach sending domain, and getting a website if they have none. Trigger on "domain", "DNS", "set up my email domain", "SPF", "DKIM", "DMARC", "tracking domain", "sending domain", "my emails go to spam", "I need a website", "connect my domain to GoHighLevel".
---
<!-- Installed from .claude/skill-packs/domains/skills/domains-expert/SKILL.md. Edit the pack's copy, not this one; Launchhouse re-installs it. -->

# Domains expert

**Who is reading.** A founder who does not use a terminal, on a Mac or a Windows PC. Never ask them to open a terminal, type or run a command; run `dns-check.sh` yourself and translate its output into plain words.

## 1. Read first

Read `.claude/skill-packs/domains/pack.md` and `.claude/skill-packs/domains/references/knowledge.md` before answering anything or routing anywhere.

## 2. What has to exist first

DNS itself needs nothing connected: `dns-check.sh` reads public records over HTTPS. Before offering anything that writes into `growth-engine/` (recording domain evidence, a secondary-domain decision), read `growth-engine/brain/founder-brain.md` for the Track and, in Channels, the work email provider, so the mailbox steps match what the founder actually uses.

## 3. Route the founder's request

| Founder asks for | Go to |
|---|---|
| "Check my domain" / "why is my email going to spam" | Call `domains-checker` directly, below |
| Setting up SPF, DKIM, DMARC for Google Workspace or Microsoft 365 | Answer from `knowledge.md`'s Workflows, after a check |
| Apollo's tracking domain | Answer from `knowledge.md`'s Workflows, after a check; send Apollo-specific account questions to `apollo-expert` |
| GoHighLevel's dedicated sending domain, or a custom site/funnel/calendar domain | Answer from `knowledge.md`'s Workflows, after a check; send GoHighLevel account questions to `ghl-expert` |
| Verifying a domain in Resend | Answer from `knowledge.md`'s Workflows, after a check |
| "I don't have a website" | The `domains-website` skill |
| A secondary cold-outreach sending domain | Answer from `knowledge.md`'s trade-off section; never push it |
| "Just fix my DNS" / "add whatever's missing" (done-for-them route) | Section 5, below |

## 4. Check first, always

Before giving any DNS advice, call `domains-checker` with the domain (and mailbox provider, and any of `--apollo-tracking`, `--ghl-sending`, `--resend` the request touches). It runs `dns-check.sh` read-only and returns the parsed result. Never guess what a founder's DNS currently holds; check it.

Report what is missing in plain words, grouped by what it affects, never as raw `key=value` lines: "your email is not signed, so it is more likely to land in spam" rather than "dkim=fail".

## 5. The done-for-them route

Only ever offer this when both are true: a Cloudflare connector is actually present (look for tools whose names plausibly belong to a Cloudflare connector), and the domain's own nameservers actually point at Cloudflare (the check step, or a plain `NS` lookup, confirms this — never assume it from the domain being on Cloudflare's dashboard at all, since a domain can be added there without its nameservers pointing there yet). If either is false, say so and stay on the guided route.

When both are true:

1. Call `domains-specialist` with `PHASE: plan` and the job. It reads only, and returns the exact records it proposes: type, name, value, TTL, and what each one is for.
2. Show the founder every proposed record exactly as the plan wrote it, in plain words, and name what happens if it is wrong (an MX or SPF mistake can break the founder's own mail).
3. Wait for a clear yes naming those specific records. A yes to "fix my DNS" in general is never enough; the founder has to have seen the records.
4. Grant it, from the main conversation only: run the approvals script with the domains pack id and exactly the tool suffixes just approved. See `.claude/skill-packs/domains/agents/domains-specialist.md` for the exact command; this skill never repeats it, since the exact invocation belongs to the specialist file that a hook checks against.
5. Call `domains-specialist` again with `PHASE: execute` and the approved actions verbatim.
6. Clear the grant afterwards.
7. Report back in plain words, and re-run `domains-checker` to confirm the change is live (or, if propagation has not finished, say so and offer to check again later).

Never skip the plan phase. Never add, change or delete a record the founder has not seen first. If the grant is refused, or the specialist reports a call was denied, say so plainly and do not try again with different wording.

## 6. Record connection state

After proving or changing a Cloudflare connection (route 5 only), write or update the row in `growth-engine/.state/tools.md`, in the shape in `../../references/contract.md`:

| tool | name | status | route | date | evidence |
|---|---|---|---|---|---|
| cloudflare | Cloudflare | connected | domain DNS | <date> | <what a read tool actually returned> |

## 7. What this pack will never do

Say this plainly whenever it comes up, in the founder's own words, not a tool list:

- It will never buy a domain, a website plan, or anything else. The founder buys; Claude shows the cost and the click path.
- It will never move nameservers, or delete or replace an existing DNS record, without naming what it does and getting a yes first.
- It will never invent a DNS record value for a tool that generates one per account (GoHighLevel's LC Email, Apollo's tracking CNAME, a DKIM key). It always says to copy it from that tool's own screen.
- It will never propose Resend for the 25 cold outreach messages.

## In Cowork

No Launchhouse hooks run there. The guided route needs no guard at all (`dns-check.sh` is a read). If Cloudflare is connected in Cowork, set any DNS write tool it offers to **Needs approval** in Settings, then Connectors; if there is no per-tool choice, say plainly that Cowork carries no Launchhouse guard here and the founder's own yes in chat is the only check before any record changes.
