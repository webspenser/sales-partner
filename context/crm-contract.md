# CRM contract

Provider-neutral contract for the sales-partner agent's data layer. Every
sub-agent (Prospector, Preparer, Approacher, Sales-call-specialist,
Follow-up) reads and writes the CRM only through the nine operations
below. No sub-agent talks to a provider's API directly, and no sub-agent
invokes another sub-agent directly — **`update_stage` is the only
handoff mechanism between sub-agents.** A sub-agent's job is done when it
calls `update_stage`; the next sub-agent picks the lead up by querying
for its trigger condition — a stage (`query_by_stage`) or a stage plus a
score threshold (`query_by_score`) — never by direct invocation.

The concrete mapping onto Airtable — tables, fields, views — lives in
`crm-airtable-adapter.md`. This document defines behavior only; it names
no Airtable table or field.

## Operations

| Operation | Arguments | Returns | On failure |
|---|---|---|---|
| `create_lead` | `company, domain, location, industry, size, source, score, score_breakdown, source_url` | `lead_id` | Duplicate domain returns the existing `lead_id` and writes nothing |
| `get_lead` | `lead_id` | full lead record with linked Contacts, Research, Activities | Missing id is an error, not an empty record |
| `update_stage` | `lead_id, stage, reason` | updated lead | Rejects any stage outside the enumerated list |
| `update_lead` | `lead_id, fields` | updated lead | Rejects any attempt to write `stage` through this operation — stage changes go only through `update_stage` |
| `log_activity` | `lead_id, contact_id, channel, direction, summary, draft_body, status, outcome` | `activity_id` | Rejects `status: sent` unless the record was previously `approved` |
| `log_research` | `lead_id, type, summary, source_url, date, hook` | `research_id` | Rejects a write with an empty `source_url` or an empty `hook` |
| `upsert_contact` | `lead_id, name, title, email, linkedin_url, role, verified, notes` | `contact_id` | Matches an existing Contact on `email` when present, otherwise on `name` plus `title`, and updates it rather than creating a duplicate; rejects a `role` outside decision-maker / influencer / gatekeeper |
| `query_by_stage` | `stage, limit` | list of leads | Empty list is a valid result |
| `query_by_score` | `min_score, stage, limit` | list of leads ordered by score descending | Empty list is a valid result |

### Notes on individual operations

- **`create_lead`** dedupes on `domain`. If a lead with the same domain
  already exists, the call returns that lead's existing `lead_id` and
  writes no new record — it never errors on a duplicate and never
  creates a second row for the same company. This is what lets the
  Prospector call `create_lead` unconditionally on every raw find
  without checking for an existing lead first.
- **`get_lead`** always resolves the full record graph: the lead plus
  its linked Contacts, Research, and Activities. A `lead_id` that does
  not exist is an error, not an empty or partial record — callers must
  not treat "not found" as "no data yet."
- **`update_stage`** is the only handoff mechanism between sub-agents
  (see below). It validates `stage` against the twelve-value enum and
  rejects anything else; it does not accept free-text stages.
- **`update_lead`** writes every non-stage field on a lead — `Score`,
  `Score Breakdown`, `Do Not Contact`, `Next Action`, `Next Action Due`,
  and any other lead-level field outside the stage itself. It **rejects
  any attempt to write `stage`** through this operation; that write
  belongs to `update_stage` alone. Keeping the two separate is what lets
  `update_stage` validate every stage write against the twelve-value
  enum and remain the sole handoff mechanism between sub-agents — a
  combined operation would let a stage change slip through unvalidated
  alongside an ordinary field edit.
- **`log_activity`** is where the operator-approval guardrail is
  enforced, not merely documented. The operation **rejects any call
  with `status: sent` unless the activity record being updated was
  previously `status: approved`.** A sub-agent can log a `draft`
  activity, or advance one from `approved`, but no sub-agent — and no
  automated caller of this contract — can move an activity straight to
  `sent`. Only the operator's approval action can put a record into
  `approved`, and only then does `sent` become a legal write. This is
  the mechanism, not a convention: nothing sends without operator
  approval because the capability to send is withheld until approval
  happens, not because agents are instructed to wait.
- **`log_research`** creates one Research row linked to the lead. It
  **rejects a write with an empty `source_url` or an empty `hook`.** A
  Research row without a source is an unverifiable claim; one without a
  hook is a research dump the outreach phase cannot use — both are
  exactly the failure modes the Preparer's guardrails prohibit, so this
  operation is where they are enforced, not merely stated.
- **`upsert_contact`** creates or updates one Contact row linked to the
  lead. It matches an existing Contact on `email` when one is given,
  and otherwise on `name` plus `title`, and updates that row rather than
  creating a duplicate — this is what lets a caller re-run contact
  discovery after a bounce without producing two records for the same
  person. `verified` defaults to `false` and the operation never sets it
  `true` on its own; only a caller that has actually verified the
  address may pass `true`. `role` is rejected unless it is one of
  decision-maker, influencer, or gatekeeper. `notes` is free text for
  provenance annotations that don't belong in `name`, `title`, or any
  other field — most importantly an unverified pattern-guessed email
  address, recorded as `pattern guess, unverified` rather than ever
  written into `email`.
- **`query_by_stage`** and **`query_by_score`** are read operations used
  by sub-agents to find their own work (e.g., a contract queries
  `stage: Scored`). An empty list is a valid, non-error result — it
  means there is currently no work at that stage or score, not that the
  query failed.

## Stage enum

A lead occupies exactly one of these twelve stages at a time. This is
the enum verbatim, in transition order; `update_stage` rejects any value
outside this list:

```
New
Scored
Researched
Approach Drafted
Contacted
Replied
Call Scheduled
Call Held
Following Up
Won
Lost
Disqualified
```

`Won`, `Lost`, and `Disqualified` are terminal — no operation should
attempt to transition a lead out of them. A hard disqualifier or an
anti-signal found during research can move a lead to `Disqualified` from
any of the other nine stages, not only from the stage where
disqualification is usually checked.

## `update_stage` is the only handoff mechanism

Sub-agents never call one another directly, and no sub-agent contract
names another sub-agent contract. A sub-agent finishes its unit of work
by calling `update_stage(lead_id, stage, reason)`; the next sub-agent in
the pipeline finds that lead by calling `query_by_stage` for the stage it
triggers on, or `query_by_score` for the stage-and-score threshold it
triggers on where its trigger is score-gated (the Preparer and the
Approacher). This is the entire coupling between sub-agents — it is what
lets the pipeline run as five independent triggers on stage or
stage-and-score queries, and also what lets the same pipeline collapse
into sequential inline phases on a host without sub-agent dispatch, with
identical behavior.
