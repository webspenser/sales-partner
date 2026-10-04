---
name: enroll
description: Use when `schedule_enroll` fires, or the operator asks to enroll leads waiting at Ready to Send — puts each approved email touch into the client's sequence platform for the lead's score band.
---

The operator approves a lead's whole plan by moving it to
`Ready to Send`. This skill sends the plan's email touch the only way
the agent may: it enrolls the lead in the client's own sequence
(InvokeIQ, through the `sequences` capability), and the platform sends.
It never writes or sends an email itself.

The guard can't check that a lead is at `Ready to Send` before
`enroll_contact` runs; the operator accepted that as an
instruction-level rule (`enroll_ready_only`). Follow every check below.

## Procedure

1. CRM `query_by_stage("Ready to Send")`. Nothing returned: report
   "no leads waiting" and stop.
2. For each lead, CRM `get_lead`. Decide what it is waiting for:
   - **Email touch to enroll:** a standing email Activity at `draft`
     whose contact has no outbound email Activity at `sent` to the same contact
     (enrolling the same contact twice would rewrite its fields
     mid-sequence). A voided email draft is not an email touch. Enroll it
     only when its date is today or earlier; otherwise report "waiting
     until <date>".
   - **Operator touch already done:** no standing email draft, and a
     LinkedIn or call Activity the operator marked `sent` →
     `update_stage(lead, "Contacted", "first touch sent by the operator")`
     and go to the next lead.
   - Otherwise leave it, and report why: "waiting until <date>", "only
     LinkedIn or call touches left for the operator", or "email already
     enrolled for this contact".
3. Check the lead before enrolling. Skip it, with the reason in the
   report, if any check fails; never enroll with a blank field:
   - `Do Not Contact` is false;
   - its country is in `allowed_countries` (`operating-config.md`); `CA`
     only when `canada_consent_basis` is filled in, any EU/EEA country or
     `GB` only when `eu_uk_legitimate_interest` is filled in; no known
     country means skip;
   - the chosen contact has an email address with no `bounced` Activity;
   - the draft has one `name: value` line for every name in `variables:`
     (`bindings/sequences.md`) and no other lines, none empty;
   - the draft's summary names a band (`band: <name>`) that is in
     `sequence_bands`.
4. Sequences `enroll_contact(band, email, first_name, last_name,
   variables)`, with `variables` as the draft's lines in a JSON object.
5. CRM `update_activity(status: "sent", outcome: "enrolled in <band>")` on
   that email Activity, then `update_stage(lead, "Contacted", "email
   enrolled in the <band> sequence")`.
6. If a sequences tool is unreachable or errors, stop and report what
   failed; never retry in a loop, and never mark an Activity `sent` for
   an enrollment that did not succeed.

## Report

One line per lead: enrolled (band), contacted by the operator, waiting,
or skipped with the reason. The digest repeats the counts.

## Undo

Once a lead is enrolled, moving it back to `Approach Drafted` does not
stop the sequence: the operator must pause the contact in InvokeIQ.
Say so in the report whenever a lead enrolled in this run.

## Scheduled runs

In a scheduled (unattended) run, ask nothing; if `bindings/sequences.md`
or `sequence_bands` is missing, stop and report it.
