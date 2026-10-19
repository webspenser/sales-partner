# Offer matching and talking points — design

Date: 2026-10-18. Builds on sales-partner 7.4.0 (one Attio list, research
and drafts as notes). Ships as **8.0.0** because the stage list, the
scheduled activities and the CRM operations change.

## Why

Sales Partner's job is now narrower and more useful: find leads, qualify
and research them, then **match each one to the offer most likely to
land**. Writing and sending the outreach happens outside Sales Partner.
The operator's n8n workflow reads the finished lead from the CRM and
starts it on a multi-channel sequence built for that lead's segment and
offer. The workflow fills the sequence's personalized parts from Sales
Partner's research and talking points.

Today the agent ends at `Approach Drafted`, with a full draft per channel
(email, LinkedIn and call notes) that the operator approves by moving the
lead to `Ready to Send`. Those per-channel drafts duplicate what the
sequences already contain. What the sequences can't know is:

- which segment and industry the lead is in;
- which offer suits it, and why;
- a lead-specific set of talking points.

Example: an accounting firm comes through. Sales Partner records segment
Professional Services, industry Accounting, and hero offer Invoice
Reconciliation, because reviews complain about billing mistakes. The
research note has what was found on the website and Google Maps. The
talking points note has the personal hooks. The operator drags the lead
to Approved, and n8n puts it in the Professional Services / Invoice
Reconciliation sequence with those hooks filled in.

## Goals

1. **An offer catalog per business.** A new context file,
   `context/offer-catalog.md`, written by the interview, lists what the
   business sells. Offers are grouped into segments, each segment lists
   the industries it covers, and each offer lists the buying signals
   that point to it. Nothing about the number of segments or offers is
   fixed. The operator's own instance has two segments with three offers
   each (see "The operator's catalog" below), but another business might
   have one segment with two offers.
2. **Four separate CRM items per researched lead,** each readable on its
   own by an automation:
   - **Segment**: one of the catalog's segments.
   - **Industry**: the specific trade, such as "Accounting" or "HVAC".
   - **Hero Offer**: one offer from the lead's segment.
   - **Talking Points**: a note.

   Two companions sit with Hero Offer: **Offer Reason** (short text with
   source links) and **Offer Evidence** (strong, moderate or weak).
3. **One Talking Points note** replaces the three per-channel draft
   notes. It holds raw material that works on phone, email and LinkedIn,
   not finished messages.
4. **A shorter pipeline.** `Approach Drafted` and `Ready to Send` merge
   into one stage, **`Approved`**, which only the operator writes. The
   agent's job ends at `Researched`.
5. **Research anyway.** The operator can tick a checkbox on a Scored
   lead to have it researched whatever its score.
6. **Research looks for what separates the offers.** The Preparer reads
   each offer's signals from the catalog and looks for them, so the
   offer pick rests on evidence.

## Non-goals

- Writing sequences, emails or scripts, or sending anything. Outreach is
  the operator's workflow's job.
- Building or changing the n8n workflow. This design only fixes what
  that workflow can read.
- Fixing the prospecting score ceiling (most leads top out at a Fit score
  of 50 at prospecting). That belongs to the goal-driven prospecting
  spec.
- Learning from outcomes, such as which offers convert. That is a later
  feature.

## Anti-goals (failure even if it technically works)

- The agent writes `Approved` or any later stage, or ticks Research
  anyway itself. Either would bypass the operator.
- A Hero Offer from outside the lead's own segment, or a Hero Offer that
  research ruled out.
- A hero offer justified by a signal that isn't in the research. Every
  claim in Offer Reason needs a source URL from the research, or is
  marked `unverified`.
- Segment, industry, offer and talking points packed into one text blob.
  Each must be a separate field or note.
- Offers fixed in the agent's instructions or tests instead of read from
  the catalog.

## The pipeline

**Stages:** New, Scored, Researched, Approved, Contacted, Engaged, Open
Deal, Nurture, Customer, Disqualified. That is ten stages, down from
eleven.

| Stage | Enters when | Exits to |
|---|---|---|
| `New` | Prospector creates the lead | Prospector scores it, moving it to `Scored`; a hard disqualifier moves it to `Disqualified` |
| `Scored` | Prospector records Fit score, Segment and Industry | Preparer picks it up when Fit clears `research_threshold` or **Research Anyway** is ticked |
| `Researched` | Preparer has researched the lead, re-scored it, matched the hero offer and written talking points | The operator drags it to `Approved`; an anti-signal found in research sends it to `Disqualified` instead of `Researched` |
| `Approved` | Only the operator writes it | The operator's workflow starts the sequence, and it or the operator moves the lead to `Contacted`. The operator moving it back to `Researched` cancels. The agent never acts on it |
| `Contacted` and later | Unchanged from 7.4 | Unchanged |
| `Disqualified` | Unchanged | Terminal for the agent |

