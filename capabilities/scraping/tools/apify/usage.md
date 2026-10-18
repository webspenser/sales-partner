# Scraping — Apify tool

Runs seven Apify actors through the client's own Apify account: the Google
Maps scraper for local businesses, the contact-info scraper for emails,
phones and social links on a business's website, and five evidence
actors for research (Maps reviews, Google Ads Transparency, the Facebook
Ad Library count, Indeed jobs and a website reader). `apify:` below means
the connected Apify server's tools, whatever their prefix (with the
restricted connector in Setup, `mcp__claude_ai_Apify_Actors__`). Tool
names are spelled as the connector shows them, case included.

- `find_businesses` — `apify:compass--crawler-google-places`. Allowed
  arguments, and no others:
  - `searchStringsArray` — exactly one search term (`["HVAC contractor"]`);
  - `city`, `state`, `countryCode` — the location, structured. Never use
    `locationQuery`: the probe showed "Alameda, CA, USA" resolving to
    Alameda County, and every result came from Livermore;
  - `maxCrawledPlacesPerSearch` = the `max_places_per_search` binding;
  - `language`, `waitSecs` (pass 45).
- `find_contacts` — `apify:vdrmota--contact-info-scraper`. Allowed
  arguments, and no others:
  - `startUrls` — at most 10 website URLs, each exactly `{"url": "https://…"}`
    and nothing else on the object;
  - `maxRequestsPerStartUrl` = `max_pages_per_site`, `maxDepth` =
    `max_crawl_depth`, `maxRequests` = `max_pages_per_call`;
  - `mergeContacts`, `sameDomain`, `considerChildFrames`, `waitSecs` (pass 45).

  Do not pass `proxyConfig`: the actor's proxy defaults apply. Return per
  URL the emails, phones and social links found, each with the page it
  came from.
- `find_reviews` — `apify:compass--Google-Maps-Reviews-Scraper`. Allowed
  arguments, and no others:
  - `placeIds` — exactly one place id, the listing's `placeId`
    (`["ChIJ…"]`);
  - `maxReviews` = `max_reviews`;
  - `personalData` — always pass `personalData: false`. The guard cannot
    pin a true/false value, so this is on you: with `false` the actor
    returns no reviewer name, id, profile or photo;
  - `reviewsSort` (pass `newest`), `reviewsStartDate`,
    `reviewsFilterString`, `reviewsOrigin`, `language`, `waitSecs`
    (pass 45).

  Never pass `startUrls`: use the place id.
- `find_ads` — two actors. Run the Google call for every lead; run the
  Facebook call only with the lead's own Facebook page URL.
  - Google: `apify:scrapesage--google-ads-transparency-scraper`. Allowed
    arguments, and no others:
    - `queries` — exactly one query, the business's bare website domain
      (`["bigbrothersplumbinginc.com"]`), or its brand name when it has
      no website;
    - `resultType` = `ads_result_type` (`advertisers`);
    - `maxAdvertisersPerQuery` = `max_ad_advertisers`, `maxAdsPerSearch`
      = `max_ads`;
    - `region`, `waitSecs` (pass 45).

    Do not pass `proxyConfiguration`: the free plan has no datacenter
    proxy, and the actor's default (residential) applies when it is left
    out.
  - Facebook: `apify:apify--facebook-ads-scraper`. Allowed arguments, and
    no others:
    - `startUrls` — exactly one URL, the lead's own Facebook page
      (`[{"url": "https://www.facebook.com/<page>"}]`), from the contact
      scraper's social links or the research, and nothing else on the
      object. Never a keyword Ad Library search: the probe's keyword
      search counted 8,296 ads from every advertiser matching the words.
      With no page URL, skip this call and record no Facebook finding;
    - `onlyTotal` — always pass `onlyTotal: true` (the count only; the
      guard cannot pin it);
    - `resultsLimit` = `max_ads`;
    - `activeStatus`, `onlyAdsNewerThan`, `waitSecs` (pass 45).
- `find_jobs` — `apify:valig--indeed-jobs-scraper`. Allowed arguments, and
  no others:
  - `title` — the company's name;
  - `location` (`"Alameda, CA"`), `country` (`us`);
  - `limit` = `max_jobs`;
  - `datePosted`, `waitSecs` (pass 45).

  Zero items is a valid result: no open listings under that name.
