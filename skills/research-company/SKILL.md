---
name: research-company
description: Use when a lead enters the research quota — gathers recent, specific, verifiable facts about a company and converts them into usable outreach hooks.
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
2. Search in this fixed order, moving to the next source only once the
   current one is exhausted or clearly unproductive:
   1. Company site and blog
   2. Recent news
   3. Funding and hiring signals
   4. Executive social posts (public posts only — read-only, never an
      automated action behind a login)
   5. Industry events (speaking slots, sponsorships, published
      attendee lists)
3. For each finding worth recording, write one Research row via CRM
   `log_research(lead_id, type, summary, source_url, date, hook)`:
   `Type` from {news, funding, social, event, hire}; `Summary` states
   what was learned in enough detail to stand alone; `Source URL` is
   required and non-empty; `Date` is the finding's actual date, not
   today's date. `log_research` itself rejects a call with an empty
   `source_url` or an empty `hook`, so a finding with no usable hook
   does not get written as a Research row at all — see step 4.
4. Before writing, decide whether the finding clears the bar for a
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
5. Stop the search — even mid-order — once either: two or more usable
   `Hook` values have been written for this lead, or the
   `research_budget_per_lead_minutes` budget is spent. Whichever comes
   first ends the run; a thorough search that blows the time budget is
   still a failure of this skill.
6. If the full search order is exhausted inside the budget and zero
   usable hooks were found, write a single Research row recording that
   explicitly (`Summary: "No hooks found — searched company site,
   news, funding/hiring signals, and social within budget"`, `Hook:
   "no hooks found"`, with whatever `Source URL` best represents the
   search — e.g. the company's own site) rather than leaving the lead
   with no research trail at all.

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
8-minute budget:

1. Company site/blog: no posts in the last year — nothing usable.
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
   two weeks. Written to Research: `Type: hire`, `Summary: "Four
   Clinical Operations Coordinator roles opened on Fennimore's
   LinkedIn jobs tab between 2026-08-14 and 2026-08-21."`, `Source
   URL:` the jobs tab URL, `Date: 2026-08-21`, `Hook: "they posted four
   clinical-ops roles in one week, directly following the Series A —
   open by asking how they're structuring that team as it scales."` —
   usable hook #2.
4. Two usable hooks reached at minute 5 of 8 — stop here per step 5,
   even though executive social posts and industry events haven't been
   checked.

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
  record "no hooks found" per step 6 and let the lead stall at
  `Researched` with a thin file, rather than manufacturing a plausible-
  sounding hook to fill the gap. A fabricated hook is worse than none —
  it puts a false claim in front of the prospect.
