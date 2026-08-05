# Data Update Process

Michelin Passport — maintaining the catalogue.

Schema is specified in `DATABASE_ARCHITECTURE.md`. Building from scratch is covered in `DATABASE_IMPORT_GUIDE.md`. This document covers every change made to the catalogue after launch.

The application never writes to the catalogue. Everything below is a maintenance operation.

---

## 1. The update calendar

MICHELIN publishes roughly fifteen guide jurisdictions, each with its own ceremony date. Award changes are a near-continuous stream, not an annual event. Six tier changes and three US three-star demotions were observed during data collection alone.

| Event | Frequency | Affects |
|---|---|---|
| MICHELIN restaurant ceremony, per jurisdiction | ~15 per year | `restaurants`, `award_history` |
| MICHELIN Keys announcement | annual | `hotels`, `award_history` |
| World's 50 Best | annual | `worlds_50_best` |
| Venue closures and reopenings | continuous | `status` on either table |
| New country or guide edition | occasional | `countries`, `cities`, both catalogue tables |

Maintain a calendar of ceremony dates per jurisdiction. A guide that publishes unnoticed leaves the app quietly wrong for months, and `award_history` cannot recover a value that was overwritten before anyone recorded it.

---

## 1a. Authentication

Every operation in this document writes to the catalogue, and **the catalogue is writable only by `service_role`**. The policies in `DATABASE_ARCHITECTURE.md` §15.2 grant `SELECT` to `anon` and `authenticated` and grant no write to either.

`service_role` bypasses RLS entirely. Its key is the most dangerous credential in the project: it can rewrite every award and delete every user row.

- It lives only in the environment of the process running these updates.
- It never appears in the Flutter application, a client environment file, or a repository.
- If updates run in CI, it is a protected secret unavailable to pull requests from forks.
- Rotate it whenever someone with access leaves the project.

Run every update as a script authenticating with that key, not from an interactive SQL editor logged in as the table owner. The owner also bypasses RLS, which makes an editor session indistinguishable from a correct one right up to the moment the same statement is run from the application.

---

## 2. The general procedure

Every catalogue update follows the same six steps, whatever triggered it.

1. **Capture the source.** MICHELIN blocks automated fetching, so most rosters are captured manually. Record what was captured and when.
2. **Stage.** Load into a staging table. Never edit the live catalogue directly.
3. **Match on code.** Resolve each incoming row to `restaurant_code` or `hotel_code`. A name may *propose* a match; a human confirms it. See §11.
4. **Diff.** Produce the change set — new rows, changed awards, removed rows — and review it before applying.
5. **Apply inside one transaction**, closing `award_history` before opening the new value.
6. **Run the regression suite** (§8). Roll back on any failure.

**The cardinal rule: never overwrite an award without writing history first.** The two statements belong in one transaction, in this order.

```sql
BEGIN;

UPDATE award_history SET is_current = false
 WHERE entity_type = 'restaurant' AND entity_id = :id
   AND award_type = 'michelin_stars' AND is_current;

INSERT INTO award_history
  (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on)
VALUES ('restaurant', :id, 2027, 'michelin_stars', :new_stars, true, :announced_on);

UPDATE restaurants SET michelin_stars = :new_stars WHERE id = :id;

COMMIT;
```

The partial unique index on `award_history (entity_type, entity_id, award_type) WHERE is_current` enforces the ordering. Inserting the new current row before clearing the old one raises a unique violation, which is the intended behaviour.

---

## 3. MICHELIN restaurant updates

For each jurisdiction's new selection, the incoming roster produces four cases.

**Unchanged.** No action.

**`guide_year` is the MICHELIN Guide edition in which an award value became effective. It is not the year the row was written.**

A row is created when an award changes, not on a schedule. A venue whose award has not moved since 2026 therefore carries one row, reading 2026, however many guide editions have published since.

