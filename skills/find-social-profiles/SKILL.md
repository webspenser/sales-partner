---
name: find-social-profiles
description: Use when a contact is identified and their social profiles are still missing — finds the person's LinkedIn, Instagram, Facebook, TikTok and X profiles, writes the confident ones into the contact, and lists the uncertain ones as possible profiles for the operator.
---

This skill reads public profiles and records what it finds. It will
never follow, connect, like, comment, post or message on any platform:
following and messaging are the operator's. Reading a public profile,
including through an actor, is allowed; acting on one is not. The
requirement behind every step is that no wrong person ends up in a
confident field. A missing profile costs the operator a search; a wrong
one costs them a message to a stranger.

## Input

- **The lead:** its `lead_id`, name, website, city, and the social links
  research and `find_contacts` already found.
- **The contact:** its `contact_id`, name, title, and any social field
  already filled.

## Output

- Confident profiles written into the contact's own fields with
  `upsert_contact`, each **only when the CRM field is empty**; a filled
  field is never overwritten.
- Every other candidate listed in one dated section of the person's note
  `Sales Partner · Possible Profiles`, through `log_possible_profiles`.
- `profiles_checked_at` written to today's date when the search
  completes. When a cap or the time budget ends the search first, the
  skill returns `stopped`, writes no `profiles_checked_at`, and the
  contact is searched again on a later run.

The Preparer's cap and time-budget rules for Apify spend apply to every
`find_profiles` and `read_profile` call. This skill does not set them.

## Procedure

1. **Anchor first.** Start from what is already confirmed, before any
   search: the business's website, its own social pages, the contact's
   LinkedIn if known, and the `find_contacts` social links. A link on a
   shared-platform host (`subagents/preparer.md`, "Shared platform") is
   never the business's website; it is a profile page, read as one.
   Use `read_profile` on a
   business social page to find people it tags or links to, and on a
   known profile to find the business it links to. A link between the
   business and the person, in either direction, is an anchor.
   A business TikTok or X page found this way goes into the company
   profile fields with `update_lead(lead_id, {"tiktok_url": …, "x_url":
   …})`, only when the lead's field is empty (Attio only; on HubSpot
   these two company fields do not exist, so skip this).
2. **Search.** For each platform the contact still has no profile on,
   in platform order (LinkedIn, Instagram, Facebook, TikTok, X), call
   `find_profiles(name, business, city, platforms)` with the contact's
   name, the business name, the lead's city and the platforms still
   missing. Facebook personal profiles cannot be searched without a login,
   so expect one only when an anchor links to it. A platform an anchor
   already filled is not searched.
3. **Score** each candidate and record its reasons as plain text, one
   short phrase each:
   - a business link: the profile links to the business's website or
     page, or the business's page links to the profile (strongest);
   - the employer or business name in the bio or job title (for LinkedIn,
     the `current_employer` read from the profile);
   - the location matches the lead's city or region;
   - the name matches, including a known nickname or surname.
   A candidate is **confident** when it has at least one business link
   from step 1, or a LinkedIn `current_employer` match read from the
   profile, and no contradicting signal (a different city and a different
   employer, a different name, a personal account for an unrelated
   person). Name or location alone is never confident, however well it
   fits. When two candidates on one platform both qualify, both are uncertain:
   neither goes into a field, and both are listed.
4. **Write.** Confident matches go into the contact's fields with one
   `upsert_contact(lead_id, name, …, linkedin_url, instagram_url,
   facebook_url, tiktok_url, x_url)` call, passing the URL for each
   platform found and nothing for the rest. Each is written only when
   the CRM field is empty. Everything else, including every candidate
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
5. **Finish.** Write `profiles_checked_at` (today's date) through
   `upsert_contact` once the search is complete, even when nothing was
   found: the contact has been searched. If a cap or the time budget
   ended the search before it completed, return `stopped` and write
   nothing for `profiles_checked_at`; keep any confident field and
   possible-profiles section already written.

## Failure modes

- `find_profiles` or `read_profile` fails: retry once. If it fails
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
  confident, apart from a LinkedIn `current_employer` match.
- The profile appears to belong to an unrelated person with the same
  name: it contradicts, so it is not listed at all.

## Worked example

Fictional lead **Brightwater Accounting** in Springfield
(`https://brightwater.example`). Contact **Priya Nandakumar**, Owner. No
social field is filled.

1. Anchors: the site footer links the business Instagram
   `https://instagram.example/brightwateracct`. `read_profile` on it
   shows the bio "Run by @priya.n" and a link to
   `https://instagram.example/priya.n`. That is a business link for
   Priya's Instagram. The footer has no TikTok or X page.
2. Search: LinkedIn, Facebook, TikTok and X are still missing.
   `find_profiles("Priya Nandakumar", "Brightwater Accounting",
   "Springfield", [linkedin, facebook, tiktok, x])` returns:
   - LinkedIn `https://linkedin.example/in/priya-nandakumar`, current
     employer Brightwater Accounting, Springfield;
   - LinkedIn `https://linkedin.example/in/priya-n-9`, Priya N, in
     another city, employer a retailer;
   - TikTok `https://tiktok.example/@priyan`, bio "mum, runner,
     Springfield".
3. Score: Instagram `priya.n`: business link both ways, so confident.
   LinkedIn `priya-nandakumar`: current employer matches, location
   matches, no contradiction, so confident. LinkedIn `priya-n-9`:
   contradicts, so not listed. TikTok `@priyan`: location and a name
   resemblance only, so uncertain.
4. Write: `upsert_contact` gets `linkedin_url` and `instagram_url`, both
   fields empty. `log_possible_profiles` gets:

   ```
   === 2026-11-03 · possible profiles ===
   tiktok: https://tiktok.example/@priyan — location matches Springfield, name resembles Priya N, no business link [https://tiktok.example/search?q=priya+nandakumar]
   ```
5. Finish: `profiles_checked_at` is written as 2026-11-03.
