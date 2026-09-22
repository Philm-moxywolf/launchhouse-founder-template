---
id: email-compliance
name: Email compliance
kind: guide
skills: [email-compliance-expert]
agents: [email-compliance-reviewer]
scripts: []
connectors: []
tracks: both
jobs: [check the outreach sequence and automation copy for compliance, answer a compliance question, record a suppression]
job_skills: []
specialist: email-compliance-reviewer
expert_skill: email-compliance-expert
verified_on: 2026-09-22
origin: template
---

## What it is for here

Every email this project sends, the 25 cold B2B touches sent by hand and the opted-in follow-ups a GoHighLevel workflow sends later, has to meet the same handful of real rules: US CAN-SPAM, Canada's CASL, UK and EU PECR and GDPR, and the bulk-sender rules Google and Yahoo now enforce on inboxes themselves. This pack is the founder's plain-words guide to those rules, and a read-only check on what has actually been written, before it goes out rather than after a complaint arrives. It never sends anything, and it never edits another skill's file; it reports what it finds and the fix, and leaves the writing to the skill that owns the file.

## When to pick this route

There is no alternative route: this is guidance and a check, not a tool with a paid tier to weigh against a free one. Use it whenever outreach copy is written or changed (after `outreach-b2b`), whenever automation copy is written or changed (after `ghl-workflows` or `ghl-values`), and before `publish-content` sends anything that looks like a bulk or automated email. It costs nothing and takes a few seconds to run.

## Connecting

Nothing to connect. This pack reads files already in `growth-engine/` and the Founder Brain; it calls no connector tool.

## In Cowork

No hooks run there, and this pack calls no connector, so there is nothing to set to Needs approval for this pack specifically. The founder's own review of what `email-compliance-reviewer` reports is what actually catches a problem in Cowork, the same as everywhere else, since this pack changes nothing on its own.

## Changing this pack

Founders edit `policy.local.tsv` in this pack's folder if they ever add one; this pack ships with no `policy.tsv`, since none of its skills or agents call a connector tool that needs an extra rule. Everything else, `skills/`, `agents/`, `references/`, is edited directly in the pack's own folder, and Launchhouse re-installs the skills and agents from here, never the other way around.
