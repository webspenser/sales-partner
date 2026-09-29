# Sales Partner

A sales partner for one business. It interviews you to learn your
business and your ideal customer, then runs a five-stage lead pipeline —
prospect, research, approach, sales call, follow-up — over your CRM. It
researches on its own but never contacts anyone: every outbound
message, email, LinkedIn note, or call opener is a draft you approve.

Built on the [Agent Standard](https://github.com/webspenser/agent-builder/blob/main/STANDARD.md)
with [Agent Builder](https://github.com/webspenser/agent-builder).
Version 2.0.0.

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
2. Clone it, run `./install.sh`, and add `instance.yaml` at the root
   with `mode: source`.
3. Ask the agent to run its interview (the `interview-business` skill).

## Tools it needs

- A CRM — Attio or Airtable (`capabilities/crm/adapters/`); setup binds it after a read-only check.
- Apify for scraping and web search; Gmail for drafts.

Each tool's guard policy makes Attio, Airtable, and Gmail unattended-safe.

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
