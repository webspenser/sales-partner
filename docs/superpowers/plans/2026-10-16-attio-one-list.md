# One Attio list, research and drafts as notes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship sales-partner 7.4.0: Attio uses one list (`sales_partner_pipeline`); research and drafts are append-only notes on the company; every reachable channel gets a full draft; the CRM contract and the HubSpot tool follow the same shape.

**Architecture:** The package is markdown instructions plus YAML guard policies and two Python bootstrap scripts. The provider-neutral contract (`capabilities/crm/contract.md`) changes first; the Attio and HubSpot tools map it; sub-agents, skills, digest and evals follow. Tests are grep assertions (`tests/test-content.sh`) and guard-engine checks (`tests/test-policies.sh`).

**Tech Stack:** Markdown, YAML (Agent Standard 7.2 guard grammar, `/Users/hochoy/Work/Webspenser/agent-builder/STANDARD.md`), Python 3 (bootstrap scripts), bash tests.

**Spec:** `docs/superpowers/specs/2026-10-16-attio-one-list-design.md` — read it first; this plan argues from it.

## Global Constraints

- Version `7.4.0` in `agent.yaml`, `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, `gemini-extension.json`, and `README.md` ("Version 7.4.0."). `standard: "7.2"` unchanged.
- Note titles, exactly (U+00B7 middle dot, single spaces): `Sales Partner · Research`, `Sales Partner · Email`, `Sales Partner · LinkedIn`, `Sales Partner · Call`.
- Section header, alone on its line: `=== YYYY-MM-DD · research ===` or `=== YYYY-MM-DD · draft ===`.
- Draft section body: `For: <person, title>` (or `For: the business`), then the full draft, then the block starting `Personalized statements` with its `opener:`, `relevance:`, `proof:`, `ask:` lines (`templates/personalized-statements.md`, unchanged).
- Research section body: one block per finding, lines `Type:`, `Date:`, `Summary:`, `Source:`, `Hook:`.
- Plain lines only in notes (Attio appends plain text): no tables, no markdown that renders only in the first section.
- Contract operations after this change, nine: `create_lead`, `get_lead`, `update_stage`, `update_lead`, `log_draft`, `log_research`, `upsert_contact`, `query_by_stage`, `query_by_score`. `log_activity`, `update_activity`, `query_activities` are gone. Every "eleven operations" (contract.md lines 5 and 320, send-digest SKILL.md line 58) becomes "nine operations"; the eleven *statuses* stay eleven.
- `log_research(lead_id, findings[])`: each finding `{type, summary, source_url, date, hook}`; one bad finding rejects the whole call.
- `log_draft(lead_id, contact_id, channel, body)`: `channel` in `email | linkedin | call`; create-or-append only.
- Pipeline entry attributes kept: `lead, stage, stage_changed_at, stage_reason, fit_score, fit_breakdown, approach_score, approach_breakdown, industry, size, source, source_url, next_action, next_action_due, revisit_on, do_not_contact`. Removed from the package: `phone, email, address, location`. No `recommended_channel` anywhere.
- The agent never edits, renames or deletes a note; it only creates one (when the title is missing) or appends.
- Nothing in `docs/` is edited except this plan's checkboxes.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.

## Review Focus

1. **Two notes with the same title** (operator copied one, or a race): append to the oldest, never create a third. Pinned in Task 2 (usage.md text) and Task 6 (eval Case 20).
2. **Operator's own notes with similar titles** (`Sales Partner · research`, `Research`): exact, case-sensitive title match only; the agent never appends to them. Pinned in Task 2.
3. **A business with no website and no street address** (service-area listing, phone only): under Attio, dedupe on company name + `primary_location` (the city/state location); `create_lead` still accepts it. Pinned in Task 2.
4. **Guard bypass on `update-note`**: `prepend`, `updated_title`, or an extra key is refused; plain `append` passes. Pinned in Task 2 policy tests.
5. **A lead whose only phone is the listing's main line** still gets a Call draft (number printed in the Call note with its source) and a lead whose only email is an info@ inbox still gets an Email draft. Pinned in Task 4 (approacher text) and Task 6 (eval Case 11).

---

### Task 1: CRM contract

**Files:**
- Modify: `capabilities/crm/contract.md`
- Test: `tests/test-content.sh` (new block `echo "-- 7.4: one Attio list"` before `finish`; existing assertions that pin removed text get replaced, not deleted silently)

**Interfaces:**
- Produces: the nine operations above; `log_research(lead_id, findings[])`; `log_draft(lead_id, contact_id, channel, body)`; `get_lead` returns `{lead, contacts[], research (sections), drafts: {email|linkedin|call: sections}}` with the newest section of each identified; invariant `draft_only` = "the agent never writes `Ready to Send` or any later status, and drafts are append-only".

- [ ] **Step 1: Add failing assertions** to the new 7.4 block:
  `assert_contains "$C" '| \`log_draft\` |'`, `assert_contains "$C" 'log_research(lead_id, findings[])'`, `assert_contains "$C" 'the nine operations'`, `assert_not_contains "$C" 'update_activity'`, `assert_not_contains "$C" 'query_activities'`, `assert_not_contains "$C" 'log_activity'`, `assert_not_contains "$C" 'recommended'`, `assert_contains "$C" 'drafts are append-only'`, `assert_contains "$C" 'a tool with no home for them skips them'` (with `C=./capabilities/crm/contract.md` as the file already uses).
- [ ] **Step 2: Run** `tests/test-content.sh 2>&1 | grep FAIL` — expect the new assertions to fail.
- [ ] **Step 3: Rewrite the contract** per spec "Contract changes": operations table; notes for `log_research`, `log_draft`, `get_lead`; lead `phone`/`email` stored where the tool has a home (`a tool with no home for them skips them`), dedupe runs on the keys the tool stores; Approval invariant restated (agent never writes `Ready to Send` or later; drafts are append-only; no voiding, no Activity statuses, no inbound entries); Opt-outs: the operator ticks `Do Not Contact`, the agent moves a ticked lead it works on (`New`, `Scored`, `Researched`, `Approach Drafted`) to `Disqualified` with reason `opt-out` and writes nothing else; `query_by_stage` idle age = now − `Stage Changed At`; Lead status transitions row for `Approach Drafted` says "one draft per reachable enabled channel"; Invariants list redefines `draft_only`. Replace "eleven operations" with "nine operations" (the eleven *statuses* stay eleven).
- [ ] **Step 4: Replace stale assertions** elsewhere in `tests/test-content.sh` that pin the old operation list or Activity status wording (the two `for op in create_lead … query_activities` loops become the nine names; drop assertions on `update_activity`/`voided`/`sent` wording in the contract).
- [ ] **Step 5: Run** `tests/test-content.sh 2>&1 | grep -E "FAIL|passed"` — the contract assertions pass; failures may remain only in files later tasks change (note them).
- [ ] **Step 6: Commit** `feat(crm): contract with append-only draft and research records`.

### Task 2: Attio tool

**Files:**
- Modify: `capabilities/crm/tools/attio/usage.md`, `capabilities/crm/tools/attio/bootstrap.py`, `capabilities/crm/tools/attio/guard.yaml`
- Test: `tests/test-policies.sh` (Attio block), `tests/test-content.sh` (7.4 block)

**Interfaces:**
- Consumes: Task 1 operations.
- Produces: Attio procedures for every contract operation; usage.md heading `## Reading notes from an automation` holding the fixed format (Global Constraints) for the operator's n8n workflow.

