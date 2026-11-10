![Webspenser Sales Partner — lead generation and personalization over your CRM; never sends](assets/banner.png)

# Sales Partner

**Fresh, researched leads every week, each matched to the offer most
likely to land, with sourced talking points ready for you to approve.**

Most small businesses know they should be doing outreach. Few have the
hours to find the right businesses, look into each one, and work out
what to say. Sales Partner does that groundwork for you: it finds
businesses that fit your ideal customer, checks them against your own
criteria, researches the promising ones, picks the one offer from your
own catalog that suits each, and writes talking points your own
sequences and calls can use. You stay in charge of who gets contacted
and when.

## What you get each week

- **New leads that fit.** Businesses that match your ideal customer,
  found from map listings, websites and web search, each given a fit
  score against your own criteria with the reasons written down.
- **Real research on the best ones.** What's changing at each business
  (new hires, a new location, a missing website, recent news), who the
  decision-maker is, and how to reach them. Every fact links to where
  it was found. A second score, from that research, is recorded for
  you to read; it doesn't trigger anything.
- **Evidence from reviews, ads, jobs and the website.** It reads a
  business's recent Google reviews (quoting a snippet with its date,
  link and the reviewer's first name, never their profile or photo), checks whether it runs Google or
  Facebook ads, looks for open jobs on Indeed, and reads its website,
  guided by the research tips you gave for each offer. Each source is
  capped, and a lead's Apify spend stops at $0.50 by default. A lead
  that hit the cap carries a **Research Capped** flag and says which
  sources it skipped, so you can decide whether to continue.
- **The offer most likely to land.** Each lead gets a Segment, an
  Industry, and a Hero Offer from your offer catalog, with an Offer
  Reason and an Offer Evidence rating (strong, moderate or weak) that
  say how well the research backs the pick. When your rules rule out
  every offer, the Hero Offer stays empty and says why.
- **Talking points to work from.** For each researched lead it writes a
  `Sales Partner · Talking Points` note on the company in your CRM: who
  it is for, the offer, an opener, sourced points, what to avoid, and
  the ways to reach them. Your own sequences, automations or calls use
  them. Each run adds a dated section and never rewrites an earlier one.
- **Social profiles for the people it finds.** Confident matches are
  filled on the person record; possible matches go in a note on the
  person. LinkedIn is searched by name. Instagram, Facebook and TikTok
  come from the business's own pages, and from Exa when it is
  connected. Nothing is ever followed or messaged.
- **A point of contact on each new lead.** The most senior person it
  found with an email address is set on the lead, with the reason, and
  the talking points are written for them. Your email workflow (for
  example n8n) reads it. Set or change it by hand and it is never
  overwritten.
- **A weekly summary** sent to you: what's waiting for your
  review, what's approved but not yet contacted, what moved, and what
  research tools cost.

## How it works

1. **A short interview.** It learns your business, your ideal customer,
   the offers you sell and the signals that point to each one, the
   results you can point to, and how you like to sound.
2. **It works on a schedule.** Each week it finds, scores and researches
   new leads, matches each to an offer and writes its talking points,
   all inside your CRM. It stops at **Researched**.
3. **You review.** Read the research, the offer and the talking points,
   and drag the leads you like to **Approved**. If a lead below the
   research bar deserves a look, tick **Research Anyway** and it is
   researched on the next run.
4. **Your process takes over.** From there, your own CRM automations,
   sequences, email tool, or you yourself make contact. Sales Partner's
   job is done, and it never touches a lead at Approved or later.

## Why you can trust it

- **It never sends anything to a prospect.** It has no ability to email,
  message or post to them on your behalf. Nothing goes further than
  Researched until you approve it, and contact stays with you and the
  tools you already use.
  It messages only you, through Resend, from a no-reply address on
  your domain.
- **You can see everything it did.** Every run writes a record to an Airtable base you own. The agent can add to that record but never change or delete it.
- **It never makes things up.** Facts about a prospect come with a source
  link or are marked unverified. Claims about your business come only
  from what you told it.
- **It respects "no."** A business marked Do Not Contact is never
  prepared again, and the agent can't remove that mark.
