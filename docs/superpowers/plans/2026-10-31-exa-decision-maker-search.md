# Exa Decision-Maker Search (sales-partner 8.2.0) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a business has Exa connected, the Preparer runs one Exa web search per researched lead to find its owner or principal, including in scheduled runs; without Exa nothing changes.

**Architecture:** A new `web_search` capability with an `exa` tool reached through Exa's hosted MCP connector (`web_search_exa`), guarded by its own `guard.yaml`, declared as `optional_prepare: web_search` (Standard 7.4). `find-decision-makers` gains the Exa step and source-strength rules for every source; the Preparer keeps Exa spend out of the Apify caps.

**Tech Stack:** markdown skills and contracts, YAML policies, the Agent Standard engine (`hooks/guard_policy.py`), bash tests.

**Spec:** `docs/superpowers/specs/2026-10-31-exa-decision-maker-search-design.md`. Depends on agent-builder plan `agent-builder/docs/superpowers/plans/2026-10-31-optional-capabilities.md`, merged first.

## Global Constraints

- Connector only. No `EXA_API_KEY`, environment variable, script, or network secret anywhere in the package or docs.
- Only `web_search_exa` may run; `agent_run`, `web_search_advanced_exa`, `web_fetch_exa` and every other Exa tool are blocked.
- `web_search_exa` takes only `query`; `numResults` is blocked, so Exa's default of 10 results applies.
- One `search_web` per lead per run; a retry of a failed call is the same search; a continue run does not repeat a successful one.
- Exa `step` events never count toward `apify_cap_usd_per_lead` or `apify_spend_cap_usd_per_week`; Exa keeps running after an Apify cap stops scraping.
- Strong sources: the business's own website; a state licence record (including `exa.ai/library/person` entries carrying licence data); BBB; a bar or trade association profile; Diamond Certified; a LinkedIn profile whose current role is at this business. Everything else is weak.
- Weak-only person: written, `Verified` unchecked, `Notes` says `directory only` with the URL. Conflicting owners: both written, unverified, `Notes` says `conflicting sources` with both URLs.
- `sales-partner` is a public repo: no real lead or person names in any committed file.
- Version `8.2.0`; `standard: "7.4"`.
- Push to `webspenser/sales-partner` over HTTPS: `git -c credential.helper= -c 'credential.helper=!gh auth git-credential' push https://github.com/webspenser/sales-partner.git <branch>`.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

- A tool on another connector whose name happens to contain `exa` would fall under the Exa policy and be blocked: Task 2's probe lists every session tool containing `exa`; `usage.md` warns the connector must be named so.
- `web_search_exa` called with `numResults: 100` (the model may add it): blocked by the guard (Task 2 test).
- `query` containing `category:people`: allowed (it is part of the query string) (Task 2 test).
- Exa bound but its call errors mid-run: research continues, failed `step` recorded, no owner notification (Task 4 content assertion).
- An instance without `bind_web_search`: the Preparer and skill skip the Exa step silently and scheduled checks pass (Task 1 and Task 5 checks).

---

### Task 1: Sync agent-builder 7.4

