# Operating Config

Volume, cadence, and caps live here. Changing them is a config edit,
never a prompt edit. That separation is what lets an operator retarget
how hard or how carefully the agent works — more leads, a longer touch
cadence, a lower spend cap — without ever touching, and risking
breaking, how any sub-agent operates.

Unlike `business-profile.md` and `icp.md`, this file does not ship as a
blank. The pipeline must be able to run before anyone has tuned it, so
every key below ships with a real working default. The
`interview-business` skill (Phase 0) may adjust any of these values
during setup and again whenever operating needs change; every
sub-agent and skill listed in `AGENT.md` reads its limits from here,
never from a hardcoded number in a prompt.

Every value below is a number, a list, or a schedule — never a vague
setting — because every `Stop conditions` entry in this agent's
sub-agent contracts (`subagents/*.md`) is a countable resource, and
these keys are what make that countable.

```yaml
leads_per_week: 40
research_quota_per_week: 10
research_threshold: 60
approach_threshold: 70
enabled_channels: [email, linkedin]
follow_up_cadence_days: 4
max_touches: 4
timezone: "America/New_York"
schedules:
  - activity: prospect
    when: "Monday 07:00"
    then: [prepare]
  - activity: digest
    when: "Monday 08:00"
digest_channel: email
digest_delivery: draft
apify_spend_cap_usd_per_week: 25
research_budget_per_lead_minutes: 8
sending_identity: "[name] <[email]>"
tone: "[three adjectives from the interview]"
```

## What each key gates

- **`leads_per_week`** — the Prospector's target count of new `Scored`
  leads per run; see `subagents/prospector.md`'s `Stop conditions`.
- **`research_quota_per_week`** — the ceiling on how many leads the
  Preparer researches per week, applied on top of `research_threshold`;
  see `subagents/preparer.md`'s `Trigger` and `Stop conditions`.
- **`research_threshold`** — the minimum Prospector score (0–100, per
  the rubric in `icp.md`) a `Scored` lead needs to enter research.
  Default `60`. See `icp.md`'s Thresholds section for the full
  explanation of this gate.
- **`approach_threshold`** — the minimum re-scored value a `Researched`
  lead needs to reach the Approacher and get a drafted first touch.
  Default `70`, applied to the score the Preparer recomputes after
  research — a distinct, later gate from `research_threshold`, not a
  repeat of it. See `icp.md`'s Thresholds section.
- **`enabled_channels`** — the outbound channels the Approacher and
  Follow-up may choose between. `linkedin` in this list means LinkedIn
  copy may be **drafted** for the operator to paste by hand — it never
  authorizes any automated LinkedIn action (no automated connection
  requests, messages, or scraping), per `AGENT.md`'s guardrails. A
  channel not in this list is never chosen, regardless of fit.
- **`follow_up_cadence_days`** — the number of idle days after which a
  `Contacted`, `Replied`, or `Following Up` lead is considered stalled
  and due for a follow-up draft or a nudge; also the interval the
  **Stalled** CRM view (`crm-airtable-adapter.md`) is built against.
- **`max_touches`** — the total outbound touch limit per lead across the
  whole pipeline. Reaching it without a positive outcome moves the lead
  to `Lost` instead of drafting again — never exceeded, per
  `subagents/follow-up.md`'s `Stop conditions` and `AGENT.md`'s
  guardrails.
- **`timezone`** — the IANA time zone every `when` in `schedules` is
  read in (default `"America/New_York"`; the interview sets the
  operator's own).
- **`schedules`** — the recurring activities the host fires, one entry
  each. `activity` is one of `prospect`, `prepare`, `approach`,
  `follow-up`, or `digest` — the Workflow steps in `AGENT.md` that can
  run unattended. `interview` and the sales-call steps are never
  scheduled: both need the operator present. `when` is a weekday and
  24-hour time (`"Monday 07:00"`) or `"daily HH:MM"`. `then` is an
  optional ordered list of further activities run in the same session
  once `activity` reaches a stop condition. The shipped default runs
  prospecting then research on Monday at 07:00, and the digest an hour
  later. The `digest` entry also sets the digest's reporting window —
  see `skills/send-digest/SKILL.md`.
- **`digest_channel`** — the delivery channel for the digest (default
  `email`; SMS is a stubbed adapter, not yet enabled).
- **`digest_delivery`** — whether `send-digest` composes the digest as
  a Gmail draft addressed to `sending_identity` for the operator to
  open (`draft`, the default) or delivers it directly (`send`). This
  is the one setting in this file that changes what capability the
  agent holds rather than how it behaves: `send` requires a Gmail send
  scope, and Gmail cannot narrow that scope to a single recipient, so
  enabling it grants an ability that could technically reach a
  prospect. Leave it at `draft` unless the operator has decided
  otherwise; see `skills/send-digest/SKILL.md`'s step 10 and
  **Approval scope**.
- **`apify_spend_cap_usd_per_week`** — the hard ceiling on Apify actor
  spend per week, shared across the Prospector's sourcing and the
  Preparer's research. Reaching it is a `Stop conditions` trigger and
  an `AGENT.md` escalation ("Escalate to human when").
- **`research_budget_per_lead_minutes`** — the time budget the Preparer
  spends researching a single lead before it stops and hands off with
  whatever hooks it has found; see `subagents/preparer.md`'s `Stop
  conditions`.
- **`sending_identity`** — the `"[name] <[email]>"` the drafted email
  Activities are written from. Filled in by the interview; the agent
  never sends a prospect-facing message from this identity itself —
  every Activity stops at
  `status: draft` and only the operator's approval and send action puts
  a message on the wire, per the `log_activity` guardrail in
  `crm-contract.md`.
- **`tone`** — three adjectives describing how outbound copy should
  read, filled in by the interview from `business-profile.md`'s Voice
  section. Read by `write-cold-email`, `write-linkedin-touch`, and
  `write-follow-up` when drafting.

## Running on a schedule

This agent is a set of markdown files; it cannot wake itself up.
`schedules` is the single declaration of *when* each activity runs,
and the host is what fires it. Each entry becomes one host trigger that
starts a session with this instruction:

> Run the scheduled activity `<activity>` per
> `context/operating-config.md`.

The session then runs that Workflow step to its stop conditions, then
each activity in `then`, in order. Examples for the shipped
`prospect` entry:

- **Claude Code routine** — create a scheduled routine for Monday 07:00
  in `timezone`, with the instruction above as its prompt, pointed at
  this folder.
- **cron + headless CLI** — `0 7 * * 1 cd /path/to/sales-partner && claude -p "Run the scheduled activity prospect per context/operating-config.md"`,
  with the machine's `TZ` set to `timezone`.
- **n8n** — a Schedule Trigger node (Monday 07:00, `timezone`) feeding
  a node that starts the host with the same instruction.

Editing `schedules` without updating the host trigger changes nothing:
the file declares, the host fires. When the two disagree, the file is
the one to trust and the trigger is the one to fix.

Nothing in this file, and nothing any key here configures, sends a
message to a prospect on its own. Nothing sends without operator approval — that
guardrail is enforced in the CRM contract, not merely stated here:
`log_activity` creates an Activity at `status: draft` only, and
`update_activity` can move an existing Activity only to
`status: voided`; `approved` and `sent` are reachable only by the
operator acting outside the agent's tool access. See
`crm-contract.md`'s Approval invariant for the full, provable rule —
this file states the outcome, not the mechanics, precisely so it
cannot drift out of sync with them again.
