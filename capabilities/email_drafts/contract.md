# Email drafts contract

The agent composes email as drafts in the operator's mailbox for the
operator to review. It never sends: turning a draft into a sent
message is an operator action taken outside the agent's tools.

## Operations

| Operation | Arguments | Returns | On failure |
|---|---|---|---|
| `create_draft` | `to, subject, body`, optional `cc` | `draft_id` | Rejects an empty `to` or `body` |
| `search_threads` | `query` | matching threads (sender, subject, date, snippet); read-only | Empty list is a valid result |

## Invariants

- `no_send` — no operation sends mail, and the bound adapter makes
  sending impossible rather than merely discouraged.