- [ ] **Step 1: Failing policy tests** in the Attio block (replace the `create-note not allowed`, `draft_body`, `status` draft/sent/voided and `sales_partner_outreach` checks):
  - `check 0 "create a note"` — `create-note` `{"parent_object":"companies","parent_record_id":"<uuid>","title":"Sales Partner · Research","content":"=== 2026-10-16 · research ==="}`
  - `check 0 "append to a note"` — `update-note` `{"note_id":"<uuid>","operation":{"type":"append","content":"x"}}`
  - `check 2 "prepend refused"` — `operation.type` `prepend`, expect message containing `type may only be written as append`
  - `check 2 "retitle refused"` — `{"note_id":"<uuid>","updated_title":"x"}`, expect `only_keys` refusal text the engine prints for a key outside the allowlist
  - `check 2 "extra operation key refused"` — `operation` with an added `"mode":"replace"`
  - `check 2 "delete-note refused"` — `delete-note`, expect `is denied`
  - keep every stage / `do_not_contact` / allow-list check that still applies.
- [ ] **Step 2: Run** `tests/test-policies.sh 2>&1 | grep -E "FAIL|passed"` — new checks fail.
- [ ] **Step 3: Guard** — `allow` gains `create-note`, `update-note`; `only_keys`: `update-note` at `$` = `[note_id, operation]`, at `operation` = `[type, content]`; `writes` gains `{kind: update, tools: [update-note], at: [operation]}`; rule `{field: type, update: [append]}`; remove the `status` and `draft_body` rules. Keep `covers: [draft_only, dnc_one_way, no_delete]`. If `guard_policy.py --check capabilities/crm/tools/attio/guard.yaml` rejects the grammar, stop and report rather than weakening the rule (spec, "Left to the builder").
- [ ] **Step 4: Run** `tests/test-policies.sh` — Attio block passes.
- [ ] **Step 5: Failing content assertions** (7.4 block): usage.md contains `Sales Partner · Research`, `=== YYYY-MM-DD · draft ===`, `## Reading notes from an automation`, `append to the oldest`, `exact title`, `company name + \`primary_location\``; usage.md and bootstrap.py do not contain `sales_partner_research`, `sales_partner_outreach`, `draft_body`, `` `phone` | text ``; bootstrap.py does not contain `attr("phone"`, `attr("email"`, `attr("address"`, `attr("location"`.
- [ ] **Step 6: usage.md** — one-list layout table (spec "Attio layout"); pipeline schema = the kept attributes; Companies section unchanged except `create_lead` writes `primary_location` from the address, else the location; operations: `create_lead` dedupe (domain via `companies.domains`, then company name + `primary_location`; reject only when `domain`, `address` and `location` are all empty), `get_lead` (pipeline entry, company, people, then `search-notes-by-metadata` on the company + `get-note-body` for the four titles), `log_research` / `log_draft` (find by exact title; create with the first section; else `update-note` append; two matches → append to the oldest), `update_stage`/`update_lead` unchanged apart from removed fields, `upsert_contact` fills empty person fields on later runs, `query_by_stage` idle age from `stage_changed_at`. Remove `log_activity`, `update_activity`, `query_activities`, the Research and Activities tables, the "Why lists" rationale for three lists. Views: drop Review's outreach steps, My touches; the operator reviews a lead by opening the company and its notes. Probe step 3 checks only `sales_partner_pipeline`. Setup Choice 1 lists only the pipeline list. Add `## Reading notes from an automation` (fixed titles, header, labelled lines; the newest section is the last header and what follows; filter the pipeline on `approach_score` and `stage` = `Ready to Send`).
- [ ] **Step 7: bootstrap.py** — `LISTS` holds only `PIPELINE` with the kept attributes; drop `RESEARCH`, `OUTREACH`; docstring says one list. It still never deletes.
- [ ] **Step 8: Run** both test files; Attio assertions pass.
- [ ] **Step 9: Commit** `feat(attio): one list; research and drafts as append-only company notes`.

