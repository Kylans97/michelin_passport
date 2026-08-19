# Events V2 — Step 1 Database Foundation Pre-Apply Report

> **DEPLOYMENT STATUS UPDATE**: this report was written and approved *before* deployment. All 5 migrations below have since been **applied to production** and post-deploy verified (schema, data integrity, and RLS all confirmed matching this document's design exactly — see the companion `EVENTS V2 STEP 1 — PRODUCTION APPLY REPORT` / `EVENTS V2 STEP 1 — FINAL REPORT` for the deployment and verification record). The "NOT deployed to production" line immediately below describes this document's status *at the time it was written*, not the current state of production — it is left unchanged as an accurate historical record of the pre-apply gate this work passed through, not a live status indicator.

**Status: prepared, validated locally, NOT deployed to production.** This document records the exact schema audit, the exact migration files, and the exact validation performed before requesting human approval to deploy. See `docs/Architecture/EVENTS_V2_ARCHITECTURE.md` for the full product/social/analytics design this Step 1 database foundation implements — this document does not repeat that design, only the database-specific audit and preparation for Step 1 of it.

## Scope

Everything in `EVENTS_V2_ARCHITECTURE.md` §29's database table, minus wineries/bars (explicitly future-only), minus notifications/host-submissions/venue-dashboards/analytics-vendor-tables (explicitly out of Step 1's scope).

## Live schema audit (performed before writing any migration)

Every table below was queried directly against production (`supabase db query --linked`, read-only) immediately before migration design, not assumed from the architecture document:

