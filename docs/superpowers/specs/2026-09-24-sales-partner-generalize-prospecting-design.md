# Sales Partner — Generalized Prospecting Design

**Date:** 2026-09-24
**Status:** Approved in conversation, pending spec review
**Amends:** [Sales Partner Agent — Design](./2026-09-01-sales-partner-agent-design.md)
**Location:** `agent-library/sales-partner/`

## Purpose

Let an operator configure a recurring prospecting activity — when it
runs, how many leads it produces, where it looks, and which sourcing
tools it may use — and let the pipeline target local businesses as
well as companies, ending in leads that are ready for a phone call.

This amends the existing agent. It adds configuration keys, contract
fields, one channel, one skill, and one template. It changes no
guardrail: the agent still never contacts a prospect, and every
outbound touch — a call included — stops at a `draft` Activity.

## Origin

An operator wants the agent to run every Monday at 07:00, find 25
local businesses inside a chosen radius, capture owner name, business
email, address, website, and phone, write each as a CRM profile, do
basic research for buying signals, and leave the leads ready for
calls. This spec keeps only what generalizes; the operator's own
values belong in an installed copy's `context/` files, not here.

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Where targeting lives | `icp.md` holds *who* (including service-area radius); `operating-config.md` holds *how much, when, and with what* | Preserves the existing split; each new setting has exactly one home |
| Scheduling shape | A generic `schedules` list of `{activity, when, then}` entries replacing `digest_schedule` | One mechanism for every recurring activity; a single-purpose key would multiply |
| Who fires a schedule | The host (Claude Code routine, cron + headless CLI, n8n), never the agent | The agent is markdown and cannot wake itself; the config is the single declaration the host reads |
| Local vs. B2B | One ICP template; the interview asks which the operator sells to and offers matching examples | A separate "mode" file would fork the rubric and double maintenance |
| Dedupe without a website | `domain`, then normalized `phone`, then normalized `name + address` | Many local businesses have no domain; domain-only dedupe would drop or collide them |
| Cold calls | `call` becomes an enabled channel; the Approacher drafts a call opener as a `draft` Activity | The operator dials; the agent's no-contact guardrail is unchanged |
| Attio | Deferred to its own spec (Part B) | Mapping eleven contract operations onto Attio's object model is its own design problem |

## Changes

### 1 · Scheduled runs — `context/operating-config.md`

Remove `digest_schedule`. Add:

```yaml
timezone: "America/New_York"
schedules:
  - activity: prospect
    when: "Monday 07:00"
    then: [prepare]
  - activity: digest
    when: "Monday 08:00"
```

- `activity` is one of `prospect`, `prepare`, `approach`, `follow-up`,
  `digest` — the Workflow steps in `AGENT.md` that can run unattended.
  `interview` and the sales-call steps are excluded: both need the
  operator present.
- `when` is a weekday and 24-hour time, or `daily HH:MM`, interpreted
  in `timezone`. For the digest, the reporting window's cadence
  interval is 7 days for a weekday entry and 1 day for a `daily` entry.
- `then` is an optional ordered list of further activities run in the
  same session after `activity` reaches a stop condition.
- The shipped defaults are the two entries above: prospecting then
  research on Monday morning, digest an hour later.

A new section, **Running on a schedule**, states that the host fires
each entry by starting a session with the instruction "Run the
scheduled activity `<activity>` per `context/operating-config.md`",
and gives one example each for a Claude Code routine, a cron entry
invoking a headless CLI, and an n8n schedule trigger. It states that
editing `schedules` without updating the host trigger changes nothing,
and that the digest's reporting window is computed from its
`schedules` entry.

`skills/send-digest/SKILL.md` reads its window from the `digest`
entry in `schedules` instead of `digest_schedule`.
`skills/interview-business/SKILL.md` asks for schedule entries instead
of a digest time.

### 2 · Sourcing tools — `operating-config.md` + `subagents/prospector.md`

Add:

```yaml
prospecting_sources: [apify_google_maps, apify_site_scraper, web_search]
```

Allowed values: `apify_google_maps` (local-business listings: name,
address, phone, website, rating, review count), `apify_site_scraper`
(company site and social pages), `web_search`, `apollo` (stubbed —
listing it is an error the Prospector reports rather than a source it
uses). The Prospector's **Tools allowed** names only sources listed
here; a source absent from the list is never used. Apify sources still
draw on `apify_spend_cap_usd_per_week`.

No new volume key. `leads_per_week` remains the run target. Researching
every new lead is already expressible by setting
`research_quota_per_week` equal to `leads_per_week` and lowering
`research_budget_per_lead_minutes`; the key descriptions say so.

