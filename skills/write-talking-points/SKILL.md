---
name: write-talking-points
description: Use when a researched lead has its hero offer (or none matched) and needs talking points — writes one dated section in the six-label Talking Points format, every claim sourced, and adds it to the lead's Talking Points record.
---

Talking points are raw material for the operator and the operator's
own workflow, which run the outreach on phone, email and LinkedIn. They
are not a message: no greeting, no sign-off, no call to action, nothing
written to be sent as it stands. This skill writes one section and sends
nothing.

Every factual claim about the prospect carries a source URL from the
research or the Contacts, or is marked `unverified`. Every claim about
the business traces to `context/business-profile.md` or
`context/offer-catalog.md`; what neither file says, the talking points
don't say.

## Input

- **The lead** (`get_lead`): company, Segment, Industry, `Do Not
  Contact`, and its research record and Contacts.
- **The `match-offer` output:** `hero_offer`, `offer_evidence`,
  `offer_reason`, and the picked offer's `name` and `what`.
- `context/offer-catalog.md`: the hero offer's `name`, `what` and
  `suits`; with no hero offer, the segment's `name` and `industries`.
- `context/business-profile.md`: What we sell, Proof, Pricing,
  Differentiators and Voice.
- `context/operating-config.md`: `tone`.

## The format

One section, exactly this shape. The header and the six labels are a
public format (`capabilities/crm/contract.md`, `log_talking_points`):
the operator's workflow parses them, so they are never reworded,
reordered, translated or decorated.

```
=== YYYY-MM-DD · talking points ===
For: <name, title> (or "owner, name not found")
Offer: <the hero offer's name> (or "none matched")
Opener: <one observation specific to this lead>
Points:
- <two or three points tied to the hero offer, each from a research finding; fewer, or "none", when research is thin>
Avoid:
- <what not to say, or "none">
Contact routes:
- <the phone, email and LinkedIn found, each sourced, or "none">
```

`For:`, `Offer:` and `Opener:` are one line each. `Points:`, `Avoid:`
and `Contact routes:` are each followed by a bulleted list, one `- `
item per line; a list with nothing in it is the one line `- none`, never
another wording. Every line is plain text: no
tables, no bold, no links in Markdown syntax. A source URL goes in
square brackets after the claim it backs.

## Procedure

1. **Check the lead first.** If `Do Not Contact` is true, or the lead is
   at `Approved` or any later status, write nothing and hand back to the
   caller. A lead that went to `Disqualified` gets no talking points.
2. Read `tone` and the Voice section (its words and its two example
   sentences) fresh. The Opener and the Points follow that voice; the
   format above does not change with it.
