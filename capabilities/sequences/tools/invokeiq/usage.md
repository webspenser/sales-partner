# Sequences InvokeIQ tool

InvokeIQ (cold email) has a REST API but no MCP server, so it is wrapped
in an n8n workflow, **"Webspenser · InvokeIQ"** (`workflow.n8n.json` in
this folder). Its MCP Server Trigger exposes four tools and nothing
else. `invokeiq:` means those tools, whatever prefix the host gives the
connector (`mcp__invokeiq__…`). The InvokeIQ API key lives only in an
n8n credential; the agent and the instance never hold it.

## Operations

- **`get_workspace`** — `invokeiq:get_workspace` (no arguments). Returns
  InvokeIQ's workspace id, API usage and monthly limit.
- **`get_campaigns`** — `invokeiq:get_campaigns` (no arguments). Returns
  the workspace's campaigns with their status. Show the operator which
  campaign each band in the workflow's map points to.
- **`enroll_contact`** — `invokeiq:enroll_contact` with `band` (a key of
  `sequence_bands` in `operating-config.md`, such as `high`), `email`,
  `firstName`, `lastName` and `variables` (the personalization lines as
  a JSON object, one key per name in `variables:`). The workflow maps
  the band to its campaign ID and posts to InvokeIQ's
  `POST /api/v1/contacts`, which upserts: calling it again for an
  enrolled contact silently changes its fields mid-sequence, so enroll
  a lead once (the `enroll` skill checks for an earlier `sent` email
  touch). An unknown band fails. Returns the InvokeIQ contact id.
- **`suppress`** — `invokeiq:suppress` with `emails` (a list) and
  `reason`. Adds the addresses to InvokeIQ's workspace suppression list
  (`POST /api/v1/suppression`) so they never receive cold outreach.

The workflow has no tool to create, launch, pause or edit a campaign:
the client does that in InvokeIQ.

## Probe

Setup runs these read-only calls when binding this tool, and writes
what they find to `bindings/sequences.md` in the instance:

1. `invokeiq:get_workspace` — record `workspace: <id>`.
2. `invokeiq:get_campaigns` — show the operator each band's campaign;
   warn if one is not active.

The interview records `variables: <name>, <name>` (the custom fields
the campaigns' templates use, such as `icebreaker, company`) in the same
file. If the tools are unreachable, check the connector (Setup step 6)
and that the workflow is published.

## Guard policy

`guard.yaml` allows only the four tools. The agent guard policy (the
package-root `guard.yaml`) also denies n8n's instance-level tools that
run or rebuild any workflow, so nothing can route around these four.

## Setup

1. In InvokeIQ, create an API key and the campaigns, one per score band
   in `sequence_bands`, each with its sequence, unsubscribe handling and
   stop-on-reply turned on. InvokeIQ should send from a separate sending
   domain.
2. In n8n, import `workflow.n8n.json`.
3. Create a **new** HTTP Bearer credential named `InvokeIQ API` holding
   the InvokeIQ key, and select it on the four tool nodes. n8n silently
   attaches any existing credential of the same type to imported nodes,
   so check that each node shows `InvokeIQ API`.
4. In the `enroll_contact` node, replace `<HIGH_CAMPAIGN_ID>` and
   `<MID_CAMPAIGN_ID>` (and add any other band) with the campaign IDs
   from step 1.
5. Leave the trigger's Authentication on **n8n OAuth2**, then
   **Publish** the workflow. Saving alone does not change the live
   workflow.
6. Add the trigger's Production URL as a connector whose name contains
   `invokeiq` (claude.ai: Settings → Connectors → Add custom connector,
   then approve the n8n login; Claude Code: add it as a remote MCP
   server and log in when asked).
7. Set up the reply relay (`## Reply relay`).

## Reply relay

InvokeIQ reports replies and bounces by webhook only, and the agent has
no endpoint, so a small n8n workflow receives them and records each one
in the CRM. The relay only records facts: it never changes the status,
Do Not Contact, or anything else. The `sync-replies` skill makes every
decision from what it records.

Shipped for Attio: `relay/attio.n8n.json`. It checks the
`X-InvokeIQ-Signature` header (HMAC SHA-256 of the raw body with the
signing secret), keeps only replies (`contact.replied`) and bounces,
finds the person by email in Attio and adds one entry to
`sales_partner_outreach` for their company: `channel` `email`,
`direction` `inbound`, `status` `sent`, `date` the received date,
`summary` `<category>: <threadSummary>` (a bounce: `bounced`), and the
sentiment, score, subject, snippet and received time in `draft_body`.

To set it up:

1. Import `relay/attio.n8n.json` into the same n8n as the tools
   workflow.
2. Create a **new** Crypto credential holding a long random signing
   secret and select it on the "HMAC of raw body" node; create a **new**
   HTTP Bearer credential named `Attio API` with an Attio API key that
   can read people and write list entries, and select it on both Attio
   nodes.
3. **Publish** the workflow. In InvokeIQ, Settings → Webhooks: add the
   webhook node's Production URL with the same signing secret, for the
   replied and bounced events.

A relay for another CRM follows the same recipe: verify the signature,
keep replies and bounces, find the lead by the contact's email, and
create exactly one inbound email Activity at `sent` with that summary
and body, through the CRM's own API. Nothing else.

