---
name: write-linkedin-touch
description: Use when LinkedIn is the chosen channel — drafts a connection note or a DM for the operator to send by hand.
---

**This skill never sends. It produces text the operator copies and
pastes by hand into LinkedIn.** LinkedIn's User Agreement prohibits
automated messaging and automated connection requests — there is no
tool this skill could call that would make an automated send
compliant, so no such tool is on its list. The output of this skill is
always a piece of copy attached to a draft Activity, never an action
taken on LinkedIn itself.

## Two output shapes

- **Connection note** — sent with the connection request itself. Hard
  limit **300 characters**. No pitch of any kind — this is a reason to
  connect, not a reason to buy. The reason must reference something
  real and specific about them, the same bar `research-company` sets
  for a usable hook.
- **DM after the connection is accepted** — a separate message sent
  once they've accepted. Under **80 words**. References the hook, has
  exactly one ask, and carries **no link in the first message** —
  LinkedIn's algorithm suppresses reach on messages containing a link,
  so any link waits for a later message once the conversation is
  live.

## Procedure

1. Read the lead's `Hook` from its Research rows via CRM `get_lead`,
   and `context/operating-config.md`'s `tone`, the same inputs
   `write-cold-email` reads.
2. Draft the **connection note** first: one sentence that references
   the hook or something else real and specific about them, phrased as
   a reason to connect — never as an opener for a pitch. No proof
   point, no capability claim, no ask beyond the connection request
   itself.
3. Count the connection note's characters, including spaces and
   punctuation. If it is at or over 300, cut a clause — don't
   abbreviate words to squeeze under the limit; an abbreviated note
   reads as rushed.
4. Log the connection note via CRM `log_activity(lead_id, contact_id,
   channel="linkedin", direction="outbound", draft_body=..., status=
   "draft")`, with a `Summary` noting it is a connection note, not a
   DM, so the operator knows which one to paste where.
5. Draft the **DM** as a second, separate draft — only after the
   connection note, and understood as a message the operator sends
   later, once LinkedIn shows the connection accepted, not
   immediately. Open by referencing the hook (it can restate or build
   on the connection note, since the recipient already saw that one),
   write exactly one ask, and include no link.
6. Count the DM's words. If it is at or over 80, cut a sentence
   whole, the same rule as `write-cold-email` step 9.
7. Read the draft in your head as a DM, not an email: short lines, no
   "Dear," no formal sign-off, no multi-paragraph structure. If it
   reads like something that could have been an email instead, it is
   in the wrong register — see Failure modes.
8. Log the DM via a second CRM `log_activity` call, same shape as step
   4, with `Summary` noting it is the DM, sent only after acceptance.

## Worked examples

Both examples continue the Fennimore Health scenario from
`write-cold-email`: hook is the clinical-ops hiring surge following the
Series A, contact is Renata Voss, VP of Clinical Operations.

### Connection note

> Hi Renata — congrats on the Series A. Noticed the clinical-ops
> hiring push right after it; scaling that function fast is its own
> project. Would like to follow along as Fennimore grows.

**184 characters** — under the 300-character limit. No pitch, no ask
beyond the connection itself; the reason to connect is the Series A
and the hiring push, both real and specific to Fennimore.

### DM, after acceptance

> Renata — thanks for connecting. Congrats again on the raise, and on
> landing four clinical-ops hires so fast afterward. Most teams feel a
> gap around week three, once new hires know the job but not the
> systems yet. We build onboarding systems for clinical-ops teams
> scaling this fast — happy to share what's worked elsewhere if it's
> useful. Open to a quick call?

**63 words** — under the 80-word limit. References the hook again,
one ask ("Open to a quick call?"), no link, and it reads as a message,
not a letter — no greeting line, no sign-off.

## Failure modes

- **Exceeding 300 characters on a connection note.** LinkedIn truncates
  or rejects an over-limit note outright — a note that only "reads"
  under the limit but wasn't actually counted is not verified.
- **Pitching in the connection note.** Any mention of what the
  business does, sells, or offers — even one soft sentence — turns a
  connection request into a cold pitch before the person has agreed to
  hear one, which is a worse first impression than no note at all.
- **A link in a first DM.** Even a single link in the first message
  after acceptance suppresses the message's reach on LinkedIn's side —
  the link, if there is one, belongs in a later message once the
  conversation is already moving.
- **Writing the DM in email register.** A "Hi Renata," greeting line,
  paragraph breaks, and a formal sign-off make a DM read like a pasted
  email — LinkedIn readers notice, and it undercuts the informality
  that makes a DM land as a real message instead of outreach.
