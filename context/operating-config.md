# Operating Config

Volume, cadence, and caps live here. Changing them is a config edit,
never a prompt edit. That separation is what lets an operator retarget
how hard or how carefully the agent works — more leads, a longer touch
cadence, a lower spend cap — without ever touching, and risking
breaking, how any sub-agent operates.

Unlike `business-profile.md` and `icp.md`, this file does not ship as a
blank. The pipeline must be able to run before anyone has tuned it, so
every key below ships with a real working default. The
`interview-business` skill (Phase 0) may adjust any of these values
during setup and again whenever operating needs change; every
sub-agent and skill listed in `AGENT.md` reads its limits from here,
never from a hardcoded number in a prompt.

Every value below is a number, a list, or a fixed choice — never a vague
setting — because every `Stop conditions` entry in this agent's
sub-agent contracts (`subagents/*.md`) is a countable resource, and
these keys are what make that countable.

```yaml
leads_per_week: 40
prospecting_sources: [apify_google_maps, apify_contact_info, apify_reviews, apify_ads, apify_jobs, apify_site_reader, web_search]
research_quota_per_week: 10
research_threshold: 60
apify_spend_cap_usd_per_week: 25
apify_cap_usd_per_lead: 0.50
research_budget_per_lead_minutes: 15
tone: "[three adjectives from the interview]"
```

## What each key gates

- **`leads_per_week`** — the Prospector's target count of new `Scored`
  leads per run; see `subagents/prospector.md`'s `Stop conditions`.
- **`prospecting_sources`** — the sourcing tools the Prospector may
  use, and the only ones. `apify_google_maps` returns local-business
  listings (name, address, phone, website, rating, review count)
  through `find_businesses`; `apify_contact_info` runs `find_contacts`
  (emails, phones and social links from a business's website; used by
  the Preparer, not the Prospector); `apify_reviews` runs
  `find_reviews` (a place's Google Maps reviews), `apify_ads` runs
  `find_ads` (the ads a business is running), `apify_jobs` runs
  `find_jobs` (a company's job posts) and `apify_site_reader` runs
  `read_site` (the text, links and markup of a few pages of a
  business's website); these four are used by the Preparer, which picks
  among them from the lead's segment's offers' `research_tips`;
  `web_search` is general search; `apollo` is a stubbed tool —
  listing it makes the Prospector report that it is not yet enabled,
  never substitute another source. Every Apify source draws on
  `apify_spend_cap_usd_per_week` and, for a lead being researched, on
  `apify_cap_usd_per_lead`. A source left out of the list is not run,
  in scheduled and interactive runs alike. To research every new lead, set
  `research_quota_per_week` equal to `leads_per_week` and lower
  `research_budget_per_lead_minutes` so the week's budget still fits.
  The old key `apify_site_scraper` no longer exists:
  apify_site_scraper was renamed apify_contact_info in 7.2.
  A config that still lists it stops the run with that message.
- **`research_quota_per_week`** — the ceiling on how many leads the
  Preparer researches per week, applied on top of `research_threshold`;
  see `subagents/preparer.md`'s `Trigger` and `Stop conditions`.
- **`research_threshold`** — the minimum Fit score (0–100, per the Fit
  rubric in `icp.md`, scored by the Prospector from the listing) a
  `Scored` lead needs to enter research. Default `60`. See `icp.md`'s
  Thresholds section for the full explanation of this gate.
- **`apify_spend_cap_usd_per_week`** — the ceiling on Apify actor
  spend per week, shared across the Prospector's sourcing and the
  Preparer's research, measured by adding up the ledger `Cost USD` of the
  last 7 days (a rolling window) for the prospect and prepare activities
  before each Apify call; Apify's
  account usage limit is the hard stop behind it. Reaching it is a `Stop conditions` trigger and
  an `AGENT.md` escalation ("Escalate to human when").
- **`apify_cap_usd_per_lead`** — the ceiling on Apify spend for
  researching a single lead, in US dollars, summed over the estimated
  cost of each Apify call for that lead (the contact scraper included).
  Default `0.50`, which also applies when the key is missing (an 8.0
  config). Before each call the Preparer checks that the call's
  worst-case estimate fits in what remains; if it doesn't, it stops
  scraping that lead, completes it with what it has, sets Research
  Capped, and starts the stage reason with `research capped at
  $<cap>; <sources not run>`. That happens in every run; in an
  interactive session the operator is then asked whether to continue
  the lead, and with how much more. It sits inside
  `apify_spend_cap_usd_per_week`, which stays the ceiling for the week.
- **`research_budget_per_lead_minutes`** — the time budget the Preparer
  spends researching a single lead before it stops and hands off with
  whatever hooks it has found; see `subagents/preparer.md`'s `Stop
  conditions`. Default `15`, which also applies when the key is
  missing: a scraping call can wait up to 45 seconds, and a lead may
  use several.
- **`tone`** — three adjectives describing how the talking points should
  read, filled in by the interview from `business-profile.md`'s Voice
  section. Read by `write-talking-points` when it writes the opener.

## Running on a schedule

Schedules live in the instance's `schedules.yaml`, which the interview
writes. The `schedule` skill turns them into Claude cloud routines, only
for activities whose capabilities are all covered by guard policies.

Nothing in this file, and nothing any key here configures, sends a
message to a prospect on its own. Nothing goes out without the
operator's approval, and only the operator approves a lead, by moving
the lead to `Approved` — the guard refuses that status to the agent.
Talking points are append-only: the agent adds a section and never
edits, replaces or removes one. See
`capabilities/crm/contract.md`'s Approval invariant for the full, provable rule —
this file states the outcome, not the mechanics, precisely so it
cannot drift out of sync with them again.