- **It's safe to leave running.** Every system it uses has written rules
  it cannot break, checked on every action rather than just promised in
  its instructions. If a rule can't be checked, it won't run on a
  schedule.
- **LinkedIn stays human on every platform.** Talking points are text
  for you to use. The agent never follows, connects with or messages
  anyone on LinkedIn, Instagram, Facebook, TikTok or anywhere else.
- **Your data stays yours.** Leads live in your CRM, your business notes
  live in your own private folder, and passwords and keys never go into
  the agent.

## What you need

- A CRM: **Attio** or **HubSpot** (or bring your own).
- **Resend**, your own account, for the digest and alerts the agent
  sends you (the free plan is enough), with a sending domain you verify.
- **Airtable**, your own account, for the agent's record of every run. Production needs the Team plan; Free (1,000 records) is fine for a trial.
- **Claude Code** on a paid Claude plan, which runs the agent and its
  weekly schedule.
- **Apify**, your own account, with a monthly usage limit you set in
  Apify Console, for local-business listings, website contact details,
  reviews, ads, jobs, website reading and social profiles.

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

Built on [Agent Standard](https://github.com/webspenser/agent-builder/blob/main/STANDARD.md) 7.5
with [Agent Builder](https://github.com/webspenser/agent-builder).
Version 8.7.0.

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

- A CRM — Attio or HubSpot (`capabilities/crm/tools/`); setup binds it after a read-only check. If a CRM needs fields the probe does not find, setup offers two choices: create them yourself from the tool's `## Setup` steps, or run its `bootstrap.py` with an API key in your own terminal.
- Resend for owner notifications, on the client's own account (`capabilities/owner_notify/tools/resend/`); setup pins your address and a no-reply sender, and the guard refuses a send to anyone else.
- Airtable for the ledger (`capabilities/ledger/tools/airtable/`); `bootstrap.py` creates the base, and the guard keeps the record append-only.
- Apify for scraping (`capabilities/scraping/tools/apify/`): setup connects the restricted connector URL and pins the limits (results per search, pages per site, and so on) the guard enforces.
  The guard also requires the fixed settings, such as reviews with
  reviewer names and LinkedIn email search (your choice in 8.6.0), and checks every start URL: Facebook pages only on
  facebook.com, and only an https site root on a public host for the
  contact scraper and the site reader. One limit remains: the guard
  can't tie a website to a lead, so data could still leave in the
  hostname itself (a made-up subdomain).
  More actors find and read social profiles (LinkedIn by name, a
  LinkedIn company search and profile reader, Instagram and TikTok).
  Web search and page fetch read only https pages on public hosts with
  no query string; data could still ride in a page's path, the same
  class of limit as the hostname. They run with no login: the agent never signs
  in to any platform. Facebook personal profiles have no reader, so they
  come only from the business's own pages and from Exa. The guard limits
  which arguments go to the profile actors and how many, but it can't
  check what a name or handle contains, so data could in principle ride
  in one.

- Optional: Exa for web search (`capabilities/web_search/tools/exa/`), through Exa's hosted connector on your own Exa account. When it is connected, research runs one Exa search per lead to find its owner or principal; without it, research runs as before. The guard lets only Exa's basic search run, at its default 10 results.

Each tool's guard policy makes Attio, HubSpot, Resend, Airtable, Apify and Exa unattended-safe.

Connect these in your host (connectors or MCP servers). Credentials
never go in this repo.

Scheduled runs: after setup, run `/sales-partner:schedule`.

Upgrading from 7.0: re-run setup's tools step to bind the ledger, commit
and push `bindings/ledger.md`, then re-run `/sales-partner:schedule`.
Until then, scheduled activities stop with an error notification.

Upgrading from 7.1: re-run setup's tools step to bind scraping, commit and push `bindings/scraping.md`, then re-run `/sales-partner:schedule`.

Upgrading from 7.2: the single Score is now two scores. The Fit score
comes from the map listing and decides which leads get researched
(`research_threshold`); the Approach score comes from research (since
8.0 it is recorded for you to read and gates nothing).

1. Rewrite the Scoring rubric in your `context/icp.md` as the two tables
   the shipped `context/icp.md` shows (Fit score, Approach score), or
   re-run the interview, and check `research_threshold` in
   `context/operating-config.md` against the new Fit rubric.
2. Re-run setup's tools step. The CRM probe now needs four fields (Fit
   Score, Fit Breakdown, Approach Score, Approach Breakdown); create
   them from the tool's `## Setup` steps or re-run its `bootstrap.py`.
3. Score the leads already in flight once, in an interactive session:
   ask the agent to score every `Scored` lead with the Fit rubric (it
   re-reads each lead's listing with `find_businesses`, which counts
   toward the Apify spend cap) and every `Researched` lead with the
   Approach rubric (from its Research rows, adding the newest review
   date where it is missing). Until then, no gate picks those leads up.
4. The old Score and Score Breakdown fields are no longer read or
   written. They stay in your CRM as history. In Attio you can archive
   them (archived attributes keep their values). In HubSpot, archived
   properties are deleted for good after 90 days, so export the values
   first or leave the properties in place.
5. Commit and push the instance.

Upgrading from 7.3: research and drafts move into notes on the company,
and every channel a lead can be reached on gets a full draft.

- **Attio.** Only the `Sales Partner Pipeline` list is used. Re-run
  setup's tools step (the probe now checks only that list). Then,
  before the next scheduled run, ask the agent in an interactive
  session to move research and drafts into notes: for each company, a
  `Sales Partner · Research` note with one section per original date,
  and a `Sales Partner · Email`, `· LinkedIn` or `· Call` note from the
  newest draft per channel. A pipeline phone or email that belongs to a
  linked person goes onto that person; otherwise it is recorded as a `listing` finding in the research note, with its source,
  so a lead whose only route was that phone keeps it. Then archive the `Sales Partner
  Research` and `Sales Partner Outreach` lists and the pipeline's
  `Phone`, `Email`, `Address` and `Location` attributes (archived data
  stays recoverable).
- **HubSpot.** New research and drafts are Notes on the company;
  existing draft Tasks stay as history.
- Commit and push the instance.

Upgrading from 7.4: Sales Partner no longer drafts first touches. It
stops at `Researched`, matching each lead to an offer from your catalog
and writing talking points. In order:

1. Update the plugin. Re-run the interview's offer catalog round and
   Round 2 (the customer and both rubrics), or the whole interview, to
   create `context/offer-catalog.md` and bring `context/icp.md` in line
   with it; the catalog round alone leaves `icp.md` as it was. Then
   check the instance's `icp.md` against the package's: Firmographics
   keeps no industry list, Industry fit scores against the catalog's
   `industries`, and Thresholds names only `research_threshold` (drop
   the `approach_threshold` bullet). Delete `approach_threshold`,
   `enabled_channels`, `sending_identity` and `callback_phone` from the
   instance's `context/operating-config.md`; nothing reads them now.
2. Re-run setup's tools step, so the bootstrap adds the new fields
   (Segment, Hero Offer, Offer Reason, Offer Evidence, Research Anyway),
   the catalog options and the `Approved` stage.
3. In the CRM, move leads at `Ready to Send` to `Approved`, and leads at
   `Approach Drafted` back to `Researched`. Then archive those two old
   stages.
4. Remove `schedule_approach` from `schedules.yaml`, then re-run
   `/sales-partner:schedule`. Until then, the schedule check refuses the
   stale entry.
5. For leads already at `Researched` with no Hero Offer, ask Sales
   Partner in an interactive session to match offers for them. That
   runs the re-match path, which first fills each lead's empty Segment
   from its Industry, or from its research. Old Email, LinkedIn and Call
   draft notes are left in place.

Upgrading from 8.0: Sales Partner now also reads reviews, ads, jobs and
the website, and caps each lead's Apify spend. In order:

1. Optional: re-run the interview's offer catalog round to add research
   tips to each offer (the signals that tell the research where to look).
2. Replace the Apify connector's URL and re-run setup's tools step. The
   connector's restricted URL must now list all seven actors, so replace
   it with:

   `https://mcp.apify.com?tools=compass/crawler-google-places,vdrmota/contact-info-scraper,compass/Google-Maps-Reviews-Scraper,scrapesage/google-ads-transparency-scraper,apify/facebook-ads-scraper,valig/indeed-jobs-scraper,apify/website-content-crawler`

   The connector may now appear as "Apify Actors", with its tools
   prefixed `mcp__claude_ai_Apify_Actors__`; the guard still matches it.
   Then re-run setup's tools step. It adds the `research_capped` field
   (Research Capped), asks for the twelve new scraping bindings and
   pushes `bindings/scraping.md`.
3. Update `context/operating-config.md`: add `apify_reviews`,
   `apify_ads`, `apify_jobs` and `apify_site_reader` to
   `prospecting_sources`, add `apify_cap_usd_per_lead: 0.50`, and set
   `research_budget_per_lead_minutes: 15`.
4. Re-run `/sales-partner:schedule`.

Your scheduled routines install the latest plugin, so they run this
release before you finish. Research goes on: a missing
`apify_cap_usd_per_lead` uses `0.50`. Until the tools step pushes the
new bindings, the new sources are skipped and you get an error
notification naming the missing bindings. Re-run
`/sales-partner:schedule` afterwards (step 4): it checks the new
bindings.

Upgrading from 8.1: decision-maker research can now use Exa, and every
name it records is graded by its source (a directory-only name is never
verified). Exa is optional. In order:

1. Without Exa: change the cloud environment's version comment to
   `# sales-partner 8.2.0` and set `agent_version: 8.2.0` in
   `schedules.yaml`, then commit and push. Nothing else changes.
   (8.2.1: use `8.2.1` in both places. 8.2.0's guard refused the
   `objective` argument Exa's connector requires, which stopped prepare
   at its first Exa search.)
2. With Exa: first add Exa's connector at claude.ai (the tool's
   `## Setup`), re-run setup's tools step and answer yes for web search,
   then re-run `/sales-partner:schedule`, attach the `ExaSearch` connector to
   the routine that runs prepare, and do step 1.

