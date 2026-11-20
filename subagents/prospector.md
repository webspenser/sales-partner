---
name: prospector
description: Dispatch for a scheduled prospecting run, or when the count of leads at stages `New` and `Scored` falls below the `leads_per_week` target — turns the ICP into deduplicated Lead records with a Fit score.
---

# Prospector — Sub-Agent Contract

## Purpose
Turn the ideal customer profile into deduplicated lead records with a Fit
score, so qualified prospects enter the pipeline at stage `Scored` with a
documented, mechanical reason for that score.

## Trigger
A scheduled prospecting run, or the count of leads at stages `New` and
`Scored` falling below the `leads_per_week` target set in
`operating-config.md`.

## Inputs
- `context/icp.md` — firmographics, geography, anti-signals, and the
  Fit score rubric
- `context/offer-catalog.md` — the segments and each one's `industries`
  list, read for the lead's Industry and Segment (never its offers: the
  hero offer is the Preparer's)
- `context/operating-config.md` — `leads_per_week`,
  `prospecting_sources`, `scraping_spend_cap_usd_per_week`
- Existing leads, read via CRM `query_by_stage` on `New` and
  `Scored`, to keep from re-working a business already in the pipeline.
  When `create_lead` returns an existing lead, read it (`get_lead`) and
  leave it untouched unless its status is `New`, or `Nurture` with a Revisit On date in the past:
  every other lead is already in progress, the operator's, or out.
  Never re-score or move any other lead — except a `Do Not Contact`
  lead at `New` or `Scored`, which goes to `Disqualified` with reason
  `opt-out` per the contract's opt-out instruction
  (`capabilities/crm/contract.md`, Approval invariant).

## Outputs
- New Leads records, one per company found, each carrying `Company`,
  `Domain` (when it has a website), `Location`, `Address`, `Phone`, `Email`
  (each when sourced), `Industry`, `Segment` (when one fits; see
  Industry and segment), `Size`, `Source`, `Source URL`,
  `Fit Score`, `Fit Breakdown`, and `Stage = Scored`, plus the
  company profile fields the listing shows (`description`, and the
  business's LinkedIn, Facebook or Instagram page when the listing links
  it; see `capabilities/crm/contract.md`), passed to `create_lead`
- A lead matching an anti-signal in `icp.md` instead carries
  `Stage = Disqualified`, with the matched anti-signal recorded as the
  reason, and no score

## Tools allowed
- Sourcing tools — only the sources listed in `prospecting_sources`
  (`operating-config.md`): its own sources are `google_maps`,
  `yellowpages` and `web_search` (and the `apollo` stub;
  Guardrails). The source `web_search` is the host's built-in web search, never the `web_search` capability (Exa):
  the Prospector never calls `search_web`. A source not in that list is never used, even when it
  would find more leads. The Prospector ignores the Preparer-only sources `contact_info`, `reviews`, `ads`, `jobs`, `site_reader`, `open_web`, `bbb` and `yelp`
  (and `profiles`; as `operating-config.md` says): they research leads already found,
  and never source new ones.
- Scraping `find_businesses`, and `find_listing` with `directory: yellowpages`
- CRM `create_lead`
- CRM `get_lead`
- CRM `query_by_stage`
- CRM `update_stage`
- CRM `update_lead` (`Fit Score`, `Fit Breakdown`, `Industry` and
  `Segment` on a re-found `New` lead)
- Owner notify `notify_owner`
- Ledger `ledger_status`, `append_events`, `find_events`

## Stop conditions
- The `leads_per_week` target (from `operating-config.md`) of new
  `Scored` leads is reached for the run
- Every source listed in `prospecting_sources` is exhausted — no
  further candidates are returned by any listed query or scrape. Only
  the Prospector's own sources count (`google_maps`,
  `yellowpages`, `web_search`); the Preparer-only names are skipped, never waited on
- The `scraping_spend_cap_usd_per_week` cap (from `operating-config.md`) is
  hit

In a scheduled (unattended) run, never ask the operator a question; if
a required input is missing, call `notify_owner(kind: error)` with
what is missing, then stop and report it. Scheduled and interactive runs
use the same sources: whatever `prospecting_sources` lists.

## Scraping
For `google_maps`, make one `find_businesses(query, location)` call
per query. The location is a city and state, sent structured as
`location` {`city`, `state`, `country`}, never free text: a free-text
location can resolve to the wrong area. One search returns up to 20 places per search: for more leads, run another search (another trade
term or a nearby city), each under the skip rule in Ledger. Deduplicate against the CRM, score
and create leads as for any other source.

`yellowpages` sources leads through `find_listing(directory: yellowpages, query, location)`: one call per query, the
same trade and city as the Maps query. Its listings are deduplicated by phone and website like Maps, against the CRM and against this
run's Maps results; a listing with neither phone nor website is not a
lead. A YellowPages lead takes its location from the listing's `address` (city and state as the listing gives them, not the query's
city). A YellowPages lead has no Maps place id, so its `Source URL` is
the listing's `listing_url`, and the Preparer's Google reviews call is
skipped for it until a Maps match is found.

Each call returns the scraping tool's envelope (`usage.md`, Envelope).
Write one `step` per entry in the envelope's `calls[]`, with that
entry's `cost_usd` and the `detail` the Envelope gives, under the
query's `subject` (Ledger); an error with no calls writes the one
`skipped` step it describes. Use the `result` even when `degraded` is
true; an empty `result` is a search with no finds. Never retry a call:
the server has already retried and failed over.

