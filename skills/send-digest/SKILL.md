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

> **Anchor = the previous scheduled occurrence of `digest_schedule`,
> exactly one cadence interval before this run's nominal scheduled
> time.**

Concretely, with the shipped default `digest_schedule: "Monday
08:00"`, the cadence interval is 7 days. To compute the anchor for any
given run:

1. Find this run's **nominal** scheduled time: the most recent
   occurrence of `digest_schedule`'s weekday and time at or before the
   actual moment this skill executes. This is deliberately *not* "the
   actual wall-clock time the skill happens to run" — a run fired
   exactly on time, a run fired three hours late because the scheduler
   was delayed, and a run triggered manually on Wednesday for review
   all round down to the same nominal time (the most recent Monday
   08:00), and therefore compute the same anchor.
2. Subtract one cadence interval (7 days for the default weekly
   schedule) from that nominal time. That is the anchor.

This anchor comes from `operating-config.md` and calendar arithmetic
alone — never from a stored "last digest sent" value, because no such
field exists among the CRM contract's nine operations
(`crm-contract.md`) and this skill does not invent one. That is also
why the anchor must be schedule-derived rather than
run-time-derived: two *consecutive normal-cadence* runs divide the
calendar into adjoining, non-overlapping seven-day windows by
construction, so nothing in that window is ever reported twice or
skipped between them. (The one case this doesn't cover: if a
scheduled run is skipped outright — the scheduler never fires it at
all — the next run's anchor still only looks back one interval, so an
entire missed week's movement is not caught retroactively. That is a
scheduling-reliability problem outside this skill's scope, not a bug
in the anchor formula.)

Record-level timestamps are compared against the anchor per section:

- **New leads scored** compares each Lead record's own **Created
  Time** — the timestamp the Airtable adapter stamps on every row the
  moment `create_lead` writes it — against the anchor. Created Time is
  store-level record metadata, not one of the fields
  `crm-airtable-adapter.md` declares on the Leads table; it needs no
  new field because every record already carries it.
- **Movement** compares each Lead record's own **Last Modified Time**
  (the same kind of native record metadata, tracking the most recent
  write to the record) against the anchor. `crm-contract.md`'s
  `update_stage` does not return or expose a dedicated "stage changed
  at" value, so Last Modified Time is the closest available signal for
  "this lead's state changed recently." If a later revision of the CRM
  contract adds an explicit stage-change timestamp, this section
  should read that field directly instead.

## This skill reads; it never writes

Its only side effect anywhere is delivering the finished digest. It
never calls `create_lead`, `update_stage`, `update_lead`,
`log_activity`, `log_research`, or `upsert_contact` — no stage moves,
no field edits, no Activity or Research row, not even a "digest sent"
marker. The reads it does use, named precisely:

- CRM **`query_by_score`** (`min_score: 0, stage: "Scored"`, ordered by
  Score descending per the contract) — Section 3, New leads scored.
- CRM **`query_by_stage`**, called once per stage of interest — Section
  5, Movement.
- The Airtable adapter's three purpose-built views —
  **Awaiting Approval**, **Due Today**, and **Stalled**
  (`crm-airtable-adapter.md`) — for Sections 1, 2, and 4. None of the
  nine contract operations takes an Activity-status filter, a
  due-date filter, or a stale-Activity filter; that gap is exactly why
  those three views exist as required, adapter-level reads rather than
  something this skill reconstructs from `query_by_stage` or
  `query_by_score`.
- Apify's own usage data — Section 6. This is the one section with no
  CRM read at all; Apify spend is not CRM data and never was.

## Procedure

1. Compute the anchor timestamp per **The "since last digest" anchor**
   above.
2. **Section 1 — Awaiting approval.** Read the Airtable adapter's
   Awaiting Approval view (Activities where `Status = draft`, sorted
   by `Date`). Record the count and, for every row, a link to the
   Activity (or its parent Lead if the adapter exposes no
   per-Activity link) and the channel. No window applied — this is
   every draft outstanding right now, however old.
