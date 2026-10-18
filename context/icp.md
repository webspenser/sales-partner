# Ideal Customer Profile

Target firmographics, geography, roles, buying triggers, hard
disqualifiers, and the two scoring rubrics the pipeline scores every lead
against. Written by the `interview-business` skill (Phase 0) and
re-run whenever the target market changes; every bracketed section is a
prompt for that interview to replace with the operator's own answer.

The Prospector (Phase 1) and Preparer (Phase 2) are the only consumers
of this file. Neither invents a score, a trigger, or a disqualifier —
both apply what's written here mechanically and record their reasoning
against it.

## Target type

```yaml
target_type: company   # company | local_business
```

Recorded by the interview's first ICP question. It only chooses which
examples the interview offers — B2B firmographics and funding triggers
for `company`, map-listing facts (including the listing criteria in the
Fit score) and storefront triggers for `local_business`. Every rubric
rule below applies identically to both.

## Firmographics

**Target industries are the catalog's.** The industries this business
targets are the `industries` lists of the segments in
`context/offer-catalog.md`, and only those; this file keeps no industry
list of its own, so the two can't disagree. The Fit rubric's Industry
fit criterion scores against them.

[Interview: get size as bands in `size_measure` (below), and company
stage (bootstrapped, funded, which stage, public). Name the bands
explicitly — e.g., "50–500 employees" or "1–3 locations," not
"mid-market" — because the Fit rubric's Company size criterion below
scores against these exact bands. Industries go in the offer catalog,
not here.]

```yaml
size_measure: headcount   # headcount | revenue | locations | review_count
```

The Company size criterion scores against bands in this measure. A
local business rarely publishes headcount; `locations` or
`review_count` (from a map listing) are observable from outside and
score just as mechanically.

## Geography

[Interview: get the primary market (where the business actively sells
and can deliver), any secondary/serviceable markets, and any region
that is explicitly out of scope (time zone, regulatory, or
language/service reasons). Name these explicitly — the Fit rubric's
Geography criterion below scores against this list.]

Optional service area. When set, it *is* the primary market:

```yaml
service_area:
  center: ""     # street address or city; empty = not used
  radius: 25
  unit: km       # km | mi
```

When `center` is empty, Geography scores against the region lists
above exactly as before.

## Target roles

