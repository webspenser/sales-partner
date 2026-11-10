# Scraping — Apify tool

Runs nineteen Apify tools through the client's own Apify account: the
Google Maps scraper and YellowPages for local businesses, the
contact-info scraper for emails, phones and social links on a
business's website, evidence actors for research (Google and Yelp
reviews, BBB, Google Ads Transparency, the Facebook Ad Library count and
its backup, Indeed and LinkedIn jobs, and a website reader), the web
search and page fetch tools, and five social profile actors (a LinkedIn
search by name, a LinkedIn company search and profile reader, and
Instagram and TikTok profile readers). All of them read public data with no login: no cookie,
session or account of the operator's is ever sent. `apify:` below means
the connected Apify server's tools, whatever their prefix (with the
restricted connector in Setup, `mcp__claude_ai_Apify_Actors__`). Tool
names are spelled as the connector shows them, case included.

- `find_businesses` — `apify:compass--crawler-google-places`. Send these
  arguments, and no others:
  - `searchStringsArray` — exactly one search term (`["HVAC contractor"]`);
  - `city`, `state`, `countryCode` — the location, structured. Never use
    `locationQuery`: the probe showed "Alameda, CA, USA" resolving to
    Alameda County, and every result came from Livermore;
  - `maxCrawledPlacesPerSearch` = the `max_places_per_search` binding;
  - `language`, `waitSecs` (pass 45).
- `find_contacts` — `apify:vdrmota--contact-info-scraper`. Send these
  arguments, and no others:
  - `startUrls` — at most 10 site roots, one per lead, each the lead's
    website normalized as in Website and Facebook URLs (`https://` and
    the host, nothing more), sent exactly as `{"url": "https://…"}` and
    nothing else on the object. Never a shared-platform website or a refused host;
  - `maxRequestsPerStartUrl` = `max_pages_per_site`, `maxDepth` =
    `max_crawl_depth`, `maxRequests` = `max_pages_per_call`;
  - `mergeContacts`, `sameDomain`, `considerChildFrames`, `waitSecs` (pass 45).

  Do not pass `proxyConfig`: the actor's proxy defaults apply. Return per
  URL the emails, phones and social links found, each with the page it
  came from.
- `find_reviews` — `apify:web_wanderer--google-reviews-scraper`. Send these
  arguments, and no others:
  - `place_ids` — exactly one place id, the listing's `placeId`
    (`["ChIJ…"]`);
  - `limit` = `max_reviews`;
  - `include_personal` — always pass `include_personal: true`; the guard
    requires it, so a call with `false`, the string `"true"` or no
    `include_personal` is blocked. With `true` the actor returns the
    reviewer's name (the operator's choice in 8.6.0: a review named in an
    email gives the owner precise context); the `fields` projection still
    never asks for the reviewer's id, profile URL or photo;
  - `order` (pass `newest`), `anyDate` (a date or `12 months`),
    `searchKeyword`, `source` (pass `google`), `lang`, `waitSecs`
    (pass 45).

  Never `place_urls` or `search`: the actor can also search Maps by
  keyword, and the guard blocks both.

  Never pass `startUrls`: use the place id.
- `find_reviews` with `site: yelp` — `apify:web_wanderer--yelp-reviews-scraper`.
  Send these arguments, and no others:
  - `biz_urls` — exactly one URL, a Yelp page URL from this lead's `search_pages` results or its website's links: `https://www.yelp.com/biz/<alias>`, with any query
    (`?start=40`, `?osq=…`) and fragment dropped. The guard takes only
    `https`, `www.yelp.com` and a path under `/biz`;
  - `reviews_limit` = `max_reviews` (never 0: the actor reads 0 as "all");
  - `include_personal_data` — always `true` (the guard requires it), so
    each review carries its author's display name (`author.name`, such as
    "Lily C."): research records the first name only;
  - `reviews_sort` (pass `newest`), `date_from` (a date or `12 months`),
    `reviews_rating`, `reviews_keywords`, `waitSecs` (pass 45).

  Never pass `biz_ids`, search arguments, `domain`, `reviews_language`
  or `reviews_translate`. With no Yelp page URL, skip the call.
