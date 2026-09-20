---
name: connect-tools
description: Connect GoHighLevel, and for B2B founders Apollo and their mailbox, to the founder's Claude account and prove each connection works by reading their own account back to them. Records where each connection stands, and sets the tool permissions that keep sending and buying in the founder's hands. Trigger on "connect GoHighLevel", "connect Apollo", "connect my email", "connect Gmail", "connect Outlook", "connect my tools", "is GoHighLevel connected", "check my connections", or before publishing or building a sequence when nothing is connected.
---

# Connect the tools

GoHighLevel publishes the founder's posts and holds their contacts. For B2B founders only, Apollo finds people and builds the sequence, and the mailbox holds drafts of their outreach emails. Each one is a **connector**: a connection that lets Claude use the tool on their behalf, on their own account.

How each one connects, and the rules for using it, are in `../../references/connections.md`. Read it first. GoHighLevel, Apollo and the mailbox all connect by signing in. Only if GoHighLevel's sign-in does not work on a computer does the founder fall back to a key in their computer's own password store: the Keychain on a Mac, Credential Manager on a Windows PC. Nothing is pasted into the chat, and no key is ever written into any file.

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

Ask: "Can you log in to GoHighLevel?" The programme buys the Starter plan in Session 2. The answers are predictable, so ask with clickable choices (the AskUserQuestion tool): **Yes**, **Not yet**, **Not sure**. It adds a box for any other answer. If you cannot show choices, as in Cowork, ask the same question in plain text.
- **If not yet:** record `GoHighLevel connector | not started | <date> | not bought yet`. Say plainly that it was due in Session 2. The clinic loads their snapshot into it, so it is needed before then. Give the one next step: buy the Starter plan now, as Session 2 set out, then say "connect my tools" again. If they are unsure how, send them to the Slack channel. Stop this part until then.
- **If they are not sure:** tell them to look in their inbox for an email from GoHighLevel with a login link. If there is nothing, they have not bought it yet, so follow the step above.

### Is it connected

Look at the tools available to you. The account connector gives six general tools: `list_locations`, `search_operations`, `describe_operation`, `execute_operation`, `search` and `fetch`. The fallback gives one tool per job, with names ending in things like `locations_get-location`. Either means it is connected. `../../references/connections.md` explains both.

**If there are none,** walk them through connecting it. This is the main route, and it is a sign-in, not a key.

1. In the Claude app, open **Settings**, then **Connectors**.
2. Choose **Add custom connector**.
3. Name it `HighLevel`.
4. For the URL, paste `https://services.leadconnectorhq.com/mcp/anthropic/v2`.
5. Click **Add**, then **Connect**.
6. Sign in to GoHighLevel in the window that opens.
7. Pick their business's sub-account.
8. Approve what it asks for.
9. Start a new conversation in this folder, then say "check my connections".

**The free Claude plan connects one custom connector.** That is all GoHighLevel needs, so never tell a founder on the free plan they must upgrade to connect it. A paid plan allows more than one, if they connect other custom connectors later.

**Set the permission once.** If their Connectors screen shows a choice for each tool, set `execute_operation` to **Needs approval**. If it doesn't, leave the default, which asks. Never say the choice is definitely there: some screens show it, some don't.

This connection works the same way in Code, Cowork, the browser and on their phone. Nothing about GoHighLevel is Code-only any more.

One later step sits outside this connection. The snapshot's custom values are filled by hand in GoHighLevel, or optionally with a separate key the founder makes and deletes themselves. That is `/growth-engine:values`: the words are written before the clinic and pasted in once the snapshot loads, and it changes nothing here.

### If signing in does not work on this computer

This is the fallback, and it only works in Code. It needs a key from their GoHighLevel account, which only they make and keep. Say why first: the key is a password for their business's GoHighLevel, so it goes in their computer's own password store, where the computer keeps its other saved passwords. It is never in a file, Claude never sees it, and GitHub never sees it.

