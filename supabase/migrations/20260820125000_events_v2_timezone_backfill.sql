-- Backfills events.timezone between the two Events V2 timezone
-- migrations, so that a from-scratch replay can get past the NOT NULL
-- step. Written 2026-10-27; the filename timestamp is a replay position,
-- not that date (see "Why this filename/timestamp" below).
--
-- Why this exists: 20260820120000_events_v2_timezone_hardening.sql adds
-- events.timezone as nullable, and 20260820130000_events_v2_timezone_
-- not_null.sql then sets it NOT NULL. Its own header requires every
-- existing row to be backfilled first, and that backfill was run on
-- production as a separately approved, out-of-band UPDATE (4 live events,
-- all classified SAFE_LOCATION_DERIVATION, Europe/Amsterdam) — never
-- written into migration history. A from-scratch replay (a shadow
-- database, a preview branch, or disaster recovery into an empty
-- project) has no such out-of-band step, so the one event the migration
-- history itself inserts — 20260810160000_create_events.sql's row for
-- 't Preuvenemint (Maastricht, country_code = 'NL') — reaches the NOT
-- NULL step with timezone = NULL and the replay fails there:
--   ERROR: column "timezone" of relation "events" contains null values
-- Found by the 2026-10-27 full-stack replay (`supabase start`, 88 files),
-- which applied 33 migrations and stopped at 20260820130000.
--
-- Why this filename/timestamp: 20260820125000 sorts after
-- 20260820120000 (which creates the column) and before 20260820130000
-- (which requires it populated) — the only position where this backfill
-- does anything. Named after the highest existing migration instead, it
-- would never run: replay stops at 20260820130000 first. This is the
-- in-between-backfill exception to CLAUDE.md's monotonic-filename rule;
-- it needs `supabase db push --include-all` on production, since its
-- timestamp precedes migrations already on remote. Same shape as
-- 20260805141520_seed_countries.sql.
--
-- What it matches, and why not more: across all migration files, the
-- only INSERT into public.events is the 't Preuvenemint row above, so
-- this is the only row a replay can contain at this point. Events carry
-- no stable code — only a generated uuid — and matching on name is
-- forbidden, so the row is selected by state plus country:
-- `timezone is null and country_code = 'NL'`. Europe/Amsterdam is the
-- zone the production backfill's own classification verified for these
-- NL events; it is not derived here for any other country. Any NULL row
-- outside NL is deliberately left NULL, so 20260820130000 still fails
-- loudly on it rather than this file guessing a zone.
--
-- Idempotent against production: events.timezone is already NOT NULL
-- there, so no row can match and this is a no-op.

update public.events
set timezone = 'Europe/Amsterdam'
where timezone is null
  and country_code = 'NL';
