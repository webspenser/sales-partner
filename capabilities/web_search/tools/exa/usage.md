# Web search — Exa tool

Searches the web through Exa's hosted MCP server, connected as a claude.ai
connector. `exa:` below means the connected Exa server's tools, whatever
their prefix (with a claude.ai connector named `ExaSearch`,
`mcp__claude_ai_ExaSearch__`).

- `search_web` — `exa:web_search_exa` with `query` only. Exa sends its
  recommended request (`type: auto`, highlights on) and returns up to 10
  results. Do not pass `numResults`; the guard refuses it. A query may
  start with `category:people` or `category:company` to search only
  Exa's people or company index, but the general index found far more
  owners in testing, so the decision-maker search does not use one.

The decision-maker query (`find-decision-makers`):
`owner or principal of <business name>, <trade> at <street address>, <city> (<domain>)`.
Leave out the domain when the lead has no website. The query says what
to find; which results count is decided afterwards by the skill's source
rules, never by words in the query.

## Results

Each result has a title, a URL, a published date when Exa knows one, and
highlights: the passages of the page that answer the query. Read the
people a page names from its highlights, and grade each by that page's
URL (`find-decision-makers`, Source strength). An `exa.ai/library/person`
URL is Exa's own profile page; when it carries contractor licence data
(a licence number, "Responsible Managing Officer"), it counts as a
licence record.

## Cost

About 0.007 USD per `search_web` call (measured 2026-10-31: ten searches
with highlights cost 0.07 USD). The connector does not report cost, so
each call's ledger `step` records this estimate in `cost_usd`.

## Setup

Exa is optional. Bind it only when the business has an Exa account.

1. Get an Exa API key at https://dashboard.exa.ai/api-keys (or use Exa's
   sign-in, if the connector offers it).
2. At claude.ai, Settings → Connectors → Add custom connector: name it `ExaSearch`
   (one word: the guard and the schedule check look for `exasearch` in
   the connector's name), URL `https://mcp.exa.ai/mcp?tools=web_search_exa`.
   The `tools` parameter turns on only the search tool, so the model is
   never offered Exa's page fetch or research agent (the guard would
   block them, and a block stops the run). Put the key where the
   connector form asks for it, or append it to the URL as
   `&exaApiKey=<key>` if it has no field for it. The key lives only in
   the connector: never in this instance, its bindings, or a file.
3. Re-run setup's tools step and answer yes for web search; it adds
   `bind_web_search: exa` to `instance.yaml`.
4. For scheduled runs, re-run the schedule skill and attach the
   `ExaSearch` connector to the routine that runs prepare.

No other connector's name or tool name may contain `exasearch`: the guard applies
this policy to any MCP tool whose name contains it, and blocks every
tool but `web_search_exa`. In setup's tools step, list the session's
tools that contain `exasearch` and stop if any is on another server.

## Probe

Call `exa:web_search_exa` once with
`owner or principal of <the operator's own business>, <its trade> at <its address>, <its city>`.
The call must return results with highlights. It records nothing in
`bindings/web_search.md`: the policy pins no values.
