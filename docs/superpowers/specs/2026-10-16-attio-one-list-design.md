# One Attio list: research and drafts as notes — design

Date: 2026-10-16. Builds on sales-partner 7.3.0 (PR #21, two-gate
scoring); ships as 7.4.0.

## Why

The Attio tool spreads one lead over three lists
(`sales_partner_pipeline`, `sales_partner_research`,
`sales_partner_outreach`) plus Companies and People. The operator opens a
lead from the Sales Partner list, lands on what looks like a company
page, and can't find the research or the drafts: they sit in two other
lists, shown only as list memberships in a side panel. The operator has
already renamed the two extra lists "zz Archive – …", but the agent
still writes to them, because it finds lists by slug.

The operator's working surface is the **company record**. The pipeline
list tracks companies; from a company the operator wants to see, in one
place:

- the company's own fields filled in (domain, description, location,
  social links) — a visible sign the agent did its part;
- a note with the research;
- a note per channel with the drafted communication;
- the people linked to the company, each with their contact details,
  including people the operator adds by hand as they meet them.

Filled-in fields on the canonical objects (Companies, People) are the
source of truth. The pipeline list holds only what is about the lead as
a sales-pipeline item.

## Goals

1. One Attio list: `sales_partner_pipeline`. The research and outreach
   lists are retired.
2. Research lives in **one note per company**, "Sales Partner ·
   Research"; each research run appends a dated section.
3. Drafts live in **one note per channel per company**: "Sales Partner ·
   Email", "Sales Partner · LinkedIn", "Sales Partner · Call". A
   redraft appends a new dated section; the newest section, at the
   bottom, is the current draft.
4. The agent fills Company and Person fields as fully as sources allow,
   filling only empty fields, and fills more in whenever later research
   finds them.
5. Contact details live only on the canonical objects: a person's
   phone, email and LinkedIn on the Person. The pipeline entry carries
   no phone, email, address or location.

## Non-goals

