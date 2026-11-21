# Sales Partner 9.0.0: scraping through the Webspenser server — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The agent scrapes only through the Webspenser Scraping MCP
server: 11 stable tools, each returning one envelope. Every Apify tool,
rule, binding and mention leaves the plugin.

**Architecture:** A new tool folder, `capabilities/scraping/tools/webspenser/`,
replaces `tools/apify/`. Its guard allows exactly the 11 tools, allowlists
each tool's argument names (`only_keys`) and keeps the URL rules. The
server holds providers, sizes, retries, failover and the hard spend cap.
The agent keeps its per-lead budget and its 7-day early stop. It reads
each tool's envelope and writes one ledger `step` per provider call it
reports. The config keys and source names lose their `apify_` prefix.

**Tech Stack:** A Markdown agent plugin; YAML guard policies enforced by
`hooks/guard_policy.py`; bash test suites (`tests/run-all.sh`); the
builder's validator (`../agent-builder/bin/validate-agent.sh`).

**Spec:** The design is on this repo's local branch `docs/mcp-adapter-design`.
Read it with `git show docs/mcp-adapter-design:docs/superpowers/specs/2026-11-16-sales-partner-mcp-adapter-design.md`,
section "The plugin (sales-partner 9.0.0)". The interface is frozen at
1.0.0, in the sibling repo `../sales-partner-mcp`:
- `interface/INTERFACE.md` is the authority on tools, envelope, errors and ledger;
- `interface/schemas/<tool>.input.json` and `.output.json` give the exact fields;
- `docs/handoff/sales-partner-9.0.0.md` is the handoff brief.

Where the spec and the handoff disagree, the newer handoff and
INTERFACE.md win, because they record what the owner decided after the
spec was written: the server holds sizes. Each such case is listed under
Rulings.

## Global Constraints

- Exactly 11 tools: `find_businesses`, `find_contacts`, `find_reviews`, `find_ads`, `find_jobs`, `read_site`, `find_profiles`, `read_profile`, `search_pages`, `fetch_page`, `find_listing`.
- Server and connector names:
  - `server_match: webspenser_scraping`;
  - tool names in a session: `mcp__claude_ai_Webspenser_Scraping__<tool>`;
  - in `usage.md`, each tool is written `webspenser_scraping:<tool>`.
- Envelope: `{result, error, calls[], cost_usd, cost_kind, degraded}`.
  - `error.code` is one of `input_refused`, `budget_exhausted`, `unavailable`.
  - Each `calls[]` entry is `{provider, attempt, outcome, cost_usd, cost_kind, note}`, with `outcome` one of `ok`, `empty`, `failed`, `timeout`.
- What the agent does with each error code:
  - `input_refused`: skip that source for the lead, and never retry with changed arguments.
  - `budget_exhausted`: stop scraping for the rest of the run, but keep doing research that needs no scraping. The run is not stopped.
  - `unavailable`: skip that source for the lead.
  - `degraded: true`: use the result.
  - An empty `result` is a valid answer.
- The agent never retries a tool call itself. The server already retries once and fails over.
- Spend:
  - The server enforces $20 per 7 days and $0.50 per provider run.
  - The agent keeps `scraping_cap_usd_per_lead` (default `0.50`) and `scraping_spend_cap_usd_per_week`. The template default for the weekly key is `15`: the agent should stop before the server's $20 does.
- The root `guard.yaml` stays as it is. It must still deny `*_workflow*`.
- Do not attach the `N8N Webspenser Newsletter` connector to the routine.
- No credentials in any file.
- `AGENT.md` stays at or under 5983 bytes, its current size.
- Done means all three:
  - `bash tests/run-all.sh` ends `ALL GREEN`;
  - `../agent-builder/bin/validate-agent.sh . --require-bump origin/main` passes;
  - `grep -rli apify --exclude-dir=.git --exclude-dir=docs .` lists only the files Task 7 allows.