**The agent writes** `New` (on create), `Scored`, `Researched` and
`Disqualified`. Both CRM guards' stage rules become `update: [Scored,
Researched, Disqualified]`, so `Approved` and every later stage are
refused. The contract's approval invariant, `draft_only`, is renamed
**`approval_only`**: the agent never writes `Approved` or later, and
never writes research or talking points on a lead at `Approved` or later.
The second part is an instruction, not guard-enforced, as today.

**What goes away:**
- the Approacher sub-agent;
- the scheduled activity `approach`;
- `approach_threshold`;
- the three per-channel drafting skills and their templates;
- `enabled_channels`, `sending_identity` and `callback_phone`.

The **Approach score** stays. The Preparer still re-scores after
research, and the score helps the operator decide what to approve, but
it no longer triggers anything.

## The offer catalog

**File:** `context/offer-catalog.md`, in the instance, next to the
business profile and ICP. It has a short prose intro and one YAML block.
Code reads the YAML block (the CRM bootstraps, the tests); the
agents read the whole file.

**Shape** (the builder settles the exact key names; this is what each
entry needs):

```yaml
segments:
  - id: professional-services          # stable, kebab-case; what CRMs store
    name: Professional Services
    industries: [Accounting, Tax, Legal, Medical, Real Estate]
    offers:
      - id: ps-invoice-reconciliation  # unique across the whole catalog
        name: Invoice Reconciliation
        what: one or two sentences on what the business delivers
        suits: who it fits best
        signals:                       # what research looks for
          - billing or invoicing complaints in reviews
        rule_out:                      # signals that make it a poor fit
          - already advertises an in-house billing team
