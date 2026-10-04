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

echo "-- follow-up channel (I5)"
F="$SP/subagents/follow-up.md"
assert_contains "$F" 'chosen from `enabled_channels`'
assert_contains "$F" '`skills/write-call-opener/SKILL.md`'
assert_contains "$F" 'no enabled channel has a sourced route'
assert_not_contains "$F" '`Channel = email`,'
assert_contains "$SP/skills/write-follow-up/SKILL.md" 'the email path'

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
assert_contains "$SP/context/operating-config.md" '`write-follow-up`, and `write-call-opener`'
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
assert_contains "$SP/subagents/follow-up.md" '`email_drafts` — `create_draft`'
assert_not_contains "$SP/subagents/follow-up.md" '- Gmail — draft only'

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

echo "-- 4.0.4: AGENT.md inline size, exact Stalled rule"
[ "$(wc -c < "$SP/AGENT.md" | tr -d ' ')" -le 9000 ] && _report ok "AGENT.md fits the 9000-byte inline limit" || _report no "AGENT.md is over 9000 bytes; the hook will not inline it"
assert_contains "$SP/capabilities/crm/contract.md" '## Stage transitions'
assert_contains "$SP/capabilities/crm/contract.md" 'draft Activities (one per enabled channel, each with its date) at `status: draft`'
assert_contains "$SP/AGENT.md" '`capabilities/crm/contract.md` (Stage enum, Stage transitions)'
assert_contains "$SP/context/icp.md" '`capabilities/crm/contract.md` (Stage transitions)'
assert_contains "$SP/capabilities/crm/contract.md" 'idle age = now − `max(last Activity date, Stage Changed'
assert_contains "$SP/capabilities/crm/contract.md" 'at all is measured from its `Stage Changed At` alone'
D="$SP/skills/send-digest/SKILL.md"
assert_contains "$D" '`Contacted`, `Replied`, `Call Scheduled`, `Call Held` or'
assert_contains "$D" 'Pre-outreach stages (`New`, `Scored`, `Researched`, `Approach'
assert_contains "$D" 'The same CRM data always gives the same'
assert_contains "$D" 'once for each of those five stages'
assert_not_contains "$D" 'every active stage'
assert_contains "$SP/capabilities/crm/tools/airtable/usage.md" 'has no Activity, use `Stage Changed At`'
assert_contains "$SP/capabilities/crm/tools/attio/usage.md" '`stage_changed_at`. If the lead has no'
assert_contains "$SP/capabilities/crm/tools/hubspot/usage.md" 'If the lead has no Task'
assert_contains "$SP/subagents/follow-up.md" 'call per stage, for `Contacted`, `Replied`'
assert_contains "$SP/subagents/follow-up.md" 'and `Following Up` only'
assert_contains "$SP/subagents/follow-up.md" 'never with `stage`'
assert_not_contains "$SP/subagents/follow-up.md" 'query_by_stage(idle_days:'
assert_contains "$SP/AGENT.md" '`Contacted`/`Replied`/`Following Up` lead idle past cadence'
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
assert_contains "$K" 'A lead occupies exactly one of these thirteen stages'
assert_contains "$K" '| `Ready to Send` |'
assert_contains "$K" 'only the operator writes `Ready to Send`'
assert_contains "$K" 'the only statuses it may later write are `sent` and `voided`'
assert_not_contains "$K" '`approved`'
assert_not_contains "$SP/AGENT.md" 'twelve lead stages'
assert_contains "$SP/AGENT.md" 'thirteen lead stages'
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
assert_contains "$OC" 'sequence_bands'
assert_contains "$OC" 'allowed_countries: [US]'
assert_contains "$OC" 'eu_uk_legitimate_interest'
assert_contains "$OC" 'canada_consent_basis'
assert_contains "$OC" 'touch_spacing_days: 3'
assert_contains "$SP/subagents/approacher.md" 'one `name: value` line per name in `variables:`'
assert_contains "$SP/subagents/approacher.md" 'touch_spacing_days'
assert_contains "$SP/subagents/approacher.md" 'never an address with a `bounced` Activity'
assert_contains "$SP/subagents/approacher.md" 'one draft per enabled channel'
assert_contains "$SP/skills/write-cold-email/SKILL.md" '## With sequences'
assert_contains "$SP/templates/cold-email.md" 'icebreaker:'
finish
