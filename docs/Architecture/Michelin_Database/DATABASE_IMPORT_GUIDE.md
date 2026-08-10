# Database Import Guide

Michelin Passport — building the production database from the source data.

Table definitions, constraints and conventions are specified in `DATABASE_ARCHITECTURE.md`. Environment setup, secrets and storage are in `DEPLOYMENT.md`. This document is the procedure: order of operations, transformations, verification and rollback. Follow it top to bottom.

Row counts quoted here are expected values for the launch dataset and are used as assertions. They belong to the dataset version recorded in `VALIDATION_REPORT.md`; when the catalogue changes, update them from the new validation run.

Estimated runtime for a full build: under two minutes. The catalogue is 1 462 rows.

---

## 1. Prerequisites

**PostgreSQL 15 or later.** Required for `GENERATED ALWAYS AS IDENTITY` on `cuisines` and for `NULLS NOT DISTINCT` if used in place of the `coalesce` unique index.

**Extensions.** Enable before creating any table.

```sql
CREATE EXTENSION IF NOT EXISTS postgis;      -- geography(Point,4326)
CREATE EXTENSION IF NOT EXISTS pg_trgm;      -- trigram search indexes
CREATE EXTENSION IF NOT EXISTS pgcrypto;     -- gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS pg_cron;      -- scheduled materialised view refresh
```

`pg_cron` installs into the `cron` schema and is enabled from the Supabase dashboard under Database → Extensions. It is required by `DATA_UPDATE_PROCESS.md` §13 and by nothing in the initial load, so the build succeeds without it — but the statistics views then never refresh.

On Supabase, `pgcrypto` and `postgis` are enabled from the dashboard or with the statements above. `gen_random_uuid()` is built in from PostgreSQL 13, but declaring `pgcrypto` makes the dependency explicit.

**Source files.**

| File | Rows |
|---|---|
| `hotels_master.csv` | 687 |
| `restaurants_master.csv` | 774 |
| `restaurants_pending_manual_review.csv` | 1 |
| `hotel_restaurant_links.csv` | 68 |
| `qa_issues.csv` | 188 |
| `manual_actions_required.csv` | 73 |
| `worlds_50_best_history.csv` | 726 |
| `restaurant_award_history.csv` | 120 |
| `hotel_award_history.csv` | 6 |

`restaurants_pending_manual_review.csv` holds `rest_0158` La Paix. It is imported — see §7.4 — but its address requires attention first.

`worlds_50_best_history.csv`, `restaurant_award_history.csv` and `hotel_award_history.csv` hold historical rows only — 2002–2024 rankings and pre-2026 award tiers, sourced through the catalogue enrichment workstream and approved for merge in `supabase/data/enrichment/APPROVAL_MANIFEST.md`. Each is read by a dedicated loader/insert pair in `scripts/import_catalogue.py` (`load_worlds_50_best_history`/`insert_worlds_50_best_history` and the restaurant/hotel award-history equivalents), inserted after the existing Hall of Fame seeding step in §9.2, always with `is_current = false`. None of the three ever supplies the current guide year — that remains the exclusive responsibility of §9.1's `insert_award_history` and §9.2's `insert_worlds_50_best_top50`/`insert_hall_of_fame`.

---

## 2. Order of operations

Order is not negotiable. Each step depends on identifiers created by the one before it.

1. Extensions
2. Types and functions
3. Reference tables — `countries`, `cities`, `cuisines`
4. Catalogue tables — `hotels`, `restaurants`
5. `hotel_restaurants`
6. `award_history`, `worlds_50_best`
7. Views
8. Indexes
9. Constraint validation
10. User tables, including the `auth.users` trigger — `DATABASE_ARCHITECTURE.md` §4.1
11. Row Level Security — `DATABASE_ARCHITECTURE.md` §15
12. Materialised views and their `pg_cron` schedule — `DATA_UPDATE_PROCESS.md` §13

