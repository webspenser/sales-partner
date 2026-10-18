# CRM — Attio tool

Maps the contract (`../../contract.md`) onto Attio: which Attio objects,
list and notes hold each kind of data, the exact attribute slugs, the
tool-call procedure behind every operation, and the views the operator
works from.

The schema is created by `bootstrap.py` in this folder (see Probe). You can
re-run that script safely: it only adds what is missing and never deletes anything.
Attribute slugs below are used verbatim; do not rename them in Attio
without updating this file.

The workspace's object IDs for `companies` and `people` (used in
record-reference filters) are in the instance's `bindings/crm.md`,
written by the probe. `attio:` below means the connected Attio server's
tools, whatever their prefix.

## Layout

The operator works from the **company record**. One list tracks which
companies are leads; everything else sits on the company and its people:

| Contract entity | Attio home |
|---|---|
| Lead (pipeline state) | one entry in list `sales_partner_pipeline` on the company |
| Company facts | the `companies` record, built-in attributes |
| Research record | the note `Sales Partner · Research` on the company |
| Talking Points record | the note `Sales Partner · Talking Points` on the company |
| Contact | a `people` record, `company` = the lead's company |

The list works on every Attio plan, including those with no custom-object
allowance. Attio list entries cannot be filtered by their parent record,
so the entry carries a `lead` record-reference attribute holding **the
same company as the parent record**; every write sets it and every read
filters on it.

**`lead_id` is the company's Attio `record_id`.** It identifies the
lead in every operation. The Pipeline entry is found from it by
filtering `sales_partner_pipeline` on `lead`.

## Schema

### Companies (standard object)

The tool writes `name` and `domains`, plus the contract's company
profile fields onto the company's own built-in attributes, so the
company page shows the basics. `domains` is unique in Attio, which gives
dedupe rule 1 (domain) for free. No custom attribute is added to
Companies.

| Contract field | Company attribute |
|---|---|
| `address`, else `location` | `primary_location` (written as one string, for example `1173 Broadway, Alameda, CA, 94501, US`, or `Alameda, CA, US` when only the city is sourced; Attio parses it) |
| `description` | `description` |
| `company_linkedin_url` | `linkedin` |
| `facebook_url` | `facebook` |
| `instagram_url` | `instagram` |

