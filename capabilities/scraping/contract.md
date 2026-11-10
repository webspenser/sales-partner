# Scraping contract

How the agent reads public business listings, contact details, reviews,
ads, job listings, website pages, public social profiles, BBB and YellowPages listings, and open-web
search results and pages through an
outside scraper. Skills and sub-agent contracts call these operations,
never a provider's tools.

## Operations

| Operation | Arguments | Returns | On failure |
|---|---|---|---|
| `find_businesses` | `query`, `location` (city, state, country) | listings: name, address, coordinates (lat, lng), phone, website, category, rating, review count, per-star review counts (one to five stars), opening hours (per day), claimed (true or false), temporarily closed (true or false), place id, URL; plus the run's cost (estimated when the provider does not report it) | Retried once; then a ledger `step` with outcome `failed` and an `error` event |
| `find_contacts` | `urls[]`, at most 10 per call | per URL: emails, phones, social links; plus the run's cost (estimated when the provider does not report it) | Same |
| `find_reviews` | `place` (the listing's place id) | reviews: text, date, stars, the owner's response and its date, place id, the place's URL, the reviewer's name; never the reviewer's profile, photo or id; plus the run's cost (estimated when the provider does not report it) | Same |
| `find_ads` | `business`: its bare website domain (or brand name), and its own Facebook page URL when known | Google: advertisers matched (name, legal name, advertiser id, URL, approximate ad count, verified), none meaning no Google ads found; Facebook, only when a page URL was given: the page's ad count and whether the count is complete; plus each run's cost (estimated when the provider does not report it) | Same |
| `find_jobs` | `company`, `location` (city, state, country) | open listings: title, date posted, employer, city, URL; none is a valid "no open listings" result; plus the run's cost (estimated when the provider does not report it) | Same |
| `read_site` | `url` (the website the Maps listing gives) | per page read: URL, title, and the page as markdown with its links, nav and footer kept; plus the run's cost (estimated when the provider does not report it) | Same |
| `find_profiles` | `name` (the person's), `business`, `city`, `platforms[]` (from `linkedin`, `instagram`, `facebook`, `tiktok`) | candidates: platform, URL, display name, bio, location, external links, current employer (when the source gives one), emails found for the person (a free-mail address included); none is a valid "no profile found" result; plus the run's cost (estimated when the provider does not report it). A platform the tool serves with no actor returns no candidates; the tool's usage says which | Same |
| `read_profile` | `url` (a public profile URL already found) | the same fields as one `find_profiles` candidate, for that profile; plus the run's cost (estimated when the provider does not report it). A platform the tool has no reader for is not read; the tool's usage says which | Same |
| `search_pages` | `query` (the business's name and city) | results: title, URL, domain, snippet, and the publication date and publisher when the engine gives them; none is a valid result; plus the call's cost (estimated) | Same |
| `fetch_page` | `url` (https, a public host, a path with no query or fragment) | the page: final URL, title, structured data (JSON-LD), and the page as markdown; plus the call's cost (estimated) | Same |
| `find_listing` | `directory` (`bbb` or `yellowpages`), `query` (the business's name, or a trade when sourcing), `location` (city, state) | BBB: name, rating, accredited, years in business, complaint counts, review count, email, website, phone, principal contacts (name, title), profile URL. YellowPages: name, claimed, rating, review count, phone, website, email, categories, listing URL. None is a valid "no listing" result; plus the run's cost (estimated) | Same |

Each call is a ledger `step` (`capabilities/ledger/contract.md`) with its
cost in `cost_usd`; an operation that makes two provider calls, such as
`find_ads`, records a step for each. A guard block on a scraping call skips that source for the lead
(the run goes on with the other sources) and is never retried with
changed arguments; the tool's usage says how drift and blocks are
reported.

## Invariants

- `no_external_send` — the scraper never sends a message to anyone.
- `allowlisted_actors` — only the actors the tool names run.
- `pinned_inputs` — every input that limits a call's size comes only from
  values pinned in `bindings/scraping.md` at interactive setup.
