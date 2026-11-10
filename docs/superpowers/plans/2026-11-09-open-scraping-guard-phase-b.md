# Open scraping guard, Phase B: new sources — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the Phase B Apify tools to sales-partner under the 8.6.0
retrieval profile: open-web search and fetch, BBB, YellowPages, Yelp
reviews, LinkedIn jobs, the LinkedIn profile search and profile reader,
and the Facebook Ad Library backup. Each is pinned from its probe and
wired into research.

**Architecture:** No engine or Standard change: the guard's dotted and
`[]` paths already reach `query.url`, `pageUrls[]` and `urls[]`
(`hooks/guard_policy.py:73`). Each tool gets `allow`, per-tool
`fixed: null` refusals, size pins and URL rules in
`capabilities/scraping/tools/apify/guard.yaml`, policy tests, a `usage.md`
section and a line in the Preparer's source rule (or the Prospector's).
Four new sources join `prospecting_sources`: `apify_web`, `apify_bbb`,
`apify_yellowpages` and `apify_yelp`. The jobs, profiles and ads tools
join existing sources.

**Tech Stack:** Markdown agent plugin; YAML guard policies enforced by
`hooks/guard_policy.py`; bash test suites (`bash tests/run-all.sh`).

**Spec:** `docs/superpowers/specs/2026-11-09-open-scraping-guard-design.md`
(Sources, Open-web research, Cost, Setup and connector, Testing, Rollout
step 3). Probe facts: `docs/superpowers/notes/2026-11-09-phase-b-actors-probe.md`.

## Global Constraints

