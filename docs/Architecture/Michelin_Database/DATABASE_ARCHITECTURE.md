# Database Architecture

Michelin Passport — production schema reference.

This document is authoritative for table structure, constraints, indexes, data conventions and the security model. Procedure for building the database is in `DATABASE_IMPORT_GUIDE.md`; for maintaining it, `DATA_UPDATE_PROCESS.md`; for environments, secrets and operations, `DEPLOYMENT.md`. Dataset statistics and row counts are authoritative in `VALIDATION_REPORT.md`, so counts are avoided here except where a number is part of a rule.

Target platform: PostgreSQL 15 or later on Supabase, with PostGIS.

---

## 1. Data model

Eleven tables in three groups.

**Reference** — `countries`, `cities`, `cuisines`
**Catalogue** — `hotels`, `restaurants`, `hotel_restaurants`, `award_history`, `worlds_50_best`
**User** — `profiles`, `visits`, `wishlist`, `photos`, `follows`

The catalogue is read-only to the application. Only the maintenance process writes to it.

---

## 2. Reference tables

### 2.1 `countries`

One row per country. Holds the flag emoji and any country-level metadata so it is stored once rather than on every venue row.

| Column | Type | Notes |
|---|---|---|
| `country_code` | `char(2)` PRIMARY KEY | ISO 3166-1 alpha-2 |
| `name` | `text NOT NULL UNIQUE` | English name |
| `flag_emoji` | `text NOT NULL` | |

Country is **geographic, never editorial**. Monaco, Hong Kong, Macau and the Faroe Islands each hold their own row and their own flag, although MICHELIN files them under the France, Hong Kong & Macau and Nordic guides respectively. Guide edition is a property of a city, not a country — see §2.2.

Expected national totals are deliberately absent. A national total is not a meaningful figure when a country spans several guide editions, and it is verified for only 12 countries for hotels and 14 for restaurants. Where a total is unknown the interface renders **Unknown**, never a computed percentage.

### 2.2 `cities`

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid PRIMARY KEY DEFAULT gen_random_uuid()` | |
| `country_code` | `char(2) NOT NULL REFERENCES countries` | |
| `name` | `text NOT NULL` | MICHELIN destination name |
| `postal_municipality` | `text` | administrative name where it differs |
| `region` | `text` | state, province, prefecture, canton, autonomous community |
| `michelin_guide_edition` | `text` | the guide jurisdiction covering this city |

Constraint and indexes:

```sql
CREATE UNIQUE INDEX cities_unique_key ON cities (
    country_code, name, coalesce(region, '')
);
CREATE INDEX ON cities (country_code, region);
CREATE INDEX ON cities (michelin_guide_edition);
```

`name` holds the name a traveller searches for: Capri not Anacapri, Hakone not Hakonemachi Ashigarashimo-gun, Kyoto not Kyoto Prefecture. `postal_municipality` preserves the administrative form for address validation.

`region` lives here and nowhere else. It is determined by the place, not the business, so storing it on a venue row would duplicate one fact across every catalogue row and allow the two catalogue tables to disagree.

`michelin_guide_edition` resolves the reconciliation problem: Tokyo → Tokyo, San Francisco → California, Monaco → France, Tórshavn → Nordic Countries. Any progress figure quoting a MICHELIN total must group by edition, not by country.

The unique index uses `coalesce(region, '')` rather than a plain `UNIQUE (country_code, name, region)`. A plain constraint treats NULLs as distinct, so it would permit two `Kyoto` rows with a null region. See `ARCHITECTURE_REVIEW.md` §1.

### 2.3 `cuisines`

| Column | Type |
|---|---|
| `id` | `smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY` |
| `name` | `text NOT NULL UNIQUE` |

Populated from the distinct cuisine values in the source data.

---

## 3. Catalogue tables

### 3.1 `venue_status`

```sql
CREATE TYPE venue_status AS ENUM ('open', 'temporarily_closed', 'permanently_closed');
```

Three values, applied identically to hotels and restaurants. Status answers exactly one question: can a guest be served there now.

This is the schema's only enumerated type; every other constrained vocabulary is `text` with a `CHECK`. The difference is deliberate. `status` is read on nearly every catalogue query and is the one such column that benefits from a four-byte fixed representation and index-friendly ordering. The other vocabularies are written by the maintenance process and read rarely.

To add a value: `ALTER TYPE venue_status ADD VALUE 'seasonal_closure';` This is permitted inside a transaction on PostgreSQL 12 and later, but the new value cannot be used in the same transaction that adds it. A value cannot be removed once added, so add sparingly. Relocation is not a status — it is an address change, and a venue in the middle of one is `temporarily_closed` with the explanation in `status_note`.

A `permanently_closed` venue is never deleted. Visits reference it indefinitely.

### 3.2 `hotels`

One row per MICHELIN Key hotel.

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid PRIMARY KEY DEFAULT gen_random_uuid()` | |
| `hotel_code` | `text NOT NULL UNIQUE` | stable external key, `hotel_001` |
| `name` | `text NOT NULL` | |
| `michelin_keys` | `smallint NOT NULL CHECK (michelin_keys BETWEEN 1 AND 3)` | current value |
| `city_id` | `uuid NOT NULL REFERENCES cities` | |
| `country_code` | `char(2) NOT NULL REFERENCES countries` | denormalised for country filters |
| `address` | `text NOT NULL` | native language and script |
| `location` | `geography(Point,4326) NOT NULL` | |
| `google_place_id` | `text UNIQUE` | |
| `michelin_url` | `text UNIQUE` | |
| `website_url` | `text` | |
| `booking_url` | `text` | |
| `status` | `venue_status NOT NULL DEFAULT 'open'` | |
| `status_since` | `date` | |
| `status_note` | `text` | |
| `created_at` | `timestamptz NOT NULL DEFAULT now()` | |
| `updated_at` | `timestamptz NOT NULL DEFAULT now()` | maintained by trigger |

