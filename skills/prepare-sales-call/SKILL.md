---
name: prepare-sales-call
description: Use when a call is scheduled — produces a one-page brief mapping what the business offers to what this specific prospect appears to need.
---

The brief this skill produces is a one-page document the operator reads
in the minutes before a call — not a case file. Every section below
maps directly onto a section of `templates/call-brief.md` (the blank
shape that template defines); this skill's job is to fill that shape
correctly, not to invent a different one.

## Procedure

1. Call CRM `get_lead(lead_id)` and read the full record graph: every
   linked Contact, every Research row, every Activity. This is the
   entire evidence base for the brief — nothing in the brief may come
   from anywhere else.
2. From the linked Contacts, identify who is actually on the call and
   their `Role` (decision-maker, influencer, gatekeeper). If the
   calendar invite or the triggering Activity names attendees not yet
   in Contacts, note them as unconfirmed rather than guessing a role
   for them.
3. From the Activities and Research, reconstruct why this prospect
   took the meeting — the specific thing that moved them from
   `Contacted` or `Replied` to `Call Scheduled`: a reply to a
   particular hook, a question they asked, an inbound request. Quote
   or closely paraphrase it; "they seemed interested" is not a reason.
4. Run a web search for news about the company (and, where relevant,
   the named attendees) from the last seven days. A funding
   announcement, a leadership change, or a product launch that
   happened yesterday outranks anything already sitting in Research —
   check for it even when Research looks complete, and log anything
   found via CRM `log_research` before using it, so the hook has a
   source URL like every other Research row.
5. From every Research row, every Activity, and this week's news
   search, list every candidate need the prospect appears to have.
   Then cut the list to the **three most likely**, each attached to
   the specific evidence it comes from (a Research `Summary`, a quote
   from an Activity, a fact from this week's search). A need with no
   evidence line next to it does not make the cut — see Failure
   modes.
6. For each of the three needs, choose the one or two offer elements
   from `business-profile.md`'s "What we sell" section that most
   directly address it, so the brief carries **two or three offer
   elements total**, not one per need stacked into five or six. An
   offer element earns its place by answering a listed need — an
   element listed because it's impressive rather than relevant does
   not belong.
7. Using `handle-objections`' six-class matrix (price, timing,
   authority, need, trust, incumbent) as the checklist, name the
   **three objections most likely to surface** given this prospect's
   size, role, and what Research shows about their situation — not
   three generic objections that would apply to any prospect.
8. Write **two open questions** — neither answerable with yes or no —
   that would let the operator confirm or correct the three needs from
   step 5 within the first few minutes of the call. A question the
   operator already knows the answer to from Research is not worth
   asking live; use the two open slots on what's still uncertain.
9. Write the brief into `templates/call-brief.md`'s shape: attendees
   and roles, why they took the meeting, the three needs with
   evidence, the two or three offer elements mapped to them, the three
   likely objections, and the two open questions. Keep every line
   short enough to scan in the minutes before the call starts — this
   is a brief, not a dossier.

## Worked example

**Fennimore Health**, `Stage = Call Scheduled`. Research holds one row
(`Summary`: "Company raised a $9M Series A, announced 2026-08-14; job
board shows four clinical-ops postings opened the same week." `Hook`:
"congratulate on the raise and ask how they're structuring the
clinical-ops team as it scales."). Activities show an inbound reply
from Renata Voss to the cold email: "Worth a call — we're trying to
figure out how to onboard this many people without slowing the team
down." A seven-day news check turns up nothing new since the funding
announcement. This example assumes `business-profile.md`'s Proof
section contains: *"cut onboarding time from six weeks to nine days
for Acme Co, a healthtech client of comparable size,"* and its Pricing
section contains: *flat fee, $8k–$15k depending on team size and how
much onboarding already exists.*

> **Call brief — Fennimore Health**
>
> **On the call:** Renata Voss, VP of Clinical Operations
> (decision-maker, confirmed via reply).
>
> **Why they took the meeting:** Replied to the cold email asking how
> to onboard four new clinical-ops hires without slowing the team
> down — her words, from the inbound Activity.
>
> **Three likely needs:**
> 1. A faster, more structured onboarding process for the four new
>    clinical-ops hires — evidence: her own reply, plus the four
>    postings opened the same week as the raise (Research).
> 2. Confidence the process holds up as the team keeps growing post-
>    Series A, not just for this one hiring wave — evidence: "as it
>    scales" framing in the original hook, and a Series A typically
>    implies more hiring to come.
> 3. A bounded cost and timeline she can defend in a budget
>    conversation — evidence: VP title plus a company at this stage
>    typically needs to justify new spend to a board or CFO.
>
> **Offer elements that map:**
> - Onboarding playbook build (maps to needs 1 and 2) — nine-day
>   result for Acme Co, a comparable healthtech client.
> - Flat-fee scoping, $8k–$15k (maps to need 3) — bounded cost, not an
>   open-ended retainer.
>
> **Three likely objections:** price ("how does $8k–$15k compare to
> just having ops handle it internally"), timing ("can this start
> before the four hires land, or does it need to run in parallel"),
> trust ("has this worked for a team our specific size before, not
> just Acme Co").
>
> **Two open questions:**
> 1. "Of the four roles you're filling, how many onboard on the same
>    start date versus staggered?"
> 2. "What does onboarding look like today — is there already a
>    written process, or is this being built from scratch?"

Every need carries its own evidence line; the brief stops at three
needs rather than listing every candidate found in step 5; the two
offer elements map directly to those needs rather than listing every
offer element the business has.

## Failure modes

- **A brief that describes the business rather than the prospect.**
  Restating what the offer includes, in general, without tying it to
  this specific prospect's situation is not a call brief — it's the
  business profile with a company name pasted at the top. Every line
  in the needs and offer sections must reference something particular
  to this lead.
- **Mapping an offer element to a need with no evidence behind it.** An
  offer element that "seems like it would help" attached to a need
  inferred from nothing is a guess wearing the brief's formatting. If a
  candidate need has no Research row, Activity, or news item behind
  it, it does not make the three — find a different need that does, or
  leave the slot for a weaker-but-evidenced one.
- **More than three needs.** A brief with five or six needs is a brief
  nobody can hold in their head walking into a live call — the
  operator ends up re-reading it mid-conversation instead of listening.
  Three is the ceiling, not a suggestion; cut the weakest before
  writing the brief, not after.
