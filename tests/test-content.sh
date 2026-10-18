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
assert_contains "$SP/context/operating-config.md" 'prospecting_sources: [apify_google_maps, apify_contact_info, web_search]'
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
C="$SP/capabilities/crm/contract.md"
assert_contains "$C" '`company, location, industry, size, source, source_url`, plus optional `domain, address, phone, email, fit_score, fit_breakdown, segment`'
assert_contains "$C" 'failing that, the same normalized `phone`'
assert_contains "$C" 'none of `domain`, `phone`, or `address`'
assert_contains "$C" '`lead_id, name, title, email, phone, linkedin_url, role, verified, notes`'
assert_contains "$C" 'listing, web_presence'
assert_contains "$SP/skills/research-company/SKILL.md" 'hire, listing, web_presence'
assert_contains "$SP/skills/find-decision-makers/SKILL.md" 'email, phone, linkedin_url'
assert_contains "$SP/subagents/preparer.md" 'email, phone, linkedin_url'
assert_contains "$SP/subagents/prospector.md" '`Address`, `Phone`, `Email`'
assert_contains "$SP/AGENT.md" 'hire, listing, web presence'

echo "-- evals"
E="$SP/evals/cases.md"
assert_contains "$E" '## Case 9: A lead with no sourced address never scores inside the service area'
assert_contains "$E" '## Case 10: A business with no website is deduped on phone, then name and address'
assert_contains "$E" '## Case 11: With no catalog signal, the pick is `weak`, never empty'
assert_contains "$E" '## Case 12: A source outside `prospecting_sources` is never used'
assert_contains "$E" 'These refusals are also'
assert_not_contains "$E" 'These twelve refusals'
assert_contains "$E" '## Case 13: A scheduled activity runs its `then` steps and nothing else'
assert_contains docs/superpowers/specs/2026-09-01-sales-partner-agent-design.md '2026-09-24-sales-partner-generalize-prospecting-design.md'

echo "-- phone normalization (I1)"
assert_contains "$C" 'normalized to E.164'
assert_contains "$C" 'never given a guessed country code'
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
assert_contains "$E" '`100×0.30=30`'
assert_contains "$E" 'same normalized company and address'
assert_contains "$E" 'segment fit alone (Home & Auto Services, industry Plumbing); no catalog signal found in research.'
assert_contains "$E" 'then_prospect: prepare'

echo "-- minors (M1-M11, D1-D2)"
assert_contains "$SP/skills/send-digest/SKILL.md" 'CRM **`get_lead`**'
assert_not_contains "$SP/context/icp.md" 'headcount/revenue falls'
assert_contains "$SP/context/icp.md" 'bands in `size_measure`'
assert_contains "$SP/context/icp.md" 'a sourced direct phone number'
assert_contains "$SP/skills/find-decision-makers/SKILL.md" 'public business registries'
assert_contains "$SP/skills/find-decision-makers/SKILL.md" 'an owner is written with `role: decision-maker`'
assert_contains "$SP/AGENT.md" 'a phone number, an address, a distance'
assert_contains "$SP/subagents/prospector.md" 'Existing leads, read via CRM'
assert_contains "$SP/subagents/prospector.md" 'Every source listed in `prospecting_sources` is exhausted'
assert_contains "$SP/subagents/preparer.md" '`apify_contact_info`'
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
assert_contains "$SP/skills/setup/SKILL.md" '`context/business-profile.md`, `context/offer-catalog.md`, `context/icp.md`, `context/operating-config.md`'
assert_contains "$SP/skills/interview-business/SKILL.md" 'into the instance'"'"'s `context/samples/`'
assert_not_contains "$SP/skills/interview-business/SKILL.md" 'artifacts supplied into `samples/`'
echo "-- capabilities"
assert_contains "$SP/capabilities/crm/contract.md" '## Invariants'
assert_contains "$SP/capabilities/crm/contract.md" '- `approval_only` —'
assert_contains "$SP/capabilities/crm/contract.md" '- `dnc_one_way` —'
assert_contains "$SP/capabilities/crm/contract.md" '- `no_delete` —'
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
for op in create_lead get_lead update_stage update_lead log_talking_points log_research upsert_contact query_by_stage query_by_score; do
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
for op in create_lead get_lead update_stage update_lead log_talking_points log_research upsert_contact query_by_stage query_by_score; do
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
m.PROPERTIES=m.build_properties(*m.read_catalog('$SP/tests/fixtures/offer-catalog.md'))
print(sorted(m.PROPERTIES)==['companies','contacts'] and ''.join(n+',' for n in sorted(p['name'] for o in m.PROPERTIES.values() for p in o)) or 'unexpected objects: '+','.join(m.PROPERTIES))")
[ -n "$u" ] && [ "$b" = "$u" ] && _report ok "Setup tables and bootstrap.py create the same properties, companies and contacts only" || _report no "Setup vs bootstrap.py: usage.md=$u bootstrap.py=$b"
assert_contains "$HT/usage.md" 'Notes need no custom fields.'
if grep -nE 'sp_(status|channel|direction|summary|outcome)' "$HT/usage.md" "$HT/bootstrap.py" "$HT/guard.yaml" | grep -q .; then
  _report no "the HubSpot tool still mentions a custom task field"; else _report ok "no custom task fields in the HubSpot tool"; fi

echo "-- tool guard policies"
assert_not_contains "$SP/AGENT.md" 'delivers it directly'
assert_contains "$SP/capabilities/crm/tools/attio/guard.yaml" 'covers: [approval_only, dnc_one_way, no_delete]'
for y in "$SP"/capabilities/*/tools/*/identity.yaml; do
  assert_pass bash -c "{ [ \"\$(grep -c . '$y')\" = 3 ] || { [ \"\$(grep -c . '$y')\" = 4 ] && grep -qx 'wrapper: n8n' '$y'; }; } && grep -q '^capability: ' '$y' && grep -q '^provider: ' '$y' && grep -q '^server_match: ' '$y'"
done
[ ! -e "$AT/guard.py" ] && _report ok "guard.py removed" || _report no "guard.py still present"
assert_contains "$SP/skills/setup/SKILL.md" '**Tools.**'
assert_contains "$SP/skills/setup/SKILL.md" 'whether the tool'"'"'s guard policy covers it'

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
for t in $(grep -oE 'hubspot:[a-z_]+' "$SP/capabilities/crm/tools/hubspot/usage.md" | sort -u | cut -d: -f2); do
  allowed_by "$SP/capabilities/crm/tools/hubspot/guard.yaml" mcp__hubspot__ "$t" && _report ok "HubSpot $t allowed" || _report no "HubSpot $t not in guard.yaml allow"
done

