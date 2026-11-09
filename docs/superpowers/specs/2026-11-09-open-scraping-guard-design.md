# Open scraping guard — design

Date: 2026-11-09. Status: draft for review. Target: sales-partner 8.6.0.

## Why

Sales Partner's Apify guard lists, for every actor, the exact arguments
it accepts (`only_keys`). That makes it safe, but brittle. A vendor that
adds an input, renames one or changes an interface breaks the call. On
2026-11-09 the Compass reviews tool changed shape, the guard blocked the
call, and every prepare run stopped at its first lead (fixed in 8.5.1 by
swapping actors; see `docs/superpowers/notes/2026-11-09-reviews-actor-probe.md`).

The operator's view: Apify only retrieves. It never contacts anyone, so
the everyday risk is cost, and the cost controls (weekly Apify cap,
per-lead research budget, Apify's own monthly limit) are enough at this
volume. The operator wants the scraping layer to be **flexible and
resilient**: fewer stops over small vendor changes, more sources, and
richer data where it helps outreach.

## Goals

1. A small change in an actor (a new optional input, a renamed or empty
   output field, a vendor-side validation error) does not stop the run.
   The run carries on and says what happened in its run report.
2. Adding an actor is a short probe-and-release round with a small,
   repeatable footprint: one allow line, its size caps, any safety pins,
   and a `usage.md` entry. Not hands-free.
3. Personal data is allowed where it helps outreach:
   - reviewer names in research findings and talking points;
   - an owner's personal email (for example a Gmail address) found by a
     source, recorded in Contacts and eligible as point of contact.
4. New sources: Yelp reviews, YellowPages, BBB, LinkedIn jobs, a backup
   Facebook Ad Library actor, two more LinkedIn profile tools, and the
   open web (`web-search`, `web-fetch`).

## Non-goals

- Hands-free actor adds (calling an actor not named in the guard).
- Replacing Exa. Exa stays the `web_search` capability used by
  find-decision-makers.
- Changing the CRM, the approval invariant, the stage machine or any
  outbound behavior. Nothing in this design sends anything to anyone.
- Changing the weekly spend cap or the per-lead budget values.

## Anti-goals (a failure even if it works)

- The agent can run an arbitrary Store actor (`call-actor`) or make raw
  Apify API calls (`api`: webhooks, schedules, storage, account).
- An injected web page can steer the agent into sending CRM data out
  through a URL, a search string or custom code.
- A call can run with an unbounded result count (several actors default
  to millions).
- Data is invented to fill a gap: a guessed email written as found, a
  quote made up for a star-only review.

## Decisions the operator made

- **On drift: carry on and report.** Not stop, not silent.
- **Per-actor adds stay a probe and a release.**
- **Personal data:** reviewer names and personal emails are wanted.
  "Naming a review in an email gives precise context a business owner
  might need." Personal emails "might be the best direct path to a
  business owner especially for non-technical owners."
- **Include `web-search` and `web-fetch`.** `web-fetch` reads:
  1. the lead's own website, any page on it;
  2. pages from the agent's own search results for the lead;
  3. a press or news item about the business from those results, only
     when dated within the last 3 months, read to judge its relevance.
- **Actor list.** Add `delicious_zebu/yellowpages-usa-business-lead-scraper`,
  `scrapesage/bbb-scraper`; keep `valig/indeed-jobs-scraper`; do not use
  `curious_coder/linkedin-jobs-scraper` or
  `curious_coder/facebook-ads-library-scraper`.
- **`web-fetch` takes paths only:** no query string or fragment. Chosen
  over open fetch and over no fetch.
- **LinkedIn email search on in 8.6.0** (`profileScraperMode` with
  email search), priced by its probe.

## The open guard profile

The Apify `guard.yaml` keeps the same engine (agent-builder Standard,
`hooks/guard_policy.py`) and switches style. Every element below exists
in the engine today, except where a section says otherwise.

### Kept as hard rules

1. **Actors allowed by name** (`allow`). Anything not named is refused,
   even when it is on the connector.
2. **Generic tools denied** (`deny`): `*call-actor*`, `*call_actor*`,
   `*search-actors*`, `*add-actor*`, `*fetch-actor*`, `*webhook*`,
   `*schedule*`, and the raw API tools. Of the connector's `runs` tools,
   only `get-actor-run` and `get-dataset-items` are allowed (as today);
   `get-actor-run-list`, `get-actor-run-log`, `abort-actor-run` and the
   `docs` tools stay outside `allow`. They may sit on the connector.
3. **Size caps on every actor** (`recipients` pins and `limits` with
   `required: true`): every result-count, page-count and list-length key
   an actor has is pinned or capped from `bindings/scraping.md`. A call
   that omits a cap is blocked (a `recipients` pin already blocks an
   omitted value; `limits` need `required: true`), so a vendor default
   of millions never applies. `hooks/tool_check.py` already requires,
   under `pinned_inputs`, that every allowed actor is pinned or named as
   a read in `usage.md` `## Probe`; each new actor, `web-search` and
   `web-fetch` included, must meet that.
4. **URL rules** (`urls`) on every argument that takes a URL: `https`
   only, a public host (the engine's always-on refusals: no IP address,
   local name, credentials or odd port). Existing per-actor rules (site
   roots for the contact scraper and site reader, Facebook hosts) stay.
5. **One shared refused list** (`refuse_args`), applied to every actor:
   custom code and request control that no research call needs:
   `pageFunction`, `preNavigationHooks`, `postNavigationHooks`,
   `customData`, `headers`, `cookies`, `sessionCookies`,
   `requestsFromUrl` (and its nested `"startUrls[].requestsFromUrl"`,
   `"startUrls[].headers"`, `"startUrls[].payload"`,
   `"startUrls[].method"`, `"startUrls[].userData"`), `webhooks`,
   `proxyConfiguration`, `proxyConfig`. The probe for each new actor adds
   any key of this kind it finds.
6. **Fixed values that are cost or scope switches, not privacy**
   (`fixed`): Facebook `onlyTotal: true`, site reader `saveMarkdown`,
   LinkedIn search `strictSearch` and `maxPages: 1`, TikTok
   `resultsPerPage: 1`, and each new actor's paid add-ons that research
   does not use (for example BBB's website contact enrichment, which the
   contact scraper already covers).

### Loosened

1. **No per-actor key allowlist** (`only_keys` removed from the actor
   tools). Any input that is not refused, capped or fixed passes. A new
   optional vendor input stops breaking calls. Accepted cost: an unknown
   risky input passes until a probe or review adds it to the refused
   list. `only_keys` stays on `get-dataset-items` and `get-actor-run`,
   whose shapes are Apify's own and stable.
2. **Personal-data switches follow the operator's choice, as `fixed`
   values set per release.** *(My call.)* The engine's `recipients` pins
   take only strings and numbers, and binding values may not contain
   spaces (`hooks/guard_policy.py:76`, `:525-539`), so these switches
   cannot be operator bindings without an engine change. They stay
   `fixed`, with the values flipped to the operator's choice:
   - reviews: `include_personal: true` (and the equivalent flag on any
     new review actor);
   - LinkedIn tools: `profileScraperMode: "Full + email search"`
     *(operator's choice, in 8.6.0 phase A)*, on the existing
     `harvestapi/linkedin-profile-search-by-name` now and on the new
     harvestapi profile tools when they land. The exact mode string and
     its price per profile come from a one-call probe before the change
     merges; the probe note records them and `usage.md` gets the cost
     line. Paid email lookups count against `max_profile_results`, the
     per-lead budget and the weekly cap like any other result.
   Changing them later is a one-line release. Paid personal-data add-ons
   still count against the caps and the weekly spend cap.

### Agent-builder Standard

The Standard (`agent-builder/STANDARD.md:607-611`) recommends
`only_keys` but no validator requires it, so dropping it needs no code
change. Two invariant claims do need the Standard's attention:

- `pinned_inputs`: with no key allowlist, a size input the guard does
  not know (a new vendor key) is not capped if the agent sends it. The
  agent only sends inputs `usage.md` names, and the Apify monthly limit
  is the backstop, but the Standard says the invariant cannot be marked
  acceptable (`STANDARD.md:344-355`).
- `no_external_send`: see Open-web research.

*(My call:)* agent-builder gets a Standard note defining the
**retrieval profile** (actor names allowed, generic tools denied, shared
`refuse_args`, caps on every allowed actor, URL rules), and what
`pinned_inputs` means under it: every size key the probe found is
capped, and unknown keys are a documented, bounded residual. No new
`tool_check` or `validate` checks beyond the existing pinned-or-read
rule. That note ships first; sales-partner pins the new Standard
version. If `tool_check` refuses the claim, the schedule gate stops
every scheduled run (`skills/schedule/SKILL.md:47-55`), so this is
checked before Phase A merges.

## Drift: carry on and report

What the agent does when a source misbehaves, per lead:

| What happens | Behavior |
|---|---|
| An output field the `usage.md` map names comes back missing or empty on every item | Record nothing from it; add `drift: <tool> <field> empty` to the run report |
| The actor returns a vendor validation error (bad input, interface changed) | The source is not run for this lead (`<source>; vendor error`); research goes on; one line in the run report with the error's first line |
| The guard blocks a scraping call | The source is not run for this lead (`<source>; blocked`); never retried with changed arguments; research goes on; the run report quotes the block. After the same source is blocked on 2 leads in one run, it is skipped for the rest of the run |
| The same source drifts or is blocked on every lead in a run | One `notify_owner(kind: error)` at the end of the run (not per lead), naming the source and the first message |

This replaces, for the scraping capability only, the current rule "If a
call is blocked by the guard, stop the activity" (`subagents/preparer.md`
and `subagents/prospector.md`). Guard blocks on every other capability
(CRM, owner_notify, web_search) still stop the activity. Reasoning: a
block on a retrieval call has already prevented the call; continuing
with other sources is not a workaround, as long as the blocked call is
never retried in another form.

A lead whose research lost sources is scored only from what was found,
as today (Sources not run). The run report and the digest's per-lead
notes say which sources were not run, so a low Approach score caused by
a missing source is visible.

## Personal data changes

From 8.1 the rule was: reviews never carry reviewer names, and the
reviews call always sends the personal-data flag off. It changes to:

- **Reviewer names:** a review finding may name its reviewer
  (`reviewer_name`), and talking points may cite the review by reviewer
  and date ("Dana's review on 2026-10-02 says…"). Still never recorded:
  the reviewer's profile URL, photo and Google ID (`reviewer_url`,
  `reviewer_photo_url`, `reviewer_photo`, `reviewer_id`); the `fields`
  projection does not ask for them. *(My call: a name gives the context;
  the rest is extra data on someone who isn't the prospect.)*
- **Names in review text** (a technician's first name) may be quoted as
  written.
- **Personal emails:** an email address a source shows for a named
  decision-maker (on LinkedIn email search, a BBB principal contact, a
  YellowPages listing, the site) is recorded in the Contact's `email`
  field whatever its domain, and counts for point-of-contact
  eligibility. *(My call:)* the Contact's `notes` say where it was found.
  Unchanged: a pattern-guessed address is never written to `email`
  (`notes` only), and no address is invented.

Files that carry the old rule and change: `capabilities/scraping/contract.md`,
`capabilities/scraping/tools/apify/usage.md`, `skills/research-company/SKILL.md`,
`subagents/preparer.md`, `skills/write-talking-points/SKILL.md` (citing a
reviewer), `skills/find-decision-makers/SKILL.md` (personal emails),
`evals/cases.md` (the cases that assert no reviewer name, for example
the "Marco" case), `README.md`.

## Sources

Source names in `prospecting_sources` name a role, not a vendor. New
roles get new names; the operator adds them to `prospecting_sources`.

| Role (source) | Actor | Use | Caps and switches to pin (confirm at probe) |
|---|---|---|---|
| `apify_google_maps` | `compass/crawler-google-places` | prospecting (unchanged) | unchanged |
| `apify_yellowpages` *(new)* | `delicious_zebu/yellowpages-usa-business-lead-scraper` | prospecting by keyword and city; research lookup of a lead's listing (claimed, years, categories, email) | results per search, pages; $0.003/result |
| `apify_contact_info` | `vdrmota/contact-info-scraper` | unchanged | unchanged |
| `apify_reviews` | `web_wanderer/google-reviews-scraper` | Google reviews (8.5.1) | `limit` = `max_reviews`; `include_personal` from binding |
| `apify_yelp` *(new)* | `web_wanderer/yelp-reviews-scraper` | Yelp reviews: recency and the frustration trigger, second source | reviews per place, places per call |
| `apify_bbb` *(new)* | `scrapesage/bbb-scraper` | BBB rating, accreditation, years, complaint count, principal contacts | businesses per search; reviews off or low; website enrichment fixed off; proxy refused or pinned |
| `apify_ads` | `scrapesage/google-ads-transparency-scraper`, `apify/facebook-ads-scraper`, backup `scrapesage/facebook-ad-library-scraper` *(new)* | ads presence | backup used only when the primary Facebook call fails |
| `apify_jobs` | `valig/indeed-jobs-scraper`, `valig/linkedin-jobs-scraper` *(new)* | open job posts | results per call |
| `apify_site_reader` | `apify/website-content-crawler` | unchanged | unchanged |
| `apify_profiles` | `harvestapi/linkedin-profile-search-by-name`, `apify/instagram-profile-scraper`, `clockworks/tiktok-profile-scraper`, plus `harvestapi/linkedin-profile-scraper` and `harvestapi/linkedin-profile-search` *(new)* | social profiles; the profile scraper reads a known LinkedIn URL | items per call, pages; `profileScraperMode` from binding |
| `apify_web` *(new)* | `apify/web-search`, `apify/web-fetch`, `apify/google-search-scraper` | open-web research (below) | results per search, URLs per fetch |

Removed from the guard: `compass--Google-Maps-Reviews-Scraper` (already
in 8.5.1).

How a new source joins research: the Preparer's existing rule decides
which sources run for a lead (an offer's tips, its signals and rule-outs,
then cost order). Each new source needs a line in that rule saying what
it reads, so an offer's tip can point at it.

## Open-web research (`apify_web`)

- **`web-search`** (or `google-search-scraper`; the probe picks one as
  primary and the other as backup) searches the business by name and
  city, once per lead, with a capped result count.
- **`web-fetch`** opens, per lead, at most `max_web_fetches` URLs
  (default 5), each one of:
  1. a page on the lead's own website host;
  2. a URL that appeared in this lead's search results;
  3. a press or news item from those results dated within the last
     3 months (by the date the result or page shows). Older items are
     not fetched.
- A relevant press item becomes a `news` finding with its date and URL;
  research-company already has the `news` type.
- **What the guard enforces:** `https`, public host, no credentials, odd
  ports or IP addresses (`urls` with `hosts: [public]`), and the
  per-call URL count. **What it cannot:** whether a URL came from the
  search results or the lead's site, because it checks one call at a
  time. That rule lives in `usage.md` and the Preparer. Accepted risk: a
  prompt-injected page could ask for a fetch of another public URL; the
  path rule below limits what can ride on it.
- **Paths only** *(operator's choice)*: a `web-fetch` URL with a query
  string or a fragment is refused by the guard, not only by the
  instructions. That closes the easiest way to carry data out; data can
  still ride in a path, which is the accepted residual. Accepted cost:
  some news links that need a query do not open; the item is then judged
  from its search-result title, snippet and date, and the run report
  says the page was not fetched. The agent's instructions also refuse a
  path containing an email address, phone number or CRM id pattern. The
  engine's always-on 2048-character URL limit (`guard_policy.py:56`)
  caps length; it is not configurable.
- **The engine already does this:** a `urls` entry's `query` and
  `fragment` rules default to `forbid` (`hooks/guard_policy.py:346-348`),
  so the `web-fetch` entry is `schemes: [https]`, `hosts: [public]`,
  `path: any`, with `query` and `fragment` left at `forbid`. No engine
  change. The Standard note records the retrieval-profile
  `no_external_send` residual (any public `https` path) as documented
  and bounded.
- Each fetch counts against `research_budget_per_lead_minutes` and the
  weekly Apify cap like any other call.

## Cost

- Apify Console's monthly usage limit stays the hard stop (README and
  `usage.md` Setup step 1 already say so). *(My call:)* setup asks the
  operator to confirm it is set; the agent does not read it, because a
  connector resource read is a raw Apify API call that the guard hook
  does not see (`hooks/hooks.json:12` matches only `mcp__` tools).
- Each new actor gets a `usage.md` cost line from its probe (price per
  result and per start), and the ledger's per-call estimate uses it.
- The weekly cap and per-lead budget are unchanged.

## Setup and connector

- `usage.md` Setup step 2's connector URL lists every allowed actor plus
  `docs` and `runs`, and never `actors` or `api`.
- The probe (8.5.1 wording) already treats extra named actors as fine;
  it flags `call-actor`, the `actors` or `api` groups, and a missing
  allowed actor.
- New bindings in `bindings/scraping.md`: each new actor's caps,
  `max_web_fetches`. (The personal-data switches are `fixed` guard
  values, not bindings; see Loosened item 2.)
  Setup's tools step asks for them with defaults.

## Testing

- Policy tests (`tests/test-policies.sh`), per actor: a minimal passing
  call; each cap raised and omitted; each fixed value changed and
  omitted; each refused key blocked (the shared list once per actor);
  URL rules; an unknown harmless input now **passes** (the change this
  design is for); the generic tools denied.
- Content tests pin the new rules in the files above, and the removal
  of the old "never record reviewer names" wording.
- Evals: one case per drift row (empty field, vendor error, guard block
  continues, a source blocked on 2 leads is skipped for the rest of the
  run); a reviewer named in a finding and talking point, with no profile
  URL; a personal email recorded and picked as point of contact; a
  press item 2 weeks old fetched and a 5-month-old one not.
- Each new actor's probe is recorded under `docs/superpowers/notes/`.

## Rollout

1. agent-builder: allow the retrieval profile in the Standard and
   validator; release.
2. sales-partner 8.6.0, phase A: convert the existing ten actors to the
   open profile, the drift behavior, the personal-data changes and the
   new bindings. Ships alone so the behavior change is small to review.
3. Phase B: the new actors, each probed (one call, smallest size,
   personal data as the binding says), then added to the guard, tests
   and `usage.md`. Can ship as 8.6.x releases in any order; suggested
   order by value: `apify_web`, `apify_bbb`, `apify_yellowpages`,
   `apify_yelp`, LinkedIn jobs, the LinkedIn profile tools, the Facebook
   backup.
4. Live instance: upgrade, re-run setup's tools step for the new
   bindings, add the new sources to `prospecting_sources`, update the
   connector URL.

## Left to the builder

- Exact cap and switch keys per new actor (from each probe), and the
  exact `profileScraperMode` string for email search.
- Whether `web-search` or `google-search-scraper` is primary.
- Run-report and digest wording for drift lines.
- Test layout and helper reuse in `tests/test-policies.sh`.