User tables come last so that a failed catalogue load never leaves `auth.users` referenced by orphaned rows.

**Step 11 is not optional and is not a hardening pass.** Until RLS is applied, every table in `public` is writable by anyone holding the `anon` key, which ships inside the Flutter binary. Do not expose the project to a client before §11 is complete and §15.9 of the architecture verifies clean.

---

## 3. Types and the updated_at trigger

```sql
CREATE TYPE venue_status AS ENUM ('open', 'temporarily_closed', 'permanently_closed');

CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

Attach to `hotels` and `restaurants` after they exist:

```sql
CREATE TRIGGER hotels_updated_at BEFORE UPDATE ON hotels
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER restaurants_updated_at BEFORE UPDATE ON restaurants
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

---

## 4. Create tables with constraints NOT VALID

Create every table per `DATABASE_ARCHITECTURE.md` §2–§4, but add foreign keys and CHECK constraints as `NOT VALID`:

```sql
ALTER TABLE restaurants
  ADD CONSTRAINT restaurants_city_fk FOREIGN KEY (city_id) REFERENCES cities(id) NOT VALID;
```

`NOT VALID` means the constraint applies to new rows but existing rows are not checked at creation. Load the data, then validate:

```sql
ALTER TABLE restaurants VALIDATE CONSTRAINT restaurants_city_fk;
```

The reason is diagnostic, not performance. A constraint failure during a 1 462-row `COPY` reports one offending row and aborts the transaction. Validating afterwards reports the whole failing set at once, which is the difference between one debugging cycle and twenty.

Do **not** defer the unique constraints on `hotel_code` and `restaurant_code`. Those must fail immediately, because a duplicate code corrupts every downstream join.

---

## 5. Staging schema

Every intermediate object used later in this guide is created here. Nothing below refers to an object that has not been defined.

Staging lives in its own schema so that a failed load leaves no debris in `public`, and so that dropping it at the end is a single statement.

```sql
CREATE SCHEMA IF NOT EXISTS staging;
```

### 5.1 `staging_hotels`

Every column of `hotels_master.csv`, all as `text` except the two coordinates. Loading as text defers type errors to an explicit cast, where the failing value is visible.

```sql
CREATE TABLE staging.staging_hotels (
  id                    text,          -- present and empty in the source; never used
  hotel_code            text NOT NULL,
  name                  text NOT NULL,
  michelin_keys         smallint NOT NULL,
  city_text             text NOT NULL, -- resolved to city_id in §7.3
  country_text          text NOT NULL, -- resolved to country_code in §7.3
  country_flag          text,          -- consumed by countries in §6.1, then discarded
  address               text NOT NULL,
  lat                   double precision NOT NULL,
  lng                   double precision NOT NULL,
  google_place_id       text,
  michelin_url          text,
  website_url           text,
  booking_url           text,
  google_maps_url       text,          -- derived at read time; never stored
  worlds_50_best_rank   smallint,      -- empty on every hotel row
  worlds_50_best_year   smallint
);
```

`city_text` and `country_text` are the CSV's `city` and `country` columns, renamed on the way in so that no staging column shares a name with a production column it does not map to. `lat` and `lng` become `location` in §7.2.

```sql
\copy staging.staging_hotels FROM 'hotels_master.csv' WITH (FORMAT csv, HEADER true)
```

### 5.2 `staging_restaurants`

```sql
CREATE TABLE staging.staging_restaurants (
  id                    text,
  restaurant_code       text NOT NULL,
  name                  text NOT NULL,
  michelin_stars        smallint NOT NULL,   -- 0 becomes NULL in §7.5
  cuisine               text,
  city_text             text NOT NULL,
  country_text          text NOT NULL,
  country_flag          text,
  address               text NOT NULL,
  lat                   double precision NOT NULL,
  lng                   double precision NOT NULL,
  google_place_id       text,
  michelin_url          text,
  website_url           text,
  booking_url           text,
  google_maps_url       text,
  located_in_hotel      boolean,             -- derived in the view; never stored
  property_name         text,
  worlds_50_best_rank   smallint,
  worlds_50_best_year   smallint
);
```