echo "-- scheduled runs"
assert_contains "$SP/agent.yaml" 'activity_digest: crm'
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
assert_contains "$SP/capabilities/crm/contract.md" 'matched the hero offer and written the talking points (`log_talking_points`)'
assert_contains "$SP/AGENT.md" '`capabilities/crm/contract.md` (Lead status, Lead status transitions)'
assert_contains "$SP/context/icp.md" '`capabilities/crm/contract.md` (Lead status transitions)'
assert_contains "$SP/capabilities/crm/contract.md" 'idle age = now − `Stage Changed At`'
D="$SP/skills/send-digest/SKILL.md"
assert_contains "$SP/capabilities/crm/tools/attio/usage.md" 'For `idle_days`: keep a lead when now minus'
echo "-- 5.0.0: void outcome Note, changed fields only"
HU="$SP/capabilities/crm/tools/hubspot/usage.md"
assert_not_contains "$HU" 'body with Outcome: line'
assert_not_contains "$HU" 'appends an `Outcome: <outcome>` line'
for f in "$SP"/capabilities/crm/tools/*/usage.md; do assert_contains "$f" 'Write only the fields that change'; done

echo "-- 8.0.0: Approved and the agent's last stage"
K="$SP/capabilities/crm/contract.md"
python3 -c "import sys; t=open('$K').read(); sys.exit(0 if 'Researched\nApproved\nContacted' in t else 1)" && _report ok "stage order has Approved" || _report no "stage order lacks Approved"
assert_contains "$K" '| `Approved` |'
assert_contains "$K" 'only the operator writes `Approved`'
assert_contains "$K" 'talking points are append-only (see Approval invariant)'
assert_not_contains "$K" '`approved`'
assert_not_contains "$SP/AGENT.md" 'twelve lead stages'
assert_contains "$SP/AGENT.md" 'The lead statuses and their transitions'
# The evals may name the stage `Approved`, but never say the agent approved a lead.
assert_not_contains "$SP/evals/cases.md" '`approved`'
if grep -qiE '(agent|preparer|prospector)( has| had| is| was)? approv(e|ed|es|ing)|approved by the (agent|preparer|prospector)|auto-?approv|(agent|preparer|prospector) (moves|moved|moving) (it|the lead|a lead|leads)( straight)? to `Approved`' "$SP/evals/cases.md"; then _report no "evals say the agent approved a lead"; else _report ok "evals never say the agent approved a lead"; fi

echo "-- 6.0.0: CRM tools"
assert_contains "$SP/capabilities/crm/tools/attio/usage.md" 'Approved'
assert_not_contains "$SP/capabilities/crm/tools/attio/usage.md" '`approved`'
assert_not_contains "$SP/capabilities/crm/tools/attio/usage.md" 'Awaiting Approval'
assert_not_contains "$SP/capabilities/crm/tools/attio/usage.md" 'twelve'
assert_contains "$SP/capabilities/crm/tools/hubspot/usage.md" 'Approved'
assert_not_contains "$SP/capabilities/crm/tools/hubspot/usage.md" '`approved`'
assert_not_contains "$SP/capabilities/crm/tools/hubspot/usage.md" 'Awaiting Approval'
assert_not_contains "$SP/capabilities/crm/tools/hubspot/usage.md" 'twelve'
for t in attio hubspot; do
  python3 -B -c "
import importlib.util, sys
s = importlib.util.spec_from_file_location('b', '$SP/capabilities/crm/tools/$t/bootstrap.py')
m = importlib.util.module_from_spec(s); s.loader.exec_module(m)
sys.exit(0 if m.STAGES == 'New, Scored, Researched, Approved, Contacted, Engaged, Open Deal, Nurture, Customer, Disqualified'.split(', ') else 1)" && _report ok "$t bootstrap STAGES: the ten stages in order" || _report no "$t bootstrap STAGES are not the ten stages in order"
  assert_not_contains "$SP"/capabilities/crm/tools/$t/bootstrap.py '"Ready to Send"'
  assert_not_contains "$SP"/capabilities/crm/tools/$t/bootstrap.py '"Approach Drafted"'
  assert_contains "$SP"/capabilities/crm/tools/$t/usage.md 'New, Scored, Researched, Approved, Contacted, Engaged, Open Deal, Nurture, Customer, Disqualified'
done
assert_not_contains "$SP/capabilities/crm/tools/attio/bootstrap.py" '"approved"'

echo "-- 6.0.0: personalization and config"
OC="$SP/context/operating-config.md"

echo "-- 6.0.0: lead status"
K="$SP/capabilities/crm/contract.md"
python3 -c "import sys; t=open('$K').read(); sys.exit(0 if 'Approved\nContacted\nEngaged\nOpen Deal\nNurture\nCustomer\nDisqualified' in t else 1)" && _report ok "status order" || _report no "status order"
assert_contains "$K" 'A lead holds exactly one of these ten statuses'
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
assert_contains "$SP/capabilities/crm/tools/hubspot/usage.md" 'Engaged'
assert_contains "$SP/capabilities/crm/tools/hubspot/usage.md" 'sp_revisit_on'
assert_not_contains "$SP/capabilities/crm/tools/hubspot/usage.md" 'Call Scheduled'
assert_not_contains "$SP/capabilities/crm/tools/hubspot/usage.md" 'thirteen'
grep -q '"Engaged"' "$SP/capabilities/crm/tools/attio/bootstrap.py" && grep -q 'revisit_on' "$SP/capabilities/crm/tools/attio/bootstrap.py" && ! grep -q '"Call Scheduled"' "$SP/capabilities/crm/tools/attio/bootstrap.py" && _report ok "attio bootstrap: ten statuses, revisit_on" || _report no "attio bootstrap statuses"
grep -q '"Engaged"' "$SP/capabilities/crm/tools/hubspot/bootstrap.py" && grep -q 'sp_revisit_on' "$SP/capabilities/crm/tools/hubspot/bootstrap.py" && ! grep -q '"Call Scheduled"' "$SP/capabilities/crm/tools/hubspot/bootstrap.py" && _report ok "hubspot bootstrap: ten statuses, sp_revisit_on" || _report no "hubspot bootstrap statuses"


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
assert_contains "$D" '**Section 2 — Approved, not yet contacted.**'
assert_not_contains "$D" 'Awaiting approval'
assert_not_contains "$D" 'Call Scheduled'
T="$SP/templates/digest.md"
assert_contains "$T" '## Review ([count])'
assert_contains "$T" '## Approved, not yet contacted ([count])'
assert_not_contains "$T" 'Won:'
K="$SP/capabilities/crm/contract.md"
assert_contains "$K" '| `log_research` | `lead_id, findings[]`'


echo "-- 6.0.0: AGENT.md and onboarding"
A="$SP/AGENT.md"
wc -c < "$A" | awk '{exit !($1 < 6000)}' && _report ok "AGENT.md under 6000 bytes" || _report no "AGENT.md 6000 bytes or more"
assert_contains "$A" 'Engaged'
assert_contains "$A" 'Open Deal'
assert_contains "$A" 'Approved'
assert_not_contains "$A" 'Sales call specialist'
assert_not_contains "$A" 'Follow-up'
assert_not_contains "$A" 'max_touches'
IV="$SP/skills/interview-business/SKILL.md"
assert_contains "$SP/README.md" 'lead generation and personalization'


echo "-- 6.0.0: final review fixes"
PR="$SP/subagents/prospector.md"
assert_contains "$PR" 'leave it untouched unless its status is `New`, or `Nurture` with a Revisit On date in the past'
assert_contains "$PR" '- CRM `get_lead`'
assert_contains "$SP/capabilities/crm/tools/attio/usage.md" 'move the lead to `Approved`: that approves it'
assert_contains "$SP/capabilities/crm/tools/hubspot/usage.md" 'then move the company to'
assert_not_contains "$SP/context/operating-config.md" '`approved`'
assert_contains "$SP/context/operating-config.md" 'only the operator approves a lead'
E="$SP/evals/cases.md"
assert_contains "$E" 'at `Contacted` and one at `Approved`'

echo "-- 6.0.0: lead generation and personalization (sending leaves)"
for f in capabilities/sequences skills/enroll skills/sync-replies; do
  [ ! -e "./$f" ] && _report ok "removed: $f" || _report no "still present: $f"  # ./ so the referenced-files check skips it
done
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

echo "-- 8.0.0: the agent stops at Researched"
K="$SP/capabilities/crm/contract.md"
assert_contains "$K" '**The agent'"'"'s job ends at `Researched`.**'
assert_contains "$K" '| `log_talking_points` | `lead_id, contact_id, body` |'
assert_contains "$K" '`query_by_stage` | `stage, limit, next_action_due_before, idle_days, research_anyway`'
assert_contains "$K" '`approval_only` — the agent never writes `Approved` or any later'
assert_contains "$K" '=== YYYY-MM-DD · talking points ==='
assert_contains "$K" 'Rejects any attempt to write `stage` through this operation'
assert_contains "$K" 'and any attempt to write `research_anyway`, which is the operator'"'"'s'
assert_contains "$K" 'Research Anyway (checkbox) | the operator only'
for f in "$K" "$SP/capabilities/crm/tools/attio/usage.md" "$SP/capabilities/crm/tools/hubspot/usage.md"; do
  assert_not_contains "$f" 'log_draft'
  assert_not_contains "$f" 'draft_only'
  assert_not_contains "$f" 'Approacher'
  assert_not_contains "$f" 'approach_threshold'
  assert_not_contains "$f" 'Channel:'
  assert_not_contains "$f" '`Ready to Send`'
done
for lbl in 'For:' 'Offer:' 'Opener:' 'Points:' 'Avoid:' 'Contact routes:'; do
  assert_contains "$K" "$lbl"
  assert_contains "$SP/capabilities/crm/tools/hubspot/usage.md" "\`${lbl}\`"
  assert_contains "$SP/capabilities/crm/tools/attio/usage.md" "\`${lbl}\`"
done
for c in attio hubspot; do
  assert_contains "./capabilities/crm/tools/$c/guard.yaml" 'covers: [approval_only, dnc_one_way, no_delete]'
done
assert_contains "./capabilities/crm/tools/attio/guard.yaml" 'field: research_anyway'
assert_contains "./capabilities/crm/tools/hubspot/guard.yaml" 'field: sp_research_anyway'
assert_contains "$K" 'the owner'"'"'s automation'
assert_contains "$K" '**Instruction, not a mechanism.** The operator records an opt-out'
assert_not_contains "$K" 'enroll'
assert_not_contains "$K" 'sync-replies'
assert_not_contains "$K" 'a bounced email returns it'
for c in attio hubspot; do
  G="./capabilities/crm/tools/$c/guard.yaml"
  grep -qF 'update: [Scored, Researched, Disqualified]' "$G" && _report ok "$c guard: agent statuses end at Researched" || _report no "$c guard stage update list"
  U="./capabilities/crm/tools/$c/usage.md"
  assert_not_contains "$U" 'enroll'
  assert_not_contains "$U" 'sync-replies'
  assert_not_contains "$U" 'sequences'
done
grep -qF 'update: [append]' "$SP/capabilities/crm/tools/attio/guard.yaml" && _report ok "attio guard: notes are append-only" || _report no "attio guard: note append rule"
assert_contains "$SP/context/operating-config.md" 'Talking points are append-only'
E="$SP/evals/cases.md"
assert_contains "$E" '## Case 5: An opted-out lead is disqualified and gets nothing new'
assert_not_contains "$E" 'enroll'
assert_not_contains "$E" 'sync-replies'
assert_not_contains "$E" 'suppress'

echo "-- 6.0.0: AGENT.md and manifests describe lead generation and personalization"
A="$SP/AGENT.md"
assert_contains "$A" 'lead generation and personalization'
assert_contains "$A" 'stops at'
assert_contains "$A" '`Researched`: once the operator moves a lead to `Approved`'
assert_contains "$A" 'talking points'
assert_contains "$A" '| Prepare | `Scored`, Fit ≥ `research_threshold` with a Segment, or Research Anyway |'
assert_contains "$A" 'never act on a lead at'
assert_not_contains "$A" 'enroll'
assert_not_contains "$A" 'sync-replies'
assert_not_contains "$A" 'sequence'
D=$(grep '^description: ' "$SP/agent.yaml" | sed 's/^description: //')
EXPECTED_DESC="Interviews a business, then finds, scores and researches fresh leads that fit its ideal customer and matches each one to the offer most likely to land, with sourced talking points the owner's own sequences can use"
[ "$D" = "$EXPECTED_DESC" ] && _report ok "agent.yaml description is the 8.0.0 string" || _report no "agent.yaml description: $D"
for m in .claude-plugin/plugin.json .codex-plugin/plugin.json gemini-extension.json .claude-plugin/marketplace.json; do
  grep -qF "$D" "./$m" && _report ok "$m description matches agent.yaml" || _report no "$m description differs from agent.yaml"
done
if grep -rlE "enroll|sync-replies|InvokeIQ|invokeiq|sequence_bands|bind_sequences|touch_spacing|enroll_ready_only" "$SP/AGENT.md" "$SP/README.md" "$SP/agent.yaml" "$SP/skills" "$SP/subagents" "$SP/capabilities" "$SP/context" "$SP/templates" "$SP/evals" "$SP/samples" | grep -q .; then _report no "references to sending pieces remain"; else _report ok "no references to sending pieces"; fi

echo "-- 6.0.0: final review of the scope cut"
K="$SP/capabilities/crm/contract.md"
assert_contains "$K" '`Disqualified` with reason `opt-out` and writes nothing else'
assert_contains "$K" 'When the Prospector (on a lead it re-finds)'
assert_not_contains "$K" '`sent` and `voided` by `update_activity`'
D="$SP/skills/send-digest/SKILL.md"
assert_contains "$D" '(now <status>)'
E="$SP/evals/cases.md"
assert_contains "$E" 'one `log_talking_points` call'
assert_not_contains "$E" 'two separate `log_activity` calls'
for c in attio hubspot; do
  assert_not_contains "./capabilities/crm/tools/$c/usage.md" 'wait for you on their dates'
done

echo "-- 6.0.0: LinkedIn needs a sourced profile (8.0.0: the LinkedIn draft case is retired)"
assert_not_contains "$SP/evals/cases.md" '## Case 15: No LinkedIn profile means no LinkedIn draft'

echo "-- 6.0.0: company profile fields"
K="$SP/capabilities/crm/contract.md"
assert_contains "$K" '### Company profile fields'
assert_contains "$K" '`description, company_linkedin_url, facebook_url, instagram_url`'
assert_contains "$K" 'only when the CRM'"'"'s own field is empty'
assert_contains "$K" 'A tool with no home for a profile field skips it'
AU="$SP/capabilities/crm/tools/attio/usage.md"
assert_contains "$AU" '`primary_location`'
assert_contains "$AU" '| `company_linkedin_url` | `linkedin` |'
assert_contains "$AU" 'never overwrite a value Attio'"'"'s enrichment or the operator already set'
assert_not_contains "$AU" 'The tool writes only `name` and `domains`.'
assert_contains "$SP/capabilities/crm/tools/hubspot/usage.md" 'skips the company profile fields'
assert_contains "$SP/subagents/preparer.md" 'the company profile fields it confirmed'
assert_contains "$SP/subagents/prospector.md" 'company profile fields the listing shows'

echo "-- 6.0.2: review minors"
for f in capabilities/crm/contract.md capabilities/crm/tools/attio/usage.md capabilities/crm/tools/hubspot/usage.md context/operating-config.md skills/send-digest/SKILL.md; do
  if grep -qiE "approves? a plan|approving a plan|approved the plan|whole plan|plans waiting|every plan waiting|Plans on DNC|The plan is approved|plan itself is approved|drafting the plan" "./$f"; then _report no "plan wording left in $f"; else _report ok "no plan wording in $f"; fi
done
D="$SP/skills/send-digest/SKILL.md"
assert_not_contains "$D" 'check the'
assert_not_contains "$SP/templates/digest.md" 'check the hand-off'
assert_contains "$D" 'researched N days ago'
assert_not_contains "$SP/capabilities/crm/contract.md" '`send-digest` needed to find'
assert_not_contains "$SP/capabilities/crm/tools/hubspot/usage.md" '|LINKED_IN_CONNECT|TODO>'
assert_not_contains "$SP/evals/cases.md" 'thirteen'
assert_contains "$SP/evals/cases.md" 'Cases 4, 11, 14 and 15 are positive checks'
A="$SP/AGENT.md"
assert_contains "$A" 'except a `Nurture` lead past its Revisit On date'
assert_contains "$SP/subagents/prospector.md" 'Never re-score or move any other lead'
assert_contains "$D" 'Report only: the digest writes nothing'

echo "-- 7.0: no Airtable CRM"
[ ! -e "./capabilities/crm/tools/airtable" ] && _report ok "airtable CRM tool removed" || _report no "airtable CRM tool still present"
# README.md and evals/cases.md name Airtable as the 7.1 ledger, not as a CRM.
for f in capabilities/crm/contract.md capabilities/crm/tools/attio/usage.md skills/send-digest/SKILL.md; do
  assert_not_contains "./$f" "Airtable"
done
assert_contains "$SP/agent.yaml" 'standard: "7.2"'
assert_contains "$SP/agent.yaml" 'capabilities: crm'

echo "-- 7.0: no email_drafts"
[ ! -e "./capabilities/email_drafts" ] && _report ok "email_drafts removed" || _report no "email_drafts still present"
for f in agent.yaml AGENT.md README.md context/operating-config.md skills/send-digest/SKILL.md skills/interview-business/SKILL.md skills/setup/SKILL.md; do
  assert_not_contains "./$f" "email_drafts"
  assert_not_contains "./$f" "digest_delivery"
  assert_not_contains "./$f" "digest_channel"
done

echo "-- 7.0: notify_owner callers"
assert_contains "$SP/skills/send-digest/SKILL.md" 'notify_owner(kind: digest)'
assert_not_contains "$SP/skills/send-digest/SKILL.md" 'Delivery is added with'
assert_not_contains "$SP/skills/send-digest/SKILL.md" 'nothing sends without operator approval'
assert_contains "$SP/AGENT.md" 'notify_owner(kind: alert)'
assert_contains "$SP/AGENT.md" 'notify_owner(kind: error)'
assert_contains "$SP/AGENT.md" 'Never send a message to anyone but the business owner'
assert_contains "$SP/AGENT.md" '`bind_owner_notify`'
assert_contains "$SP/subagents/prospector.md" 'notify_owner(kind: error)'
assert_contains "$SP/subagents/prospector.md" '- Owner notify `notify_owner`'
assert_contains "$SP/subagents/preparer.md" 'notify_owner(kind: error)'
assert_contains "$SP/subagents/preparer.md" '- Owner notify `notify_owner`'
assert_contains "$SP/skills/setup/SKILL.md" 'recipient_email'
assert_contains "$SP/skills/setup/SKILL.md" 'owner_only_send'
assert_contains "$SP/skills/interview-business/SKILL.md" 'recipient_email'
assert_contains "$SP/README.md" 'messages only you, through Resend'
assert_contains "$SP/evals/cases.md" 'A notification never reaches anyone but the owner'

echo "-- 7.0.0: release"
assert_contains "$SP/agent.yaml" 'version: 8.0.0'
for m in agent.yaml .claude-plugin/plugin.json .claude-plugin/marketplace.json .codex-plugin/plugin.json gemini-extension.json; do
  grep -qF "$EXPECTED_DESC" "./$m" && _report ok "$m: description is the 8.0.0 string" || _report no "$m: description is not the 8.0.0 string"
done

echo "-- 7.0.0: setup pushes before the test notification"
ST="$SP/skills/setup/SKILL.md"
tools_step=$(awk '/^9\. \*\*Tools\.\*\*/,/^10\. \*\*Version control/' "$ST")
after_tools=$(awk '/^10\. \*\*Version control/,0' "$ST")
printf '%s' "$tools_step" | grep -qF 'test notification.' && printf '%s' "$tools_step" | grep -qF 'step 11 offers the' \
  && _report ok "tools step defers the test notification to step 11" || _report no "tools step does not defer the test notification"
