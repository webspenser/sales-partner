# CRM — Attio tool

Maps the contract (`../../contract.md`) onto Attio: which Attio objects and lists
hold each kind of data, the exact attribute slugs, the tool-call
procedure behind every operation, and the views the operator works
from.

The schema is created by `bootstrap.py` in this folder (see Probe). You can
re-run that script safely: it only adds what is missing and never deletes anything.
Attribute slugs below are used verbatim; do not rename them in Attio
without updating this file.

The workspace's object IDs for `companies` and `people` (used in
record-reference filters) are in the instance's `bindings/crm.md`,
written by the probe. `attio:` below means the connected Attio server's
tools, whatever their prefix.

## Why lists, not custom objects

Lists work on every Attio plan, including those with no custom-object
allowance, so every contract entity other than Contacts is an Attio **list** whose parent object is
`companies`:

| Contract entity | Attio home | Entries per company |
|---|---|---|
| Lead | `companies` record + one entry in list `sales_partner_pipeline` | exactly one |
| Research | list `sales_partner_research` | many, one per finding |
| Activity | list `sales_partner_outreach` | many, one per message or logged interaction |
| Contact | `people` record | — |

Attio list entries cannot be filtered by their parent record. Every
list therefore carries a `lead` record-reference attribute that holds
**the same company as the parent record**, and every write sets it.
Every read filters on `lead`, never on the parent.

**`lead_id` is the company's Attio `record_id`.** It identifies the
lead in every operation. The Pipeline entry is found from it by
filtering `sales_partner_pipeline` on `lead`.

## Schema

### Companies (standard object)

The tool writes only `name` and `domains`. `domains` is unique in
Attio, which gives dedupe rule 1 (domain) for free. Every pipeline
field lives on the list entry below, so the company record stays clean
for the rest of the CRM.

### List `sales_partner_pipeline` — the Leads table

| Slug | Type | Contract field |
|---|---|---|
| `lead` | record-reference → companies | the lead itself (equals the parent) |
| `stage` | status — exactly the eleven statuses | `Stage` |
| `stage_changed_at` | timestamp | `Stage Changed At` |
| `stage_reason` | text | the `reason` from the latest `update_stage` call |
| `score` | number | `Score` |
| `score_breakdown` | text | `Score Breakdown` |
| `industry` | text | `Industry` |
| `size` | text | `Size` |
| `location` | text | `Location` |
| `address` | text | `Address` (as sourced) |
| `phone` | text, E.164 | `Phone` |
| `email` | text | `Email` (general inbox only) |
| `source` | text | `Source` |
| `source_url` | text | `Source URL` |
| `next_action` | text | `Next Action` |
| `next_action_due` | date | `Next Action Due` |
| `revisit_on` | date | `Revisit On` — set by the operator for `Nurture`; the agent reads it, never writes it |
| `do_not_contact` | checkbox | `Do Not Contact` |

`industry` and `size` are text rather than select. Their values come
from the band names in `icp.md`, which the interview sets, and an
Attio select rejects any option that doesn't exist yet.

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
that must be kept.

### List `sales_partner_research` — the Research table

| Slug | Type |
|---|---|
| `lead` | record-reference → companies |
| `type` | select: news, funding, social, event, hire, listing, web_presence |
| `summary` | text |
| `source_url` | text |
| `date` | date |
| `hook` | text |

`summary` and `hook` mean exactly what the Research section of the
Airtable tool (`../airtable/usage.md`) says: `summary` is the finding, and `hook` is the
usable angle the Approacher opens with.

### List `sales_partner_outreach` — the Activities table

| Slug | Type |
|---|---|
| `lead` | record-reference → companies |
| `contact` | record-reference → people (optional) |
| `channel` | select: email, linkedin, call, other |
| `direction` | select: outbound, inbound |
| `date` | date |
| `summary` | text |
| `draft_body` | text |
| `status` | select: draft, sent, voided |
| `outcome` | text |

Drafts are Outreach entries at `status = draft`, one per channel, each
with its `date`. There is no separate drafts list: the operator reviews
a lead's whole plan from the lead (see **Review** below).

