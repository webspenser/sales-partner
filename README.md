![Webspenser Sales Partner — lead generation and personalization over your CRM; never sends](assets/banner.png)

# Sales Partner

**Fresh, researched leads every week, each with its first touch ready
for you to approve.**

Most small businesses know they should be doing outreach. Few have the
hours to find the right businesses, look into each one, and write
something worth reading. Sales Partner does that groundwork for you:
it finds businesses that fit your ideal customer, checks them against
your own criteria, researches the promising ones, and prepares a first
message that sounds like you. You stay in charge of who gets contacted
and when.

## What you get each week

- **New leads that fit.** Businesses that match your ideal customer,
  found from map listings, websites and web search, each scored against
  your own criteria with the reasons written down.
- **Real research on the best ones.** What's changing at each business
  (new hires, a new location, a missing website, recent news), who the
  decision-maker is, and how to reach them. Every fact links to where
  it was found.
- **A first touch, ready to go.** For each lead it recommends the best
  channel (email, LinkedIn or a phone call) and says why, writes that
  message in full, and gives you short personalized lines for your
  other channels: an opener, why it matters to them, a proof point
  from your own results, and one simple ask.
- **A weekly summary** in your Gmail drafts: what's waiting for your
  review, what's approved, what moved, and what research tools cost.

## How it works

1. **A short interview.** It learns your business, your ideal customer,
   the results you can point to, and how you like to sound.
2. **It works on a schedule.** Each week it finds, scores and researches
   new leads and prepares their first touch, all inside your CRM.
3. **You review.** Read the drafts, edit anything, and move the leads you
   like to **Ready to Send**.
4. **Your process takes over.** From there, your own CRM automations,
   email tool, or you yourself send the message. Sales Partner's job is
   done.

## Why you can trust it

- **It never sends anything.** It has no ability to email, message or
  post on your behalf. Every message waits for your approval, and
  sending stays with you and the tools you already use.
- **It never makes things up.** Facts about a prospect come with a source
  link or are marked unverified. Claims about your business come only
  from what you told it.
- **It respects "no."** A business marked Do Not Contact is never drafted
  for again, and the agent can't remove that mark.
- **It's safe to leave running.** Every system it uses has written rules
  it cannot break, checked on every action rather than just promised in
  its instructions. If a rule can't be checked, it won't run on a
  schedule.
- **LinkedIn stays human.** LinkedIn lines are text for you to paste. It
  never automates anything on LinkedIn.
- **Your data stays yours.** Leads live in your CRM, your business notes
  live in your own private folder, and passwords and keys never go into
  the agent.

## What you need

- A CRM: **Attio**, **Airtable** or **HubSpot** (or bring your own).
- **Gmail**, for the weekly summary (it only creates drafts).
- **Claude Code** on a paid Claude plan, which runs the agent and its
  weekly schedule.
- Optional: **Apify**, for richer map and website data when you run it
  yourself, with a weekly spending cap you set. Scheduled runs use web
  search only.

**Want it set up for you?** [Webspenser](https://www.webspenser.com/lp/agent-builder) offers
a one-time, done-for-you setup: we connect your tools, run the
interview with you, and turn on the schedule. Ongoing management is
available as part of our AI managed services.

---

## Install (plugin mode)

    /plugin marketplace add webspenser/agent-library
    /plugin install sales-partner@webspenser

Then open Claude Code in an empty folder — this becomes your instance,
where your data lives — and run `/sales-partner:setup`. It writes
`instance.yaml`, runs the interview to fill `context/`, and offers to
make the folder a private git repo. From then on, opening Claude Code
in that folder loads the agent. Plugin updates never touch your folder.

Built on the [Agent Standard](https://github.com/webspenser/agent-builder/blob/main/STANDARD.md)
with [Agent Builder](https://github.com/webspenser/agent-builder).
Version 6.0.1.

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
