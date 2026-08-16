-- Vergeet Mij Niet Gala — event insert.
--
-- APPLIED to production 2026-08-16. Production event id
-- fd23d7f5-ff7c-4caf-ba9b-a17e6397a607, independently re-verified
-- post-insert. Kept as the historical prepared/applied artifact — see
-- EVENT_PARTICIPANT_ENRICHMENT_REPORT.md §"APPLIED AND VERIFIED" and
-- §"Future enrichment note" for the chef-line-up re-check plan.
--
-- No event_restaurants or event_hotels links accompany this insert:
-- no specific participating restaurant was officially named in the
-- sources found in this pass (see EVENT_PARTICIPANT_ENRICHMENT_REPORT.md
-- for the plausible-but-unconfirmed Ciel Bleu/Yamazato note — plausible
-- is not evidence, so nothing is linked), and Hotel Okura Amsterdam
-- itself is not yet in the production hotel catalogue. Zero literal
-- UUIDs.
--
-- RECOMMENDED FOLLOW-UP BEFORE APPLYING: re-check the official site
-- closer to the event date for a published chef/restaurant lineup, and
-- re-run the fresh-FK/participant-matching pass in
-- EVENT_PARTICIPANT_ENRICHMENT_STANDARD.md if one is published.
--
-- MANDATORY PRE-FLIGHT (run first, separately):
--
--   select id, name, start_at, end_at from public.events
--   where name = 'Vergeet Mij Niet Gala' and start_at::date = '2026-10-06';
--
-- Only proceed if that returns zero rows.

begin;

insert into public.events (
  name, description, start_at, end_at, country_code, city, venue_name,
  official_url, ticket_url, event_type, status, admission_type,
  admission_note
) values (
  'Vergeet Mij Niet Gala',
  'The first edition of the Vergeet Mij Niet Gala brings together some of the finest restaurants in the Netherlands for an evening of gastronomy, storytelling and entertainment in the Grand Ballroom of Hotel Okura Amsterdam. Guests enjoy an aperitif, a 5-course dinner prepared by leading Dutch chefs, drinks and entertainment, black tie with a touch of yellow. All proceeds support research, guidance and awareness for young-onset dementia, including Alzheimer''s research.',
  '2026-10-06 18:00:00+02'::timestamptz,
  '2026-10-06 23:59:00+02'::timestamptz,
  'NL',
  'Amsterdam',
  'Hotel Okura Amsterdam (Grand Ballroom)',
  'https://www.vergeetmijnietgala.nl',
  'https://www.vergeetmijnietgala.nl',
  'dinner',
  'upcoming',
  'paid',
  'EUR 575 per seat, or EUR 5,500 per table of 10. Black tie with a touch of yellow. Proceeds benefit dementia research and awareness.'
);

commit;
