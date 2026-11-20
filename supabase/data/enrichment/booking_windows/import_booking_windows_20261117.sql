-- Booking windows, research import: 37 restaurants.
-- Prepared 2026-11-17 from the reviewed staging files in this folder
-- (status = 'proposed' only): booking_windows_staging.csv, booking_windows_w50b_2026_staging.csv, booking_windows_three_star_staging.csv.
-- Research run 2026-11-16, see RUN_LOG.md. Every rule was re-fetched from the
-- restaurant's own page and matched word for word.
--
-- NOT a migration. Applied to production only with the product owner's
-- approval, as one transaction:
--   supabase db query --linked -f supabase/data/enrichment/booking_windows/import_booking_windows_20261117.sql
--
-- Safety, in order:
--   1. Every restaurant_code + country_code must resolve to exactly one
--      restaurant, or the whole import aborts. Never matched on name.
--   2. A restaurant with an active venue manager (revoked_at is null) or
--      with any existing window is skipped: the venue's own word wins and
--      nothing is overwritten. Skips are reported, not errors.
--   3. Rows are written with source_kind = 'research', source_url = the
--      evidence URL, verified_on = the date it was checked, updated_by null.
--      The table's own checks and timezone trigger still apply.
--   4. The final counts are asserted before commit.

begin;

create temp table staged_window (
  restaurant_code text, country_code text, kind text, timezone text,
  rolling_amount smallint, rolling_unit text, release_day smallint,
  months_ahead smallint, release_time time, platform text,
  source_url text, verified_on date
) on commit drop;

