#!/usr/bin/env bash
# Content checks for this agent: keys and rules that must stay consistent
# across files. Each block pins one change from the 2026-09-24 spec.
set -uo pipefail
cd "$(dirname "$0")/.."
source tests/lib.sh
SP=.

# Every file this suite reads must exist, or its assertions are meaningless.
missing=0
while IFS= read -r p; do
  f="${p/\$SP/$SP}"
  [ -e "$f" ] || { echo "  FAIL missing file referenced by tests: $f"; missing=1; }
done < <(grep -oE '"\$SP/[^"]+"' "$0" | tr -d '"' | sort -u)
[ "$missing" -eq 0 ] && _report ok "all referenced files exist" || _report no "referenced files missing"

echo "-- schedules"
assert_contains "$SP/skills/send-digest/SKILL.md" '`schedule_digest`'
assert_contains "$SP/skills/interview-business/SKILL.md" '`schedules.yaml`'
assert_contains "$SP/AGENT.md" 'Scheduled activities'
while IFS= read -r f; do
  assert_not_contains "$f" 'digest_schedule'
done < <(find "$SP" -name '*.md' -not -path './docs/*' -not -path './tests/*' -not -path './.git/*' -not -name README.md -not -path './.claude/*' -not -path './CLAUDE.md' -not -path './GEMINI.md' -not -path './AGENTS.md')

echo "-- prospecting sources"
assert_contains "$SP/context/operating-config.md" 'prospecting_sources: [apify_google_maps, apify_site_scraper, web_search]'
assert_contains "$SP/context/operating-config.md" '**`prospecting_sources`**'
assert_contains "$SP/subagents/prospector.md" 'only the sources listed in `prospecting_sources`'
assert_contains "$SP/subagents/prospector.md" '`apollo` is listed'
assert_contains "$SP/skills/interview-business/SKILL.md" '`prospecting_sources`'

echo "-- local ICP and radius"
assert_contains "$SP/context/icp.md" 'target_type:'
assert_contains "$SP/context/icp.md" 'size_measure:'
assert_contains "$SP/context/icp.md" 'service_area:'
assert_contains "$SP/context/icp.md" 'new opening or new location'
assert_contains "$SP/skills/score-lead/SKILL.md" '`service_area`'
assert_contains "$SP/skills/score-lead/SKILL.md" 'no sourced address'
assert_contains "$SP/skills/interview-business/SKILL.md" 'companies or local businesses'

echo "-- contact fields and dedupe"
C="$SP/capabilities/crm/contract.md"; A="$SP/capabilities/crm/tools/airtable/usage.md"
assert_contains "$C" '`company, location, industry, size, source, source_url`, plus optional `domain, address, phone, email, score, score_breakdown`'
assert_contains "$C" 'failing that, the same normalized `phone`'
assert_contains "$C" 'none of `domain`, `phone`, or `address`'
assert_contains "$C" '`lead_id, name, title, email, phone, linkedin_url, role, verified, notes`'
assert_contains "$C" 'listing, web_presence'
assert_contains "$A" '| `Address` | text |'
assert_contains "$A" '| `Phone` | phone |'
assert_pass bash -c "grep -A2 -F '| \`Address\` | text |' '$A' | tr -d '\n' | grep -qF '| \`Address\` | text || \`Phone\` | phone || \`Email\` | email |'"
assert_contains "$A" 'news, funding, social, event, hire, listing, web_presence'
assert_contains "$SP/skills/research-company/SKILL.md" 'hire, listing, web_presence'
assert_contains "$SP/skills/find-decision-makers/SKILL.md" 'email, phone, linkedin_url'
assert_contains "$SP/subagents/preparer.md" 'email, phone, linkedin_url'
assert_contains "$SP/subagents/prospector.md" '`Address`, `Phone`, `Email`'
assert_contains "$SP/AGENT.md" 'hire, listing, web presence'
assert_not_contains "$A" '`Domain` | text, unique'

echo "-- call channel"
assert_contains "$SP/skills/write-call-opener/SKILL.md" 'name: write-call-opener'
assert_contains "$SP/skills/write-call-opener/SKILL.md" 'channel="call"'
assert_contains "$SP/templates/cold-call-opener.md" 'Voicemail:'
assert_contains "$SP/subagents/approacher.md" 'only for a lead with a sourced phone number'
assert_contains "$SP/context/operating-config.md" '`call` in this list'
assert_contains "$SP/skills/send-digest/SKILL.md" 'number to dial'
assert_contains "$SP/templates/digest.md" 'number to dial'
assert_contains "$SP/AGENT.md" '`write-call-opener`'
assert_contains "$SP/context/operating-config.md" 'callback_phone:'
assert_contains "$SP/skills/write-call-opener/SKILL.md" '`callback_phone`'

echo "-- evals"
E="$SP/evals/cases.md"
assert_contains "$E" '## Case 9: A lead with no sourced address never scores inside the service area'
assert_contains "$E" '## Case 10: A business with no website is deduped on phone, then name and address'
assert_contains "$E" '## Case 11: A lead with no sourced phone never gets a call draft'
assert_contains "$E" '## Case 12: A source outside `prospecting_sources` is never used'
assert_contains "$E" 'These thirteen refusals'
assert_not_contains "$E" 'These twelve refusals'
assert_contains "$E" '## Case 13: A scheduled activity runs its `then` steps and nothing else'
assert_contains docs/superpowers/specs/2026-09-01-sales-partner-agent-design.md '2026-09-24-sales-partner-generalize-prospecting-design.md'

