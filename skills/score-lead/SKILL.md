---
name: score-lead
description: Use when a lead needs a score or a re-score — applies the weighted rubric in context/icp.md and records the per-criterion breakdown.
---

This skill carries no rubric of its own. Every weight and every anchor
comes from `context/icp.md` at the moment the skill runs, so a change
to that file changes scoring behavior immediately, with no edit to this
skill ever required.

## Procedure

1. Read `context/icp.md`'s Anti-signals list and its five-row Scoring
   rubric table (criterion, weight, and 0/50/100 anchor language) fresh
   — never from a cached or remembered copy.
2. Check the lead against every anti-signal first, before scoring
   anything. On any match: stop scoring, call CRM
   `update_stage(lead_id, "Disqualified", reason)` with the matched
   anti-signal as the reason, and write nothing to `Score` or `Score
   Breakdown`. A disqualified lead is never scored.
3. If no anti-signal matched, score each of the five criteria against
   its stated anchors, using only the values 0, 50, or 100 — never an
   intermediate number. Ground each score in something observed (a
   fact from the lead record or research), never an overall impression
   of the company.
4. For each criterion, multiply the 0/50/100 score by weight ÷ 100 to
   get its weighted points, and write the working as one line in the
   form `<Criterion> <score>×<weight/100>=<points> (<justification,
   with a source URL when one exists>)`.
5. Sum the five weighted-points values to get the total (0–100).
6. **First run** (scoring a new lead, called from within the
   Prospector): pass the total and the five breakdown lines as the
   `score` and `score_breakdown` arguments to CRM `create_lead` — this
   is the only write path for a lead's first score, since `create_lead`
   takes them directly and the lead has no `lead_id` yet for
   `update_lead` to target.
7. **Second run** (re-scoring an existing lead after research, called
   from within the Preparer): recompute all five criteria — Buying
   trigger present and Decision-maker reachable are the two that
   research typically moves, since they were estimates before; the
   other three usually don't change. Call CRM `update_lead(lead_id,
   {Score: new_total, "Score Breakdown": appended_text})`, where
   `appended_text` is the existing `Score Breakdown` value with a new
   block **appended**, not replacing it — opened with the line
   `re-scored after research — <date>`, followed by the new five
   breakdown lines. Never overwrite or delete the first block; the
   point of appending is that the movement from guess to sourced fact
   stays visible in the record.
8. Hand the total back to the calling context. `score-lead` does not
   decide `Stage` beyond the anti-signal short-circuit in step 2 — the
   Prospector and Preparer each apply their own threshold from
   `operating-config.md` (`research_threshold`, `approach_threshold`)
   to decide what happens next.

## Worked example

Fictional lead: **Corvid Analytics**, a B2B SaaS data platform, 48
employees, Toronto. The operator's confirmed rubric in `icp.md` (a
small, operator-approved adjustment from the shipped default — 1 point
moved from Industry fit to Buying trigger) is:

| Criterion | Weight |
|---|---|
| Industry fit | 24 |
| Company size | 20 |
| Geography | 10 |
| Buying trigger present | 26 |
| Decision-maker reachable | 20 |

**Run 1 — at prospecting**, on public signals only:

```
Industry fit 100×0.24=24 (on target list: B2B SaaS)
Company size 50×0.20=10 (48 employees; within one band boundary of the 50–500 target range)
Geography 50×0.10=5 (Toronto — secondary/serviceable market; primary market is US)
Buying trigger present 50×0.26=13 (soft signal: LinkedIn mentions a "recent Series A" with no date; no explicit recent event found)
Decision-maker reachable 50×0.20=10 (Priya Shah, VP of Revenue Operations, identified by name/title on LinkedIn company page; no contact route found)
```

Total: 24+10+5+13+10 = **62**. Written via `create_lead`. 62 clears
`research_threshold` (60), so the lead enters research; it does not yet
clear `approach_threshold` (70).

**Run 2 — after research**, decision-maker reachability resolved
(buying trigger unchanged — research found nothing fresher than the
same soft signal):

```
re-scored after research — 2026-08-20
Industry fit 100×0.24=24 (unchanged: on target list, B2B SaaS)
Company size 50×0.20=10 (unchanged: 48 employees)
Geography 50×0.10=5 (unchanged: Toronto, secondary market)
Buying trigger present 50×0.26=13 (unchanged: no explicit recent trigger found in research; same soft signal stands)
Decision-maker reachable 100×0.20=20 (Priya Shah's LinkedIn profile confirmed current as VP of Revenue Operations — contact route verified: linkedin.com/in/priyashah-example)
```

Total: 24+10+5+13+20 = **72**. Written via `update_lead`, with the
`re-scored after research` block appended to the Run 1 breakdown, not
replacing it. 72 clears `approach_threshold` (70) — the lead is ready
for the Approacher.

## Failure modes

- **Scoring from impression rather than the rubric.** "This company
  feels like a good fit" is not a score. Every criterion traces to one
  of `icp.md`'s stated anchors and, where possible, a source.
- **Omitting the breakdown.** A `Score` with no `Score Breakdown` is
  unauditable and untunable — nobody, including the operator, can tell
  why a lead scored 72 instead of 62, or adjust the rubric with
  confidence later.
- **Scoring a lead that matched an anti-signal instead of
  disqualifying it.** Step 2 runs before step 3 for exactly this
  reason — a matched anti-signal is never weighed against the other
  four criteria; it ends the run.
- **Overwriting the first breakdown instead of appending.** Replacing
  `Score Breakdown` on the second run hides why the score moved between
  Prospecting and Research — the whole point of the re-score is that
  the record shows the estimate and the resolved fact side by side.