3. **For:** the decision-maker from the lead's Contacts (`role:
   decision-maker`), written as `<name>, <title>` with the title the
   source gives. With more than one, take the one whose title best
   matches `icp.md`'s Target roles, preferring a `Verified` one. With
   none, write `For: owner, name not found`. Keep that contact's
   `contact_id` for the write; with none, `contact_id` is empty.
4. **Offer:** the hero offer's `name` from the catalog, not its id, so
   the note reads on its own. With `hero_offer` empty, write exactly
   `Offer: none matched`.
5. **Opener:** the strongest usable hook from the research, one line,
   with its source: specific to this lead, under 90 days old, something
   the operator could have an opinion about. Prefer a hook that is also
   one of the hero offer's signals. Never the Opener:
   - a finding whose `Hook` is one of the placeholders `contact route`,
     `offer signal`, `rule-out` or `no hooks found`;
   - a complaint review, which belongs in `Avoid:` (see below).
   With no usable hook left, write exactly
   `Opener: unverified — no recent hook found`.
6. **Points:** two or three, each joining one research finding to what
   the hero offer does, in the words of its `what` in the catalog. Each
   quotes or states the finding as research recorded it, with its source
   URL, adding nothing the finding doesn't say, then links it to the
   offer. An `offer signal` finding is good material here even without a
   usable hook; `contact route`, `rule-out` and `no hooks found` findings
   are not. With fewer findings to draw on, write fewer points: one
   finding, one point; none, `- none`. A claim about results or proof
   is used only when `business-profile.md`'s Proof section states it; a
   price only when Pricing does. With `Offer: none matched`, the points
   draw only on the findings and name no offer; they say nothing about
   what the business does beyond `business-profile.md`.
7. **Avoid:** what the operator should not say to this lead, each with
   its reason and source where one exists. For example: a recent bad
   review not to quote back at them; an offer research ruled out (the
   `offer_reason` names it), so the lead isn't pitched what it already
   has; a claim the business profile can't back, such as results when
   Proof is empty. With nothing to avoid, write `- none`.
8. **Contact routes:** every phone, email and LinkedIn URL found, one per
   line, each with whose it is and its source: the Contacts' sourced
   routes, then the business's main line and general inbox from the
   `listing` findings with `Hook: contact route`. A pattern-guessed
   email is never a route. With none found, write `- none`.
9. **Check before writing.** The header is first, with today's date; the
   six labels are present, in order, each spelled exactly as above; every
   factual claim has a source URL in brackets or the word `unverified`;
   every claim about the business is in `business-profile.md` or
   `offer-catalog.md`.
10. Write the section with one CRM call,
    `log_talking_points(lead_id, contact_id, body)`, where `body` is the
    whole section, header line included. The call adds the section to the lead's Talking Points
    record, creating the record on the first call; earlier sections are
    never edited. A redo is a new section, and the newest section is the
    one the workflow reads.

## Worked example

Fictional lead **Brightwater Accounting**, matched by `match-offer` to
Invoice Reconciliation (`ps-invoice-reconciliation`, `strong`), with
Inbound Lead Qualification ruled out. `tone`: "plain, warm, direct".
Proof in `business-profile.md` is empty. The research is the three
findings in `match-offer`'s worked example (the 2026-09-21 billing
review, the 2026-10-02 accounts clerk post, the contact page's 24/7
answering service) plus two `listing` findings with `Hook: contact
route`: the main line on the Google listing and the info@ address on
the contact page. Contacts: Priya Nandakumar, Managing Partner
(`decision-maker`), named on the firm's team page, which links her
LinkedIn profile.

```
=== 2026-10-18 · talking points ===
For: Priya Nandakumar, Managing Partner
Offer: Invoice Reconciliation
Opener: Brightwater posted an accounts clerk role on 2026-10-02 to "chase and reconcile client invoices" [https://jobs.example/brightwater-clerk]
Points:
- The 2026-10-02 accounts clerk post asks for someone to "chase and reconcile client invoices" [https://jobs.example/brightwater-clerk]; Invoice Reconciliation matches invoices to payments and flags the differences.
- A 2026-09-21 review says "they billed me twice for the same quarter and it took weeks to fix" [https://maps.example/brightwater]; Invoice Reconciliation flags the differences, so the books close without manual checking.
Avoid:
- Don't quote the double-billing review back to them; it is a complaint, there only to show the problem [https://maps.example/brightwater].
- Don't pitch call answering: their contact page says "calls answered 24/7 by our answering service" [https://brightwater.example/contact].
- Don't cite results or client names: Proof in the business profile is empty.
Contact routes:
- LinkedIn: https://linkedin.example/in/priya-nandakumar (Priya Nandakumar) [https://brightwater.example/team]
- Phone: +1 555 0100, main line [https://maps.example/brightwater]
- Email: info@brightwater.example, general inbox [https://brightwater.example/contact]
```

Two points, because research holds two findings that bear on the offer;
the answering-service finding is a rule-out and goes to `Avoid:`.
Written with `log_talking_points(lead_id, contact_id = <Priya's
contact_id>, body = <the section above>)`. Had `match-offer` found every
offer ruled out, the Offer line would read `Offer: none matched` and the
points would state the clerk post and the review as found, naming no
offer.

## Failure modes

- **Writing a message instead of material.** "Hi Priya, I noticed…" is a
  draft. The workflow fills its own sequences from these lines; a
  greeting or sign-off in them ends up duplicated or out of place.
- **Changing the format.** A renamed label (`Talking points:`), a
  reordered part, a table or a bold heading breaks the workflow's
  parsing. The header and the six labels are fixed.
- **A point with no finding behind it.** "Accounting firms always
  struggle at year end" is true of the industry, not this lead. Each
  point names its finding and source, or is left out.
- **Claiming what the business can't back.** A result, a client name, a
  price or a capability that isn't in `business-profile.md` or
  `offer-catalog.md` is never stated, however plausible; it goes in
  `Avoid:` if the operator might be tempted to say it.
- **Pitching a ruled-out offer, or naming an offer when none matched.**
  The Offer line repeats `match-offer`'s pick and nothing else.
- **Listing a guessed route.** A pattern-guessed email address stays in
  the Contact's Notes; it is never a contact route.
