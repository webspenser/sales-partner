---
name: interview-business
description: Use when installing this agent for a business, or when its offer, market, or targeting has materially changed — conducts the intake interview and writes the context files and the instance's schedules.yaml.
---

This skill is the only writer of `context/business-profile.md`,
`context/offer-catalog.md`, `context/icp.md`,
`context/operating-config.md`'s interview-sourced keys, and the
instance's `schedules.yaml`. It runs as a conversation with the operator,
never as a form to fill in silently — every bracketed prompt in those
files exists because a human has to answer it in their own words.

## Procedure

1. **Round 1 — the business.** Ask, one at a time, waiting for an
   answer before asking the next: what do you sell, who is it for, what
   does it cost, and what happens if a customer does nothing about the
   problem you solve. Never combine two of these into one message.
2. Write what was learned to `context/business-profile.md` before
   starting the offer catalog round: fill in "What we sell" as a short
   summary (what the business does overall, what "done" looks like for a
   customer, what is out of scope; the offers themselves stay in the
   catalog), a first pass at "Who we serve," "Pricing," and fold the
   "does nothing" answer into "Differentiators" (the alternative every
   prospect is really comparing against). Leave any sub-point the
   operator didn't cover as its original bracketed prompt rather than
   guessing at it.
3. **Round 1b — the offer catalog.** Ask, one at a time, waiting for an
   answer before asking the next:
   1. Which kinds of business do you sell to? Each is a **segment**. A
      business with no distinct kinds gets one segment, named after the
      business itself.
   2. For each segment, which industries does it cover? These are the
      only target industries: `icp.md`'s Fit rubric scores industry fit
      against them, so ask for them in the wording the Prospector should
      write to a lead's Industry field.
   3. For each segment, which offers do you sell to it? For each offer
      ask separately: its name; what you deliver, in one or two
      sentences; who it suits best; the buying `signals` that research
      can find in public sources (reviews, listings, websites, job
      posts) and that point to it; and the `rule_out` signals that make
      it a poor fit. Push for signals a researcher could actually read
      off a public page, not a sales opinion such as "needs help". The
      same product pitched differently to two segments is two offers.
      Last for each offer, after its signals and rule-outs, ask an
      optional question: do you have research tips for it, meaning what
      the researcher should look for and where (for example "reviews
      mentioning voicemail; a front desk job post is strong; check
      whether the website offers online booking")? These are the
      offer's `research_tips`. The operator may skip it; an offer
      without tips is researched from its signals and rule-outs alone.
      Never write tips the operator didn't give.
   4. Give every segment and every offer an `id`: lowercase kebab-case
      (`a-z`, `0-9`, single hyphens), for example
      `ps-invoice-reconciliation`. **Every id is unique across the whole
      catalog**, segments and offers together; a segment prefix on offer
      ids keeps the same offer in two segments apart. The CRMs store the
      id and it never changes once leads use it, so a rename changes
      `name` only.

   Then read the draft catalog back to the operator, segment by segment:
   names, industries, and for each offer its what, suits, signals,
   rule_out and any research_tips, with the ids. If an industry appears in two segments'
   `industries`, say so at the readback and ask the operator which one
   segment keeps it: a lead in an industry two segments list gets no
   Segment, and the Preparer skips it on every run unless the operator
   ticks Research Anyway. Get an explicit confirmation or correction of
   each before writing anything, the same way the rubrics are confirmed.
   Only after the operator confirms, write `context/offer-catalog.md`
   in the instance: keep the template's first paragraph and "Rules for
   the catalog"; drop the template's paragraph about having no `yaml`
   block (it is untrue once the catalog is filled); and replace the
   bracketed prompt and the `text` example with exactly one fenced block
   whose info string is `yaml` (not `text`), in the shape the template
   documents. The CRM bootstraps read that one `yaml` block and nothing
   else, and stop if the file holds none or more than one, so write
   valid YAML and no other `yaml` fence:

   ```yaml
   segments:
     - id: <segment-id>
       name: <Segment name>
       industries: [<Industry>, <Industry>]
       offers:
         - id: <offer-id>
           name: <Offer name>
           what: <one or two sentences>
           suits: <who it suits best>
           signals:
             - <a signal research can find>
           rule_out:
             - <a signal that makes it a poor fit>
           research_tips: >
             <what the researcher should look for, and where; omit the key
             when the operator gave none>
   ```

   `research_tips` is prose: keep it inside the folded block, with every
   line indented under the key, and the bootstraps will skip it.

   Then update `context/business-profile.md`'s "What we sell" if the
   catalog round changed the summary, so the two files agree, before
   starting Round 2. When the interview is re-run for a changed offer,
   segment or industry, read the existing catalog first, change only
   what the operator says has changed, keep every existing id, and tell
   the operator to re-run setup's tools step so the CRM's Segment and
   Hero Offer choice lists pick up the new ids. An offer the operator
   drops is deleted from the catalog; leads already matched to it keep
   it.
4. **Round 2 — the customer.** First ask whether the business sells
   to companies or local businesses, and note the answer as
   `target_type`. Then ask, one at a time: describe your three best
   current customers; what did they have in common before they bought;
   who have you declined to work with, and why; which size measure fits
   (offer headcount or revenue for companies, locations or review count
   for local businesses), and its bands; if the business serves an
   area, the service area center and radius, with the unit; and
   which events signal a prospect is newly in-market, offering the
   example set in `context/icp.md`'s Buying triggers section that
   matches `target_type`. Do not ask for target industries here: they
   come from the segments' `industries` in the offer catalog (Round 1b),
   and `icp.md` keeps no industry list of its own.
5. From the Round 2 answers, derive two draft rubrics, each with 0/50/100
   anchor language per criterion and weights summing to 100 within each
   table:
   - **Fit score** (gates research): only criteria the Prospector can
     read from the source listing before any research — industry fit
     (scored against the catalog's industries), company size,
     geography, and for `local_business` the listing criteria in
     `context/icp.md` (website on listing, phone listed, opening hours,
     review sentiment, unclaimed listing).
   - **Approach score** (recorded, gates nothing): only criteria
     research resolves — buying trigger, decision-maker reachable,
     review recency (or, for `company`, the date of the latest news or
     post), or the operator's own equivalents.

   A criterion only research can resolve never goes in the Fit table:
   scored at prospecting it is always 0, and it holds every lead below
   the research gate. Propose `research_threshold` with the Fit rubric,
   checking that a strong-fit lead can clear the Fit gate on listing
   facts alone; the Approach score has no threshold. State the draft
   weights and the threshold back to the operator explicitly, one rubric
   at a time (e.g. "For Fit I'd weight industry at 25, geography at
   15... does that match how you'd pick which leads to research?") and
   get an explicit confirmation or correction of each before writing
   anything. Only after both are confirmed, write these
   `context/icp.md` sections: Target type, Firmographics (with
   `size_measure`; no industry list), Geography (with `service_area` when
   it serves an area), Target roles, Buying triggers, Anti-signals, and
   Scoring rubric (both tables, the anchor guidance and the threshold) —
   including the "who did you decline" answers as concrete Anti-signals
   — and `research_threshold` to `context/operating-config.md`, before
   starting Round 3. On a re-run over an `icp.md` written before the
   offer catalog existed, rewrite those sections rather than keep their
   old text: remove any industry list from Firmographics, word the
   Industry fit criterion and its anchor as the package's
   `context/icp.md` does (scored against the catalog's `industries`),
   and keep only `research_threshold` in Thresholds.
6. **Round 3 — the proof.** Ask, one at a time: what results can you
   name, with numbers; who will take a reference call. If the operator
   offers a sample email, social post, or web page as evidence, ask
   for the real artifact (a link, a pasted copy, a forwarded file) —
   never draft one yourself to fill the gap.
7. Write `context/business-profile.md`'s "Proof" section from Round 3's
   named metrics and references before starting Round 4. Save any real
   artifacts supplied into the instance's `context/samples/`,
   unmodified from what the operator gave; if none were supplied,
   leave `context/samples/` empty rather than inventing content for
   it. Never write into the package's `samples/`.
8. **Round 4 — the operating parameters.** Ask, one at a time: how many
   leads per week should the pipeline target; which sourcing tools may
   it use (`apify_google_maps` for local-business listings,
   `apify_contact_info` for contact details on business websites,
   `apify_reviews` for a business's Google Maps reviews, `apify_ads`
   for the ads it runs, `apify_jobs` for its job posts,
   `apify_site_reader` for reading a few pages of its website,
   `web_search`; Apify needs the business's own Apify account with a
   monthly usage limit; do not ask about the Apify connection itself,
   because setup's tools step owns it); which activities should
   run on a schedule (prospecting, research, the
   digest — the shipped default is prospecting
   then research on Monday at 07:00 and the digest on Monday at 08:00),
   and for each one the weekday and time, or daily, plus your time zone
   as an IANA name such as `America/New_York`); what is the weekly
   Apify spend cap; how should the
   talking points sound (three to five adjectives, plus one example
   sentence in that voice). Last, ask which email
   address or addresses should receive the digest and the agent's
   alerts. Do not write them to any file here: setup's tools step
   offers them as the `recipient_email` values for `owner_notify`,
   repeats them back, and writes `bindings/owner_notify.md` once the
   operator confirms.
9. Write the answers to `context/operating-config.md`'s keys
   (`leads_per_week`, `prospecting_sources`,
   `apify_spend_cap_usd_per_week`, `tone`), to
   `context/business-profile.md`'s "Voice" section (the adjectives plus
   the example sentence), and to
   `schedules.yaml` at the instance root (the folder holding
   `instance.yaml`), which holds the schedule answers: `timezone` (the
   IANA name), one `schedule_<activity>: "<Weekday|daily> HH:MM"` line
   for each activity the operator wants on a schedule (`<activity>` is
   `prospect`, `prepare`, or `digest`), and
   `then_prospect: prepare` when research should follow prospecting in
   the same run. The shipped default is `schedule_prospect: "Monday
   07:00"`, `then_prospect: prepare`, and `schedule_digest: "Monday
   08:00"`. Tell the operator that the `schedule` skill turns these
   lines into scheduled runs. This is the last write; the interview
   is complete once it lands.

Because each round writes its own files before the next round starts,
an interview interrupted after Round 2 leaves a complete, usable
`offer-catalog.md` and `icp.md` and a partial `business-profile.md`
behind — never a half answer sitting only in the conversation.

## Worked example

Operator: "Ridgeline Ops" sells fractional revenue-ops setup to B2B SaaS
companies.

- Round 1 answers → `business-profile.md`: sells a 6-week RevOps
  build-out ($8k flat fee) to Series A–C SaaS companies; "what happens
  if nothing" → they keep losing pipeline visibility in spreadsheets,
  which becomes the "doing nothing" comparison in Differentiators.
- Round 1b answers: one segment, named after the business ("Ridgeline
  Ops", id `ridgeline-ops`), industries SaaS and Fintech; one offer,
  `ridgeline-revops-buildout` ("6-week RevOps build-out": sets up the
  CRM, pipeline stages and reporting for a SaaS sales team), suits
  Series A–C companies whose pipeline lives in spreadsheets; `signals`:
  job posts for a first RevOps or sales-ops hire, a funding announcement
  in the last 90 days; `rule_out`: already employs a head of revenue
  operations. The operator confirms the readback and the catalog is
  written to `context/offer-catalog.md` as a `yaml` block;
  `business-profile.md`'s "What we sell" stays a two-line summary that
  names the segment.
- Round 2 answers: best three customers were all 50–500-employee SaaS
  companies within 90 days of a funding round; declined two roofing
  companies and one that wanted a full-time hire, not a fractional
  engagement. Size measure: headcount, 50–500; no service area (they
  sell nationally); buying trigger: a funding round in the last 90
  days. Industries are not asked here; Fit's industry criterion scores
  against the catalog's. Fit rubric proposed: Industry fit 40, Company
  size 30, Geography 30, with `research_threshold` 60; Approach rubric
  (recorded, no threshold): Buying trigger 50, Decision-maker reachable
  30, latest news or post 20. The operator moves Fit weight from Geography
  to Industry (50/30/20) and confirms Approach as-is. Written to
  `icp.md`, including "not B2B SaaS" and "wants full-time hire, not
  fractional" as Anti-signals.
- Round 3 answers: "cut time-to-first-qualified-pipeline from 11 weeks
  to 4 weeks for Meridian Analytics"; Meridian's founder will take
  reference calls. Operator pastes an actual outbound email they sent
  Meridian — saved verbatim to `context/samples/`.
- Round 4 answers: 40 leads/week, prospecting
  Monday 07:00 and digest Monday 08:00 Eastern, $25/week Apify cap,
  tone "direct, technical, no fluff" with the example line "We don't
  do discovery calls to sell you discovery calls — here's the
  finding." Written to `operating-config.md`, `schedules.yaml`
  (`timezone: America/New_York`, `schedule_prospect: "Monday 07:00"`,
  `then_prospect: prepare`, `schedule_digest: "Monday 08:00"`), and
  `business-profile.md`'s Voice section.

## Failure modes

- **Accepting "everyone" as an ICP.** If Round 2's three best
  customers don't share anything concrete, keep asking — a rubric
  built on "everyone" scores every lead the same and is worthless to
  the Prospector. Push for the actual pattern, or name the absence of
  one and flag it to the operator rather than inventing a plausible-
  sounding target.
- **Putting a research-only criterion in the Fit rubric.** A buying
  trigger or a reachable decision-maker is unknown at prospecting, so
  it scores 0 there and lowers every lead's Fit score by its weight. If
  the operator wants one weighed, it belongs in the Approach rubric.
- **Writing a catalog the operator has not confirmed, or inventing its
  content.** Segments, industries, offers, signals and rule-outs are the
  operator's, read back and confirmed before `offer-catalog.md` is
  written. Never fill a `signals` or `rule_out` list with plausible
  entries the operator didn't give; an offer with no signals yet is
  written with `signals: []` and flagged; an offer the operator gave no
  tips for is written without a `research_tips` key. Two offers sharing an `id`, or
  an `id` that is not kebab-case, breaks the CRM bootstrap — check every
  id before writing.
- **Writing a rubric the operator has not confirmed.** Deriving weights
  from Round 2 is a draft, not a write. `icp.md` is never updated with
  scoring weights the operator hasn't explicitly agreed to, even when
  the draft looks obviously right.
- **Filling `context/samples/` with invented copy instead of asking
  for real artifacts.** A sample the agent wrote itself teaches the
  voice back to itself, not the operator's actual voice. If no real
  artifact is offered, leave `context/samples/` empty rather than
  manufacture one.
