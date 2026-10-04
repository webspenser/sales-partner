---
name: interview-business
description: Use when installing this agent for a business, or when its offer, market, or targeting has materially changed — conducts the intake interview and writes the context files and the instance's schedules.yaml.
---

This skill is the only writer of `context/business-profile.md`,
`context/icp.md`, `context/operating-config.md`'s interview-sourced
keys, and the instance's `schedules.yaml`. It runs as a conversation with the operator, never as a form to
fill in silently — every bracketed prompt in those three files exists
because a human has to answer it in their own words.

## Procedure

1. **Round 1 — the business.** Ask, one at a time, waiting for an
   answer before asking the next: what do you sell, who is it for, what
   does it cost, and what happens if a customer does nothing about the
   problem you solve. Never combine two of these into one message.
2. Write what was learned to `context/business-profile.md` before
   starting Round 2: fill in "What we sell," a first pass at "Who we
   serve," "Pricing," and fold the "does nothing" answer into
   "Differentiators" (the alternative every prospect is really
   comparing against). Leave any sub-point the operator didn't cover
   as its original bracketed prompt rather than guessing at it.
3. **Round 2 — the customer.** First ask whether the business sells
   to companies or local businesses, and note the answer as
   `target_type`. Then ask, one at a time: describe your three best
   current customers; what did they have in common before they bought;
   who have you declined to work with, and why; which size measure fits
   (offer headcount or revenue for companies, locations or review count
   for local businesses), and its bands; if the business serves an
   area, the service area center and radius, with the unit; and
   which events signal a prospect is newly in-market, offering the
   example set in `context/icp.md`'s Buying triggers section that
   matches `target_type`.
