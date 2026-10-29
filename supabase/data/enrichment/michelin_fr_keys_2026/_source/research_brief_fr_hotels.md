# Brief: official website + phone for France MICHELIN Key hotels

(Adapted 2026-10-30 from the UK brief in ../michelin_gb_ie_2026/_source/research_brief_uk_hotels.md; only the country-specific parts changed.)

You are researching contact data for a data-quality project where **a blank is always better than a plausible wrong value**. Nothing you produce is applied automatically; a human reviews it.

Input: a TSV (path given in your task) with columns ref, name, city, address, current_phone, current_website, michelin_phone, michelin_url (ref is a production hotel_code, or new_<MICHELIN id> for a hotel not yet in production). Research only the fields that are empty (current_phone / current_website). Identity of every hotel is already settled by its address and coordinates; the `address` column is the truth to match against. `michelin_phone` is the number MICHELIN's own page prints — a cross-check only, never a source by itself.

## Website (`website_url`)
- The hotel's OWN official site. For a chain/brand property (Airelles, Cheval Blanc, Oetker Collection, Four Seasons, Rosewood, Mandarin Oriental, Barrière, Beaumier, Maison Albar, Les Sources (Caudalie/Cheverny/Vougeot), K2 Collections, Domaine de Fontenille, Zannier, Six Senses, Shangri-La, Bvlgari, Peninsula, Marriott/Luxury Collection, InterContinental, LXR, Soho House, etc.) use the **property's own page** on the brand site (the page for this one hotel), not the brand homepage.
- NEVER: booking/OTA pages (Booking.com, Expedia, Hotels.com, Tablet/MICHELIN, Relais & Châteaux, SLH, Mr & Mrs Smith, Design Hotels, Leading Hotels, Preferred, Châteaux & Hôtels Collection, Small Luxury Hotels), guide pages, Tripadvisor, Google, Instagram/Facebook.
- For a restaurant-with-rooms (Troisgros, Pic, Georges Blanc, Flocons de Sel, Le Clos des Sens, La Bouitte, Bernard Loiseau, Les Prés d'Eugénie, Maison Bras-type properties...) the official site covering the hotel is correct; note if the site is the restaurant's.
- Confirm by **name + city + address on the site itself** (footer, contact page, legal notice). Load the page (curl -sL with a browser user agent, or WebFetch). If you only matched on name, it is `unclear`.
- Watch for traps: same-named hotels in other cities, renamed properties (note the new name), parked/for-sale domains, a sibling property of the same group (e.g. the four K2 hotels in Courchevel (K2 Palace, K2 Altitude, K2 Djola, K2 Chogori in Val d'Isère); Airelles Courchevel / Gordes / Val d'Isère / Saint-Tropez / Versailles; Cheval Blanc Courchevel / Paris / St-Tropez; Les Sources de Caudalie / Cheverny / Vougeot; Maison Albar Le Victoria (Nice) vs L'Imperator (Nîmes); Château de Maubreuil vs Maison Maubreuil; Les Fermes de Marie vs other Sibuet hotels; Domaine de Fontenille vs its sister hotels; La Réserve Paris vs Ramatuelle vs Beaulieu; the several Saint-Tropez hotels). Give the canonical URL (https, the page that actually loads, prefer the English root the hotel itself links to; no tracking params).

## Phone (`phone`)
Rule set by the product owner: **use the hotel's own number as printed on its own official site.** If the site shows no local hotel number but shows a central/group reservations line (e.g. a brand's central reservations, an 0800/08xx number), record it with line_type `group` (it is acceptable but must be labelled). Never take a number from Google, an OTA or an aggregator. Never take the restaurant's or spa's line when a hotel line exists (note it if that is the only one).
- Record `phone_as_listed` exactly as printed, and `phone` normalised to international format with French grouping in pairs, e.g. `+33 1 40 29 19 19`, `+33 4 90 54 33 07` (drop the leading 0 after +33; no parentheses, no '(0)'). A mobile (06/07) is acceptable only if it is the hotel's only number; say so in notes.
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
