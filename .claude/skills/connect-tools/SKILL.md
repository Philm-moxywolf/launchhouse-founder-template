---
name: connect-tools
description: Connect GoHighLevel, and for B2B founders Apollo and their mailbox, to the founder's Claude account and prove each connection works by reading their own account back to them. Records where each connection stands, and sets the tool permissions that keep sending and buying in the founder's hands. Trigger on "connect GoHighLevel", "connect Apollo", "connect my email", "connect Gmail", "connect Outlook", "connect my tools", "is GoHighLevel connected", "check my connections", or before publishing or building a sequence when nothing is connected.
---

# Connect the tools

GoHighLevel publishes the founder's posts and holds their contacts. For B2B founders only, Apollo finds people and builds the sequence, and the mailbox holds drafts of their outreach emails. Each one is a **connector**: a connection that lets Claude use the tool on their behalf, on their own account.

How each one connects, and the rules for using it, are in `../../references/connections.md`. Read it first. Every connection is made by signing in. Nothing is pasted, and no key is ever written into any file in this folder.

**The doubt to name first.** Connecting a tool to Claude sounds like handing over the keys. So say what it can and cannot do here:
- Claude can read, and it can create drafts and paused sequences when the founder says yes.
- It cannot start an Apollo sequence, send from Apollo, or buy anything. The Launchhouse checks stop those.
- It can reply to someone who messaged them first in GoHighLevel, but only after showing the founder the reply and getting a yes. A first message to someone who has not written is always sent by hand.
- In their mailbox it only writes drafts. It never sends. The founder presses Send.

**Who is reading.** A founder who does not use a terminal. Never ask them to run a command.

**Dates.** Every programme date comes from the cohort block in `../../references/gates.md`. Take today's date from the founder's own computer. Once a date in that block has passed, do not announce it as though it is still ahead: say "your clinic session" or "the Saturday of your programme" instead.

Each check writes a row in `growth-engine/.state/setup.md`, in the shape in `../../references/contract.md`. **Evidence is only ever what the tool returned**, never what the founder said.

## 0. Before starting

1. **Check the folder.** Read the session context. If it says this is not the founder folder, stop and tell them which folder to open.
2. **Read the track** from the Brain. Apollo is B2B only. A B2C founder never sees an Apollo step, and not seeing one is correct. If there is no Brain, or it has no Track line yet, do not stop and never ask which track they are on. Say in one sentence that GoHighLevel is the same for everyone, so it can be checked now, and that the rest waits until their Founder Brain is built. Do section 1 without its B2C-only Instagram check, skip sections 2 and 3, then offer to build the Brain now (`/growth-engine:brain`, or "build my founder brain"), and tell them that saying "connect my tools" afterwards finishes the job.
3. **Check what is done.** Read `growth-engine/.state/setup.md` if it exists. Skip what is already done unless they asked to check again.

## 1. GoHighLevel

### Do they have it

Ask: "Can you log in to GoHighLevel?" The programme buys the Starter plan in Session 2.
- **If not yet:** record `GoHighLevel connector | not started | <date> | not bought yet`. Say plainly that it was due in Session 2. The clinic loads their snapshot into it, so it is needed before then. Give the one next step: buy the Starter plan now, as Session 2 set out, then say "connect my tools" again. If they are unsure how, send them to the Slack channel. Stop this part until then.
- **If they are not sure:** tell them to look in their inbox for an email from GoHighLevel with a login link. If there is nothing, they have not bought it yet, so follow the step above.

### Is it connected

Look at the tools available to you. GoHighLevel's tools come in two shapes, both listed in `../../references/connections.md`: general tools such as `list_locations` and `execute_operation`, or tools with names ending in things like `locations_get-location`.

**If there are none,** walk them through connecting it. GoHighLevel is a connector on their Claude account: they sign in, and the connection itself needs nothing pasted.

One later step sits outside the connector. The snapshot's custom values are filled by hand in GoHighLevel, or optionally with a key the founder makes and deletes themselves. That is `/growth-engine:values`: the words are written before the clinic and pasted in once the snapshot loads, and it changes nothing here.

