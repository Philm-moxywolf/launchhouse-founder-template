# Connections

How the founder's tools reach Claude. `connect-tools` sets them up and proves them. Any skill that uses a tool follows this file.

| Tool | Who | How it connects | Its name |
|---|---|---|---|
| GoHighLevel | everyone | Claude's own connector, signed in from Settings, then Connectors, then Add custom connector. If sign-in does not work on this computer, this folder's own fallback connection instead, in `.mcp.json`, using a key the founder keeps in their computer's own password store | **HighLevel** |
| Apollo | B2B only | Claude's own connector, by signing in | **Apollo.io** |
| The mailbox | B2B only | Claude's own connector, by signing in, chosen from the work email provider in the Brain's Channels section | **Gmail** for Google (Gmail or Google Workspace), **Microsoft 365** for Microsoft 365 |

Nothing else needs connecting. GitHub is GitHub Desktop's job, not a connection.

## How a tool call is checked

One check, `mcp-guard.sh`, runs before every call to a connected tool, on any connector, not only the three above. It is deterministic by the founder's own Claude permission mode, and it only ever adds a note or a prompt on top. It never removes one, and in the mode most founders run in (auto, with no prompts) it never invents a prompt of its own.

- **Refused outright, in every mode:** spending the founder's money (buying, purchasing, checking out), a tool that sends or connects to a real person in bulk or cold (a broadcast, a batch send, a mailbox send or reply or forward, LinkedIn's send or connect), a mail rule, and GoHighLevel's own refused set below.
- **Asks the founder first, even in a mode with no other prompts:** a message actually going out, a calendar change, an Apollo credit spend, and a short named set of GoHighLevel writes (a reply, a social post, an email template, a contact, a deal).
- **Guided, not blocked:** every other write. Claude is told the rule and, when the founder's mode would show no prompt of its own, told to get a yes in chat first, but the call itself is never held up by this check.
- **Silent:** a plain read. Nothing is said.

## GoHighLevel: the connector

The main route is a Claude account connector, named **HighLevel**, at `https://services.leadconnectorhq.com/mcp/anthropic/v2`. It works the same way in Code, Cowork, the browser and on a phone, once it is connected. `connect-tools` walks a founder through adding it.

It gives six tools:

- `list_locations` reads back the business. This is the job that proves the connection.
- `search_operations` finds the right operation for a job, by domain and keyword.
- `describe_operation` reads what that operation needs.
- `execute_operation` runs it, with only the inputs `describe_operation` listed.
- `search` and `fetch` are general-purpose reads.

**Skills never hard-code an operation id.** GoHighLevel's operation names can change. For any job, search for it, read what it needs, then run it with only the inputs it listed.

| Job | Search for | One-per-job tool (fallback shape) |
|---|---|---|
| Read back the business | use `list_locations` directly | `locations_get-location` |
| The accounts to post to | Social Planner accounts | `get-account` |
| Create, edit or read a post | Social Planner post | `create-post`, `edit-post`, `get-post`, `get-posts` |
| How posts did | Social Planner statistics | `get-social-media-statistics` |
| Reply to someone who wrote first | conversations send message | `conversations_send-a-new-message` |
| One contact, to show contacts are readable | contacts search, or get contact | `contacts_get-contacts` |
| Custom values, create or update | custom values | none in this shape; use `ghl-values-api.sh` |

Some connections spell the social tool endings `social-media-posting_` instead of `socialmediaposting_`.

**The rules, in either shape:**
- Before any write, show the founder exactly what will go out, where and when, in their own timezone, and wait for a clear yes.
- A reply only ever goes to someone who wrote first. Read their conversation and check it holds a message from them before replying.
- Never call an operation in Payments, never a delete, and never anything that creates, edits or triggers a workflow. Those stay out of every job a skill does here, whichever shape is connected.

**In Cowork, none of this folder's checks run.** The guard that is left is the founder's own connector setting: `execute_operation` set to **Needs approval** in Settings, then Connectors. `connect-tools` sets it when it connects GoHighLevel, and asks the founder to confirm it is still that way when they say "check my connections".

