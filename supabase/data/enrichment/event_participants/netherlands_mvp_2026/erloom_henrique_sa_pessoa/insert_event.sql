-- Erloom x Henrique Sá Pessoa — event insert.
--
-- APPLIED to production 2026-08-16. Production event id
-- d09498ce-df42-4885-98d9-ec26fae5945c, independently re-verified
-- post-insert. Kept as the historical prepared/applied artifact — see
-- EVENT_PARTICIPANT_ENRICHMENT_REPORT.md §"APPLIED AND VERIFIED".
--
-- No event_restaurants or event_hotels links accompany this insert: no
-- Michelin-starred restaurant match exists in the production catalogue
-- for this event (see participant_matches.csv), and the venue is a farm
-- pop-up, not a hotel. Zero literal UUIDs — this is a plain insert with
-- no relationship to resolve.
--
-- MANDATORY PRE-FLIGHT (run first, separately):
--
--   select id, name, start_at, end_at from public.events
--   where name = 'Erloom x Henrique Sá Pessoa' and start_at::date = '2026-09-25';
--
-- Only proceed if that returns zero rows.

begin;

insert into public.events (
  name, description, start_at, end_at, country_code, city, venue_name,
  official_url, ticket_url, event_type, status, admission_type,
  admission_note
) values (
  'Erloom x Henrique Sá Pessoa',
  'Erloom is a traveling summer restaurant set on the biological farm ''t Schop in Hilvarenbeek, hosting a new guest chef nearly every weekend from May to September in an open-air pop-up celebrating hyper-seasonal, farm-fresh ingredients. From 25-27 September 2026, the guest chef is Henrique Sá Pessoa — concept chef of ARCA (Amsterdam) and chef of the 2-Michelin-starred Alma in Lisbon — presenting a menu connecting his Portuguese roots to Erloom''s own seasonal produce.',
  '2026-09-25 12:00:00+02'::timestamptz,
  '2026-09-27 23:00:00+02'::timestamptz,
  'NL',
  'Hilvarenbeek',
  'Erloom (bio-boerderij ''t Schop)',
  'https://erloom-restaurant.com/chefs/henrique-sa-pessoa/',
  'https://erloom-restaurant.com/',
  'dinner',
  'upcoming',
  'paid',
  'Lunch EUR 99 per person, dinner EUR 129 per person, includes the tasting menu, drink pairing, and table water. Publicly bookable via the official Erloom website.'
);

commit;