- Version `9.0.0` in `agent.yaml`, `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, `gemini-extension.json` and README `Version 9.0.0.`. `standard: "7.5"` is unchanged.

## Rulings made while planning

1. **`allowlisted_actors` becomes `allowlisted_tools` and stays covered by the guard.**
   - New text: "only the tools the bound tool names run; which providers serve each tool is held by the scraping server, outside the guard's view."
   - The guard's exact `allow` list of 11 enforces it.
   - Why not `(acceptable)`: the gate would then need `accept_instruction_only` in the instance and would print ACCEPTED on every run. Nothing the plugin can see would be held by instructions alone, so that warning would be noise.
   - Cost if wrong: one id rename.
2. **`pinned_inputs` leaves the scraping contract.**
   - The 11 tools take no size input; the server holds sizes and drops unknown keys.
   - Keeping the invariant would force a `recipients` entry on every allowed tool (`tool_check.py`), pinning values that don't exist. It cannot be marked `(acceptable)`.
   - The size guarantee moves to the server's per-run maximum and 7-day cap (INTERFACE.md Safety model 1–2), plus the guard's `only_keys`, which refuses any size key the agent might send.
   - `find_contacts` ≤ 10 URLs is enforced by the server's schema (`maxItems: 10`), not by the guard: a guard count would need a pushed bindings file again.
   - This departs from the spec line "size caps pinned to bindings" and follows the handoff ("the size keys in `bindings/scraping.md` go away").
   - Cost if wrong: re-add one `limits` entry and one binding.
3. **`only_keys` instead of the retrieval profile.**
   - The interface is ours and frozen, so an argument allowlist no longer breaks on a vendor change. It is the Standard's recommended form.
   - A key outside the contract (a size, an actor option) is blocked before it leaves the session, not just silently dropped by the server.
4. **Webspenser is an external system, not `wrapper: n8n`.**
   - No `workflow.n8n.json` ships, and `identity.yaml` has no `wrapper` key.
   - This follows the spec's recommendation (a) and the MCP repo's `docs/decisions/0001-external-system.md`.
   - The server changes without a plugin release; a snapshot export would be stale on day one.
5. **Renames, with the 7.2 precedent.**
   - Every `apify_` source and cap key loses its prefix (table in Task 2).
   - A config that still lists an old name stops the run with `<old> was renamed <new> in 9.0.0`, as `apify_site_scraper` does today.
   - Setup's upgrade pass rewrites the instance's config, so the stop is reachable only by a hand edit. A 9.0.0 routine can't run before setup anyway: `agent_version` must match.
6. **Pre-call estimates stay in the plugin; the envelope's cost is what gets recorded.**
   - The per-lead check needs a worst case before the call, so `webspenser/usage.md` `## Cost` lists one per tool at the server's sizes (Task 1).
   - After the call, the lead total and the 7-day sum use the envelope's `cost_usd`, not the estimate.
   - Cost if wrong: an estimate drifts from the server's sizes and the per-lead stop trips early or late by at most one call.
7. **`max_web_fetches` moves to `operating-config.md` as `max_web_fetches_per_lead` (default 5).** It was a binding the guard never read, and bindings/scraping.md goes away.
8. **README keeps only the 9.0.0 upgrade note for scraping.** The 8.x notes ("Upgrading from 8.0" through "8.6.0") describe Apify connector URLs that no longer apply and are removed. Git history keeps them.

## Review Focus

1. **A provider fails over** (`degraded: true`, two or more `calls[]` entries).
   - Expected: one ledger step per entry, the failed one included with its cost.
   - The lead and 7-day totals add the envelope's `cost_usd` once.
   - Pinned by the Task 3 and Task 4 content tests.
2. **`budget_exhausted` mid-lead.**
   - Expected: no further scraping call in that run, from any lead, in the Prospector or the Preparer.
   - Leads already being researched finish with what they have. Their stage reason starts `research capped by the scraping server's 7-day cap; …`.
   - One `stop_condition` event.
   - Pinned by Task 4 tests and an eval case.
3. **A key outside the contract is sent** (`maxItems`, `waitSecs`, `actorId`, a nested `location.radius`).
   - Expected: the guard blocks it with `may not use`.
   - Pinned by Task 1 policy tests, one per tool.
4. **A URL with a query string or a non-root path** sent to `find_contacts` or `read_site`.
   - Expected: blocked. The agent strips it first (usage.md "Website and Facebook URLs", kept).
   - Pinned by Task 1 policy tests.
5. **An 8.7 config left unchanged** (`apify_cap_usd_per_lead` present, `scraping_cap_usd_per_lead` absent).
   - Expected: the run stops with the rename message and never runs at the default.
   - Pinned by Task 2 content tests.

---

### Task 1: The webspenser tool folder replaces the Apify folder

**Files:**
- Create:
  - `capabilities/scraping/tools/webspenser/identity.yaml`
  - `capabilities/scraping/tools/webspenser/guard.yaml`
  - `capabilities/scraping/tools/webspenser/usage.md`
- Delete: `capabilities/scraping/tools/apify/` (all three files)
- Modify:
  - `capabilities/scraping/contract.md`
  - `tests/test-policies.sh` (replace the `-- scraping (apify)` section)
  - `tests/test-schedules.sh` (`scrape()`)
  - `tests/test-content.sh` (every assertion on `$SUD`, the Apify usage path)

**Interfaces:**
- Produces:
  - tool folder `webspenser` with `server_match: webspenser_scraping`;
  - contract invariants `no_external_send` and `allowlisted_tools`;
  - usage sections `## Envelope`, `## Website and Facebook URLs`, `## Drift`, `## Cost`, `## Setup`, `## Probe`;
  - the `## Cost` table that Tasks 3 and 4 cite by name.

