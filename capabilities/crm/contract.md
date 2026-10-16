# CRM contract

Provider-neutral contract for the sales-partner agent's data layer. Every
sub-agent (Prospector, Preparer, Approacher) and skill reads and writes
the CRM only through the nine operations
below. No sub-agent talks to a provider's API directly, and no sub-agent
invokes another sub-agent directly — **`update_stage` is the only
handoff mechanism between sub-agents.** A sub-agent's job is done when it
calls `update_stage`; the next sub-agent picks the lead up by querying
for its trigger condition — a stage (`query_by_stage`) or a stage plus a
Fit or Approach score threshold (`query_by_score`) — never by direct
invocation.

The concrete mapping onto a provider — tables, fields, views — lives in
each tool (`tools/<provider>/usage.md`). This document defines
behavior only; it names no provider table or field.

## Operations

| Operation | Arguments | Returns | On failure |
|---|---|---|---|
| `create_lead` | `company, location, industry, size, source, source_url`, plus optional `domain, address, phone, email, fit_score, fit_breakdown` and the company profile fields | `lead_id`, on a record created at `Stage = New` with `Stage Changed At` stamped at creation | A lead matching an existing one by the dedupe order (domain, then phone, then company + address, each where the tool stores it) returns the existing `lead_id` and writes nothing; rejects a call with none of `domain`, `phone`, or `address` |
| `get_lead` | `lead_id` | full lead record with linked Contacts, its research record and its draft records (one per channel), the newest section of each identified | Missing id is an error, not an empty record |
| `update_stage` | `lead_id, stage, reason` | updated lead, with `stage_changed_at` set to the moment of this call | Rejects any stage outside the enumerated list |
| `update_lead` | `lead_id, fields` | updated lead | Rejects any attempt to write `stage` through this operation — stage changes go only through `update_stage`. May set `Do Not Contact` to true; rejects any attempt to clear it once true |
| `log_draft` | `lead_id, contact_id, channel, body` | the draft record the section was added to | Create or append only: adds one dated section to the lead's draft record for `channel` (`email`, `linkedin` or `call`), creating the record when it has none; never edits, replaces or removes earlier text. Rejects any other `channel`. The agent drafts nothing for a lead whose `Do Not Contact` is true — an instruction the guard does not enforce |
| `log_research` | `lead_id, findings[]` (each `type, summary, source_url, date, hook`) | the research record the section was added to | Adds one dated section holding the whole run's findings; rejects the call when any finding has an empty `source_url` or `hook`, or a `type` outside the seven |
| `upsert_contact` | `lead_id, name, title, email, phone, linkedin_url, role, verified, notes` | `contact_id` | Matches an existing Contact on `email` when present, otherwise on `name` plus `title`, and updates it rather than creating a duplicate; rejects a `role` outside decision-maker / influencer / gatekeeper |
| `query_by_stage` | `stage, limit, next_action_due_before, idle_days` | list of leads | Empty list is a valid result; rejects a call where `stage` is omitted and neither `next_action_due_before` nor `idle_days` is given |
| `query_by_score` | `score, min_score, stage, limit` | list of leads ordered by that score descending | Rejects a `score` other than `fit` or `approach`; empty list is a valid result |

### Scores

A lead carries two scores, one per pipeline gate, each a number from 0
to 100 with its per-criterion breakdown as text (`skills/score-lead`):

| Field | Written by | Read by |
|---|---|---|
| `Fit Score`, `Fit Breakdown` | the Prospector, on `create_lead` (`fit_score`, `fit_breakdown`), or on a re-found `New` lead with `update_lead` | the Preparer's trigger, against `research_threshold` |
| `Approach Score`, `Approach Breakdown` | the Preparer, with `update_lead`, after research | the Approacher's trigger, against `approach_threshold` |

Each score holds the exact value the rubric's arithmetic produces (for
example 67.5), never rounded. `query_by_score(score: fit)` filters and
sorts on `Fit Score`, `query_by_score(score: approach)` on `Approach
Score`; a lead with no value for that score is never returned.

