# Websites and phones — Netherlands, restaurants and Key hotels (2026-10-31)

Status: **APPLIED 2026-10-31** (QA-375). 118 of 118 values verified in production afterwards.

Prompted by Flore (`rest_0047`) having no website in the app.

## Scope

Read-only production export (`_source/export_nl_missing.sql`, 2026-10-31)
of every `country_code = 'NL'` row in `restaurants` and `hotels` with an
empty `website_url` or `phone`. Fields that already hold a value were **not**
re-checked: they were added recently, so the user asked not to.

| | NL rows | empty `website_url` | empty `phone` |
|---|---|---|---|
| restaurants | 131 | 96 | 20 |
| hotels | 17 | 0 | 17 |

That makes 120 rows with at least one empty field. Two are
`permanently_closed` (Spectrum, De Groene Lantaarn) and were skipped, which
leaves 118 venues and 131 empty fields to check.

## Result

| Field | Confirmed (in the SQL) | Left blank (`unclear`) |
|---|---|---|
| `restaurants.website_url` | 93 | 3 |
| `restaurants.phone` | 8 | 10 |
| `hotels.phone` | 17 | 0 |

Per-field evidence (value, E.164, source URL, how it was matched) is in
`nl_contacts_research.csv`. `build_prepared.py` builds both that CSV and
`prepared_nl_contacts.sql` from `prepared_template.sql`.

### How values were confirmed

- **Websites.** 89 were found in the 2026-10-28 phone pass
  (`../michelin_nl_phones/nl_phones_all.csv`, `official_website`), where each
  was matched on name, city and address. Every one was fetched again on
  2026-10-31 (`_source/website_recheck_20261031.tsv`): all returned HTTP 200
  with the venue's name and city on the page. Five render their address only
  on a contact page, so that page was read instead. Rijnzicht's domain shows a
  holding page ("tijdelijk offline in verband met een beveiligingsprobleem").
  Its address was confirmed on 2026-10-28.
- **New this pass.** Restaurant Wolfslaar now has its own site
  (`restaurantwolfslaar.com`), which replaces the estate page found earlier.
  Three sites were found through the link on the MICHELIN page and checked on
  the site itself: Affect, Vista and De Woage.
- **Parent-property pages.** De Heeren van Harinxma (Lauswolt), Karel 5
  (Karel V) and LIZZ (Weeshuis) have no site of their own. Their URL is the
  restaurant's page on the hotel site, as the skill allows when no separate
  site exists. Voltaire's own domain redirects to its page on Parc Broekhuizen.
- **Phones.** Each number was read from the venue's own site, next to its own
  address, and stored in the human-readable format the column already uses
  (`+31 20 523 5235`). Hotels got the hotel's main line. Two of the hotel
  sites (Tivoli Doelen, De L'Europe) only render in a browser. Tivoli Doelen
  prints two numbers, and the first was taken.
- **Same-name hotel-restaurants.** 't Lansink, De Bloemenbeek and De Swarte
  Ruijter are one business with the hotel of the same name, so they are
  treated like De Nederlanden and De Leuf in the earlier pass. The 2026-10-28
  pass had held back 't Lansink and De Bloemenbeek as switchboards; this pass
  includes them.

### Left blank on purpose

- **Switchboard only (6).** Harinxma, Karel 5, LIZZ, Vinkeles and Voltaire
  publish only the hotel or estate number, and Vinkeles's number is The
  Dylan's (`hotel_03`). Each number is in the CSV notes. They can be added if
  a switchboard is acceptable on a restaurant row; that is a product decision,
  not a data one.
- **CUE.** Its site prints a mobile number one digit short. It is not
  corrected by guessing.
- **Vista.** The contact page would not load. Only MICHELIN gives a number
  (`+31 168 852 212`).
- **Demain, Sense and Graphite.** All three MICHELIN pages return 404 on
  2026-10-31, and none has a usable site of its own. Graphite was reported
  closed (QA-203). Demain looked closed on 2026-10-28 (QA-205). Sense has no
  site found and seems to have moved to Raadhuisstraat 1, Vught.
  They already have no star in production (`michelin_stars` null), but
  all three are still `open`. **That status may be stale. It needs a
  separate review and is not fixed here (QA-376).**

## Findings, logged and not fixed

- **Addresses that differ from the venue's own site.** These were seen in
  passing, in the QA-206 family: Bolenius (Nachtwachtlaan 20B), Nami
  (Deutersestraat 39B, Cromvoirt), Studio (Wycker Grachtstraat 24), Affect
  (Thorbeckegracht 41-42), Vista (Havenhoofd 2) and Sense (Raadhuisstraat 1).
  The 2026-10-28 notes list more of them.
- **A name.** MICHELIN and the venue's own site call De Woage
  (`rest_0788`) "Restobar de Woage".

## Testing

The file was run on a scratch PostgreSQL 17, seeded from the production
export. The first run filled all 118 values. A second run aborted on the
guard, as intended, because the fields were no longer empty. The guards
abort the whole transaction in three cases: a code is unknown, a row is not
Dutch, or a field already holds a value. The script updates only fields that
are still empty, and a post-check confirms that every value landed.
