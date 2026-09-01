---
name: write-follow-up
description: Use when something meaningful has happened with a lead, or when a lead has gone quiet past the configured cadence — drafts the next touch and sets the next action.
---

## Procedure

1. Read the lead's last Activity — `Summary`, `Outcome`, and any prior
   `Draft Body` — via CRM `get_lead`, and every Activity since it, not
   only the single most recent one. A reply thread with two messages
   since the last touch has two messages' worth of questions to
   answer, not one.
2. From that history, list every question the prospect actually
   asked, in the order asked. Write the list out before drafting a
   word of the reply — an unlisted question is one that risks being
   skipped for the rest of the run.
3. Identify which variant this is: a **thank-you after a call**
   (`Outcome` reflects a completed call), an **answer to a specific
   question** (an inbound Activity contains a question not yet
   answered), or a **re-engagement after silence** (the lead has been
   idle past `follow_up_cadence_days` with no new inbound Activity).
4. Check `Do Not Contact` on the lead record before drafting anything.
   If it is checked, stop here — no draft, regardless of what
   triggered this run.
5. Answer every question from step 2, in the order asked, before
   writing anything else. A draft that introduces new material while
   an asked question sits unanswered fails this skill, no matter how
   good the new material is.
6. After every question is answered, add **exactly one** new piece of
   value — not zero (that's a check-in, see Failure modes) and not
   several (that dilutes the one thing worth their attention): a
   concrete answer to a question they didn't ask but the last
   interaction implies, a proof point from `business-profile.md`, or a
   specific next step.
7. For the re-engagement variant specifically, the new piece of value
   from step 6 is the entire reason this message exists — see that
   variant below for what happens when there isn't one.
8. Count this draft against `max_touches` (from
   `context/operating-config.md`). If logging this draft would put the
   lead's total touch count at or over `max_touches`, do not draft it
   — call CRM `update_stage(lead_id, "Lost", reason)` instead, per
   `subagents/follow-up.md`'s Stop conditions.
9. Log the draft via CRM `log_activity(lead_id, contact_id,
   channel="email", direction="outbound", draft_body=..., status=
   "draft")`.
10. Call CRM `update_lead(lead_id, {"Next Action": ..., "Next Action
    Due": ...})` — both fields, every time a draft is logged.
    `Next Action` states the concrete next step in plain words (e.g.
    "send proposal," "wait for reply, then re-engage if none by
    <date>"); `Next Action Due` is an actual date, never a vague
    interval like "soon."

## Variant: thank-you after a call

Fennimore Health, call held with Renata Voss on 2026-08-25. `Outcome`:
"Call held. Renata asked whether the onboarding playbook covers remote
clinical hires, and what the typical implementation timeline looks
like. Said budget approval needs a proposal by end of September." This
example assumes `business-profile.md`'s Proof section is filled in
with the same Acme Co result used in `write-cold-email`'s worked
example.

> Hi Renata,
>
> Good talking today. Two things you asked about:
>
> Remote hires — yes, the playbook covers distributed clinical-ops
> teams. About a third of Acme Co's onboarded group worked remote from
> day one, on the same nine-day timeline.
>
> Timeline — a typical rollout runs two weeks: one to map your current
> onboarding steps, one to build the playbook around them.
>
> I'll have a proposal over by Friday, ahead of your end-of-September
> budget window.
>
> Andrew Ho Choy \<andrew@example.com\>

77 words. Both questions answered first, in the order asked; the one
new piece of value is the proposal-by-Friday commitment. `Next Action`:
"Send onboarding proposal." `Next Action Due`: 2026-08-28.

## Variant: answer to a specific question

Renata replied to an earlier touch asking, verbatim, "What's the
ballpark for something like this?" This example assumes
`business-profile.md`'s Pricing section is filled in with: *flat fee,
$8k–$15k depending on team size and how much onboarding already
exists; escalate anything outside that range rather than quote it.*

> Hi Renata,
>
> Ballpark for something like this: flat fee, $8k to $15k depending on
> team size and how much of your onboarding already exists versus
> needs to be built from scratch — most clinical-ops engagements our
> size land around $11k.
>
> One thing worth knowing going in: Acme Co's project ran nine days
> end-to-end, so the fee maps to a fast, bounded engagement, not an
> open-ended retainer.
>
> Happy to scope the range more precisely on a short call, once I know
> how much of your current onboarding is already written down.
>
> Andrew Ho Choy \<andrew@example.com\>

94 words. The question is answered first, directly, with the number
`business-profile.md` actually authorizes — a question this skill
cannot answer from that file (e.g. a number outside the stated range)
gets escalated to the operator instead of guessed at. The one new
value-add is the nine-day-timeline context, which reframes the number
rather than repeating it.

## Variant: re-engagement after silence

**This variant never says "just checking in" or "bumping this."** It
either carries a genuinely new piece of information, or it is the last
touch this lead gets — there is no lighter, no-content version of a
re-engagement message. Fennimore Health has gone quiet 5 days past
`follow_up_cadence_days` (4) since the first approach, with no reply.
This example assumes a second, more recent Proof entry exists in
`business-profile.md`.

> Hi Renata,
>
> Flagging one thing since we last spoke: we just wrapped a
> clinical-ops onboarding project for a healthtech team about your
> size, and cut their ramp time by the same margin as Acme Co's,
> remote hires included.
>
> Given the hiring pace at Fennimore, thought the result was worth
> putting in front of you before your budget window closes.
>
> Worth reviving the conversation?
>
> Andrew Ho Choy \<andrew@example.com\>

67 words. There are no unanswered questions to answer first here — no
new question came in — so the message is entirely the one new piece of
value: a just-finished, comparable result. `Next Action`: "Wait for
reply; if none, this was the last outreach touch under `max_touches`."
`Next Action Due`: `follow_up_cadence_days` out from today. If no new
result, case study, or event existed to report, this skill would not
draft a lighter version of this message — it would move the lead
straight to `Lost` per step 8, the same as reaching `max_touches`.

## Failure modes

- **Adding value while leaving an asked question unanswered.** A draft
  that answers question one, skips question two, and pivots to a new
  case study reads as evasive even when the new material is genuinely
  useful — every asked question gets answered before anything new is
  introduced, no exceptions.
- **Exceeding `max_touches`.** A follow-up drafted after the lead has
  already reached its touch cap is not a lighter or friendlier
  message — it's an over-limit send waiting for approval. Step 8 stops
  the draft before it's written, not after.
- **Drafting again for a lead marked `Do Not Contact`.** Whatever
  triggered this run — a fresh Activity, a stalled-cadence check — a
  lead with `Do Not Contact` checked gets no draft, full stop. Step 4
  checks this before any other step runs.
