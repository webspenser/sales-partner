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
holding the eleven statuses. People at the lead are **Contacts**
associated with that company. The research record and the draft
records are **Notes** associated with the company: one Note per
`log_research` call and one per `log_draft` call. HubSpot notes have no
title and can't be appended to through a guard-safe write, so each
section is its own Note, and its first lines say which record it
belongs to. This works on the free tier, keeps one record per business,
and leaves the Deals pipeline free for real deals. Tasks are not used.
All custom properties carry the `sp_` prefix and sit in the property
group `Sales Partner` (internal name `sales_partner`).

| Contract entity | HubSpot object | Associated with |
|---|---|---|
| Lead | Company | — |
| Contact | Contact | its company |
| Research record | Notes, one per research run | its company |
| Draft records | Notes, one per draft | its company and, when there is one, the contact |

**`lead_id` is the Company's record ID** (`hs_object_id`), and
`contact_id` the Contact's.

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

### Notes — the research and draft records

`hs_note_body` is rich text: one `<p>` per line, in the section format
of the Attio tool's **Reading notes from an automation**
(`../attio/usage.md`), so an automation reads both CRMs the same way. A
research Note's first line is `=== YYYY-MM-DD · research ===`, then one
block per finding (`Type:`, `Date:`, `Summary:`, `Source:`, `Hook:`). A
draft Note's first lines are `=== YYYY-MM-DD · draft ===` and
`Channel: email` (or `linkedin`, `call`), then `For: …`, the full draft
and the Personalized statements block. `hs_timestamp` is the moment of
the write.

The guard refuses any change to `hs_note_body` after create, so a draft
can't be rewritten after the operator read it: a redraft is a new Note.
An operator's edit in HubSpot may rewrap the lines in other tags, so on
read strip the HTML tags (treating `</p>`, `<br>` and `</div>` as line
breaks) before parsing the lines.

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
  `CONTACT`, `NOTE`), `filterGroups` (each
  `{"filters": [{"propertyName", "operator", "value"}], "associatedWith": [{"objectType", "operator", "objectIdValues"}]}`;
  groups are ORed, filters in a group ANDed), `properties`, `sorts`
  (one rule), `limit` (max 200) and `offset` for paging. It also needs
  `chatInsights`. Always check `total` and page with `offset` until the
  results run out. `hubspot:get_crm_objects` takes `objectType`,
  `objectIds` (up to 100 integers) and `properties`.

## Company profile fields

This tool skips the company profile fields (`description`,
`company_linkedin_url`, `facebook_url`, `instagram_url`) in this release;
the contract allows that. `address` is still written as the lead's
address.

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
         "sp_industry": "…", "sp_size": "…",
         "sp_source": "…", "sp_source_url": "…", "sp_email": "…",
         "sp_fit_score": "…", "sp_fit_breakdown": "…"}}]}}

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
2. `hubspot:search_crm_objects` on `CONTACT` and `NOTE`, each with
   `associatedWith: [{"objectType": "companies", "operator": "EQUAL", "objectIdValues": [lead_id]}]`
   and the Schema properties for that object, paging until the results
   run out. These are the lead's Contacts and its Notes. A Note whose
   first line is a `research` header is a research section; one whose
   first lines are a `draft` header and `Channel: <channel>` is a draft
   section for that channel. Any other Note is the operator's and is
   ignored. Sort each record's sections by `hs_timestamp`: the last is
   the newest.

### `update_stage`

Reject a `stage` outside the eleven. Then one call, with all three
properties **in the same update**:

    {"updateRequest": {"objects": [{"objectType": "companies", "objectId": <lead_id>, "properties": {
      "sp_stage": "<stage>", "sp_stage_changed_at": "<now, ISO 8601 UTC>", "sp_stage_reason": "<reason>"}}]}}

Read the clock right before the call. Never write the reason into
`sp_next_action`; that property holds only a real task for the
operator.

### `update_lead`

Write only the fields that change: an update that repeats unchanged
fields (for example `sp_do_not_contact` as `false`) can be refused by
the guard.

Reject if `fields` contains `stage`, `sp_stage`, or
`sp_stage_changed_at`. Read the company first
(`hubspot:get_crm_objects`, property `sp_do_not_contact`). If it is
already `true`, reject any `fields` that sets it to `false`. Otherwise
one `updateRequest` on `companies` with the mapped properties. Setting
the flag is `"sp_do_not_contact": "true"`.

### `log_draft`

1. Reject a `channel` other than `email`, `linkedin` or `call`.
2. `hubspot:get_crm_objects` on `COMPANY` with `objectIds: [lead_id]`
   and property `sp_do_not_contact`. Reject if it is `true`.
3. One create, never an update:

       {"createRequest": {"objects": [{"objectType": "notes",
         "properties": {"hs_note_body": "<p>=== YYYY-MM-DD · draft ===</p><p>Channel: <channel></p><p>For: …</p><p><draft lines></p>",
           "hs_timestamp": "<now, ISO 8601 UTC>"},
         "associations": [{"targetObjectType": "COMPANY", "targetObjectId": <lead_id>},
                          {"targetObjectType": "CONTACT", "targetObjectId": <contact_id>}]}]}}

   Drop the contact association when there is no `contact_id`.

### `log_research`