Read the company first (`attio:get-records-by-ids`) and write only the
attributes that are empty:
never overwrite a value Attio's enrichment or the operator already set. The contract's lead `phone` and `email` (the
business's main line and general inbox) have no home in this tool: they
are skipped here and recorded, with their source URLs, as `listing`
findings in the research note.

### List `sales_partner_pipeline` — the Leads table

| Slug | Type | Contract field |
|---|---|---|
| `lead` | record-reference → companies | the lead itself (equals the parent) |
| `stage` | status — exactly the ten statuses | `Stage` |
| `stage_changed_at` | timestamp | `Stage Changed At` |
| `stage_reason` | text | the `reason` from the latest `update_stage` call |
| `fit_score` | number | `Fit Score` |
| `fit_breakdown` | text | `Fit Breakdown` |
| `approach_score` | number | `Approach Score` |
| `approach_breakdown` | text | `Approach Breakdown` |
| `industry` | text | `Industry` |
| `segment` | select — the catalog's segment ids | `Segment` |
| `hero_offer` | select — the catalog's offer ids | `Hero Offer` |
| `offer_reason` | text | `Offer Reason` |
| `offer_evidence` | select — `strong`, `moderate`, `weak` | `Offer Evidence` |
| `research_anyway` | checkbox | `Research Anyway` — set by the operator only; the agent reads it, never writes it |
| `size` | text | `Size` |
| `source` | text | `Source` |
| `source_url` | text | `Source URL` |
| `next_action` | text | `Next Action` |
| `next_action_due` | date | `Next Action Due` |
| `revisit_on` | date | `Revisit On` — set by the operator for `Nurture`; the agent reads it, never writes it |
| `do_not_contact` | checkbox | `Do Not Contact` |

`industry` and `size` are text rather than select. Their values come
from the band names in `icp.md`, which the interview sets, and an
Attio select rejects any option that doesn't exist yet.

`segment` and `hero_offer` are selects whose options are the ids in the
YAML block of `context/offer-catalog.md`, so the options are the same
ids the catalog uses, and never the display names. `bootstrap.py` adds
the options and never removes any: an offer dropped from the catalog
stays selectable on the leads already matched to it.

### People (standard object) — the Contacts table

| Slug | Contract field |
|---|---|
| `name` | `Name` (personal-name: `"Last, First"`) |
| `job_title` | `Title` |
| `email_addresses` | `Email` |
| `phone_numbers` | `Phone` |
| `linkedin` | `LinkedIn URL` |
| `company` | `Lead` (record-reference to the company) |
| `sp_role` | `Role`: decision-maker / influencer / gatekeeper |
| `sp_verified` | `Verified` |
| `sp_notes` | `Notes` |
| `lead_source` | select, set to `Outbound` on create only, and only when `bindings/crm.md` says `lead_source_outbound: yes` |

The `sp_` prefix keeps these three apart from fields your other
workflows use on People.
The tool never writes those other fields, with one exception: every
person it **creates** gets `lead_source` = `Outbound` (only when
`bindings/crm.md` says `lead_source_outbound: yes`), because the
agent found them by prospecting rather than them coming in. It never
sets or changes `lead_source` on a person who already exists, since
that person may have arrived through an inbound source
that must be kept. The operator can add people to a company by hand;
the agent treats them like any other Contact.

### Notes — the research and talking points records

Each lead has at most one note per title, on the company:

| Title, exactly | Holds | Written by |
|---|---|---|
| `Sales Partner · Research` | one section per research run | `log_research` |
| `Sales Partner · Talking Points` | one section per set of talking points | `log_talking_points` |

A note is created with its first section and only ever appended to.
The newest section is at the bottom. The format is in **Reading notes
from an automation** below; it is the same whether the section was the
note's first or was appended.

## Operations

Each operation below is a fixed sequence of Attio tool calls. Do the
checks in the order written, and **refuse the call** (report it and
write nothing) exactly where the contract says the operation rejects.

- **`create_lead`**
  1. Reject if `domain`, `phone`, and `address` are all empty (the
     contract's rule; `phone` itself is not stored here).
  2. If `domain` is present: `attio:list-records` on `companies`,
     filtered on `domains` eq the bare domain. If a company matches and
     it has a Pipeline entry (filter `sales_partner_pipeline` on
     `lead`), return that company's `record_id` and stop.
  3. Otherwise, `attio:search-records` on `companies` by `company`. For
     each hit that has a Pipeline entry, compare the normalized
     company name + `primary_location` (lowercase, punctuation and suite
     numbers stripped) against the call's company and its `address`, or
     its `location` when there is no address. If one matches, return it
     and stop. This is the dedupe for a business with no website, even
     one whose listing shows no street address.
  4. No match: create the company. Use `attio:upsert-record` matching on
     `domains` when a domain exists (this reuses a company already in
     your CRM outside the pipeline), or `attio:create-record` with
     `name` only when there is no domain. Then
     `attio:add-record-to-list` on `sales_partner_pipeline` with
     `allow_duplicates: false` and these entry values: `lead` = the
     company, `stage` = `New`, `stage_changed_at` = now (ISO 8601 UTC,
     read right before the call), and the given pipeline fields. Then
     write `primary_location` and any company profile fields given
     (see Companies above) with `attio:update-record` on `companies`,
     empty attributes only. Return the company `record_id`.
- **`get_lead`** — `attio:get-records-by-ids` on `companies`, then
  the Pipeline entry (filtered on `lead` eq `{object_id: companies,
  record_id: lead_id}`). Contacts come from `attio:list-records` on
  `people`, filtered on `company` eq the same reference. Notes come from
  `attio:search-notes-by-metadata` (`parent_record_object: companies`,
  `parent_record_id: lead_id`, paging until the results run out); keep
  those whose title equals one of the two titles exactly, and read each
  with `attio:get-note-body`. When more than one note has the same
  exact title, use the oldest (earliest `created_at`): it is the one the
  agent appends to. Split a note into sections on its header lines; the
  last section is the newest, and a header with nothing after it (a
  write cut short) is skipped. If there is no company or no
  Pipeline entry, that is an error, not an empty record.
- **`update_stage`** — Reject a `stage` outside the ten. Find the
  Pipeline entry by `lead`, then call `attio:update-list-entry-by-id`
  with `stage`, `stage_changed_at` = now (read the clock right before
  the call), and `stage_reason` = `reason`, **all in the same call**.
  Never write the reason into `next_action`; that field holds only a
  real task for the operator.
- **`update_lead`** — Reject if `fields` contains `stage`,
  `stage_changed_at` or `research_anyway`. `segment`, `industry`,
  `hero_offer`, `offer_reason` and `offer_evidence` go to the Pipeline
  entry like any other lead field. To clear a select or text field (for
  example `hero_offer` and `offer_evidence` when every offer is ruled
  out), write it as `[]`: an entry value may be an array even for a
  single-value attribute, and an empty one removes the value. Read the Pipeline entry first. If
  `do_not_contact` is already `true`, reject any `fields` that sets it
  to `false`. Otherwise, one `attio:update-list-entry-by-id` call. Company
  profile fields in `fields` go to the company instead: one
  `attio:update-record` on `companies`, empty attributes only. `phone`
  and `email` in `fields` are skipped (no home here).
  Write only the fields that change: an update that repeats unchanged
  fields (for example `do_not_contact: false`) can be refused by the
  guard.
- **`log_research`** — Reject the call if any finding has an empty
  `source_url` or `hook`, or a `type` outside the seven. Build one
  research section (format below), then write it to the note titled
  `Sales Partner · Research` (see **Writing a section**).
- **`log_talking_points`** — Build one talking points section (format
  below), then write it to the note titled `Sales Partner · Talking
  Points` (see **Writing a section**): create the note with the header
  line, then append the rest; later calls only append. The call takes no
  channel argument.
- **Writing a section.** `attio:search-notes-by-metadata` on the company,
  paging with `limit: 100` and `offset` until the results run out (a
  company can hold many other notes, newest first), or reuse the note
  IDs `get_lead` found. Keep the notes whose title equals the wanted one,
  by exact title match (case and the `·` included; `Sales Partner ·
  research` or `Research` is the operator's own note and is never
  touched). None: create the note with the header line alone, then append
  the rest of the section: `attio:create-note` with `parent_object:
  companies`, `parent_record_id: lead_id`, the title, and the header
  line as `content`, then `attio:update-note` with the new `note_id` and
  `operation: {type: append, content: <the section's other lines>}`.
  Appended text is plain, one paragraph per line, so no line is ever
  reformatted as Markdown. One: `attio:update-note` appending the whole
  section. More than one (an operator copy, or a race):
  append to the oldest (earliest `created_at`) and never create another. Never pass
  `updated_title`, never prepend, never delete.
- **`upsert_contact`** — Reject a `role` outside the three values.
  Find an existing person first. With an email: `attio:list-records`
  on `people`, filtered on `email_addresses` eq the email. Without
  one: `attio:search-records` on `people` by name, and pick the hit
  whose `job_title` equals `title` and whose `company` is this lead.
  If a person matches, update it with `attio:update-record`, writing
  only attributes that are empty on the person (a later run fills in
  an email, phone or LinkedIn found since; it never replaces a value),
  and leave `lead_source` out of the call. If none matches, create the
  person with `attio:create-record` and include `lead_source` =
  `Outbound` only when `bindings/crm.md` says `lead_source_outbound:
  yes`. Always set `company` = the lead. Set `sp_verified` to `true`
  only when the caller passes it.
- **`query_by_stage`** — `attio:list-records-in-list` on
  `sales_partner_pipeline`, filtered on `stage` eq the stage (when
  given), plus `next_action_due` lte the date for
  `next_action_due_before`. For `idle_days`: keep a lead when now minus
  its `stage_changed_at` is greater than `idle_days`. When
  `research_anyway` is given, add a filter on `research_anyway` eq that
  boolean. Page with `offset` until the results run out.
- **`query_by_score`** — Reject a `score` other than `fit` or
  `approach`. `attio:list-records-in-list` on `sales_partner_pipeline`,
  filtered on `fit_score` (for `fit`) or `approach_score` (for
  `approach`) gte `min_score` (and `stage` eq when given), sorted by
  that attribute desc. Page with `offset` until the results run out;
  apply `limit` last.

The Pipeline entry carries Attio's own `created_at`. `send-digest`'s
"New leads scored" section uses it as the lead's Created Time.

## Reading notes from an automation

The note titles and the section format are fixed, so the operator's own
automations (for example an n8n workflow) can read them. They change
only with a version bump and an upgrade note in the README.

- Titles, exactly: `Sales Partner · Research`, `Sales Partner · Talking
  Points`.
- Every section starts with a header alone on its line:
  `=== YYYY-MM-DD · research ===` in the research note,
  `=== YYYY-MM-DD · talking points ===` in the Talking Points note.
- A research section holds one block per finding, each with the lines
  `Type:`, `Date:` (the finding's own date), `Summary:`, `Source:` (the
  URL) and `Hook:`, blocks separated by a blank line.
- A talking points section holds six labels, in this order: `For:`,
  `Offer:`, `Opener:`, `Points:`, `Avoid:` and `Contact routes:`. `For:`
  is `<person, title>` or `owner, name not found`; `Offer:` is the hero
  offer's name, or `none matched`; `Opener:` is one line, or exactly
  `Opener: unverified — no recent hook found` when research found no
  usable hook. `Points:`,
  `Avoid:` and `Contact routes:` are each followed by a list, one
  `- ` item per line; an empty list (no points, nothing to avoid, no
  contact route found) is the one line `- none`.
- Every line is plain text: no tables, no markdown that renders only in
  a note's first section.

To read the current talking points or research, list the notes on the company
(Attio API: notes filtered by parent record, paging until the results
run out), pick the title, and take the last header line and everything
after it. If more than one note has the exact title, use the oldest
(earliest `created_at`), the one the agent appends to. Skip a header
with nothing after it. To pick leads, list `sales_partner_pipeline`
entries filtered on `stage` = `Approved`, so only leads the operator
approved go out, and on `do_not_contact` is not true, so a lead the
operator opted out after approving is left out. A lead the operator
pushed through with `research_anyway` and that found no matching offer
has a Talking Points note whose `Offer:` line reads `none matched`.

## Approval invariant under Attio

Attio's `update-list-entry-by-id` can write any value to any
attribute, so the contract's guarantees are enforced by mechanism
(`approval_only`, `dnc_one_way` and `no_delete`):

1. **`guard.yaml` in this folder**, enforced by the agent's guard policy
   engine before every Attio call inside an instance (the agent's
   `hooks/guard.sh` starts it; nothing to wire by hand):
   - an allow list: only the read tools, `whoami`, `create-note`,
     `update-note` and the record and list-entry write tools this tool
     uses are callable; any other Attio tool is blocked;
   - `delete` and `merge` tools (including `delete-note`), and list
     configuration changes (`create-list`, `update-list`), are always
     denied;
   - `create-note` takes only `parent_object`, `parent_record_id`,
     `title` and `content`;
   - `update-note` takes only `note_id` and `operation`, and
     `operation` only `type` and `content`, with `type` = `append`: a
     note can't be prepended to, retitled or rewritten;
   - `stage` may only be written as `New` on create, and as `Scored`,
     `Researched` or `Disqualified` after; never as `Approved` or a later
     status: only the operator approves a lead;
   - `research_anyway` may not be written at all: it is the operator's;
   - `do_not_contact` may only be updated to `true`;
   - attribute keys given as IDs instead of slugs are refused.

   The operator's own edits in the Attio app never pass through it, so
   approving a lead (moving the lead to `Approved`) stays
   operator-only. "Notes go on companies only" is an instruction: the
   guard can't see which record a note is attached to, and a note on the
   wrong record sends nothing and deletes nothing.
2. **Nothing sends from the CRM.** The agent sends nothing to prospects; after the
   operator's approval, the owner's automations or the operator send the
   first touch.

## Views (the operator's interface)

The operator arranges Attio's screens. Suggested views on
`sales_partner_pipeline` (create them in the Attio app; the connector
can't):

- **Pipeline board** — a Kanban view grouped by `stage`.
- **Review** — filtered on `stage` is `Researched`, sorted by
  `approach_score`, highest first. Open a lead's company to read its
  research note and its Talking Points note, then
  move the lead to `Approved`: that approves it. Show `do_not_contact`, so an opted-out
  lead is obvious, and `segment`, `hero_offer`, `offer_reason` and
  `offer_evidence`.
- **Approved** — filtered on `stage` is `Approved`: approved, waiting
  for your workflow or your own touch. The agent never acts on them;
  move a lead back to `Researched` to cancel.
- **Research Queue** — filtered on `stage` is `Scored`, sorted by
  `fit_score`, highest first.
- **Due Today** — filtered on `next_action_due` on or before today.
- **Nurture** — filtered on `stage` is `Nurture`, sorted by
  `revisit_on`, soonest first. Leads you parked to come back to; the
  agent leaves them alone until that date.

## Probe

Setup runs these read-only calls when binding this tool, and writes
what they find to `bindings/crm.md` in the instance:

1. `attio:whoami` — record `workspace:`.
2. `attio:list-objects` — record `companies_object_id:` and
   `people_object_id:`.
3. `attio:list-list-attribute-definitions` on `sales_partner_pipeline`
   — every slug in its Schema table above must exist (including
   `segment`, `hero_offer`, `offer_reason`, `offer_evidence` and
   `research_anyway`), `stage` must hold the ten statuses, and `segment` and
   `hero_offer` must hold every segment id and offer id in
   `context/offer-catalog.md`.
4. `attio:list-attribute-definitions` on `people` — `sp_role`,
   `sp_verified`, and `sp_notes` must exist. Record
   `lead_source_outbound: yes` if `lead_source` exists with an
   `Outbound` option, otherwise `no`.

If step 3 or 4 finds anything missing, offer the two choices in `## Setup`.
Then probe again.

`bindings/crm.md` looks like:

    # CRM binding — Attio
    workspace: Acme
    companies_object_id: 1da534c1-…
    people_object_id: 77bbcd3e-…
    lead_source_outbound: no

## Setup

The probe needs these attributes and the list to exist. Create them
yourself in Attio (Choice 1) or run the script (Choice 2). Then probe again.

### Choice 1: create them yourself in Attio

Attribute names below are the title and the API slug (Attio shows the slug
when you create or edit an attribute). The slug must match exactly.

**People (standard object).** Settings, then Objects, then People, then
Attributes, then New attribute. Add three:

1. Title `Sales Role`, slug `sp_role`, type Select, options
   `decision-maker`, `influencer`, `gatekeeper`.
2. Title `Contact Verified`, slug `sp_verified`, type Checkbox.
3. Title `Contact Notes`, slug `sp_notes`, type Text.

**One list.** Lists, then New list: name `Sales Partner Pipeline`, slug
`sales_partner_pipeline`, parent object Companies, access: full access
for the workspace. Then add its attributes in the list's settings:

| Title | Slug | Type | Options |
|---|---|---|---|
| Stage | `stage` | Status | New, Scored, Researched, Approved, Contacted, Engaged, Open Deal, Nurture, Customer, Disqualified |
| Stage Changed At | `stage_changed_at` | Timestamp | |
| Stage Reason | `stage_reason` | Text | |
| Fit Score | `fit_score` | Number | |
| Fit Breakdown | `fit_breakdown` | Text | |
| Approach Score | `approach_score` | Number | |
| Approach Breakdown | `approach_breakdown` | Text | |
| Industry | `industry` | Text | |
| Segment | `segment` | Select | the segment ids in `context/offer-catalog.md` |
| Hero Offer | `hero_offer` | Select | the offer ids in `context/offer-catalog.md` |
| Offer Reason | `offer_reason` | Text | |
| Offer Evidence | `offer_evidence` | Select | strong, moderate, weak |
| Research Anyway | `research_anyway` | Checkbox | |
| Size | `size` | Text | |
| Source | `source` | Text | |
| Source URL | `source_url` | Text | |
| Next Action | `next_action` | Text | |
| Next Action Due | `next_action_due` | Date | |
| Revisit On | `revisit_on` | Date | |
| Do Not Contact | `do_not_contact` | Checkbox | |
| Lead | `lead` | Record reference, allowed object Companies | |

Leave every attribute optional (not required, not unique, not multi-select).
Notes need no setup. When you are done, tell the agent and it probes again.

### Choice 2: run the script with an API key

`bootstrap.py` creates everything in Choice 1 and only adds what is
missing; it never deletes or renames anything. It reads the Segment and
Hero Offer options from the instance's offer catalog before it makes any
API call. Run it from the instance folder, where the default
`context/offer-catalog.md` is found, or pass `--catalog <path>`. After
you change the catalog, run it again: re-running only adds the new
options. It also leaves the old stages `Approach Drafted` and `Ready to
Send` in place and prints a note; archive them by hand in Attio.

1. In Attio, create an API key (Settings, then Developers) with these
   scopes, all read-write: `object_configuration`, `list_configuration`,
   `record_permission`, `list_entry`.
2. In your own terminal, set the key for that terminal only, and run the
   script. `read -rs` prompts for the key without showing it and writes
   nothing to your shell history. Paste the key at that prompt only;
   never paste it into the chat or a file:

       read -rs ATTIO_API_KEY && export ATTIO_API_KEY
       python3 "<package>/capabilities/crm/tools/attio/bootstrap.py" --catalog context/offer-catalog.md

   The environment variable the script reads is `ATTIO_API_KEY`.
3. Tell the agent it is done, and it probes again.