echo "-- phone normalization (I1)"
assert_contains "$C" 'normalized to E.164'
assert_contains "$C" 'never given a guessed country code'
assert_contains "$A" 'normalized to E.164'
assert_contains "$A" 'never given a guessed country code'
assert_contains "$E" '`+15550104477`'

echo "-- sourced distance (I3)"
assert_contains "$SP/skills/score-lead/SKILL.md" 'distance not sourced — unverified'
assert_contains "$SP/context/icp.md" 'distance not sourced — unverified'
assert_contains "$E" 'distance not sourced — unverified'

echo "-- interview asks what it writes (I4)"
I="$SP/skills/interview-business/SKILL.md"
assert_contains "$I" 'which size measure fits'
assert_contains "$I" 'the service area center and radius'
assert_contains "$I" 'which events signal a prospect is newly in-market'
assert_contains "$I" 'Target roles, Buying triggers, Anti-signals'

echo "-- evals widened (I6)"
assert_contains "$E" '`100×0.10=10`'
assert_contains "$E" 'same normalized company and address'
assert_contains "$E" 'may get a `Channel = call` draft'
assert_contains "$E" 'then_prospect: prepare'

echo "-- minors (M1-M11, D1-D2)"
assert_contains "$SP/skills/send-digest/SKILL.md" 'CRM **`get_lead`**'
assert_not_contains "$SP/context/icp.md" 'headcount/revenue falls'
assert_contains "$SP/context/icp.md" 'bands in `size_measure`'
assert_contains "$SP/context/icp.md" 'a sourced direct phone number'
assert_contains "$SP/skills/find-decision-makers/SKILL.md" 'public business registries'
assert_contains "$SP/skills/find-decision-makers/SKILL.md" 'an owner is written with `role: decision-maker`'
assert_contains "$SP/AGENT.md" 'a phone number, an address, a distance'
assert_contains "$SP/subagents/approacher.md" '`callback_phone`'
assert_contains "$SP/subagents/prospector.md" 'Existing leads, read via CRM'
assert_contains "$SP/subagents/prospector.md" 'Every source listed in `prospecting_sources` is exhausted'
assert_contains "$SP/subagents/preparer.md" '`apify_google_maps`'
assert_contains "$SP/skills/write-call-opener/SKILL.md" 'status="draft"'
assert_contains "$SP/skills/write-call-opener/SKILL.md" 'never dials'
assert_contains "$SP/skills/write-call-opener/SKILL.md" 'never an invented number'
assert_contains "$SP/subagents/approacher.md" 'places, schedules, or records a call'
assert_contains docs/superpowers/specs/2026-09-01-sales-partner-agent-design.md 'holds thirteen cases'
assert_contains "$SP/AGENT.md" '`schedule_digest` in the instance'"'"'s `schedules.yaml`'
assert_not_contains "$SP/AGENT.md" 'on the schedule in'
assert_not_contains "$SP/skills/send-digest/SKILL.md" 'digest schedule in operating-config.md'

echo "-- instance mode (1.1)"
assert_contains "$SP/agent.yaml" 'catalog_repo: webspenser/agent-library'
assert_contains "$SP/skills/setup/SKILL.md" '`interview-business`'

echo "-- 1.0.1: hook points at AGENT.md; samples and context ownership"
assert_contains "$SP/hooks/session-start.sh" 'Read the full instructions now, before anything else'
SP_VERSION=$(sed -n 's/^version: //p' "$SP/agent.yaml" | head -n 1)
assert_contains "$SP/README.md" "Version $SP_VERSION."
assert_not_contains "$SP/skills/setup/SKILL.md" '<interview-skill>'
assert_not_contains "$SP/skills/setup/SKILL.md" '<context-files>'
assert_contains "$SP/skills/setup/SKILL.md" '`context/business-profile.md`, `context/icp.md`, `context/operating-config.md`'
assert_contains "$SP/skills/interview-business/SKILL.md" 'into the instance'"'"'s `context/samples/`'
assert_not_contains "$SP/skills/interview-business/SKILL.md" 'artifacts supplied into `samples/`'
assert_contains "$SP/subagents/approacher.md" 'the instance'"'"'s `context/samples/` first, then the package'"'"'s `samples/`'
echo "-- capabilities"
assert_contains "$SP/capabilities/crm/contract.md" '## Invariants'
assert_contains "$SP/capabilities/crm/contract.md" '- `draft_only` —'
assert_contains "$SP/capabilities/crm/contract.md" '- `dnc_one_way` —'
assert_contains "$SP/capabilities/crm/contract.md" '- `no_delete` —'
assert_contains "$SP/capabilities/crm/tools/airtable/usage.md" '## Probe'
assert_pass bash -c "[ \"\$(wc -l < '$SP/capabilities/crm/tools/airtable/identity.yaml' | tr -d ' ')\" = 3 ] && grep -qx 'capability: crm' '$SP/capabilities/crm/tools/airtable/identity.yaml' && grep -qx 'provider: airtable' '$SP/capabilities/crm/tools/airtable/identity.yaml' && grep -qx 'server_match: airtable' '$SP/capabilities/crm/tools/airtable/identity.yaml'"
assert_contains "$SP/AGENT.md" 'bound in `instance.yaml` (`bind_crm`)'

