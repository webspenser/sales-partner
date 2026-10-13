# Scraping — Apify tool

Runs two Apify actors through the client's own Apify account: the Google
Maps scraper for local businesses, and the contact-info scraper for
emails, phones and social links on a business's website. `apify:` below
means the connected Apify server's tools, whatever their prefix.

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
- Reads: `apify:get-actor-run` takes `runId` and `waitSecs`;
  `apify:get-dataset-items` takes `datasetId`, `fields`, `limit` (always pass it; at most
  `max_dataset_items`), `offset`, `clean`, `omit` and `desc`.

Pass every pinned argument on every call, with the bound value: the guard
refuses a call that leaves one out or raises it, one that carries any
argument not listed above (even with a `false` or empty value; leave it
out entirely), and one whose lists run past `max_search_terms` search
terms or `max_sites_per_call` URLs. Never call any other Apify tool.

## Results

An actor tool returns run metadata, not items: `runId`, `status`,
`stats`, `storages.datasets.default.id` and `itemCount`. It waits at most
`waitSecs` (0 to 45; pass 45). If `status` is not `SUCCEEDED`, call
`apify:get-actor-run` with the `runId` (`waitSecs` 45) until it is. Then
read the items with `apify:get-dataset-items` using the dataset id and a
`fields` projection: a Maps item has about 64 fields, so ask only for
`title,categoryName,categories,address,street,city,state,postalCode,phone,website,totalScore,reviewsCount,placeId,url,permanentlyClosed,temporarilyClosed,claimThisBusiness`.
Map them to the contract's fields and drop places that are permanently
closed.

## Cost

Apify does not return a USD figure (only compute units). Record an
estimate in `cost_usd` and write `estimated` in the step's `detail`:
$0.004 per place for Maps (places returned × 0.004), $0.002 per page for
the contact scraper (pages crawled × 0.002; if the page count is not
known, use `max_pages_per_site` × the number of URLs). The estimates are
deliberately above Apify's list prices, so a spend cap trips early. The
operator recalibrates them from Apify Console.

## Setup

1. The business owns the Apify account and pays for it; Webspenser
   manages it. In Apify Console set a monthly usage limit: it is the hard
   stop on spend.
2. Add the hosted connector in claude.ai (Settings → Connectors → Add
   custom connector) at
   `https://mcp.apify.com?tools=compass/crawler-google-places,vdrmota/contact-info-scraper`
   and sign in to that Apify account.
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
   - `max_dataset_items` — items per `get-dataset-items` read (default 100).

## Probe

Call ToolSearch for the Apify server's tools (read-only) and confirm the
exposed tools are `compass--crawler-google-places` and
`vdrmota--contact-info-scraper`, plus the two reads the agent uses,
`get-actor-run` and `get-dataset-items`. If the connector exposes
`call-actor` or other tools, tell the operator to re-add it with the URL
in Setup step 2; the guard blocks them either way.
