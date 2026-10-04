# CRM Airtable tool

The concrete Airtable mapping for the contract (`../../contract.md`)'s eleven operations:
four tables, their exact fields and types, and the four views the
operator works from. Field names below are used verbatim by the
sub-agent contracts and skills in Tasks 8–12 — do not rename, abbreviate,
or reword any of them when implementing this tool.

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
| `Stage` | single select — the eleven statuses (see the contract) |
| `Stage Changed At` | datetime |
| `Next Action` | text |
| `Next Action Due` | date |
| `Revisit On` | date — set by the operator for `Nurture`; the agent reads it, never writes it |
| `Do Not Contact` | checkbox |

`create_lead` dedupes on `Domain`, then on `Phone`, then on `Company`
plus `Address` (normalized), in that order — see the contract.
A phone is normalized to E.164: `+` and digits, nothing else. A number
written without a country code takes the country of the lead's sourced
address; failing that, the country of `service_area.center` in
`icp.md`; failing both, it is compared as written, digits only, and is
never given a guessed country code. None of the three is a unique
column, because each may be empty on a given lead. `Stage` options
must be exactly the eleven values from the lead status list in
the contract — no additional options, no renamed options.

`query_by_stage`'s two optional filters read this table and, for
`idle_days`, the Activities table too: `next_action_due_before` filters
on `Next Action Due` directly; `idle_days` applies the contract's
`max(...)` rule: a Lead's idle age is now minus the later of its linked
Activities' most recent `Date` and its `Stage Changed At`. If the lead
has no Activity, use `Stage Changed At`. A Lead is kept when that idle
age is greater than the given number of days.

`get_lead` reads one Leads record by its record id and follows the
links to its Contacts, Research, and Activities rows. `query_by_score`
filters the Leads table on `Stage` and `Score >= min_score`, sorted by
`Score` descending and cut at `limit`.

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
restores contactability; the guard enforces this (`dnc_one_way`). The
rule that `log_activity` must not create an Activity with
`Direction = outbound` for a Lead whose `Do Not Contact` is checked is
an instruction, not a mechanism: the guard checks one call at a time
and cannot see the Lead's flag. It is held by the agent's instructions,
the digest check and the Do Not Contact column in the **Review** view
below.

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
| `Status` | single select: draft, sent, voided |
| `Outcome` | text |
| `Lead` | link to Leads |
| `Contact` | link to Contacts |
| `Lead Do Not Contact` | lookup of `Do Not Contact` from `Lead`; set up by hand, never written |

**Design principle: drafts are Activities, not a separate table.** A
draft outreach message is an Activities row with `Status = draft` and
its content in `Draft Body`, linked to its lead, one per channel with
its own `Date`. There is no separate "Drafts" table and none should ever
be created: the operator reviews a lead's whole plan from the lead (see
**Review** below), and a split table would break that.

`Status` moves from `draft` to `sent` (the touch went out: `enroll`
enrolled the email, or the operator did the LinkedIn or call touch) or
to the terminal `voided`, and never back. **`log_activity` is
create-only and accepts only `status: "draft"`**; **`update_activity`
only touches an existing row and accepts only `status: "sent"` or
`"voided"`**, writing `Status` and `Outcome` and never `Draft Body`. The
plan itself is approved only when the operator moves the lead to
`Ready to Send`; no operation writes that stage, and the guard policy
(below) refuses it. `voided` is used by `skills/sync-replies/SKILL.md`'s
opt-out guardrail, which voids every pending draft for a lead the moment
an inbound opt-out is logged. The matching rule on the creation side is
that **`log_activity` refuses to create an Activity with
`Direction = outbound` for a Lead whose `Do Not Contact` is checked**.
That rule is an instruction the guard does not enforce; because
`update_lead` can never uncheck the flag (`dnc_one_way`), it holds for
as long as the agent follows it. Inbound Activities are unaffected: a
reply or a call debrief on an opted-out Lead is still recordable
history.

`query_activities` reads this table, filtered by `Status`, optionally
`Direction`, optionally `Channel` when given, and optionally a
`[since, until]` window on `Date`. This
is the operation `send-digest` uses to find every outbound Activity at
`Status = draft`, and it returns each Activity with its linked `Lead`,
so a caller gets the company without a second call. Pass
`Direction = outbound` to leave out inbound replies and call debriefs,
which `log_activity` also creates at `draft`.

## Tool mapping

