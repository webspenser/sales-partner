---
name: handle-objections
description: Use when an objection surfaces before or during a call — classifies it and produces a response grounded in the business profile.
---

An objection is a request for more information wearing the shape of a
refusal. The pattern below treats it that way every time — never as
something to argue down.

## Procedure

1. Classify the objection into exactly one of six classes: **price**
   (the cost, or cost relative to value), **timing** (not now, bad
   timing, other priorities), **authority** ("I need to check with
   someone else"), **need** ("we don't think we need this" or "we're
   fine as is"), **trust** ("how do I know this will work for us"),
   **incumbent** ("we already use/do X"). If the objection genuinely
   does not fit one of these six, do not force it — go to the
   escalation rule below.
2. Apply the response pattern for that class, in order, every time:
   1. **Acknowledge specifically.** Restate what they actually said,
      not a paraphrase so generic it could answer any objection in
      that class. "Makes sense — a nine-day figure sounds tight when
      you haven't seen the process" acknowledges the specific doubt
      behind a trust objection; "I understand your concern" does not.
   2. **Ask one question** that surfaces what's underneath the stated
      objection. Exactly one — a second question in the same breath
      turns this into an interrogation and lets the prospect answer
      neither. The stated objection is often not the real one (see
      Failure modes); this question is how the real one surfaces.
   3. **Respond with evidence from `business-profile.md`.** Once the
      real concern is clear, answer it with a named proof point,
      priced range, or stated differentiator — never a reassurance
      with nothing behind it ("it'll be fine, trust me").
3. Before answering, check whether the response requires a claim
   `business-profile.md` does not contain — a metric not listed under
   Proof, a price outside the stated range in Pricing, a capability
   not listed under What we sell. If it does, this skill does not
   invent the missing piece; it escalates per the rule below instead
   of answering.
4. Log the objection and how it was handled (or escalated) as part of
   the call record — during a live call this happens through
   `run-live-call-script`'s debrief step, not as a separate write from
   this skill.

## Escalation rule

An objection that does not fit any of the six classes, or one whose
evidence-backed response would require a claim absent from
`business-profile.md`, is escalated to the operator rather than
answered. Escalating sounds like: "Good question — let me confirm the
exact number and follow up rather than guess," never a made-up figure
or capability offered to keep the conversation moving. A conversation
that stalls for a beat is recoverable; a claim made on a live call is
not.

## Starter matrix — one worked response per class

Each response below assumes `business-profile.md`'s Pricing section
contains: *flat fee, $8k–$15k depending on team size and how much
onboarding already exists*, and its Proof section contains: *"cut
onboarding time from six weeks to nine days for Acme Co, a healthtech
client of comparable size."* Speaker is the operator, on a call with
Renata Voss (Fennimore Health, from `prepare-sales-call`'s worked
example).

**Price** — *"$8k feels like a lot for what's basically a document."*
> Acknowledge: "Fair — from the outside it can look like you're paying
> for a document." Question: "What would make the cost feel
> proportionate to you — is it the number itself, or not yet seeing
> what's behind it?" Evidence: "The deliverable's the playbook, but
> what you're actually paying for is the nine-day result it produced
> at Acme Co, versus a six-week ramp without it — that gap is what the
> fee maps to."

**Timing** — *"Can we revisit this in Q1? Things are chaotic right
now."*
> Acknowledge: "Makes sense — mid-hiring-wave is a rough time to add
> anything new." Question: "Is the chaos about bandwidth to run this
> right now, or about the four hires already being past the point
> where a new process would help them?" Evidence: "If it's bandwidth —
> the whole point of the playbook is it runs in the background while
> your team keeps hiring; it doesn't ask for hours from anyone besides
> the one scoping call."

**Authority** — *"I'd need to run this by our COO before moving
forward."*
> Acknowledge: "Of course — a spend like this shouldn't be a
> one-person call." Question: "What does your COO usually want to see
> before signing off on something like this — the cost, the proof it
> works, or the timeline?" Evidence: "Happy to put together a one-pager
> with the Acme Co number and the $8k–$15k range so you're not
> relaying it from memory."

**Need** — *"Honestly, we've onboarded people before — I'm not sure we
need a formal process for this."*
> Acknowledge: "Fair — you've clearly onboarded people successfully
> before this." Question: "What's different about this round — is it
> the number of people at once, or something about the roles
> themselves?" Evidence: "That's usually where the six-week version
> creeps in — one-off onboarding works fine at one hire at a time; the
> Acme Co gap opened up specifically when they went from one-by-one to
> four in a week, same as you're facing now."

**Trust** — *"Nine days sounds fast. How do I know that's not a
best-case number?"*
> Acknowledge: "Fair to be skeptical of a number that sounds that
> good." Question: "Would it help more to see how the nine days broke
> down at Acme Co, or to hear what would make it run longer for a team
> like yours?" Evidence: "Nine days was the median across Acme Co's
> onboarded group, including their remote hires — not a cherry-picked
> best case. It runs longer if the current process isn't written down
> anywhere yet, which is worth knowing going in."

**Incumbent** — *"We already have an onboarding doc our HR team put
together."*
> Acknowledge: "Good — that's more than a lot of teams have at this
> stage." Question: "Is that doc built for clinical-ops roles
> specifically, or is it the general company onboarding doc applied to
> everyone?" Evidence: "That's usually the gap — a general HR doc
> covers badges and benefits, not the clinical-ops-specific ramp that's
> what actually drove Acme Co's nine-day number. The playbook can sit
> alongside your existing doc rather than replace it."

Every response above acknowledges the specific stated objection, asks
exactly one question before offering anything, and answers only with a
proof point or figure that exists in `business-profile.md` — none of
them concede on price, invent a capability, or move to evidence before
asking the question.

## Failure modes

- **Answering the stated objection when a different one is
  underneath it.** "We already have a doc" is often actually a trust
  or need objection wearing an incumbent's clothes — answering it as a
  feature comparison against "our doc" without asking what the doc
  covers answers the wrong question. The one question in the pattern
  exists precisely to catch this; skipping straight to evidence skips
  the check.
- **Conceding on price before understanding the class.** Dropping the
  number, offering a discount, or hedging ("well, we could probably
  work something out") the moment cost comes up treats every price
  objection as a price objection, when it is frequently a trust or
  need objection expressed in dollar terms. Concede nothing until the
  question in step 2 has surfaced what's actually underneath it.
- **Inventing a capability to clear an objection.** Claiming the
  playbook does something not in `business-profile.md`'s What we sell
  section, or citing a metric not in Proof, to make an objection go
  away is exactly the failure the escalation rule exists to prevent —
  a claim made live cannot be unsaid once the prospect has heard it.