### 3.3 `restaurants`

One row per MICHELIN-starred restaurant or World's 50 Best entry.

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid PRIMARY KEY DEFAULT gen_random_uuid()` | |
| `restaurant_code` | `text NOT NULL UNIQUE` | stable external key, `rest_0001` |
| `name` | `text NOT NULL` | |
| `michelin_stars` | `smallint` | NULL where the venue does not currently hold a star — see below |
| `inclusion_reason` | `text NOT NULL DEFAULT 'michelin_star'` | why the row exists |
| `cuisine_id` | `smallint REFERENCES cuisines` | |
| `city_id` | `uuid NOT NULL REFERENCES cities` | |
| `country_code` | `char(2) NOT NULL REFERENCES countries` | |
| `address` | `text NOT NULL` | |
| `location` | `geography(Point,4326) NOT NULL` | |
| `google_place_id` | `text UNIQUE` | |
| `michelin_url` | `text UNIQUE` | |
| `website_url` | `text` | |
| `booking_url` | `text` | |
| `property_name` | `text` | name of a non-Key hotel; free text |
| `status` | `venue_status NOT NULL DEFAULT 'open'` | |
| `status_since` | `date` | |
| `status_note` | `text` | |
| `created_at` / `updated_at` | `timestamptz` | |

```sql
CONSTRAINT michelin_stars_valid
    CHECK (michelin_stars IS NULL OR michelin_stars BETWEEN 1 AND 3),
CONSTRAINT inclusion_reason_valid
    CHECK (inclusion_reason IN ('michelin_star', 'worlds_50_best',
                                'hall_of_fame', 'bib_gourmand'))
```

**`michelin_stars` is NULL, never zero.** **A NULL `michelin_stars` means the venue does not currently hold a MICHELIN star.** It covers two situations: venues in countries where MICHELIN awards no stars, and venues inside a covered guide that are currently unstarred. `inclusion_reason` records why the row exists and is what distinguishes the two.

Zero is not used because it would assert that MICHELIN assessed the venue and awarded nothing, which is false for every row in the first situation, and because a zero drags any average computed across the column.

At launch seven rows carry NULL: six in Peru, Chile and Colombia, where MICHELIN awards no stars at all, and one — Wing, Hong Kong — inside a covered guide and unstarred.

**Interface contract, non-negotiable:** a null star count must never render as "no award" or as an empty star row. Render the World's 50 Best rank instead. Maido was the best restaurant in the world in 2025.

**Scope rule.** A restaurant qualifies for a row if it meets any of three conditions:

1. it holds at least one MICHELIN star;
2. it appears on the current World's 50 Best list;
3. it is a member of the World's 50 Best **Best of the Best** hall of fame.

The third condition is deliberately narrow. It admits only restaurants that have been ranked No.1, currently eleven, growing by one a year — not every restaurant that has ever appeared in the top 50, which would admit several hundred. Hall of fame members are ineligible for the annual ranking by construction, so without this clause the most celebrated restaurants in the list's history would be the ones it excluded.

Unstarred MICHELIN Guide entries, including Bib Gourmand, are out of scope. `inclusion_reason` already permits `bib_gourmand` so that admitting them later needs no migration.

`inclusion_reason` carries one value per row, matching the three qualifying conditions above plus the reserved fourth. It records the **primary** reason the row exists, not the complete set: a restaurant holding three stars and a current ranking reads `michelin_star`. To find current World's 50 Best restaurants, query the `worlds_50_best` table — filtering `inclusion_reason` returns only those that would not otherwise qualify.

### 3.4 `hotel_restaurants`

The only place a hotel-restaurant relationship is stored.

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid PRIMARY KEY DEFAULT gen_random_uuid()` | |
| `hotel_id` | `uuid NOT NULL REFERENCES hotels ON DELETE CASCADE` | |
| `restaurant_id` | `uuid NOT NULL REFERENCES restaurants ON DELETE CASCADE` | |
| `link_confidence` | `text NOT NULL` | `exact`, `campus`, `manual_review` |
| `evidence` | `text` | why the link exists |
| `verified_at` | `timestamptz` | |
| | | `UNIQUE (hotel_id, restaurant_id)` |