## If signing in does not work on this computer

This is the fallback, and it is Code only: it never runs in Cowork.

**The GoHighLevel key lives in one place only:** the computer's own password store, never a file. On a Mac that is the Keychain, and on a Windows PC it is Credential Manager. The item is named exactly `Launchhouse GoHighLevel`. Its account name (Mac) or user name (Windows) is the Location ID, and its password is the key. The founder adds it themselves, by clicking, as `connect-tools` sets out. Claude Code reads it when it connects, through `.claude/scripts/ghl-headers.sh`, which gives it only to GoHighLevel's own address, `https://services.leadconnectorhq.com/mcp/anthropic/v2`.

**The connection file.** `.mcp.json`, at the top of this folder, is not shipped. `sh .claude/scripts/ghl-headers.sh --connect < /dev/null` writes it once the key checks out. It holds GoHighLevel's address and this computer's own path to the helper, never the key. Git ignores it, because the path belongs to this computer, and another computer connects by saying "connect my tools" there.

- Never ask for a key, token or password in the chat, and never write one into any file, in this folder or anywhere else.
- Never read the password store yourself, by any command. Anything you read lands in this conversation.
- The only commands that may touch it are `sh .claude/scripts/ghl-headers.sh --check < /dev/null`, the same with `--connect`, and the same with `--disconnect`. They say whether the item is there and in the right shape, never what is in it. `ghl-values` has its own helper for its own separate token.
- The connection's item is not the one `ghl-values` uses. Never use it for that, and never delete it.
- If a key was pasted into the chat, tell them to delete it in GoHighLevel, under Settings, then Private Integrations, because it has now been shared, then make a new one and put it in the item in place of the old one.

**How long a key lasts.** GoHighLevel's own help pages say a Private Integration key does not expire on its own. It stops working only when it is deleted, or rotated: "rotate and expire now" stops it at once, and "rotate and expire later" stops it 7 days later. GoHighLevel recommends rotating it every 90 days, as good practice, not as a deadline. A new key goes into the same item, in place of the old one's password.

**Routines run in the cloud,** where the key on this computer is not. A routine that reads GoHighLevel finds no connection there and writes nothing.

**If both are connected.** A founder can end up with the account connector and this fallback at once, and then see GoHighLevel's tools twice. Prefer the account connector. `connect-tools` offers to remove the fallback: `sh .claude/scripts/ghl-headers.sh --disconnect < /dev/null` removes only the `.mcp.json` it wrote, never the key in the password store.

## The mailbox

**Which one.** Read the work email provider in the Brain's Channels section. Google means **Gmail**. Microsoft 365 means **Microsoft 365**. Anything else, or nothing recorded, means no mailbox connection: the founder sends by hand, which is already their route.

**Drafts only.**
- Claude never sends, replies or forwards from the founder's mailbox, even when asked. Never call a tool that does, such as Gmail's `send_message`, `reply` or `forward`, and never set up a mail rule.
- Claude writes drafts. The founder reads each one and presses Send in their own mail app.
- That is also how the 25 outreach emails stay within the rule that a first message to someone who has not written is never sent by a tool: the founder sends each one.
- Show the founder what will be drafted, and to whom, and wait for a yes before writing any draft.

**Microsoft 365 reads mail but cannot write drafts.** Its mail tool is `outlook_email_search`, which only searches. The 25 then go by hand from each person's file, as the manual route already says.

**Replies are read, never answered.** To check for replies, search the mailbox for mail from each person's address since their email went out: Gmail's `search_threads`, or Microsoft 365's `outlook_email_search`. Read only who wrote and when. The founder answers in their own mail app. The Microsoft 365 check has not yet been tried on a real account: if its search does not return the sender, say so plainly and ask the founder who has replied.

**Privacy.** Drafts and replies live in the mailbox. Never copy a person's details, or what they wrote, into any file other than their own person file.
