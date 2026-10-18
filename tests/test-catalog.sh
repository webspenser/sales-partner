#!/usr/bin/env bash
# Offer catalog reader: both CRM bootstraps must read the catalog's one YAML
# block the same way. Loads each bootstrap with importlib, so no network call
# happens (load_key() only runs under __main__).
set -uo pipefail
cd "$(dirname "$0")/.."
SP=.
. tests/lib.sh

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

# Prints repr(read_catalog(path)); a SystemExit prints its message to stderr, exit 1.
PY='
import importlib.util, sys
spec = importlib.util.spec_from_file_location("bootstrap", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
print(repr(mod.read_catalog(sys.argv[2])))
'
catalog() { python3 -B -c "$PY" "$1" "$2"; }

two_segments() { # two segments, six offers, in the nested style
  printf '%s\n' '# Offer Catalog' 'Intro text.' '' '```yaml' \
    'segments:' \
    '  - id: professional-services' \
    '    name: Professional Services' \
    '    industries: [Accounting, Legal]' \
    '    offers:' \
    '      - id: ps-inbound-lead-qualification   # inline comment' \
    '        name: Inbound' \
    '        signals:' \
    '          - billing complaints in reviews' \
    '      - id: ps-invoice-reconciliation' \
    '        name: Invoices' \
    '      - id: ps-onboarding-copilot' \
    '        name: Onboarding' \
    '  - id: home-auto-services' \
    '    name: Home' \
    '    offers:' \
    '      - id: ha-inbound-lead-qualification' \
    '      - id: ha-reputation-management' \
    '      - id: ha-past-customer-outreach' \
    '```' 'Trailing prose.'
}

echo "-- two-segment example"
two_segments > "$T/two.md"
WANT="(['professional-services', 'home-auto-services'], ['ps-inbound-lead-qualification', 'ps-invoice-reconciliation', 'ps-onboarding-copilot', 'ha-inbound-lead-qualification', 'ha-reputation-management', 'ha-past-customer-outreach'])"

echo "-- one segment, two offers"
printf '%s\n' '```yaml' 'segments:' '- id: acme' '  offers:' '  - id: widget-a' '  - id: widget-b' '```' > "$T/one.md"
WANT_ONE="(['acme'], ['widget-a', 'widget-b'])"

echo "-- bad catalogs"
printf '%s\n' '# Offer Catalog' 'No block here.' > "$T/noblock.md"
printf '%s\n' '```yaml' 'segments:' '  - id: acme' '    offers:' '      - id: Invoice_Recon' '```' > "$T/badid.md"
printf '%s\n' '```yaml' 'segments:' '  - id: a-seg' '    offers:' '      - id: same-offer' '  - id: b-seg' '    offers:' '      - id: same-offer' '```' > "$T/dupoffer.md"
printf '%s\n' '```yaml' 'segments:' '  - id: acme' '    offers:' '      - id: acme' '```' > "$T/segoffer.md"
printf '%s\n' '```yaml' 'segments:' '  - id: acme' '    offers:' '```' > "$T/nooffers.md"

check() { # check <label> <bootstrap> <catalog> <want>
  local got
  got=$(catalog "$2" "$3" 2>&1)
  if [ "$got" = "$4" ]; then _report ok "$1"; else _report no "$1 (got: $got)"; fi
}

fails() { # fails <label> <bootstrap> <catalog> <must-contain...>
  local label=$1 b=$2 f=$3 out; shift 3
  if out=$(catalog "$b" "$f" 2>&1); then _report no "$label: expected a non-zero exit"; return; fi
  local s
  for s in offer-catalog.md "$@"; do
    case "$out" in *"$s"*) ;; *) _report no "$label: message lacks '$s' (got: $out)"; return ;; esac
  done
  _report ok "$label"
}

for tool in attio hubspot; do
  B=capabilities/crm/tools/$tool/bootstrap.py
  echo "-- $tool"
  check "$tool: two segments, six offers" "$B" "$T/two.md" "$WANT"
  check "$tool: one segment, two offers" "$B" "$T/one.md" "$WANT_ONE"
  check "$tool: the package template parses to two segments, six offers" "$B" context/offer-catalog.md \
    "(['professional-services', 'home-auto-services'], ['ps-inbound-lead-qualification', 'ps-invoice-reconciliation', 'ps-onboarding-copilot', 'ha-inbound-lead-qualification', 'ha-reputation-management', 'ha-past-customer-outreach'])"
  fails "$tool: missing file" "$B" "$T/missing.md"
  fails "$tool: no yaml block" "$B" "$T/noblock.md"
  fails "$tool: bad id" "$B" "$T/badid.md" Invoice_Recon
  fails "$tool: duplicate offer id" "$B" "$T/dupoffer.md" same-offer
  fails "$tool: offer id equal to a segment id" "$B" "$T/segoffer.md" acme
  fails "$tool: no offers" "$B" "$T/nooffers.md"
  grep -qF -- '--catalog' "$B" && _report ok "$tool: has --catalog" || _report no "$tool: lacks --catalog"
  grep -qF 'context/offer-catalog.md' "$B" && _report ok "$tool: --catalog defaults to context/offer-catalog.md" || _report no "$tool: lacks the default catalog path"
done

echo "-- both bootstraps agree"
A=$(catalog capabilities/crm/tools/attio/bootstrap.py "$T/two.md" 2>&1)
H=$(catalog capabilities/crm/tools/hubspot/bootstrap.py "$T/two.md" 2>&1)
[ "$A" = "$H" ] && _report ok "identical results for the two-segment fixture" || _report no "bootstraps disagree: $A vs $H"

echo "-- the catalog is read before the key and any API call"
for tool in attio hubspot; do
  out=$(cd "$T" && env -u ATTIO_API_KEY -u HUBSPOT_TOKEN python3 -B "$OLDPWD/capabilities/crm/tools/$tool/bootstrap.py" --catalog "$T/missing.md" 2>&1)
  case "$out" in *offer-catalog.md*) _report ok "$tool: a missing catalog is reported before the missing key" ;; *) _report no "$tool: expected an offer-catalog.md message (got: $out)" ;; esac
done

finish
