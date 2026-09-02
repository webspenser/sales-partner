---
name: send-digest
description: Use when the digest schedule in operating-config.md fires — assembles the pipeline summary and delivers it to the operator.
---

This skill produces a report, not a pipeline action. It reads the CRM
and Apify usage, renders six fixed sections in a fixed order, and
delivers the result to the operator. It never advances a stage, edits
a lead field, logs an Activity, or logs Research — see **This skill
reads; it never writes** below.

## The "since last digest" anchor

Two of the six sections — **New leads scored** and **Movement** — are
windowed on "since last digest." The other four are point-in-time
snapshots evaluated fresh against *now* and carry no window at all (see
each section below). Getting the window wrong is the single most
likely way this skill produces a wrong digest, so the anchor is defined
precisely, not left to "whenever this happened to last run":

> **Window = `(anchor, nominal_time]`. `anchor` is one cadence interval
> before this run's nominal scheduled time; `nominal_time` is this
> run's own nominal scheduled time. Both edges are fixed at scheduled
> times — neither is ever the actual moment the skill happens to
> execute.**

Concretely, with the shipped default `digest_schedule: "Monday
08:00"`, the cadence interval is 7 days. To compute the window for any
given run:

1. Find this run's **nominal** scheduled time: the most recent
   occurrence of `digest_schedule`'s weekday and time at or before the
   actual moment this skill executes. This is deliberately *not* "the
   actual wall-clock time the skill happens to run" — a run fired
   exactly on time, a run fired three hours late because the scheduler
   was delayed, and a run triggered manually on Wednesday for review
   all round down to the same nominal time (the most recent Monday
   08:00), and therefore compute the same nominal time.
2. Subtract one cadence interval (7 days for the default weekly
   schedule) from that nominal time. That is the anchor — the window's
   lower edge.
3. **Bound every windowed query on both edges, not just the lower
   one.** A record qualifies only if its timestamp is strictly after
   `anchor` **and** at or before `nominal_time` — never merely "after
   `anchor`," which would leave the window's upper edge implicitly at
   "whatever exists at actual execution time." Anything timestamped
   after `nominal_time` — created or changed during the lag between the
   scheduled moment and the moment this skill actually gets around to
   running — is excluded from this run on purpose. It belongs to the
   *next* run instead: that run's anchor will be this run's
   `nominal_time`, so its window picks up exactly where this one left
   off.

This anchor comes from `operating-config.md` and calendar arithmetic
alone — never from a stored "last digest sent" value, because no such
field exists among the CRM contract's eleven operations
(`crm-contract.md`) and this skill does not invent one.

