# World's 50 Best Hotels — Schema Design Proposal

**Status: design for review. No migration has been written or applied.**

---

## 1. Current state, confirmed by direct inspection

`public.worlds_50_best` (from `supabase/migrations/20260805141519_production_schema_v1.sql`):

```sql
create table public.worlds_50_best (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  year smallint not null,
  rank smallint,
  list_type text not null default 'top_50'
    check (list_type in ('top_50', 'extended_51_100', 'hall_of_fame')),
  unique (restaurant_id, year)
);
```

**`restaurant_id` is a hard, `NOT NULL`, typed foreign key to `restaurants(id)`.** There is no `entity_type` column, no way to attach a hotel row without either a schema change or an unacceptable hack (inserting a fake restaurant row). The table is restaurant-specific by construction, not by convention — confirmed, not assumed.

`hotels_full` (both the original view and the `add_venue_coordinates.sql` revision landed by the concurrent MVP work this week) has no World's 50 Best exposure at all, unlike `restaurants_full`, which carries a derived `worlds_50_best_rank` column via a join on `restaurant_id`.

---

## 2. Two options

### Option A — Generalize `worlds_50_best` to `entity_type`/`entity_id`

```sql
-- illustrative only, not a migration to apply
alter table worlds_50_best rename column restaurant_id to entity_id;
alter table worlds_50_best add column entity_type text not null default 'restaurant'
  check (entity_type in ('restaurant', 'hotel'));
alter table worlds_50_best drop constraint worlds_50_best_restaurant_id_fkey;
alter table worlds_50_best add constraint worlds_50_best_hall_of_fame_restaurant_only
  check (list_type <> 'hall_of_fame' or entity_type = 'restaurant');
```

Mirrors `award_history`'s existing polymorphic shape exactly (`entity_type`/`entity_id`), which is already a proven, documented pattern in this schema.

### Option B — New `worlds_50_best_hotels` table, `worlds_50_best` untouched

```sql
-- illustrative only, not a migration to apply
create table public.worlds_50_best_hotels (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references public.hotels(id) on delete cascade,
  year smallint not null,
  rank smallint,
  list_type text not null default 'top_50'
    check (list_type in ('top_50', 'extended_51_100')),
  unique (hotel_id, year)
);

create unique index worlds_50_best_hotels_year_rank_uidx
  on worlds_50_best_hotels (year, rank) where rank is not null;
```

Structurally a sibling of `worlds_50_best`, not a modification of it. Note `list_type` deliberately excludes `hall_of_fame` in its own `CHECK` — see §3.

---

## 3. Evaluation

| Criterion | Option A (polymorphic) | Option B (separate table) |
|---|---|---|
| **Migration risk** | Real `ALTER` on a live, populated table (800+ existing rows once the restaurant history + Hall of Fame data is deployed): rename column, add column, backfill, drop/re-add constraints. Not purely additive. | Purely additive — a new `CREATE TABLE`, nothing about the existing table or its rows changes at all. |
| **FK integrity** | None on `entity_id` — same accepted trade-off already in use for `award_history`, `visits`, `wishlist`, `photos` (documented compensating controls: append-only catalogue, service-role-only writes, regression suite). Not a new risk category, but does add a table to that list. | Real, Postgres-enforced `FOREIGN KEY ... REFERENCES hotels(id)`. Strictly stronger guarantee. |
| **Flutter querying** | One query, `WHERE entity_type = 'hotel'`, for "hotel ranking history." A future "all World's 50 Best across both venue types" view needs no `UNION`. | Hotel-only queries never need an `entity_type` filter at all — simpler for the two features actually requested (Explore filter, Hotel Detail history). A combined cross-type view needs a `UNION ALL` of two tables — cheap, standard, not a real cost. |
| **Historical scalability** | Absorbs a future third `entity_type` (if 50 Best ever adds a category beyond restaurants/hotels) with no new table. | A third category means a third near-identical table. |
| **Future Hall of Fame / special list types** | Hotels currently have **no** Hall of Fame equivalent (confirmed by research — no retirement/Best-of-the-Best mechanism exists for hotels as of the 2025 edition). A same-row `CHECK (list_type <> 'hall_of_fame' OR entity_type = 'restaurant')` handles this correctly, but it's an extra rule to maintain and to notice. | The new table's own `list_type CHECK` simply never lists `hall_of_fame` as a hotel-side option — the constraint enforces the real-world asymmetry by omission, with no cross-column logic needed. |
| **Consistency with `award_history`** | Matches it exactly — same polymorphic shape, same maintenance mental model project-wide. | Diverges from it — two "historical achievement" tables now follow two different conventions. A future engineer has to remember which pattern governs which table. |
| **Backwards compatibility with existing restaurant code** | Every existing consumer of `restaurant_id` on this table changes: `restaurants_full`'s join condition, `insert_hall_of_fame()`, `insert_worlds_50_best_top50()`, `insert_worlds_50_best_history()` (built this workstream), and the restaurant `worlds_50_best_review.csv`/`worlds_50_best_history.csv` pipeline all reference `restaurant_id` directly today. | Zero existing restaurant-side code changes. Every function, view, and CSV built so far for the restaurant World's 50 Best workstream keeps working exactly as-is. |

---

## 4. Recommendation

**Option B now. Option A is the architecturally cleaner long-term shape, but this is not the moment to take on that migration risk.**

Three reasons, in order of weight:

1. **The project is mid-MVP, with a concurrent team actively shipping.** Two new migrations landed from that work in the time this single enrichment workstream has been running. A real `ALTER` on `worlds_50_best` — a table the Flutter app's `restaurants_full` view already depends on in production — is exactly the kind of change that should happen deliberately, on its own review cycle, not bundled into a hotel-data feature.
2. **Everything else in this entire enrichment effort has been additive by design**, specifically to keep every step independently reviewable and independently reversible. `worlds_50_best_hotels` continues that discipline exactly: it can be created, populated, reviewed, and — if the decision ever goes the other way — dropped, without a single existing table or row ever being touched.
3. **The two entity types genuinely have different valid `list_type` vocabularies today** (hotels have no Hall-of-Fame equivalent). Option B lets that asymmetry live in the schema directly (the new table's own `CHECK` simply doesn't offer `hall_of_fame`), rather than in a cross-column rule that has to be remembered and re-verified every time the table is touched.

**When to revisit Option A:** once both `worlds_50_best` (restaurant) and `worlds_50_best_hotels` are stable, populated, and shipped, a deliberate "generalize achievement history" migration — reviewed on its own, with its own dry-run cycle exactly like every migration in this project — can merge them. Having two clean, well-tested, correctly-shaped tables to merge at that point is a safer starting position than rushing the merge now, before the hotel data itself has even been reviewed.

**Not implemented.** This is a design for review, per your instruction. No migration file has been created.
