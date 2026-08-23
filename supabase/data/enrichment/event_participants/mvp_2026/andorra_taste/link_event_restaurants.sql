-- Andorra Taste 2026 — event + participant-link SQL.
--
-- APPLIED to production 2026-08-23. Production event id
-- 35dd62ac-2d72-40e1-a231-8518358d169d, independently re-verified
-- post-insert (event row + all 6 event_restaurants rows read back and
-- confirmed). Kept as the historical prepared/applied artifact — see
-- EVENT_PARTICIPANT_ENRICHMENT_REPORT.md's Applied Status section.
--
-- SCHEMA DRIFT CORRECTION: the version originally prepared 2026-08-16
-- (preserved in git history) inserted start_at/end_at as literal
-- timestamps with no timezone/start_date/end_date columns at all — this
-- predates the Events V2 Time Precision migrations (2026-08-22), which
-- added those three as NOT NULL. The first apply attempt on 2026-08-23
-- failed cleanly (transaction rolled back, zero partial writes,
-- independently confirmed) with "null value in column timezone violates
-- not-null constraint". This version below is what was actually
-- executed: since this event's exact clock time was never really
-- researched (the original 00:00:00/23:59:59 were always whole-day
-- placeholders, never sourced times), it is applied as a genuine
-- date-only Event — start_at/end_at NULL, timezone='Europe/Andorra',
-- start_date/end_date populated — matching the live precedent already
-- set by Douro to Table / Forces of Nature. Same originally-researched
-- facts (Sept 16-20 2026, Escaldes-Engordany, Andorra), just represented
-- via the schema's current date-only shape rather than a fabricated
-- exact instant.
--
-- Deliberately contains ZERO literal restaurant UUIDs — every restaurant
-- identifier resolves via its stable restaurant_code at apply time, per
-- the fresh-FK-revalidation rule (docs/Architecture/
-- EVENT_PARTICIPANT_ENRICHMENT_STANDARD.md §8).
--
-- MANDATORY PRE-FLIGHT (run first, separately):
--
--   select id, name, start_date, end_date from public.events
--   where name = 'Andorra Taste' and start_date = '2026-09-16';
--
-- Only proceed to the block below if that returns zero rows — it did,
-- confirmed immediately before this apply. Idempotent: re-running this
-- file today would insert a genuine SECOND Andorra Taste event (no
-- unique constraint on name/start_date), so it is not safe to blindly
-- re-run — the event_restaurants half alone (on conflict do nothing) is
-- idempotent against the existing event_id, but the event insert itself
-- is not. Do not re-run without first confirming via the pre-flight
-- query above.

begin;

with new_event as (
  insert into public.events (
    name, description, country_code, city, venue_name,
    address, official_url, ticket_url, event_type, status,
    admission_type, admission_note, timezone, start_date, end_date
  ) values (
    'Andorra Taste',
    'The 5th edition of the International High Mountain Gastronomy Meeting brings together 18 chefs from France, Spain, Austria, Italy, Peru and Andorra — 14 international participants carrying 19 Michelin stars between them — to explore how territory, altitude, climate and biodiversity shape mountain cuisine. The 2026 edition spotlights France as guest country and presents the Andorra Taste Award 2026 to chef Virgilio Martínez of Central (Lima).',
    'AD',
    'Escaldes-Engordany',
    'El Prat del Roure',
    'C/ Veedors, Escaldes-Engordany, Andorra',
    'https://www.andorrataste.com/en',
    null,
    'festival',
    'upcoming',
    'mixed',
    'General-public programme (showcookings, demonstrations at El Prat del Roure, Sept 18-20) is free to attend, with limited capacity for some activities. A separate professional/trade agenda runs Sept 16-18.',
    'Europe/Andorra',
    '2026-09-16',
    '2026-09-20'
  )
  returning id
)
insert into public.event_restaurants (event_id, restaurant_id)
select
  new_event.id,
  r.id
from new_event
cross join public.restaurants r
where r.restaurant_code in (
  'rest_0330', -- Cocina Hermanos Torres (Sergio y Javier Torres)
  'rest_0271', -- Rote Wand Chef's Table (Julian Stieger)
  'rest_1223', -- Le Prince Noir - Vivien Durand
  'rest_0359', -- LÚ Cocina y Alma (Juanlu Fernández)
  'rest_0363', -- Paco Roncero
  'rest_0372'  -- Iván Cerdeño
)
on conflict (event_id, restaurant_id) do nothing;

commit;

-- Post-write state, independently re-verified: 1 new events row (id
-- 35dd62ac-2d72-40e1-a231-8518358d169d), 6 new event_restaurants rows,
-- all six resolving to Michelin-starred restaurants (3+2+1+2+2+2 stars
-- respectively), all is_host=false/is_venue=false, zero duplicates.
-- events total 27 -> 28; event_restaurants total 28 -> 34.
