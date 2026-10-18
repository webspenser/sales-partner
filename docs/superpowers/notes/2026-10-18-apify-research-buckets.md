# Apify actor research for Sales Partner evidence buckets

Researched 2026-10-18 (read-only; no actor was run, nothing signed up for).
Budget: up to $2.00 Apify spend per researched lead. Guard model: pin size args, allowlist argument names.

## How to read this / sourcing

Every number below (users, rating, last updated, pricing, input defaults) was read from Apify's public, unauthenticated API on 2026-10-18. Each actor block ends with a `Source:` line giving the exact URLs.

- Actor metadata, stats, pricing, run options: `https://api.apify.com/v2/acts/<owner>~<name>` (fields `stats.totalUsers`, `stats.totalUsers30Days`, `stats.actorReviewRating`, `modifiedAt`, `pricingInfos`, `defaultRunOptions`).
- Input schema (names, defaults, min/max, descriptions): the latest build's `actorDefinition.input` at `https://api.apify.com/v2/actor-builds/<buildId>` (buildId is in `taggedBuilds.latest.buildId` of the actor endpoint). Human view: `https://apify.com/<owner>/<name>/input-schema`.
- Store listing / discovery: `https://api.apify.com/v2/store?search=<query>&limit=N` and the store pages `https://apify.com/<owner>/<name>`.
- Compute price: `https://apify.com/pricing` (fetched via summarizer: Free $0.2/CU, Starter $0.2/CU, Scale $0.16/CU, Business $0.13/CU) and the Website Content Crawler page `https://apify.com/apify/website-content-crawler` (states "$0.25 per CU" baseline, "$0.2 per 1,000 pages with raw HTTP crawler", "$0.5 - $5 per 1,000 web pages with a headless browser"). These two pages disagree slightly on CU price; use the higher figure for budgeting.

Conventions:
- "Users" = `totalUsers` / `totalUsers30Days`. "Rating" = `actorReviewRating` (count of reviews in parentheses).
- Tiered PPE prices are shown as FREE-plan price / BRONZE price (BRONZE is the next tier up; I did not verify which Apify subscription maps to BRONZE, so treat the FREE-plan number as the conservative budget). The existing repo estimate ($0.004 per Maps place) is the FREE-plan price too (`/Users/hochoy/Work/Webspenser/sales-partner/capabilities/scraping/tools/apify/usage.md`).
- "Start" = the `apify-actor-start` event, charged once per run, per GB of memory (min 1 event).
- Per-lead estimates assume a typical small local business: about 80 to 300 Google reviews, one website of 5 to 30 pages, a name that is not a household brand.
- Wherever a pricing change is scheduled in the future I say so; the prices below are the ones in effect on 2026-10-18.

