# CRM contract

Provider-neutral contract for the sales-partner agent's data layer. Every
sub-agent (Prospector, Preparer, Approacher) and skill reads and writes
the CRM only through the eleven operations
below. No sub-agent talks to a provider's API directly, and no sub-agent
invokes another sub-agent directly — **`update_stage` is the only
handoff mechanism between sub-agents.** A sub-agent's job is done when it
calls `update_stage`; the next sub-agent picks the lead up by querying
for its trigger condition — a stage (`query_by_stage`) or a stage plus a
score threshold (`query_by_score`) — never by direct invocation.

The concrete mapping onto a provider — tables, fields, views — lives in
each tool (`tools/<provider>/usage.md`). This document defines
behavior only; it names no Airtable table or field.

## Operations

| Operation | Arguments | Returns | On failure |
|---|---|---|---|
| `create_lead` | `company, location, industry, size, source, source_url`, plus optional `domain, address, phone, email, score, score_breakdown` | `lead_id`, on a record created at `Stage = New` with `Stage Changed At` stamped at creation | A lead matching an existing one by the dedupe order (domain, then phone, then company + address) returns the existing `lead_id` and writes nothing; rejects a call with none of `domain`, `phone`, or `address` |
| `get_lead` | `lead_id` | full lead record with linked Contacts, Research, Activities | Missing id is an error, not an empty record |
| `update_stage` | `lead_id, stage, reason` | updated lead, with `stage_changed_at` set to the moment of this call | Rejects any stage outside the enumerated list |
| `update_lead` | `lead_id, fields` | updated lead | Rejects any attempt to write `stage` through this operation — stage changes go only through `update_stage`. May set `Do Not Contact` to true; rejects any attempt to clear it once true |
| `log_activity` | `lead_id, contact_id, channel, direction, summary, draft_body, status, outcome` | `activity_id` of the newly created row | Create-only — takes no `activity_id` and never touches an existing row. Accepts only `status: "draft"`; rejects `sent` and `voided` outright and unconditionally. The agent rejects `direction: "outbound"` for a lead whose `Do Not Contact` is true — an instruction the guard does not enforce |
| `update_activity` | `activity_id, status, outcome` | updated activity | Accepts only `status: "voided"` — rejects `draft` and `sent` outright and unconditionally; never changes the draft's body |
| `log_research` | `lead_id, type, summary, source_url, date, hook` | `research_id` | Rejects a write with an empty `source_url` or an empty `hook` |
| `upsert_contact` | `lead_id, name, title, email, phone, linkedin_url, role, verified, notes` | `contact_id` | Matches an existing Contact on `email` when present, otherwise on `name` plus `title`, and updates it rather than creating a duplicate; rejects a `role` outside decision-maker / influencer / gatekeeper |
| `query_by_stage` | `stage, limit, next_action_due_before, idle_days` | list of leads | Empty list is a valid result; rejects a call where `stage` is omitted and neither `next_action_due_before` nor `idle_days` is given |
| `query_by_score` | `min_score, stage, limit` | list of leads ordered by score descending | Empty list is a valid result |
| `query_activities` | `status, direction, channel, since, until, limit` | list of activities, each with its linked Lead | Rejects a `status` outside draft / sent / voided; `direction` is optional and, when given, must be `outbound` or `inbound`; empty list is a valid result |

### Notes on individual operations