**Both edges matter equally, and pinning only the lower edge is not
enough.** A late-firing run is the normal condition for a scheduled
job, not an edge case, and an anchor with no upper bound double-reports
under it routinely: take `digest_schedule: "Monday 08:00"`, and a run
that actually executes three hours late. Its anchor is correctly
`nominal_time − 7d`, but if the query for "since last digest" is left
open-ended above — "anything after the anchor," full stop — the query
implicitly returns everything that exists at the moment the query
actually runs, i.e. up to `nominal_time + 3h`, and that includes a lead
created at `nominal_time + 1h`. The *following* week's on-time run then
computes anchor `= (this week's) nominal_time`, and reports everything
after that — which still includes the same lead, created at
`nominal_time + 1h`, because that timestamp is after this week's
`nominal_time` too. The lead appears in both digests. Fixing the upper
bound at `nominal_time` (step 3, above) closes this exactly: the late
run's window ends at its own `nominal_time`, so the lead created an
hour after it falls *outside* this run's window and is picked up by
the next run instead, whose window starts precisely at that same
`nominal_time`. This is what actually makes consecutive
normal-cadence runs divide the calendar into adjoining, non-overlapping
windows — the upper bound fixed at `nominal_time`, not merely the
anchor being schedule-derived on its own. (The one gap this still
doesn't cover: if a scheduled run is skipped outright — the scheduler
never fires it at all — the next run's window still only reaches back
one interval, so an entire missed week's movement is not caught
retroactively. That is a scheduling-reliability problem outside this
skill's scope, not a bug in the window formula.)

Record-level timestamps are compared against the `(anchor, nominal_time]`
window per section:

- **New leads scored** compares each Lead record's own **Created
  Time** — the timestamp the Airtable adapter stamps on every row the
  moment `create_lead` writes it — against the full window,
  `(anchor, nominal_time]`, not the anchor alone. Created Time is
  store-level record metadata, not one of the fields
  `crm-airtable-adapter.md` declares on the Leads table; it needs no
  new field because every record already carries it.
- **Movement** compares each Lead record's own **`Stage Changed At`**
  against the same `(anchor, nominal_time]` window. `Stage Changed At`
  is a declared field on the Leads table (`crm-airtable-adapter.md`),
  written only by `update_stage`, on every transition, as part of that
  same call — never by `update_lead` and never by anything else. That
  exclusivity is what makes it trustworthy here: `update_lead` writes
  `Score`, `Next Action`, `Do Not Contact`, and other lead fields
  routinely without touching stage at all, so a generic "record last
  touched" timestamp would fire on those unrelated edits too and list
  leads in Movement that never moved. `Stage Changed At` only ever
  moves when the stage actually does.

## This skill reads; it never writes

Its only side effect anywhere is delivering the finished digest. It
never calls `create_lead`, `update_stage`, `update_lead`,
`log_activity`, `log_research`, or `upsert_contact` — no stage moves,
no field edits, no Activity or Research row, not even a "digest sent"
marker. The reads it does use, named precisely:

- CRM **`query_activities`** (`status: "draft"`, no `since`/`until` —
  every outstanding draft regardless of age) — Section 1, Awaiting
  approval.
- CRM **`query_by_stage`** with its `next_action_due_before` filter
  (`stage` omitted, so leads across every stage are considered) —
  Section 2, Next actions due today.
- CRM **`query_by_score`** (`min_score: 0`, ordered by Score descending
  per the contract), called once per stage a scored lead can currently
  occupy, results filtered client-side to the `(anchor, nominal_time]`
  window on Created Time — Section 3, New leads scored.
- CRM **`query_by_stage`** with its `idle_days` filter (`stage`
  omitted) — Section 4, Stalled.
- CRM **`query_by_stage`**, called once per stage of interest, results
  filtered client-side to the `(anchor, nominal_time]` window on
  `Stage Changed At` — Section 5, Movement.
- Apify's own usage data — Section 6. This is the one section with no
  CRM read at all; Apify spend is not CRM data and never was.

Every one of the above is a call through `crm-contract.md`'s ten
provider-neutral operations — none of the six sections reads an
Airtable view directly. `crm-airtable-adapter.md`'s four named views
(Awaiting Approval, Research Queue, Due Today, Stalled) still exist as
a convenience for the operator looking at Airtable by hand, and are
defined to compute exactly what the operations above return, but this
skill does not depend on them: swap the adapter for a different CRM
behind the same contract, and every one of these six sections still
works, because none of them named an Airtable-specific view as its read
path.

## Procedure

1. Compute the window — the anchor and `nominal_time` that bound it on
   both edges — per **The "since last digest" anchor** above.
2. **Section 1 — Awaiting approval.** Call CRM `query_activities(status:
   "draft")`, `since`/`until` both omitted. Record the count and, for
   every returned Activity, a link (or the linked Lead's company name
   if the adapter exposes no per-Activity link) and the channel. No
   window applied — this is every draft outstanding right now, however
   old. Render the section heading with that count, e.g. `Awaiting
   approval (2)`.
3. **Section 2 — Next actions due today.** Call CRM
   `query_by_stage(next_action_due_before: today, stage: omitted)` —
   omitting `stage` so leads at every stage are considered, not one
   at a time. List each returned lead's `Next Action` and `Next Action
   Due`. No window applied — overdue items stay listed every run until
   acted on; that is the point of a due-date filter, not a bug. Render
   the section heading with the count of leads returned, e.g. `Next
   actions due today (2)`.
4. **Section 3 — New leads scored.** Select by *when the lead was
   created*, not by its current stage — a lead scored at prospecting
   and then advanced to `Researched` (or further) within this same
   window is still a new lead since last digest, and is exactly the
   kind of fast-moving lead the operator most wants to see, so this
   section must not lose it. Call `query_by_score(min_score: 0, stage:
   <stage>, limit: 50)` once per stage a lead can occupy while still
   carrying a `Score` — every stage except `New` (score-lead hasn't run
   yet) and `Disqualified` (a lead disqualified on an anti-signal was
   never scored at all, per `score-lead` step 2) — merge the results,
   and filter to leads whose Created Time falls in the window
   `(anchor, nominal_time]` — strictly after the anchor **and** at or
   before this run's nominal scheduled time, never merely "after the
   anchor" (see the upper-bound explanation in **The "since last
   digest" anchor** above; a lead created after `nominal_time`, during
   this run's own execution lag, belongs to next week's digest, not
   this one). Sort the merged, filtered set by Score descending and
   take the top five.
   For each, derive its one-line rationale from `Score Breakdown`:
   parse the five `<criterion> <score>×<weight/100>=<points>
   (<justification>)` lines the `score-lead` skill wrote — using only
   the most recent block if the lead has since been re-scored — take
   the line with the highest `<points>` value, and keep only its
   parenthetical justification, dropping the arithmetic. If fewer than
   five leads clear the anchor filter, list however many there are; if
   none do, render the heading with `None` under it rather than
   omitting the heading (see Failure modes). Render the section heading
   with both the count actually listed and the cadence phrasing, e.g.
   `New leads scored (5, top 5 since last digest)` — the count reflects
   how many leads are actually listed under the heading, which may be
   fewer than five whenever fewer clear the anchor filter.

   A lead created since the anchor appears **at most once** in this
   section, keyed by its Created Time, no matter how many times its
   `Score` has since been recomputed. If that same lead's Score was
   recomputed as part of a stage change (a Preparer re-score alongside
   `Scored → Researched`), that transition is reported once, under
   Movement (Section 5) — not as a second appearance here. Section 3
   answers "which leads are new since last digest"; Section 5 answers
   "what changed since last digest." A lead that answers both
   questions still gets exactly one line in each, never two lines in
   either.
5. **Section 4 — Stalled.** Call CRM
   `query_by_stage(idle_days: follow_up_cadence_days, stage: omitted)`
   — `follow_up_cadence_days` from `operating-config.md`, `stage`
   omitted so every active stage is considered. List each returned
   lead, its `Stage`, and the date of its last Activity. No anchor
   window applied — staleness is measured against *now*, every run,
   independent of when the last digest fired. Render the section
   heading with the count of leads returned, e.g. `Stalled (2)`.
6. **Section 5 — Movement.** Call `query_by_stage` once for each stage
   that signals movement worth reporting — at minimum `Won`, `Lost`,
   and `Disqualified`, plus any of `Contacted`, `Replied`, `Call
   Scheduled`, `Call Held`, `Following Up` the operator has asked to
   see. For each stage's results, keep only leads whose `Stage Changed
   At` falls in the window `(anchor, nominal_time]` — strictly after
   the anchor **and** at or before this run's nominal scheduled time —
   and list them as `<Company>: → <Stage>
   (<date>, <reason if one was recorded on the transition>)`. Call out
   `Won`, `Lost`, and `Disqualified` explicitly, even when the list for
   one of them is empty (write "No wins this week" rather than
   dropping the line). Because `Stage Changed At` is written only by
   `update_stage`, never by `update_lead`, a lead whose `Score` or
   `Next Action` was edited without its stage moving does not appear
   here — only an actual transition does. Render the section heading
   with the count of leads that actually transitioned — e.g. `Movement
   (5)` — an explicit "No wins this week"-style line added only because
   a bucket was empty does not add to that count.
7. **Section 6 — Spend.** Read Apify's usage total for the current cap
   week — the same weekly boundary the anchor uses, so spend and
   digest windows line up — and compare it to
   `apify_spend_cap_usd_per_week` from `operating-config.md`. Report the
   dollar amount spent, the cap, and the percentage. This section does
   not touch the CRM.
8. Render all six sections, in the fixed order above, every run — a
   section with nothing to report still gets its heading and an
   explicit "None" (or equivalent), never a silently omitted heading.
   This is the shape `templates/digest.md` defines; until that
   template exists, the section order and content rules above **are**
   the shape.
9. Resolve the delivery channel: read `digest_channel` from
   `operating-config.md`. If it is `sms` and no Twilio credential is
   configured — true of the shipped default, since SMS is a stubbed
   adapter, not yet enabled — switch delivery to email and make the
   digest's first line say so verbatim, e.g. `Delivered by email — SMS
   is configured but no Twilio credential exists yet.` If
   `digest_channel` is `email`, or is `sms` with a working Twilio
   credential, deliver on that channel with no disclaimer line.
10. Deliver the rendered digest by Gmail to `sending_identity` (the
    operator's own address from `operating-config.md`). See **Approval
    scope** below for why this send needs no separate approval step.
    This is the skill's only side effect. Stop — no CRM write of any
    kind follows.

## Why approvals lead

Section 1 is a queue: every entry in it needs the operator to do
something (approve, edit, or reject a draft). Every other section is
reporting: it describes state for the operator to be aware of, but
nothing in Sections 2 through 6 requires an action to clear it from
the digest. A queue and a report read very differently once a person
has scanned five paragraphs before reaching either — reporting placed
above a queue trains the reader to treat the whole digest as
skimmable, and the one part of it that was never skimmable, the
approval queue, is exactly the part that gets scrolled past out of
habit. Section 1 leads so that the one thing this digest exists to get
acted on is the first thing the operator sees, every time, regardless
of how long the rest of the pipeline summary runs. This ordering is
load-bearing, not a stylistic default — see the first Failure mode
below for what breaks when someone "cleans it up" by moving the
summary to the top.

## Approval scope

`AGENT.md`'s guardrail — "nothing sends without operator approval" —
and `crm-contract.md`'s `log_activity` enforcement of it both gate one
specific thing: **outbound prospect communication**, logged as an
Activity and walked through `draft` → `approved` → `sent` — or, if an
inbound opt-out arrives first, diverted from `draft`/`approved`
straight to the terminal `voided` via `update_activity`, which never
reaches `sent`. The digest
is never logged as an Activity, is never addressed to a prospect, and
never touches `log_activity` at all — it is a report the agent sends
to the operator, about the operator's own pipeline. Delivering it by
Gmail is not a violation of that guardrail; it is a different act
entirely, on a different channel scope than the draft-only Gmail
access `AGENT.md`'s Inputs describes for composing prospect-facing
Activities. Do not read this skill's Gmail delivery as an argument
that any other agent output no longer needs approval — it applies to
this one report, addressed to this one recipient, precisely because
that recipient is the person the approval gate exists to protect, not
someone the approval gate exists to protect *from*.

## Worked example

Run fires Monday, 2026-08-31, 08:00 — the nominal scheduled time
matches the wall clock exactly this week. Anchor: Monday, 2026-08-24,
08:00 (one cadence interval, 7 days, earlier). `digest_channel: email`
(the shipped default — no fallback disclaimer needed this run).

```
# Sales Partner Digest — 2026-08-31

## Awaiting approval (2)
- Meridian Robotics — email approach draft — [link]
- Fennimore Health — email follow-up draft ("thank you after call") — [link]

## Next actions due today (2)
- Fennimore Health — Send onboarding proposal — due 2026-08-28 (3 days overdue)
- Corvid Analytics — Await reply to approach; re-engage if none by 2026-08-31 — due 2026-08-31

## New leads scored (5, top 5 since last digest)
1. Solvent Robotics — 82.5 — buying trigger: posted six ops-eng roles in two weeks after a Series B
2. Northwind Logistics — 77.5 — on target list: mid-market logistics SaaS
3. Harrow Analytics — 71.0 — decision-maker reachable: VP Data identified with a verified LinkedIn profile
4. Bellcrest Health — 65.0 — on target list: healthtech, 80 employees
5. Quill Systems — 60.0 — geography: primary market, San Francisco

## Stalled (2)
- Thornfield Media — Contacted — last Activity 2026-08-22 (9 days, cadence is 4)
- Meridian Robotics — Replied — last Activity 2026-08-20 (11 days, cadence is 4)

## Movement (5)
- Harrow Analytics: Scored → Researched (2026-08-30)
- Fennimore Health: Call Scheduled → Call Held (2026-08-25)
- Meridian Robotics: Contacted → Replied (2026-08-28)
- Ashgrove Systems: Researched → Disqualified (2026-08-27; anti-signal — company size under floor)
- Bramwell & Co: Following Up → Lost (2026-08-29; touch limit exhausted, no positive outcome)
- Won: none this week

## Spend
$18.40 of $25.00/week Apify cap (74%) — $6.60 remaining this cap week
```

Harrow Analytics shows the anchor and the two changed sections working
together correctly: created 2026-08-25 (after the 2026-08-24 anchor),
scored 62.5 at prospecting, then re-scored by the Preparer to 71.0 and
advanced `Scored → Researched` on 2026-08-30 (also after the anchor, so
`Stage Changed At` clears the Movement filter too). It appears exactly
once in New leads scored — Created Time selected it, Score shows its
current, re-scored value — and exactly once in Movement, for the stage
transition. Neither section repeats what the other already said: New
leads scored never mentions the re-score or the transition, and
Movement never repeats the score. Next week's run, with the anchor
moved forward to 2026-08-31, will not see Harrow Analytics in either
section again — its Created Time and its `Stage Changed At` are both
now before the new anchor — which is the non-overlapping-windows
property holding across a second, later run for both of these sections
at once.

**Late-run illustration, same week.** Suppose the scheduler had instead
fired this run at 11:00 rather than 08:00. `nominal_time` is still
2026-08-31 08:00 — the scheduled moment, not the actual one — so the
window is still `(2026-08-24 08:00, 2026-08-31 08:00]`, unchanged.
Now suppose a new lead, Vantage Fleet, was created at 2026-08-31 09:30
— after `nominal_time`, during this run's own three-hour lag. It is
excluded from this run's New leads scored, because 09:30 is after the
window's upper edge, `08:00`, even though the run executing at 11:00
could otherwise see it. It is not lost: next week's run computes its
anchor as this week's `nominal_time` (2026-08-31 08:00), so Vantage
Fleet's 09:30 Created Time falls inside *that* window instead —
reported exactly once, the following week, regardless of what time
either run actually fired at. Had the query instead used "anything
after the anchor" with no upper bound, this run (executing at 11:00)
would have caught Vantage Fleet too, and next week's on-time run would
report it again — the double-report Finding 1 describes.

Delivered by Gmail to `sending_identity` (e.g. `Andrew Ho Choy
<andrew@example.com>`). Had `digest_channel` instead been `sms` with
no Twilio credential configured, the same body would still go by
Gmail, with this line prepended above the `#` heading:

```
Delivered by email — SMS is configured but no Twilio credential exists yet.
```

## Failure modes

- **Burying an empty approval queue under five sections of reporting.**
  Section 1 renders first even when its count is zero — `Awaiting
  approval (0)` — never dropped or moved beneath the reporting
  sections because "there's nothing to approve this week." A queue
  that's empty this run is still the queue; hiding it below reporting
  is exactly the ordering mistake **Why approvals lead** exists to
  prevent, and it is not a smaller mistake just because the count
  happens to be zero.
- **Recomputing "since last digest" from the wrong timestamp.**
  Using the actual moment this run executes (instead of the nominal
  scheduled time), or using a record's Score value or Stage name
  (instead of its Created Time or `Stage Changed At`) as a stand-in for
  "when this happened," breaks the non-overlapping-windows property the
  anchor formula depends on — consecutive runs either double-report
  a lead that landed near the boundary or skip it, and a late-firing
  or manually-triggered run computes a different anchor than a
  same-week on-time run would have, which it must not.
- **Leaving the window's upper edge unbounded.** Filtering New leads
  scored or Movement to "anything after the anchor," with no upper
  bound, looks correct and is not: a run that fires late (the normal
  condition for a scheduled job, not a rare one) then implicitly
  captures everything that exists up to its actual execution time,
  including records created after its own `nominal_time`. The
  following week's on-time run recomputes its anchor as this week's
  `nominal_time` and reports everything after *that* — which still
  includes the same record, since its timestamp is also after this
  week's `nominal_time`. Both digests report it: routine double
  reporting, not a boundary-case rarity, because scheduled jobs run
  late often. Step 3 of **The "since last digest" anchor** — bounding
  every windowed query at `nominal_time` on the upper edge, exactly
  like the anchor bounds it on the lower edge — is what closes this,
  and it is mandatory for New leads scored and Movement on every run,
  not only the runs a reviewer happens to notice ran late.
- **Silently falling back to email without saying so.** The fallback
  from `sms` to `email` when no Twilio credential exists is not itself
  a failure — it's the only sane behavior with a stubbed adapter. The
  failure is delivering that fallback digest with no disclaimer line,
  leaving the operator to assume SMS delivery is live when it never
  ran. Step 9's disclaimer line is mandatory whenever the fallback
  fires, never optional or paraphrased away.
