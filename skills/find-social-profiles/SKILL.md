---
name: find-social-profiles
description: Use when a contact is identified and their social profiles are still missing — finds the person's LinkedIn, Instagram, Facebook, TikTok profiles (and X when a source returns it), writes the confident ones into the contact, and lists the uncertain ones as possible profiles for the operator.
---

This skill reads public profiles and records what it finds. It will
never follow, connect, like, comment, post or message on any platform:
following and messaging are the operator's. Reading a public profile,
including through an actor, is allowed; acting on one is not. The
requirement behind every step is that no wrong person ends up in a
confident field. A missing profile costs the operator a search; a wrong
one costs them a message to a stranger.

## Input

- **The lead:** its `lead_id`, name, website, city, region,
  `company_linkedin_url`, and the social links research and
  `find_contacts` already found.
- **The contact:** its `contact_id`, name, title, email, role, and any
  social field already filled.

## Output

- Confident profiles written into the contact's own fields with
  `upsert_contact`, each **only when the CRM field is empty**; a filled
  field is never overwritten.
- Every other candidate listed in one dated section of the person's note
  `Sales Partner · Possible Profiles`, through `log_possible_profiles`.
- `profiles_checked_at` written (now, ISO 8601 UTC) when the search
  completes. When a cap or the time budget ends the search first, the
  skill returns `stopped`, writes no `profiles_checked_at`, and the
  contact is searched again on a later run. When the lead has reached
  `Approved` or later before the writes, it returns `approved` and
  writes nothing (step 4).

The Preparer's cap and time-budget rules for Apify spend apply to every
`find_profiles` and `read_profile` call. This skill does not set them.

## Procedure

1. **Anchor first.** Start from what is already confirmed, before any
   search: the business's website, its own social pages, the contact's
   LinkedIn if known, and the `find_contacts` social links. A link on a
   shared-platform host (`subagents/preparer.md`, "Shared platform") is
   never the business's website; it is the business's own page on that
   platform, an anchor like its other social pages.
   A LinkedIn profile URL already known for the contact (an anchor) is read with `read_profile`
   (LinkedIn, email-search mode) instead of searching, for its employer
   and emails; a candidate a by-name `find_profiles` search (`Full + email search`) returned is not read again; a company-search
   candidate (Short mode, no email) is read.
   Use `read_profile` (Instagram and TikTok) on a
   business social page to find people it tags or links to, and on a
   known profile to find the business it links to. A link between the
   business and the person, in either direction, is an anchor.
   A business TikTok or X page found this way goes into the company
   profile fields with `update_lead(lead_id, {"tiktok_url": …, "x_url":
   …})`, only when the lead's field is empty (Attio only; on HubSpot
   these two company fields do not exist, so skip this).
2. **Search.** For each platform the contact still has no profile on,
   in platform order (LinkedIn, Instagram, Facebook, TikTok):
   - LinkedIn: call `find_profiles(name, business, city, [linkedin])`
     with the contact's name, the business name and the lead's city.
     `find_profiles` is called for LinkedIn only.
   - Instagram, Facebook and TikTok: when `web_search` is bound
     (`capabilities/web_search/contract.md`), make one `search_web` call
     per contact for the platforms still missing, with the contact's
     name, the business name and the city. When it is not bound, skip
     this silently.

   Facebook personal profiles cannot be searched without a login,
   so expect one only when an anchor links to it. A platform an anchor
   already filled is not searched. We never search for X: `x_url` is
   filled only from an X link already returned by an anchor or another
   source.