3. **Section 2 — Next actions due today.** Read the Due Today view
   (Leads where `Next Action Due` is today or earlier). List each
   lead's `Next Action` and `Next Action Due`. No window applied —
   overdue items stay listed every run until acted on; that is the
   point of a due-date view, not a bug.
4. **Section 3 — New leads scored.** Call `query_by_score(min_score:
   0, stage: "Scored", limit: 50)`. Filter to leads whose Created Time
   falls after the anchor. Take the first five of what remains
   (already ordered by Score descending). For each, derive its
   one-line rationale from `Score Breakdown`: parse the five
   `<criterion> <score>×<weight/100>=<points> (<justification>)`
   lines the `score-lead` skill wrote, take the line with the highest
   `<points>` value, and keep only its parenthetical justification —
   drop the arithmetic. If fewer than five leads clear the anchor
   filter, list however many there are; if none do, render the
   heading with `None` under it rather than omitting the heading (see
   Failure modes).
5. **Section 4 — Stalled.** Read the Stalled view (Leads with no
   Activity newer than `follow_up_cadence_days`, from
   `operating-config.md`). List each lead, its `Stage`, and the date of
   its last Activity. No anchor window applied — staleness is measured
   against *now*, every run, independent of when the last digest fired.
6. **Section 5 — Movement.** Call `query_by_stage` once for each stage
   that signals movement worth reporting — at minimum `Won`, `Lost`,
   and `Disqualified`, plus any of `Contacted`, `Replied`, `Call
   Scheduled`, `Call Held`, `Following Up` the operator has asked to
   see. For each stage's results, keep only leads whose Last Modified
   Time falls after the anchor, and list them as `<Company>: → <Stage>
   (<date>, <reason if one was recorded on the transition>)`. Call out
   `Won`, `Lost`, and `Disqualified` explicitly, even when the list for
   one of them is empty (write "No wins this week" rather than
   dropping the line).
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
Activity and walked through `draft` → `approved` → `sent`. The digest
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

## Next actions due today
- Fennimore Health — Send onboarding proposal — due 2026-08-28 (3 days overdue)
- Corvid Analytics — Await reply to approach; re-engage if none by 2026-08-31 — due 2026-08-31

## New leads scored (top 5 since last digest)
1. Solvent Robotics — 82.5 — buying trigger: posted six ops-eng roles in two weeks after a Series B
2. Northwind Logistics — 77.5 — on target list: mid-market logistics SaaS
3. Harrow Analytics — 71.0 — decision-maker reachable: VP Data identified with a verified LinkedIn profile
4. Bellcrest Health — 65.0 — on target list: healthtech, 80 employees
5. Quill Systems — 60.0 — geography: primary market, San Francisco

## Stalled
- Thornfield Media — Contacted — last Activity 2026-08-22 (9 days, cadence is 4)
- Meridian Robotics — Replied — last Activity 2026-08-20 (11 days, cadence is 4)

## Movement
- Fennimore Health: Call Scheduled → Call Held (2026-08-25)
- Meridian Robotics: Contacted → Replied (2026-08-28)
- Ashgrove Systems: Researched → Disqualified (2026-08-27; anti-signal — company size under floor)
- Bramwell & Co: Following Up → Lost (2026-08-29; touch limit exhausted, no positive outcome)
- Won: none this week

## Spend
$18.40 of $25.00/week Apify cap (74%) — $6.60 remaining this cap week
```

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
  (instead of its Created/Last Modified Time) as a stand-in for "when
  this happened," breaks the non-overlapping-windows property the
  anchor formula depends on — consecutive runs either double-report
  a lead that landed near the boundary or skip it, and a late-firing
  or manually-triggered run computes a different anchor than a
  same-week on-time run would have, which it must not.
- **Silently falling back to email without saying so.** The fallback
  from `sms` to `email` when no Twilio credential exists is not itself
  a failure — it's the only sane behavior with a stubbed adapter. The
  failure is delivering that fallback digest with no disclaimer line,
  leaving the operator to assume SMS delivery is live when it never
  ran. Step 9's disclaimer line is mandatory whenever the fallback
  fires, never optional or paraphrased away.
