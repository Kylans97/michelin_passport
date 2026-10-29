# Brief: official website + phone for Italian MICHELIN Key hotels

You are researching contact data for a data-quality project where **a blank is always better than a plausible wrong value**. Nothing you produce is applied automatically; a human reviews it.

Input: a TSV (path given in your task) with columns hotel_code, name, city, address, current_phone, current_website, michelin_phone. Research only the fields that are empty (current_phone / current_website). Identity of every hotel is already settled by its address and coordinates; the `address` column is the truth to match against. `michelin_phone` is the number MICHELIN's own page prints — a cross-check only, never a source by itself.

## Website (`website_url`)
- The hotel's OWN official site. For a chain/brand property (Belmond, Aman, Four Seasons, Rosewood, Bulgari, Six Senses, COMO, Oetker, Auberge, Lefay, ADLER, Evok/Nolinski, Orient Express, Marriott Luxury Collection, Portrait/Lungarno, J.K. Place, etc.) use the **property's own page** on the brand site, not the brand homepage. Marriott property URLs carry a 5-letter code; check the code on the loaded page belongs to THIS hotel (codes are easily crossed between siblings).
- NEVER: booking/OTA pages (Booking.com, Expedia, Hotels.com, Tablet/MICHELIN, Relais & Châteaux, SLH, Mr & Mrs Smith, Design Hotels, Leading Hotels, Preferred), guide pages, Tripadvisor, Google, Instagram/Facebook.
- For a restaurant-with-rooms (e.g. Casa Maria Luigia, Villa Crespi, Locanda al Colle...) the official site covering the hotel is correct; note if the site is the restaurant's.
- Confirm by **name + city + address on the site itself** (footer, contact page, legal notice). Load the page (curl -sL with a browser user agent, or WebFetch). If you only matched on name, it is `unclear`.
- Watch for traps: same-named hotels in other cities, renamed properties (note the new name), parked/for-sale domains, a sibling property of the same group (e.g. Splendido vs Splendido Mare in Portofino; Portrait Roma vs Portrait Milano; J.K. Place Roma vs Capri; Villadorata Country House vs Seven Rooms Villadorata; La Fiermontina Luxury Home vs Palazzo Bozzi Corso; Lefay Garda vs Dolomiti; ADLER Sicilia vs ADLER Lodge Ritten; Sextantio Matera vs Santo Stefano). Give the canonical URL (https, the page that actually loads, prefer the language-neutral or Italian/English root the hotel itself links to; no tracking params).

## Phone (`phone`)
Rule set by the product owner: **use the hotel's own number as printed on its own official site.** If the site shows no local hotel number but shows a central/group reservations line, record it with line_type `group` (it is acceptable but must be labelled). Never take a number from Google, an OTA or an aggregator. Never take the restaurant's or spa's line when a hotel line exists (note it if that is the only one).
- Record `phone_as_listed` exactly as printed, and `phone` normalised to international format with spaces: always `+39`, then the Italian number **keeping its leading 0 for landlines** (Italy is special: +39 089 871012 is correct, +39 89 871012 is WRONG). Mobiles start with 3 (+39 338 637 6121). Keep the hotel's own grouping where sensible; no 0039/00, no parentheses, no dots. Never invent or drop digits.
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
