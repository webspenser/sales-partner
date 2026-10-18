# Research actors probe (Task 1, 8.1)

Probed on 2026-10-18, with the operator present.
- **Connector.** The operator re-added the claude.ai Apify connector with a restricted URL listing all six actors.
- **Tool prefix.** Tools now appear as `mcp__claude_ai_Apify_Actors__<tool>`. The server segment, lowercased, is `claude_ai_apify_actors`, and the existing `server_match: apify` still covers it, being a substring.
- **Where it ran.** Schemas were captured, and the live calls run, in fresh headless sessions, because the controller session only saw the old connector. Raw outputs are summarized below; reviewer data never left Apify.
- **Target.** Big Brothers Plumbing Inc, Alameda, CA (place ID `ChIJkyhXi8iHj4ARLP5o2YRo-iY`, `bigbrothersplumbinginc.com`).

The connector URL the operator uses (and that `usage.md`'s Setup must print):

```
https://mcp.apify.com?tools=compass/crawler-google-places,vdrmota/contact-info-scraper,compass/Google-Maps-Reviews-Scraper,scrapesage/google-ads-transparency-scraper,apify/facebook-ads-scraper,valig/indeed-jobs-scraper,apify/website-content-crawler
```

All four picks pass, and no runner-up is needed. The survey (`2026-10-18-apify-research-buckets.md`) has the prices.

**Cost is not returned.** As in 7.2, runs report only `stats` (`runTimeSecs`, `computeUnits`, `memMaxBytes`). There is no USD field, so the agent records an estimate for each call.

## Live calls

| # | Tool | Arguments (summary) | Run | Result |
|---|---|---|---|---|
| 1 | `compass--Google-Maps-Reviews-Scraper` | 1 place ID, `maxReviews` 5, newest, `personalData: false` | SUCCEEDED, 6.0 s, 0.0017 CU | 5 items |
| 2 | `scrapesage--google-ads-transparency-scraper` | `queries` = the domain, `resultType: advertisers`, 1 advertiser, 5 ads, `apifyProxyGroups: ["DATACENTER"]` | rejected before start | `You currently do not have access to proxy groups: DATACENTER`; not billed |
| 2b | same, with no `proxyConfiguration` (actor default) | — | SUCCEEDED, 0.0016 CU | 0 items (no advertiser found); "Nothing was billed" |
| 3 | `apify--facebook-ads-scraper` | a keyword Ad Library URL, `onlyTotal`, `resultsLimit` 5 | SUCCEEDED, 6.0 s, 0.0017 CU | `totalCount: 8296` from a loose keyword match (see finding) |
| 4 | `valig--indeed-jobs-scraper` | `title` = company name, Alameda CA, `limit` 5 | SUCCEEDED, 2.4 s, 0.0002 CU | 0 items |
| 5 | `apify--website-content-crawler` | `cheerio`, 2 pages, depth 1, `htmlTransformer: none`, remove only script/style/noscript/svg | SUCCEEDED, 7.3 s, 0.0081 CU, 0.8 GB memory | 2 items |

**Reviews**
- With `personalData: false`, every item's `name`, `reviewerId`, `reviewerUrl`, `reviewerPhotoUrl` and `reviewUrl` were null. The reviewer data is suppressed at the source.
- The useful fields are `text`, `publishedAtDate`, `stars` (`rating` is null), `responseFromOwnerText` / `responseFromOwnerDate`, `placeId` and `url` (the place).

**Google Ads**
- The free plan has no datacenter proxy, so the actor's default (residential) must be allowed. That means `proxyConfiguration` is left out.
- In advertisers mode with one query, the run is small, and an empty result wasn't billed.

**Facebook**
- **Finding:** a keyword Ad Library search counts every advertiser matching the words, so 8,296 is not this business. A per-business total needs the business's own Facebook page URL (from the contact scraper's social links or the research).
- Rule: run the Facebook count only with the lead's Facebook page URL. With no page URL, skip it and record no Facebook finding.

**Indeed**
- A company-name search for a small business can return nothing, and that is a valid "no open listings" result.
- The inline tool response is large (about 56 KB, because of the schema), so always read the items with a `fields` projection.

**Website**
- With `htmlTransformer: none`, the markdown keeps nav and footer links ("Request Service" → `/contact-us`, "Maintenance Agreements", a phone CTA). Feature words can then be checked.
- Cheerio runs no JavaScript, so a script-injected chat widget is invisible. This confirms the rule never to claim "lacks chat".
- Finding: the apex domain and `www` came back as two identical pages, which used up the 2-page budget. Start at the URL the Maps listing gives, and keep `max_site_pages` at 5 so the contact and booking pages are reached.
- No memory argument is exposed. 0.8 GB for 2 pages at 0.008 CU is cheap enough.

## Values for Tasks 2–5

Tool names are exact, case included. `only_keys` lists everything allowed at `$`; any other key blocks.