The rows seeded at launch all carry `guide_year = 2026`. That is a launch limitation, not historical truth: the awards these venues held before 2026 were not recoverable when the catalogue was built. A query of the form "how long has this venue held three stars" returns 2026 for every seeded venue and is only meaningful for changes recorded after launch. State that in the interface or do not build the feature.

**Promoted or demoted.** Apply §2. `visits.stars_at_visit` is never touched — it records what the user experienced.

**New to the guide.** Create the restaurant row and seed its first `award_history` entry. New rows need the full research pass: address, coordinates, Place ID, cuisine, city and country resolution.

**Left the guide.** This is the case that is most often handled wrongly.

| Situation | Action |
|---|---|
| Still trading, star withdrawn | Keep the row. Insert `award_history` with `award_value = NULL` for the new year. Set `restaurants.michelin_stars = NULL` and `inclusion_reason` appropriately. |
| Closed | Set `status`. See §7. |
| Neither starred nor on the 50 Best list, and still trading | The row now falls outside the scope rule. Keep it, with `michelin_stars = NULL`; do not delete. |

**Never delete a catalogue row.** `visits`, `wishlist` and `photos` reference venues polymorphically, so no foreign key protects them. A deleted restaurant silently orphans every visit that referenced it.

---

## 4. World's 50 Best updates

The list publishes annually. Ranks are rewritten wholesale — up to 50 rows change in one operation.

```sql
INSERT INTO worlds_50_best (restaurant_id, year, rank, list_type)
VALUES (:restaurant_id, :year, :rank, 'top_50');
```

**Never update last year's rows.** A rank is a fact about a year. Insert new rows; leave the old ones alone.

**A restaurant absent from this year's list gets no row for this year.** Do not store a null rank or a zero to represent absence — absence is the lack of a row.

**Hall of Fame.** A restaurant entering the Best of the Best leaves the ranking permanently. Record one row in the induction year with `rank = NULL` and `list_type = 'hall_of_fame'`, and no rows in any later year.

The winner of a given year is elevated when the *following* year's list publishes, not at the moment it wins. Disfrutar won in 2024 and was elevated in 2025; Central won in 2023 and was elevated in 2024. Record the induction year, not the year of the win.

A hall of fame member qualifies for a catalogue row on that basis alone, even with no MICHELIN star and no current ranking — this is the third branch of the scope rule. Central is the worked example: no MICHELIN guide operates in Peru, and it is ineligible for the annual list. Membership is permanent by construction:

```sql
SELECT EXISTS (
  SELECT 1 FROM worlds_50_best
   WHERE restaurant_id = :id AND list_type = 'hall_of_fame');
```

**The induction rule.** The restaurant ranked No.1 in a given year is elevated into the Hall of Fame when the *following* year's list publishes, and leaves the ranking permanently at that moment. Its rank-1 row for the winning year is never altered; a new row with `rank = NULL` and `list_type = 'hall_of_fame'` is inserted for the year of induction.

**Never create the induction row in advance.** Until the following list publishes, the reigning No.1 legitimately holds rank 1 and nothing else. Seeding the induction early records an event that has not happened, and the Hall of Fame membership test in this section then returns true for a restaurant still in the ranking.

**Restaurants entering the list without a MICHELIN star.** Seven such rows exist today. They qualify under the second branch of the scope rule. Create the restaurant with `michelin_stars = NULL` and `inclusion_reason = 'worlds_50_best'`. Six of the current seven are in countries where MICHELIN awards no stars at all, so a null star count is the correct value, not a gap to be filled later.

---

## 5. MICHELIN Keys updates

Identical to §3, on `hotels` and `award_type = 'michelin_keys'`, with one additional rule.

**A starred restaurant inside a hotel is not evidence that the hotel holds a Key.** Grand Hotel a Villa Feltrinelli hosts a starred restaurant and holds no Keys; there are five further examples in Tokyo alone. A hotel enters `hotels` only on a Key award. A hotel that loses its last Key keeps its row, with an `award_history` entry recording `award_value = NULL`.

