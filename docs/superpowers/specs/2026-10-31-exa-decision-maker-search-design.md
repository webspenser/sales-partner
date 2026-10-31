# Exa web search for decision-makers — design

Date: 2026-10-31. Scope: the Exa capability lives in sales-partner
only; if a later agent needs Exa, it moves into the builder then.
agent-builder gets one generic change, optional capabilities in an
activity (below), because Exa must be optional and still run unattended.

## Why

The Preparer often finishes a lead with no decision-maker. Of 30
researched leads on 2026-10-31, 16 had nobody named. A throwaway test
ran Exa web search on all 30. Its raw results hold real people's names,
so they are kept outside this public repository, on the maintainer's
machine (`live-agents/exa-test-2026-10-31/`), as the baseline for the
smoke test.

- For the 16 with nobody, Exa named a likely owner or principal for 8,
  several from strong sources: a contractor licence record, BBB, the
  company's own team page, Diamond Certified.
- For the 14 where the agent had found someone, Exa named the same
  person every time, and often added a missing surname (an owner known
  from reviews only by first name), a co-owner, or the legal name from
  a licence record.
- Cheap aggregator directories (unitedcars.us, uslocaldir.com,
  smallbusinessbay.com, `*.engineering-us.org` / `*.personal-us.org`)
  produced stale or conflicting names. Strong sources did not.
- Exa's people index alone added little; the general web index did the
  work. Cost: about $0.007 per search.

Exa is not used to find leads: Apify's Google Maps scraper stays the
source of leads, because Exa has no listing data (hours, reviews,
claimed status).

## Goals

- During research, find the owner or principal of a lead with one Exa
  web search, and record what it finds through the existing
  `find-decision-makers` rules.
- Treat names by source strength (below), so weak directories never
  produce a verified decision-maker.
