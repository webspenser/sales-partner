# Offer Catalog

What the business sells, grouped into segments, and the buying signals
that point to each offer. Written by the `interview-business` skill and
re-run whenever an offer, a segment or a target industry changes; every
bracketed section is a prompt for that interview to replace with the
operator's own answer. The interview is the only writer of this file.

The CRM bootstraps read the one fenced `yaml` block (and only that
block) to fill the Segment and Hero Offer choice lists. **This package
template has no such block on purpose**: the example below is a `text`
block the bootstraps ignore, so an unfilled template can't put example
ids into a CRM. A bootstrap run against it stops and says to run the
interview's offer catalog round first, which writes the instance's real
`yaml` block.

The Prospector, the Preparer and `match-offer` read the whole file.
Nothing downstream may claim an offer, a segment or a signal this file
doesn't contain.

## Rules for the catalog

- An `id` is lowercase kebab-case (`a-z`, `0-9`, single hyphens), for
  example `ps-invoice-reconciliation`.
- **Every `id` is unique across the whole catalog**, segments and offers
  together, not just within a segment. The CRMs store the id, so an id
  never changes once leads use it. Rename an offer by changing `name`.
- Two offers that are pitched differently are two offers with two ids,
  even when the product underneath is the same.
- A business with no distinct segments has one segment, named after the
  business.
- An offer removed from the catalog stays on the leads already matched
  to it; the agent stops choosing it for new leads.
- `industries` is the list the Fit score's industry criterion scores
  against, in the wording the Prospector should write to a lead's
  Industry field.

## Segments and offers

[Interview: get the segments (the kinds of business the operator sells
to), each segment's industries, and, for each offer in a segment, its
name, what the business delivers in one or two sentences, who it suits
best, the buying `signals` that research can find in public sources
(reviews, listings, websites, job posts), and the `rule_out` signals that
make it a poor fit. Confirm the finished catalog with the operator, the
same way the rubrics are confirmed. Write the result as one fenced
`yaml` block in the shape of the example below, and delete the example.]

Example of the shape (a `text` block, not read by code):

```text
segments:
  - id: professional-services          # stable, kebab-case; what the CRMs store
    name: Professional Services
    industries: [Accounting, Tax, Legal, Medical, Real Estate]
    offers:
      - id: ps-inbound-lead-qualification   # unique across the whole catalog
        name: Inbound Lead Qualification & Appointment Setting
        what: A 24/7 voice agent that answers inbound calls, qualifies the caller and books the appointment.
        suits: Practices that miss calls outside office hours or lose enquiries to voicemail.
        signals:                       # what research looks for
          - reviews mention unanswered calls or voicemail
          - listing shows limited opening hours
        rule_out:                      # signals that make it a poor fit
          - already advertises a 24/7 answering service
      - id: ps-invoice-reconciliation
        name: Invoice Reconciliation
        what: Matches invoices to payments and flags the differences, so the books close without manual checking.
        suits: Firms that handle high invoice volumes for their clients.
        signals:
          - billing or invoicing complaints in reviews
          - job posts for bookkeepers or accounts clerks
        rule_out:
          - already advertises an in-house billing team
      - id: ps-onboarding-copilot
        name: Onboarding Copilot
        what: Guides each new client through the intake forms and document requests.
        suits: Firms that take on many new clients and chase paperwork by hand.
        signals:
          - reviews mention a slow or confusing start
          - a new-client page with a long document checklist
        rule_out:
          - already runs a client portal with guided intake
  - id: home-auto-services
    name: Home & Auto Services
    industries: [Plumbing, HVAC, Mechanic]
    offers:
      - id: ha-inbound-lead-qualification
        name: Inbound Lead Qualification & Appointment Setting
        what: A 24/7 voice agent that answers inbound calls, qualifies the job and books the visit.
        suits: Trades whose crews are on site and can't pick up the phone.
        signals:
          - reviews mention calls that went unanswered
          - an emergency-service claim with only a single phone line
        rule_out:
          - already advertises a dispatcher or a live answering service
      - id: ha-reputation-management
        name: Reputation Management
        what: Asks every happy customer for a review and answers the reviews that arrive.
        suits: Trades with good work and few or unanswered reviews.
        signals:
          - few reviews for the size of the business
          - unanswered negative reviews
        rule_out:
          - already has a review count and response rate above its competitors
      - id: ha-past-customer-outreach
        name: Past Customer Retargeting / Outreach
        what: Contacts past customers when a service is due, such as a yearly service or an inspection.
        suits: Trades with repeat work and a customer base they don't follow up with.
        signals:
          - services that recur, such as a yearly service or a seasonal check
          - no sign of a maintenance plan or reminder programme
        rule_out:
          - already runs a membership or maintenance-plan programme
```
