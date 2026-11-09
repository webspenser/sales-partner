# Open Scraping Guard, Phase A (8.6.0) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the Apify guard from per-actor key allowlists to the open retrieval profile, make scraping failures carry on and report, turn on reviewer names, personal emails and LinkedIn email search, and release sales-partner 8.6.0 on Agent Standard 7.5.

**Architecture:** One agent-builder change first (Standard 7.5: a written retrieval profile, no engine change), then sales-partner changes in four parts: the guard and its policy tests, the drift rules, the personal-data rules, and the release. Phase B (new actors, `apify_web`) is out of scope and gets its own plan after its probes.

**Tech Stack:** Markdown agent plugin; YAML guard policies run by `hooks/guard_policy.py` (Python 3, stdlib); bash tests (`tests/run-all.sh`); agent-builder validator (`../agent-builder/bin/validate-agent.sh`).

**Spec:** `docs/superpowers/specs/2026-11-09-open-scraping-guard-design.md`

## Global Constraints

- `bash tests/run-all.sh` ends `ALL GREEN` after every task in this repo; in agent-builder, its own `tests/` runner ends green.
- `../agent-builder/bin/validate-agent.sh . --require-bump origin/main` passes before the release commit.
- `AGENT.md` stays under 6000 bytes (it is 5983): do not add to it.
- Versions: sales-partner `8.6.0` in `agent.yaml`, both `plugin.json` files and `gemini-extension.json`; `standard: "7.5"` in `agent.yaml`; agent-builder `7.5.0` and `CURRENT_STANDARD = "7.5"`.
- No engine change: every guard rule uses elements `hooks/guard_policy.py` has today.
- Kept hard rules (spec): actors allowed by name; generic tools denied; every size key pinned or capped with omission blocked; URL rules; shared `refuse_args`; cost or scope `fixed` values.
- Never recorded from reviews: `reviewer_url`, `reviewer_photo_url`, `reviewer_photo`, `reviewer_id`.
- A pattern-guessed address is never written to `email` (`notes` only); no address is invented.
- Guard blocks on any capability other than scraping still stop the activity.
- Doc and test text is normal prose (not caveman). Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Rulings made while planning

