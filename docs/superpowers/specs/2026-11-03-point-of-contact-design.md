# Point of contact for each lead: design

Date: 2026-11-03. Scope: sales-partner only. No Agent Standard change is
expected.

## Why

The operator's next funnel step is email outreach. An n8n workflow reads
each lead on the pipeline list and prepares the data to import into the
operator's email outreach platform. To do that it needs one person per
lead to send to. Today a lead can have several Contacts (people), each
tagged decision-maker, influencer or gatekeeper, and nothing says which
one the email goes to.

## Goals

- Every **new** lead the Preparer researches gets one **point of
  contact**, a new field on the lead (in Attio, on the
  `sales_partner_pipeline` list entry).
- **Who it is.** These rules are the operator's:
  - Only a person with an email address in their email field is
    eligible. Verified and unverified emails both count. A
    pattern-guessed address never sits in the email field
    (`capabilities/crm/contract.md`, `upsert_contact`), so guesses are
    already excluded.
  - With one eligible person, that person is the point of contact.
  - With more than one, the **most senior** wins: owner, founder,
    owner-operator, general manager and so on.
  - Having an email beats seniority. A GM with an email beats an owner
    without one. An owner with an unverified email beats a gatekeeper
    with a verified one.
- **A manual choice is never overwritten.** If the operator sets or
  changes the point of contact by hand, the agent leaves it alone. The
  only exception is when the operator explicitly tells the agent, in a
  session, to change it.

## Non-goals

- **No backfill.** Leads that exist today, at any stage, are not touched.
  The operator sets theirs by hand (decided 2026-11-03).
- No change to the approval invariant. Nothing is written to a lead at
  `Approved` or later.
- No new searching for people or emails. The pick uses the Contacts that
  research already wrote.
- No change to how n8n or the email platform work. That side is the
  operator's.

## Anti-goals

- **A point of contact with no email.** The field exists so an email can
  be sent. An empty field is better than a person the platform can't
  reach.
- **Overwriting the operator's choice.**
- A point of contact who isn't one of this lead's Contacts.

## How it is picked

These are our calls, built on the operator's rules above.

1. **When.** At the end of research, after the Contacts are written and
   before `write-talking-points` (see Talking points, below). A lead that goes to
   `Disqualified` gets none. A lead marked Do Not Contact gets none.
2. **Eligible.** The lead's Contacts with a non-empty email field. A
   Contact row that isn't a named person, such as a generic `info@`
   inbox written as a gatekeeper, is not eligible. The email platform
   addresses people by name.
3. **Seniority** comes from the job title the source gave, not from the
   decision-maker / influencer / gatekeeper role. Ranked from most to
   least senior:
   1. owner, co-owner, owner-operator, founder, co-founder, president,
      CEO, principal, managing partner;
   2. general manager, managing director, COO, partner;
   3. other managers and directors (office manager, operations manager,
      service manager);
   4. everyone else.
   A gatekeeper can therefore be the point of contact when they are the
   only eligible person.
4. **Ties** within a rank: a `Verified` email wins. If still tied, the
   person whose title best matches `context/icp.md`'s Target roles wins.
   If still tied, the earliest-written Contact wins.
5. **None eligible.** The field stays empty, and the stage reason says
   `no point of contact: no contact has an email`.
6. **Re-picks.** An interactive re-research or continue run on a lead at
   `Researched` may add Contacts. The pick is then made again, but only
   when the field still holds the agent's own last pick, or when it is
   empty and the agent has never recorded a pick for the lead (see
   Manual choices). This is our call.
   - **A field the operator cleared stays cleared.** If the agent
     recorded a pick and the field is now empty, the operator chose
     "nobody". The agent leaves it alone.
   - **Older leads.** A lead from before 8.4 that the operator asks to
     re-research, and whose field is still empty, gets a pick. Nothing
     is overwritten, and the operator asked for the run. This is not a
     backfill: no run goes looking for old leads.

The ranking and the tie rules are written as a skill, or as a section of
`find-decision-makers`. That's the builder's call.

## Manual choices

The agent has to tell its own pick from the operator's. It records each
pick it makes. When the field holds anyone other than the agent's last
recorded pick, it is the operator's, and the agent never changes it
unless the operator explicitly asks in a session. How the pick is
recorded is the builder's call. It could be a ledger event with the
`contact_id`, or a small agent-written field next to the point of
contact.

## CRM changes

- **Contract.** `update_lead` accepts `point_of_contact`, a
  `contact_id` or empty. It rejects a `contact_id` that isn't one of the
  lead's linked Contacts. `get_lead` returns it.
- **Attio.** There is a new attribute on `sales_partner_pipeline`,
  `point_of_contact`, a record-reference to `people`. A suggested
  companion is `point_of_contact_reason`, a text field such as
  `Owner; only contact with an email`, so the operator sees why that
  person was picked. That's the builder's call. `bootstrap.py`, the
  `## Setup` list and the guard's `writes` coverage are updated to
  match.
- **HubSpot.** Both tools follow one contract, so HubSpot gets the
  equivalent: a company property or an association label pointing at
  the Contact. Builder's call. The bootstrap and the guard are updated
  to match.
- **n8n.** The record reference gives n8n the Person's ID. n8n reads the
  name and email from that Person. Copying the email onto the list entry
  as well is not planned. The operator checks this against the
  workflow.

## Talking points follow the point of contact

This is the operator's decision, made 2026-11-03. When a lead has a
point of contact, `write-talking-points` writes `For:` for that person
and passes their `contact_id` to `log_talking_points`. With no point of
contact, it keeps today's rule: the decision-maker whose title best
matches Target roles, preferring a `Verified` one.

The pick therefore runs **before** `write-talking-points`, not just
before `update_stage`. An interactive "refresh talking points" request
reads the current point of contact, including one the operator set by
hand.

## Release checks

- Evals:
  - one eligible person;
  - owner without an email and GM with one;
  - owner with an unverified email against a gatekeeper with a verified
    one;
  - nobody with an email;
  - two owners, one verified;
  - a manual choice that survives a re-research;
  - an explicit operator request to change it;
  - a field the operator cleared stays empty after a re-research;
  - talking points `For:` names the point of contact, not a
    better-matching decision-maker without an email.
- A live check on the next few researched leads. The operator confirms
  each pick, and that n8n reads the field.
- Version: a minor bump (8.4.0). The README's upgrade steps re-run
  setup's tools step for the new list attribute.
