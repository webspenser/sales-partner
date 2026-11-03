# Social profiles for contacts — design

Date: 2026-11-03. Scope: sales-partner only. No Agent Standard change is
expected (the guard's existing `only_keys`, `fixed`, `limits` and `urls`
keys should cover the new actors); if the builder finds one is needed,
it goes to agent-builder first, as with 7.3.

## Why

The operator works leads on social media before, or instead of, email.
The steps are:

1. Add the lead's people to Attio.
2. Follow them on whatever profiles exist, both the business's accounts
   and each person's own.
3. Pick one platform, most likely LinkedIn, Facebook or Instagram, and DM
   them there.

Today Sales Partner records only a person's LinkedIn URL
(`upsert_contact.linkedin_url`). For the business it records LinkedIn,
Facebook and Instagram (`company_linkedin_url`, `facebook_url`,
`instagram_url`). The website contact scraper (`find_contacts`) already
returns social links, but the Preparer attaches them to the lead's
Contacts without tying them to a person (`subagents/preparer.md`,
Website contacts). The operator therefore searches every platform by
hand for every person, and that search is the work this feature takes
over.

## Goals

- For **every contact** the Preparer records at a lead, find that
  person's public social profiles. Platforms in the operator's order of
  preference: **LinkedIn, Instagram, Facebook, TikTok.**
  - Also record X (Twitter) when a source surfaces it without an extra
    search. This is our call, since it is cheap to keep.
  - Also record the business's own TikTok and X pages when found,
    alongside the company profile fields that already exist. This is
    also our call.
- **Confident matches** go straight into the person's social fields in
  the CRM. In Attio these are the built-in People attributes
  `linkedin`, `instagram`, `facebook` and `twitter` (confirmed on the
  live workspace on 2026-11-03), plus a new custom attribute for TikTok,
  which Attio lacks.
- **Uncertain matches** go into a note on the person record. Each one
  gets the link and the reasons it might be them, so the operator can
  pick.
- **Backfill:** leads already at `Researched` get the same profile
  search. Leads at `Approved` or later are never touched.
- HubSpot gets the same feature, because both CRM tools follow one
  contract.

## Non-goals

- **Acting on any platform.** The agent never follows, connects, likes,
  comments, posts or messages. It finds and records. Following and
  DMing are the operator's. This extends "LinkedIn stays human" (README)
  to every platform.
