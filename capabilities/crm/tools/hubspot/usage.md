# CRM — HubSpot tool

Maps the contract (`../../contract.md`) onto HubSpot: which HubSpot
objects hold each kind of data, the exact property names, the tool-call
procedure behind every operation, and the views the operator works from.

The custom properties (on Companies and Contacts only) are listed in
`## Setup`. Create them by hand, or
run `bootstrap.py` in this folder. The script only adds what is missing
and never deletes anything. Property names below are used verbatim; do
not rename them in HubSpot without updating this file.

`hubspot:` below means the connected HubSpot server's tools, whatever
their prefix (for example `mcp__claude_ai_HubSpot__search_crm_objects`).

## Data model

Every lead is a HubSpot **Company**, with a custom `sp_stage` dropdown
holding the twelve stages. People at the lead are **Contacts**
associated with that company. Each research finding is a **Note**
associated with the company. Each outreach draft or logged interaction
(an Activity) is a **Task** associated with the company and, when there
is one, the contact. A Task's contract `status` lives in HubSpot's
built-in task status (`hs_task_status`), because the free tier allows no
custom properties on Tasks. This works on the free tier, keeps one
record per business, and leaves the Deals pipeline free for real deals.
All custom properties carry the `sp_` prefix and sit in the property
group `Sales Partner` (internal name `sales_partner`).

| Contract entity | HubSpot object | Associated with |
|---|---|---|
| Lead | Company | — |
| Contact | Contact | its company |
| Research | Note | its company |
| Activity | Task (built-in fields only; status in `hs_task_status`) | its company and contact |

**`lead_id` is the Company's record ID** (`hs_object_id`).
`activity_id` is the Task's ID, `research_id` the Note's, and
`contact_id` the Contact's.

## Schema

### Company — the Leads table

| Property | Type | Contract field |
|---|---|---|
| `name` | native | `company` |
| `domain` | native | `domain` (bare, no `https://` or `www.`) |
| `phone` | native, written as E.164 | `phone` |
| `address`, `city`, `state`, `zip`, `country` | native | `address`, as sourced, split into its parts |
| `sp_stage` | dropdown, the twelve stages | `Stage` |
| `sp_stage_changed_at` | datetime | `Stage Changed At` |
| `sp_stage_reason` | multi-line text | the `reason` from the latest `update_stage` |
| `sp_score` | number | `Score` |
| `sp_score_breakdown` | multi-line text | `Score Breakdown` |
| `sp_industry` | text | `Industry` |
| `sp_size` | text | `Size` |
| `sp_location` | text | `Location` |
| `sp_source` | text | `Source` |
| `sp_source_url` | text | `Source URL` |
| `sp_email` | text | `Email` (the general inbox only) |
| `sp_next_action` | text | `Next Action` |
| `sp_next_action_due` | date | `Next Action Due` |
| `sp_do_not_contact` | checkbox (`true` / `false`) | `Do Not Contact` |

`sp_stage` option values are exactly the contract's stage names: `New`,
`Scored`, `Researched`, `Approach Drafted`, `Contacted`, `Replied`,
`Call Scheduled`, `Call Held`, `Following Up`, `Won`, `Lost`,
`Disqualified`.

### Contact — the Contacts table