| Operation | Tool | only_keys (`$`) | Nested only_keys | Pins (`recipients`) | Counted lists (`limits`, required) |
|---|---|---|---|---|---|
| `find_reviews(place)` | `compass--Google-Maps-Reviews-Scraper` | `placeIds, maxReviews, reviewsSort, reviewsStartDate, reviewsFilterString, reviewsOrigin, language, personalData, waitSecs` | — (`startUrls` not allowed) | `maxReviews` → `max_reviews` | `placeIds` ≤ `max_review_places` |
| `find_ads(business)` (Google) | `scrapesage--google-ads-transparency-scraper` | `queries, resultType, maxAdvertisersPerQuery, maxAdsPerSearch, region, waitSecs` | — (no `proxyConfiguration`, `domains`, `startUrls`, `urlsFromFile`) | `maxAdsPerSearch` → `max_ads`; `maxAdvertisersPerQuery` → `max_ad_advertisers`; `resultType` → `ads_result_type` | `queries` ≤ `max_ad_queries` |
| `find_ads(business)` (Facebook) | `apify--facebook-ads-scraper` | `startUrls, onlyTotal, resultsLimit, activeStatus, onlyAdsNewerThan, waitSecs` | `startUrls[]`: `url` | `resultsLimit` → `max_ads` | `startUrls` ≤ `max_ad_queries` |
| `find_jobs(company, location)` | `valig--indeed-jobs-scraper` | `title, location, country, limit, datePosted, waitSecs` | — | `limit` → `max_jobs` | — |
| `read_site(url)` | `apify--website-content-crawler` | `startUrls, crawlerType, maxCrawlPages, maxResults, maxCrawlDepth, maxConcurrency, htmlTransformer, removeElementsCssSelector, saveMarkdown, proxyConfiguration, waitSecs` | `startUrls[]`: `url`; `proxyConfiguration`: `useApifyProxy` | `crawlerType` → `site_crawler_type`; `maxCrawlPages` → `max_site_pages`; `maxResults` → `max_site_pages`; `maxCrawlDepth` → `max_site_depth` | `startUrls` ≤ `max_site_urls` |

Blocked by these allowlists, and worth naming in tests:
- **Reviews:** `startUrls`.
- **Google Ads:** `includeDetails` ($), `onlyNewAds` and `monitorStoreName` (they write state to the account), `includeRawData`, `proxyConfiguration`, `startUrls`, `urlsFromFile`, `domains`.
- **Facebook:** `isDetailsPerAd`, `includeAboutPage`, `enrichWithEcommerceData` ($), and `method`, `headers`, `payload` and `userData` on start URLs.
- **Crawler:**
  - code and credentials: `customHttpHeaders`, `pageFunction` and `initialCookies` (the tool refuses these too);
  - paid or expensive options: `summarize` ($), `saveScreenshots`, `saveContentTypes`, `saveFiles`;
  - options that widen the crawl: `includeUrlGlobs`, `useSitemaps`, `useLlmsTxt`;
  - `proxyConfiguration.apifyProxyGroups` and `proxyUrls`, and `method`, `headers`, `payload` and `userData` on start URLs.

New bindings and defaults, beyond the spec's five. Two of them, `ads_result_type` and `site_crawler_type`, are text pins:

| Binding | Default |
|---|---|
| `max_reviews` | 50 |
| `max_ads` | 5 |
| `max_jobs` | 20 |
| `max_site_pages` | 5 |
| `max_site_depth` | 1 |
| `max_review_places` | 1 |
| `max_ad_queries` | 1 |
| `max_ad_advertisers` | 1 |
| `ads_result_type` | `advertisers` |
| `site_crawler_type` | `cheerio` |
| `max_site_urls` | 1 |

**Instructions the guard can't pin** (true/false values), which go into `usage.md`:
- reviews always `personalData: false`;
- Facebook always `onlyTotal: true`;
- crawler `saveMarkdown: true`, `htmlTransformer: "none"`, `removeElementsCssSelector: "script, style, noscript, svg"`.

**Dataset reads** (`get-dataset-items`, `limit` ≤ `max_dataset_items`, always with `fields`):
- **reviews:** `text,publishedAtDate,stars,responseFromOwnerText,responseFromOwnerDate,placeId,url`. Never `name,reviewerId,reviewerUrl,reviewerPhotoUrl`.
- **Google Ads:** `advertiserId,advertiserName,adCount` and the like, as returned (empty here).
- **Facebook:** `inputUrl,totalCount,isResultComplete`.
- **jobs:** `title,datePublished,employer.name,location.city,jobUrl`.
- **site:** `url,markdown,metadata.title`.

**Cost estimates per call** (worst case at the pinned sizes, deliberately high, as in 7.2):

| Call | Estimate |
|---|---|
| reviews | $0.05 |
| Google Ads | $0.01 |
| Facebook count | $0.01 |
| jobs | $0.005 |
| site | $0.03 |

Together with the contact scraper's $0.06 and the Maps listing, a full lead is about $0.17, well under the $0.50 cap.