printf '%s' "$tools_step" | grep -qF 'offer one test notification' && _report no "tools step still offers the test notification" || _report ok "tools step sends no test notification"
printf '%s' "$after_tools" | grep -qF 'git push -u' && _report ok "version control pushes the instance" || _report no "version control does not push"
printf '%s' "$after_tools" | grep -qF 'offer one test notification' && _report ok "open step offers the test notification" || _report no "open step does not offer the test notification"

echo "-- 7.1: ledger"
assert_contains "$SP/agent.yaml" 'standard: "7.2"'
assert_contains "$SP/agent.yaml" 'capabilities: crm, owner_notify, ledger'
assert_contains "$SP/agent.yaml" 'activity_prospect: crm, owner_notify, ledger'
assert_contains "$SP/agent.yaml" 'activity_prepare: crm, owner_notify, ledger, scraping'
assert_contains "$SP/agent.yaml" 'activity_digest: crm, owner_notify, ledger'
assert_contains "$SP/capabilities/ledger/tables.md" 'ledger_schema: 1'
for f in contract.md tools/airtable/guard.yaml tools/airtable/usage.md tools/airtable/identity.yaml tools/airtable/bootstrap.py; do
  [ -f "./capabilities/ledger/$f" ] && _report ok "ledger $f present" || _report no "ledger $f missing"
