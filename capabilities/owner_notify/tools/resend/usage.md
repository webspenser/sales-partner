# Owner notify — Resend tool

Sends the owner's notifications through the client's own Resend account,
from a no-reply address on the client's verified domain. `resend:` below
means the connected Resend server's tools, whatever their prefix.

- `notify_owner` — call `resend:send-email` with `from` = the
  `sender_email` binding (the bare address, no display name), `to` =
  every `recipient_email` binding (one list), `subject` =
  `[sales-partner] <kind>: <subject>`, and the plain-text body in `text`
  (with `payload`, when given, appended as a fenced block). Pass an
  `idempotencyKey` built from the run and the kind, so a retry never
  sends twice. Never pass `cc`, `bcc`, `replyTo`, `headers`,
  `scheduledAt`, `attachments` or `topicId`: the guard refuses them.
  Return the email id from the response.

The tool's description tells the model to ask the user for `from`, `cc`,
`bcc` and `replyTo`. Do not ask: `from` and `to` come only from the
bindings, and the others are never passed. Pass `context` and
`llm_model` as the tool requires. Pass `conversation_id` only when the
server returned one earlier in this session; never invent one.

## Setup

1. The client owns the Resend account and pays for it; Webspenser is a
   team member on it (the free plan sets no strict team-member limit) or
   manages it on the client's behalf.
2. Add the client's sending domain in Resend (a subdomain such as
   `notify.<domain>` keeps it apart from the client's own mail) and add
   its DNS records until Resend shows it verified.
3. Choose a no-reply sender on that domain, for example
   `no-reply@notify.<domain>`.
4. Add the hosted connector `https://mcp.resend.com/mcp` in claude.ai
   (Settings → Connectors → Add custom connector) and sign in to Resend.
5. Pinned values, written to `bindings/owner_notify.md` by setup after
   the owner confirms each:
   - `recipient_email` — the owner's address (repeat the line for each
     address that should receive notifications);
   - `sender_email` — the no-reply address from step 3.
6. Commit and push `bindings/owner_notify.md`. The guard lets the agent
   send only while the file matches the pushed copy.

## Probe

Call `list-domains` (or `get-domain` with its id) and confirm the
`sender_email` domain is listed with status `verified` and sending
enabled. Record it as `sender_domain: <domain>` in
`bindings/owner_notify.md`. If it is not verified, stop and show step 2
of Setup. The probe sends nothing.
