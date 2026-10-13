# Owner notify contract

How the agent tells the business owner something: a status alert, an
error, a run summary, the digest. It sends to the owner and nobody else.
Skills and sub-agent contracts call `notify_owner`, never a provider's
tools.

## Operations

| Operation | Arguments | Returns | On failure |
|---|---|---|---|
| `notify_owner` | `kind` (`alert`, `error`, `summary`, `digest`), `subject`, `body`, `payload` (optional) | the provider's message id | the provider rejects the send, or no recipient is bound |

The recipient is never an argument: it is every `recipient_email` line in
`bindings/owner_notify.md`, and the sender is its `sender_email` line,
both written at setup with the owner confirming them. The subject starts
with `[sales-partner] <kind>:`. The body is plain text. `payload`, when
given, is appended to the body as a fenced block, so a person or a later
skill can read it back unchanged.

## Invariants

- `owner_only_send` — every send goes only to recipients pinned in
  `bindings/owner_notify.md`, from the pinned sender. The tool's guard
  checks every recipient argument and refuses any argument that could
  bypass that check.