- [ ] **Step 1: Write the failing policy tests.**
  - Replace the `-- scraping (apify)` section with `-- scraping (webspenser)`, with `AG2=capabilities/scraping/tools/webspenser/guard.yaml`, `P=mcp__claude_ai_Webspenser_Scraping__` and `SM=webspenser_scraping`, and no bindings argument (`-`).
  - Cases, each `check <rc> <label> ...`:
    - `check 0` for one valid input per tool:
      - `find_businesses {"query":"HVAC contractor","location":{"city":"Alameda","state":"CA","country":"US"}}`;
      - `find_contacts {"urls":["https://example.com"]}`;
      - `find_reviews {"site":"google","place":"ChIJ123"}` and `{"site":"yelp","url":"https://www.yelp.com/biz/joes-plumbing"}`;
      - `find_ads {"business":"example.com","facebook_page_url":"https://www.facebook.com/joes/"}`;
      - `find_jobs {"company":"Bell Bros Plumbing","location":{"city":"Hayward","state":"CA","country":"US"}}`;
      - `read_site {"url":"https://example.com/"}`;
      - `find_profiles {"name":"Dana Ruiz","business":"Joe's","city":"Oakland","platforms":["linkedin"]}` and `{"company_url":"https://www.linkedin.com/company/joes","roles":["owner"]}`;
      - `read_profile {"url":"https://www.instagram.com/joes"}`;
      - `search_pages {"query":"Joe's Plumbing Oakland"}`;
      - `fetch_page {"url":"https://example.com/about"}`;
      - `find_listing {"directory":"bbb","query":"Joe's Plumbing","location":{"city":"Oakland","state":"CA"}}`.
    - `check 2 "<tool> extra key <k>"`, expecting the text `may not use`:
      - `maxItems`, `waitSecs` and `actorId` on every tool;
      - `location.radius` on `find_businesses`, `find_jobs` and `find_listing`.
    - `check 2`, URL rules:
      - `find_contacts` `https://example.com/about`, `http://example.com`, `https://example.com/?a=1`, `https://localhost`;
      - `read_site` `https://example.com/page`;
      - `fetch_page` `https://example.com/a?b=1` and `https://example.com/#x`;
      - `read_profile` `https://evil.example/in/x`;
      - `find_ads` `facebook_page_url` `https://fb.com/joes`;
      - `find_reviews` `url` `https://www.yelp.com/search?q=x`;
      - `find_profiles` `company_url` `https://www.linkedin.com/in/someone`.
    - `check 2 "not in the allow list"` for `${P}execute_workflow`, `${P}call-actor` and `${P}find_everything`.
  - In `tests/test-schedules.sh`, `scrape()` becomes: write `bind_scraping: webspenser` and no `bindings/scraping.md`.
  - Delete the `noscrape-$key` loop (lines 82–91): there are no pinned scraping keys left.
  - Add one test: a `bind_scraping: apify` instance fails the gate, with text containing `apify` (the tool folder is missing).
- [ ] **Step 2: Run them and confirm they fail.**
  - Run: `tests/test-policies.sh 2>&1 | grep -c FAIL` and `tests/test-schedules.sh`.
  - Expected: FAIL lines for every webspenser case (`guard.yaml` missing).
- [ ] **Step 3: Write `identity.yaml` and `guard.yaml`.**
  - `identity.yaml` has three lines: `capability: scraping`, `provider: webspenser`, `server_match: webspenser_scraping`.
  - `guard.yaml`:
    - a header comment saying what the server holds and what the guard holds, citing INTERFACE.md "Plugin guard duties";
    - `covers: [no_external_send, allowlisted_tools]`;
    - `allow`: the 11 tool names;
    - `only_keys`, one item per tool at `["$"]`, keys from the input schemas:
      - `find_businesses [query, location]`
      - `find_contacts [urls]`
      - `find_reviews [site, place, url]`
      - `find_ads [business, facebook_page_url]`
      - `find_jobs [company, location]`
      - `read_site [url]`
      - `find_profiles [name, business, city, platforms, company_url, roles]`
      - `read_profile [url]`
      - `search_pages [query]`
      - `fetch_page [url]`
      - `find_listing [directory, query, location]`
    - plus one item at `[location]`, for `find_businesses`, `find_jobs` and `find_listing`: `[city, state, country]`.
    - `urls`:

      | Tools | `at` | Rule |
      |---|---|---|
      | `find_contacts` | `"urls[]"` | https, public, `root`, required |
      | `read_site` | `url` | https, public, `root`, required |
      | `fetch_page` | `url` | https, public, `any`, required |
      | `read_profile` | `url` | https; `[www.linkedin.com, linkedin.com, www.instagram.com, instagram.com, www.tiktok.com, tiktok.com, www.facebook.com, facebook.com]`; `any`; required |
      | `find_ads` | `facebook_page_url` | https; `[facebook.com, www.facebook.com]`; `any` |
      | `find_reviews` | `url` | https; `[www.yelp.com]`; `/biz` |
      | `find_profiles` | `company_url` | https; `[www.linkedin.com, linkedin.com]`; `/company` |

      Query and fragment stay at the default `forbid` everywhere.
