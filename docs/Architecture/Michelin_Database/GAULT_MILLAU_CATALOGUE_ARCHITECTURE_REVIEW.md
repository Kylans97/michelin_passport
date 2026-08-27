# Restaurant Catalogue Architecture Review — Pre-Gault&Millau Production Blocker

Reviewed: 2026-08-11. **Status: ARCHITECTURE REVIEW ONLY. Nothing applied to production. No migration run. No Flutter code changed. No commit made.**

A companion SQL sketch (`supabase/data/enrichment/gault_millau/proposed_catalogue_architecture_fix.sql`) is referenced throughout — marked **PREPARED — NOT APPLIED**, syntax- and behavior-verified only via a rolled-back local transaction.

One naming correction up front: the task brief refers to a table `restaurant_michelin_awards`. No such table exists in this codebase — the actual Michelin-history table is `public.award_history` (shared between restaurants and hotels via `entity_type`). This review uses the real name throughout.

---

## 1. Audit — current meaning of `inclusion_reason`

**Answer: (D) a mixture — but a narrower, more specific mixture than "provenance vs. current recognition." In practice it is (A) *creation provenance* for the row's original write, that has come to be *misread* by exactly one code path as (C) *current recognition*, and that misreading is currently broken on real data (see §1.1).**

Schema (`supabase/migrations/20260805141519_production_schema_v1.sql:151,169-171`, confirmed live on the local dev catalogue mirror — 774 restaurants):

```sql
inclusion_reason text not null default 'michelin_star',
...
constraint inclusion_reason_valid
    check (inclusion_reason in ('michelin_star', 'worlds_50_best',
                                 'hall_of_fame', 'bib_gourmand'))
```

`DATABASE_ARCHITECTURE.md` §3.3 is explicit that this is provenance, not a live summary: *"It records the **primary** reason the row exists, not the complete set: a restaurant holding three stars and a current ranking reads `michelin_star`."* That sentence is the entire intended semantics — (A), single-valued, historical. Nothing in the schema re-derives or re-writes it after insert; there is no trigger, no scheduled job, nothing that keeps it in sync with `michelin_stars` or `worlds_50_best` as either changes over time.

The one place this breaks down is `Restaurant.isHallOfFame` (§2), which reads `inclusion_reason` as if it answered "is this restaurant *currently* a Hall of Fame member" — a (C)-style question — even though the column was only ever designed to answer (A). That mismatch is exactly what `ENGINEERING_REVIEW.md` finding **M1** already flagged before this review started (see §1.2).

### 1.1 A concrete, currently-live bug found during this audit

Querying the local dev catalogue mirror directly:

```
inclusion_reason distribution: [('michelin_star', 767), ('worlds_50_best', 7)]
```