- Arranging Attio's screens (record layouts, list views, which
  attributes show). The operator owns the Attio UI. The tool's `##
  Views` section may suggest views, nothing more.
- Using the Deals object. Deals stay the operator's, for real
  opportunities (unchanged).
- Building any automation. The package triggers nothing from notes.
  But notes are a **read surface for the operator's own automations**
  (see Reading from an automation), so their format is fixed.
- Any outreach. Unchanged: the agent drafts; it never emails, messages
  or calls anyone. A "call" draft is talking points for the operator.

## Anti-goals (failure even if it works)

- The agent overwrites or deletes something the operator or Attio's
  enrichment wrote: a field value, a note, a person.
- A draft's text is rewritten after it was written. A redraft adds; it
  never replaces.
- A second research or channel note appears for the same company
  (the operator would have to hunt again).
- Phone or email copied onto the company or the pipeline entry, so two
  places disagree.

## Decisions taken with the operator

- One list; research and drafts as notes on the **company**.
- One research note per company, appended per run with a date header.
- One draft note per channel per company, appended on redraft with a
  date header; the operator scrolls to the bottom for the current one.
- Company fields: only Attio's built-in ones (domain, description,
  primary location, LinkedIn, Facebook, Instagram, and any other
  built-in the research sources). **No custom phone or email field on
  Companies.**
- Person fields: phone, email, LinkedIn, job title, role (`sp_role`),
  plus the existing `sp_verified`, `sp_notes` and `lead_source`.
- Pipeline entry: no phone, no email. Dedupe uses the company's domain.
- Opt-out: shown by status only (`Do Not Contact` ticked, lead moved to
  `Disqualified`). The agent does not touch notes for an opt-out. Notes
  are never deleted; nothing acts on them.

## Design

### Attio layout

| Thing | Home |
|---|---|
| The lead (pipeline state) | `sales_partner_pipeline` entry on the company (exactly one) |
| Company facts | the Companies record, built-in attributes |
| Research | note "Sales Partner · Research" on the company |
| Drafts | notes "Sales Partner · Email" / "· LinkedIn" / "· Call" on the company |
| Contacts | People records, `company` = the lead's company |

`lead_id` stays the company's `record_id`.

### Pipeline entry attributes

Kept: `lead`, `stage`, `stage_changed_at`, `stage_reason`, `fit_score`,
`fit_breakdown`, `approach_score`, `approach_breakdown`, `industry`,
`size`, `source`, `source_url`, `next_action`, `next_action_due`,
`revisit_on`, `do_not_contact`.

Added: `recommended_channel` — select `email`, `linkedin`, `call`;
written by the Approacher with the drafts, so the operator sees the
recommendation in the list without opening notes.

Removed from the package (no longer read, written or probed): `phone`,
`email`, `address`, `location`. Address and location live on the
company's `primary_location`.

### Company and Person fields

- `create_lead` writes `name`, `domains` (when there is a website) and
  `primary_location` (from the sourced address, else the city/state
  location) on the company, empty attributes only, plus `description`
  and the social links when the listing shows them (the existing
  company profile fields rule).
- The Preparer fills more company fields as research confirms them,
  empty attributes only (existing rule).
- `upsert_contact` is unchanged: `email_addresses`, `phone_numbers`,
  `linkedin`, `job_title`, `company`, `sp_role`, `sp_verified`,
  `sp_notes`, `lead_source` (create only). When a later run sources a
  value for an empty field on an existing person, it fills it in; it
  never replaces a value.
- A business's **main line** and **general inbox** (info@) are not
  stored as fields anywhere. They are recorded, with their source URL,
  in the research note (listing facts), and printed in the Call or
  Email note when a draft uses them.

### Notes

Attio's `create-note` takes a title and markdown content on a parent
record. `update-note` can only **append** or prepend plain text (each
newline a paragraph) and change the title; it cannot replace the body.
That is exactly the behaviour wanted.

**Finding a note.** `search-notes-by-metadata` on the company
(`parent_record_object: companies`, `parent_record_id: lead_id`), match
the exact title. If none exists, `create-note` with that title and the
first section as content. If more than one exists (an operator copy, a
race), append to the oldest and never create another.

**Section format.** Every section starts with a header line, so the
operator can scroll to the newest and an automation can split on it
(the exact format is fixed; see Reading from an automation):

- Research: `=== 2026-10-16 · research ===`, then one block per finding
  with the lines `Type:`, `Date:` (the finding's date), `Summary:`,
  `Source:` (URL), `Hook:`. Listing facts
  (rating, review count, newest review date, hours, the main phone,
  website state) are findings like any other, each with its URL.
- Draft notes: `=== 2026-10-16 · recommended: <one-line reason> ===` or
  `=== 2026-10-16 · statements ===`, then `For: <person, title>` (or
  `For: the business`), then the body: the full draft and the
  Personalized statements block for the recommended channel, the
  statements block alone otherwise (unchanged content rules,
  `templates/personalized-statements.md`).

The first section goes into `create-note` as markdown; later sections
are appended as plain text, so the header and body use plain lines in
both cases (no tables, no markdown that only renders in the first
section).

**Redraft.** Append a new dated section to that channel's note. If the
recommendation moves to another channel, `recommended_channel` changes
on the pipeline entry and the new channel's note gets a `recommended:`
section; the old channel's note gets a new `statements` section only
if its statements change. Nothing is voided.

### Reading from an automation

The operator plans an n8n workflow (not part of this build) that:

1. lists `sales_partner_pipeline` entries filtered on `approach_score`
   in two bands (50–70 to one sequence, 70 and up to another), and on
   `stage` = `Ready to Send`, so only leads the operator approved go
   out (the approval invariant);
2. lists the notes on each entry's company (Attio API, notes filtered by
   parent record; each note returns its title and its text);
3. picks the research note and the Email or Call note by exact title,
   and takes the newest section (the last header line and what follows);
4. writes its own personalized statement from that text and enrolls the
   lead.

So the note titles and the section header are a **fixed, documented
format** (in the Attio tool's `usage.md`, under a heading such as
"Reading notes from an automation"), changed only with a version bump
and a README upgrade note:

- Titles, exactly: `Sales Partner · Research`, `Sales Partner · Email`,
  `Sales Partner · LinkedIn`, `Sales Partner · Call`.
- Header, alone on its line: `=== YYYY-MM-DD · <kind> ===`, where
  `<kind>` is `research`, `recommended: <one-line reason>` or
  `statements`.
- Inside a draft section, labelled lines an automation can split on:
  `For: …`, then the draft, then the block starting `Personalized
  statements` with its `opener:`, `relevance:`, `proof:`, `ask:` lines
  (unchanged from `templates/personalized-statements.md`).
- Inside a research section, one block per finding with the lines
  `Type:`, `Date:`, `Summary:`, `Source:`, `Hook:`.

A lead in the 50–70 band was researched (Fit gate) but got no drafts:
the Approacher drafts only at or above `approach_threshold` (70). For
those leads the automation reads the research note alone. Lowering
`approach_threshold` to 50 is the operator's choice if they want drafts
for that band too.

### Contract changes (`capabilities/crm/contract.md`)

The contract stays provider-neutral and changes for every tool, so
there is one shape (no Attio-only branch):

- **`log_research(lead_id, findings[])`** appends one dated section
  holding a whole research run's findings to the lead's research
  record; each finding keeps today's fields (`type, summary,
  source_url, date, hook`) and rejections (`source_url` and `hook`
  required, seven types; one bad finding rejects the call). One call
  per run, so two runs on the same day are two sections. *(Builder
  check; my call: per-call findings could not tell which call opens a
  new section.)* The Preparer collects findings as it researches and
  writes them once, before scoring; under HubSpot that is one Note per
  run.
- **`log_activity`** becomes **`log_draft(lead_id, contact_id, channel,
  kind, reason, body)`**: appends a dated section to the lead's draft
  record for `channel` (`kind` is `recommended` or `statements`).
  Create or append only; it never edits or removes earlier text.
- **Removed:** `update_activity` (no voiding: a redraft appends, an
  opt-out is the status), `query_activities` (no caller needs it once
  drafts have no status), and Activity `status`/`direction`/`outcome`.
- **`get_lead`** returns the lead, its Contacts, its research record
  and its draft records (per channel, newest section identified).
- **`update_lead`** gains `Recommended Channel`.
- **Lead `phone` and `email`** remain optional `create_lead` arguments,
  stored where the tool has a home for them; a tool with no home skips
  them (as with company profile fields). Attio has none. Dedupe then
  runs on the keys the tool stores: Attio uses domain, then company
  name + `primary_location`. `create_lead` still rejects a call with
  none of `domain`, `phone`, `address`.
- **Approval invariant** restated: the agent never writes `Ready to
  Send` or any later status (guard-enforced, unchanged); drafts are
  append-only. `draft_only` is redefined to that. Inbound Activities
  and the "opt-out logged as an inbound Activity" instruction are
  removed: the operator records an opt-out by ticking `Do Not Contact`
  (one-way, unchanged), and the agent moves a ticked lead it works on
  to `Disqualified` with reason `opt-out`.

### Who changes what

- **Prospector** — `create_lead` as above; no phone/email on the
  pipeline entry under Attio.
- **Preparer** — one research section per run; fills company and person
  fields (empty only). Records the main phone and general inbox as
  listing findings with URLs.
- **Approacher** — `log_draft` per reachable channel, sets
  `recommended_channel`. Reachability: `call` needs a sourced phone on
  the chosen Contact or a main line recorded in the research with its
  URL; `email` needs a contact email or a general inbox recorded in the
  research with its URL; `linkedin` unchanged (the Contact's own
  profile). The "bounced Activity" rule goes away: the operator removes
  a bad address from the person.
- **send-digest** — Review lists each lead's `recommended_channel` and
  the channels with a draft note; the call number comes from the Call
  note. The "opt-out logged but not flagged" check goes. Duplicate
  check uses domain (and phone where the tool stores one).
- **write-cold-email / write-linkedin-touch / write-call-opener** — log
  with `log_draft`.
- **Attio tool** — `usage.md`, `bootstrap.py`, `guard.yaml`, probe and
  `## Setup` per this design. Bootstrap stops creating the research and
  outreach lists and the four removed pipeline attributes, and adds
  `recommended_channel`; it still never deletes anything.