- `read_site` — `apify:apify--website-content-crawler`. Allowed arguments,
  and no others:
  - `startUrls` — exactly one URL, the `website` the Maps listing gives
    (start there: the probe's apex and `www` URLs came back as two
    identical pages), as `{"url": "https://…"}` and nothing else on the
    object;
  - `crawlerType` = `site_crawler_type` (`cheerio`),
    `htmlTransformer` = `site_html_transformer` (`none`, which keeps nav
    and footer links such as "Book now" or "Request Service");
  - `maxCrawlPages` = `max_site_pages`, `maxResults` = `max_site_pages`,
    `maxCrawlDepth` = `max_site_depth`;
  - `saveMarkdown` — always `true`; `removeElementsCssSelector` — always
    `"script, style, noscript, svg"` (the guard cannot pin either);
  - `waitSecs` (pass 45).

  Cheerio runs no JavaScript, so a widget a script injects (chat, most
  often) is invisible: never claim a site lacks chat.
- Reads: `apify:get-actor-run` takes `runId` and `waitSecs`;
  `apify:get-dataset-items` takes `datasetId`, `fields`, `limit` (always pass it; at most
  `max_dataset_items`), `offset`, `clean`, `omit` and `desc`.

Send only the arguments listed above, spelled exactly as listed, and
always send each call's list with at least one item: `searchStringsArray`
(Maps), `startUrls` (contacts, Facebook and the site reader), `placeIds`
(reviews) and `queries` (Google Ads).

Pass every pinned argument on every call, with the bound value: the guard
refuses a call that leaves one out or raises it, one that carries any
argument not listed above (even with a `false` or empty value; leave it
out entirely), and one whose lists run past `max_search_terms` search
terms, `max_sites_per_call` URLs, `max_review_places` places,
`max_ad_queries` Google queries or Facebook pages, or `max_site_urls`
start URLs. Never call any other Apify tool.

## Results

An actor tool returns run metadata, not items: `runId`, `status`,
`stats`, `storages.datasets.default.id` and `itemCount`. It waits at most
`waitSecs` (0 to 45; pass 45). If `status` is not `SUCCEEDED`, call
`apify:get-actor-run` with the `runId` (`waitSecs` 45) until it is. Then
read the items with `apify:get-dataset-items` using the dataset id and a
`fields` projection: a Maps item has about 64 fields, so ask only for
`title,categoryName,categories,address,street,city,state,postalCode,location,phone,website,totalScore,reviewsCount,reviewsDistribution,openingHours,placeId,url,permanentlyClosed,temporarilyClosed,claimThisBusiness`.
These are all free dataset fields: no paid add-on (reviews, contacts,
images) is needed, and none is allowed. Drop places that are
permanently closed, then map each item to the contract's fields:

| Contract field | Maps item field |
|---|---|
| name, category | `title`, `categoryName` (`categories` for the rest) |
| address | `address` (or `street`, `city`, `state`, `postalCode`) |
| coordinates | `location`: `{"lat": …, "lng": …}` |
| phone, website | `phone`, `website` (missing when the listing shows none) |
| rating, review count | `totalScore`, `reviewsCount` |
| per-star review counts | `reviewsDistribution`: `oneStar` … `fiveStar` |
| opening hours | `openingHours`: one `{"day": "Monday", "hours": "8 AM to 5 PM"}` per day; `"Closed"` and `"Open 24 hours"` as written; missing or empty when the listing posts none |
| claimed | `claimThisBusiness`: `true` means the listing shows "Claim this business", so it is **unclaimed**; claimed = `not claimThisBusiness` |
| temporarily closed | `temporarilyClosed` |
| place id, URL | `placeId`, `url` |

Never infer a field the item does not carry: a missing `location` leaves
the coordinates empty, and missing `openingHours` means no hours
listed.

The evidence actors' items are read the same way, always with these
`fields` (the jobs actor's inline response alone is about 56 KB, so
never read items without a projection):

| Operation | `fields` | Contract fields |
|---|---|---|
| `find_reviews` | `text,publishedAtDate,stars,responseFromOwnerText,responseFromOwnerDate,placeId,url` | text, date (`publishedAtDate`), stars (`stars`; `rating` is empty), owner response and date, place id, place URL (`url`) |
| `find_ads` (Google) | `name,legalName,advertiserId,advertiserUrl,approxAdCountLow,approxAdCountHigh,verified` | one advertiser per item; zero items means no Google ads for that query in the region |
| `find_ads` (Facebook) | `inputUrl,totalCount,isResultComplete` | the page (`inputUrl`), its ad count (`totalCount`), whether the count is complete |
| `find_jobs` | `title,datePublished,employer.name,location.city,jobUrl` | title, date posted, employer, city, URL |
| `read_site` | `url,markdown,metadata.title` | URL, title, the page as markdown |

