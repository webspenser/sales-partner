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
  `Scored`, to keep from re-working a business already in the pipeline.
  When `create_lead` returns an existing lead, read it (`get_lead`) and
  leave it untouched unless its status is `New`, or `Nurture` with a Revisit On date in the past:
  every other lead is already in progress, the operator's, or out.
  Never re-score or move any other lead — except for a logged opt-out on a lead at `New`
  or `Scored`, handled per the contract's opt-out instruction
  (`capabilities/crm/contract.md`, Approval invariant, **Opt-outs**).

## Outputs
- New Leads records, one per company found, each carrying `Company`,
  `Domain` (when it has a website), `Location`, `Address`, `Phone`, `Email`
  (each when sourced), `Industry`, `Size`, `Source`, `Source URL`,
  `Score`, `Score Breakdown`, and `Stage = Scored`, plus the
  company profile fields the listing shows (`description`, and the
  business's LinkedIn, Facebook or Instagram page when the listing links
  it; see `capabilities/crm/contract.md`), passed to `create_lead`
- A lead matching an anti-signal in `icp.md` instead carries
  `Stage = Disqualified`, with the matched anti-signal recorded as the
  reason

## Tools allowed
- Sourcing tools — only the sources listed in `prospecting_sources`
  (`operating-config.md`): `apify_google_maps`, `apify_contact_info`,
  `web_search`. A source not in that list is never used, even when it
  would find more leads.
- Scraping `find_businesses`
- CRM `create_lead`
- CRM `get_lead`
- CRM `query_by_stage`
- CRM `update_stage`
- CRM `update_lead` (`Do Not Contact` only, for an opt-out)
- CRM `update_activity` (`voided` only, for an opt-out)
- Owner notify `notify_owner`
- Ledger `ledger_status`, `append_events`, `find_events`

## Stop conditions
- The `leads_per_week` target (from `operating-config.md`) of new
  `Scored` leads is reached for the run
- Every source listed in `prospecting_sources` is exhausted — no
  further candidates are returned by any listed query or scrape
- The `apify_spend_cap_usd_per_week` cap (from `operating-config.md`) is
  hit

In a scheduled (unattended) run, never ask the operator a question; if
a required input is missing, call `notify_owner(kind: error)` with
what is missing, then stop and report it. Scheduled and interactive runs
use the same sources: whatever `prospecting_sources` lists.

## Scraping
For `apify_google_maps`, make one `find_businesses(query, location)` call
per query. The location is a city and state (the tool passes them as
structured `city`, `state` and `countryCode`), never free text: a free-text
location can resolve to the wrong area. Deduplicate against the CRM, score
and create leads as for any other source.

Before each call, add up the Apify spend of the last 7 days (a rolling
window, not the calendar week): call `find_events` twice, with
`activity: prospect, event: step` and `activity: prepare, event: step`,
`since` set to now minus 7 days, and sum `cost_usd` over those `step`
events only (`run_finished` repeats the run's total, so counting it would
double the spend). Add this run's own steps not yet written (queued or
pending). Estimate the next call from `usage.md`'s `## Cost`: for Maps,
`max_places_per_search` times the per-place estimate. If the spend plus
that estimate would pass `apify_spend_cap_usd_per_week`, write a
`stop_condition` event, call `notify_owner(kind: alert)` naming the cap,
and stop scraping for this run.

If a call is blocked by the guard, stop the activity and call
`notify_owner(kind: error)` with the block's message. Never retry a guard
block.

## Ledger
Call `ledger_status` first; write `run_started` first and `run_finished` last, numbering events with `seq` per `capabilities/ledger/contract.md` (Run bracketing, Failure policy). Write `stop_condition`, `notify_sent` and `error` events when they happen.

One `step` per source query: `subject` is the query for web search; for
`find_businesses` it is `<query>|<city>, <state>` (for example
`HVAC contractor|Oakland, CA`), the same format used when matching prior
steps. `items_in` is the results returned, `items_out` the new `Scored`
leads it produced, and, for a `find_businesses` call, `cost_usd` is the
run's cost (an estimate; `detail` says `estimated`). Before choosing
queries, call
`find_events(since: 30 days ago, activity: prospect, event: step)` and
skip any query whose `subject` matches a step with `outcome` `ok` and
`items_out` 0, unless every remaining query would be skipped. An errored
or partial step never suppresses a query. If `find_events` fails,
proceed without skipping. `run_finished` carries the run's totals and
the Apify spend in `cost_usd`.

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
- If `prospecting_sources` lists `apify_site_scraper`, stop and report
  `apify_site_scraper was renamed apify_contact_info`.
- If `apollo` is listed in `prospecting_sources`, report that the
  Apollo tool is stubbed and not yet enabled, and continue with the
  remaining listed sources — never quietly swap in an unlisted one.
  If no listed source is usable, stop and escalate.
