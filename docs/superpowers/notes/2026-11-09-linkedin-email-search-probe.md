# LinkedIn email search probe

Date: 2026-11-09. Actor: `harvestapi/linkedin-profile-search-by-name`,
tool `harvestapi--linkedin-profile-search-by-name` on the
`claude_ai_Apify_Connector` server. For sales-partner 8.6.0 (open
scraping guard, Phase A).

## Mode string

The input schema's `profileScraperMode` enum is
`["Short", "Full", "Full + email search"]`; the field is required. The
email-search mode is exactly `Full + email search` (spaces and `+` as
written). The README: "Full + email search. Additionally to Full
profiles, it will try to find email addresses for the profiles."

## The call

```json
{"firstName":"Satya","lastName":"Nadella","locations":["Redmond Washington"],
 "maxItems":1,"maxPages":1,"profileScraperMode":"Full + email search",
 "strictSearch":true,"waitSecs":45}
```

A well-known public profile was used, not a lead's owner, so no private
person's data was fetched for the probe. Run `hKtDZIOmG9Qc2W1y0`:
SUCCEEDED in 8.5 s, 1 item. The installed guard did not block it in
this development session.

## Output

The dataset gains two email groups beside the Full profile fields:

- `emails[]`: `email`, `status`, `deliverable`, `qualityScore`,
  `free` (true for a free-mail domain such as Gmail), `catchAllDomain`,
  `validEmailServer`;
- `companyWebsites[]`: `domain`, `url`, `validEmailServer`.

For this profile `emails[]` came back empty (no address found). An
empty `emails[]` is a valid "no email found" result, not drift.

Projection for `find_profiles` adds `emails.email,emails.free,emails.status,emails.deliverable`.
An address is recorded only when `deliverable` is true or `status` is
not `invalid`; `free: true` (a personal domain) is recorded like any
other found address, per the operator's choice.

## Price

The Store page says only "This Actor is paid per event" and "from
$3.00 / 1,000 search page results"; it does not state a per-profile
price for Full or for email search, or whether a lookup that finds no
email is charged. The run record the connector returns carries no
charged amount.

Until the operator reads the charge for run `hKtDZIOmG9Qc2W1y0` in
Apify Console, `usage.md` uses a conservative estimate of **$0.15 per
call** in `Full + email search` mode, three times the $0.05 per call
Full estimate from the 2026-11-03 probe (at `max_profile_results` 5),
so the ledger's estimate and the weekly cap err high.
