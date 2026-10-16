---
name: score-lead
description: Use when a lead needs a Fit score (at prospecting) or an Approach score (after research) — applies the matching rubric in context/icp.md and records the per-criterion breakdown.
---

This skill carries no rubric of its own. Every criterion, weight and
anchor comes from `context/icp.md` at the moment the skill runs, so a
change to that file changes scoring behavior immediately, with no edit
to this skill ever required.

## Argument

`rubric` — `fit` or `approach`. It picks the table, the evidence the
skill may use, and the fields it writes:

| `rubric` | Table in `icp.md` | Scored by | Evidence | Writes | Gate |
|---|---|---|---|---|---|
| `fit` | `### Fit score` | Prospector | the source listing only | `Fit Score`, `Fit Breakdown` | `research_threshold` |
| `approach` | `### Approach score` | Preparer | research findings only | `Approach Score`, `Approach Breakdown` | `approach_threshold` |

Each run writes only its own rubric's two fields. An `approach` run
never writes, overwrites or clears `Fit Score` or `Fit Breakdown`, and a
`fit` run never touches the Approach fields.

## Procedure

1. Read `context/icp.md`'s Anti-signals list and the table under the
   heading for `rubric` (criterion, weight, and 0/50/100 anchor
   language), with its Anchor guidance, fresh — never from a cached or
   remembered copy. The table has as many rows as the operator chose;
   score every row it holds. If its weights do not sum to 100, stop and
   report it: the rubric is broken, and no score is written.
2. Check the lead against every anti-signal first, before scoring
   anything. On any match: stop scoring, call CRM
   `update_stage(lead_id, "Disqualified", reason)` with the matched
   anti-signal as the reason, and write no score and no breakdown. A
   disqualified lead is never scored.
3. If no anti-signal matched, score each criterion against its stated
   anchors, using only the values 0, 50, or 100 — never an intermediate
   number. Ground each score in something observed, never an overall
   impression of the company, and only in the evidence `rubric` allows:

   - **`fit`** reads the source listing's fields (for a map find, the
     `find_businesses` result: address, coordinates, phone, website,
     category, rating, per-star review counts, review count, opening
     hours, claimed or not). Nothing from research counts here. A lead
     found with no map listing (by web search alone) scores 0 on every
     listing criterion, with the justification `no listing —
     unverified`.
   - **`approach`** reads research findings: the lead's Research rows
     and Contacts, and the newest review date the Preparer sourced,
     each with its source URL. A criterion research did not source scores 0
     with the justification `not sourced — unverified`.

   Geography under a `service_area`: distance from the lead's sourced
   address to `service_area.center` counts only when it comes from a
   sourced map or geocoding result, cited by URL in the Geography
   justification. A great-circle distance between the listing's
   coordinates and the center's sourced coordinates counts as sourced;
   cite both. A lead with no sourced address scores 0 on Geography
   with the justification `no sourced address — unverified`. A lead
   with an address but no sourced distance scores 0 with the
   justification `distance not sourced — unverified`. Distance is never
   estimated from memory, a city name, or a phone area code.
4. For each criterion, multiply the 0/50/100 score by weight ÷ 100 to
   get its weighted points, and write the working as one line in the
   form `<Criterion> <score>×<weight/100>=<points> (<justification,
   with a source URL when one exists>)`, in the table's row order.
5. Sum every row's weighted points to get the total (0–100), and end
   the breakdown with `Total: <points>+<points>+…=<total>`.
