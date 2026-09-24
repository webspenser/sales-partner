# CRM Airtable adapter

The concrete Airtable mapping for `crm-contract.md`'s eleven operations:
four tables, their exact fields and types, and the four views the
operator works from. Field names below are used verbatim by the
sub-agent contracts and skills in Tasks 8–12 — do not rename, abbreviate,
or reword any of them when implementing this adapter.

## Tables

### Leads

| Field | Type |
|---|---|
| `Company` | text |
| `Domain` | text |
| `Location` | text |
| `Address` | text |
| `Phone` | phone |
| `Email` | email |
| `Industry` | single select |
| `Size` | single select |
| `Source` | text |
| `Source URL` | url |
| `Score` | number 0–100 |
| `Score Breakdown` | long text |
| `Stage` | single select — the twelve stages (see `crm-contract.md`) |
| `Stage Changed At` | datetime |
| `Next Action` | text |
| `Next Action Due` | date |
| `Do Not Contact` | checkbox |

`create_lead` dedupes on `Domain`, then on `Phone` (digits only), then
on `Company` plus `Address` (normalized), in that order — see
`crm-contract.md`. None of the three is a unique column, because each
may be empty on a given lead. `Stage` options must be exactly the
twelve values from the stage enum in `crm-contract.md` — no additional
options, no renamed options.

`query_by_stage`'s two optional filters read this table and, for
`idle_days`, the Activities table too: `next_action_due_before` filters
on `Next Action Due` directly; `idle_days` filters to Leads whose
linked Activities' most recent `Date` is older than the given number of
days (or which have no Activity at all), the same staleness computation
the **Stalled** view below already performs — the operation and the
view compute identically, the operation is simply the path a skill or
sub-agent calls instead of a human opening the view.

`create_lead` writes this table's fields at creation, and that includes
`Stage` and `Stage Changed At`: **every record it creates starts at
`Stage = New`**, with `Stage Changed At` stamped at the moment of
creation. It takes no stage argument — `New` is the only initial value
— which is what makes `query_by_stage` on `New` return freshly created
leads rather than nothing. `Score` and `Score Breakdown` are optional
at creation and stay empty on a lead disqualified before it was ever
scored.

Every other field is written afterward by `update_lead` — `Score`,
`Score Breakdown`, `Next Action`, `Next Action Due`, and `Do Not
Contact` all move through it. `Stage` is the one field `update_lead`
refuses to write; that write, and the timestamp that goes with it,
belong to `update_stage` alone. `update_stage` sets `Stage Changed At`
to the moment of the call on every transition, and is the only
operation that writes the field after `create_lead` stamped it at
creation — `update_lead` never does — so a record's `Stage Changed At`
value always reflects either its creation or an actual stage
transition, never an unrelated field edit that happened to touch the
record. `update_stage` likewise remains the only operation that
*changes* a `Stage` value once `create_lead` has set it to `New`.

**`Do Not Contact` is a one-way flag.** `update_lead` may check it and
rejects any write that would uncheck it once checked; no other
operation writes the field at all, so nothing an agent can call
restores contactability. And `log_activity` rejects creating an
Activity with `Direction = outbound` for a Lead whose `Do Not Contact`
is checked, so an opted-out Lead cannot acquire a new outbound draft
through any operation this adapter maps — the same withheld-capability
enforcement as the approval guarantee, applied to the opt-out.

### Contacts

| Field | Type |
|---|---|
| `Name` | text |
| `Title` | text |
| `Email` | email |
| `Phone` | phone |
| `LinkedIn URL` | url |
| `Role` | single select: decision-maker, influencer, gatekeeper |
| `Verified` | checkbox |
| `Notes` | long text |
| `Lead` | link to Leads |

