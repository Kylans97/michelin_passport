# Applying France 2026 and Peru to production

Branch `data/fr-pe-2026`, which merges the France preparation
(`claude/michelin-fr-2026`, `27c715b`) with the Peru preparation. **Nothing in
it has been applied.** Each prepared SQL file is one transaction with its own
checks: on any problem it aborts and changes nothing.

## 0. Checked against production first (read-only, 2026-10-28)

Every check the files make before writing was rerun as a plain `SELECT`
against production, with the files' own data (their `VALUES` blocks read out
of the files themselves). All pass.

**France, stars** (`prepared_fr_stars_2026.sql`):

| Check | Expected | Production |
|---|---|---|
| `rest_1405`–`rest_1577` free | 0 taken | 0 |
| Starred FR restaurants now | 479 | 479 |
| The 14 corrections still at their old value (restaurant, and current 2026 award row) | 14 / 14 | 14 / 14 |
| 410 `michelin_url` rows: codes exist in FR; no URL used by another row | none bad | none |
| New restaurants' cities resolve to exactly one FR row, once the migration's 82 cities exist | all | all |
| The 82 migration cities already in production | none | none; all 82 are used |
| New restaurants already present (by MICHELIN URL) | none | none |
| Starred FR afterwards (existing with corrections, plus new) | 652: 30 / 80 / 542 | 652: 30 / 80 / 542 |
| Starred FR today without exactly one current star row, or disagreeing with it | 0 / 0 | 0 / 0 |

One name match was looked at and is not a duplicate: the new `rest_1428`
L'Orangerie (Four Seasons George V, Paris, two stars) and the existing
`rest_1344` L'Orangerie (Eugénie-les-Bains, one star).

**France, phones** (`prepared_fr_phone_backfill.sql`): all 385 codes exist in
FR, and all 385 currently have no phone, so it fills 385 and overwrites none.

**Peru** (`prepared_pe_keys_and_w50b.sql`):

| Check | Expected | Production |
|---|---|---|
| `hotel_804`–`hotel_817`, `rest_1578` free | 0 taken | 0 |
| Peruvian hotels now | 1 (Palacio Nazarenas) | 1 |
| Current Key rows share one guide year | 1 year | 1 (2026) |
| `hotel_745` is PE with One Key, and has no Key row yet | yes / 0 | yes / 0 |
| `rest_1381` is Mil (PE), with no 2024 rank yet | yes / 0 | yes / 0 |
| Hotels' cities resolve to exactly one PE row, once the migration's 5 exist | all | all |
| Hotels or Palacio's new URL already present | none | none |
| Central's and Mil's ranking slots free | all | all |
| Central not already in Peru | not present | not present |
| Hall-of-fame rows now | 6 | 6 |

## 1. Migrations

```bash
supabase migration list --linked      # remote should end at 20261018130000 (100 migrations)
supabase db push --linked             # applies 20261019120000, 20261019130000
supabase migration list --linked      # local and remote must now agree (102)
```

| Migration | What it does |
|---|---|
| `20261019120000_add_fr_2026_star_cities` | 82 FR cities, only `public.cities` rows |
| `20261019130000_add_pe_key_hotel_cities` | 5 PE cities, only `public.cities` rows |

If `db push` seems to hang after "Applying migration…", **do not retry**:
check for one of the new cities directly (CLAUDE.md).

## 2. Catalogue data, in this order

```bash
cd supabase/data/enrichment
supabase db query --linked --file michelin_fr_stars_2026/prepared_fr_stars_2026.sql
supabase db query --linked --file michelin_fr_stars_2026/prepared_fr_phone_backfill.sql
supabase db query --linked --file michelin_pe_2026/prepared_pe_keys_and_w50b.sql
```

| File | Effect |
|---|---|
| FR stars 2026 | 14 star corrections, 410 MICHELIN URLs, 173 new restaurants (`rest_1405`–`1577`, 148 with a phone), each with a 2026 award row. France becomes 652 starred: 30 / 80 / 542. |
| FR phones | 385 existing restaurants get a confirmed phone; none overwritten |
| Peru | 14 Key hotels (`hotel_804`–`817`), Palacio Nazarenas' missing Key row and current URL, Central (`rest_1578`) with its ranking history, Mil's 2024 rank. Peru becomes 15 Key hotels: 1 / 4 / 10. |

## 3. Afterwards

- Both changelogs: the Michelin_Database CHANGELOG (QA-220 to QA-225, Peru)
  and the app CHANGELOG under Unreleased, since two migrations were applied.
- Merge `data/fr-pe-2026` into main before the 1.2.0 build is cut.

## Open decisions (not blocking the apply)

- **Peru, Arequipa:** "Arequipa" and "City of Arequipa" become two city rows,
  as MICHELIN has them. The alternative breaks the MICHELIN-destination rule.
- **Peru, Belmond phones:** Monasterio, Miraflores Park and Rio Sagrado stay
  without a phone (MICHELIN only gives Belmond's US line). Their own local
  number could be used if you relax the phone rule for hotels.
- **France, QA-222:** `rest_0972` Jean Imbert au Plaza Athénée is listed by
  MICHELIN as La Grande Table du Plaza Athénée; its name and URL stay
  untouched until you decide.
- **France, QA-224:** Monaco's 9 starred restaurants, out of scope until
  decided.
- **Place IDs:** none for the 173 French restaurants or the 14 Peruvian
  hotels yet (no Places API key in the preparing session).
- **Editorial branch:** `feature/editorial-selection` carries
  `20261017130000`, which now sorts before applied migrations. It needs a
  new number (after these two) before it is applied.