- Retrieval profile (Standard 7.5): tools allowed by name; generic tools (`call-actor`, `api`) stay denied; any input not refused, pinned, capped or fixed passes.
- `web-fetch` takes paths only: a URL with a query string or fragment is refused by the guard (engine default `forbid`).
- `web-fetch` reads, per lead, at most `max_web_fetches` URLs (default 5), each a page on the lead's own website host, a URL from this lead's search results, or a press item from those results dated within the last 3 months. Older items are not fetched.
- The agent's instructions also refuse a fetch path holding an email address, a phone number or a CRM id pattern.
- Personal data: reviewer names are kept (first name only in findings); profile photos, ids and profile URLs are never projected or recorded; personal emails are recorded like any found address.
- Drift rules from 8.6.0 apply to every new source unchanged (skip for the lead, report, 2-lead block skip, one end-of-run error).
- `AGENT.md` stays under 6000 bytes (it is 5983: do not add to it).
- `bash tests/run-all.sh` ends ALL GREEN; `../agent-builder/bin/validate-agent.sh . --require-bump origin/main` passes.
- Version 8.7.0 in `agent.yaml`, `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, `gemini-extension.json`; `standard: "7.5"` unchanged.

## Rulings made while planning (the spec left these to the builder)

1. **`apify--google-search-scraper` is dropped.** `web-search` is primary, and its own `provider: duckduckgo` is the backup. Why: the scraper's `queries` is one newline-separated string the guard cannot count; it has 13 paid add-ons; and it costs more ($1.80 vs $1.00 per 1,000). Cost if wrong: one more probe and section later.
2. **Operation names.** `search_pages` and `fetch_page` (scraping contract). The names are distinct from the `web_search` capability's `search_web` (Exa), which is unchanged. `find_listing` covers BBB and YellowPages, taking a `directory` argument.
3. **One release, 8.7.0**, not several 8.6.x. It adds sources (a minor bump), and the operator upgrades once before the live trial.
4. **YellowPages `maxPages` is fixed to 1**, not bound. It is the actor's only size key, at 30 items a page (about $0.06 a call).
5. **LinkedIn company search runs in `Short` mode** ($0.10 a page, no profile charge). Only the chosen candidate is read with the profile reader in `Profile details + email search ($10 per 1k)` mode. The reader's mode string carries the vendor's price, so a price change shows up as drift (a block, the source skipped and reported), as intended.
6. **LinkedIn jobs searches by `companyName` only**, with `datePosted` fixed to `r2592000` (30 days). The probe's keyword search returned a 2023 post.
7. **The Facebook backup takes `pageUrls` only**, and runs only when the primary Facebook call fails (vendor error or block). The probe's keyword search returned an unrelated advertiser.
8. **Bindings.** Only `max_web_results` (default 10) and `max_bbb_results` (default 5) are new guard-bound keys. `max_web_fetches` (default 5) is a binding the Preparer reads, not a guard bound, because the guard sees one call at a time. Every other new cap reuses an existing binding (Task-level tables). `schedule_check.py` requires every guard-bound key, so the README upgrade note says to run setup's tools step before the next scheduled run.

## Review Focus

1. A `web-fetch` sent as `POST` with `body.url`, or with `query.headers`: it must be blocked, not merely unchecked (Task 1 tests).
2. A Yelp or LinkedIn URL with a query (`?start=40`, `?trk=…`): it is blocked by the guard. The agent strips the query before sending (usage.md says so; Task 3 and 5 tests pin the block).
3. The LinkedIn profile search with `mongoDbConnectionString`: must be blocked for any non-null value, the empty string included (Task 5 test), since it ships results to an outside database.
4. BBB or YellowPages finding no listing: a valid result, not drift (usage and eval case pin it).
5. An instance upgraded without the two new bindings: the four new sources are skipped with `bindings missing` and one error, and the other sources still run (Task 7 content pin plus the existing Preparer rule).

---

### Task 1: `apify_web` — `search_pages` and `fetch_page`

**Files:**
- Modify: `capabilities/scraping/tools/apify/guard.yaml`, `tests/test-policies.sh`, `capabilities/scraping/tools/apify/usage.md`, `capabilities/scraping/contract.md`, `subagents/preparer.md`, `skills/research-company/SKILL.md`, `tests/test-content.sh`, `evals/cases.md`, `tests/test-schedules.sh` (`scrape()` adds `max_web_results: 10`)

**Interfaces:**
- Produces: contract ops `search_pages(query, location)` (results: title, URL, snippet, date when given) and `fetch_page(url)` (URL, title, markdown, JSON-LD); source `apify_web`; bindings `max_web_results`, `max_web_fetches`.

Guard (both tools: `apify--web-search`, `apify--web-fetch`):

| Element | Value |
|---|---|
| fixed, required | `method` = `"GET"`, `path` = `"/"` |
| fixed null (refused) | `body` |
| refuse_args (policy-wide, add) | `query.headers` |
| limits (web-search) | `query.maxResults`, kind max, bound `max_web_results`, required |
| urls (web-fetch) | at `query.url`, schemes `[https]`, hosts `public`, path `any`, required (query and fragment forbid by default) |

- [ ] **Step 1: Write the failing policy tests** in `tests/test-policies.sh`, after the TikTok block. `WS_OK='{"method":"GET","path":"/","query":{"query":"Franklin Barbecue Austin TX","maxResults":10,"countryCode":"US"}}'`, `WF_OK='{"method":"GET","path":"/","query":{"url":"https://franklinbbq.com/about","formats":["markdown"]}}'`. Checks:
  - `check 0` both OK calls, plus `harmless` for each (the top-level unknown key);
  - web-search: `maxResults` 11 is blocked; omitted is blocked; `"5"` (a string) passes;
  - `method` `"POST"` is blocked with `must send method = "GET"`; method omitted is blocked; `path` `"/x"` is blocked; a `body` object is blocked;
  - web-fetch: `?a=1` blocked, `#x` blocked, `http://` blocked, `https://127.0.0.1/` blocked, `https://user@x.com/` blocked, url omitted blocked; a `query.headers` string blocked;
  - `provider: duckduckgo` passes.

  Add the `bindings` fixture line `max_web_results: 10` to `$W/scraping.md` in the same file.
