---
name: sync-replies
description: Use when `schedule_sync-replies` fires, or the operator asks to process sequence replies — turns the reply relay's inbound records into the lead's status, Do Not Contact and suppression.
---

The reply relay (an n8n workflow, see the sequences tool's `usage.md`)
records each reply or bounce from the sequence platform as an inbound
email Activity on the lead, at `status: sent`. It decides nothing. This
skill makes every decision, and every action is idempotent, so running
it twice over the same records (or the relay delivering an event twice)
changes nothing the second time.

## Procedure

1. Window: two schedule intervals back from this run's scheduled time
   (the overlap catches anything a skipped or late run missed; repeats
   are harmless), or the last 7 days when run by hand. Call CRM
   `query_activities(status: "sent", direction: "inbound", channel: "email", since: <window start>, until: <now>)`.
2. For each Activity, `get_lead` on its lead, then:
   - **Bounce** (summary `bounced`): if the lead is at `Contacted`, and
     only when the bounce is dated on or after the lead's `Stage Changed At` (an
     older bounce belongs to an earlier attempt),
     `update_stage(lead, "Approach Drafted", "email bounced — pick
     another contact or channel")`. A bounce is not a touch, and the
     Approacher never reuses that address.
   - **Reply**: if the lead is at `Contacted`, move it
     `Contacted` → `Engaged` (`update_stage(lead, "Engaged", "replied by
     email")`) and void the plan's remaining draft touches
     (`update_activity(status: "voided", outcome: "replied")`), so no
     scripted LinkedIn or call touch follows a reply. At any other
     status, change nothing: from `Engaged` on, the lead is the
     operator's.
   - **Opt-out** (a category such as `unsubscribe` or `not_interested`
     with removal wording, or wording such as "remove me", "stop",
     "unsubscribe", "don't contact"):
     `update_lead(lead, {"Do Not Contact": true})`; void each draft Activity still pending on the
     lead (`update_activity(status: "voided", outcome: "opt-out
     reply")`); `suppress([email], "opt-out reply")`. An opt-out is also
     a reply: the lead moves to `Engaged` as above.
3. Every lead whose `Do Not Contact` is true and that has a `sent` email
   Activity with outcome `enrolled in …`: `suppress([its contact
   emails], "Do Not Contact in CRM")`. Suppressing an address twice is
   harmless.
4. If a sequences or CRM tool fails, stop and report what failed; never
   retry in a loop.

## Report

Counts and one line per lead: engaged, bounced (back to Approach
Drafted), opted out (Do Not Contact, drafts voided, suppressed). The
digest repeats the counts.

## Scheduled runs

In a scheduled (unattended) run, ask nothing and edit no instance
files; if the sequences binding is missing, stop and report it.