insert into staged_window values
  ('rest_0033', 'NL', 'rolling', 'Europe/Amsterdam', 3, 'month', null, null, null, null, 'https://restaurantdekas.com/nl/faq', '2026-11-16'), -- De kas (NL)
  ('rest_0075', 'NL', 'rolling', 'Europe/Amsterdam', 3, 'month', null, null, '10:00', null, 'https://odille.nl/#faq', '2026-11-16'), -- Odille (NL)
  ('rest_0118', 'NL', 'rolling', 'Europe/Amsterdam', 56, 'day', null, null, null, 'other', 'https://www.restaurantwils.nl/reserveringen', '2026-11-16'), -- Wils (NL)
  ('rest_1402', 'NL', 'rolling', 'Europe/Amsterdam', 3, 'month', null, null, null, 'other', 'https://www.rozewied.nl/reserveren/', '2026-11-16'), -- Rozewied (NL)
  ('rest_0301', 'HK', 'rolling', 'Asia/Hong_Kong', 30, 'day', null, null, '00:00', 'sevenrooms', 'https://wingrestaurant.hk/reserve', '2026-11-16'), -- Wing (W50B 2026)
  ('rest_0135', 'PE', 'rolling', 'America/Lima', 5, 'month', null, null, null, 'other', 'https://www.kjolle.com/reservaciones', '2026-11-16'), -- Kjolle (W50B 2026)
  ('rest_0044', 'ES', 'rolling', 'Europe/Madrid', 90, 'day', null, null, '00:00', 'own_site', 'https://www.diverxo.com/es/reservar', '2026-11-16'), -- DiverXO (W50B 2026)
  ('rest_0311', 'TH', 'rolling', 'Asia/Bangkok', 60, 'day', null, null, null, 'sevenrooms', 'http://www.restaurantsuhring.com/reservation.html', '2026-11-16'), -- Sühring (W50B 2026)
  ('rest_0317', 'ES', 'rolling', 'Europe/Madrid', 60, 'day', null, null, null, 'own_site', 'https://enigmaconcept.es/reserva', '2026-11-16'), -- Enigma (W50B 2026)
  ('rest_0237', 'CH', 'rolling', 'Europe/Zurich', 8, 'month', null, null, null, 'own_site', 'http://www.schauenstein.ch/reservierung', '2026-11-16'), -- Schloss Schauenstein (W50B 2026)
  ('rest_1376', 'AU', 'rolling', 'Australia/Sydney', 6, 'month', null, null, null, 'opentable', 'https://www.saintpeter.com.au/reservations', '2026-11-16'), -- Saint Peter (W50B 2026)
  ('rest_0502', 'JP', 'monthly', 'Asia/Tokyo', null, null, 1, 2, null, 'other', 'https://sazenka.com/reservation', '2026-11-16'), -- Sazenka (W50B 2026)
  ('rest_0319', 'JP', 'rolling', 'Asia/Tokyo', 1, 'month', null, null, '00:00', 'other', 'https://www.aoyama-florilege.jp/reservations.html', '2026-11-16'), -- Florilège (W50B 2026)
  ('rest_0837', 'BE', 'monthly', 'Europe/Brussels', null, null, 1, 3, null, 'other', 'https://www.thejaneantwerp.com/faq/', '2026-11-16'), -- The Jane (W50B 2026)
  ('rest_4202', 'SG', 'rolling', 'Asia/Singapore', 60, 'day', null, null, null, 'sevenrooms', 'https://seroja.sg/reservations', '2026-11-16'), -- Seroja (W50B 2026)
  ('rest_1387', 'ES', 'rolling', 'Europe/Madrid', 90, 'day', null, null, null, 'own_site', 'https://txispa.com/faqs/', '2026-11-16'), -- Txispa (W50B 2026)
  ('rest_0322', 'FR', 'rolling', 'Europe/Paris', 21, 'day', null, null, '10:00', 'other', 'https://www.septime-charonne.fr', '2026-11-16'), -- Septime (W50B 2026)
  ('rest_4205', 'TH', 'rolling', 'Asia/Bangkok', 60, 'day', null, null, null, 'other', 'https://www.tablecheck.com/en/shops/baan-tepa-culinary-space/reserve', '2026-11-16'), -- Baan Tepa (W50B 2026)
  ('rest_0532', 'JP', 'rolling', 'Asia/Tokyo', 2, 'month', null, null, '12:00', 'phone', 'https://www.jimbochoden.com/en/reserve/', '2026-11-16'), -- Den (W50B 2026)
  ('rest_0154', 'BE', 'rolling', 'Europe/Brussels', 120, 'day', null, null, null, null, 'https://www.zilte.be/en/reservations', '2026-11-16'), -- Zilte (three stars)
  ('rest_0155', 'BE', 'monthly', 'Europe/Brussels', null, null, 1, 3, null, 'other', 'https://www.restaurantboury.be/reserveren', '2026-11-16'), -- Boury (three stars)
  ('rest_2772', 'CN', 'rolling', 'Asia/Shanghai', 90, 'day', null, null, null, 'own_site', 'https://sh.taian-table.cn/faq', '2026-11-16'), -- Taian Table (three stars)
  ('rest_0331', 'ES', 'rolling', 'Europe/Madrid', 12, 'month', null, null, null, 'own_site', 'https://www.disfrutarbarcelona.com/bookings', '2026-11-16'), -- Disfrutar (three stars)
  ('rest_0337', 'ES', 'monthly', 'Europe/Madrid', null, null, 1, 11, '00:00', 'own_site', 'https://cellercanroca.com/informacion-sobre-las-reservas/', '2026-11-16'), -- El Celler de Can Roca (three stars)
  ('rest_1270', 'FR', 'seasonal', 'Europe/Paris', null, null, null, null, null, 'other', 'https://www.mirazur.fr/', '2026-11-16'), -- Mirazur (three stars)
  ('rest_2507', 'GB', 'rolling', 'Europe/London', 90, 'day', null, null, null, null, 'https://dxp.maybourne.com/globalassets/our-hotels/the-connaught/rb/helene-darroze-at-the-connaught/menus/2026/9.-september/helene-darroze-at-the-connaught-tcs.pdf', '2026-11-16'), -- Hélène Darroze at The Connaught (three stars)
  ('rest_0382', 'IT', 'rolling', 'Europe/Rome', 120, 'day', null, null, null, 'sevenrooms', 'https://qrco.de/bcWLes', '2026-11-16'), -- La Pergola (three stars)
  ('rest_0488', 'JP', 'rolling', 'Asia/Tokyo', 12, 'month', null, null, null, 'phone', 'http://www.mizai.jp/', '2026-11-16'), -- Mizai (three stars)
  ('rest_0500', 'JP', 'rolling', 'Asia/Tokyo', 3, 'month', null, null, '09:30', 'other', 'http://www.quintessence.jp/reservation.html', '2026-11-16'), -- Quintessence (three stars)
  ('rest_0507', 'JP', 'monthly', 'Asia/Tokyo', null, null, 1, 2, '12:00', 'phone', 'http://www.nihonryori-ryugin.com/ja/reserve/', '2026-11-16'), -- RyuGin (three stars)
  ('rest_0126', 'SG', 'monthly', 'Asia/Singapore', null, null, 1, 1, '10:00', 'own_site', 'https://www.restaurantzen.com/', '2026-11-16'), -- Zen (three stars)
  ('rest_0462', 'TW', 'rolling', 'Asia/Taipei', 30, 'day', null, null, null, 'other', 'https://tairroir.com/reservation', '2026-11-16'), -- Taïrroir (three stars)
  ('rest_0045', 'US', 'monthly', 'America/New_York', null, null, 1, 1, null, 'resy', 'https://www.elevenmadisonpark.com/faq', '2026-11-16'), -- Eleven Madison Park (three stars)
  ('rest_0737', 'US', 'rolling', 'America/Los_Angeles', 30, 'day', null, null, '10:00', 'sevenrooms', 'https://www.benusf.com/reservations', '2026-11-16'), -- Benu (three stars)
  ('rest_0739', 'US', 'monthly', 'America/Los_Angeles', null, null, 1, 1, null, 'sevenrooms', 'https://www.quincerestaurant.com/info-reservations', '2026-11-16'), -- Quince (three stars)
  ('rest_0743', 'US', 'rolling', 'America/Los_Angeles', 2, 'month', null, null, null, 'opentable', 'https://providencela.com/reservations/', '2026-11-16'), -- Providence (three stars)
  ('rest_0744', 'US', 'rolling', 'America/Los_Angeles', 1, 'month', null, null, null, 'resy', 'https://www.somnirestaurant.com/en/faqs', '2026-11-16'); -- Somni (three stars)