| Table | Confirmed live state |
|---|---|
| `events` | 20 columns (per `20260810160000_create_events.sql` + `20260810180000_add_event_admission.sql`), no `moderation_status`/`availability_status`/`external_host_*`/`descriptor_tags`. **4 rows, all `status='upcoming'`.** |
| `event_attendance` | `status` CHECK is `(status = 'going')` — a single-value equality check, not an `IN`-list. **2 rows, both `status='going'`.** `unique(event_id, user_id)` confirmed present. |
| `event_restaurants` | 3 columns (`id, event_id, restaurant_id`), `unique(event_id, restaurant_id)`. **1 row** (Tout à Fait ↔ 't Preuvenemint). |
| `event_hotels` | Same shape. **0 rows.** |
| `planned_venues` | `entity_type` CHECK is `ANY (ARRAY['hotel','restaurant'])`. **8 rows.** |
| `visits` | 18 columns confirmed, no `converted_from_planned_venue_id`, no naming collision. **5 rows.** |
| `photos` | 9 columns confirmed (`visit_id` nullable, `entity_type`/`entity_id` present but unused by any current policy per prior audit). |
| `private_chefs` | `id`/`publication_status` confirmed present, for the `event_chefs.chef_id` FK target. |
| RLS (`event_attendance`, `event_restaurants`, `event_hotels`, `planned_venues`, `events`, `visits`, `photos`) | Every policy's exact `qual`/`with_check` text pulled via `pg_policies` and reproduced verbatim where this Step 1 extends it (see Migrations below) — not paraphrased from memory. |
| Migration sync | 26 local migrations, 26 remote, zero drift, confirmed via `supabase migration list --linked` immediately before writing new files. |
| Grants | Confirmed empirically (see **Grant observation** below) that `anon`/`authenticated` already hold full table-level privileges on every existing table (including recently-created ones with no explicit `GRANT` statement in their migration, e.g. `event_restaurants`) — a project-level default-privilege setting, not something configured per-migration. |

No discrepancy was found between the architecture document's description of the live schema and what production actually contains.

### Grant observation (not a Step 1 concern, noted for completeness)

`information_schema.role_table_grants` shows `anon` and `authenticated` both already hold `SELECT/INSERT/UPDATE/DELETE/...` on tables with **and** without an explicit `GRANT` statement in their own migration (e.g. `event_restaurants`, which has none, and `event_attendance`, which has one — both show identical grant sets). This confirms a project-level default-privilege setting grants broad table-level access automatically to both roles for every new table, and RLS policy role-scoping (`to authenticated`, never `to anon`, on every owner-only/friends table in this schema) is the actual, sole enforcement mechanism — the raw grant is not. This is pre-existing behavior, unrelated to and unchanged by Step 1; every new table below still gets an explicit `GRANT` statement matching established convention, and every policy is scoped correctly, so this observation has no bearing on this migration's safety.

## Proposed database model

Full detail in `EVENTS_V2_ARCHITECTURE.md` §29 (as corrected — see that document's own "Correction" call-outs in §6.3, §13/§14, §32/§33 for what changed since the previous pass). Summary of what Step 1 adds:

| Table | Change |
|---|---|
| `events` | + `moderation_status`, `availability_status`, `external_host_name`, `external_host_url`, `descriptor_tags text[]` |
| `event_restaurants` / `event_hotels` | + `is_host boolean`, `is_venue boolean` (both default `false`) — **replaces** the single-value `role` column this document's first draft proposed; see the architecture doc's §6.3 correction for why |
| `event_chefs` | **NEW** — `id, event_id → events cascade, chef_id → private_chefs cascade, is_host, is_venue, unique(event_id, chef_id)` |
| `event_attendance` | widen `status` CHECK from `('going')` to `('interested', 'going')` |
| `event_confirmed_attendance` | **NEW** — full shape below |
| `photos` | + `attendance_id → event_confirmed_attendance cascade`; `photos_read` RLS gains an `attendance_id` branch |
| `planned_venues` | widen `entity_type` CHECK to add `'event'` |
| `visits` | + `converted_from_planned_venue_id → planned_venues, on delete set null, unique` |
| `follows_restaurants` / `follows_hotels` / `follows_private_chefs` | **NEW** — `user_id, entity_id, created_at, unique(user_id, entity_id)` each |

## Event attendance migration — explicit

**Current state**: `event_attendance.status text not null default 'going' check (status = 'going')`, constraint name `event_attendance_status_check`. 2 live rows, both `status = 'going'`.

**New state**: same column, same default, same constraint name, widened definition:

```sql
alter table public.event_attendance
  drop constraint event_attendance_status_check,
  add constraint event_attendance_status_check
    check (status in ('interested', 'going'));
```

**Impact on existing rows**: none. Both existing rows already satisfy `status in ('interested', 'going')` (they're `'going'`) — the `DROP`+`ADD CONSTRAINT` pair does not rewrite, lock-scan-fail, or touch row data; it only changes what future writes are allowed to contain. **Verified locally**: after applying this migration against a full replay of the production migration history, `pg_get_constraintdef` confirms the exact resulting definition is `CHECK ((status = ANY (ARRAY['interested'::text, 'going'::text])))` — Postgres's own normalized form of the `IN`-list I wrote, semantically identical.

**Confirmed Attendance separation**: `event_confirmed_attendance` is a wholly separate table, sharing no column, trigger, or cascade with `event_attendance`. No existing or future write to `event_attendance.status` ever creates, deletes, or modifies a row in `event_confirmed_attendance`, and vice versa — the two are connected only by both referencing the same `event_id`/`user_id`, queried independently.

## Trip idempotency — final mechanism

**Problem this solves**: a future trip-completion flow, if retried (double-tap, flaky connection resubmit), must never write the same history twice — but `visits` cannot get a `unique(user_id, entity_id)` constraint, because a user must be able to genuinely visit the same restaurant many times (existing, deliberate, undisturbed behavior — confirmed 5 live `visits` rows, no uniqueness constraint of any kind on the table today, and none added by this migration).

**Mechanism**: `visits.converted_from_planned_venue_id uuid references planned_venues(id) on delete set null, unique` — populated *only* by the trip-completion flow, left `NULL` by every other creation path (manual Log Visit/Add Stay). Postgres treats `NULL` as distinct from every other `NULL` for `UNIQUE` purposes, so:

- Every ordinary manually-logged visit (5 today, and every future one) is entirely unaffected — it never populates this column.
- A retried trip-completion write for the *same specific* `planned_venues` row is rejected at the database level the second time, not merely by application discipline.
- Repeated **genuine** visits to the same venue remain fully possible — nothing about this column limits how many `visits` rows can exist for a given `(user_id, entity_id)` pair; it only limits how many can claim the same *specific plan item* as their origin.

`event_confirmed_attendance` gets the identical column for symmetry and precise provenance, but — unlike `visits` — it doesn't structurally need it: `unique(event_id, user_id)` already makes a duplicate confirmed-attendance row impossible regardless of creation path, since a specific dated event happens once for a given attendee. This is stated explicitly in both the architecture doc and this migration's own header comment, so the asymmetry is documented, not accidental.

Detecting a visit the user already logged manually *before* a prompt is ever shown remains a separate, query-time existence check (no provenance link exists for a manual visit) — unchanged from the architecture document, not a database constraint, and correctly so.

## RLS — exact policy matrix

| Table | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| `event_chefs` | `anon, authenticated` — `using (true)` | *(none — service-role/admin only)* | *(none)* | *(none)* |
| `event_confirmed_attendance` | `authenticated` — `user_id = auth.uid() OR (visibility = 'friends' AND is_friend(user_id))` | `authenticated` — `with check (user_id = auth.uid())` | `authenticated` — `using/with check (user_id = auth.uid())` | `authenticated` — `using (user_id = auth.uid())` |
| `follows_restaurants` | `authenticated` — `user_id = auth.uid()` | `authenticated` — `with check (user_id = auth.uid())` | *(none — pure membership, nothing to revise in place)* | `authenticated` — `using (user_id = auth.uid())` |
| `follows_hotels` | identical shape, `follows_hotels` | identical | *(none)* | identical |
| `follows_private_chefs` | identical shape, `follows_private_chefs` | identical | *(none)* | identical |
| `events` (modified) | `anon, authenticated` — **was** `using (true)`, **now** `using (moderation_status = 'published')` | unchanged (none) | unchanged (none) | unchanged (none) |
| `event_attendance` (modified) | unchanged shape (owner-or-friends via `is_friend()`) — only the legal `status` set widens | unchanged | unchanged | unchanged |
| `photos` (modified) | `photos_read` gains an `attendance_id` branch, reproduced byte-for-byte alongside the untouched, verified-unchanged `visit_id` branch | unchanged | unchanged | unchanged |
| `planned_venues` (modified) | unchanged (owner-only) — only the `entity_type` CHECK widens | unchanged | unchanged | unchanged |
| `visits` (modified) | unchanged (owner-or-friends) — new column carries no RLS implication of its own | unchanged | unchanged | unchanged |

Every rule the task required is satisfied: user owns their Interested/Going state (unchanged `event_attendance` RLS shape); user owns their confirmed Attendance (new table, identical ownership shape); Follow lists are owner-only, no public/friends read at all on any of the three new tables; friend-visible Going continues to flow through the same, unmodified `is_friend()` predicate; Interested defaults `private` (new legal value on an unchanged-default column — `event_attendance`'s own default stays `'going'`, unaffected; a client explicitly choosing `'interested'` sets it, and the architecture doc's own recommendation is that the *application* default that choice to `private` visibility — no schema change enforces this, since `visibility` and `status` are independent columns, matching how `event_attendance` already lets any caller pick any legal `visibility` regardless of `status`); confirmed Attendance defaults `private` (`event_confirmed_attendance.visibility` column default, enforced at the schema level); catalogue/event relationships (`event_chefs`) remain public-read wherever the parent event is (the `events_public_read` gate change means an unpublished event's linked chefs are still technically visible via `event_chefs`' own unconditional `using (true)` — see **Known scope boundary** below); clients cannot self-publish/moderate events (`moderation_status` has no client-facing INSERT/UPDATE policy of any kind, exactly like every other moderation field in this schema).

**Known scope boundary, not a defect**: `event_chefs`/`event_restaurants`/`event_hotels` keep their existing, unconditional `using (true)` read policy — a `moderation_status = 'draft'` event's linked entities remain technically queryable by directly selecting from the join table, even though the event row itself is now hidden by the widened `events_public_read` gate. This exactly matches how `event_restaurants`/`event_hotels` already behaved before this migration (their own read policy has never depended on the parent event's visibility), and closing it would require either a cross-table RLS subquery on every join table (a real, non-trivial design change not requested for Step 1) or waiting for the host-submission workflow (§19 of the architecture doc, explicitly future work) to make `moderation_status='draft'` events a real, populated case rather than a currently-empty one (every live event defaults to `'published'`). Flagged here rather than silently accepted.

## Migrations — in order

1. **`20260819140000_events_v2_host_venue_moderation.sql`** — `events` gains `moderation_status`/`availability_status`/`external_host_name`/`external_host_url`/`descriptor_tags`; `events_public_read` re-created with the moderation gate; `event_restaurants`/`event_hotels` gain `is_host`/`is_venue`; new `event_chefs` table + index + RLS.
2. **`20260819141000_events_v2_attendance_interested_going.sql`** — widens `event_attendance.status` CHECK; adds `event_attendance_event_status_idx`/`event_attendance_user_status_idx` (additive, alongside the existing single-column indexes, not replacing them).
3. **`20260819142000_events_v2_confirmed_attendance.sql`** — new `event_confirmed_attendance` table (including `converted_from_planned_venue_id` from creation, not a later `ALTER`) + index + RLS + grant; `photos` gains `attendance_id`; `photos_read` re-created with the new branch.
4. **`20260819143000_events_v2_trip_conversion_idempotency.sql`** — widens `planned_venues.entity_type` CHECK; `visits` gains `converted_from_planned_venue_id`.
5. **`20260819144000_events_v2_follow.sql`** — three new `follows_*` tables + indexes + RLS + grants.

Five files rather than one, deliberately — each is independently reviewable and each addresses one coherent piece of Step 1 (host/venue/moderation; intent widening; confirmed history; trip idempotency; follow), matching the task's own "prefer a logical sequence... if separation meaningfully improves safety" instruction. Every `ALTER` is additive (new nullable/defaulted column or a widened CHECK); every `CREATE TABLE` is a brand-new table with no prior data to migrate; two `DROP POLICY`/`CREATE POLICY` pairs (`events_public_read`, `photos_read`) change a predicate, never touch row data. No `DROP TABLE`, no `DROP COLUMN`, no data rewrite, anywhere.

## Local validation

Docker container `supabase_db_michelin_passport` (already running, healthy). `supabase db reset` was attempted first and failed — **not because of anything in this Step 1's own migrations** — on a pre-existing, unrelated gap: `20260810160000_create_events.sql`'s own inline Preuvenemint seed `INSERT` requires `countries.country_code = 'NL'` to already exist, and this project's `countries`/`cities`/`restaurants`/etc. reference data is populated in production via a separate Python import script (`scripts/import_catalogue.py`), never via a tracked migration — so a from-absolute-zero local reset has never actually been exercised end-to-end before this pass. Recovered by inserting three minimal rows (`NL`/`BE`/`FR` into `countries`, matching every country code any migration's own inline INSERT references — confirmed by grepping the full migration history) directly via `psql`, then running `supabase migration up --local` to replay every remaining migration, including all five new ones, from that point forward.

**Result: all 30 migrations (25 pre-existing + this Step 1's 5) applied cleanly, in order, with zero errors.** Verified directly against the resulting local schema afterward (not merely "no error was printed"):

- Every new column present on `events`/`event_restaurants`/`event_hotels`/`photos`/`visits`, with the exact names designed.
- `event_chefs` and `event_confirmed_attendance` both exist with every designed column, in the designed order.
- All three `follows_*` tables exist.
- Every `CHECK`/`UNIQUE`/`FOREIGN KEY` constraint's `pg_get_constraintdef()` output matches the design exactly, including `event_attendance_status_check` now reading `CHECK ((status = ANY (ARRAY['interested'::text, 'going'::text])))` and `visits_entity_type_check` **confirmed unchanged** at `('hotel', 'restaurant')` (only `planned_venues.entity_type` was widened — `visits` itself correctly has no `'event'` value, since a restaurant/hotel visit and an event confirmation are different tables entirely).
- Every RLS policy's `qual` text pulled directly from `pg_policies` and confirmed to match the design, including `events_public_read`'s new `(moderation_status = 'published'::text)` predicate and `photos_read`'s new `attendance_id` branch appearing correctly alongside its untouched `visit_id` branch.
- The locally-seeded Preuvenemint row (created by `20260810160000_create_events.sql`'s own inline insert) correctly resolved to `moderation_status = 'published', availability_status = 'unknown'` under the new defaults — confirming the moderation gate doesn't hide anything that was previously visible.

## Production safety

None of the following was touched, because no production write of any kind occurred in this task — confirmed by the absence of any `supabase db push`, any direct `UPDATE`/`INSERT`/`ALTER` against the linked project, and by every check below being read-only:

- Existing event count: **4**, unchanged (read, not re-verified post-anything since nothing was applied).
- Existing `event_attendance` count: **2**, both `status='going'`, unchanged.
- Every current Going row remains exactly `status='going'` — the widened CHECK was never applied to production, only validated locally against a schema *replica* of production's shape.
- 't Preuvenemint: unchanged (production row never touched).
- `event_restaurants`/`event_hotels` links: unchanged (**1** row, Tout à Fait ↔ Preuvenemint; **0** hotel links).
- Friends Going: unaffected — its own repository/RLS path (`event_attendance_select`, `is_friend()`) was not modified in shape, only in the legal `status` values the same policy already allowed through.
- Existing trips: unchanged (**8** `planned_venues` rows, never touched).
- Existing visits/stays: unchanged (**5** rows, never touched).
- Existing private chef data: unchanged (not queried for writes at all this task, only read once to confirm `id`/`publication_status` exist for the `event_chefs.chef_id` FK target).
- **No production write has occurred** — every production interaction this task performed was a `select`/`information_schema`/`pg_policies`/`pg_constraint`/`pg_indexes` read, or `supabase migration list --linked` (also read-only).

## Reference cases — revalidated against the corrected model

All seven resolve cleanly against `is_host`/`is_venue` (independent booleans) with no special-casing, per `EVENTS_V2_ARCHITECTURE.md` §8:

1. **Club Leroy at Parkheuvel** — `events.external_host_name = 'Club Leroy'`; `event_restaurants` row for Parkheuvel with `is_venue=true, is_host=false` — the exact correction this pass made: Parkheuvel is never auto-inferred as host merely because it's the location.
2. **Preuvenemint** — `events.venue_name='Vrijthof'` (no canonical entity); Tout à Fait linked via `event_restaurants` with `is_host=false, is_venue=false` (the live row, correctly defaulting to plain-participant under the new columns).
3. **Lucas de Jager × Winery** — `event_chefs` row (`is_host=true`) + future `event_wineries` row (`is_host=true`) — two simultaneous, independent hosts, one row each.
4. **Apostelhoeve** — future `event_wineries` row, `is_host=true, is_venue=true` on the same row (host and venue are the same fact here, expressed without a second row).
5. **Hotel × Chef weekend** — `event_hotels` row (`is_host=true, is_venue=true`) + `event_chefs` row (`is_host=true, is_venue=false`).
6. **W50B Bar guest shift (future)** — two `event_bars`-equivalent rows, one `is_host=true, is_venue=true` (the home bar), one `is_host=true, is_venue=false` (the guest).
7. **Private Chef at external venue** — `event_chefs` row (`is_host=true, is_venue=false`); `events.venue_*` populated independently, never derived from the chef's own `home_city`.

## Validation

- **Database**: `supabase migration up --local` — all 30 migrations applied with zero errors; schema/constraint/RLS verification queries above all match design exactly.
- **`dart format --output=none --set-exit-if-changed .`**: 327 files, 0 changed.
- **`flutter analyze`**: No issues found.
- **`flutter test`**: **1054/1054 passing** — identical to the pre-existing baseline, confirming zero Dart impact (no Dart file was touched in this task; no UI, repository, or model code exists yet for anything this migration adds).
- No existing test was weakened, removed, or skipped. No new Dart test was added — there is no new Dart code in this step to protect with one; the appropriate protection at this stage is the local migration replay above, which is what was performed.

## Files

**Added**: `supabase/migrations/20260819140000_events_v2_host_venue_moderation.sql`, `supabase/migrations/20260819141000_events_v2_attendance_interested_going.sql`, `supabase/migrations/20260819142000_events_v2_confirmed_attendance.sql`, `supabase/migrations/20260819143000_events_v2_trip_conversion_idempotency.sql`, `supabase/migrations/20260819144000_events_v2_follow.sql`, `docs/Architecture/EVENTS_V2_DATABASE_FOUNDATION_PRE_APPLY.md` (this file).
**Modified**: `docs/Architecture/EVENTS_V2_ARCHITECTURE.md` (three corrections from this task's Part A, folded into the existing document rather than duplicated into a new one).
**Deleted**: none.
**Unrelated exclusions**: `docs/Architecture/Michelin_Database/GAULT_MILLAU_UNBLOCK_DEPLOYMENT_REPORT.md` and every `supabase/data/enrichment/*` artifact — pre-existing from other workstreams, untouched.

---

**This was a pre-apply document at the time of writing — no production deployment had occurred, and human approval was required before any `supabase db push --linked` against this migration sequence. That approval was subsequently given and all 5 migrations have since been deployed and verified; see the deployment-status note at the top of this document.**