- [ ] **Step 2: Run** `bash tests/test-policies.sh 2>&1 | tail -5`. Expected: the new checks FAIL (tool not allowed).
- [ ] **Step 3: Add the guard entries above** plus both names to `allow`. Extend the header comment: one line for the HTTP shape, and one for the residual: "a search query or a fetch path can carry data out; paths only, and instructions refuse emails, phones and CRM ids in a path".
- [ ] **Step 4: Run** `bash tests/test-policies.sh 2>&1 | tail -3`. Expected: all pass.
- [ ] **Step 5: Write the failing content pins** (`tests/test-content.sh`, new block "8.7.0: apify_web") for these phrases:
  - in usage.md: `search_pages`, `fetch_page`, `"method": "GET"`, `provider: duckduckgo`, `max_web_fetches`, `dated within the last 3 months`, `never an email address, phone number or CRM id`;
  - in contract.md: `| \`search_pages\`` and `| \`fetch_page\``;
  - in the Preparer: `apify_web` with the three allowed URL kinds;
  - in research-company: a fetched press item becomes a `news` finding with its date and URL.

  Run them; expect FAIL.
- [ ] **Step 6: Write the docs.**
  - `usage.md` gets a section for each op: args sent and no others; the result fields from the probe note; and the cost line `| search_pages | $0.002 |`, `| fetch_page | $0.002 |`.
  - The `max_web_results` Setup line.
  - The contract gets two rows.
  - The Preparer gets an `apify_web` evidence source. It runs one `search_pages` per lead (name plus city), then up to `max_web_fetches` `fetch_page` calls. URLs are only of the three kinds, the path is stripped of query and fragment, and it never refetches a URL. A news link that needs a query is judged from its title, snippet and date, and listed as not fetched.
  - research-company maps a press item to `news`.
- [ ] **Step 7: Add eval cases** 62 (a press item 2 weeks old is fetched and becomes `news`; one 5 months old is not fetched) and 63 (a search result URL with `?id=` is fetched without its query, or skipped when the page needs it).
- [ ] **Step 8: Run** `bash tests/run-all.sh 2>&1 | tail -3`. Expected: ALL GREEN.
- [ ] **Step 9: Commit** `feat(scraping): open-web search and fetch (apify_web)`.

### Task 2: `apify_bbb` and `apify_yellowpages` — `find_listing`

**Files:** the same set as Task 1, plus `subagents/prospector.md`, `context/operating-config.md`, `skills/find-decision-makers/SKILL.md`, `tests/test-schedules.sh` (`max_bbb_results: 5`).

**Interfaces:**
- Consumes: `max_search_terms` (existing).
- Produces: `find_listing(directory: bbb|yellowpages, query, location)`, which returns BBB items (rating, accreditation, years, complaint counts, principal contacts, email, website, phone, profile URL) or YellowPages items (name, claimed, rating, review count, phone, website, email, categories, listing URL). None is a valid "no listing" result.

| Tool | Pins |
|---|---|
| `scrapesage--bbb-scraper` | fixed required `includeDetails` = true; recipients `maxResults` = `max_bbb_results`; limits count required `searchTerms`, `locations` at `max_search_terms`; fixed null `includeReviews, maxReviewsPerBusiness, enrichContacts, monitorMode, monitorKey, maxResultsPerSearch, maxConcurrency, startUrls, urlsFromFile` |
| `delicious_zebu--yellowpages-usa-business-lead-scraper` | fixed required `maxPages` = 1; limits count required `searchKeyword` at `max_search_terms`; fixed null `urls` |

Add `urlsFromFile` to the shared `refuse_args`, since several actors take it (BBB, the FB backup and Google Ads, which already nulls it). Keep it in the BBB null list too.