### 3 · Geography by radius — `context/icp.md` + `skills/score-lead/SKILL.md`

Geography gains an optional **Service area** block:

```yaml
service_area:
  center: "[street address or city]"
  radius: 25
  unit: km        # km | mi
```

When `service_area` is set, it defines the primary market: the
Geography criterion scores 100 for a lead whose address falls inside
the radius, 50 for a lead in a named secondary market, 0 otherwise.
When it is unset, Geography scores against the region lists exactly
as today. Distance is measured from the lead's sourced address; a lead
with no sourced address scores 0 on Geography and is marked
`unverified` in its breakdown — never estimated.

### 4 · Local-business-ready ICP — `icp.md` + `interview-business`

- The interview opens the ICP round by asking whether the operator
  sells to companies or to local businesses, and offers examples from
  the matching set. The answer is recorded in `icp.md` as
  `target_type: company | local_business`, which only selects examples
  — every rubric rule applies identically.
- Firmographics names a **size measure** chosen by the operator —
  headcount, revenue, locations, or review count — and the Company size
  criterion scores against bands in that measure.
- Buying-trigger examples for local businesses: new opening or new
  location, hiring, no website or an outdated one, a recent ownership
  change, a surge or drop in reviews.
- Research `type` gains `listing` (directory or map-listing facts such
  as rating and review count) and `web_presence` (website existence
  and quality), so local signals can be logged with a source URL like
  any other finding.

### 5 · Contact fields and dedupe — `context/crm-contract.md` + `context/crm-airtable-adapter.md`

- `create_lead` adds optional `address`, `phone`, `email` (the
  business's general inbox, not a person). `domain` becomes optional.
- Dedupe order: an existing lead with the same `domain`; else the same
  normalized `phone` (digits only, with country code); else the same
  normalized `company + address` (lowercased, punctuation and suite
  numbers stripped). A match returns the existing `lead_id` and writes
  nothing, as today.
- `create_lead` rejects a call carrying none of `domain`, `phone`, or
  `address` — a lead with no dedupe key cannot be kept unique.
- `upsert_contact` adds optional `phone`. A business owner is written
  as a Contact with `role: decision-maker` and the title the source
  gives (`Owner` when the source says so).
- The Airtable adapter adds `Address`, `Phone`, `Email` to Leads,
  `Phone` to Contacts, and `listing`, `web_presence` to Research
  `Type`.
- The no-fabrication rule is unchanged and restated for the new
  fields: an address, phone, or email that cannot be sourced is left
  empty. A pattern-guessed email is never written.

### 6 · Cold-call channel

- `enabled_channels` may include `call`. The Approacher may choose
  `call` only for a lead with a sourced phone number, on the lead or on
  its chosen Contact.
- New skill `skills/write-call-opener/SKILL.md` and template
  `templates/cold-call-opener.md`: a short opener (who, why this
  business, the sourced hook, one question), the likely gatekeeper
  line, and a voicemail version. It is logged via `log_activity` with
  `channel: call`, `direction: outbound`, `status: draft`, exactly like
  an email draft.
- The operator places the call. Marking the Activity `sent` and logging
  the outcome remain operator actions; the Follow-up contract reads the
  outcome as it does for any other channel.
- A call counts as one touch toward `max_touches`.
- The digest's **Awaiting approval** section lists a `call` draft
  like any other draft and adds the number to dial — the draft's
  Contact `phone` when present, otherwise the lead's `phone`. No new
  digest section: `send-digest` renders six fixed sections, and a
  call opener awaiting the operator is exactly an outbound draft
  awaiting approval.
- The voicemail's callback number comes from a new
  `operating-config.md` key, `callback_phone`, filled in by the
  interview when `call` is enabled. When it is unset, the voicemail
  omits the number rather than inventing one.

### 7 · Consistency

- `AGENT.md`: Inputs list the new keys; Skills table adds
  `write-call-opener`; the Workflow notes that scheduled activities are
  fired by the host per `schedules`.
- `evals/cases.md` adds cases for radius scoring (inside, outside, no
  address), dedupe without a domain (phone match, name+address match,
  no key rejected), a `call` draft for a lead with and without a phone,
  a source not in `prospecting_sources` being refused, and a
  `schedules` entry with `then`.
- The 2026-09-01 design spec gains a pointer to this amendment.
- `tests/run-all.sh` passes.

## Out of scope

- **Part B — Attio adapter.** Its own spec: map the contract onto
  Attio companies, people, notes, and list-based stages, and add a
  `crm_adapter` key.
- Any automated dialing, SMS, or voicemail drop. The agent drafts;
  the operator calls.
- The operator's own ICP, radius, and schedule values — those are
  filled into an installed copy, not the library.
