# Scraping contract

How the agent reads public business listings and contact details through
an outside scraper. Skills and sub-agent contracts call these
operations, never a provider's tools.

## Operations

| Operation | Arguments | Returns | On failure |
|---|---|---|---|
| `find_businesses` | `query`, `location` (city, state, country) | listings: name, address, phone, website, category, rating, review count, place id, URL; plus the run's cost (estimated when the provider does not report it) | Retried once; then a ledger `step` with outcome `failed` and an `error` event |
| `find_contacts` | `urls[]`, at most 10 per call | per URL: emails, phones, social links; plus the run's cost (estimated when the provider does not report it) | Same |

Each call is a ledger `step` (`capabilities/ledger/contract.md`) with its
cost in `cost_usd`. A guard block on a scraping call stops the activity
and calls `notify_owner(kind: error)` naming the block; it is never
retried.

## Invariants

- `no_external_send` — the scraper never sends a message to anyone.
- `allowlisted_actors` — only the actors the tool names run.
- `pinned_inputs` — every input that limits a call's size comes only from
  values pinned in `bindings/scraping.md` at interactive setup.
