---
name: pick-point-of-contact
description: Use when a lead's Contacts are written and its talking points are next — picks the one person the operator's email outreach goes to (the most senior named Contact with an email) and writes them to the lead's point of contact, never overwriting a choice the operator made by hand.
---

The point of contact is the one person the operator's email outreach
goes to. A workflow outside the agent (n8n) reads it to build the import
for the operator's email platform, so the person has to be someone that
platform can reach: an email beats seniority. The talking points are
then written for this person (`write-talking-points`, `For:`).

## Input

- `lead_id`. Read the lead with CRM `get_lead`: its Contacts (each with
  `name`, `title`, `email`, `role`, `verified`) and its three point of
  contact fields (`capabilities/crm/contract.md`, Point of contact
  fields).
- `context/icp.md`'s Target roles section, for the tie rule.

The caller runs this only on a lead about to move to `Researched`, or
on one at `Researched` in an interactive request. Never on a lead that
is `Disqualified`, marked `Do Not Contact`, or at `Approved` or later.

## Returns

One of:
- `picked <contact_id>`, after one `update_lead` call;
- `none eligible`, with nothing written. The caller adds
  `; no point of contact: no contact has an email` to the end of the stage
  reason;
- `kept: operator's choice`, with nothing written.

## Procedure

1. **Check whose choice the field holds.** Let F be `point_of_contact`
   and P be `point_of_contact_pick`.
   - F equals P (both empty counts as equal): the field is the agent's
     to set. Go on.
   - F differs from P: the operator set, changed or cleared it by hand.
     This includes **F empty and P set**: the operator cleared it and
     chose nobody. Return `kept: operator's choice` and write nothing.
   - The one exception is an **explicit operator request** in a session
     to set or change the point of contact. Then go on, and when the
     operator names a person, pick that person (they must be one of
     the lead's Contacts) instead of ranking.
2. **Build the eligible list:** the lead's Contacts with a **non-empty
   email** field and a person's name. Verified and unverified emails
   both count. A pattern-guessed address never sits in the email field
   (it is in `notes`), so it never makes anyone eligible. A **generic
   inbox** written as a Contact (an `info@`, `office@` or contact-form
   row with no person's name) is not eligible: the email platform
   addresses people by name. With no one eligible, return
   `none eligible`.
3. **Rank by seniority, from the job title, never from** the
   decision-maker / influencer / gatekeeper `role`. Most senior first:
   1. owner, co-owner, owner-operator, founder, co-founder, president,
      CEO, principal, managing partner;
   2. general manager, managing director, COO, partner;
   3. other managers and directors (office manager, operations manager,
      service manager, director of anything);
   4. everyone else.

   A title with more than one part ("Owner & Lead Technician",
   "Office Manager / Partner") takes the **highest rank any part of the
   title names**. A gatekeeper can be the point of contact when they
   are the only eligible person.
4. **Break ties** within the top rank, in order:
   1. a `Verified` email beats an unverified one;
   2. the title that best matches `icp.md`'s Target roles;
   3. the **earliest-written** Contact.
5. **Write** with one CRM `update_lead(lead_id, fields)` call setting
   `point_of_contact` and `point_of_contact_pick` to the same
   `contact_id`, and `point_of_contact_reason` to
   `<rank word from the title>; <why>`, for example
   `Owner; most senior with an email`, `General Manager; owner has no
   email` or `Office Manager; only contact with an email`. When F
   already equals the new pick, write nothing. Return
   `picked <contact_id>`.

## Failure modes

- **Picking a generic inbox.** An `info@` gatekeeper row is the only
  Contact with an email. The answer is `none eligible`, not the inbox.
- **Ranking by role.** A `role: decision-maker` office manager is still
  rank 3; a `role: gatekeeper` owner is still rank 1. Rank comes from
  the title.
- **Refilling a cleared field.** The operator cleared the field after
  the agent's pick (F empty and P set). A later re-research leaves it
  empty.
- **Picking someone without an email** because they are more senior.
  The email decides eligibility first.
- **Writing F alone.** F and P are always written together, with the
  same value, or the next run mistakes the agent's own pick for the
  operator's.

## Worked example

All names are fictional. Harbor Plumbing has three Contacts:
- Dana Reyes, "Owner", no email;
- Sam Ortiz, "Office Manager / Partner", `sam@harborplumbing.example`,
  unverified;
- a gatekeeper row, `info@harborplumbing.example`, no person's name.

Both fields are empty, so F equals P and the agent may set it. Dana
isn't eligible (no email) and neither is the inbox (no person). Sam is
eligible, and "Partner" makes the title rank 2. Sam is picked:

`update_lead(lead_id, {point_of_contact: <Sam's contact_id>,
point_of_contact_pick: <Sam's contact_id>, point_of_contact_reason:
"Partner; owner has no email"})`. Returns `picked <Sam's contact_id>`.
