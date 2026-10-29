# Brief: official website + phone for MICHELIN Key hotels in Austria, Switzerland, Belgium, Hungary, Poland and Croatia

You are researching contact data for a data-quality project where **a blank is always better than a plausible wrong value**. Nothing you produce is applied automatically; a human reviews it.

Input: a TSV (path given in your task) with columns hotel_code, name, city, address, current_phone, current_website, michelin_phone. Research only the fields that are empty (current_phone / current_website). Identity of every hotel is already settled by its address and coordinates; the `address` column is the truth to match against. `michelin_phone` is the number MICHELIN's own page prints — a cross-check only, never a source by itself.

## Website (`website_url`)
- The hotel's OWN official site. For a chain/brand property (Kempinski, Rosewood, Four Seasons, Mandarin Oriental, Ritz-Carlton, Bürgenstock, Badrutt's, Aman, Park Hyatt, Sofitel, Marriott/Luxury Collection, Belmond, Hyatt, IHG, Accor, Small Luxury Hotels members' own sites, Interalpen, Kempinski Palace Engelberg, Valamar/Maistra in Croatia, etc.) use the **property's own page** on the brand site, not the brand homepage. Marriott property URLs carry a 5-letter code; check the code on the loaded page belongs to THIS hotel (codes are easily crossed between siblings).
- NEVER: booking/OTA pages (Booking.com, Expedia, Hotels.com, Tablet/MICHELIN, Relais & Châteaux, SLH, Mr & Mrs Smith, Design Hotels, Leading Hotels, Preferred), guide pages, Tripadvisor, Google, Instagram/Facebook.
- For a restaurant-with-rooms (e.g. Hof van Cleve-style restaurants with rooms) the official site covering the hotel is correct; note if the site is the restaurant's.
- Confirm by **name + city + address on the site itself** (footer, contact page, legal notice / Impressum / mentions légales). Postcode + street + number on the page counts as an address match. Load the page (curl -sL with a browser user agent, or WebFetch). If you only matched on name, it is `unclear`.
- Watch for traps: same-named hotels in other cities, renamed properties (note the new name), parked/for-sale domains, a sibling property of the same group (e.g. several Lech/Zürs/Ischgl/Kitzbühel/St. Moritz/Gstaad/Zermatt/Crans-Montana/Verbier hotels a few hundred metres apart; Vienna and Zurich and Geneva and Budapest city hotels on the same street; Brussels/Antwerp/Bruges boutique hotels; Dubrovnik and Rovinj resorts of the same group (Maistra Grand Park vs Lone; Adriatic Luxury Hotels); same-family hotels in one village (e.g. Post, Krone, Sonne)). Give the canonical URL (https, the page that actually loads, prefer the language-neutral or local/English root the hotel itself links to; no tracking params).

## Phone (`phone`)
Rule set by the product owner: **use the hotel's own number as printed on its own official site.** If the site shows no local hotel number but shows a central/group reservations line, record it with line_type `group` (it is acceptable but must be labelled). Never take a number from Google, an OTA or an aggregator. Never take the restaurant's or spa's line when a hotel line exists (note it if that is the only one).
- Record `phone_as_listed` exactly as printed, and `phone` normalised to international format with spaces, by country (the country code is in square brackets at the end of the `address` column, e.g. [AT]):
  - Austria `+43`, Switzerland `+41`, Belgium `+32`, Croatia `+385`: drop the trunk 0. E.g. `05583 2228` → `+43 5583 2228`; `081 836 70 00` → `+41 81 836 70 00`; `02 548 42 11` → `+32 2 548 42 11`; `020 500 300` → `+385 20 500 300`.
  - Hungary `+36`: drop the domestic prefix 06. E.g. `06 1 886 6600` → `+36 1 886 6600`.
  - Poland `+48`: no trunk prefix; 9 digits. E.g. `22 551 10 00` → `+48 22 551 10 00`.
  - Printed extension endings like "-0" (Austria) may be folded into the number exactly as the site's tel: link dials it; never add or drop other digits. No 00-prefix, parentheses, '(0)', dots or hyphens.
- Compare with michelin_phone and say `matches MICHELIN` / `differs from MICHELIN (MICHELIN: …)` in notes.
- If the site prints two numbers (landline + mobile/WhatsApp), take the landline/reception and note the other.

## Output
Write a CSV (path given in your task), UTF-8, with a header and **one row per input hotel, in input order — including those where you found nothing**:

hotel_code,name,website_url,website_source_url,website_match_basis,website_certainty,phone,phone_as_listed,line_type,phone_source_url,phone_certainty,notes

- website_match_basis: `name+city+address` | `name+city` | `name only` | `none found`
- *_certainty: `confirmed` | `unclear` | `not_found` | `already_set` (when the current field was not empty)
- line_type: `hotel` | `group` | `reservations` | `restaurant` | blank
- source_url: the exact page where you saw the address / the number.
- notes: anything a reviewer needs — renames, closures, a different address on the site, two candidates, mismatch with MICHELIN, site blocked.
Use Python's csv module to write it (quotes for commas).

## Rules
- Work one hotel at a time; do not batch-guess.
- Do not write anywhere except your output CSV. Do not touch any git repo or database.
- If a site blocks automated access, try WebFetch, then a search snippet is NOT enough — leave blank, certainty `unclear`, say why.
- Finish with a short summary: counts per field (confirmed / unclear / not found), and every trap, rename or closure you hit.

## Blocked sites
Do NOT use the built-in browser or any browser tool (other agents share it), and do not try to get around bot protection with spoofed headers. If a site returns 403/406/challenge to curl and WebFetch, leave the field `unclear`, put the candidate URL in notes with the words `NEEDS_BROWSER: <url>`, and move on — the main session will check those in a browser.

## This pass
`michelin_phone` is empty in the input this time (MICHELIN is being read separately); skip the MICHELIN comparison and say "no MICHELIN phone given" in notes.