## Operations

Each operation below is a fixed sequence of Attio tool calls. Do the
checks in the order written, and **refuse the call** (report it and
write nothing) exactly where the contract says the operation rejects.

- **`create_lead`**
  1. Reject if `domain`, `phone`, and `address` are all empty.
  2. If `domain` is present: `attio:list-records` on `companies`,
     filtered on `domains` eq the bare domain. If a company matches and
     it has a Pipeline entry (filter `sales_partner_pipeline` on
     `lead`), return that company's `record_id` and stop.
  3. Otherwise, if `phone` is present, normalize it to E.164 per
     the contract and filter `sales_partner_pipeline` on `phone`
     eq that value. If an entry matches, return its `lead` and stop.
  4. Otherwise, if `address` is present, `attio:search-records` on
     `companies` by `company`. For each hit that has a Pipeline entry,
     compare the normalized company + address (lowercase, punctuation
     and suite numbers stripped). If one matches, return it and stop.
  5. No match: create the company. Use `attio:upsert-record` matching on
     `domains` when a domain exists (this reuses a company already in
     your CRM outside the pipeline), or `attio:create-record` with
     `name` only when there is no domain. Then
     `attio:add-record-to-list` on `sales_partner_pipeline` with
     `allow_duplicates: false` and these entry values: `lead` = the
     company, `stage` = `New`, `stage_changed_at` = now (ISO 8601 UTC,
     read right before the call),
     and the given fields. Return the company `record_id`.
- **`get_lead`** — `attio:get-records-by-ids` on `companies`, then
  the Pipeline entry, then Research and Outreach entries, each filtered
  on `lead` eq `{object_id: companies, record_id: lead_id}`. Contacts
  come from `attio:list-records` on `people`, filtered on `company` eq
  the same reference. If there is no company or no Pipeline entry,
  that is an error, not an empty record.
- **`update_stage`** — Reject a `stage` outside the eleven. Find the
  Pipeline entry by `lead`, then call `attio:update-list-entry-by-id`
  with `stage`, `stage_changed_at` = now (read the clock right before
  the call), and `stage_reason` = `reason`, **all in the same call**.
  Never write the reason into `next_action`; that field holds only a
  real task for the operator.
- **`update_lead`** — Reject if `fields` contains `stage` or
  `stage_changed_at`. Read the Pipeline entry first. If
  `do_not_contact` is already `true`, reject any `fields` that sets it
  to `false`. Otherwise, one `attio:update-list-entry-by-id` call.
  Write only the fields that change: an update that repeats unchanged
  fields (for example `do_not_contact: false`) can be refused by the
  guard.
- **`log_activity`** — Reject `status` other than `draft`. If
  `direction` is `outbound`, read the Pipeline entry and reject if
  `do_not_contact` is `true`. Then call `attio:add-record-to-list` on
  `sales_partner_outreach` with `allow_duplicates: true`,
  `parent_record_id` = `lead_id`, `lead` = the same company, `status` =
  `draft`, `date` = today, and the other fields. Return the new
  `entry_id` as `activity_id`. Never update an existing entry here.
- **`update_activity`** — Reject `status` other than `voided`.
  Call `attio:update-list-entry-by-id` on `sales_partner_outreach` with
  `status` and `outcome` only (never `draft_body`). This is the only
  write this tool ever makes to an existing Outreach entry.
- **`log_research`** — Reject an empty `source_url` or `hook`, or a
  `type` outside the seven values. Then `attio:add-record-to-list` on
  `sales_partner_research` with `allow_duplicates: true` and `lead` set.
- **`upsert_contact`** — Reject a `role` outside the three values.
  Find an existing person first. With an email: `attio:list-records`
  on `people`, filtered on `email_addresses` eq the email. Without
  one: `attio:search-records` on `people` by name, and pick the hit
  whose `job_title` equals `title` and whose `company` is this lead.
  If a person matches, update it with `attio:update-record` and leave
  `lead_source` out of the call. If none matches, create the person
  with `attio:create-record` and include `lead_source` = `Outbound`
  only when `bindings/crm.md` says `lead_source_outbound: yes`.
  Always set `company` = the lead. Set `sp_verified` to `true` only
  when the caller passes it.
