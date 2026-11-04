# Point of Contact (sales-partner 8.4.0) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every new lead the Preparer researches gets one point of contact on the pipeline list: the most senior named person with an email address. n8n reads it to build the email-platform import, and the talking points are written for that person.

**Architecture:** Three new lead fields go through the existing `update_lead`: the point of contact, the agent's own last pick (so a manual choice can be told apart from an agent choice), and a short reason. A new skill, `pick-point-of-contact`, holds the eligibility, seniority and tie rules, plus the manual-choice check. The Preparer calls it after the Contacts are written and before `write-talking-points`. `write-talking-points` addresses `For:` to the point of contact when one is set.

**Tech Stack:** markdown skills and contracts, YAML guard policies (`hooks/guard_policy.py`), Python `bootstrap.py`, bash tests (`tests/lib.sh`).

**Spec:** `docs/superpowers/specs/2026-11-03-point-of-contact-design.md` (approved 2026-11-03).

## Global Constraints

- **Version:** `8.4.0`, with `standard: "7.4"` unchanged. There is no agent-builder change and no `hooks/` change.
- **Branch:** `feat/point-of-contact`, which already holds the spec commit.
- **Contract field names** (on the lead, through `update_lead`, returned by `get_lead`):
  - `point_of_contact`: a `contact_id` or empty;
  - `point_of_contact_pick`: a `contact_id` or empty, written only by the agent;
  - `point_of_contact_reason`: text.
- **Attio, on list `sales_partner_pipeline`:**
  - `point_of_contact` and `point_of_contact_pick` are record-references allowing only `people`;
  - `point_of_contact_reason` is text.
- **HubSpot, Company properties:** `sp_point_of_contact` and `sp_point_of_contact_pick` are strings holding the Contact's record ID. `sp_point_of_contact_reason` is a string.
- **`update_lead` rejects** a `point_of_contact` or `point_of_contact_pick` that is not one of the lead's linked Contacts.
- **Eligible:** a Contact with a non-empty email field and a person's name. A generic inbox written as a Contact is not eligible. Verified and unverified emails both count.
- **Seniority, from the job title only** (never from `role`), most senior first:
  1. owner, co-owner, owner-operator, founder, co-founder, president, CEO, principal, managing partner;
  2. general manager, managing director, COO, partner;
  3. other managers and directors;
  4. everyone else.
- **Ties:** a `Verified` email first, then the closest match to `icp.md`'s Target roles, then the earliest-written Contact.
- **The manual-choice rule.** Let F be `point_of_contact` and P be `point_of_contact_pick`.
  - The agent may write when F = P, including when both are empty.
  - It never writes when F ≠ P. That covers the operator setting F by hand, and also the operator clearing F (F empty, P set).
  - The only exception is an explicit operator request in a session.
  - When the agent writes, it always sets F and P to the same value, together with the reason, in one `update_lead` call.
- **Reason format:** `<seniority word from the title>; <why>`, for example `Owner; most senior with an email` or `General Manager; owner has no email`.
- **No one eligible:** F and P are left empty, nothing is written to them, and the stage reason ends with `; no point of contact: no contact has an email`.
- **When the pick runs:** only on a lead about to move to `Researched`, after the Contacts are written and before `write-talking-points`. It never runs on `Disqualified`, on Do Not Contact, or at `Approved` or later.
- **No backfill.** No run goes looking for old leads.
- **Tests:** every task leaves `bash tests/run-all.sh` ending `ALL GREEN`, and `finish` stays the last line of `tests/test-content.sh`.
- **Commits** end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never push unless the operator asks.

## Review Focus

1. **The operator clears the field, then asks for a re-research.** The field must stay empty, because F is empty and P is set. Pinned in Task 2 (skill text) and Task 4 (eval).
2. **A title that hides seniority**, such as "Owner & Lead Technician" or "GM / Partner". The highest rank any part of the title names wins. Pinned in Task 2 (a skill content assertion and the worked example).
3. **A generic `info@` gatekeeper row is the only Contact with an email.** The field must be empty, not the inbox. Pinned in Task 2 and Task 4.
4. **The talking points name the point of contact even when a better-matching decision-maker exists without an email.** Pinned in Task 2 (the `write-talking-points` assertion) and Task 4 (eval).
5. **A `contact_id` from another company passed as `point_of_contact`.** `update_lead` must reject it. Pinned in Task 1 (contract and both usage.md files).

---

### Task 1: CRM contract and both tools: the three point-of-contact fields