- **`create_lead`** dedupes in a fixed order. An existing lead with the
  same `domain` is a match; failing that, the same normalized `phone`
  (E.164, below); failing that, the same normalized `company + address`
  (lowercased, punctuation and suite numbers stripped).

  A phone is normalized to E.164: `+` and digits, nothing else. A
  number written without a country code takes the country of the
  lead's sourced address; failing that, the country of
  `service_area.center` in `icp.md`; failing both, it is compared as
  written, digits only, and is never given a guessed country code.

  On a match the call returns that lead's existing `lead_id` and
  writes no new record — it never errors on a duplicate and never
  creates a second row for the same business. This is what lets the
  Prospector call `create_lead` unconditionally on every raw find
  without checking for an existing lead first. `domain` is optional
  because many local businesses have no website; a call carrying
  none of `domain`, `phone`, or `address` is **rejected**, since a
  lead with no dedupe key could never be kept unique.

  `address`, `phone`, and `email` are optional and hold only sourced
  values: `email` is the business's general inbox (an `info@` address
  from its site or listing), never a person's address and never a
  pattern guess. A value that cannot be sourced is left empty.

  **Every lead it creates starts at `Stage = New`.** `create_lead`
  takes no `stage` argument because there is nothing to choose: it
  writes `New` on the record it creates, and stamps `stage_changed_at`
  at that same moment, so a lead has a valid stage and a valid stage
  timestamp from the instant it exists. This is what makes
  `query_by_stage("New")` a meaningful read — a caller doing its own
  dedupe pass over freshly created leads finds them there rather than
  finding nothing. Creation is the one place a stage is written outside
  `update_stage`; **`update_stage` remains the only operation that
  *changes* a lead's stage, and the only writer of `stage_changed_at`
  after creation.**

  `score` and `score_breakdown` are **optional**. A lead matched
  against a hard disqualifier is created and moved to `Disqualified`
  without ever being scored (`evals/cases.md`, Case 1; `score-lead`
  step 2), so a call that omits both is valid and leaves both fields
  empty — omitting them is not an error, and `create_lead` never
  invents a placeholder score to fill them.
- **`get_lead`** always resolves the full record graph: the lead plus
  its linked Contacts, Research, and Activities. A `lead_id` that does
  not exist is an error, not an empty or partial record — callers must
  not treat "not found" as "no data yet."
- **`update_stage`** is the only handoff mechanism between sub-agents
  (see below). It validates `stage` against the eleven-value status list and
  rejects anything else; it does not accept free-text stages. Every
  call also sets `stage_changed_at` (`Stage Changed At` in the Airtable
  tool) to the moment of the transition, as part of the same write —
  not a second call, not an optional argument. **After creation, no
  other operation ever writes `stage_changed_at`** — `create_lead`
  stamps it once on the record it creates, and from then on only
  `update_stage` touches it. This is what makes the field
  trustworthy as "when did this lead's stage actually change": because
  `update_lead` writes every other lead-level field routinely (`Score`,
  `Next Action`, `Do Not Contact`, and so on) without touching stage at
  all, a record's generic last-modified time would be set by any of
  those unrelated writes too — `stage_changed_at` moves only when
  `update_stage` runs, and never otherwise.
- **`update_lead`** writes every non-stage field on a lead — `Score`,
  `Score Breakdown`, `Do Not Contact`, `Next Action`, `Next Action Due`,
  and any other lead-level field outside the stage itself. It **rejects
  any attempt to write `stage`** through this operation, and it never
  writes `stage_changed_at` either — both belong to `update_stage`
  alone. Keeping the two separate is what lets `update_stage` validate
  every stage write against the eleven-value status list and remain the sole
  handoff mechanism between sub-agents, and what lets
  `stage_changed_at` be read elsewhere (the `send-digest` skill's
  Movement section) as an unambiguous transition timestamp rather than
  a general-purpose "record touched" timestamp — a combined operation
  would let a stage change slip through unvalidated and untimestamped
  alongside an ordinary field edit.

  **`Do Not Contact` is one-way.** `update_lead` may *set* it to true,
  and that is the only direction it moves: a call that would clear it —
  writing `false` on a lead whose flag is already true, by any argument
  shape — is **rejected outright**. Once true, permanently true, for
  every caller and every sequence of calls. No other operation in this
  contract writes the field at all, so there is no second path back.
  This is deliberate and it is the point: an opt-out that an agent can
  undo is not an opt-out, and the one guardrail in this system carrying
  legal weight should not rest on an agent choosing not to reverse it.