**Zero rows carry `'hall_of_fame'` or `'bib_gourmand'`.** Cross-referencing against the actual Hall of Fame roster (`worlds_50_best.list_type = 'hall_of_fame'`, which `scripts/import_catalogue.py`'s `insert_hall_of_fame()` populates correctly):

| restaurant_code | name | inclusion_reason (should be `hall_of_fame`) |
|---|---|---|
| rest_0331 | Disfrutar | `michelin_star` |
| rest_0337 | El Celler de Can Roca | `michelin_star` |
| rest_0045 | Eleven Madison Park | `michelin_star` |
| rest_0473 | Geranium | `michelin_star` |
| rest_0078 | Osteria Francescana | `michelin_star` |
| rest_0735 | The French Laundry | `michelin_star` |

Root cause: `scripts/import_catalogue.py:678`, `insert_restaurants()`:

```python
inclusion_reason = "michelin_star" if r.michelin_stars is not None else "worlds_50_best"
```

A two-branch expression that can **never** produce `'hall_of_fame'`. All 6 real Hall of Fame members currently also hold 3 Michelin stars, so they fall into the first branch. `insert_hall_of_fame()` (same file) correctly writes their `worlds_50_best` row — the fact table is right — but nothing ever corrects `restaurants.inclusion_reason` afterward.

**Consequence:** `Restaurant.isHallOfFame` (`lib/models/restaurant.dart:83`, `inclusionReason == 'hall_of_fame'`) returns `false` for every real Hall of Fame restaurant. The Hall of Fame badge (`restaurant_awards_card.dart:27`) and the Explore "Hall of Fame" filter (`restaurant_repository.dart:85`, `hallOfFameOnly`) are silently non-functional for real data today. This is finding M1's own predicted failure mode ("a filter that returns wrong rows"), now confirmed to have actually happened — found incidentally while auditing this column for the Gault&Millau blocker, not something this review went looking for. Found in the local dev mirror (seeded by this exact deterministic script); not independently re-verified against a live production connection, which this review does not make, but the same bug is expected in production since the logic is identical and deterministic. **Not fixed here** — see §17.

### 1.2 Prior art: this was already flagged

`ENGINEERING_REVIEW.md` §M1 (pre-dates this task): *"The scope rule has three branches... `inclusion_reason` has three values... hall of fame is not among them... **Recommended.** Add `hall_of_fame` to the permitted values, **or drop the column and derive inclusion from the facts already stored — a star count, a `worlds_50_best` row, a `hall_of_fame` row. The second is more consistent with how `is_in_hotel` was resolved.**"*

The minimal fix (add the value to the CHECK) was taken; the deeper fix (derive instead of store) was not. §1.1 shows the cost of stopping at the minimal fix: the column now permits the correct value but nothing ever writes it, so the bug moved from "impossible to represent" to "possible but never actually done." This is direct precedent for this review's recommendation (§7, §16).

## 2. Every dependency on `inclusion_reason` / the four values

Full-repository grep (`inclusion_reason`, `michelin_star`, `worlds_50_best`, `hall_of_fame`, `bib_gourmand`), every hit classified:

| Dependency | File | Classification | Notes |
|---|---|---|---|
| Column + CHECK constraint | `supabase/migrations/20260805141519_production_schema_v1.sql` | **database constraint** | The definition itself |
| `restaurants_full` view | passes `r.*` through unchanged | **view** | No transformation of the column, just exposed |
| No index | — | — | Confirmed via `pg_indexes` — never indexed, never a performance-sensitive filter |
| No trigger, no function | — | — | Confirmed via grep — nothing keeps it in sync with anything |
| `insert_restaurants()` | `scripts/import_catalogue.py:678` | **import/enrichment logic** | Writes `'michelin_star'`/`'worlds_50_best'` only — the bug in §1.1 |
| `insert_hall_of_fame()` | `scripts/import_catalogue.py:799-818` | **import/enrichment logic** | Writes to `worlds_50_best`, correctly — does NOT touch `inclusion_reason` at all |
| `restaurant_repository.dart:21` | column list | **repository/business logic** | Selected, passed through |
| `restaurant_repository.dart:85` | `hallOfFameOnly` filter | **repository/business logic** | `.eq('inclusion_reason', 'hall_of_fame')` — the one real query-time dependency, and currently broken per §1.1 |
| `Restaurant.inclusionReason` field | `lib/models/restaurant.dart:14,90` | **Flutter presentation logic** (model) | Raw passthrough |
| `Restaurant.isHallOfFame` getter | `lib/models/restaurant.dart:83` | **Flutter presentation logic** | The only derived business meaning read from the value |
| `RestaurantAwardsCard` | `lib/features/restaurants/widgets/restaurant_awards_card.dart:27` | **Flutter presentation logic** | Consumes `isHallOfFame`, not the raw string — one hop removed |
| 8 test fixtures | `test/*.dart` | **test/documentation only** | Hardcode `inclusionReason: 'michelin_star'` as required-field boilerplate; none assert on its value meaningfully |
| `test/worlds_50_best_ranking_test.dart:21` | fixture | **test/documentation only** | Same pattern |
| `apply_hotel_catalogue_expansion.py` | uses an `inclusion_reason` CSV column | **import/enrichment logic (hotels, staging only)** | See §13 — never reaches an actual `hotels` table column, because that table has none |
| `bib_gourmand` | CHECK only + one pre-launch legacy migration | **database constraint / historical artifact** | Zero live rows anywhere (§1.1); see §8 |
| Documentation | `DATABASE_ARCHITECTURE.md`, `ENGINEERING_REVIEW.md`, `CHANGELOG.md`, `VALIDATION_REPORT.md`, `DATA_UPDATE_PROCESS.md`, `DATABASE_IMPORT_GUIDE.md`, `START_HERE.md` | **documentation only** | Extensive, consistent, already names the (A) semantics correctly in prose even where the code doesn't fully honor it |

**Blast radius is small and well-contained.** Exactly one Flutter model field, one derived boolean, one UI badge, one repository filter clause, one import-time write expression. No index, no trigger, no other view, no RLS policy references the column (RLS on `restaurants` is `USING (true)` for `SELECT`, unconditional — see `DATABASE_ARCHITECTURE.md` §15.2 — column-value-independent). **It is safe to change how this column is used without a wide, unpredictable ripple effect** — verified by exhaustive search, not assumed.

## 3. Target domain model

Three genuinely distinct concepts, currently conflated by a single column trying to answer more than one of them:

- **VENUE IDENTITY** — "this restaurant has exactly one row in `public.restaurants`." Owned by `restaurants` itself: `id`, `restaurant_code`, `name`, `address`, `location`. A fact about the *place*, immutable in the sense that a venue doesn't stop existing when it loses an award.
- **EXTERNAL RECOGNITION** — "which outside authorities currently recognize this restaurant, and with what value." Already correctly modeled as **N independent, per-source fact tables**: `award_history` (Michelin stars/keys), `worlds_50_best` (rank + hall-of-fame membership), and now `gault_millau_awards`/`gault_millau_special_awards`. Zero, one, or many can be true simultaneously for the same restaurant, each with its own history, its own current-vs-past distinction, its own value shape (a star count is not a rank is not a score).
- **EDITORIAL RECOGNITION** — "Mantelier itself has selected this restaurant" (Editor's Choice, One to Watch, etc.). Structurally identical in shape to EXTERNAL RECOGNITION — a future dedicated table, not a `restaurants` column, not a special case.

**These three must stay orthogonal.** A restaurant can have venue identity with zero recognition sources (should it? — see §11), or with any combination of Michelin/W50B/G&M/editorial recognition simultaneously (§10). `inclusion_reason`, single-valued by construction, can only ever answer "which ONE of these got the row created" — a `WHERE` clause on it answers a provenance question, never a "does this restaurant currently qualify" question, and treating it as if it does is exactly §1.1's bug.

## 4. Option A — extend `inclusion_reason`

**Effort:** trivial — `DROP CONSTRAINT` / `ADD CONSTRAINT` with a wider `IN (...)` list, seconds of work, no data migration, no Flutter change required to keep existing behavior working.

**Backwards compatibility:** perfect — every existing row, every existing read, unaffected. This is exactly the same shape of change `hall_of_fame` itself already was (per `VALIDATION_REPORT.md` §"One further constraint was widened before implementation").

**Multiple-recognition semantics:** **does not solve it, and cannot** — a single text column has exactly one value per row by definition. A restaurant with Michelin + G&M + W50B still only gets to record ONE of those as `inclusion_reason`, which is fine **only if the field is strictly read as original-creation provenance** (§1, (A)) and **never** as "what does this restaurant currently hold." §1.1 shows what happens when that discipline slips even once.

**Future extensibility:** the vocabulary itself extends trivially (this is the whole point of a `CHECK` over an `ENUM` — `ENGINEERING_REVIEW.md` D4 already flagged enum-vs-check inconsistency elsewhere in this schema, and text+CHECK is the pattern this column already correctly uses). But extensibility of the *value list* is not the same as extensibility of the *concept* — adding `'gault_millau'` doesn't give the schema any new way to answer "does this restaurant currently have Gault&Millau recognition," because that answer was never supposed to live here.

**Does the field remain conceptually truthful if strictly interpreted as provenance?** **Yes.** `inclusion_reason = 'gault_millau'` for a restaurant first catalogued because of Gault&Millau recognition is exactly as truthful as `inclusion_reason = 'michelin_star'` already is for the 767 restaurants first catalogued for a star that a few of them have since lost, or `'worlds_50_best'` for the 6 Hall of Fame members who happen to also hold stars today. The field has never promised "complete current recognition set" — only "why this row exists" — and under that reading, adding one value is correct and safe.

**Verdict: correct and safe as far as it goes, but insufficient alone** — it unblocks new-row creation (the literal blocker) without fixing the underlying pattern that let §1.1's bug happen, and does nothing for the actual "what does this restaurant currently hold" question that Guide screens, Explore filters, and `RestaurantAwardsCard` all actually need to answer. See §16.

## 5. Option B — neutralize `inclusion_reason` toward explicit provenance

Renaming the *concept* (not necessarily the column, yet) to something like `catalogue_origin` / `initial_source` — "which source caused this canonical row to be created" — makes the (A)-only semantics unambiguous in the schema itself rather than only in prose (`DATABASE_ARCHITECTURE.md` §3.3's sentence). Values would very plausibly stay single-valued and largely unchanged: `michelin_star`, `worlds_50_best`, `gault_millau`, `chasing_stars_editorial`, with `hall_of_fame`/`bib_gourmand` reconsidered (§8).

**Migration complexity if the *column* is actually renamed:** moderate, not trivial — every one of §2's ~10 real (non-doc) call sites reads/writes the literal string `inclusion_reason`, including a Flutter model field name and JSON key (`restaurantFullColumns`, `Restaurant.fromJson`). A rename requires the view, the Dart constant, the model, and the import script to move together, which is exactly the kind of coordinated app+DB deploy `DATABASE_ARCHITECTURE.md`'s own conventions are built to avoid needing.

**Value of the rename alone, without also fixing §1.1's underlying pattern:** low. A clearer name does not stop a future developer from writing `restaurant.catalogueOrigin == 'hall_of_fame'` and reintroducing exactly today's bug under a new name — the naming was never the root cause, the *reliance on a single-valued column for a multi-valued question* was.

**Verdict: worth doing eventually for clarity, not worth doing now** — see §14/§18 (CAN DEFER). The *semantic* neutralization (stop treating it as current-recognition, treat it as pure provenance, document that explicitly) should happen now, in prose and in usage; the *column rename* should not.

## 6. Option C — normalized `restaurant_catalogue_sources` table

Conceptually: `restaurant_catalogue_sources(restaurant_id, source, first_seen_year, source_reference, created_at)`.

**This would substantially duplicate data that already has a better home.** Walking through each proposed source:

- `michelin` → already `award_history` (richer: `guide_year`, `award_type`, `award_value`, `is_current`, `announced_on`).
- `worlds_50_best` → already `worlds_50_best` (richer: `year`, `rank`, `list_type` including hall-of-fame).
- `gault_millau` → already `gault_millau_awards` (richer: `score`, `toque_count`, `toque_colour`, `recognition_type`).
- `chasing_stars_editorial` → the one genuinely new concept, and it would need its own richer shape too the moment it's designed (a pick *type*, a *reason*, an *editor*, a *date* — precisely the same richness gap the other three rows show).

A generic `restaurant_catalogue_sources` table can only ever be as rich as its least common denominator — a bare `(restaurant_id, source, year)` triple — because a real Michelin row needs `award_type`/`award_value` and a real G&M row needs `score`/`toque_count`/`toque_colour`, fields a generic sources table has nowhere to put without either (a) a JSON blob column (a pattern this schema does not otherwise use, and for good reason — it loses the CHECK constraints, the FK integrity, and the query-plan indexability every other award table gets), or (b) becoming redundant with the dedicated tables that already exist, now needing to be kept in sync with them — a drift risk with no corresponding benefit.

**This is exactly the over-engineering trap §6's own instructions warn against.** The dedicated recognition tables are not a workaround for a missing sources table — they **are** the correct normalized provenance/membership model already, one table per source, richer than a generic table could be, and adding a generic layer on top would answer a question ("which sources recognize this restaurant") that is already trivially answerable as a `UNION`/`EXISTS` across the tables that already exist (§7).

**Verdict: rejected.** No genuine domain value beyond what §7's model already provides; real duplication risk if built.

## 7. Recognition tables as the authoritative source — confirmed

**Yes, this already matches the existing architecture, and should be made the explicit rule going forward rather than an implicit convention:**

```
restaurants               = canonical venue identity (one row per venue, forever)
award_history              = Michelin recognition/history (stars AND keys, both entity types)
worlds_50_best              = World's 50 Best recognition/history (rank + hall-of-fame)
gault_millau_awards         = Gault&Millau recognition/history
gault_millau_special_awards = Gault&Millau editorial-award history (person-level, not venue recognition — see that table's own design)
[future] chasing_stars_editorial_picks = Mantelier's own editorial recognition/history
```

`restaurants.inclusion_reason` should **never** be queried to determine current recognition of any kind — not Michelin (already correctly not: `restaurant_repository.dart` reads `michelin_stars`/`worlds_50_best_rank` directly, never `inclusion_reason`, for those two), not Hall of Fame (currently **incorrectly** still reads `inclusion_reason` — §1.1, §17), and not Gault&Millau once it exists (the reviewed `import_gault_millau.py` already gets this right by construction — it has no code path that touches `inclusion_reason` at all).

## 8. Bib Gourmand / Hall of Fame special case

**`bib_gourmand`:** a genuine **historical import artifact / reserved placeholder**, not a currently-active recognition type. `DATABASE_ARCHITECTURE.md` §3.3: *"Unstarred MICHELIN Guide entries, including Bib Gourmand, are out of scope. `inclusion_reason` already permits `bib_gourmand` so that admitting them later needs no migration."* Confirmed zero live rows anywhere (§1.1). It reserves vocabulary space for a scope decision not yet made, costs nothing sitting unused, and is orthogonal to this review's problem.

**`hall_of_fame`:** genuinely a **recognition type** wearing provenance clothing. It was added to `inclusion_reason` (per `VALIDATION_REPORT.md`/`CHANGELOG.md` M1) specifically because Hall of Fame membership is a form of qualifying recognition the scope rule needs to represent — not because any restaurant was *first catalogued* on account of it (every current Hall of Fame member already qualifies independently via 3 Michelin stars, so in practice `inclusion_reason` never even gets the chance to be `'hall_of_fame'` — see §1.1). This is the clearest evidence in the whole schema that `inclusion_reason` is carrying a recognition-type job it wasn't built for: the value exists in the CHECK constraint, was reasoned about in a governance document, and still never appears in a single real row.

**Conceptual problem exposed:** both values reveal that "reason the row was created" and "recognition the venue holds" were never fully separated, and `hall_of_fame` in particular shows what happens when a recognition fact tries to live in a provenance column — it becomes structurally permitted but practically unreachable, because a restaurant almost always ALSO qualifies through an earlier-checked branch (Michelin star) that wins the "primary reason" framing every time. Not changed here (§8 instruction), but §17's derived-column fix removes the need for `inclusion_reason` to carry this job at all going forward.

## 9. New Gault&Millau-only restaurant — exact writes under the recommended model

Worked example: `gm_030`, Azurite (Delft, Netherlands) — the one READY_TO_ADD candidate flagged `unsure` rather than `likely` for existing Michelin status in the Gault&Millau review, i.e. the strongest real candidate for this exact case.

```sql
insert into public.restaurants
  (restaurant_code, name, michelin_stars, inclusion_reason, cuisine_id,
   city_id, country_code, address, location, google_place_id,
   michelin_url, website_url, booking_url, property_name)
values
  ('rest_0775', 'Azurite', null, 'gault_millau', <cuisine_id>,
   <delft_city_id>, 'NL', 'Houttuinen 2, 2611 DX Delft',
   ST_SetSRID(ST_MakePoint(<lon>, <lat>), 4326)::geography, null,
   null, 'restaurantazurite.nl', null, null);

insert into public.gault_millau_awards
  (restaurant_id, guide_year, score, toque_count, recognition_type, gault_millau_url)
values
  (<new id>, 2026, <score if published>, <toques if published>, 'scored', <url>);
```

- `michelin_stars = NULL` — true, not a lie, not a workaround; this restaurant genuinely has no Michelin recognition today.
- `inclusion_reason = 'gault_millau'` — true under (A)'s semantics: Gault&Millau is genuinely why this row was first created. **Requires §14/§17's Option A migration** to be permitted at all.
- Nothing is written that asserts Michelin ever assessed this restaurant, nothing double-encodes the G&M score anywhere else, and `restaurants_full` continues to expose `michelin_stars` as `NULL` and (once a UI consumer exists — not built now) a current G&M standing derived the same way `worlds_50_best_rank` already is.

## 10. Multi-recognition example — Restaurant X

Michelin 2 stars (2026), World's 50 Best #37 (2026), Gault&Millau 17/20 (2026), Mantelier Editor's Choice — **exactly one row in `restaurants`:**

```
restaurants:            id=<uuid>, restaurant_code='rest_XXXX', michelin_stars=2,
                         inclusion_reason='michelin_star'   -- whichever source created the row FIRST, historically
award_history:           (entity_type='restaurant', entity_id=<id>, guide_year=2026,
                          award_type='michelin_stars', award_value=2, is_current=true)
worlds_50_best:           (restaurant_id=<id>, year=2026, rank=37, list_type='top_50')
gault_millau_awards:      (restaurant_id=<id>, guide_year=2026, score=17,
                          toque_count=<published value>, recognition_type='scored')
[future] editorial table: (restaurant_id=<id>, pick_type='editors_choice', ...)  -- not designed here
```

`restaurants_full` (extended, not built now) would expose `michelin_stars=2`, `worlds_50_best_rank=37`, and — once a G&M UI consumer justifies it — a current score/toque pair, all simultaneously, all independently derived, none stored redundantly on the `restaurants` row. `RestaurantAwardsCard` (§2) already renders exactly this shape today — `hasMichelinStar`, `isWorlds50Best`, `isHallOfFame` are already three independent, simultaneously-true booleans building up a list of badge rows; adding a fourth (`hasGaultMillau`) or fifth (`isEditorialPick`) is additive to that same pattern, not a redesign of it.

## 11. Mantelier editorial future — architecture check only

No editorial feature is designed here (per instruction). The question asked is narrower: **does today's catalogue architecture force a redesign later when editorial-only restaurants need to exist?**

**No, given §7's model.** An editorial-only restaurant (one Mantelier wants to feature that holds no Michelin/W50B/G&M recognition at all) is structurally identical to §9's Gault&Millau-only case: one `restaurants` row, `michelin_stars = NULL`, `inclusion_reason` needing exactly one more permitted value (`'chasing_stars_editorial'`, not added now — §4/§18) when that feature is actually built, plus a row in a future dedicated editorial table mirroring `gault_millau_awards`'s shape. Nothing about §9's or §10's pattern needs to change to accommodate this later — the same `CHECK`-widen-when-needed, same one-table-per-source discipline, applies unchanged.

## 12. `restaurants_full` impact

**Current derivation (confirmed from the live view definition, `supabase/migrations/20260807140000_add_venue_coordinates.sql:12-34`):**

- Michelin: `r.michelin_stars` passed through directly via `r.*` — no derivation, the catalogue table's own column is already "current."
- World's 50 Best: `left join worlds_50_best w on w.restaurant_id = r.id and w.year = (select max(year) from worlds_50_best where rank is not null)` → `w.rank as worlds_50_best_rank` — genuinely derived, always current, exactly the pattern this review recommends reusing.
- Hall of Fame: **not derived at all today** — read from `inclusion_reason` instead, and broken (§1.1).

**Recommendation for Gault&Millau: repository-joined, not a view column, for now — unchanged from the prior Gault&Millau production-readiness review's own conclusion** (`PRODUCTION_READINESS_REVIEW.md` §7), reaffirmed here with the added context of `HotelWorlds50BestRepository`'s precedent (World's 50 Best Hotels' "current ranking" is also derived at the repository/Dart layer, not a SQL view, despite `worlds_50_best_rank` on the restaurant side using a view). No Gault&Millau UI consumer exists yet; building the view column now would be speculative ahead of a real requirement. When a Guide screen is actually built, the exact same `left join ... on ... year = (select max(guide_year) from gault_millau_awards where restaurant_id = r.id)` pattern applies directly — already documented in `SCHEMA_DESIGN.md`.

**Recommendation for Hall of Fame: fix now, via a view column — not repository-joined.** Unlike Gault&Millau, this already has real consumers today (`RestaurantAwardsCard`, Explore's `hallOfFameOnly` filter) that are currently silently broken (§1.1) — this isn't a speculative future need, it's a live bug with existing callers. `is_hall_of_fame` derived the same way `worlds_50_best_rank` is (§17's SQL sketch) is the cleanest fix, additive to the view, no new repository round-trip needed since `restaurants_full` is already the thing every restaurant screen reads.

## 13. Hotel architecture comparison

**Hotels do not have an `inclusion_reason` column at all** (confirmed via `information_schema.columns` on the local dev mirror — `hotels` has no such column; only `restaurants` does). So hotels cannot have *this specific* bug. But the underlying structural gap is present in a different shape:

- `hotels.michelin_keys` is nullable (made so by `20260807150000_hotel_michelin_keys_nullable.sql`, confirmed already applied on the local dev mirror) — mirroring `restaurants.michelin_stars`'s own nullability, explicitly "so a hotel can qualify for the catalogue through The World's 50 Best Hotels alone."
- `worlds_50_best_hotels.list_type` has only 2 values (`top_50`, `extended_51_100`) — **no Hall-of-Fame-equivalent exists for hotels**, per that table's own migration comment: "The World's 50 Best Hotels publishes no Hall of Fame / Best-of-the-Best mechanism... inventing one here would misrepresent a program that does not exist." So hotels are not exposed to §1.1's specific failure mode (there is no third recognition state to misrepresent).
- **However:** the hotel catalogue-expansion CSVs (`supabase/data/enrichment/worlds_50_best_hotels/catalogue_expansion/`) independently invented an `inclusion_reason`-shaped *staging* column, including at least one compound value, `michelin_key_and_worlds_50_best` (`phase7_end_state_report.md`), to describe a hotel recognized by both sources at once. That value **never reaches an actual database column** — `hotels` has none to receive it — but its existence at the CSV/staging layer is a real signal: whoever did that work independently hit the exact same "one column can't hold two simultaneous recognitions" problem this review is solving for restaurants, and worked around it with an ad hoc compound string rather than a real multi-valued model. That workaround does not exist in the schema today and should not be allowed to become one.

**Flag for consistency, not action:** if/when hotels gain a Gault&Millau or editorial recognition path, do **not** add an `inclusion_reason` column to `hotels` to match `restaurants` — that would import the exact pattern this review is moving *away* from. Keep hotels on the nullable-award-column + dedicated-recognition-table pattern they already correctly use, which is actually **closer** to this review's target model than `restaurants` currently is. No hotel-side change is proposed or needed now.

## 14. Migration strategy

**MUST DO NOW (to unblock Gault&Millau):**

1. Widen `restaurants.inclusion_reason`'s CHECK to add `'gault_millau'` — the literal blocker. Trivial, additive, zero data migration, zero Flutter change required. (Sketch: `proposed_catalogue_architecture_fix.sql` §1.)

**MUST DO NOW (found during this audit, tightly coupled, recommended to ship alongside #1 even though it is a logically separate concern — §17):**

2. Add `is_hall_of_fame` to `restaurants_full` as a derived boolean, fixing §1.1's live bug at the data layer. Additive view change, zero risk to existing columns/consumers. (Sketch: same file, §2.)
3. *(Not SQL — a follow-up Flutter change, explicitly out of scope for this review to make, but required for #2 to actually fix anything a user sees — see §17/§21.)*

**CAN DEFER:**

- Adding `'chasing_stars_editorial'` to the same CHECK — no consumer exists yet; add it when that feature is actually built (§4, §11).
- Renaming `inclusion_reason` to a more provenance-explicit name — cosmetic, moderate coordinated-deploy cost, no functional benefit alone (§5).
- Building `restaurant_catalogue_sources` — rejected (§6).
- Adding a Gault&Millau current-recognition column to `restaurants_full` — no UI consumer yet (§12).
- Fixing `scripts/import_catalogue.py`'s `insert_restaurants()` expression that can never write `'hall_of_fame'` — low urgency once #2 means nothing reads that case from `inclusion_reason` anymore, but worth cleaning up so the script stops writing a value that documents an intent it never fulfills.
- Any hotel-side change (§13) — nothing broken there today.

Both MUST-DO-NOW SQL changes are drafted in `supabase/data/enrichment/gault_millau/proposed_catalogue_architecture_fix.sql`, marked **PREPARED — NOT APPLIED**, verified via a rolled-back local transaction (confirmed: new CHECK accepts `'gault_millau'`; `is_hall_of_fame` correctly resolves `true` for exactly the 6 real Hall of Fame restaurants and no others; restaurant count and every other column unchanged; then rolled back).

## 15. Gault&Millau import consequences, given the recommended fix

Once MUST-DO-NOW item 1 (only) ships:

- **The 41 launch-scope core award rows and 58 special award rows** (`PRODUCTION_READINESS_REVIEW.md` §13) become importable exactly as already planned — **unaffected by this review**, since every one of those rows targets an `existing_restaurant_code` already present in `restaurants`; none of them touch `inclusion_reason` at all. `import_gault_millau.py` requires no change.
- **Of the 23 READY_TO_ADD candidates**, the fix makes insertion *possible*, but §5 of the Gault&Millau review already found most are very likely already Michelin-starred restaurants missing from the catalogue for unrelated reasons (`gault_millau_new_restaurant_review.csv`, `likely_already_michelin_starred` column). Those should be verified against real Michelin status and, if confirmed Michelin-starred, routed through the **existing Michelin catalogue-expansion process** (`inclusion_reason = 'michelin_star'`, not `'gault_millau'`) — inserting them as `'gault_millau'` would misrepresent why they actually belong in the catalogue, even after this review's fix removes the technical blocker. Only genuinely Gault&Millau-exclusive candidates (`gm_030` Azurite is the one flagged `unsure` rather than `likely` — §9) are real candidates for `inclusion_reason = 'gault_millau'`.
- **Germany (deferred) and `gm_024` (REVIEW-tier address conflict)** are unaffected by this architecture review — those are launch-scope and match-confidence decisions, not schema questions, and stay exactly as `PRODUCTION_READINESS_REVIEW.md` left them.
- **No import of any kind happens as part of this review** — this is analysis only.

## 16. Recommendation

**Adopt Option A (extend the CHECK) now, narrowly, as a provenance-only value — combined with formally establishing Option "recognition tables are authoritative" (§7) as the governing rule going forward, and fixing the Hall of Fame derivation (§17) as a tightly-coupled bug fix found in the process. Reject Option C. Defer Option B's column rename.**

This is not "pick A over B and C" in isolation — it's the combination that actually solves the problem:

- **Semantic correctness:** `inclusion_reason` stays exactly as truthful as it already is today (§4) — a historical fact, never a live summary — while §7 makes explicit, in the architecture doc and in future code review, that no one may query it for current recognition. §17 removes the one place that rule was already being broken.
- **Low migration risk:** both MUST-DO-NOW changes are additive, non-breaking, verified via a rolled-back local transaction, affect a small and exhaustively-enumerated blast radius (§2), and require no coordinated Flutter deploy to ship safely (existing behavior is unaffected until the app opts into reading `is_hall_of_fame`).
- **Future extensibility:** a new source (editorial) costs one more `CHECK` value plus one more dedicated table, exactly matching the pattern Michelin/W50B/G&M already established — no redesign, per §11.
- **No duplicated recognition data:** rejecting Option C keeps every recognition fact in exactly one authoritative table (§6, §7).
- **Multi-recognition supported:** already true today at the UI layer (`RestaurantAwardsCard`'s independent booleans) and at the data layer (independent tables) — this review doesn't need to build it, only avoid breaking it, which none of the MUST-DO-NOW items do.
- **Editorial-only restaurants supported later without a redesign:** §11 confirms directly.
- **Schema stays understandable:** one column keeps meaning exactly one thing (why was this row first created), and "what does this restaurant currently hold" is answered the same way for every source — by joining its own dedicated table — with no special case except the one this review fixes (§17).

## 17. Exact recommended next implementation step

1. **Review and apply** `proposed_catalogue_architecture_fix.sql` §1 (widen the CHECK) — unblocks Gault&Millau restaurant insertion. Zero Flutter coordination required.
2. **Review and apply** the same file's §2 (`is_hall_of_fame` on `restaurants_full`) — fixes §1.1's live bug at the data layer. Zero Flutter coordination required to ship safely (additive column, nothing reads it yet).
3. **As a follow-up Flutter change** (separate PR, outside this review's scope, but the change that actually makes step 2 visible to a user): update `Restaurant.isHallOfFame` to read `is_hall_of_fame` from the row instead of `inclusionReason == 'hall_of_fame'`, and add `is_hall_of_fame` to `restaurantFullColumns`. Until this ships, step 2 is inert but harmless — the badge/filter stay exactly as broken as they are today, not worse.
4. **Separately, when actually importing Gault&Millau data**, verify each of the 23 READY_TO_ADD candidates' real-world Michelin status before choosing `inclusion_reason`; route likely-Michelin candidates through the existing Michelin catalogue-expansion process instead.
5. Everything else in §14's CAN DEFER list waits for its own trigger (an editorial feature being greenlit, a Gault&Millau UI screen being built, a hotel-side Gault&Millau/editorial need arising) — none of it should be built speculatively now.

## 18. Confirmation — nothing applied remotely

Confirmed. Every database interaction in this review connected only to a local development Postgres instance (`127.0.0.1:54322`); the one SQL sketch was applied inside a transaction and immediately rolled back (confirmed via `information_schema`/`pg_indexes` re-queries showing the pre-review state restored) — never committed, never applied to any remote or production target. No `supabase db push` was run. `git status` at the end of this review shows exactly two new files (this document, `proposed_catalogue_architecture_fix.sql`) plus the untouched pre-existing Gault&Millau enrichment folder and migration from the prior review — nothing under `lib/`, nothing in Guides/Explore/Passport/navigation, no Michelin or World's 50 Best *data* file, was created, modified, staged, or committed. Nothing was pushed.

**STOP — as instructed. Awaiting explicit further instruction before any migration is applied or any code is changed.**
