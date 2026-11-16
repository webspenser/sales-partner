# Sales Partner MCP adapter — design

Date: 2026-11-16. Status: approved by the owner 2026-11-16. Target: sales-partner
9.0.0.

## Why

Scheduled runs keep failing on changes nobody controls. On 2026-11-16 the
Apify connector moved `vdrmota/contact-info-scraper` from an actor-run
tool to an HTTP-shaped tool (`POST /` with one `body.url`). The guard,
which checks each actor's own input shape, blocked every call, and most
leads got no point of contact. The same run lost Indeed (each call
returned a ~100 KB schema into the agent's context), got unrelated jobs
back from the LinkedIn jobs actor (it ignores `companyName`), and ran out
of session after 7 of 25 leads. Earlier, the Compass reviews outage
(8.5.1) was the same class: a vendor change broke the run.

Today every actor's shape is known in three places at once: the guard
(`guard.yaml`), the model's mapping (`usage.md`), and the cloud
environment's installed plugin version. Any vendor change needs a plugin
release, an environment upgrade, and an `agent_version` bump before the
next Monday run works. That is a software problem, not an AI problem.

The fix is an adapter: a Webspenser-owned MCP server that exposes the
scraping contract's operations as stable tools and owns every
vendor-specific detail behind them. Vendor changes are fixed once, in the
server, without touching the plugin or any instance.

## What success looks like

- 30 consecutive days of scheduled runs where scraping and research
  complete. A failing provider is skipped and noted (or replaced by its
  backup); it never blocks or stops a run.
- Once that holds, the owner moves from one large Monday run to smaller,
  more frequent ones (for example, find 10 Monday, research 10 Tuesday,
  find 10 Wednesday, research 10 Thursday). This design must not assume
  one weekly run; the cadence change itself is later work.

## Goals

1. **Stable interface.** One MCP tool per scraping contract operation,
   with exactly the contract's inputs and outputs:
   `find_businesses`, `find_contacts`, `find_reviews`, `find_ads`,
   `find_jobs`, `read_site`, `find_profiles`, `read_profile`,
   `search_pages`, `fetch_page`, `find_listing`
   (`capabilities/scraping/contract.md`). The agent never sees an actor,
   an actor input, a dataset id or a run id.
2. **Providers behind operations.** Each operation has an ordered list of
   providers: a primary and, where one exists, a backup. A provider can be
   an Apify actor (called through the Apify REST API with a pinned
   `build`), a plain HTTP service, or a built-in n8n node. The owner can
   reorder, swap or add providers without a plugin release.
3. **Per-call resilience in the server.** Retries with a set limit,
   failover from primary to backup, and normalization of each provider's
   output to the contract's fields (n8n's own retry and output-repair
   features may be used here). Results come back trimmed to the contract
   fields, never as raw provider output.
4. **Proactive repair.** A separate Claude agent (the "hygiene agent")
   checks every provider on a schedule, repairs mappings that drifted,
   tests them, publishes them live and reports what it did.
5. **Real costs.** Each tool result carries the provider's actual charge
   when the provider reports one (Apify run usage), else an estimate,
   marked as such. The ledger's `cost_usd` uses it.

## Non-goals (now)

- Serving more than one Sales Partner instance. First and only user:
  Webspenser's own live instance, on Webspenser's Apify account. Multiple
  clients, bring-your-own-key, and how client spend is billed are decided
  after 30 stable days. Owner's call: client-specific settings (keys,
  caps, which providers are enabled) live in their own clearly separated
  part of the server, so adding clients later is not a redesign.
- Composite operations (one `research_business(lead)` call that runs
  everything). Revisit only if research still runs out of session after
  the research step is split.
- The research-step split and the pre-run check in the plugin
  (recommended on 2026-11-16). They follow this work.
- Moving non-scraping capabilities (CRM, ledger, notify, Exa web search)
  behind the server.

## Anti-goals

- An automatic repair that quietly raises a limit, turns on a paid
  add-on, or lets a call reach a URL the contract would refuse.
- Runtime AI deciding a provider's inputs on every call. Live calls stay
  deterministic and cheap; AI is used at repair time, by the hygiene
  agent.
- A server that is a second copy of the plugin's research logic. Which
  sources a lead needs stays the agent's decision.

## Shape

