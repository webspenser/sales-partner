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

Every value below is a number, a list, or a fixed choice — never a vague
setting — because every `Stop conditions` entry in this agent's
sub-agent contracts (`subagents/*.md`) is a countable resource, and
these keys are what make that countable.

```yaml
leads_per_week: 40
prospecting_sources: [apify_google_maps, apify_site_scraper, web_search]
research_quota_per_week: 10
research_threshold: 60
approach_threshold: 70
enabled_channels: [email, linkedin]
digest_channel: email
digest_delivery: draft
apify_spend_cap_usd_per_week: 25
research_budget_per_lead_minutes: 8
sending_identity: "[name] <[email]>"
callback_phone: "[phone]"
tone: "[three adjectives from the interview]"
```

## What each key gates

- **`leads_per_week`** — the Prospector's target count of new `Scored`
  leads per run; see `subagents/prospector.md`'s `Stop conditions`.
- **`prospecting_sources`** — the sourcing tools the Prospector may
  use, and the only ones. `apify_google_maps` returns local-business
  listings (name, address, phone, website, rating, review count);
  `apify_site_scraper` reads company sites and public social pages;
  `web_search` is general search; `apollo` is a stubbed tool —
  listing it makes the Prospector report that it is not yet enabled,
  never substitute another source. Both Apify sources draw on
  `apify_spend_cap_usd_per_week`. To research every new lead, set
  `research_quota_per_week` equal to `leads_per_week` and lower
  `research_budget_per_lead_minutes` so the week's budget still fits.
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
- **`enabled_channels`** — the outbound channels the Approacher drafts
  touches for. `linkedin` in this list means LinkedIn
  copy may be **drafted** for the operator to paste by hand — it never
  authorizes any automated LinkedIn action (no automated connection
  requests, messages, or scraping), per `AGENT.md`'s guardrails. A
  channel not in this list is never chosen, regardless of fit.
  `call` in this list means the Approacher may draft a phone opener
  (`skills/write-call-opener/SKILL.md`) for a lead with a sourced phone
  number; the operator places the call.
- **`digest_channel`** — the delivery channel for the digest (default
  `email`; SMS is a stubbed tool, not yet enabled).
- **`digest_delivery`** — whether `send-digest` composes the digest as
  a draft (via `email_drafts`) addressed to `sending_identity` for the
  operator to open (`draft`, the default) or delivers it directly
  (`send`). This
  is the one setting in this file that changes what capability the
  agent holds rather than how it behaves: `send` requires a Gmail send
  scope, and Gmail cannot narrow that scope to a single recipient, so
  enabling it grants an ability that could technically reach a
  prospect. Leave it at `draft` unless the operator has decided
  otherwise; see `skills/send-digest/SKILL.md`'s step 10 and
  **Approval scope**. `send` is dormant and falls back to a draft with a
  disclaimer line (the email tool's guard policy denies send tools)
  until an `email_send` capability exists; see
  `skills/send-digest/SKILL.md`.
- **`apify_spend_cap_usd_per_week`** — the hard ceiling on Apify actor
  spend per week, shared across the Prospector's sourcing and the
  Preparer's research. Reaching it is a `Stop conditions` trigger and
  an `AGENT.md` escalation ("Escalate to human when").
- **`research_budget_per_lead_minutes`** — the time budget the Preparer
  spends researching a single lead before it stops and hands off with
  whatever hooks it has found; see `subagents/preparer.md`'s `Stop
  conditions`.
- **`sending_identity`** — the `"[name] <[email]>"` the drafted email
  Activities are written from, and the digest's address. Filled in by
  the interview; the agent never sends a prospect-facing message from
  this identity — email to prospects goes out only through the
  operator's sequence platform after approval.
- **`callback_phone`** — the operator's own number the voicemail in a
  call opener gives for callbacks. Filled in by the interview when
  `call` is in `enabled_channels`; never a prospect-facing send
  capability — the agent only writes it into a draft.
- **`tone`** — three adjectives describing how outbound copy should
  read, filled in by the interview from `business-profile.md`'s Voice
  section. Read by `write-cold-email`, `write-linkedin-touch` and
  `write-call-opener` when drafting.

## Running on a schedule

Schedules live in the instance's `schedules.yaml`, which the interview
writes. The `schedule` skill turns them into Claude cloud routines, only
for activities whose capabilities are all covered by guard policies.

Nothing in this file, and nothing any key here configures, sends a
message to a prospect on its own. Nothing goes out without the
operator's approval, and only the operator approves a plan, by moving
the lead to `Ready to Send` — the guard refuses that status to the agent.
`log_activity` creates an Activity at `status: draft` only, and
`update_activity` moves it to `sent` (after the operator's own touch or
their automation) or `voided`. See
`capabilities/crm/contract.md`'s Approval invariant for the full, provable rule —
this file states the outcome, not the mechanics, precisely so it
cannot drift out of sync with them again.
