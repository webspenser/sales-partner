# CRM contract

Provider-neutral contract for the sales-partner agent's data layer. Every
sub-agent (Prospector, Preparer) and skill reads and writes
the CRM only through the nine operations
below. No sub-agent talks to a provider's API directly, and no sub-agent
invokes another sub-agent directly — **`update_stage` is the only
handoff mechanism between sub-agents.** A sub-agent's job is done when it
calls `update_stage`; the next sub-agent picks the lead up by querying
for its trigger condition — a stage (`query_by_stage`) or a stage plus a
Fit score threshold (`query_by_score`) — never by direct
invocation.

The concrete mapping onto a provider — tables, fields, views — lives in
each tool (`tools/<provider>/usage.md`). This document defines
behavior only; it names no provider table or field.

## Operations

| Operation | Arguments | Returns | On failure |
|---|---|---|---|
| `create_lead` | `company, location, industry, size, source, source_url`, plus optional `domain, address, phone, email, fit_score, fit_breakdown, segment` and the company profile fields | `lead_id`, on a record created at `Stage = New` with `Stage Changed At` stamped at creation | A lead matching an existing one by the dedupe order (domain, then phone, then company + address, each where the tool stores it) returns the existing `lead_id` and writes nothing; rejects a call with none of `domain`, `phone`, or `address` |
| `get_lead` | `lead_id` | full lead record with linked Contacts, its research record and its Talking Points record, the newest section of each identified | Missing id is an error, not an empty record |
| `update_stage` | `lead_id, stage, reason` | updated lead, with `stage_changed_at` set to the moment of this call | Rejects any stage outside the enumerated list |
| `update_lead` | `lead_id, fields` | updated lead | Accepts `segment`, `industry`, `hero_offer`, `offer_reason` and `offer_evidence` among its fields. Rejects any attempt to write `stage` through this operation — stage changes go only through `update_stage` — and any attempt to write `research_anyway`, which is the operator's. May set `Do Not Contact` to true; rejects any attempt to clear it once true |
| `log_talking_points` | `lead_id, contact_id, body` | the Talking Points record the section was added to | Create or append only: adds one dated section to the lead's Talking Points record, creating the record when it has none; never edits, replaces or removes earlier text. Takes no channel argument. The agent writes no talking points for a lead whose `Do Not Contact` is true — an instruction the guard does not enforce |
| `log_research` | `lead_id, findings[]` (each `type, summary, source_url, date, hook`) | the research record the section was added to | Adds one dated section holding the whole run's findings; rejects the call when any finding has an empty `source_url` or `hook`, or a `type` outside the seven |
| `upsert_contact` | `lead_id, name, title, email, phone, linkedin_url, role, verified, notes` | `contact_id` | Matches an existing Contact on `email` when present, otherwise on `name` plus `title`, and updates it rather than creating a duplicate; rejects a `role` outside decision-maker / influencer / gatekeeper |
| `query_by_stage` | `stage, limit, next_action_due_before, idle_days, research_anyway` | list of leads | Empty list is a valid result; rejects a call where `stage` is omitted and neither `next_action_due_before` nor `idle_days` is given. `research_anyway` is an optional boolean filter on the operator's Research Anyway field |
| `query_by_score` | `score, min_score, stage, limit` | list of leads ordered by that score descending | Rejects a `score` other than `fit` or `approach`; empty list is a valid result |

### Scores

A lead carries two scores, each a number from 0
to 100 with its per-criterion breakdown as text (`skills/score-lead`):

| Field | Written by | Read by |
|---|---|---|
| `Fit Score`, `Fit Breakdown` | the Prospector, on `create_lead` (`fit_score`, `fit_breakdown`), or on a re-found `New` lead with `update_lead` | the Preparer's trigger, against `research_threshold` |
| `Approach Score`, `Approach Breakdown` | the Preparer, with `update_lead`, after research | the operator, to decide what to approve; it triggers nothing |

Each score holds the exact value the rubric's arithmetic produces (for
example 67.5), never rounded. `query_by_score(score: fit)` filters and
sorts on `Fit Score`, `query_by_score(score: approach)` on `Approach
Score`; a lead with no value for that score is never returned.

### Offer fields

Six lead fields carry the offer match (`context/offer-catalog.md`). The
Segment and Hero Offer choices are the catalog's ids, never the display
names, so a workflow routing on them is unaffected by a rename.

