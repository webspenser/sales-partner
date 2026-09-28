# Sales Partner

A sales partner for one business. It interviews you to learn your
business and your ideal customer, then runs a five-stage lead pipeline —
prospect, research, approach, sales call, follow-up — over your CRM. It
researches on its own but never contacts anyone: every outbound
message, email, LinkedIn note, or call opener is a draft you approve.

Built on the [Agent Standard](https://github.com/webspenser/agent-builder/blob/main/STANDARD.md)
with [Agent Builder](https://github.com/webspenser/agent-builder).
Version 0.9.1.

## Use it today (source mode)

1. Click **Use this template** on GitHub to create your own private
   copy — not a fork, so your data and changes stay in your repo.
2. Clone it and open Claude Code (or another host) in the folder.
   Run `./install.sh` once to wire the host files.
3. Ask the agent to run its interview (the `interview-business` skill);
   it fills `context/` with your business profile, ideal customer, and
   operating settings. Commit those files to your repo.

Plugin installs — the agent's logic from a catalog, your data in your
own folder — arrive with instance mode in version 1.0.0.

## Tools it needs

- A CRM. Today: Airtable, through `context/crm-airtable-adapter.md`;
  more adapters come later.
- Apify for scraping, web search, and Gmail in draft-only mode.

Connect these in your host (connectors or MCP servers). Credentials
never go in this repo.

## Scheduling

`context/operating-config.md` declares when each activity runs
(`schedules`); your host fires them — see "Running on a schedule" in that
file.

## Developing

    tests/run-all.sh                                   # content checks
    /path/to/agent-builder/bin/validate-agent.sh .     # structure

CI runs on pushes to `main` and on every pull request. Content tests and
the release rule run only in webspenser/sales-partner — in your own
copy, CI checks structure only, so committing your filled-in `context/`
is fine.

## License

Apache-2.0.