- **HubSpot tool** — follows the contract: research and drafts become
  Notes on the company with the same titles and section format (a
  HubSpot note can't be appended through the guard-safe path, so each
  section is its own Note, titled with the channel and date, body
  `forbid: update`). HubSpot Tasks are no longer used for drafts.
  `sp_recommended_channel` added.
- **evals/cases.md** — cases that use `update_activity`,
  `query_activities` or Activity status (4, 5, 11, 14, 15 and the
  degradation check) are rewritten against notes and statuses; add a
  case: a redraft appends and never rewrites; a second run never
  creates a second note.

### Guard (`capabilities/crm/tools/attio/guard.yaml`)

- Allow `create-note`, `update-note`, `search-notes-by-metadata`,
  `get-note-body` (reads are already allowed by glob).
- `update-note`: `only_keys` at `$` = `note_id`, `operation`; at
  `operation` = `type`, `content`; a rule that `type` may only be
  `append`. No `updated_title`, no prepend. `delete-note` stays denied
  by the existing `*delete*` deny.
- `create-note` on companies only is an **instruction**, not a guard
  rule: the Standard's rules see attribute maps, not a top-level
  argument's value, and a note on the wrong record is harmless (no
  delete, no send). *(My call, from the builder check: the alternative
  is a bindings pin or a Standard change, too heavy for this.)*
