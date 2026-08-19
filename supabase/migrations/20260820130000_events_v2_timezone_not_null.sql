-- Events V2 — Timezone Hardening, part 2 of 2: tightens events.timezone
-- to NOT NULL.
--
-- MUST NOT be deployed until AFTER 20260820120000's nullable column has
-- shipped AND every existing events row has been backfilled with a
-- verified timezone value (see the Step 2/2 pre-apply report's backfill
-- classification — all 4 live events classified SAFE_LOCATION_DERIVATION,
-- Europe/Amsterdam). This is a deliberately separate migration, not
-- bundled with part 1, specifically so the backfill UPDATE can be its own
-- independently reviewed, independently approved action between the two
-- schema changes — mirroring this project's own established pattern of
-- never bundling a schema change with the data write that depends on it
-- having already happened (see the Parkheuvel phone rollout for the same
-- shape: migration deployed and verified first, the actual data UPDATE
-- applied and independently verified second).
--
-- Running this migration while any row still has timezone = NULL will
-- fail outright (a NOT NULL constraint addition is rejected by Postgres
-- if existing data violates it) — which is the correct, safe failure mode
-- here: better a rejected migration than a silently incomplete backfill.
--
-- NOT applied to production by this migration file's authoring — prepared
-- for pre-deployment review only, and not part of this task's own human
-- apply gate (which asks approval only for the part 1 migration and the
-- backfill UPDATE) — this file is staged and ready for a follow-up
-- approval once the backfill is confirmed complete with zero remaining
-- NULLs.

begin;

alter table public.events
  alter column timezone set not null;

commit;
