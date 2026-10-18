---
name: research-company
description: Use when a lead enters the research quota — gathers recent, specific, verifiable facts about a company, converts them into usable outreach hooks, and records the signals and rule-outs of its segment's offers.
---

Every claim this skill produces about a prospect carries a source URL.
An inference that isn't directly sourced is marked `unverified` in
`Summary` rather than stated as fact. Nothing here is scraped from
behind a login, and nothing here drafts or sends anything — this skill
only gathers and records.

## Procedure

1. Read `context/operating-config.md`'s `research_budget_per_lead_minutes`
   before starting, and track elapsed time against it — this is the
   stop condition for the whole run, not a suggestion.
2. Read the lead's segment in `context/offer-catalog.md`: the segment
   whose `id` is the lead's Segment, and each of its offers' `signals`
   and `rule_out` entries. These are what separates one offer from
   another, so the search below looks for every one of them alongside
   the hooks (reviews, the listing, the website, job posts). Look only at
   this segment's offers. With no Segment, or one the catalog doesn't
   hold, skip this step and say so in the run's report.
3. Search in this fixed order, moving to the next source only once the
   current one is exhausted or clearly unproductive:
   1. Company site and blog
   2. Recent news
   3. Funding and hiring signals
   4. Executive social posts (public posts only — read-only, never an
      automated action behind a login)
   5. Industry events (speaking slots, sponsorships, published
      attendee lists)
   6. For a local business: its map or directory listing (rating,
      review count, hours, recent reviews, and the business's main line
      and general inbox → `listing`) and whether it has a website and
      what state it is in (`web_presence`)

   The scraping sources the Preparer runs from the offers' tips
   (reviews, ads, job posts, the website reader) feed items 1, 3 and 6;
   record their results as in Evidence-source findings below.
4. Collect each finding worth recording as you go, and write them all
   at the end of the run with one CRM `log_research(lead_id,
   findings[])` call, each finding with `type, summary, source_url,
   date, hook`:
   `Type` from {news, funding, social, event, hire, listing, web_presence};
   `Summary` states what was learned in enough detail to stand alone;
   `Source URL` is required and non-empty; `Date` is the finding's
   actual date, not today's date. `log_research` itself rejects a call
   when any finding has an empty `source_url` or an empty `hook`, so a
   finding with no usable hook is left out of the call — see step 5.
5. Two kinds of finding are always recorded when sourced, whatever the
   bar below:
   - A contact route: the business's main line or general inbox (info@)
     becomes a `listing` finding with `Hook: contact route`, so the
     talking points can name it as a route to the lead.
   - A catalog signal or rule-out from step 2: one finding each, under
     the one of the seven types its source fits (a review or a listing
     detail → `listing`, a job post → `hire`, a claim on the website →
     `web_presence`, a news item → `news`). Its `Summary` says what was
     found and ends with the catalog entry it matches, in the form
     `Signal for <offer id>: "<signals entry>".` or `Rule-out for <offer
     id>: "<rule_out entry>".`; quote the entry exactly as the catalog
     words it. Its `Hook` is the usable angle when the finding clears the
     bar below, and otherwise `offer signal` or `rule-out`. `match-offer`
     weighs these findings to pick the lead's offer.
   For every other finding, before writing,
   decide whether the finding clears the bar for a
   usable hook. A hook is usable only if it is **all three**:
   - **Specific to this company** — not a fact true of the whole
     industry or every company its size.
   - **Recent** — under 90 days old as of today.
   - **Something the operator could plausibly have an opinion about** —
     an event, a decision, or a change, not a static fact like "they
     are in SaaS."
   If a finding clears this bar, write the `Hook` as the specific
   angle an outreach draft could open with. If it does not, the finding
   may still be worth noting in `Summary` for context, but do not
   force a `Hook` out of it — see the anti-signal-shaped failure mode
   below.
6. Stop the search — even mid-order — once either: two or more usable
   `Hook` values have been written for this lead **and** every Approach
   criterion in `icp.md` and every signal and rule-out from step 2 has
   been looked for (for a local business, item 6 is always searched: the
   newest review date, recent complaint reviews and the website check), or the
   `research_budget_per_lead_minutes` budget is spent. Whichever comes
   first ends the run; a thorough search that blows the time budget is
   still a failure of this skill.
