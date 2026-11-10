# Phase B actors probe

Date: 2026-11-09. Server `claude_ai_Apify_Connector`. For the open
scraping guard, Phase B (spec
`docs/superpowers/specs/2026-11-09-open-scraping-guard-design.md`,
Sources and Open-web research). One call per tool at the smallest size,
against public businesses (Franklin Barbecue and a BBB-listed plumber in
Austin, TX) and a well-known public LinkedIn profile, so no lead's data
was fetched. The installed guard did not run in this development session;
every call went straight to Apify. Prices are from each actor's Store page
(fetched the same day); no run reported a dollar amount.

## Open web

### `apify--web-search` (apify/web-search)

Not an actor input. The tool takes an HTTP-shaped call:
`{"method": "GET"|"POST", "path": "/", "query": {...}, "body": {...}}`.
Search options sit under `query` (GET) or `body` (POST): `query`
(required), `provider` (`google`, default, or `duckduckgo`),
`maxResults`, `countryCode`, `languageCode`, `location`, `dateFrom`,
`dateTo` (YYYY-MM-DD), `allowedDomains`, `blockedDomains`.

Call: `GET / query={"query":"Franklin Barbecue Austin TX","maxResults":5,"countryCode":"US"}`.
HTTP 200, 3 KB, no run started ("multi-tenant ... start no run in your
account"). Result items: `position`, `url`, `domain`, `title`, `snippet`,
`displayedUrl`, `siteName`, `siteLinks[]`, plus a publication date and
publisher when the engine gives one. The lead's own site, its Yelp page,
Instagram and Wikipedia came back in the top 5.

Price: "from $1.00 / 1,000 google search results", one event per search;
`maxResults` does not change it.

### `apify--web-fetch` (apify/web-fetch)

Same HTTP shape. Options under `query`: `url` (required), `formats`
(`markdown`, `html`, `text`, `links`, `raw`), `unwrap`, `headers` (a JSON
string of extra request headers), `wait` (1 to 60000 ms; renders in a
browser).

Call: `GET / query={"url":"https://franklinbbq.com/","formats":["markdown"]}`.
HTTP 200, 12 KB: `url`, `fetch` (`loadedUrl`, `httpStatusCode`,
`contentType`), `metadata` (`title`, `description`, `canonicalUrl`,
`jsonLd[]` with the business's email, phone and `sameAs` social links,
`openGraph[]`, response `headers`), `markdown`. Redirects are not
followed.

Price: "from $1.00 / 1,000 fetches", one `fetch` event per successful
request.

Guard consequences: the URL is at `query.url` (and `body.url` on POST);
request headers at `query.headers`. Pin `method` to `GET` and `path` to
`/`, refuse `body`, so every value the guard checks sits under `query`.

### `apify--google-search-scraper` (apify/google-search-scraper)

Call: `queries:"Franklin Barbecue Austin TX"`, `maxPagesPerQuery:1`,
`saveHtmlToKeyValueStore:false`, `countryCode:"us"`. SUCCEEDED in 6.9 s,
1 item (one SERP page) with `organicResults[]` (`title`, `url`,
`description`, `date`, `lastUpdated`, `position`, rating fields).
`queries` is one string holding one query per line, so a single call can
carry many queries, which the guard cannot count. Thirteen paid add-ons
(AI Mode, AI Overview, ChatGPT, Copilot, Gemini, Perplexity, link
prospecting, leads enrichment and its departments and email
verification, website content, paid ads, HTML saving). Price "from
$1.80 / 1,000 scraped search result pages".

## Directories

### `scrapesage--bbb-scraper` (scrapesage/bbb-scraper)

First call (`searchTerms:["Franklin Barbecue"]`, `locations:["Austin, TX"]`,
`maxResults:1`, `includeDetails:true`, reviews and enrichment off):
SUCCEEDED, 0 items, "BBB returned no businesses ... No results were
billed". A business absent from BBB is a valid "no listing" result.

Second call (`searchTerms:["Plumbers"]`, same switches): 1 item with the
full profile: `businessName`, `bbbRating` (`A+`), `accredited`,
`yearsInBusiness`, `businessStarted`, `complaintCount`,
`complaintsLast12Months`, `complaintsLast3Years`, `customerReviewCount`,
`averageStarRating`, `email` (a personal Yahoo address on this one),
`website`, `phone`, `profileClaimed`, `principalContacts[]`
(`name`, `title`: "Owner/Operator"), `profileUrl`, `licenses[]`.

Inputs: `searchTerms[]`, `locations[]` (each term is combined with each
location), `maxResults` (default 100; 0 means no limit),
`maxResultsPerSearch`, `includeDetails` (one extra request per
business; needed for principals, email and years), `includeReviews`,
`maxReviewsPerBusiness`, `enrichContacts` (visits the business's
website), `accreditedOnly`, `minRating`, `monitorMode`, `monitorKey`,
`maxConcurrency`, `startUrls[]` (request objects with headers, method,
payload, userData), `urlsFromFile` (a URL list or a link to a file or
Google Sheet), `proxyConfiguration` (default residential US; the call
works without it).

Price: "from $4.00 / 1,000 business leads"; "Full business profile",
"Customer review" and "Website contact enrichment" events are named
without prices.

### `delicious_zebu--yellowpages-usa-business-lead-scraper`

Call: `searchKeyword:["barbecue restaurants"]`, `location:"Austin, TX"`,
`maxPages:1`. SUCCEEDED in 25 s, 30 items (one page; the size key is
pages only, 30 items each, with no per-item cap). Items: `title`,
`is_ad`, `is_claimed` (empty on both items read), `star_rating`,
`rating_count`, `phone`, `website`, `email` (Franklin's listing gives a
Gmail address), `address`, `source_url`, `categories[]`,
`opening_hours`, `regular_hours.*`, `more_info.*` (General Info, AKA,
Other Emails, Social Links, BBB Rating, Ownership and others),
`reviews[]` (`author`, `date`, `text`, `rating`).

Inputs: `searchKeyword[]`, `location` (default "New York, NY" when
omitted), `maxPages` (default 2), `sort`, `urls[]` (any YellowPages URL,
query included).

Price: "from $2.00 / 1,000 results" (the spec's $0.003/result was a
higher earlier figure).

## Reviews

### `web_wanderer--yelp-reviews-scraper`

Call: `biz_urls:["https://www.yelp.com/biz/franklin-barbecue-austin"]`,
`reviews_limit:2`, `reviews_sort:"newest"`, `include_personal_data:true`.
SUCCEEDED in 19 s, 2 items. Item: `name`, `businessRating`,
`totalReviews`, `rating`, `reviewDate`, `text`, `reviewUrl`,
`publicReply`, `language`, `author.name` ("Lily C.": first name and last
initial), and with personal data also `author.profile_photo`,
`author.friend_count`, `author.review_count`, `author.photo_count`,
elite flags; `photos[]`, `videos[]`.

The Yelp page URL came back as result 2 of the web search above, so
`apify_web` can supply it.

Inputs: `biz_urls[]`, `biz_ids[]`, `search_urls[]`, `search_location`,
`search_limit`, `search_sort`, `search_features[]`, `search_price[]`,
`domain` (regional Yelp hosts), `reviews_limit` (0 or blank means all),
`reviews_sort`, `reviews_rating[]`, `reviews_language` (`all` downloads
every language), `reviews_keywords[]`, `reviews_translate`, `date_from`,
`include_personal_data`.

Price: "$0.30 / 1,000 reviews".

## Jobs

### `valig--linkedin-jobs-scraper`

Call: `keywords:"barbecue"`, `location:"Austin, TX"`, `limit:1`.
SUCCEEDED in 5 s, 1 item: `title`, `companyName`, `companyUrl`,
`location`, `postedDate` (2023-03-28: a keyword search returns stale
posts), `postedTimeAgo`, `applicationsCount`, `url`, `recruiterName`,
`description`. Use `companyName` and `datePosted` (`r2592000` = 30
days, `r604800`, `r86400`) to get a lead's own current posts.

Inputs: `keywords`, `location`, `companyName[]`, `companyId[]`,
`datePosted`, `limit` (default 100), `easyApply`, `under10Applicants`,
`titleInclude[]`, `titleExclude[]`, `skipJobId[]`, `urlParam[]`
(arbitrary search URL parameters), `urlPath` (a custom path under
`/jobs/`).

Price: "from $0.28 / 1,000 results" (title says $0.4/1K).

## LinkedIn profiles

### `harvestapi--linkedin-profile-scraper`

Call: `urls:["https://www.linkedin.com/in/williamhgates"]`,
`profileScraperMode:"Profile details no email ($4 per 1k)"`. SUCCEEDED in
7.8 s, 1 item, 160 fields: `firstName`, `lastName`, `headline`, `about`,
`linkedinUrl`, `location.linkedinText`, `currentPosition[]`
(`companyName`, `position`, `companyLinkedinUrl`), `experience[]`,
`websites[]`, `emails[]` (empty in this mode), photos and more.

`profileScraperMode` enum, prices inside the strings:
`"Profile details no email ($4 per 1k)"`,
`"Profile details + email search ($10 per 1k)"`. If the vendor changes a
price, the string changes and a pinned value is blocked (drift: the
source is skipped and reported). Email search is not charged when a
profile is too incomplete for it.

Other inputs: `queries[]`, `publicIdentifiers[]`, `profileIds[]`.

### `harvestapi--linkedin-profile-search`

Call: `searchQuery:"Owner"`,
`currentCompanies:["https://www.linkedin.com/company/microsoft"]`,
`maxItems:1`, `takePages:1`, `profileScraperMode:"Short"`. SUCCEEDED in
7.5 s, 1 item: `firstName`, `lastName`, `linkedinUrl`, `summary`,
`location.linkedinText`, `currentPositions[]` (`title`, `companyName`,
`companyLinkedinUrl`, `current`), `_meta.pagination`.

Inputs include filters (`currentCompanies[]` as LinkedIn company URLs,
`currentJobTitles[]`, `seniorityLevelIds[]` with `310` CXO and `320`
Owner / Partner, `locations[]` and others), `maxItems`, `takePages`,
`startPage`, `profileScraperMode` (`Short`, `Full`,
`Full + email search`), `searchCoverage`, `autoQuerySegmentation*`, and
MongoDB inputs: `mongoDbConnectionString`, `mongoDbDatabaseName`,
`profileDeduplicationMode`, `postFilteringMongoDbQuery`,
`postFilteringMongoDbAggregation`. A connection string sends the
scraped profiles to any database the caller names, so it must be
refused.

Price (README): Short "$0.10 per search page" with no per-profile
charge; Full adds $0.004 per profile; Full + email search adds $0.01 per
profile.

## Ads

### `scrapesage--facebook-ad-library-scraper` (backup)

Call: `searchTerms:["Franklin Barbecue"]`, `maxResults:1`, `country:"US"`.
SUCCEEDED in 4.6 s, 1 item, from an unrelated advertiser ("FlickReels
3"): a keyword search matches any ad's words, the same failure the
primary's keyword probe showed. Use `pageUrls[]` (a page URL, name or id)
only. Item fields: `pageName`, `pageId`, `isActive`, `status`,
`startDate`, `endDate`, `publisherPlatforms[]`, `adLibraryUrl`,
`ctaText`, `linkUrl`, `bodyText`, `spend`, `impressions`.

Inputs: `searchTerms[]`, `pageUrls[]`, `startUrls[]` (request objects),
`urlsFromFile`, `country`, `adActiveStatus`, `adType`, `mediaType`,
`languages[]`, `publisherPlatforms[]`, `dateFrom`, `dateTo`,
`maxResults` (default 100; 0 means unlimited), `monitoringMode`,
`monitorId`, `pageDelaySeconds`, `proxyConfiguration` (required
residential, defaulted when left out).

Price: `actor-start` $0.005 per run plus `ad-scraped` $0.00075 per ad.
