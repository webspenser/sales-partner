#!/usr/bin/env bash
# This agent's guard policies, run through the Agent Standard engine.
set -uo pipefail
cd "$(dirname "$0")/.."
source tests/lib.sh
E=hooks/guard_policy.py
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT

check() { # check <rc> <label> <policy> <tool_name> <tool_input> [text] [bindings]
  local out rc
  out=$(printf '{"tool_name":"%s","tool_input":%s}' "$4" "$5" | python3 -B "$E" "$3" "${7:--}" "sales-partner guard policy" 2>&1); rc=$?
  if [ "$rc" -eq "$1" ] && { [ -z "${6:-}" ] || printf '%s\n' "$out" | grep -qF -- "$6"; }; then _report ok "$2"; else _report no "$2 (rc=$rc): $out"; fi
}
for p in capabilities/*/tools/*/guard.yaml; do
  python3 -B "$E" --check "$p" >/dev/null && _report ok "$p parses" || _report no "$p does not parse"
done

echo "-- agent policy"
AG=guard.yaml
python3 -B "$E" --check --agent "$AG" >/dev/null 2>&1 && _report ok "agent policy parses" || _report no "agent policy does not parse"
acheck() { # acheck <rc> <label> <tool_name>
  local out rc
  out=$(printf '{"tool_name":"%s","tool_input":{}}' "$3" | python3 -B "$E" --agent "$AG" "sales-partner agent guard policy" 2>&1); rc=$?
  if [ "$rc" -eq "$1" ]; then _report ok "$2"; else _report no "$2 (rc=$rc): $out"; fi
}
for t in mcp__claude_ai_Gmail__send_message mcp__claude_ai_Gmail__reply mcp__claude_ai_Gmail__forward \
         mcp__claude_ai_Slack__slack_send_message mcp__claude_ai_Slack__slack_schedule_message \
         mcp__claude_ai_Zernio__posts_publish_now mcp__claude_ai_Zernio__posts_create mcp__claude_ai_Zernio__posts_cross_post \
         mcp__claude_ai_Zernio__posts_bulk_upload_posts mcp__claude_ai_Loops__execute_write \
         mcp__claude_ai_Zernio__comments_reply_to_inbox_post mcp__claude_ai_ClickUp__clickup_send_chat_message \
         mcp__claude_ai_Zernio__call_tool mcp__claude_ai_Zernio__posts_retry mcp__claude_ai_Zernio__posts_retry_all_failed \
         mcp__claude_ai_Google_Calendar__create_event mcp__claude_ai_Google_Calendar__update_event \
         mcp__claude_ai_Google_Calendar__respond_to_event; do
  acheck 2 "denied: $t" "$t"
done
for t in mcp__claude_ai_Gmail__create_draft mcp__claude_ai_Gmail__list_drafts mcp__claude_ai_Gmail__search_threads \
         mcp__claude_ai_Gmail__get_thread mcp__claude_ai_Attio__list-comment-replies mcp__claude_ai_Attio__list-records \
         mcp__claude_ai_Beehiiv__list_publications mcp__claude_ai_Beehiiv__get_publication \
         mcp__claude_ai_HubSpot__manage_crm_objects mcp__claude_ai_HubSpot__search_crm_objects \
         mcp__claude_ai_Airtable__update_records_for_table mcp__claude_ai_Slack__slack_read_channel \
         mcp__claude_ai_Slack__slack_read_thread mcp__claude_ai_ClickUp__clickup_get_chat_message_replies \
         mcp__claude_ai_Zernio__posts_list mcp__claude_ai_Loops__execute mcp__claude_ai_Notion__notion-search \
         mcp__claude_ai_Google_Calendar__list_events mcp__claude_ai_Google_Calendar__get_event \
         mcp__claude_ai_Google_Calendar__search_events mcp__claude_ai_Zernio__search_tools; do
  acheck 0 "read or CRM write passes: $t" "$t"
done

for t in execute_workflow test_workflow create_workflow_from_code update_workflow archive_workflow publish_workflow unpublish_workflow restore_workflow_version; do
  acheck 2 "n8n dispatcher denied: $t" "mcp__claude_ai_N8N_Webspenser_Newsletter__$t"