- **`query_by_stage`** — `attio:list-records-in-list` on
  `sales_partner_pipeline`, filtered on `stage` eq the stage (when
  given), plus `next_action_due` lte the date for
  `next_action_due_before`. For `idle_days`: for each candidate lead,
  read its Outreach entries (filtered on `lead`, sorted by `date`
  desc, limit 1). Its idle age is now minus the later of that newest
  `date` and the lead's `stage_changed_at`. If the lead has no
  Activity, use `stage_changed_at`. Keep the lead if its idle age is
  greater than `idle_days`. Page with `offset` until the results run out.
- **`query_by_score`** — `attio:list-records-in-list` on
  `sales_partner_pipeline`, filtered on `score` gte `min_score` (and
  `stage` eq when given), sorted by `score` desc.
- **`query_activities`** — `attio:list-records-in-list` on
  `sales_partner_outreach`, filtered on `status` (and `direction`, and
  `channel` when given, and `date` gte `since` / lte `until`). Each entry's `lead` gives the
  company without a second call.

Every list entry carries Attio's own `created_at`. `send-digest`'s
"New leads scored" section uses the Pipeline entry's `created_at` as
the lead's Created Time.

## Approval invariant under Attio

Attio's `update-list-entry-by-id` can write any value to any
attribute, so the contract's guarantees are enforced by mechanism (approval and `dnc_one_way` only):

1. **`guard.yaml` in this folder**, enforced by the agent's guard policy
   engine before every Attio call inside an instance (the agent's
   `hooks/guard.sh` starts it; nothing to wire by hand):
   - an allow list: only the read tools, `whoami`, and the write tools
     this tool uses are callable; any other Attio tool is blocked;
   - `delete` and `merge` tools, and list configuration changes
     (`create-list`, `update-list`), are always denied;
   - `status` may only be written as `draft` on create and `voided` on
     update;
   - `stage` may only be written as `New` on create, and never as
     `Ready to Send`: only the operator approves a plan;
   - `draft_body` can't be changed after create;
   - `do_not_contact` may only be updated to `true`;
   - attribute keys given as IDs instead of slugs are refused.

   The operator's own edits in the Attio app never pass through it, so
   approving a plan (moving the lead to `Ready to Send`) stays
   operator-only.
2. **Nothing sends from the CRM.** The agent sends nothing; after the
   operator's approval, the owner's automations or the operator send the
   first touch.

## Views (the operator's interface)

Create these once in the Attio app. The Attio connector can't create
views.

- **Pipeline board** — on `sales_partner_pipeline`: a Kanban view
  grouped by `stage`.
- **Review** — on `sales_partner_pipeline`: filtered on `stage` is
  `Approach Drafted`. Open a lead to see its draft Outreach entries (one
  per channel: the `recommended:` one holds the full draft and its
  personalized statements, the others `statements` only) and show
  `do_not_contact`, so drafts for an opted-out lead are obvious. Edit a
  draft's `draft_body`, set any draft you don't want to `voided`, then
  move the lead to `Ready to Send`: that approves the lead.
- **Ready to Send** — on `sales_partner_pipeline`: filtered on `stage`
  is `Ready to Send`: approved, waiting for your automation or your own
  touch. The agent never acts on them; move a lead back to `Approach
  Drafted` to cancel.
- **My touches** — on `sales_partner_outreach`: filtered on `status` is
  `draft`, `direction` is `outbound` and `channel` is `linkedin` or
  `call`, sorted by `date`. Attio can't filter by the parent lead's
  stage, so act on a touch only for leads at `Ready to Send` or `Contacted`
  (open the lead first). These wait for you on their dates; set
  `status` to `sent` when you've done one.
- **Research Queue** — on `sales_partner_pipeline`: filtered on `stage`
  is `Scored`, sorted by `score`, highest first.