When a hotel gains its first Key and already appears as a `property_name` on a restaurant row, three changes are needed together: create the hotel row, create the link row, and clear `property_name` on the restaurant. Leaving `property_name` populated alongside a link row violates the mutual exclusivity in `DATABASE_ARCHITECTURE.md` §6 and is caught by the regression suite.

---

## 6. Renamed venues

**Always adopt MICHELIN's published name.** Following the publisher has already dissolved one collision entirely: the Swiss two-star is *Da Vittorio - St. Moritz* and the Italian three-star is *Da Vittorio*, so they no longer collide at all.

A rename is a single `UPDATE` on `name`. The code never changes — that is what the code is for, and every QA entry and manual action references it.

Check three things on every rename:

- Does the new name collide with an existing row? Four names already collide inside a single country.
- Does the address also change? A rename often accompanies a move. Verify separately; do not assume.
- Does `google_place_id` still resolve? A rebranded venue sometimes gets a new Google record.

Record the previous name in `data_issues` with an `issue_id`. There is no `former_name` column, and search does not need one — users searching an old name are a support question, not a schema question, until evidence says otherwise.

---

## 7. Closures, reopenings and relocations

Three status values, described in `DATABASE_ARCHITECTURE.md` §3.1.

**Temporary closure.**

```sql
UPDATE restaurants
   SET status = 'temporarily_closed',
       status_since = :date,
       status_note = 'Closed for refurbishment, expected to reopen spring 2027'
 WHERE restaurant_code = :code;
```

**Permanent closure.** Set `status = 'permanently_closed'`. **Never delete the row.** In a passport app the visit is the product, and a user who dined somewhere before it closed has a legitimate record.

**Relocation is not a status.** A relocating venue is `temporarily_closed` with the destination in `status_note`. On reopening: set `status = 'open'`, update `address`, `location`, `google_place_id` and `city_id`, and create or remove the hotel link as appropriate.

La Paix is the worked example. It left its Anderlecht premises of more than 140 years for the Corinthia Grand Hotel Astoria Brussels — `hotel_153`, already in the catalogue — retaining two stars throughout. On reopening it becomes `open`, gains a new address, and gains a link row.

**The interface contract.** `open` renders normally. `temporarily_closed` renders with a banner from `status_note` and booking suppressed. `permanently_closed` renders greyed, with visit history preserved and booking removed.

---

## 8. Regression testing

Run after every catalogue change, in CI on every commit that touches catalogue data. Each query must return zero rows.

