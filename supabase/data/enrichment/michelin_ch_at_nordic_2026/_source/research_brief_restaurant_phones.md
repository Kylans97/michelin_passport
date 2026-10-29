# Brief: confirm phone numbers of Swiss, Austrian and Nordic MICHELIN-starred restaurants

Data-quality project: **a blank is always better than a plausible wrong value.** Nothing you produce is applied automatically; a human reviews it.

Input CSV (_source/phone_check_todo.csv) columns: michelin_url, name, town, country, michelin_phone, website, auto_check. `website` is the official site MICHELIN links to; `michelin_phone` is the number on MICHELIN's own page (may be empty). An automated check could not find the MICHELIN number in the raw HTML of the site (often JavaScript-rendered or bot-blocked).

For each restaurant:
- Load the official site (WebFetch; try the home page and its contact / find-us / reservations page). Confirm it is this restaurant (name + town or postcode on the site).
- If michelin_phone is set: is that exact number printed on the official site? -> `confirmed`, record the page. If the site prints a *different* number for the restaurant, record it as `phone_on_site` and certainty `differs` (do not choose; a human decides).
- If michelin_phone is empty: if the official site prints the restaurant's own number, record it, certainty `site_only`.
- Never use Google, OTAs, Tripadvisor, aggregators, booking widgets, or search snippets as a source. A hotel switchboard is acceptable only if it is the number the site gives for the restaurant; say so in notes.
- Format: international, as MICHELIN prints it (e.g. `+41 81 303 30 36`, `+43 1 7133168`); when the site prints a national form (062 511 60 05) it counts as the same number.

Output CSV (path in your task), UTF-8, header, one row per input row in input order, including those where you found nothing, written with Python's csv module:
michelin_url,name,phone,certainty,phone_source_url,notes
certainty: confirmed | differs | site_only | not_found | site_unreachable

Rules: one restaurant at a time; write nothing except the output CSV; no git, no database. End with counts per certainty and anything odd (closures, renames, wrong site).
