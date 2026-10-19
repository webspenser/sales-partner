# Research Scrapers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sales Partner 8.1.0 adds four guarded Apify evidence sources (Maps reviews, ads, Indeed jobs, website reader), each steered by per-offer research tips in the catalog. Each lead has a $0.50 Apify cap. A scheduled run that hits the cap sets a Research Capped flag; continuing past it happens only interactively.

**Architecture:**
- Same layers as 8.0: markdown contracts (scraping and CRM contracts, the Apify `usage.md`, the Preparer and skills), the Apify `guard.yaml` (allowlist, `only_keys`, pinned `recipients` and `limits` bound to `bindings/scraping.md`), the stdlib CRM bootstraps, and bash tests.
- Task 1 is a live probe with the operator present. Its notes fix the exact tool names and arguments every later task uses.

**Tech Stack:**
- Markdown.
- YAML guard policies checked by `hooks/guard_policy.py`. Hooks are byte-synced from agent-builder; don't edit them.
- Python 3 stdlib.
- Bash tests, using `tests/lib.sh` and `check` in `tests/test-policies.sh`.
- The Apify hosted MCP (`mcp__claude_ai_Apify__*`).

**Spec:** `docs/superpowers/specs/2026-10-18-research-scrapers-design.md`. The actor survey is `docs/superpowers/notes/2026-10-18-apify-research-buckets.md`.

## Global Constraints

- **Version:** **8.1.0**. `standard: "7.2"` is unchanged. No agent-builder change and no `hooks/` change.
- **Branch:** `feat/research-scrapers`, built on `feat/offer-matching` (8.0.0). Rebase onto `main` once sales-partner#23 merges; Task 8 checks this.
- **Actors**, the probe's target picks:
  - `compass/Google-Maps-Reviews-Scraper` (reviews);
  - `scrapesage/google-ads-transparency-scraper` (advertisers mode) and `apify/facebook-ads-scraper` (`onlyTotal`) for ads;
  - `valig/indeed-jobs-scraper` (jobs);
  - `apify/website-content-crawler` with the `cheerio` crawler (site reader).
  - A pick that fails the probe is replaced by the survey's runner-up, and the probe notes say why.
- **Source names in `prospecting_sources`:** `apify_reviews`, `apify_ads`, `apify_jobs`, `apify_site_reader`. The default list includes all four, alongside the existing names.
- **New scraping bindings** (key: default): `max_reviews: 50`, `max_ads: 5`, `max_jobs: 20`, `max_site_pages: 5`, `max_site_depth: 1`. The probe may add a binding where an actor has a further size argument; name it `max_<thing>` and record it.
- **New scraping contract operations:** `find_reviews(place)`, `find_ads(business)`, `find_jobs(company, location)`, `read_site(url)`. Each returns its results plus the run's cost, estimated when the provider doesn't report it. Failure handling is the same as `find_businesses`.
- **New `operating-config.md` keys and values:**
  - `apify_cap_usd_per_lead: 0.50`;
  - `research_budget_per_lead_minutes` default 15 (was 8).
- **New lead field:** Research Capped. Attio `research_capped`, HubSpot `sp_research_capped`, a checkbox. The agent writes it (not `forbid`). Both Review views show it.
- **Stage-reason starts:**
  - per-lead cap: `research capped at $<cap>; <sources not run>`;
  - 7-day cap: `research capped by the 7-day Apify cap; <sources not run>`.
- **Catalog key:** `research_tips` (free text, optional) on each offer. The bootstraps' `read_catalog` must accept it unchanged.
- **Reviews:**
  - The Preparer always passes `personalData: false` to the reviews actor.
  - Findings quote a snippet with its date and link, and never the reviewer's name.
  - The recency rule: a review older than 12 months doesn't count for a catalog entry when a review from the last 12 months shows the same entry. It applies to reviews only, in `match-offer`'s counting step.
- **Website:**
  - "Lacks" is claimed only after the home page and the relevant page were both read.
  - "Lacks chat" is never claimed.
- **Weekly cap:** it is never raised from a session prompt.
- **Continuing past the per-lead cap** is interactive only.
- **Tests and commits:**
  - Every task leaves `bash tests/run-all.sh` green.
  - `finish` stays the last line of `tests/test-content.sh`.
  - Restore exec bits on `tests/*.sh` after edits.
  - Commits end with a `Co-Authored-By:` trailer naming the model that made them. Never push.

## Review Focus

