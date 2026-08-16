-- Preuvenemint Event Participant Enrichment Pilot — link SQL.
--
-- APPLIED to production on 2026-08-16, following user approval and the
-- full re-resolve -> re-verify -> duplicate-check -> write -> post-write-
-- verify sequence in docs/Architecture/EVENT_PARTICIPANT_ENRICHMENT_
-- STANDARD.md. The actual write used UUIDs re-resolved fresh at apply
-- time (per that standard's fresh-FK-revalidation rule), which matched
-- the UUIDs below exactly. See EVENT_PARTICIPANT_ENRICHMENT_REPORT.md
-- §13 and applied_status.csv for the full verification record.
--
-- This file is kept as the historical prepared artifact — re-running it is
-- safe (idempotent, ON CONFLICT DO NOTHING) but unnecessary; the row it
-- describes already exists (event_restaurants.id =
-- bb66395c-e9f4-4870-b4ce-82c8cc9debf9).
--
-- Scope: creates ONE link in the existing public.event_restaurants join
-- table only (already live in production — see the Events UI Consistency
-- Step 1 architecture doc for why no migration is needed). No restaurant
-- write, no event write, no award write, no hotel write, no schema change,
-- no RLS change.
--
-- Idempotent: ON CONFLICT DO NOTHING against the table's own
-- unique(event_id, restaurant_id) constraint, so re-running this file after
-- it has already been applied once is always a safe no-op, never a
-- duplicate-row error.
--
-- event_id  75d341a4-41d9-4e76-b47c-936048ae54a4  — 't Preuvenemint (Maastricht, NL)
-- restaurant_id  8edbcee4-8120-4de2-9bf2-6f47a74d48ac  — Tout a Fait (rest_0109, 1 Michelin star)
-- Evidence: exact_matches.csv, row 1.

begin;

insert into public.event_restaurants (event_id, restaurant_id)
values
  ('75d341a4-41d9-4e76-b47c-936048ae54a4', '8edbcee4-8120-4de2-9bf2-6f47a74d48ac') -- Tout à Fait / Tout a Fait
on conflict (event_id, restaurant_id) do nothing;

commit;