6. Write the score:
   - **`fit`, new lead** (from within the Prospector): pass the total
     and the breakdown as `fit_score` and `fit_breakdown` to CRM
     `create_lead`. This is the only write path for a new lead's first
     score: the lead has no `lead_id` yet for `update_lead` to target.
   - **`fit`, existing lead** (a re-found lead at `New`, or the
     operator asking for one, with the lead's current listing): call
     CRM `update_lead(lead_id, {"Fit Score": total, "Fit Breakdown":
     text})`.
   - **`approach`** (from within the Preparer, after research, or the
     operator asking for one): call CRM `update_lead(lead_id,
     {"Approach Score": total, "Approach Breakdown": text})`.

   When the breakdown field already holds a block, this is a re-score:
   `text` is the existing breakdown with the new block **appended**,
   opened with the line `re-scored — <date> (<why>)`. Never overwrite
   or delete an earlier block: the record keeps every score it has had.
7. Hand the total back to the calling context. `score-lead` does not
   decide `Stage` beyond the anti-signal short-circuit in step 2 — the
   Prospector and Preparer each apply their own threshold from
   `operating-config.md` to decide what happens next.

## Worked example

Fictional lead: **Harbor Line Plumbing**, scored against a
`local_business` `icp.md` whose rubrics are:

| Fit criterion | Weight | | Approach criterion | Weight |
|---|---|---|---|---|
| Industry fit | 25 | | Buying trigger present | 50 |
| Geography | 15 | | Decision-maker reachable | 30 |
| Company size | 5 | | Review recency | 20 |
| Website on listing | 10 | | | |
| Phone listed | 10 | | | |
| Opening hours | 15 | | | |
| Review sentiment | 10 | | | |
| Unclaimed listing | 10 | | | |

with `research_threshold` 55 and `approach_threshold` 70.

**Fit — at prospecting**, from the Maps listing alone: a plumber (a
target industry) 10 mi from the center, 80 reviews, a website and a
phone on the listing, closed Sundays, rated 4.1, listing claimed.

```
Industry fit 100×0.25=25 (Maps category 'Plumber', a target industry; <listing URL>)
Geography 100×0.15=15 (10.0 mi great-circle between the listing's coordinates [<listing URL>] and service_area.center_geocode [<geocode URL>]; within 25 mi)
Company size 100×0.05=5 (80 Google reviews, 0–249 band; <listing URL>)
Website on listing 0×0.10=0 (listing links https://harborlineplumbing.example)
Phone listed 100×0.10=10 (listing shows +15105550142)
Opening hours 100×0.15=15 (listing hours: closed Sunday)
Review sentiment 100×0.10=10 (rating 4.1, in 3.0–4.4)
Unclaimed listing 0×0.10=0 (listing is claimed)
Total: 25+15+5+0+10+15+10+0=80
```

Fit 80 is written through `create_lead`. It clears `research_threshold`
(55), so the Preparer will pick the lead up.

**Approach — after research**, from research findings only: the
strongest trigger is weak (a review-count jump, sourced), the owner is
named but reachable only through the main line, and the newest review
is five weeks old.

```
Buying trigger present 50×0.50=25 (weak #6: review count rose from 52 to 80 since March; <review site URL>)
Decision-maker reachable 50×0.30=15 (Dana Ortiz, Owner, named on the state license record <license URL>; only the business's main line found)
Review recency 100×0.20=20 (newest Google review dated 2026-09-08; <listing URL>)
Total: 25+15+20=60
```

Approach 60 is written through `update_lead`; `Fit Score` stays 80,
untouched. 60 is below `approach_threshold` (70), so the Approacher
does not pick the lead up. Had research found the owner's verified
email, Decision-maker reachable would read `100×0.30=30` and the total
would be 25+30+20 = **75**, which clears 70.

A score holds the exact value the arithmetic produces, including any
half: an adjacent industry at weight 25 scores `50×0.25=12.5`, and a
total of 67.5 stays 67.5, never rounded to 67 or 68. The thresholds are
plain integers, so each gate is a direct `score >= threshold` against
that exact value; no rounding step exists, so no lead is ever left
sitting ambiguously on a threshold.

## Failure modes

- **Scoring from impression rather than the rubric.** "This company
  feels like a good fit" is not a score. Every criterion traces to one
  of `icp.md`'s stated anchors and, where possible, a source.
- **Scoring with the other gate's evidence.** A Fit criterion read from
  research, or an Approach criterion guessed at prospecting, puts back
  the problem the two rubrics exist to remove: a criterion only
  research can resolve, scored before research, holds every lead below
  the first gate.
- **Omitting the breakdown.** A score with no breakdown is unauditable
  and untunable — nobody, including the operator, can tell why a lead
  scored 75 instead of 60, or adjust the rubric with confidence later.
- **Scoring a lead that matched an anti-signal instead of
  disqualifying it.** Step 2 runs before step 3 for exactly this
  reason — a matched anti-signal is never weighed against the
  criteria; it ends the run.
- **Overwriting a breakdown.** A re-score appends a block; an Approach
  score never touches the Fit fields. Either overwrite hides why a lead
  passed a gate it may no longer pass.
