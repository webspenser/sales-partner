---
name: write-call-opener
description: Use when call is the chosen channel for a first touch or a follow-up — drafts a short phone opener, gatekeeper line, and voicemail built on a research hook, for the operator to read from.
---

The operator places every call. This skill writes what they read from
and logs it as a draft Activity; it never dials, texts, or leaves a
voicemail itself. Hard constraints:

- **The lead has a sourced phone number.** Use the chosen Contact's
  `phone` when present, otherwise the lead's `Phone`. With neither,
  this skill does not run — the Approacher or Follow-up picks another
  enabled channel.
- **Opener under 60 words**, spoken aloud in about 20 seconds.
- **Opens with who is calling in one line, then the hook** — the
  specific sourced thing research found about this business.
- **Exactly one question**, one a person can answer on the spot.
- **Voicemail under 25 seconds**: name, the hook, one reason to call
  back, the callback number from `callback_phone` in
  `context/operating-config.md`. If it is unset or still the
  `[phone]` placeholder, the voicemail leaves the number out for the
  operator to add — never an invented number.
- **Every claim about the business traces to
  `context/business-profile.md`**; every fact about the prospect has a
  Research row with a source URL.

## Procedure

1. Read the lead via CRM `get_lead`: its Research `Hook`s, its
   Contacts, and its `Phone`. Pick the number to dial per the first
   rule above.
2. Read `tone` and `callback_phone` from `context/operating-config.md`
   and the Voice section of `context/business-profile.md`.
3. Fill `templates/cold-call-opener.md`: the call line, the opener, the
   gatekeeper line, and the voicemail.
4. Count the opener's words; at or over 60, cut a sentence.
5. Re-check every claim against `business-profile.md` and every
   prospect fact against the lead's Research rows. Cut anything that
   doesn't trace.
6. Log via CRM `log_activity(lead_id, contact_id, channel="call",
   direction="outbound", draft_body=..., status="draft")`. This skill
   never sets any status but `draft`.

## Worked example

**Harbor Street Bakery**, a single-location bakery. Research row
(`web_presence`): "No website; the Google listing links to a
Facebook page last updated in 2024." Hook: "customers searching for
the bakery land on a two-year-old Facebook page." Contact: owner
Marisol Vega (from the listing's owner response), no direct line;
the listing's main number is used. `callback_phone` in
`context/operating-config.md` is configured as (555) 010-9000.

> Call: Harbor Street Bakery — (555) 010-4477 — ask for Marisol Vega
>
> Opener: Hi Marisol, it's Sam from Northbeam Studio. When people
> look up the bakery online, they land on a Facebook page from 2024.
> Is that where most of your new customers find you today?
>
> If a gatekeeper answers: Could I grab Marisol for a minute? It's
> about the bakery's online listing.
>
> Voicemail: Hi Marisol, Sam from Northbeam Studio. People searching
> for Harbor Street Bakery are landing on a Facebook page from 2024 —
> I have one idea for that. Call me back at (555) 010-9000.

Opener: 42 words. One question. The hook is sourced to the listing.

## Failure modes

- **Drafting a call for a lead with no sourced number.** A guessed or
  area-code-derived number is a fabrication; the Approacher chooses a
  different channel instead.
- **A pitch instead of a question.** An opener that describes the
  service before asking anything gets cut off; the question is the
  point of the call.
- **Treating the draft as permission to call.** The operator approves
  and dials. This skill's output is a draft Activity and nothing more.
