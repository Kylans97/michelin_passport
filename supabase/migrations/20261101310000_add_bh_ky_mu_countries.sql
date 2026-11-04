-- Countries Bahrain (BH), Cayman Islands (KY) and Mauritius (MU): prerequisite for
-- events from supabase/data/enrichment/events/world_event_overview_20261105.csv
-- (events.country_code references countries; events.city is free text, so no
-- cities rows are needed).
--
-- Written 2026-11-05, on the product owner's decision of that day ("ja laten we
-- die landen toevoegen"). Filename timestamp is a sequence number only: the next
-- after 20261101300000, the highest migration on main when written. If another
-- unapplied migration has taken this number by the time this is applied, rename
-- this file to follow the highest one (it has not been applied anywhere).
--
-- None of the three exists in any countries insert in supabase/migrations/ on
-- main (checked 2026-11-05). The live table was NOT read from this session (no
-- production access): ON CONFLICT DO NOTHING keeps this safe if one was added by
-- hand in the meantime. The zone check below aborts if production's
-- pg_timezone_names lacks one of the three zones.
--
-- Columns as in 20261101300000_add_europe9_2026_countries_and_cities.sql:
-- country_code, name, flag_emoji, timezones (20261018120000_add_country_timezones).

begin;

-- Abort (nothing applied) if the server's tz database lacks one of the zones.
do $$
declare v_bad text;
begin
  select string_agg(z, ', ') into v_bad
    from unnest(array['Asia/Bahrain', 'America/Cayman', 'Indian/Mauritius']) as z
   where z not in (select name from pg_timezone_names);
  if v_bad is not null then
    raise exception 'Unknown timezone(s): %', v_bad;
  end if;
end;
$$;

insert into public.countries (country_code, name, flag_emoji, timezones)
values
  ('BH', 'Bahrain',        '🇧🇭', array['Asia/Bahrain']),
  ('KY', 'Cayman Islands', '🇰🇾', array['America/Cayman']),
  ('MU', 'Mauritius',      '🇲🇺', array['Indian/Mauritius'])
on conflict (country_code) do nothing;

commit;