Load both `restaurants_master.csv` and `restaurants_pending_manual_review.csv` into this table. The pending file has four extra columns describing why the row was held; ignore them, and read §7.4 before loading it.

**Do not drop `staging_restaurants` after §7.** §8.2 reads `worlds_50_best_rank` from it. Drop the whole staging schema at the end of §9.

### 5.3 `staging_links`

```sql
CREATE TABLE staging.staging_links (
  link_id            text NOT NULL,
  hotel_code         text NOT NULL,
  hotel_name         text,   -- discarded
  restaurant_code    text NOT NULL,
  restaurant_name    text,   -- discarded
  michelin_stars     smallint,
  link_confidence    text NOT NULL,
  evidence           text,
  hotel_address      text,   -- discarded
  restaurant_address text,   -- discarded
  hotel_city         text,   -- discarded
  restaurant_city    text,   -- discarded
  country            text    -- discarded
);
```

Eight of the thirteen columns exist for human review of the source file. Only `hotel_code`, `restaurant_code`, `link_confidence` and `evidence` reach the database.

### 5.4 `country_bounds`

Required by the coordinate check in §9.2, which is the only test that catches a reversed `ST_MakePoint`.

```sql
CREATE TABLE staging.country_bounds (
  country_code char(2) PRIMARY KEY,
  geom         geometry(Polygon, 4326) NOT NULL
);
```

Populate it by either route:

**From Natural Earth (preferred).** Download the 1:110m Admin 0 Countries shapefile from naturalearthdata.com, load with `shp2pgsql`, and insert the envelope of each country keyed on its ISO alpha-2 code. This gives a real boundary for all 43 countries.

**From a bounding-box list.** If no GIS tooling is available, insert a rectangle per country from any published min/max latitude and longitude table:

```sql
INSERT INTO staging.country_bounds (country_code, geom) VALUES
  ('CH', ST_MakeEnvelope(5.96, 45.82, 10.49, 47.81, 4326)),
  ('NL', ST_MakeEnvelope(3.36, 50.75,  7.23, 53.56, 4326));
  -- one row per country present in the catalogue
```

An envelope is coarser than a boundary and will pass a point that is offshore but within the rectangle. That is acceptable: the failure this check exists to catch moves a European venue into the Indian Ocean, which no envelope contains.

**A country with no row is not checked.** Assert coverage before trusting the result:

```sql
SELECT DISTINCT country_text FROM staging.staging_hotels
 EXCEPT SELECT c.name FROM staging.country_bounds b JOIN countries c USING (country_code);
```

---

## 6. Reference table import

Reference tables are derived from the source files, not supplied separately.

### 6.1 `countries`

43 rows. Extract the distinct set of `country` and `country_flag` pairs across both catalogue files, map each to its ISO 3166-1 alpha-2 code, and insert.

Hong Kong is `HK`, Macau is `MO`, Monaco is `MC`, the Faroe Islands are `FO`. Each is its own country. Do not fold any of them into a parent state.

### 6.2 `cities`

614 rows. Extract distinct `(country, city)` pairs across both files; 77 pairs occur in both.

Three columns are not present in the source and must be populated here:

- **`region`** — required for federal countries. The United States spans 13 guide jurisdictions and is currently distinguishable only by city string.
- **`michelin_guide_edition`** — the guide covering the city, not the country.
- **`postal_municipality`** — where it differs from the destination name.

Two Japanese cities were inferred from a prefecture and are unconfirmed: Satoyama Jujo under Minamiuonuma and Oyado The Earth under Toba.

Retire the `Washington (Virginia)` workaround here: create two rows named `Washington`, one with `region = 'District of Columbia'` and one with `region = 'Virginia'`.

### 6.3 `cuisines`

146 rows from the distinct non-null `cuisine` values. 170 restaurants have no cuisine and take a null `cuisine_id`.

