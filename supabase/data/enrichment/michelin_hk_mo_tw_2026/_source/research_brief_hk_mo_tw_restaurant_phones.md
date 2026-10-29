# Brief: confirm phone numbers of Hong Kong, Macau and Taiwan MICHELIN-starred restaurants

Data-quality project: **a blank is always better than a plausible wrong value.** Nothing you produce is applied automatically; a human reviews it.

Input TSV columns: michelin_url, name, town, address, postcode (may be empty), website, michelin_phone. `website` is the official site MICHELIN links to; `michelin_phone` is the number on MICHELIN's own page (may be empty). An automated check could not find the MICHELIN number in the raw HTML of the site (often JavaScript-rendered or bot-blocked).

For each restaurant:
- Load the official site (WebFetch; try the home page and its contact / find-us / reservations page). Confirm it is this restaurant (name + town or postcode (may be empty) on the site).
- If michelin_phone is set: is that exact number printed on the official site? -> `confirmed`, record the page. If the site prints a *different* number for the restaurant, record it as `phone_on_site` and certainty `differs` (do not choose; a human decides).
- If michelin_phone is empty: if the official site prints the restaurant's own number, record it, certainty `site_only`.
- Never use Google, OpenRice, Inline, Ctrip/Trip.com, OTAs, Tripadvisor, aggregators, booking widgets, or search snippets as a source. A hotel switchboard is acceptable only if it is the number the site gives for the restaurant; say so in notes.
- Format: international, e.g. Hong Kong `+852 2555 2202`, Macau `+853 8889 3663`, Taiwan `+886 2 2181 9950` (drop Taiwan's leading 0). Chinese-language pages count; the number may appear as `2555 2202` or `(02) 2181-9950`.

Output CSV (path in your task), UTF-8, header, one row per input row in input order, including those where you found nothing, written with Python's csv module:
michelin_url,name,phone,certainty,phone_source_url,notes
certainty: confirmed | differs | site_only | not_found | site_unreachable

Rules: one restaurant at a time; write nothing except the output CSV; no git, no database. End with counts per certainty and anything odd (closures, renames, wrong site).