```

**Rules:**
- **IDs are unique across the whole catalog**, not just within a
  segment, and never change once leads use them. The two Inbound Lead
  Qualification offers are separate offers with separate IDs, because
  they are pitched differently.
- **A business with no segments** has one segment, which the interview
  names after the business. The Segment field is still written.
- **An offer removed from the catalog** stays on leads already matched
  to it. The agent stops choosing it for new leads.
- **The ICP's target industries come from the catalog.** `icp.md` keeps
  the Fit and Approach rubrics, but its industry-fit criterion scores
  against the catalog's industries instead of its own list, so the two
  files can't disagree.
- **The catalog is an allowed source for claims about the business.**
  Today, AGENT.md's operating rule 2 says every claim about the business
  traces to `business-profile.md`. That rule becomes
  "`business-profile.md` or `offer-catalog.md`". The profile's "What we
  sell" section becomes a short summary that points to the catalog for
  the offers. The interview keeps the two consistent, as it now does for
  the ICP. Eval Case 7 is updated to match. *(Designer's call.)*

**The interview** gets a new round after Round 1 (the business), and
asks for:
- the segments;
- each segment's industries;
- each offer's name, what it is, who it suits, the buying signals that
  point to it, and what rules it out.

It writes the catalog and confirms it with the operator, the same way it
confirms the rubrics. Re-running the interview updates the catalog. The
interview becomes the only writer of `offer-catalog.md`.

**Setup** (the tools step) keeps the CRM's Segment and Hero Offer
choice lists in sync with the catalog by re-running the bootstrap, which
adds missing options. The operator re-runs that step after changing the
catalog.

## Who does what

**Prospector.** When it scores a lead, it also sets:
- **Industry**: the specific trade from the listing category or search
  result, in the catalog's wording where one fits.
- **Segment**: the catalog segment whose industries include it.

A lead whose industry fits no segment scores low on industry fit, as
today. Its Segment is left empty, and it is not researched unless the
operator ticks Research Anyway.

**Preparer.** It works through Scored leads in this order, up to
`research_quota_per_week`:
1. leads with Research Anyway ticked, by Fit score, highest first;
2. then leads whose Fit score clears `research_threshold` *and* whose
   Segment is set, highest first.

A lead with an empty Segment is skipped even when its Fit score clears
the threshold, because the Fit rubric alone can reach 60 with zero for
industry fit. Before skipping, the Preparer tries to fill Segment from
the lead's Industry, using the catalog's industry lists. This covers
leads scored before 8.0, which have no Segment. If the Industry maps to
a segment, the Preparer sets it and continues; if not, it skips the
lead. *(Designer's call.)*

A Research Anyway lead whose industry fits no segment is still
researched. The Preparer assigns the segment the research fits best,
marks Offer Evidence `weak`, and says in Offer Reason that the segment
was chosen by the Preparer. If no segment fits at all, it leaves
Segment, Hero Offer and Offer Evidence empty, explains why in the stage
reason, and still moves the lead to `Researched` with its research and
talking points. The operator's workflow should treat an empty Hero Offer
as "route to the operator". *(Designer's call.)*

For each lead:
- It researches as today, but also looks for the signals and rule-outs
  of each offer in the lead's segment.
- It identifies decision-makers.
- It re-scores the lead with the Approach rubric.
- It corrects Segment or Industry if the research shows the Prospector's
  guess was wrong. The stage reason says what changed.
- It **matches the hero offer**: of the offers in the lead's segment, the
  one whose signals the research supports best and that nothing rules
  out. If at least one offer isn't ruled out, it always picks one. If
  research rules out **every** offer in the segment, it leaves Hero Offer
  and Offer Evidence empty, names each rule-out with its source in Offer
  Reason, and still moves the lead to `Researched` with its talking
  points. *(Operator's decision.)*
  - **Offer Evidence** is `strong` when two or more sourced signals point
    to that offer, `moderate` for one, and `weak` when the pick rests
    only on the industry or segment with no specific signal.
  - **Offer Reason** names the signals with their source URLs, or says
    the pick is by segment fit alone.
- It **writes the talking points**: one dated section added to the
  lead's Talking Points record.
- It moves the lead to `Researched`, or to `Disqualified` if research
  found an anti-signal. A disqualified lead gets no offer and no talking
  points.

When the lead was picked because of Research Anyway, the stage reason
says so, for example "researched by operator request; Fit 45 below
research_threshold 60". The operator can later see how those leads turn
out.

**Interactive requests.** In an interactive session, the operator can
ask the Preparer to:
- **research a named lead.** Treated like a Research Anyway tick.
- **re-match or refresh talking points** for a lead at `Researched`. The
  Preparer re-runs only the matching and talking points from the
  existing research, unless asked to research again. It adds a new
  Talking Points section and overwrites the three offer fields.

The agent never acts on a lead at `Approved` or later.

**New skills:**
- **`match-offer`** picks the offer, evidence level and reason.
- **`write-talking-points`** replaces `write-cold-email`,
  `write-linkedin-touch` and `write-call-opener`.

`research-company` gains the step of looking for the catalog signals.
`score-lead` drops the approach-gate wording.

## The Talking Points note

**The record.** Each lead gets one Talking Points record, added to by
dated sections like the research record. It is never edited, replaced or
deleted.
- **Attio:** a note on the company titled `Sales Partner · Talking
  Points`, with sections headed `=== YYYY-MM-DD · talking points ===`.
- **HubSpot:** one Note per section associated with the company, whose
  body starts with the same header line.

**Each section holds these six labelled parts, in this order,** with
every factual claim sourced or marked `unverified`. `For:`, `Offer:` and
`Opener:` are one line each. `Points:`, `Avoid:` and `Contact routes:`
are each followed by a bulleted list, one item per line; `Avoid:` may
have none, written as `- none`.
- **For:** the decision-maker to address (name and title), or "owner,
  name not found".
- **Offer:** the hero offer's name, repeated so the note reads on its
  own, or `none matched` when Hero Offer is empty. In that case the
  points stay general to the segment.
- **Opener:** one observation specific to this lead, the strongest hook
  from the research.
- **Points:** two or three talking points tied to the hero offer, each
  drawn from a research finding, such as a review, the website or a
  listing detail.
- **Avoid:** anything not to say, for example a recent bad review not to
  mention, or a claim the business profile can't back.
- **Contact routes:** the phone, email and LinkedIn found, each sourced.
  This is a list for the workflow, not a message.

**For the n8n workflow:** read the newest section, which is the last one
in the note. The header format and the six labels are a public format.
They change only with a version bump and an upgrade note in the README,
like the research note today.

## CRM fields

These are new fields on the lead. In Attio they go on the
`sales_partner_pipeline` entry; in HubSpot they are company properties.
Industry already exists.

| Field | Attio slug | HubSpot property | Type | Written by |
|---|---|---|---|---|
| Segment | `segment` | `sp_segment` | single select (catalog segment IDs) | Prospector; Preparer may correct |
| Industry | `industry` (exists) | `sp_industry` (exists) | text | Prospector; Preparer may correct |
| Hero Offer | `hero_offer` | `sp_hero_offer` | single select (catalog offer IDs) | Preparer |
| Offer Reason | `offer_reason` | `sp_offer_reason` | text | Preparer |
| Offer Evidence | `offer_evidence` | `sp_offer_evidence` | single select: strong / moderate / weak | Preparer |
| Research Anyway | `research_anyway` | `sp_research_anyway` | checkbox | operator only |

**Choice options are the catalog IDs** (for example
`ps-invoice-reconciliation`), so the workflow routes on a value that
doesn't change if the operator renames an offer. The readable offer name
is in the Talking Points note and the catalog.

**Guards:** `research_anyway` / `sp_research_anyway` get `forbid: true`
in both CRM guard policies, so the agent can't tick it. The stage rule
changes as described under "The pipeline". The other new fields are
normal agent writes.

**Bootstraps:**
- Both bootstraps add the new fields.
- They read Segment and Hero Offer options from the instance's
  `context/offer-catalog.md`, adding missing options and never removing
  any, as they do today.
- They add the `Approved` stage.
- They can't remove the old `Approach Drafted` and `Ready to Send`
  stages, so they print a note, and the README's upgrade steps tell the
  operator to archive them by hand.

**CRM contract changes:**
- `log_draft` becomes `log_talking_points(lead_id, contact_id, body)`.
  It only creates or adds sections, and has no channel argument.
- `get_lead` returns the Talking Points record instead of the three
  draft records.
- `query_by_score` loses `approach` as a trigger use. The Preparer's
  queue needs Research Anyway leads first. The builder decides whether
  that is a new argument or a separate query.
- The lead-field text names the six fields above and who writes them.

## Digest

- The Review section is a queue, as today: every lead waiting at
  `Researched`, however old, each with Segment, Hero Offer, Offer
  Evidence and a link, highest Approach score first. Weak-evidence picks
  and empty Hero Offers are marked. *(Designer's call: a queue, not a
  "since last digest" list, so unapproved leads don't drop out.)*
- The Ready to Send section becomes **Approved, not yet contacted**, so
  the operator can spot leads the workflow hasn't picked up. It shows
  days since the lead was researched, labelled as such. True days since
  approval would need CRM history reads, because the operator's drag
  doesn't stamp `Stage Changed At`. *(Designer's call: the same
  approximation the 7.4 digest uses.)*
- The draft and channel wording goes.
- The digest still never writes to the CRM.

## Upgrading from 7.4

The README gets an "Upgrading from 7.4" note. In order:
1. Update the plugin. Re-run the interview's offer catalog round, or
   the whole interview, to create `context/offer-catalog.md`.
2. Re-run setup's tools step, so the bootstrap adds the new fields, the
   catalog options and the `Approved` stage.
3. In the CRM, move leads at `Ready to Send` to `Approved`, and leads at
   `Approach Drafted` back to `Researched`. Then archive those two old
   stages.
4. Remove `schedule_approach` from `schedules.yaml`, then re-run
   `/sales-partner:schedule`. Until then, the schedule check refuses the
   stale entry.
5. For leads already at `Researched` with no Hero Offer, ask Sales
   Partner in an interactive session to match offers for them. That
   runs the re-match path. Old Email, LinkedIn and Call draft notes are
   left in place.

## Tests and evals

**Tests.** Today's content and policy tests pin the Approacher, the
drafting skills, the eleven stages and the draft note titles. They are
rewritten to pin the new shape:
- the ten stages;
- the stage rule `[Scored, Researched, Disqualified]`;
- `Approved` refused to the agent in both guards;
- `research_anyway` forbidden to the agent;
- the Talking Points title and header;
- the catalog YAML parsing in both bootstraps;
- no remaining reference to the Approacher, `approach_threshold` or the
  removed skills.

**Evals.** The draft cases (4, 11, 14, 15, 20) are replaced with cases
for:
- an offer matched with strong evidence and sourced reasons;
- a weak-evidence pick when research finds nothing specific;
- an offer ruled out by a rule-out signal;
- every offer ruled out, so Hero Offer is empty and the lead still
  reaches `Researched`;
- a Research Anyway lead below the threshold being researched first;
- a lead whose industry fits no segment;
- talking points that stay sourced, and say nothing the business profile
  can't back.

## The operator's catalog (instance content, not product)

The operator's own instance will hold the following, written during
their re-interview. Signals and rule-outs come from the operator's
offer reference, still to come. Listed here only so the design can be
checked against a real case.

- **Professional Services** (accounting, tax, legal, medical, real
  estate):
  - Inbound Lead Qualification & Appointment Setting (24/7 voice agent)
  - Invoice Reconciliation
  - Onboarding Copilot
- **Home & Auto Services** (plumbing, HVAC, mechanic):
  - Inbound Lead Qualification & Appointment Setting (24/7 voice agent)
  - Reputation Management
  - Past Customer Retargeting / Outreach

## Left to the builder

- Exact YAML key names in the catalog, and how the bootstraps parse it.
- Whether the Research Anyway queue is a new query or an argument on
  `query_by_score`.
- How the content of `research-company`, `match-offer` and
  `write-talking-points` is split.
- Whether a new research finding type is needed for review-based signals,
  or whether the existing types cover them.
- How AGENT.md stays under its size limit after the changes.