7. If the full search order is exhausted inside the budget and zero
   usable hooks were found, write one more finding recording that
   explicitly, alongside any step-5 findings (`Summary: "No hooks found
   — searched company site, news, funding/hiring signals, and social
   within budget"`, `Hook: "no hooks found"`, with whatever `Source URL`
   best represents the search — e.g. the company's own site) rather than
   leaving the lead with no research trail at all. The contact routes,
   signals and rule-outs step 5 records are kept beside it, never
   dropped for it.

## Evidence-source findings

Each result becomes findings of the seven types, each with its source
URL, under the step 5 and usable-hook rules above.

- **Reviews (`find_reviews`) → `listing`.** The Preparer passes
  `personalData: false`, so the reviews come back without their
  reviewers. A finding quotes only the words of the review that show the
  signal or rule-out, gives the review's date as `Date`, and links the
  place's Maps URL as `Source URL` (there is no per-review URL). A review finding never carries a reviewer's name, and names of people in
  the text (a technician's first name) are left out of the quote. The
  newest review's date is the Approach rubric's review date.
- **Job posts (`find_jobs`) → `hire`.** The title and date posted, with
  the listing's URL. Zero listings means no open listings under that
  name: it is not a finding.
- **Ads (`find_ads`) → `web_presence`, presence only.** Whether the
  business runs Google ads (the advertiser's Ads Transparency URL) or
  Facebook ads (its own page's ad count, with the page URL), never what
  the ads say. No advertiser found is not a finding: the search may
  simply have missed one.
- **Site features (`read_site`) → `web_presence`.** For each feature
  the tips name (online booking, a client portal, a quote form), say
  "has" or "lacks", with the page checked as `Source URL`. "Lacks" is
  claimed only after the home page and the relevant page (contact,
  booking or services) were both read; the `Summary` names both. Never
  claim "lacks chat": chat usually loads by script, which the reader
  does not run. "Has chat" can be claimed when the widget's markup or
  link is on the page.

## What makes a hook usable

Contrast concretely, not abstractly:

- **Not a hook:** "they are in SaaS." True of thousands of companies,
  not tied to any date, nothing to plausibly react to.
- **A hook:** "they posted three support-engineer roles in two weeks
  after announcing a Series A." Specific to this company, dated,
  and gives the operator something real to open with — the hiring
  surge tells them what's actually changing inside the business right
  now.

## Worked example

Researching **Fennimore Health**, a healthtech company, within an
8-minute budget. Its Segment's one offer in the catalog (fictional) is
Clinical Ops Scheduling (`ho-clinical-scheduling`), with the signal
`hiring for clinical operations roles` and the rule-out `already
advertises a scheduling platform`.

1. Company site/blog: no posts in the last year — nothing usable; no
   scheduling platform advertised, so the rule-out is not found.
2. Recent news: TechCrunch, 2026-07-30, "Fennimore Health raises $9M
   Series A led by Bluecrest Partners." Written to Research: `Type:
   funding`, `Summary: "Fennimore Health raised a $9M Series A led by
   Bluecrest Partners, announced 2026-07-30; press release cites plans
   to expand the clinical operations team."`, `Source URL:` the
   TechCrunch article, `Date: 2026-07-30`, `Hook: "congratulate on the
   $9M Series A and tie the opening line to their stated plan to
   expand clinical operations."` — 33 days old, specific, opinionable.
   Usable hook #1.
3. Funding and hiring signals: the company's LinkedIn jobs tab shows
   four "Clinical Operations Coordinator" postings opened in the last
   two weeks. Written to Research: `Type: hire`, and the `Summary`
   (one line in the record):

   ```
   Four Clinical Operations Coordinator roles opened on Fennimore's LinkedIn jobs tab between 2026-08-14 and 2026-08-21. Signal for ho-clinical-scheduling: "hiring for clinical operations roles".
   ```

   Then `Source URL:` the jobs tab URL, `Date: 2026-08-21`, `Hook: "they
   posted four clinical-ops roles in one week, directly following the
   Series A — open by asking how they're structuring that team as it
   scales."` — usable hook #2, and the offer's signal.
4. Two usable hooks reached at minute 5 of 8, with the offer's signal
   and rule-out both looked for — stop here per step 6, even though
   executive social posts and industry events haven't been checked.

## Failure modes

- **Producing a research dump with no hook.** A Research row with a
  detailed `Summary` and no usable `Hook` is incomplete for what the
  Preparer exists to do — `log_research` rejects an empty `hook`
  outright, so this failure mode looks like forcing a weak hook
  through (see below) rather than an empty field slipping past.
- **Hooks older than 90 days presented as news.** A funding round from
  eight months ago is background, not a hook — writing it as if it
  were current makes the resulting outreach read as out of touch.
- **Inventing a hook when the company has no public footprint.** If the
  full search order turns up nothing that clears the usable-hook bar,
  record "no hooks found" per step 7 and let the lead stall at
  `Researched` with a thin file, rather than manufacturing a plausible-
  sounding hook to fill the gap. A fabricated hook is worse than none —
  it puts a false claim in front of the prospect.
- **Searching only for hooks, not for the offers' signals.** A file of
  good hooks with no word on the segment's signals or rule-outs leaves
  `match-offer` to pick by segment fit alone, or to pick an offer the
  lead already has. Every signal and rule-out from step 2 is looked for
  before the search stops, and each one found is recorded.
