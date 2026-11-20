-- Country Ethiopia (ET): prerequisite for the Ethiopian wine region (the
-- Rift Valley vineyard near Ziway), staged in
-- supabase/data/enrichment/wine_regions/wine_regions_seed_africa_v1.sql.
-- wine_regions.country_code references countries; no cities rows are
-- needed.
--
-- Written 2026-11-20, on the product owner's request of that day: "I want
-- to add the wine regions of Morocco and Ethiopia". Filename is a
-- sequence number: the next after
-- 20261101590000_add_wine_region_outlines.sql.
--
-- ET does not exist in production (read 2026-11-20 with a select on
-- countries); Morocco (MA) already does. ON CONFLICT DO NOTHING keeps
-- this safe if ET is added in the meantime. The zone check aborts if the
-- server lacks the zone. Columns as in 20261101560000_add_lb_uy_countries.sql.

begin;

do $$
begin
  if 'Africa/Addis_Ababa' not in (select name from pg_timezone_names) then
    raise exception 'Unknown timezone: Africa/Addis_Ababa';
  end if;
end;
$$;

insert into public.countries (country_code, name, flag_emoji, timezones)
values
  ('ET', 'Ethiopia', '🇪🇹', array['Africa/Addis_Ababa'])
on conflict (country_code) do nothing;

commit;