[Interview: get the job titles and functions that make a real buyer or
influencer for this business — the person the talking points should
be aimed at at a company that scores well. Distinguish
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

Examples for `target_type: local_business`, each observable from
outside with a source URL: a new opening or new location; hiring
(storefront signs, job boards); no website, or one visibly outdated;
a recent ownership change; a surge or drop in reviews.

## Anti-signals

Hard disqualifiers. Any match sends the lead straight to `Disqualified`
from any stage, per the lead state machine in
`capabilities/crm/contract.md` (Lead status transitions) — this list is
checked mechanically, not weighed against other criteria the way the
scoring rubric below is.

[Interview: get the hard "never work with" conditions — company
types, industries, past-bad-fit patterns, or anything from
`business-profile.md`'s Disqualifiers section that can be checked
against a prospect from the outside. Also capture any explicit
"currently a customer" or "currently in an active deal" condition, and
any "prospect has opted out" or `Do Not Contact` condition — those are
checked before every other rule in this document.]

Shipped for every lead found on a map listing, whatever the interview
adds:
- **Temporarily closed**: the listing is marked temporarily closed.
  (Permanently closed listings are dropped before scoring.)

## Scoring rubric

Scoring is split into two rubrics, so each scores only what can
actually be observed at that stage:

- **Fit score** — scored by the Prospector from the source listing
  alone (for a map find, the Google Maps listing), and compared against
  `research_threshold`.
- **Approach score** — scored by the Preparer from research findings
  only. It no longer gates anything: it records how strong the research
  found the lead to be. Fit already passed the first gate, so it is not
  counted again here.

`score-lead` applies the matching table mechanically and records a
per-criterion breakdown, never a judgment call in place of it. Every
criterion scores only 0, 50 or 100. These are the shipped defaults; the
interview may change the criteria, the weights or the anchor language
for a specific business, but **each table's weights must always sum to
100.**

### Fit score (research gate)

Verification: 40 + 30 + 30 = **100**.

| Criterion | Weight | 0 points | 50 points | 100 points |
|---|---|---|---|---|
| Industry fit | 40 | outside target list | adjacent | on target list |
| Company size | 30 | outside range | within one band | in range |
| Geography | 30 | unserviceable | serviceable | in primary market |

For `target_type: local_business`, the interview also offers these
listing criteria, each read from the map listing (and re-weights the
table so it still sums to 100):

| Criterion | 0 points | 50 points | 100 points |
|---|---|---|---|
| Website on listing | website linked from the listing | (not used) | no website linked from the listing |
| Phone listed | no phone on the listing | (not used) | phone on the listing |
| Opening hours | open 24/7 | no hours listed (unknown) | closed evenings or weekends |
| Review sentiment | rating below 3.0 | rating 4.5 or higher | rating 3.0–4.4, or 15%+ of reviews are one-star |
| Unclaimed listing | listing claimed | (not used) | listing unclaimed |

### Approach score

Verification: 50 + 30 + 20 = **100**.

| Criterion | Weight | 0 points | 50 points | 100 points |
|---|---|---|---|---|
| Buying trigger present | 50 | none found | dated or indirect signal, sourced | explicit recent trigger, sourced |
| Decision-maker reachable | 30 | none identified | identified, no direct contact route | identified with a direct contact route |
| Review recency | 20 | no review in the last 12 months, or not sourced | latest review 3–12 months old | a review within the last 3 months |

### Anchor guidance

So two different readers score the same company the same way.

Fit score:

- **Industry fit** — the target list is every segment's `industries`
  in `context/offer-catalog.md` (see Firmographics). 0 if the company's
  industry appears in no segment's list and has no reasonable adjacency
  to one; 50 if it's a neighboring industry the business has served
  before but the catalog doesn't name; 100 only if the industry is named
  in a segment's `industries`, which is also the lead's Segment.
- **Company size** — measured against the bands in `size_measure`: 0
  if the lead's size falls outside every band in Firmographics; 50 if
  it falls within one band's boundary but outside the sweet spot
  (e.g., just above or below the named range); 100 if it falls
  squarely inside the stated range.
- **Geography** — when `service_area.center` is set: 100 if the lead's
  sourced address is within `radius` of `center`; 50 if it is outside
  the radius but in a named secondary market; 0 otherwise. Distance
  counts only when it comes from a sourced map or geocoding result,
  cited by URL in the justification. No sourced address scores 0 as
  `no sourced address — unverified`; an address with no sourced
  distance scores 0 as `distance not sourced — unverified`. Distance
  is never estimated from memory, a city name, or an area code. A
  great-circle distance computed from the listing's coordinates and
  sourced coordinates for `center` counts as sourced; cite both. When
  `service_area.center` is empty: 0 if the company is in a region
  explicitly marked out of scope in Geography; 50 if it's in a
  secondary/serviceable market; 100 if it's in the primary market
  named in Geography.
- **Listing criteria** (when the interview adds them) — read only from
  the listing: Website on listing is 100 when the listing links no
  website, whether or not a site exists elsewhere (an outdated site is
  a research finding, not a Fit criterion); Opening hours is 100 when
  the business is closed on weekday evenings or on at least one weekend
  day, 0 when listed as open 24 hours, 50 when no hours are posted;
  Review sentiment uses the star rating and the per-star counts —
  a rating below 3.0 scores 0 first, and the one-star share counts only
  for a rating of 3.0 or higher — and a listing with no reviews scores
  50; Unclaimed listing is 100 when the
  listing shows it is unclaimed by its owner.

Approach score:

- **Buying trigger present** — 0 if research found no event from the
  Buying triggers list; 50 if the strongest sourced signal is indirect
  or dated (e.g., a role posted months ago, an old funding round); 100
  if research surfaces an explicit, recent trigger from the list, with
  a source URL.
- **Decision-maker reachable** — 0 if no person matching Target roles
  can be identified at the company; 50 if a matching person is
  identified by name/title but no direct contact route has been found;
  100 if a matching person is identified with a verified direct contact
  route (verified email, LinkedIn profile, or
  a sourced direct phone number). The business's main phone line is not
  a direct route.
- **Review recency** — the date of the most recent review, read by the
  Preparer from the listing or a review site and cited by URL: 100
  within the last 3 months; 50 if 3–12 months old; 0 if older or not
  sourced. For `target_type: company`, the interview may replace it
  with the date of the company's latest news, post or announcement,
  on the same tiers.

### Thresholds

One gate, read from `operating-config.md`:

- **`research_threshold` (default 60)** — gates entry into research. A
  lead at stage `Scored` is picked up by the Preparer only once its
  **Fit score** is at or above this threshold (subject also to the
  research quota, which ranks leads above the threshold by Fit score).
  Leads below it stay at `Scored` and are never researched.
- The **Approach score** has no threshold. The Preparer still computes
  it from research findings and records it with its breakdown for the
  operator to read, but nothing is picked up or held back by it.
