# Catalogue import and enrichment

Two scripts, two workflows, never mixed:

| | `import_catalogue.py` | `apply_catalogue_enrichment.py` |
|---|---|---|
| Target state | **Empty** catalogue tables | **Already populated** catalogue tables |
| What it does | Full initial load — every hotel, restaurant, link, current award | Incremental — GREEN-approved field fills and historical rows only |
| Safety guard | Refuses to run unless every catalogue table is empty (`--allow-nonempty` to override) | Resolves everything by code against existing rows; refuses on any conflict |
| Can create a restaurant/hotel row | Yes — that's its job | **Never** |
| Can change a current award value | Yes — that's the initial seed | **Never** |

Use `import_catalogue.py` to stand up a catalogue from nothing (a fresh local
dev database, or the very first production load). Use
`apply_catalogue_enrichment.py` to layer the catalogue enrichment
workstream's GREEN-approved output onto a catalogue that already has data in
it — which is production's actual state as of this workstream. Running the
former against a populated target, or weakening its empty-table guard to
force it through, is exactly the mistake this split exists to prevent — see
`supabase/data/enrichment/GREEN_INTEGRATION_AUDIT.md` for what went wrong the
first time this was tried (historical-data seeding was briefly wired directly
into `import_catalogue.py`'s `run_import()`, which broke that script's own
post-import checks for a plain empty-target load; it was reverted before
being used against anything, and the logic now lives here instead).

`import_catalogue.py` loads the Michelin Passport catalogue from
`supabase/data/*.csv` into `countries`, `cities`, `cuisines`, `hotels`,
`restaurants`, `hotel_restaurants`, `award_history` and `worlds_50_best`, in
that order, inside a single database transaction.

Authoritative rules: `docs/Architecture/Michelin_Database/DATABASE_ARCHITECTURE.md`,
`DATABASE_IMPORT_GUIDE.md`, `VALIDATION_REPORT.md`, `DATA_UPDATE_PROCESS.md`.
For the enrichment script specifically: `supabase/data/enrichment/APPROVAL_MANIFEST.md`
and `supabase/data/enrichment/GREEN_INTEGRATION_AUDIT.md`.

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

---

# Catalogue enrichment (incremental)

`apply_catalogue_enrichment.py` applies the GREEN-approved rows from the
catalogue enrichment workstream to a catalogue that **already has data in
it**. It shares `import_catalogue.py`'s connection handling, CSV reading and
`Check`/`report_checks` pattern (imported directly, not duplicated) but
nothing else — the two scripts solve opposite problems.

## What it writes

| Source | Destination | Rows |
|---|---|---|
| `supabase/data/enrichment/field_enrichment/restaurants_3star_fields.csv` (GREEN only) | `restaurants.website_url` / `.michelin_url` / `.booking_url` / `.cuisine_id` | 108 |
| `supabase/data/enrichment/field_enrichment/hotels_3key_fields.csv` (GREEN only) | `hotels.website_url` / `.michelin_url` / `.booking_url` | 41 |
| `supabase/data/worlds_50_best_history.csv` | `worlds_50_best` | 726 |
| `supabase/data/restaurant_award_history.csv` | `award_history` (`entity_type='restaurant'`) | 120 |
| `supabase/data/hotel_award_history.csv` | `award_history` (`entity_type='hotel'`) | 6 |

**1,001 total writes.** The field-enrichment sources are the GREEN-filtered
enrichment-workstream ledgers (`confidence=high, status=proposed`), not a
diff of the master CSVs — a master-CSV diff could pick up an edit nobody
reviewed. The three historical sources are already GREEN-only.

Restaurant `cuisine` needs its own code path: the CSV carries a name, but
`restaurants` has no `cuisine` column — only `cuisine_id`, a foreign key into
`cuisines`. `classify_cuisine_fills`/`apply_cuisine_fills` resolve the name
first and never fall through the generic field-fill path, which would query
a column that doesn't exist. See "Known gap" below for what happens when a
name doesn't resolve.

## What it never writes