```sql
CHECK (link_confidence IN ('exact', 'campus', 'manual_review'))
```

Every relationship in the launch dataset is `exact`. The other two values are retained deliberately: every future import runs an address matcher that produces uncertain matches, and `link_confidence` with `evidence` is how a human confirmation is recorded. `evidence` has already caught two incorrect links and is not decorative.

A hotel may hold several restaurants; at least one already does. A restaurant belongs to at most one hotel today, but that is not constrained: IGNIV by Andreas Caminada operates in three separate Swiss locations, and a brand appearing in two Key hotels is a legitimate future state.

### 3.5 `award_history`

| Column | Type |
|---|---|
| `id` | `uuid PRIMARY KEY DEFAULT gen_random_uuid()` |
| `entity_type` | `text NOT NULL CHECK (entity_type IN ('hotel','restaurant'))` |
| `entity_id` | `uuid NOT NULL` |
| `guide_year` | `smallint NOT NULL` — see below |
| `award_type` | `text NOT NULL CHECK (award_type IN ('michelin_keys','michelin_stars'))` |
| `award_value` | `smallint` — NULL means the venue held no award that year |
| `is_current` | `boolean NOT NULL DEFAULT false` |
| `announced_on` | `date` |
| | `UNIQUE (entity_type, entity_id, guide_year, award_type)` |

```sql
CREATE INDEX ON award_history (entity_type, entity_id);
CREATE UNIQUE INDEX ON award_history (entity_type, entity_id, award_type) WHERE is_current;
```

**`guide_year` is the MICHELIN Guide edition in which an award value became effective. It is not the year the row was written.**

A row is created when an award changes, not on a schedule. A venue whose award has not moved since 2026 therefore carries one row, reading 2026, however many guide editions have published since.

The rows seeded at launch all carry `guide_year = 2026`. That is a launch limitation, not historical truth: the awards these venues held before 2026 were not recoverable when the catalogue was built. A query of the form "how long has this venue held three stars" returns 2026 for every seeded venue and is only meaningful for changes recorded after launch. State that in the interface or do not build the feature.

MICHELIN publishes roughly fifteen guide jurisdictions with independent ceremony dates, so award changes are a near-continuous stream rather than an annual event. The moment a new guide overwrites `restaurants.michelin_stars`, the previous value is unrecoverable — a backup restores a row, not a field's timeline.

`hotels.michelin_keys` and `restaurants.michelin_stars` remain on the catalogue tables as the fast path for lists and filters. This is the schema's one deliberate denormalisation. It is safe because the entity value is authoritative and history is append-only; the partial unique index guarantees exactly one current row per entity per award type.

This is distinct from `visits.stars_at_visit`, which freezes the award at the moment of a meal. That field records the user's experience; `award_history` records the venue's timeline.

### 3.6 `worlds_50_best`

| Column | Type |
|---|---|
| `id` | `uuid PRIMARY KEY DEFAULT gen_random_uuid()` |
| `restaurant_id` | `uuid NOT NULL REFERENCES restaurants ON DELETE CASCADE` |
| `year` | `smallint NOT NULL` |
| `rank` | `smallint` — NULL for hall of fame |
| `list_type` | `text NOT NULL DEFAULT 'top_50'` |
| | `UNIQUE (restaurant_id, year)` |

```sql
CHECK (list_type IN ('top_50', 'extended_51_100', 'hall_of_fame'))
CREATE UNIQUE INDEX ON worlds_50_best (year, rank) WHERE rank IS NOT NULL;
CREATE INDEX ON worlds_50_best (restaurant_id);
```

A ranking is a yearly event, not a property of a restaurant. One row per restaurant per year; a restaurant absent from a year's list simply has no row for that year. Never store a zero or a null rank to represent absence.

Hall of Fame is a `list_type`, not a boolean. A restaurant is inducted once, gains a row in the induction year with a null rank, and has no rows afterwards because it is no longer eligible. Eleven restaurants are members; six hold three MICHELIN stars and are already in the catalogue. Membership is `EXISTS (… WHERE list_type = 'hall_of_fame')`, which is permanent by construction.