---

## 7. Catalogue import

### 7.1 UUID strategy

**Insert from staging with `id` absent from the column list and let PostgreSQL assign.**

```sql
INSERT INTO hotels (hotel_code, name, michelin_keys, address,
                    google_place_id, michelin_url, website_url, booking_url)
SELECT hotel_code, name, michelin_keys, address,
       nullif(google_place_id,''), nullif(michelin_url,''),
       nullif(website_url,''), nullif(booking_url,'')
  FROM staging.staging_hotels;
```

`nullif(col,'')` is required on every nullable text column. `COPY` reads an empty CSV field as an empty string, not as `NULL`, and an empty string satisfies a `UNIQUE` constraint only once — the second empty `google_place_id` raises a duplicate key error that reads as though the data contains a real collision.

`city_id`, `country_code` and `location` are populated in §7.2 and §7.3, so both columns are created `NULL`-able and set to `NOT NULL` afterwards.

The `id` column is present and empty in the source files. Never write a UUID into a source file. Two identifiers exist deliberately: `id` is internal and generated, `hotel_code` and `restaurant_code` are the external keys that every QA entry and manual action references.

Do not mix UUID strategies. An earlier pass produced deterministic v5 UUIDs on some rows; all of them were cleared. If deterministic UUIDs are ever wanted, they must be regenerated for every row from a recorded namespace, never for a subset.

### 7.2 Building `location`

Coordinates arrive as `lat` and `lng` on the staging tables defined in §5.1 and §5.2. No temporary column is added to the production table.

```sql
UPDATE hotels h
   SET location = ST_SetSRID(ST_MakePoint(s.lng, s.lat), 4326)::geography
  FROM staging.staging_hotels s
 WHERE s.hotel_code = h.hotel_code;

ALTER TABLE hotels ALTER COLUMN location SET NOT NULL;
```

Identical for `restaurants`, joining on `restaurant_code`.

**`ST_MakePoint` takes longitude first.** Reversing the arguments produces coordinates that are silently valid — every row lands somewhere — and puts European venues in the Indian Ocean. Verify with §10.2 before dropping the staging columns.

### 7.3 Resolving `city_id` and `country_code`

The source files carry city and country as text. Resolve them through the reference tables:

The catalogue tables have no `city_text` or `country_text`; those columns live on the staging tables. Resolve through staging:

```sql
UPDATE restaurants r
   SET city_id      = c.id,
       country_code = n.country_code
  FROM staging.staging_restaurants s
  JOIN countries n ON n.name  = s.country_text
  JOIN cities    c ON c.name  = s.city_text
                  AND c.country_code = n.country_code
 WHERE s.restaurant_code = r.restaurant_code;

ALTER TABLE restaurants ALTER COLUMN city_id SET NOT NULL,
                        ALTER COLUMN country_code SET NOT NULL;
```

Join `cities` on `country_code` as well as `name`. No city name occurs in more than one country in the launch data, so a name-only join would in fact succeed today — but `cities` is unique on `(country_code, name, region)`, not on `name`, so nothing in the schema guarantees that. The first city added to a second country would attach venues to the wrong one silently, and the import would not fail.

Any row left with a null `city_id` is a reference-table gap, not a data error. Fix the reference table and re-run. Set `NOT NULL` only once no nulls remain — the `ALTER` fails otherwise, which is the intended safeguard.

### 7.4 La Paix

`rest_0158` is imported from the pending file with:

- `status = 'temporarily_closed'`
- `status_note = 'Relocating to Corinthia Grand Hotel Astoria Brussels'`
- `status_since` set to the date MICHELIN reported the closure
- two stars, `inclusion_reason = 'michelin_star'`

**Its stored address is wrong.** The row's city correctly reads Anderlecht while its address, coordinates and Place ID point to Rue Royale 103 in central Brussels — four kilometres away and a different property. QA-054 records the correct Anderlecht street.

