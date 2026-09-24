---
name: prospector
description: Dispatch for a scheduled prospecting run, or when the count of leads at stages `New` and `Scored` falls below the `leads_per_week` target — turns the ICP into scored, deduplicated Lead records.
---

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
  `prospecting_sources`, `apify_spend_cap_usd_per_week`
- Existing leads, read via CRM `query_by_stage` on `New` and
  `Scored`, to keep from re-working a business already in the pipeline

## Outputs
- New Leads records, one per company found, each carrying `Company`,
  `Domain` (when it has a website), `Location`, `Address`, `Phone`, `Email`
  (each when sourced), `Industry`, `Size`, `Source`, `Source URL`,
  `Score`, `Score Breakdown`, and `Stage = Scored`
- A lead matching an anti-signal in `icp.md` instead carries
  `Stage = Disqualified`, with the matched anti-signal recorded as the
  reason

## Tools allowed
- Sourcing tools — only the sources listed in `prospecting_sources`
  (`operating-config.md`): `apify_google_maps`, `apify_site_scraper`,
  `web_search`. A source not in that list is never used, even when it
  would find more leads.
- CRM `create_lead`
- CRM `query_by_stage`
- CRM `update_stage`

## Stop conditions
- The `leads_per_week` target (from `operating-config.md`) of new
  `Scored` leads is reached for the run
- Every source listed in `prospecting_sources` is exhausted — no
  further candidates are returned by any listed query or scrape
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
- Deduplicate before writing. `create_lead` already dedupes on domain,
  then phone, then company + address, and returns the existing
  `lead_id` without writing a second record, so this contract may call
  `create_lead` unconditionally on every raw find rather than
  pre-checking for a duplicate.
- Never fabricate an email address. If no contact detail can be sourced,
  leave it absent rather than guessed.
- Any match against `icp.md`'s Anti-signals list sends the lead straight
  to `Disqualified`, never through `Scored`.
- Every lead record carries a `Source URL` — the score and every
  criterion behind it must trace to something found, not assumed.
- If `apollo` is listed in `prospecting_sources`, report that the
  Apollo adapter is stubbed and not yet enabled, and continue with the
  remaining listed sources — never quietly swap in an unlisted one.
  If no listed source is usable, stop and escalate.