for h in CLAUDE GEMINI AGENTS; do
  git -C "$SP" check-ignore --no-index -q "hosts/$h.md" \
    && _report no ".gitignore ignores hosts/$h.md" || _report ok "hosts/$h.md is not ignored"
done

echo "-- Attio tool"
AT="$SP/capabilities/crm/tools/attio"
assert_contains "$AT/usage.md" '## Probe'
assert_contains "$AT/usage.md" 'lead_source_outbound: yes'
assert_not_contains "$AT/usage.md" 'Webspenser'
[ -x "$AT/bootstrap.py" ] && _report ok "bootstrap.py present and executable" || _report no "bootstrap.py missing or not executable"
assert_not_contains "$AT/bootstrap.py" '.env'
for op in create_lead get_lead update_stage update_lead log_activity update_activity log_research upsert_contact query_by_stage query_by_score query_activities; do
  assert_contains "$AT/usage.md" "\`$op\`"
done

echo "-- HubSpot tool"
HT="$SP/capabilities/crm/tools/hubspot"
assert_contains "$HT/usage.md" '## Probe'
assert_contains "$HT/usage.md" '## Setup'
assert_contains "$HT/usage.md" 'hub_id:'
assert_contains "$HT/usage.md" 'CONFIRMATION_WAIVED_FOR_SESSION'
assert_not_contains "$HT/usage.md" 'Webspenser'
[ -x "$HT/bootstrap.py" ] && _report ok "hubspot bootstrap.py present and executable" || _report no "hubspot bootstrap.py missing or not executable"
assert_contains "$HT/bootstrap.py" 'HUBSPOT_TOKEN'
for op in create_lead get_lead update_stage update_lead log_activity update_activity log_research upsert_contact query_by_stage query_by_score query_activities; do
  assert_contains "$HT/usage.md" "\`$op\`"
done

echo "-- 4.0 final review"
assert_contains "$HT/usage.md" 'read -rs HUBSPOT_TOKEN && export HUBSPOT_TOKEN'
assert_contains "$AT/usage.md" 'read -rs ATTIO_API_KEY && export ATTIO_API_KEY'
assert_contains "$HT/bootstrap.py" 'read -rs HUBSPOT_TOKEN && export HUBSPOT_TOKEN'
assert_contains "$SP/skills/setup/SKILL.md" 'read -rs <VAR> && export <VAR>'
if grep -rnE 'export [A-Z_]*(TOKEN|KEY)=' "$SP/capabilities" "$SP/skills" "$SP/README.md" "$SP/AGENT.md" 2>/dev/null | grep -q .; then
  _report no "a key is set with export VAR=..., which lands in shell history"; else _report ok "no export VAR=<key> instructions"; fi
