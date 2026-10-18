---
name: match-offer
description: Use when a researched lead needs its hero offer — picks the one offer from the lead's segment in context/offer-catalog.md that research supports best and nothing rules out, grades the evidence, and writes the reason with source URLs.
---

This skill carries no offers of its own. Every segment, offer, signal
and rule-out comes from `context/offer-catalog.md` at the moment the
skill runs, so a catalog edit changes matching immediately, with no edit
to this skill. Every claim in the reason comes from a research finding
with its source URL, or is marked `unverified`; a signal that is not in
the research is never used to justify a pick.

## Input

- **The lead:** its `lead_id`, Segment (a catalog segment id) and
  Industry.
- **Its research findings:** this run's findings, or, for a re-match, the
  findings in the lead's research record from `get_lead`. Each has
  `type, summary, source_url, date, hook`.
- **Its segment's offers:** read from the catalog's one fenced `yaml`
  block (`segments:` → `offers:`, each with `id`, `name`, `what`,
  `suits`, `signals` and `rule_out`).
- **Segment chosen by the Preparer** (optional, yes or no): yes when the
  lead's Industry fit no segment and the Preparer assigned the segment
  the research fits best.

## Output

Three values, written with one CRM `update_lead(lead_id, {"hero_offer":
…, "offer_evidence": …, "offer_reason": …})` call and handed back to the
caller for `write-talking-points`:

| Field | Value |
|---|---|
| `hero_offer` | one offer `id` from the lead's own segment, or empty |
| `offer_evidence` | `strong`, `moderate` or `weak`, or empty |
| `offer_reason` | short text naming the signals and rule-outs with their source URLs |

`offer_evidence` is:
- `strong` when two or more sourced signals point to the picked offer;
- `moderate` when one sourced signal does;
- `weak` when the pick rests only on the segment or industry, with no
  specific signal;
- empty when every offer in the segment is ruled out, or when no segment
  fits. `hero_offer` is empty in exactly the same two cases.

## Procedure

1. Read `context/offer-catalog.md` fresh, never from a remembered copy.
   Find the segment whose `id` equals the lead's Segment. If the Segment
   is empty or is no segment in the catalog, stop here: write
   `hero_offer` and `offer_evidence` empty and `offer_reason` as `No
   segment: <why, e.g. industry "Dentistry" is in no catalog
   segment>.` Never borrow an offer from another segment.
2. Take that segment's offers only, in catalog order. An offer no longer
   in the catalog is never chosen, even on a re-match of a lead that had
   it. `research-company` ends the `Summary` of each finding it recorded
   for the catalog with `Signal for <offer id>: "…"` or `Rule-out for
   <offer id>: "…"`. Start from those, but read every finding: research
   written before the catalog existed carries no such marks.
3. **Rule-outs first.** For each offer, compare every finding with each
   of its `rule_out` entries. A finding that shows a rule-out (for
   example, the website advertises "our in-house billing team" against
   `already advertises an in-house billing team`) rules that offer out.
   A rule-out needs a sourced finding, the same as a signal; a hunch with
   no source rules nothing out. A ruled-out offer is never picked,
   however many signals point to it.
4. **Signals.** For each offer still in, count the findings that show one
   of its `signals` entries, each with its source URL. Count each
   finding once, even when it fits two entries, and count the same fact
   found on two sites once. Only the catalog's signals count: a finding
   that seems to point to the offer but matches none of its `signals` is
   not a signal.
5. **Pick.** If every offer in the segment is ruled out, write
   `hero_offer` and `offer_evidence` empty and an `offer_reason` that
   names each rule-out with its source (form below). Otherwise always
   pick one offer: the one with the most signals. On a tie, pick the one
   whose signals are the most recent; if still tied, the one whose
   `suits` best describes what research shows about the lead; if
   nothing separates them, the first in catalog order. With no signal for
   any offer, pick the offer whose `suits` the research best supports, or
   the first offer not ruled out, and grade it `weak`.
