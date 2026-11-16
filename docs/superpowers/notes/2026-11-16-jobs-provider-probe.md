# Jobs provider probe

Date: 2026-11-16. Server `claude_ai_Apify_Connector`, tool
`johnvc--Google-Jobs-Scraper` (actor `johnvc/Google-Jobs-Scraper`,
id `CkLDY9GAQf6QlP6GP`). For `find_jobs` in Sales Partner 9.0.0 (design
`docs/superpowers/specs/2026-11-16-sales-partner-mcp-adapter-design.md`).
The two valig job actors were removed from the connector the same day:
LinkedIn ignored `companyName`, and Indeed matched keywords only.

## Input used

```json
{"query": "<business name>", "location": "<City>, California, United States",
 "country": "us", "posted_within": "30d", "num_results": 10,
 "max_pagination": 1, "waitSecs": 45}
```

Other inputs to leave at their defaults or keep out of reach: `output_file`,
`max_delay`, `include_lrad` and `lrad_value`, `google_domain`, `language`
(the actor warns that setting `en` returns zero results in non-English
markets).

## Results

| # | Query, location | Items | Finding |
|---|---|---|---|
| 1 | Albert Nahman Plumbing, Hayward | 2 | Neither from the employer: Barrett Business Services, PipeDreams. A name query returns loosely related employers, so a filter is required. |
| 2 | plumber, Hayward (trade search) | 10 | Small local employers appear: Bell Bros Plumbing, Water Heater Specialists, Dale Plumbing, Pipedreams. Sources: Indeed, Craigslist, JobLeads, SimplyHired, Monster. |
| 3 | Bell Bros Plumbing, Heating, and Air, Hayward | 10 | All 10 from the employer. Posted 6 to 19 days ago. |
| 4 | Blanding Auto Repair, Alameda | 0 | Status: "No jobs posted within the last month … No page fee was charged." Took 36 s: the actor retries with the location merged into the query. |

Run time: 5 to 10 s with results, 36 s for an empty result. Cost: three
page fees, at most $0.09 each on the free plan ($0.035 to $0.045 on paid
plans); the empty run had no page fee. Check the real charges in Apify
Console.

## Output fields for the contract

`title`, `company_name`, `location`, `detected_extensions.posted_at`
(relative: "6 days ago"), `share_link` (the Google Jobs URL), `via` (the
source job board), `apply_options[]` (links to the boards). Leave out
`description`, `job_highlights` and the rest.

## Employer matching (required in the server)

Google Jobs names one employer several ways. For Bell Bros the 10
results said: `Bell Brothers`, `BELL BROS. PLUMBING, HEATING & AIR`,
`bellbros`, `Bell Brothers Plumbing, Heating and Air Conditioning`,
`Bell Bros Plumbing, Heating, and Air`. An exact match on the normalized
name keeps 1 of 10. The rule:

1. Normalize both names: lower case; `&` becomes `and`; drop punctuation;
   expand `bros` to `brothers` and `co` to `company`; drop legal suffixes
   (`inc`, `llc`, `ltd`, `corp`, `company` when it comes last).
2. Match when one name's tokens are a leading run of the other's tokens
   (`bell brothers` and `bell brothers plumbing heating and air`), or
   when the two are equal with spaces removed (`bellbrothers` and
   `bell brothers`).
3. Anything else is dropped. With this rule, probe 1 keeps 0 of 2
   (correct) and probe 3 keeps 10 of 10.

Risk: a short or generic name ("Premier HVAC") can match an unrelated
employer whose name starts the same way. The location must also match
the lead's city or a nearby one. The server returns the matched
`company_name` so the agent can judge.
