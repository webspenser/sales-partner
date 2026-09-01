# CRM contract

Provider-neutral contract for the sales-partner agent's data layer. Every
sub-agent (Prospector, Preparer, Approacher, Sales-call-specialist,
Follow-up) reads and writes the CRM only through the six operations
below. No sub-agent talks to a provider's API directly, and no sub-agent
invokes another sub-agent directly — **`update_stage` is the only
handoff mechanism between sub-agents.** A sub-agent's job is done when it
calls `update_stage`; the next sub-agent picks the lead up by querying
for its trigger stage (`query_by_stage`), never by direct invocation.

The concrete mapping onto Airtable — tables, fields, views — lives in
`crm-airtable-adapter.md`. This document defines behavior only; it names
no Airtable table or field.

## Operations

| Operation | Arguments | Returns | On failure |
|---|---|---|---|
| `create_lead` | `company, domain, location, industry, size, source, score, score_breakdown, source_url` | `lead_id` | Duplicate domain returns the existing `lead_id` and writes nothing |
| `get_lead` | `lead_id` | full lead record with linked Contacts, Research, Activities | Missing id is an error, not an empty record |
| `update_stage` | `lead_id, stage, reason` | updated lead | Rejects any stage outside the enumerated list |
| `log_activity` | `lead_id, contact_id, channel, direction, summary, draft_body, status, outcome` | `activity_id` | Rejects `status: sent` unless the record was previously `approved` |
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
- **`query_by_stage`** and **`query_by_score`** are read operations used
  by sub-agents to find their own work (e.g., the Preparer queries
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
triggers on. This is the entire coupling between sub-agents — it is what
lets the pipeline run as five independent triggers on stage queries, and
also what lets the same pipeline collapse into sequential inline phases
on a host without sub-agent dispatch, with identical behavior.