**Files:**
- Modify: `capabilities/crm/contract.md`: the `update_lead` and `get_lead` rows; a new "Point of contact fields" subsection after Offer fields that states the manual-choice rule and the reject rule.
- Modify: `capabilities/crm/tools/attio/usage.md`: the `sales_partner_pipeline` table, the `update_lead` and `get_lead` procedures, `## Views`, `## Probe`, `## Setup` Choice 1.
- Modify: `capabilities/crm/tools/attio/bootstrap.py`: three `attr(...)` entries on the pipeline list. The record-references follow the `lead` attribute's pattern at line 144, with `allowed_objects: ["people"]`.
- Modify: `capabilities/crm/tools/hubspot/usage.md` (the Company properties, `update_lead`, `get_lead`, `## Setup`) and `capabilities/crm/tools/hubspot/bootstrap.py` (three `prop(...)` string entries).
- Modify, only if Step 2 fails: either `guard.yaml`.
- Test: `tests/test-policies.sh`, `tests/test-content.sh`

**Interfaces:**
- Produces:
  - `update_lead(lead_id, fields)` accepts `point_of_contact`, `point_of_contact_pick` and `point_of_contact_reason`.
  - `get_lead` returns all three.
  - The reject rule and the F/P rule in Global Constraints, stated in `contract.md`.

- [ ] **Step 1: Write policy cases.** Allowed: Attio `update-list-entry-by-id` writing `point_of_contact`, `point_of_contact_pick` and `point_of_contact_reason`. Allowed: HubSpot `manage_crm_objects` updating a Company's `sp_point_of_contact`, `sp_point_of_contact_pick` and `sp_point_of_contact_reason`.
- [ ] **Step 2: Run** `bash tests/test-policies.sh`. Edit a guard only for a case that fails, and leave its `covers` unchanged.
- [ ] **Step 3: Add the failing content assertions:**
  - `contract.md` contains `point_of_contact_pick`, `Point of contact fields` and `not one of the lead's linked Contacts`;
  - Attio `usage.md` contains `` `point_of_contact` `` and `record-reference → people`;
  - HubSpot `usage.md` contains `sp_point_of_contact_pick`;
  - each `bootstrap.py` contains its three names.
- [ ] **Step 4: Edit the contract, both usage.md files and both bootstraps.** The Attio Review view shows `point_of_contact` and `point_of_contact_reason`, and never the pick. The bootstraps only add fields.
- [ ] **Step 5: Run** `bash tests/run-all.sh 2>&1 | tail -1`, then `tool_check.py` on both CRM tools, as in the 8.3 plan. Expected: `ALL GREEN`, then `OK:` twice.
- [ ] **Step 6: Commit** `feat(crm): point of contact fields on the lead`.

---

### Task 2: The `pick-point-of-contact` skill, and talking points `For:`

**Files:**
- Create: `skills/pick-point-of-contact/SKILL.md`
- Modify: `skills/write-talking-points/SKILL.md`, step 3 (`For:`, line 65)
- Test: `tests/test-content.sh`

**Interfaces:**
- Consumes: `get_lead` and `update_lead` with the Task 1 fields.
- Produces:
  - A skill the Preparer calls once per lead, with input `lead_id`.
  - It returns one of `picked <contact_id>`, `none eligible`, or `kept: operator's choice`.
  - On `picked`, it has made one `update_lead` call setting F = P = `contact_id`, plus the reason.

- [ ] **Step 1: Add the failing content assertions** on the new skill:
  - `non-empty email`;
  - `generic inbox`;
  - `from the job title, never from`;
  - `highest rank any part of the title names` (Review Focus 2);
  - `Verified`;
  - `Target roles`;
  - `earliest-written`;
  - `point_of_contact_pick`;
  - `F empty and P set` (Review Focus 1);
  - `explicit operator request`;
  - `no point of contact: no contact has an email`.

  On `write-talking-points`, assert it contains `the lead's point of contact`, and keep the existing Target roles fallback text.
- [ ] **Step 2: Run** `bash tests/test-content.sh 2>&1 | grep FAIL`. Expected: the new assertions fail.
- [ ] **Step 3: Write the skill.** The frontmatter is `name: pick-point-of-contact`, with a "Use when…" description. The procedure:
  1. Check the F/P rule first, and return `kept` when F ≠ P.
  2. Build the eligible list.
  3. Rank by seniority, then apply the tie rules.
  4. Write F, P and the reason in one `update_lead` call, or return `none eligible`.

  Then add a Failure modes section covering a generic inbox, a role tag mistaken for seniority, and overwriting a cleared field. Finish with one fictional worked example, with no real names: an owner with no email, an "Office Manager / Partner" with an unverified email and an `info@` gatekeeper. The partner is picked, at rank 2.