[ "$(grep -cF 'apply the `sp_stage` check' "$HT/usage.md")" -ge 3 ] && _report ok "create_lead: domain, phone and address matches all apply the sp_stage check" || _report no "create_lead: a match step skips the sp_stage check"
assert_contains "$HT/usage.md" 'Never overwrite a native field that already has a value'
assert_contains "$HT/usage.md" 'only when the search showed its current'
u=$(awk '/^### Choice 1/,/^### Choice 2/' "$HT/usage.md" | grep -oE '^\| `sp_[a-z_]+`' | tr -d '|` ' | sort | tr '\n' ,)
b=$(python3 -B -c "
import importlib.util,sys
sp=importlib.util.spec_from_file_location('b','$HT/bootstrap.py'); m=importlib.util.module_from_spec(sp); sp.loader.exec_module(m)
print(sorted(m.PROPERTIES)==['companies','contacts'] and ''.join(n+',' for n in sorted(p['name'] for o in m.PROPERTIES.values() for p in o)) or 'unexpected objects: '+','.join(m.PROPERTIES))")
[ -n "$u" ] && [ "$b" = "$u" ] && _report ok "Setup tables and bootstrap.py create the same properties, companies and contacts only" || _report no "Setup vs bootstrap.py: usage.md=$u bootstrap.py=$b"
assert_contains "$HT/usage.md" "Tasks need no custom fields; drafts use HubSpot's built-in task status."
assert_contains "$HT/guard.yaml" 'field: hs_task_status'
if grep -nE 'sp_(status|channel|direction|summary|outcome)' "$HT/usage.md" "$HT/bootstrap.py" "$HT/guard.yaml" | grep -q .; then
  _report no "the HubSpot tool still mentions a custom task field"; else _report ok "no custom task fields in the HubSpot tool"; fi

echo "-- email drafts"
assert_contains "$SP/agent.yaml" 'capabilities: crm, email_drafts'
assert_not_contains "$SP/AGENT.md" 'delivers it directly'
assert_contains "$SP/capabilities/email_drafts/contract.md" '- `no_send` —'
assert_contains "$SP/capabilities/email_drafts/tools/gmail/guard.yaml" 'covers: [no_send]'
assert_contains "$SP/capabilities/crm/tools/attio/guard.yaml" 'covers: [draft_only, dnc_one_way, no_delete]'
for y in "$SP"/capabilities/*/tools/*/identity.yaml; do
  assert_pass bash -c "{ [ \"\$(grep -c . '$y')\" = 3 ] || { [ \"\$(grep -c . '$y')\" = 4 ] && grep -qx 'wrapper: n8n' '$y'; }; } && grep -q '^capability: ' '$y' && grep -q '^provider: ' '$y' && grep -q '^server_match: ' '$y'"
done
[ ! -e "$AT/guard.py" ] && _report ok "guard.py removed" || _report no "guard.py still present"
assert_contains "$SP/skills/setup/SKILL.md" '**Tools.**'
assert_contains "$SP/skills/setup/SKILL.md" 'whether the tool'"'"'s guard policy covers it'
assert_contains "$SP/skills/send-digest/SKILL.md" 'cannot send; delivered as a draft'

allowed_by() { # allowed_by <policy> <prefix> <tool>
  printf '{"tool_name":"%s%s","tool_input":{}}' "$2" "$3" | python3 -B "$SP/hooks/guard_policy.py" "$1" - x >/dev/null 2>&1
}
in_allow() { # in_allow <policy> <prefix> <tool>: listed and not denied; a write may still exit 2 for missing bindings
  local out
  out=$(printf '{"tool_name":"%s%s","tool_input":{}}' "$2" "$3" | python3 -B "$SP/hooks/guard_policy.py" "$1" - x 2>&1)
  case "$out" in *"is not in the allow list"*|*"is denied"*|*"cannot check"*|*Traceback*) return 1 ;; esac
  return 0
}
for t in $(grep -oE 'attio:[a-z-]+' "$SP/capabilities/crm/tools/attio/usage.md" | sort -u | cut -d: -f2); do
  allowed_by "$SP/capabilities/crm/tools/attio/guard.yaml" mcp__attio__ "$t" && _report ok "Attio $t allowed" || _report no "Attio $t not in guard.yaml allow"
done
for t in $(grep -oE 'gmail:[a-z_]+' "$SP/capabilities/email_drafts/tools/gmail/usage.md" | sort -u | cut -d: -f2); do
  allowed_by "$SP/capabilities/email_drafts/tools/gmail/guard.yaml" mcp__gmail__ "$t" && _report ok "Gmail $t allowed" || _report no "Gmail $t not in guard.yaml allow"
done
for t in $(grep -oE 'airtable:[a-z_]+' "$SP/capabilities/crm/tools/airtable/usage.md" | sort -u | cut -d: -f2); do
  in_allow "$SP/capabilities/crm/tools/airtable/guard.yaml" mcp__airtable__ "$t" && _report ok "Airtable $t allowed" || _report no "Airtable $t not in guard.yaml allow"
done
for t in $(grep -oE 'hubspot:[a-z_]+' "$SP/capabilities/crm/tools/hubspot/usage.md" | sort -u | cut -d: -f2); do
  allowed_by "$SP/capabilities/crm/tools/hubspot/guard.yaml" mcp__hubspot__ "$t" && _report ok "HubSpot $t allowed" || _report no "HubSpot $t not in guard.yaml allow"
done
assert_contains "$SP/capabilities/crm/tools/airtable/usage.md" 'field_status'

echo "-- scheduled runs"
assert_contains "$SP/agent.yaml" 'standard: "6.0"'
assert_contains "$SP/agent.yaml" 'activity_digest: crm, email_drafts'
assert_contains "$SP/agent.yaml" 'activity_approach: crm'
assert_not_contains "$SP/agent.yaml" 'activity_approach: crm, email_drafts'
assert_contains "$SP/skills/send-digest/SKILL.md" 'DO NOT SEND — lead is Do Not Contact'
assert_contains "$SP/skills/send-digest/SKILL.md" 'Possible duplicate leads'
assert_contains "$SP/AGENT.md" 'this rule is an instruction'
assert_not_contains "$SP/context/operating-config.md" 'schedules:'
assert_not_contains "$SP/context/operating-config.md" 'timezone:'
assert_not_contains "$SP/context/operating-config.md" 'cron + headless CLI'
assert_not_contains "$SP/context/operating-config.md" 'n8n'
assert_contains "$SP/skills/interview-business/SKILL.md" 'schedules.yaml'
assert_contains "$SP/skills/send-digest/SKILL.md" 'schedule_digest'
assert_contains "$SP/AGENT.md" 'schedules.yaml'
assert_contains "$SP/AGENT.md" 'unattended'
[ -f "$SP/skills/schedule/SKILL.md" ] && _report ok "schedule skill present" || _report no "schedule skill missing"

