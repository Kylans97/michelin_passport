# Engineering Review

Michelin Passport — review of the documentation set by an engineer joining the project.

Eleven findings. Three would stop me shipping. Four are real defects with cheap fixes. Four are maintenance risks that compound over five years.

> **Status: accepted and implemented.** All eleven are resolved in the current documentation, with one deliberate departure: B2's recommended foreign keys were declined in favour of documented mitigations, because the polymorphic user tables are a pinned architectural decision. The residual risk is stated in `CHANGELOG.md` and in `DATABASE_ARCHITECTURE.md` §4.

I have also listed what I deliberately would not change, because a review that only finds fault is not useful for judging what is load-bearing.

---

## Blocking

### B1. Row Level Security is named and never specified

`START_HERE` lists RLS as step 11 of the implementation order. `DATABASE_IMPORT_GUIDE` lists it as step 11. **No document defines a single policy, and no document says which tables need one.**

This is not a documentation gap. On Supabase, PostgREST exposes every table in the `public` schema over HTTP. A table without RLS enabled is readable and writable by anyone holding the anon key, which ships inside the Flutter binary. Following this documentation exactly produces a database where any user can read every other user's private visits, edit their ratings, and delete their photos.

The schema already implies a visibility model that is written down nowhere: `profiles.is_public`, `photos.is_public`, and a `follows` table whose only purpose is to grant access to something.

**Required before launch.** A section specifying, at minimum:

- `ALTER TABLE … ENABLE ROW LEVEL SECURITY` on all five user tables, plus a stated decision to leave the catalogue readable by `anon`
- read policy for own rows, and the exact predicate for another user's rows: public profile, or an accepted follow
- write policies keyed on `auth.uid() = user_id`
- whether `photos.is_public` overrides `profiles.is_public` or is subordinate to it
- whether the service role bypasses RLS for the maintenance process, and how it is protected

The last point matters more than it looks. The maintenance process in `DATA_UPDATE_PROCESS.md` writes to the catalogue on a schedule. If it authenticates as the service role, the credential that can rewrite every award in the database is sitting in whatever runs that job.

### B2. Four tables reference venues with no foreign key, protected only by a process promise

`visits`, `wishlist`, `photos` and `award_history` all address a venue through `entity_type` plus `entity_id`. `DATABASE_ARCHITECTURE.md` §4 acknowledges this and offers a mitigation:

> The maintenance process never deletes a catalogue row, which is what keeps these references valid.

**A process guarantee is not a referential guarantee.** It holds until the first developer who has not read this document runs a `DELETE` to clean up a mistaken import — which is a normal thing to do in year three, and which the database will accept silently. There is no error, no constraint violation, and no way to detect the damage afterwards except by scanning for orphans.

The cost is asymmetric and permanent: a lost visit cannot be reconstructed, and in a passport app the visit is the product.

**Recommended fix — two nullable columns with a mutual-exclusion check:**

```sql
ALTER TABLE visits
  ADD COLUMN hotel_id      uuid REFERENCES hotels(id)      ON DELETE RESTRICT,
  ADD COLUMN restaurant_id uuid REFERENCES restaurants(id) ON DELETE RESTRICT,
  ADD CONSTRAINT visits_one_venue CHECK (num_nonnulls(hotel_id, restaurant_id) = 1);
```

`ON DELETE RESTRICT` converts the process promise into a database guarantee: the `DELETE` fails loudly instead of orphaning a row. `num_nonnulls` is built in and does exactly what is needed here.

The cost is that "all visits for this user" becomes two joins or a `UNION`, against one polymorphic join today. That is a real ergonomic loss and it is why the polymorphic pattern was chosen. It is not worth the risk on `visits`, `wishlist` and `photos`, which hold irreplaceable user data.

**`award_history` is a genuinely harder case** and I would leave it polymorphic. It carries two entity types with identical structure, it is written only by the maintenance process, and splitting it into `hotel_award_history` and `restaurant_award_history` duplicates a table definition to solve a problem that only manifests through the same process that maintains it. Add an orphan check to the regression suite instead.

This is the one place I am recommending a departure from the existing design, and I want the trade stated plainly rather than assumed: **user tables get real foreign keys, catalogue history stays polymorphic.**

### B3. The import guide cannot be followed end to end

`DATABASE_IMPORT_GUIDE.md` opens by claiming it allows a developer to build the database from scratch. It does not, because four objects appear in its SQL and are defined nowhere:

| Object | Where used | Problem |
|---|---|---|
| `r.city_text`, `r.country_text` | §6.3 | Staging columns that §6.1's `COPY` never creates |
| `staging_links` | §7 | Never created or loaded |
| `staging_restaurants` | §8.2 | Never created; also read *after* §6 implies it is gone |
| `country_bounds` | §9.2 | A bounding-box table with a `geom` column, never sourced or created |

`country_bounds` is the worst of the four, because §9.2 is the check that catches a reversed `ST_MakePoint` — the single most damaging silent error in the whole build. The fallback query provided beneath it covers six European countries out of 43.

**Required.** A staging section that creates every intermediate object explicitly, and either a source for country bounding boxes or an honest statement that the coarse check is all that exists and which countries it covers.

---

## Real defects, cheap fixes

### D1. Cross-document links are all broken

Every document references `DATABASE_ARCHITECTURE.md`, `VALIDATION_REPORT.md` and `ACTION_TRIAGE.md`. The files are named `DATABASE_ARCHITECTURE_v2_0.md`, `VALIDATION_REPORT_v2_0.md` and `ACTION_TRIAGE_v2_0.md`. **Not one link resolves on GitHub.**

The version suffix is also self-defeating. A document set that has removed every internal reference to previous versions still announces its own version in seven filenames, and the next revision either renames all seven and breaks every external bookmark, or keeps `v2_0` in the name while describing v2.1 content.

**Fix.** Drop the suffix. Version belongs in git history and in a tag, not a filename.

### D2. `country_code` on the catalogue tables can silently contradict `city_id`

Both `hotels` and `restaurants` carry `country_code`, described as "denormalised for country filters". Both also carry `city_id`, and `cities` carries `country_code`.

Nothing enforces agreement. A hotel may claim `CH` while its city row says `IT`, and every index, filter and country-progress figure will disagree with the map depending on which path the query took.

This is the exact pattern the project eliminated when it dropped `is_in_hotel`: one fact, two places, no constraint. The difference is that this denormalisation buys a genuine index — `(country_code, michelin_keys)` — which a join could not.

**Fix.** Keep the column; add the check to the regression suite in `DATA_UPDATE_PROCESS.md` §8, where it costs nothing:

```sql
SELECT h.hotel_code FROM hotels h JOIN cities c ON c.id = h.city_id
 WHERE h.country_code <> c.country_code;
```

### D3. `guide_year` has two incompatible meanings

`DATABASE_ARCHITECTURE.md` presents `guide_year` as the year of a guide edition. `DATA_UPDATE_PROCESS.md` §3 says rows are written on change, not on schedule.

Both cannot hold. Under the second rule, a restaurant unchanged since launch carries `guide_year = 2026` indefinitely, and the query the architecture advertises — *"this restaurant has held three stars since 2019"* — returns 2026, because 2026 is when the row was seeded rather than when the award was earned.

**Fix.** One sentence in the column definition: *`guide_year` is the guide edition in which this award value took effect, not the year the row was written.* Then state that seeded rows carry 2026 because the earlier history was not recoverable, which is true and is the honest caveat a developer needs before writing a "held since" feature.

### D4. `venue_status` is the only enum in a schema of text-plus-CHECK

Seven columns carry a constrained vocabulary: `entity_type`, `award_type`, `list_type`, `inclusion_reason`, `link_confidence`, and `status`. Six are `text` with a `CHECK`. One is a PostgreSQL `ENUM`.

Nothing justifies the difference, and the two behave differently where it matters. Adding a value to a CHECK is an `ALTER TABLE`; adding one to an enum is `ALTER TYPE … ADD VALUE`, which cannot be removed later and has transactional restrictions across versions. A developer adding `seasonal_closure` in 2028 will discover this at the worst moment.

**Fix.** Convert `venue_status` to `text` with a `CHECK`, matching the other six. Free before the table exists.

---

## Maintenance risks

### M1. `inclusion_reason` no longer covers the scope rule

The scope rule has three branches: MICHELIN star, current 50 Best listing, hall of fame membership. `inclusion_reason` has three values — `michelin_star`, `worlds_50_best`, `bib_gourmand` — and **hall of fame is not among them**, while `bib_gourmand` describes a category deliberately excluded.

Central would be stored as `worlds_50_best`, which is wrong in the only sense that matters: it is *not* on the World's 50 Best list, and cannot be, because hall of fame members are ineligible. Anyone filtering `inclusion_reason = 'worlds_50_best'` to find current list members gets Central back.

