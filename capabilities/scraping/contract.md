# Scraping contract

How the agent reads public business listings, contact details, reviews,
ads, job listings and website pages through an outside scraper. Skills and sub-agent contracts call these
operations, never a provider's tools.

## Operations

| Operation | Arguments | Returns | On failure |
|---|---|---|---|
| `find_businesses` | `query`, `location` (city, state, country) | listings: name, address, coordinates (lat, lng), phone, website, category, rating, review count, per-star review counts (one to five stars), opening hours (per day), claimed (true or false), temporarily closed (true or false), place id, URL; plus the run's cost (estimated when the provider does not report it) | Retried once; then a ledger `step` with outcome `failed` and an `error` event |
| `find_contacts` | `urls[]`, at most 10 per call | per URL: emails, phones, social links; plus the run's cost (estimated when the provider does not report it) | Same |
| `find_reviews` | `place` (the listing's place id) | reviews: text, date, stars, the owner's response and its date, place id, the place's URL; never the reviewer's name or profile; plus the run's cost (estimated when the provider does not report it) | Same |
| `find_ads` | `business`: its bare website domain (or brand name), and its own Facebook page URL when known | Google: advertisers matched (name, legal name, advertiser id, URL, approximate ad count, verified), none meaning no Google ads found; Facebook, only when a page URL was given: the page's ad count and whether the count is complete; plus each run's cost (estimated when the provider does not report it) | Same |
| `find_jobs` | `company`, `location` (city, state, country) | open listings: title, date posted, employer, city, URL; none is a valid "no open listings" result; plus the run's cost (estimated when the provider does not report it) | Same |
| `read_site` | `url` (the website the Maps listing gives) | per page read: URL, title, and the page as markdown with its links, nav and footer kept; plus the run's cost (estimated when the provider does not report it) | Same |

Each call is a ledger `step` (`capabilities/ledger/contract.md`) with its
cost in `cost_usd`; an operation that makes two provider calls, such as
`find_ads`, records a step for each. A guard block on a scraping call stops the activity
and calls `notify_owner(kind: error)` naming the block; it is never
retried.

## Invariants

- `no_external_send` — the scraper never sends a message to anyone.
- `allowlisted_actors` — only the actors the tool names run.
- `pinned_inputs` — every input that limits a call's size comes only from
  values pinned in `bindings/scraping.md` at interactive setup.
