-- PREPARED -- NOT APPLIED.
--
-- Contact fields for Poland's MICHELIN Key hotels: phone, website_url and
-- michelin_url, filled only where production has NULL. Written 2026-10-29
-- from a read-only production export of the same day (11 PL hotels with
-- michelin_keys set). Evidence per row, with source URL and how each value
-- was confirmed: pl_hotels_all.csv beside this file. Report: SIX_COUNTRIES_REPORT.md.
--
--   michelin_url  11 rows  the hotel's own guide.michelin.com page, matched
--                         on coordinates + postcode, never on name
--   website_url   11 rows  the hotel's own site (for a chain, the property
--                         page), confirmed by name + city + address on the site
--   phone         11 rows  the number printed on the hotel's own site
--                         (rule of 2026-10-28, see michelin_pe_2026)
--
-- Only values marked `confirmed` in the CSV are here; `unclear` and
-- `not_found` stay NULL.
--
-- Guards (one transaction; any failure rolls everything back):
--   1. every code exists as a Poland hotel with a Key and the expected name;
--   2. every field this file fills is still NULL (nothing filled since the
--      export) -- otherwise it raises instead of skipping silently;
--   3. no MICHELIN URL here is already held by another hotel row
--      (hotels_michelin_url_key is unique);
--   4. the number of rows each UPDATE touches equals the number expected.
-- Each UPDATE is also limited to `hotel_code = ... and country_code = 'PL'
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
    ('hotel_306', 'Jaskółka Dom i SPA', '+48 537 106 055', 'https://jaskolkadom.com/', 'https://guide.michelin.com/en/hotels-stays/szklarskapor%C4%99ba/jaskolka-dom-i-spa-14254'),
    ('hotel_307', 'Zamek Łeba', '+48 59 863 51 20', 'https://zamekleba.pl/', 'https://guide.michelin.com/en/hotels-stays/leba/zamek-leba-14325'),
    ('hotel_308', 'Raffles Europejski Warsaw', '+48 22 255 95 00', 'https://www.raffles.com/warsaw/', 'https://guide.michelin.com/en/hotels-stays/warsaw/raffles-europejski-warsaw-123592-13408'),
    ('hotel_309', 'Hotel Copernicus', '+48 12 424 34 00', 'https://copernicus.hotel.com.pl/', 'https://guide.michelin.com/en/hotels-stays/krakow/hotel-copernicus-11432'),
    ('hotel_310', 'Stradom House, Autograph Collection', '+48 12 201 57 00', 'https://stradomhouse.com/en/', 'https://guide.michelin.com/en/hotels-stays/krakow/stardom-house-13818'),
    ('hotel_311', 'Hotel Altus Palace', '+48 71 747 50 00', 'https://www.hotelaltuspalace.pl/', 'https://guide.michelin.com/en/hotels-stays/Wroc%C5%82aw/hotel-altus-palace-14783'),
    ('hotel_312', 'Pałac Ciekocinko Hotel Resort & Wellness', '+48 58 572 25 08', 'https://palacciekocinko.pl/', 'https://guide.michelin.com/en/hotels-stays/Ciekocinko/paac-ciekocinko-hotel-resort-wellness-14836'),
    ('hotel_313', 'Hotel Bristol, A Luxury Collection Hotel, Warsaw', '+48 22 551 10 00', 'https://www.marriott.com/en-us/hotels/wawlc-hotel-bristol-a-luxury-collection-hotel-warsaw/overview/', 'https://guide.michelin.com/en/hotels-stays/warsaw/hotel-bristol-a-luxury-collection-hotel-warsaw-6369'),
    ('hotel_314', 'EN Hotel', '+48 662 222 333', 'https://enhotel.pl/', 'https://guide.michelin.com/en/hotels-stays/Zakopane/enhotel-13961'),
    ('hotel_315', 'Quadrille', '+48 58 351 03 00', 'https://quadrille.pl/', 'https://guide.michelin.com/en/hotels-stays/Gdynia/relais-chateaux-hotel-quadrille-adults-only-14010'),
    ('hotel_316', 'H15 Palace, a Luxury Collection Hotel', '+48 12 371 15 15', 'https://www.marriott.com/en-us/hotels/krkhp-h15-palace-a-luxury-collection-hotel-krakow/overview/', 'https://guide.michelin.com/en/hotels-stays/krakow/h15-luxury-palace-14828');

do $$
declare bad text; n int;
begin
  select count(*) into n from _c;
  if n <> 11 then raise exception 'expected 11 rows in _c, found %', n; end if;

  select string_agg(c.code, ', ') into bad from _c c
   where not exists (select 1 from public.hotels h
                      where h.hotel_code = c.code and h.country_code = 'PL'
                        and h.michelin_keys is not null and h.name = c.name);
  if bad is not null then raise exception 'not the expected Poland Key hotel: %', bad; end if;

  select string_agg(c.code, ', ') into bad from _c c join public.hotels h on h.hotel_code = c.code
   where (c.phone is not null and h.phone is not null)
      or (c.website_url is not null and h.website_url is not null)
      or (c.michelin_url is not null and h.michelin_url is not null);
  if bad is not null then raise exception 'field already set since the export (refusing to skip silently): %', bad; end if;

  select string_agg(c.code || ' -> ' || h.hotel_code, ', ') into bad from _c c
    join public.hotels h on h.michelin_url = c.michelin_url and h.hotel_code <> c.code;
  if bad is not null then raise exception 'MICHELIN URL already held by another hotel: %', bad; end if;

  update public.hotels h set michelin_url = c.michelin_url from _c c
   where h.hotel_code = c.code and h.country_code = 'PL' and c.michelin_url is not null and h.michelin_url is null;
  get diagnostics n = row_count;
  if n <> 11 then raise exception 'michelin_url: expected 11 rows, updated %', n; end if;

  update public.hotels h set website_url = c.website_url from _c c
   where h.hotel_code = c.code and h.country_code = 'PL' and c.website_url is not null and h.website_url is null;
  get diagnostics n = row_count;
  if n <> 11 then raise exception 'website_url: expected 11 rows, updated %', n; end if;

  update public.hotels h set phone = c.phone from _c c
   where h.hotel_code = c.code and h.country_code = 'PL' and c.phone is not null and h.phone is null;
  get diagnostics n = row_count;
  if n <> 11 then raise exception 'phone: expected 11 rows, updated %', n; end if;
end $$;

commit;