Upgrading from 8.2: Sales Partner now finds social profiles for the
people it researches. Exa is optional; with Exa bound, Instagram,
Facebook and TikTok get more candidates. In order:

1. Replace the Apify connector's restricted URL with the ten-actor URL.
   Copy it exactly:

   `https://mcp.apify.com?tools=compass/crawler-google-places,vdrmota/contact-info-scraper,compass/Google-Maps-Reviews-Scraper,scrapesage/google-ads-transparency-scraper,apify/facebook-ads-scraper,valig/indeed-jobs-scraper,apify/website-content-crawler,harvestapi/linkedin-profile-search-by-name,apify/instagram-profile-scraper,clockworks/tiktok-profile-scraper`

2. Re-run setup's tools step. It creates the new CRM fields (with
   `bootstrap.py` or by hand) and pins the three new scraping bindings
   `max_profile_results` (5), `max_profile_reads` (10) and
   `max_profile_locations` (1). Then commit and push
   `bindings/scraping.md`. Until the new keys are pushed, scheduled
   runs stop.
3. Add `apify_profiles` to `prospecting_sources` in
   `context/operating-config.md`.
4. Re-run `/sales-partner:schedule`.

Upgrading from 8.3: each new lead now gets a point of contact on the
pipeline list. In order:

1. Re-run setup's tools step. It creates the three new lead fields
   `point_of_contact`, `point_of_contact_pick` (the agent's own last
   pick; leave it alone) and `point_of_contact_reason`, with
   `bootstrap.py` or by hand.