`Verified` distinguishes a contact confirmed by research (name, title,
and channel checked against a live source) from one inferred or
unconfirmed. Sub-agents that draft outreach should prefer `Verified`
contacts and treat an unverified `Role` as provisional. `Notes` holds
provenance annotations that don't belong in any other field — most
importantly an unverified pattern-guessed email, recorded as `pattern
guess, unverified` rather than ever written into `Email`.

`upsert_contact` writes this table: matched on `Email` when present,
otherwise on `Name` plus `Title`, updating the matched row rather than
creating a second one for the same person. `Verified` defaults to
unchecked; `upsert_contact` never checks it on its own — only a caller
that has actually confirmed the address may set it.

### Research

| Field | Type |
|---|---|
| `Type` | single select: news, funding, social, event, hire, listing, web_presence |
| `Summary` | long text |
| `Source URL` | url |
| `Date` | date |
| `Hook` | long text |
| `Lead` | link to Leads |

`Summary` and `Hook` hold different things and both are required —
`Summary` is not a longer version of `Hook`, and `Hook` is not a
shortened version of `Summary`:

- **`Summary`** records the finding — what was learned, in enough
  detail to stand on its own (e.g., "Company raised a $12M Series A led
  by Acme Ventures, announced 2026-08-14; plans to double the
  engineering team per the funding press release").
- **`Hook`** holds the specific, usable connection point derived from
  that finding — the phrase or angle an outreach draft can open with
  (e.g., "congratulate on the Series A and tie it to scaling the
  engineering team"). `Hook` is what makes Phase 3 (drafting the first
  approach) possible: the Approacher reads `Hook`, not `Summary`, to
  write an opening line that is specific to this lead rather than
  generic. A Research row with a `Summary` and no usable `Hook` is
  incomplete for the Preparer's purposes.

`log_research` writes this table and rejects a call with an empty
`Source URL` or an empty `Hook` — the same incompleteness this section
describes is refused at the operation, not merely discouraged by
convention.

### Activities

| Field | Type |
|---|---|
| `Channel` | single select: email, linkedin, call, other |
| `Direction` | single select: outbound, inbound |
| `Date` | date |
| `Summary` | long text |
| `Draft Body` | long text |
| `Status` | single select: draft, approved, sent, voided |
| `Outcome` | text |
| `Lead` | link to Leads |
| `Contact` | link to Contacts |

**Design principle: drafts are Activities, not a separate table.** A
draft outreach message is an Activities row with `Status = draft` and
its content in `Draft Body`. There is no separate "Drafts" table and
none should ever be created. Keeping drafts inside Activities means the
operator's entire approval queue is a single Airtable view (see
**Awaiting Approval** below) — one place to see every draft, approve it,
edit `Draft Body` if needed, and watch it move to `approved` and then
`sent`. A later change that splits drafts into their own table would
break the review workflow: the approval queue would no longer be one
view, `log_activity`'s guardrail (below) would no longer have a single
`Status` field to check, and the operator would lose the single-surface
review interface this schema is built around. Do not make that change.

`Status` only ever moves forward through `draft` → `approved` → `sent`,
or sideways from `draft` or `approved` to the terminal `voided` — never
the reverse of either path, and never from `voided` onward to `sent`.
No operation available to an agent can write `approved` or `sent` at
all, under any condition: **`log_activity` is create-only — it takes
no `activity_id` and never touches an existing row — and accepts only
`status: "draft"` on the row it creates**, rejecting `approved`,
`sent`, and `voided` outright and unconditionally, on every call, with
no notion of "current status" to satisfy since there is no existing
record to check. **`update_activity` only touches an existing row and
accepts only `status: "voided"`**, rejecting `draft`, `approved`, and
`sent` outright and unconditionally regardless of that record's
current status. Between these two operations — the only two that
write `Status` at all — `approved` and `sent` are never a legal write.
Those two values are reachable only by the operator acting directly in
Airtable: approving a draft in the **Awaiting Approval** view below,
and separately sending it, both outside every one of the eleven
operations this adapter maps (`crm-contract.md`'s Approval invariant
states this as a provable rule, not a convention). This is the
mechanism that makes "nothing sends without operator approval" true —
the capability to write `approved` or `sent` does not exist anywhere
in the agent's tool access, not merely withheld by instruction.
`voided` exists for exactly one case today: `subagents/follow-up.md`'s
opt-out guardrail calls `update_activity` to move every pending
(`draft` or `approved`) Activity for a lead to `voided` the moment an
inbound opt-out is logged, so a message already queued for approval
can never reach `sent` after the prospect has asked not to be
contacted. Voiding handles the messages already queued; the matching
rule on the creation side is that **`log_activity` refuses to create an
Activity with `Direction = outbound` for a Lead whose `Do Not Contact`
is checked** — so once the flag is set, no new outbound draft can be
minted for that Lead either, and because `update_lead` can never
uncheck the flag, that refusal is permanent. Inbound Activities are
unaffected: a reply or a call debrief on an opted-out Lead is still
recordable history.

