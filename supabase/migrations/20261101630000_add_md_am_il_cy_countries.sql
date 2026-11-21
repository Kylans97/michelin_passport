-- Countries Moldova (MD), Armenia (AM), Israel (IL) and Cyprus (CY):
-- prerequisite for round 6 of the wine regions, staged in
-- supabase/data/enrichment/wine_regions/wine_regions_seed_round6_v1.sql.
-- wine_regions.country_code references countries; no cities rows are
-- needed.
--
-- Written 2026-11-21, on the product owner's request "Start round 6:
-- Eastern Europe and the Eastern Mediterranean (Moravia, Romania, Bulgaria,
-- Serbia, Moldova, Armenia, Israel, Cyprus, Turkey, more of Greece)".
-- Filename is a sequence number: written as 20261101640000 after the
-- wine verdicts migration, renumbered the same day (neither applied) to
-- come before it, so these countries can be applied while the verdicts
-- wait for the privacy policy.
--
-- None of the four exists in production (read 2026-11-21 with a select on
-- countries). ON CONFLICT DO NOTHING keeps this safe if one is added in
-- the meantime. The zone check aborts if the server lacks a zone. Columns
-- as in 20261101620000_add_ge_country.sql. No function is created.

begin;

do $$
declare
  zone text;
begin
  foreach zone in array array['Europe/Chisinau', 'Asia/Yerevan',
                              'Asia/Jerusalem', 'Asia/Nicosia'] loop
    if zone not in (select name from pg_timezone_names) then
      raise exception 'Unknown timezone: %', zone;
    end if;
  end loop;
end;
$$;

insert into public.countries (country_code, name, flag_emoji, timezones)
values
  ('MD', 'Moldova', '🇲🇩', array['Europe/Chisinau']),
  ('AM', 'Armenia', '🇦🇲', array['Asia/Yerevan']),
  ('IL', 'Israel', '🇮🇱', array['Asia/Jerusalem']),
  ('CY', 'Cyprus', '🇨🇾', array['Asia/Nicosia'])
on conflict (country_code) do nothing;

commit;