### Company profile fields

`description, company_linkedin_url, facebook_url, instagram_url`, plus
`address`: the basics the operator sees on the company itself.
`create_lead` and `update_lead` accept them, each optional. Each value
is sourced: `description` is one line on what the business does and
where, written from the listing or the research; each URL is a page the
research found for this business (never a guess from its name). A tool
writes a profile field only when the CRM's own field is empty: it never
overwrites what the CRM's enrichment or the operator already set, and
it never clears one. A tool with no home for a profile field skips it
and says nothing; that is not a failure.

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
  values: `phone` is the business's main line and `email` its general
  inbox (an `info@` address from its site or listing), never a person's
  address and never a pattern guess. A value that cannot be sourced is
  left empty. They are stored where the tool has a home for them;
  a tool with no home for them skips them, and its dedupe skips the
  steps that need them. The research record still holds them as listing findings,
  with their source URLs, which is enough for a draft to use them.

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

  `fit_score` and `fit_breakdown` are **optional**. A lead matched
  against a hard disqualifier is created and moved to `Disqualified`
  without ever being scored (`evals/cases.md`, Case 1; `score-lead`
  step 2), so a call that omits both is valid and leaves both fields
  empty — omitting them is not an error, and `create_lead` never
  invents a placeholder score to fill them. `create_lead` takes no
  Approach score: a new lead has had no research.
- **`get_lead`** always resolves the full record graph: the lead plus
  its linked Contacts, its research record and its draft records, with
  the newest section of each identified (sections are dated and the
  newest is last). A `lead_id` that does
  not exist is an error, not an empty or partial record — callers must
  not treat "not found" as "no data yet."
- **`update_stage`** is the only handoff mechanism between sub-agents
  (see below). It validates `stage` against the eleven-value status list and
  rejects anything else; it does not accept free-text stages. Every
  call also sets `stage_changed_at` (`Stage Changed At` in the CRM
  tools) to the moment of the transition, as part of the same write —
  not a second call, not an optional argument. **After creation, no
  other operation ever writes `stage_changed_at`** — `create_lead`
  stamps it once on the record it creates, and from then on only
  `update_stage` touches it. This is what makes the field
  trustworthy as "when did this lead's stage actually change": because
  `update_lead` writes every other lead-level field routinely (`Approach
  Score`, `Next Action`, `Do Not Contact`, and so on) without touching stage at
  all, a record's generic last-modified time would be set by any of
  those unrelated writes too — `stage_changed_at` moves only when
  `update_stage` runs, and never otherwise.
- **`update_lead`** writes every non-stage field on a lead — the four
  score fields, `Do Not Contact`, `Next Action`, `Next Action Due`,
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
- **`log_draft`** adds one section to the lead's draft record for one
  channel: a header line with today's date, `For: <person, title>` (or
  `For: the business`), the full draft, then the Personalized
  statements block (`templates/personalized-statements.md`). There is
  one draft record per channel per lead, created by the first call;
  every later call appends. A redraft is a new section at the end: the
  newest section is the current draft, and nothing before it is ever
  rewritten, voided or deleted. There is no draft status: a lead's
  drafts are approved together when the operator moves the lead to
  `Ready to Send` (Approval invariant). The tool fixes the record's
  exact title and section format in its `usage.md`, because the
  operator's own automations read them.
- **`log_research(lead_id, findings[])`** adds one section to the lead's research record:
  a header line with today's date, then one block per finding with its
  `type`, `date` (the finding's own date), `summary`, `source_url` and
  `hook`. A caller collects a run's findings and makes one call, so two
  runs, even on the same day, are two sections. It **rejects the whole
  call** when any finding has an empty `source_url` or an empty `hook`:
  a finding without a source is an unverifiable claim, and one without
  a hook is a research dump the drafting phase cannot use. The one
  exception to the usable-hook bar is a contact route: the business's
  main line or general inbox, recorded as a `listing` finding with
  `Hook: contact route` whenever it is sourced, because a draft may need
  it to reach the lead. `type` is one
  of news, funding, social, event, hire, listing, web_presence;
  anything else is rejected. `listing` holds map- or directory-listing
  facts (rating, review count, newest review date, hours, the main
  phone); `web_presence` holds whether a website exists and its visible
  state.
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
  number — a business's main line belongs on the lead (or, in a tool
  with no home for it, in the research record), a person's
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
  same answer: idle age = now − `Stage Changed At`, where "now" is the
  moment of the call. `idle_days` keeps a lead only when its idle age
  is greater than `idle_days` days.
