# Prospector — Sub-Agent Contract

## Purpose
Turn the ideal customer profile into scored, deduplicated lead records, so
qualified prospects enter the pipeline at stage `Scored` with a documented,
mechanical reason for that score.

## Trigger
A scheduled prospecting run, or the count of leads at stages `New` and
`Scored` falling below the `leads_per_week` target set in
`operating-config.md`.

## Inputs
- `context/icp.md` — firmographics, geography, target roles, buying
  triggers, anti-signals, and the scoring rubric
- `context/operating-config.md` — `leads_per_week`,
  `apify_spend_cap_usd_per_week`
- Existing CRM domains, read via CRM `query_by_stage` on `New` and
  `Scored`, to keep from re-working a company already in the pipeline

## Outputs
- New Leads records, one per company found, each carrying `Company`,
  `Domain`, `Location`, `Industry`, `Size`, `Source`, `Source URL`,
  `Score`, `Score Breakdown`, and `Stage = Scored`
- A lead matching an anti-signal in `icp.md` instead carries
  `Stage = Disqualified`, with the matched anti-signal recorded as the
  reason

## Tools allowed
- Apify actors (site and social scrapers used for sourcing)
- Web search
- Apollo adapter (stubbed — not yet enabled)
- CRM `create_lead`
- CRM `query_by_stage`

## Stop conditions
- The `leads_per_week` target (from `operating-config.md`) of new
  `Scored` leads is reached for the run
- The current source is exhausted — no further candidates are returned
  by the query or scrape in use
- The `apify_spend_cap_usd_per_week` cap (from `operating-config.md`) is
  hit

## Handoff
Calls CRM `update_stage(lead_id, "Scored", reason)` on every lead that
clears scoring, or `update_stage(lead_id, "Disqualified", reason)` on any
lead matching an anti-signal, and stops there. The stage transition is
the entire handoff — work at the next stage is picked up independently
by whichever contract queries the CRM for leads at that stage.

## Inline fallback
Runs as the first sequential phase on a host without sub-agent dispatch:
source candidates, apply the scoring rubric, call `create_lead` and
`update_stage` in the same context, then move to the next phase once a
stop condition is reached. No isolation or parallel dispatch is required
for correct behavior.

### Guardrails
- Deduplicate on `Domain` before writing. `create_lead` already dedupes
  on `Domain` and returns the existing `lead_id` without writing a
  second record, so this contract may call `create_lead` unconditionally
  on every raw find rather than pre-checking for a duplicate.
- Never fabricate an email address. If no contact detail can be sourced,
  leave it absent rather than guessed.
- Any match against `icp.md`'s Anti-signals list sends the lead straight
  to `Disqualified`, never through `Scored`.
- Every lead record carries a `Source URL` — the score and every
  criterion behind it must trace to something found, not assumed.