The two award systems are kept apart because they are opposed scales. A MICHELIN star is an ordinal tier where higher is better; a 50 Best rank is a position where lower is better. Folding them into one `award_value` column would make `ORDER BY award_value DESC` correct for one and wrong for the other.

---

## 4. User tables

**`profiles`** — `id uuid PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE`, `username text UNIQUE`, `display_name text`, `avatar_url text`, `home_country_code char(2) REFERENCES countries`, `is_public boolean NOT NULL DEFAULT true`, `created_at timestamptz NOT NULL DEFAULT now()`. Created by trigger — see §4.1.

### 4.1 Profile bootstrap

**A `profiles` row is created by a trigger on `auth.users`, not by the application.**

This is not optional and it is not a convenience. Every read policy on a user table calls `profile_is_visible(user_id)` (§15.3), which returns false when no profile row exists. A signed-up user without a profile row can read none of their own visits, wishlist or photos — and the failure presents as an empty application rather than an error, so it is expensive to diagnose.

```sql
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO profiles (id, username)
  VALUES (NEW.id, NEW.raw_user_meta_data ->> 'username');
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

`SECURITY DEFINER` is required: the trigger runs in the context of the signing-up user, who has no rights on `profiles`. `SET search_path = public` is required for the same reason it is required in §15.3.

**Username.** `username` is nullable and is left NULL when the client does not supply one at signup. `raw_user_meta_data ->> 'username'` returns NULL for an absent key, so the same trigger serves both flows without branching.

A profile with a NULL username is valid and fully functional — every policy keys on `id`, never on `username`. The application prompts for one when it is needed, and sets it with an ordinary `UPDATE` under the `profiles_update` policy.

**The UNIQUE constraint is enforced at update, not at signup.** `username text UNIQUE` permits multiple NULLs, because PostgreSQL treats NULLs as distinct in a unique constraint — the one place that behaviour is wanted rather than worked around (contrast §2.2).

Do not validate uniqueness by querying `profiles` before the `UPDATE`: the read policy hides other users' private rows, so the check returns "available" for a name that is taken, and the `UPDATE` then fails anyway. Attempt the `UPDATE`, catch SQLSTATE `23505`, and surface it as "username taken". The constraint is the check.

Never put username selection inside the signup trigger. A `23505` raised there aborts the `auth.users` insert, and the account is not created at all.

---

**`visits`** — one row per visit, so a second dinner is a second row.

| Column | Type |
|---|---|
| `id` | `uuid PRIMARY KEY DEFAULT gen_random_uuid()` |
| `user_id` | `uuid NOT NULL REFERENCES profiles ON DELETE CASCADE` |
| `entity_type` | `text NOT NULL CHECK (entity_type IN ('hotel','restaurant'))` |
| `entity_id` | `uuid NOT NULL` |
| `visited_on` | `date NOT NULL` |
| `rating` | `smallint CHECK (rating BETWEEN 1 AND 10)` |
| `notes` | `text` |
| `price_paid` | `numeric` |
| `currency` | `char(3)` |
| `keys_at_visit` / `stars_at_visit` | `smallint` — the award frozen as it stood |

**`wishlist`** — `user_id`, `entity_type`, `entity_id`, `added_at`, `priority smallint`, `UNIQUE (user_id, entity_type, entity_id)`.

**`photos`** — `id`, `user_id`, `visit_id uuid REFERENCES visits`, `entity_type`, `entity_id`, `storage_path text NOT NULL`, `caption`, `taken_at`, `is_public`.

**`follows`** — `follower_id`, `following_id`, `created_at`, `UNIQUE (follower_id, following_id)`, `CHECK (follower_id <> following_id)`.

`visits`, `wishlist` and `photos` reference a venue polymorphically through `entity_type` and `entity_id`. The pattern is deliberate: it keeps one table per user concept instead of two, so "everything this user has visited" is one query rather than a `UNION`, and it is what makes a visit list orderable by date across both venue types.

**The cost is that PostgreSQL cannot enforce the reference.** A `DELETE` against `hotels` or `restaurants` will succeed and will silently orphan every visit, wishlist entry and photo that pointed at the row. There is no error and no recovery — a lost visit cannot be reconstructed.

Three things stand in for the missing foreign key, and all three are mandatory:

1. **The catalogue is append-and-amend only.** No process deletes a catalogue row. A closed venue takes a `status` — see §3.1.
2. **Only the service role can write to the catalogue** (§15), so an accidental delete cannot originate from the application.
3. **The regression suite scans for orphans** on every catalogue change (`DATA_UPDATE_PROCESS.md` §8), which converts a silent loss into a detected one.

Detection is only half of it. Recovery is a restore, so Point-in-Time Recovery is a hard requirement rather than a precaution — `DEPLOYMENT.md` §9.

A developer who needs to remove a catalogue row must migrate the dependent user rows first. `restaurant_code` and `hotel_code` exist partly to make that remap possible.

---

## 5. Views

**`restaurants_full`** — the application reads this, not `restaurants`.

It exposes every restaurant column plus:

| Derived column | Definition |
|---|---|
| `is_in_hotel` | `hotel_restaurants` row exists **or** `property_name` is not null |
| `hotel_name` | `hotels.name` through the link, falling back to `property_name` |
| `hotel_id` | the linked hotel, null when the property holds no Keys |
| `city_name`, `region`, `country_name`, `flag_emoji` | resolved through `cities` and `countries` |
| `worlds_50_best_rank` | current year's rank, null when unranked |

`is_in_hotel` is derived rather than stored. As a stored boolean it drifted twice: once contradicting the link table on 41 rows, and once leaving 3 rows claiming a hotel they did not have. A Postgres generated column cannot solve it, because the value depends on the existence of a row in another table. The join costs an indexed `EXISTS`.

**`hotels_full`** — the equivalent for hotels. It exposes every hotel column plus:

| Derived column | Definition |
|---|---|
| `has_michelin_restaurant` | a `hotel_restaurants` row exists for this hotel |
| `restaurant_count` | count of `hotel_restaurants` rows for this hotel |
| `city_name`, `region`, `country_name`, `flag_emoji` | resolved through `cities` and `countries` |

`has_michelin_restaurant` is `restaurant_count > 0` and is exposed separately because it is the value the list screen filters on. Neither is stored: both were removed from the `hotels` table during normalisation, and the join is an indexed lookup against a small table.

Aggregate statistics — visit counts, country progress, leaderboards — are materialised views, refreshed on a schedule by `pg_cron`. Each carries a unique index so that `REFRESH MATERIALIZED VIEW CONCURRENTLY` can be used; without `CONCURRENTLY` the refresh takes an `ACCESS EXCLUSIVE` lock and blocks every read for its duration. Schedule and procedure are in `DATA_UPDATE_PROCESS.md` §13.

`google_maps_url` is never stored. It is derived from `google_place_id`.

---

## 6. Relationship rules

Three rules govern hotel scope. They are mutually exclusive by construction.

1. `hotels` holds **only MICHELIN Key hotels**. No stub record is ever created for an unkeyed property.
2. `hotel_restaurants` holds **only verified links to Key hotels already present** in `hotels`. A link to a hotel that is not in the table is not a link.
3. A restaurant inside a **non-Key** hotel records the property in `restaurants.property_name` — no hotel row, no link row.

A restaurant is therefore in a Key hotel exactly when it has a link row, and in a non-Key hotel exactly when `property_name` is filled. The third case is well populated, concentrated in Hong Kong, Macau, Japan and the United States. `VALIDATION_REPORT.md` carries the current count and its distribution.

**`property_name` is free text and must never be joined on.** Five properties already host more than one starred restaurant; Four Seasons Hotel Hong Kong hosts three. If grouping by property becomes a feature, promote it to a lookup table first.

A starred restaurant inside a hotel is not evidence that the hotel holds a Key. Grand Hotel a Villa Feltrinelli hosts a starred restaurant and holds no Keys; there are five further examples in Tokyo alone.

---

## 7. Identifier and matching conventions

Every catalogue entity carries two identifiers, deliberately.

`id` is a UUID generated by PostgreSQL. It is the primary key, is never shown to a user and is never reused.

`hotel_code` and `restaurant_code` are the stable external keys. Every QA entry, manual action and source file references them. They survive re-imports and are what a developer greps for.

**Codes decide. Names may only propose.**

| Operation | Key |
|---|---|
| Foreign keys and joins | `id` |
| External reference, QA, source files | `hotel_code` / `restaurant_code` |
| Import matching | code where available; a name may generate a candidate for human confirmation only |
| Deduplication | code plus country — never name |
| User search | name, with mandatory city and country disambiguation in every result |
| Analytics and grouping | code |
| `property_name` | never joined on under any circumstance |

Nine rows share a name with another row across four names: IGNIV by Andreas Caminada, L'Atelier de Joël Robuchon, La Brezza and Noor. Four collide inside a single country. La Brezza appears twice in Switzerland — Arosa at three stars, Ascona at two, 130 km apart, because one chef cooks in each seasonally. Matching those two by name merges a three-star with a two-star.

A search for "La Brezza" must return two distinct cards, "La Brezza · Arosa ★★★" and "La Brezza · Ascona ★★", and the navigation argument must be `restaurant_code`.

**Always adopt MICHELIN's published name.** Following the publisher dissolves collisions without any matching logic: the Swiss two-star is *Da Vittorio - St. Moritz* and the Italian three-star is *Da Vittorio*, so they no longer collide at all.

---

## 8. Google Place ID rules

One Place ID per row, **unique within its own table and never across tables**.

Ten Place IDs are deliberately shared between a hotel row and a restaurant row, because the property is a single building with one Google record: Atrio, ABaC, Terra The Magic Place, Central Park, Söl'ring Hof, Château Neercanne, 7132 Hotel with 7132 Silver, Tschuggen Grand Hotel with La Brezza, Kanamean Nishitomiya, and Carlton Hotel St. Moritz with Da Vittorio - St. Moritz. A cross-table unique index rejects all ten.

Two rules learned from defects:

- Google frequently ranks a hotel's restaurant or spa above the hotel itself. Every hotel Place ID must be confirmed to resolve to the accommodation.
- Google has almost no commercial coverage in mainland China. Use Amap or Baidu there, or store name, city and award only.

---

## 9. MICHELIN URL rules

`michelin_url` is nullable and sparse. The numeric identifier inside a MICHELIN URL cannot be derived from a name, so each one requires an individual lookup.

Treat it as enrichment, never as identity, and never as a join key. MICHELIN blocks automated fetching, which is why most rosters in this project were captured manually.

---

## 10. Nullability

**Never null:** `hotel_code`, `restaurant_code`, `name`, `city_id`, `country_code`, `address`, `location`, `status`, `inclusion_reason`, `michelin_keys`.

**Nullable by design:** every URL field, `cuisine_id`, `google_place_id`, `property_name`, `region`, `postal_municipality`, `michelin_guide_edition`, `status_since`, `status_note`.

**`michelin_stars` is nullable**, and its null carries meaning — see §3.3.

`property_name` is null for every restaurant that is not inside a non-Key hotel. That is the point: a filled value means non-Key, a link row means Key, neither means no hotel.

---

## 11. Naming conventions

Tables plural and snake_case. Columns snake_case. Booleans read as assertions: `is_in_hotel`, `is_public`, `is_current`. Timestamps end `_at`, dates end `_on`. Foreign keys are `<singular_table>_id`. Never abbreviate — `restaurant_id`, not `rest_id`.

`region` is the neutral term for a US state, a Canadian province, a Japanese prefecture, a Swiss canton, a Spanish autonomous community and an Italian region alike.

**The two external codes predate this convention and are frozen.** `hotel_code` is `hotel_` plus three digits (`hotel_001`); `restaurant_code` is `rest_` plus four digits (`rest_0001`). The prefixes disagree in style and the widths disagree in size, and neither may be changed: The QA log and the manual-action list reference them throughout, and surviving unchanged is the entire purpose of an external key. A script formatting an identifier must use `hotel_%03d` and `rest_%04d`. The "never abbreviate" rule governs schema identifiers only.

---

## 12. Indexes

```sql
CREATE INDEX ON hotels USING gist (location);
CREATE INDEX ON restaurants USING gist (location);
CREATE INDEX ON hotels (country_code, michelin_keys);
CREATE INDEX ON restaurants (country_code, michelin_stars);
CREATE INDEX ON hotels (city_id);
CREATE INDEX ON restaurants (city_id);
CREATE INDEX ON hotels USING gin (name gin_trgm_ops);
CREATE INDEX ON restaurants USING gin (name gin_trgm_ops);
CREATE INDEX ON restaurants (status) WHERE status <> 'open';
CREATE INDEX ON hotels (status) WHERE status <> 'open';
CREATE INDEX ON hotel_restaurants (restaurant_id);
CREATE INDEX ON visits (user_id, visited_on DESC);
CREATE INDEX ON visits (entity_type, entity_id);
CREATE INDEX ON wishlist (user_id);
CREATE INDEX ON follows (following_id);
```

The two GiST indexes carry Map and Nearby. The two trigram indexes carry Search. Without them both features degrade badly beyond a few thousand rows. The status indexes are partial because the overwhelming majority of rows are `open`.

---

## 13. QA strategy

`data_issues` mirrors the QA log with the same columns as the source file, keyed on `issue_id`. Every correction script references an `issue_id`. The log is the project's reasoning, not merely its errors — it has already caught a cake shop returned as a two-star restaurant, a restaurant carrying a hotel's address and Place ID, and an address matcher that silently ignores house numbers in British-form addresses.

Four checks belong in CI and run on every catalogue change:

- every `location` falls inside its country's bounding box
- `michelin_keys` in 1–3, and `michelin_stars` null or in 1–3
- every `hotel_restaurants` row resolves on both sides
- no duplicate `google_place_id` within a table

A fifth, added after the relationship consolidation: no restaurant carries both a link row and a `property_name`.

---

## 14. Future expansion

**Absorbed without migration.** `award_history` takes yearly guide changes. `worlds_50_best` takes the annual refresh, including hall of fame induction and the extended 51–100 list. `cities.michelin_guide_edition` takes new guide jurisdictions. `inclusion_reason` takes Bib Gourmand. `venue_status` takes closures on both tables.

**Requires real work.** Multi-language names — MICHELIN publishes Japanese, Chinese and Taiwanese names in their own scripts and only romanised forms are stored.

**Deliberately excluded.** The MICHELIN Green Star and Young Chef Award are out of scope; `award_history.award_type` carries two values and is not widened for them. Neither catalogue table carries a phone number. Where a number is needed, `google_place_id` resolves to one through the Places API.

**Google ratings are deliberately not stored.** No column holds a Google star rating or review count, on either catalogue table, and none should be added.

Three reasons. They are volatile — a rating moves continuously, so a stored copy is stale from the moment it is written and there is no event that would trigger a refresh. They are third-party licensed, and Google's terms restrict retention and redisplay of Places content. And they are already reachable: `google_place_id` resolves to the current rating through the Places API at the moment it is needed, which is both fresher and simpler than a cache.

There is also a product reason. `visits.rating` is the user's own score, and Country Progress and every statistic are built from it. A stored Google rating would sit beside it on the same screen and compete with it. Inside Michelin Passport, the user's rating is the source of truth.

---

## 15. Security and access control

This section is the definitive specification for Row Level Security. Every table in the `public` schema is covered.

The deployment target is Supabase, where PostgREST exposes every table in `public` over HTTP and the `anon` key is embedded in the distributed Flutter binary. **A table without RLS enabled is readable and writable by anyone who has installed the app.** Enabling RLS with no policy denies everything; enabling it with a `SELECT` policy and no write policy produces a read-only table. Both are used below.

### 15.1 Roles

| Role | Holder | Access |
|---|---|---|
| `anon` | any unauthenticated client | catalogue read only |
| `authenticated` | a signed-in user | catalogue read, plus own user rows and rows made visible under §15.4 |
| `service_role` | the maintenance process only | bypasses RLS entirely |

`service_role` **bypasses every policy in this section.** Its key must never appear in the Flutter application, in a client-side environment file, or in any repository. It belongs only in the environment of the process described in `DATA_UPDATE_PROCESS.md`, which is the only thing that writes to the catalogue.

If that process runs in CI, the key is a CI secret with no pull-request exposure. A forked pull request that can read the secret can rewrite every award in the database.

### 15.2 Catalogue tables — public read, no write

Applies to `countries`, `cities`, `cuisines`, `hotels`, `restaurants`, `hotel_restaurants`, `award_history` and `worlds_50_best`.

RLS is enabled on all eight even though their contents are public. Enabling it is what removes write access: without RLS, the `anon` key can `UPDATE` any star count in the database.

```sql
ALTER TABLE hotels ENABLE ROW LEVEL SECURITY;