done
[ -f ./skills/ledger-backfill/SKILL.md ] && _report ok "ledger-backfill skill present" || _report no "ledger-backfill skill missing"
# Byte-identity with the builder's _ledger/ is the validator's check (validate-agent.sh), which CI runs.

echo "-- 7.1: runs record themselves"
assert_contains "$SP/AGENT.md" '`bind_ledger`'
assert_contains "$SP/AGENT.md" 'Every run records itself in the ledger'
assert_contains "$SP/subagents/prospector.md" '## Ledger'
assert_contains "$SP/subagents/prospector.md" 'find_events(since: 30 days ago, activity: prospect, event: step)'
assert_contains "$SP/subagents/preparer.md" '## Ledger'
assert_contains "$SP/skills/send-digest/SKILL.md" '## Ledger'
assert_contains "$SP/README.md" 'You can see everything it did.'
assert_contains "$SP/README.md" 'Team plan'
assert_contains "$SP/evals/cases.md" 'A ledger outage never hides a run'
assert_not_contains "$SP/skills/send-digest/SKILL.md" "Delivery is the skill's only side effect."
assert_contains "$SP/skills/send-digest/SKILL.md" 'write `run_finished`, then stop'
assert_contains "$SP/subagents/prospector.md" '`outcome` `ok` and'
assert_contains "$SP/subagents/prospector.md" 'ledger_status'
assert_contains "$SP/subagents/prospector.md" '`run_started`'
assert_contains "$SP/subagents/prospector.md" 'Ledger `ledger_status`, `append_events`'
assert_contains "$SP/subagents/preparer.md" 'ledger_status'
assert_contains "$SP/subagents/preparer.md" '`run_started`'
assert_contains "$SP/subagents/preparer.md" 'Ledger `ledger_status`, `append_events`'
assert_not_contains "$SP/skills/send-digest/SKILL.md" 'This skill reads; it never writes'
assert_contains "$SP/README.md" 'Upgrading from 7.0'
wc -c < "$SP/AGENT.md" | awk '{exit !($1 < 6000)}' && _report ok "AGENT.md under 6000 bytes" || _report no "AGENT.md 6000 bytes or more"

echo "-- 7.2: scraping"
assert_contains "$SP/agent.yaml" 'standard: "7.2"'
assert_contains "$SP/agent.yaml" 'capabilities: crm, owner_notify, ledger, scraping'
assert_contains "$SP/capabilities/scraping/contract.md" '`pinned_inputs`'
assert_contains "$SP/capabilities/scraping/tools/apify/usage.md" 'mcp.apify.com?tools=compass/crawler-google-places,vdrmota/contact-info-scraper'
assert_contains "$SP/capabilities/scraping/tools/apify/usage.md" 'monthly usage limit'
assert_contains "$SP/capabilities/scraping/tools/apify/usage.md" 'Send only the arguments listed above, spelled exactly as listed'
assert_contains "$SP/capabilities/scraping/tools/apify/usage.md" '`estimated`'
assert_contains "$SP/capabilities/scraping/tools/apify/usage.md" '`get-dataset-items`'
assert_contains "$SP/capabilities/scraping/tools/apify/usage.md" '`countryCode`'
assert_contains "$SP/capabilities/scraping/tools/apify/usage.md" '`max_pages_per_call`'
assert_contains "$SP/capabilities/scraping/tools/apify/usage.md" 'Do not pass `proxyConfig`'
assert_contains "$SP/capabilities/scraping/tools/apify/usage.md" '`max_search_terms` — search terms per Maps call (default 1)'
assert_contains "$SP/capabilities/scraping/tools/apify/usage.md" '`max_sites_per_call`'
assert_contains "$SP/capabilities/scraping/tools/apify/usage.md" '`max_dataset_items`'
assert_not_contains "$SP/capabilities/scraping/tools/apify/usage.md" 'Arguments to omit'