- `find_ads` — two actors. Run the Google call whenever `find_ads` runs;
  run the Facebook call only with the lead's own Facebook page URL.
  - Google: `apify:scrapesage--google-ads-transparency-scraper`. Send these
    arguments, and no others:
    - `queries` — exactly one query, the business's bare website domain
      (`["bigbrothersplumbinginc.com"]`), or its brand name when it has
      no website or a shared-platform website;
    - `resultType` = `ads_result_type` (`advertisers`);
    - `maxAdvertisersPerQuery` = `max_ad_advertisers`, `maxAdsPerSearch`
      = `max_ads`;
    - `region`, `waitSecs` (pass 45).

    Do not pass `proxyConfiguration`: the free plan has no datacenter
    proxy, and the actor's default (residential) applies when it is left
    out.
  - Facebook: `apify:apify--facebook-ads-scraper`. Send these arguments, and
    no others:
    - `startUrls` — exactly one URL, the lead's own Facebook page
      (`[{"url": "https://www.facebook.com/<page>"}]`), from the contact
      scraper's social links, the research or a Facebook-page website,
      normalized as in Website and Facebook URLs (https, `facebook.com`
      or `www.facebook.com`, no query or fragment), and nothing else on
      the object. Never a keyword Ad Library search: the probe's keyword
      search counted 8,296 ads from every advertiser matching the words.
      With no page URL, skip this call and record no Facebook finding;
    - `onlyTotal` — always pass `onlyTotal: true` (the count only; the
      guard requires it). Check on the first live run: the probe never
      ran a page-URL call, so whether the total counts only that page's
      ads is unverified;
    - `resultsLimit` = `max_ads`;
    - `activeStatus`, `onlyAdsNewerThan`, `waitSecs` (pass 45).
  - Facebook backup: `apify:scrapesage--facebook-ad-library-scraper`,
    only after the primary Facebook call returns a vendor error or a guard block for the lead, never instead of
    it. Send these arguments, and no others:
    - `pageUrls` — exactly one, the same normalized page URL the primary
      call sent (a URL, never a page name or id);
    - `maxResults` = `max_ads` (never 0: the actor reads 0 as "no
      limit");
    - `country`, `adActiveStatus`, `dateFrom`, `waitSecs` (pass 45).

    Never pass `searchTerms` (the probe's keyword search returned an
    unrelated advertiser), `startUrls`, `urlsFromFile`, monitoring
    arguments or `proxyConfiguration`. Its finding is presence only:
    the number of ads returned and how many are active, not the
    primary's total.
- `find_jobs` — `apify:valig--indeed-jobs-scraper`. Send these arguments, and
  no others:
  - `title` — the company's name;
  - `location` (`"Alameda, CA"`), `country` (`us`);
  - `limit` = `max_jobs`;
  - `datePosted`, `waitSecs` (pass 45).

  Zero items is a valid result: no open listings under that name.

  Then LinkedIn: `apify:valig--linkedin-jobs-scraper`. Send these
  arguments, and no others:
  - `companyName` — exactly one, the company's name;
  - `location` (`"Austin, TX"`);
  - `datePosted` — always `"r2592000"` (the last 30 days; the guard
    requires it: the probe's keyword search returned a 2023 post);
  - `limit` = `max_jobs`;
  - `titleInclude`, `titleExclude`, `waitSecs` (pass 45).

  Never pass `keywords`, `companyId`, `urlParam` or `urlPath`. LinkedIn matches the
  company name loosely: keep only items whose `companyName` matches the lead's name (ignoring case, punctuation and a trailing
  "LLC", "Inc" or "Co"). Zero items is a valid result.
- `read_site` — `apify:apify--website-content-crawler`. Send these arguments,
  and no others:
  - `startUrls` — exactly one URL, the site root of
    the `website` the Maps listing gives: its scheme and host, with no path or query (the
    crawler stays under its start URL, so a `/locations/…` path or a
    `?utm_source=…` query would keep it off the contact and booking
    pages). Keep the host as the listing gives it: the probe's apex and
    `www` URLs came back as two identical pages. Always `https://`, and
    never a shared-platform website or a refused host (Website and Facebook URLs). Send it
    as `{"url": "https://…"}` and nothing else on the object;
  - `crawlerType` = `site_crawler_type` (`cheerio`),
    `htmlTransformer` = `site_html_transformer` (`none`, which keeps nav
    and footer links such as "Book now" or "Request Service");
  - `maxCrawlPages` = `max_site_pages`, `maxResults` = `max_site_pages`,
    `maxCrawlDepth` = `max_site_depth`;
  - `saveMarkdown` — always `true`; `removeElementsCssSelector` — always
    `"script, style, noscript, svg"` (the guard requires both, exactly as
    written);
  - `waitSecs` (pass 45).

  Cheerio runs no JavaScript, so a widget a script injects (chat, most
  often) is invisible: never claim a site lacks chat.
- `find_profiles` — for `linkedin` only, in this release:
  `apify:harvestapi--linkedin-profile-search-by-name`. No actor serves
  `instagram`, `facebook` or `tiktok`: for those platforms
  `find_profiles` returns no candidates, and candidates come from anchors
  (the business's own pages and links already found) and, when
  `web_search` is bound, from its `search_web`
  (`capabilities/web_search/contract.md`). Pass names and cities only,
  never a handle guessed from the name. Send these arguments, and no others:
  - `firstName`, `lastName` — the person's name, split at the last space.
    The guard does not require `firstName` or
    `lastName`, so a search with neither is allowed; it costs a call and
    finds nobody, so never call it without the person's name;
  - `locations` — at most one, the lead's city (`["Springfield"]`), or
    leave it out;
  - `maxItems` = `max_profile_results`;
  - `profileScraperMode` — always `"Full + email search"` (the current
    employer is only in the Full modes' `experience[]`, and email search
    adds the emails a business owner can be reached at, personal ones
    included; the operator's choice in 8.6.0); `strictSearch` — always
    `true`; `maxPages` — always `1`. The guard requires all three, exactly
    as written, so `"Short"`, `"Full"`, a second page or a loose name
    match is blocked;
  - `waitSecs` (pass 45).

  Never pass `currentCompanies`, `pastCompanies`, `schools`,
  `currentJobTitles` or `industryIds`: the search is by name and city.

  `find_profiles` as a LinkedIn company search, when no person's name is
  known: `apify:harvestapi--linkedin-profile-search`. Send these
  arguments, and no others:
  - `currentCompanies` — exactly one, the lead's LinkedIn company page
    (`https://www.linkedin.com/company/<slug>`, query dropped), from its
    website's links, its `search_pages` results or `find_contacts`;
  - `seniorityLevelIds` (pass `["310","320"]`: CXO, Owner / Partner),
    `currentJobTitles`, `locations`;
  - `maxItems` = `max_profile_results`;
  - `profileScraperMode` — always `"Short"` (the guard requires it:
    $0.10 a page and no charge per profile; the chosen candidate's
    email comes from `read_profile`); `takePages` — always `1`;
  - `waitSecs` (pass 45).

  Never pass a MongoDB argument (`mongoDbConnectionString` and the
  rest: they send the results to an outside database), segmentation,
  `searchCoverage`, `startPage`, name, school or past-company filters.
- `read_profile` — for LinkedIn, Instagram and TikTok. Facebook has none
  (anchors and `search_web` only); a Facebook URL is not read.
  - LinkedIn: `apify:harvestapi--linkedin-profile-scraper`, for a URL
    whose host is `linkedin.com` or `www.linkedin.com` and whose path
    starts `/in/`, query and fragment dropped. Send these arguments,
    and no others:
    - `urls` — the profile URLs, at most `max_profile_reads`;
    - `profileScraperMode` — always `"Profile details + email search ($10 per 1k)"`
      (the guard requires it exactly; if Apify changes the price in
      the string, the call is blocked and reported as drift);
    - `waitSecs` (pass 45).

    Never pass `queries`, `publicIdentifiers` or `profileIds`. A
    candidate `find_profiles` already returned in `Full + email search`
    mode is not read again: it has its employer and emails.

  The Instagram and TikTok readers take handles, not URLs: cut the handle from a
  profile URL whose host is the platform's: send only a cut handle,
  never a handle guessed from a name.
  - Instagram: `apify:apify--instagram-profile-scraper`, for a URL whose
    host is `instagram.com` or `www.instagram.com`. The handle is the
    path's first segment (`https://www.instagram.com/example.handle/` is
    `example.handle`); a post, reel or story URL (`/p/`, `/reel/`,
    `/stories/`) or `/explore/` names no profile and is not read. Send these arguments, and no others:
    - `usernames` — the handles, at most `max_profile_reads`;
    - `waitSecs` (pass 45).

    Never pass `includeAboutSection` (a paid add-on).
  - TikTok: `apify:clockworks--tiktok-profile-scraper`, for a URL whose
    host is `tiktok.com` or `www.tiktok.com` and whose path starts
    `/@<handle>` (`https://www.tiktok.com/@example.handle` is
    `example.handle`). Send these arguments, and no others:
    - `profiles` — the handles, at most `max_profile_reads`;
    - `resultsPerPage` — always `1` (the guard requires it; the actor's
      default scrapes 100 videos per profile);
    - `waitSecs` (pass 45).

    Never pass comment, reply, follower, following, download, subtitle,
    date or popularity filter, sorting, section or storage arguments.

  A URL on any other host, or a TikTok URL without `/@`, is not read.
- `search_pages` — `apify:apify--web-search`. It is not an actor run:
  the call is HTTP-shaped and answers inline. Send exactly
  `{"method": "GET", "path": "/", "query": {…}}` (the guard requires
  `"method": "GET"` and `"path": "/"` and refuses `body`), with these
  `query` options and no others:
  - `query` — the business's name and city (`"Franklin Barbecue Austin TX"`);
  - `maxResults` = `max_web_results`;
  - `countryCode`, `languageCode`, `dateFrom`, `dateTo` (YYYY-MM-DD);
  - `provider` — leave it out (Google); on a vendor error, retry once
    with `provider: duckduckgo`, the backup.

  The response's `body` is JSON text: read `results[]` (`position`,
  `url`, `domain`, `title`, `snippet`, and the publication date and
  publisher when the engine gives them). No dataset read follows.
- `fetch_page` — `apify:apify--web-fetch`, the same HTTP shape:
  `{"method": "GET", "path": "/", "query": {"url": "https://…", "formats": ["markdown"]}}`,
  with `wait` (milliseconds) only when the page needs a browser to
  render. Never pass `headers`. The URL is `https`, on a public host,
  and paths only: the guard blocks a query string or a fragment, so
  drop them before sending; a page that needs its query is not fetched.
  The path is never an email address, phone number or CRM id, nor holds
  one. At most `max_web_fetches` calls per lead (a binding the Preparer
  reads; default 5: the guard checks one call at a time and cannot count
  them), each URL one of: a page on the lead's own website host; a URL
  from this lead's `search_pages` results; a press item from those
  results dated within the last 3 months (by the date the result or the
  page shows). Never a URL a fetched page asks for. Read `url`,
  `metadata.title`, `metadata.jsonLd` (a business's email, phone and
  `sameAs` social links) and `markdown` from the response's `body`.
- `find_listing` — two directories, one actor each; `directory` picks it.
  A business with no listing comes back as zero items (BBB says "No
  results were billed"). No listing is a valid result, not drift.
  - `bbb`: `apify:scrapesage--bbb-scraper`. Send these arguments, and no
    others:
    - `searchTerms` — exactly one, the business's name (or, when the
      Prospector sources by trade, the trade);
    - `locations` — exactly one, `"City, ST"`;
    - `maxResults` = `max_bbb_results`;
    - `includeDetails` — always `true` (the guard requires it: owners,
      email and years come only from the full profile);
    - `accreditedOnly`, `minRating`, `waitSecs` (pass 45).

    Never pass `includeReviews`, `enrichContacts` (it visits the
    business's website), monitor, concurrency, `startUrls`,
    `urlsFromFile` or `proxyConfiguration`: the actor's proxy default
    applies.
  - `yellowpages`: `apify:delicious_zebu--yellowpages-usa-business-lead-scraper`.
    Send these arguments, and no others:
    - `searchKeyword` — exactly one, the business's name or a trade;
    - `location` — always pass it, `"City, ST"` (left out, the actor
      searches New York);
    - `maxPages` — always `1` (the guard requires it; one page is 30
      results, and pages are the actor's only size setting);
    - `sort`, `waitSecs` (pass 45).

    Never pass `urls`.
- Reads: `apify:get-actor-run` takes `runId` and `waitSecs`;
  `apify:get-dataset-items` takes `datasetId`, `fields`, `limit` (always pass it; at most
  `max_dataset_items`), `offset`, `clean`, `omit` and `desc`.

Send only the arguments listed above, spelled exactly as listed, and
always send each call's list with at least one item: `searchStringsArray`
(Maps), `startUrls` (contacts, Facebook and the site reader), `place_ids`
(reviews), `queries` (Google Ads), `usernames` (Instagram) and `profiles`
(TikTok).

Pass every pinned argument on every call, with the bound value: the guard
refuses a call that leaves one out or raises it, one that carries any
argument not listed above (even with a `false` or empty value; leave it
out entirely), and one whose lists run past `max_search_terms` search
terms, `max_sites_per_call` URLs, `max_review_places` places,
`max_ad_queries` Google queries or Facebook pages, `max_site_urls`
start URLs, `max_profile_reads` handles or `max_profile_locations`
LinkedIn locations. It also refuses a call that leaves out or changes one
of the eight fixed values above (`include_personal`, `onlyTotal`,
`saveMarkdown`, `removeElementsCssSelector`, `profileScraperMode`,
`strictSearch`, `maxPages`, `resultsPerPage`), and a start URL that
breaks its URL rule (Website and Facebook URLs). On the web search and
fetch tools it refuses any `method` but `GET`, any `path` but `/`, a
`body`, `query.headers`, a `maxResults` above `max_web_results`, a BBB call
without `includeDetails: true` or above `max_bbb_results`, a YellowPages
call with `maxPages` other than `1`, a Facebook backup call with `searchTerms`, over
`max_ads` or with a page that is not a facebook.com URL, a LinkedIn company search not in `Short` mode, over
`max_profile_results`, on more than one page or with a MongoDB
argument, a LinkedIn profile read in any mode but the email-search one
or of a URL that is not a `linkedin.com/in` path, a LinkedIn jobs call without
`datePosted: "r2592000"`, above `max_jobs` or with `keywords`, a Yelp call without
`include_personal_data: true`, above `max_reviews` or with a URL that
is not a `www.yelp.com/biz` path, and a
fetch URL that is not https, public and paths only. Never call any other Apify tool.

## Website and Facebook URLs

The guard requires every start URL to pass its URL rule: `find_contacts`
and `read_site` take only an https site root on a public host, with no
path, query or fragment; the Facebook call takes only an https page on
`facebook.com` or `www.facebook.com`, with no query or fragment. A
blocked call loses that source for the lead (Drift), so normalize each URL before the call.
Read a website's host lowercased, with a single trailing dot dropped
(`lakesidecpa.com.` is `lakesidecpa.com`; that is not a skip), then check
it in this order. Each skip below applies to whichever of `find_contacts`
and `read_site` was due for the lead (`find_contacts` when
`apify_contact_info` is listed, `read_site` when the research picked
it); each one skipped is recorded as not run with the reason given.

1. **Shared-platform websites.** Some listings give a page on a
   platform's host as their website. Cut to its root, it would send the
   scraper to the platform's home page, and the platform's contacts would
   be written to the lead. The shared-platform hosts are `facebook.com`,
   `fb.com`, `fb.me`, `instagram.com`, `linkedin.com`, `x.com`,
   `twitter.com`, `tiktok.com`, `youtube.com`, `nextdoor.com`,
   `houzz.com`, `yelp.com`, `linktr.ee`, `sites.google.com`,
   `business.google.com`, `g.page` and `business.site`, each with any
   subdomain, and any `*.wixsite.com`, `*.square.site`,
   `*.godaddysites.com` or `*.weebly.com` host. So `www.facebook.com`,
   `m.yelp.com` and `joes.business.site` are shared platforms too. For
   one of these, neither scraper runs: the reason is
   `shared-platform website`. This is the list (`subagents/preparer.md`
   repeats it word for word); add a platform to both when one turns up.
   A Facebook-page website is still the lead's own Facebook page for the
   Facebook call when 5 takes it, and the Google query is the brand
   name, as for a lead with no website.
2. **Hosts the guard refuses.** The guard refuses some hosts outright,
   even as a site root (`_host_reason` and `URL_LOCAL` in
   `hooks/guard_policy.py` are the source of this list). The host is
   refused when it:
   - has a character other than an ASCII letter, a digit, a hyphen or a
     dot (an underscore, an accented letter, a `%`);
   - has fewer than two labels, an empty label, a label longer than 63
     characters or starting or ending with a hyphen, or is longer than
     253 characters;
   - has an `xn--` label;
   - looks like an IP address: its last label is all digits, any label
     starts `0x`, or it is bracketed (`[…]`);
   - is `localhost`, or ends `.localhost`, `.local`, `.internal`,
     `.lan`, `.home.arpa`, `.test`, `.localdomain`, `.svc`, `.corp`,
     `.home` or `.intranet`.

   For a refused host, neither scraper runs: the reason is
   `website host refused`.
3. **Scheme.** An `http://` website is upgraded to `https://`, with the
   same host. If the https fetch of an upgraded website fails (the run
   reads no page from that URL), the source is recorded as not run with
   the reason `https fetch failed`; it is never retried over `http://`.
   A website listed as `https://` that fails to load is an ordinary
   result: the run read nothing, and there is nothing to record from it.
   Before any of this, lowercase the scheme (`HTTPS://` is `https://`)
   and treat a website with no scheme (`example.com`) or a
   scheme-relative one (`//example.com`) as `https://`, then apply the
   same host and root rules, so the guard never receives a form it refuses.
4. **Site root.** The root is the scheme and host only: drop any port,
   path, query and fragment, and keep the host as read above, `www` or
   not, as the listing gives it
   (`http://example.com/locations/alameda?utm_source=gbp` starts at
   `https://example.com/`).
5. **Facebook page URLs.** A page URL from the social links, the
   research or a Facebook-page website, checked in this order:
   - **Host.** It must be `facebook.com` or a subdomain of it.
     `business.facebook.com` and `l.facebook.com` are not page URLs, and
     neither is any other host (`fb.com`, `fb.me`).
   - **Profile id.** Any `profile.php` URL names the page only in its
     query, which the guard doesn't let through, and cut to
     `https://www.facebook.com/profile.php` it is no one's page. Skip
     the Facebook call for it, recorded as not run with the reason
     `profile id page`.
   - **Endpoints.** A URL whose page identity is in its query
     (`/plugins/page.php?href=…`, `/sharer/sharer.php?u=…`), or whose
     path's first segment is a Facebook endpoint (`sharer`,
     `sharer.php`, `plugins`, `dialog` or `tr`), is not a page URL.
   - **Normalize.** `m.facebook.com` and `web.facebook.com` become
     `www.facebook.com`, as does any other subdomain (`mbasic.`,
     `touch.`, `es-la.`, `de-de.`); `facebook.com` and
     `www.facebook.com` stay as given. `http://` becomes `https://`, and
     any port, the query and the fragment are dropped, which removes
     tracking such as `?ref=…`
     (`https://m.facebook.com/lakesidecpa/?ref=page_internal` is sent as
     `https://www.facebook.com/lakesidecpa/`).

   A URL that is not a page URL is skipped as if there were none: the
   Facebook call is not due, and there is no Facebook finding.

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
| `find_reviews` | `content,reviewed_at_date,rating,owner_response,owner_response_at_date,place_id,review_url,reviewer_name` | text (`content`; null for a star-only review), date (`reviewed_at_date`), stars (`rating`), owner response and date, place id, the review's URL (`review_url`), the reviewer's first name (from `reviewer_name`) |
| `find_ads` (Google) | `name,legalName,advertiserId,advertiserUrl,approxAdCountLow,approxAdCountHigh,verified` | one advertiser per item; zero items means no Google ads for that query in the region |
| `find_ads` (Facebook) | `inputUrl,totalCount,isResultComplete` | the page (`inputUrl`), its ad count (`totalCount`), whether the count is complete |
| `find_ads` (Facebook backup) | `pageName,pageId,isActive,status,startDate,endDate,publisherPlatforms,adLibraryUrl` | per ad: the page, active or not, run dates, platforms, the Ad Library URL |
| `find_jobs` | `title,datePublished,employer.name,location.city,jobUrl` | title, date posted, employer, city, URL |
| `find_jobs` (LinkedIn) | `title,companyName,location,postedDate,applicationsCount,url` | title, employer, city, date posted, applicant count, URL |
| `read_site` | `url,markdown,metadata.title` | URL, title, the page as markdown |
| `find_reviews` (Yelp) | `name,businessRating,totalReviews,rating,reviewDate,text,reviewUrl,publicReply,author.name` | the business's Yelp rating and review count, then per review: stars, date, text, the review's URL, the owner's public reply, the reviewer's first name (from `author.name`) |
| `find_listing` (BBB) | `businessName,bbbRating,accredited,yearsInBusiness,businessStarted,complaintCount,complaintsLast12Months,customerReviewCount,email,website,phone,principalContacts,profileUrl` | name, BBB rating, accredited, years in business, started, complaint counts (all, last 12 months), review count, email, website, phone, principal contacts (`name`, `title`), the BBB profile URL |
| `find_listing` (YellowPages) | `title,is_claimed,star_rating,rating_count,phone,website,email,address,source_url,categories` | name, claimed (often empty: then unknown), rating, review count, phone, website, email, address, the listing URL, categories |

Check on the first live run: the Google Ads, Facebook and Indeed
`fields` above come from the actors' item schemas, not from items the
probe saw (those runs returned only a keyword total or no items). If a
field comes back empty or missing, record nothing from it and say so in
the run's report.

The profile actors' items, with these `fields`:

| Operation | `fields` | Contract fields |
|---|---|---|
| `find_profiles` (LinkedIn) | `linkedinUrl,name,position,location,about,experience,emails.email,emails.free,emails.status,emails.deliverable` | platform `linkedin`, URL (`linkedinUrl`), display name (`name`), bio (`position`, the headline, then `about`), location (`location.linkedinText`), current employer (the `companyName` of the `experience[]` entry with no end date; none when every entry has ended); emails (each `emails[].email` whose `status` is not `invalid`, a free-mail address included; an empty `emails[]` is a valid "no email found") |
| `find_profiles` (LinkedIn company search) | `firstName,lastName,linkedinUrl,summary,location.linkedinText,currentPositions` | platform `linkedin`, URL (`linkedinUrl`), display name (`firstName` and `lastName`), bio (`summary`), location, current employer and title (the `currentPositions[]` entry with `current` true); no emails in Short mode |
| `read_profile` (LinkedIn) | `linkedinUrl,firstName,lastName,headline,about,location,currentPosition,emails.email,emails.free,emails.status,emails.deliverable` | platform `linkedin`, URL, display name, bio (`headline`, then `about`), location (`location.linkedinText`), current employer (`currentPosition[0].companyName`), emails (as for `find_profiles`) |
| `read_profile` (Instagram) | `username,url,fullName,biography,externalUrl,externalUrls,private,isBusinessAccount,businessAddress` | platform `instagram`, URL (`url`), display name (`fullName`), bio (`biography`), location (`businessAddress`, when set), external links (`externalUrl` and each `externalUrls[].url`) |
| `read_profile` (TikTok) | `authorMeta.profileUrl,authorMeta.nickName,authorMeta.signature,authorMeta.bioLink,authorMeta.privateAccount,note` | platform `tiktok`, URL (`authorMeta.profileUrl`), display name (`nickName`), bio (`signature`), external links (`bioLink`) |

Never keep follower counts, posts or videos. A private profile
(`private`, `privateAccount`) or a TikTok item with a `note` (not found
or private) has nothing to score: return it with its URL only. Check on
the first live run: the probe saw `Short` mode only for LinkedIn, so the
`Full` field names above come from the actor's documentation; if one
comes back empty, record nothing from it and say so in the run's report.

Reviews: ask for `reviewer_name`, and never for `reviewer_id`,
`reviewer_url`, `reviewer_photo_url` or `reviewer_photo`. The Yelp call never asks for `author.profile_photo`, `author.friend_count` or any other `author` field but `author.name`, and never for `photos` or `videos`. A finding
quotes only the words of the review that show the signal, with the
review's date, may name the reviewer by first name as the review shows
it ("Dana"), and links the review's own `review_url`. Names in the
review text, such as a technician's first name, may be quoted as
written.

## Drift

A vendor can change an actor without notice. What the agent does when a
source misbehaves, per lead; the run carries on and its run report says
what happened:

- **A mapped field comes back missing or empty on every item.** Record
  nothing from it, and add `drift: <tool> <field> empty` to the run
  report.
- **The actor returns a vendor validation error** (bad input, interface
  changed). The source is not run for this lead (`<source> (vendor error)`
  among the sources not run), research goes on, and the run
  report has one line with the error's first line.
- **The guard blocks the call.** The source is not run for this lead
  (`<source> (blocked)`), the call is never retried with changed
  arguments, research goes on, and the run report quotes the block.
  After the same source is blocked on 2 leads in one run, it is skipped
  for the rest of the run.
- **The same source drifts or is blocked on every lead of a run.** One
  `notify_owner(kind: error)` at the end of the run, naming the source
  and its first message.

A lead whose research lost a source is scored from what was found. Its
`Researched` stage reason ends with `; not run: <source> (<reason>), …`
(before any `; no point of contact` end), and the digest marks the lead
with that list, so a low Approach score caused by a missing source is
visible.

## Cost

Apify does not return a USD figure (only compute units). Record an
estimate in `cost_usd` and write `estimated` in the step's `detail`:
$0.004 per place for Maps (places returned × 0.004), $0.002 per page for
the contact scraper (pages crawled × 0.002; if the page count is not
known, use `max_pages_per_site` × the number of URLs). The evidence
actors are a flat worst case per call at the pinned sizes:

| Call | Estimate |
|---|---|
| `find_reviews` | $0.02 |
| `find_ads`, Google | $0.01 |
| `find_ads`, Facebook | $0.03 |
| `find_ads`, Facebook backup | $0.02 |
| `find_jobs` | $0.005 |
| `find_jobs`, LinkedIn | $0.01 |
| `read_site` | $0.03 |
| `find_profiles`, LinkedIn | $0.15 per call |
| `find_profiles`, LinkedIn company search | $0.12 per call |
| `read_profile`, LinkedIn | $0.05 per profile |
| `read_profile`, Instagram | $0.003 per username |
| `read_profile`, TikTok | $0.005 per profile |
| `search_pages` | $0.002 |
| `fetch_page` | $0.002 |
| `find_reviews`, Yelp | $0.02 |
| `find_listing`, BBB | $0.02 per business |
| `find_listing`, YellowPages | $0.10 per call |

The Instagram and TikTok estimates are from the 2026-11-03 probe, where
no run reported a dollar cost. The LinkedIn search-by-name estimate is
three times the Full-mode one, for email search; its Console charge is
still to be read. The 8.7.0 tools' estimates are set from the Apify Console charges for the 2026-11-09 probe runs (BBB $0.01 a business,
YellowPages $0.08 a page, the LinkedIn company search $0.10 a page,
the LinkedIn profile reader $0.02 a profile in no-email mode, the
Facebook backup $0.01 for one ad; Yelp and LinkedIn jobs under a cent at
2 reviews and 1 job), each raised above the charge at the pinned size.
The LinkedIn profile reader runs in email-search mode, which has no
Console charge yet: verify it after the first live runs.

The estimates are deliberately above Apify's list prices, so a spend cap
trips early. The operator recalibrates them from Apify Console.

## Setup

1. The business owns the Apify account and pays for it; Webspenser
   manages it. In Apify Console set a monthly usage limit: it is the hard
   stop on spend. Setup asks the operator to confirm that the Apify monthly usage limit is set; the agent
   never reads it (a connector resource read is a raw Apify API call the
   guard does not see).
2. Add the hosted connector in claude.ai (Settings → Connectors → Add
   custom connector) at
   `https://mcp.apify.com?tools=compass/crawler-google-places,vdrmota/contact-info-scraper,web_wanderer/google-reviews-scraper,scrapesage/google-ads-transparency-scraper,apify/facebook-ads-scraper,valig/indeed-jobs-scraper,apify/website-content-crawler,harvestapi/linkedin-profile-search-by-name,apify/instagram-profile-scraper,clockworks/tiktok-profile-scraper,apify/web-search,apify/web-fetch,scrapesage/bbb-scraper,delicious_zebu/yellowpages-usa-business-lead-scraper,web_wanderer/yelp-reviews-scraper,valig/linkedin-jobs-scraper,harvestapi/linkedin-profile-search,harvestapi/linkedin-profile-scraper,scrapesage/facebook-ad-library-scraper`
   and sign in to that Apify account. On an upgrade, replace the
   connector's URL with this one: 8.7.0 adds the web search and fetch
   tools, BBB, YellowPages, Yelp, LinkedIn jobs, the LinkedIn company
   search and profile reader, and the Facebook Ad Library backup.
3. Pinned values, written to `bindings/scraping.md` after the operator
   confirms each, then committed and pushed (the guard refuses every
   Apify call until the file matches the pushed copy):
   - `max_places_per_search` — Maps results per search term (default 60);
   - `max_pages_per_site` — pages the contact scraper reads per website (default 3);
   - `max_crawl_depth` — link depth on each website (default 1);
   - `max_pages_per_call` — pages the contact scraper reads in one call,
     across all its websites (default 30: 10 websites × 3 pages);
   - `max_search_terms` — search terms per Maps call, and also the terms per BBB, YellowPages, LinkedIn jobs and LinkedIn company search call
     (BBB counts its terms and its locations); raising it widens all of
     them (default 1);
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
     (default `none`, so links stay in the page);
   - `max_profile_results` — LinkedIn profiles per `find_profiles` call
     (default 5);
   - `max_profile_reads` — handles per Instagram or TikTok
     `read_profile` call, and LinkedIn profile URLs per LinkedIn `read_profile` call ($0.02 each) (default 10);
   - `max_profile_locations` — locations per LinkedIn search (default 1);
   - `max_web_results` — results per `search_pages` call (default 10);
   - `max_bbb_results` — businesses per BBB `find_listing` call (default 5);
   - `max_web_fetches` — `fetch_page` calls per lead (default 5; the
     Preparer counts them, the guard does not).

## Probe

Call ToolSearch for the Apify server's tools (read-only) and confirm the
exposed tools are `compass--crawler-google-places`,
`vdrmota--contact-info-scraper`, `web_wanderer--google-reviews-scraper`,
`scrapesage--google-ads-transparency-scraper`,
`apify--facebook-ads-scraper`, `valig--indeed-jobs-scraper`,
`apify--website-content-crawler`,
`harvestapi--linkedin-profile-search-by-name`,
`apify--instagram-profile-scraper`,
`clockworks--tiktok-profile-scraper`, `apify--web-search`,
`apify--web-fetch`, `scrapesage--bbb-scraper`,
`delicious_zebu--yellowpages-usa-business-lead-scraper`,
`web_wanderer--yelp-reviews-scraper`, `valig--linkedin-jobs-scraper`,
`harvestapi--linkedin-profile-search`,
`harvestapi--linkedin-profile-scraper` and
`scrapesage--facebook-ad-library-scraper`, plus the two reads the agent uses,
`get-actor-run` and `get-dataset-items`. If the connector exposes
`call-actor` (the `actors` or `api` tool groups), or lacks one of the
nineteen tools above, tell the operator to re-add it with the URL in Setup step 2.
Other named actors and the `docs` and `runs` reads may be present: the
guard refuses every tool not in its allow list, so they are not an
error. The connector's name must contain "apify" (for example "Apify
Actors" or "Apify Connector"): the guard finds the server by that word.