### Task 3: HubSpot tool

**Files:**
- Modify: `capabilities/crm/tools/hubspot/usage.md`, `capabilities/crm/tools/hubspot/guard.yaml`
- Test: `tests/test-policies.sh` (HubSpot block), `tests/test-content.sh`

**Interfaces:**
- Consumes: Task 1 operations; the Global Constraints formats.
- Produces: HubSpot `log_research` = one Note per call, body = the research section; `log_draft` = one Note per call, body starts with the header line then `Channel: <email|linkedin|call>`; `get_lead` reads Notes associated with the company and groups them by first lines.

- [ ] **Step 1: Failing policy tests** — replace the Task-status checks with: `check 0 "create a draft note"` (`objectType: notes`, `hs_note_body`, association to company 202); `check 2 "note body rewritten"` (update `hs_note_body`, expect `hs_note_body may not be changed after create`); keep `sp_stage`, `sp_do_not_contact`, `hs_pipeline`, `hs_pipeline_stage`, delete/merge and allow-list checks.
- [ ] **Step 2: Run** `tests/test-policies.sh` — new checks fail.
- [ ] **Step 3: guard.yaml** — remove the `hs_task_status`, `hs_task_body`, `hs_task_completion_date` rules; add `{field: hs_note_body, forbid: update}`; keep the rest.
- [ ] **Step 4: Run** — HubSpot block passes.
- [ ] **Step 5: usage.md** — Data model: Research and drafts are Notes on the company (HubSpot notes have no title, so the header line and `Channel:` line identify them); Tasks are not used. Rewrite `log_research`, `log_draft`, `get_lead`; delete the Task table, status mapping, `log_activity`, `update_activity`, `query_activities`, "Outcome for task" handling; Views: Review = companies at `Approach Drafted`, open the company's notes; probe drops the `tasks` property check. Content assertions: usage.md contains `Channel: email` and `hs_note_body`; does not contain `hs_task_status`, `update_activity`, `Outcome for task`.
- [ ] **Step 6: Run** both test files, then `python3 -B -c "import ast,sys; ast.parse(open('capabilities/crm/tools/hubspot/bootstrap.py').read())"` (bootstrap unchanged; its probe test in test-policies must still pass).
- [ ] **Step 7: Commit** `feat(hubspot): research and drafts as company notes`.

