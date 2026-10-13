---
name: preparer
description: Dispatch for a lead at stage `Scored` whose `Score` clears `research_threshold` — deep-researches the company, identifies decision-makers, produces hooks, and re-scores it.
---

# Preparer — Sub-Agent Contract

## Purpose
Deep-research top-scoring leads, identify decision-makers, and produce
usable hooks, then re-score the lead now that research has resolved the
two rubric criteria that scoring at intake could only estimate.

## Trigger
CRM `query_by_score(min_score = research_threshold, stage = "Scored",
limit = research_quota_per_week)` — leads at stage `Scored` whose `Score`
clears `research_threshold`, capped per run at `research_quota_per_week`
(both keys from `operating-config.md`).

## Inputs
- The lead record, via CRM `get_lead` (includes any existing linked
  Contacts, Research, and Activities)
- `context/business-profile.md` — what the business sells, proof,
  differentiators
- `context/icp.md` — buying triggers, target roles, anti-signals, and
  the scoring rubric
- `context/operating-config.md` — `research_threshold`,
  `research_quota_per_week`, `research_budget_per_lead_minutes`,
  `prospecting_sources`, `apify_spend_cap_usd_per_week`

## Outputs
- Research rows linked to the lead, each with `Type`, `Summary`,
  `Source URL`, `Date`, and, where usable, `Hook`
- Contacts rows linked to the lead, each with `Name`, `Title`, `Email`
  (if verifiable), `Phone` (if sourced), `LinkedIn URL` (if found),
  `Role` (decision-maker / influencer / gatekeeper), and `Verified`
- A revised `Score`, written by re-running `score-lead` against the same
  rubric in `icp.md` now that research has resolved the
  `Buying trigger present` and `Decision-maker reachable` criteria — the
  two criteria worth 45 of the 100 points that could only be guessed at
  before research
- The new per-criterion figures **appended** to `Score Breakdown` rather
  than overwriting the entry written when the lead was first scored, so
  the movement from estimate to sourced fact stays visible in the record
- `Stage = Researched`, or `Stage = Disqualified` if research surfaces
  an anti-signal

## Tools allowed
- Web search
- Map and directory listings, read through web search
- Scraping `find_contacts`, when `apify_contact_info` is listed in
  `prospecting_sources` — within `apify_spend_cap_usd_per_week`
- CRM `get_lead`
- CRM `query_by_score`
- CRM `log_research`
- CRM `upsert_contact`
- CRM `update_lead`
- CRM `update_activity` (`voided` only, for an opt-out)
- CRM `update_stage`
- Owner notify `notify_owner`
- Ledger `ledger_status`, `append_events`, `find_events`

Before researching, apply the contract's opt-out instruction
(`capabilities/crm/contract.md`, Approval invariant, **Opt-outs**) to
the lead.

## Stop conditions
- Two or more usable `Hook` values have been written for the lead
- The `research_budget_per_lead_minutes` time budget (from
  `operating-config.md`) for this lead is spent
- The `apify_spend_cap_usd_per_week` cap would be passed by the next
  scrape: stop scraping and carry on with web search

In a scheduled (unattended) run, never ask the operator a question; if
a required input is missing, call `notify_owner(kind: error)` with
what is missing, then stop and report it. Scheduled and interactive runs
use the same sources: whatever `prospecting_sources` lists.

## Scraping
When `apify_contact_info` is listed, gather the websites of the leads
being researched (skip a lead with no website) and call `find_contacts`
once per batch of up to 10. Add each email, phone and social link to its
lead's Contacts with its source URL.

Before each call, add up the Apify spend of the last 7 days (a rolling
window, not the calendar week): call `find_events` twice, with
`activity: prospect, event: step` and `activity: prepare, event: step`,
`since` set to now minus 7 days, and sum `cost_usd` over those `step`
events only (`run_finished` repeats the run's total, so counting it would
double the spend). Add this run's own steps not yet written (queued or
pending). Estimate the next call from `usage.md`'s `## Cost`: for contact
info, `max_pages_per_call` times the per-page estimate. If the spend plus
that estimate would pass `apify_spend_cap_usd_per_week`, write a
`stop_condition` event, call `notify_owner(kind: alert)` naming the cap,
and stop scraping for this run.

If a call is blocked by the guard, stop the activity and call
`notify_owner(kind: error)` with the block's message. Never retry a guard
block.

## Ledger
Call `ledger_status` first; write `run_started` first and `run_finished` last, numbering events with `seq` per `capabilities/ledger/contract.md` (Run bracketing, Failure policy). Write `stop_condition`, `notify_sent` and `error` events when they happen.

One `step` per lead researched: `subject` is the CRM lead id,
`items_in` the findings logged, `items_out` the hooks written. Each
`find_contacts` call is a `step` with `subject` the website domains joined
by `,` (truncated to 100 characters), `items_in` the URLs sent,
`items_out` the contacts written, and `cost_usd` (an estimate; `detail`
says `estimated`).

## Handoff
Writes each finding with CRM `log_research(lead_id, type, summary,
source_url, date, hook)` and each person with CRM
`upsert_contact(lead_id, name, title, email, phone, linkedin_url, role,
verified, notes)` as research proceeds. Re-runs `score-lead`, then calls CRM
`update_lead(lead_id, fields)` to write the revised `Score`, the
appended `Score Breakdown`, and the company profile fields it confirmed
(`description`, `address`, `company_linkedin_url`, `facebook_url`,
`instagram_url`; see `capabilities/crm/contract.md`, each one sourced),
then calls CRM `update_stage(lead_id,
"Researched", reason)` — or `update_stage(lead_id, "Disqualified",
reason)` if an anti-signal was found — and stops. The stage transition
is the entire handoff; the next stage's work is picked up independently
by whichever contract queries the CRM for leads at that stage and
score.

## Inline fallback
Runs as the second sequential phase on a host without sub-agent
dispatch: pull leads at or above `research_threshold` directly from the
CRM, research and re-score each in the same context, then advance the
stage before moving to the next phase.

### Guardrails
- If `prospecting_sources` lists `apify_site_scraper`, stop and report
  `apify_site_scraper was renamed apify_contact_info`.
- Nothing behind a login is used as a source.
- A `Source URL` is required on every Research row —
  `log_research` itself rejects a call with an empty `source_url` or an
  empty `hook`.
- Anything inferred rather than directly sourced is marked `unverified`
  in `Summary`.
- An anti-signal discovered during research moves the lead straight to
  `Disqualified` rather than passing it on to the next stage.