CREATE POLICY hotels_public_read ON hotels
  FOR SELECT TO anon, authenticated
  USING (true);
```

Repeat verbatim for the other seven tables. **Create no `INSERT`, `UPDATE` or `DELETE` policy on any of them.** Absence of a policy is the denial; `service_role` is unaffected because it bypasses RLS.

Views inherit the policies of their underlying tables. `restaurants_full` and `hotels_full` are readable by `anon` because `restaurants` and `hotels` are.

### 15.3 The visibility rule

One rule governs every user table. It is implemented once, as a function, and referenced by every policy that needs it.

> **A profile and everything belonging to it are visible to its owner, and to everyone else only when `profiles.is_public` is true.**

```sql
CREATE OR REPLACE FUNCTION public.profile_is_visible(target uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT target = auth.uid()
      OR EXISTS (SELECT 1 FROM profiles p WHERE p.id = target AND p.is_public);
$$;

REVOKE EXECUTE ON FUNCTION public.profile_is_visible(uuid) FROM public;
GRANT  EXECUTE ON FUNCTION public.profile_is_visible(uuid) TO anon, authenticated;
```

Three details in that definition are load-bearing:

- **`SECURITY DEFINER` prevents infinite recursion.** A policy on `profiles` that queries `profiles` re-enters its own policy and PostgreSQL raises `infinite recursion detected in policy`. Running the lookup as the definer bypasses RLS inside the function and terminates.
- **`SET search_path = public` is mandatory** on any `SECURITY DEFINER` function. Without it a caller can prepend a schema to `search_path` and substitute their own `profiles` table.
- **`STABLE`, not `VOLATILE`**, so the planner may cache the result within a statement instead of re-evaluating per row.

### 15.4 `follows` does not grant access

**A follow confers no read access.** `follows` records a social graph for feeds and follower counts; it does not widen visibility.

This is deliberate, and it is the one place where the security model is more restrictive than the product might eventually want. `follows` has no approval column — a row is created unilaterally by the follower. If following granted access to a private profile, then any user could read any private profile by inserting one row, and `is_public = false` would mean nothing.

Follower-only visibility is a legitimate product feature and it requires a schema change that is deliberately not made here: a `status` column on `follows` with an approval workflow, and a third branch in `profile_is_visible`. Until that exists, `is_public` is binary and `follows` is metadata. This is listed as an open decision in `ACTION_TRIAGE.md`.

### 15.5 `profiles`

```sql
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY profiles_read ON profiles
  FOR SELECT TO anon, authenticated
  USING (is_public OR id = auth.uid());

CREATE POLICY profiles_insert ON profiles
  FOR INSERT TO authenticated
  WITH CHECK (id = auth.uid());

CREATE POLICY profiles_update ON profiles
  FOR UPDATE TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());
