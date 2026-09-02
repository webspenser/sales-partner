# Follow-up — Sub-Agent Contract

## Purpose
Maintain momentum with a lead after a meaningful interaction, drafting
the next outbound touch without ever exceeding the configured touch
limit.

## Trigger
An Activity logged with an `Outcome`, or a lead idle longer than
`follow_up_cadence_days` (from `operating-config.md`) since its last
Activity — found via CRM `query_by_stage(idle_days:
follow_up_cadence_days)`, the same idle-lookup `send-digest`'s Stalled
section uses, rather than this contract scanning every stage's leads
for staleness on its own.

## Inputs
- The lead's last Activity — `Summary`, `Outcome`, and prior
  `Draft Body` — via CRM `get_lead`
- Questions actually asked and promises actually made in that history,
  read from `Summary`
- `context/operating-config.md` — `follow_up_cadence_days`,
  `max_touches`

## Outputs
- A drafted follow-up Activities row: `Channel = email`,
  `Direction = outbound`, `Draft Body`, `Status = draft`, linked to the
  lead
- `Next Action` and `Next Action Due` set on the lead record
- If `max_touches` is reached instead: no new draft; `Stage = Lost`

## Tools allowed
- CRM `get_lead`
- CRM `query_by_stage` (including the `idle_days` filter, to find leads
  past cadence)
- CRM `log_activity`
- CRM `update_activity`
- CRM `update_lead`
- CRM `update_stage`
- Gmail — draft only

This contract has no send capability. Gmail access is limited to
composing a draft; nothing in this contract's tool access can move a
message beyond `Status = draft`, and that absence is the enforcement
mechanism, not an instruction.

## Stop conditions
- A draft Activity has been created and both `Next Action` and
  `Next Action Due` are set on the lead, or
- `max_touches` (from `operating-config.md`) has been reached for the
  lead

## Handoff
When under the touch limit, logs the draft and calls CRM
`update_lead(lead_id, fields)` to set `Next Action` and
`Next Action Due`, leaving the lead's stage as-is for the operator's
approval-and-send cycle to move it forward. When `max_touches` is
reached, calls CRM `update_stage(lead_id, "Lost", reason)` instead of
drafting again. When an inbound opt-out is found, calls CRM
`update_lead(lead_id, fields)` to set `Do Not Contact`, then calls CRM
`update_activity(activity_id, "voided", reason)` once for every
Activity on the lead still at `Status = draft` or `Status = approved`
— found from the Activities `get_lead` already returned for this lead,
no separate query needed — so none of them can still reach `sent`
after the opt-out. Either way, the contract stops there — the stage
and the lead fields are the entire handoff; no other role is invoked
directly.

## Inline fallback
Runs as the fifth sequential phase on a host without sub-agent dispatch:
pull idle or outcome-logged leads directly from the CRM, draft the next
touch or close out the lead in the same context, and set the next
action fields.

### Guardrails
- Any inbound reply containing an opt-out sets `Do Not Contact`
  permanently on the lead and calls CRM `update_activity` to void every
  pending (`draft` or `approved`) Activity for it — never left sitting
  in the operator's approval queue after the prospect has asked not to
  be contacted.
- Every question the prospect actually asked is answered before
  anything new is introduced in the draft.
- Reaching `max_touches` moves the lead to `Lost` rather than drafting
  again — never exceeded.
