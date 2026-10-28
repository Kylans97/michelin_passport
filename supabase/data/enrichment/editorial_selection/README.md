# Editorial Selection — first entries

Prepared 2026-10-28. Nothing here is applied.

The Selection ("Mantelier Selection" in the app) is the fourth way a
restaurant enters the catalogue, added by
`supabase/migrations/20261020120000_add_editorial_selection.sql`. See the
scope rule in `docs/Architecture/Michelin_Database/DATABASE_ARCHITECTURE.md`.

| File | What it is |
|---|---|
| `candidates.csv` | Tacite and Petit Péché, Amsterdam: researched values with sources and notes |
| `prepared_insert.sql` | Checks, then one statement that inserts both restaurants and their Selection entries |

## Before apply

1. **Review `candidates.csv`.** Two open points on Petit Péché:
   - **Spelling.** The venue writes "Petit Péché"; the request said
     "Petit Pêche".
   - **Season.** The Amsterdam restaurant runs November–April; the team is
     in Zandvoort May–September. Recorded as `open`. Whether to record the
     summer months another way is your call.
2. **Find the Google Place IDs** with find-place-id, using the coordinates
   in the CSV as proof. No Places API access was available here, so both are
   blank. Fill them in `prepared_insert.sql` or leave them NULL on purpose.
3. **Apply the migration**, then run `prepared_insert.sql` step 0 and read
   its output: the Amsterdam city row, zero restaurants within 50 m, and the
   highest code.
4. **Run step 1, then step 2.** Record the apply in both changelogs.

## Sources

- Addresses, phones and hours come from each venue's own site.
- Tacite's postcode comes from Amsterdam's alcohol-licence notice
  (gmb-2026-55686).
- Coordinates are BAG address points from PDOK.

## Left blank on purpose

| Field | Why |
|---|---|
| Cuisine | Neither restaurant has a MICHELIN description, so there is no source to map to `cuisine_id` without guessing. |

Tacite's Instagram (`tacite.amsterdam`) was supplied by the product owner on
2026-10-28. It is not linked from the venue's own site.
