---
name: run-live-call-script
description: Use when a sales call is in progress — provides a talk track and surfaces the right material as the conversation moves.
---

## OUTPUT SHORT — read this before anything else

During a live call the operator is talking to a prospect, not reading
a screen. Every response this skill produces must fit in **one or two
lines the operator can glance at and say out loud** — never a
paragraph, never a bulleted list of options to choose from mid-sentence.
If a response from this skill takes longer to read than to say, it is
wrong, regardless of how accurate or complete it is. This constraint
overrides every other instinct below, including the instinct to be
thorough — thoroughness lives in `prepare-sales-call`'s brief, which
was already read before the call started.

## The five beats

The call moves through five beats in order. This skill does not
re-order them for a fast-moving prospect — it holds beat 2 before beat
3 even when the prospect seems ready to hear the offer, because a
diagnosis skipped now is unavailable later in the same call.

1. **Open and confirm the agenda.** State why this call is happening
   and what the next few minutes will cover; get a yes before moving
   on. Short and mutual, not a monologue.
2. **Diagnose with questions before presenting anything.** Use the two
   open questions from the call brief (`prepare-sales-call`) to
   confirm or correct the three needs it identified. No offer element
   gets named in this beat — this beat is for listening.
3. **Map two or three offer elements to what was just said.** Not the
   full brief's offer list recited — the one or two elements that
   answer what the prospect just described in beat 2, stated as a
   direct response to their words, not a pitch that would work on
   anyone.
4. **Handle what comes back with `handle-objections`.** Every
   objection, question, or hesitation from here runs through that
   skill's classify-then-respond pattern — this skill does not
   improvise a separate response path.
5. **Close on a specific next step with a date.** Never end on "I'll
   follow up" or "let's stay in touch" — the close names an action and
   a date both parties agree to before the call ends.

## Worked example

Fennimore Health, live call with Renata Voss. Brief from
`prepare-sales-call`'s worked example: three needs (fast structured
onboarding, confidence it scales, a bounded budget number), offer
elements (playbook build, flat-fee scoping $8k–$15k), two open
questions (start dates staggered or same-day; existing process written
down or not). Every line the operator sees fits the OUTPUT SHORT rule
above — this is the actual shape of what gets surfaced, not a
summary of it.

> **Beat 1 — say:** "Renata — fifteen minutes, mainly your side: how
> the four hires are onboarding. Sound right?"
>
> **Beat 2 — ask:** "Are those four starting the same day, or
> staggered?"
> **then ask:** "Is there a written onboarding process today, or
> nothing yet?"
>
> *(Prospect answers: staggered over three weeks, nothing written
> down.)*
>
> **Beat 3 — say:** "Staggered plus nothing written down is exactly
> the nine-day Acme Co case — playbook gets built once, reused per
> hire as they land."
>
> *(Prospect: "$8k feels like a lot for a document.")*
>
> **Beat 4 — [handle-objections: price]**
> **say:** "Fair — from outside it looks like paying for a document."
> **ask:** "Is it the number, or not yet seeing what's behind it?"
> **then say (evidence):** "You're paying for the nine-day result at
> Acme Co, not the doc — that's the gap versus a six-week ramp."
>
> **Beat 5 — say:** "Let's scope it properly — 20 minutes Thursday at
> 2pm, I'll bring the exact number for four staggered hires?"

Every operator-facing line above is one sentence, sayable in the time
it takes to read it. Beat 2 asks before beat 3 offers anything. Beat 4
routes through `handle-objections`' three-step pattern without
expanding it into paragraph form. Beat 5 names a day, a time, and a
concrete deliverable — not "I'll follow up."

## Failure modes

- **Presenting before diagnosing.** Naming an offer element in beat 1
  or before both diagnostic questions land in beat 2 — even when the
  prospect seems ready — skips the information beat 3 needs to map the
  right element instead of a generic one.
- **Closing without a dated next step.** "I'll send some info over" or
  "let's touch base soon" ends the call with nothing either party is
  bound to. The close always names a specific action and a specific
  date, agreed on the call, not proposed afterward by email.
- **Producing long output the operator cannot read while talking.** A
  three-paragraph objection response, or a beat-3 recap of the full
  offer list instead of the one relevant element, is unusable mid-call
  even if every word in it is accurate — the operator either stops
  talking to read it or ignores it and improvises blind. Every output
  from this skill is checked against the OUTPUT SHORT rule before it's
  surfaced, not after.
