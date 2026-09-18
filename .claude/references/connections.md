# Connections

How the founder's tools reach Claude. `connect-tools` sets them up and proves them. Any skill that uses a tool follows this file.

| Tool | Who | How it connects | Its name |
|---|---|---|---|
| GoHighLevel | everyone | This folder's own connection, in `.mcp.json`, which `connect-tools` writes when the founder connects. It reads a key the founder keeps in their computer's own password store. Claude has no GoHighLevel connector, and GoHighLevel has no sign-in for one yet | **highlevel** |
| Apollo | B2B only | Claude's own connector, by signing in | **Apollo.io** |
| The mailbox | B2B only | Claude's own connector, by signing in, chosen from the work email provider in the Brain's Channels section | **Gmail** for Google (Gmail or Google Workspace), **Microsoft 365** for Microsoft 365 |

Nothing else needs connecting. GitHub is GitHub Desktop's job, not a connection.

## Keys

Apollo and the mailbox need no key: the founder signs in. GoHighLevel needs one, because it has no sign-in for Claude yet.

**The GoHighLevel key lives in one place only:** the computer's own password store, never a file. On a Mac that is the Keychain, and on a Windows PC it is Credential Manager. The item is named exactly `Launchhouse GoHighLevel`. Its account name (Mac) or user name (Windows) is the Location ID, and its password is the key. The founder adds it themselves, by clicking, as `connect-tools` sets out. Claude Code reads it when it connects, through `.claude/scripts/ghl-headers.sh`, which gives it only to GoHighLevel's own address.

**The connection file.** `.mcp.json`, at the top of this folder, is not shipped. `sh .claude/scripts/ghl-headers.sh --connect < /dev/null` writes it once the key checks out. It holds GoHighLevel's address and this computer's own path to the helper, never the key. Git ignores it, because the path belongs to this computer, and another computer connects by saying "connect my tools" there.

- Never ask for a key, token or password in the chat, and never write one into any file, in this folder or anywhere else.
- Never read the password store yourself, by any command. Anything you read lands in this conversation.
- The only commands that may touch it are `sh .claude/scripts/ghl-headers.sh --check < /dev/null` and the same with `--connect`. They say whether the item is there and in the right shape, never what is in it. `ghl-values` has its own helper for its own separate token.
- The connection's item is not the one `ghl-values` uses. Never use it for that, and never delete it.
- If a key was pasted into the chat, tell them to delete it in GoHighLevel, under Settings, then Private Integrations, because it has now been shared, then make a new one and put it in the item in place of the old one.

**How long a key lasts.** GoHighLevel's own help pages say a Private Integration key does not expire on its own. It stops working only when it is deleted, or rotated: "rotate and expire now" stops it at once, and "rotate and expire later" stops it 7 days later. GoHighLevel recommends rotating it every 90 days, as good practice, not as a deadline. A new key goes into the same item, in place of the old one's password.

**Routines run in the cloud,** where the key on this computer is not. A routine that reads GoHighLevel finds no connection there and writes nothing.

## GoHighLevel's tools come in two shapes

- **This folder's connection** gives one tool per job, with names ending in `locations_get-location`, `contacts_get-contacts`, `socialmediaposting_get-account`, `socialmediaposting_create-post` and so on. Some connections spell the social ones `social-media-posting_`.
- **Another kind of connection** gives a few general tools: `list_locations`, `search`, `fetch`, `search_operations`, `describe_operation` and `execute_operation`.

Either works. To do a job a skill names:
1. If a one-per-job tool for it is there, use it.
2. Otherwise find the operation with `search_operations`, read its inputs with `describe_operation`, and run it with `execute_operation`. Use only the inputs it lists.

| Job | One-per-job tool ends in | Otherwise |
|---|---|---|
| Read back the business | `locations_get-location` | `list_locations` |
| The accounts to post to | `get-account` | Social Planner accounts |
| One contact, to show contacts are readable | `contacts_get-contacts` | a contacts search, limited to one |
| Create, edit or read a post | `create-post`, `edit-post`, `get-post`, `get-posts` | Social Planner posts |
| How posts did | `get-social-media-statistics` | Social Planner statistics |
| Reply to someone who wrote first | `conversations_send-a-new-message` | send a message in a conversation |

The rules are the same in both shapes. A post, an edit, a message, a contact change or a template goes in only after the founder has seen it and said yes. A message only ever replies to someone who wrote first.

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
