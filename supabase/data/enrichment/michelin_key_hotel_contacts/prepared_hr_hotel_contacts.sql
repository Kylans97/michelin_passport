-- PREPARED -- NOT APPLIED.
--
-- Contact fields for Croatia's MICHELIN Key hotels: phone, website_url and
-- michelin_url, filled only where production has NULL. Written 2026-10-29
-- from a read-only production export of the same day (10 HR hotels with
-- michelin_keys set). Evidence per row, with source URL and how each value
-- was confirmed: hr_hotels_all.csv beside this file. Report: SIX_COUNTRIES_REPORT.md.
--
--   michelin_url  10 rows  the hotel's own guide.michelin.com page, matched
--                         on coordinates + postcode, never on name
--   website_url   9 rows  the hotel's own site (for a chain, the property
--                         page), confirmed by name + city + address on the site
--   phone         9 rows  the number printed on the hotel's own site
--                         (rule of 2026-10-28, see michelin_pe_2026)
--
-- Only values marked `confirmed` in the CSV are here; `unclear` and
-- `not_found` stay NULL.
--
-- Guards (one transaction; any failure rolls everything back):
--   1. every code exists as a Croatia hotel with a Key and the expected name;
--   2. every field this file fills is still NULL (nothing filled since the
--      export) -- otherwise it raises instead of skipping silently;
--   3. no MICHELIN URL here is already held by another hotel row
--      (hotels_michelin_url_key is unique);
--   4. the number of rows each UPDATE touches equals the number expected.
-- Each UPDATE is also limited to `hotel_code = ... and country_code = 'HR'
-- and <field> is null`, so it can never overwrite a value.

begin;

create temp table _c (
    code         text primary key,
    name         text not null,
    phone        text,
    website_url  text,
    michelin_url text
) on commit drop;

insert into _c (code, name, phone, website_url, michelin_url) values
    ('hotel_258', 'Maslina Resort', '+385 21 214 880', 'https://www.maslinaresort.com/', 'https://guide.michelin.com/en/hotels-stays/Stari-Grad/maslina-resort-12293'),
    ('hotel_259', 'Villa Nai 3.3', '+385 23 643520', null, 'https://guide.michelin.com/en/hotels-stays/dugi-otok/villa-nai-33-12045'),
    ('hotel_260', 'Villa Dubrovnik', '+385 20 500 300', 'https://www.villa-dubrovnik.hr/', 'https://guide.michelin.com/en/hotels-stays/dubrovnik/hotel-villa-dubrovnik-7107'),
    ('hotel_261', 'Supetar', '+385 20 479 833', 'https://www.adriaticluxuryhotels.com/hotel-supetar-dubrovnik-cavtat', 'https://guide.michelin.com/en/hotels-stays/cavtat/hotel-supetar-14324'),
    ('hotel_262', 'Villa Korta Katarina & Winery', '+385 99 525 7955', 'https://www.kortakatarina.com/', 'https://guide.michelin.com/en/hotels-stays/Orebi%C4%87/villa-korta-katarina-winery-15415'),
    ('hotel_263', 'Esplanade Zagreb Hotel', '+385 1 45 666 66', 'https://esplanade.hr/', 'https://guide.michelin.com/en/hotels-stays/zagreb/esplanade-zagreb-hotel-6198'),
    ('hotel_264', 'San Canzian', '+385 52 853 897', 'https://san-canzian.com/', 'https://guide.michelin.com/en/hotels-stays/Buje/san-canzian-hotel-residences-12309'),
    ('hotel_265', 'Meneghetti Wine Hotel and Winery', '+385 52 528 800', 'https://meneghetti.hr/', 'https://guide.michelin.com/en/hotels-stays/Bale/meneghetti-wine-hotel-and-winery-12301'),
    ('hotel_266', 'Grand Park Hotel Rovinj by Maistra Collection', null, 'https://www.maistra.com/properties/grand-park-hotel-rovinj/', 'https://guide.michelin.com/en/hotels-stays/rovinj/grand-park-hotel-rovinj-by-maistra-collection-13815'),
    ('hotel_267', 'Palace Elisabeth Hvar', '+385 21 750 400', 'https://www.suncanihvar.com/palace-elisabeth', 'https://guide.michelin.com/en/hotels-stays/hvar/palace-elisabeth-hvar-hotel-15344');

do $$
declare bad text; n int;
begin
  select count(*) into n from _c;
  if n <> 10 then raise exception 'expected 10 rows in _c, found %', n; end if;

  select string_agg(c.code, ', ') into bad from _c c
   where not exists (select 1 from public.hotels h
                      where h.hotel_code = c.code and h.country_code = 'HR'
                        and h.michelin_keys is not null and h.name = c.name);
  if bad is not null then raise exception 'not the expected Croatia Key hotel: %', bad; end if;

  select string_agg(c.code, ', ') into bad from _c c join public.hotels h on h.hotel_code = c.code
   where (c.phone is not null and h.phone is not null)
      or (c.website_url is not null and h.website_url is not null)
      or (c.michelin_url is not null and h.michelin_url is not null);
  if bad is not null then raise exception 'field already set since the export (refusing to skip silently): %', bad; end if;

  select string_agg(c.code || ' -> ' || h.hotel_code, ', ') into bad from _c c
    join public.hotels h on h.michelin_url = c.michelin_url and h.hotel_code <> c.code;
  if bad is not null then raise exception 'MICHELIN URL already held by another hotel: %', bad; end if;

  update public.hotels h set michelin_url = c.michelin_url from _c c
   where h.hotel_code = c.code and h.country_code = 'HR' and c.michelin_url is not null and h.michelin_url is null;
  get diagnostics n = row_count;
  if n <> 10 then raise exception 'michelin_url: expected 10 rows, updated %', n; end if;

  update public.hotels h set website_url = c.website_url from _c c
   where h.hotel_code = c.code and h.country_code = 'HR' and c.website_url is not null and h.website_url is null;
  get diagnostics n = row_count;
  if n <> 9 then raise exception 'website_url: expected 9 rows, updated %', n; end if;

  update public.hotels h set phone = c.phone from _c c
   where h.hotel_code = c.code and h.country_code = 'HR' and c.phone is not null and h.phone is null;
  get diagnostics n = row_count;
  if n <> 9 then raise exception 'phone: expected 9 rows, updated %', n; end if;
end $$;

commit;