4. From the Round 2 answers, derive a draft scoring rubric — five
   criteria (industry fit, company size, geography, buying trigger,
   decision-maker reachable, or the operator's own equivalents), a
   weight for each summing to 100, and 0/50/100 anchor language for
   each. State the draft weights back to the operator explicitly (e.g.
   "I'd weight industry fit at 25, company size at 20... does that
   match how you'd actually prioritize a lead?") and get an explicit
   confirmation or correction before writing anything. Only after
   confirmation, write these `context/icp.md` sections: Target type,
   Firmographics (with `size_measure`), Geography (with `service_area`
   when it serves an area), Target roles, Buying triggers, Anti-signals,
   and Scoring rubric — including the "who did you decline" answers as
   concrete Anti-signals — before starting Round 3.
5. **Round 3 — the proof.** Ask, one at a time: what results can you
   name, with numbers; who will take a reference call. If the operator
   offers a sample email, social post, or web page as evidence, ask
   for the real artifact (a link, a pasted copy, a forwarded file) —
   never draft one yourself to fill the gap.
6. Write `context/business-profile.md`'s "Proof" section from Round 3's
   named metrics and references before starting Round 4. Save any real
   artifacts supplied into the instance's `context/samples/`,
   unmodified from what the operator gave; if none were supplied,
   leave `context/samples/` empty rather than inventing content for
   it. Never write into the package's `samples/`.
7. **Round 4 — the operating parameters.** Ask, one at a time: how many
   leads per week should the pipeline target; which sourcing tools may
   it use (map listings for local businesses, company sites, web
   search); which channels should it use; which activities should
   run on a schedule (prospecting, research, approach drafting, the
   digest — the shipped default is prospecting
   then research on Monday at 07:00 and the digest on Monday at 08:00),
   and for each one the weekday and time, or daily, plus your time zone
   as an IANA name such as `America/New_York` (tell them scheduled
   prospecting and research use web search only, since Apify is never
   attached to a scheduled run); what is the weekly
   Apify spend cap; how should the
   outreach sound (three to five adjectives, plus one example sentence
   in that voice). If `call` is among the chosen channels, also ask
   for the operator's own callback number — the one a voicemail in a
   call opener should give for callbacks. Then the outreach plan: how
   many days apart the touches in a plan should be (`touch_spacing_days`,
   default 3); and, when cold email goes through a sequence platform
   (InvokeIQ), the score bands (`sequence_bands`, for example high from
   80 and mid from 65) and which campaign each band uses (the operator
   sets that map in the InvokeIQ workflow), the custom fields the
   campaigns' templates merge in (recorded as `variables: <name>, <name>`
   in `bindings/sequences.md`), and which countries leads may be
   enrolled from (`allowed_countries`, default US; for Canada record the
   consent basis in `canada_consent_basis`, for the EU/EEA or UK the
   legitimate-interest note in `eu_uk_legitimate_interest`). Remind them
   that the sequence platform should send from a
   separate sending domain, not their main one.
8. Write the answers to `context/operating-config.md`'s keys
   (`leads_per_week`, `prospecting_sources`, `enabled_channels`,
   `apify_spend_cap_usd_per_week`, `tone`, `callback_phone` when `call`
   was chosen, `touch_spacing_days`, and with a sequence platform
   `sequence_bands`, `allowed_countries` and its notes), to `context/business-profile.md`'s "Voice"
   section (the adjectives plus the example sentence), and to
   `schedules.yaml` at the instance root (the folder holding
   `instance.yaml`), which holds the schedule answers: `timezone` (the
   IANA name), one `schedule_<activity>: "<Weekday|daily> HH:MM"` line
   for each activity the operator wants on a schedule (`<activity>` is
   `prospect`, `prepare`, `approach`, `enroll`, `sync-replies`, or `digest`), and
   `then_prospect: prepare` when research should follow prospecting in
   the same run. The shipped default is `schedule_prospect: "Monday
   07:00"`, `then_prospect: prepare`, and `schedule_digest: "Monday
   08:00"`. Tell the operator that the `schedule` skill turns these
   lines into scheduled runs. This is the last write; the interview
   is complete once it lands.

Because each round writes its own files before the next round starts,
an interview interrupted after Round 2 leaves a complete, usable
`icp.md` and a partial `business-profile.md` behind — never a half
answer sitting only in the conversation.

## Worked example

Operator: "Ridgeline Ops" sells fractional revenue-ops setup to B2B SaaS
companies.

- Round 1 answers → `business-profile.md`: sells a 6-week RevOps
  build-out ($8k flat fee) to Series A–C SaaS companies; "what happens
  if nothing" → they keep losing pipeline visibility in spreadsheets,
  which becomes the "doing nothing" comparison in Differentiators.
- Round 2 answers: best three customers were all 50–500-employee SaaS
  companies within 90 days of a funding round; declined two roofing
  companies and one that wanted a full-time hire, not a fractional
  engagement. Size measure: headcount, 50–500; no service area (they
  sell nationally); buying trigger: a funding round in the last 90
  days. Draft rubric proposed: Industry fit 25, Company size 20,
  Geography 10, Buying trigger 25, Decision-maker reachable 20 —
  operator confirms as-is. Written to `icp.md`, including "not
  B2B SaaS" and "wants full-time hire, not fractional" as Anti-signals.
- Round 3 answers: "cut time-to-first-qualified-pipeline from 11 weeks
  to 4 weeks for Meridian Analytics"; Meridian's founder will take
  reference calls. Operator pastes an actual outbound email they sent
  Meridian — saved verbatim to `context/samples/`.
- Round 4 answers: 40 leads/week, email and LinkedIn, prospecting
  Monday 07:00 and digest Monday 08:00 Eastern, $25/week Apify cap,
  tone "direct, technical, no fluff" with the example line "We don't
  do discovery calls to sell you discovery calls — here's the
  finding." Written to `operating-config.md`, `schedules.yaml`
  (`timezone: America/New_York`, `schedule_prospect: "Monday 07:00"`,
  `then_prospect: prepare`, `schedule_digest: "Monday 08:00"`), and
  `business-profile.md`'s Voice section.

## Failure modes

- **Accepting "everyone" as an ICP.** If Round 2's three best
  customers don't share anything concrete, keep asking — a rubric
  built on "everyone" scores every lead the same and is worthless to
  the Prospector. Push for the actual pattern, or name the absence of
  one and flag it to the operator rather than inventing a plausible-
  sounding target.
- **Writing a rubric the operator has not confirmed.** Deriving weights
  from Round 2 is a draft, not a write. `icp.md` is never updated with
  scoring weights the operator hasn't explicitly agreed to, even when
  the draft looks obviously right.
- **Filling `context/samples/` with invented copy instead of asking
  for real artifacts.** A sample the agent wrote itself teaches the
  voice back to itself, not the operator's actual voice. If no real
  artifact is offered, leave `context/samples/` empty rather than
  manufacture one.
