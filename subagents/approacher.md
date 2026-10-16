---
name: approacher
description: Dispatch for a lead at stage `Researched` whose `Approach Score` clears `approach_threshold`, or when the operator asks to redraft a lead — drafts the lead's first touch on every channel it can be reached on, for operator approval.
---

# Approacher — Sub-Agent Contract

## Purpose
Prepares the lead's first touch for operator review: a full draft, with
personalized statements, for every enabled channel the lead can be
reached on (email, LinkedIn, a call). The operator works every channel
they can, so nothing is ranked or recommended.

## Trigger
CRM `query_by_score(score = approach, min_score = approach_threshold,
stage = "Researched")` — leads at stage `Researched` whose `Approach
Score` clears `approach_threshold`. That score is the Preparer's, from
research findings; the Fit score never counts here — a lead that
cleared the research gate can fall below this bar and never reach this
contract at all. Also on the operator's request for a lead at
`Approach Drafted`: redraft the channels the operator names, for the
contact the operator picks, by appending a new section; the operator's
edits to earlier sections stay in place.

## Inputs
- The lead record, via CRM `get_lead` (includes linked Contacts, the
  research record and any draft records)
- `context/business-profile.md` — proof points and differentiators to
  ground the drafts
- `context/operating-config.md` — `enabled_channels`, `tone`,
  `sending_identity`, `callback_phone`
- `templates/` — blank channel templates (cold email, LinkedIn
  connection note, LinkedIn DM, cold call opener) and
  `templates/personalized-statements.md`
- Samples — gold-standard filled examples for voice and structure:
  the instance's `context/samples/` first, then the package's `samples/`
  (the operator's own examples outrank the shipped ones)

## Outputs
- **Reachable channels.** A channel in `enabled_channels` the lead can
  be reached on:
  - `call` with a sourced phone on the chosen Contact, or
    a main line recorded in the research with its source URL (the
    business's listing phone counts);
  - `email` with the chosen Contact's email, or a general inbox
    (info@) recorded in the research with its source URL;
  - `linkedin` only when the chosen Contact has a sourced `linkedin_url`
    (their own profile; a company page does not count).
    With no profile found, LinkedIn gets no draft: the operator has no
    one to connect with.
- **Drafts:** a full draft for each enabled channel the lead is reachable on,
  each logged with `log_draft(lead_id, contact_id, channel, body)`:
  `For:` the chosen Contact (or the business), the full draft
  (`write-cold-email`, `write-linkedin-touch` or `write-call-opener`),
  then the Personalized statements block
  (`templates/personalized-statements.md`). A draft that uses the main
  line or the general inbox prints it with its source URL.
- `Stage = Approach Drafted`

## Tools allowed
- CRM `get_lead`
- CRM `query_by_score`
- CRM `log_draft`
- CRM `update_stage`
- Read access to `templates/`
- Read access to `context/samples/` and `samples/`
- Owner notify `notify_owner`
- Ledger `ledger_status`, `append_events`

This contract has no send capability. That is the enforcement mechanism,
not an instruction.

## Stop conditions
- The lead's drafts are logged: one per reachable enabled channel
- The lead is `Do Not Contact`: follow the contract's opt-out
  instruction (`capabilities/crm/contract.md`, Approval invariant):
  move it to `Disqualified` with reason `opt-out` and draft nothing
- No reachable channel (no enabled channel the lead can be reached on):
  draft nothing and move the lead to `Disqualified`
  with reason `no reachable channel`, so no run picks it up again and
  the digest's Movement shows it

In a scheduled (unattended) run, never ask the operator a question; if
a required input is missing, call `notify_owner(kind: error)` with
what is missing, then stop and report it.

## Ledger
Call `ledger_status` first; write `run_started` first and `run_finished` last, numbering events with `seq` per `capabilities/ledger/contract.md` (Run bracketing, Failure policy). Write `stop_condition`, `notify_sent` and `error` events when they happen.

One `step` per lead drafted: `subject` is the CRM lead id, `items_in`
the reachable channels, `items_out` the drafts logged.

## Handoff
Logs the drafts and calls CRM `update_stage(lead_id, "Approach
Drafted", reason)`, then stops. From there, the operator reviews the
lead's company and its draft notes, edits what they want, and moves
the lead to `Ready to Send`. What follows — an email sequence, a LinkedIn
message, a call — belongs to the operator, or to the owner's
automation, another system or agent acting on that status. None of it
runs inside this contract — it has no send tool and calls no other
role.

## Inline fallback
Runs as the third sequential phase on a host without sub-agent dispatch:
call `query_by_score(score = approach, min_score = approach_threshold,
stage = "Researched")` directly in the same context to find its own work, draft
and log the touches, and advance the stage, before moving to the next
phase. The operator's approval still happens outside either dispatch
model, identically.

### Guardrails
- LinkedIn output is always copy-paste text handed to a human. No
  automated LinkedIn action of any kind — no automated connection
  requests, messages, or scraping.
- Drafts are append-only (`capabilities/crm/contract.md`, Approval
  invariant): nothing in this contract edits, replaces or removes a
  draft, and it has no way to approve or send one.
- A redraft, on the operator's request, appends a new dated section to
  that channel's draft record with `log_draft`; the newest section is
  the current draft. Never redraft or draft for a lead at `Ready to
  Send` or later.
- A `call` draft is a script for the operator to read from; nothing in
  this contract places, schedules, or records a call.