```

No `DELETE` policy. A profile is removed by deleting the `auth.users` row, which cascades.

The read policy inlines the visibility rule rather than calling `profile_is_visible`, because on `profiles` itself the column is directly available and the function would be a needless round trip.

`USING` and `WITH CHECK` are both required on `UPDATE`. `USING` decides which rows may be updated; `WITH CHECK` decides what they may become. With `USING` alone, a user can reassign their own row's `id` to another user.

### 15.6 `visits`, `wishlist`, `photos`

The same shape for all three. `visits` is shown in full; `wishlist` is identical with its own table name.

```sql
ALTER TABLE visits ENABLE ROW LEVEL SECURITY;

CREATE POLICY visits_read ON visits
  FOR SELECT TO anon, authenticated
  USING (profile_is_visible(user_id));

CREATE POLICY visits_insert ON visits
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY visits_update ON visits
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY visits_delete ON visits
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());
```

`photos` differs on read only, because it carries its own `is_public` flag:

```sql
CREATE POLICY photos_read ON photos
  FOR SELECT TO anon, authenticated
  USING (
    user_id = auth.uid()
    OR (is_public AND profile_is_visible(user_id))
  );
```

**`photos.is_public` is subordinate to `profiles.is_public`, never an override.** A public photo on a private profile stays private. Both must be true for a third party to see it. Composing them the other way would let a single photo leak the existence, timing and location of a private user's visit.

### 15.7 `follows`

```sql
ALTER TABLE follows ENABLE ROW LEVEL SECURITY;

