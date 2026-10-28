-- Country timezones — venue events phase 3, decision 1
-- (docs/Architecture/VENUE_EVENTS_PHASE_3_DESIGN.md §2).
--
-- Written 2026-10-28. Not yet applied.
--
-- Why: an event stores its IANA timezone (NOT NULL, validated), and is
-- rendered in it. Venues store no timezone and neither did countries, so
-- the event form had nothing to prefill from. Each country now carries
-- every zone IANA lists for it:
--   - one zone  → the form uses it as the default;
--   - several   → the form asks, from exactly this list; it never
--                  assumes one (Spain: Madrid, Ceuta, Canaries).
-- submit_venue_event/update_venue_event (the next migration) refuse a
-- timezone that isn't in the event country's list.
--
-- Source: the IANA time zone database, tzdata 2025b, file zone.tab
-- (one row per country, its canonical zones in file order), read from
-- this machine's /usr/share/zoneinfo/zone.tab on 2026-10-28 — never
-- typed from memory. All 58 countries in public.countries on that date
-- are covered (44 with one zone, 14 with several); all 149 distinct zones
-- were checked to exist in production's pg_timezone_names the same day.
-- France has only Europe/Paris: its overseas regions have their own
-- country codes in IANA (and here).
--
-- Any later migration that adds a country must give it its zones too:
-- the column is NOT NULL with at least one entry, so a country without
-- them fails loudly instead of leaving events with nothing to use.

begin;

alter table public.countries add column timezones text[];

