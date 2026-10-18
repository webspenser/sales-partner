# Offer Matching and Talking Points Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sales Partner 8.0.0 stops at `Researched`. Each researched lead
gets a Segment, an Industry, a Hero Offer chosen from a per-business offer
catalog (with a reason and an evidence level), and one Talking Points
note. The Approacher, the per-channel drafts and the `Approach Drafted`
and `Ready to Send` stages are replaced by one operator-only `Approved`
stage.

**Architecture:** The agent's behaviour lives in markdown contracts:
`AGENT.md`, `subagents/*.md`, `skills/*/SKILL.md`, the CRM contract and
the per-tool `usage.md` files. The guard policies (`guard.yaml`) enforce
what the agent may write. The stdlib-only Python bootstraps create the
CRM schema. Bash suites under `tests/` pin the cross-file consistency.
This plan changes those files in dependency order:
1. schema;
2. contract and guards;
3. removing the Approacher;
4. new skills;
5. sub-agents;
6. interview and setup;
7. digest;
8. evals;
9. release.

**Tech Stack:** Markdown; YAML guard policies, checked by the
`hooks/guard_policy.py` engine; Python 3 stdlib (no PyYAML); bash tests
(`tests/lib.sh` provides `assert_contains`, `assert_not_contains` and
`_report`).

**Spec:** `docs/superpowers/specs/2026-10-18-offer-matching-design.md`.
Read it before any task.

## Global Constraints

- Version **8.0.0**. `standard: "7.2"` is unchanged.
- **Stages, in this order** (ten): `New, Scored, Researched, Approved, Contacted, Engaged, Open Deal, Nurture, Customer, Disqualified`.
- **The agent's stage rule** in both CRM guards is `create: [New]` and `update: [Scored, Researched, Disqualified]`.
- **Approval invariant:** the id `draft_only` becomes **`approval_only`** everywhere (contract, both guard `covers`, both usage.md files, tests).
- **The agent's job ends at `Researched`.** Only the operator writes `Approved` or later.
- **Talking Points record:**
  - Attio: a note titled `Sales Partner · Talking Points`.
  - HubSpot: one Note per section.
  - Both: each section starts with `=== YYYY-MM-DD · talking points ===`.
  - The six labels, in order: `For:`, `Offer:`, `Opener:`, `Points:`, `Avoid:`, `Contact routes:`.
  - `Points:`, `Avoid:` and `Contact routes:` are each followed by a bulleted list. `Avoid:` may be `- none`.
  - With no hero offer, the Offer line reads `Offer: none matched`.
- **Contract operation:** `log_talking_points(lead_id, contact_id, body)` replaces `log_draft`. It only creates the record or adds a section, and takes no channel argument.
- **New lead fields** (Attio slug / HubSpot property / type):
  - Segment: `segment` / `sp_segment` / select. Options are the catalog's segment IDs.
  - Hero Offer: `hero_offer` / `sp_hero_offer` / select. Options are the catalog's offer IDs.
  - Offer Reason: `offer_reason` / `sp_offer_reason` / text.
  - Offer Evidence: `offer_evidence` / `sp_offer_evidence` / select with `strong`, `moderate`, `weak`.
  - Research Anyway: `research_anyway` / `sp_research_anyway` / checkbox, operator only, `forbid: true` in both guards.
- **Industry** keeps its existing field: `industry` / `sp_industry`, text.
- **Offer catalog:**
  - The file is `context/offer-catalog.md`, in the instance.
  - It has one fenced YAML block: `segments:` → each segment has `id`, `name`, `industries`, and `offers:` → each offer has `id`, `name`, `what`, `suits`, `signals`, `rule_out`.
  - IDs match `^[a-z0-9]+(-[a-z0-9]+)*$` and are unique across the whole catalog.
- **Offer Evidence:**
  - `strong`: two or more sourced signals.
  - `moderate`: one sourced signal.
  - `weak`: segment or industry fit only.
  - Empty when every offer in the segment is ruled out, or when no segment fits.
