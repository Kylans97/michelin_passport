-- Country Georgia (GE): prerequisite for the Kakheti wine region, staged in
-- supabase/data/enrichment/wine_regions/wine_regions_seed_classics_v1.sql.
-- wine_regions.country_code references countries; no cities rows are
-- needed.
--
-- Written 2026-11-21, on the product owner's request "kunnen we al met 2:
-- Europa breder?". Filename is a sequence number: the next after
-- 20261101610000_add_ro_bg_ba_countries.sql.
--
-- GE does not exist in production (read 2026-11-21 with a select on
-- countries). ON CONFLICT DO NOTHING keeps this safe if it is added in the
-- meantime. The zone check aborts if the server lacks the zone. Columns as
-- in 20261101600000_add_et_country.sql. No function is created.

begin;

do $$
begin
  if 'Asia/Tbilisi' not in (select name from pg_timezone_names) then
    raise exception 'Unknown timezone: Asia/Tbilisi';
  end if;
end;
$$;

insert into public.countries (country_code, name, flag_emoji, timezones)
values
  ('GE', 'Georgia', '🇬🇪', array['Asia/Tbilisi'])
on conflict (country_code) do nothing;

commit;