### Task 4: Sub-agents, skills, templates, AGENT.md, operating-config

**Files:**
- Modify: `subagents/prospector.md`, `subagents/preparer.md`, `subagents/approacher.md`, `skills/research-company/SKILL.md`, `skills/write-cold-email/SKILL.md`, `skills/write-linkedin-touch/SKILL.md`, `skills/write-call-opener/SKILL.md`, `skills/find-decision-makers/SKILL.md` (line ~116 bounced wording only if it references Activities), `templates/cold-email.md`, `AGENT.md`, `context/operating-config.md` (lines ~105–112)
- Test: `tests/test-content.sh`

**Interfaces:**
- Consumes: `log_research(lead_id, findings[])`, `log_draft(lead_id, contact_id, channel, body)`.

- [ ] **Step 1: Failing assertions** (7.4 block): for every file in `AGENT.md subagents skills templates context` (exclude `docs`, `tests`): no `log_activity`, `update_activity`, `query_activities`, `recommended:`, `` `statements` ``, `bounced Activity`. Positive: `subagents/approacher.md` contains `a full draft for each enabled channel the lead is reachable on` and `a main line recorded in the research with its source URL`; `subagents/preparer.md` contains `log_research(lead_id, findings[])` and `main line and general inbox`; each `write-*` skill contains `log_draft(lead_id, contact_id, channel=`; `AGENT.md` contains `a full draft and personalized statements for every channel it can reach` and is under 6000 bytes.
- [ ] **Step 2: Run** — they fail.
- [ ] **Step 3: Approacher** — Outputs: per reachable enabled channel, a full draft plus statements via `log_draft`; no recommendation. Reachability (spec "Who changes what"): `call` = sourced phone on the chosen Contact or a main line recorded in the research with its source URL; `email` = contact email or a general inbox recorded in the research with its source URL; `linkedin` unchanged. Stop conditions: drafts logged for every reachable channel; no reachable channel → `Disqualified`, reason `no reachable channel` (unchanged); `Do Not Contact` ticked → `Disqualified`, reason `opt-out`, draft nothing. Redraft on operator request: append a new section to that channel's note. Tools allowed: `log_draft` (drop `log_activity`, `update_activity`). Guardrails: drafts append-only.
- [ ] **Step 4: Preparer and research-company** — findings collected during research, one `log_research(lead_id, findings[])` per run before scoring; record the main line and general inbox as `listing` findings with source URLs; opt-out text per Task 1; drop `update_activity` from Tools allowed. Prospector: opt-out text per Task 1; drop `update_activity`.
- [ ] **Step 5: write-* skills and templates** — each skill writes the full draft and the statements block for its channel and logs it with `log_draft(lead_id, contact_id, channel="<channel>", body=…)`; delete the "is / is not the recommended channel" branches; descriptions drop "recommended". Call opener prints the number it uses with its source. `templates/cold-email.md` drops lines 18–20's recommended clause.
- [ ] **Step 6: AGENT.md and operating-config.md** — Identity and Outputs: a full draft and personalized statements for every channel it can reach; drafts are notes on the company, append-only. operating-config lines on `log_activity`/`update_activity` restated as: drafts are append-only; only the operator moves a lead to `Ready to Send`.
- [ ] **Step 7: Run** `tests/test-content.sh 2>&1 | grep -E "FAIL|passed"` and `wc -c < AGENT.md` (< 6000).
- [ ] **Step 8: Commit** `feat: a full draft for every reachable channel, logged with log_draft`.

### Task 5: Digest

**Files:**
- Modify: `skills/send-digest/SKILL.md`, `templates/digest.md`
- Test: `tests/test-content.sh`

- [ ] **Step 1: Failing assertions**: send-digest contains `drafted: email, call`-style listing (`drafted:`), `the Call note`; does not contain `recommended`, `opt-out logged — Do Not Contact not set`, `query_activities`; digest.md line 13 and 17 templates say `drafted: <channels>`.
- [ ] **Step 2: Run** — fail.
- [ ] **Step 3: Edit** — "the CRM contract's eleven operations" becomes "nine operations"; Section 1 Review lists `<company> — drafted: <channels> — [link]`, the call number taken from the newest Call note section; delete the "Opt-outs not yet flagged" check; duplicate check on normalized `domain`, and `phone` only where the tool stores one; Section 2 lists drafted channels instead of the recommended one; worked example updated to match; the "This skill reads" list names `get_lead` for notes.
- [ ] **Step 4: Run** — pass.
- [ ] **Step 5: Commit** `feat(digest): report drafted channels from the draft notes`.