`query_activities` reads this table, filtered by `Status`, optionally
`Direction`, and optionally a `[since, until]` window on `Date`. This
is the operation `send-digest` uses to find every outbound Activity at
`Status = draft` — the same set the **Awaiting Approval** view below
renders for a human — and it returns each Activity with its linked
`Lead`, so a caller gets the company without a second call.
`query_activities` accepts `voided` as a `Status` value like any
other, for a caller that specifically wants voided history — but
nothing in this adapter treats a `voided` Activity as awaiting
anything: the **Awaiting Approval** view below filters on
`Status = draft` specifically, not "not yet sent," so a voided
Activity never appears there once `update_activity` has moved it out
of `draft`. **The view also filters on `Direction = outbound`,** for a
different reason than `voided` exclusion: `log_activity` creates
every Activity at `Status = draft` regardless of `Direction` — an
inbound reply logged for context, or a call debrief logged by the
Sales-call-specialist, lands at `draft` exactly like an outbound
approach message does. Without the `Direction` filter, those
non-decision rows would sit in the same queue as messages genuinely
awaiting an operator's send decision, diluting the one view this
schema's entire no-send guarantee depends on a human actually reading.
`Direction = outbound` narrows the view to only the rows a decision is
actually needed on.

## Views

These four views are required, since they are the operator's interface
onto the pipeline. They are a convenience for the operator looking at
Airtable directly — a human-facing surface — not the mechanism any
skill or sub-agent depends on to read this data: `send-digest`, and any
future skill with the same needs, reads through `query_activities` and
`query_by_stage`'s `next_action_due_before` / `idle_days` filters
instead of these views, precisely so that provider-neutrality holds —
swapping the adapter (a different CRM behind the same contract) keeps
every skill working, where reading these views directly would not.
Each view below is defined to compute exactly what its corresponding
operation returns, so the operator's screen and a skill's query never
disagree about what counts as "awaiting approval," "due today," or
"stalled."

- **Awaiting Approval** — Activities where `Status = draft` **and**
  `Direction = outbound`, sorted by Date. This view **is** the entire
  review interface: because drafts live in Activities rather than a
  separate table, this one view shows every message awaiting operator
  approval across every lead and every channel — and only that: the
  `Direction = outbound` half of the filter is what keeps inbound
  replies and call debriefs, which also land at `Status = draft`, out
  of a queue that exists specifically for decisions the operator still
  has to make.
- **Research Queue** — Leads where `Stage = Scored`, sorted by Score
  descending. What the Preparer works through next, highest-score
  first.
- **Due Today** — Leads where `Next Action Due` is today or earlier.
  Leads with an overdue or due-today follow-up, across any active
  stage.
- **Stalled** — Leads with no Activity newer than the configured
  cadence. Leads that have gone quiet longer than the pipeline's
  configured touch cadence allows, and need attention (a nudge, a
  follow-up, or a move to `Lost`).
