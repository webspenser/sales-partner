# Research scrapers for offer evidence — design

Date: 2026-10-18. Builds on sales-partner 8.0.0 (branch `feat/offer-matching`,
PR #23: offer catalog, hero offer, talking points). Ships as **8.1.0**.
The new lead field, catalog key and config keys are additive, so this is
not a breaking change.

## Why

8.0 matches each researched lead to the offer most likely to land, from
the signals and rule-outs in the offer catalog. Research today has only
web search, the Google Maps listing and a website contact scraper, so most
signals are never looked for. The Plumbing Plus run found a license record
and no website, and nothing else. The operator wants research to find the
evidence the catalog's offers depend on:
- open **job listings**, such as a receptionist, front-desk or bookkeeper
  role;
- **review keywords**, such as "voicemail", "never called back" or
  "billing mistake";
- **website features**, that is whether the site has or lacks online
  booking or a client portal;
- **ads**: whether the business pays for Google or Facebook ads.

The scrapers exist to support matching against the offer catalog, not
research for its own sake.

## Goals

1. **Four new evidence sources** through Apify, each guarded like today's
   two actors, with an allowlist of argument names and pinned sizes:
   - Maps reviews;
   - ads (Google Ads Transparency, and Facebook Ad Library as a count
     only);
   - job listings (Indeed);
   - a website-features check that reads a few pages of the lead's site.

   "Search" stays the agent's built-in web search. The tips can point
   research at it.
2. **Research tips per offer.** Each offer in the catalog gets
   operator-written tips saying what to prioritize and where to look. The
   Preparer reads the tips for every offer in the lead's segment and
   decides which sources to run and what to look for.
3. **A $0.50 per-lead Apify cap.** Scraping for one lead stops when its
   estimated spend reaches the cap. This sits alongside the existing
   rolling 7-day cap.
4. **Continuing past the cap is interactive only.**
   - In a scheduled run, a lead that reaches the cap stops scraping. The
     Preparer finishes the lead with what it found, leaves a note and
     sets a visible flag.
   - In an interactive session, the Preparer asks the operator whether
     to continue, and for how much more. The operator watches progress
     there.

## Non-goals

- **A paid Google search scraper.** The operator decided to drop it.
  `apify/google-search-scraper` takes its searches as one newline-
  separated string, with each line billed, and today's guard engine can't
  count lines. Bounding it would need an Agent Standard engine change
  first. Built-in web search covers the search need for now; the scraper
  can come later if research shows a gap.
- **Local Services Ads.** No well-used actor exists, and they search by
  trade and city, not by business.
- **LinkedIn Jobs.** It is out of this release, and Indeed only is used.
  *(My call.)*
- **Ad copy.** Only whether ads run is stored. *(My call.)*
- **Changing how offers are matched.** Signals and rule-outs still
  decide; tips only steer where to look. The one change is a recency
  rule for reviews, described under "How it works".
- **The prospecting score ceiling.** That belongs to the goal-driven
  prospecting spec.

## Anti-goals

- **Personal data about reviewers in the CRM.** Review findings quote a
  short snippet with its date and link, and never the reviewer's name or
  profile. The Preparer passes `personalData: false` to the reviews
  actor.
  - This is an instruction, not guard-enforced. The engine can't pin
    true/false values, and a true/false pin would be an engine change.
  - The CRM side is covered either way: the Preparer never writes a
    reviewer name. *(My call.)*
- **A scraping call whose cost isn't bounded by pinned arguments.** That
  includes an unlimited default left open, and a crawler's page count or
  depth.
- **Custom code, cookies, headers or request bodies sent through any
  actor:** the crawler's `pageFunction`, `initialCookies` and
  `customHttpHeaders`.
- **Paid add-ons switched on:** the crawler's `summarize`, scrapesage's
  `includeDetails`, and Facebook's `enrichWithEcommerceData`.
- **A tip treated as evidence.** A finding counts as a signal or rule-out
  only when it matches one in the catalog and has a source URL, as in
  8.0.
- **Scraping every source for every lead regardless of the tips.**
- **A "lacks" claim the page can't support.** Chat widgets often load by
  script after the page loads, so a fetched page can miss them. The
  website check therefore never claims a site lacks chat. See "How it
  works".

## The sources

These picks come from the Apify Store survey in
`docs/superpowers/notes/2026-10-18-apify-research-buckets.md`, which has
the prices, users and argument names with sources, and was read-only. The
costs are free-plan prices.

| Source | Actor | Target | Typical cost per lead |
|---|---|---|---|
| Maps reviews | `compass/Google-Maps-Reviews-Scraper` | the lead's place ID or Maps URL | about $0.03 for 50 reviews |
| Ads | `scrapesage/google-ads-transparency-scraper` (advertisers mode) and `apify/facebook-ads-scraper` (`onlyTotal`) | the business name and domain | about $0.009 |
| Jobs | `valig/indeed-jobs-scraper` | company name and city | about $0.003 for 20 results |
| Website features | `apify/website-content-crawler` (`cheerio` crawler) | the lead's website, up to a few pages | about $0.02, ceiling about $0.06 |

Running all of them once costs about **$0.06 per lead**, and about $0.11
at worst. The $0.50 cap is there to catch a runaway call, not to ration
normal research.

**What has to be verified before it ships.** The Task 5 probe in 7.2 did
this for the first two actors. For each new actor, the builder confirms
against the live connector:
- the tool name the hosted Apify MCP exposes;
- the input schema;
- the arguments that bound size and cost, and their defaults;
- the output fields;
- one tiny live call, with the operator's OK.

Two items are flagged for this check:
- whether the hosted MCP lets the crawler's run memory be lowered; it
  defaults to 8 GB, which drives its cost;
- the crawler's options for keeping links and markup. See "Website
  check" under "How it works".

If any pick fails the check, the builder substitutes the survey's
runner-up for that source and records why.

## How it works

**Catalog: one new key per offer.** `research_tips` is free text written
by the operator, saying what to look for and where. For example:

```yaml
      - id: ha-voice-agent
        name: Inbound Lead Qualification & Appointment Setting
        research_tips: >
          Reviews mentioning voicemail, no answer, or after-hours. A front
          desk or receptionist job posting is strong. Check whether the
          website offers online booking.
```

- The interview asks for the tips with each offer, after its signals and
  rule-outs.
- The tips are optional. Without them, the Preparer works from the
  signals and rule-outs alone, as in 8.0.
- Tips are prose for the agent. The bootstraps ignore the key.

**Turning sources on.** The new sources are listed in
`prospecting_sources` like today's two, so the existing rule still
holds: scheduled and interactive runs use the same sources, whatever the
list says. The new names are `apify_reviews`, `apify_ads`, `apify_jobs`
and `apify_site_reader`. The default list includes all four. The
interview's Round 4 offers them, and the upgrade step tells the operator
to add them. *(My call.)*

**Contract: new scraping operations,** one per source, each provider-
neutral like `find_businesses` and `find_contacts`. Each returns its
results plus the run's cost, estimated when the provider doesn't report
it.
- `find_reviews(place)`;
- `find_ads(business)`;
- `find_jobs(company, location)`;
- `read_site(url)`.

The builder settles the exact signatures and result fields from the
probe.

**Guard.** The Apify tool's guard follows the same pattern as today:
- allowlist the new actor tools;
- add exact-key `only_keys` allowlists per tool;
- add pinned sizes as bindings in `bindings/scraping.md`, with
  `required` limits on every list or count argument.

New bindings, with my default values (the operator can change them at
setup):

| Binding | Default |
|---|---|
| `max_reviews` | 50 |
| `max_ads` | 5 |
| `max_jobs` | 20 |
| `max_site_pages` | 5 |
| `max_site_depth` | 1 |

No agent-builder change is needed. The existing engine covers these
actors.

**Preparer.**
1. After the Maps listing and website contact steps, it reads the
   research tips for every offer in the lead's segment.
2. It picks the sources the tips point to, from those listed in
   `prospecting_sources`, and runs them in the order that gives the most
   evidence for the least cost. Reviews and the website check usually
   come first.
3. Each result becomes research findings of the existing seven types,
   for example reviews under `listing` and jobs under `hire`. Each
   finding has a source URL.

**Reviews.**
- Findings quote the snippet, with its date and link, and give no
  reviewer name.
- **Recency rule:** a review older than 12 months doesn't count as a
  signal or rule-out for a catalog entry when a review from the last 12
  months shows the same entry. An old review alone still counts.
  - The rule applies to reviews only; jobs and ads are current by
    nature.
  - `match-offer`'s counting step applies it.
  - It closes the deferred recency gap from 8.0. *(My call.)*

**Website check.**
- `read_site` keeps links and page markup, not just readable text, so
  "Book now" links and booking or portal links are visible. The builder
  allows and pins the crawler options that do this, per the probe.
- Findings say "has" or "lacks" for each feature the tips name, with
  the page checked.
- "Lacks" is claimed only after the home page and the relevant page
  (contact, booking or services) were both read.
- "Lacks chat" is never claimed, because chat usually loads by script.
  "Has chat" can be claimed when the widget's markup or link is
  present. *(My call.)*

**Time budget.** Each actor call can wait up to 45 seconds, so the
default `research_budget_per_lead_minutes` rises from 8 to 15. *(My
call.)*

**Per-lead cap.**
- The Preparer adds up the estimated cost of each Apify call for the
  lead, including the existing contact scraper, against
  `apify_cap_usd_per_lead` (default `0.50`, a new key in
  `operating-config.md`).
- Before each call, it checks that the call's worst-case estimate fits
  in what remains. If it doesn't, it stops scraping that lead.

**Reaching the per-lead cap.**
- **Scheduled run:**
  - The Preparer stops scraping the lead and completes it with what it
    has: match-offer, talking points, then `Researched`.
  - It sets the new lead field **Research Capped** to true. This is a
    checkbox the agent writes, not the operator.
  - It starts the stage reason with `research capped at $<cap>; <sources
    not run>`.
  - It records a ledger `stop_condition`.
  - The digest lists capped leads with a mark in the Review section.
- **Interactive session:** the Preparer pauses and asks the operator
  whether to continue, and with how much more. If the operator agrees,
  it continues up to the new amount, then completes the lead as usual,
  and Research Capped stays false.
- **Continuing later:** the operator asks Sales Partner in a session to
  continue research on a capped lead.
  - The Preparer runs only the sources not yet run, adds a research
    section, and re-matches.
  - It clears Research Capped once the lead completes.
  - The agent never does this in a scheduled run.

**Reaching the rolling 7-day cap.** This behaves as today: scraping stops
for the rest of the run, `notify_owner(kind: alert)` is sent, and
research carries on with web search only.
- The lead in progress gets Research Capped, with the stage reason
  `research capped by the 7-day Apify cap; <sources not run>`. That way it
  shows in the digest and can be continued later.
- The weekly cap is never raised from a session prompt. It changes only
  by editing `apify_spend_cap_usd_per_week` in `operating-config.md`.
  *(My call.)*

## CRM

**New field:**

| Field | Attio slug | HubSpot property | Type | Written by |
|---|---|---|---|---|
| Research Capped | `research_capped` | `sp_research_capped` | checkbox | Preparer: set true when capped, cleared after an interactive continue completes |

- Both bootstraps add it.
- The guard leaves it agent-writable. Unlike Research Anyway, this flag
  is the agent's.
- The Review views in both CRMs show it.

## Upgrading from 8.0

1. **Re-run the interview's catalog round** to add research tips. This
   is optional; without tips, research behaves as in 8.0 plus the new
   sources.
2. **Update `operating-config.md`.**
   - Add the new source names to `prospecting_sources`.
   - Add `apify_cap_usd_per_lead: 0.50`.
   - Raise `research_budget_per_lead_minutes` to 15.
3. **Re-run setup's tools step.**
   - It adds the `research_capped` field.
   - It asks for the new scraping bindings and pushes
     `bindings/scraping.md`.
   - It tells the operator to add the new actors to the Apify connector's
     restricted URL, `https://mcp.apify.com?tools=…`.
4. **Re-run `/sales-partner:schedule`.**

## Tests and evals

**Tests:**
- policy cases for every new actor tool: allowed inputs, each pinned
  limit, each blocked key and add-on;
- content tests for:
  - the new operations;
  - the new source names;
  - the per-lead cap key;
  - the Research Capped field in both bootstraps and usage.md files;
  - the `research_tips` key in the catalog template and the interview.

**Evals:**
- a scheduled lead that reaches the per-lead cap, gets Research Capped
  set and still reaches `Researched`;
- the weekly cap reached mid-lead;
- an interactive continue past the cap;
- tips steering which sources run;
- a source not listed in `prospecting_sources` isn't run;
- a review signal quoted with no reviewer name;
- a website "lacks" claim that needs both pages read, and no "lacks chat"
  claim;
- an old review that doesn't count when a newer review shows the same
  entry.

## The operator's part

- Writing the research tips per offer, during the re-interview.
- Adding the new actors to the Apify connector.
- Approving the one tiny live call per actor in the probe.

## Left to the builder

- Exact operation signatures and result fields, from the probe.
- Whether a pick is swapped for the survey's runner-up.
- The crawler options that keep links and markup.
- The order in which sources run.
- How `research-company` is split versus a new skill.