2. Point your email workflow (for example n8n) at `point_of_contact`:
   in Attio it links to the Person, whose name and email you read.
3. Existing leads are not backfilled. Set theirs by hand.

Upgrading from 8.4: the digest now arrives as a formatted email, with
the plain text still inside it, and no longer has a Next actions
section. Add `business_name: "<your business>"` to
`context/operating-config.md` so the title reads
`Weekly Digest for <your business>`. Nothing else changes: Resend sends
the HTML through the same pinned sender and recipients.

Upgrading from 8.5.0: the reviews source now runs on
`web_wanderer/google-reviews-scraper`. Apify moved the old Compass
reviews tool to an HTTP server interface the connector could not call,
so every prepare run stopped at its first review call. Your
`prospecting_sources` and `bindings/scraping.md` stay as they are.

1. Replace the Apify connector's URL with:

   `https://mcp.apify.com?tools=compass/crawler-google-places,vdrmota/contact-info-scraper,web_wanderer/google-reviews-scraper,scrapesage/google-ads-transparency-scraper,apify/facebook-ads-scraper,valig/indeed-jobs-scraper,apify/website-content-crawler,harvestapi/linkedin-profile-search-by-name,apify/instagram-profile-scraper,clockworks/tiktok-profile-scraper`

   Other named actors and the `docs` and `runs` tools may stay on the
   connector: the guard refuses any tool it does not allow. Leave off
   the `actors` and `api` tool groups. The connector's name must contain "apify"
   (for example "Apify Actors" or "Apify Connector"), because the guard
   finds the server by that word.