1. In the Claude desktop app, open **Settings**, then **Connectors**.
2. Find **HighLevel** and connect it. It opens GoHighLevel's sign-in.
3. Sign in, and choose the business's **sub-account** when asked, not the agency. A connection made at agency level does not reach their business.
4. If the sign-in lists permissions to grant, accept what it asks for.

**If HighLevel is not in the list,** follow GoHighLevel's own guide, which is kept current: https://help.gohighlevel.com/support/solutions/articles/155000005741-how-to-setup-and-use-the-highlevel-mcp-server. If they are still stuck after that, record `needs a hand` and send them to the Slack channel.

Never ask for a key or token in the chat, and follow "No keys, ever" in `../../references/connections.md`.

When they have connected it, the new tools may need a fresh conversation to appear. If you still cannot see them, ask them to start a new conversation in this folder and say "check my connections".

### Prove it

Do not tick a box. Read their own account back to them, which a broken connection cannot fake. For each job below, use the tool that `../../references/connections.md` names for it.

**Location**
- Read back the business.
- Say: "Connected to <location name>. Is that your business?"
- Record `GoHighLevel connector | done | <date> | read back location: <name>`.

**Accounts to post to**
- Read the accounts to post to.
- Name each connected account and its platform.
- Record `GoHighLevel accounts to post to | done | <date> | <platform: name, ...>`.
- If the list is empty, the connection works but nothing is connected to post to. Tell them: in GoHighLevel, open Social Planner and connect their Facebook Page, and their Instagram for B2C, then say "check again". Record `in progress`.

**Contacts**
- Read one contact.
- Say contacts are readable. Never show a contact's details.
- Record `GoHighLevel contacts | done | <date> | contacts readable`.

**B2C only: Instagram**
- If an Instagram account appears in the accounts list, record `Instagram Business or Creator | done | <date> | Instagram connected in Social Planner: <name>`. GoHighLevel only connects Business or Creator accounts.
- If there is none, remind them to convert Instagram to Business or Creator and link it to a Facebook Page. Record `not started`.

**When a check fails,** say the likely cause in plain words, and give one next step:

| What happened | Say |
|---|---|
| Not authorised | The connection has lapsed or was made at agency level. Sign in to HighLevel again, and choose the sub-account. |
| Wrong location | The connection works, but for a different sub-account. Reconnect and choose the business's own sub-account. |
| A permission refused | The connection works, but did not get that permission. Reconnect and accept what the sign-in asks for. |
| Too many requests | GoHighLevel is asking us to slow down. Nothing is wrong. Try again in a minute. |
| No answer | That is GoHighLevel's side, not theirs. Try again shortly. |

Record `needs a hand` only when the founder cannot fix it with that step.

## 2. Apollo, B2B only

Skip this whole section for B2C.

### Is it connected

Look for tools whose names end in `apollo_users_api_profile` and `apollo_mixed_people_api_search`.

**If there are none:**

1. In the Claude desktop app, open **Settings**, then **Connectors**.
2. Choose **Browse connectors**, find **Apollo.io** and connect it. It asks them to sign in to Apollo. There is nothing to paste.
3. Start a new conversation in this folder if the tools do not appear.

**The free Apollo plan connects in full.** Never tell a founder they need the paid plan to connect. The 65 USD/month plan buys credits, sending limits and mailboxes, and it is set up with sending in Session 2.

### Prove it

**Account**
- Call the tool ending `apollo_users_api_profile`.
- Say: "Connected to Apollo as <their email>."
- Record `Apollo connector | done | <date> | signed in as <email>`.

**Sending mailbox**
- Call the tool ending `apollo_email_accounts_index`.
- If a mailbox is connected, record `Apollo sending mailbox | done | <date> | <address>`.
- If none is, tell them: in Apollo, open the settings for email accounts and connect the mailbox they will send from, which is a two-minute sign-in. Record `not started`.
- Only needed on the Apollo route. If `outreach-sequence.md` records the manual route, record `not needed yet`.