- **Due Today** — on `sales_partner_pipeline`: filtered on
  `next_action_due` on or before today.
- **Nurture** — on `sales_partner_pipeline`: filtered on `stage` is
  `Nurture`, sorted by `revisit_on`, soonest first. Leads you parked to
  come back to; the agent leaves them alone until that date.

## Probe

Setup runs these read-only calls when binding this tool, and writes
what they find to `bindings/crm.md` in the instance:

1. `attio:whoami` — record `workspace:`.
2. `attio:list-objects` — record `companies_object_id:` and
   `people_object_id:`.
3. `attio:list-list-attribute-definitions` on `sales_partner_pipeline`,
   `sales_partner_research`, and `sales_partner_outreach` — every slug
   in the Schema tables above must exist, and `stage` must hold the
   eleven statuses.
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

The probe needs these objects, lists and attributes to exist. Create them
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

**Three lists.** Lists, then New list. For each one: parent object
Companies, access: full access for the workspace. Then add its attributes
in the list's settings.

List `sales_partner_pipeline` (name `Sales Partner Pipeline`):

| Title | Slug | Type | Options |
|---|---|---|---|
| Stage | `stage` | Status | New, Scored, Researched, Approach Drafted, Ready to Send, Contacted, Engaged, Open Deal, Nurture, Customer, Disqualified |
| Stage Changed At | `stage_changed_at` | Timestamp | |
| Stage Reason | `stage_reason` | Text | |
| Score | `score` | Number | |
| Score Breakdown | `score_breakdown` | Text | |
| Industry | `industry` | Text | |
| Size | `size` | Text | |
| Location | `location` | Text | |
| Address | `address` | Text | |
| Phone | `phone` | Text | |
| Email | `email` | Text | |
| Source | `source` | Text | |
| Source URL | `source_url` | Text | |
| Next Action | `next_action` | Text | |
| Next Action Due | `next_action_due` | Date | |
| Revisit On | `revisit_on` | Date | |
| Do Not Contact | `do_not_contact` | Checkbox | |
| Lead | `lead` | Record reference, allowed object Companies | |

List `sales_partner_research` (name `Sales Partner Research`):

| Title | Slug | Type | Options |
|---|---|---|---|
| Type | `type` | Select | news, funding, social, event, hire, listing, web_presence |
| Summary | `summary` | Text | |
| Source URL | `source_url` | Text | |
| Date | `date` | Date | |
| Hook | `hook` | Text | |
| Lead | `lead` | Record reference, allowed object Companies | |

List `sales_partner_outreach` (name `Sales Partner Outreach`):

| Title | Slug | Type | Options |
|---|---|---|---|
| Channel | `channel` | Select | email, linkedin, call, other |
| Direction | `direction` | Select | outbound, inbound |
| Date | `date` | Date | |
| Summary | `summary` | Text | |
| Draft Body | `draft_body` | Text | |
| Status | `status` | Select | draft, sent, voided |
| Outcome | `outcome` | Text | |
| Contact | `contact` | Record reference, allowed object People | |
| Lead | `lead` | Record reference, allowed object Companies | |

Leave every attribute optional (not required, not unique, not multi-select).
When you are done, tell the agent and it probes again.

### Choice 2: run the script with an API key

`bootstrap.py` creates everything in Choice 1 and only adds what is
missing; it never deletes or renames anything.

1. In Attio, create an API key (Settings, then Developers) with these
   scopes, all read-write: `object_configuration`, `list_configuration`,
   `record_permission`, `list_entry`.
2. In your own terminal, set the key for that terminal only, and run the
   script. `read -rs` prompts for the key without showing it and writes
   nothing to your shell history. Paste the key at that prompt only;
   never paste it into the chat or a file:

       read -rs ATTIO_API_KEY && export ATTIO_API_KEY
       python3 "<package>/capabilities/crm/tools/attio/bootstrap.py"

   The environment variable the script reads is `ATTIO_API_KEY`.
3. Tell the agent it is done, and it probes again.