Cross-cutting facts that matter for the guard:
1. `minimalMaxTotalChargeUsd` is a platform-enforced floor on any per-run max-charge cap. Values seen: compass/crawler-google-places 0.5, apify/google-search-scraper 0.5, fatihtahta/ziprecruiter-scraper 1, api-ninja reviews 0.1. You cannot cap those actors' per-run spend below that figure with `maxTotalChargeUsd`, so the pinned size args are the real limit.
2. Actors with `isPPEPlatformUsagePaidByUser: true` (kaix reviews, kaix indeed, jmlp Meta, lofomachines SERP, rl1987 Wappalyzer, epctex) bill Apify compute and proxy usage to the caller in addition to the per-event price. They are cheap in events but the total is less predictable.
3. The Apify MCP server currently exposed to the agent has only `compass--crawler-google-places` and `vdrmota--contact-info-scraper` tools (plus run/dataset/KV readers). Every pick below needs its tool enabled on the MCP server (for example by adding it to the server's actors list) and a new `only_keys` entry in `guard.yaml`. Not verified here: whether the hosted MCP tool lets the caller override run memory (matters for Website Content Crawler, see bucket 5).

---

## Bucket 1: Maps reviews

### Does `compass/crawler-google-places` return reviews itself? Yes, as a paid add-on.

- Input `maxReviews` (integer, default **0** = no reviews, min 0). Setting it >0 adds the review add-on. Description: "To extract all reviews, set this to 99999"; each output place item holds at most 5,000 reviews, extra reviews spill into duplicate place items.
- Related inputs: `reviewsStartDate` (absolute `2024-05-03` or relative `3 months`; requires `reviewsSort: newest`), `reviewsSort` (default `newest`; enum newest, mostRelevant, highestRanking, lowestRanking), `reviewsFilterString` (keyword filter, max 500 bytes, default empty), `reviewsOrigin` (default `all`), `scrapeReviewsPersonalData` (default true).
- Cost when you set `maxReviews`: place-scraped $0.004 (FREE) / $0.003 (BRONZE) per place + **place-details-scraped add-on $0.002 / $0.002** per place (the schema says this add-on is charged for each place scraped for reviews because the detail page must be opened) + **review-scraped $0.0005 / $0.0005 per review** + start $0.00005. So 50 reviews on one place = 0.004 + 0.002 + 0.025 + 0.00005 = **$0.031** on FREE. If you re-scrape by `placeIds` you pay the place fee again, which is why a dedicated reviews actor is cheaper for the evidence step.
- Guard note: `maxReviews` default is 0, so it is safe by default, but `maxCrawledPlacesPerSearch` default is null (unbounded) and `minimalMaxTotalChargeUsd` is 0.5. Other paid add-on args to keep blocked: `scrapeContacts`, `maximumLeadsEnrichmentRecords`, `verifyLeadsEnrichmentEmails`, `scrapeSocialMediaProfiles`, `maxImages`, `enableCompetitorAnalysis` ($0.025 per competitor), `maxQuestions`, `scrapeTableReservationProvider`, `scrapeOrderOnline`, `includeWebResults`, `categoryFilterWords`/`placeMinimumStars`/`website`/`skipClosedPlaces` (each triggers the $0.001 filter add-on).
- Source: https://api.apify.com/v2/acts/compass~crawler-google-places (pricing, run options), input schema https://apify.com/compass/crawler-google-places/input-schema. Users 655,297 / 42,851; rating 4.70 (1,816); last updated 2026-10-15; 30-day success 96.8% of 4,146,379 runs (same endpoint).

### Candidate 1A (recommended): `compass/Google-Maps-Reviews-Scraper`

- URL: https://apify.com/compass/google-maps-reviews-scraper
- Users 63,008 total / 7,950 in 30 days; rating 4.85 (198 reviews); last updated 2026-10-15; 30-day success 99.7% of 13.04M runs.
- Pricing: pay-per-event. `review-scraped` **$0.0006 (FREE) / $0.00045 (BRONZE) / $0.0004 (SILVER) per review**; `apify-actor-start` $0.00005. No other events, so no add-ons to block.
- Target identification: `placeIds` (27-char IDs starting `ChIJ` or `GhIJ`) or `startUrls` (objects with `url`; place, search or review URLs). Pass `placeIds` only; the Maps actor already returns `placeId`.
- Size/cost bounds (exact names and defaults):
  - `maxReviews` integer, min 1, **default 10,000,000 (effectively unlimited; pin it)**.
  - `reviewsStartDate` string, absolute date or relative (`6 months`); only works with `reviewsSort: newest`; the actor stops at the first review older than the date.
  - `reviewsSort` enum newest | mostRelevant | highestRanking | lowestRanking, default newest.
  - `reviewsFilterString` string up to 500 bytes: server-side keyword filter, only matching reviews are returned (and billed). Google treats it as one query string, so use one phrase per call (for example `voicemail`); I could not confirm multi-keyword OR semantics, so assume one phrase per call.
  - `reviewsOrigin` enum all | google, default all (set `google` to avoid Tripadvisor etc.).
  - `language` default `en`; `personalData` boolean default **true** (set false; reviewer names are personal data and not needed).
- Paid add-ons to block: none exist. Run defaults: 1024 MB, 36,000 s timeout, no `maxTotalChargeUsd` default (set one).
- Output fields relevant to signals: `text`, `textTranslated`, `stars`, `publishedAtDate`, `publishAt`, `likesCount`, `responseFromOwnerText`, `responseFromOwnerDate`, `reviewId`, `reviewUrl`, `originalLanguage`, `placeId`, `title`, `totalScore`, `reviewsCount` (sample in the actor README, https://apify.com/compass/google-maps-reviews-scraper).
- Risks: no cookies or login; default proxy handled by the actor (no user-supplied proxy). `startUrls` accepts arbitrary URL objects, so keep it out of the allowlist and use `placeIds`.
- Per-lead estimate (FREE plan):
  - Option A, one call, newest 50 reviews, grep locally: 0.00005 + 50 x 0.0006 = **$0.030** (BRONZE: $0.0226).
  - Option B, three keyword-filtered calls (`voicemail`, `never called back`, `billing`) with `maxReviews` 10 each: worst case 3 x (0.00005 + 10 x 0.0006) = **$0.018**, typical far less because only matching reviews are billed.
  - Option A + B worst case $0.048.
- Source: https://api.apify.com/v2/acts/compass~Google-Maps-Reviews-Scraper ; input schema https://apify.com/compass/google-maps-reviews-scraper/input-schema

### Candidate 1B: `kaix/google-maps-reviews-scraper`

- URL: https://apify.com/kaix/google-maps-reviews-scraper
- Users 1,762 / 320; rating 4.89 (13); last updated 2026-10-13; success 94.9% of 64,961 (30 days).
- Pricing: PPE `apify-default-dataset-item` ("reviews") **$0.00004 per review flat**; start $0.00005. **Platform usage is also billed to the caller** (`isPPEPlatformUsagePaidByUser: true`; price-change note: "we include a platform usage fee so you pay for the actual compute your run consumes", effective 2026-07-15).
- Target: `urls` (required array; place URLs, URLs containing a place ID, or bare place IDs).
- Bounds: `maxReviews` default **20**, "Set to 0 for no per-place limit"; `sort` enum relevant | newest | highest | lowest (default newest); `searchQuery` (keyword or phrase filter); `reviewsNewerThan` / `reviewsOlderThan` (JS-parsed dates); `language`, `region`; `proxyConfiguration` (default Apify proxy; do not allow).
- Per-lead estimate: events 50 x 0.00004 = $0.002 plus compute for a 1 GB run of roughly 30 to 60 s (about 0.01 CU x $0.2 = $0.002), so roughly **$0.005 to $0.01** total; cheaper than 1A by 3x to 6x but much lower usage and less predictable bill.
- Risk: smaller user base and 94.9% success rate; pin `maxReviews` (0 means unlimited).
- Source: https://api.apify.com/v2/acts/kaix~google-maps-reviews-scraper

### Candidate 1C: `web_wanderer/google-reviews-scraper`

- URL: https://apify.com/web_wanderer/google-reviews-scraper
- Users 2,178 / 303; rating 4.69 (8); last updated 2026-09-04; success 96.4% of 62,189.
- Pricing: PPE `Review` **$0.00035 (FREE) / $0.00032 (BRONZE)** per review plus `apify-actor-start` **$0.002 (FREE) / $0.0016 (BRONZE)** per run (raised 2026-06-11; the actor says it was "running at a loss").
- Target: `place_urls` or `place_ids`. Also has `search` (Maps search queries) which would let it crawl many places: keep out of the allowlist.
- Bounds: `limit` default **200**, max 100,000; `order` default most_relevant; `anyDate` (YYYY-MM-DD or `{number} {unit}`); `searchKeyword`; `filter_stars`; `source` default all; `include_personal` default false; `search_limit` default 1, `sort_dataset` etc. (irrelevant).
- Per-lead estimate: 50 reviews = 0.002 + 50 x 0.00035 = **$0.0195**.
- Risk: the `search`, `search_limit`, `search_location` args expand into many places if allowed.
- Source: https://api.apify.com/v2/acts/web_wanderer~google-reviews-scraper

Also looked at (not recommended): `api-ninja/google-maps-reviews-scraper` (375 / 52 users; FREE-plan price $0.005 per result vs $0.0003 on paid tiers, start $0.01; `maxReviewsPerPlace` min 100 so you cannot go small; https://api.apify.com/v2/acts/api-ninja~google-maps-reviews-scraper) and `delicious_zebu/google-maps-store-review-scraper` (731 / 27; $0.0004 per result FREE; `maxCrawlPages` default 50 pages of about 10 reviews, 0 = unlimited; https://api.apify.com/v2/acts/delicious_zebu~google-maps-store-review-scraper).

### Bucket 1 recommendation

**`compass/Google-Maps-Reviews-Scraper`** with `placeIds` = [one id], `maxReviews` = 50 (pinned), `reviewsSort` = newest, `reviewsStartDate` = `12 months`, `reviewsOrigin` = google, `personalData` = false; optionally follow with keyword-filtered calls via `reviewsFilterString`. Highest usage and rating of the dedicated actors, maintained by the same team as the Maps actor already in use, tiny start fee, one billing event. Estimated **$0.03** per lead (worst case $0.048 with three filtered follow-ups).

---

## Bucket 2: Search (Google results as a structured list)

### Candidate 2A (recommended): `apify/google-search-scraper`

- URL: https://apify.com/apify/google-search-scraper
- Users 210,169 / 27,733; rating 4.61 (219 reviews); last updated 2026-10-17; success 98.2% of 8.05M runs (30 days). Maintained by Apify.
- Pricing: PPE `search-page-scraped` **$0.0045 (FREE) / $0.0025 (BRONZE) / $0.00195 (SILVER) per results page** (about 10 results); start $0.00005; `minimalMaxTotalChargeUsd` 0.5. Price took effect 2026-10-07.
- Paid add-ons to block (all are args on the input): `aiOverview` ($0.003 FREE per query), `aiModeSearch` ($0.2 FREE / $0.005 BRONZE), `geminiSearch`, `perplexitySearch` ($0.2 FREE / $0.013 BRONZE), `chatGptSearch`, `copilotSearch` (each $0.2 FREE), `maximumLeadsEnrichmentRecords` ($0.1 per lead FREE), `verifyLeadsEnrichmentEmails` ($0.1 FREE), `linkProspecting`, `websiteContentScraper` ($0.008 per page FREE), `focusOnPaidAds` ($0.0065 per page FREE; see bucket 3).
- Target: `queries`, which is **a single string, newline-separated; each line is a separate query** (or Google Search URLs). Guard it as exactly one line, or cap line count, since lines multiply cost. Site-restricted queries work either via `site:` in the string or the `site` arg (domain pattern only).
- Size/cost bounds: `maxPagesPerQuery` integer min 1, **default null (not set; pin to 1)**. Other filters: `site`, `quickDateRange`, `afterDate`/`beforeDate`, `countryCode` (default US), `languageCode`, `forceExactMatch`, `wordsInTitle/Text/Url`, `fileTypes`, `mobileResults`. Also block `saveHtml`, `saveHtmlToKeyValueStore` (default **true**, stores page HTML in the KV store), `includeIcons`, `includeUnfilteredResults`.
- Output (README): `organicResults[]` with `title`, `url`, `displayedUrl`, `description`, `position`, `siteLinks`; also `paidResults`, `relatedQueries`, `peopleAlsoAsk`, `searchQuery`.
- Risks: nothing needs cookies; proxy is handled by the actor (do not allow `proxyConfiguration`-type args). README example input shows more fields than the schema (for example `maxConcurrency`), so keep the allowlist strict.
- Per-lead estimate: 3 queries x 1 page (business name + city; `"<name>" site:facebook.com`; `"<name>" reviews complaints`) = 3 x 0.0045 + 0.00005 = **$0.0136** (BRONZE $0.0076). As three separate runs add 2 more starts: $0.0137.
- Source: https://api.apify.com/v2/acts/apify~google-search-scraper ; README https://apify.com/apify/google-search-scraper

### Candidate 2B: `scraperlink/google-search-results-serp-scraper`

- URL: https://apify.com/scraperlink/google-search-results-serp-scraper
- Users 13,454 / 3,488; rating 4.80 (44); last updated 2026-09-03; success 99.9% of 4.33M (30 days).
- Pricing: PPE `apify-default-dataset-item` ("search result pages") **$0.0005 per page** flat, no start event, no tiers (title "~$0.05/1K results"; README says $0.50 per 1,000 searches of up to 10 results; the README also says "Includes 100 free searches/month; an Apify paid plan is required to continue afterward").
- Target: `keyword` (required string, one query per line; default "nike").
- Bounds: `limit` enum 10 | 20 | 30 | 40 | 50 | 100 | **all (default all)**; each page = up to 10 results, so `limit: "10"` = one page. `include_merged` boolean default **true** (adds a merged row with page_number "all"; it is a dataset item so it may be billed; pin false). `page`, `start`, `tbs` (time filter), `gl`, `hl`, `country`, `proxy_location` (us/ca).
- Per-lead estimate: 3 queries x 1 page x $0.0005 = **$0.0015** (assuming the merged row is off).
- Risk: smaller-team actor; run default 128 MB / 120 s timeout. Unknown whether `include_merged` is billed; pin it off.
- Source: https://api.apify.com/v2/acts/scraperlink~google-search-results-serp-scraper

### Candidate 2C: `lofomachines/google-serp-scraper`

- URL: https://apify.com/lofomachines/google-serp-scraper
- Users 866 / 393; rating 0 (0 reviews); last updated 2026-10-01; success 99.9% of 31,846.
- Pricing: PPE `apify-default-dataset-item` ("result") **$0.0005 (FREE) / $0.00014 (BRONZE and above)** per organic result; start $0.00005; **platform usage billed to caller** (since 2026-10-09).
- Target: `query` (array, 1 to 1,000 keywords). Bounds: `maxItems` min **20**, max 300, default 20 (results per keyword); `maxConcurrency` default 50; `proxyConfiguration` and `customSearchEngineId` overrides (block both).
- Per-lead estimate: 3 queries x 20 results x $0.0005 = $0.030 on FREE ($0.0084 on BRONZE) plus compute.
- Risk: no reviews, newer actor, minimum 20 results per keyword so no one-page minimum.
- Source: https://api.apify.com/v2/acts/lofomachines~google-serp-scraper

Others seen: `apidojo/google-search-scraper` (1,474 / 208; 3.90 (11); $0.002 per query + $0.0002 per result beyond the first 10; `maxItems`, `maxPagesPerQuery` default null; https://api.apify.com/v2/acts/apidojo~google-search-scraper), `damilo/google-search-apify` (642 / 7; $0.0005 per result + $0.002 per page; https://api.apify.com/v2/acts/damilo~google-search-apify). Store listing: https://api.apify.com/v2/store?search=google%20search%20results&limit=15.

### Bucket 2 recommendation

**`apify/google-search-scraper`**: `queries` = one line, `maxPagesPerQuery` = 1, all add-ons blocked, `saveHtml`/`saveHtmlToKeyValueStore` off. Largest user base by far, Apify-maintained, results are exactly structured organic lists. About **$0.0136** per lead for 3 queries (FREE plan). If cost matters more than provenance, `scraperlink/google-search-results-serp-scraper` is about 9x cheaper at **$0.0015**.

---

## Bucket 3: Ads (Google Ads Transparency, Google Local Services Ads, Meta Ad Library)

### 3a. Google Ads Transparency Center

#### Candidate 3a-A (recommended): `scrapesage/google-ads-transparency-scraper`

- URL: https://apify.com/scrapesage/google-ads-transparency-scraper
- Users 2,270 / 1,100; rating 5.00 (1 review); last updated 2026-10-17; success 99.6% of 26,097 (30 days).
- Pricing: PPE, effective since 2026-06-11: `ad` **$0.002** per ad creative; `advertiser` **$0.003** per advertiser summary (ad-check mode); `detail` $0.003 per ad (only with `includeDetails`); `adText` $0.002 per ad (event exists; I could not find the corresponding input arg in the current schema, so keep unknown args out). No start fee, no tiers. A pricing record dated 2026-11-01 exists with the same prices (no change).
- Target: `queries` (array; brand names or domains, resolved through the Transparency Center autocomplete), or `domains`, `advertiserIds` (start with `AR`), `startUrls`.
- Size/cost bounds: `resultType` enum ads | **advertisers** (use `advertisers`: "one summary row per advertiser (approximate ad counts, country, legal name, verified badge)... ideal for checking whether companies run Google Ads"); `maxAdvertisersPerQuery` integer 1 to 50, **default 5 (pin to 1 or 2)**; `maxAdsPerSearch` integer 1 to 50,000, **default 100 (pin to 5 if using ads mode)**; `includeDetails` default false (block, adds $0.003 per ad); `region` default US; `platforms`, `adFormat`, `startDate`/`endDate`.
- Block: `proxyConfiguration` (default is Apify RESIDENTIAL group), `onlyNewAds` + `monitorStoreName` (writes named KV stores), `includeRawData`, `urlsFromFile` (fetches a user-supplied file/URL), `detailConcurrency`.
- Output (ads mode README): `creativeId`, `advertiserId`, `advertiserName`, `domain`, `format`, `firstShown`, `lastShown`, `shownForDays`, `adUrl`, `region`, `advertiserCountry`, `advertiserLegalName`, `advertiserVerified`; advertisers mode: approximate ad count per advertiser.
- Per-lead estimate: advertisers mode, 1 query, `maxAdvertisersPerQuery` 1 = **$0.003** (no charge if no advertiser matches); ads mode with `maxAdsPerSearch` 5 = $0.010.
- Risk: name matching for small businesses is fuzzy (brand-name autocomplete); prefer querying the website domain from the Maps record. Small businesses that advertise via an agency can appear under the agency's legal name (the README says the verified legal name is for "spotting agencies and resellers").
- Source: https://api.apify.com/v2/acts/scrapesage~google-ads-transparency-scraper

#### Candidate 3a-B: `automation-lab/google-ads-transparency-center-scraper`

- URL: https://apify.com/automation-lab/google-ads-transparency-center-scraper
- Users 231 / 82; no ratings; last updated 2026-09-11; success 99.6% of 4,557.
- Pricing: PPE `start` $0.005 per run + `item` **$0.000115 (FREE) / $0.0001 (BRONZE)** per advertiser or creative row.
- Target: `queries` (advertiser names, keywords or domains) or `advertiserIds`. Bounds: `maxItems` integer 1 to 5,000, **default 20** (global across queries); `searchMode` creatives | advertisers; `regionCriteriaId` default 2840 (US).
- Per-lead estimate: 0.005 + up to 5 x 0.000115 = **$0.0056**.
- Source: https://api.apify.com/v2/acts/automation-lab~google-ads-transparency-center-scraper

#### Candidate 3a-C: `clearpath/google-ads-transparency-scraper`

- URL: https://apify.com/clearpath/google-ads-transparency-scraper
- Users 38 / 21; no ratings; last updated 2026-10-06; success 99.6% of 739.
- Pricing: PPE `result-scraped` **$0.00099** flat per complete result (incomplete rows not charged).
- Target `searchQuery` (name, domain or `AR` id) with `queryType`; bounds `maxResults` default 100 (**0 = unlimited**), `advertiserMatchMode` all | best.
- Per-lead estimate: `maxResults` 5 = **$0.005**. Too small a user base to be a primary.
- Source: https://api.apify.com/v2/acts/clearpath~google-ads-transparency-scraper

### 3b. Google Local Services Ads (weak category: all candidates have under 100 users)

These actors return the Local Services listing for a category + city (up to about 20 advertisers), not a lookup by business name. The agent would query "plumber, Austin TX" and then name-match. A lead that is not in the top 20 is invisible.

#### Candidate 3b-A: `johnvc/google-local-services-api`

- URL: https://apify.com/johnvc/google-local-services-api
- Users 88 / 43; rating 5.00 (1); last updated 2026-10-04; success 100% of 560.
- Pricing: PPE `business_returned` **$0.004 (FREE) / $0.0039 (BRONZE)** per business; `location_resolved` **$0.015** one time per unique location (skipped when `dataCid` is given).
- Target: `query` or `queries` (service, for example "plumber") + `location` (US city) or `dataCid`. Bounds: `maxResultsPerQuery` min 1, **default null (all found, about 20)**; `jobType`.
- Output: name, Google Guaranteed or Screened badge, rating, reviews, phone, service area, hours, IDs.
- Per-lead estimate: 20 x 0.004 + 0.015 = **$0.095** (pin `maxResultsPerQuery` 20; share the call across all leads in the same city and category to cut cost).
- Source: https://api.apify.com/v2/acts/johnvc~google-local-services-api

#### Candidate 3b-B: `scrapersdelight/google-local-services-scraper`

- Users 20 / 14; rating 5.00 (1); last updated 2026-10-17; success 100% of 116. PPE `business-scraped` **$0.003** per advertiser; `maxItems` default 100 (0 = unlimited; pin 20); requires US residential proxy (`proxyConfiguration` default RESIDENTIAL). Per-lead estimate about $0.06. Source: https://api.apify.com/v2/acts/scrapersdelight~google-local-services-scraper

#### Candidate 3b-C: `piotrv1001/local-services-ads-google-verified-scraper`

- Users 64 / 20; no ratings; last updated 2026-09-16; success 99.4% of 483. PPE $0.004 per result + $0.00005 start; `maxResultsPerQuery` default 20 (min 1, max 200), `maxPages` default 3 (documented as unused). Also returns local pack cards, so up to 2 x N rows are billed. Source: https://api.apify.com/v2/acts/piotrv1001~local-services-ads-google-verified-scraper

Verdict: LSA is the only ads signal that needs a category+city search; treat it as optional. Note that `compass/crawler-google-places` itself is not an LSA source.

### 3c. Meta (Facebook) Ad Library

#### Candidate 3c-A (recommended): `apify/facebook-ads-scraper`

- URL: https://apify.com/apify/facebook-ads-scraper
- Users 44,768 / 8,965; rating 3.99 (59); last updated 2026-10-16; success 99.4% of 1.23M (30 days). Maintained by Apify.
- Pricing: PPE `apify-default-dataset-item` ("Ad") **$0.0058 (FREE) / $0.005 (BRONZE) / $0.0042 (SILVER)** per ad; `ecommerce-enrichment` add-on $0.0057 FREE per ad URL. `minimalMaxTotalChargeUsd` 0.0058. No start fee. Price effective 2026-07-14.
- Target: `startUrls` (required; Facebook Page URL, Meta Ad Library brand URL, or Ad Library search URL; for a small business, the Facebook page URL from the contact scraper's social links, or an Ad Library search URL built from the business name).
- Size/cost bounds: `resultsLimit` integer min 1, **default null = "as many results as possible"; pin it (5 to 10)**; `onlyTotal` boolean ("returns just the total number of ads for each page... a single dataset item per page"; best presence check, billed as one item = $0.0058); `activeStatus` (active | inactive); `onlyAdsNewerThan` / `onlyAdsOlderThan`; `sorting`.
- Block: `enrichWithEcommerceData` ($0.0057 per ad, FREE), and treat `isDetailsPerAd` and `includeAboutPage` as unbounded-effort add-ons (no separate event listed, but they open a detail view per ad; keep off).
- Output (README): `adArchiveID`, `pageId`, `startDateFormatted`, `endDateFormatted`, `isActive`, `snapshot.pageName`, `snapshot.pageProfileUri`, ad body, CTA, `snapshot.caption` (landing domain).
- Per-lead estimate: `onlyTotal` = **$0.0058**; or `resultsLimit` 5 = $0.029.
- Risks: free-text URL input (guard it with a pattern: `https://www.facebook.com/<page>` or `https://www.facebook.com/ads/library/?...`); rating 3.99 is the lowest of the picks; keyword-style Ad Library search URLs can match many unrelated advertisers, so name-match `pageName`.
- Source: https://api.apify.com/v2/acts/apify~facebook-ads-scraper

#### Candidate 3c-B: `automation-lab/facebook-ads-library`

- URL: https://apify.com/automation-lab/facebook-ads-library
- Users 3,349 / 1,244; rating 4.46 (3); last updated 2026-09-18; success 99.5% of 121,238.
- Pricing: PPE `start` **$0.005** per run + `ad-scraped` **$0.000575 (FREE) / $0.0005 (BRONZE)** per ad.
- Target: `searchQueries` (keywords), `pageUrls` (Facebook page URLs) or `adsLibraryUrls`; "Safety cap: up to 20 total search/page/Ads Library URLs". Bounds: `maxAds` min 1, max 500, **default 100** per query/URL (pin 5 to 10); `country` default US; `activeStatus` default all; `mediaType`.
- Output: `pageId`, `pageName`, `pageUrl`, `pageCategories`, `pageLikeCount`, `isActive`, `startDate`, `endDate`, `platforms`, `bodyText`, `title`, `ctaText`, `linkUrl` (README).
- Per-lead estimate: 0.005 + 10 x 0.000575 = **$0.0108**.
- Source: https://api.apify.com/v2/acts/automation-lab~facebook-ads-library

#### Candidate 3c-C: `jmlp/meta-ad-library-scraper`

- URL: https://apify.com/jmlp/meta-ad-library-scraper
- Users 928 / 582; rating 5.00 (11); last updated 2026-10-17; success 99.7% of 342,149.
- Pricing: PPE "Result" **$0.00015 (FREE) / $0.00014** per non-null result; **platform usage billed to caller**; default memory **4096 MB**, default proxy RESIDENTIAL.
- Target: `pageID` (numeric id or the advertiser name as the Ad Library shows it), `pageIDs`, `adLibraryUrl(s)`, `keyword(s)`. Bounds: `maxAds` default **null (unlimited)**, `maxPages` null, `maxConcurrency` 4, `proxyRotations` 3.
- Per-lead estimate: events $0.0015 for 10 ads plus compute and residential proxy, probably $0.01 to $0.05 total.
- Risks: unbounded defaults; many proxy and impersonation args (`impersonate`, `docId`, `proxySessionId`) that must stay off; platform usage makes cost less predictable.
- Source: https://api.apify.com/v2/acts/jmlp~meta-ad-library-scraper

### Bucket 3 recommendation

- Google Ads: **`scrapesage/google-ads-transparency-scraper`**, `resultType` = advertisers, `maxAdvertisersPerQuery` = 1, `queries` = [business domain], `region` = US: **$0.003**.
- Meta: **`apify/facebook-ads-scraper`**, `onlyTotal` = true, `startUrls` = [one Facebook page URL]: **$0.0058** (or `resultsLimit` 5 for $0.029 when you want to read the ads).
- Local Services Ads: skip by default; if wanted, `johnvc/google-local-services-api` at about $0.095 per category+city call, shareable across leads.
- Ads bucket total: **$0.009** typical (presence checks), about **$0.042** worst case (5 Google ads at $0.010 + 5 Meta ads at $0.029 + advertiser row $0.003).

---

## Bucket 4: Job listings

Reality check for small businesses: most do not post on LinkedIn; Indeed and ZipRecruiter are where plumbers and clinics hire. All four sources are keyword-and-location searches, so the agent must name-match the employer field on the results. Use company name + city, a small `limit`, and discard non-matching employers.

### Candidate 4A (recommended): `valig/indeed-jobs-scraper`

- URL: https://apify.com/valig/indeed-jobs-scraper
- Users 35,251 / 4,337; rating 4.73 (18); last updated 2026-09-26; success 100% of 485,430 (30 days).
- Pricing: PPE `apify-default-dataset-item` ("result") **$0.0001 (FREE) / $0.00009 (BRONZE) per job**; `apify-actor-start` **$0.001 (FREE) / $0.0009 (BRONZE)**. Default memory 128 MB.
- Target: `title` ("Job title, keywords, or company") + `location` (city, state, zip) + `country` (default `us`).
- Bounds: `limit` integer 1 to 1,000, **default 100 (pin 20)**; `datePosted` enum 1 | 3 | 7 | 14 days.
- Output (README): `key`, `url`, `title`, `employer.name`, `employer.companyPageUrl`, `employer.employeesCount`, `employer.revenue`, location, salary, benefits, `attributes`, description. Use `employer.name` to match the lead.
- Per-lead estimate: 0.001 + 20 x 0.0001 = **$0.003**.
- Risks: keyword search can return jobs from other employers mentioning the company; no explicit company filter in the schema; no cookies or proxies required from the user.
- Source: https://api.apify.com/v2/acts/valig~indeed-jobs-scraper

### Candidate 4B: `valig/linkedin-jobs-scraper`

- URL: https://apify.com/valig/linkedin-jobs-scraper
- Users 31,678 / 5,641; rating 4.68 (26); last updated 2026-09-26; success 98.5% of 397,057.
- Pricing: PPE `result` **$0.0004 (FREE) / $0.00036 (BRONZE)** per job; start **$0.001 / $0.0009**.
- Target: `companyName` (array, "Filter by company name"), `companyId`, `keywords`, `location`. Bounds: `limit` 1 to 1,000, **default 100 (pin 10)**; `datePosted` (r86400 | r604800 | r2592000); `titleInclude`/`titleExclude`.
- Block: `urlPath` (custom job search path), `urlParam` (arbitrary extra URL params sent to LinkedIn).
- Per-lead estimate: 0.001 + 10 x 0.0004 = **$0.005**.
- Risk: public (logged-out) LinkedIn pages only; small local businesses often have no LinkedIn jobs; output fields not inspected.
- Source: https://api.apify.com/v2/acts/valig~linkedin-jobs-scraper

### Candidate 4C: `curious_coder/linkedin-jobs-scraper`

- URL: https://apify.com/curious_coder/linkedin-jobs-scraper
- Users 173,229 / 16,356; rating 4.53 (142); last updated 2026-10-11; success 98.7% of 493,037.
- Pricing: PPE `result` **$0.002 (FREE) / $0.001 (BRONZE and above)**; start $0.00005; `minimalMaxTotalChargeUsd` 0.001.
- Target: `keywords` + `location`, `companyIds`, or `urls` (LinkedIn search URLs). Bounds: `limitPerSource` integer min 1, **default null (as many as LinkedIn returns)**, `splitByLocation` default false (block; multiplies searches by city), `scrapeCompany` default **true** (extra request per job).
- Block: `initialCookies`-style args are not in this schema, but `urls` accepts arbitrary LinkedIn URLs; allow `keywords`/`location`/`companyIds` only.
- Per-lead estimate: 10 x 0.002 + 0.00005 = **$0.020**.
- Source: https://api.apify.com/v2/acts/curious_coder~linkedin-jobs-scraper

### Other Indeed candidates (not picked)

- `borderline/indeed-scraper`: 27,590 / 2,567; 4.63 (37); updated 2026-10-06; PPE $0.005 per job; `maxRows` default null; `maxRowsPerUrl`; takes `query`, `location`, `urls`. 20 jobs = $0.10. https://api.apify.com/v2/acts/borderline~indeed-scraper
- `kaix/indeed-scraper`: 7,789 / 1,310; 4.27 (6); updated 2026-10-13; PPE $0.00005 per job + $0.00001 start + **platform usage billed to caller**; `maxItems` default 20 (0 = unlimited); `searchMode` basic | detailed | rich. https://api.apify.com/v2/acts/kaix~indeed-scraper

### Google Jobs

- `johnvc/Google-Jobs-Scraper`: https://apify.com/johnvc/google-jobs-scraper. Users 4,210 / 458; rating 4.55 (13); updated 2026-10-04; success 91.4% of 16,337. PPE `page_processed` **$0.09 (FREE) / $0.045 (BRONZE)** per page of about 10 jobs + $0.00001 per row + start $0.00005 (FREE). Target `query` + `location`; bounds `num_results` min 10, default 100; **`max_pagination` default 0 = unlimited (pin 1)**. One page = **$0.09** (FREE) / $0.045 (BRONZE). Google Jobs aggregates Indeed, LinkedIn, ZipRecruiter and company career pages, but costs 30x Indeed. https://api.apify.com/v2/acts/johnvc~Google-Jobs-Scraper
- `epctex/google-jobs-scraper`: avoid. Users 1,782 / 103; rating 2.91 (13); **30-day success 0.1% of 803 runs**; requires a user-supplied `proxy`; `maxItems` default unlimited; `extendOutputFunction`/`customMapFunction` run arbitrary code. https://api.apify.com/v2/acts/epctex~google-jobs-scraper

### ZipRecruiter

- `fatihtahta/ziprecruiter-scraper`: https://apify.com/fatihtahta/ziprecruiter-scraper. Users 159 / 36; no ratings; updated 2026-09-25; success 100% of 1,347. PPE `outputrecord` **$0.001** per result; **`minimalMaxTotalChargeUsd` 1**. Target `queries` (array) + `location` + `radius`; **`limit` default 50,000 per keyword (pin 20)**. 20 results = **$0.020**. https://api.apify.com/v2/acts/fatihtahta~ziprecruiter-scraper
- `blackfalcondata/ziprecruiter-job-scraper`: Users 89 / 21; updated 2026-10-02; PPE $0.00099 per result + $0.005 start; but its own schema says "US requires additional account configuration — use GB, IE, IN, DE, FR, or NZ for self-service access", and the input has webhook, Telegram, Slack, Discord and WhatsApp-token fields that send data out (block all). Not suitable for US leads. https://api.apify.com/v2/acts/blackfalcondata~ziprecruiter-job-scraper

### Bucket 4 recommendation

**`valig/indeed-jobs-scraper`** (`title` = business name, `location` = city + state, `limit` = 20, `datePosted` = `14`). **$0.003** per lead. Optional second check with `valig/linkedin-jobs-scraper` (`companyName` filter, `limit` 10) for **$0.005**, giving $0.008 for both. ZipRecruiter and Google Jobs have weaker or costlier options.

---

## Bucket 5: Website features

Important constraint found in the tech-detector READMEs: the HTTP-only detectors fingerprint the initial HTML. `tugelbay/website-tech-stack-detector` says "Technologies loaded entirely via JavaScript (e.g., some chat widgets that load asynchronously) may not be detected. For those, you'd need a browser-based analysis tool", and "It sends a single HTTP GET request to each URL". Booking widgets (Calendly, Acuity, Housecall Pro, Jobber) and chat widgets are often injected by a script tag that does appear in the HTML, but async-injected ones can be missed. A crawler that returns HTML plus rendered text, inspected by the agent, is the more general approach.

### Candidate 5A (recommended): `apify/website-content-crawler`

- URL: https://apify.com/apify/website-content-crawler
- Users 169,666 / 14,351; rating 4.62 (235); last updated 2026-10-15; success 96.3% of 3.20M runs (30 days). Maintained by Apify.
- Pricing: **pay per usage** (no `pricingInfos`; billed as platform compute). Page says compute is the main driver; "$0.2 per 1,000 web pages with raw HTTP crawler", "$0.5 - $5 per 1,000 web pages with a headless browser"; compute units $0.2 (Free/Starter) to $0.13 (Business) per CU. Default run memory is **8,192 MB** (`defaultRunOptions`), which dominates the cost for small crawls.
- Target: `startUrls` (required, array of URL objects) and `proxyConfiguration` (marked required in the schema, default `{"useApifyProxy": true}`).
- Size/cost bounds (exact names and defaults): `maxCrawlPages` **default 9,999,999 (effectively unlimited)**; `maxCrawlDepth` **default 20**; `maxResults` **default 9,999,999**; `crawlerType` default **`playwright:firefox`** (use `cheerio`, the raw HTTP client, for cost); `maxConcurrency` default 200; `requestTimeoutSecs` 60; `maxRequestRetries` 3; `maxSessionRotations` 10; `useSitemaps` false; `respectRobotsTxtFile` false.
- To keep widget markup: the defaults strip it. `removeElementsCssSelector` default removes `nav, footer, script, style, noscript, svg, ...` (booking links and chat script tags live there), and `htmlTransformer` default `readableText`. For feature detection pin `removeElementsCssSelector` to an empty string, `htmlTransformer` to `none`, and `saveHtml` true (flagged deprecated in the schema; may still work) or `saveHtmlAsFile` true (HTML goes to the key-value store, link in `htmlUrl`; readable with the MCP's `get-key-value-store-record`).
- Add-ons/args to block: `summarize` (AI add-on, about $0.002 to $0.007 per page, free plan pays 10x the model cost, per the actor page), `saveFiles`/`saveContentTypes` (downloads files), `saveScreenshots`, `initialCookies`, `customHttpHeaders`, `signHttpRequests`, `pageFunction` (arbitrary JS), `clickElementsCssSelector`, `includeUrlGlobs` / `excludeUrlGlobs` (can widen crawl scope beyond the site), `useLlmsTxt`.
- Output: `url`, `crawl.depth`, `metadata.title/description/languageCode/openGraph`, `text`, `markdown`, plus `html`/`htmlUrl` when enabled.
- Per-lead estimate: `crawlerType` cheerio, `maxCrawlPages` 5, `maxCrawlDepth` 1, `maxResults` 5. Compute: if the run lasts about 30 to 60 s at 8 GB that is 0.067 to 0.133 CU x $0.2 to $0.25 = **$0.013 to $0.033**, plus negligible per-page costs ($0.2 per 1,000 pages x 5 = $0.001). Budget **$0.02 typical, $0.06 ceiling**. If the MCP can lower run memory to 1 GB, expect about $0.005. This estimate is derived from the page's per-1,000-page figures and run time assumptions; it was not measured.
- Risks: unbounded defaults on three args; cost is usage-based, so there is no per-event ceiling (set `maxTotalChargeUsd` on the run as a backstop, which the platform enforces for pay-per-usage actors); browser crawler types and `initialCookies`/`customHttpHeaders` must be blocked.
- Source: https://api.apify.com/v2/acts/apify~website-content-crawler ; pricing text https://apify.com/apify/website-content-crawler

### Candidate 5B: `rl1987/wappalyzer-tech-lookup` (Wappalyzer-style technology detection)

- URL: https://apify.com/rl1987/wappalyzer-tech-lookup
- Users 63 / 14; no ratings; last updated 2026-10-18; success 100% of 1,207 runs.
- Pricing: PPE `output-row` **$0.0005 per technology row** (one row per detected technology, with category, version, traffic rank); **platform usage billed to caller** (residential proxy default).
- Target: `urls` (array of URLs or bare domains); default empty "scans nothing and costs nothing". No size arg except the URL list; `maxConcurrency` 1 to 25.
- It queries Wappalyzer's lookup API ("powered by the Wappalyzer API", "No Wappalyzer API key of your own is required"), so it reflects Wappalyzer's own crawl data, which may be missing or stale for long-tail small-business sites; it is not a live fingerprint of the page.
- Per-lead estimate: 10 to 20 technology rows x $0.0005 = **$0.005 to $0.01** plus proxy and compute (small).
- Risks: very low usage; third-party API dependency; row count per site is not boundable by input (cap with `maxTotalChargeUsd`).
- Source: https://api.apify.com/v2/acts/rl1987~wappalyzer-tech-lookup

### Candidate 5C: `automation-lab/tech-stack-detector`

- URL: https://apify.com/automation-lab/tech-stack-detector
- Users 384 / 25; no ratings; last updated 2026-09-02; success 99.7% of 6,554.
- Pricing now: PPE `start` **$0.035** per run + `url-analyzed` **$0.0023 (FREE) / $0.002 (BRONZE)** per site. **Scheduled change on 2026-10-21**: a new PPE model charges `output-row` $0.0012 (FREE) / $0.00075 (BRONZE) per technology row ("$0.50 per 1,000 rows" in the event text), which makes cost depend on how many technologies the site has.
- Target: `urls` only (no size args at all).
- Per-lead estimate today: 0.035 + 0.0023 = **$0.037**; after 2026-10-21 about $0.012 to $0.024 for 10 to 20 rows.
- Source: https://api.apify.com/v2/acts/automation-lab~tech-stack-detector

Other tech detectors seen (all under 120 total users): `tugelbay/website-tech-stack-detector` (111 / 6; $0.003 per site + $0.005 start; HTTP GET only, 33 KB README; https://api.apify.com/v2/acts/tugelbay~website-tech-stack-detector), `benthepythondev/tech-stack-detector` (108 / 8; $0.0025 per site FREE; `maxUrls` default 1; https://api.apify.com/v2/acts/benthepythondev~tech-stack-detector). `seibs.co/home-services-lead-finder` detects field-service tools (ServiceTitan, Housecall Pro, Jobber, FieldEdge) but is a Maps-style lead finder at $0.004 per record + $0.007 per detected signal, not a per-site lookup (https://api.apify.com/v2/acts/seibs.co~home-services-lead-finder).

Cheap page crawlers considered: `apify/cheerio-scraper` (25,620 / 1,660; 4.75 (38); updated 2026-09-03; pay per usage; requires a `pageFunction` JS string, `maxPagesPerCrawl` default 0 = unlimited, `maxCrawlingDepth` default 0 = unlimited, `initialCookies`, `prepareRequestFunction`; the code argument is a risk even if pinned; https://api.apify.com/v2/acts/apify~cheerio-scraper) and `6sigmag/fast-website-content-crawler` (4,662 / 138; 4.9 (7); last updated 2026-02-12; $0.0015 start + $0.003 per page; only `startUrls` as input, so crawl depth is not documented or boundable; https://api.apify.com/v2/acts/6sigmag~fast-website-content-crawler).

### Bucket 5 recommendation

**`apify/website-content-crawler`** with `crawlerType` = cheerio, `maxCrawlPages` = 5, `maxCrawlDepth` = 1, `maxResults` = 5, `removeElementsCssSelector` = "", `htmlTransformer` = none, `saveHtml` (or `saveHtmlAsFile`) = true, all add-ons and cookie/header/pageFunction args blocked. About **$0.02** per lead (ceiling $0.06); the agent greps the HTML for `calendly`, `acuityscheduling`, `housecallpro`, `servicetitan`, `jobber`, `podium`, `intercom`, `tawk`, `livechat`, `<form`, "portal", "book online". Optional cheap add-on for named-technology evidence: `rl1987/wappalyzer-tech-lookup` (about $0.005 to $0.01, low usage).

---

## Picks and total cost per lead (one run of each pick)

| Bucket | Pick | Key pinned args | Price basis | Typical | Worst case |
|---|---|---|---|---|---|
| 1 Maps reviews | compass/Google-Maps-Reviews-Scraper | placeIds [1], maxReviews 50, newest, 12 months | $0.0006/review + $0.00005 start | $0.030 | $0.048 (with 3 keyword-filter follow-ups) |
| 2 Search | apify/google-search-scraper | queries 3 lines, maxPagesPerQuery 1 | $0.0045/page + $0.00005 start | $0.014 | $0.014 |
| 3 Ads | scrapesage ATC (advertisers) + apify/facebook-ads-scraper (onlyTotal) | maxAdvertisersPerQuery 1, resultsLimit 5 if reading ads | $0.003 + $0.0058 | $0.009 | $0.042 |
| 4 Jobs | valig/indeed-jobs-scraper | limit 20, datePosted 14 | $0.0001/job + $0.001 start | $0.003 | $0.008 (adds valig LinkedIn, limit 10) |
| 5 Website | apify/website-content-crawler | cheerio, maxCrawlPages 5, maxCrawlDepth 1 | pay per usage, 8 GB default memory | $0.02 | $0.06 |
| **Total** | | | FREE-plan prices | **about $0.076** | **about $0.17** |

Arithmetic: typical 0.030 + 0.014 + 0.009 + 0.003 + 0.020 = 0.076; worst 0.048 + 0.014 + 0.042 + 0.008 + 0.060 = 0.172. On BRONZE prices the reviews, search and Meta lines drop (reviews $0.0226, search $0.0076, Meta $0.005), putting the typical total near $0.06.

That is roughly 4% of the $2.00 per-lead budget for a full run of all five, plus the existing Maps ($0.004 per place) and contact scraper ($0.002 per page) calls. Even with the optional Local Services Ads call ($0.095) the total stays under $0.30.

## Top risks and guard notes

1. **Unbounded defaults to pin**: compass reviews `maxReviews` 10,000,000; apify/facebook-ads-scraper `resultsLimit` null; scrapesage `maxAdvertisersPerQuery` 5 and `maxAdsPerSearch` 100; Website Content Crawler `maxCrawlPages` and `maxResults` 9,999,999 and `maxCrawlDepth` 20, plus default `crawlerType` `playwright:firefox`; fatihtahta ZipRecruiter `limit` 50,000; Google Jobs `max_pagination` 0; apify/google-search-scraper `maxPagesPerQuery` null.
2. **List-or-newline args multiply cost**: `queries` (apify/google-search-scraper, scraperlink `keyword`) is one string with newlines as separators; guard line count or reject newlines, in addition to array-length caps.
3. **Paid add-ons to keep out of every allowlist**: apify/google-search-scraper (`aiOverview`, `aiModeSearch`, `geminiSearch`, `perplexitySearch`, `chatGptSearch`, `copilotSearch`, `maximumLeadsEnrichmentRecords`, `verifyLeadsEnrichmentEmails`, `linkProspecting`, `websiteContentScraper`, `focusOnPaidAds`), compass Maps (contacts, leads, social, images, competitor analysis, extra details), scrapesage (`includeDetails`), apify/facebook-ads-scraper (`enrichWithEcommerceData`, `isDetailsPerAd`, `includeAboutPage`), Website Content Crawler (`summarize`, `saveFiles`, `saveScreenshots`).
4. **Arbitrary code or request shaping**: Website Content Crawler `pageFunction`, `initialCookies`, `customHttpHeaders`, `signHttpRequests`; cheerio-scraper `pageFunction`/`prepareRequestFunction`; epctex `extendOutputFunction`/`customMapFunction`; valig LinkedIn `urlPath`/`urlParam`; `startUrls` object arrays on any actor (same issue the guard already handles for the contact scraper). Allow only `{ "url": ... }` objects or plain string arrays.
5. **Data-egress args**: blackfalcondata ZipRecruiter (webhook, Telegram, Slack, Discord, WhatsApp tokens), several newer actors with `outputConnector`/`deliverTarget` (apidojo SERP). Keep off; none of the picks have them.
6. **Usage-billed actors**: kaix reviews and indeed, jmlp Meta, lofomachines SERP and rl1987 bill compute and proxy to the caller on top of events; none of the picks use them except as noted alternatives.
7. **Thin evidence for LSA and tech detection**: every Local Services Ads actor has under 100 users and works by category + city (miss if the lead is not in the top 20); Wappalyzer-style detectors have under 400 users, miss async-loaded widgets, and the Wappalyzer lookup depends on a third-party dataset.
8. **Name-match noise**: Indeed/ZipRecruiter/Meta/Google Ads Transparency are keyword or brand lookups, so the agent must verify employer or advertiser name and city before treating a hit as evidence.
9. **Privacy**: Maps review actors return reviewer names by default (`personalData` true in compass reviews); set false.
10. **Price drift**: several prices changed in the last 90 days (apify/google-search-scraper 2026-10-07, scrapesage record dated 2026-11-01, automation-lab tech detector change on 2026-10-21, kaix reviews 2026-07-15). Re-read `pricingInfos` before shipping and have the agent log `cost_usd` as an estimate, as `usage.md` already does.
