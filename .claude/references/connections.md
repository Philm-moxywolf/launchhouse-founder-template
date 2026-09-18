# Connections

How the founder's tools reach Claude. `connect-tools` sets them up and proves them. Any skill that uses a tool follows this file.

| Tool | Who | How it connects | Its name in the Claude app |
|---|---|---|---|
| GoHighLevel | everyone | Claude's connector list. If it is not there, GoHighLevel's own guide, linked in `connect-tools` | **HighLevel** |
| Apollo | B2B only | Claude's own connector | **Apollo.io** |
| The mailbox | B2B only | Claude's own connector, chosen from the work email provider in the Brain's Channels section | **Gmail** for Google (Gmail or Google Workspace), **Microsoft 365** for Microsoft 365 |

## No keys, ever

- Never ask the founder for a key, token or password to connect a tool, and never write one into any file in this folder. The one optional key in Launchhouse belongs to `ghl-values`, which has its own rules for it.
- If one was pasted into the chat, tell them to delete that key in GoHighLevel, under Settings, then Private Integrations, because it has now been shared. Nothing here needs a new one.

## GoHighLevel's tools come in two shapes

- **One connection** gives a few general tools: `list_locations`, `search`, `fetch`, `search_operations`, `describe_operation` and `execute_operation`.
- **Another** gives one tool per job, with names ending in `locations_get-location`, `contacts_get-contacts`, `get-account`, `create-post` and so on. The social tools start `social-media-posting_` or `socialmediaposting_`.

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

The rules are the same in both shapes. A post, an edit, a message or a template goes in only after the founder has seen it and said yes. A message only ever replies to someone who wrote first.

## The mailbox

**Which one.** Read the work email provider in the Brain's Channels section. Google means **Gmail**. Microsoft 365 means **Microsoft 365**. Anything else, or nothing recorded, means no mailbox connection: the founder sends by hand, which is already their route.

**Drafts only.**
- Claude never sends, replies or forwards from the founder's mailbox, even when asked. Never call a tool that does, such as Gmail's `send_message`, `reply` or `forward`.
- Claude writes drafts. The founder reads each one and presses Send in their own mail app.
- That is also how the 25 outreach emails stay within the rule that a first message to someone who has not written is never sent by a tool: the founder sends each one.
- Show the founder what will be drafted, and to whom, and wait for a yes before writing any draft.

**Microsoft 365 reads mail but cannot write drafts.** If the connection has no tool that creates a draft, say so plainly. The 25 then go by hand from each person's file, as the manual route already says.

**Privacy.** Drafts live in the mailbox. Never copy a person's details into any file other than their own person file.