```sql
-- 1. Coordinates inside the country bounding box
-- 2. Award values in range
SELECT 1 FROM hotels WHERE michelin_keys NOT BETWEEN 1 AND 3;
SELECT 1 FROM restaurants WHERE michelin_stars IS NOT NULL
                            AND michelin_stars NOT BETWEEN 1 AND 3;

-- 3. Every link resolves on both sides
-- 4. No duplicate google_place_id within a table
SELECT google_place_id FROM restaurants WHERE google_place_id IS NOT NULL
 GROUP BY 1 HAVING count(*) > 1;

-- 5. Mutual exclusivity of the hotel-scope rules
SELECT r.restaurant_code FROM restaurants r
  JOIN hotel_restaurants hr ON hr.restaurant_id = r.id
 WHERE r.property_name IS NOT NULL;

-- 6. Exactly one current award per entity per type
SELECT entity_id, award_type FROM award_history WHERE is_current
 GROUP BY 1,2 HAVING count(*) > 1;

-- 7. No 50 Best rank collision within a year
SELECT year, rank FROM worlds_50_best WHERE rank IS NOT NULL
 GROUP BY 1,2 HAVING count(*) > 1;

-- 8. No hall of fame restaurant ranked in a later year
SELECT w.restaurant_id FROM worlds_50_best w
 WHERE w.list_type = 'hall_of_fame'
   AND EXISTS (SELECT 1 FROM worlds_50_best x
                WHERE x.restaurant_id = w.restaurant_id
                  AND x.year > w.year AND x.rank IS NOT NULL);

-- 9. Denormalised country_code agrees with the country reachable through city_id
SELECT h.hotel_code FROM hotels h JOIN cities c ON c.id = h.city_id
 WHERE h.country_code <> c.country_code;

SELECT r.restaurant_code FROM restaurants r JOIN cities c ON c.id = r.city_id
 WHERE r.country_code <> c.country_code;

-- 10. No orphaned user row. PostgreSQL cannot enforce this: see
--     DATABASE_ARCHITECTURE.md section 4. These queries are the enforcement.
SELECT v.id FROM visits v
 WHERE (v.entity_type = 'hotel'      AND NOT EXISTS (SELECT 1 FROM hotels      h WHERE h.id = v.entity_id))
    OR (v.entity_type = 'restaurant' AND NOT EXISTS (SELECT 1 FROM restaurants r WHERE r.id = v.entity_id));

SELECT w.user_id FROM wishlist w
 WHERE (w.entity_type = 'hotel'      AND NOT EXISTS (SELECT 1 FROM hotels      h WHERE h.id = w.entity_id))
    OR (w.entity_type = 'restaurant' AND NOT EXISTS (SELECT 1 FROM restaurants r WHERE r.id = w.entity_id));

SELECT p.id FROM photos p
 WHERE (p.entity_type = 'hotel'      AND NOT EXISTS (SELECT 1 FROM hotels      h WHERE h.id = p.entity_id))
    OR (p.entity_type = 'restaurant' AND NOT EXISTS (SELECT 1 FROM restaurants r WHERE r.id = p.entity_id));

SELECT a.id FROM award_history a
 WHERE (a.entity_type = 'hotel'      AND NOT EXISTS (SELECT 1 FROM hotels      h WHERE h.id = a.entity_id))
    OR (a.entity_type = 'restaurant' AND NOT EXISTS (SELECT 1 FROM restaurants r WHERE r.id = a.entity_id));
```

**Check 10 is the only thing standing between a mistaken `DELETE` and permanent loss of user data.** The catalogue is append-and-amend only for exactly this reason. If it ever returns a row, the deletion has already happened and the affected visits cannot be reconstructed — restore rather than clearing the orphans. Procedure in `DEPLOYMENT.md` §9.3.

Also assert that row counts move only in the direction the change set predicted. A guide update that adds four restaurants and removes one should change the count by three, and any other number means the diff was applied incorrectly.

---

## 9. Country totals

Expected totals are held per **guide edition**, never per country. A national total is meaningless where a country spans several editions — the United States spans thirteen, Japan spans three.

Verify totals only against selections MICHELIN publishes itself. During data collection four different secondary sources gave four different national counts for US two-stars, and only the per-guide selections proved reliable.

Where a total is unverified, the interface renders **Unknown**. Never a computed percentage. Nine of the current countries are in this state.

---

## 10. Adding a new country

1. Insert into `countries` with its ISO code and flag. Country is geographic — a territory MICHELIN files under another guide still gets its own row.
2. Insert its cities, with `region` and `michelin_guide_edition` populated at creation. Backfilling these later means touching every city in the country.
3. Research the venues. Each needs address, coordinates, Place ID, cuisine, award and city resolution.
4. Insert catalogue rows and seed `award_history` for each.
5. Run the address matcher for hotel-restaurant links. Review every proposed link and record `link_confidence` and `evidence`.
6. Run the regression suite.

Two known traps. Google has almost no commercial coverage in mainland China — six of eight Beijing lookups returned an unrelated business, including a cake shop for a two-star restaurant. Use Amap or Baidu there. And the address matcher assumes street-then-number, so it misreads British-form addresses; check it before running over Malta, Ireland, the UK or the US.

---

## 11. Matching and QA workflow

