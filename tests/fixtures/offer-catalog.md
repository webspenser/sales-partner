# Test fixture: a filled offer catalog (two segments, six offers).

Used by the offline bootstrap tests. Not a package file the agent reads.

```yaml
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