echo "-- 4.0.4: AGENT.md inline size, idle rule"
[ "$(wc -c < "$SP/AGENT.md" | tr -d ' ')" -le 9000 ] && _report ok "AGENT.md fits the 9000-byte inline limit" || _report no "AGENT.md is over 9000 bytes; the hook will not inline it"
assert_contains "$SP/capabilities/crm/contract.md" '## Lead status transitions'
assert_contains "$SP/capabilities/crm/contract.md" 'draft Activities (one per enabled channel: the recommended channel'"'"'s full draft and statements, the others'"'"' statements) at `status: draft`'
assert_contains "$SP/AGENT.md" '`capabilities/crm/contract.md` (Lead status, Lead status transitions)'
assert_contains "$SP/context/icp.md" '`capabilities/crm/contract.md` (Lead status transitions)'
assert_contains "$SP/capabilities/crm/contract.md" 'idle age = now − `max(last Activity date, Stage Changed'
assert_contains "$SP/capabilities/crm/contract.md" 'at all is measured from its `Stage Changed At` alone'
D="$SP/skills/send-digest/SKILL.md"
assert_contains "$SP/capabilities/crm/tools/airtable/usage.md" 'has no Activity, use `Stage Changed At`'
assert_contains "$SP/capabilities/crm/tools/attio/usage.md" '`stage_changed_at`. If the lead has no'
assert_contains "$SP/capabilities/crm/tools/hubspot/usage.md" 'If the lead has no Task'
echo "-- 5.0.0: void outcome Note, Airtable field IDs, changed fields only"
HU="$SP/capabilities/crm/tools/hubspot/usage.md"; AU="$SP/capabilities/crm/tools/airtable/usage.md"
assert_contains "$HU" 'Outcome for task <activity_id>:'
assert_contains "$HU" 'are outcomes, not Research'
assert_not_contains "$HU" 'body with Outcome: line'
assert_not_contains "$HU" 'appends an `Outcome: <outcome>` line'
assert_contains "$AU" 'every field of the four tables'
assert_contains "$AU" 'is not a recorded field ID'
assert_contains "$AU" 'retry the write once'
assert_not_contains "$AU" 'binding_id'
assert_not_contains "$AU" 'stays blocked until the probe has recorded both'
for f in "$SP"/capabilities/crm/tools/*/usage.md; do assert_contains "$f" 'Write only the fields that change'; done
assert_not_contains "$SP/capabilities/email_drafts/tools/gmail/usage.md" 'add its names to'
assert_contains "$SP/capabilities/email_drafts/tools/gmail/usage.md" 'matches names by suffix'
assert_contains "$AU" 'In a scheduled run, do not rewrite'
assert_contains "$AU" 'take each field ID from that table'

echo "-- 6.0.0: Ready to Send and sent"
K="$SP/capabilities/crm/contract.md"
python3 -c "import sys; t=open('$K').read(); sys.exit(0 if 'Approach Drafted\nReady to Send\nContacted' in t else 1)" && _report ok "stage order has Ready to Send" || _report no "stage order lacks Ready to Send"
assert_contains "$K" '| `Ready to Send` |'
assert_contains "$K" 'only the operator writes `Ready to Send`'
assert_contains "$K" 'the only status it may later write is `voided`'
assert_not_contains "$K" '`approved`'
assert_not_contains "$SP/AGENT.md" 'twelve lead stages'
assert_contains "$SP/AGENT.md" 'The lead statuses and their transitions'
assert_not_contains "$SP/evals/cases.md" 'approved'

echo "-- 6.0.0: CRM tools"
assert_contains "$SP/capabilities/crm/tools/attio/usage.md" 'Ready to Send'
assert_not_contains "$SP/capabilities/crm/tools/attio/usage.md" '`approved`'
assert_not_contains "$SP/capabilities/crm/tools/attio/usage.md" 'Awaiting Approval'
assert_not_contains "$SP/capabilities/crm/tools/attio/usage.md" 'twelve'
assert_contains "$SP/capabilities/crm/tools/airtable/usage.md" 'Ready to Send'
assert_not_contains "$SP/capabilities/crm/tools/airtable/usage.md" '`approved`'
assert_not_contains "$SP/capabilities/crm/tools/airtable/usage.md" 'Awaiting Approval'
assert_not_contains "$SP/capabilities/crm/tools/airtable/usage.md" 'twelve'
assert_contains "$SP/capabilities/crm/tools/hubspot/usage.md" 'Ready to Send'
assert_not_contains "$SP/capabilities/crm/tools/hubspot/usage.md" '`approved`'
assert_not_contains "$SP/capabilities/crm/tools/hubspot/usage.md" 'Awaiting Approval'
assert_not_contains "$SP/capabilities/crm/tools/hubspot/usage.md" 'twelve'
grep -q '"Ready to Send"' "$SP/capabilities/crm/tools/attio/bootstrap.py" && _report ok "attio bootstrap has Ready to Send" || _report no "attio bootstrap lacks Ready to Send"
grep -q '"Ready to Send"' "$SP/capabilities/crm/tools/hubspot/bootstrap.py" && _report ok "hubspot bootstrap has Ready to Send" || _report no "hubspot bootstrap lacks Ready to Send"
assert_not_contains "$SP/capabilities/crm/tools/attio/bootstrap.py" '"approved"'

echo "-- 6.0.0: personalization and config"
OC="$SP/context/operating-config.md"
assert_contains "$SP/subagents/approacher.md" 'never an address with a `bounced` Activity'

echo "-- 6.0.0: lead status"
K="$SP/capabilities/crm/contract.md"
python3 -c "import sys; t=open('$K').read(); sys.exit(0 if 'Ready to Send\nContacted\nEngaged\nOpen Deal\nNurture\nCustomer\nDisqualified' in t else 1)" && _report ok "status order" || _report no "status order"
assert_contains "$K" 'A lead holds exactly one of these eleven statuses'
assert_contains "$K" 'Revisit On'
assert_not_contains "$K" 'Call Scheduled'
assert_not_contains "$K" 'Call Held'
assert_not_contains "$K" 'Following Up'
assert_not_contains "$K" '`Replied`'
assert_not_contains "$K" '`Won`'
assert_not_contains "$K" '`Lost`'
assert_contains "$SP/subagents/prospector.md" 'unless its status is `New`'
assert_contains "$SP/subagents/prospector.md" 'Revisit On'
assert_contains "$SP/capabilities/crm/tools/attio/usage.md" 'Engaged'
assert_contains "$SP/capabilities/crm/tools/attio/usage.md" 'revisit_on'
assert_not_contains "$SP/capabilities/crm/tools/attio/usage.md" 'Call Scheduled'
assert_not_contains "$SP/capabilities/crm/tools/attio/usage.md" 'thirteen'
assert_contains "$SP/capabilities/crm/tools/airtable/usage.md" 'Engaged'
assert_contains "$SP/capabilities/crm/tools/airtable/usage.md" 'Revisit On'
assert_not_contains "$SP/capabilities/crm/tools/airtable/usage.md" 'Call Scheduled'
assert_not_contains "$SP/capabilities/crm/tools/airtable/usage.md" 'thirteen'
assert_contains "$SP/capabilities/crm/tools/hubspot/usage.md" 'Engaged'
assert_contains "$SP/capabilities/crm/tools/hubspot/usage.md" 'sp_revisit_on'
assert_not_contains "$SP/capabilities/crm/tools/hubspot/usage.md" 'Call Scheduled'
assert_not_contains "$SP/capabilities/crm/tools/hubspot/usage.md" 'thirteen'
grep -q '"Engaged"' "$SP/capabilities/crm/tools/attio/bootstrap.py" && grep -q 'revisit_on' "$SP/capabilities/crm/tools/attio/bootstrap.py" && ! grep -q '"Call Scheduled"' "$SP/capabilities/crm/tools/attio/bootstrap.py" && _report ok "attio bootstrap: eleven statuses, revisit_on" || _report no "attio bootstrap statuses"
grep -q '"Engaged"' "$SP/capabilities/crm/tools/hubspot/bootstrap.py" && grep -q 'sp_revisit_on' "$SP/capabilities/crm/tools/hubspot/bootstrap.py" && ! grep -q '"Call Scheduled"' "$SP/capabilities/crm/tools/hubspot/bootstrap.py" && _report ok "hubspot bootstrap: eleven statuses, sp_revisit_on" || _report no "hubspot bootstrap statuses"


echo "-- 6.0.0: call and follow-up stages removed"
for f in subagents/sales-call-specialist.md subagents/follow-up.md skills/prepare-sales-call skills/run-live-call-script skills/handle-objections skills/write-follow-up templates/call-brief.md templates/objection-matrix.md templates/follow-up-email.md; do
  [ ! -e "./$f" ] && _report ok "removed: $f" || _report no "still present: $f"  # ./ so the referenced-files check skips it
done
! grep -q '^activity_follow-up' "$SP/agent.yaml" && _report ok "no follow-up activity" || _report no "activity_follow-up still declared"
assert_not_contains "$SP/context/operating-config.md" 'max_touches'
assert_not_contains "$SP/context/operating-config.md" 'follow_up_cadence_days'
assert_not_contains "$SP/skills/interview-business/SKILL.md" 'max_touches'
assert_not_contains "$SP/skills/send-digest/SKILL.md" 'Stalled'
assert_not_contains "$SP/templates/digest.md" 'Stalled'
if grep -rlE "sales-call-specialist|Sales-call-specialist|write-follow-up|handle-objections|prepare-sales-call|run-live-call-script|subagents/follow-up" "$SP/AGENT.md" "$SP/skills" "$SP/subagents" "$SP/capabilities" "$SP/context" "$SP/templates" "$SP/evals" | grep -q .; then _report no "references to removed pieces remain"; else _report ok "no references to removed pieces"; fi
assert_contains "$SP/agent.yaml" 'finds, scores and researches fresh leads'


echo "-- 6.0.0: digest, channel filter"
D="$SP/skills/send-digest/SKILL.md"
assert_contains "$D" '**Section 1 — Review.**'
assert_contains "$D" '**Section 2 — Ready to Send.**'
assert_not_contains "$D" 'Awaiting approval'
assert_not_contains "$D" 'Call Scheduled'
T="$SP/templates/digest.md"
assert_contains "$T" '## Review ([count])'
assert_contains "$T" '## Ready to Send ([count])'
assert_not_contains "$T" 'Won:'
K="$SP/capabilities/crm/contract.md"
assert_contains "$K" '| `query_activities` | `status, direction, channel, since, until, limit` |'
assert_contains "$SP/capabilities/crm/tools/attio/usage.md" '`channel` when given'
assert_contains "$SP/capabilities/crm/tools/airtable/usage.md" '`Channel` when given'
assert_contains "$SP/capabilities/crm/tools/hubspot/usage.md" '`channel` when given'


echo "-- 6.0.0: AGENT.md and onboarding"
A="$SP/AGENT.md"
wc -c < "$A" | awk '{exit !($1 < 6000)}' && _report ok "AGENT.md under 6000 bytes" || _report no "AGENT.md 6000 bytes or more"
assert_contains "$A" 'Engaged'
assert_contains "$A" 'Open Deal'
assert_contains "$A" 'Ready to Send'
assert_not_contains "$A" 'Sales call specialist'
assert_not_contains "$A" 'Follow-up'
assert_not_contains "$A" 'max_touches'
IV="$SP/skills/interview-business/SKILL.md"
assert_contains "$SP/README.md" 'lead generation and personalization'


echo "-- 6.0.0: final review fixes"
PR="$SP/subagents/prospector.md"
assert_contains "$PR" 'leave it untouched unless its status is `New`, or `Nurture` with a Revisit On date in the past'
assert_contains "$PR" '- CRM `get_lead`'
assert_contains "$SP/capabilities/crm/tools/airtable/usage.md" '`Lead Stage` is `Ready to Send` or `Contacted`'
assert_contains "$SP/capabilities/crm/tools/attio/usage.md" 'only for leads at `Ready to Send` or `Contacted`'
assert_contains "$SP/capabilities/crm/tools/hubspot/usage.md" 'only for leads at `Ready to Send` or `Contacted`'
assert_not_contains "$SP/context/operating-config.md" '`approved`'
assert_contains "$SP/context/operating-config.md" 'only the operator approves a plan'
AP="$SP/subagents/approacher.md"
assert_not_contains "$AP" 'One opening touch per lead'
assert_contains "$AP" 'prepares the lead'"'"'s first touch'
assert_contains "$AP" 'redraft'
E="$SP/evals/cases.md"
assert_contains "$E" 'at `Contacted` and one at `Ready to Send`'

echo "-- 6.0.0: lead generation and personalization (sending leaves)"
for f in capabilities/sequences skills/enroll skills/sync-replies; do
  [ ! -e "./$f" ] && _report ok "removed: $f" || _report no "still present: $f"  # ./ so the referenced-files check skips it
done
grep -qx 'capabilities: crm, email_drafts' "$SP/agent.yaml" && _report ok "capabilities: crm, email_drafts" || _report no "capabilities line still lists more than crm, email_drafts"
! grep -qE '^activity_(enroll|sync-replies):' "$SP/agent.yaml" && _report ok "no enroll or sync-replies activity" || _report no "enroll or sync-replies still declared"
OC="$SP/context/operating-config.md"
IV="$SP/skills/interview-business/SKILL.md"
for k in sequence_bands allowed_countries eu_uk_legitimate_interest canada_consent_basis touch_spacing_days; do
  assert_not_contains "$OC" "$k"
  assert_not_contains "$IV" "$k"
done
assert_not_contains "$IV" 'InvokeIQ'
assert_not_contains "$IV" 'sending domain'
assert_not_contains "$IV" '`enroll`'
assert_not_contains "$SP/skills/setup/SKILL.md" 'accept_instruction_only'
assert_not_contains "$SP/skills/setup/SKILL.md" 'enroll'
D="$SP/skills/send-digest/SKILL.md"
T="$SP/templates/digest.md"
for f in "$D" "$T"; do
  assert_not_contains "$f" 'Enrolled'
  assert_not_contains "$f" 'Replies'
  assert_not_contains "$f" 'InvokeIQ'
  assert_not_contains "$f" 'enroll'
done
assert_contains "$D" 'six fixed sections'
assert_contains "$D" '**Section 6 — Spend.**'
assert_contains "$D" 'waiting for the owner'"'"'s hand-off'
assert_contains "$T" 'Six sections'
assert_contains "$D" 'not time since approval'
assert_contains "$D" "Owner's pipeline now"
assert_contains "$T" "Owner's pipeline now"
assert_not_contains "$SP/README.md" 'InvokeIQ'
assert_not_contains "$SP/README.md" 'enroll'
assert_not_contains "$SP/guard.yaml" 'InvokeIQ'
assert_contains "$SP/guard.yaml" '"*_workflow*"'

echo "-- 6.0.0: the agent stops at Approach Drafted"
K="$SP/capabilities/crm/contract.md"
assert_contains "$K" '**The agent'"'"'s job ends at `Approach Drafted`.**'
assert_contains "$K" '| `update_activity` | `activity_id, status, outcome` | updated activity | Accepts only `status: "voided"`'
assert_contains "$K" 'the owner'"'"'s automation'
assert_contains "$K" '**Opt-outs.**'
assert_contains "$K" 'outcome: "opt-out"'
assert_not_contains "$K" 'enroll'
assert_not_contains "$K" 'sync-replies'
assert_not_contains "$K" 'a bounced email returns it'
for c in attio airtable hubspot; do
  G="./capabilities/crm/tools/$c/guard.yaml"
  grep -qF 'update: [Scored, Researched, "Approach Drafted", Disqualified]' "$G" && _report ok "$c guard: agent statuses end at Approach Drafted" || _report no "$c guard stage update list"
  U="./capabilities/crm/tools/$c/usage.md"
  assert_not_contains "$U" 'enroll'
  assert_not_contains "$U" 'sync-replies'
  assert_not_contains "$U" 'sequences'
done
grep -qF 'update: [voided]' "$SP/capabilities/crm/tools/attio/guard.yaml" && grep -qF 'update: [voided]' "$SP/capabilities/crm/tools/airtable/guard.yaml" && grep -qF 'update: [DEFERRED]' "$SP/capabilities/crm/tools/hubspot/guard.yaml" && _report ok "guards: agent only voids Activities" || _report no "guards: Activity status update list"
assert_contains "$SP/capabilities/crm/tools/attio/usage.md" '**`update_activity`** — Reject `status` other than `voided`.'
assert_contains "$SP/capabilities/crm/tools/hubspot/usage.md" 'Reject a `status` other than `voided`.'
assert_contains "$SP/capabilities/crm/tools/airtable/usage.md" 'accepts only `status: "voided"`'
assert_contains "$SP/context/operating-config.md" '`update_activity` moves it only to `voided`'
E="$SP/evals/cases.md"
assert_contains "$E" '## Case 5: Opt-out sets Do Not Contact and voids pending drafts'
assert_not_contains "$E" 'enroll'
assert_not_contains "$E" 'sync-replies'
assert_not_contains "$E" 'suppress'

echo "-- 6.0.0: recommendation and personalized statements"
AP="$SP/subagents/approacher.md"
assert_contains "$AP" 'recommended: <one-line reason>'
assert_contains "$AP" 'summary `statements`'
assert_contains "$AP" 'one draft Activity per enabled channel'
assert_contains "$AP" 'the full draft only for the recommended channel'
assert_contains "$AP" 'templates/personalized-statements.md'
assert_contains "$AP" 'never an address with a `bounced` Activity'
assert_not_contains "$AP" 'touch_spacing_days'
assert_not_contains "$AP" 'sequences'
assert_not_contains "$AP" 'sequence platform'
assert_not_contains "$AP" 'variables:'
assert_not_contains "$AP" 'enroll'
assert_not_contains "$AP" 'moves to `Contacted`'
PS="$SP/templates/personalized-statements.md"
for l in 'opener:' 'relevance:' 'proof:' 'ask:'; do assert_contains "$PS" "$l"; done
assert_contains "$PS" 'Personalized statements'
assert_contains "$PS" 'two to four lines'
for w in write-cold-email write-linkedin-touch write-call-opener; do
  assert_contains "./skills/$w/SKILL.md" '## Personalized statements'
  assert_contains "./skills/$w/SKILL.md" 'templates/personalized-statements.md'
  assert_contains "./skills/$w/SKILL.md" 'summary="statements"'
done
assert_not_contains "$SP/skills/write-cold-email/SKILL.md" 'sequences'
assert_not_contains "$SP/skills/write-cold-email/SKILL.md" 'variables:'
assert_not_contains "$SP/templates/cold-email.md" 'sequences'
assert_contains "$SP/skills/write-linkedin-touch/SKILL.md" 'one Activity holding both'
assert_contains "$SP/capabilities/crm/tools/attio/usage.md" 'the `recommended:` one holds the full draft'
assert_contains "$SP/capabilities/crm/tools/airtable/usage.md" 'the `recommended:` one holds the full draft'
assert_contains "$SP/capabilities/crm/tools/hubspot/usage.md" 'the `recommended:` one holds the full draft'
assert_contains "$SP/evals/cases.md" '## Case 14: The first touch is one recommendation plus statements per channel'

echo "-- 6.0.0: AGENT.md and manifests describe lead generation and personalization"
A="$SP/AGENT.md"
assert_contains "$A" 'lead generation and personalization'
assert_contains "$A" 'stops at `Approach Drafted`'
assert_contains "$A" 'never act on a lead at'
assert_contains "$A" '`recommended:`'
assert_not_contains "$A" 'enroll'
assert_not_contains "$A" 'sync-replies'
assert_not_contains "$A" 'sequence'
D=$(grep '^description: ' "$SP/agent.yaml" | sed 's/^description: //')
case "$D" in *"personalized statements"*) _report ok "agent.yaml description names personalized statements" ;; *) _report no "agent.yaml description: $D" ;; esac
for m in .claude-plugin/plugin.json .codex-plugin/plugin.json gemini-extension.json .claude-plugin/marketplace.json; do
  grep -qF "$D" "./$m" && _report ok "$m description matches agent.yaml" || _report no "$m description differs from agent.yaml"
done
if grep -rlE "enroll|sync-replies|InvokeIQ|invokeiq|sequence_bands|bind_sequences|touch_spacing|enroll_ready_only" "$SP/AGENT.md" "$SP/README.md" "$SP/agent.yaml" "$SP/skills" "$SP/subagents" "$SP/capabilities" "$SP/context" "$SP/templates" "$SP/evals" "$SP/samples" | grep -q .; then _report no "references to sending pieces remain"; else _report ok "no references to sending pieces"; fi

finish