Import the corrected Anderlecht address. If coordinates for it are not available, hold the row out entirely rather than importing the Brussels values to satisfy a `NOT NULL` column. A constraint satisfied by known-incorrect data offers no protection. See `ARCHITECTURE_REVIEW.md` §2.

On reopening: set `status = 'open'`, update the address, and create the link row to `hotel_153`.

### 7.5 `michelin_stars`

Seven rows carry `0` in the source. **Convert to `NULL`** with `inclusion_reason = 'worlds_50_best'`:

```sql
UPDATE restaurants
   SET michelin_stars = NULL, inclusion_reason = 'worlds_50_best'
 WHERE michelin_stars = 0;
```

Every other row keeps `inclusion_reason = 'michelin_star'`. The `CHECK (michelin_stars BETWEEN 1 AND 3)` makes zero unrepresentable afterwards, so this conversion cannot be undone by a later import.

---

## 8. Relationship import

Join on the codes; store the UUIDs.

```sql
INSERT INTO hotel_restaurants (hotel_id, restaurant_id, link_confidence, evidence, verified_at)
SELECT h.id, r.id, lower(l.link_confidence), l.evidence, now()
  FROM staging.staging_links l
  JOIN hotels      h ON h.hotel_code      = l.hotel_code
  JOIN restaurants r ON r.restaurant_code = l.restaurant_code;
```

68 rows in, 68 rows out. Any shortfall is an unresolved code and must be investigated, not ignored.

**Never carry `hotel_code` or `restaurant_code` into the join table as foreign keys.** They exist to resolve the join at load time and nothing more.

The source file carries eight denormalised copies — `hotel_name`, `restaurant_name`, `michelin_stars`, both addresses, both cities and `country`. Discard all eight. They exist for human review of the source and have no place in the database.

`link_confidence` is lower-cased on the way in to match the CHECK constraint.

---

## 9. Award seeding

### 9.1 `award_history`

1 455 rows: one per current award.

```sql
INSERT INTO award_history (entity_type, entity_id, guide_year, award_type, award_value, is_current)
SELECT 'hotel', id, 2026, 'michelin_keys', michelin_keys, true FROM hotels;

INSERT INTO award_history (entity_type, entity_id, guide_year, award_type, award_value, is_current)
SELECT 'restaurant', id, 2026, 'michelin_stars', michelin_stars, true
  FROM restaurants WHERE michelin_stars IS NOT NULL;
```

687 hotel rows plus 768 restaurant rows. The seven null-star restaurants are excluded: they hold no MICHELIN award, so there is nothing to record.

### 9.2 `worlds_50_best`

50 rows, all `year = 2025`, ranks 1 through 50 with no gaps.

```sql
INSERT INTO worlds_50_best (restaurant_id, year, rank, list_type)
SELECT r.id, s.worlds_50_best_year, s.worlds_50_best_rank, 'top_50'
  FROM staging.staging_restaurants s
  JOIN restaurants r ON r.restaurant_code = s.restaurant_code
 WHERE s.worlds_50_best_rank IS NOT NULL;
```

**Hall of Fame rows.** Eleven restaurants are members. Six are in the catalogue — The French Laundry, El Celler de Can Roca, Osteria Francescana, Eleven Madison Park, Geranium and Disfrutar. Seed one row each with `rank = NULL` and `list_type = 'hall_of_fame'`, dated to the induction year.

The induction year is not the year the restaurant was ranked No.1. The group was introduced in 2019, so every pre-2019 winner was elevated then; later winners are elevated when the following year's list publishes. Confirm each one before seeding — this is MA-075.

The remaining five members have no catalogue row and cannot be seeded: El Bulli, The Fat Duck, Noma, Mirazur and Central. Membership and No.1 years for all eleven are recorded in `worlds_50_best_hall_of_fame.csv`. Tracked as MA-074.