- **Per-actor refusals use `fixed: null`, not `refuse_args`.** The engine's `refuse_args` is one list for the whole policy (`hooks/guard_policy.py:293-298`), so it cannot refuse `startUrls` on Maps while the site reader needs it, nor `maxItems` on jobs while LinkedIn needs it. A `fixed` entry with `value: null` and no `required` blocks any non-null value at that key on the named tools only (checked: `{"startUrls":[...]}` blocked with `must send startUrls = null`, `{}` passes, other tools unaffected). So: generic keys go in the shared `refuse_args`; each actor's known scope or cost keys (today's per-actor refused lists) become per-tool `fixed: null` entries. Cost if wrong: a less clear block message; the Standard note explains it.
- **`max_web_fetches` waits for Phase B.** It only has meaning with `apify_web`, which Phase B adds.

## Review Focus

1. A respelled cap key sent beside the real one (`{"maxItems":5,"MaxItems":5000}`) now passes the guard. Expected: the vendor reads the exact key only, so the cap holds; the Standard 7.5 note names this as part of the bounded residual. Task 3 adds one test that pins the pass, so the behavior is chosen, not accidental.
2. A null sent for a per-tool refused key (`{"startUrls":null}` on Maps) passes. Expected: harmless (the actor treats null as absent). Task 3 pins it.
3. A source blocked on the first lead, then on a second: the third lead never calls it, and the run report lists it once per lead as `<source>; blocked`. Task 4's eval covers it.
4. A review with `reviewer_name` but a complaint: talking points still keep it in `Avoid:` and never quote it back at the owner. Task 5's eval covers it.
5. A personal Gmail address found by LinkedIn email search for the owner wins point of contact over an unnamed info@ row. Task 5's eval covers it.

---

### Task 1: Agent Standard 7.5 — the retrieval profile (agent-builder repo)

Work in `/Users/hochoy/Work/Webspenser/agent-builder` on a new branch `feat/retrieval-profile`.

**Files:**
- Modify: `STANDARD.md` (version lines 14, 17, 235, 1575; the `only_keys` paragraph at 607-611; the `pinned_inputs` and `no_external_send` text at 344-355)
- Modify: `bin/lib/check_manifests.py:24`
- Modify: `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, `gemini-extension.json` (7.4.0 → 7.5.0)
- Modify: `tests/test-builder-manifests.sh` (the version it pins), and any `_template` or `docs/how-it-works.md` line naming 7.4 (follow commit `f80a8d9` as the pattern)

**Interfaces:**
- Produces: Standard `"7.5"`, which sales-partner's `agent.yaml` names in Task 6.

- [ ] **Step 1: Write the failing test.** In `tests/test-builder-manifests.sh`, change the pinned version to `7.5.0`; add an assertion that `STANDARD.md` contains `### Retrieval profile` and the sentence `A retrieval profile does not satisfy pinned_inputs by key allowlist; it satisfies it by capping every size key its probe found.`
- [ ] **Step 2: Run it.** Run: `bash tests/test-builder-manifests.sh`. Expected: FAIL on the version and the missing heading.
- [ ] **Step 3: Write the Standard text.** Bump the version lines. After the `only_keys` paragraph, add `### Retrieval profile`, saying:
  - which tools may use it: a capability whose contract claims `no_external_send` and whose tools only read (scrapers);
  - its rules: tools allowed by name; generic run-anything tools denied; a shared `refuse_args` of code and request-control keys; per-tool scope keys refused with `fixed` and `value: null`; every size key from the probe pinned (`recipients`) or capped (`limits` with `required: true`); `urls` rules on every URL argument;
  - what `pinned_inputs` means under it (the sentence from Step 1), and that an unknown size key or a respelled cap key is a documented, bounded residual, backed by the provider's own account limit;
  - what `no_external_send` means under it: a fetch tool limited to `https` public hosts with `query` and `fragment` forbidden; data riding in a path or hostname is the documented residual, the same class as the existing hostname note;
  - that `tool_check`'s pinned-or-read rule is unchanged and still applies.
  Update the `only_keys` paragraph's first sentence to "An allowlist (`only_keys`) is the recommended way to restrict arguments, except under the retrieval profile below." Set `CURRENT_STANDARD = "7.5"` and the three manifests to `7.5.0`.
- [ ] **Step 4: Run the agent-builder suite.** Run its full runner (`bash tests/run-all.sh` or the runner `tests/` names). Expected: all pass.
- [ ] **Step 5: Commit.** `git commit -m "docs: retrieval profile (Standard 7.5, builder 7.5.0)"`. Do not push or merge; the operator merges agent-builder before Task 6's validator run. Stop here and tell the operator only if they want it pushed now.

---

### Task 2: Probe LinkedIn email search

**Files:**
- Create: `docs/superpowers/notes/2026-11-09-linkedin-email-search-probe.md`

**Interfaces:**
- Produces: `MODE` — the exact `profileScraperMode` string for email search, and `PRICE` — the price per profile in that mode. Tasks 3 and 5 use both.

- [ ] **Step 1: Read the actor's input schema** with the connector's actor details for `harvestapi/linkedin-profile-search-by-name`; record the `profileScraperMode` enum values and the pricing table.
- [ ] **Step 2: Run one call:** `{"firstName":"<a public owner from a live lead>","lastName":"…","locations":["<city>"],"maxItems":1,"maxPages":1,"profileScraperMode":"<MODE>","strictSearch":true,"waitSecs":45}`. If the installed guard hook blocks it (it pins `"Full"`), ask the operator to run the same input in Apify Console and paste the run's input, the item and the charged price; do not edit the installed plugin to get around the hook.
- [ ] **Step 3: Write the note:** date, actor, `MODE` exactly, `PRICE`, the email field names in the output (`emails[]` or what it shows), whether personal domains appear, and the item fields `usage.md`'s projection should take.
- [ ] **Step 4: Commit.** `git commit -m "docs: probe LinkedIn email search mode"`.

---

### Task 3: Convert the Apify guard to the retrieval profile

**Files:**
- Modify: `capabilities/scraping/tools/apify/guard.yaml`
- Test: `tests/test-policies.sh` (the `-- scraping (apify)` section, lines ~108-360)
- Modify: `tests/test-content.sh:1231` (pins old guard-comment phrases)

**Interfaces:**
- Consumes: `MODE` from Task 2.
- Produces: guard behavior Tasks 4-6 document: block messages `may not use <key>` (shared list) and `must send <key> = null` (per-tool scope keys).

The shared `refuse_args` (my call: the spec's list plus the generic cookie, header and proxy keys today's tests already refuse):
`[pageFunction, preNavigationHooks, postNavigationHooks, customData, headers, customHttpHeaders, cookies, cookie, initialCookies, sessionCookies, sessionCookie, li_at, requestsFromUrl, "startUrls[].requestsFromUrl", "startUrls[].headers", "startUrls[].payload", "startUrls[].method", "startUrls[].userData", webhooks, proxyConfiguration, proxyConfig, proxy, proxyCountryCode]`

Per-tool `fixed: null` (no `required`), from today's tests:
- Maps: `locationQuery, startUrls, placeIds, customGeolocation, scrapeContacts, maxReviews, scrapePlaceDetailPage, website`
- contacts: `useBrowser, waitUntil, maximumLeadsEnrichmentRecords, scrapeSocialMediaProfiles`
- reviews: `place_urls, search, search_location, search_limit, search_coordination, sort_dataset, sort_keys`
- Google Ads: `includeDetails, onlyNewAds, monitorStoreName, includeRawData, startUrls, urlsFromFile, domains, advertiserIds`
- Facebook: `isDetailsPerAd, includeAboutPage, enrichWithEcommerceData, sorting, onlyAdsOlderThan`
- jobs: `maxItems, startUrls`
- site reader (its code and header keys are in the shared list): `summarize, saveScreenshots, saveContentTypes, saveFiles, saveHtmlAsFile, includeUrlGlobs, useSitemaps, useLlmsTxt, clickElementsCssSelector, waitForSelector, maxConcurrency`
- LinkedIn search: `currentCompanies, pastCompanies, schools, currentJobTitles, industryIds, profileUrls, searchQuery`
- Instagram: `includeAboutSection, directUrls, resultsLimit, resultsType, searchType`
- TikTok: `commentsPerPost, topLevelCommentsPerPost, maxRepliesPerComment, maxFollowersPerProfile, maxFollowingPerProfile, shouldDownloadVideos, shouldDownloadCovers, shouldDownloadSlideshowImages, shouldDownloadAvatars, downloadSubtitlesOptions, oldestPostDateUnified, newestPostDate, leastDiggs, mostDiggs, profileSorting, excludePinnedPosts, profileScrapeSections, videoKvStoreIdOrName`

- [ ] **Step 1: Write the failing tests** in `tests/test-policies.sh`:
  - Add `nulled() { # nulled <label> <tool> <ok json> <key>...: each per-tool scope key blocked, even false }` expecting `must send $key = null`, beside `refused`. Move every per-tool key above from its `refused …` or `for a in …` line to a `nulled …` line; keep the shared keys on `refused` lines (still `may not use`).
  - Per actor, one `check 0 "<label> unknown harmless input passes"` with the ok JSON plus `"someNewVendorOption":true`.
  - Per actor with `startUrls`, `start_extras` stays (shared nested refusals keep `may not use startUrls[].X`); the "start URL as a bare string" check changes to expect what the `urls` rule now says (`startUrls[].url` missing) — run once and pin the actual message.
  - Each "respelled key" check where the real key is still present flips to `check 0`; Review Focus 1: `check 0 "linkedin search respelled cap beside the real one passes"` with `"MaxItems":5000` added to `LI_OK`.
  - Review Focus 2: `check 0 "maps null scope key passes"` with `"startUrls":null`.
  - Reviews: `REV_OK` uses `"include_personal":true`; the fixed checks expect `must send include_personal = true` (false, omitted, string `"true"`, null).
  - LinkedIn: `LI_OK` uses `"profileScraperMode":"<MODE>"`; `"Full"` and `"Short"` are now blocked with `must send profileScraperMode = "<MODE>"`.
  - The `get-actor-run` and `get-dataset-items` "other arg" checks stay `may not use` (their `only_keys` stay).
- [ ] **Step 2: Run them.** Run: `bash tests/test-policies.sh 2>&1 | grep -c '^not ok'`. Expected: failures on every `nulled`, harmless-input, respelled, `include_personal` and mode check.
- [ ] **Step 3: Rewrite `guard.yaml`.** Delete the actor `only_keys` entries; keep the two run-read entries (`get-dataset-items`: `datasetId, fields, limit, offset, clean, omit, desc`; `get-actor-run`: `runId, waitSecs`). Add the shared `refuse_args` and the per-tool `fixed: null` entries above. Change the reviews fixed value to `true` and the LinkedIn mode to `'<MODE>'`. Keep `allow`, `deny`, `recipients`, `limits`, `urls` and the other `fixed` entries as they are. Rewrite the header comment: retrieval profile (Standard 7.5), why `fixed: null` is used per tool, the residual (unknown keys, respelled cap keys, data in a handle or hostname), and the personal-data values as the operator's choice in 8.6.0.
- [ ] **Step 4: Run the policy tests.** Run: `bash tests/test-policies.sh`. Expected: all ok.
- [ ] **Step 5: Fix the content pins.** In `tests/test-content.sh:1231`, replace the two old guard-comment phrases with `retrieval profile (Standard 7.5)` and `fixed: null`. Run: `bash tests/run-all.sh`. Expected: `ALL GREEN`. (The docs still say `include_personal: false` and `"Full"` until Task 5; their content pins test the docs, not the guard, so they stay green.)
- [ ] **Step 6: Commit.** `git commit -m "feat(scraping): open retrieval profile for the Apify guard"`.

---

### Task 4: Drift — carry on and report

**Files:**
- Modify: `subagents/preparer.md:463-465`, `subagents/prospector.md:102-104`
- Modify: `capabilities/scraping/contract.md` (the guard-block sentence after the Operations table)
- Modify: `capabilities/scraping/tools/apify/usage.md` (new `## Drift` section before `## Cost`)
- Test: `tests/test-content.sh:613,619` and a new `-- 8.6.0: drift` block; `evals/cases.md` (four new cases)

**Interfaces:**
- Consumes: Task 3's block messages.
- Produces: the run-report strings `drift: <tool> <field> empty`, `<source>; vendor error`, `<source>; blocked`, which the digest and evals quote.

- [ ] **Step 1: Write the failing content tests:**
  - `assert_contains` in preparer and prospector: `A guard block on a scraping call does not stop the activity` and `never retried with changed arguments`; `Never retry a guard` stays pinned.
  - preparer: `after the same source is blocked on 2 leads in one run, it is skipped for the rest of the run`; `one \`notify_owner(kind: error)\` at the end of the run`.
  - usage.md: `## Drift` and the three report strings exactly.
  - contract.md: `A guard block on a scraping call skips that source for the lead`; `assert_not_contains` contract.md `A guard block on a scraping call stops the activity`.
  - evals: headings `## Case 56: An empty mapped field is reported as drift and records nothing`, `## Case 57: A vendor error skips the source for that lead and research goes on`, `## Case 58: A guard block skips the source, and after 2 leads the source is skipped for the run`, `## Case 59: A source failing on every lead sends one error at the end of the run`.
- [ ] **Step 2: Run.** `bash tests/test-content.sh`. Expected: FAIL on each new pin.
- [ ] **Step 3: Write the rules** from the spec's Drift table in usage.md `## Drift`; in preparer and prospector, replace the stop rule with: scraping blocks follow usage.md `## Drift`; a guard block on any other capability stops the activity and calls `notify_owner(kind: error)` with the block's message; never retry a guard block. Update contract.md's sentence to match. Write cases 56-59 in the existing case format (setup, expected, why it matters, how to check); case 58 covers Review Focus 3.
- [ ] **Step 4: Run.** `bash tests/run-all.sh`. Expected: `ALL GREEN`.
- [ ] **Step 5: Commit.** `git commit -m "feat(scraping): carry on and report when a source drifts or is blocked"`.

---

### Task 5: Personal data — reviewer names, personal emails, LinkedIn email search

**Files:**
- Modify: `capabilities/scraping/contract.md` (`find_reviews` Returns; `find_profiles` Returns gains emails)
- Modify: `capabilities/scraping/tools/apify/usage.md` (`find_reviews` block and its `fields` projection; `find_profiles` mode line 129-131; fixed-values sentence 183-187; `## Cost` LinkedIn line with `PRICE`)
- Modify: `subagents/preparer.md:333-334`, `skills/research-company/SKILL.md:103-111`, `skills/write-talking-points/SKILL.md`, `skills/find-decision-makers/SKILL.md` (step 4 and step 7), `skills/pick-point-of-contact/SKILL.md` (only if its eligibility text names a domain rule; today it does not)
- Modify: `evals/cases.md` Case 29 (rename and rewrite), plus two new cases
- Test: `tests/test-content.sh` lines 1007-1008, 1024, 1073, 1101-1102, 1125, 1132, 1274

**Interfaces:**
- Consumes: Task 3's `include_personal: true` and `<MODE>`; Task 2's `PRICE` and email field names.

- [ ] **Step 1: Rewrite the failing content tests:**
  - Replace pins of `include_personal: false` with `include_personal: true` (usage.md `always pass \`include_personal: true\`; the guard requires it`, preparer, research-company).
  - `assert_contains` usage.md `reviewer_name` in the `find_reviews` fields line; `assert_not_contains` usage.md `never record reviewer names`; keep `assert_not_contains "$SU" 'reviewerId,'`; add `assert_not_contains` for `reviewer_url,` `reviewer_photo_url,` `reviewer_id,` in the fields line.
  - research-company: `A review finding may name its reviewer`; `never the reviewer's profile URL, photo or ID`.
  - write-talking-points: `may cite a review by its reviewer and date`; the complaint-review `Avoid:` rule still pinned.
  - find-decision-makers: `whatever its domain` and `the Contact's notes say where it was found`; the pattern-guess pins stay.
  - usage.md: `profileScraperMode` — `always \`"<MODE>"\``; `## Cost` names the LinkedIn email-search price.
  - evals: `## Case 29: A review signal is quoted with its date, link and reviewer's first name` (replacing the old heading at test line 1125 and the `'`include_personal: false`'` literal at 1132); `## Case 60: A complaint review is named only in Avoid and never quoted back`; `## Case 61: A personal email from LinkedIn email search makes the owner the point of contact`.
- [ ] **Step 2: Run.** `bash tests/test-content.sh`. Expected: FAIL on each changed pin.
- [ ] **Step 3: Write the rules** from the spec's Personal data section into each file listed. Case 29 now expects "Marco" may appear in the finding and talking points as the reviewer's name, with no `reviewer_url`, photo or ID anywhere; its why-it-matters says the operator chose names for context (quote the operator's sentence from the spec). Case 60 covers Review Focus 4; case 61 covers Review Focus 5. README lines 29 and 154: reviewer names now kept, profile links and photos never.
- [ ] **Step 4: Run.** `bash tests/run-all.sh`. Expected: `ALL GREEN`.
- [ ] **Step 5: Commit.** `git commit -m "feat: reviewer names, personal emails and LinkedIn email search"`.

---

### Task 6: Setup, README and the 8.6.0 release

**Files:**
- Modify: `capabilities/scraping/tools/apify/usage.md` `## Setup` (step 1: confirm the Apify monthly usage limit is set; the agent does not read it)
- Modify: `README.md` (`Version 8.6.0.`; an "Upgrading from 8.5.1" note: Standard 7.5, open guard, drift behavior, personal-data changes, LinkedIn email-search cost, re-run setup's tools step not needed in Phase A)
- Modify: `agent.yaml` (`version: 8.6.0`, `standard: "7.5"`), `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json` (if present), `gemini-extension.json`
- Test: `tests/test-content.sh` new `-- 8.6.0: release` block

**Interfaces:**
- Consumes: Task 1's Standard 7.5 (agent-builder branch checked out or merged in `../agent-builder`).

- [ ] **Step 1: Write the failing tests:** README contains `Version 8.6.0.` and `Upgrading from 8.5.1`; usage.md Setup contains `confirm that the Apify monthly usage limit is set`; `agent.yaml` contains `standard: "7.5"`.
- [ ] **Step 2: Run.** `bash tests/test-content.sh`. Expected: FAIL on the three pins.
- [ ] **Step 3: Write** the README note, the Setup line and the version bumps.
- [ ] **Step 4: Run everything.** Run: `bash tests/run-all.sh` — Expected: `ALL GREEN`. Run: `../agent-builder/bin/validate-agent.sh . --require-bump origin/main` with `../agent-builder` on `feat/retrieval-profile` — Expected: pass, and `tool_check` accepts every allowed actor as pinned or read. If `tool_check` refuses a claim, stop: the schedule gate would stop every scheduled run.
- [ ] **Step 5: Commit.** `git commit -m "chore: sales-partner 8.6.0 (Standard 7.5)"`. Pushing, merging and the agent-builder merge are the operator's call.