update public.countries c
   set timezones = v.timezones
  from (values
  ('AD', array['Europe/Andorra']),
  ('AE', array['Asia/Dubai']),
  ('AR', array['America/Argentina/Buenos_Aires', 'America/Argentina/Cordoba', 'America/Argentina/Salta', 'America/Argentina/Jujuy', 'America/Argentina/Tucuman', 'America/Argentina/Catamarca', 'America/Argentina/La_Rioja', 'America/Argentina/San_Juan', 'America/Argentina/Mendoza', 'America/Argentina/San_Luis', 'America/Argentina/Rio_Gallegos', 'America/Argentina/Ushuaia']),
  ('AT', array['Europe/Vienna']),
  ('AU', array['Australia/Lord_Howe', 'Antarctica/Macquarie', 'Australia/Hobart', 'Australia/Melbourne', 'Australia/Sydney', 'Australia/Broken_Hill', 'Australia/Brisbane', 'Australia/Lindeman', 'Australia/Adelaide', 'Australia/Darwin', 'Australia/Perth', 'Australia/Eucla']),
  ('AW', array['America/Aruba']),
  ('BE', array['Europe/Brussels']),
  ('BL', array['America/St_Barthelemy']),
  ('BR', array['America/Noronha', 'America/Belem', 'America/Fortaleza', 'America/Recife', 'America/Araguaina', 'America/Maceio', 'America/Bahia', 'America/Sao_Paulo', 'America/Campo_Grande', 'America/Cuiaba', 'America/Santarem', 'America/Porto_Velho', 'America/Boa_Vista', 'America/Manaus', 'America/Eirunepe', 'America/Rio_Branco']),
  ('CH', array['Europe/Zurich']),
  ('CL', array['America/Santiago', 'America/Coyhaique', 'America/Punta_Arenas', 'Pacific/Easter']),
  ('CN', array['Asia/Shanghai', 'Asia/Urumqi']),
  ('CO', array['America/Bogota']),
  ('DE', array['Europe/Berlin', 'Europe/Busingen']),
  ('DK', array['Europe/Copenhagen']),
  ('EC', array['America/Guayaquil', 'Pacific/Galapagos']),
  ('ES', array['Europe/Madrid', 'Africa/Ceuta', 'Atlantic/Canary']),
  ('FI', array['Europe/Helsinki']),
  ('FO', array['Atlantic/Faroe']),
  ('FR', array['Europe/Paris']),
  ('GB', array['Europe/London']),
  ('GR', array['Europe/Athens']),
  ('HK', array['Asia/Hong_Kong']),
  ('HR', array['Europe/Zagreb']),
  ('HU', array['Europe/Budapest']),
  ('ID', array['Asia/Jakarta', 'Asia/Pontianak', 'Asia/Makassar', 'Asia/Jayapura']),
  ('IN', array['Asia/Kolkata']),
  ('IT', array['Europe/Rome']),
  ('JP', array['Asia/Tokyo']),
  ('KR', array['Asia/Seoul']),
  ('LK', array['Asia/Colombo']),
  ('LU', array['Europe/Luxembourg']),
  ('MA', array['Africa/Casablanca']),
  ('MC', array['Europe/Monaco']),
  ('ME', array['Europe/Podgorica']),
  ('MO', array['Asia/Macau']),
  ('MT', array['Europe/Malta']),
  ('MV', array['Indian/Maldives']),
  ('MX', array['America/Mexico_City', 'America/Cancun', 'America/Merida', 'America/Monterrey', 'America/Matamoros', 'America/Chihuahua', 'America/Ciudad_Juarez', 'America/Ojinaga', 'America/Mazatlan', 'America/Bahia_Banderas', 'America/Hermosillo', 'America/Tijuana']),
  ('MY', array['Asia/Kuala_Lumpur', 'Asia/Kuching']),
  ('NL', array['Europe/Amsterdam']),
  ('NO', array['Europe/Oslo']),
  ('NZ', array['Pacific/Auckland', 'Pacific/Chatham']),
  ('OM', array['Asia/Muscat']),
  ('PA', array['America/Panama']),
  ('PE', array['America/Lima']),
  ('PL', array['Europe/Warsaw']),
  ('PT', array['Europe/Lisbon', 'Atlantic/Madeira', 'Atlantic/Azores']),
  ('RS', array['Europe/Belgrade']),
  ('SE', array['Europe/Stockholm']),
  ('SG', array['Asia/Singapore']),
  ('SI', array['Europe/Ljubljana']),
  ('TH', array['Asia/Bangkok']),
  ('TR', array['Europe/Istanbul']),
  ('TW', array['Asia/Taipei']),
  ('US', array['America/New_York', 'America/Detroit', 'America/Kentucky/Louisville', 'America/Kentucky/Monticello', 'America/Indiana/Indianapolis', 'America/Indiana/Vincennes', 'America/Indiana/Winamac', 'America/Indiana/Marengo', 'America/Indiana/Petersburg', 'America/Indiana/Vevay', 'America/Chicago', 'America/Indiana/Tell_City', 'America/Indiana/Knox', 'America/Menominee', 'America/North_Dakota/Center', 'America/North_Dakota/New_Salem', 'America/North_Dakota/Beulah', 'America/Denver', 'America/Boise', 'America/Phoenix', 'America/Los_Angeles', 'America/Anchorage', 'America/Juneau', 'America/Sitka', 'America/Metlakatla', 'America/Yakutat', 'America/Nome', 'America/Adak', 'Pacific/Honolulu']),
  ('VN', array['Asia/Ho_Chi_Minh']),
  ('ZA', array['Africa/Johannesburg'])
  ) as v(country_code, timezones)
 where c.country_code = v.country_code;

-- Every zone must be one this Postgres knows, or an event using it would
-- fail validate_event_timezone().
do $$
declare
  v_bad text;
begin
  select string_agg(distinct z, ', ') into v_bad
    from public.countries c, unnest(c.timezones) as z
   where z not in (select name from pg_timezone_names);
  if v_bad is not null then
    raise exception 'Unknown timezone(s) in countries.timezones: %', v_bad;
  end if;
end;
$$;

alter table public.countries
  alter column timezones set not null,
  add constraint countries_timezones_not_empty check (cardinality(timezones) >= 1);

comment on column public.countries.timezones is
  'Every IANA zone for this country (tzdata zone.tab). One entry: the event '
  'form''s default. Several: the form asks. Events must use one of these.';

commit;
