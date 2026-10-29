# Brief: official website + phone for United States, Canada and Mexico MICHELIN Key hotels

(Adapted 2026-10-29 from ../../michelin_gb_ie_2026/_source/research_brief_uk_hotels.md, itself from the Spain brief; only the country-specific parts changed.)

You are researching contact data for a data-quality project where **a blank is always better than a plausible wrong value**. Nothing you produce is applied automatically; a human reviews it.

Input: a TSV (path given in your task) with columns ref, name, city, address, current_phone, current_website, michelin_phone, michelin_url (ref is a production hotel_code, or new_<MICHELIN id> for a hotel not yet in production). Research only the fields that are empty (current_phone / current_website). Identity of every hotel is already settled by its address and coordinates; the `address` column is the truth to match against. `michelin_phone` is the number MICHELIN's own page prints — a cross-check only, never a source by itself.

## Website (`website_url`)
- The hotel's OWN official site. For a chain/brand property (Four Seasons, Mandarin Oriental, Rosewood, Auberge Resorts, Aman, Belmond, Montage, Ritz-Carlton, St. Regis, Edition, Park Hyatt, Kimpton, Proper, Fairmont, One&Only, Six Senses, Ace, Thompson, Viceroy, Grupo Habita, Marriott Autograph Collection, etc.) use the **property's own page** on the brand site (e.g. https://www.fourseasons.com/newyork/ or https://aubergeresorts.com/aubergedusoleil/ style), not the brand homepage.
- NEVER: booking/OTA pages (Booking.com, Expedia, Hotels.com, Tablet/MICHELIN, Relais & Châteaux, SLH, Mr & Mrs Smith, Design Hotels, Leading Hotels, Preferred), guide pages, Tripadvisor, Google, Instagram/Facebook.
- For a restaurant-with-rooms (an inn whose site is the restaurant's, e.g. SingleThread, The Inn at Little Washington, Harbor House Inn) the official site covering the hotel is correct; note if the site is the restaurant's.
- Confirm by **name + city + address on the site itself** (footer, contact page, legal notice). Load the page (curl -sL with a browser user agent, or WebFetch). If you only matched on name, it is `unclear`.
- Watch for traps: same-named hotels in other cities, renamed properties (note the new name), parked/for-sale domains, a sibling property of the same group (e.g. Four Seasons New York vs Four Seasons New York Downtown; the several Aman, Rosewood, Auberge, Proper and Habita properties; Ritz-Carlton vs Ritz-Carlton Reserve; same-named inns in different states; Casa/Hacienda names repeated across Mexican towns). Give the canonical URL (https, the page that actually loads, prefer the English root the hotel itself links to; no tracking params).

## Phone (`phone`)
Rule set by the product owner: **use the hotel's own number as printed on its own official site.** If the site shows no local hotel number but shows a central/group reservations line, record it with line_type `group` (it is acceptable but must be labelled). Never take a number from Google, an OTA or an aggregator. Never take the restaurant's or spa's line when a hotel line exists (note it if that is the only one).
- Record `phone_as_listed` exactly as printed, and `phone` normalised to international format: US/Canada `+1 212 555 0123` (area code, exchange, line, spaces); Mexico `+52 55 1234 5678` or `+52 984 123 4567` (as the area code dictates; no leading 01/044/045). A toll-free number (+1 800/833/844/855/866/877/888) is a central reservations line unless the site clearly labels it as this hotel's own: line_type `group` or `reservations`.
- Compare with michelin_phone and say `matches MICHELIN` / `differs from MICHELIN (MICHELIN: …)` in notes.
- If the site prints two numbers (landline + mobile/WhatsApp), take the landline/reception and note the other.

## Output
Write a CSV (path given in your task), UTF-8, with a header and **one row per input hotel, in input order — including those where you found nothing**:

ref,name,website_url,website_source_url,website_match_basis,website_certainty,phone,phone_as_listed,line_type,phone_source_url,phone_certainty,notes

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