**Codes decide, names may only propose.** An import script may use a name to generate a candidate match, and a human must confirm it before anything is written. This is not a loophole — it is how every existing link was built, and `link_confidence` and `evidence` exist to record that confirmation.

Every uncertain match is written with `link_confidence = 'campus'` or `'manual_review'` and reviewed before promotion to `'exact'`. Those two values will be used again on the next import even though every current row is `exact`.

**Log the reasoning, not only the errors.** The QA log has caught a cake shop returned as a two-star restaurant, a restaurant carrying a hotel's address and Place ID, and an address matcher that silently ignores house numbers. It also records near-misses: the Carlton Hotel sits on Via Johannes Badrutt, a street named after the same family as Badrutt's Palace two blocks away, and that single coincidence corrupted a restaurant record for months.

Log method mistakes too. A MICHELIN hotel card's dining box is neither exhaustive nor restricted to venues in the building — it has listed a Bib Gourmand while omitting a two-star restaurant at the same hotel. Use it to propose a link, never to reject one.

---

## 12. Versioning

**Catalogue data** is versioned by `award_history.guide_year` and `worlds_50_best.year`. There is no snapshot table and none is needed; the history tables are the version record.

**Schema** is versioned by numbered, forward-only migrations. Never edit a migration that has been applied to production.

**Source files** are versioned in the repository alongside the migration that consumed them, so any state of the catalogue can be rebuilt from a known input.

Tag a release when a guide year completes across all jurisdictions. That tag, plus the migrations up to it, reproduces the catalogue exactly.


---

## 13. Materialised views and scheduled refresh

Aggregate statistics — visit counts, country progress, leaderboards — are materialised views. They are the only derived objects in the schema that are not computed at read time, because each aggregates across every user.

### 13.1 Each view requires a unique index

```sql
CREATE MATERIALIZED VIEW user_country_progress AS
SELECT v.user_id, r.country_code, count(DISTINCT v.entity_id) AS visited
  FROM visits v
  JOIN restaurants r ON r.id = v.entity_id AND v.entity_type = 'restaurant'
 GROUP BY 1, 2;

CREATE UNIQUE INDEX ON user_country_progress (user_id, country_code);
```

**The unique index is not optional.** `REFRESH MATERIALIZED VIEW CONCURRENTLY` requires one, and without `CONCURRENTLY` the refresh takes an `ACCESS EXCLUSIVE` lock that blocks every read of the view for its duration. At launch scale that is milliseconds; at the scale where a materialised view earns its place, it is a visible outage.

### 13.2 Refresh procedure

```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY user_country_progress;
```

`CONCURRENTLY` builds the new contents alongside the old and swaps them, so readers are never blocked. It is slower and requires the view to have been populated at least once — the first refresh after creation must run without it.

### 13.3 Schedule

`pg_cron` runs the refresh. It is enabled from the Supabase dashboard under Database → Extensions, and is listed in `DATABASE_IMPORT_GUIDE.md` §1.

```sql
SELECT cron.schedule(
  'refresh-country-progress',
  '15 3 * * *',                     -- 03:15 UTC daily
  $$REFRESH MATERIALIZED VIEW CONCURRENTLY user_country_progress$$
);
```

Nightly is the right cadence because these views summarise user activity, which no user expects to be real-time, and because the underlying tables are written continuously. Schedule each view a few minutes apart rather than together: concurrent refreshes compete for the same I/O and lengthen each other.

Run them outside any window in which a catalogue update is scheduled. A refresh reading `restaurants` mid-update produces a statistic that matches neither the old catalogue nor the new one.

### 13.4 Verification

```sql
SELECT jobid, jobname, schedule, active FROM cron.job;

SELECT jobname, status, return_message, start_time
  FROM cron.job_run_details
 WHERE status <> 'succeeded'
 ORDER BY start_time DESC LIMIT 20;
```

A failing refresh is silent to the application: the view keeps serving its previous contents, so the symptom is statistics that stop moving rather than an error. Alert on `cron.job_run_details`, not on application behaviour.
