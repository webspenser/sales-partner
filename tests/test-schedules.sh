#!/usr/bin/env bash
# sales-partner's activities pass the schedule checker when bound to guarded tools.
set -uo pipefail
cd "$(dirname "$0")/.."
source tests/lib.sh
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
C=hooks/schedule_check.py
notify() { # notify <dir>: bind owner_notify to Resend with pinned owner values
  mkdir -p "$1/bindings"
  printf '%s\n' 'bind_owner_notify: resend' >> "$1/instance.yaml"
  printf '%s\n' 'recipient_email: owner@example.com' 'sender_email: no-reply@example.com' > "$1/bindings/owner_notify.md"
}
ledger() { # ledger <dir>: bind the ledger to Airtable with complete bindings
  mkdir -p "$1/bindings"
  printf '%s\n' 'bind_ledger: airtable' >> "$1/instance.yaml"
  { echo 'base_id: appAAAAAAAAAAAAAA'; echo 'table_events: tblAAAAAAAAAAAAAA'
    for f in at run_id seq activity trigger event subject outcome items_in items_out cost_usd duration_s detail agent_version backfilled; do
      echo "field_$f: fld$(printf '%-14s' "$f" | tr ' _' 'XX' | cut -c1-14)"; done
    echo 'ledger_schema: 1'; } > "$1/bindings/ledger.md"
}
inst() { # inst <dir> <crm provider>
  mkdir -p "$1"
  printf '%s\n' 'agent: sales-partner' 'mode: plugin' "bind_crm: $2" > "$1/instance.yaml"
  notify "$1"
  ledger "$1"
  printf '%s\n' 'timezone: America/New_York' 'schedule_prospect: "Monday 07:00"' 'then_prospect: prepare' \
    'schedule_approach: "Tuesday 07:00"' 'schedule_digest: "Monday 08:00"' > "$1/schedules.yaml"
}
for crm in attio hubspot; do
  inst "$W/$crm" "$crm"
  out=$(python3 -B "$C" check "$W/$crm" --repo acme/sales 2>&1); rc=$?
  [ "$rc" -eq 0 ] && _report ok "all activities pass with $crm" || _report no "$crm (rc=$rc): $out"
done
# approach needs the CRM and owner_notify (to alert the owner) and nothing else.
mkdir -p "$W/approach"
printf '%s\n' 'agent: sales-partner' 'mode: plugin' 'bind_crm: attio' > "$W/approach/instance.yaml"
notify "$W/approach"
ledger "$W/approach"
printf '%s\n' 'timezone: America/New_York' 'schedule_approach: "Tuesday 07:00"' > "$W/approach/schedules.yaml"
out=$(python3 -B "$C" check "$W/approach" --repo acme/sales 2>&1); rc=$?
[ "$rc" -eq 0 ] && _report ok "approach passes with crm, owner_notify and ledger bound" || _report no "approach with crm, owner_notify and ledger (rc=$rc): $out"
grep -qx 'activity_approach: crm, owner_notify, ledger' agent.yaml && _report ok "approach declares crm, owner_notify and ledger only" || _report no "activity_approach is not exactly crm, owner_notify, ledger"
# An instance with the CRM and owner_notify bound but no ledger fails the gate.
mkdir -p "$W/noledger"
printf '%s\n' 'agent: sales-partner' 'mode: plugin' 'bind_crm: attio' > "$W/noledger/instance.yaml"
notify "$W/noledger"
printf '%s\n' 'timezone: America/New_York' 'schedule_approach: "Tuesday 07:00"' > "$W/noledger/schedules.yaml"
out=$(python3 -B "$C" check "$W/noledger" --repo acme/sales 2>&1); rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -qF 'ledger is not bound' && _report ok "ledger unbound fails the gate" || _report no "ledger unbound (rc=$rc): $out"
# Every activity can alert the owner, so none is schedulable without owner_notify.
mkdir -p "$W/crmonly"
printf '%s\n' 'agent: sales-partner' 'mode: plugin' 'bind_crm: attio' > "$W/crmonly/instance.yaml"
printf '%s\n' 'timezone: America/New_York' 'schedule_approach: "Tuesday 07:00"' > "$W/crmonly/schedules.yaml"
out=$(python3 -B "$C" check "$W/crmonly" --repo acme/sales 2>&1); rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -qF 'owner_notify is not bound' && _report ok "owner_notify unbound fails the gate" || _report no "owner_notify unbound (rc=$rc): $out"
# A bound owner_notify with no pinned recipient fails the gate.
mkdir -p "$W/nopin/bindings"
printf '%s\n' 'agent: sales-partner' 'mode: plugin' 'bind_crm: attio' 'bind_owner_notify: resend' > "$W/nopin/instance.yaml"
printf '%s\n' 'sender_email: no-reply@example.com' > "$W/nopin/bindings/owner_notify.md"
printf '%s\n' 'timezone: America/New_York' 'schedule_approach: "Tuesday 07:00"' > "$W/nopin/schedules.yaml"
out=$(python3 -B "$C" check "$W/nopin" --repo acme/sales 2>&1); rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -qF 'has no recipient_email line' && _report ok "missing recipient_email fails the gate" || _report no "missing recipient_email (rc=$rc): $out"
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
notify "$W/enr"
printf '%s\n' 'timezone: America/New_York' 'schedule_enroll: "daily 10:00"' > "$W/enr/schedules.yaml"
out=$(python3 -B "$C" check "$W/enr" --repo acme/sales 2>&1); rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -qF 'enroll is not an activity of sales-partner' && _report ok "enroll is no longer schedulable" || _report no "enroll still schedulable (rc=$rc): $out"
finish