done
echo "-- Attio"
AT=capabilities/crm/tools/attio/guard.yaml; P=mcp__claude_ai_Attio__
L='"list":"sales_partner_outreach","parent_object":"companies","parent_record_id":"00000000-0000-0000-0000-000000000001"'
X='"list":"sales_partner_outreach","entry_id":"00000000-0000-0000-0000-000000000002"'
check 0 "create draft"              $AT ${P}add-record-to-list "{$L,\"entry_values\":{\"status\":\"draft\",\"summary\":\"x\"}}"
check 0 "create draft as list"      $AT ${P}add-record-to-list "{$L,\"entry_values\":{\"status\":[\"draft\"]}}"
check 2 "create approved"           $AT ${P}add-record-to-list "{$L,\"entry_values\":{\"status\":\"approved\"}}" "status may only be written as draft on create"
check 2 "create sent via option"    $AT ${P}add-record-to-list "{$L,\"entry_values\":{\"status\":{\"option\":\"sent\"}}}"
check 2 "create voided"             $AT ${P}add-record-to-list "{$L,\"entry_values\":{\"status\":\"voided\"}}"
check 2 "mixed wrapped status"      $AT ${P}add-record-to-list "{$L,\"entry_values\":{\"status\":{\"option\":\"draft\",\"title\":\"approved\"}}}"
check 0 "create lead, dnc false ok" $AT ${P}add-record-to-list "{$L,\"entry_values\":{\"stage\":\"New\",\"do_not_contact\":false}}"
check 0 "update voided"             $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"status\":\"voided\",\"outcome\":\"dup\"}}"
check 2 "update draft"              $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"status\":\"draft\"}}" "status may only be written as voided on update"
check 2 "update approved by record" $AT ${P}update-list-entry-by-record-id "{$L,\"entry_values\":{\"status\":\"Approved\"}}"
check 2 "status by option UUID"     $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"status\":\"49e56c99-597b-40b5-9413-162ce1adadfc\"}}"
check 2 "unknown value shape"       $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"status\":{\"foo\":1}}}" "cannot check this call"
check 2 "dnc cleared"               $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"do_not_contact\":false}}" "do_not_contact may only be written as true"
check 2 "dnc cleared as string"     $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"do_not_contact\":\"false\"}}"
check 0 "dnc set true"              $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"do_not_contact\":true}}"
check 2 "attribute by ID"           $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"925c1cde-cba6-453e-96f9-5bd8f498d8a3\":\"sent\"}}" "addressed by ID"
check 2 "upsert with approved"      $AT ${P}upsert-record '{"object":"people","matching_attribute":"email_addresses","values":{"status":"approved"}}'
check 0 "update person"             $AT ${P}update-record '{"object":"people","record_id":"00000000-0000-0000-0000-000000000003","values":{"sp_role":"influencer"}}'
check 0 "fill company profile"      $AT ${P}update-record '{"object":"companies","record_id":"00000000-0000-0000-0000-000000000004","values":{"description":"Plumbing and radiant heating in Alameda, CA","primary_location":"1173 Broadway, Alameda, CA, 94501, US","linkedin":"https://www.linkedin.com/company/x"}}'
check 2 "create-record approved"    $AT ${P}create-record '{"object":"companies","values":{"status":"approved"}}'
check 2 "create-list refused"       $AT ${P}create-list '{"name":"x"}' "is denied"
check 2 "update-list refused"       $AT ${P}update-list '{"list":"sales_partner_outreach"}'
check 2 "delete refused"            $AT ${P}delete-comment '{}' "is denied"
check 2 "merge refused"             $AT ${P}merge-records '{}' "is denied"
check 2 "unlisted tool refused"     $AT ${P}create-comment '{}' "is not in the allow list"
check 0 "read tool allowed"         $AT ${P}list-records-in-list '{"list":"sales_partner_outreach"}'
check 2 "create-note not allowed"   $AT ${P}create-note '{"title":"x","content":"y"}' "is not in the allow list"
check 2 "create-task not allowed"   $AT ${P}create-task '{"content":"x"}' "is not in the allow list"
check 2 "update-task not allowed"   $AT ${P}update-task '{"task_id":"x"}' "is not in the allow list"
check 0 "create with draft_body"    $AT ${P}add-record-to-list "{$L,\"entry_values\":{\"status\":\"draft\",\"draft_body\":\"Hi\"}}"
check 2 "draft_body rewritten"      $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"draft_body\":\"new\"}}" "draft_body may not be changed after create"
check 2 "Draft Body spelled out"    $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"Draft Body\":\"new\"}}" "may not be changed after create"
out=$(printf '{not json' | python3 -B "$E" "$AT" - x 2>&1); rc=$?
[ "$rc" -eq 2 ] && _report ok "malformed JSON blocks" || _report no "malformed JSON (rc=$rc)"

