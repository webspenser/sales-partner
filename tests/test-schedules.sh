#!/usr/bin/env bash
# sales-partner's activities pass the schedule checker when bound to guarded tools.
set -uo pipefail
cd "$(dirname "$0")/.."
source tests/lib.sh
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
C=hooks/schedule_check.py
inst() { # inst <dir> <crm provider>
  mkdir -p "$1"
  printf '%s\n' 'agent: sales-partner' 'mode: plugin' "bind_crm: $2" 'bind_email_drafts: gmail' > "$1/instance.yaml"
  printf '%s\n' 'timezone: America/New_York' 'schedule_prospect: "Monday 07:00"' 'then_prospect: prepare' \
    'schedule_approach: "Tuesday 07:00"' 'schedule_digest: "Monday 08:00"' > "$1/schedules.yaml"
}
for crm in attio airtable hubspot; do
  inst "$W/$crm" "$crm"
  out=$(python3 -B "$C" check "$W/$crm" --repo acme/sales 2>&1); rc=$?
  [ "$rc" -eq 0 ] && _report ok "all activities pass with $crm + gmail" || _report no "$crm (rc=$rc): $out"
done
printf '%s\n' 'agent: sales-partner' 'mode: plugin' 'bind_crm: attio' > "$W/attio/instance.yaml"
out=$(python3 -B "$C" check "$W/attio" 2>&1); rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -qF 'email_drafts is not bound' && _report ok "digest refused without email binding" || _report no "unbound email (rc=$rc): $out"
# approach needs only the CRM: schedulable with no email_drafts bound.
mkdir -p "$W/crmonly"
printf '%s\n' 'agent: sales-partner' 'mode: plugin' 'bind_crm: attio' > "$W/crmonly/instance.yaml"
printf '%s\n' 'timezone: America/New_York' 'schedule_approach: "Tuesday 07:00"' > "$W/crmonly/schedules.yaml"
out=$(python3 -B "$C" check "$W/crmonly" --repo acme/sales 2>&1); rc=$?
[ "$rc" -eq 0 ] && _report ok "approach passes with only crm bound" || _report no "approach with only crm (rc=$rc): $out"
grep -qx 'activity_approach: crm' agent.yaml && _report ok "approach declares crm only" || _report no "activity_approach is not exactly crm"
for a in prospect prepare approach digest; do
  grep -q "^activity_$a:" agent.yaml && _report ok "activity $a declared" || _report no "activity $a missing"
done
for f in subagents/prospector.md subagents/preparer.md; do
  grep -qF "web search only; Apify connectors are" "$f" && grep -qF "attached to routines." "$f" \
    && _report ok "$f: scheduled runs use web search only" || _report no "$f: no web-search-only rule for scheduled runs"
done
# enroll and sync-replies left with the sequences capability.
mkdir -p "$W/enr"
printf '%s\n' 'agent: sales-partner' 'mode: plugin' 'bind_crm: attio' > "$W/enr/instance.yaml"
printf '%s\n' 'timezone: America/New_York' 'schedule_enroll: "daily 10:00"' > "$W/enr/schedules.yaml"
out=$(python3 -B "$C" check "$W/enr" --repo acme/sales 2>&1); rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -qF 'enroll is not an activity of sales-partner' && _report ok "enroll is no longer schedulable" || _report no "enroll still schedulable (rc=$rc): $out"
finish
