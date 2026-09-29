# Email drafts — Gmail adapter

Maps the contract (`../../contract.md`) onto a Gmail MCP server.
`gmail:` means the connected Gmail server's tools, whatever their
prefix; if that server names them differently, use its equivalent
draft-create and thread-search tools.

- `create_draft` — `gmail:create_draft` with `to`, `subject`, `body`
  (and `cc`). Return the draft's id as `draft_id`.
- `search_threads` — `gmail:search_threads` with the query; use
  `gmail:get_thread` when the caller needs a thread's messages.

`adapter.yaml` blocks every tool of the matched server whose name
contains `send`, so `no_send` holds by mechanism even on a Gmail
server that offers sending.

## Probe

1. `gmail:list_drafts` must succeed (read-only). Write
   `mailbox: <address>` to `bindings/email_drafts.md` in the instance
   when the result shows the address; otherwise ask the operator which
   mailbox this is.