echo "-- 7.2: Apify wiring"
assert_contains "$SP/context/operating-config.md" 'apify_contact_info'
assert_not_contains "$SP/context/operating-config.md" 'apify_site_scraper:'
assert_contains "$SP/context/operating-config.md" 'apify_site_scraper was renamed apify_contact_info'
assert_not_contains "$SP/subagents/prospector.md" 'Apify is never attached'
assert_not_contains "$SP/subagents/prospector.md" 'Apify connectors are not'
assert_not_contains "$SP/subagents/preparer.md" 'Apify is never attached'
assert_not_contains "$SP/subagents/preparer.md" 'Apify connectors are not'
assert_not_contains "$SP/README.md" 'Apify is never attached'
assert_not_contains "$SP/README.md" 'Apify connectors are not'
assert_contains "$SP/subagents/prospector.md" '`find_businesses`'
assert_contains "$SP/subagents/prospector.md" 'apify_spend_cap_usd_per_week'
assert_contains "$SP/subagents/prospector.md" 'Never retry a guard'
assert_contains "$SP/subagents/prospector.md" '`<query>|<city>, <state>`'
assert_not_contains "$SP/subagents/prospector.md" '`<city>|<industry>`'
assert_contains "$SP/subagents/prospector.md" 'sum `cost_usd` over those `step`'
assert_contains "$SP/subagents/prospector.md" 'city and state'
assert_contains "$SP/subagents/preparer.md" '`find_contacts`'
assert_contains "$SP/subagents/preparer.md" 'Never retry a guard'
assert_contains "$SP/subagents/preparer.md" 'sum `cost_usd` over those `step`'
assert_contains "$SP/subagents/preparer.md" 'apify_site_scraper was renamed apify_contact_info'
assert_contains "$SP/skills/send-digest/SKILL.md" 'Apify cost from the ledger'
assert_contains "$SP/README.md" 'monthly usage limit'
assert_contains "$SP/README.md" 'Upgrading from 7.1'
assert_contains "$SP/evals/cases.md" 'A scrape never exceeds its pinned limits'


echo "-- 7.3: two-gate scoring"
SL="$SP/skills/score-lead/SKILL.md"
assert_contains "$SL" '`rubric` — `fit` or `approach`'
assert_contains "$SL" 'never writes, overwrites or clears `Fit Score` or `Fit Breakdown`'
assert_contains "$SL" 'Total: 25+15+5+0+10+15+10+0=80'
assert_contains "$SL" 'Total: 25+15+20=60'
assert_contains "$SL" 'would be 25+30+20 = **75**'
assert_not_contains "$SL" 'five-row'
assert_not_contains "$SL" 'five weights'
assert_contains "$SP/context/icp.md" '### Fit score (research gate)'
assert_contains "$SP/context/icp.md" '### Approach score'
assert_contains "$SP/context/icp.md" "**each table's weights must always sum to"
assert_contains "$SP/context/icp.md" '**Temporarily closed**'
assert_not_contains "$SP/context/icp.md" 'five weights'
assert_contains "$SP/subagents/prospector.md" '`score-lead` (`rubric: fit`)'
assert_contains "$SP/subagents/prospector.md" 'Temporarily closed anti-signal'
assert_contains "$SP/subagents/prospector.md" '`fit_score` and `fit_breakdown`'
assert_contains "$SP/subagents/preparer.md" 'query_by_score(score = fit, min_score = research_threshold'
assert_contains "$SP/subagents/preparer.md" '(`rubric: approach`)'
assert_contains "$SP/subagents/preparer.md" 'most recent'
assert_contains "$SP/subagents/preparer.md" '`Fit Breakdown` are never written'
assert_contains "$SP/skills/send-digest/SKILL.md" '`score: fit`, `min_score: 0`'
assert_contains "$SP/skills/send-digest/SKILL.md" 'Approach <a> · Fit <f>'
assert_contains "$SP/skills/interview-business/SKILL.md" 'two draft rubrics, each with 0/50/100'
assert_contains "$SP/capabilities/crm/contract.md" '### Scores'
assert_contains "$SP/capabilities/crm/contract.md" '`score, min_score, stage, limit`'
for t in attio hubspot; do
  U="$SP"/capabilities/crm/tools/$t/usage.md
  assert_contains "$U" "Reject a \`score\` other than \`fit\` or"
done
for slug in fit_score fit_breakdown approach_score approach_breakdown segment hero_offer offer_reason offer_evidence research_anyway research_capped; do
  assert_contains "$SP/capabilities/crm/tools/attio/usage.md" "\`$slug\`"
  grep -qF "attr(\"$slug\"" ./capabilities/crm/tools/attio/bootstrap.py && _report ok "attio bootstrap creates $slug" || _report no "attio bootstrap misses $slug"
  assert_contains "$SP/capabilities/crm/tools/hubspot/usage.md" "\`sp_$slug\`"
  grep -qF "prop(\"sp_$slug\"" ./capabilities/crm/tools/hubspot/bootstrap.py && _report ok "hubspot bootstrap creates sp_$slug" || _report no "hubspot bootstrap misses sp_$slug"
done
for f in ./capabilities/crm/tools/attio/bootstrap.py ./capabilities/crm/tools/hubspot/bootstrap.py ./capabilities/crm/tools/attio/usage.md ./capabilities/crm/tools/hubspot/usage.md; do
  grep -qE '"(sp_)?score(_breakdown)?"|`(sp_)?score_breakdown`|`sp_score`|\| `score` \|' "$f" && _report no "$f still names the old score field" || _report ok "$f drops the old score field"
done
U="$SP/capabilities/scraping/tools/apify/usage.md"
assert_contains "$U" 'postalCode,location,phone,website,totalScore,reviewsCount,reviewsDistribution,openingHours,placeId'
assert_contains "$U" 'claimed = `not claimThisBusiness`'
assert_contains "$SP/capabilities/scraping/contract.md" 'per-star review counts (one to five stars), opening hours (per day), claimed (true or false), temporarily closed (true or false)'
assert_contains "$SP/evals/cases.md" '## Case 19: The research gate reads the Fit score, and research never rewrites it'
assert_contains "$SP/README.md" 'Upgrading from 7.2'


echo "-- 7.4: one Attio list"
assert_contains "$C" '| `log_talking_points` |'
assert_contains "$C" 'log_research(lead_id, findings[])'
assert_contains "$C" 'the nine operations'
assert_not_contains "$C" 'update_activity'
assert_not_contains "$C" 'query_activities'
assert_not_contains "$C" 'log_activity'
assert_not_contains "$C" 'recommended'
assert_contains "$C" 'talking points are append-only'
assert_contains "$C" 'a tool with no home for them skips them'

AU="$SP/capabilities/crm/tools/attio/usage.md"
AB=./capabilities/crm/tools/attio/bootstrap.py
assert_contains "$AU" '`Sales Partner · Research`'
assert_contains "$AU" '`Sales Partner · Talking Points`'
assert_contains "$AU" '=== YYYY-MM-DD · talking points ==='
assert_contains "$AU" '## Reading notes from an automation'
assert_contains "$AU" 'append to the oldest'
assert_contains "$AU" 'exact title'
assert_contains "$AU" 'company name + `primary_location`'
for gone in sales_partner_research sales_partner_outreach draft_body '`phone` | text' log_activity update_activity query_activities; do
  assert_not_contains "$AU" "$gone"
done
for gone in sales_partner_research sales_partner_outreach draft_body 'attr("phone"' 'attr("email"' 'attr("address"' 'attr("location"'; do
  grep -qF "$gone" "$AB" && _report no "attio bootstrap still has $gone" || _report ok "attio bootstrap drops $gone"
done

HU="$SP/capabilities/crm/tools/hubspot/usage.md"
assert_contains "$HU" 'hs_note_body'
assert_contains "$HU" '=== YYYY-MM-DD · talking points ==='
assert_contains "$HU" 'forbidden outright: the agent uses no Tasks'
assert_contains "$HU" 'by `hs_createdate` (stamped by HubSpot, never by the agent)'
for gone in update_activity query_activities log_activity 'Outcome for task' recommended; do
  assert_not_contains "$HU" "$gone"
done
grep -qF 'field: hs_note_body' ./capabilities/crm/tools/hubspot/guard.yaml && _report ok "hubspot guard: note body fixed after create" || _report no "hubspot guard: note body rule"

while IFS= read -r f; do
  for gone in log_activity update_activity query_activities 'recommended:' '`statements`' 'bounced Activity'; do
    assert_not_contains "$f" "$gone"
  done
done < <(find ./AGENT.md ./subagents ./skills ./templates ./context -name '*.md')
assert_contains "$SP/subagents/preparer.md" 'log_research(lead_id, findings[])'
assert_contains "$SP/subagents/preparer.md" 'main line and general inbox'

