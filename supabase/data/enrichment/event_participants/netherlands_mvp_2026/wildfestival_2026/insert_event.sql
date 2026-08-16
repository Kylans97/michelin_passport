-- Wildfestival 2026 — event insert.
--
-- APPLIED to production 2026-08-16. Production event id
-- eaad5729-e88c-47fa-b842-0343f6f794a2, independently re-verified
-- post-insert. Kept as the historical prepared/applied artifact — see
-- EVENT_PARTICIPANT_ENRICHMENT_REPORT.md §"APPLIED AND VERIFIED".
--
-- No event_restaurants or event_hotels links accompany this insert: De
-- Echoput and Wild Atelier are not in the production catalogue (see
-- participant_matches.csv). Zero literal UUIDs.
--
-- MANDATORY PRE-FLIGHT (run first, separately):
--
--   select id, name, start_at, end_at from public.events
--   where name = 'Wildfestival' and start_at::date = '2026-09-13';
--
-- Only proceed if that returns zero rows.

begin;

insert into public.events (
  name, description, start_at, end_at, country_code, city, venue_name,
  official_url, ticket_url, event_type, status, admission_type,
  admission_note
) values (
  'Wildfestival',
  'The 3rd edition of Wildfestival, hosted by Hotel Gastronomique De Echoput on the Veluwe, is a culinary preview celebrating game, nature, gastronomy, wine, and local seasonal products. Chefs Peter Paul van den Breemen (De Echoput) and Jonathan Zandbergen (Wild Atelier) present a 4-course walking lunch featuring game and seasonal produce, alongside tastings and demonstrations in an informal festival atmosphere. Previous editions sold out.',
  '2026-09-13 13:00:00+02'::timestamptz,
  '2026-09-13 17:00:00+02'::timestamptz,
  'NL',
  'Apeldoorn',
  'Hotel Gastronomique De Echoput',
  'https://www.echoput.nl/agenda',
  'https://www.eventbrite.nl/e/tickets-wildfestival-2026-culinair-preuvenement-1993438945548',
  'tasting',
  'upcoming',
  'paid',
  'EUR 114 per person. Previous editions sold out — early booking recommended, per the official site.'
);

commit;