`restaurants.michelin_stars`, `hotels.michelin_keys`, any address/coordinate/
`google_place_id` column, `hotel_restaurants`, any row with
`is_current = true`, and anything from the Hall of Fame mechanism — that one
is already correct via the existing `worlds_50_best_hall_of_fame.csv` +
`insert_hall_of_fame()` path in `import_catalogue.py`, and is deliberately
not duplicated here (`GREEN_INTEGRATION_AUDIT.md` section 2 has the full
reasoning, including a real discrepancy this comparison caught in the
enrichment workspace's own derived data).

## Usage

Setup is identical to `import_catalogue.py` (see above — same venv, same
`requirements.txt`).

Dry run against local:

```bash
python3 scripts/apply_catalogue_enrichment.py --target local --dry-run
```

Real run against local:

```bash
python3 scripts/apply_catalogue_enrichment.py --target local
```

Dry run against remote:

```bash
export DATABASE_URL='postgresql://...'
python3 scripts/apply_catalogue_enrichment.py --target remote --dry-run
```

Real run against remote — requires the exact confirmation token, distinct
from `import_catalogue.py`'s, so the two can never be confused for one
another:

```bash
export DATABASE_URL='postgresql://...'
python3 scripts/apply_catalogue_enrichment.py --target remote --confirm-remote-enrichment APPLY-MICHELIN-ENRICHMENT
```

There is no `--allow-nonempty` flag here — the opposite assumption is the
whole point. If a target's catalogue tables are actually empty, every code
lookup fails and the run stops on unresolved codes; use `import_catalogue.py`
first.

## Safety model

- One transaction per run, always. `--dry-run` runs the real classify/apply/
  validate path and then unconditionally rolls back. A real run commits only
  if every post-deploy check passes; any `CONFLICT`, unresolved code, or
  failed invariant rolls back the *entire* transaction — a run that is 999
  rows clean and 2 rows conflicted applies zero of the 999.
- Every write is preceded by classification, never assumed. Each proposed
  row becomes exactly one of `INSERT`, `UPDATE`, `ALREADY_PRESENT`,
  `CONFLICT`, `SKIP_UNRESOLVED_CODE`, or `UNRESOLVED_CUISINE`, printed before
  anything is touched.
- Field fills additionally guard at the SQL level —
  `update ... where {field} is null` — so even a hypothetical race between
  classification and write cannot overwrite a value that appeared in
  between; `cur.rowcount != 1` aborts the whole run rather than continuing
  on a surprise.
- Six invariants are snapshotted before the first write and re-checked
  after the last one, inside the same transaction: current
  `michelin_stars`, current `michelin_keys`, every restaurant's
  address/`google_place_id`/location, every hotel's, `hotel_restaurants`,
  and every existing `is_current = true` award row. All six must compare
  identical or the run fails.
- Idempotent by construction, not by a special-cased flag: a row already
  matching production classifies `ALREADY_PRESENT` and is never re-applied.
  A second run after a successful deployment reports "0 required new
  writes" and changes nothing — verified directly, see below.

## Cuisine reference rows

The 10 missing `cuisines` names blocking restaurant enrichment (found by
real local testing — see the previous revision of this section in version
control) were individually reviewed for genuine novelty vs. spelling/synonym
duplication against all 146 existing values —
`supabase/data/enrichment/verification/cuisine_normalization_review.{csv,md}`
has the full evidence per name. Result: **7 GREEN_NEW, 3 AMBER, 0
GREEN_MAP_EXISTING, 0 RED.**

The 7 GREEN_NEW names are inserted into `cuisines` in the **same
transaction**, immediately before restaurant field enrichment —
`classify_cuisine_references` / `apply_cuisine_references` in
`apply_catalogue_enrichment.py`. Never a guessed id: `cuisines.id` is
`smallint generated always as identity`, so the insert omits it and captures
the assigned value with `RETURNING id`. A name already present (this run or
a prior one) classifies `ALREADY_PRESENT` and is never re-inserted —
idempotent by the same mechanism as everything else in this script.

The 3 AMBER names are never inserted by this script, on principle — each is
a real, evidence-backed cuisine description sitting close enough to an
existing value that a human should decide whether to keep it distinct, not
this script. The 3 restaurants that need one of them classify
`DEFERRED_AMBER_CUISINE`: reported clearly, left untouched (`cuisine_id`
stays `NULL`), and — this is the important part — **do not block the other
1,005 rows** the way a genuinely unresolved/unreviewed cuisine name still
would. `classify_cuisine_fills` treats a missing name two ways: a name that
matches a known AMBER entry defers just that one row; a name that matches
neither an existing cuisine, a GREEN_NEW insertion, nor a known AMBER entry
is `UNRESOLVED_CUISINE` and still blocks everything, because that would mean
a row nobody ever reviewed at all.

**Write counts stay separate on purpose** (never folded into one number
that could be misread as the original 1,001):

| | Rows |
|---|---|
| Catalogue enrichment (field fills + historical) | 1,001 |
| Cuisine reference rows (GREEN_NEW only) | 7 |
| **Total DB write operations, this deployment** | **1,008** |
| Deferred, not written this run (AMBER, pending human decision) | 3 |

## Verified locally

Tested against a real local Supabase Postgres instance (`supabase status`,
port 54322), not just offline logic checks:

1. Dry run and real run against a freshly-loaded, pre-enrichment local
   catalogue — correctly classified 7 cuisine-reference `INSERT` + 146
   field `UPDATE` (85 + 20 cuisine + 41 hotel) + 852 historical `INSERT` =
   exactly 1,005 applied, 3 correctly `DEFERRED_AMBER_CUISINE`, matched
   expectations precisely, and a real run committed cleanly.
2. Re-running `--dry-run` immediately after: all 1,005 rows classified
   `ALREADY_PRESENT`, the 3 AMBER rows still correctly `DEFERRED_AMBER_CUISINE`
   (not "required" — reported separately from "0 required new writes"),
   applied nothing.
3. Deliberately corrupted one field value and one historical `award_value`
   directly in the database, then ran again: both were caught as `CONFLICT`
   and named exactly, the other clean rows were **not** applied despite
   being ready, and the transaction rolled back in full. Reverted the
   corruption and confirmed a clean re-run afterward.
4. The `cuisine_id` gap itself, and later the ordering bug where the new
   cuisine rows weren't actually visible to `classify_cuisine_fills` until
   `apply_cuisine_references` ran in the same step rather than the later
   "Applying..." phase, were both found by this same real-database testing,
   not anticipated in advance.