SD="$SP/skills/send-digest/SKILL.md"
assert_contains "$SD" 'Approved, not yet contacted'
assert_contains "$SD" 'researched N days ago'
assert_contains "$SD" 'no offer'
assert_contains "$SD" 'nine operations'
assert_not_contains "$SD" 'drafted:'
assert_not_contains "$SD" 'drafted N days ago'
assert_not_contains "$SD" 'the Call note'
assert_not_contains "$SD" 'recommended'
assert_not_contains "$SD" 'opt-out logged — Do Not Contact not set'
assert_not_contains "$SD" 'eleven operations'
assert_contains "$SP/templates/digest.md" 'Approved, not yet contacted'
assert_contains "$SP/templates/digest.md" 'researched N days ago'
assert_contains "$SP/templates/digest.md" 'no offer'
assert_not_contains "$SP/templates/digest.md" 'drafted: <channels>'
assert_not_contains "$SP/templates/digest.md" 'the Call note'
assert_not_contains "$SP/templates/digest.md" 'recommended'

EV="$SP/evals/cases.md"
assert_not_contains "$EV" '## Case 14: Every reachable channel gets a full draft'
assert_not_contains "$EV" '## Case 20: A redraft appends and never rewrites'
for gone in update_activity query_activities log_activity 'recommended:'; do
  assert_not_contains "$EV" "$gone"
done

for m in agent.yaml .claude-plugin/plugin.json .claude-plugin/marketplace.json .codex-plugin/plugin.json gemini-extension.json; do
  grep -qF 'matches each one to the offer most likely to land' "./$m" && _report ok "$m: description names offer matching" || _report no "$m: description does not name offer matching"
  grep -qF 'personalized statements' "./$m" && _report no "$m: description still names personalized statements" || _report ok "$m: no personalized statements"
  grep -qF 'recommended channel' "./$m" && _report no "$m still says recommended channel" || _report ok "$m: no recommended channel"
done
assert_contains "$SP/README.md" 'Upgrading from 7.3'
assert_not_contains "$SP/README.md" 'recommends the best'

echo "-- 7.4: final review fixes"
RC="$SP/skills/research-company/SKILL.md"
assert_contains "$RC" 'Hook: contact route'
assert_contains "$SP/capabilities/crm/contract.md" 'contact route'
assert_contains "$SP/subagents/preparer.md" 'Hook: contact route'
AU2="$SP/capabilities/crm/tools/attio/usage.md"
assert_contains "$AU2" 'paging with `limit: 100` and `offset`'
assert_contains "$AU2" 'use the oldest (earliest `created_at`)'
assert_contains "$AU2" 'create the note with the header line alone, then append'
assert_contains "$AU2" '`do_not_contact` is not true'
assert_contains "$SP/skills/send-digest/SKILL.md" 'In Section 2 too, mark every lead whose `Do Not Contact` is true'
assert_contains "$SP/README.md" 'otherwise it is recorded as a `listing` finding in the research note'
assert_contains "$SP/evals/cases.md" 'the general inbox recorded in its research'

echo "-- 8.0.0: the Approacher path is retired"
for f in subagents/approacher.md skills/write-cold-email skills/write-linkedin-touch skills/write-call-opener templates/cold-email.md templates/cold-call-opener.md templates/linkedin-dm.md templates/linkedin-connection-note.md templates/personalized-statements.md; do
  [ ! -e "./$f" ] && _report ok "removed: $f" || _report no "still present: $f"  # ./ so the referenced-files check skips it
done
! grep -q '^activity_approach' "$SP/agent.yaml" && _report ok "no approach activity" || _report no "activity_approach still declared"
! grep -q 'approacher' ./.claude-plugin/plugin.json && _report ok "plugin.json lists no Approacher" || _report no "plugin.json still lists the Approacher"
for k in approach_threshold enabled_channels sending_identity callback_phone; do
  assert_not_contains "$SP/context/operating-config.md" "$k"
done
assert_contains "$SP/context/operating-config.md" 'write-talking-points'
for k in research_threshold research_quota_per_week research_budget_per_lead_minutes leads_per_week prospecting_sources apify_spend_cap_usd_per_week tone; do
  assert_contains "$SP/context/operating-config.md" "$k:"
done
# The retired terms appear nowhere in the package, except in the README's "Upgrading from
# 7.4" note, which has to name the retired stages and schedule key so operators can migrate.
# That note is stripped (from its heading to the next "## " heading) before the README is checked.
README_NO_UPGRADE=$(mktemp)
awk '/^Upgrading from 7\.4/ { skip=1; next } skip && /^## / { skip=0 } !skip' "$SP/README.md" > "$README_NO_UPGRADE"
while IFS= read -r f; do
  src="$f"; [ "$f" = README.md ] && src="$README_NO_UPGRADE"
  for t in approacher approach_threshold enabled_channels callback_phone sending_identity write-cold-email write-linkedin-touch write-call-opener 'Approach Drafted' 'Ready to Send'; do
    # The CRM usage.md files name the two old stages once, in the note about the stages the bootstrap leaves in place.
    case "$f:$t" in capabilities/crm/tools/*/usage.md:'Approach Drafted'|capabilities/crm/tools/*/usage.md:'Ready to Send') continue ;; esac
    if grep -qiF -- "$t" "$src"; then _report no "$f still contains '$t'"; else _report ok "$f free of '$t'"; fi
  done
done < <(find AGENT.md README.md subagents skills templates context capabilities evals -type f \
  -not -name '*.pyc')
rm -f "$README_NO_UPGRADE"

echo "-- 8.0.0: release: version, README flow and the upgrade note"
assert_contains "$SP/agent.yaml" 'version: 8.0.0'
assert_contains "$SP/README.md" 'Version 8.0.0.'
for m in .claude-plugin/plugin.json .codex-plugin/plugin.json gemini-extension.json; do
  assert_contains "./$m" '"version": "8.0.0"'
done
assert_contains "$SP/README.md" 'Upgrading from 7.4'
for t in 'Approved' 'Research Anyway' 'Talking Points' 'offer catalog' 'Hero Offer' 'schedule_approach'; do
  assert_contains "$SP/README.md" "$t"
done
# The README's retired stage names sit only inside the upgrade note (the strip above leaves none).
UP=$(awk '/^Upgrading from 7\.4/ { f=1; next } f && /^## / { f=0 } f' "$SP/README.md")
for t in 'Ready to Send' 'Approach Drafted' 'schedule_approach'; do
  printf '%s' "$UP" | grep -qF -- "$t" && _report ok "upgrade note names '$t'" || _report no "upgrade note does not name '$t'"
done

