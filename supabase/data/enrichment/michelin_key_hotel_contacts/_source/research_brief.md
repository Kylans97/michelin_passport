# Brief: official website + phone for Spanish MICHELIN Key hotels

You are researching contact data for a data-quality project where **a blank is always better than a plausible wrong value**. Nothing you produce is applied automatically; a human reviews it.

Input: a TSV (path given in your task) with columns hotel_code, name, city, address, current_phone, current_website, michelin_phone. Research only the fields that are empty (current_phone / current_website). Identity of every hotel is already settled by its address and coordinates; the `address` column is the truth to match against. `michelin_phone` is the number MICHELIN's own page prints — a cross-check only, never a source by itself.

## Website (`website_url`)
- The hotel's OWN official site. For a chain/brand property (Marriott Luxury Collection, Four Seasons, Mandarin Oriental, Belmond, Rosewood, Royal Hideaway/Barceló, Meliá, Only YOU/Palladium, Room Mate, CoolRooms, Hospes, Mercer, Vincci, Anantara, Fairmont, Soho House, etc.) use the **property's own page** on the brand site (e.g. https://www.marriott.com/en-us/hotels/madlc-the-palace-a-luxury-collection-hotel-madrid/overview/ style), not the brand homepage.
- NEVER: booking/OTA pages (Booking.com, Expedia, Hotels.com, Tablet/MICHELIN, Relais & Châteaux, SLH, Mr & Mrs Smith, Design Hotels, Leading Hotels, Preferred), guide pages, Tripadvisor, Google, Instagram/Facebook.
- For a restaurant-with-rooms (Atrio, Akelarre, ABaC, Pepe Vieira, Esperit Roca/Sants Metges...) the official site covering the hotel is correct; note if the site is the restaurant's.
- Confirm by **name + city + address on the site itself** (footer, contact page, legal notice). Load the page (curl -sL with a browser user agent, or WebFetch). If you only matched on name, it is `unclear`.
- Watch for traps: same-named hotels in other cities, renamed properties (note the new name), parked/for-sale domains, a sibling property of the same group (e.g. Only YOU Atocha vs Only YOU Boutique; Mercer Barcelona vs Mercer Sevilla; Cristine Bedfor Mahón vs Málaga/Sevilla; Royal Hideaway Corales Suites vs Corales Villas; Hospes Palacio del Bailío vs other Hospes). Give the canonical URL (https, the page that actually loads, prefer the language-neutral or Spanish/English root the hotel itself links to; no tracking params).

## Phone (`phone`)
Rule set by the product owner: **use the hotel's own number as printed on its own official site.** If the site shows no local hotel number but shows a central/group reservations line, record it with line_type `group` (it is acceptable but must be labelled). Never take a number from Google, an OTA or an aggregator. Never take the restaurant's or spa's line when a hotel line exists (note it if that is the only one).
- Record `phone_as_listed` exactly as printed, and `phone` normalised to international format with spaces, Spanish grouping, e.g. `+34 971 13 86 20` or `+34 910 883 333` (keep the hotel's own grouping if sensible; always `+34`, no leading 0/00, no parentheses).
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