- Pipeline rules unchanged (`stage` agent values, `do_not_contact` one
  way); `status` and `draft_body` rules go with the outreach list.
- `covers` stays `[draft_only, dnc_one_way, no_delete]` under the
  redefined `draft_only`.

### Migration (live Webspenser instance, then the README note)

The build ships the package and the procedure (README "Upgrading from
7.3"). Running it on the live workspace is a separate, operator-approved
step, done right after upgrading and **before the next scheduled run**:
a 7.4 run first would create the notes and the migration would then
have to append older dates below newer ones. *(My call.)* One
interactive pass, inside the guard:

1. Add `recommended_channel` (bootstrap or by hand).
2. For each company with entries in `sales_partner_research`: create
   "Sales Partner · Research" with one section per original date, from
   the entries' type, date, summary, source URL and hook.
3. For each company with non-voided entries in
   `sales_partner_outreach`: create the channel notes from the newest
   draft per channel (`recommended:` summary → recommended section),
   and set `recommended_channel`.
4. Pipeline `phone`/`email`: where the number or address belongs to a
   linked person and that person's field is empty, fill it there;
   otherwise it is already in the listing and is recorded in the
   research note as a listing finding. Nothing is lost that isn't
   re-sourceable.
5. Then the operator archives the two lists and the four pipeline
   attributes in Attio (archived data stays recoverable).

Live state on 2026-10-16: research entries for the researched leads
(latest 2026-10-15), outreach drafts for Corral Cooling and HTO
Plumbing (2026-10-05), 18 pipeline entries.

## Left to the builder

- How `get_lead` identifies the newest section (split on the header
  line).
- Guard YAML spelling for the note rules within the Standard's
  grammar; if the grammar can't express "`operation.type` is
  `append`", raise it before building rather than weakening the rule.
- HubSpot details within the contract above.
- Test and eval wording.

## Acceptance

On the Webspenser Attio workspace, after migration and one
prospect → prepare → approach run:

- Only `sales_partner_pipeline` receives writes; the two archived lists
  get none.
- A researched company shows exactly one "Sales Partner · Research"
  note and one note per drafted channel; a second Preparer or Approacher
  run appends a dated section to the same notes.
- The company's built-in fields and the people's contact fields are
  filled where sourced; nothing previously set was changed.
- The pipeline entry has no phone, email, address or location; a
  re-found business with a website is deduped on its domain.
- A guard test refuses `update-note` with `prepend` and with
  `updated_title`.