- **Reading is allowed.** The operator confirmed on 2026-11-03 that
  reading LinkedIn, and any search platform the agent can reach without
  logging in, is allowed, including through an Apify actor. The old
  rule was about outreach, not reading. Two places need rewording to say
  so:
  - `AGENT.md` ("Never automate anything on LinkedIn") becomes "never act
    on LinkedIn or any social platform: no follow, connect, message or
    post". The agent has no tool that could do these things anyway.
  - `skills/find-decision-makers/SKILL.md` ("viewing it as a human would
    is not") is reworded to allow reading public profiles.
- Picking the DM channel for the operator. The operator chooses.
- **No change to the talking points.** `Contact routes:` keeps phone,
  email and LinkedIn as today. The operator reads confident profiles on
  the person record (decided 2026-11-03), so the public format that n8n
  reads doesn't change.
- Copying profile content into the CRM: no posts, photos, follower
  lists or follower counts. Only the URL and the reasons for the match
  are kept.
- Searching for people the agent hasn't already found. This feature
  enriches contacts. It doesn't add new ones.

## Anti-goals (failure even if it technically works)

- **A wrong person in a social field.** A confident field that points to
  someone else is worse than an empty one, because the operator follows
  or DMs a stranger. When in doubt, a candidate goes in the note.
- **Reading anything behind a login.** That means no actor that takes
  cookies, a session or account credentials.
- **Starving the evidence.** Profile search must never use up research
  budget that reviews, ads, jobs or the website reader would have used.
- Overwriting a social field the operator, Attio's enrichment or an
  earlier run already set.

## Constraints

- **Budget.** Profile search shares the existing per-lead Apify cap,
  `apify_cap_usd_per_lead`, default $0.50, and the 7-day cap. No new
  config key. The operator will raise the cap if leads hit it more than
  once.
- **Order: evidence first, across the whole run (our call).** Profile
  search is a separate **profile pass**. It runs after every queued lead
  in the run has been prepared and moved to `Researched`. That way,
  profile spend on one lead can't push a later lead's reviews, ads,
  jobs or site read over the 7-day cap. Within the pass, each lead
  spends what is left of its own `apify_cap_usd_per_lead`, and the
  pass stops when the 7-day cap would be passed.
  - The same pass handles the backfill, because every lead it works on
    is already at `Researched` (see Backfill, below).
  - When a cap or the time budget stops the pass, the lead stays
    unsearched (no marker is written), and the next run picks it up.
    This is not the Research Capped flag, which keeps meaning "evidence
    was cut short".
  - The order and the caps are Preparer instructions, like the rest of
    the spend cap. No guard counts dollars.
- **Do Not Contact wins.** Do Not Contact is a lead flag; there is no
  per-person flag, and none is added. A lead marked Do Not Contact gets
  no profile search. The pass follows the existing contract rule: a
  `Researched` lead found with the flag set moves to `Disqualified`
  (reason `opt-out`). These are instructions, like the existing skip.
- **Approval invariant.** No profile writes and no profile note on a lead
  at `Approved` or later. This is an instruction, the same as for talking
  points (`capabilities/crm/contract.md`, Approval invariant).
- **Guarded like every scraper.** Each new actor is added to the Apify
  guard's `allow`, with an `only_keys` allowlist, pinned result limits
  from `bindings/scraping.md`, `fixed` values for any safety setting,
  and `urls` rules for any start URL. For example, a profile reader
  takes only https URLs on that platform's own hosts. The capability
  keeps all three invariants (`no_external_send`,
  `allowlisted_actors`, `pinned_inputs`).
- **Public data only, minimum kept.** URLs and match reasons only, each
  with the source page that supports it.
- **The repository is public.** Probe notes and test fixtures must not
  hold real people's names or profile URLs. Keep those outside the repo,
  as the Exa spec did (`live-agents/`).

## How it finds the right person

This part is our design, not the operator's. The operator's own
requirement is "no wrong person in a confident field".

1. **Anchor first.** Start from what research already confirmed: the
   business's website, its own social pages and the person's LinkedIn.
   Follow links outward. Examples: the business's Instagram bio tags
   "@owner"; a person's bio links to the business's website or page; a
   LinkedIn profile lists the business as the current employer.
2. **Search second.** For a person still missing profiles, search by
   name, narrowed by the lead's city and by the business name in the
   bio or job title. The candidates found so far are:
   - [Find Social Media Profiles](https://apify.com/tri_angle/find-social-media-profiles):
     takes names, covers Facebook, Instagram, LinkedIn, TikTok and more,
     about $3 per 1,000 results;
   - [HarvestAPI LinkedIn profile search by name](https://apify.com/harvestapi/linkedin-profile-search-by-name):
     filters by current company, no cookies;
   - an Instagram bio, location or keyword search such as
     [Scrape Architect's profile scraper](https://apify.com/scrapearchitect/ultimate-instagram-profile-scraper),
     plus [Apify's Instagram Profile Scraper](https://apify.com/apify/instagram-profile-scraper)
     to read a known handle;
   - the bound Exa `search_web` is also a candidate for discovery.

   None of these has been tested yet. Facebook personal profiles can't
   be searched without a login, so expect them only when an anchor
   links to one.
3. **Score each candidate** with written reasons, the way the Fit score
   records its breakdown:
   - a link to or from the business (strongest);
   - the employer or business name in the bio or job title;
   - the location matches the lead's city or region;
   - the name matches, including a known nickname or surname.
4. **Confident** means at least one business link (step 1), or a
   LinkedIn current-employer match read from the profile, plus no
   contradicting signal.
   Location or name alone is never confident. Two candidates that both
   qualify for one platform are both uncertain.

## CRM changes

- **Contract.**
  - `upsert_contact` gains `instagram_url`, `facebook_url`,
    `tiktok_url` and `x_url` beside `linkedin_url`. Each is written only
    when the CRM field is empty, the same rule as the company profile
    fields.
  - Name clash: `facebook_url` and `instagram_url` already exist as
    lead fields. The contact versions can share the name, since they
    are arguments of a different operation, or take a prefix. Builder's
    call.
  - The company profile fields gain `tiktok_url` and `x_url`.
  - In HubSpot, which skips the company profile fields in this release,
    only the person fields and the possible-profiles note are in scope.
    This is our call.
- **Possible-profiles note.** A new append-only operation writes one
  dated section to a note on the **person** record, titled, for
  example, `Sales Partner · Possible Profiles`. The note lists
  candidates per platform, each with its link, its reasons and its
  source.
  - It works like `log_talking_points`: create or append, never edit.
  - A re-run adds a dated section and never rewrites one.
  - Attio's guard already allows `create-note` and append-only
    `update-note`. Its `parent_object` must allow `people`.
  - HubSpot gets a Note associated with the Contact.
- **Attio.**
  - Map the new arguments to the built-in People attributes
    `instagram`, `facebook` and `twitter`, and to a new custom `sp_tiktok`
    text attribute.
  - `bootstrap.py` and the `## Setup` list add `sp_tiktok`.
  - Check whether Companies has built-in `twitter` and `tiktok`
    attributes before adding custom ones.
- **HubSpot.**
  - The person's LinkedIn is `hs_linkedin_url`.
  - The builder checks which built-in contact properties exist for X
    (HubSpot has `twitterhandle`), Instagram, Facebook and TikTok, and
    adds `sp_` custom properties for the rest.
  - `bootstrap.py` and the `## Setup` table are updated to match.
  - The guard's `unknown_writes: block` means new properties need
    `writes` coverage.

## The profile pass and backfill

The profile pass (Constraints, above) works on `Researched` leads whose
contacts haven't been searched yet. That covers the leads the run just
prepared and the backlog of leads already at `Researched`.

- Order within the pass: the leads prepared in this run first, then
  the backlog, oldest `Stage Changed At` first. This is our call.
- Leads stay at `Researched`. Only the profile search runs: no new
  research, no re-score, no new talking-points section.
- A lead whose contacts were all searched is not searched again. A
  contact added later, for example by a re-run of research, is searched
  then.
- It spends from the same caps and stops on them.

The marker for "already searched" is the builder's call. It could be a
ledger event, or a per-person checked-at field.

## Digest and ledger

- Each scraping call is a ledger `step` with its cost, as today.
- The digest's research cost already includes this spend.
- Optional: the digest counts profiles found per platform, so the
  operator sees the hit rate. Builder's call.

## Release checks

1. **Probe each chosen actor live**, interactively, before writing its
   guard policy:
   - its input schema;
   - which keys must be blocked (cookies, proxies, custom headers);
   - its cost per call;
   - whether it works without a login.

   Record the results in `docs/superpowers/notes/`, without real
   people's data.
2. **A test run on real leads.** Run it on 5 to 10 researched leads in
   the live instance. The operator reviews every confident field.
   - Pass: no wrong person in a confident field.
   - Also record the hit rate per platform and the extra cost per lead.
3. Confirm that no lead's evidence sources were skipped because of
   profile spend.

## Left to the builder

- Which actors to adopt, after the probe, and whether Exa does part of
  the discovery.
- How profile search is split into contract operations. For example, a
  `find_profiles(person, business, location)` and a `read_profile(url)`
  for checking a candidate.
- The exact scoring rubric and its wording, as a skill
  (`find-social-profiles`) the Preparer calls after
  `find-decision-makers`.
- How far to normalize profile URLs: lowercase hosts, strip tracking
  parameters, and cut `m.` or `www.` variants down to one form.
- The backfill marker and trigger (above).
- Version: a minor bump (8.3.0), with upgrade steps in the README:
  - re-run setup's tools step for the new actors and fields;
  - put the new actors in the Apify connector URL;
  - re-run the schedule.
- Evals: a wrong-person case, a two-candidate case, a Do Not Contact
  lead, an `Approved` lead, and a lead that hits the cap before the
  profile search.
