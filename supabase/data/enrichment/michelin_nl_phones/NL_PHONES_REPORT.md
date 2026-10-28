# Phone numbers — MICHELIN-starred restaurants, Netherlands (2026-10-28)

Status: **PREPARED — NOT APPLIED.**

## Scope

Production export (run by the user, 2026-10-28) of every NL restaurant with
`michelin_stars` set and `phone` null: 117 rows. Two are
`permanently_closed` (Spectrum, De Groene Lantaarn) and were skipped, which
leaves 115.

## Result

| | Count |
|---|---|
| Confirmed, in `prepared_nl_phone_backfill.sql` | 100 |
| Unclear, left out | 9 |
| Not found | 6 |

Per-row evidence (number as printed, line type, official site, source URL,
notes) is in `nl_phones_all.csv`.

- **How numbers were sourced.** Every confirmed number comes from the
  restaurant's own website, or from the site of the hotel or estate it sits in
  when that is the number the restaurant itself publishes. Each was checked
  against city and address. MICHELIN was used only as a cross-check, and was
  mostly unreachable through its bot protection.
- **Unclear.** 8 restaurants publish only their hotel or estate switchboard:
  Vinkeles, Lizz, Wolfslaar, De Heeren van Harinxma, Karel 5, Voltaire,
  't Lansink and De Bloemenbeek. Calling these numbers does reach the
  restaurant, so they can be added if a switchboard is acceptable for a
  restaurant row. CUE's own site prints a number one digit short.
- **Not found.**
  - Demain may have closed (QA-205).
  - Graphite is reported closed (QA-203).
  - Vista and De Swarte Ruijter: their sites could not be loaded.
  - Restaurant Affect: its site blocks automated access.
  - Sense: no official website found.

## Wrong-record traps hit (all rejected)

The obvious domain was not the restaurant in these cases:

- noor.nl vs restaurantnoor.nl (Bloemendaal)
- tante-koosje.nl vs tantekoosje.nl (Nijmegen)
- studio.restaurant vs studiomaastricht.nl (room rental)
- restaurantcodium.nl vs codium.nl
- deburgemeester.nl vs deburgemeester.com (parked)
- sinne.nl (unrelated blog)
- wiesen.nl (for sale)
- dejuwelier.nl (placeholder)

Two stored MICHELIN URLs now redirect to a same-named restaurant abroad:
Nami goes to Orlando and Apicius to Valencia (QA-202).

## Also found

These are logged, not fixed:

- Stale MICHELIN URLs (QA-202).
- Closed venues still carrying stars (QA-204).
- City and address differences (QA-206).
- A possible rename (QA-207).

Official websites were found for about 90 rows whose `website_url` is blank.
They are in the `official_website` column, ready for a separate website
backfill if wanted.

## Testing

The file has the same structure as `../worlds_50_best_2025_2026/prepared_w50b_phone_backfill.sql`,
which was tested on a scratch database; this one was not run separately. It
fills only empty values and aborts on any unknown or non-NL code.