check 2 "agent can't approve a lead"  $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"stage\":\"Ready to Send\"}}" "stage may only be written as"
check 2 "agent can't mark Contacted"  $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"stage\":\"Contacted\"}}" "stage may only be written as"
check 0 "agent marks Researched"      $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"stage\":\"Researched\"}}"
check 0 "agent returns a lead to Approach Drafted" $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"stage\":\"Approach Drafted\"}}"
check 2 "agent can't mark Engaged"    $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"stage\":\"Engaged\"}}" "stage may only be written as"
check 0 "agent disqualifies"          $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"stage\":\"Disqualified\"}}"
check 2 "agent can't open a deal"     $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"stage\":\"Open Deal\"}}" "stage may only be written as"
check 2 "no New on update"            $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"stage\":\"New\"}}" "stage may only be written as"
check 2 "agent can't nurture"         $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"stage\":\"Nurture\"}}" "stage may only be written as"
check 2 "agent can't mark Customer"   $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"stage\":\"Customer\"}}" "stage may only be written as"
check 2 "Replied is gone"             $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"stage\":\"Replied\"}}" "stage may only be written as"
check 2 "lead created past New"       $AT ${P}add-record-to-list "{$L,\"entry_values\":{\"stage\":\"Scored\"}}" "stage may only be written as New on create"
check 0 "lead created at New"         $AT ${P}add-record-to-list "{$L,\"entry_values\":{\"stage\":\"New\"}}"
check 2 "agent can't mark a touch sent" $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"status\":\"sent\"}}" "status may only be written as voided on update"
check 2 "agent can't revive a draft"  $AT ${P}update-list-entry-by-id "{$X,\"entry_values\":{\"status\":\"draft\"}}"
echo "-- Gmail"
GM=capabilities/email_drafts/tools/gmail/guard.yaml; G=mcp__claude_ai_Gmail__
check 0 "create draft"              $GM ${G}create_draft '{"to":"a@b.c","subject":"s","body":"b"}'
check 0 "search threads"            $GM ${G}search_threads '{"query":"x"}'
check 2 "send refused"              $GM ${G}send_message '{}' "is denied"
check 2 "reply refused"             $GM ${G}reply_to_thread '{}' "is denied"
check 2 "forward refused"           $GM ${G}forward_message '{}' "is denied"
check 2 "trash not allowed"         $GM ${G}trash_thread '{}' "is not in the allow list"
check 2 "new unlisted tool"         $GM ${G}schedule_email '{}' "is not in the allow list"
check 0 "prefixed create_draft"     $GM mcp__gmail_server__gmail_create_draft '{}'
check 0 "prefixed search_threads"   $GM mcp__gmail_server__gmail_search_threads '{}'
check 2 "prefixed send still denied" $GM mcp__gmail_server__gmail_send_message '{}' "is denied"
check 2 "suffix glob is not a substring" $GM ${G}create_draft_and_send '{}'

echo "-- Airtable"
AR=capabilities/crm/tools/airtable/guard.yaml; A=mcp__claude_ai_Airtable__
printf '%s\n' '# CRM binding — Airtable' 'base_id: appAAAAAAAAAAAAAA' 'field_status: fldSSSSSSSSSSSSSS' 'field_do_not_contact: fldDDDDDDDDDDDDDD' \
  'field_draft_body: fldBBBBBBBBBBBBBB' 'field_lead: fldL1LLLLLLLLLLLLL' 'field_lead: fldL2LLLLLLLLLLLLL' \
  'field_stage: fldSTAGEEEEEEEEEE' > "$W/b.md"