1. **A new actor called with an unlimited default left out.** For example `maxReviews` omitted, which defaults to 10,000,000, or a crawler page cap omitted. The guard must block. Tested in Task 2 with a "limit omitted" case per pinned argument.
2. **Code, cookie or header arguments on the crawler,** including in a nested object. The guard must block `pageFunction`, `initialCookies`, `customHttpHeaders` and any unlisted key. Tested in Task 2.
3. **A scheduled lead whose next call's worst-case estimate exceeds what's left of $0.50.** The Preparer must stop before the call, not after it. Pinned in Task 5's content test and an eval in Task 7.
4. **A reviewer name reaching the CRM through a quoted snippet.** The finding format must quote only the review text. Pinned in Task 5, and an eval in Task 7.
5. **An instance whose `prospecting_sources` omits a new source.** That source must never run, scheduled or interactive. A content test in Task 5, and an eval in Task 7.

---

### Task 1: Live probe of the four new actors (operator present)

**Files:**
- Create: `docs/superpowers/notes/2026-10-18-research-actors-probe.md`

**Interfaces:**
- Produces, per actor, the facts every later task uses verbatim:
  - the exact MCP tool name (as `mcp__claude_ai_Apify__<tool>` shows it);
  - the full input schema;
  - the arguments that bound size or cost, with their defaults, and which become pins (to which binding) or `limits`;
  - the target argument;
  - the arguments to leave out (paid add-ons, code, cookies, headers, proxies);
  - the output fields used for findings;
  - the cost per result or event and a per-lead estimate.
- Also produces:
  - for the site reader, the options that keep links and markup, and whether run memory can be lowered;
  - for reviews, how `personalData: false` is passed and what still comes back.

- [ ] **Step 1: Stop and ask the operator to add the four actors to the Apify connector's restricted URL.** The current URL is `https://mcp.apify.com?tools=compass/crawler-google-places,vdrmota/contact-info-scraper`; keep the two existing actors and append the four new ones. Then confirm with ToolSearch that the tools are exposed.

- [ ] **Step 2: Record each tool's schema and its bounding arguments in the notes,** without calling it.

- [ ] **Step 3: Get the operator's OK, then run one tiny call per actor on a known lead.** Use Plumbing Plus or Big Brothers Plumbing in Alameda, CA, with the smallest size values (for example 5 reviews, 1 page, 5 jobs). Record the run ID, status, item count, compute units and the fields returned.

- [ ] **Step 4: Fill the notes' "Values for Tasks 2–5" table:** tool names, pins and bindings, `only_keys` lists, output fields and cost estimates. Mark any replacement by a runner-up, with the reason.

- [ ] **Step 5: Commit:** `docs: research actors probe`.

---

### Task 2: Scraping contract, Apify guard and usage

**Files:**
- Modify: `capabilities/scraping/contract.md`: add the four operations to the Operations table.
- Modify: `capabilities/scraping/tools/apify/guard.yaml`:
  - `allow` the four tools;
  - an `only_keys` per tool (with nested paths where an argument is an object or list of objects);
  - `recipients` pins for each size argument;
  - `limits` (`kind: count`, `required: true`) for each list argument.
- Modify: `capabilities/scraping/tools/apify/usage.md`:
  - each operation's mapping, with allowed arguments in the existing style;
  - result mapping and cost estimate per actor;
  - the `## Setup` binding list with the five new bindings and defaults;
  - the connector's restricted URL listing all six actors, so setup's tools step tells the operator exactly what to add.
- Test: `tests/test-policies.sh` (the `-- scraping (apify)` block: extend the bindings fixture with the new keys), `tests/test-content.sh`.

**Interfaces:**
- Consumes: the Task 1 "Values for Tasks 2–5" table.
- Produces:
  - the contract operation names and signatures in the Global Constraints;
  - the binding keys and defaults in the Global Constraints;
  - the guard tool names exactly as the probe recorded them.

- [ ] **Step 1: Write the failing policy cases for each new tool:**
  - in-limit call allowed;
  - each pinned argument raised: blocked, naming its binding;
  - each pinned argument omitted: blocked ("names no pinned value");
  - each counted list over its bound or empty: blocked;
  - a respelled key: blocked ("may not use");
  - each paid add-on or code/cookie/header key, even set to `false`: blocked;
  - for the reviews actor, a call with `personalData: false` allowed.

