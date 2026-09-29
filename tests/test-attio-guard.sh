#!/usr/bin/env bash
# Rules of the Attio guard (capabilities/crm/adapters/attio/guard.py).
set -uo pipefail
cd "$(dirname "$0")/.."
source tests/lib.sh
G=capabilities/crm/adapters/attio/guard.py
P=mcp__claude_ai_Attio__

check() { # check <expected rc> <label> <tool> <tool_input JSON> [stderr text]
  local out rc
  out=$(printf '{"tool_name":"%s%s","tool_input":%s}' "$P" "$3" "$4" | python3 "$G" 2>&1); rc=$?
  if [ "$rc" -eq "$1" ] && { [ -z "${5:-}" ] || printf '%s\n' "$out" | grep -qF -- "$5"; }; then
    _report ok "$2"; else _report no "$2 (rc=$rc): $out"; fi
}
raw() { # raw <expected rc> <label> <whole stdin>
  local out rc; out=$(printf '%s' "$3" | python3 "$G" 2>&1); rc=$?
  [ "$rc" -eq "$1" ] && _report ok "$2" || _report no "$2 (rc=$rc): $out"
}
L='"list":"sales_partner_outreach","parent_object":"companies","parent_record_id":"00000000-0000-0000-0000-000000000001"'
E='"list":"sales_partner_outreach","entry_id":"00000000-0000-0000-0000-000000000002"'

check 0 "create draft"                 add-record-to-list "{$L,\"entry_values\":{\"status\":\"draft\",\"summary\":\"x\"}}"
check 0 "create draft as list"         add-record-to-list "{$L,\"entry_values\":{\"status\":[\"draft\"]}}"
check 2 "create approved"              add-record-to-list "{$L,\"entry_values\":{\"status\":\"approved\"}}" "status may only be written as draft"
check 2 "create sent via option"       add-record-to-list "{$L,\"entry_values\":{\"status\":{\"option\":\"sent\"}}}"
check 2 "create voided"                add-record-to-list "{$L,\"entry_values\":{\"status\":\"voided\"}}"
check 0 "create lead, dnc false ok"    add-record-to-list "{$L,\"entry_values\":{\"stage\":\"New\",\"do_not_contact\":false}}"
check 0 "update voided"                update-list-entry-by-id "{$E,\"entry_values\":{\"status\":\"voided\",\"outcome\":\"dup\"}}"
check 2 "update draft"                 update-list-entry-by-id "{$E,\"entry_values\":{\"status\":\"draft\"}}" "status may only be written as voided"
check 2 "update approved by record"    update-list-entry-by-record-id "{$L,\"entry_values\":{\"status\":\"Approved\"}}"
check 2 "status by option UUID"        update-list-entry-by-id "{$E,\"entry_values\":{\"status\":\"49e56c99-597b-40b5-9413-162ce1adadfc\"}}"
check 2 "unknown value shape"          update-list-entry-by-id "{$E,\"entry_values\":{\"status\":{\"foo\":1}}}" "cannot check this call"
check 2 "dnc cleared"                  update-list-entry-by-id "{$E,\"entry_values\":{\"do_not_contact\":false}}" "do_not_contact is one-way"
check 2 "dnc cleared as string"        update-list-entry-by-id "{$E,\"entry_values\":{\"do_not_contact\":\"false\"}}"
check 0 "dnc set true"                 update-list-entry-by-id "{$E,\"entry_values\":{\"do_not_contact\":true}}"
check 0 "dnc set \"true\""             update-list-entry-by-id "{$E,\"entry_values\":{\"do_not_contact\":\"true\"}}"
check 2 "attribute by ID"              update-list-entry-by-id "{$E,\"entry_values\":{\"925c1cde-cba6-453e-96f9-5bd8f498d8a3\":\"sent\"}}" "addressed by ID"
check 2 "upsert with approved"         upsert-record '{"object":"people","matching_attribute":"email_addresses","values":{"status":"approved"}}'
check 0 "update person"                update-record '{"object":"people","record_id":"00000000-0000-0000-0000-000000000003","values":{"sp_role":"influencer"}}'
check 2 "create-list refused"          create-list '{"name":"x"}' "list configuration"
check 2 "update-list refused"          update-list '{"list":"sales_partner_outreach"}'
check 0 "read tool allowed"            list-records-in-list '{"list":"sales_partner_outreach"}'
check 2 "entry_values not an object"   update-list-entry-by-id "{$E,\"entry_values\":[1]}"
check 2 "tool_input not an object"     update-list-entry-by-id '"x"'
check 2 "unknown tool, approved"       assert-list-entry "{$E,\"entry_values\":{\"status\":\"approved\"}}"
check 0 "unknown tool, no values"      create-note '{"title":"t","content":"c"}'
check 2 "create-record approved"       create-record '{"object":"people","values":{"status":"approved"}}'
check 2 "mixed status dict"            add-record-to-list "{$L,\"entry_values\":{\"status\":{\"option\":\"draft\",\"title\":\"approved\"}}}"
raw   2 "malformed JSON blocks"        '{not json'
raw   2 "no tool_name blocks"          '{"tool_input":{}}'
[ -x "$G" ] && _report ok "guard is executable" || _report no "guard not executable"

finish
