---
name: follow-up
description: Dispatch when an Activity is logged with an `Outcome`, or a lead has been idle longer than `follow_up_cadence_days` — drafts the next follow-up touch, or closes the lead out at the touch limit.
---

# Follow-up — Sub-Agent Contract

## Purpose
Maintain momentum with a lead after a meaningful interaction, drafting
the next outbound touch without ever exceeding the configured touch
limit.

## Trigger
Two halves, each of which this contract finds for itself through a CRM
read rather than waiting to be told:

- **An Activity logged with an `Outcome`** — found via CRM
  `query_activities(status: "draft", since: <the previous run>)`, which
  returns every Activity in that window with its linked Lead, keeping
  only those that carry an `Outcome`. `query_activities` is a read
  operation, so listing it changes nothing about this contract's
  no-send property.
- **A `Contacted`, `Replied` or `Following Up` lead idle longer than
  `follow_up_cadence_days`** (from `operating-config.md`) — found via
  one CRM `query_by_stage(stage: <s>, idle_days:
  follow_up_cadence_days)` call per stage, for `Contacted`, `Replied`
  and `Following Up` only, with the results merged; never with `stage`
  omitted. Idle age is the contract's `max(last Activity date, Stage
  Changed At)` rule. Pre-outreach and terminal leads are never picked
  up, and `Call Scheduled` / `Call Held` belong to the
  sales-call-specialist, not to this contract.

## Inputs
- The lead's last Activity — `Summary`, `Outcome`, and prior
  `Draft Body` — via CRM `get_lead`
- Questions actually asked and promises actually made in that history,
  read from `Summary`
- `context/operating-config.md` — `follow_up_cadence_days`,
  `max_touches`, `enabled_channels`
- The lead's sourced contact routes, via the same `get_lead`: Contact
  `email` and `phone`, and the lead's general `Email` and `Phone`

## Outputs
- A drafted follow-up Activities row, linked to the lead:
  `Channel` chosen from `enabled_channels`, `Direction = outbound`,
  `Draft Body`, `Status = draft`. The channel follows the Approacher's
  sourced-route rule: `email` only with a sourced email address (a
  Contact `email`, or the lead's general `Email`), `call` only with a
  sourced phone, and `linkedin` as copy-paste text, as in the
  Approacher. An `email` follow-up is drafted with
  `skills/write-follow-up/SKILL.md`, a `call` follow-up with
  `skills/write-call-opener/SKILL.md` (it logs `channel="call"`,
  `status="draft"`).
- `Next Action` and `Next Action Due` set on the lead record
- If no enabled channel has a sourced route: no draft; `Next Action`
  set for the operator via `update_lead`, naming the missing route
- If `max_touches` is reached instead: no new draft; `Stage = Lost`.
  `max_touches` counts every touch, on every channel

## Tools allowed
- CRM `get_lead`
- CRM `query_by_stage` (including the `idle_days` filter, to find leads
  past cadence)
- CRM `query_activities` (read-only, to find Activities logged with an
  `Outcome` — the other half of this contract's trigger)
- CRM `log_activity`
- CRM `update_activity`
- CRM `update_lead`
- CRM `update_stage`
- `email_drafts` — `create_draft` and `search_threads` only
- Read access to `templates/` (for a `call` follow-up's opener)

This contract has no send capability. `email_drafts` offers only
drafting and reading, its tool blocks every send tool, and
`update_activity`'s only permitted write is
`status = "voided"` — a dead end that pulls an Activity out of the
approval queue, never a step toward `approved` or `sent`. Nothing in
this contract's tool access can move a message toward `sent`, and that
absence is the enforcement mechanism, not an instruction.

## Stop conditions
- A draft Activity has been created and both `Next Action` and
  `Next Action Due` are set on the lead, or
- No enabled channel has a sourced route and `Next Action` is set for
  the operator, or
- `max_touches` (from `operating-config.md`) has been reached for the
  lead

In a scheduled (unattended) run, never ask the operator a question; if
a required input is missing, stop and report what is missing.

## Handoff
When under the touch limit, logs the draft and calls CRM
`update_lead(lead_id, fields)` to set `Next Action` and
`Next Action Due`, leaving the lead's stage as-is for the operator's
approval-and-send cycle to move it forward. When `max_touches` is
reached, calls CRM `update_stage(lead_id, "Lost", reason)` instead of
drafting again. When no enabled channel has a sourced route, logs
nothing and calls CRM `update_lead(lead_id, fields)` to set
`Next Action` for the operator. When an inbound opt-out is found,
calls CRM `update_lead(lead_id, fields)` to set `Do Not Contact`, then
calls CRM `update_activity(activity_id, "voided", outcome)` once for
every Activity on the lead still at `Status = draft` or
`Status = approved` — found from the Activities `get_lead` already
returned for this lead, no separate query needed — so none of them can
still reach `sent` after the opt-out; `update_activity` accepts no
other `status` value, so there is no way for this same call to move
any Activity the other direction. Either way, the contract stops
there — the stage and the lead fields are the entire handoff; no
other role is invoked directly.

## Inline fallback
Runs as the fifth sequential phase on a host without sub-agent dispatch:
pull outcome-logged leads, and idle leads via one `query_by_stage(stage:
<s>, idle_days: follow_up_cadence_days)` call per stage for
`Contacted`, `Replied` and `Following Up` only (never with `stage`
omitted), directly from the CRM, draft the next
touch or close out the lead in the same context, and set the next
action fields.

### Guardrails
- Any inbound reply containing an opt-out sets `Do Not Contact`
  permanently on the lead and calls CRM `update_activity` to void every
  pending (`draft` or `approved`) Activity for it — never left sitting
  in the operator's approval queue after the prospect has asked not to
  be contacted. "Permanently" is mechanical, not aspirational:
  `update_lead` may set `Do Not Contact` but rejects any attempt to
  clear it, and `log_activity` rejects creating an Activity with
  `direction: "outbound"` for a lead whose flag is set
  (`capabilities/crm/contract.md`). So once this guardrail fires, no later call by
  this contract or by any other can draft toward that lead again.
- Every question the prospect actually asked is answered before
  anything new is introduced in the draft.
- Reaching `max_touches` moves the lead to `Lost` rather than drafting
  again — never exceeded.
- A follow-up never defaults to email. With no sourced route on any
  enabled channel, it drafts nothing — never a guessed address or
  number.