6. **Grade.** Apply the thresholds above to the picked offer's signal
   count. When the segment was chosen by the Preparer, the grade is
   `weak` whatever the count.
7. **Reason.** Write `offer_reason` in one of these forms, plain text,
   every claim followed by its source URL in brackets:
   - Signals: `<offer name>: <signal entry> — <what the finding shows>
     [<source URL>]; <signal entry> — … [<source URL>].`
   - Segment fit alone: `<offer name>: segment fit alone (<segment
     name>, industry <Industry>); no catalog signal found in research.`
   - Preparer's segment: start with `Segment chosen by the Preparer:
     <why, sourced>.`, then the signals or the segment-fit form.
   - Every offer ruled out: `Every offer ruled out: <offer name> —
     <rule_out entry> — <what the finding shows> [<source URL>]; …`
   In the first three forms, also name any other offer ruled out, as
   `Ruled out: <offer name> — <rule_out entry> [<source URL>].`, so the
   operator sees why it was passed over.
8. Write the three values with one `update_lead` call. On a re-match this
   overwrites the earlier values; that is the point of a re-match. Hand
   the values, with the picked offer's `name` and `what`, back to the
   caller.

## Worked example

Fictional lead **Brightwater Accounting**, Segment
`professional-services`, Industry Accounting. The segment's offers are
Inbound Lead Qualification & Appointment Setting
(`ps-inbound-lead-qualification`), Invoice Reconciliation
(`ps-invoice-reconciliation`) and Onboarding Copilot
(`ps-onboarding-copilot`). Research found:

- `listing`: a Google review, 2026-09-21, "they billed me twice for the
  same quarter and it took weeks to fix" (`https://maps.example/brightwater`).
- `hire`: a job post for an accounts clerk to "chase and reconcile client
  invoices", 2026-10-02 (`https://jobs.example/brightwater-clerk`).
- `web_presence`: the site's contact page says "calls answered 24/7 by
  our answering service" (`https://brightwater.example/contact`).

Rule-outs: the contact page shows `already advertises a 24/7 answering
service`, so Inbound Lead Qualification is ruled out. Signals: Invoice
Reconciliation has two (the review and the job post); Onboarding Copilot
has none. Pick Invoice Reconciliation, two sourced signals: `strong`.

```
hero_offer: ps-invoice-reconciliation
offer_evidence: strong
offer_reason: Invoice Reconciliation: billing or invoicing complaints in reviews — a 2026-09-21 review says they were billed twice for one quarter [https://maps.example/brightwater]; job posts for bookkeepers or accounts clerks — an accounts clerk post to reconcile client invoices, 2026-10-02 [https://jobs.example/brightwater-clerk]. Ruled out: Inbound Lead Qualification & Appointment Setting — already advertises a 24/7 answering service [https://brightwater.example/contact].
```

Had research found only the answering-service page, two offers would
still be in with no signal: the pick would be by segment fit alone,
graded `weak`. Had the site also shown a client portal with guided
intake and an in-house billing team, every offer would be ruled out:
`hero_offer` and `offer_evidence` empty, and the reason naming all three
rule-outs with their sources.

## Failure modes

- **Picking from another segment.** A plumber's lead never gets a
  Professional Services offer because its signals look better. The
  segment bounds the choice; if the segment is wrong, the Preparer
  corrects the Segment first, then matches.
- **Picking an offer research ruled out.** A sourced rule-out ends that
  offer for this lead, whatever its signals. Picking it anyway puts a
  pitch for something the lead already has in front of the operator.
- **A pick justified by a signal that isn't in the research.** "Firms
  like this usually struggle with billing" is not a signal. Every signal
  in the reason has a finding and a source URL behind it.
- **Grading up.** One review is `moderate`, not `strong`; an industry
  match with no signal is `weak`. The workflow and the operator read the
  grade to decide how hard to lean on the offer.
- **Leaving the offer empty when one offer is still in.** Empty is only
  for "every offer ruled out" and "no segment". If one offer is not ruled
  out, pick it, at `weak` if that is all the evidence there is.