B='"baseId":"appAAAAAAAAAAAAAA","tableId":"tblTTTTTTTTTTTTTT"'
check 0 "create draft by ID"        $AR ${A}create_records_for_table "{$B,\"records\":[{\"fields\":{\"fldSSSSSSSSSSSSSS\":\"draft\"}}]}" "" "$W/b.md"
check 2 "create approved by ID"     $AR ${A}create_records_for_table "{$B,\"records\":[{\"fields\":{\"fldSSSSSSSSSSSSSS\":\"approved\"}}]}" "Status may only be written as draft on create" "$W/b.md"
check 2 "update sent by name"       $AR ${A}update_records_for_table "{$B,\"records\":[{\"id\":\"recRRRRRRRRRRRRRR\",\"fields\":{\"Status\":\"sent\"}}]}" "Status is not a recorded field ID" "$W/b.md"
check 2 "unrecorded field ID"       $AR ${A}update_records_for_table "{$B,\"records\":[{\"id\":\"recRRRRRRRRRRRRRR\",\"fields\":{\"fldOOOOOOOOOOOOOO\":\"x\"}}]}" "fldOOOOOOOOOOOOOO is not a recorded field ID" "$W/b.md"
check 0 "repeated name: both IDs recorded" $AR ${A}create_records_for_table "{$B,\"records\":[{\"fields\":{\"fldL1LLLLLLLLLLLLL\":[\"recA\"]}},{\"fields\":{\"fldL2LLLLLLLLLLLLL\":[\"recB\"]}}]}" "" "$W/b.md"
check 0 "update voided by ID"       $AR ${A}update_records_for_table "{$B,\"records\":[{\"id\":\"recRRRRRRRRRRRRRR\",\"fields\":{\"fldSSSSSSSSSSSSSS\":\"voided\"}}]}" "" "$W/b.md"
check 2 "clear DNC by ID"           $AR ${A}update_records_for_table "{$B,\"records\":[{\"id\":\"recRRRRRRRRRRRRRR\",\"fields\":{\"fldDDDDDDDDDDDDDD\":false}}]}" "Do Not Contact may only be written as true" "$W/b.md"
check 2 "write without field IDs"   $AR ${A}create_records_for_table "{$B,\"records\":[{\"fields\":{\"fldXXXXXXXXXXXXXX\":\"x\"}}]}" "has not recorded any field IDs"
check 2 "delete refused"            $AR ${A}delete_records_for_table "{$B}" "is denied"
check 2 "schema change refused"     $AR ${A}create_field "{$B}" "is not in the allow list"
check 0 "read allowed"              $AR ${A}list_records_for_table "{$B}"
check 0 "create draft with body"    $AR ${A}create_records_for_table "{$B,\"records\":[{\"fields\":{\"fldSSSSSSSSSSSSSS\":\"draft\",\"fldBBBBBBBBBBBBBB\":\"Hi\"}}]}" "" "$W/b.md"
check 2 "Draft Body rewritten"      $AR ${A}update_records_for_table "{$B,\"records\":[{\"id\":\"recRRRRRRRRRRRRRR\",\"fields\":{\"fldBBBBBBBBBBBBBB\":\"new\"}}]}" "Draft Body may not be changed after create" "$W/b.md"