| Field | Written by |
|---|---|
| Segment (a catalog segment id) | the Prospector, on `create_lead` or `update_lead`; the Preparer may correct it |
| Industry (text) | the Prospector; the Preparer may correct it |
| Hero Offer (a catalog offer id) | the Preparer, with `update_lead`; empty when no offer fits |
| Offer Reason (text) | the Preparer, with `update_lead` |
| Offer Evidence (`strong`, `moderate` or `weak`) | the Preparer, with `update_lead`; empty when every offer in the segment is ruled out, or no segment fits |
| Research Anyway (checkbox) | the operator only; no operation writes it, and every tool's guard policy refuses it to the agent |

`Offer Evidence` is `strong` with two or more sourced signals,
`moderate` with one, and `weak` when only the segment or industry fits.

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
  with their source URLs, which is enough for the talking points to use them.

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
  its linked Contacts, its research record and its Talking Points
  record, with the newest section of each identified (sections are dated and the
  newest is last). A `lead_id` that does
  not exist is an error, not an empty or partial record — callers must
  not treat "not found" as "no data yet."
- **`update_stage`** is the only handoff mechanism between sub-agents
  (see below). It validates `stage` against the ten-value status list and
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
  score fields, `segment`, `industry`, `hero_offer`, `offer_reason`,
  `offer_evidence`, `Do Not Contact`, `Next Action`, `Next Action Due`,
  and any other lead-level field outside the stage itself. It **rejects
  any attempt to write `stage`** through this operation, and it never
  writes `stage_changed_at` either — both belong to `update_stage`
  alone. It also **rejects `research_anyway`**: that checkbox is the
  operator's, and the agent only reads it. Keeping the two separate is what lets `update_stage` validate
  every stage write against the ten-value status list and remain the sole
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
- **`log_talking_points`** adds one section to the lead's Talking Points
  record: a header line `=== YYYY-MM-DD · talking points ===` with
  today's date, then six labelled parts in this order (the exact format
  is below). There is one Talking Points record per lead, created by the
  first call; every later call appends. A redo is a new section at the
  end: the newest section is the current one, and nothing before it is
  ever rewritten, voided or deleted. The call takes no channel
  argument and holds what to say, never a message.
  The tool fixes the record's exact title and section format in its
  `usage.md`, because the operator's own automations read them.

  **The Talking Points format is public,** versioned like the research
  record: it changes only with a version bump and an upgrade note in the
  README. Each section holds these six labels, in this order, with every
  factual claim sourced or marked `unverified`:

  ```
  === YYYY-MM-DD · talking points ===
  For: <name, title> (or "owner, name not found")
  Offer: <the hero offer's name> (or "none matched")
  Opener: <one observation specific to this lead>
  Points:
  - <two or three points tied to the hero offer, each from a research finding>
  Avoid:
  - <what not to say, or "none">
  Contact routes:
  - <the phone, email and LinkedIn found, each sourced>
  ```

  `For:`, `Offer:` and `Opener:` are one line each. `Points:`, `Avoid:`
  and `Contact routes:` are each followed by a bulleted list, one item
  per line; `Avoid:` may be `- none`. With no hero offer the Offer line
  reads `Offer: none matched` and the points stay general to the
  segment. A workflow reads the newest section, which is the last one.
