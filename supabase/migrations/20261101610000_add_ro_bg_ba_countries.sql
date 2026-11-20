-- Countries Romania (RO), Bulgaria (BG) and Bosnia and Herzegovina (BA):
-- prerequisite for
-- supabase/data/enrichment/journeys/journey_route_stops_seed_20261120.sql,
-- whose stops in
-- Bucharest, Sinaia, Brașov, Sofia, Plovdiv, Sarajevo and Mostar
-- reference countries(country_code). No cities rows are needed.
--
-- Written 2026-11-20 and applied that day on the product owner's
-- approval ("Yes, apply the countries prerequisite and the route stops
-- to production"). Filename is a sequence number: the next after
-- 20261101600000_add_et_country.sql.
--
-- None of the three exists in production (read 2026-11-20 with a select
-- on countries). ON CONFLICT DO NOTHING keeps this safe if one is added
-- in the meantime. Columns as in 20261101600000_add_et_country.sql.

begin;

do $$
declare
  tz text;
begin
  foreach tz in array array['Europe/Bucharest', 'Europe/Sofia', 'Europe/Sarajevo'] loop
    if tz not in (select name from pg_timezone_names) then
      raise exception 'Unknown timezone: %', tz;
    end if;
  end loop;
end;
$$;

insert into public.countries (country_code, name, flag_emoji, timezones)
values
  ('RO', 'Romania', '🇷🇴', array['Europe/Bucharest']),
  ('BG', 'Bulgaria', '🇧🇬', array['Europe/Sofia']),
  ('BA', 'Bosnia and Herzegovina', '🇧🇦', array['Europe/Sarajevo'])
on conflict (country_code) do nothing;

commit;