This compounds `ARCHITECTURE_REVIEW.md` §5, which already notes that the column records a primary reason rather than a set. Two known problems with one column suggests the column is carrying a load it was not designed for.

**Recommended.** Add `hall_of_fame` to the permitted values, or drop the column and derive inclusion from the facts already stored — a star count, a `worlds_50_best` row, a `hall_of_fame` row. The second is more consistent with how `is_in_hotel` was resolved.

### M2. `hotels_full` is named but not specified

`restaurants_full` gets a definition table with six derived columns and a paragraph explaining why the derivation is safe. `hotels_full` gets one sentence naming `has_michelin_restaurant` and `restaurant_count` with no definitions.

The application reads these views rather than the tables, so an undefined view is an undefined API. Specify it to the same standard, or say explicitly that it is out of scope for launch.

### M3. Nightly refresh has no mechanism

Aggregate statistics are described as "materialised views refreshed nightly". Nothing states what performs the refresh. On Supabase that is `pg_cron`, which must be enabled and is not in the extensions list in `DATABASE_IMPORT_GUIDE.md` §1.

Also unstated: `REFRESH MATERIALIZED VIEW CONCURRENTLY` requires a unique index on the view, and without `CONCURRENTLY` the refresh takes an `ACCESS EXCLUSIVE` lock that blocks every read for its duration. At current row counts that is milliseconds; at the scale where materialised views are worth having, it is an outage.

### M4. The code formats contradict the stated naming convention

`hotel_code` is `hotel_001`. `restaurant_code` is `rest_0001`. One uses the full word and three digits; the other abbreviates and uses four. §11 then states: *"Never abbreviate — `restaurant_id`, not `rest_id`."*

The codes cannot be changed — 193 QA entries and 38 manual actions reference them, and that stability is their entire purpose. But leaving the contradiction unacknowledged guarantees that a developer will eventually "fix" one of them.

**Fix.** One clause in §11 stating that the convention governs schema identifiers and that the two external codes predate it and are frozen. Also state the zero-padding widths, because a script that formats an id as `rest_%03d` will produce a code that matches nothing.

---

## What I would not change

Listed because restraint is part of a review, and because these look unusual enough that a new engineer might otherwise "simplify" them.

| Design | Why it stays |
|---|---|
| Two identifiers per venue | The UUID is internal, the code is the stable external key that survives a rebuild. Both are load-bearing; the codes are what make B2's remap strategy possible. |
| `award_history` at launch | Adding it later is trivial; reconstructing it is impossible. The single best decision in the schema. |
| `worlds_50_best` as a separate table | Star and rank are opposed scales. Folding them guarantees a wrong `ORDER BY` for one of them. |
| `is_in_hotel` derived, not stored | It drifted twice as a stored value, and a generated column cannot express a dependency on another table's rows. |
| `michelin_stars` nullable | Zero would assert an assessment that never happened for six rows. The null is meaningful. |
| `region` on `cities` only | Region is a property of a place. On both catalogue tables it would duplicate one fact across 1 462 rows. |
| Codes decide, names propose | Four names collide inside one country, one pair across different star counts. |
| Ten shared Place IDs | Correct. A cross-table unique index would reject all ten legitimate cases. |

---

## Priority

| | Finding | Effort | Consequence if skipped |
|---|---|---|---|
| 1 | **B1** RLS unspecified | 1 day | Every user's private data is readable with a key shipped in the app |
| 2 | **B3** Import guide incomplete | Half a day | The build cannot be reproduced; the coordinate check is unusable |
| 3 | **B2** Foreign keys on user tables | Half a day | Silent, unrecoverable loss of user data on a routine `DELETE` |
| 4 | **D4** `venue_status` to text | Minutes | Locked into an enum's migration constraints |
| 5 | **M1** `inclusion_reason` | Minutes | A filter that returns wrong rows |
| 6 | **D1** Filenames and links | Minutes | Every cross-reference broken on GitHub |
| 7 | **D3** `guide_year` meaning | Minutes | A "held since" feature that silently reports the seed year |
| 8 | **D2** `country_code` check | Minutes | Country filters disagreeing with the map |
| 9 | **M4** Code format note | Minutes | A future "correction" that breaks 231 references |
| 10 | **M2**, **M3** Views and refresh | Half a day | Undefined API; a refresh that locks reads |

Items 4 through 9 total under an hour and should be done in one pass. Items 1, 2 and 3 are the ones I would want closed before any code is written against this schema.