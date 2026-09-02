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
| `Domain` | text, unique |
| `Location` | text |
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

`Domain` is the uniqueness key `create_lead` dedupes on. `Stage` options
must be exactly the twelve values from the stage enum in
`crm-contract.md` — no additional options, no renamed options.

`query_by_stage`'s two optional filters read this table and, for
`idle_days`, the Activities table too: `next_action_due_before` filters
on `Next Action Due` directly; `idle_days` filters to Leads whose
linked Activities' most recent `Date` is older than the given number of
days (or which have no Activity at all), the same staleness computation
the **Stalled** view below already performs — the operation and the
view compute identically, the operation is simply the path a skill or
sub-agent calls instead of a human opening the view.

`create_lead` writes this table's fields only at creation. Every other
field except `Stage` and `Stage Changed At` is written afterward by
`update_lead` — `Score`, `Score Breakdown`, `Next Action`, `Next Action
Due`, and `Do Not Contact` all move through it. `Stage` is the one
field `update_lead` refuses to write; that write, and the timestamp
that goes with it, belong to `update_stage` alone. `update_stage` sets
`Stage Changed At` to the moment of the call on every transition — no
other operation, including `update_lead`, ever writes this field, so a
record's `Stage Changed At` value always reflects an actual stage
transition and never an unrelated field edit that happened to touch
the record.

### Contacts

| Field | Type |
|---|---|
| `Name` | text |
| `Title` | text |
| `Email` | email |
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
| `Type` | single select: news, funding, social, event, hire |
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
**`log_activity` rejects any write with `status: sent` unless the
record being updated has a current status of `status: approved`.**
This is a hard rule enforced by the operation itself, not a convention
sub-agents are trusted to follow: no sub-agent, and nothing calling
this adapter, can write `sent` directly onto a `draft` record. The
only path from `draft` to `sent` runs through the operator setting
`approved` first. This is the mechanism that makes "nothing sends
without operator approval" true — the capability to send is withheld
until approval happens, not merely requested by instruction.
**`update_activity` is restricted the opposite way, and unconditionally:
it accepts only `status: "voided"`, and rejects `draft`, `approved`,
and `sent` outright no matter what the record's current status is.**
It is not a second path to `sent`, and not a second path to `approved`
either — the only status change any agent can perform on an existing
Activity through this contract is voiding it, a dead end. `voided`
exists for exactly one case today: `subagents/follow-up.md`'s opt-out
guardrail calls `update_activity` to move every pending (`draft` or
`approved`) Activity for a lead to `voided` the moment an inbound
opt-out is logged, so a message already queued for approval can never
reach `sent` after the prospect has asked not to be contacted —
because `update_activity` has no ability to write `sent` at all, not
merely because it wasn't asked to.

`query_activities` reads this table, filtered by `Status` and,
optionally, a `[since, until]` window on `Date`. This is the operation
`send-digest` uses to find every Activity at `Status = draft` — the
same set the **Awaiting Approval** view below renders for a human — and
it returns each Activity with its linked `Lead`, so a caller gets the
company without a second call. `query_activities` accepts `voided`
as a `Status` value like any other, for a caller that specifically
wants voided history — but nothing in this adapter treats a `voided`
Activity as awaiting anything: the **Awaiting Approval** view below
filters on `Status = draft` specifically, not "not yet sent," so a
voided Activity never appears there once `update_activity` has moved
it out of `draft`.

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

- **Awaiting Approval** — Activities where `Status = draft`, sorted by
  Date. This view **is** the entire review interface: because drafts
  live in Activities rather than a separate table, this one view shows
  every message awaiting operator approval across every lead and every
  channel.
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