- **Removed:** `subagents/approacher.md`, `activity_approach`, `approach_threshold`, `enabled_channels`, `sending_identity`, `callback_phone`, `log_draft`, and the skills `write-cold-email`, `write-linkedin-touch`, `write-call-opener`.
- **Kept:** the Approach score (`approach_score`/`sp_approach_score`), which no longer triggers anything.
- **Bootstraps:** stdlib only. They add and never remove. The old stages are left in place with the existing "extra options left in place" note.
- `AGENT.md` stays under 6000 bytes (`tests/test-content.sh` checks it).
- Every task leaves `bash tests/run-all.sh` green, and edits the existing assertions it invalidates rather than deleting coverage. Task 9 also requires `../agent-builder/bin/validate-agent.sh . --require-bump main` to pass.
- Commits end with a `Co-Authored-By:` trailer naming the model that made them. Never push.

## Review Focus

1. **Catalog missing or malformed when a bootstrap runs.** The operator expects a clear message naming `context/offer-catalog.md`, given before any API call, not a traceback or half-created options. Tested in Task 1.
2. **Duplicate IDs, or an offer ID that reuses a segment ID.** The operator expects the bootstrap to refuse, naming the ID, because n8n routes on these values. Tested in Task 1.
3. **The agent writing `Research Anyway`** in any spelling of the value (`true`, `false`, `"true"`), or writing `Approved`. The operator expects a block in both CRMs. Tested in Task 2.
4. **A Scored lead with an empty Segment that clears the Fit threshold.** The operator expects it skipped unless its Industry maps to a catalog segment or Research Anyway is ticked. A content test is added in Task 5 and an eval in Task 8.
5. **n8n parsing the Talking Points note.** The header and the six labels must be identical in the contract, both usage.md files and `write-talking-points`. Tested in Task 4.

---

### Task 1: Offer catalog and CRM schema