- [ ] **Step 4: Write `usage.md`.**
  - **Intro:** one paragraph. The Webspenser server runs every operation for this instance. `webspenser_scraping:` means the `Webspenser Scraping` connector's tools. The agent sends each operation's contract arguments as plain fields and nothing else.
  - **One bullet per operation:** `- \`find_jobs\` — \`webspenser_scraping:find_jobs\`. Send \`company\` and \`location\` {\`city\`, \`state\`, \`country\`}.`
    - Copy each tool's arguments from the input schemas.
    - Copy the result fields the agent reads from the `.output.json` files.
    - Copy the per-operation notes from the handoff's "Behavior the agent should expect":
      - Maps returns up to 20 places per search, so run more searches (other terms, neighborhoods) for more;
      - `find_profiles` searches LinkedIn only;
      - `read_profile` reads LinkedIn, Instagram and TikTok, and returns `profile: null` for Facebook;
      - `find_jobs` returns only that employer's postings, and an empty list is "no open jobs";
      - a call can take up to about 105 s.
    - Keep the contract output rules verbatim from the Apify file's Results section: no reviewer profile, photo or id; first name only in findings; never keep follower counts, posts or videos; a private profile has only its URL.
  - **`## Envelope`:** the shape and the agent rules from Global Constraints, verbatim. Ledger: one `step` per `calls[]` entry:
    - its `cost_usd`;
    - `detail` `<tool> via <provider>: <outcome> (attempt <n>)`, plus `; estimated` when that entry's `cost_kind` is `estimated`, plus `; degraded` on the entry that answered when `degraded` is true.
    - An error with an empty `calls[]` (`input_refused`, `budget_exhausted`) writes one `step` with `outcome` `skipped`, `cost_usd` 0 and `detail` `<tool>: <code> (<rule>)`.
  - **`## Website and Facebook URLs`:** move it from the Apify file unchanged, except:
    - source names follow Task 2's table;
    - the sentence citing `hooks/guard_policy.py` stays.
  - **`## Drift`:** the Apify file's four bullets, rewritten for the envelope:
    - `input_refused` gives `<source> (refused)`;
    - `unavailable` gives `<source> (unavailable)`;
    - a guard block still gives `<source> (blocked)`;
    - a missing or empty mapped field on every item is still `drift: <tool> <field> empty`;
    - "the same source blocked, refused or unavailable on 2 leads in one run is skipped for the rest of the run";
    - one `notify_owner(kind: error)` when a source fails on every lead of a run. Keep the `Researched` reason rule verbatim.
  - **`## Cost`:** "Before a call, check its worst case below against what remains of the lead's budget; after it, add the envelope's `cost_usd`."

    | Call | Worst case |
    |---|---|
    | `find_businesses` | $0.08 |
    | `find_contacts` | $0.006 per URL |
    | `find_reviews` (Google or Yelp) | $0.02 |
    | `find_ads` | $0.01, or $0.04 with a `facebook_page_url` |
    | `find_jobs` | the largest per-call estimate among `providers.find_jobs` in `../sales-partner-mcp/config/instances/webspenser.json` at the time of this task; $0.01 if LinkedIn is still alone |
    | `read_site` | $0.03 |
    | `find_profiles` by name | $0.15 |
    | `find_profiles` by company | $0.12 |
    | `find_profiles`, other platforms | $0 |
    | `read_profile` LinkedIn | $0.05 |
    | `read_profile` Instagram | $0.003 |
    | `read_profile` TikTok | $0.005 |
    | `read_profile` Facebook | $0 |
    | `search_pages` | $0.006 |
    | `fetch_page` | $0.002 |
    | `find_listing` BBB | $0.10 |
    | `find_listing` YellowPages | $0.10 |

    Add one sentence: "These follow the server's sizes in `config/instances/webspenser.json`; when the server's sizes or providers change, the operator updates this table in a plugin release."
  - **`## Setup`:**
    1. In claude.ai, add the custom connector `Webspenser Scraping` at `https://n8n.webspenser.cloud/mcp/webspenser-scraping` and sign in with n8n.
    2. Attach it to the prospect routine.
    3. Never attach the `N8N Webspenser Newsletter` connector: it exposes n8n's instance tools, which the root guard denies.
    4. There are no pinned values and no `bindings/scraping.md`.
  - **`## Probe`:**
    - Call ToolSearch for `Webspenser_Scraping`. Confirm exactly the 11 tools, and that the connector's server name contains `webspenser_scraping` once lowercased.
    - Record nothing.
    - If a tool is missing, tell the operator to re-add the connector, and leave scraping unbound.
- [ ] **Step 5: Update the contract and delete the Apify folder.**
  - In `contract.md`:
    - replace the `allowlisted_actors` and `pinned_inputs` items with ``- `allowlisted_tools` — only the tools the bound tool names run; which providers serve each tool is held by the scraping server, outside the guard's view.``
    - replace "an operation that makes two provider calls, such as `find_ads`, records a step for each" with "the tool reports each provider call it made, and each is a step".
  - Run `git rm -r capabilities/scraping/tools/apify`.
  - In `tests/test-content.sh`, set `SUD=$SP/capabilities/scraping/tools/webspenser/usage.md`. Delete the assertions on actor names, `fields` projections and binding keys. Replace them with:

    ```bash
    flat_has "$SUD" '`webspenser_scraping:find_jobs`'
    flat_has "$SUD" 'one `step` per `calls[]` entry'
    flat_has "$SUD" '`input_refused` gives `<source> (refused)`'
    flat_has "$SUD" 'never the reviewer'"'"'s profile URL, photo or ID'
    flat_has "$SUD" 'Never attach the `N8N Webspenser Newsletter` connector'
    flat_lacks "$SUD" 'get-dataset-items'
    ```

    Keep any existing reviewer-rule assertion that now points at `$SUD`.