### Task 6: Evals

**Files:**
- Modify: `evals/cases.md`
- Test: `tests/test-content.sh`

- [ ] **Step 1: Failing assertions**: cases.md contains `## Case 14: Every reachable channel gets a full draft` and `## Case 20: A redraft appends and never rewrites`; does not contain `update_activity`, `query_activities`, `log_activity`, `recommended:`.
- [ ] **Step 2: Run** — fail.
- [ ] **Step 3: Rewrite** Cases 4, 5, 11, 14, 15 and the Degradation check against notes and statuses (Case 5: operator ticks `Do Not Contact` → next run moves the lead to `Disqualified`, reason `opt-out`, no note written; Case 11: a lead with only the listing's main line gets a Call draft printing that number and its source, a lead with no phone anywhere gets none). Add Case 20: a second Approacher run on the same lead appends one dated section to each channel note, never creates a second note, and the guard refuses `update-note` with `prepend` or `updated_title`; with two notes titled `Sales Partner · Email`, the append goes to the oldest. Update the intro line naming the positive cases.
- [ ] **Step 4: Run** — pass.
- [ ] **Step 5: Commit** `test(evals): cases for notes, full drafts and append-only redrafts`.

### Task 7: Release 7.4.0

**Files:**
- Modify: `agent.yaml`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `.codex-plugin/plugin.json`, `gemini-extension.json`, `README.md`, `tests/test-content.sh`

- [ ] **Step 1: Failing assertions**: `version: 7.4.0`; every manifest contains `prepares each first touch in the CRM: a full draft with personalized statements for every channel it can reach`; README contains `Upgrading from 7.3` and `Version 7.4.0.`; no manifest contains `recommended channel`.
- [ ] **Step 2: Run** — fail.
- [ ] **Step 3: Edit** — description (all five manifests, identical): `Interviews a business, then finds, scores and researches fresh leads that fit its ideal customer and prepares each first touch in the CRM: a full draft with personalized statements for every channel it can reach, email, LinkedIn and calls`. Version bump in the four versioned files and README. README "What you get each week" bullet 3 rewritten to match (every channel, no recommendation). README `Upgrading from 7.3` (Attio): re-run setup's tools step (probe now needs only the pipeline list); before the next scheduled run, ask the agent in an interactive session to move research and drafts into notes (spec "Migration" steps 1–3); then archive the `Sales Partner Research` and `Sales Partner Outreach` lists and the pipeline `Phone`, `Email`, `Address`, `Location` attributes. HubSpot: existing Tasks stay as history; new drafts are Notes. Commit and push the instance.
- [ ] **Step 4: Run** `tests/run-all.sh` (ALL GREEN) and `/Users/hochoy/Work/Webspenser/agent-builder/bin/validate-agent.sh . --require-bump origin/main` (`OK: . conforms`).
- [ ] **Step 5: Final sweep** — `grep -rn "log_activity\|update_activity\|query_activities\|recommended:\|sales_partner_outreach\|sales_partner_research" --include='*.md' --include='*.py' --include='*.yaml' --include='*.json' . | grep -v "^./docs/\|^./tests/\|^./README.md"` prints nothing.
- [ ] **Step 6: Commit** `chore: sales-partner 7.4.0`, push the branch, open the PR (body ends with the 🤖 Claude Code line).

### Task 8 (operator-gated): migrate the live Webspenser instance

Runs only after the operator approves, after the PR merges and the plugin updates, and before the next scheduled Monday run. Interactive session in `/Users/hochoy/Work/Webspenser/live-agents/webspenser-sales-partner`.

- [ ] **Step 1:** Re-run setup's tools step for the CRM; the probe passes with only `sales_partner_pipeline`.
- [ ] **Step 2:** For each company with `sales_partner_research` entries: create `Sales Partner · Research` with one `=== <original date> · research ===` section per date, oldest first (create with the oldest, append the rest).
- [ ] **Step 3:** For each company with non-voided `sales_partner_outreach` drafts: create the channel note from the newest draft per channel, as written.
- [ ] **Step 4:** Pipeline `phone`/`email` values that belong to a linked person with that field empty → fill on the person; others are recorded as listing findings in the research note (append a dated section).
- [ ] **Step 5:** Report the counts (notes created, sections appended, person fields filled) and hand the operator the archive list: two lists, four pipeline attributes.