- [ ] **Step 4: Edit `write-talking-points` step 3.** When the lead has a point of contact, `For:` is that Contact and its `contact_id` is used for the write. Otherwise the current rule applies, unchanged.
- [ ] **Step 5: Run** `bash tests/run-all.sh 2>&1 | tail -1 && ../agent-builder/bin/validate-agent.sh .`. Expected: `ALL GREEN` and `OK: . conforms`.
- [ ] **Step 6: Commit** `feat: pick-point-of-contact skill; talking points follow it`.

---

### Task 3: Preparer wiring

**Files:**
- Modify: `subagents/preparer.md`:
  - the description frontmatter (one clause);
  - Outputs (a new bullet);
  - Tools allowed (`update_lead` point-of-contact fields);
  - Handoff (call `pick-point-of-contact` after the Contacts and `match-offer`, before `write-talking-points`; the stage-reason suffix);
  - Interactive requests (re-research and continue re-run the skill; a new request, "set or change the point of contact", is the explicit operator request);
  - Inline fallback (the same order).
- Test: `tests/test-content.sh`

**Interfaces:**
- Consumes: the `pick-point-of-contact` returns from Task 2.
- Produces: nothing new for later tasks.

- [ ] **Step 1: Add the failing content assertions** on `preparer.md`:
  - `pick-point-of-contact`;
  - `before \`write-talking-points\``;
  - `; no point of contact: no contact has an email`;
  - `set or change the point of contact`;
  - `never on a lead that goes to \`Disqualified\``.
- [ ] **Step 2: Run** the tests and confirm the new assertions fail.
- [ ] **Step 3: Edit `preparer.md`** as listed under Files. The stage-reason suffix goes after every existing start (cap and operator request), so continue runs that parse the start still work.
- [ ] **Step 4: Run** `bash tests/run-all.sh 2>&1 | tail -1`. Expected: `ALL GREEN`.
- [ ] **Step 5: Commit** `feat(preparer): pick the point of contact before talking points`.

---

### Task 4: Evals

**Files:**
- Modify: `evals/cases.md`, adding new cases after Case 43 and before `## Degradation check`
- Test: `tests/test-content.sh`, with one assertion per heading

- [ ] **Step 1: Add the assertions, then write the cases** in the file's format (Given, Expect, Never). All names are fictional.
  - `## Case 44: One person with an email is the point of contact`
  - `## Case 45: A GM with an email beats an owner without one`
  - `## Case 46: An owner with an unverified email beats a verified gatekeeper`
  - `## Case 47: No one with an email leaves the field empty` (includes the `info@` row; Review Focus 3)
  - `## Case 48: Two owners, the verified one wins`
  - `## Case 49: A hand-set point of contact survives a re-research`
  - `## Case 50: A field the operator cleared stays empty` (Review Focus 1)
  - `## Case 51: The operator asks to change the point of contact`
  - `## Case 52: Talking points are written for the point of contact` (Review Focus 4)
- [ ] **Step 2: Run** `bash tests/run-all.sh 2>&1 | tail -1`. Expected: `ALL GREEN`.
- [ ] **Step 3: Commit** `test(evals): point of contact cases`.

---

### Task 5: Release 8.4.0

**Files:**
- Modify: `agent.yaml`, `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json` and `gemini-extension.json`, setting the version to `8.4.0`.
- Modify: `README.md`:
  - change the version line to "Version 8.4.0.";
  - add a "Point of contact" bullet under "What you get each week": the most senior person with an email is set on each new lead, and a hand-set choice is never overwritten;
  - add an "Upgrading from 8.3" note:
    1. re-run setup's tools step, which creates the three fields, with `bootstrap.py` or by hand;
    2. point the n8n workflow at `point_of_contact`;
    3. existing leads are not backfilled, so set those by hand.
- Test: `tests/test-content.sh`, covering the version pins and `Upgrading from 8.3`.

- [ ] **Step 1: Update the version pins and add the assertion.** Run them and confirm they fail.
- [ ] **Step 2: Edit the manifests and the README.**
- [ ] **Step 3: Run** `bash tests/run-all.sh 2>&1 | tail -1 && ../agent-builder/bin/validate-agent.sh . --require-bump origin/main`. Expected: `ALL GREEN` and `OK: . conforms`.
- [ ] **Step 4: Commit** `chore: sales-partner 8.4.0`. Then stop until the operator asks for the PR.

---

### Task 6: Live check (operator present, after merge)

- [ ] On the instance, after the upgrade, research the next 3–5 new leads interactively.
- [ ] The operator confirms each pick and reason in Attio, and confirms that n8n reads `point_of_contact`.
- [ ] Set one lead's point of contact by hand, ask for a re-research, and confirm the choice is kept.
