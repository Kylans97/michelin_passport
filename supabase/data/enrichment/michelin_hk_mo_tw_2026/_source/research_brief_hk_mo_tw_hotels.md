# Brief: official website + phone for Hong Kong, Macau and Taiwan MICHELIN Key hotels

(Adapted 2026-10-29 from ../../michelin_cn_2026/_source/research_brief_cn_hotels.md; only the country-specific parts changed.)

You are researching contact data for a data-quality project where **a blank is always better than a plausible wrong value**. Nothing you produce is applied automatically; a human reviews it.

Input: a TSV (path given in your task) with columns ref, name, city, address, current_phone, current_website, michelin_phone, michelin_url (ref is a production hotel_code, or new_<MICHELIN id> for a hotel not yet in production). Research only the fields that are empty (current_phone / current_website). Identity of every hotel is already settled by its address and coordinates; the `address` column is the truth to match against. `michelin_phone` is the number MICHELIN's own page prints — a cross-check only, never a source by itself.

## Website (`website_url`)
- The hotel's OWN official site. For a chain/brand property (Four Seasons, Mandarin Oriental, Rosewood, Aman, Capella, Bvlgari, Peninsula, Upper House / Swire, Six Senses, Banyan Tree, Shangri-La, Park Hyatt / Andaz (hyatt.com), InterContinental / Kimpton / Regent (ihg.com), Waldorf Astoria (hilton.com), St. Regis / EDITION / Ritz-Carlton Reserve (marriott.com), Raffles / Sofitel (all.accor.com), etc.) use the **property's own page** on the brand site (e.g. https://www.mandarinoriental.com/en/beijing/qianmen style), not the brand homepage.
- NEVER: booking/OTA pages (Booking.com, Expedia, Hotels.com, Trip.com/Ctrip, Agoda, Klook, Tablet/MICHELIN, Relais & Châteaux, SLH, Mr & Mrs Smith, Design Hotels, Leading Hotels, Preferred), guide pages, Tripadvisor, Google, Instagram/Facebook.
- Casino-resort hotels in Macau (Grand Lisboa Palace, The Londoner, Karl Lagerfeld, Morpheus, Palazzo Versace, St. Regis, Ritz-Carlton, Four Seasons) sit inside integrated resorts: use the hotel's own page on the resort/brand site, not the resort or casino homepage. Taiwan's independent hotels (Villa 32, The Lalu, The One Nanyuan, Hoshinoya Guguan) may have Chinese- or Japanese-language sites; that is acceptable if clearly the hotel's own.
- Confirm by **name + city + address on the site itself** (footer, contact page, legal notice). Load the page (curl -sL with a browser user agent, or WebFetch). If you only matched on name, it is `unclear`.
- Watch for traps: same-named hotels in other cities, renamed properties (note the new name), parked/for-sale domains, a sibling property of the same group (e.g. Mandarin Oriental The Landmark vs Mandarin Oriental Hong Kong; The Ritz-Carlton Hong Kong vs The Ritz-Carlton Macau; The St. Regis Hong Kong vs The St. Regis Macao; Four Seasons Hotel Macao vs Four Seasons Hong Kong; Kimpton Da An vs other Taipei Kimptons; mainland China siblings). Give the canonical URL (https, the page that actually loads, prefer the English root the hotel itself links to; no tracking params).

## Phone (`phone`)
Rule set by the product owner: **use the hotel's own number as printed on its own official site.** If the site shows no local hotel number but shows a central/group reservations line, record it with line_type `group` (it is acceptable but must be labelled). Never take a number from Google, an OTA or an aggregator. Never take the restaurant's or spa's line when a hotel line exists (note it if that is the only one).
- Record `phone_as_listed` exactly as printed, and `phone` normalised to international format, e.g. Hong Kong `+852 2522 0111`, Macau `+853 8802 2388`, Taiwan `+886 2 2181 9950`, `+886 4 2595 1111` (drop Taiwan's leading 0 after +886; no parentheses). A 0800 number is a national hotline: line_type `group`.
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