**Files:**
- Modify: `hooks/schedule_check.py` (byte copy of builder `_template/hooks/schedule_check.py`)
- Modify: `skills/setup/SKILL.md` (apply the builder's step 9 optional-capability wording; this file keeps its existing agent-specific substitutions)
- Modify: `skills/schedule/SKILL.md` (byte copy of builder template)
- Modify: `agent.yaml` `standard: "7.4"`; `tests/*` fixtures that assert `"7.3"`

- [ ] **Step 1:** Pull builder `main` (contains the merged optional-capabilities PR) and copy/apply the files above.
- [ ] **Step 2:** Run `bash tests/run-all.sh 2>&1 | tail -1` and `../agent-builder/bin/validate-agent.sh .`. Expected: `ALL GREEN`, `OK: . conforms`.
- [ ] **Step 3: Commit** `chore: sync agent-builder 7.4 (optional capabilities)` on branch `feat/exa-decision-makers`.

---

### Task 2: `web_search` capability and the `exa` tool

**Files:**
- Create: `capabilities/web_search/contract.md`
- Create: `capabilities/web_search/tools/exa/identity.yaml`, `guard.yaml`, `usage.md`
- Create: `docs/superpowers/notes/2026-10-31-exa-connector-probe.md`
- Modify: `agent.yaml` (`capabilities: crm, owner_notify, ledger, scraping, web_search`; add `optional_prepare: web_search`)
- Test: `tests/test-policies.sh` (new section `-- web_search (exa)`), `tests/test-content.sh`

**Interfaces:**
- Produces: operation `search_web(query)` → up to 10 results (title, URL, published date when known, highlights) plus estimated cost; on failure retried once, then a ledger `step` with outcome `failed`. Ledger `step` `detail` starts with `search_web` (Task 4 relies on this prefix).
- Produces: invariants `no_external_send`, `allowlisted_tools`, `default_result_count`.

- [ ] **Step 1: Probe the live connector.** The user adds Exa's hosted MCP server (`https://mcp.exa.ai/mcp`) as a claude.ai connector named `Exa`, authenticated with their Exa key or OAuth. In a session where it is connected, record in the probe note: the exact tool names (expected `mcp__claude_ai_Exa__web_search_exa`, `..._web_fetch_exa`), `web_search_exa`'s input schema, one result's shape, and every tool name in the session containing `exa` (collision check). No key, no lead names in the note.

- [ ] **Step 2: Write the failing tests** in `tests/test-policies.sh`, using its `check` helper:

```bash
echo "-- web_search (exa)"
EX=capabilities/web_search/tools/exa/guard.yaml; P=mcp__claude_ai_Exa__; SM=exa
check 0 "search with query"          $EX ${P}web_search_exa '{"query":"owner of a roofing contractor in Alameda"}'
check 0 "category in the query"      $EX ${P}web_search_exa '{"query":"category:people owner of a roofing contractor"}'
check 2 "numResults blocked"         $EX ${P}web_search_exa '{"query":"x","numResults":100}' "may not use numResults"
check 2 "agent_run blocked"          $EX ${P}agent_run '{"query":"x"}'
check 2 "advanced search blocked"    $EX ${P}web_search_advanced_exa '{"query":"x"}'
check 2 "page fetch blocked"         $EX ${P}web_fetch_exa '{"urls":["https://example.com"]}'
```

Use the exact block text the engine prints for a disallowed key (copy from an existing Apify `only_keys` case) in place of `may not use numResults` if it differs. In `tests/test-content.sh` assert: the contract lists the three invariants; `usage.md` has `## Setup`, `## Probe`, `## Cost` and names `search_web`; `agent.yaml` has `optional_prepare: web_search`.

- [ ] **Step 3: Run to verify they fail**

Run: `bash tests/test-policies.sh 2>&1 | grep -E 'FAIL|passed'`
Expected: the new cases fail (policy file missing).

- [ ] **Step 4: Write the capability**

- `contract.md`: Operations table with `search_web` (Interfaces above); Invariants `no_external_send` — never sends anything; `allowlisted_tools` — only `web_search_exa` runs; `default_result_count` — no call sets a result count, so Exa's default of 10 applies. Ledger and guard-block paragraphs as in `capabilities/scraping/contract.md`.
- `identity.yaml`: `capability: web_search`, `provider: exa`, `server_match: exa` (connector name must contain it; confirm against Step 1).
- `guard.yaml`: header comment citing the probe note; `covers: [no_external_send, allowlisted_tools, default_result_count]`; `allow: [web_search_exa]`; `only_keys` for `web_search_exa` at `$` with keys `[query]`.
- `usage.md`: maps `search_web` to `web_search_exa {query}`; the query form from the spec ("owner or principal of <business>, <trade> at <street address>, <city> (<domain>)"); `## Setup` (add the connector at claude.ai, name containing `exa`, key or OAuth in the connector, attach it to the prospect routine); `## Probe` (one `web_search_exa` call on the operator's own business, records nothing in bindings); `## Cost` (estimate `0.007` USD per call, measured 2026-10-31).
- `agent.yaml` lines above.

- [ ] **Step 5: Run tests and validator**

Run: `bash tests/run-all.sh 2>&1 | tail -1 && python3 -B hooks/tool_check.py capabilities/web_search/tools/exa capabilities/web_search/contract.md && ../agent-builder/bin/validate-agent.sh .`
Expected: `ALL GREEN`, `OK:`, `OK: . conforms`.

- [ ] **Step 6: Commit** `feat: web_search capability with the Exa connector tool`

---

### Task 3: `find-decision-makers` uses Exa and grades every source

**Files:**
- Modify: `skills/find-decision-makers/SKILL.md` (Procedure step 2, step 6, a new "Source strength" section, Failure modes)
- Test: `tests/test-content.sh`

- [ ] **Step 1: Failing content assertions** (`assert_contains` on the skill): `search_web`, `bind_web_search`, `directory only`, `conflicting sources`, `Strong`, `licence`, `Diamond Certified`, `One search per lead`.

- [ ] **Step 2: Run** `bash tests/test-content.sh 2>&1 | grep FAIL` — expected: the new assertions fail.

- [ ] **Step 3: Edit the skill**

Step 2 begins: when `instance.yaml` has `bind_web_search`, make one `search_web` call first with the spec's query form; otherwise skip it (not an error). Add "Source strength" with the strong list and the weak/conflict rules from Global Constraints, applying to every source in step 2. Step 6: a weak-only source never supports `Verified`. Add a failure mode: "Trusting an aggregator directory". The worked example stays fictional.

- [ ] **Step 4: Run** `bash tests/run-all.sh 2>&1 | tail -1` — expected `ALL GREEN`.

- [ ] **Step 5: Commit** `feat(find-decision-makers): Exa search and source strength for every source`

---

### Task 4: Preparer: Exa spend outside the Apify caps; failure handling

**Files:**
- Modify: `subagents/preparer.md` (sources list ~:104; caps :111-112, :313-366; the stop-scraping sentence ~:141 and ~:299-360)
- Test: `tests/test-content.sh`

- [ ] **Step 1: Failing content assertions** on `preparer.md`: `search_web` steps are excluded from the 7-day sum (text containing `detail` starts with `search_web`); `Exa keeps running` (or equivalent fixed phrase you choose and assert) after a cap stop; a failed `search_web` call does not stop research or notify the owner.

- [ ] **Step 2: Run** — expected: they fail.

- [ ] **Step 3: Edit**

Sources list gains "Exa web search, when `web_search` is bound". 7-day cap: sum `cost_usd` only over `step` events whose `detail` does not start with `search_web`. Per-lead cap: counts Apify calls only (already says so; add that `search_web` is excluded). When a cap stops scraping, research carries on with web search, Exa included. A `search_web` failure: retry once, failed `step`, continue.

- [ ] **Step 4: Run** `bash tests/run-all.sh 2>&1 | tail -1` — expected `ALL GREEN`.

- [ ] **Step 5: Commit** `feat(preparer): Exa spend stays out of the Apify caps`

---

### Task 5: Release 8.2.0

**Files:**
- Modify: `agent.yaml`, `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, `gemini-extension.json` (`8.2.0`); `README.md` ("Version 8.2.0." and an upgrade note); `tests/test-content.sh` version assertions
- Modify (builder repo, separate small commit on its own branch or folded into the builder PR if still open): `docs/how-it-works.md` current versions line

- [ ] **Step 1:** Upgrade note: Exa is optional; to use it, add the Exa connector at claude.ai, re-run setup's tools step (binds `web_search`), then the schedule skill (attach the connector to the prospect routine, update the environment's version comment and `agent_version` to 8.2.0). Without Exa: only the environment comment and `agent_version`.
- [ ] **Step 2:** Run `bash tests/run-all.sh 2>&1 | tail -1 && ../agent-builder/bin/validate-agent.sh . --require-bump origin/main` — expected `ALL GREEN`, `OK`.
- [ ] **Step 3:** Commit `feat: Exa decision-maker search (8.2.0)` with the spec and this plan; push over HTTPS; open the PR; stop for the user to merge.

---

### Task 6: Live rollout and smoke test (with the user)

**Files:** live instance `live-agents/webspenser-sales-partner` (`instance.yaml`, `schedules.yaml`); no package files.

- [ ] **Step 1:** User: Exa connector exists (Task 2 Step 1). Re-run setup's tools step in the instance: answer yes for Exa; it adds `bind_web_search: exa`. Commit and push the instance over HTTPS.
- [ ] **Step 2:** Run the schedule skill: `check` shows `web_search` as a bound connector on the prospect entry; user attaches the `ExaSearch` connector to the prospect routine; `verify` prints `OK`. Set `agent_version: 8.2.0`; user sets the environment comment `# sales-partner 8.2.0`.
- [ ] **Step 3:** User runs the prospect routine (Run now). Read the log with `RemoteTrigger get_run_log`: 8.2.0 loaded; `web_search_exa` calls not blocked; one per researched lead.
- [ ] **Step 4:** Compare names written in Attio with the baseline in `live-agents/exa-test-2026-10-31/results2.json` for the four strong-source leads. Pass: all four named with a strong source. Report the comparison to the user; if fewer, report the gap (the release stands).
