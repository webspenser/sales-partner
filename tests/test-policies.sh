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
check 2 "create-record approved"    $AT ${P}create-record '{"object":"companies","values":{"status":"approved"}}'
check 2 "create-list refused"       $AT ${P}create-list '{"name":"x"}' "is denied"
check 2 "update-list refused"       $AT ${P}update-list '{"list":"sales_partner_outreach"}'
check 2 "delete refused"            $AT ${P}delete-comment '{}' "is denied"
check 2 "merge refused"             $AT ${P}merge-records '{}' "is denied"
check 2 "unlisted tool refused"     $AT ${P}create-comment '{}' "is not in the allow list"
check 0 "read tool allowed"         $AT ${P}list-records-in-list '{"list":"sales_partner_outreach"}'
check 0 "note without values"       $AT ${P}create-note '{"title":"x","content":"y"}'
out=$(printf '{not json' | python3 -B "$E" "$AT" - x 2>&1); rc=$?
[ "$rc" -eq 2 ] && _report ok "malformed JSON blocks" || _report no "malformed JSON (rc=$rc)"

echo "-- Gmail"
GM=capabilities/email_drafts/tools/gmail/guard.yaml; G=mcp__claude_ai_Gmail__
check 0 "create draft"              $GM ${G}create_draft '{"to":"a@b.c","subject":"s","body":"b"}'
check 0 "search threads"            $GM ${G}search_threads '{"query":"x"}'
check 2 "send refused"              $GM ${G}send_message '{}' "is denied"
check 2 "reply refused"             $GM ${G}reply_to_thread '{}' "is denied"
check 2 "forward refused"           $GM ${G}forward_message '{}' "is denied"
check 2 "trash not allowed"         $GM ${G}trash_thread '{}' "is not in the allow list"
check 2 "new unlisted tool"         $GM ${G}schedule_email '{}' "is not in the allow list"

echo "-- Airtable"
AR=capabilities/crm/tools/airtable/guard.yaml; A=mcp__claude_ai_Airtable__
printf '%s\n' '# CRM binding — Airtable' 'base_id: appAAAAAAAAAAAAAA' 'field_status: fldSSSSSSSSSSSSSS' 'field_do_not_contact: fldDDDDDDDDDDDDDD' > "$W/b.md"
B='"baseId":"appAAAAAAAAAAAAAA","tableId":"tblTTTTTTTTTTTTTT"'
check 0 "create draft by ID"        $AR ${A}create_records_for_table "{$B,\"records\":[{\"fields\":{\"fldSSSSSSSSSSSSSS\":\"draft\"}}]}" "" "$W/b.md"
check 2 "create approved by ID"     $AR ${A}create_records_for_table "{$B,\"records\":[{\"fields\":{\"fldSSSSSSSSSSSSSS\":\"approved\"}}]}" "Status may only be written as draft on create" "$W/b.md"
check 2 "update sent by name"       $AR ${A}update_records_for_table "{$B,\"records\":[{\"id\":\"recRRRRRRRRRRRRRR\",\"fields\":{\"Status\":\"sent\"}}]}" "" "$W/b.md"
check 0 "update voided by ID"       $AR ${A}update_records_for_table "{$B,\"records\":[{\"id\":\"recRRRRRRRRRRRRRR\",\"fields\":{\"fldSSSSSSSSSSSSSS\":\"voided\"}}]}" "" "$W/b.md"
check 2 "clear DNC by ID"           $AR ${A}update_records_for_table "{$B,\"records\":[{\"id\":\"recRRRRRRRRRRRRRR\",\"fields\":{\"fldDDDDDDDDDDDDDD\":false}}]}" "Do Not Contact may only be written as true" "$W/b.md"
check 2 "write without field IDs"   $AR ${A}create_records_for_table "{$B,\"records\":[{\"fields\":{\"fldXXXXXXXXXXXXXX\":\"x\"}}]}" "has not recorded field_status"
check 2 "delete refused"            $AR ${A}delete_records_for_table "{$B}" "is denied"
check 2 "schema change refused"     $AR ${A}create_field "{$B}" "is not in the allow list"
check 0 "read allowed"              $AR ${A}list_records_for_table "{$B}"

echo "-- HubSpot"
HS=capabilities/crm/tools/hubspot/guard.yaml; H=mcp__claude_ai_HubSpot__
TC='{"objectType":"tasks","properties":{"sp_status":"%s"}}'
TU='{"objectType":"tasks","objectId":101,"properties":{%s}}'
CU='{"objectType":"companies","objectId":202,"properties":{"sp_do_not_contact":%s}}'
check 0 "create task at draft"      $HS ${H}manage_crm_objects "{\"createRequest\":{\"objects\":[$(printf "$TC" draft)]}}"
check 2 "create task at sent"       $HS ${H}manage_crm_objects "{\"createRequest\":{\"objects\":[$(printf "$TC" sent)]}}" "sp_status may only be written as draft on create"
check 0 "update task to voided"     $HS ${H}manage_crm_objects "{\"updateRequest\":{\"objects\":[$(printf "$TU" '"sp_status":"voided","sp_outcome":"dup"')]}}"
check 2 "update task to approved"   $HS ${H}manage_crm_objects "{\"updateRequest\":{\"objects\":[$(printf "$TU" '"sp_status":"approved"')]}}" "sp_status may only be written as voided on update"
check 2 "both kinds, bad create"    $HS ${H}manage_crm_objects "{\"updateRequest\":{\"objects\":[$(printf "$TU" '"sp_status":"voided"')]},\"createRequest\":{\"objects\":[$(printf "$TC" approved)]}}" "draft on create"
check 0 "both kinds, both fine"     $HS ${H}manage_crm_objects "{\"updateRequest\":{\"objects\":[$(printf "$TU" '"sp_status":"voided"')]},\"createRequest\":{\"objects\":[$(printf "$TC" draft)]}}"
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
out=$(HUBSPOT_TOKEN=sk-canary-12345 python3 -B capabilities/crm/tools/hubspot/bootstrap.py 2>&1 </dev/null); \
  printf '%s' "$out" | grep -q 'sk-canary-12345' && _report no "bootstrap echoed the token" || _report ok "bootstrap never prints the token"
grep -q 'print(.*token' capabilities/crm/tools/hubspot/bootstrap.py && _report no "bootstrap prints a token variable" || _report ok "no print of the token"

finish