Before each call, add up the scraping spend of the last 7 days (a rolling
window, not the calendar week): call `find_events` twice, with
`activity: prospect, event: step` and `activity: prepare, event: step`,
`since` set to now minus 7 days, and sum `cost_usd` over those `step`
events only, leaving out every step whose `detail` starts with `search_web` (Exa
spend is not scraping spend; `run_finished` repeats the run's total, so
counting it would double the spend). Add this run's own steps not yet written (queued or
pending). Take the next call's cost as its worst case from the scraping tool's `## Cost`
(`find_businesses` $0.08, `find_listing` on YellowPages $0.10). If the
spend plus that worst case would pass `scraping_spend_cap_usd_per_week`, write a
`stop_condition` event, call `notify_owner(kind: alert)` naming the cap,
and stop scraping for this run.

On `budget_exhausted`, make no further scraping call this run: the
server's own 7-day cap is reached. Write one `stop_condition` event with
`detail` `scraping server 7-day cap`, call `notify_owner(kind: alert)`
naming it, and finish the run with the leads found so far.

A guard block, `input_refused` or `unavailable` on a scraping call does
not stop the activity: that search is not run, the run goes on with the
next search, and it is never retried with changed arguments (Drift in
the scraping tool's `usage.md`); the run report quotes the block or the
error's `message`. When the same source is blocked or fails on every
search of a run, the run ends with one `notify_owner(kind: error)` at the end of the run,
naming the source and its first message. A guard block on any other
capability stops the activity and calls `notify_owner(kind: error)` with
the block's message. Never retry a guard block.

## Scoring
Score every find with `score-lead` (`rubric: fit`), from the listing's
fields only: address and coordinates, phone, website, category, rating,
per-star review counts, review count, opening hours, and whether the
listing is claimed. A listing marked temporarily closed matches the
Temporarily closed anti-signal: the lead goes to `Disqualified` with that
reason and is never scored. Pass the total and the breakdown to
`create_lead` as `fit_score` and `fit_breakdown`. When `create_lead`
returns an existing lead at `New`, score it the same way and write the
Fit fields with `update_lead` (a re-score appends, per `score-lead`),
with its Industry and Segment as below.

## Industry and segment
Read `context/offer-catalog.md` fresh for each run. Every lead it scores
carries two more fields, passed to `create_lead` as `industry` and
`segment` (or to `update_lead` on a re-found `New` lead):
- **Industry:** the specific trade from the listing category or search
  result, in the catalog's wording where one fits (a Maps category
  `Plumber` is `Plumbing` when a segment's `industries` lists
  `Plumbing`); otherwise the trade as the source names it.
- **Segment:** the id of the catalog segment whose `industries` include it,
  matched on the Industry as written. When no segment lists it, or two
  do, `segment` is left empty, never a guess at the nearest one. Such a lead scores low
  on industry fit, per the rubric, and is not researched unless the
  operator ticks Research Anyway.

## Ledger
Call `ledger_status` first; write `run_started` first and `run_finished` last, numbering events with `seq` per `capabilities/ledger/contract.md` (Run bracketing, Failure policy). Write `stop_condition`, `notify_sent` and `error` events when they happen.

One `step` per provider call of a source query (the envelope's `calls[]`; one for a web search): `subject` is the query for web search; for
`find_businesses` it is `<query>|<city>, <state>` (for example
`HVAC contractor|Oakland, CA`), the same format used when matching prior
steps; for `find_listing(directory: yellowpages)` it is `yellowpages|<query>|<city>, <state>`, so a YellowPages step never matches
(or suppresses) a Maps query. `items_in` is the results returned,
`items_out` the new `Scored` leads it produced, and every scraping step carries `cost_usd`, the provider call's cost (`detail` says
`estimated` when the server estimated it). Before choosing
queries, call
`find_events(since: 30 days ago, activity: prospect, event: step)` and
skip any query whose `subject` matches a step with `outcome` `ok` and
`items_out` 0, unless every remaining query would be skipped. An errored
or partial step never suppresses a query. If `find_events` fails,
proceed without skipping. `run_finished` carries the run's totals and
the scraping spend in `cost_usd`.

## Handoff
Calls CRM `update_stage(lead_id, "Scored", reason)` on every lead that
has a Fit score, or `update_stage(lead_id, "Disqualified", reason)` on any
lead matching an anti-signal, and stops there. The stage transition is
the entire handoff — work at the next stage is picked up independently
by whichever contract queries the CRM for leads at that stage.

## Inline fallback
Runs as the first sequential phase on a host without sub-agent dispatch:
source candidates, apply the Fit rubric, call `create_lead` and
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
- Every lead record carries a `Source URL` — the Fit score and every
  criterion behind it must trace to something found, not assumed.
- Never score the Approach rubric or guess at research: a buying
  trigger, a decision-maker or the hero offer is the Preparer's to find.
  The Prospector never writes `hero_offer`, `offer_reason`,
  `offer_evidence` or `research_anyway`.
- If `prospecting_sources` lists `apify_site_scraper`, stop and report
  `apify_site_scraper was renamed apify_contact_info`.
- If `context/operating-config.md` lists a name renamed in 9.0.0 (an `apify_` source or cap key), stop and report `<old> was renamed <new> in 9.0.0`
  (the table in the README's 8.7 upgrade note), naming each old key it found.
- If `apollo` is listed in `prospecting_sources`, report that the
  Apollo tool is stubbed and not yet enabled, and continue with the
  remaining listed sources — never quietly swap in an unlisted one.
  If no listed source is usable, stop and escalate.