Reject the call if any finding has an empty `source_url` or `hook`, or a
`type` outside the seven values. Then one Note for the whole run:

    {"createRequest": {"objects": [{"objectType": "notes",
      "properties": {"hs_note_body": "<p>=== YYYY-MM-DD · research ===</p><p>Type: …</p><p>Date: …</p><p>Summary: …</p><p>Source: …</p><p>Hook: …</p>…",
                     "hs_timestamp": "<now, ISO 8601 UTC>"},
      "associations": [{"targetObjectType": "COMPANY", "targetObjectId": <lead_id>}]}]}}

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
`idle_days`: keep a lead when now minus its `sp_stage_changed_at` is
greater than `idle_days`.
Page with `offset` until the results run out; apply `limit` last.

### `query_by_score`

Reject a `score` other than `fit` or `approach`.
`hubspot:search_crm_objects` on `COMPANY`, filters `sp_fit_score` (for
`fit`) or `sp_approach_score` (for `approach`) `GTE` `min_score` (and
`sp_stage` `EQ` the stage when given), sorted by that property
`DESCENDING`. Page with `offset` until the results run out; apply
`limit` last.

Every record carries HubSpot's own `createdate`. `send-digest`'s "New
leads scored" section uses the company's `createdate` as the lead's
Created Time.

## Approval invariant under HubSpot

`manage_crm_objects` can write any value to any property, so the
contract's guarantees are enforced by mechanism (approval, append-only
drafts and `dnc_one_way`):

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
   - `hs_note_body` and `hs_timestamp` may not be changed after
     create, so a draft or a research section is never rewritten or
     re-ordered (`draft_only`);
   - `hs_task_status`, `hs_task_body` and `hs_task_completion_date` are
     forbidden outright: the agent uses no Tasks, so the operator's own
     Tasks are out of its reach;
   - `sp_stage` may only be created as `New`, and never written as
     `Ready to Send`: only the operator approves a lead.
     `hs_pipeline_stage` and `hs_pipeline` are forbidden to the agent
     outright (`forbid: true`), on create or update;
   - `sp_do_not_contact` may only be updated to `true` (`dnc_one_way`).

   The operator's own edits in HubSpot never pass through it, so
   approving a lead stays operator-only.
2. **Nothing sends from the CRM.** The agent sends nothing to prospects; after the
   operator's approval, the owner's workflows or the operator send the
   first touch. HubSpot's email and marketing tools are not on the allow
   list.

## Views (the operator's interface)

Create these once in HubSpot. The connector can't create views.

- **Review** — Companies filtered on `sp_stage` is `Approach Drafted`.
  Open a company to read its research and draft Notes (one draft Note
  per channel, a full draft and its personalized statements each) and
  `Do Not Contact` (`sp_do_not_contact`), then move the company to
  `Ready to Send`: that approves the lead.
- **Ready to Send** — Companies filtered on `sp_stage` is
  `Ready to Send`: approved, waiting for your workflow or your own
  touch. The agent never acts on them; move a company back to `Approach
  Drafted` to cancel.
- **Pipeline** — a Companies view grouped (or a board) by
  `Sales Partner stage` (`sp_stage`), filtered on `sp_stage` is known.
- **Research Queue** — Companies filtered on `sp_stage` is `Scored`,
  sorted by `Fit score`, highest first.
- **Approach Queue** — Companies filtered on `sp_stage` is `Researched`,
  sorted by `Approach score`, highest first.
- **Due Today** — Companies filtered on `Next action due` on or before
  today.
- **Nurture** — Companies filtered on `sp_stage` is `Nurture`, sorted
  by `Revisit on`, soonest first. Leads you parked to come back to; the
  agent leaves them alone until that date.

## Probe

Setup runs these read-only calls when binding this tool, and writes
what they find to `bindings/crm.md` in the instance:

1. `hubspot:get_user_details` — record `hub_id:` (the `hubId` /
   `accountId`). `COMPANY`, `CONTACT` and `NOTE` must each
   show `write: AVAILABLE`; report any that don't.
2. `hubspot:get_properties`:
   - on `companies`, `["sp_stage", "sp_stage_changed_at", "sp_do_not_contact",
     "sp_fit_score", "sp_fit_breakdown", "sp_approach_score", "sp_approach_breakdown"]`:
     all seven exist, and `sp_stage` has the eleven status options;
   - on `contacts`, `["sp_role"]`: it has the three role options;
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
probe again. Notes need no custom fields.

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
| `sp_stage` | Sales Partner stage | Dropdown select | New, Scored, Researched, Approach Drafted, Ready to Send, Contacted, Engaged, Open Deal, Nurture, Customer, Disqualified |
| `sp_stage_changed_at` | Stage changed at | Date and time picker | |
| `sp_stage_reason` | Stage reason | Multi-line text | |
| `sp_fit_score` | Fit score | Number | |
| `sp_fit_breakdown` | Fit breakdown | Multi-line text | |
| `sp_approach_score` | Approach score | Number | |
| `sp_approach_breakdown` | Approach breakdown | Multi-line text | |
| `sp_industry` | Industry (Sales Partner) | Single-line text | |
| `sp_size` | Size | Single-line text | |
| `sp_source` | Source | Single-line text | |
| `sp_source_url` | Source URL | Single-line text | |
| `sp_email` | General inbox | Single-line text | |
| `sp_next_action` | Next action | Single-line text | |
| `sp_next_action_due` | Next action due | Date picker | |
| `sp_revisit_on` | Revisit on | Date picker | |
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