**Files:**
- Create: `context/offer-catalog.md` (package template: an intro, bracketed prompts, and a commented example YAML block using the two-segment shape from the spec's "The operator's catalog")
- Modify: `capabilities/crm/tools/attio/bootstrap.py`, `capabilities/crm/tools/hubspot/bootstrap.py`
- Modify: `capabilities/crm/tools/attio/usage.md`, `capabilities/crm/tools/hubspot/usage.md` (the schema tables, the Probe and the bootstrap command only; the operation mappings change in Task 2)
- Create: `tests/test-catalog.sh`, and add it to `tests/run-all.sh` as `echo "== catalog"; tests/test-catalog.sh || STATUS=1`
- Modify: `tests/test-content.sh` (the stage-list and bootstrap assertions, around lines 246-296 and 681-686)

**Interfaces:**
- Produces, in **both** bootstraps, the same function: `read_catalog(path: str) -> tuple[list[str], list[str]]`. It returns `(segment_ids, offer_ids)` in file order. On a missing file, no YAML block, a bad ID or a duplicate, it calls `sys.exit()` with a message containing `offer-catalog.md`.
- Produces a `--catalog <path>` argument on both bootstraps. The default is `context/offer-catalog.md` relative to the working directory (the instance). The catalog is read before any API call.
- Produces `STAGES` equal to the ten Global Constraints stages in both bootstraps.
- Produces the five new fields (Global Constraints) in both bootstraps. Segment and Hero Offer options come from `read_catalog`; Offer Evidence options are `strong, moderate, weak`.

- [ ] **Step 1: Write `tests/test-catalog.sh`** (it sources `tests/lib.sh`). For each of the two bootstraps, load the module with `importlib.util.spec_from_file_location`, so no network call happens, and assert on these fixtures written to a `mktemp -d`:
  - The two-segment example yields `(['professional-services','home-auto-services'], [six offer IDs])`.
  - A one-segment catalog with two offers yields one segment and two offers.
  - A missing file exits non-zero, with output containing `offer-catalog.md`.
  - A file with no YAML block does the same.
  - The ID `Invoice_Recon` exits non-zero, naming `Invoice_Recon`.
  - The same offer ID in two segments exits non-zero, naming the ID.
  - An offer ID equal to a segment ID exits non-zero.
  - Both bootstraps return identical results for the two-segment fixture.

- [ ] **Step 2: Run it and check it fails.** Run `bash tests/test-catalog.sh`. Expected: FAIL, because `read_catalog` is not defined.

- [ ] **Step 3: Implement `read_catalog`, the `--catalog` argument, the ten `STAGES` and the five fields in both bootstraps.**
  - Parse only the fenced YAML block, with a small indentation-aware reader:
    - an `- id:` item directly under `segments:` is a segment;
    - one under an `offers:` key is an offer.
  - No PyYAML.
  - HubSpot enumeration options use the ID as both `label` and `value`.

- [ ] **Step 4: Update the schema tables, Probe and bootstrap command in both usage.md files.**
  - Add the five fields and the ten stages.
  - The Probe requires the new slugs and the ten stages.
  - Document `--catalog`, and the fact that re-running after a catalog change only adds options.

- [ ] **Step 5: Update the `tests/test-content.sh` assertions on stage order and bootstrap contents.**
  - The bootstrap and usage stage strings become the ten-stage list, with `"Approved"`.
  - Assert both bootstraps contain `attr("segment"`/`prop("sp_segment"`, `hero_offer`, `offer_reason`, `offer_evidence` and `research_anyway`.

- [ ] **Step 6: Run** `bash tests/run-all.sh`. Expected: `ALL GREEN`.

- [ ] **Step 7: Commit:** `feat(crm): offer catalog and the 8.0 schema in both bootstraps`.

---

### Task 2: CRM contract and guards

**Files:**
- Modify: `capabilities/crm/contract.md`:
  - the operations table;
  - the lead fields, Scores and Company profile sections;
  - Invariants;
  - the approval invariant section;
  - Lead status and its transitions table, and the trigger sentences.
- Modify: `capabilities/crm/tools/attio/guard.yaml`, `capabilities/crm/tools/hubspot/guard.yaml`
- Modify: `capabilities/crm/tools/attio/usage.md`, `capabilities/crm/tools/hubspot/usage.md`:
  - the operation mappings;
  - Notes and the note format;
  - Views;
  - Reading leads.
- Test: `tests/test-policies.sh`; `tests/test-content.sh` (around lines 135, 152, 165, 191, 390-413, 699-747)

**Interfaces:**
- Consumes: the Task 1 field slugs and stage list.
- Produces these contract operations, and only these, which later tasks call by these names:
  - `log_talking_points(lead_id, contact_id, body)` returns the Talking Points record.
  - `get_lead` returns the lead, its contacts, the research record and the Talking Points record, with the newest section of each identified.
  - `query_by_stage(stage, limit, next_action_due_before, idle_days, research_anyway)`. `research_anyway` is an optional boolean filter.
  - `query_by_score(score, min_score, stage, limit)` is unchanged.
  - `update_lead` accepts `segment`, `industry`, `hero_offer`, `offer_reason` and `offer_evidence`. It rejects `research_anyway`, as it does `stage`.
- Produces the contract's agent-written stages: `New` on create, `Scored`, `Researched`, `Disqualified`. "The agent's job ends at `Researched`."

- [ ] **Step 1: Write the failing policy cases in `tests/test-policies.sh`, for both Attio and HubSpot.**
  - **Stage writes:**
    - `Approved` is blocked, with "stage may only be written as".
    - `Approach Drafted` is now blocked.
    - `Ready to Send` stays blocked.
    - `Researched` and `Disqualified` are allowed.
  - **Research Anyway:** `research_anyway` / `sp_research_anyway` is blocked when set to `true`, `false` or `"true"`.
  - **Other new fields:** `segment`, `hero_offer`, `offer_reason` and `offer_evidence` writes are allowed.
  - **Notes:** a `create-note` titled `Sales Partner · Talking Points` with content `=== 2026-10-18 · talking points ===` is allowed in Attio. A HubSpot note create with that body is allowed.
  - Replace the existing `Sales Partner · Call` extra-key case with the Talking Points title.

- [ ] **Step 2: Run** `bash tests/test-policies.sh`. Expected: FAIL on `Approach Drafted` (still allowed) and on `research_anyway`.

- [ ] **Step 3: Change both guards.**
  - Set `covers: [approval_only, dnc_one_way, no_delete]`.
  - Set the stage rule `update: [Scored, Researched, Disqualified]`.
  - Add a `research_anyway` (or `sp_research_anyway`) rule with `forbid: true`.
  - In HubSpot (`unknown_writes: block`), confirm the four agent-written properties pass.

- [ ] **Step 4: Rewrite the contract sections** listed under Files to the spec's "The pipeline", "CRM fields" and "The Talking Points note" sections:
  - ten statuses, with the transitions table from the spec;
  - `approval_only` in place of `draft_only`;
  - nine operations, with `log_talking_points` replacing `log_draft`;
  - the Talking Points format as a public format, versioned like the research note;
  - the six lead fields, with who writes each.

- [ ] **Step 5: Update both usage.md files' operation mappings.**
  - **Attio:**
    - Map `log_talking_points` to the note `Sales Partner · Talking Points` (create, then append).
    - Map the `get_lead` read of it, and the `research_anyway` filter on `query_by_stage`.
    - Views become:
      - **Review:** `stage` is `Researched`, sorted by `approach_score`.
      - **Approved:** `stage` is `Approved`.
  - **HubSpot:** the same. Each section is a Note whose body starts with the header line.
  - **Both:** remove the draft note titles and the `Channel:` marker.

- [ ] **Step 6: Update the content assertions that pin old wording** to the new strings:
  - `approval_only`;
  - `The agent's job ends at \`Researched\``;
  - the guard stage rule;
  - `| \`log_talking_points\` |`;
  - `Sales Partner · Talking Points`;
  - `=== YYYY-MM-DD · talking points ===`.

  Remove the assertions for the three draft titles, `Channel: email` and `log_draft`, and add `assert_not_contains` for `log_draft` in the contract and both usage.md files.

- [ ] **Step 7: Run** `bash tests/run-all.sh`. Expected: `ALL GREEN`.

- [ ] **Step 8: Commit:** `feat(crm): Approved stage, approval_only, log_talking_points, research_anyway`.

---

### Task 3: Retire the Approacher path

**Files:**
- Delete:
  - `subagents/approacher.md`;
  - `skills/write-cold-email/`, `skills/write-linkedin-touch/`, `skills/write-call-opener/`;
  - `templates/cold-email.md`, `templates/cold-call-opener.md`, `templates/linkedin-dm.md`, `templates/linkedin-connection-note.md`, `templates/personalized-statements.md`.
- Modify:
  - `agent.yaml`: remove `activity_approach`;
  - `.claude-plugin/plugin.json`: remove the `agents` entry for the Approacher;
  - `context/operating-config.md`: remove `approach_threshold`, `enabled_channels`, `sending_identity` and `callback_phone`, with their "What each key gates" entries. `tone` stays, and its gate entry now names `write-talking-points`, which Task 4 creates;
  - `AGENT.md`: the Workflow table row, the Sub-agents table, the Skills list, and the Identity/Mission text that names `Approach Drafted` or per-channel drafts;
  - `context/icp.md` and `skills/score-lead/SKILL.md`: drop "approach gate" and `approach_threshold`;
  - `context/business-profile.md`: the Voice section's Approacher reference.
- Test: `tests/test-content.sh` (the call channel, Approacher, write-* and channel blocks listed in the recon: lines 54-63, 107-113, 132, 339-352, 415-476, 543-544, 585, 599-601, 660-671, 728-748, 787-788) and `tests/test-schedules.sh` (lines 33-50, 79-87)

**Interfaces:**
- Produces three activities in `agent.yaml`: `activity_prospect`, `activity_prepare`, `activity_digest`.
- Produces the `AGENT.md` workflow table with Interview, Prospect, Prepare and Digest rows. The Prepare row reads: `Scored`, Fit ≥ `research_threshold` with a Segment, or Research Anyway.

- [ ] **Step 1: Change the schedule tests.**
  - The `for a in …` loop covers `prospect prepare digest`.
  - The approach seeding and gate cases are replaced by `prepare`.
  - Add a case: an instance `schedules.yaml` containing `schedule_approach` makes the schedule check fail, with output naming `schedule_approach`.

- [ ] **Step 2: Run** `bash tests/test-schedules.sh`. Expected: FAIL (`activity_approach` still present).

- [ ] **Step 3: Delete the files and edit the manifests, config and AGENT.md** as listed under Files.

- [ ] **Step 4: Replace the deleted-feature assertions in `tests/test-content.sh`.**
  - Add `assert_not_contains` across `AGENT.md`, `subagents/`, `skills/`, `context/`, `capabilities/` and `evals/` for: `approacher`, `approach_threshold`, `enabled_channels`, `callback_phone`, `sending_identity`, `write-cold-email`, `write-linkedin-touch`, `write-call-opener`, `Approach Drafted`, `Ready to Send`.
  - Any eval text still naming these is fixed in Task 8. Until then, this task scopes the evals check out with a `# Task 8` comment.

- [ ] **Step 5: Run** `bash tests/run-all.sh`. Expected: `ALL GREEN`, and `AGENT.md` under 6000 bytes.

- [ ] **Step 6: Commit:** `refactor: retire the Approacher, per-channel drafts and the approach activity`.

---

### Task 4: Skills `match-offer` and `write-talking-points`; research signals

**Files:**
- Create: `skills/match-offer/SKILL.md`, `skills/write-talking-points/SKILL.md`
- Modify:
  - `skills/research-company/SKILL.md`: a step that reads the lead's segment's offers in `context/offer-catalog.md`, and records each signal or rule-out found as a finding with a source URL;
  - `context/icp.md`: industry fit scores against the catalog's industries;
  - `context/business-profile.md`: "What we sell" becomes a summary pointing to the catalog;
  - `AGENT.md`: operating rule 2 becomes "`business-profile.md` or `offer-catalog.md`"; add `context/offer-catalog.md` to Inputs; add both skills to the Skills list.
- Test: `tests/test-content.sh`

**Interfaces:**
- Consumes: `context/offer-catalog.md` (Task 1 shape); the research findings that `log_research` takes (`type, summary, source_url, date, hook`, seven types); `log_talking_points` (Task 2).
- Produces `match-offer`:
  - **Input:** the lead, its research findings, and its segment's offers.
  - **Output:** `hero_offer` (an offer ID or empty), `offer_evidence` (`strong|moderate|weak` or empty) and `offer_reason` (text with source URLs).
  - **Rules:**
    - Evidence follows the Global Constraints thresholds.
    - It never picks an offer from another segment, or an offer that research ruled out.
    - Every offer ruled out gives an empty offer and evidence, with each rule-out and its source named in the reason.
    - No segment gives an empty offer and evidence.
- Produces `write-talking-points`:
  - **Input:** the lead, contacts, research and the `match-offer` output.
  - **Output:** one section `body`, in the six-label format exactly as in the Global Constraints.
  - Each claim is sourced or `unverified`. Claims about the business trace to `business-profile.md` or `offer-catalog.md`.

- [ ] **Step 1: Write the failing content assertions.**
  - Both new skill files exist (through `"$SP/…"` paths).
  - `write-talking-points` contains the header and each of the six labels verbatim, and `Offer: none matched`.
  - `match-offer` contains `strong`, `moderate`, `weak` and `ruled out`.
  - **Review Focus 5:** the contract and both usage.md files contain the same header string and the six labels.
  - `AGENT.md` contains `offer-catalog.md`.
  - `research-company` contains `offer-catalog.md`.

- [ ] **Step 2: Run** `bash tests/test-content.sh`. Expected: FAIL (the files are missing).

- [ ] **Step 3: Write both skills and edit the four files.** Follow the spec's "Who does what" and "The Talking Points note" sections. Match the structure and tone of the existing skills (frontmatter `name`/`description`, Procedure, Failure modes).

- [ ] **Step 4: Run** `bash tests/run-all.sh`. Expected: `ALL GREEN`, and `AGENT.md` under 6000 bytes.

- [ ] **Step 5: Commit:** `feat(skills): match-offer and write-talking-points; research looks for catalog signals`.

---

### Task 5: Prospector and Preparer

**Files:**
- Modify: `subagents/prospector.md`: set Industry (catalog wording where one fits) and Segment (the catalog segment whose industries include it, otherwise empty) on `create_lead`/`update_lead`.
- Modify: `subagents/preparer.md`:
  - the trigger and queue;
  - Inputs, which add `context/offer-catalog.md`;
  - Outputs, Tools allowed, the steps, the Ledger step detail (now including `hero_offer` and `offer_evidence`), and Guardrails.
- Test: `tests/test-content.sh`

**Interfaces:**
- Consumes: `query_by_stage(stage="Scored", research_anyway=true, limit)` and `query_by_score(score="fit", min_score=research_threshold, stage="Scored", limit)` (Task 2); `match-offer` and `write-talking-points` (Task 4).
- Produces the Preparer's queue, in the spec's order, capped at `research_quota_per_week`:
  1. Research Anyway leads, by Fit score, highest first;
  2. then threshold leads that have a Segment.

  An empty Segment is first filled from Industry using the catalog; if that fails, the lead is skipped.
- Produces the handling of a Research Anyway lead whose industry fits no segment:
  - The Preparer assigns the segment the research fits best, then runs `match-offer`. Evidence is capped at `weak`, and Offer Reason says the segment was chosen by the Preparer.
  - If no segment fits, Segment, Hero Offer and Offer Evidence stay empty, the stage reason explains why, and the lead still moves to `Researched` with talking points.
- Produces the Preparer's `update_lead` allowance: `Approach Score`, `Approach Breakdown`, company profile fields, `Next Action`, `segment`, `industry`, `hero_offer`, `offer_reason`, `offer_evidence`.
- Produces the stage reason text for overrides: `researched by operator request; Fit <n> below research_threshold <t>`.
- Produces two interactive requests:
  - **Research a named lead:** treated as Research Anyway.
  - **Re-match a lead at `Researched`:** re-runs only `match-offer` and `write-talking-points` from the existing research, adds a new section, and overwrites the three offer fields.

  The Preparer never acts on a lead at `Approved` or later.

- [ ] **Step 1: Write the failing content assertions.**
  - The Preparer contains `research_anyway=true`, `match-offer`, `write-talking-points`, `log_talking_points` and `researched by operator request`.
  - **Review Focus 4:** the Preparer contains the sentence pinning that an empty Segment is filled from Industry or the lead is skipped.
  - The Prospector contains `Segment` and `offer-catalog.md`.
  - The Preparer contains neither `approach_threshold` nor `log_draft`.

- [ ] **Step 2: Run** `bash tests/test-content.sh`. Expected: FAIL.

- [ ] **Step 3: Edit both sub-agents** as listed under Files and Interfaces. Keep each `## Ledger` section consistent with `capabilities/ledger/contract.md`.

- [ ] **Step 4: Run** `bash tests/run-all.sh`. Expected: `ALL GREEN`.

- [ ] **Step 5: Commit:** `feat: Preparer matches the hero offer and writes talking points; Prospector sets segment`.

---

### Task 6: Interview and setup

**Files:**
- Modify: `skills/interview-business/SKILL.md`:
  - A new round after Round 1 that asks for segments, their industries, and each offer's name, what it is, who it suits, signals and rule-outs. It writes `context/offer-catalog.md` and confirms it with the operator.
  - The preamble names it as the only writer of the catalog.
  - Round 2 takes target industries from the catalog.
  - Round 4 drops channels, `callback_phone` and the approach schedule.
  - The worked example adds a catalog.
- Modify: `skills/setup/SKILL.md`:
  - Step 8's context file list adds `context/offer-catalog.md`.
  - Step 9 notes that the CRM bootstrap reads it, so the interview runs before the tools step, and is re-run after catalog changes.
- Test: `tests/test-content.sh`

**Interfaces:**
- Consumes: the catalog shape (Task 1) and the `--catalog` default path.
- Produces nothing new for later tasks.

- [ ] **Step 1: Write the failing assertions.**
  - The interview contains `context/offer-catalog.md`, `signals` and `rule_out`.
  - Setup's step 8 list contains `context/offer-catalog.md`.
  - The interview no longer contains `enabled_channels` or `callback_phone`.

- [ ] **Step 2: Run** `bash tests/test-content.sh`. Expected: FAIL.

- [ ] **Step 3: Edit both skills.**

- [ ] **Step 4: Run** `bash tests/run-all.sh`. Expected: `ALL GREEN`.

- [ ] **Step 5: Commit:** `feat(interview): offer catalog round; setup copies the catalog`.

---

### Task 7: Digest

**Files:**
- Modify: `skills/send-digest/SKILL.md`, `templates/digest.md`
- Test: `tests/test-content.sh` (around lines 238, 312-323, 370-375, 497-501, 750-757)

**Interfaces:**
- Consumes: `query_by_stage` on `Researched` and `Approved`; the Hero Offer and Offer Evidence fields.
- Produces two digest sections:
  - **`## Review ([count])`** is a queue of every lead at `Researched`. Each line is `<company> — <segment> · <hero offer or "no offer"> · <evidence> — [link]`, ordered by Approach score, highest first. `weak` picks and empty offers are marked.
  - **`## Approved, not yet contacted ([count])`** lists leads at `Approved`, with `researched N days ago`.

- [ ] **Step 1: Change the assertions.**
  - Add `Approved, not yet contacted`, `researched N days ago` and `no offer`.
  - Remove the assertions for `drafted:`, `drafted N days ago` and `the Call note`.
  - Fix the stale "eleven operations" wording, so the digest says `nine operations`.

- [ ] **Step 2: Run** `bash tests/test-content.sh`. Expected: FAIL.

- [ ] **Step 3: Edit the digest skill, its worked example, and the template.** The Movement query uses the ten stages. The digest still never writes to the CRM.

- [ ] **Step 4: Run** `bash tests/run-all.sh`. Expected: `ALL GREEN`.

- [ ] **Step 5: Commit:** `feat(digest): review queue shows offers; approved-not-contacted section`.

---

### Task 8: Evals

**Files:**
- Modify: `evals/cases.md`
- Test: `tests/test-content.sh` (eval headings and phrases; the `approved` negative pin at line 255)

**Interfaces:**
- Consumes: the behaviour from Tasks 2-7.

- [ ] **Step 1: Change the assertions.**
  - Remove the headings and phrases for Cases 4, 11, 14, 15 and 20.
  - Change the lowercase `approved` negative pin so it allows the stage name `Approved`, while still forbidding prose that says the agent approved a lead.
  - Add headings for the new cases:
    - strong match;
    - weak pick;
    - one offer ruled out;
    - every offer ruled out;
    - Research Anyway below the threshold;
    - industry fits no segment;
    - legacy lead whose Segment is filled from Industry;
    - talking points stay sourced.
  - Remove the Task 3 evals scoping comment, so the retired-term checks cover `evals/`.

- [ ] **Step 2: Run** `bash tests/test-content.sh`. Expected: FAIL.

- [ ] **Step 3: Rewrite `evals/cases.md`.**
  - Replace Cases 4, 11, 14, 15 and 20 with the eight new cases.
  - Update Cases 5, 6, 13 and 19, and every other reference to the Approacher or the old stages, to the 8.0 pipeline.
  - Update the header's list of positive checks.

- [ ] **Step 4: Run** `bash tests/run-all.sh`. Expected: `ALL GREEN`.

- [ ] **Step 5: Commit:** `test(evals): offer matching, talking points and Research Anyway cases`.

---

### Task 9: Release 8.0.0

**Files:**
- Modify: `agent.yaml` (`version: 8.0.0` and the description), `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, `gemini-extension.json`, `.claude-plugin/marketplace.json` (the same description and version), and `README.md` (the flow copy, the stage names, and "Version 8.0.0.")
- Test: `tests/test-content.sh` (the version and description pins at lines 437-450, 549-555, 761-773)

**Interfaces:**
- Produces this exact description string, in all five manifests:
  `Interviews a business, then finds, scores and researches fresh leads that fit its ideal customer and matches each one to the offer most likely to land, with sourced talking points the owner's own sequences can use`
- Produces the README section `Upgrading from 7.4`, holding the spec's five steps, in order.

- [ ] **Step 1: Change the pins.**
  - The version becomes `version: 8.0.0` and `Version 8.0.0.`.
  - The description assertions use the new string, in all five manifests.
  - Add `Upgrading from 7.4`.

- [ ] **Step 2: Run** `bash tests/test-content.sh`. Expected: FAIL.

- [ ] **Step 3: Edit the manifests and README.**

- [ ] **Step 4: Run the full check:** `bash tests/run-all.sh && ../agent-builder/bin/validate-agent.sh . --require-bump main`. Expected: `ALL GREEN` and `OK: . conforms`.

- [ ] **Step 5: Commit:** `chore: sales-partner 8.0.0`.

---

## Done when

- `bash tests/run-all.sh` and `../agent-builder/bin/validate-agent.sh . --require-bump main` are green on the branch.
- A search for the retired terms (`approacher`, `approach_threshold`, `log_draft`, `Approach Drafted`, `Ready to Send`, `enabled_channels`, `write-cold-email`) outside `docs/` and the README's upgrade note finds nothing.
- PRs only when the operator asks.
