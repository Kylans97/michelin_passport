# Brief: confirm mainland China venue addresses on the venue's own website

(2026-10-30. Product owner: "google in China is not very accurate sadly, let's use hotel and restaurant own websites to confirm the actual address".)

Data-quality project: **a blank is always better than a plausible wrong value.** Nothing you produce is applied automatically; a human reviews it.

Input TSV columns: kind (`restaurant` | `hotel` | `existing_hotel`), ref, name, city, michelin_address, website. `michelin_address` is what MICHELIN's own page prints; `website` is the official site MICHELIN links to (for `hotel` rows it is a note with the *unconfirmed* candidate URL found earlier — those brand sites refused curl).

Use the built-in browser (the `mcp__Claude_Browser__*` tools: `navigate`, `get_page_text`, `find`, `read_page`). It renders JavaScript, which is why it is used now. One venue at a time.

For each row:
- Open the official site. Look for the address on the home page, footer, "Contact", "Location", "Find us", "Getting here", "Dining" detail or "Reservations" page. For a restaurant inside a hotel, the restaurant's page on the hotel's own site, or the hotel's contact page, counts as the venue's own site.
- **confirmed**: the site prints the same street number and the same road as `michelin_address` (floor/shop numbers and district may differ in detail; Chinese-language addresses count — e.g. 金和东路20号 = 20 Jinhe East Road; 路 = Road/Lu, 街 = Street/Jie, 号 = No.). Copy the address exactly as printed into `site_address` (Chinese as Chinese).
- **differs**: the site prints a different address (another street or number, a new location). Copy it; do not decide which is right.
- **not_found**: the site loads and is the venue's, but prints no street address.
- **site_unreachable**: the page will not load, is a placeholder, or shows a bot check / CAPTCHA.
- For `hotel` rows only, also: if the property's own page is confirmed (name + city + address), record `website_url` (the property page, not the brand home page; https, no tracking params) and `phone` (the hotel's own number as printed on that site, international format `+86 21 2327 2888`; leave blank if only a group / 400 / 800 hotline) with `phone_as_listed`.

Never:
- solve, click through or work around a CAPTCHA / bot check / "verify you are human" page — record `site_unreachable`;
- sign in, create accounts, submit any form, make or start a booking;
- accept cookies beyond what is needed to read the page (choose the decline / "continue without accepting" option);
- use Google, Baidu, Amap, Dianping, Meituan, Ctrip/Trip.com, OTAs, WeChat or search snippets as a source.

Output CSV (path given in your task), UTF-8, header, one row per input row **in input order**, written with Python's csv module:
`kind,ref,name,michelin_address,certainty,site_address,source_url,website_url,phone,phone_as_listed,notes`

End with counts per kind × certainty and anything odd (moves, closures, renamed hotels, wrong site).
