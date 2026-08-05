# Catalogue import

`import_catalogue.py` loads the Michelin Passport catalogue from
`supabase/data/*.csv` into `countries`, `cities`, `cuisines`, `hotels`,
`restaurants`, `hotel_restaurants`, `award_history` and `worlds_50_best`, in
that order, inside a single database transaction.

Authoritative rules: `docs/Architecture/Michelin_Database/DATABASE_ARCHITECTURE.md`,
`DATABASE_IMPORT_GUIDE.md`, `VALIDATION_REPORT.md`, `DATA_UPDATE_PROCESS.md`.

## Setup

```bash
cd scripts
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Usage

Dry run against local (parses, validates, inserts, then rolls back — writes nothing):

```bash
python3 scripts/import_catalogue.py --target local --dry-run
```

Real import against local:

```bash
python3 scripts/import_catalogue.py --target local
```

Dry run against remote (reads `DATABASE_URL` from the environment; still writes nothing):

```bash
export DATABASE_URL='postgresql://...'
python3 scripts/import_catalogue.py --target remote --dry-run
```

Real import against remote — requires the exact confirmation token in addition to `DATABASE_URL`:

```bash
export DATABASE_URL='postgresql://...'
python3 scripts/import_catalogue.py --target remote --confirm-remote-import IMPORT-MICHELIN-CATALOGUE
```

If any target catalogue table already has rows, every mode above refuses to run
until you pass `--allow-nonempty`. This is the *only* repeatability mechanism —
the script never upserts, so re-running against a non-empty table will hit a
unique-constraint violation and roll back rather than silently overwrite data.

## Connections

- `local` connects to `postgresql://postgres:postgres@127.0.0.1:54322/postgres`
  — the Supabase CLI's own local development default (`supabase status`),
  identical on every machine running `supabase start` and not a secret.
  Override with `LOCAL_DATABASE_URL` if your local stack uses different
  settings.
- `remote` requires `DATABASE_URL` in the environment. The script fails
  immediately with a clear message if it is unset, and never prints a
  connection string — only `scheme://***@host:port/db`.

## What gets imported

- `supabase/data/hotels_master.csv` (687 rows)
- `supabase/data/restaurants_master.csv` (774 rows)
- `supabase/data/hotel_restaurant_links.csv` (68 rows)
- `supabase/data/worlds_50_best_hall_of_fame.csv` (11 candidates; only those
  with a `restaurant_code` already in the catalogue **and** a derivable
  induction year are inserted — skipped members are printed with a reason)

`supabase/data/restaurants_pending_manual_review.csv` (La Paix, `rest_0158`)
is never read. Its stored address and coordinates point at the wrong
building, four kilometres from the correct site — see
`DATABASE_IMPORT_GUIDE.md` section 7.4. It stays quarantined until a
corrected address/coordinates are available or it reopens at the Corinthia
Grand Hotel Astoria Brussels.

## Safety

- Everything runs inside one transaction. Any error, at any step, rolls back
  the entire import — nothing partial is ever left behind.
- All SQL is parameterised (`psycopg` placeholders); no string-built SQL
  from CSV content.
- Before any write, the script checks that every target catalogue table is
  empty and refuses to proceed otherwise, unless `--allow-nonempty` is given.
- `--dry-run` runs the exact same code path — parsing, validation, inserts,
  post-import checks — then rolls back instead of committing. A clean dry
  run is a reliable predictor of a clean real import.
- A non-dry-run `--target remote` additionally requires
  `--confirm-remote-import IMPORT-MICHELIN-CATALOGUE`, matched exactly.
  `--target local` never requires this.
- Progress is reported per step and per table, not per row.

## Known documentation discrepancies

Verified directly against the actual CSV files in `supabase/data/` before
writing this script. None of these indicate a defect in the data — they are
stale figures in the documentation, or numbers computed for a different
scope (the full 775-restaurant catalogue including La Paix) than this
774-restaurant import.

**1. Restaurant count: 774, not 775.**
`VALIDATION_REPORT.md` and `START_HERE.md` describe a 775-restaurant
catalogue. That total includes La Paix, imported separately once its address
is corrected (see above). `restaurants_master.csv` itself has 774 rows,
which is what this importer loads — and matches `DATABASE_IMPORT_GUIDE.md`'s
own source-file table (`restaurants_master.csv | 774`).

**2. Cities: 613, not the documented 614.**
`DATABASE_IMPORT_GUIDE.md` section 6.2 and `VALIDATION_REPORT.md` state 614
city rows. Directly computing distinct `(country, city)` pairs across
`hotels_master.csv` and `restaurants_master.csv` yields 613 (373 hotel-only
+ 317 restaurant-only − 77 appearing in both — the "77" figure itself
matches the documentation exactly, confirming the underlying computation).
The one documented transformation that touches city count — retiring the
`Washington (Virginia)` string workaround into two `region`-distinguished
`Washington` rows (`DATABASE_IMPORT_GUIDE.md` section 6.2, implemented in
`resolve_city_name_and_region`) — does not change the total, because the
source data already carries `Washington` and `Washington (Virginia)` as two
separate city strings. There is no transformation that reconciles 613 with
614; this importer treats 614 as a stale count and reports the true derived
figure (613) at runtime.

**3. `award_history`: 1454, not 1455.**
`DATABASE_IMPORT_GUIDE.md` section 9.1 gives 1455 = 687 hotels + 768 starred
restaurants. The 768 figure is the starred-restaurant count for the full
775-restaurant catalogue, including La Paix (2 stars). This import's actual
star distribution is 121 + 340 + 306 = 767 starred restaurants (774 total −
7 zero-star), so the correct total for this scope is 687 + 767 = **1454**.
The script computes this figure from the real distribution rather than
hardcoding either number, and reports the discrepancy explicitly at the end
of a run.

**4. `hotel_code` zero-padding is not uniform.**
`DATABASE_ARCHITECTURE.md` section 11 documents `hotel_%03d` (3 digits,
e.g. `hotel_001`). The actual codes in `hotels_master.csv` use 2-digit
padding for 1–99 (`hotel_01` … `hotel_99`, 99 rows) and 3-digit padding for
100+ (`hotel_100` …, 588 rows). `restaurant_code` does match its documented
`rest_%04d` format exactly (774/774 rows, 4 digits). Codes are external,
frozen identifiers stored verbatim — this importer never reformats them, so
the mismatch has no functional effect, but a future script that *generates*
a new `hotel_code` should not assume 3-digit padding for codes below 100.

**5. `property_name`: 32, not 33 (not covered by required validation, noted for completeness).**
`VALIDATION_REPORT.md` section 3.7 states 33 restaurants have `property_name`
populated. `restaurants_master.csv` has 32 such rows, and La Paix (excluded
from this import) has no `property_name` either, so this isn't explained by
scope. Also a stale documentation count.

Every other documented invariant — 43 countries, 687 hotels, 774
restaurants, 68 links, 146 cuisines, the 36/161/490 Key distribution, the
121/340/306/7 star distribution, exactly 10 shared Google Place IDs, zero
duplicate codes, all relationship codes resolving, `link_confidence` uniformly
`Exact` in the source — was independently verified against the real CSV
files and matches exactly. The importer asserts all of these and fails
loudly if any stop holding.