## Approval invariant

Stated once, plainly, so a future editor sees exactly what they would
be breaking before they break it:

- An agent never writes the stage `Ready to Send` or any later status:
  only the operator writes `Ready to Send`, by moving the lead once its
  drafts are right. That move approves the lead's first touch on every
  channel; nothing is approved draft by draft.
- Drafts are append-only: `log_draft` adds a section and no operation
  edits, replaces or deletes one, so what the operator read when they
  approved is what stays on the record.
- The agent writes no draft or research section on a lead at `Ready to
  Send` or later. Approval covers the sections present when the
  operator moved the lead, and an automation reading "the newest
  section" relies on nothing being added after that. This is an
  instruction: the guard checks one call at a time and cannot see the
  lead's stage.
- **Therefore no sequence of operations approves a lead: only the
  operator's move to `Ready to Send` does.** What happens next — an
  email sequence, a LinkedIn message, a call — is the operator's, or the
  owner's automation, another system or agent acting on that status.
  The agent sends nothing to prospects and never acts on a lead at
  `Ready to Send` or later.

The opt-out has one mechanism and one instruction:

- **Mechanism (`dnc_one_way`).** `update_lead` may set `Do Not Contact`
  to true and can never clear it — a write that would move the flag
  from true back to false is rejected, and no other operation writes
  the field at all.
- **Instruction, not a mechanism.** The operator records an opt-out by
  ticking `Do Not Contact`. When the Prospector (on a lead it re-finds),
  the Preparer or the Approacher reads a lead whose `Do Not Contact` is
  true and the lead is at a status the agent works on (`New`, `Scored`,
  `Researched`, `Approach Drafted`), it moves the lead to
  `Disqualified` with reason `opt-out` and writes nothing else: no
  draft, no research, no note. A lead at `Ready to Send` or later is the
  owner's: the agent leaves it alone, and the digest flags it. The
  guard cannot see the lead's flag when it checks a single call, so
  "draft nothing for a Do Not Contact lead" is held by the agent's
  instructions and the digest, not enforced. The owner's sending system
  handles its own suppression list.

Any change that lets an operation write the stage `Ready to Send`, or
edit or remove a draft after it was written, breaks the invariant and
turns the guardrail "nothing goes out without operator approval"
(`AGENT.md`) back into an unenforced instruction. The same test
applies to `dnc_one_way`: any change that would let an operation clear
`Do Not Contact` breaks that invariant.

## Invariants

Each tool's `guard.yaml` lists in `covers` the invariants its guard
policy enforces; an invariant it does not list is instruction-only.

- `draft_only` — the agent never writes `Ready to Send` or any later
  status, and drafts are append-only (see Approval invariant).
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
| `Scored` | Prospector finishes applying the `icp.md` Fit rubric and records the Fit score and breakdown | Preparer picks it up once the Fit score clears `research_threshold`, moving it to `Researched` |
| `Researched` | Preparer finishes research, identifies decision-makers, produces hooks, and records the Approach score and breakdown | Approacher picks it up once the Approach score clears `approach_threshold`, drafting its first touch and moving it to `Approach Drafted`; an anti-signal found during research moves it to `Disqualified` instead |
| `Approach Drafted` | Approacher logs one draft per reachable enabled channel (`log_draft`: the full draft and its personalized statements) | The operator reviews and edits the drafts, ignores any they don't want, then approves the lead by moving it to `Ready to Send` — nothing is approved draft by draft |
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