- [ ] **Step 6: Run the suites.**
  - Run: `tests/test-policies.sh && tests/test-schedules.sh && python3 -B hooks/tool_check.py capabilities/scraping/tools/webspenser capabilities/scraping/contract.md`
  - Expected: all pass. `tool_check` exits 0.
- [ ] **Step 7: Commit.** Run `git add -A capabilities/scraping tests && git commit -m "feat: webspenser scraping tool replaces the Apify tool"`.

### Task 2: Config keys and source names without `apify_`

**Files:**
- Modify:
  - `context/operating-config.md`
  - `skills/interview-business/SKILL.md`
  - `subagents/prospector.md` (Stop conditions only)
  - `subagents/preparer.md` (Stop conditions only)
  - `tests/test-content.sh`

**Interfaces:**
- Produces the renames below, used by every later task:

  | Old | New |
  |---|---|
  | `apify_google_maps` | `google_maps` |
  | `apify_contact_info` | `contact_info` |
  | `apify_reviews` | `reviews` |
  | `apify_ads` | `ads` |
  | `apify_jobs` | `jobs` |
  | `apify_site_reader` | `site_reader` |
  | `apify_web` | `open_web` |
  | `apify_bbb` | `bbb` |
  | `apify_yellowpages` | `yellowpages` |
  | `apify_yelp` | `yelp` |
  | `apify_profiles` | `profiles` |
  | `apify_spend_cap_usd_per_week` | `scraping_spend_cap_usd_per_week` |
  | `apify_cap_usd_per_lead` | `scraping_cap_usd_per_lead` |

  `web_search` (the host's search) and `apollo` are unchanged.

- [ ] **Step 1: Write the failing content tests** (new section `-- 9.0.0: renamed keys`).

  ```bash
  OC=$SP/context/operating-config.md
  assert_contains "$OC" 'prospecting_sources: [google_maps, contact_info, reviews, ads, jobs, site_reader, profiles, web_search]'
  assert_contains "$OC" 'scraping_spend_cap_usd_per_week: 15'
  assert_contains "$OC" 'scraping_cap_usd_per_lead: 0.50'
  assert_contains "$OC" 'max_web_fetches_per_lead: 5'
  flat_has "$OC" 'the Webspenser scraping server'"'"'s own 7-day cap ($20) is the hard stop behind it'
  for f in "$SP/subagents/prospector.md" "$SP/subagents/preparer.md"; do
    flat_has "$f" 'lists a name renamed in 9.0.0 (an `apify_` source or cap key), stop and report `<old> was renamed <new> in 9.0.0`'
  done
  flat_lacks "$SP/skills/interview-business/SKILL.md" 'Apify'
  ```

  In the existing assertions on these files, swap old names for new ones (for example line 1044 becomes `scraping_cap_usd_per_lead: 0.50`).
- [ ] **Step 2: Run it and confirm it fails.** Run `tests/test-content.sh | grep FAIL | head`. Expected: the new lines FAIL.
- [ ] **Step 3: Apply the renames to `operating-config.md`.**
  - Rename everything per the table, including the "What each key gates" text, and add a `max_web_fetches_per_lead` entry with default 5.
  - The weekly cap's text says the Webspenser scraping server's own 7-day cap ($20) is the hard stop behind it.
  - Keep the `apify_site_scraper` sentence. Add: "The `apify_` source and cap names were renamed in 9.0.0 (the table in the README's 9.0.0 upgrade note); a config that still lists one stops the run with `<old> was renamed <new> in 9.0.0`."
- [ ] **Step 4: Update the interview skill.**
  - In `interview-business/SKILL.md`, rename the sources at lines 172–200 and the cap.
  - Replace "Apify needs the business's own Apify account with a monthly usage limit; do not ask about the Apify connection itself" with "scraping runs through the Webspenser server; do not ask about its connection".
  - Change the "$25/week Apify cap" example to "$15/week scraping cap".
- [ ] **Step 5: Add the rename stop.** In both subagents' Stop conditions, next to the `apify_site_scraper` line, add the 9.0.0 rename stop worded exactly as the test says.
- [ ] **Step 6: Run and confirm it passes.** Run `tests/test-content.sh | tail -1`. Expected: `0 failed`. Later tasks may leave other sections failing until done; the task-done run is `tests/run-all.sh` after Task 7, while this task's check is its own section.
- [ ] **Step 7: Commit.** Message: `feat: scraping config keys and source names without apify_`.

### Task 3: The Prospector reads envelopes

**Files:**
- Modify:
  - `subagents/prospector.md`
  - `tests/test-content.sh`
  - `evals/cases.md` (Prospector cases)

**Interfaces:**
- Consumes:
  - Task 1's usage `## Envelope`, `## Drift` and `## Cost`;
  - Task 2's names.

- [ ] **Step 1: Write the failing tests.**

  ```bash
  PR=$SP/subagents/prospector.md
  flat_has "$PR" 'one `step` per entry in the envelope'"'"'s `calls[]`'
  flat_has "$PR" 'On `budget_exhausted`, make no further scraping call this run'
  flat_has "$PR" 'up to 20 places per search: for more leads, run another search'
  flat_has "$PR" 'its worst case from the scraping tool'"'"'s `## Cost`'
  flat_has "$PR" 'every scraping step carries `cost_usd`'
  flat_lacks "$PR" 'Apify'
  flat_lacks "$PR" 'max_places_per_search'
  ```

  Replace the old assertion at test line 1810 (`every Apify step carries`).
- [ ] **Step 2: Run it and confirm it fails.**
- [ ] **Step 3: Edit `prospector.md`.**
  - Sources use Task 2's names.
  - The 7-day check sums scraping steps' `cost_usd` and tests the next call's worst case from the scraping tool's `## Cost` ($0.08 for `find_businesses`, $0.10 for `find_listing` on YellowPages), in place of `max_places_per_search` × the per-place estimate.
  - Each call's envelope gives `calls[]`, one `step` each, as Task 1 `## Envelope` says. The query `subject` formats are unchanged.
  - Errors are handled as Task 1 `## Drift` says.
  - `budget_exhausted` stops all scraping for the run: one `stop_condition` with detail `scraping server 7-day cap`. The run then finishes, reporting the leads found so far.
  - Replace "Drift in the Apify tool's usage" with "Drift in the scraping tool's usage".
  - Note that Maps returns up to 20 places per search, so the Prospector reaches `leads_per_week` with more queries (other trade terms, nearby cities); the existing skip-on-zero rule applies to each.
- [ ] **Step 4: Update evals.** Swap names in the Prospector cases. Add one case, `budget_exhausted on the third Maps query`:
  - Given 3 queries, the third returns `budget_exhausted`.
  - Then there is no fourth call, one `stop_condition`, and `run_finished` with the leads from the first two.
- [ ] **Step 5: Run the content tests and confirm the Prospector lines pass.**
- [ ] **Step 6: Commit.** Message: `feat: prospector reads scraping envelopes`.

### Task 4: The Preparer and its skills read envelopes

**Files:**
- Modify:
  - `subagents/preparer.md`
  - `skills/find-social-profiles/SKILL.md`
  - `skills/find-decision-makers/SKILL.md`
  - `skills/research-company/SKILL.md` (if it names a source or binding)
  - `capabilities/web_search/contract.md` (line 27)
  - `tests/test-content.sh`
  - `evals/cases.md`

**Interfaces:**
- Consumes Tasks 1–2.
- Produces the stage-reason strings the digest renders:
  - `research capped at $<cap>; not run: <sources>` (unchanged);
  - `research capped by the 7-day scraping cap; not run: <sources>`, for the agent's own cap;
  - `research capped by the scraping server's 7-day cap; not run: <sources>`, for `budget_exhausted`.

- [ ] **Step 1: Write the failing tests.**

  ```bash
  PP=$SP/subagents/preparer.md
  flat_has "$PP" 'add the envelope'"'"'s `cost_usd` to the lead'"'"'s total'
  flat_has "$PP" 'research capped by the scraping server'"'"'s 7-day cap'
  flat_has "$PP" 'at most `max_web_fetches_per_lead` `fetch_page` calls'
  flat_has "$PP" 'The Preparer never retries a scraping call: the server already retried and failed over'
  flat_lacks "$PP" 'Apify'
  flat_lacks "$PP" 'needs `max_reviews`'
  flat_lacks "$SP/skills/find-social-profiles/SKILL.md" 'retry once'
  flat_has "$SP/skills/find-social-profiles/SKILL.md" '`unavailable` or a guard block: treat that platform as not searched'
  flat_lacks "$SP/skills/find-social-profiles/SKILL.md" 'Apify'
  ```

  Update every existing `$PP` assertion that quotes `apify_`, `Apify` or a size binding, swapping in new names (for example lines 1145, 1167, 1183, 1208 and 1337).
- [ ] **Step 2: Run it and confirm it fails.**
- [ ] **Step 3: Edit `preparer.md`.**
  - Inputs:
    - `capabilities/scraping/tools/apify/usage.md`'s `## Cost` becomes the bound scraping tool's `usage.md` `## Cost`;
    - add `max_web_fetches_per_lead`.
  - Delete the paragraph listing size bindings each source needs (lines 412–418) and its "bindings missing" skip. Sizes are the server's.
  - Caps:
    - the pre-call check uses the `## Cost` worst case;
    - the lead total and the 7-day sum add each envelope's `cost_usd`;
    - check order is unchanged: 7-day, then per-lead.
  - Add a `budget_exhausted` stop next to the 7-day cap stop: same handling (complete the lead, set Research Capped, end scraping for the run), with the reason start from Interfaces. It is a `stop_condition` once per run.
  - Drift and blocks follow Task 1 `## Drift`.
  - Delete the Facebook backup rule ("the Facebook backup runs with the same page URL"): the server fails over.
  - Rename "Website URLs … (`capabilities/scraping/tools/apify/usage.md`, …)" to the scraping tool's `usage.md`.
  - Add the no-retry sentence the test quotes.
- [ ] **Step 4: Edit the skills.**
  - `find-social-profiles`:
    - the Failure modes bullet becomes "`find_profiles` or `read_profile` returns `unavailable` or a guard block: treat that platform as not searched, say so in the report, and return `stopped` rather than marking the contact checked; `input_refused` skips the platform for this contact";
    - remove "(`Full + email search`)" from line 49 (a server mode, not the agent's);
    - "Apify spend" becomes "scraping spend".
  - `find-decision-makers` line 40: `apify_profiles` becomes `profiles`.
  - `web_search` contract: "the Preparer's Apify caps" becomes "the Preparer's scraping caps".
- [ ] **Step 5: Update the evals.**
  - Swap names and caps in cases 27 and nearby (lines 941–1100, 1183, 1223).
  - Point the `usage.md` path at the scraping tool.
  - Replace actor arguments such as `place_ids` with contract arguments (`place`).
  - Add a case, `failover recorded`:
    - `find_reviews` returns `degraded: true` with calls `[failed $0.00 actual, ok $0.02 estimated]`;
    - then two `step` events, a lead total +$0.02, and the finding used.
- [ ] **Step 6: Run the content tests and confirm the Preparer and skill lines pass.**
- [ ] **Step 7: Commit.** Message: `feat: preparer and research skills read scraping envelopes`.

### Task 5: Digest, CRM text, AGENT.md and README

**Files:**
- Modify:
  - `skills/send-digest/SKILL.md`
  - `templates/digest.md`
  - `templates/digest.html`
  - `capabilities/crm/contract.md`
  - `capabilities/crm/tools/attio/usage.md`
  - `capabilities/crm/tools/attio/bootstrap.py` (the `research_capped` description)
  - `capabilities/crm/tools/hubspot/usage.md`
  - `AGENT.md`
  - `README.md`
  - `tests/test-content.sh`

- [ ] **Step 1: Write the failing tests.**

  ```bash
  for f in skills/send-digest/SKILL.md templates/digest.md templates/digest.html capabilities/crm/contract.md \
           capabilities/crm/tools/attio/usage.md capabilities/crm/tools/attio/bootstrap.py capabilities/crm/tools/hubspot/usage.md AGENT.md; do
    flat_lacks "$SP/$f" 'Apify'
  done
  flat_has "$SP/templates/digest.md" '[$ spent] of [$ cap]/week scraping cap'
  flat_has "$SP/AGENT.md" 'Webspenser scraping server (`bind_scraping`)'
  flat_has "$SP/README.md" 'Upgrading from 8.7: scraping now runs through the Webspenser server'
  flat_lacks "$SP/README.md" 'mcp.apify.com'
  [ "$(wc -c < "$SP/AGENT.md")" -le 5983 ] && _report ok "AGENT.md <= 5983 bytes" || _report no "AGENT.md over 5983 bytes"
  ```

- [ ] **Step 2: Run it and confirm it fails.**
- [ ] **Step 3: Edit the digest.**
  - In `send-digest`, Section 5 reads "the week's scraping cost from the ledger" against `scraping_spend_cap_usd_per_week`, with the per-lead cap `scraping_cap_usd_per_lead`.
  - Replace "(Apify does not return cost)" with "marked estimated when the server reported an estimate".
  - "Apify cap" becomes "scraping cap" in lines 7, 135, 182 and 382, and in both templates.
- [ ] **Step 4: Edit the CRM text.** "an Apify cap" becomes "a scraping cap" in the four CRM files. `bootstrap.py` changes only its description string.
- [ ] **Step 5: Edit `AGENT.md`, keeping it within 5983 bytes.**
  - Line 27: "- Webspenser scraping server (`bind_scraping`): Maps listings, website contacts and research evidence (reviews, ads, jobs, site pages), through `capabilities/scraping/contract.md`."
  - Lines 76 and 110–115: the renamed caps, and "weekly scraping spend cap".
- [ ] **Step 6: Edit the README.**
  - Every Apify mention in "What you get", "What you need" and "Tools it needs" becomes the Webspenser server. What you need: "the Webspenser Scraping connector (Webspenser runs the scraping accounts)".
  - Delete the "Upgrading from 8.0" through "Upgrading from 8.5.1" notes whose steps concern the Apify connector (Ruling 8). Keep upgrade notes that concern other capabilities, but drop their Apify sentences.
  - Add an "Upgrading from 8.7" note:
    1. install 9.0.0 on a quiet day (no scheduled run within 24 hours);
    2. add the `Webspenser Scraping` connector (`usage.md` `## Setup`);
    3. re-run setup's tools step, which binds `webspenser`, renames the config keys per the table (repeat Task 2's table here) and deletes `bindings/scraping.md`;
    4. re-run `/sales-partner:schedule`: it removes the Apify connector from the prospect routine, attaches `Webspenser Scraping`, and sets `agent_version: 9.0.0` and the environment comment `# sales-partner 9.0.0`;
    5. rollback: the MCP repo's `docs/runbook/cutover.md`.
- [ ] **Step 7: Run the content tests and confirm these lines pass.**
- [ ] **Step 8: Commit.** Message: `docs: digest, CRM, AGENT.md and README for the scraping server`.

### Task 6: Setup and schedule

**Files:**
- Modify:
  - `skills/setup/SKILL.md`
  - `skills/schedule/SKILL.md`
  - `tests/test-content.sh`

- [ ] **Step 1: Write the failing tests.**

  ```bash
  ST=$SP/skills/setup/SKILL.md; SC=$SP/skills/schedule/SKILL.md
  flat_has "$ST" 'An instance bound to `apify` for scraping is upgraded in this step'
  flat_has "$ST" 'deletes `bindings/scraping.md`'
  flat_has "$ST" 'renames the config keys listed in the README'"'"'s 8.7 upgrade note'
  flat_has "$SC" 'never attach the `N8N Webspenser Newsletter` connector'
  flat_has "$SC" 'remove a connector the scraping tool no longer uses (an Apify connector)'
  ```

  In the existing setup assertions, `max_places_per_search` stops being the example cap. The example becomes only `recipient_email`.
- [ ] **Step 2: Run it and confirm it fails.**
- [ ] **Step 3: Edit the setup skill's tools step.**
  - Remove `max_places_per_search` from the pinned-values example (line 120); keep `recipient_email`.
  - Add a sub-step for scraping: "An instance bound to `apify` for scraping is upgraded in this step":
    1. run the webspenser Probe;
    2. on a pass, replace `bind_scraping: apify` with `bind_scraping: webspenser`;
    3. delete `bindings/scraping.md`;
    4. rename the config keys listed in the README's 8.7 upgrade note in the instance's `context/operating-config.md`, repeating each change to the operator first;
    5. commit and push.
- [ ] **Step 4: Edit the schedule skill's connectors step.**
  - "remove a connector the scraping tool no longer uses (an Apify connector) from every routine";
  - "never attach the `N8N Webspenser Newsletter` connector".
- [ ] **Step 5: Run the content tests and confirm these lines pass.**
- [ ] **Step 6: Commit.** Message: `feat: setup and schedule move an instance to the scraping server`.

### Task 7: Release 9.0.0 and the no-Apify check

**Files:**
- Modify:
  - `agent.yaml`
  - `.claude-plugin/plugin.json`
  - `.codex-plugin/plugin.json`
  - `gemini-extension.json`
  - `README.md` (`Version 9.0.0.`)
  - `tests/test-content.sh`

- [ ] **Step 1: Write the failing tests.**
  - Change the version assertions at lines 533, 797–800 to `9.0.0`.
  - Replace the `-- 8.7.1` section with a `-- 9.0.0: release` section:

    ```bash
    left=$(grep -rli apify --exclude-dir=.git --exclude-dir=docs . | sort | tr '\n' ' ')
    allowed='./README.md ./context/operating-config.md ./skills/schedule/SKILL.md ./skills/setup/SKILL.md ./subagents/preparer.md ./subagents/prospector.md ./tests/test-content.sh ./tests/test-schedules.sh '
    [ "$left" = "$allowed" ] && _report ok "Apify named only in rename and upgrade text" || _report no "Apify still named in: $left"
    ```

  - Each allowed file names Apify only in the rename stop, the 8.7 upgrade note, the connector removal, or a test. Inspect `grep -n -i apify` on each and confirm.
  - `evals/cases.md` is not in the list. If a case must name an old key, to test the rename stop, add the file to `allowed` and say why in a comment.
- [ ] **Step 2: Run it and confirm it fails** (the version is still 8.7.1).
- [ ] **Step 3: Bump to `9.0.0`** in the five manifests and the README line.
- [ ] **Step 4: Run the full verification.**
  - Run: `bash tests/run-all.sh && ../agent-builder/bin/validate-agent.sh . --require-bump origin/main`
  - Expected: `ALL GREEN`, and the validator exits 0.
- [ ] **Step 5: Commit.** Message: `chore: sales-partner 9.0.0`.

## Not in this plan (owner, after merge)

- **Cutover waits for the MCP repo's jobs fix:**
  - `johnvc/Google-Jobs-Scraper` at the head of `providers.find_jobs`;
  - `employerMatches` widened to the 2026-11-16 probe's rule;
  - the acceptance test passed.
- **If the jobs fix changes `find_jobs`' estimate** after Task 1, update the `## Cost` row before release.
- **The live upgrade** follows the README's 8.7 note and the MCP repo's `docs/runbook/cutover.md`, on a quiet day. The 18 leads from 2026-11-16 stay waiting until after cutover.