create temp table staged_release (
  restaurant_code text, country_code text, release_on date,
  release_time time, covers_from date, covers_to date
) on commit drop;

insert into staged_release values
  ('rest_1270', 'FR', '2026-12-07', '09:00', '2027-04-01', '2027-04-30'),
  ('rest_1270', 'FR', '2027-01-04', '09:00', '2027-05-01', '2027-05-31'),
  ('rest_1270', 'FR', '2027-02-01', '09:00', '2027-06-01', '2027-06-30');

do $$
declare
  bad text;
begin
  select string_agg(s.restaurant_code || ' (' || coalesce(m.n, 0) || ' matches)', ', ')
    into bad
    from staged_window s
    left join (select restaurant_code, country_code, count(*) n
                 from public.restaurants group by 1, 2) m
      using (restaurant_code, country_code)
   where coalesce(m.n, 0) <> 1;
  if bad is not null then
    raise exception 'Codes that do not resolve to exactly one restaurant: %', bad;
  end if;
  if (select count(*) from staged_window) <> 37
     or (select count(distinct restaurant_code) from staged_window) <> 37 then
    raise exception 'Expected 37 distinct staged restaurants';
  end if;
end $$;

create temp table import_target on commit drop as
select s.*, r.id restaurant_id,
       exists (select 1 from public.venue_managers_restaurants v
                where v.restaurant_id = r.id and v.revoked_at is null) has_manager,
       exists (select 1 from public.restaurant_booking_windows w
                where w.restaurant_id = r.id) has_window
  from staged_window s
  join public.restaurants r using (restaurant_code, country_code);

-- Reported for the log: anything skipped because the venue already speaks.
select restaurant_code, has_manager, has_window
  from import_target
 where has_manager or has_window;

insert into public.restaurant_booking_windows
  (restaurant_id, kind, timezone, rolling_amount, rolling_unit, release_day,
   months_ahead, release_time, platform, source_kind, source_url, verified_on)
select restaurant_id, kind, timezone, rolling_amount, rolling_unit, release_day,
       months_ahead, release_time, platform, 'research', source_url, verified_on
  from import_target
 where not has_manager and not has_window;

insert into public.restaurant_booking_releases
  (restaurant_id, release_on, release_time, covers_from, covers_to)
select t.restaurant_id, s.release_on, s.release_time, s.covers_from, s.covers_to
  from staged_release s
  join import_target t using (restaurant_code, country_code)
 where not t.has_manager and not t.has_window;

do $$
declare
  expected int := (select count(*) from import_target where not has_manager and not has_window);
  written  int := (select count(*) from public.restaurant_booking_windows w
                     join import_target t using (restaurant_id)
                    where w.source_kind = 'research' and not t.has_manager and not t.has_window);
begin
  if written <> expected then
    raise exception 'Wrote % windows, expected %', written, expected;
  end if;
  raise notice 'Imported % research windows (% skipped)', written, 37 - written;
end $$;

-- What was written, for the log.
select t.restaurant_code, w.kind, w.timezone, w.rolling_amount, w.rolling_unit,
       w.release_day, w.months_ahead, w.release_time,
       (select count(*) from public.restaurant_booking_releases x
         where x.restaurant_id = w.restaurant_id) releases
  from public.restaurant_booking_windows w
  join import_target t using (restaurant_id)
 order by t.restaurant_code;

commit;
