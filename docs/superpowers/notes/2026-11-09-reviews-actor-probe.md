# Reviews actor probe, 2026-11-09

Why: the scheduled prepare run `prepare-20261109T1530Z` stopped at its
first lead. The guard blocked the reviews call because the agent sent
`path` and `query` arguments.

## The Compass tool broke

`compass--Google-Maps-Reviews-Scraper` on the Apify connector:

- Its published input schema is still the batch input (`placeIds`,
  `maxReviews`, `personalData`, …), also after a session restart.
- Calling it with that input fails: `root: must have required property 'path'`.
- `path: "/"` returns `"interface":"server"` and
  `Documented operations: GET / (required: place)`.
- A call with `/?place=…` is rejected by the client, because the reply
  does not match the published output schema (`data must have required
  property 'runId'`).

So neither input works from Claude Code. The other actors on the same
connection work normally.

## Replacement: `web_wanderer/google-reviews-scraper`

Actor `pP8fxA1kSf7snQKNW`, a batch actor (`standbyUrl: null`).

- 24,864 runs in 30 days, 645 failed (about 2.6%).
- Pay per event: $0.00032 per review and $0.0016 per start (charged on
  this account), so a 50-review call costs about $0.018.

Probe call, on the connector tool `web_wanderer--google-reviews-scraper`:

`{"place_ids":["ChIJn3zNZ5aGj4ARdv7oMmIqhBA"],"limit":50,"order":"newest","include_personal":false,"waitSecs":45}`

- Run `AfJK9oOMwfDY93PmB`: SUCCEEDED in 9.3 s, 1 item, $0.00192.
- With `include_personal: false`, `reviewer_id`, `reviewer_name`,
  `reviewer_url`, `reviewer_photo_url` and `reviewer_photo` were all null.
  The item schema still types them as strings, so the guard requires the
  flag rather than trusting the default.
- `review_url` is present (it names the review, not the reviewer).
- The one review was star-only: `rating` 5, `content` null,
  `reviewed_at_date` `2022-11-10T00:00:00Z`.
- The response wraps the run (`runId`, `storages`, `nextStep`); items are
  read with `get-dataset-items`, as for the other actors.

Field map used in `usage.md`: `content`, `reviewed_at_date`, `rating`,
`owner_response`, `owner_response_at_date`, `place_id`, `review_url`.

Inputs the guard allows: `place_ids`, `limit`, `order`, `anyDate`,
`searchKeyword`, `source`, `lang`, `include_personal`, `waitSecs`. It
refuses `place_urls` and the keyword search mode (`search`,
`search_location`, `search_limit`, `search_coordination`) and the
dataset re-sort (`sort_dataset`, `sort_keys`).