- **`log_activity`** is **create-only**: it takes no `activity_id`, it
  never reads or touches an existing Activity row, and every call
  produces a brand-new row, returning that new row's `activity_id`.
  The `status` it accepts is hard-restricted to `"draft"` — a call
  passing `sent` or `voided` is **rejected outright and
  unconditionally**. There is no "current status" for a create-only
  operation to check against; the restriction applies to every call,
  every time, with no conditional path through it. Every draft this
  operation produces sits on a lead at `Approach Drafted`, where the
  operator reviews the whole plan (each tool's **Review** view). Nothing
  goes out until the operator moves the lead to `Ready to Send`, and no
  operation this contract exposes to an agent can write that stage — see
  the Approval invariant below — not because agents are instructed to
  wait.

  `log_activity` carries a second rule alongside its draft-only one,
  but **it is an instruction, not a mechanism**: the agent must refuse
  to create an Activity with `direction: "outbound"` for a lead whose
  `Do Not Contact` is true. The guard checks one call at a time and
  cannot see the lead's flag, so it does not enforce this. The rule is
  held by the agent's instructions (`AGENT.md`), the digest's check
  that flags any outbound draft on a Do Not Contact lead, and the
  Do Not Contact column in the operator's approval view. What the guard
  does enforce is `dnc_one_way`: the flag can never be cleared. Inbound
  Activities are unaffected — a reply or a debrief on an opted-out lead
  is still recordable history.
- **`update_activity`** is the only operation that can change an
  existing Activity after `log_activity` created it. It takes the
  `activity_id` `log_activity` returned and writes `status` and
  `outcome` on that row; the only `status` value it accepts is
  `"voided"` — a call passing `draft` or `sent` is **rejected outright
  and unconditionally**. `sent` (the touch went out) is written by the
  operator or the owner's automation in the CRM, never by the agent. It
  never changes the draft's body: what the operator approved is what
  goes out. `log_activity` and `update_activity` are disjoint by
  design: one only ever creates a new row (and only at `draft`), the
  other only ever voids an existing one. Both `sent` and `voided` are
  dead ends — an Activity never moves again after either. This is the
  operation the opt-out instruction (Approval invariant, **Opt-outs**)
  calls to void every pending draft Activity for a lead.
- **`log_research`** creates one Research row linked to the lead. It
  **rejects a write with an empty `source_url` or an empty `hook`.** A
  Research row without a source is an unverifiable claim; one without a
  hook is a research dump the outreach phase cannot use — both are
  exactly the failure modes the Preparer's guardrails prohibit, so this
  operation is where they are enforced, not merely stated. `type` is one
  of news, funding, social, event, hire, listing, web_presence; anything
  else is rejected. `listing` holds map- or directory-listing facts
  (rating, review count, hours); `web_presence` holds whether a website
  exists and its visible state.
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
  written into `email`. `phone` is optional and holds only a sourced
  number — a business's main line belongs on the lead, a person's
  direct line here. A business owner is written with
  `role: decision-maker` and the title the source gives.
- **`query_by_stage`** and **`query_by_score`** are read operations used
  by sub-agents to find their own work (e.g., a contract queries
  `stage: Scored`). An empty list is a valid, non-error result — it
  means there is currently no work at that stage or score, not that the
  query failed.
- **`query_by_stage`**'s base behavior is unchanged by its two optional
  filters: called with just `stage` (and optionally `limit`), it returns
  exactly what it always returned — every lead at that stage, `stage`
  required, rejecting anything outside the eleven-value status list. Passing
  either `next_action_due_before` (a date) or `idle_days` (an integer)
  changes what the call means: `stage` becomes optional, and the result
  is filtered to leads whose `Next Action Due` is on or before
  `next_action_due_before`, or whose idle age is greater than
  `idle_days` days, respectively — across
  every stage when `stage` is omitted, or narrowed to one stage when
  both are given together. Omitting `stage` while also omitting both
  filters is rejected rather than silently returning every lead in the
  CRM; at least one of the three must be present. This is what lets
  `send-digest` ask "which leads are due today" or "which leads have
  gone stale" without a table scan across all eleven statuses one at a
  time, and it is why the operation grew these filters rather than the
  digest reconstructing them from `query_by_stage`'s original one-stage
  form.

  **Idle age** is defined exactly, so the same data always gives the
  same answer: idle age = now − `max(last Activity date, Stage Changed
  At)`, where "now" is the moment of the call. A lead with no Activity
  at all is measured from its `Stage Changed At` alone — it is neither
  skipped nor treated as infinitely idle. `idle_days` keeps a lead only
  when its idle age is greater than `idle_days` days.
- **`query_activities`** is the read counterpart to `log_activity` and
  `update_activity`: it finds Activities directly, by `status`,
  optionally `direction`, optionally `channel` (email, linkedin, call,
  other), and optionally a `[since, until]` window on `Date` — the read this contract had no operation for until
  `send-digest` needed to find every outbound Activity at
  `status: draft` regardless of which lead it belongs to. `status` is
  required and validated against the three-value `Status` enum
  (`draft`, `sent`, `voided`): `draft` is written by `log_activity`,
  `sent` and `voided` by `update_activity`. `direction`, when
  given, must be `outbound` or `inbound`; omitting it returns
  Activities in either direction. This is what lets a caller separate
  outbound drafts genuinely awaiting an operator decision from inbound
  replies and call debriefs that also land at `status: draft` (every
  Activity `log_activity` creates starts there, regardless of
  direction) but need no approval — `send-digest` filters on both
  `status: draft` and `direction: outbound` for exactly this reason. `since` and `until` are each
  optional, and omitting one leaves that edge of the window unbounded,
  so omitting both returns every Activity at that status regardless of
  `Date`. Every returned Activity carries its linked Lead, so a caller
  does not need a separate `get_lead` call per row just to show which
  company an Activity belongs to.

## Approval invariant

Stated once, plainly, so a future editor sees exactly what they would
be breaking before they break it:

- An agent can create an Activity only at `status: "draft"`, via
  `log_activity` — no other status is accepted, ever.
- An agent can move an existing Activity only to `status: "voided"`,
  via `update_activity`, and never rewrites a draft's body after it was
  created.
- An agent never writes the stage `Ready to Send`: only the operator
  writes `Ready to Send`, by moving the lead once its drafts are right.
  That move approves the lead's first touch; nothing is approved draft
  by draft.
- **Therefore no sequence of operations approves a lead: only the
  operator's move to `Ready to Send` does.** What happens next — an
  email sequence, a LinkedIn message, a call — is the operator's, or the
  owner's automation, another system or agent acting on that status.
  The agent sends nothing and never acts on a lead at `Ready to Send`
  or later.

The opt-out has one mechanism and one instruction:

- **Mechanism (`dnc_one_way`).** `update_lead` may set `Do Not Contact`
  to true and can never clear it — a write that would move the flag
  from true back to false is rejected, and no other operation writes
  the field at all.
- **Instruction, not a mechanism.** `log_activity` must not create an
  Activity with `direction: "outbound"` for a lead whose
  `Do Not Contact` is true. The guard cannot see the lead's flag when
  it checks a single call, so this is not enforced, and re-creating a
  lead can also get around it. It is held by the agent's instructions,
  the digest check (outbound drafts on Do Not Contact leads, and
  duplicate leads) and the Do Not Contact column in the operator's
  approval view.
- **Opt-outs.** No skill reads replies; the operator or the owner's
  automation logs them as inbound Activities. Whenever the agent reads
  a lead with `get_lead` and finds an inbound Activity recording an
  opt-out (the prospect asked not to be contacted), it sets
  `update_lead(lead_id, {"Do Not Contact": true})` and voids every
  outbound draft Activity on the lead with
  `update_activity(activity_id, "voided", outcome: "opt-out")`, then
  stops working that lead. It leaves the status alone. The owner's
  sending system handles its own suppression list.

Any change that gives an operation a new way to write `Status` on an
Activity — a new argument, a relaxed check, a new operation — must be
checked against this invariant before it ships. If the change would
let any of the eleven operations write the stage `Ready to Send`, or
rewrite a draft after create, the invariant is broken and the guardrail
"nothing goes out without operator approval" (`AGENT.md`) stops being a
mechanism and goes back to being
an unenforced instruction. The same test applies to `dnc_one_way`:
any change that would let an operation clear `Do Not Contact` breaks
that invariant. "Never draft a message toward a lead flagged
`Do Not Contact`" is already an instruction, not a mechanism.

## Invariants

Each tool's `guard.yaml` lists in `covers` the invariants its guard
policy enforces; an invariant it does not list is instruction-only.

- `draft_only` — the agent creates Activities only at `status: draft`,
  the only status it may later write is `voided`, and
  only the operator writes `Ready to Send` (see Approval invariant).
- `dnc_one_way` — `Do Not Contact`, once true, is never cleared.
- `no_delete` — the agent never deletes or merges CRM records.

## Lead status

A lead holds exactly one of these eleven statuses at a time (the lead
is the company). The operation is still `update_stage` and the field `stage`; the
values are the lead's status, verbatim, in order. `update_stage` rejects
any value outside this list:

```
New
Scored
Researched
Approach Drafted
Ready to Send
Contacted
Engaged
Open Deal
Nurture
Customer
Disqualified
```

Statuses describe the lead, not a deal: when a real opportunity exists
(for example a proposal), the operator tracks it on the CRM's own deal
object, with its own stages. The agent writes only `Scored`,
`Researched`, `Approach Drafted` and `Disqualified` (plus `New` on
create); `Ready to Send`, `Contacted`, `Engaged`, `Open Deal`,
`Nurture` and `Customer` are the operator's, or the owner's automation
acting on the operator's approval, and every tool's guard policy
refuses them to the agent.
**The agent's job ends at `Approach Drafted`.** For
`Nurture`, the operator sets the lead's **Revisit On** date; the agent
reads it and leaves the lead alone until then. `Do Not Contact` is a
separate one-way flag, not a status.

## Lead status transitions

Status changes are the only handoff between sub-agents, so this table
is the state machine the `subagents/*.md` contracts code against. A hard
disqualifier in `icp.md`, or an anti-signal found during research, moves
a lead to `Disqualified` from any status the agent works on.

| Status | Enters when | Exits to |
|---|---|---|
| `New` | Prospector creates the lead record from a raw find | Prospector scores it, moving it to `Scored`; a hard disqualifier moves it straight to `Disqualified` |
| `Scored` | Prospector finishes applying the `icp.md` rubric and records the score breakdown | Preparer picks it up once the score clears `research_threshold`, moving it to `Researched` |
| `Researched` | Preparer finishes research, identifies decision-makers, produces hooks, and re-scores | Approacher picks it up once the revised score clears `approach_threshold`, drafting the plan and moving it to `Approach Drafted`; an anti-signal found during research moves it to `Disqualified` instead |
| `Approach Drafted` | Approacher logs the lead's draft Activities (one per enabled channel: the recommended channel's full draft and statements, the others' statements) at `status: draft` | The operator reviews and edits the drafts, voids any they don't want, then approves the lead by moving it to `Ready to Send` — nothing is approved draft by draft |
| `Ready to Send` | The operator moves the lead here once its drafts are right — only the operator writes `Ready to Send` | The owner's automation, another system or agent, or the operator sends the first touch and moves it to `Contacted`; the operator moving it back to `Approach Drafted` cancels. The agent never acts on it |
| `Contacted` | The first touch went out, on any channel (set by the operator or the owner's automation) | A reply moves it to `Engaged` (operator or automation) |
| `Engaged` | The prospect replied | The operator decides: `Open Deal`, `Nurture` or `Customer` |
| `Open Deal` | The operator created a deal for the lead | The operator, from the deal's outcome |
| `Nurture` | The operator parks the lead, with a Revisit On date | The operator; the Prospector leaves it alone until Revisit On |
| `Customer` | The operator won business with the lead | — |
| `Disqualified` | A hard disqualifier in `icp.md`, or an anti-signal found during research | Terminal for the agent |

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