`airtable:` means the connected Airtable server's tools. Every
operation reaches Airtable through these:

- Reads (`get_lead`, `query_by_stage`, `query_by_score`,
  `query_activities`, and the matching and dedupe lookups inside the
  write operations) use `airtable:list_records_for_table` or
  `airtable:search_records`, with `airtable:get_table_schema` for
  select-field options.
- Creates (`create_lead`, `log_activity`, `log_research`, and the
  create half of `upsert_contact`) use
  `airtable:create_records_for_table`.
- Updates (`update_lead`, `update_stage`, `update_activity`, and the
  update half of `upsert_contact`) use
  `airtable:update_records_for_table`.
  Write only the fields that change: an update that repeats unchanged
  fields (for example `Do Not Contact` unchecked) can be refused by the
  guard.
- Every write keys its fields by field ID. Get the table's ID and its
  fields from `airtable:list_tables_for_base`, and
  take each field ID from that table: names like `Lead` or `Email` repeat across tables. The
  `field_` lines in `bindings/crm.md` (see Probe) are the guard's list of
  IDs a write may use, across all four tables. Before the first Airtable
  write in a session, if `bindings/crm.md` has no `field_` lines, run the
  Probe first. If a write is refused with "is not a recorded field ID" or
  "has not recorded any field IDs", run the Probe again, rewrite the
  `field_` lines, and retry the write once; if it is refused again, stop
  and tell the user. In a scheduled run, do not rewrite
  `bindings/crm.md` (a scheduled run edits no instance files): stop and
  report that the probe must be re-run in setup's tools step.

## Views

These four views are required, since they are the operator's interface
onto the pipeline. They are a convenience for the operator looking at
Airtable directly — a human-facing surface — not the mechanism any
skill or sub-agent depends on to read this data: `send-digest`, and any
future skill with the same needs, reads through `query_activities` and
`query_by_stage`'s `next_action_due_before` / `idle_days` filters
instead of these views, precisely so that provider-neutrality holds —
swapping the tool (a different CRM behind the same contract) keeps
every skill working, where reading these views directly would not.
Each view below is defined to compute exactly what its corresponding
operation returns, so the operator's screen and a skill's query never
disagree about what counts as "in review," "due today," or "stalled."

- **Review** — Leads where `Stage = Approach Drafted`, with their linked
  Activities and `Do Not Contact` visible. Open a lead to see its plan:
  one draft per channel, each with its `Date`. Edit `Draft Body` or
  `Date`, set any draft you don't want to `voided`, then move the lead
  to `Ready to Send`: that approves the whole plan.
- **Ready to Send** — Leads where `Stage = Ready to Send`. The next
  `enroll` run picks these up; move a lead back to `Approach Drafted`
  before then to cancel.
- **My touches** — Activities where `Status = draft`,
  `Direction = outbound` and `Channel` is `linkedin` or `call`, sorted
  by Date. These wait for you on their dates; set `Status` to `sent`
  when you've done one.
- **Research Queue** — Leads where `Stage = Scored`, sorted by Score
  descending. What the Preparer works through next, highest-score
  first.
- **Due Today** — Leads where `Next Action Due` is today or earlier.
- **Nurture** — Leads where `Stage = Nurture`, sorted by `Revisit On`,
  soonest first. Leads you parked to come back to; the agent leaves them
  alone until that date.

## Probe

Setup runs these read-only calls when binding this tool, and writes
what they find to `bindings/crm.md` in the instance:

1. `airtable:search_bases` (or `list_bases`) — find the base that
   holds the Leads, Contacts, Research, and Activities tables; ask the
   operator if more than one could. Record `base_id` and `base_name`.
2. `airtable:list_tables_for_base` on that base — every table and
   field named in this tool must exist with the listed type. Record
   every field of the four tables, from that one call, as
   `field_<name>: <field ID>`: the name lowercased, with spaces and
   hyphens as underscores (`Do Not Contact` → `field_do_not_contact`).
   A name used in two tables gets two lines.

Write each `field_` line as a plain line, `field_<name>: <ID>`, with
nothing else on it: no bullet, no backticks or quotes, no trailing note.
A decorated line blocks every Airtable write. Example of
`bindings/crm.md`:

```
base_id: appXXXXXXXXXXXXXX
base_name: Sales
field_status: fldXXXXXXXXXXXXXX
field_do_not_contact: fldYYYYYYYYYYYYYY
field_draft_body: fldZZZZZZZZZZZZZZ
field_lead: fldAAAAAAAAAAAAAA
field_lead: fldBBBBBBBBBBBBBB
…
```