- **`log_research(lead_id, findings[])`** adds one section to the lead's research record:
  a header line with today's date, then one block per finding with its
  `type`, `date` (the finding's own date), `summary`, `source_url` and
  `hook`. A caller collects a run's findings and makes one call, so two
  runs, even on the same day, are two sections. It **rejects the whole
  call** when any finding has an empty `source_url` or an empty `hook`:
  a finding without a source is an unverifiable claim, and one without
  a hook is a research dump the talking points cannot use. Two kinds of
  finding are exceptions to the usable-hook bar, recorded whenever they
  are sourced: a contact route (the business's main line or general
  inbox, a `listing` finding with `Hook: contact route`), because the
  talking points may need it to reach the lead; and an offer signal or
  rule-out from `context/offer-catalog.md` (`Hook: offer signal` or
  `Hook: rule-out` when it has no usable angle), because `match-offer`
  picks the offer from them. `type` is one
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
  required, rejecting anything outside the ten-value status list. Passing
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
  gone stale" without a table scan across all ten statuses one at a
  time, and it is why the operation grew these filters rather than the
  digest reconstructing them from `query_by_stage`'s original one-stage
  form.

  **Idle age** is defined exactly, so the same data always gives the
  same answer: idle age = now − `Stage Changed At`, where "now" is the
  moment of the call. `idle_days` keeps a lead only when its idle age
  is greater than `idle_days` days.

  **`research_anyway`** is a third optional filter, a boolean on the
  operator's `Research Anyway` field: `true` keeps only leads where it is
  ticked, `false` only leads where it is not. It narrows a result and
  never replaces the other conditions, so it does not make `stage`
  optional. This is how the Preparer's queue picks up the leads the
  operator pushed through below `research_threshold`
  (`query_by_stage(Scored, research_anyway: true)`), alongside
  `query_by_score` for the leads that clear it on their own.

## Approval invariant

Stated once, plainly, so a future editor sees exactly what they would
be breaking before they break it:

- An agent never writes the stage `Approved` or any later status: only
  the operator writes `Approved`, by moving the lead once its research
  and talking points look right. That move approves the lead for the
  operator's outreach; nothing is approved piece by piece.
- Talking points are append-only: `log_talking_points` adds a section
  and no operation edits, replaces or deletes one, so what the operator
  read when they approved is what stays on the record.
- The agent writes no talking points or research section on a lead at
  `Approved` or later. Approval covers the sections present when the
  operator moved the lead, and a workflow reading "the newest section"
  relies on nothing being added after that. This is an instruction: the
  guard checks one call at a time and cannot see the lead's stage.
- **Therefore no sequence of operations approves a lead: only the
  operator's move to `Approved` does.** What happens next — an email
  sequence, a LinkedIn message, a call — is the operator's, or the
  owner's automation, another system or agent acting on that status. The
  agent sends nothing to prospects and never acts on a lead at
  `Approved` or later.

The opt-out has one mechanism and one instruction:

- **Mechanism (`dnc_one_way`).** `update_lead` may set `Do Not Contact`
  to true and can never clear it — a write that would move the flag
  from true back to false is rejected, and no other operation writes
  the field at all.
- **Instruction, not a mechanism.** The operator records an opt-out by
  ticking `Do Not Contact`. When the Prospector (on a lead it re-finds)
  or the Preparer reads a lead whose `Do Not Contact` is true and the
  lead is at a status the agent works on (`New`, `Scored`,
  `Researched`), it moves the lead to
  `Disqualified` with reason `opt-out` and writes nothing else: no
  talking points, no research, no note. A lead at `Approved` or later is the owner's: the agent leaves
  it alone, and the digest flags it. The guard cannot see the lead's
  flag when it checks a single call, so "write no talking points for a
  Do Not Contact lead" is held by the agent's instructions and the
  digest, not enforced. The owner's sending system handles its own
  suppression list.

Any change that lets an operation write the stage `Approved`, or edit
or remove talking points after they were written, breaks the invariant
and turns the guardrail "nothing goes out without operator approval"
(`AGENT.md`) back into an unenforced instruction. The same test
applies to `dnc_one_way`: any change that would let an operation clear
`Do Not Contact` breaks that invariant.

## Invariants

Each tool's `guard.yaml` lists in `covers` the invariants its guard
policy enforces; an invariant it does not list is instruction-only.

- `approval_only` — the agent never writes `Approved` or any later
  status, and talking points are append-only (see Approval invariant).
- `dnc_one_way` — `Do Not Contact`, once true, is never cleared.
- `no_delete` — the agent never deletes or merges CRM records.

## Lead status

A lead holds exactly one of these ten statuses at a time (the lead
is the company). The operation is still `update_stage` and the field `stage`; the
values are the lead's status, verbatim, in order. `update_stage` rejects
any value outside this list:

```
New
Scored
Researched
Approved
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
`Researched` and `Disqualified` (plus `New` on create); `Approved`,
`Contacted`, `Engaged`, `Open Deal`, `Nurture` and `Customer` are the
operator's, or the owner's automation acting on the operator's approval,
and every tool's guard policy refuses them to the agent.
**The agent's job ends at `Researched`.** For
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
| `Scored` | Prospector records the Fit score, Segment and Industry | Preparer picks it up once the Fit score clears `research_threshold`, or the operator ticked `Research Anyway`, moving it to `Researched` |
| `Researched` | Preparer has researched the lead, re-scored it (the Approach score and breakdown), matched the hero offer and written the talking points (`log_talking_points`) | The operator reviews the research and talking points, then approves the lead by moving it to `Approved`; an anti-signal found during research moves it to `Disqualified` instead of `Researched` |
| `Approved` | The operator moves the lead here — only the operator writes `Approved` | The operator's workflow starts the sequence, and it or the operator moves the lead to `Contacted`; the operator moving it back to `Researched` cancels. The agent never acts on it |
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
triggers on where its trigger is score-gated (the Preparer, which also
reads `query_by_stage` with `research_anyway`). This is the entire
coupling between sub-agents — it is what lets the pipeline run as
independent triggers on stage or stage-and-score queries, and also what lets the same pipeline collapse
into sequential inline phases on a host without sub-agent dispatch, with
identical behavior.
