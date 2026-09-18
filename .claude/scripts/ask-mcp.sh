#!/bin/sh
# PreToolUse on the vendor tools that spend credits, publish, or put people into
# a sequence. Claude Code asks the founder every time, whatever was allowed
# before, so one "always allow" cannot remove the founder's yes.
#
# Every Apollo tool comes here. Only the ones on the read list below go ahead
# without asking, so a new or unlisted Apollo tool asks first by default. The
# tools that send or buy are refused outright by deny-mcp.sh.

. "$(dirname "$0")/lib.sh" 2>/dev/null || exit 0
lh_active || [ -n "$(lh_near)" ] || exit 0

input=$(cat) || exit 0
tool=$(lh_json_get tool_name "$input") || tool=""

case $tool in
  *apollo_people_match|*apollo_people_bulk_match|*apollo_organizations_enrich|*apollo_organizations_bulk_enrich)
    why="This spends Apollo credits. Check the founder has seen the cost and said yes." ;;
  *apollo_emailer_campaigns_add_contact_ids)
    why="This adds people to an Apollo sequence. Check it is paused and the founder said yes." ;;
  *apollo_contacts_create|*apollo_contacts_bulk_create)
    why="This adds people to the founder's Apollo account. Check the founder said yes." ;;
  *social-media-posting_create-post|*social-media-posting_edit-post|*socialmediaposting_create-post|*socialmediaposting_edit-post)
    why="This puts a post into GoHighLevel. Check the founder has seen the words, the account and the time, and said yes." ;;
  *conversations_send-a-new-message)
    why="This sends a message from the founder's GoHighLevel account. It is only for replying to someone who wrote first: check their conversation shows a message from them, show the founder the reply, and get a yes. A first message to someone who has not written goes by hand from the founder's own phone." ;;
  *emails_create-template)
    why="This creates an email template in GoHighLevel. Check the founder said yes." ;;
  *contacts_create-contact|*contacts_upsert-contact|*contacts_update-contact|*contacts_add-tags|*opportunities_update-opportunity)
    why="This changes a contact or deal in GoHighLevel, which can start one of its workflows and send a message. Check the founder has seen the change and said yes." ;;
  *blogs_create-blog-post|*blogs_update-blog-post)
    why="This puts a blog post into GoHighLevel. Check the founder has seen the words and said yes." ;;
  *__execute_operation)
    why="This can post, edit or message from the founder's GoHighLevel account. Show the founder exactly what goes out, and check they said yes." ;;
  *__create_draft|*__update_draft)
    why="This writes a draft in the founder's mailbox. Check the founder has seen the words and who it is to, and said yes." ;;
  # Apollo tools that only read, and spend no credits.
  *apollo_contacts_search|*apollo_mixed_people_api_search|*apollo_mixed_companies_search|\
  *apollo_emailer_campaigns_search|*apollo_emailer_campaigns_show|*apollo_emailer_campaigns_activity_feed|\
  *apollo_emailer_messages_search|*apollo_emailer_messages_get_content|*apollo_emailer_messages_email_send_status|\
  *apollo_emailer_schedules_index|*apollo_email_accounts_index|*apollo_fields_index|*apollo_labels_index|\
  *apollo_users_api_profile|*apollo_users_search|*apollo_usage_stats_credit_usage_stats|\
  *apollo_deals_search|*apollo_deals_show|*apollo_tasks_search|*apollo_tasks_show|*apollo_phone_calls_search|\
  *apollo_conversations_search|*apollo_context_center_show|*apollo_context_center_show_product)
    exit 0 ;;
  *apollo_*)
    why="This Apollo tool can change the founder's Apollo account, spend credits or reach people. Check the founder has seen what it will do and said yes." ;;
  *) exit 0 ;;
esac

printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$(lh_json_escape "Launchhouse: $why")"
exit 0