**Never call an enrichment tool to test the connection.** Enrichment spends credits.

**Refusals**
- **Not allowed:** either the plan does not carry that feature yet, or the connection needs signing in again. Try reconnecting first.
- **Too many requests, or no answer:** wait a minute and try again.

### Domain authentication

There is no tool that reads SPF, DKIM and DMARC here. Ask whether Apollo, or their domain provider, shows all three as set. Record the answer as a gate answer, not as setup evidence:

`- <date> gate C, domain set up and sending started: <their answer>`

## 3. The mailbox, B2B only

Skip this whole section for B2C.

The mailbox lets Claude put the founder's outreach emails into their own drafts folder, so they read each one and press Send, instead of copying and pasting. Claude never sends from it.

### Which mailbox

Read the work email provider in the Brain's Channels section. Do not ask again if it is there.
- **Google** (Gmail or Google Workspace): the connector is **Gmail**.
- **Microsoft 365:** the connector is **Microsoft 365**.
- **Anything else, or nothing recorded:** ask once what they open their work email in. If it is neither, there is no mailbox connector for it. Record `Mailbox connector | not needed yet | <date> | work email is on <provider>` and move on. They send by hand, which is already their route.

### Is it connected

Look for the connector's tools: for Gmail, tools whose names end in `create_draft` and `search_threads`; for Microsoft 365, tools whose names end in `outlook_email_search`.

**If there are none:**
1. In the Claude desktop app, open **Settings**, then **Connectors**.
2. Choose **Browse connectors**, find **Gmail** or **Microsoft 365**, and connect it.
3. Sign in with their **work** email account, and accept what it asks for. There is nothing to paste.
4. On Microsoft 365, if it says an administrator must approve, that is whoever set up their Microsoft 365, often the founder themselves.
5. Start a new conversation in this folder if the tools do not appear.

### Prove it

- Search their sent mail for one message, and read back only the address it was sent from. Never show anyone else's details.
- Say: "Connected to the mailbox <address>. Is that your work email?"
- Record `Mailbox connector | done | <date> | <Gmail or Microsoft 365>, read back address: <address>`.
- If the address is not their work email, they signed in with the wrong account. Tell them to disconnect it in Settings, Connectors, and connect again with the work account.
- On Microsoft 365, say plainly that this connector reads mail but cannot write drafts, so the 25 go by hand from each person's file.

## 4. Tool permissions

**The Launchhouse checks already, in this folder:**
- stop Apollo sending, starting a sequence, or buying a mailbox, and stop sending, replying or forwarding from the mailbox
- ask the founder every time before a GoHighLevel reply is sent, a post goes out, a mailbox draft is written, credits are spent, or people are added to a sequence

**Their connector settings can do the same everywhere, including Cowork on other folders.** If the Connectors settings let them choose per tool, suggest:

| Setting | Tools |
|---|---|
| **Never allow** | Apollo `apollo_emailer_messages_send_now`, `apollo_emailer_campaigns_approve`, `apollo_email_account_purchase_create`, and Gmail `send_message`, `reply` and `forward` |
| **Ask each time** | GoHighLevel `conversations_send-a-new-message` and `execute_operation`, Gmail `create_draft` and `update_draft`, and anything that creates, edits or adds, including Apollo `apollo_sequences_create` and `apollo_sequences_update`, which could switch a sequence on, and Apollo enrichment (`apollo_people_match`, `apollo_people_bulk_match`), which spends credits |
| **Always allow** | tools that only read |

If their settings do not offer this, say the Launchhouse checks cover it in this folder, and move on.

## 5. Save and hand on

1. Run `git add growth-engine/.state` and `git commit -m "Checked connections"`. Push if there is a remote.
2. Tell them in two lines what is connected and what is not.
3. The next step is usually:
   - `/growth-engine:publish` for approved content
   - or, for B2B on the Apollo route, `/growth-engine:sequence`
   - or, for B2B on the manual route with Gmail connected, putting the 25 outreach emails into their drafts, which is "put my outreach emails in my drafts"

Then tell them, once, that if a connection stops working later they can say "something is not working".