| Property | Contract field |
|---|---|
| `firstname`, `lastname` | `name`, split at the last space |
| `jobtitle` | `title` |
| `email` | `email` |
| `phone` | `phone` (a person's direct line only) |
| `hs_linkedin_url` | `linkedin_url` |
| `sp_role` | `role`: `decision-maker` / `influencer` / `gatekeeper` |
| `sp_verified` | `verified` (`true` / `false`) |
| `sp_notes` | `notes` |

### Note — the Research table

`hs_note_body` holds five labelled lines, one `<p>` each:

    <p>Type: news</p><p>Summary: …</p><p>Source URL: https://…</p><p>Date: 2026-09-30</p><p>Hook: …</p>

`hs_timestamp` is the research `date` (ISO 8601). `type` is one of news,
funding, social, event, hire, listing, web_presence.

### Task — the Activities table

Every field is a built-in Task property; Tasks need no custom fields.

| Property | Contract field |
|---|---|
| `hs_task_subject` | `subject`: a short title, `<channel> <direction> — <company>` |
| `hs_task_body` | rich text: `direction`, `summary` and `outcome` as labelled `<p>` lines, then `draft_body` (below) |
| `hs_timestamp` | the due date / `Date` (set to now on create) |
| `hs_task_type` | `channel`: `EMAIL` for email, `CALL` for call, `LINKED_IN_MESSAGE` for linkedin (`LINKED_IN_CONNECT` for a connection note), `TODO` for other |
| `hs_task_status` | `status`, mapped below |
| `hs_task_priority` | `direction`: `HIGH` for outbound, `NONE` for inbound. This is the source of truth for direction |

`status` maps onto HubSpot's built-in task status:

| Contract `status` | `hs_task_status` | Who sets it |
|---|---|---|
| `draft` | `NOT_STARTED` | the agent, on create only (omitting the field also yields `NOT_STARTED`) |
| `approved` | `IN_PROGRESS` or `WAITING` | the operator only |
| `sent` | `COMPLETED` | the operator only |
| `voided` | `DEFERRED` | the agent, the only status it may update to |

`hs_task_body` is rich text, so it starts with labelled lines, one
`<p>` each (as Research Notes do), then the draft:

    <p>Direction: outbound</p><p>Summary: <summary></p><p><draft_body></p>

`update_activity` appends an `Outcome: <outcome>` line after `Summary:`.
An operator's edit in HubSpot may rewrap these lines in other tags, so
on read strip the HTML tags (treating `</p>`, `<br>` and `</div>` as line
breaks) before parsing the lines back into `summary` and `outcome`. The
`Direction:` line is kept for people to read; `direction` itself is read
from `hs_task_priority`.

Outbound drafts are Tasks with status Not started and priority High.
There is no separate drafts object: the approval queue must stay a
single view.

## Calling the connector

- **Writes.** Every write is one `hubspot:manage_crm_objects` call.
  Creates go under `createRequest.objects[]`, each with `objectType`,
  `properties` and optional `associations`
  (`[{"targetObjectType": "COMPANY", "targetObjectId": <id>}]`).
  Updates go under `updateRequest.objects[]`, each with `objectType`,
  `objectId` and `properties`. Property values are strings: write
  `"true"`, `"72"`, `"2026-09-30T14:05:00Z"`.
- **At most 10 objects per `manage_crm_objects` request.** Split larger
  batches.
- **`confirmationStatus`.** Interactive runs: follow the connector's confirmation step — on the first write show the change table and offer to skip confirmations for the session. Scheduled runs (the prompt starts `Scheduled run of`): pass `confirmationStatus: CONFIRMATION_WAIVED_FOR_SESSION`; the guard enforces the invariants.
- **Reads.** `hubspot:search_crm_objects` takes `objectType` (`COMPANY`,
  `CONTACT`, `NOTE`, `TASK`), `filterGroups` (each
  `{"filters": [{"propertyName", "operator", "value"}], "associatedWith": [{"objectType", "operator", "objectIdValues"}]}`;
  groups are ORed, filters in a group ANDed), `properties`, `sorts`
  (one rule), `limit` (max 200) and `offset` for paging. It also needs
  `chatInsights`. Always check `total` and page with `offset` until the
  results run out. `hubspot:get_crm_objects` takes `objectType`,
  `objectIds` (up to 100 integers) and `properties`.

## Operations

Each operation below is a fixed sequence of HubSpot tool calls. Do the
checks in the order written, and **refuse the call** (report it and
write nothing) exactly where the contract says the operation rejects.

### `create_lead`

Every search below asks for the properties
`["name", "domain", "phone", "address", "city", "state", "zip", "country", "sp_stage"]`.
When a search finds a match, apply **the `sp_stage` check**: if the
matched company has an `sp_stage`, it is already a lead, so return its
ID and stop. If it has no `sp_stage` (a company already in your CRM,
outside the pipeline), adopt it (step 7) and return its ID as `lead_id`.

1. Reject if `domain`, `phone`, and `address` are all empty.
2. If `domain` is present: `hubspot:search_crm_objects` on `COMPANY`
   with the filter `domain` `EQ` the bare domain. If a company matches,
   apply the `sp_stage` check.
3. Otherwise, if `phone` is present, normalize it to E.164 per the
   contract, then search `COMPANY` with `phone` `EQ` that value. If one
   matches, apply the `sp_stage` check.
4. Otherwise, if `address` is present, search `COMPANY` with
   `query: <company>`. Compare the normalized company + address
   (lowercase, punctuation and suite numbers stripped) against each
   hit. If one matches, apply the `sp_stage` check.
5. No match: create it.
6. `hubspot:manage_crm_objects` with

       {"createRequest": {"objects": [{"objectType": "companies", "properties": {
         "name": "<company>", "domain": "<domain>", "phone": "<E.164>",
         "address": "…", "city": "…", "state": "…", "zip": "…", "country": "…",
         "sp_stage": "New", "sp_stage_changed_at": "<now, ISO 8601 UTC>",
         "sp_industry": "…", "sp_size": "…", "sp_location": "…",
         "sp_source": "…", "sp_source_url": "…", "sp_email": "…",
         "sp_score": "…", "sp_score_breakdown": "…"}}]}}

   Read the clock right before the call. Leave out every empty value;
   never invent a placeholder score. Return the new company's ID.
7. **Adopting an existing company** (a match in step 2, 3, or 4 with no
   `sp_stage`). The company is the user's own record, so the update
   adds to it and never replaces anything. It writes only:
   - the `sp_*` properties from step 6, always including
     `"sp_stage": "New"` and `"sp_stage_changed_at": "<now, ISO 8601 UTC>"`;
   - a native field (`name`, `domain`, `phone`, `address`, `city`,
     `state`, `zip`, `country`) only when the search showed its current
     value as empty.

   **Never overwrite a native field that already has a value**, such as
   `phone` or `address`, even when the new value differs; leave it out
   of the update. Read the clock right before the call, then send
   `{"updateRequest": {"objects": [{"objectType": "companies", "objectId": <id>, "properties": {…}}]}}`
   and return the company's ID as `lead_id`.

### `get_lead`

1. `hubspot:get_crm_objects` on `COMPANY` with `objectIds: [lead_id]`
   and every Company property in the Schema. No record, or a record
   without `sp_stage`, is an error, not an empty record.
2. `hubspot:search_crm_objects` on `CONTACT`, `NOTE`, and `TASK`, each
   with `associatedWith: [{"objectType": "companies", "operator": "EQUAL", "objectIdValues": [lead_id]}]`
   and the Schema properties for that object. These are the lead's
   Contacts, Research, and Activities.

### `update_stage`

Reject a `stage` outside the twelve. Then one call, with all three
properties **in the same update**:

    {"updateRequest": {"objects": [{"objectType": "companies", "objectId": <lead_id>, "properties": {
      "sp_stage": "<stage>", "sp_stage_changed_at": "<now, ISO 8601 UTC>", "sp_stage_reason": "<reason>"}}]}}

Read the clock right before the call. Never write the reason into
`sp_next_action`; that property holds only a real task for the
operator.

### `update_lead`

Reject if `fields` contains `stage`, `sp_stage`, or
`sp_stage_changed_at`. Read the company first
(`hubspot:get_crm_objects`, property `sp_do_not_contact`). If it is
already `true`, reject any `fields` that sets it to `false`. Otherwise
one `updateRequest` on `companies` with the mapped properties. Setting
the flag is `"sp_do_not_contact": "true"`.

### `log_activity`

1. Reject a `status` other than `draft`.
2. If `direction` is `outbound`: `hubspot:get_crm_objects` on `COMPANY`
   with `objectIds: [lead_id]` and property `sp_do_not_contact`.
   Reject if it is `true`.
3. Build the body: `<p>Direction: <direction></p><p>Summary: <summary></p>`
   (and `<p>Outcome: <outcome></p>` when given), then `draft_body` in
   `<p>` paragraphs. Map `channel` to `hs_task_type` per the Schema and
   `direction` to `hs_task_priority`: `HIGH` for outbound, `NONE` for
   inbound.
4. One create, never an update, always at `NOT_STARTED`:

       {"createRequest": {"objects": [{"objectType": "tasks",
         "properties": {"hs_task_subject": "…",
           "hs_task_body": "<p>Direction: <direction></p><p>Summary: <summary></p><p><draft_body></p>",
           "hs_timestamp": "<now, ISO 8601 UTC>", "hs_task_type": "<EMAIL|CALL|LINKED_IN_MESSAGE|LINKED_IN_CONNECT|TODO>",
           "hs_task_priority": "<HIGH|NONE>", "hs_task_status": "NOT_STARTED"},
         "associations": [{"targetObjectType": "COMPANY", "targetObjectId": <lead_id>},
                          {"targetObjectType": "CONTACT", "targetObjectId": <contact_id>}]}]}}

   Drop the contact association when there is no `contact_id`. Return
   the new Task's ID as `activity_id`.

### `update_activity`

Reject a `status` other than `voided`. Read the Task
(`hubspot:get_crm_objects` on `TASK`, property `hs_task_body`), insert
a `<p>Outcome: <outcome></p>` line after the labelled lines at its top,
and send the full new body with the status:

    {"updateRequest": {"objects": [{"objectType": "tasks", "objectId": <activity_id>,
      "properties": {"hs_task_status": "DEFERRED", "hs_task_body": "<body with Outcome: line>"}}]}}

This is the only write this tool ever makes to an existing Task.

### `log_research`

Reject an empty `source_url` or `hook`, or a `type` outside the seven
values. Then:

    {"createRequest": {"objects": [{"objectType": "notes",
      "properties": {"hs_note_body": "<the five labelled lines>", "hs_timestamp": "<date, ISO 8601>"},
      "associations": [{"targetObjectType": "COMPANY", "targetObjectId": <lead_id>}]}]}}

Return the new Note's ID as `research_id`.

### `upsert_contact`

Reject a `role` outside decision-maker / influencer / gatekeeper. Find
an existing contact first:

1. With an `email`: `hubspot:search_crm_objects` on `CONTACT`, filter
   `email` `EQ` the email.
2. Without one: search `CONTACT` with filters `firstname` `EQ` and
   `lastname` `EQ` the split name, plus `jobtitle` `EQ` `title`, and
   `associatedWith` this company.

If a contact matches, update it (`updateRequest` on `contacts` with
`objectId`, plus an association to the company when it lacks one). If
none matches, create it:

    {"createRequest": {"objects": [{"objectType": "contacts",
      "properties": {"firstname": "…", "lastname": "…", "jobtitle": "…", "email": "…",
        "phone": "…", "hs_linkedin_url": "…", "sp_role": "<role>",
        "sp_verified": "false", "sp_notes": "…"},
      "associations": [{"targetObjectType": "COMPANY", "targetObjectId": <lead_id>}]}]}}

Set `sp_verified` to `"true"` only when the caller passes it. An
unverified pattern-guessed address goes in `sp_notes`, never in
`email`. Return the contact's ID.

### `query_by_stage`

Reject a call with no `stage` and neither filter. Then
`hubspot:search_crm_objects` on `COMPANY` with one filter group:
`sp_stage` `EQ` the stage (when given), plus `sp_next_action_due` `LTE`
the date (for `next_action_due_before`). With no stage, add
`sp_stage` `HAS_PROPERTY` so only pipeline companies return. For
`idle_days`: for each candidate, search `TASK` with `associatedWith`
that company, sorted by `hs_timestamp` `DESCENDING`, `limit: 1`; keep
the lead if it has no Task or the newest is older than `idle_days`.
Page with `offset` until the results run out; apply `limit` last.

### `query_by_score`

`hubspot:search_crm_objects` on `COMPANY`, filters `sp_score` `GTE`
`min_score` (and `sp_stage` `EQ` the stage when given), sorted by
`sp_score` `DESCENDING`, with `limit`.

### `query_activities`

Reject a `status` outside draft / approved / sent / voided, or a
`direction` other than outbound / inbound. Then
`hubspot:search_crm_objects` on `TASK`, mapping the contract status to
status filters: `draft` → `hs_task_status` `EQ` `NOT_STARTED`;
`approved` → `hs_task_status` `IN` with
`"values": ["IN_PROGRESS", "WAITING"]`;
`sent` → `EQ` `COMPLETED`; `voided` → `EQ` `DEFERRED`. When
`direction` is given, add `hs_task_priority` `EQ` `HIGH` (outbound) or
`NONE` (inbound) to the same filter group. Add
`hs_timestamp` `GTE` `since` and `hs_timestamp` `LTE` `until` when
given, request `hs_task_body` and `hs_task_priority`, and sort by
`hs_timestamp`. Read each Task's `direction` from `hs_task_priority`
(`HIGH` = outbound, anything else = inbound). For each Task's lead, search `COMPANY` with
`associatedWith: [{"objectType": "tasks", "operator": "EQUAL", "objectIdValues": [<task id>]}]`
and properties `["name", "sp_stage"]`.

Every record carries HubSpot's own `createdate`. `send-digest`'s "New
leads scored" section uses the company's `createdate` as the lead's
Created Time.

## Approval invariant under HubSpot

`manage_crm_objects` can write any value to any property, so the
contract's guarantees are enforced by mechanism:

1. **`guard.yaml` in this folder**, enforced by the agent's guard
   policy engine before every HubSpot call inside an instance:
   - an allow list: only the read tools and `manage_crm_objects` are
     callable. Schema tools (`manage_custom_properties`,
     `manage_custom_pipelines`), marketing tools and every other
     HubSpot tool are blocked;
   - any `*delete*` or `*merge*` tool is always denied, and
     `manage_crm_objects` has no delete operation, so nothing is ever
     deleted (`no_delete`);
   - values under `createRequest.objects[].properties` are checked as
     creates, and values under `updateRequest.objects[].properties` as
     updates, even in one call. The connector's `manage_crm_objects`
     accepts only those two request shapes, so there is no other place
     for values to sit;
   - `hs_task_status` may only be created as `NOT_STARTED` and updated
     to `DEFERRED` (`draft_only`). Creating a Task with no status also
     yields `NOT_STARTED`. The Task Pipeline's stages mirror the
     statuses, so `hs_pipeline_stage`, `hs_pipeline` and
     `hs_task_completion_date` are forbidden to the agent outright
     (`forbid: true`): it may never write them, on create or update;
   - `sp_do_not_contact` may only be updated to `true` (`dnc_one_way`).

   The operator's own edits in HubSpot never pass through it, so
   approving and sending stay operator-only.
2. **Nothing can send.** Email goes through the `email_drafts`
   capability, whose tool blocks send tools. HubSpot's email and
   marketing tools are not on the allow list.

## Views (the operator's interface)

Create these once in HubSpot. The connector can't create views.

- **Awaiting Approval** — the approval queue. A Tasks view filtered on
  status is Not started **and** priority is High (outbound), sorted by
  due date. To approve a draft, edit the task notes if needed and move
  it to In progress (or Waiting); send it yourself, then mark it
  Completed. Deferred tasks are voided drafts. If you change a task's
  priority by hand, it only moves between views; nothing is sent.
- **Pipeline** — a Companies view grouped (or a board) by
  `Sales Partner stage` (`sp_stage`), filtered on `sp_stage` is known.
- **Research Queue** — Companies filtered on `sp_stage` is `Scored`,
  sorted by `Score`, highest first.
- **Due Today** — Companies filtered on `Next action due` on or before
  today.
- **Stalled** — the digest's Stalled section, which uses
  `query_by_stage` with `idle_days`, is the source of truth.

## Probe

Setup runs these read-only calls when binding this tool, and writes
what they find to `bindings/crm.md` in the instance:

1. `hubspot:get_user_details` — record `hub_id:` (the `hubId` /
   `accountId`). `COMPANY`, `CONTACT`, `TASK`, and `NOTE` must each
   show `write: AVAILABLE`; report any that don't.
2. `hubspot:get_properties`:
   - on `companies`, `["sp_stage", "sp_stage_changed_at", "sp_do_not_contact"]`:
     all three exist, and `sp_stage` has the twelve stage options;
   - on `contacts`, `["sp_role"]`: it has the three role options;
   - on `tasks`, `["hs_task_status", "hs_task_type", "hs_task_priority"]`:
     `hs_task_status` has `NOT_STARTED`, `IN_PROGRESS`, `COMPLETED` and
     `DEFERRED`, `hs_task_type` has `EMAIL`, `CALL` and `TODO`, and
     `hs_task_priority` has `HIGH` and `NONE`.
3. Report every missing property or option by name.

If step 2 finds anything missing, offer the two choices in `## Setup`.
Then probe again.

HubSpot writes properties by name, so the binding holds no field IDs.
`bindings/crm.md` looks like:

    # CRM binding — HubSpot
    hub_id: <id>

## Setup

The probe needs these company and contact properties to exist. Create
them yourself in HubSpot (Choice 1) or run the script (Choice 2). Then
probe again. Tasks need no custom fields; drafts use HubSpot's built-in task status.

### Choice 1: create them yourself in HubSpot

First create the property group: Settings → Properties → choose the
object → Groups → Create group, named `Sales Partner` (internal name
`sales_partner`). Do this for Companies and Contacts.

Then, for each row below: Settings → Properties → choose the object →
Create property. Put it in the group `Sales Partner`, give it the label
below, and set its internal name exactly as shown (open "Internal name"
before saving; it cannot be changed later). For a dropdown, add the
options in the order given, with each option's label and internal value
both equal to the text shown.

**Companies**

| Internal name | Label | Field type | Options |
|---|---|---|---|
| `sp_stage` | Sales Partner stage | Dropdown select | New, Scored, Researched, Approach Drafted, Contacted, Replied, Call Scheduled, Call Held, Following Up, Won, Lost, Disqualified |
| `sp_stage_changed_at` | Stage changed at | Date and time picker | |
| `sp_stage_reason` | Stage reason | Multi-line text | |
| `sp_score` | Score | Number | |
| `sp_score_breakdown` | Score breakdown | Multi-line text | |
| `sp_industry` | Industry (Sales Partner) | Single-line text | |
| `sp_size` | Size | Single-line text | |
| `sp_location` | Location | Single-line text | |
| `sp_source` | Source | Single-line text | |
| `sp_source_url` | Source URL | Single-line text | |
| `sp_email` | General inbox | Single-line text | |
| `sp_next_action` | Next action | Single-line text | |
| `sp_next_action_due` | Next action due | Date picker | |
| `sp_do_not_contact` | Do not contact | Single checkbox | Yes = `true`, No = `false` |

**Contacts**

| Internal name | Label | Field type | Options |
|---|---|---|---|
| `sp_role` | Sales role | Dropdown select | decision-maker, influencer, gatekeeper |
| `sp_verified` | Contact verified | Single checkbox | Yes = `true`, No = `false` |
| `sp_notes` | Contact notes | Multi-line text | |

When you are done, tell the agent and it probes again.

### Choice 2: run the script with an API key

`bootstrap.py` creates everything in Choice 1 and only adds what is
missing; it never deletes or renames anything.

1. In HubSpot, create a private app (Settings → Integrations → Private
   Apps → Create a private app) with these scopes:
   `crm.schemas.companies.read`, `crm.schemas.companies.write`,
   `crm.schemas.contacts.read`, `crm.schemas.contacts.write`,
   `crm.objects.companies.read`, `crm.objects.contacts.read`.
   Copy its access token.
2. In your own terminal, set the token for that terminal only, and run
   the script. `read -rs` prompts for the token without showing it and
   writes nothing to your shell history. Paste the token at that prompt
   only; never paste it into the chat or a file:

       read -rs HUBSPOT_TOKEN && export HUBSPOT_TOKEN
       python3 "<package>/capabilities/crm/tools/hubspot/bootstrap.py"

   The environment variable the script reads is `HUBSPOT_TOKEN`.
3. Tell the agent it is done, and it probes again. You can delete the
   private app afterwards; the agent never uses it.