Reviews: never ask for `name`, `reviewerId`, `reviewerUrl` or
`reviewerPhotoUrl`, and never record reviewer names. A finding quotes
only the words of the review that show the signal, with the review's
date, and links the place's Maps `url` (with `personalData: false` there
is no review URL). Review text can name people, such as a technician's
first name: leave those names out of the snippet.

## Cost

Apify does not return a USD figure (only compute units). Record an
estimate in `cost_usd` and write `estimated` in the step's `detail`:
$0.004 per place for Maps (places returned × 0.004), $0.002 per page for
the contact scraper (pages crawled × 0.002; if the page count is not
known, use `max_pages_per_site` × the number of URLs). The evidence
actors are a flat worst case per call at the pinned sizes:

| Call | Estimate |
|---|---|
| `find_reviews` | $0.05 |
| `find_ads`, Google | $0.01 |
| `find_ads`, Facebook | $0.03 |
| `find_jobs` | $0.005 |
| `read_site` | $0.03 |

The estimates are deliberately above Apify's list prices, so a spend cap
trips early. The operator recalibrates them from Apify Console.

## Setup

1. The business owns the Apify account and pays for it; Webspenser
   manages it. In Apify Console set a monthly usage limit: it is the hard
   stop on spend.
2. Add the hosted connector in claude.ai (Settings → Connectors → Add
   custom connector) at
   `https://mcp.apify.com?tools=compass/crawler-google-places,vdrmota/contact-info-scraper,compass/Google-Maps-Reviews-Scraper,scrapesage/google-ads-transparency-scraper,apify/facebook-ads-scraper,valig/indeed-jobs-scraper,apify/website-content-crawler`
   and sign in to that Apify account. On an upgrade, replace the
   connector's URL with this one: it adds the five evidence actors.
3. Pinned values, written to `bindings/scraping.md` after the operator
   confirms each, then committed and pushed (the guard refuses every
   Apify call until the file matches the pushed copy):
   - `max_places_per_search` — Maps results per search term (default 60);
   - `max_pages_per_site` — pages the contact scraper reads per website (default 3);
   - `max_crawl_depth` — link depth on each website (default 1);
   - `max_pages_per_call` — pages the contact scraper reads in one call,
     across all its websites (default 30: 10 websites × 3 pages);
   - `max_search_terms` — search terms per Maps call (default 1);
   - `max_sites_per_call` — website URLs per contact call (default 10);
   - `max_dataset_items` — items per `get-dataset-items` read (default 100);
   - `max_reviews` — reviews per reviews call (default 50);
   - `max_review_places` — places per reviews call (default 1);
   - `max_ads` — ads per Google query, and the Facebook results limit (default 5);
   - `max_ad_advertisers` — Google advertisers per query (default 1);
   - `max_ad_queries` — Google queries, or Facebook page URLs, per ads call (default 1);
   - `ads_result_type` — the Google Ads mode (default `advertisers`; the
     cost estimate assumes it);
   - `max_jobs` — job listings per jobs call (default 20);
   - `max_site_pages` — pages the site reader reads per call (default 5);
   - `max_site_depth` — link depth for the site reader (default 1);
   - `max_site_urls` — start URLs per site read (default 1);
   - `site_crawler_type` — the site reader's crawler (default `cheerio`,
     plain HTTP; a browser crawler costs far more);
   - `site_html_transformer` — the site reader's HTML transformer
     (default `none`, so links stay in the page).

## Probe

Call ToolSearch for the Apify server's tools (read-only) and confirm the
exposed tools are `compass--crawler-google-places`,
`vdrmota--contact-info-scraper`, `compass--Google-Maps-Reviews-Scraper`,
`scrapesage--google-ads-transparency-scraper`,
`apify--facebook-ads-scraper`, `valig--indeed-jobs-scraper` and
`apify--website-content-crawler`, plus the two reads the agent uses,
`get-actor-run` and `get-dataset-items`. If the connector exposes
`call-actor` or other tools, or lacks one of the seven actors, tell the
operator to re-add it with the URL in Setup step 2; the guard blocks
other tools either way.
