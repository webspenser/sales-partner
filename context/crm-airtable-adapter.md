# CRM Airtable adapter

The concrete Airtable mapping for `crm-contract.md`'s six operations:
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
| `Next Action` | text |
| `Next Action Due` | date |
| `Do Not Contact` | checkbox |

`Domain` is the uniqueness key `create_lead` dedupes on. `Stage` options
must be exactly the twelve values from the stage enum in
`crm-contract.md` — no additional options, no renamed options.

### Contacts

| Field | Type |
|---|---|
| `Name` | text |
| `Title` | text |
| `Email` | email |
| `LinkedIn URL` | url |
| `Role` | single select: decision-maker, influencer, gatekeeper |
| `Verified` | checkbox |
| `Lead` | link to Leads |

`Verified` distinguishes a contact confirmed by research (name, title,
and channel checked against a live source) from one inferred or
unconfirmed. Sub-agents that draft outreach should prefer `Verified`
contacts and treat an unverified `Role` as provisional.

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

### Activities

| Field | Type |
|---|---|
| `Channel` | single select: email, linkedin, call, other |
| `Direction` | single select: outbound, inbound |
| `Date` | date |
| `Summary` | long text |
| `Draft Body` | long text |
| `Status` | single select: draft, approved, sent |
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

`Status` only ever moves forward: `draft` → `approved` → `sent`.
**`log_activity` rejects any write with `status: sent` unless the record
being updated was previously `status: approved`.** This is a hard rule
enforced by the operation itself, not a convention sub-agents are
trusted to follow: no sub-agent, and nothing calling this adapter, can
write `sent` directly onto a `draft` record. The only path from `draft`
to `sent` runs through the operator setting `approved` first. This is
the mechanism that makes "nothing sends without operator approval" true
— the capability to send is withheld until approval happens, not merely
requested by instruction.

## Views

These four views are required, since they are the operator's interface
onto the pipeline:

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
