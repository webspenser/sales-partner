# Approacher — Sub-Agent Contract

## Purpose
Choose the opening outbound channel for a qualified lead and draft the
first-touch message for operator review.

## Trigger
`Stage = Researched` **and** `Score >= approach_threshold` — the revised
score written after research, not the original scoring estimate. A lead
that looked promising before research can fall below this bar and never
reach this contract at all, without consuming an outreach touch. This
contract is invoked once a lead meets that condition and is handed a
specific `lead_id` already matching it; the query that identifies
qualifying leads runs outside this contract's own tool access, per the
`Tools allowed` list below.

## Inputs
- The lead record, via CRM `get_lead` (includes linked Contacts and
  Research)
- `context/business-profile.md` — proof points and differentiators to
  ground the draft
- `context/operating-config.md` — `enabled_channels`, `tone`,
  `sending_identity`
- `templates/` — blank channel templates (cold email, LinkedIn
  connection note, LinkedIn DM)
- `samples/` — gold-standard filled examples for voice and structure

## Outputs
- A channel recommendation with rationale, chosen only from
  `enabled_channels`
- A drafted first-touch message logged as an Activities row: `Channel`,
  `Direction = outbound`, `Draft Body`, `Status = draft`, linked to the
  lead and the chosen Contact
- `Stage = Approach Drafted`

## Tools allowed
- CRM `get_lead`
- CRM `log_activity`
- CRM `update_stage`
- Read access to `templates/`
- Read access to `samples/`

This contract has no send capability. That is the enforcement mechanism,
not an instruction.

## Stop conditions
- One draft Activity has been logged for the lead

## Handoff
Logs the draft and calls CRM `update_stage(lead_id, "Approach Drafted",
reason)`, then stops. From there, the operator reviews the draft in the
**Awaiting Approval** view, flips `Status` to `approved`, and the send
happens outside this contract's tool access; once the message sends,
`Status` becomes `sent` and the lead's stage moves to `Contacted`. None
of that runs inside this contract — it has no send tool and calls no
other role.

## Inline fallback
Runs as the third sequential phase on a host without sub-agent dispatch:
the same orchestrating loop that would otherwise dispatch this contract
instead runs it directly, once per lead already identified as
`Stage = Researched` and `Score >= approach_threshold`. Drafting,
logging, and the stage update all run in the same context; the operator
approval-and-send step still happens outside either dispatch model,
identically.

### Guardrails
- LinkedIn output is always copy-paste text handed to a human. No
  automated LinkedIn action of any kind — no automated connection
  requests, messages, or scraping.
- Email drafts stop at `Status = draft`; nothing in this contract can
  move an Activity to `sent` — `log_activity` itself rejects a `sent`
  write unless the record was previously `approved`, and approval is an
  operator action.
- One opening touch per lead from this contract.