**Never seed a Hall of Fame row for the reigning No.1.** A winner is elevated only when the following year's list publishes, so at seed time it holds a rank and nothing more. The induction is handled by the annual refresh — see `DATA_UPDATE_PROCESS.md` §4.

The two ranking columns are empty on all 687 hotel rows and were never meaningful there; the ranking is a restaurant award. They are not carried into `hotels`.

---

## 10. Validation queries

Run every one. All must return zero rows except where stated.

### 10.1 Referential integrity

```sql
SELECT * FROM restaurants WHERE city_id IS NULL OR country_code IS NULL;
SELECT * FROM hotels      WHERE city_id IS NULL OR country_code IS NULL;

SELECT hr.* FROM hotel_restaurants hr
  LEFT JOIN hotels h ON h.id = hr.hotel_id
  LEFT JOIN restaurants r ON r.id = hr.restaurant_id
 WHERE h.id IS NULL OR r.id IS NULL;
```

### 10.2 Coordinates

The check that catches a reversed `ST_MakePoint`:

```sql
SELECT h.hotel_code, h.name, c.name AS country,
       ST_Y(h.location::geometry) AS lat, ST_X(h.location::geometry) AS lng
  FROM hotels h JOIN countries c ON c.country_code = h.country_code
 WHERE NOT ST_Intersects(h.location::geometry,
                         (SELECT b.geom FROM staging.country_bounds b
                           WHERE b.country_code = h.country_code));
```

`country_bounds` is defined and populated in §5.4. A country absent from it is not checked, so run the coverage assertion in §5.4 first.

If `country_bounds` was not built, this coarse version catches a full coordinate swap across the six largest European markets and nothing else:

```sql
SELECT hotel_code, name FROM hotels
 WHERE country_code IN ('CH','AT','DE','IT','NL','BE')
   AND NOT (ST_Y(location::geometry) BETWEEN 35 AND 60
        AND ST_X(location::geometry) BETWEEN -5 AND 20);
```

### 10.3 Award values

```sql
SELECT * FROM hotels      WHERE michelin_keys NOT BETWEEN 1 AND 3;
SELECT * FROM restaurants WHERE michelin_stars IS NOT NULL
                            AND michelin_stars NOT BETWEEN 1 AND 3;
SELECT * FROM restaurants WHERE michelin_stars = 0;   -- must be impossible
```

### 10.4 Place IDs

Unique within a table, shared across tables by design.

```sql
SELECT google_place_id, count(*) FROM hotels
 WHERE google_place_id IS NOT NULL GROUP BY 1 HAVING count(*) > 1;

-- Expected: exactly 10 rows. Not an error.
SELECT h.name, r.name FROM hotels h
  JOIN restaurants r ON r.google_place_id = h.google_place_id;
```

### 10.5 Relationship rules

No restaurant may be in a Key hotel and a non-Key hotel at once:

```sql
SELECT r.restaurant_code, r.name FROM restaurants r
  JOIN hotel_restaurants hr ON hr.restaurant_id = r.id
 WHERE r.property_name IS NOT NULL;
```

The non-Key cohort must be 33:

```sql
SELECT count(*) FROM restaurants WHERE property_name IS NOT NULL;
```

### 10.6 Denormalised country agreement

`hotels.country_code` and `restaurants.country_code` are denormalised copies of the country reachable through `city_id`. No constraint enforces agreement, by design — see `DATABASE_ARCHITECTURE.md` §3.2. Both queries must return zero rows.

```sql
SELECT h.hotel_code, h.country_code AS on_hotel, c.country_code AS on_city
  FROM hotels h JOIN cities c ON c.id = h.city_id
 WHERE h.country_code <> c.country_code;

SELECT r.restaurant_code, r.country_code AS on_restaurant, c.country_code AS on_city
  FROM restaurants r JOIN cities c ON c.id = r.city_id
 WHERE r.country_code <> c.country_code;
```

A row returned here means a country filter and the map disagree about the same venue.

### 10.7 Row counts

