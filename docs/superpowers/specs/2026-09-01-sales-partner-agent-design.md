# Sales Partner Agent — Design

**Date:** 2026-09-01
**Status:** Approved, pending implementation plan
**Implements:** [Portable Agent Specification Format](https://github.com/webspenser/agent-builder/blob/main/docs/superpowers/specs/2026-09-01-portable-agent-spec-design.md)
**Location:** `agent-library/sales-partner/`
**Amended by:** [Generalized Prospecting](./2026-09-24-sales-partner-generalize-prospecting-design.md) — schedules, sourcing, radius, local-business ICP, contact fields, call channel

## Purpose

An agent that acts as a sales partner for a single business: it
interviews the operator to build a durable profile of the business and
its ideal customer, then runs a five-stage lead pipeline on top of that
profile — prospecting, research, first contact, sales calls, and
follow-up — with a CRM as the system of record and scheduled digests as
the reporting surface.

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Autonomy | Research automatic, all outbound drafts only | Phases 1–2 are read-only and safe unattended; phases 3–5 speak under the operator's name |
| System of record | Neutral CRM contract, Airtable as first adapter | Swapping CRMs later touches one adapter file |
| Tenancy | One business per installed copy | Copying the folder is already the supported operation; no tenancy logic anywhere |
| Data sources | Apify live; web search and Gmail live; Apollo specified but stubbed | Matches credentials actually held |
| LinkedIn | Draft-and-hand-to-human, never automated | LinkedIn's User Agreement prohibits automated scraping and messaging; accounts get restricted |
| Phase 0 | A skill, not a sub-agent | It is an interactive interview with the operator, not delegated work |
| Phase 4 | One sub-agent with three skills | Prep, objections, and live script share one lead's context and run minutes apart |

## Pipeline

```
[0] Interview  → business profile + ICP + operating config
[1] Prospector → find & score leads
[2] Preparer   → research top leads, find decision-makers, produce hooks
[3] Approacher → choose channel, draft first touch
[4] Sales call → prep, value mapping, objections, live script, debrief
[5] Follow-up  → thank-you, open questions, momentum
        ↕
      CRM (system of record) → scheduled digests
```

## Phase 0 — Profile Artifacts

Runs once at install, re-runnable when anything material changes.
Writes three versioned files to `context/`.

| File | Holds | Consumed by |
|---|---|---|
| `business-profile.md` | What the business sells, proof, pricing, differentiators, case studies, disqualifiers | Phases 3, 4, 5 |
| `icp.md` | Target firmographics, geography, roles, buying triggers, **scoring rubric**, **anti-signals** | Phases 1, 2 |
| `operating-config.md` | Volume targets, cadence, enabled channels, digest schedule, tone, sending identity, spend caps | All phases |

The scoring rubric in `icp.md` is weighted criteria summing to 100 plus
hard disqualifiers. The Prospector applies this rubric and records the
per-criterion breakdown; it does not invent scores. Keeping the rubric
in configuration rather than in a prompt means retargeting never risks
breaking how the Prospector operates.

## Lead State Machine

Every lead occupies exactly one stage. Stage transitions are the only
handoff mechanism between sub-agents.

```
New → Scored → Researched → Approach Drafted → Contacted
   → Replied → Call Scheduled → Call Held → Following Up → Won
                                                          ↘ Lost
   (any stage) ↘ Disqualified
```

Sub-agents trigger on stage queries, never on direct invocation of one
another. No contract names another contract. This is what allows the
pipeline to collapse into sequential inline phases on a host without
sub-agent dispatch, with identical behavior.

## CRM

### Neutral contract

Eleven operations: `create_lead`, `get_lead`, `update_stage`,
`update_lead`, `log_activity`, `update_activity`, `log_research`,
`upsert_contact`, `query_by_stage`, `query_by_score`,
`query_activities`. `log_activity` and `update_activity` are disjoint
by design — one create-only, one update-only — and between them never
reach `approved` or `sent`. `log_activity` takes no `activity_id`,
never touches an existing row, and accepts only `status: "draft"` on
the row it creates, rejecting `approved`, `sent`, and `voided`
outright and unconditionally. `update_activity` is the only operation
that can change an Activity `log_activity` already created, and it
exists for exactly one purpose — voiding: it writes `status` and
`outcome` by `activity_id`, but the only `status` it accepts is
`"voided"` — `draft`, `approved`, and `sent` are all rejected outright
and unconditionally, regardless of the record's current status. This
is what lets a pending `draft` Activity be moved to the fourth
`status` value, `voided`, when an opt-out arrives, with no way back
toward being sent — see the Follow-up contract below. `approved` and
`sent` are reachable only by the operator acting directly in Airtable,
outside every one of these eleven operations.
`update_stage` writes only the `stage` field, validated against the
twelve-value enum, and stamps `stage_changed_at` on every transition —
the one field only this operation ever writes; `update_lead` writes
every other lead-level field (`score`, `score breakdown`,
`do-not-contact`, `next action`, `next action due`, and so on) and
rejects any attempt to write `stage` or `stage_changed_at` through it.
The split is what keeps `update_stage` the sole handoff mechanism
between sub-agents. `log_activity`, `log_research`, and `upsert_contact`
are the child-record writes, one per linked table: `log_activity`
creates an Activity at `status: draft` and nothing else, `log_research`
creates a Research row and rejects an empty source URL or an empty
hook, and `upsert_contact` creates or updates a Contact — matched on
email, or on name plus title — so a second contact-discovery pass after
a bounce never duplicates a person.
`query_by_stage` takes two optional filters, `next_action_due_before`
and `idle_days`, that make `stage` itself optional when either is
given — added so a caller can find due-today or stalled leads across
every stage in one call, rather than looping `query_by_stage` once per
stage. `query_activities` is the read counterpart to `log_activity`:
it finds Activities by `status`, optionally `direction`, and an
optional `[since, until]` window, added because no existing operation
could answer "every outbound Activity at `status: draft`" without a
`lead_id` in hand — exactly what `send-digest`'s approval queue needs.
The `direction` filter exists because `log_activity` creates every
Activity at `status: draft` regardless of direction, so an inbound
reply or a call debrief lands at `draft` exactly like an outbound
approach message does — `direction: "outbound"` is what keeps the
approval queue to messages actually awaiting a send decision.

### Airtable adapter — four tables

- **Leads** — company, domain, location, industry, size, source, score,
  score breakdown, stage, stage changed at (set only by `update_stage`,
  on every transition — never touched by `update_lead`), next action,
  next action due, do-not-contact
- **Contacts** — name, title, email, LinkedIn URL, role
  (decision-maker / influencer / gatekeeper), verified, notes
  (provenance annotations, e.g. an unverified pattern-guessed email);
  linked to Leads
- **Research** — type (news / funding / social / event / hire), summary,
  source URL, date, **hook**; linked to Leads
- **Activities** — channel, direction, date, summary, draft body,
  status (created at `draft` only, via `log_activity`; moved only to
  the dead-end `voided`, via `update_activity`; `approved` and `sent`
  reachable only by the operator directly in Airtable, never by any of
  the eleven operations), outcome; linked to Leads and Contacts

Drafts are Activities with `status: draft` rather than a separate
table. The approval queue is then a single Airtable view, which serves
as the operator's entire review interface.

## Sub-Agent Contracts

Each is one file in `subagents/`, following the framework's eight-section
role contract schema.

### 1 · `prospector.md`

- **Purpose** — turn the ICP into scored, deduplicated lead records
- **Trigger** — scheduled run, or leads in `New` + `Scored` below the
  target in `operating-config.md`
- **Inputs** — `icp.md`, `operating-config.md`, existing CRM domains
- **Outputs** — N Leads at `Scored`, each with score, per-criterion
  breakdown, and source URL
- **Tools** — Apify actors, web search, CRM `create_lead` /
  `query_by_stage`; Apollo adapter (stubbed)
- **Stop** — target count reached, source exhausted, or Apify spend cap hit
- **Handoff** — Preparer, via `stage = Scored`
- **Inline fallback** — runs as phase 1 in sequence

Guardrails: deduplicate on domain before writing; never fabricate an
email address; hard disqualifiers short-circuit to `Disqualified`;
every lead carries provenance.

### 2 · `preparer.md`

- **Purpose** — deep-research top leads, identify decision-makers,
  produce hooks
- **Trigger** — `stage = Scored` and `score >= research_threshold`,
  capped at the research quota
- **Inputs** — lead record, `business-profile.md`, `icp.md`
- **Outputs** — Research rows each carrying a hook, Contacts rows with
  role tags, `stage = Researched`
- **Tools** — web search, Apify site and social scrapers, CRM
- **Stop** — two or more usable hooks found, or per-lead research budget spent
- **Re-score** — before handoff, re-run `score-lead`. Research resolves the
  two rubric criteria worth 45 points that prospecting can only guess at:
  buying trigger present, and decision-maker reachable.
- **Handoff** — Approacher
- **Inline fallback** — runs as phase 2 in sequence

Guardrails: nothing behind a login; a source URL is required on every
claim; inferences are marked unverified; an anti-signal moves the lead
to `Disqualified` rather than passing it on.

### 3 · `approacher.md`

- **Purpose** — choose the opening channel and draft the first touch
- **Trigger** — `stage = Researched` and `score >= approach_threshold`,
  using the score the Preparer revised after research
- **Inputs** — lead, Contacts, Research hooks, `business-profile.md`,
  tone and sending identity from config
- **Outputs** — channel recommendation with rationale, drafted message
  as an Activity with `status: draft`, `stage = Approach Drafted`
- **Tools** — CRM, `templates/`, `samples/`. **No send tool.**
- **Stop** — draft logged
- **Handoff** — operator approves, message sends, `stage = Contacted`
- **Inline fallback** — runs as phase 3 in sequence

Guardrails: LinkedIn output is always copy-paste for a human; email may
send through Gmail only after approval flips the Activity status; one
opening touch per lead.

### 4 · `sales-call-specialist.md`

- **Purpose** — prepare the call, map the offer to the prospect's
  situation, arm the operator for objections, debrief afterward
- **Trigger** — `stage = Call Scheduled` for prep; on request during a
  call; `stage = Call Held` for debrief
- **Inputs** — full lead history, all Research, `business-profile.md`
- **Outputs** — call brief, objection matrix, talk track; after the
  call, notes, outcome, and next action
- **Skills** — `prepare-sales-call`, `handle-objections`,
  `run-live-call-script`
- **Tools** — CRM, `context/`, web search for day-of news
- **Stop** — brief delivered, or debrief logged
- **Handoff** — Follow-up
- **Inline fallback** — runs as phase 4 in sequence

Guardrails: every claim must trace to `business-profile.md`; no
invented capabilities, metrics, or references.

### 5 · `follow-up.md`

- **Purpose** — maintain momentum after a meaningful interaction
- **Trigger** — an Activity logged with an outcome, or a lead idle past
  the cadence in config
- **Inputs** — last activity, questions asked, promises made
- **Outputs** — drafted follow-up Activity with `status: draft`, next
  action and due date set on the lead
- **Tools** — CRM (including `update_activity`, restricted to voiding
  only), Gmail draft
- **Stop** — draft created and next action set
- **Handoff** — back to the lead's stage, or `Lost` once the touch
  limit is exhausted
- **Inline fallback** — runs as phase 5 in sequence

Guardrails: never exceed the configured touch count; any reply
containing an opt-out sets `do-not-contact` permanently and calls
`update_activity` to void every pending (`draft` or `approved`) draft
for the lead; every question actually asked is answered before
anything new is introduced.

## Skills

| Skill | Trigger | Used by |
|---|---|---|
| `interview-business` | Install, or profile change | Phase 0 |
| `score-lead` | A lead needs scoring or re-scoring | 1 |
| `research-company` | Lead enters the research quota | 2 |
| `find-decision-makers` | Company known, contacts unknown | 2, 3 |
| `write-cold-email` | Email chosen as channel | 3, 5 |
| `write-linkedin-touch` | LinkedIn chosen as channel | 3, 5 |
| `prepare-sales-call` | Call scheduled | 4 |
| `handle-objections` | Objection surfaces, before or during a call | 4 |
| `run-live-call-script` | Call in progress | 4 |
| `write-follow-up` | Meaningful interaction, or idle past cadence | 5 |
| `send-digest` | Digest schedule from config | Orchestrator |

Anything used once by one sub-agent stays inline in that contract.
`score-lead` and `find-decision-makers` are separate files because both
get re-run: leads are re-scored when the ICP changes, and the Approacher
frequently needs a second contact after a bounce. `write-cold-email`
and `write-linkedin-touch` stay separate because a 300-character
connection note and a cold email are different crafts with different
failure modes.

## Templates and Samples

```
templates/
  cold-email.md            linkedin-connection-note.md
  linkedin-dm.md           call-brief.md
  objection-matrix.md      follow-up-email.md
  research-summary.md      digest.md

samples/
  README.md    # replace these after the Phase 0 interview
```

`_template/` ships generic samples only. Real samples are written from
the operator's own business after the interview, because samples teach
voice, and shipped-generic voice is precisely the templated output the
agent exists to avoid producing.

## Digest

A skill plus a template, fired on the schedule in `operating-config.md`
and delivered by Gmail. SMS is defined as a delivery adapter and stubbed
until a Twilio credential exists.

Sections, in order:

1. **Awaiting approval** — count and links
2. **Next actions due today**
3. New leads scored — top five, each with a one-line rationale
4. Stalled — past cadence with no activity
5. Movement — stage changes, wins, losses, disqualifications since the
   previous digest
6. Spend — Apify usage against the cap

Approvals lead because that section is a queue; every other section is
reporting, and reporting placed above a queue trains the reader to
scroll past it.

## Capability Tiers

Per the framework's degradation ladder:

- **Tier 1 (full)** — five sub-agents dispatched, skills autoloaded
- **Tier 2 (reduced)** — the same five contracts executed inline as
  sequential phases; skills loaded by name
- **Tier 3 (minimum)** — `AGENT.md` alone, one phase at a time,
  skills pasted in

No step on the critical path requires tier 1. Sub-agent dispatch buys
parallelism and context isolation, never correctness.

## Testing

`evals/cases.md` holds thirteen cases, all negative — what the agent
must refrain from doing; cases 9–13 come from the Generalized
Prospecting amendment. Positive outcomes are not testable without
judgment; refusals are binary and catch the failures that cost money
or reputation.

1. A lead matching a hard disqualifier in `icp.md` is marked
   `Disqualified` and never written as `Scored`
2. A lead scoring below `research_threshold` is not researched
3. A company with no findable news or socials produces "no hooks found"
   rather than an invented hook
4. LinkedIn as chosen channel produces copy-paste text and calls no send tool
5. A reply containing an opt-out sets `do-not-contact` and voids pending drafts via `update_activity`
6. Reaching the configured touch limit marks the lead `Lost` instead of
   drafting again
7. An offer claim absent from `business-profile.md` is omitted, not inferred
8. A duplicate domain is skipped rather than created a second time

Cases run under Claude Code (tier 1) and under at least one tier 2 host
to confirm graceful degradation.

## Out of Scope

- Automated LinkedIn actions of any kind
- Autonomous sending of any outbound message
- Multi-tenant operation; a second business is a second copy of the folder
- Apollo integration beyond a stubbed source adapter
- SMS digests beyond a stubbed delivery adapter
- Contract, invoicing, or post-sale delivery workflow
