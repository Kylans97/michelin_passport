# Deployment Order — Verified Against Actual Schema, Not Assumed

**Status: documentation only. Nothing applied.**

The task's suggested conceptual order was: (1) make `michelin_keys` nullable, (2) create `worlds_50_best_hotels`, (3) insert 94 new hotels, (4) insert/reconcile 200 ranking rows, (5) validate invariants. Direct inspection of `20260805141519_production_schema_v1.sql` confirms this order is necessary but **incomplete** — one step is missing that the earlier research didn't need to surface, and one step turns out to gate almost everything downstream of it today.

## The order, as verified

1. **Apply `20260807150000_hotel_michelin_keys_nullable.sql`.**
   Required before step 3: 82 of the 94 new hotels have no confirmed Key value, and `hotels.michelin_keys` is `NOT NULL` until this runs. No dependency on step 2.

2. **Apply `20260807160000_create_worlds_50_best_hotels.sql`.**
   Required before step 4 (`insert into worlds_50_best_hotels` needs the table to exist). No dependency on step 1 — the two migrations are independent and could apply in either order, but are numbered sequentially for a single, ordered migration history.

3. **Resolve or insert `countries` / `cities` rows for the new hotels' locations — a step the original 5-step sketch omitted.**
   `hotels.city_id` and `hotels.country_code` are both `NOT NULL` foreign keys. Direct query against the local database confirms **15 of the 26 new countries this expansion touches do not yet have a `countries` row at all** (Australia, Costa Rica, Fiji, French Polynesia, Greece, India, Indonesia, Malaysia, Maldives, Morocco, New Zealand, Oman, South Africa, Sri Lanka, St. Barthélemy) — the other 11 (China, France, Hong Kong, Mexico, Peru, Sweden, Thailand, Turkey, UAE, UK, USA) already exist because restaurants already cover them. Every city these 94 hotels sit in is new regardless, since no hotel or restaurant currently uses any of them. `apply_hotel_catalogue_expansion.py` performs this resolution automatically and idempotently, immediately before each hotel insert — not as a separate manual step — but it is a real, load-bearing part of the dependency chain and belongs in this list explicitly.

4. **Insert new hotel rows — gated by a requirement the original 5-step sketch didn't anticipate.**
   `hotels.address text not null` and `hotels.location geography(Point,4326) not null`. Neither is nullable. **As of this pass, 0 of the 94 candidate hotels have independently verified address and coordinates** — Phase 1 and this pass's research deliberately never attempt to guess a Google Place ID or lat/long, per the standing "never guess coordinates" guardrail. This means step 4, as designed, inserts **zero hotel rows today**, not 94. It remains ready to insert every hotel that later gets verified coordinates, without any script change.

5. **Insert / reconcile ranking-history rows into `worlds_50_best_hotels`.**
   `worlds_50_best_hotels.hotel_id` is `NOT NULL`, so a ranking row can only be inserted once its hotel exists. This splits into two independent sub-cases the original sketch collapsed into one:
   - **34 rows** whose hotel is one of the existing 21 already-catalogued, already-matched hotels — resolvable via `hotel_code` today, independent of step 4's outcome. These insert successfully in a run today.
   - **166 rows** whose hotel is one of the 94 new candidates — blocked until that specific hotel clears step 4. Classified `BLOCKED_DEPENDENT_HOTEL`, not silently dropped, not inserted with a fabricated `hotel_id`.

6. **Validate catalogue invariants** (post-deploy checks — see `apply_hotel_catalogue_expansion.py::run_post_deploy_checks`).

## Net correction to the original 5-step sketch

The real dependency chain has **6 steps, not 5** — country/city resolution is a genuine, necessary step the original sketch folded silently into "insert 94 new hotels," and doing so would have hidden a real FK dependency rather than handled it. More importantly: **step 4 is the actual bottleneck of this entire expansion.** Both migrations (steps 1-2) are ready to apply today. Country/city resolution (step 3) is ready to run today. But until per-hotel address and coordinates exist, step 4 inserts nothing, which caps step 5 at the 34 rows that don't depend on it. The Key-status research in this pass (`phase8_production_readiness_report.md` §3) closes the Key-tier gap for most of the 94 candidates — it does not, and cannot, close the coordinates gap, which is a categorically different kind of research (geocoding, not published-source lookup) and was explicitly out of scope for this pass.