```
Sales Partner (cloud routine)
  └─ guard hook: checks calls to the 11 stable tools
       └─ claude.ai connector (n8n OAuth2)
            └─ n8n: Sales Partner MCP workflow (MCP Server Trigger)
                 ├─ policy layer   (protected: caps, URL rules, refusals)
                 ├─ provider layer (editable: one mapping per provider)
                 └─ state          (n8n Data Table: spend, provider health)
                       └─ Apify REST API / HTTP services / n8n nodes

Hygiene agent (separate Claude routine, every 12 hours)
  ├─ health-checks each provider
  ├─ edits provider mappings only, tests, publishes
  └─ emails the owner a report
```

### The server (n8n)

A new n8n workflow on the owner's n8n instance, with one **MCP Server
Trigger** exposing the 11 tools. Owner's decision: build it new; the
existing "WS Sales Partner Test" connector is unrelated and out of scope.

- **Auth:** the trigger requires **n8n OAuth2**, so the claude.ai
  connector (which scheduled runs use) signs in with no shared secret.
  This matches the Agent Standard's rule for wrapped tools.
- **Policy layer (protected).** Every call passes through it before any
  provider runs. It enforces, independent of the provider:
  - the contract's input rules (https and public URLs, `find_contacts` at
    most 10 URLs, `fetch_page` with no query or fragment, and the rest of
    the contract's input constraints);
  - a per-call maximum spend of $0.50 and a hard weekly ceiling of $20
    across all runs (state in a Data Table). Owner's numbers. The agent
    keeps its own $15 weekly cap and $0.50 per-lead budget, so in normal
    weeks the server ceiling is never reached;
  - the refusals the guard holds today in actor terms: no paid add-ons,
    no proxy settings, no request headers or cookies, no MongoDB or other
    export destinations, personal-data flags as the contract requires.
  A refused call returns a contract-shaped error naming the rule, never a
  provider error.
- **Provider layer (editable).** One sub-workflow per provider per
  operation: it maps contract inputs to a request for that provider, and
  maps the provider's response back to contract fields. It does not send
  the request and holds no credential.
- **Outgoing check (protected).** The policy layer receives each
  provider's built request, checks it against that provider's protected
  entry (the actor id and pinned `build`, or the HTTP host and path; the
  most each size input may be; the options that are refused), and only
  then makes the call itself with the credential. A request that breaks
  its entry is not sent, and the provider counts as failed. Apify actors
  are called through the REST API with the pinned `build`, never through
  the Apify connector.
- **Failover.** A provider that errors, times out, or returns output that
  fails the contract's shape check is retried once, then the next
  provider is tried. A valid empty result ("no listing", "no ads") is a
  result, not a failure. When every provider fails, the tool returns a
  contract error saying the operation is unavailable, and the agent skips
  that source for the lead as it does today.
- **Result envelope.** Every tool returns the contract output plus a
  `calls` list, one entry per provider call the operation made (a failed
  primary included): `provider`, `outcome`, `cost_usd` and whether it is
  actual or estimated. It also returns `degraded` (true when a backup
  answered). My call: the agent writes one ledger `step` per `calls`
  entry. That keeps the contract's existing rule (`find_ads` records a
  step per provider call), and the per-lead budget counts what failed
  attempts cost too.
- **Size limits are server configuration** (my call). Tool inputs are
  exactly the contract's inputs, with no size arguments. Sizes such as
  places per search, reviews per place and pages per site are set in the
  server's per-instance settings, in the protected policy layer. The
  plugin's guard keeps only the rules the contract itself states: URL
  rules and `find_contacts` at most 10 URLs. `pinned_inputs` is restated:
  sizes are pinned in the server's per-instance settings, which only the
  owner edits. The size keys in `bindings/scraping.md` go away in 9.0.0.
- **Ceiling reached** (my call): the server returns a contract error
  `budget_exhausted`. The agent handles it like today's 7-day cap: stop
  scraping for the rest of the run, carry on with research that needs no
  scraping, and say so in the report. The run is not stopped.

### The plugin (sales-partner 9.0.0)

- **New scraping tool folder** (my call: `capabilities/scraping/tools/webspenser/`),
  bound in the instance as the scraping tool. `usage.md` maps each
  operation to one server tool. `guard.yaml` allows exactly the 11
  tools and keeps the contract-level checks that never change (URL rules,
  batch sizes and size caps pinned to bindings). All per-actor rules
  disappear from the plugin.
- **Apify tool folder.** Removed in 9.0.0 (my call): keeping it as an
  alternative would keep the brittle path alive and double the tests. The
  Apify connector is removed from the routine's connectors.