check 2 "agent can't approve a lead"  $AR ${A}update_records_for_table "{$B,\"records\":[{\"id\":\"recRRRRRRRRRRRRRR\",\"fields\":{\"fldSTAGEEEEEEEEEE\":\"Ready to Send\"}}]}" "Stage may only be written as" "$W/b.md"
check 2 "agent can't mark Contacted"  $AR ${A}update_records_for_table "{$B,\"records\":[{\"id\":\"recRRRRRRRRRRRRRR\",\"fields\":{\"fldSTAGEEEEEEEEEE\":\"Contacted\"}}]}" "Stage may only be written as" "$W/b.md"
check 0 "agent marks Approach Drafted" $AR ${A}update_records_for_table "{$B,\"records\":[{\"id\":\"recRRRRRRRRRRRRRR\",\"fields\":{\"fldSTAGEEEEEEEEEE\":\"Approach Drafted\"}}]}" "" "$W/b.md"
check 2 "agent can't mark Engaged"    $AR ${A}update_records_for_table "{$B,\"records\":[{\"id\":\"recRRRRRRRRRRRRRR\",\"fields\":{\"fldSTAGEEEEEEEEEE\":\"Engaged\"}}]}" "Stage may only be written as" "$W/b.md"
check 2 "agent can't nurture"         $AR ${A}update_records_for_table "{$B,\"records\":[{\"id\":\"recRRRRRRRRRRRRRR\",\"fields\":{\"fldSTAGEEEEEEEEEE\":\"Nurture\"}}]}" "Stage may only be written as" "$W/b.md"
check 2 "agent can't open a deal"     $AR ${A}update_records_for_table "{$B,\"records\":[{\"id\":\"recRRRRRRRRRRRRRR\",\"fields\":{\"fldSTAGEEEEEEEEEE\":\"Open Deal\"}}]}" "Stage may only be written as" "$W/b.md"
check 2 "no New on update"            $AR ${A}update_records_for_table "{$B,\"records\":[{\"id\":\"recRRRRRRRRRRRRRR\",\"fields\":{\"fldSTAGEEEEEEEEEE\":\"New\"}}]}" "Stage may only be written as" "$W/b.md"
check 2 "agent can't mark Customer"   $AR ${A}update_records_for_table "{$B,\"records\":[{\"id\":\"recRRRRRRRRRRRRRR\",\"fields\":{\"fldSTAGEEEEEEEEEE\":\"Customer\"}}]}" "Stage may only be written as" "$W/b.md"
check 2 "agent can't mark a touch sent" $AR ${A}update_records_for_table "{$B,\"records\":[{\"id\":\"recRRRRRRRRRRRRRR\",\"fields\":{\"fldSSSSSSSSSSSSSS\":\"sent\"}}]}" "Status may only be written as voided on update" "$W/b.md"
echo "-- HubSpot"
HS=capabilities/crm/tools/hubspot/guard.yaml; H=mcp__claude_ai_HubSpot__
TC='{"objectType":"tasks","properties":{"hs_task_status":"%s"}}'
TU='{"objectType":"tasks","objectId":101,"properties":{%s}}'
CU='{"objectType":"companies","objectId":202,"properties":{"sp_do_not_contact":%s}}'
check 0 "create task NOT_STARTED"   $HS ${H}manage_crm_objects "{\"createRequest\":{\"objects\":[$(printf "$TC" NOT_STARTED)]}}"
check 2 "create task COMPLETED"     $HS ${H}manage_crm_objects "{\"createRequest\":{\"objects\":[$(printf "$TC" COMPLETED)]}}" "hs_task_status may only be written as NOT_STARTED on create"
check 2 "create task IN_PROGRESS"   $HS ${H}manage_crm_objects "{\"createRequest\":{\"objects\":[$(printf "$TC" IN_PROGRESS)]}}" "NOT_STARTED on create"
check 0 "update task DEFERRED"      $HS ${H}manage_crm_objects "{\"updateRequest\":{\"objects\":[$(printf "$TU" '"hs_task_status":"DEFERRED"')]}}"
check 2 "void rewrites the body"    $HS ${H}manage_crm_objects "{\"updateRequest\":{\"objects\":[$(printf "$TU" '"hs_task_status":"DEFERRED","hs_task_body":"Direction: outbound\\nOutcome: dup"')]}}" "hs_task_body may not be changed after create"
check 0 "task created with body"    $HS ${H}manage_crm_objects '{"createRequest":{"objects":[{"objectType":"tasks","properties":{"hs_task_status":"NOT_STARTED","hs_task_body":"<p>x</p>"}}]}}'
check 0 "outcome note created"      $HS ${H}manage_crm_objects '{"createRequest":{"objects":[{"objectType":"notes","properties":{"hs_note_body":"<p>Outcome for task 101: dup</p>","hs_timestamp":"2026-10-01T00:00:00Z"},"associations":[{"targetObjectType":"COMPANY","targetObjectId":202}]}]}}'
check 2 "agent can't complete a task (sent)" $HS ${H}manage_crm_objects "{\"updateRequest\":{\"objects\":[$(printf "$TU" '"hs_task_status":"COMPLETED"')]}}" "hs_task_status may only be written as DEFERRED on update"
check 2 "agent can't approve a lead"  $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"companies","objectId":202,"properties":{"sp_stage":"Ready to Send"}}]}}' "sp_stage may only be written as"
check 2 "agent can't mark Contacted"  $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"companies","objectId":202,"properties":{"sp_stage":"Contacted"}}]}}' "sp_stage may only be written as"
check 0 "agent disqualifies"          $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"companies","objectId":202,"properties":{"sp_stage":"Disqualified"}}]}}'
check 2 "agent can't mark Engaged"    $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"companies","objectId":202,"properties":{"sp_stage":"Engaged"}}]}}' "sp_stage may only be written as"
check 2 "agent can't nurture"         $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"companies","objectId":202,"properties":{"sp_stage":"Nurture"}}]}}' "sp_stage may only be written as"
check 2 "no New on update"            $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"companies","objectId":202,"properties":{"sp_stage":"New"}}]}}' "sp_stage may only be written as"
check 2 "agent can't open a deal"     $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"companies","objectId":202,"properties":{"sp_stage":"Open Deal"}}]}}' "sp_stage may only be written as"
check 2 "agent can't mark Customer"   $HS ${H}manage_crm_objects '{"updateRequest":{"objects":[{"objectType":"companies","objectId":202,"properties":{"sp_stage":"Customer"}}]}}' "sp_stage may only be written as"
check 2 "lead created past New"       $HS ${H}manage_crm_objects '{"createRequest":{"objects":[{"objectType":"companies","properties":{"name":"X","sp_stage":"Scored"}}]}}' "sp_stage may only be written as New on create"
check 2 "update task IN_PROGRESS"   $HS ${H}manage_crm_objects "{\"updateRequest\":{\"objects\":[$(printf "$TU" '"hs_task_status":"IN_PROGRESS"')]}}" "DEFERRED on update"
check 2 "update task WAITING"       $HS ${H}manage_crm_objects "{\"updateRequest\":{\"objects\":[$(printf "$TU" '"hs_task_status":"WAITING"')]}}" "DEFERRED on update"
check 2 "create task WAITING"       $HS ${H}manage_crm_objects "{\"createRequest\":{\"objects\":[$(printf "$TC" WAITING)]}}" "NOT_STARTED on create"
check 2 "create task DEFERRED"      $HS ${H}manage_crm_objects "{\"createRequest\":{\"objects\":[$(printf "$TC" DEFERRED)]}}" "NOT_STARTED on create"
check 2 "update task NOT_STARTED"   $HS ${H}manage_crm_objects "{\"updateRequest\":{\"objects\":[$(printf "$TU" '"hs_task_status":"NOT_STARTED"')]}}" "DEFERRED on update"
DONE=61bafb31-e7fa-46ed-aaa9-1322438d6e67
check 2 "update stage to Completed" $HS ${H}manage_crm_objects "{\"updateRequest\":{\"objects\":[$(printf "$TU" "\"hs_pipeline_stage\":\"$DONE\"")]}}" "hs_pipeline_stage may not be written"
check 2 "create at Completed stage, NOT_STARTED status" $HS ${H}manage_crm_objects "{\"createRequest\":{\"objects\":[{\"objectType\":\"tasks\",\"properties\":{\"hs_task_status\":\"NOT_STARTED\",\"hs_pipeline_stage\":\"$DONE\"}}]}}" "hs_pipeline_stage may not be written"
check 2 "hs_pipeline blocked"       $HS ${H}manage_crm_objects "{\"updateRequest\":{\"objects\":[$(printf "$TU" '"hs_pipeline":"3d314325-1b2a-4225-9388-375f49c57ec3"')]}}" "hs_pipeline may not be written"
check 2 "hs_task_completion_date blocked" $HS ${H}manage_crm_objects "{\"updateRequest\":{\"objects\":[$(printf "$TU" '"hs_task_completion_date":"2026-09-30T00:00:00Z"')]}}" "hs_task_completion_date may not be written"
check 0 "create outbound draft, priority HIGH" $HS ${H}manage_crm_objects '{"createRequest":{"objects":[{"objectType":"tasks","properties":{"hs_task_status":"NOT_STARTED","hs_task_priority":"HIGH","hs_task_type":"EMAIL"}}]}}'
check 0 "create task, no status"    $HS ${H}manage_crm_objects '{"createRequest":{"objects":[{"objectType":"tasks","properties":{"hs_task_subject":"x","hs_task_type":"EMAIL"}}]}}'
check 2 "both kinds, bad create"    $HS ${H}manage_crm_objects "{\"updateRequest\":{\"objects\":[$(printf "$TU" '"hs_task_status":"DEFERRED"')]},\"createRequest\":{\"objects\":[$(printf "$TC" COMPLETED)]}}" "NOT_STARTED on create"
check 0 "both kinds, both fine"     $HS ${H}manage_crm_objects "{\"updateRequest\":{\"objects\":[$(printf "$TU" '"hs_task_status":"DEFERRED"')]},\"createRequest\":{\"objects\":[$(printf "$TC" NOT_STARTED)]}}"
# The engine compares case-insensitively; HubSpot itself would reject the lowercase value.
check 0 "create not_started lower"  $HS ${H}manage_crm_objects "{\"createRequest\":{\"objects\":[$(printf "$TC" not_started)]}}"
check 0 "dnc set \"true\""          $HS ${H}manage_crm_objects "{\"updateRequest\":{\"objects\":[$(printf "$CU" '"true"')]}}"
check 0 "dnc set true"              $HS ${H}manage_crm_objects "{\"updateRequest\":{\"objects\":[$(printf "$CU" true)]}}"
check 2 "dnc cleared \"false\""     $HS ${H}manage_crm_objects "{\"updateRequest\":{\"objects\":[$(printf "$CU" '"false"')]}}" "sp_do_not_contact may only be written as true"
check 2 "dnc cleared false"         $HS ${H}manage_crm_objects "{\"updateRequest\":{\"objects\":[$(printf "$CU" false)]}}"
check 0 "create lead at New"        $HS ${H}manage_crm_objects '{"createRequest":{"objects":[{"objectType":"companies","properties":{"name":"X","sp_stage":"New"}}]}}'
check 2 "custom properties refused" $HS ${H}manage_custom_properties '{}' "is not in the allow list"
check 2 "marketing email refused"   $HS ${H}manage_marketing_email '{}' "is not in the allow list"
check 2 "delete refused"            $HS ${H}delete_crm_objects '{}' "is denied"
check 2 "merge refused"             $HS ${H}merge_crm_objects '{}' "is denied"
check 0 "search allowed"            $HS ${H}search_crm_objects '{"objectType":"TASK"}'
check 0 "local server name allowed" $HS mcp__HubSpot__search_crm_objects '{"objectType":"COMPANY"}'
# Token canary, offline: call is faked to fail (a 401, then a raised Stop); all output is captured.
canary=$(python3 -B - <<'PY' 2>&1
import importlib.util, io, os, contextlib
sp = importlib.util.spec_from_file_location("b", "capabilities/crm/tools/hubspot/bootstrap.py")
b = importlib.util.module_from_spec(sp); sp.loader.exec_module(b)
os.environ["HUBSPOT_TOKEN"] = "sk-canary-12345"

def unauthorized(token, method, path, body=None):
    return 401, {"message": "Authentication credentials not found."}

def unreachable(token, method, path, body=None):
    raise b.Stop("cannot reach HubSpot: offline")

for name, fake in (("401", unauthorized), ("stop", unreachable)):
    b.call = fake
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf), contextlib.redirect_stderr(buf):
        rc = b.main()
    print(f"[{name}] rc={rc}")
    print(buf.getvalue())
