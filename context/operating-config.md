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
digest_schedule: "Monday 08:00"
digest_channel: email
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
- **`digest_schedule`** — when `send-digest` fires, as a weekday and
  24-hour time (default `"Monday 08:00"`).
- **`digest_channel`** — the delivery channel for the digest (default
  `email`; SMS is a stubbed adapter, not yet enabled).
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
  never sends from this identity itself — every Activity stops at
  `status: draft` and only the operator's approval and send action puts
  a message on the wire, per the `log_activity` guardrail in
  `crm-contract.md`.
- **`tone`** — three adjectives describing how outbound copy should
  read, filled in by the interview from `business-profile.md`'s Voice
  section. Read by `write-cold-email`, `write-linkedin-touch`, and
  `write-follow-up` when drafting.

Nothing in this file, and nothing any key here configures, sends a
message on its own. Nothing sends without operator approval — that
guardrail is enforced in the CRM contract (`log_activity` rejects any
write of `status: sent` unless the record's current status is
`status: approved`), not merely stated here.