`airtable:` means the connected Airtable server's tools, whatever
their prefix. If a table or field is missing, offer the steps in `## Setup`
(this tool has no bootstrap script), then probe again.

## Guard policy

`guard.yaml` in this folder is enforced by the agent's guard policy
engine before every Airtable call inside an instance. Its allow list
holds only the read tools (`list_bases`, `search_bases`,
`list_tables_for_base`, `get_table_schema`, `list_records_for_table`,
`search_records`) and the two record-write tools
(`create_records_for_table`, `update_records_for_table`); every other
tool is blocked, and any tool whose name contains `delete` is denied.
Airtable writes name fields by ID, and every key in a write must be a
field ID the probe recorded in `bindings/crm.md`; any other key is
refused ("is not a recorded field ID"). A field added or recreated in
Airtable gets a new ID, so it is refused until the probe runs again,
which also means a recreated `Status` can't slip past its rule. With no
`field_` lines recorded, every write is refused. The rules, checked
against the recorded IDs:

- `Stage` may only be written as `New` on create, and never as
  `Ready to Send`: only the operator approves a plan;
- `Status` may only be written as `draft` on create and as `sent` or `voided` on
  update;
- `Do Not Contact` may only be written as `true`;
- `Draft Body` may be set on create and never changed after, so an
  draft can't be rewritten after create.

## Setup

The probe needs four tables in one Airtable base, with the fields below.
Create any that are missing yourself in Airtable, then tell the agent so it
probes again. This tool has no script route. Field names are used
verbatim, so match the spelling and capitalization exactly.

1. Open (or create) the base that will hold the pipeline.
2. Create a table named `Leads` with these fields:

   | Field | Type | Options |
   |---|---|---|
   | `Company` | Single line text | |
   | `Domain` | Single line text | |
   | `Location` | Single line text | |
   | `Address` | Single line text | |
   | `Phone` | Phone number | |
   | `Email` | Email | |
   | `Industry` | Single select | |
   | `Size` | Single select | |
   | `Source` | Single line text | |
   | `Source URL` | URL | |
   | `Score` | Number | integer, 0 to 100 |
   | `Score Breakdown` | Long text | |
   | `Stage` | Single select | exactly the eleven statuses: New, Scored, Researched, Approach Drafted, Ready to Send, Contacted, Engaged, Open Deal, Nurture, Customer, Disqualified |
   | `Stage Changed At` | Date and time | |
   | `Next Action` | Single line text | |
   | `Next Action Due` | Date | |
   | `Revisit On` | Date | |
   | `Do Not Contact` | Checkbox | |

   Leave `Industry` and `Size` options empty or set them from the bands in
   `icp.md`.
3. Create a table named `Contacts`:

   | Field | Type | Options |
   |---|---|---|
   | `Name` | Single line text | |
   | `Title` | Single line text | |
   | `Email` | Email | |
   | `Phone` | Phone number | |
   | `LinkedIn URL` | URL | |
   | `Role` | Single select | decision-maker, influencer, gatekeeper |
   | `Verified` | Checkbox | |
   | `Notes` | Long text | |
   | `Lead` | Link to another record | table `Leads` |

4. Create a table named `Research`:

   | Field | Type | Options |
   |---|---|---|
   | `Type` | Single select | news, funding, social, event, hire, listing, web_presence |
   | `Summary` | Long text | |
   | `Source URL` | URL | |
   | `Date` | Date | |
   | `Hook` | Long text | |
   | `Lead` | Link to another record | table `Leads` |

5. Create a table named `Activities`:

   | Field | Type | Options |
   |---|---|---|
   | `Channel` | Single select | email, linkedin, call, other |
   | `Direction` | Single select | outbound, inbound |
   | `Date` | Date | |
   | `Summary` | Long text | |
   | `Draft Body` | Long text | |
   | `Status` | Single select | draft, sent, voided |
   | `Outcome` | Single line text | |
   | `Lead` | Link to another record | table `Leads` |
   | `Contact` | Link to another record | table `Contacts` |
   | `Lead Do Not Contact` | Lookup | `Do Not Contact` from `Lead`; for the Review and My touches views, never written |

6. Create the views from the Views section above (Review, Ready to Send,
   My touches, Research Queue, Due Today, Nurture). They are for you, not for the agent.