- [ ] **Step 1: Write the failing policy tests.** `BBB_OK='{"searchTerms":["Franklin Barbecue"],"locations":["Austin, TX"],"maxResults":5,"includeDetails":true,"waitSecs":45}'` and `YP_OK='{"searchKeyword":["Franklin Barbecue"],"location":"Austin, TX","maxPages":1,"waitSecs":45}'`. Checks:
  - each OK call passes, and each has a `harmless` check;
  - `nulled` checks for each null list;
  - `maxResults` 6 is blocked and omitted is blocked;
  - `includeDetails` false is blocked and omitted is blocked;
  - two search terms are blocked;
  - YellowPages `maxPages` 2 is blocked and omitted is blocked;
  - `proxyConfiguration` on BBB is blocked (the shared refusal).
- [ ] **Step 2: Run, expect FAIL.** **Step 3: Write the guard entries.** **Step 4: Run, expect PASS.**
- [ ] **Step 5: Write the failing content pins:**
  - usage.md `find_listing` with both directories and the projections `businessName,bbbRating,accredited,yearsInBusiness,businessStarted,complaintCount,complaintsLast12Months,customerReviewCount,email,website,phone,principalContacts,profileUrl` and `title,is_claimed,star_rating,rating_count,phone,website,email,source_url,categories`;
  - the cost lines `| find_listing, BBB | $0.02 per business |` and `| find_listing, YellowPages | $0.06 per call |`;
  - the Preparer's `apify_bbb` and `apify_yellowpages` research lines;
  - find-decision-makers: a BBB principal contact with an owner title is a decision-maker candidate, source `BBB`;
  - the Prospector: `apify_yellowpages` sources leads through `find_listing(directory: yellowpages, …)`, deduplicated by phone and website like Maps;
  - operating-config: the two sources.

  Run them; expect FAIL.
- [ ] **Step 6: Write the docs.**
  - Research matches a BBB or YellowPages item to the lead by phone or website host. A name-only match is not enough: an unmatched item is dropped.
  - A YellowPages review author follows the reviewer-name rule (first name only).
  - A BBB `email` or a YellowPages `email` is recorded like any found address.
  - The Prospector's source list in `subagents/prospector.md:50-56` gains `apify_yellowpages`, and `apify_bbb` joins the Preparer-only list.
- [ ] **Step 7: Add eval cases** 64 (a BBB principal "Owner/Operator" becomes the point of contact when the lead had none) and 65 (BBB returns no listing; no drift line).
- [ ] **Step 8: Run all; expect ALL GREEN.** **Step 9: Commit** `feat(scraping): BBB and YellowPages listings`.

### Task 3: `apify_yelp` — `find_reviews(site: yelp)`

**Files:** guard, policy tests, usage.md, contract.md (the `find_reviews` row gains `site` and `url`), the Preparer, content tests, evals.

| Tool | Pins |
|---|---|
| `web_wanderer--yelp-reviews-scraper` | fixed required `include_personal_data` = true; recipients `reviews_limit` = `max_reviews`; limits count required `biz_urls` at `max_review_places`; urls `biz_urls[]` schemes https, hosts `[www.yelp.com]`, path `/biz`, required; fixed null `biz_ids, search_urls, search_location, search_limit, search_sort, search_features, search_price, domain, reviews_language, reviews_translate` |