echo "-- 8.0.0: match-offer, write-talking-points and catalog-aware research"
MO="$SP/skills/match-offer/SKILL.md"
WT="$SP/skills/write-talking-points/SKILL.md"
TP_HEADER='=== YYYY-MM-DD · talking points ==='
# The first fenced block holding the format header, indentation stripped.
tp_block() {
  awk -v h="$TP_HEADER" '
    /^[[:space:]]*```/ { if (inb) { if (has) { printf "%s", buf; exit } inb=0; buf=""; has=0; next } inb=1; next }
    inb { l=$0; sub(/^[[:space:]]+/, "", l); buf = buf l "\n"; if (l == h) has=1 }
  ' "$1"
}
WT_BLOCK=$(tp_block "$WT")
K_BLOCK=$(tp_block "$SP/capabilities/crm/contract.md")
[ -n "$WT_BLOCK" ] && [ "$WT_BLOCK" = "$K_BLOCK" ] && _report ok "write-talking-points format block is identical to the contract's" || _report no "write-talking-points format block differs from the contract's"
labels=$(printf '%s\n' "$K_BLOCK" | grep -oE '^(===|For:|Offer:|Opener:|Points:|Avoid:|Contact routes:)' | tr '\n' '|')
[ "$labels" = '===|For:|Offer:|Opener:|Points:|Avoid:|Contact routes:|' ] && _report ok "contract format block: header then the six labels, in order" || _report no "contract format block label order: $labels"
for f in "$WT" "$SP/capabilities/crm/contract.md" "$SP/capabilities/crm/tools/attio/usage.md" "$SP/capabilities/crm/tools/hubspot/usage.md"; do
  assert_contains "$f" "$TP_HEADER"
  for lbl in 'For:' 'Offer:' 'Opener:' 'Points:' 'Avoid:' 'Contact routes:'; do
    assert_contains "$f" "$lbl"
  done
done
assert_contains "$WT" 'Offer: none matched'
assert_contains "$WT" 'log_talking_points(lead_id, contact_id, body)'
assert_contains "$WT" '`tone`'
assert_contains "$WT" 'offer-catalog.md'
for w in '`strong`' '`moderate`' '`weak`' 'ruled out'; do
  assert_contains "$MO" "$w"
done
assert_contains "$MO" 'offer-catalog.md'
assert_contains "$MO" 'hero_offer'
assert_contains "$MO" 'offer_evidence'
assert_contains "$MO" 'offer_reason'
A="$SP/AGENT.md"
assert_contains "$A" '`business-profile.md` or `offer-catalog.md`'
assert_contains "$A" '`context/offer-catalog.md`'
assert_contains "$A" '`match-offer`'
assert_contains "$A" '`write-talking-points`'
RC="$SP/skills/research-company/SKILL.md"
assert_contains "$RC" 'offer-catalog.md'
assert_contains "$RC" 'rule_out'
assert_contains "$SP/context/icp.md" 'offer-catalog.md'
assert_contains "$SP/context/business-profile.md" 'offer-catalog.md'
wc -c < "$A" | awk '{exit !($1 < 6000)}' && _report ok "AGENT.md under 6000 bytes" || _report no "AGENT.md 6000 bytes or more"

echo "-- 8.0.0: the Preparer matches the hero offer; the Prospector sets the segment"
PP="$SP/subagents/preparer.md"
for w in 'research_anyway=true' '`match-offer`' '`write-talking-points`' 'log_talking_points' 'researched by operator request; Fit <n> below research_threshold <t>' 'context/offer-catalog.md'; do
  assert_contains "$PP" "$w"
done
# Review Focus 4: an empty Segment is filled from Industry, or the lead is skipped.
assert_contains "$PP" 'an empty Segment is first filled from Industry, using the catalog'"'"'s `industries` lists; if that fails, the lead is skipped'
assert_contains "$PP" 'never writes `hero_offer`, `offer_evidence` or `offer_reason` itself'
assert_contains "$PP" 'Segment chosen by the Preparer'
assert_contains "$PP" 'run its search (step 3) for that segment'"'"'s signals and rule-outs'
assert_contains "$PP" '`segment`, `industry`, `hero_offer`, `offer_reason`, `offer_evidence`'
assert_contains "$PP" 'Re-match a lead at `Researched`'
assert_contains "$PP" 'never acts on a lead at `Approved` or later'
assert_contains "$PP" 'hero_offer=<id or none>; offer_evidence=<grade or none>'
for w in 'the Prospector'"'"'s rule' 'a clear synonym of' 'matches two segments'"'"' `industries` is no unambiguous match' 'after the `get_lead`, status and opt-out' 'researched by operator request; no Fit score' 'but Industry "<Industry>" matches no single segment' '`disqualified; <reason>`' 'counts against the lead'"'"'s `research_budget_per_lead_minutes`' 'A lead not at `Researched` is not re-matched'; do
  assert_contains "$PP" "$w"
done
assert_not_contains "$PP" 'catalog search (step 2)'
for gone in approach_threshold log_draft 'the drafts'; do
  assert_not_contains "$PP" "$gone"
done
PR="$SP/subagents/prospector.md"
assert_contains "$PR" '`Segment`'
assert_contains "$PR" 'context/offer-catalog.md'
assert_contains "$PR" 'in the catalog'"'"'s wording where one fits'
assert_contains "$PR" 'the catalog segment whose `industries` include it'
for t in attio hubspot; do
  assert_contains "$SP"/capabilities/crm/tools/$t/usage.md 'To clear a select or text field'
done
assert_contains "$SP/capabilities/crm/tools/attio/usage.md" 'write it as `[]`'
assert_contains "$SP/capabilities/crm/tools/hubspot/usage.md" 'write it as `""`'

echo "-- 8.0.0: the interview builds the catalog and setup copies it"
IV="$SP/skills/interview-business/SKILL.md"
assert_contains "$IV" 'context/offer-catalog.md'
assert_contains "$IV" 'only writer of `context/business-profile.md`,'
assert_contains "$IV" '`signals`'
assert_contains "$IV" '`rule_out`'
assert_contains "$IV" '**Round 1b — the offer catalog.**'
assert_contains "$IV" 'whose info string is `yaml`'
assert_contains "$IV" 'unique across the whole'
assert_contains "$IV" 'named after the'
assert_contains "$IV" 'come from the segments'"'"' `industries` in the offer catalog'
assert_contains "$IV" 'explicit confirmation or correction'
assert_contains "$IV" 're-run setup'"'"'s tools step'
assert_not_contains "$IV" 'approach_threshold'
assert_contains "$SP/skills/setup/SKILL.md" '`context/offer-catalog.md`, `context/icp.md`'
assert_contains "$SP/skills/setup/SKILL.md" 'bootstrap reads the instance'"'"'s `context/offer-catalog.md`'
assert_contains "$SP/skills/setup/SKILL.md" 'Re-run this step after the catalog'

echo "-- 8.0.0: the digest shows offers and the approved queue"
SD="$SP/skills/send-digest/SKILL.md"
DT="$SP/templates/digest.md"
assert_contains "$SD" '`query_by_stage("Researched")`'
assert_contains "$SD" '`query_by_stage("Approved")`'
assert_contains "$SD" '<company> — <segment> · <hero offer or'
assert_contains "$SD" 'Order the list by `Approach'
assert_contains "$SD" '(weak: segment fit only)'
assert_contains "$SD" 'New, Scored, Researched, Approved,'
assert_contains "$SD" 'not time since approval'
assert_contains "$SD" '`<Company>: → Researched (now <status>)`'
assert_contains "$DT" '## Review ([count])'
assert_contains "$DT" 'ordered by Approach score'
assert_not_contains "$SD" 'log_draft'
assert_not_contains "$SD" 'Drafts on DNC'

echo "-- 8.0.0: evals for offer matching, talking points and Research Anyway"
EV="$SP/evals/cases.md"
for h in \
  '## Case 4: A strong match rests on two sourced signals' \
  '## Case 11: With no catalog signal, the pick is `weak`, never empty' \
  '## Case 14: A sourced rule-out takes an offer out, whatever its signals' \
  '## Case 15: Every offer ruled out leaves Hero Offer empty, and the lead still reaches `Researched`' \
  '## Case 20: A Research Anyway lead below the threshold is researched first' \
  '## Case 21: An industry that fits no segment is never guessed into one' \
  '## Case 22: A lead scored before 8.0 gets its Segment from its Industry, or is skipped' \
  '## Case 23: Talking points stay sourced and claim only what the business files hold' \
  '## Case 7: A claim absent from `business-profile.md` and `offer-catalog.md` is omitted, not inferred' \
  '## Case 5: An opted-out lead is disqualified and gets nothing new' \
  '## Case 13: A scheduled activity runs its `then` steps and nothing else'; do
  assert_contains "$EV" "$h"
done
for gone in '## Case 4: LinkedIn output is copy-paste text' '## Case 11: A lead with no sourced phone' log_draft draft_only 'Personalized statements' 'Draft Body' '`channel' 'first touch'; do
  assert_not_contains "$EV" "$gone"
done
for w in '`strong`' '`moderate`' '`weak`' '`Offer: none matched`' '`- none`' 'Segment chosen by the Preparer:' 'Every offer ruled out:' 'Ruled out: Inbound Lead Qualification & Appointment Setting' \
  'researched by operator request; Fit 45 below research_threshold 60' 'researched by operator request; no Fit score' 'matches no single segment' \
  '`hero_offer=none; offer_evidence=none`' 'hero_offer=ha-inbound-lead-qualification; offer_evidence=strong' 'counts as neither' 'a clear synonym' 'matches two segments' \
  '=== <today> · talking points ===' 'For:`, `Offer:`, `Opener:`, `Points:`, `Avoid:`, `Contact routes:' 'Opener: unverified — no recent hook found' \
  'traces to `business-profile.md` or `offer-catalog.md`' 'Run **Case 1** (Prospector), **Case 4** (Preparer, a strong match)'; do
  assert_contains "$EV" "$w"
done
# The instructions the evals rely on.
assert_contains "$SP/subagents/preparer.md" 'A re-query leaves out every'
assert_contains "$SP/subagents/preparer.md" 'gets one skipped `step` per run'
assert_contains "$SP/context/icp.md" 'a ticked lead is researched'

echo "-- 8.0.0: final-review fixes"
# I1: a re-match fills an empty Segment before match-offer runs.
for w in 'When the lead'"'"'s Segment is empty (a lead researched before' 'first apply Segment fill (Trigger)' 'Only then call `match-offer`' 'run no new search'; do
  assert_contains "$PP" "$w"
done
assert_contains "$EV" 'Asked to match offers for (f) and (g)'
assert_contains "$EV" 'never `No segment:`'
# I2: the 7.4 upgrade brings icp.md and operating-config.md in line with the catalog.
UP=$(awk '/^Upgrading from 7\.4/ { f=1; next } f && /^## / { f=0 } f' "$SP/README.md")
for t in 'Round 2 (the customer and both rubrics)' 'the catalog round alone leaves `icp.md` as it was' 'keeps no industry list' 'Delete `approach_threshold`,' '`enabled_channels`, `sending_identity` and `callback_phone` from the' 'first fills each lead'"'"'s empty Segment'; do
  printf '%s' "$UP" | grep -qF -- "$t" && _report ok "upgrade note: '$t'" || _report no "upgrade note missing '$t'"
done
n=$(printf '%s\n' "$UP" | grep -cE '^[1-9]\. ')
[ "$n" -eq 5 ] && _report ok "upgrade note keeps the spec's five steps" || _report no "upgrade note has $n steps, not 5"
assert_contains "$IV" 'On a re-run over an `icp.md` written before the'
assert_contains "$IV" 'and keep only `research_threshold` in Thresholds.'
# Minors.
assert_contains "$IV" 'If an industry appears in two segments'"'"''
assert_contains "$SP/context/icp.md" 'in exactly one segment'"'"'s `industries`, and that segment is the lead'"'"'s'
assert_not_contains "$SP/context/icp.md" 'aimed at at'
assert_contains "$RC" 'alongside any step-5 findings'
assert_not_contains "$RC" 'write a single finding'
assert_contains "$SP/templates/research-summary.md" 'research-company step 7'
for f in "$SP/capabilities/crm/contract.md" "$SP/capabilities/crm/tools/attio/usage.md" "$SP/capabilities/crm/tools/hubspot/usage.md" "$WT"; do
  assert_contains "$f" 'Opener: unverified — no recent hook found'
done
assert_contains "$SP/capabilities/crm/tools/hubspot/usage.md" '`NOT_HAS_PROPERTY`, so a checkbox never set counts as unticked.'
assert_not_contains "$SP/capabilities/crm/tools/hubspot/usage.md" '(or `"false"`)'
assert_contains "$SP/capabilities/crm/tools/hubspot/usage.md" '`Hero offer` (`sp_hero_offer`), `Offer evidence` (`sp_offer_evidence`)'
assert_contains "$SP/capabilities/crm/tools/attio/usage.md" '`segment`, `hero_offer`, `offer_reason` and'
assert_not_contains "$SP/guard.yaml" 'drafts go to the CRM'
assert_not_contains "$SD" 'My touches'
assert_not_contains "$SD" 'Await reply to approach'
assert_contains "$A" 'Per lead, its Industry and Segment, and its Hero Offer, Offer'

echo "-- 8.1: evidence scrapers (contract, Apify usage)"
SC="$SP/capabilities/scraping/contract.md"; SU="$SP/capabilities/scraping/tools/apify/usage.md"
for op in find_reviews find_ads find_jobs read_site; do
  grep -qE "^\| \`$op\` \|" "$SC" && _report ok "contract.md has operation $op" || _report no "contract.md missing operation $op"
  assert_contains "$SU" "\`$op\`"
done
SETUP=$(awk '/^## Setup/ { f=1; next } f && /^## / { f=0 } f' "$SU")
for key in max_reviews max_ads max_jobs max_site_pages max_site_depth max_review_places max_ad_queries max_ad_advertisers \
           ads_result_type site_crawler_type site_html_transformer max_site_urls; do
  printf '%s' "$SETUP" | grep -qF -- "- \`$key\` — " && _report ok "usage.md Setup lists $key" || _report no "usage.md Setup missing $key"
done
for d in '`max_reviews` — reviews per reviews call (default 50)' '`max_ads` — ads per Google query, and the Facebook results limit (default 5)' \
         '`max_jobs` — job listings per jobs call (default 20)' '`max_site_pages` — pages the site reader reads per call (default 5)' \
         '`max_site_depth` — link depth for the site reader (default 1)'; do
  printf '%s' "$SETUP" | grep -qF -- "$d" && _report ok "usage.md Setup: $d" || _report no "usage.md Setup missing: $d"
done
printf '%s' "$SETUP" | grep -qF 'mcp.apify.com?tools=compass/crawler-google-places,vdrmota/contact-info-scraper,compass/Google-Maps-Reviews-Scraper,scrapesage/google-ads-transparency-scraper,apify/facebook-ads-scraper,valig/indeed-jobs-scraper,apify/website-content-crawler`' \
  && _report ok "usage.md Setup gives the seven-actor connector URL" || _report no "usage.md Setup lacks the seven-actor connector URL"
assert_contains "$SU" 'always pass `personalData: false`'
assert_contains "$SU" 'never record reviewer names'
assert_contains "$SU" 'always pass `onlyTotal: true`'
assert_contains "$SU" 'With no page URL, skip this call and record no Facebook finding'
assert_contains "$SU" 'Zero items is a valid result: no open listings'
assert_contains "$SU" 'the `website` the Maps listing gives'
assert_contains "$SU" '`"script, style, noscript, svg"`'
assert_contains "$SU" 'never claim a site lacks chat'
assert_contains "$SU" 'Do not pass `proxyConfiguration`'
for t in compass--Google-Maps-Reviews-Scraper scrapesage--google-ads-transparency-scraper apify--facebook-ads-scraper \
         valig--indeed-jobs-scraper apify--website-content-crawler; do
  assert_contains "$SU" "\`apify:$t\`"
  grep -qF "$t" "$SP/capabilities/scraping/tools/apify/guard.yaml" && _report ok "guard.yaml allows $t" || _report no "guard.yaml missing $t"
done
for c in '`find_reviews` | $0.05' '`find_ads`, Google | $0.01' '`find_ads`, Facebook | $0.03' '`find_jobs` | $0.005' '`read_site` | $0.03'; do
  assert_contains "$SU" "$c"
done
assert_not_contains "$SU" 'reviewerId,'

# Research Capped: an agent-written checkbox in both CRMs, unlike research_anyway
CT="$SP/capabilities/crm/contract.md"
assert_contains "$CT" 'Research Capped (checkbox)'
assert_contains "$CT" '`offer_evidence` and `research_capped` among its fields'
assert_contains "$CT" 'no guard policy forbids it'
assert_not_contains "$SP/capabilities/crm/tools/attio/guard.yaml" 'research_capped'
assert_not_contains "$SP/capabilities/crm/tools/hubspot/guard.yaml" 'research_capped'
assert_contains "$SP/capabilities/crm/tools/attio/usage.md" '`offer_evidence` and `research_capped`'
assert_contains "$SP/capabilities/crm/tools/attio/usage.md" '| Research Capped | `research_capped` | Checkbox | |'
assert_contains "$SP/capabilities/crm/tools/hubspot/usage.md" '`research_capped` maps to'
assert_contains "$SP/capabilities/crm/tools/hubspot/usage.md" '(`sp_research_capped`) as columns'
assert_contains "$SP/capabilities/crm/tools/hubspot/usage.md" '"sp_research_anyway", "sp_research_capped"]'
assert_contains "$SP/capabilities/crm/tools/hubspot/usage.md" '| `sp_research_capped` | Research capped | Single checkbox |'
grep -qF 'attr("research_capped", "Research Capped", "checkbox"' ./capabilities/crm/tools/attio/bootstrap.py && _report ok "attio research_capped is a checkbox" || _report no "attio research_capped is not a checkbox"
grep -qF 'prop("sp_research_capped", "Research capped", "bool", "booleancheckbox"' ./capabilities/crm/tools/hubspot/bootstrap.py && _report ok "hubspot sp_research_capped is a checkbox" || _report no "hubspot sp_research_capped is not a checkbox"

finish