CREATE POLICY follows_read ON follows
  FOR SELECT TO authenticated
  USING (follower_id = auth.uid() OR following_id = auth.uid());

CREATE POLICY follows_insert ON follows
  FOR INSERT TO authenticated
  WITH CHECK (follower_id = auth.uid());

CREATE POLICY follows_delete ON follows
  FOR DELETE TO authenticated
  USING (follower_id = auth.uid() OR following_id = auth.uid());
```

Both parties may read and both may delete: the follower unfollows, the followed party removes a follower. No `UPDATE` policy — a follow has no mutable state.

Public follower counts cannot be served by this policy, because a third party sees no rows. Expose a count through a materialised view or a `SECURITY DEFINER` function; do not widen the read policy to `true`, which would publish the entire social graph.

### 15.8 Storage

`photos.storage_path` points into a Supabase Storage bucket. **Storage has its own RLS on `storage.objects` and does not inherit anything from this schema.** A correct policy on `photos` with a public bucket means the metadata is protected and the image is not.

Use a private bucket, path-prefix every object with the owner's UUID, and mirror §15.6 on `storage.objects` using the first path segment as the owner. Serve images through signed URLs.

### 15.9 Verification

Run after applying policies. Anything returned is a defect.

```sql
-- Every table in public has RLS enabled
SELECT tablename FROM pg_tables
 WHERE schemaname = 'public' AND rowsecurity = false;

-- No catalogue table has a write policy
SELECT tablename, policyname, cmd FROM pg_policies
 WHERE schemaname = 'public'
   AND tablename IN ('countries','cities','cuisines','hotels','restaurants',
                     'hotel_restaurants','award_history','worlds_50_best')
   AND cmd <> 'SELECT';

-- Every SECURITY DEFINER function pins search_path
SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.prosecdef
   AND NOT coalesce(p.proconfig, '{}') @> ARRAY['search_path=public'];
```

Then test as a real user, not as the table owner. **The table owner bypasses RLS by default**, so a policy verified in the SQL editor may be wrong in the application:

```sql
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims = '{"sub":"<some-user-uuid>"}';
SELECT count(*) FROM visits;   -- own rows plus public profiles only
RESET ROLE;
```
