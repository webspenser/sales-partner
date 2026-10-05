# Sales Partner

A lead generation and personalization partner for one business. It
interviews you to learn your business and your ideal customer, then
finds, scores and researches fresh leads on a recurring basis and
prepares the first touch for each: it recommends email, LinkedIn or a
call, drafts that touch in full, and writes personalized statements for
every channel you use. It never sends. When you approve a lead in your
CRM (`Ready to Send`), your own CRM automations, systems or other
agents take it from there.

Built on the [Agent Standard](https://github.com/webspenser/agent-builder/blob/main/STANDARD.md)
with [Agent Builder](https://github.com/webspenser/agent-builder).
Version 6.0.0.

## Install (plugin mode)

    /plugin marketplace add webspenser/agent-library
    /plugin install sales-partner@webspenser

Then open Claude Code in an empty folder — this becomes your instance,
where your data lives — and run `/sales-partner:setup`. It writes
`instance.yaml`, runs the interview to fill `context/`, and offers to
make the folder a private git repo. From then on, opening Claude Code
in that folder loads the agent. Plugin updates never touch your folder.

## Use it from source

1. Click **Use this template** to create your own private copy.
2. Clone it and run `./install.sh`.
3. Run the `setup` skill in source mode. It writes `instance.yaml` at
   the root; the guard needs the `agent` line:

   ```yaml
   agent: sales-partner
   mode: source
   ```
4. Ask the agent to run its interview (the `interview-business` skill).

## Tools it needs

- A CRM — Attio, Airtable, or HubSpot (`capabilities/crm/tools/`); setup binds it after a read-only check. If a CRM needs fields the probe does not find, setup offers two choices: create them yourself from the tool's `## Setup` steps, or run its `bootstrap.py` with an API key in your own terminal.
- Apify for scraping and web search; Gmail for the digest draft.

Each tool's guard policy makes Attio, Airtable, HubSpot and Gmail unattended-safe.

Connect these in your host (connectors or MCP servers). Credentials
never go in this repo.

Scheduled runs: after setup, run `/sales-partner:schedule`. Scheduled
prospecting and research use web search only: Apify is never attached
to a routine, because no guard policy covers it.

## Developing

    tests/run-all.sh                                   # content checks
    /path/to/agent-builder/bin/validate-agent.sh .     # structure

CI runs on pushes to `main` and on every pull request. Content tests and
the release rule run only in webspenser/sales-partner — in your own
copy, CI checks structure only, so committing your filled-in `context/`
is fine.

## License

Apache-2.0.