- Exa is optional (the user's decision): a business without Exa runs
  every activity, scheduled or not, exactly as today. A business that
  has Exa connected gets the enrichment in its scheduled runs too: the
  prospect routine runs prospect, then prepare, and prepare is where
  decision-makers are researched.
- Work the same in scheduled cloud runs as interactively.

## Non-goals

- No change to how leads are found (Apify `find_businesses` stays).
- No use of Exa for the rest of company research (news, offers,
  evidence) in this release. `research-company` keeps its sources.
- No Exa Agent API (`agent_run`), advanced search, or page fetch.
- No Exa capability in agent-builder or the template; the only builder
  change is the generic optional-capability rule below.
- No `EXA_API_KEY` environment variable anywhere in the agent, its
  setup, or its docs (the user's decision: connectors only). The key
  the user stored for the test stays on their machine and is not used.

## Anti-goals (would make this a failure even if it works)

- A directory-only or conflicting name written as a verified
  decision-maker.
- A scheduled run blocked or failed because the Exa connector is
  missing: research must carry on without it.
- Unbounded spend: more than one Exa search per lead per run, or result
  counts above Exa's default 10.

## Decided

**Connector, not a script (the user's decision).** Exa is reached only
through Exa's hosted MCP server added as a claude.ai connector, the same
way as Apify, Attio, Airtable and Resend. That keeps the schedule
checker (one connector per bound capability) and the guard (which sees
only MCP calls) working unchanged, and needs no network allowlist change
or network secret in the cloud environment. The key lives in the
connector (Exa supports `?exaApiKey=` on the URL, an `x-api-key` or
Bearer header, or OAuth); which one the user picks at claude.ai is a
setup detail, not part of the package.

**The tool is `web_search_exa`.** Exa's connector exposes
`web_search_exa` and `web_fetch_exa` by default. `web_search_exa` sends
exactly the request Exa's own guidance recommends (`query`, `type:
auto`, `contents: {highlights: true}`), takes `query` and an optional
`numResults`, and accepts `category:people` or `category:company` inside
the query. It returns results with title, URL and highlights. It does
not return Exa's structured output; the Preparer reads the highlights
and applies the source rules itself. (The test used Exa's structured
output; this difference is checked in the smoke test below.)

## The capability

A new capability, **`web_search`**, with one tool, **`exa`**
(`capabilities/web_search/tools/exa/`, `server_match: exa`).

- **Operation `search_web(query)`**: returns up to 10 results, each
  with title, URL, published date when known, and highlights; plus the
  call's cost (estimated, since the connector does not report it). On
  failure: retried once, then a ledger `step` with outcome `failed`,
  as for scraping.
- **Invariants**, each covered by the tool's `guard.yaml` so scheduled
  runs pass the gate:
  - `no_external_send` — the tool never sends anything.
  - `allowlisted_tools` — only `web_search_exa` runs. `agent_run`,
    `web_search_advanced_exa`, `web_fetch_exa` and anything else on the
    server are blocked.
  - a bound on call size: `numResults` is never above 10. Builder's
    choice whether this is the reserved `pinned_inputs` (a value pinned
    in `bindings/web_search.md`, like Apify's `max_places`) or a fixed
    cap in the policy; either way the agent cannot raise it.
- Each call is a ledger `step` with `cost_usd`, like scraping. A guard
  block stops the activity and notifies the owner, as for scraping.
- **Spend (my call).** Exa calls do not count toward the Apify caps
  (`apify_cap_usd_per_lead`, `apify_spend_cap_usd_per_week`): the
  Preparer's cap sums are limited to scraping steps. Exa needs no cap
  of its own: one search per lead and the research quota bound it
  (25 leads is about $0.20 a run). When an Apify cap stops scraping,
  Exa keeps running, since it is part of web search.

`web_search` is generic on purpose: later work (company research, other
agents) can call `search_web` without a new capability.

## Where it is used

In `find-decision-makers`, step 2, for every lead the Preparer
researches:

1. One `search_web` call, before the other sources. Query: the owner or
   principal of the business, with its trade, street address and city,
   and its website domain when known (the test's form: "owner or
   principal of <business name>, <trade> at <street address>, <city>
   (<domain>)"). Retrieval intent only; no keep/drop rules in the query.
   One search per lead per run: a retry after a failed call is the same
   search, and a later continue run on the same lead does not search
   again if the first one succeeded.
2. The other sources in step 2 then run as today; they can confirm or
   contradict what Exa found.

**Source strength.** Every person `find-decision-makers` records,
whatever found them (Exa, the company site, the map listing, the
Preparer's other web searches), is classified by the page that names
them. The same weak directories show up in the other web searches, so
an Exa-only rule would leave the gap open (builder check; my call):

- **Strong:** the business's own website; a state licence record
  (including Exa's `exa.ai/library/person` entries that carry contractor
  licence data); BBB; a bar or trade association profile; Diamond
  Certified; a LinkedIn profile whose current role is at this business.
- **Weak:** any other directory or aggregator page.

Rules:

- A strong source alone may support `Verified` (step 6 is unchanged:
  `Verified` still needs a contact route the source confirms).
- A weak source alone: the person may be written, with `Verified`
  unchecked and `Notes` naming the source as `directory only`.
- Two sources naming different people as owner: write both, unverified,
  with `Notes` saying `conflicting sources` and both URLs. (The test hit
  this once: a trade directory and a scraped aggregator named different
  owners for the same auto shop.)
- Names only from similarly named businesses elsewhere are ignored.
- Every person keeps the source URL in `Notes`, as today.

The Approach score's "Decision-maker reachable" criterion is unchanged;
it already distinguishes a named owner from a reachable one.

## Optional capabilities (agent-builder change)

Today an activity lists capabilities that must all be bound and fully
guarded, or the schedule gate refuses it, and `verify` requires one
connector per bound capability. Neither allows "use it if present".
The Standard gains optional capabilities per activity:

- `agent.yaml` names them separately from the required ones. My call on
  the form: a flat key `optional_<activity>: web_search` next to
  `activity_<activity>`, listing names from `capabilities`, never a name
  the activity already requires. The validator checks it like
  `activity_*`.
- **Unbound optional capability:** the gate passes the entry as if it
  were not listed; `check` prints it as `optional, not bound`; no
  connector is expected, and `verify` still refuses a connector that
  matches no bound `server_match` (so an Exa connector attached without
  the binding stays refused, because nothing would guard it).
- **Bound optional capability:** exactly the rules for a required one:
  every contract invariant covered by its tool's `guard.yaml`, and its
  connector attached to the routine.
- The guard needs no change: it already applies a tool's policy only
  when the capability is bound.
- Skills that use an optional capability check the binding first and
  skip the step when it is unbound.

This ships as a builder release (a new manifest key, so the Standard
moves to 7.4 and sales-partner follows), merged before the
sales-partner release.

## If Exa is not available

If `web_search` is not bound, `find-decision-makers` skips the Exa step
and runs as today. This is not an error. If it is bound but a call
fails, the call is retried once, then recorded as a failed ledger
`step`, and research carries on without it. A guard block on an Exa
call is handled like any guard block (stop and notify), because it
means a call the policy refuses.

## Setup and rollout

- Setup's tools step binds `web_search` to `exa` like any capability;
  `usage.md` `## Setup` tells the user to add Exa's hosted MCP server as
  a claude.ai connector whose name contains `exa`; `## Probe` makes one
  read-only `web_search_exa` call on a known business.
- `agent.yaml`: `web_search` added to `capabilities` and as
  `optional_prepare: web_search` (prospect and digest do not use it).
- Release: sales-partner minor bump (8.2.0), with an upgrade note.
- Setup's tools step offers optional capabilities as optional: it asks
  whether the business has the system, and binds it only on yes.
- Live instance (the user has Exa): re-run setup's tools step (adds
  `bind_web_search: exa`), then the schedule skill: the prospect routine
  (it runs prospect, then prepare) gets the Exa connector attached,
  `verify` passes, `agent_version` and the environment's version comment
  move to 8.2.0.
- Smoke test after rollout: one prepare run on a handful of leads,
  compared with the saved baseline, to check that reading highlights
  gives the same names as Exa's structured output did. Pass (my call):
  the run names the strong-source owner for the leads where the test
  found one (four of them). If it finds fewer, the release still stands
  (it is never worse than today) and the gap is reported to the user,
  who can then decide whether to allow `web_search_advanced_exa`.

## Left to the builder

- The exact `guard.yaml` (allow list, the size bound's form) and the
  probe notes for the connector's real tool and server names, read from
  a live connector before writing the policy.
- The cost estimate per call and how it is recorded.
- Wording in the skill, `usage.md` and the contract, and test coverage,
  following the repo's existing patterns for Apify.