- [ ] **Step 1: Write the failing tests.** `YELP_OK='{"biz_urls":["https://www.yelp.com/biz/franklin-barbecue-austin"],"reviews_limit":50,"reviews_sort":"newest","include_personal_data":true,"waitSecs":45}'`. Checks:
  - the OK call passes, plus `harmless` and `nulled`;
  - `?start=40` is blocked; `https://www.yelp.ca/biz/x` is blocked; `/search?…` is blocked;
  - `reviews_limit` 51 is blocked; `reviews_limit` 0 is blocked (0 means all: check that the engine's recipients pin rejects 0 against 50; if it passes, add `limits` kind max on `reviews_limit` and ledger a ruling);
  - `include_personal_data` false is blocked.
- [ ] **Step 2: Run, expect FAIL.** **Step 3: Write the guard.** **Step 4: Run, expect PASS.**
- [ ] **Step 5: Write the failing content pins:**
  - usage.md: the Yelp projection `name,businessRating,totalReviews,rating,reviewDate,text,reviewUrl,publicReply,author.name`, and the line that it never asks for `author.profile_photo`, `author.friend_count` or other author fields;
  - the Yelp URL comes from this lead's `search_pages` results or its website's links, with path `/biz/…` and no query;
  - the cost line `| find_reviews, Yelp | $0.02 |`;
  - the Preparer: `apify_yelp` runs when reviews are picked and a Yelp URL is known.

  Run them; expect FAIL.
- [ ] **Step 6: Write the docs.** `author.name` gives "Lily C.", so a finding names "Lily". **Step 7: Add eval case** 66 (a Yelp complaint goes in `Avoid:` with first name and date, like Google). **Step 8: Run all.** **Step 9: Commit** `feat(scraping): Yelp reviews (apify_yelp)`.

### Task 4: LinkedIn jobs in `find_jobs`

| Tool | Pins |
|---|---|
| `valig--linkedin-jobs-scraper` | recipients `limit` = `max_jobs`; limits count required `companyName` at `max_search_terms`; fixed required `datePosted` = `"r2592000"`; fixed null `urlParam, urlPath, keywords` |

`find_jobs` runs Indeed then LinkedIn for the lead, as two ledger steps like `find_ads`. Projection: `title,companyName,location,postedDate,applicationsCount,url`. Keep only items whose `companyName` matches the lead's name. Cost: `| find_jobs, LinkedIn | $0.005 |`.

- [ ] Steps 1–9 as in Task 3, with `LIJ_OK='{"companyName":["Franklin Barbecue"],"location":"Austin, TX","datePosted":"r2592000","limit":20,"waitSecs":45}'`. Tests: limit 21 blocked; `datePosted` `r604800` blocked (a fixed value); `keywords` blocked; `urlParam` blocked. Eval case 67: a LinkedIn post from a different company with a similar name is dropped. Commit `feat(scraping): LinkedIn jobs in find_jobs`.

### Task 5: LinkedIn profile search and reader

**Files:** guard, policy tests, usage.md (`find_profiles`, `read_profile`), contract.md (the `read_profile` row: LinkedIn now read), the Preparer's Profile pass, `skills/find-decision-makers/SKILL.md`, `skills/find-social-profiles/SKILL.md`, content tests, evals.

| Tool | Pins |
|---|---|
| `harvestapi--linkedin-profile-search` | fixed required `profileScraperMode` = `"Short"`, `takePages` = 1; recipients `maxItems` = `max_profile_results`; limits count required `currentCompanies` at `max_search_terms`; urls `currentCompanies[]` https, hosts `[www.linkedin.com, linkedin.com]`, path `/company`, required; fixed null `mongoDbConnectionString, mongoDbDatabaseName, profileDeduplicationMode, postFilteringMongoDbQuery, postFilteringMongoDbAggregation, autoQuerySegmentation, autoQuerySegmentationLevels, autoQuerySegmentationTargetCountries, searchCoverage, startPage, pastCompanies, excludePastCompanies, schools, firstNames, lastNames` |
| `harvestapi--linkedin-profile-scraper` | fixed required `profileScraperMode` = `"Profile details + email search ($10 per 1k)"`; limits count required `urls` at `max_profile_reads`; urls `urls[]` https, hosts `[www.linkedin.com, linkedin.com]`, path `/in`, required; fixed null `queries, publicIdentifiers, profileIds` |

Add `mongoDbConnectionString` to the shared `refuse_args` as well (defense in depth).

Use: when a lead has no owner name, `find-decision-makers` runs the company search. It needs the company's LinkedIn URL, taken from its website links, search results or contacts, and uses `seniorityLevelIds` `["310","320"]` (CXO, Owner/Partner). In the Profile pass, the reader runs only for a candidate already judged confident, to get the employer and emails. Its email goes to an empty `Email` under the 8.6.0 rule (notes `email from LinkedIn email search`).

Costs: `| find_profiles, LinkedIn company search | $0.10 per call |` and `| read_profile, LinkedIn | $0.02 per profile |`.

- [ ] Steps 1–9 as above. Tests:
  - the OK calls pass, plus `harmless` and `nulled`;
  - `mongoDbConnectionString` blocked (also as `""` through refuse_args? `""` passes refuse_args by design, so the `fixed: null` entry must block it; assert `must send mongoDbConnectionString = null`);
  - `Full` mode on the search blocked; `takePages` 2 blocked;
  - the reader with the no-email mode blocked;
  - `?trk=x` on an `/in/` URL blocked; a `/company/x` URL on the reader blocked; a `/in/x` URL in `currentCompanies` blocked.

  Eval case 68: a lead with no owner name gets an Owner/Partner from the company search, then the reader's email becomes the point of contact's email. Commit `feat(scraping): LinkedIn company search and profile reader`.

### Task 6: Facebook Ad Library backup

| Tool | Pins |
|---|---|
| `scrapesage--facebook-ad-library-scraper` | recipients `maxResults` = `max_ads`; limits count required `pageUrls` at `max_ad_queries`; urls `pageUrls[]` https, hosts `[facebook.com, www.facebook.com]`, path any, required; fixed null `searchTerms, startUrls, urlsFromFile, monitoringMode, monitorId` |

Runs only after the primary `apify--facebook-ads-scraper` call returns a vendor error or a guard block for the lead, with the same normalized page URL. Projection: `pageName,pageId,isActive,status,startDate,endDate,publisherPlatforms,adLibraryUrl`. The finding is "has ads" (count of items, active ones) rather than the primary's total. Cost: `| find_ads, Facebook backup | $0.01 |`.

- [ ] Steps 1–9 as above, with `FBB_OK='{"pageUrls":["https://www.facebook.com/franklinbbq"],"maxResults":5,"country":"US","waitSecs":45}'`. Tests:
  - `searchTerms` blocked; `maxResults` 0 blocked;
  - a page name instead of a URL is blocked (not a URL);
  - `?ref=x` blocked.

  Eval case 69: the primary Facebook call errors, the backup runs, and the drift line names only the primary. Commit `feat(scraping): Facebook Ad Library backup`.

### Task 7: Release 8.7.0

**Files:** `usage.md` (intro count; Setup step 2 connector URL with all 19 actors; Setup bindings `max_web_results`, `max_bbb_results`, `max_web_fetches`; the Probe tool list), `README.md` (version, sources, an "Upgrading from 8.6.0" note), `context/operating-config.md` and `skills/interview-business/SKILL.md` (the four new sources described), the Preparer's Missing bindings rule (`apify_web` needs `max_web_results`; `apify_bbb` needs `max_bbb_results`), the version files, `tests/test-content.sh`.

The upgrade note covers four steps:
1. Replace the connector URL.
2. Run setup's tools step to write `max_web_results`, `max_bbb_results` and `max_web_fetches`, then commit and push the bindings. Do this before the next scheduled run: the scheduled-run gate requires every bound key.
3. Add `apify_web`, `apify_bbb`, `apify_yellowpages` and `apify_yelp` to `prospecting_sources` when wanted.
4. Start a new session.

- [ ] **Step 1: Write the failing content pins:** version 8.7.0 in the four files; the connector URL contains each new actor id; the README has `Upgrading from 8.6.0`; the Missing bindings line names the two new keys; and a stale-count guard: usage.md must not say "Runs ten Apify actors". Run them; expect FAIL.
- [ ] **Step 2: Write the docs and bump the versions.** **Step 3: Run** `bash tests/run-all.sh 2>&1 | tail -3` (expect ALL GREEN) and `../agent-builder/bin/validate-agent.sh . --require-bump origin/main` (expect `conforms`).
- [ ] **Step 4: Commit** `chore: sales-partner 8.7.0`.
