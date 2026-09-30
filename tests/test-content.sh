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
C="$SP/capabilities/crm/contract.md"; A="$SP/capabilities/crm/adapters/airtable/adapter.md"
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
assert_contains "$SP/README.md" 'Version 2.1.0.'
assert_not_contains "$SP/skills/setup/SKILL.md" '<interview-skill>'
assert_not_contains "$SP/skills/setup/SKILL.md" '<context-files>'
assert_contains "$SP/skills/setup/SKILL.md" '`context/business-profile.md`, `context/icp.md`, `context/operating-config.md`'
assert_contains "$SP/skills/interview-business/SKILL.md" 'into the instance'"'"'s `context/samples/`'
assert_not_contains "$SP/skills/interview-business/SKILL.md" 'artifacts supplied into `samples/`'
assert_contains "$SP/subagents/approacher.md" 'the instance'"'"'s `context/samples/` first, then the package'"'"'s `samples/`'
echo "-- capabilities (Agent Standard 2.0)"
assert_contains "$SP/capabilities/crm/contract.md" '## Invariants'
assert_contains "$SP/capabilities/crm/contract.md" '- `draft_only` —'
assert_contains "$SP/capabilities/crm/contract.md" '- `dnc_one_way` —'
assert_contains "$SP/capabilities/crm/contract.md" '- `no_delete` —'
assert_contains "$SP/capabilities/crm/adapters/airtable/adapter.md" '## Probe'
assert_pass bash -c "[ \"\$(wc -l < '$SP/capabilities/crm/adapters/airtable/adapter.yaml' | tr -d ' ')\" = 3 ] && grep -qx 'capability: crm' '$SP/capabilities/crm/adapters/airtable/adapter.yaml' && grep -qx 'provider: airtable' '$SP/capabilities/crm/adapters/airtable/adapter.yaml' && grep -qx 'server_match: airtable' '$SP/capabilities/crm/adapters/airtable/adapter.yaml'"
assert_contains "$SP/AGENT.md" 'bound in `instance.yaml` (`bind_crm`)'
[ ! -e "$SP"/context/crm-contract.md ] && [ ! -e "$SP"/context/crm-airtable-adapter.md ] \
  && _report ok "CRM files left context/" || _report no "CRM files still in context/"
while IFS= read -r f; do
  assert_not_contains "$f" 'context/crm-'
done < <(find "$SP" -name '*.md' -not -path './docs/*' -not -path './tests/*' -not -path './.git/*' -not -path './migrations/*')

echo "-- Attio adapter"
AT="$SP/capabilities/crm/adapters/attio"
assert_contains "$AT/adapter.md" '## Probe'
assert_contains "$AT/adapter.md" 'lead_source_outbound: yes'
assert_not_contains "$AT/adapter.md" 'Webspenser'
[ -x "$AT/bootstrap.py" ] && _report ok "bootstrap.py present and executable" || _report no "bootstrap.py missing or not executable"
assert_not_contains "$AT/bootstrap.py" '.env'
for op in create_lead get_lead update_stage update_lead log_activity update_activity log_research upsert_contact query_by_stage query_by_score query_activities; do
  assert_contains "$AT/adapter.md" "\`$op\`"
done

echo "-- email drafts"
assert_contains "$SP/agent.yaml" 'capabilities: crm, email_drafts'
assert_not_contains "$SP/AGENT.md" 'delivers it directly'
assert_contains "$SP/capabilities/email_drafts/contract.md" '- `no_send` —'
assert_contains "$SP/capabilities/email_drafts/adapters/gmail/guard.yaml" 'covers: [no_send]'
assert_contains "$SP/capabilities/crm/adapters/attio/guard.yaml" 'covers: [draft_only, dnc_one_way, no_delete]'
for y in "$SP"/capabilities/*/adapters/*/adapter.yaml; do
  assert_pass bash -c "[ \"\$(grep -c . '$y')\" = 3 ] && grep -q '^capability: ' '$y' && grep -q '^provider: ' '$y' && grep -q '^server_match: ' '$y'"
done
[ ! -e "$AT/guard.py" ] && _report ok "guard.py removed" || _report no "guard.py still present"
assert_contains "$SP/skills/setup/SKILL.md" '**Tools.**'
assert_contains "$SP/skills/setup/SKILL.md" 'whether the adapter'"'"'s guard policy covers it'
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
for t in $(grep -oE 'attio:[a-z-]+' "$SP/capabilities/crm/adapters/attio/adapter.md" | sort -u | cut -d: -f2); do
  allowed_by "$SP/capabilities/crm/adapters/attio/guard.yaml" mcp__attio__ "$t" && _report ok "Attio $t allowed" || _report no "Attio $t not in guard.yaml allow"
done
for t in $(grep -oE 'gmail:[a-z_]+' "$SP/capabilities/email_drafts/adapters/gmail/adapter.md" | sort -u | cut -d: -f2); do
  allowed_by "$SP/capabilities/email_drafts/adapters/gmail/guard.yaml" mcp__gmail__ "$t" && _report ok "Gmail $t allowed" || _report no "Gmail $t not in guard.yaml allow"
done
for t in $(grep -oE 'airtable:[a-z_]+' "$SP/capabilities/crm/adapters/airtable/adapter.md" | sort -u | cut -d: -f2); do
  in_allow "$SP/capabilities/crm/adapters/airtable/guard.yaml" mcp__airtable__ "$t" && _report ok "Airtable $t allowed" || _report no "Airtable $t not in guard.yaml allow"
done
assert_contains "$SP/capabilities/crm/adapters/airtable/adapter.md" 'field_status'
[ "$(ls -A "$SP/migrations")" = ".gitkeep" ] && _report ok "migrations/ holds only .gitkeep" || _report no "migrations/ must hold only .gitkeep"

echo "-- scheduled runs (Agent Standard 2.1)"
assert_contains "$SP/agent.yaml" 'standard: "2.1"'
assert_contains "$SP/agent.yaml" 'version: 2.1.0'
assert_contains "$SP/agent.yaml" 'activity_digest: crm, email_drafts'
assert_not_contains "$SP/context/operating-config.md" 'schedules:'
assert_not_contains "$SP/context/operating-config.md" 'timezone:'
assert_not_contains "$SP/context/operating-config.md" 'cron + headless CLI'
assert_not_contains "$SP/context/operating-config.md" 'n8n'
assert_contains "$SP/skills/interview-business/SKILL.md" 'schedules.yaml'
assert_contains "$SP/skills/send-digest/SKILL.md" 'schedule_digest'
assert_contains "$SP/AGENT.md" 'schedules.yaml'
assert_contains "$SP/AGENT.md" 'unattended'
[ -f "$SP/skills/schedule/SKILL.md" ] && _report ok "schedule skill present" || _report no "schedule skill missing"
finish
