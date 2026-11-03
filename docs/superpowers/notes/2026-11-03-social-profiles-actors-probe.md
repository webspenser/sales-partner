# Social profile actors: live probe, 2026-11-03

This probe was run interactively with the operator's consent. Each actor was tested on the operator's own profile and on Webspenser's accounts. The raw output is kept outside this repository, in `live-agents/social-profiles-probe-2026-11/`. This note records field names, counts and run facts only, with no names or profile URLs.

## Connector

The restricted Apify connector URL listed five candidates on top of the seven existing actors. After a `/mcp` reconnect, three of them appeared as tools:

| Candidate | Exposed | Tool name |
|---|---|---|
| `harvestapi/linkedin-profile-search-by-name` | yes | `harvestapi--linkedin-profile-search-by-name` |
| `apify/instagram-profile-scraper` | yes | `apify--instagram-profile-scraper` |
| `clockworks/tiktok-profile-scraper` | yes | `clockworks--tiktok-profile-scraper` |
| `tri_angle/find-social-media-profiles` | no | none |
| `scrapearchitect/ultimate-instagram-profile-scraper` | no | none |

The two that were not exposed are rejected for this release. They can't be called through the connector, so there is no multi-platform name search and no Instagram discovery by bio or location.

## Live calls

| Actor | Run | Status | Items | Compute units | Login needed |
|---|---|---|---|---|---|
| LinkedIn search by name (`Short`, `maxItems` 3, `maxPages` 1) | CCuWDPE3ennmKuiyg | SUCCEEDED, 3.9 s | 1 | 0.00027 | no |
| Instagram profile reader (1 username) | b4GCW79g8oMmyuesz | SUCCEEDED, 2.8 s | 1 | 0.00077 | no |
| TikTok profile reader (1 profile, `resultsPerPage` 1) | fHnPZREaz1oEvC3tb | SUCCEEDED, 4.0 s | 1 (not found/private) | 0.00447 | no |

None of the run records reports a dollar cost. All three actors bill per event, and the store listings checked on 2026-11-03 did not show a per-profile price for these exact actors. The estimates below are conservative and should be checked in Apify Console after the first live runs.

## What each returns (fields used for scoring)

- **LinkedIn search by name.**
  - `Short` mode returns `name`, `position` (the headline), `linkedinUrl`, `publicIdentifier` and `location.linkedinText`.
  - `Full` mode adds `experience[]` (`companyName`, `companyLinkedinUrl`, `position`, dates), `about` and more.
  - The current employer can only be read in `Full` mode. In the probe, the headline named the business, but a headline is free text.
- **Instagram profile reader.** Takes `usernames[]` (handles, not URLs). Returns:
  - `username`, `url`, `fullName`, `biography`;
  - `externalUrl` and `externalUrls[].url` (the bio links);
  - `private`, `isBusinessAccount`, `businessAddress`;
  - plus counts and latest posts, which we never keep.
- **TikTok profile reader.** Takes `profiles[]` (handles). Returns `authorMeta.profileUrl`, `nickName`, `signature` (bio), `bioLink`, `privateAccount` and a `note` when the profile is not found or private. It also scrapes videos: `resultsPerPage` defaults to 100.

## Exa as discovery

One `search_web` call asked for the operator's profiles on four platforms. It returned:
- the LinkedIn profile, with its Experience section marking the business as the current employer;
- the business's own LinkedIn page, which lists its X account;
- the business website's contact page, which lists its Facebook and Instagram.

It returned no personal Instagram, Facebook or TikTok. That was expected for this subject.

Exa costs about $0.007 per search, is not Apify spend, and is already bound and guarded as `web_search`. Instagram, Facebook and TikTok have no name-search actor exposed, so Exa (when bound) is how those platforms get candidates beyond the anchors.

## Values for Tasks 2–5

| Item | Value |
|---|---|
| `find_profiles`, LinkedIn | Maps to `harvestapi--linkedin-profile-search-by-name` with `firstName`, `lastName`, optional `locations` (one, the lead's city), `maxItems`, `maxPages`, `profileScraperMode`, `strictSearch` and `waitSecs` |
| `find_profiles`, other platforms | No actor. Candidates come from anchors and, when bound, the Exa `search_web` |
| `read_profile`, Instagram | `apify--instagram-profile-scraper` with `usernames` and `waitSecs` |
| `read_profile`, TikTok | `clockworks--tiktok-profile-scraper` with `profiles`, `resultsPerPage` and `waitSecs` |
| `read_profile`, LinkedIn and Facebook | No reader. LinkedIn employer data comes from `find_profiles` in `Full` mode. Facebook is anchors and Exa only |
| Fixed values | LinkedIn: `profileScraperMode: "Full"`, `strictSearch: true`, `maxPages: 1`. Instagram: none. TikTok: `resultsPerPage: 1` |
| Pins (bindings) | `max_profile_results` (default 5) caps LinkedIn `maxItems`. `max_profile_reads` (default 10) caps the count of `usernames` or `profiles` per call |
| Blocked by `only_keys` | LinkedIn: `currentCompanies`, `pastCompanies`, `schools`, `currentJobTitles`, `industryIds`, and any mode with email search. Instagram: `includeAboutSection` (paid). TikTok: comments, replies, followers, following, downloads, subtitles, date and popularity filters, sorting, sections, and `videoKvStoreIdOrName` |
| URL rules | None apply. The two readers take handles, not URLs, so the handle is cut from a profile URL that matched the platform host (ruling in the SDD ledger) |
| Cost estimates | LinkedIn search, `Full`, up to 5 profiles: $0.05 per call. Instagram read: $0.003 per username. TikTok read with 1 video: $0.005 per profile |
