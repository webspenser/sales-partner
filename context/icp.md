# Ideal Customer Profile

Target firmographics, geography, roles, buying triggers, hard
disqualifiers, and the scoring rubric the pipeline scores every lead
against. Written by the `interview-business` skill (Phase 0) and
re-run whenever the target market changes; every bracketed section is a
prompt for that interview to replace with the operator's own answer.

The Prospector (Phase 1) and Preparer (Phase 2) are the only consumers
of this file. Neither invents a score, a trigger, or a disqualifier —
both apply what's written here mechanically and record their reasoning
against it.

## Firmographics

[Interview: get target industry or industries, company size (by
headcount and/or revenue), and company stage (bootstrapped, funded,
which stage, public). Name the bands explicitly — e.g., "50–500
employees" not "mid-market" — because the scoring rubric's Company size
criterion below scores against these exact bands.]

## Geography

[Interview: get the primary market (where the business actively sells
and can deliver), any secondary/serviceable markets, and any region
that is explicitly out of scope (time zone, regulatory, or
language/service reasons). Name these explicitly — the scoring rubric's
Geography criterion below scores against this list.]

## Target roles

[Interview: get the job titles and functions that make a real buyer or
influencer for this business — the person the Approacher should be
trying to reach at a company that scores well. Distinguish
decision-makers from influencers and gatekeepers, since Contacts in the
CRM carry that same three-way role tag.]

## Buying triggers

[Interview: get the events that indicate a company is newly in-market —
funding rounds, leadership changes, product launches, hiring surges,
expansion announcements, compliance deadlines, whatever the operator
has actually seen precede a deal. Each trigger listed here should be
something the Preparer can search for and cite with a source URL; a
trigger that can't be observed from outside the company doesn't belong
here.]

## Anti-signals

Hard disqualifiers. Any match sends the lead straight to `Disqualified`
from any stage, per `AGENT.md`'s lead state machine — this list is
checked mechanically, not weighed against other criteria the way the
scoring rubric below is.

[Interview: get the hard "never work with" conditions — company
types, industries, past-bad-fit patterns, or anything from
`business-profile.md`'s Disqualifiers section that can be checked
against a prospect from the outside. Also capture any explicit
"currently a customer" or "currently in an active deal" condition, and
any "prospect has opted out" or `Do Not Contact` condition — those are
checked before every other rule in this document.]

## Scoring rubric

Five weighted criteria, weights summing to 100. `score-lead` (used by
the Prospector and re-run by the Preparer) applies this table
mechanically and records a per-criterion breakdown — never a judgment
call in place of it. These are the shipped defaults; the interview may
adjust the weights or the anchor language for a specific business, but
**the five weights must always sum to 100.**

Verification: 25 + 20 + 10 + 25 + 20 = **100**.

| Criterion | Weight | 0 points | 50 points | 100 points |
|---|---|---|---|---|
| Industry fit | 25 | outside target list | adjacent | on target list |
| Company size | 20 | outside range | within one band | in range |
| Geography | 10 | unserviceable | serviceable | in primary market |
| Buying trigger present | 25 | none found | soft signal | explicit recent trigger |
| Decision-maker reachable | 20 | none identified | identified, no contact route | identified with contact route |

Anchor guidance, so two different readers score the same company the
same way:

- **Industry fit** — 0 if the company's industry does not appear on the
  Firmographics target list and has no reasonable adjacency to it; 50
  if it's a neighboring industry the business has served before but
  didn't name as primary target; 100 only if the industry is named on
  the target list above.
- **Company size** — 0 if headcount/revenue falls outside every band in
  Firmographics; 50 if it falls within one band's boundary but outside
  the sweet spot (e.g., just above or below the named range); 100 if it
  falls squarely inside the stated range.
- **Geography** — 0 if the company is in a region explicitly marked out
  of scope in Geography; 50 if it's in a secondary/serviceable market;
  100 if it's in the primary market named in Geography.
- **Buying trigger present** — 0 if prospecting found no event matching
  the Buying triggers list; 50 if there's an indirect or dated signal
  (e.g., a role posted months ago, an old funding round) without a
  clear recent event; 100 if research surfaces an explicit, recent,
  sourced trigger from the list, with a source URL. This criterion is
  usually a guess at Prospecting time and gets resolved for real by the
  Preparer's research — see Thresholds below.
- **Decision-maker reachable** — 0 if no person matching Target roles
  can be identified at the company; 50 if a matching person is
  identified by name/title but no contact route (verified email,
  LinkedIn profile) has been found; 100 if a matching person is
  identified with a verified contact route. Like the trigger criterion,
  this is usually a guess at Prospecting time and gets resolved by the
  Preparer.

Buying trigger present and Decision-maker reachable together carry 45
of the 100 points precisely because they are the two criteria
Prospecting can only estimate — the Preparer's research is what turns
an estimate into a sourced fact, which is why the lead is re-scored
after research (see Thresholds below).

### Thresholds

Two different gates, at two different pipeline stages, read from
`operating-config.md`:

- **`research_threshold` (default 60)** — gates entry into research. A
  lead at stage `Scored` is picked up by the Preparer only once its
  Prospector-assigned score is at or above this threshold (subject also
  to the research quota). Leads below it stay at `Scored` and are never
  researched.
- **`approach_threshold` (default 70)** — gates entry into outreach
  drafting. A lead at stage `Researched` is picked up by the Approacher
  only once its score — re-computed by the Preparer against this same
  rubric, after research resolves the Buying trigger and
  Decision-maker criteria above — is at or above this threshold. This
  is a second, later gate applied to a re-scored number, not the same
  check repeated: a lead can clear `research_threshold` on a
  Prospector guess and still fail to clear `approach_threshold` once
  research finds no real trigger or no reachable decision-maker.