- [ ] **Step 2: Run** `bash tests/test-policies.sh`. Expected: FAIL (the tools aren't in `allow`).

- [ ] **Step 3: Edit the guard, contract and usage.md** as listed under Files. Keep the guard header comment accurate.

- [ ] **Step 4: Add content assertions:**
  - the four operations appear in `contract.md` and `usage.md`;
  - the five binding keys appear in `usage.md`'s `## Setup`;
  - `usage.md` tells the agent to pass `personalData: false` and never to record reviewer names.

- [ ] **Step 5: Run** `bash tests/run-all.sh`. Expected: ALL GREEN.

- [ ] **Step 6: Commit:** `feat(scraping): reviews, ads, jobs and site reader through Apify, guarded`.

---

### Task 3: Research Capped field in both CRMs

**Files:**
- Modify: `capabilities/crm/tools/attio/bootstrap.py`, `capabilities/crm/tools/hubspot/bootstrap.py`: add the checkbox.
- Modify: both `capabilities/crm/tools/*/usage.md`: the schema table, the Probe, the Review views (show it), and the `update_lead` mapping.
- Modify: `capabilities/crm/contract.md`: the Offer fields table, adding the field and who writes it; `update_lead` accepts `research_capped`.
- Test: `tests/test-content.sh`, `tests/test-policies.sh`.

**Interfaces:**
- Produces `update_lead(fields: {research_capped: true|false})`, which the Preparer calls in Task 5.

- [ ] **Step 1: Write the failing tests.**
  - Both bootstraps define `research_capped` / `sp_research_capped` as a checkbox.
  - Both usage.md files and the contract name it.
  - Policy cases: the agent may write it `true` and `false` in both CRMs.

- [ ] **Step 2: Run** `bash tests/run-all.sh`. Expected: FAIL.

- [ ] **Step 3: Implement the bootstrap, usage and contract edits.**

- [ ] **Step 4: Run** `bash tests/run-all.sh`. Expected: ALL GREEN.

- [ ] **Step 5: Commit:** `feat(crm): Research Capped flag`.

---

### Task 4: Catalog research tips, config keys, interview

**Files:**
- Modify: `context/offer-catalog.md` (template): document `research_tips`, with the spec's example in the `text` example block.
- Modify: `skills/interview-business/SKILL.md`:
  - Round 1b asks for each offer's research tips, after signals and rule-outs, as optional;
  - Round 4 offers the four new source names.
- Modify: `context/operating-config.md`:
  - `prospecting_sources` gets the four new names;
  - add `apify_cap_usd_per_lead: 0.50`;
  - `research_budget_per_lead_minutes: 15`;
  - each key gets a "What each key gates" entry.
- Test: `tests/test-catalog.sh` (a fixture offer with a multi-line `research_tips: >` block still parses to the same IDs), `tests/test-content.sh`.

**Interfaces:**
- Produces the config keys and source names that Task 5 reads.

- [ ] **Step 1: Write the failing tests.**
  - The catalog fixture with `research_tips` (including a line starting `- id:` inside the folded text, which must not count as an ID) parses to the same segment and offer IDs in both bootstraps.
  - Content assertions:
    - `operating-config.md` contains `apify_cap_usd_per_lead: 0.50` and `research_budget_per_lead_minutes: 15`;
    - its `prospecting_sources` line contains all four new names;
    - the interview and template contain `research_tips`.

- [ ] **Step 2: Run** `bash tests/run-all.sh`. Expected: FAIL.

- [ ] **Step 3: Implement the edits.** If `read_catalog` miscounts the `- id:` inside folded text, fix the parser in both bootstraps, keeping them identical.

- [ ] **Step 4: Run** `bash tests/run-all.sh`. Expected: ALL GREEN.

- [ ] **Step 5: Commit:** `feat(catalog): research tips; config keys for the new sources and the per-lead cap`.

---

### Task 5: Preparer, research and matching

**Files:**
- Modify: `subagents/preparer.md`:
  - Inputs: the tips and the new keys.
  - Tools allowed: the four operations.
  - Steps: tips-driven source choice, only from `prospecting_sources`.
  - The per-lead cap: running total and the worst-case check before each call.
  - Scheduled capping: finish the lead, set Research Capped, the stage-reason start, a ledger `stop_condition`.
  - The interactive continue prompt.
  - The "continue research on a capped lead" interactive request: run only the sources not yet run, add a section, re-match, clear Research Capped.
  - The 7-day cap: as today, plus Research Capped on the lead in progress, and never raised from a prompt.
  - The Ledger step detail for each new call.
- Modify: `skills/research-company/SKILL.md`: findings for each source.
  - Reviews go under `listing`: a quoted snippet with its date and link, no reviewer name.
  - Jobs go under `hire`.
  - Ads go under `web_presence`, presence only.
  - Site features go under `web_presence`, "has" or "lacks", with the page checked. "Lacks" needs the home page and the relevant page read; never "lacks chat".
- Modify: `skills/match-offer/SKILL.md`: the review recency rule in the counting step.
- Test: `tests/test-content.sh`.

**Interfaces:**
- Consumes: the Task 2 operations, Task 3's `research_capped`, and Task 4's keys and source names.

- [ ] **Step 1: Write the failing content assertions.** The Preparer contains:
  - `apify_cap_usd_per_lead`;
  - `research capped at $`;
  - `research capped by the 7-day Apify cap`;
  - `research_capped`;
  - `research_tips`;
  - each of the four operation names;
  - a sentence pinning that a source not in `prospecting_sources` never runs;
  - a sentence pinning that the worst-case estimate is checked before each call.

  research-company contains `personalData: false`, a sentence saying review findings never carry a reviewer name, and `lacks chat`. match-offer contains `12 months`.

- [ ] **Step 2: Run** `bash tests/test-content.sh`. Expected: FAIL.

- [ ] **Step 3: Edit the three files.** Keep each `## Ledger` consistent with `capabilities/ledger/contract.md`.

- [ ] **Step 4: Run** `bash tests/run-all.sh`. Expected: ALL GREEN.

- [ ] **Step 5: Commit:** `feat: tips-driven research sources with a per-lead Apify cap`.

---

### Task 6: Digest

**Files:**
- Modify: `skills/send-digest/SKILL.md`, `templates/digest.md`. In the Review section, a lead with Research Capped gets the mark `(research capped)` after its evidence. The Spend section shows the per-lead cap.
- Test: `tests/test-content.sh`.

- [ ] **Step 1: Write the failing assertions:** both files contain `(research capped)`.
- [ ] **Step 2: Run** `bash tests/test-content.sh`. Expected: FAIL.
- [ ] **Step 3: Edit both files,** including the worked example.
- [ ] **Step 4: Run** `bash tests/run-all.sh`. Expected: ALL GREEN.
- [ ] **Step 5: Commit:** `feat(digest): mark research-capped leads`.

---

### Task 7: Evals

**Files:**
- Modify: `evals/cases.md`, `tests/test-content.sh` (new case headings).

- [ ] **Step 1: Add heading assertions for eight new cases:**
  1. a scheduled lead hits the per-lead cap, stops before the over-cap call, gets Research Capped and still reaches `Researched`;
  2. the weekly cap is reached mid-lead;
  3. an interactive continue past the cap;
  4. tips steer which sources run;
  5. a source not in `prospecting_sources` doesn't run;
  6. a review signal quoted with no reviewer name;
  7. a "lacks" claim needs both pages, and there is no "lacks chat";
  8. an old review doesn't count when a newer one shows the same entry.

- [ ] **Step 2: Run** `bash tests/test-content.sh`. Expected: FAIL.

- [ ] **Step 3: Write the eight cases** in the existing format. Check each expected outcome against the shipped text of the Preparer, research-company, match-offer, the Apify `usage.md` and both contracts.

- [ ] **Step 4: Run** `bash tests/run-all.sh`. Expected: ALL GREEN.

- [ ] **Step 5: Commit:** `test(evals): research sources and the per-lead cap`.

---

### Task 8: Release 8.1.0

**Files:**
- Modify: `agent.yaml`, `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, `gemini-extension.json` (version `8.1.0`). The description is unchanged.
- Modify: `README.md`:
  - "Version 8.1.0.";
  - the research sources in the flow copy;
  - an "Upgrading from 8.0" note with the spec's four steps, in order, including the connector URL step.
- Test: `tests/test-content.sh` (version pins and `Upgrading from 8.0`).

- [ ] **Step 1: Check the base.** If sales-partner#23 has merged, rebase `feat/research-scrapers` onto `main`. Then change the version pins and add `Upgrading from 8.0`.
- [ ] **Step 2: Run** `bash tests/test-content.sh`. Expected: FAIL.
- [ ] **Step 3: Edit the manifests and README.**
- [ ] **Step 4: Run** `bash tests/run-all.sh && ../agent-builder/bin/validate-agent.sh . --require-bump main`. Expected: `ALL GREEN` and `OK: . conforms`.
- [ ] **Step 5: Commit:** `chore: sales-partner 8.1.0`.

## Done when

- Both checks are green on the branch.
- The probe notes record a live call for each actor.
- PRs only when the operator asks.