| Table | Expected |
|---|---|
| `countries` | 43 |
| `cities` | 614 |
| `cuisines` | 146 |
| `hotels` | 687 |
| `restaurants` | 775 |
| `hotel_restaurants` | 68 |
| `award_history` | 1 455 |
| `worlds_50_best` | 50 |

### 10.8 Award distribution

```sql
SELECT michelin_keys, count(*) FROM hotels GROUP BY 1 ORDER BY 1;
-- 1 → 490, 2 → 161, 3 → 36

SELECT coalesce(michelin_stars::text, 'null'), count(*) FROM restaurants GROUP BY 1 ORDER BY 1;
-- 1 → 306, 2 → 341, 3 → 121, null → 7
```

---

## 11. Rollback

Every step of the build runs inside one transaction:

```sql
BEGIN;
-- extensions, types, tables, loads, seeds
-- run §10 validation
COMMIT;   -- or ROLLBACK
```

Extensions cannot be created inside a transaction on some managed platforms. Run §1 separately and treat it as idempotent; `CREATE EXTENSION IF NOT EXISTS` is safe to repeat.

If the build is already committed and must be undone:

```sql
DROP SCHEMA IF EXISTS staging CASCADE;
DROP TABLE IF EXISTS worlds_50_best, award_history, hotel_restaurants,
                     restaurants, hotels, cuisines, cities, countries CASCADE;
DROP TYPE IF EXISTS venue_status;
DROP FUNCTION IF EXISTS public.profile_is_visible(uuid);
```

On a successful build, drop the staging schema once §10 passes:

```sql
DROP SCHEMA staging CASCADE;
```

**Never drop the catalogue once user tables carry data.** `visits`, `wishlist` and `photos` reference venues polymorphically through `entity_type` and `entity_id`, so no foreign key protects them and `CASCADE` will not clean up after itself. A dropped and rebuilt catalogue assigns new UUIDs, and every visit in the database silently points at nothing.

If the catalogue must be rebuilt after launch, rebuild it into new tables, remap `visits.entity_id` through `restaurant_code`, and swap. That is why the codes exist.

---

## 12. Common mistakes

**Reversed coordinates.** `ST_MakePoint(lng, lat)`, not `(lat, lng)`. Every row remains valid and every venue moves. §10.2 catches it.

**Writing UUIDs into the source files.** The `id` column stays empty. A source file carrying UUIDs cannot be re-imported into a fresh database without collisions.

**Carrying codes into `hotel_restaurants`.** The codes resolve the join at load time. Storing them creates a second join path that will eventually disagree with the first.

**Storing zero stars.** Seven rows arrive as `0` and must become `NULL`. Zero asserts that MICHELIN assessed the venue and awarded nothing, which is false for six of the seven.

**Rendering a null star count as "no award".** This is an interface bug, not an import bug, but it originates here. Maido was the best restaurant in the world in 2025 and holds no star.

**A cross-table unique index on `google_place_id`.** Ten Place IDs are legitimately shared between a hotel row and a restaurant row. The index will reject all ten and the failure looks like duplicate data.

**Matching on name.** Four names collide inside a single country. La Brezza appears twice in Switzerland at different star counts; merging them by name destroys one award value.

**Importing La Paix with its stored address.** See §7.4.

**Leaving RLS until later.** Every table in `public` is writable by the `anon` key until policies exist, and that key is in the app binary. Step 11 is part of the build, not a hardening pass.

**Empty strings instead of nulls.** `COPY` reads an empty CSV field as `''`. On a `UNIQUE` column the second empty value raises a duplicate key error that looks like a data collision. Wrap every nullable text column in `nullif(col,'')`.

**Resolving a city by name alone.** `cities` is unique on `(country_code, name, region)`, not on `name`. The launch data happens to contain no cross-country collision, so a name-only join passes now and breaks silently on the first country added.

**Skipping the `evidence` column on links.** It is not decorative — it has already caught two incorrect links, and every future import produces uncertain matches that need it. 