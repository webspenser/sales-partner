# Web search contract

How the agent searches the web through an outside search engine, for
facts its other sources miss. Today one skill uses it: `find-decision-makers`
finds a lead's owner or principal with it. Skills and sub-agent contracts
call these operations, never a provider's tools.

The capability is optional (`optional_prepare` in `agent.yaml`): a skill
checks `instance.yaml` for a `bind_web_search` line first and skips the
step when there is none.

## Operations

| Operation | Arguments | Returns | On failure |
|---|---|---|---|
| `search_web` | `query`: what to find, in plain words, with the business's name, trade, street address, city and website domain when the search is about one business | up to 10 results, each with title, URL, published date when known, and highlights (the passages of the page that answer the query); plus the call's cost (estimated, since the provider does not report it) | Retried once; then a ledger `step` with outcome `failed` |

Each call is a ledger `step` (`capabilities/ledger/contract.md`) whose
`detail` starts with `search_web`, with its cost in `cost_usd`. Its spend
is not scraping spend: the Preparer's Apify caps leave it out. A guard
block on a web search call stops the activity and calls
`notify_owner(kind: error)` naming the block; it is never retried.

## Invariants

- `no_external_send` — the search engine never sends a message to anyone.
- `allowlisted_tools` — only the search tool the tool names runs; the
  provider's research agents, advanced search and page fetch do not.
- `default_result_count` — no call sets a result count, so the
  provider's default (10) applies.