3. **Score** each candidate and record its reasons as plain text, one
   short phrase each:
   - a business link: the profile links to the business's own website or
     page, or the business's page links to the profile (strongest). A
     link to a shared-platform website (the list in `subagents/preparer.md`,
     "Shared platform") is never a business link. A business page is
     never a person's profile: a business link counts only when it points
     to a person's profile whose name fits the contact. Use `read_profile`
     on an Instagram or TikTok candidate when needed, to check its links
     (a LinkedIn candidate's current employer comes with `find_profiles`);
   - the employer or business name in the bio or job title (for LinkedIn,
     the `current_employer` returned by `find_profiles`);
   - the location matches the lead's city or region;
   - the name matches, including a known nickname or surname.

   A LinkedIn employer match counts only when the employer is this
   business: the current `experience[]` entry's `companyLinkedinUrl`
   equals the lead's `company_linkedin_url`, or the profile's location
   matches the lead's city or region. A same-named business elsewhere is
   not this business.

   Contradicting signals: a different name; a current employer that is
   not this business; a personal account for an unrelated person. A
   different city or region from the lead's is a contradicting signal for
   every candidate, including a LinkedIn employer match: that candidate
   is uncertain unless it also has a direct business link (it links to,
   or is linked from, the business's own site or pages).

   A candidate is **confident** when it has at least one business link
   found in step 1 or step 2, or a LinkedIn `current_employer` match that
   counts, and no contradicting signal (a different city is overridden
   only by a direct business link, as above).
   Name or location alone is never confident, however well it fits.
   When two candidates on one platform both qualify, both are uncertain:
   neither goes into a field, and both are listed. A candidate with a different name, or with both a
   different city and a different employer, is an unrelated person and
   is not listed at all.
4. **Write.** Re-read the lead with `get_lead` before the first write
   for this contact (here, before step 5's when step 4 writes nothing).
   At `Approved` or later the operator has taken the lead over: write
   nothing for this contact, no field, note or `profiles_checked_at`, and
   return `approved`; the Preparer stops the lead there. Confident
   matches go into the contact's fields with one
   `upsert_contact(lead_id, name, …, linkedin_url, instagram_url,
   facebook_url, tiktok_url, x_url)` call, passing the URL for each
   platform found and nothing for the rest. Each is written only when
   the CRM field is empty. An email `find_profiles` found for a confident candidate goes in `email` only when the field is empty
   (LinkedIn email search; a free-mail address included, with `notes`
   saying `email from LinkedIn email search`), and an uncertain candidate's email goes only in the possible-profiles section, so a
   stranger's address never becomes a route to the lead. Otherwise every
   `upsert_contact` call here passes the contact's current name, title,
   email and role unchanged, so it matches the same person; the Preparer never sends a contact with no
   role to this skill. Everything else, including every candidate
   from a tie and any confident match for a field already filled with a
   different URL, goes into one `log_possible_profiles(lead_id,
   contact_id, body)` call. The body is one dated section, in this
   exact format:

   ```
   === YYYY-MM-DD · possible profiles ===
   <platform>: <URL> — <reasons> [<source URL>]
   ```

   with one line per candidate, the source URL being the page the
   candidate was found on. When there is no candidate to list, write no
   section.
5. **Finish.** Write `profiles_checked_at` (now, ISO 8601 UTC) through
   `upsert_contact` once the search is complete, even when nothing was
   found: the contact has been searched. If a cap or the time budget
   ended the search before it completed, return `stopped` and write
   nothing for `profiles_checked_at`; keep any confident field and
   possible-profiles section already written.

## Failure modes

- `find_profiles` or `read_profile` fails: retry once. A guard block is never retried: it counts as a failed second try. If it fails
  again, treat that platform as not searched, say so in the report, and
  return `stopped` rather than marking the contact checked.
- A candidate's profile is private or empty: it has no bio or links to
  score, so it can only be listed as possible, with the reason `private
  profile, name match only`.
- The contact has only a first name or an initial: Name or location alone
  is never confident, so nothing is written to a field; list candidates
  only if a business link supports them.
- A CRM field already holds a different URL: leave it; list the new
  candidate as possible.
- The lead has no website and no known social pages: there is nothing to
  anchor on; search, and expect everything to be possible rather than
  confident, apart from a LinkedIn `current_employer` match that counts.
- The profile appears to belong to an unrelated person with the same
  name: it contradicts, so it is not listed at all.

## Worked example

Fictional lead **Brightwater Accounting** in Springfield
(`https://brightwater.example`). Contact **Priya Nandakumar**, Owner. No
social field is filled.

1. Anchors: the site footer links the business Instagram
   `https://www.instagram.com/example.brightwater`. `read_profile` on it
   shows the bio "Run by @example.priya.n" and a link to
   `https://www.instagram.com/example.priya.n`. That is a business link for
   Priya's Instagram. The footer has no TikTok or X page, so no company field is set.
2. Search: LinkedIn, Facebook and TikTok are still missing.
   `find_profiles("Priya Nandakumar", "Brightwater Accounting",
   "Springfield", [linkedin])` returns:
   - LinkedIn `https://www.linkedin.com/in/example-priya-nandakumar`,
     current employer Brightwater Accounting, Springfield;
   - LinkedIn `https://www.linkedin.com/in/example-priya-n-9`, Priya N,
     in another city, employer a retailer.

   One `search_web` call for Facebook and TikTok returns the TikTok
   profile `https://www.tiktok.com/@example.priyan` as a result;
   `read_profile` on it shows the bio "mum, runner, Springfield".
3. Score: Instagram `example.priya.n`: the business page links to it,
   so confident. LinkedIn `example-priya-nandakumar`: current employer
   is this business (its location matches Springfield), no
   contradiction, so confident. LinkedIn `example-priya-n-9`: a
   different city and a different employer, so not listed. TikTok
   `@example.priyan`: location and a name resemblance only, so
   uncertain.
4. Write: `get_lead` shows the lead still at `Researched`.
   `upsert_contact` gets `linkedin_url` and `instagram_url`, both
   fields empty. `log_possible_profiles` gets:

   ```
   === 2026-11-03 · possible profiles ===
   tiktok: https://www.tiktok.com/@example.priyan — location matches Springfield, name resembles Priya N, no business link [https://www.tiktok.com/@example.priyan]
   ```
5. Finish: `profiles_checked_at` is written as now, for example
   `2026-11-03T07:42:00Z`.