2. Start a new session so the agent loads the new tool.

Upgrading from 8.6.0: 8.7.0 adds nine Apify tools under the same
guard: web search and page fetch (`apify_web`: press, news and pages
from a lead's own site and search results, paths only), BBB
(`apify_bbb`: rating, complaints, years, owners), YellowPages
(`apify_yellowpages`: a listing for research, and leads by trade and
city for the Prospector), Yelp reviews (`apify_yelp`), LinkedIn jobs
(part of `apify_jobs`), a LinkedIn company search and profile reader
(part of `apify_profiles`: the owner of a business that names no one,
and their email) and a Facebook Ad Library backup (part of `apify_ads`,
used only when the primary Facebook call fails).

1. Replace the Apify connector's URL with:

   `https://mcp.apify.com?tools=compass/crawler-google-places,vdrmota/contact-info-scraper,web_wanderer/google-reviews-scraper,scrapesage/google-ads-transparency-scraper,apify/facebook-ads-scraper,valig/indeed-jobs-scraper,apify/website-content-crawler,harvestapi/linkedin-profile-search-by-name,apify/instagram-profile-scraper,clockworks/tiktok-profile-scraper,apify/web-search,apify/web-fetch,scrapesage/bbb-scraper,delicious_zebu/yellowpages-usa-business-lead-scraper,web_wanderer/yelp-reviews-scraper,valig/linkedin-jobs-scraper,harvestapi/linkedin-profile-search,harvestapi/linkedin-profile-scraper,scrapesage/facebook-ad-library-scraper`
2. Run setup's tools step to add `max_web_results` (default 10),
   `max_bbb_results` (default 5) and `max_web_fetches` (default 5) to
   `bindings/scraping.md`, then commit and push it. Do this before the next scheduled run: the scheduled-run gate refuses to
   start while a value the guard pins is missing.
3. Add `apify_web`, `apify_bbb`, `apify_yellowpages` and `apify_yelp` to
   `prospecting_sources` in `context/operating-config.md` if you want
   them; a source left out never runs.
4. Start a new session so the agent loads the new guard.

Upgrading from 8.5.1: the Apify guard now follows the retrieval profile
(Agent Standard 7.5). It names the actors it allows, caps every result
and page count, refuses code, headers, cookies, proxies and each actor's
paid add-ons, and lets any other new vendor input pass, so a small
vendor change no longer blocks every call. Three behaviors change:

- A scraping source that fails (an empty field, a vendor error or a
  guard block) is skipped for that lead and research goes on; the run
  report says what happened. A source blocked on 2 leads is skipped for
  the rest of the run, and a source that fails on every lead sends one
  error notification at the end.
- Review findings and talking points can name a reviewer by first name
  and date. Profile links, photos and IDs are never kept.
- The LinkedIn search runs in `Full + email search` mode, and an email it
  finds for an owner, a Gmail address included, can become the point of
  contact. Its cost estimate is $0.15 per search; check the real charge
  in Apify Console after the first runs.

Your connector URL, `prospecting_sources` and `bindings/scraping.md`
stay as they are. Confirm that the Apify monthly usage limit is set in
Apify Console: it is the hard stop on spend. Start a new session so the
agent loads the new guard.

## Developing

    tests/run-all.sh                                   # content checks
    /path/to/agent-builder/bin/validate-agent.sh .     # structure

CI runs on pushes to `main` and on every pull request. Content tests and
the release rule run only in webspenser/sales-partner — in your own
copy, CI checks structure only, so committing your filled-in `context/`
is fine.

## License

Apache-2.0.
