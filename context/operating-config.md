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
prospecting_sources: [apify_google_maps, apify_contact_info, web_search]
research_quota_per_week: 10
research_threshold: 60
apify_spend_cap_usd_per_week: 25
research_budget_per_lead_minutes: 8
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
  the Preparer, not the Prospector); `web_search` is general search; `apollo` is a stubbed tool —
  listing it makes the Prospector report that it is not yet enabled,
  never substitute another source. Both Apify sources draw on
  `apify_spend_cap_usd_per_week`. To research every new lead, set
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
- **`research_budget_per_lead_minutes`** — the time budget the Preparer
  spends researching a single lead before it stops and hands off with
  whatever hooks it has found; see `subagents/preparer.md`'s `Stop
  conditions`.
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
