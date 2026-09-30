# Email drafts — Gmail tool

Maps the contract (`../../contract.md`) onto a Gmail MCP server.
`gmail:` means the connected Gmail server's tools, whatever their
prefix; if that server names them differently, use its equivalent
draft-create and thread-search tools.

- `create_draft` — `gmail:create_draft` with `to`, `subject`, `body`
  (and `cc`). Return the draft's id as `draft_id`.
- `search_threads` — `gmail:search_threads` with the query; use
  `gmail:get_thread` when the caller needs a thread's messages.

`guard.yaml` in this folder is enforced by the agent's guard policy
engine before every Gmail call inside an instance. Its allow list holds
only the draft and read tools (`create_draft`, `list_drafts`,
`get_draft`, `search_threads`, `get_thread`, `get_message`,
`list_labels`). Any tool whose name contains `send`, `reply` or
`forward` is denied, and every tool not on the list is blocked, so
`no_send` holds by mechanism even on a Gmail server that offers
sending, replying or forwarding. If your Gmail server names these tools
differently, add its names to `allow`.

## Probe

1. `gmail:list_drafts` must succeed (read-only). Write
   `mailbox: <address>` to `bindings/email_drafts.md` in the instance
   when the result shows the address; otherwise ask the operator which
   mailbox this is.