1. **Make the key.** In GoHighLevel, open the business's **sub-account**, not the agency. Go to **Settings**, then **Private Integrations**, then **Create New Integration**. Name it "Claude Launchhouse". Tick View Locations, View Contacts, View and Edit Conversations, View and Edit Conversation Messages, and every Social Planner permission. Create it and copy the key. It is shown only once. If it gets lost before step 3, delete that integration and make another.
2. **Find the Location ID.** In the same sub-account, go to **Settings**, then **Business Profile**, and find the **Location ID**. They copy it in step 3.
3. **Put both in the password store.** The name must be exactly `Launchhouse GoHighLevel`, with that capital L, G and H and one space.
   - **On a Mac, in Keychain Access:**
     1. Press Command and Space, type **Keychain Access**, and press Return.
     2. In the list on the left, choose **login**.
     3. From the **File** menu, choose **New Password Item**.
     4. In **Keychain Item Name**, type `Launchhouse GoHighLevel`.
     5. In **Account Name**, paste the Location ID.
     6. In **Password**, paste the key.
     7. Click **Add**.
   - **On a Windows PC, in Credential Manager:**
     1. Press the Windows key, type **Credential Manager**, and open it.
     2. Choose **Windows Credentials**.
     3. Click **Add a generic credential**.
     4. In **Internet or network address**, type `Launchhouse GoHighLevel`.
     5. In **User name**, paste the Location ID.
     6. In **Password**, paste the key.
     7. Click **OK**.
4. **Check it and connect.** When they say it is added, tell them first: on a Mac, a box will ask whether to let "security" use the item. They type their Mac password and click **Always Allow**, so the connection can read it each time the app opens. Then run `sh .claude/scripts/ghl-headers.sh --connect < /dev/null`. It says only whether the item is there and in the right shape, never what is in it, and when all is right it writes this folder's connection, `.mcp.json`, pointing at the same address as the connector. Tell them what it found in plain words, and fix one thing at a time. To look without connecting, use `--check` in place of `--connect`.
5. **Reopen.** Ask them to quit the Claude app, open it again, and open this folder. If it asks whether to use the **highlevel** server from this folder, they say yes. Then they say "check my connections".

**In Cowork,** this fallback never runs. If this is Cowork, or the check says it works on a Mac or a Windows PC only, stop this part, say in one plain sentence that this fallback is for Code only, and go back to the connector steps above.

**If both are connected,** the founder sees GoHighLevel's tools twice. Prefer the connector. Tell them plainly, and run `sh .claude/scripts/ghl-headers.sh --disconnect < /dev/null` to remove the fallback connection. It removes only the `.mcp.json` this folder wrote, never the key in their password store.

Never ask for the key in the chat, never read the password store yourself, and follow "If signing in does not work on this computer" in `../../references/connections.md`.

**How long the key lasts.** GoHighLevel's help pages say the key does not expire on its own. It stops working when it is deleted or rotated. GoHighLevel recommends rotating it every 90 days. Say this once, plainly, and never promise a date. To change it, they make or rotate the key in Private Integrations, then open the same item and paste the new key over the old password. In Keychain Access that is a double click on the item, then **Show password**. In Credential Manager it is the item's arrow, then **Edit**.

If they are still stuck, record `needs a hand` and send them to the Slack channel.

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

**The approval setting.** Ask with clickable choices (the AskUserQuestion tool): "Does GoHighLevel ask you before it posts or sends?" **Yes**, **No**, **Not sure**. Record `GoHighLevel approval setting | <their answer> | <date> | asked directly` in `growth-engine/.state/setup.md`. If the answer is No, walk them back to the connector's tool settings and set `execute_operation` to **Needs approval**, if that choice is there.

**When a check fails,** say the likely cause in plain words, and give one next step:

