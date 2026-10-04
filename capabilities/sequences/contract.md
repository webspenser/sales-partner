# Sequences contract

The agent hands an approved email touch to the client's own cold-email
sequence platform: it adds the lead, with its personalization, to the
campaign the client set up for the lead's score band. The platform
sends the emails; the agent never writes or sends them itself.

## Operations

| Operation | Arguments | Returns | On failure |
|---|---|---|---|
| `get_workspace` | — | workspace id, quota used and limit; read-only | Reports the platform's error |
| `get_campaigns` | — | the band campaigns (band, id, name, status); read-only | Empty list means no band is mapped |
| `enroll_contact` | `band, email, first_name, last_name, variables` | the platform's contact id | Rejects an unknown `band` or an empty `email`; calling it again for an enrolled contact updates its fields mid-sequence, so callers enroll a lead once |
| `suppress` | `emails, reason` | ok | Rejects an empty `emails` list |

## Invariants

- `no_send` — no operation sends; enrollment hands the lead to a campaign the client set up and launched in the platform.
- `campaigns_bound_only` — enrollment reaches only the client's band campaigns: the agent passes a band, and the platform tool maps bands to campaigns.
- `no_campaign_control` — the agent never creates, launches, pauses or edits a campaign; the tool has no such operation.
- `enroll_ready_only` (acceptable) — only leads the operator moved to `Ready to Send`, not Do Not Contact, in an allowed country, never enrolled before. No guard can check this: it depends on the lead's state in the CRM.