- **Invariants.** `allowlisted_actors` and `pinned_inputs` are restated
  for the adapter: the guard pins the 11 tools and the size inputs; the
  server's policy layer holds which providers may run. Whether
  `allowlisted_actors` stays guard-covered or becomes `(acceptable)` (held
  by the server, outside the guard's view) is a decision for the plan,
  argued against the Agent Standard.
- **Spend.** Agreed split: the server enforces the hard weekly ceiling and
  a per-call maximum as the backstop; the agent keeps the per-lead budget
  (`apify_cap_usd_per_lead`), because how much a lead deserves is a
  research decision. The agent's existing 7-day check from the ledger can
  stay as an early stop.
- **Agent Standard.** No Standard change is expected: the Standard
  already accepts an n8n-wrapped tool with an OAuth2 MCP Server Trigger.
  Open point for the plan: the Standard's "Wrapped tools" rules expect the
  workflow export to ship inside the tool folder as a thin wrapper. This
  server is a Webspenser service that changes without plugin releases, so
  the plan decides between (a) treating it as an external system (no
  `wrapper: n8n`, like Attio), or (b) shipping a snapshot export to
  satisfy the rules. My recommendation is (a).

### The hygiene agent

A Claude Code project living in the `sales-partner-mcp` repository
(owner's decision: not an agent-builder agent), run as a Claude cloud
routine every 12 hours, with its own connectors: the n8n instance-level MCP (to read,
edit and publish workflows) and an email sender for reports.

- **Health check:** one smallest-size call per provider against a fixed
  public business (the probe targets used in development: Franklin
  Barbecue, Austin TX, and a BBB-listed plumber), plus a free comparison
  of each provider's current input schema against the one recorded.
- **Decisions:**
  - primary healthy, unchanged: nothing to do;
  - primary's inputs or outputs changed but it still runs: edit that
    provider's mapping, re-run its health check, publish, report;
  - primary down, backup healthy: mark the primary unhealthy so the
    server goes straight to the backup, report;
  - primary and backup down: email the owner at once as an outage.
- **Boundary:** it may edit only provider-layer sub-workflows (field
  mappings and input format) and mark providers healthy or unhealthy.
  Owner's decision: anything bigger is a proposal emailed to the owner,
  and nothing changes until the owner approves it. That includes a new
  actor or service, a new build, a size above the protected maximum, or
  a refused option. It may not edit the policy layer, the MCP trigger, the
  tool interface, credentials or caps. Enforced by mechanism, not
  instruction: only the provider-layer workflows are enabled for n8n's
  instance-level MCP ("Available in MCP"); the policy layer and the
  trigger workflow are not. My call, as a second layer: the policy layer,
  its Data Tables (spend, caps, provider health) and the credentials sit
  in a separate n8n project. The hygiene agent signs in as its own n8n
  user, which has no access to that project, so n8n's data-table tools
  can't reach the caps either. The plan verifies both mechanisms on the
  real instance before the hygiene agent gets write access.
- **Version history:** each published change is also committed as a
  workflow export to a git repository (my call: a new
  `sales-partner-mcp` repo), so any repair can be diffed and rolled back.
- **Reports:** one email per run that changed something, and an immediate
  email for an outage. Quiet runs send nothing.

## Constraints

- No credentials in the plugin, the instance, or any chat. The Apify key
  is an n8n credential.
- Generic Apify tools (`call-actor`, `api`) stay out of reach of the
  agent; with the connector removed, the agent has no direct Apify path.
- Every contract output rule stays true, including: no reviewer profile,
  photo or id; `find_profiles` returns emails as the contract says.
- The ledger stays the agent's: one `step` per operation call, with the
  envelope's provider and cost in its detail.
- The live instance needs one setup pass to bind the new tool and add the
  connector; `schedules.yaml` `agent_version` goes to 9.0.0.

## Left to the builder

- n8n structure (sub-workflows versus Execute Workflow tools, Data Table
  layout), timeouts for slow actors, retry counts.
- The exact provider list per operation, starting from today's actors and
  dropping those known broken (Indeed; LinkedIn jobs until it honors
  `companyName`).
- **`find_jobs` must work in 9.0.0** (owner's decision: no 9.1 for jobs).
  A replacement jobs provider is researched and probed in parallel with
  the server build, and goes in as `find_jobs`'s primary before cutover.
  It must return a named small business's own current postings for a city,
  not keyword matches.
- Test approach for the server and the hygiene agent.
- Migration order and whether to cut over on a quiet day.
