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
  `research_quota_per_week`, `research_budget_per_lead_minutes`

## Outputs
- Research rows linked to the lead, each with `Type`, `Summary`,
  `Source URL`, `Date`, and, where usable, `Hook`
- Contacts rows linked to the lead, each with `Name`, `Title`, `Email`
  (if verifiable), `LinkedIn URL` (if found), `Role` (decision-maker /
  influencer / gatekeeper), and `Verified`
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
- Apify site and social scrapers
- CRM `get_lead`
- CRM `query_by_score`
- CRM `update_stage`
- Provider CRM write access to Research and Contacts records, per
  `crm-airtable-adapter.md` — outside the six neutral operations, which
  govern lead-level state only

## Stop conditions
- Two or more usable `Hook` values have been written for the lead
- The `research_budget_per_lead_minutes` time budget (from
  `operating-config.md`) for this lead is spent

## Handoff
Re-runs `score-lead`, writes the revised `Score`, appends to
`Score Breakdown`, then calls CRM `update_stage(lead_id, "Researched",
reason)` — or `update_stage(lead_id, "Disqualified", reason)` if an
anti-signal was found — and stops. The stage transition is the entire
handoff; the next stage's work is picked up independently by whichever
contract queries the CRM for leads at that stage and score.

## Inline fallback
Runs as the second sequential phase on a host without sub-agent
dispatch: pull leads at or above `research_threshold` directly from the
CRM, research and re-score each in the same context, then advance the
stage before moving to the next phase.

### Guardrails
- Nothing behind a login is used as a source.
- A `Source URL` is required on every Research row.
- Anything inferred rather than directly sourced is marked `unverified`
  in `Summary`.
- An anti-signal discovered during research moves the lead straight to
  `Disqualified` rather than passing it on to the next stage.
