---
id: instagram-setup
name: Instagram setup
kind: guide
skills: [instagram-setup-expert, instagram-setup-profile]
agents: [instagram-setup-checker]
scripts: []
connectors: [ghl]
tracks: b2c
jobs: [switch to a professional account, link to a Facebook Page, turn on two-factor, GoHighLevel Instagram connection, ManyChat or Composio prerequisites, check it worked, profile basics in the founder's voice]
job_skills: [connect-tools, audience-b2c, publish-content]
origin: template
verified_on: 2026-09-22
---

## What it is for here

A B2C founder's Instagram has to be a Professional account, linked to a Facebook Page, before GoHighLevel's Social Planner can post to it or read its statistics, and before the audience engine's comment-to-DM and inbound scripts have anywhere to run. This pack gets that account into the right shape and helps write its bio, link-in-bio and highlights from the Founder Brain, in the founder's own voice, for them to paste in themselves. It never touches the account itself: every click here is the founder's own.

## When to pick this route

There is no tool route to any of this. Switching account type, linking a Facebook Page, and turning on two-factor authentication are all account-security actions Instagram only accepts from the account owner, signed in themselves, in the Instagram app or on instagram.com (see `../../references/social-accounts.md`). This pack's only job is to make those few minutes count: the right choice between Business and Creator for this founder, the right Facebook Page, and profile copy that is already written and ready to paste once they get there. A founder who has already done this once (an existing Professional account, already linked) skips straight to the profile-copy step.

## Connecting

Nothing in this pack connects on its own. It reads two things that connect elsewhere: the Founder Brain (`growth-engine/brain/founder-brain.md`, for the profile copy) and, once GoHighLevel is connected (`connect-tools`), GoHighLevel's own Social Planner accounts list, to check the Instagram connection actually took. If GoHighLevel is not connected yet, the check step asks the founder directly instead of guessing.

## In Cowork

No hooks run there, and this pack calls no write tool of its own; the one read it makes (GoHighLevel's accounts list) is a plain read, so there is nothing to set to "Needs approval" for this pack specifically. If GoHighLevel itself is connected in Cowork, that connector's own approval setting still governs everything else `publish-content` and `audience-b2c` do there, as documented in the `ghl` pack.

## Changing this pack

Founders edit `.claude/skill-packs/instagram-setup/policy.local.tsv` if they ever add one; there is no `policy.tsv` in this pack today because it calls no connector tool of its own beyond the plain GoHighLevel read above, already governed by the `ghl` pack. Everything else here (`skills/`, `agents/`, `references/`) is edited directly in this pack's own folder, and Launchhouse re-installs the skills and agent from here.
