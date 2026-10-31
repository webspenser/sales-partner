# Exa connector probe — 2026-10-31

A temporary, disabled cloud routine on the operator's environment, with
every claude.ai connector attached, listed the session's tools and made
one `web_search_exa` call about the operator's own business. No key or
lead data is recorded here.

## Connector

- Name `ExaSearch`, URL `https://mcp.exa.ai/mcp?tools=web_search_exa`,
  key held by the connector.
- Tool names: `mcp__ExaSearch__web_search_exa` in a cloud routine;
  `mcp__claude_ai_ExaSearch__web_search_exa` in a local Claude Code
  session with claude.ai connectors. Both contain `exasearch`
  (`server_match`) after `mcp__`, lowercased.
- The connector exposes only `web_search_exa`: the `tools` parameter took
  effect, so `web_fetch_exa` and `agent_run` are not offered.

## Collision check

Tools in the session whose name contains `exa`, any case:

- `mcp__ExaSearch__web_search_exa`
- `mcp__Exa__web_search_exa`, `mcp__Exa__web_fetch_exa`,
  `mcp__Exa__agent_run` — a second, older connector named `Exa` on the
  same account, with Exa's default tools.

Only the first contains `exasearch`, so the guard applies the Exa policy
to nothing else. The `Exa` connector is not guarded by this policy and
must not be attached to a routine: `verify` refuses it (its name does
not contain any bound `server_match`).

## web_search_exa

- Input: `query` (string, required), `objective` (string, required),
  optional `numResults` (number). The policy allows `query` and
  `objective`. (This probe asked for the schema but its answer was not
  read; the first scheduled run on 8.2.0 found `objective` required when
  the guard refused it. Fixed in 8.2.1.)
- A call with only `query` succeeded in about one second.
- The result is text, one block per result: `Title:`, `URL:`,
  `Published:`, `Author:` and `Highlights:` (the passages that answer the
  query, as markdown). The first result for the operator's own business
  was its owner's LinkedIn profile, with name, title and business in the
  highlights.