| What happened | Say |
|---|---|
| No GoHighLevel tools after connecting | Disconnect and connect again, from inside a chat: open Settings, then Connectors, disconnect **HighLevel**, then repeat the steps above. Starting a new conversation afterwards often clears it on its own. |
| No GoHighLevel tools after reopening (fallback) | Run step 4 again, which checks the item and writes the connection again. If both are right, the app did not start the connection: ask them to quit and reopen the app once more, and say yes if it asks about **highlevel**. The same fixes it if the folder has moved. |
| Not authorised | The key is wrong, was deleted, or was made in the agency, not the sub-account. Make a new key in the sub-account and paste it as the item's password. |
| The key stopped working | It worked before and now does not. Someone deleted or rotated it in Private Integrations, since it does not run out on its own. Make a new key there, or rotate it, paste it as the item's password in place of the old one, and reopen the app. |
| Wrong location | The connection works, but for a different sub-account. Copy the Location ID from the business's own sub-account into the item's account name (Mac) or user name (Windows). |
| A permission refused | The key is missing that permission. In Private Integrations, edit the integration, tick it, and save. |
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
- Only needed on the Apollo route. If `engines/outreach/outreach-sequence.md` records the manual route, record `not needed yet`.

**Never call an enrichment tool to test the connection.** Enrichment spends credits.

**Refusals**
- **Not allowed:** either the plan does not carry that feature yet, or the connection needs signing in again. Try reconnecting first.
- **Too many requests, or no answer:** wait a minute and try again.

### Domain authentication

There is no tool that reads SPF, DKIM and DMARC here. Ask whether Apollo, or their domain provider, shows all three as set. Record the answer as a gate answer, not as setup evidence:

`- <date> gate C, domain set up and sending started: <their answer>`

## 3. The mailbox, B2B only

Skip this whole section for B2C.

The mailbox lets Claude put the founder's outreach emails into their own drafts folder, so they read each one and press Send, instead of copying and pasting. It also lets Claude see who has replied, and mark them in their person file. Claude never sends from it.

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
- The Microsoft 365 check has not yet been tried on a real account. If its search cannot show the address, record `in progress` with what it did return, and say so plainly.

## 4. Tool permissions

**The Launchhouse checks already, in this folder:**
- stop Apollo sending, starting a sequence, or buying a mailbox, and stop sending, replying, forwarding or setting mail rules in the mailbox
- ask the founder every time before a GoHighLevel reply is sent, a post goes out, a contact is changed, a mailbox draft is written, credits are spent, or people are added to a sequence

**Their connector settings can do the same for Apollo and the mailbox everywhere, including Cowork on other folders.** If the Connectors settings let them choose per tool, suggest:

| Setting | Tools |
|---|---|
| **Never allow** | Apollo `apollo_emailer_messages_send_now`, `apollo_emailer_campaigns_approve`, `apollo_email_account_purchase_create`, and Gmail `send_message`, `reply`, `forward` and `create_filter` |
| **Ask each time** | Gmail `create_draft` and `update_draft`, and anything that creates, edits or adds, including Apollo `apollo_sequences_create` and `apollo_sequences_update`, which could switch a sequence on, and Apollo enrichment (`apollo_people_match`, `apollo_people_bulk_match`), which spends credits |
| **Always allow** | tools that only read |

If their settings do not offer this, say the Launchhouse checks cover it in this folder, and move on.

## 5. Save and hand on

1. Run `git add growth-engine/.state` and `git commit -m "Checked connections"`. Push if there is a remote.
2. Tell them in two lines what is connected and what is not.
3. The next step is usually:
   - `/growth-engine:publish` for approved content
   - or, for B2B on the Apollo route, `/growth-engine:sequence`
   - or, for B2B on the manual route with Gmail connected, putting the 25 outreach emails into their drafts, which is "put my outreach emails in my drafts"
   - or, for B2B once emails have gone out with a mailbox connected, "check for replies"

Then tell them, once, that if a connection stops working later they can say "something is not working".

A founder who brought work across from the app can now ask Claude to check that imported work against what these accounts actually show.

## Connect a source

Separately from GoHighLevel, Apollo and the mailbox, the engines can offer to look in a founder's own files, notes, cloud storage or email instead of asking them to type an answer from memory. That offer, and how to check what is already connected, add one, and use it safely, is in `../../references/sources.md`. It is a different kind of connection, read-only and only ever used after a yes, so it is not part of the setup above.
