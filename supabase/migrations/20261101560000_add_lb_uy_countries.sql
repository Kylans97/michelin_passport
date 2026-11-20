-- Countries Lebanon (LB) and Uruguay (UY): prerequisite for two estates on
-- The World's 50 Best Vineyards 2026 (Château Kefraya, Bekaa Valley, and
-- Bodega Garzón, Maldonado), staged in
-- supabase/data/enrichment/worlds_50_best_vineyards/. vineyards.country_code
-- references countries; vineyards keep their town as free text, so no
-- cities rows are needed.
--
-- Written 2026-11-20, on the product owner's decision of that day to put
-- the vineyards migration and the estate data in production. Filename is a
-- sequence number: the next after 20261101550000_add_vineyards.sql.
--
-- Neither code exists in production (read 2026-11-20 with a select on
-- countries). ON CONFLICT DO NOTHING keeps this safe if one is added in
-- the meantime. The zone check aborts if the server lacks either zone.
-- Columns as in 20261101310000_add_bh_ky_mu_countries.sql.

begin;

do $$
declare v_bad text;
begin
  select string_agg(z, ', ') into v_bad
    from unnest(array['Asia/Beirut', 'America/Montevideo']) as z
   where z not in (select name from pg_timezone_names);
  if v_bad is not null then
    raise exception 'Unknown timezone(s): %', v_bad;
  end if;
end;
$$;

insert into public.countries (country_code, name, flag_emoji, timezones)
values
  ('LB', 'Lebanon', '🇱🇧', array['Asia/Beirut']),
  ('UY', 'Uruguay', '🇺🇾', array['America/Montevideo'])
on conflict (country_code) do nothing;

commit;