PY
)
printf '%s' "$canary" | grep -qF '[401] rc=1' && printf '%s' "$canary" | grep -qF '[stop] rc=1' \
  && _report ok "bootstrap canary: a failing call stops with exit 1, offline" || _report no "bootstrap canary did not run as expected ($canary)"
printf '%s' "$canary" | grep -q 'sk-canary-12345' && _report no "bootstrap echoed the token" || _report ok "bootstrap never prints the token"
grep -q 'print(.*token' capabilities/crm/tools/hubspot/bootstrap.py && _report no "bootstrap prints a token variable" || _report ok "no print of the token"

# bootstrap.py: pass 1 checks existing property types offline (call is faked; no network)
bt=$(python3 -B - <<'PY' 2>&1
import importlib.util, io, contextlib
sp = importlib.util.spec_from_file_location("b", "capabilities/crm/tools/hubspot/bootstrap.py")
b = importlib.util.module_from_spec(sp); sp.loader.exec_module(b)
import os
os.environ["HUBSPOT_TOKEN"] = "t"

def defn(obj, name):
    return next(p for p in b.PROPERTIES[obj] if p["name"] == name)

def run(over):
    calls = []
    def fake(token, method, path, body=None):
        calls.append((method, path))
        parts = path.strip("/").split("/")
        if method == "GET" and len(parts) == 3 and parts[1] == "groups":
            return 200, {}
        if method == "GET":
            have = over.get(path)
            if have == 404:
                return 404, {"message": "nf"}
            if have is not None:
                return 200, have
            d = defn(parts[0], parts[1])
            return 200, {k: d[k] for k in ("type", "fieldType", "options") if k in d}
        return 200, {}
    b.call = fake
    out, err = io.StringIO(), io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
        rc = b.main()
    writes = [c for c in calls if c[0] in ("POST", "PATCH")]
    return rc, out.getvalue() + err.getvalue(), writes

rc, text, w = run({"/companies/sp_stage": {"type": "string", "fieldType": "text"}})
print("A", rc == 1 and "companies.sp_stage exists as string/text but must be enumeration/select" in text
      and "Company properties" in text and not w)
rc, text, w = run({})
print("B", rc == 0 and not w)
rc, text, w = run({"/companies/sp_score": 404})
print("C", rc == 0 and w == [("POST", "/companies")])
rc, text, w = run({"/contacts/sp_role": {"type": "enumeration", "fieldType": "select",
                   "options": [{"value": "decision-maker"}, {"value": "extra"}]}})
print("D", rc == 0 and [m for m, _ in w] == ["PATCH"])

# E: a realistic HubSpot GET payload for every property: extra fields, real type/fieldType pairs.
META = {"archivable": True, "readOnlyDefinition": False, "readOnlyValue": False}
def realistic(d):
    p = {"updatedAt": "2026-09-01T12:00:00.000Z", "createdAt": "2026-09-01T12:00:00.000Z",
         "name": d["name"], "label": d["label"], "type": d["type"], "fieldType": d["fieldType"],
         "description": "", "groupName": "sales_partner", "options": [],
         "createdUserId": "1234567", "updatedUserId": "1234567", "displayOrder": -1,
         "calculated": False, "externalOptions": False, "archived": False,
         "hasUniqueValue": False, "hidden": False, "formField": True,
         "dataSensitivity": "non_sensitive", "modificationMetadata": META}
    for i, o in enumerate(d.get("options", [])):
        p["options"].append({"label": o["label"], "value": o["value"], "description": "",
                             "displayOrder": i, "hidden": False})
    return p
pairs = {(p["type"], p["fieldType"]) for ps in b.PROPERTIES.values() for p in ps}
real = {f"/{o}/{p['name']}": realistic(p) for o, ps in b.PROPERTIES.items() for p in ps}
rc, text, w = run(real)
print("E", rc == 0 and not w and pairs == {("enumeration", "select"), ("datetime", "date"),
      ("string", "textarea"), ("number", "number"), ("string", "text"), ("date", "date"),
      ("bool", "booleancheckbox")})
PY
)
for c in A:"mismatched type blocks with a clear message and no writes" B:"correct types pass with no writes" \
         C:"a missing property is created" D:"missing enum options are patched, extras kept" \
         E:"a realistic HubSpot property payload passes with no writes"; do
  k=${c%%:*}; echo "$bt" | grep -qx "$k True" && _report ok "bootstrap $k: ${c#*:}" || _report no "bootstrap $k: ${c#*:} ($bt)"
done

finish
