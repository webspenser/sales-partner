# Social Profiles for Contacts (sales-partner 8.3.0) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** For every contact at a lead, find the person's public LinkedIn, Instagram, Facebook and TikTok profiles, plus X when it turns up. Confident matches are written to the person's CRM fields, and uncertain candidates go into an append-only note on the person. This covers new leads and the backlog already at `Researched`.

**Architecture:** Two new scraping operations, `find_profiles` and `read_profile`, run on Apify actors chosen by a live probe and guarded like the existing seven. A new skill, `find-social-profiles`, holds the matching rules. The Preparer runs a separate **profile pass** after its whole prepare queue. The pass works on `Researched` leads whose contacts haven't been checked, so evidence always spends first. The CRM contract gains person social fields, a `Profiles Checked At` marker and a `log_possible_profiles` note operation, in both Attio and HubSpot.

**Tech Stack:** markdown skills and contracts, YAML guard policies run by the Agent Standard engine (`hooks/guard_policy.py`), Python `bootstrap.py` scripts, bash tests (`tests/lib.sh`).

**Spec:** `docs/superpowers/specs/2026-11-03-social-profiles-design.md` (approved 2026-11-03).

## Global Constraints

- **Version:** `8.3.0`, `standard: "7.4"` unchanged. No agent-builder change and no `hooks/` change. If the probe shows a guard key the engine lacks, stop and raise it: it becomes a builder change first.
- **Branch:** `feat/social-profiles` (already holds the spec commit).
- **Platforms and order:** LinkedIn, Instagram, Facebook, TikTok. X is recorded only when a source already returned it; never run a search just for X.
- **Never act on a platform.** No follow, connect, like, comment, post or message. Reading public profiles, including through an actor, is allowed. Allowed actors must need no login, cookies, session or account credentials.
- **Keep only URLs and reasons.** Never write bios, posts, photos, follower counts or follower lists to the CRM.
- **Confident** means:
  - a link between the profile and the business (the profile links to the business's site or its own social pages, or a business page links or tags the profile), **or** a LinkedIn profile whose current employer, read from the profile, is this business;
  - **and** no contradicting signal.
  - Name or location alone is never confident.
  - If two candidates for one platform both qualify, both are uncertain.
- **A shared-platform website is never a business link.** That covers the hosts in `subagents/preparer.md`'s shared-platform list, for example a linktree or wix root.
- **Write only when the field is empty.** A social field already set, by the operator, by Attio enrichment or by an earlier run, is never overwritten.
- **Budget:** the profile pass spends from `apify_cap_usd_per_lead` (default `0.50`) and `apify_spend_cap_usd_per_week`. No new cap key.
  - The pass runs only after every queued lead in the run has been prepared.
  - Within the pass, leads prepared in this run come first. The backlog follows, oldest `Stage Changed At` first.
  - A cap or the time budget leaves the lead unchecked: no `Profiles Checked At` is written. That is **not** Research Capped.
- **Skips:**
  - A lead with Do Not Contact set moves to `Disqualified` (reason `opt-out`) and nothing else is written.
  - A lead at `Approved` or later is never written. Re-check the stage immediately before the first write.
  - A contact with no person's name (for example a generic inbox) is not searched.
- **New CRM names:**
  - `upsert_contact` arguments: `instagram_url`, `facebook_url`, `tiktok_url`, `x_url`, `profiles_checked_at`.
  - Company profile fields: `tiktok_url`, `x_url`.
  - Operation: `log_possible_profiles(lead_id, contact_id, body)`.
  - Note title: `Sales Partner · Possible Profiles`.
- **Attio slugs:**
  - People: `linkedin`, `instagram`, `facebook`, `twitter` (built in); `sp_tiktok` and `sp_profiles_checked_at` (new, custom).
  - Companies: `twitter` (built in); `sp_tiktok` (new, custom).
- **HubSpot properties:**
  - Contacts: `hs_linkedin_url`; new `sp_instagram_url`, `sp_facebook_url`, `sp_tiktok_url`, `sp_x_url`, `sp_profiles_checked_at`.
  - Companies: none. HubSpot keeps skipping the company profile fields.
- **Source name** in `prospecting_sources`: `apify_profiles`. It is added to the default list. A list without it means no profile pass.
- **Public repo:** no real person's name, handle or profile URL in any committed file, probe notes included. Raw probe output goes to `live-agents/social-profiles-probe-2026-11/`, outside the repo.
- **AGENT.md:102** becomes: "Never act on LinkedIn or any social platform: no follow, connect, message or post. Reading public profiles is fine."
- **Tests:** every task leaves `bash tests/run-all.sh` ending `ALL GREEN`, and `finish` stays the last line of `tests/test-content.sh`. Restore exec bits on `tests/*.sh` after edits.
- **Commits** end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never push without the operator asking.

## Review Focus

1. **A common name.** For example, two "J. Smith" Instagram accounts in the lead's city, neither linking to the business. Both must go to the note and neither to the field. Pinned by an eval (Task 6) and a skill content assertion (Task 4).
2. **A candidate whose only "business link" is a shared-platform website**, such as a linktree page the business also uses. This must not count as confident. Pinned in Task 4 (content) and Task 6 (eval).
3. **A social field the operator filled by hand.** It must never be overwritten, even by a confident match. Pinned in Task 3 (contract and usage text) and Task 6 (eval).
4. **A `read_profile` URL on a lookalike host or carrying data.** Examples: `https://instagram.com.evil.example/x`, `https://www.instagram.com/x?ref=1`, an IP address, `http://`. The guard must block each. Pinned in Task 2 policy tests.
5. **A backlog lead the operator moves to `Approved` while the pass is running.** No write may land. Pinned in Task 5 (the re-check before the first write) and Task 6 (eval).

---

### Task 1: Live probe of candidate profile actors (operator present)

**Files:**
- Create: `docs/superpowers/notes/2026-11-03-social-profiles-actors-probe.md`

**Interfaces:**
- Produces, for each chosen actor, the facts Tasks 2 and 5 use verbatim:
  - the exact MCP tool name;
  - the full input schema;
  - the size and cost arguments with their defaults, and which become pins (to which binding) or `limits`;
  - the target argument;
  - the arguments to block (cookies, sessions, proxies, headers, paid add-ons);
  - the output fields used for scoring (profile URL, name, bio, location, external links, current employer);
  - the cost per result, and a per-person estimate.
- Produces a "Values for Tasks 2–5" table in the notes.

- [ ] **Step 1: Ask the operator to add the candidates to the Apify connector's restricted URL.** Keep the seven existing actors. Candidates, in preference order:
  - `tri_angle/find-social-media-profiles` (name to many platforms);
  - `harvestapi/linkedin-profile-search-by-name` (name plus company, no cookies);
  - `apify/instagram-profile-scraper` (read a known handle);
  - one Instagram discovery actor (`scrapearchitect/ultimate-instagram-profile-scraper` or `seemuapps/instagram-user-search-scraper`);
  - one TikTok profile reader (the most-used no-login actor in the store at probe time).

  Confirm with ToolSearch that each tool is exposed.
- [ ] **Step 2: Record each schema and its bounding, login and cookie arguments** without calling the actor. Reject any actor that needs a login or cookies to return profiles, and say why.
- [ ] **Step 3: With the operator's OK, run one minimal call per actor.** Use the operator's own name and business as the subject, with consent. Raw output goes to `live-agents/social-profiles-probe-2026-11/`. The committed notes keep only field names, counts, run IDs, compute units and cost.
- [ ] **Step 4: Also try one Exa `search_web` for the same person.** Record whether it returns profile URLs, to decide whether Exa does part of the discovery.
- [ ] **Step 5: Fill the "Values for Tasks 2–5" table:**
  - the chosen actors (at most four), with the reasons for each pick and rejection;
  - which operation each one serves;
  - the binding names, defaults, `only_keys`, `fixed` values and per-platform URL hosts and path prefixes.
- [ ] **Step 6: Commit** `docs: social profile actors probe`.

---

### Task 2: Scraping contract, Apify guard and usage: `find_profiles` and `read_profile`

**Files:**
- Modify: `capabilities/scraping/contract.md` (Operations table)
- Modify: `capabilities/scraping/tools/apify/guard.yaml`:
  - `allow` and an `only_keys` per new tool;
  - pins and `limits` from Task 1;
  - `fixed` values for any safety setting;
  - `urls` rules on every URL argument;
  - the header comment updated.
- Modify: `capabilities/scraping/tools/apify/usage.md`:
  - the operation mappings, result mapping and `## Cost`;
  - `## Setup` bindings;
  - the connector URL listing all actors.
- Test: `tests/test-policies.sh` (the `-- scraping (apify)` block and its bindings fixture), `tests/test-content.sh`

**Interfaces:**
- Consumes: the Task 1 values table.
- Produces:
  - `find_profiles(name, business, city, platforms[])` returns candidates. Each candidate has `platform`, `url`, `display_name`, `bio`, `location`, `external_links[]`, `current_employer` (when the source gives one), plus the run's cost.
  - `read_profile(url)` returns the same fields for one profile, plus cost.
  - Failure handling for both is the same as `find_businesses`.
  - New bindings: `max_profile_results` (default `5`) and `max_profile_reads` (default `10`). The probe may add more, named `max_<thing>`.
  - `read_profile` URL rules: https only, path any, no query or fragment, on these hosts per platform:
    - LinkedIn: `linkedin.com`, `www.linkedin.com`, with path prefix `/in/`;
    - Instagram: `instagram.com`, `www.instagram.com`;
    - Facebook: `facebook.com`, `www.facebook.com`;
    - TikTok: `tiktok.com`, `www.tiktok.com`, with path prefix `/@`.

    Narrow these if Task 1 shows one actor per platform.

- [ ] **Step 1: Write the failing policy cases for each new tool**, using `check`, `pins`, `lists`, `refused`, `start_url` and `start_extras`:
  - an in-limit call is allowed;
  - each pinned argument raised or omitted is blocked, naming its binding;
  - each counted list over its bound or empty is blocked;
  - a respelled key is blocked ("may not use");
  - every cookie, session, proxy or header key is blocked, even when set to `false`;
  - each `fixed` value omitted or changed is blocked.
- [ ] **Step 2: Write the URL cases (Review Focus 4).** `start_url 2` for each of:
  - `https://instagram.com.evil.example/x`;
  - `https://www.instagram.com/x?ref=1` ("a query is not allowed");
  - `http://www.instagram.com/x`;
  - `https://93.184.216.34/x`;
  - `https://www.linkedin.com/company/x` (outside `/in/`);
  - `https://www.tiktok.com/x` (outside `/@`).

  Then `start_url 0` for one valid URL per platform.
- [ ] **Step 3: Run** `bash tests/test-policies.sh 2>&1 | grep -cE 'FAIL'`. Expected: the new cases fail.
- [ ] **Step 4: Edit the contract, guard and usage.md** as listed under Files. `usage.md` says to pass names and cities only, never a handle guessed from the name.
- [ ] **Step 5: Add content assertions:**
  - both operations appear in `contract.md` and `usage.md`;
  - both binding keys appear in `usage.md`'s `## Setup`;
  - `usage.md` contains `no login`.
- [ ] **Step 6: Run** `bash tests/run-all.sh 2>&1 | tail -1 && python3 -B hooks/tool_check.py capabilities/scraping/tools/apify capabilities/scraping/contract.md`. Expected: `ALL GREEN` and `OK:`.
- [ ] **Step 7: Commit** `feat(scraping): find_profiles and read_profile through Apify, guarded`.

---

### Task 3: CRM contract and both tools: person social fields, the checked marker, the possible-profiles note

**Files:**
- Modify: `capabilities/crm/contract.md`:
  - the Operations table: `upsert_contact` arguments, `get_lead` returns, and the new `log_possible_profiles`;
  - Company profile fields;
  - a new "Social profile fields" subsection;
  - Approval invariant: the agent writes no possible-profiles note and no social field on a lead at `Approved` or later.
- Modify: `capabilities/crm/tools/attio/usage.md` (People and Companies tables, the note procedure, `## Setup`, `## Probe`), `capabilities/crm/tools/attio/bootstrap.py`
- Modify: `capabilities/crm/tools/hubspot/usage.md` (Contacts table, the note procedure, `## Setup`, `## Probe`), `capabilities/crm/tools/hubspot/bootstrap.py`
- Modify (only if Step 1's cases fail): `capabilities/crm/tools/attio/guard.yaml`, `capabilities/crm/tools/hubspot/guard.yaml`
- Test: `tests/test-policies.sh` (Attio and HubSpot blocks), `tests/test-content.sh`

**Interfaces:**
- Produces:
  - `upsert_contact(lead_id, name, title, email, phone, linkedin_url, instagram_url, facebook_url, tiktok_url, x_url, profiles_checked_at, role, verified, notes)`.
    - Each social argument is written only when the CRM field is empty.
    - `profiles_checked_at` is an ISO date-time, written every time a person's search completes.
  - `get_lead` returns each Contact with its social fields and `profiles_checked_at`.
  - `log_possible_profiles(lead_id, contact_id, body)` creates or appends one dated section on the person's note `Sales Partner · Possible Profiles`, and never edits earlier text. In HubSpot, it writes one Note per section, associated with the Contact and its Company.
  - Company profile fields gain `tiktok_url` and `x_url`, written in Attio only.

- [ ] **Step 1: Write the failing policy cases:**
  - Attio `create-note` with `parent_object: "people"` and the new title is allowed;
  - Attio `update-note` with an operation type other than `append` is blocked;
  - Attio `update-record` on people writing `instagram`, `sp_tiktok` and `sp_profiles_checked_at` is allowed;
  - HubSpot `manage_crm_objects` creating a Note associated with a Contact is allowed;
  - HubSpot updating `hs_note_body` is blocked;
  - HubSpot updating a Contact's `sp_instagram_url` and `sp_profiles_checked_at` is allowed.
- [ ] **Step 2: Run** `bash tests/test-policies.sh`. Edit a guard only for a case that fails, keeping its `covers` unchanged.
- [ ] **Step 3: Add the failing content assertions:**
  - `contract.md` contains `log_possible_profiles`, `Sales Partner · Possible Profiles`, `profiles_checked_at` and `only when the CRM field is empty`;
  - each `usage.md` maps every new argument to the slug or property in Global Constraints;
  - each `bootstrap.py` contains every new custom slug or property name.
- [ ] **Step 4: Edit the contract, both `usage.md` files and both `bootstrap.py` files.**
  - The bootstraps only add fields, as today.
  - The Attio probe checks that `instagram`, `facebook` and `twitter` exist on People, and `twitter` on Companies.
  - Both Review views show the person's social fields.
- [ ] **Step 5: Run** `bash tests/run-all.sh 2>&1 | tail -1`, then `tool_check.py` on both CRM tools. Expected: `ALL GREEN` and `OK:` twice.
- [ ] **Step 6: Commit** `feat(crm): person social fields, profiles-checked marker and possible-profiles note`.

---

### Task 4: The `find-social-profiles` skill, and the LinkedIn wording

**Files:**
- Create: `skills/find-social-profiles/SKILL.md`
- Modify: `AGENT.md:102` (the wording in Global Constraints)
- Modify: `skills/find-decision-makers/SKILL.md:6-9`: reading a public LinkedIn profile, including through an actor, is allowed, and acting on LinkedIn is not.
- Test: `tests/test-content.sh`

**Interfaces:**
- Consumes: `find_profiles` and `read_profile` (Task 2); `upsert_contact` and `log_possible_profiles` (Task 3).
- Produces: a skill the Preparer calls once per contact, with inputs `(lead, contact)`. It ends by writing `profiles_checked_at`, or returns `stopped` without writing it when a cap or the time budget ends the search.

- [ ] **Step 1: Add the failing content assertions** on the new skill:
  - `Anchor first`;
  - `Name or location alone is never confident`;
  - `both are uncertain`;
  - `shared-platform`;
  - `only when the CRM field is empty`;
  - `never follow, connect, like, comment, post or message`;
  - `Sales Partner · Possible Profiles`;
  - `profiles_checked_at`.

  Also assert `AGENT.md` contains the new line, and no longer contains `Never automate anything on LinkedIn.`
- [ ] **Step 2: Run** `bash tests/test-content.sh 2>&1 | grep FAIL`. Expected: the new assertions fail.
- [ ] **Step 3: Write the skill.** Frontmatter `name: find-social-profiles` and a "Use when…" description. The procedure:
  1. **Anchors.** Collect links from the business's website, its own social pages and the `find_contacts` social links. Use `read_profile` on a business page to find tagged or linked people. A business TikTok or X page found here goes into the company profile fields `tiktok_url` and `x_url` with `update_lead`, only when they are empty (Attio only).
  2. **Search.** Search the platforms still missing, in platform order, with `find_profiles(name, business, city, platforms)`.
  3. **Score** each candidate. Record its reasons as plain text: business link, employer or business name in the bio or job title, location, and name match.
  4. **Write.** Confident matches go into the fields via `upsert_contact`. Everything else goes into one dated `log_possible_profiles` section. Each candidate gets one line: platform, URL, reasons, and source URL in square brackets.
  5. **Finish.** Write `profiles_checked_at`.

  Then add a Failure modes section, and one fictional worked example with no real names.
- [ ] **Step 4: Edit `AGENT.md` and `find-decision-makers`.**
- [ ] **Step 5: Run** `bash tests/run-all.sh 2>&1 | tail -1 && ../agent-builder/bin/validate-agent.sh .`. Expected: `ALL GREEN` and `OK: . conforms`.
- [ ] **Step 6: Commit** `feat: find-social-profiles skill; reading LinkedIn allowed, acting never`.

---

### Task 5: Preparer profile pass and config

**Files:**
- Modify: `subagents/preparer.md`:
  - the queue section: a new "Profile pass" section after the prepare queue;
  - the sources list;
  - the caps section, so profile calls count toward both caps;
  - the time budget, which applies per lead in the pass.
- Modify: `context/operating-config.md`: add `apify_profiles` to the `prospecting_sources` default and its description.
- Modify: `skills/interview-business/SKILL.md`, only where it lists the sources.
- Test: `tests/test-content.sh`

**Interfaces:**
- Consumes: `find-social-profiles` (Task 4); `query_by_stage("Researched")`, `get_lead` and `update_stage` (contract).
- Produces: the profile-pass order and skip rules in Global Constraints, as Preparer text.

- [ ] **Step 1: Add the failing content assertions** on `preparer.md`:
  - `Profile pass`;
  - `after every queued lead`;
  - `oldest \`Stage Changed At\` first`;
  - `apify_profiles`;
  - `re-check the stage` (Review Focus 5);
  - `not Research Capped`;
  - `no person's name`;
  - `opt-out`.

  Also assert the default list in `operating-config.md` is exactly `prospecting_sources: [apify_google_maps, apify_contact_info, apify_reviews, apify_ads, apify_jobs, apify_site_reader, apify_profiles, web_search]`, and update the existing pin in `test-content.sh` to match.
- [ ] **Step 2: Run** and confirm the new assertions fail.
- [ ] **Step 3: Edit `preparer.md`.** The profile pass:
  - runs only when `apify_profiles` is in `prospecting_sources`;
  - builds its list as this run's newly `Researched` leads, then the other `Researched` leads with any named contact lacking `profiles_checked_at`, oldest first;
  - per lead: re-checks the stage and Do Not Contact before the first write, then calls `find-social-profiles` for each named contact without `profiles_checked_at`;
  - stops on either cap or the time budget, leaving the remaining contacts unchecked;
  - records every call as a ledger `step`, as today.
- [ ] **Step 4: Edit `operating-config.md`, and the interview if it lists sources.**
- [ ] **Step 5: Run** `bash tests/run-all.sh 2>&1 | tail -1`. Expected: `ALL GREEN`.
- [ ] **Step 6: Commit** `feat(preparer): profile pass after the prepare queue, with backlog`.

---

### Task 6: Evals

**Files:**
- Modify: `evals/cases.md` (new cases after Case 36, before `## Degradation check`)
- Test: `tests/test-content.sh` (one assertion per case heading)

- [ ] **Step 1: Add content assertions** for these headings, then **write the cases** in the file's existing format (Given, Expect, Never):
  - `## Case 37: A name-only match goes to the note, never the field` (Review Focus 1);
  - `## Case 38: Two candidates for one platform both go to the note`;
  - `## Case 39: A shared-platform website is not a business link` (Review Focus 2);
  - `## Case 40: A field the operator filled is never overwritten` (Review Focus 3);
  - `## Case 41: A lead moved to Approved mid-pass gets no write` (Review Focus 5);
  - `## Case 42: A Do Not Contact lead in the backlog is disqualified, not searched`;
  - `## Case 43: Evidence spends first; the profile pass stops on the cap and leaves the contact unchecked`.

  All names in the cases are fictional.
- [ ] **Step 2: Run** `bash tests/run-all.sh 2>&1 | tail -1`. Expected: `ALL GREEN`.
- [ ] **Step 3: Commit** `test(evals): social profile cases`.

---

### Task 7: Release 8.3.0

**Files:**
- Modify: `agent.yaml`, `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, `gemini-extension.json` (version `8.3.0`)
- Modify: `README.md`:
  - "Version 8.3.0.";
  - a "Social profiles" bullet under "What you get each week": confident matches on the person, uncertain ones in a note, never followed or messaged;
  - the Apify actors under "Tools it needs";
  - "LinkedIn stays human" reworded to cover every platform;
  - an "Upgrading from 8.2" note, in this order:
    1. add the new actors to the Apify connector URL;
    2. re-run setup's tools step, which creates the new fields with `bootstrap.py` or by hand and pins the new bindings;
    3. add `apify_profiles` to `prospecting_sources`;
    4. re-run `/sales-partner:schedule`.
- Test: `tests/test-content.sh` (version pins and `Upgrading from 8.2`)

- [ ] **Step 1: Update the version pins and add the `Upgrading from 8.2` assertion.** Run it and confirm it fails.
- [ ] **Step 2: Edit the manifests and the README.**
- [ ] **Step 3: Run** `bash tests/run-all.sh 2>&1 | tail -1 && ../agent-builder/bin/validate-agent.sh . --require-bump origin/main`. Expected: `ALL GREEN` and `OK: . conforms`.
- [ ] **Step 4: Commit** `chore: sales-partner 8.3.0`. Stop for the operator to ask for the PR.

---

### Task 8: Live trial (operator present, after merge)

**Files:** the live instance `live-agents/webspenser-sales-partner` only. No package files.

- [ ] **Step 1: Upgrade the instance** with the README's four steps. Commit and push the instance.
- [ ] **Step 2: Run the profile pass interactively on 5 to 10 `Researched` leads.**
- [ ] **Step 3: The operator reviews every confident field.**
  - Pass: no wrong person in a confident field.
  - Record the hit rate per platform and the added cost per lead in `live-agents/social-profiles-probe-2026-11/trial.md`, outside the repo.
- [ ] **Step 4: Confirm from the ledger** that no lead's evidence source was skipped because of profile spend. Report the results to the operator.

## Done when

- `ALL GREEN` and the validator pass on the branch.
- The probe notes record a live call for each chosen actor.
- The live trial passes with zero wrong confident matches.
