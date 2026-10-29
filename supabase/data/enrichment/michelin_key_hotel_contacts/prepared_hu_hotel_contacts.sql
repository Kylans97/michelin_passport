-- PREPARED -- NOT APPLIED.
--
-- Contact fields for Hungary's MICHELIN Key hotels: phone, website_url and
-- michelin_url, filled only where production has NULL. Written 2026-10-29
-- from a read-only production export of the same day (12 HU hotels with
-- michelin_keys set). Evidence per row, with source URL and how each value
-- was confirmed: hu_hotels_all.csv beside this file. Report: SIX_COUNTRIES_REPORT.md.
--
--   michelin_url  12 rows  the hotel's own guide.michelin.com page, matched
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
--   1. every code exists as a Hungary hotel with a Key and the expected name;
--   2. every field this file fills is still NULL (nothing filled since the
--      export) -- otherwise it raises instead of skipping silently;
--   3. no MICHELIN URL here is already held by another hotel row
--      (hotels_michelin_url_key is unique);
--   4. the number of rows each UPDATE touches equals the number expected.
-- Each UPDATE is also limited to `hotel_code = ... and country_code = 'HU'
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
    ('hotel_268', 'Platán Manor', '+36 30 444 9055', 'https://platanudvarhaz.hu/', 'https://guide.michelin.com/en/hotels-stays/Tata/platan-manor-13561'),
    ('hotel_269', 'Hotel Clark Budapest', '+36 1 610 4890', 'https://hotelclarkbudapest.hu/', 'https://guide.michelin.com/en/hotels-stays/budapest/hotel-clark-budapest-9054'),
    ('hotel_270', 'Kozmo Hotel Suites & Spa', '+36 1 701 6300', 'https://www.kozmohotelbudapest.com/', 'https://guide.michelin.com/en/hotels-stays/budapest/kozmo-hotel-suites-spa-12004'),
    ('hotel_271', 'Kimpton Bem Budapest', '+36 1 883 9880', 'https://kimptonbembudapest.com/', 'https://guide.michelin.com/en/hotels-stays/budapest/kimpton-bem-budapest-14261'),
    ('hotel_272', 'Anantara New York Palace Budapest', '+36 1 886 6111', 'https://www.anantara.com/en/new-york-palace-budapest', 'https://guide.michelin.com/en/hotels-stays/budapest/anantara-new-york-palace-budapest-7674'),
    ('hotel_273', 'Verno House', '+36 1 886 1120', 'https://vernohouse.com/', 'https://guide.michelin.com/en/hotels-stays/budapest/verno-house-13047'),
    ('hotel_274', 'Four Seasons Hotel Gresham Palace Budapest', '+36 1 268 6000', 'https://www.fourseasons.com/budapest/', 'https://guide.michelin.com/en/hotels-stays/budapest/four-seasons-hotel-gresham-palace-budapest-6348'),
    ('hotel_275', 'Matild Palace, a Luxury Collection Hotel', '+36 1 550 5000', 'https://www.matildpalace.hu/', 'https://guide.michelin.com/en/hotels-stays/budapest/matild-palace-a-luxury-collection-hotel-12094'),
    ('hotel_276', 'Dorothea Hotel, Budapest, Autograph Collection', '+36 1 884 5100', 'https://www.marriott.com/en-us/hotels/budkc-dorothea-hotel-budapest-autograph-collection/overview/', 'https://guide.michelin.com/en/hotels-stays/budapest/dorothea-hotel-budapest-autograph-collection-13598'),
    ('hotel_277', 'Párisi Udvar Hotel Budapest', null, null, 'https://guide.michelin.com/en/hotels-stays/budapest/parisi-udvar-hotel-budapest-120059-9359'),
    ('hotel_278', 'W Budapest', '+36 1 253 3100', 'https://www.marriott.com/en-us/hotels/budwh-w-budapest/overview/', 'https://guide.michelin.com/en/hotels-stays/budapest/w-budapest-14320'),
    ('hotel_279', 'Hotel Petit Bois', '+36 30 258 9371', 'https://www.petitbois.hu/', 'https://guide.michelin.com/en/hotels-stays/Balatonf%C3%BCred/hotel-petit-bois-15109');

do $$
declare bad text; n int;
begin
  select count(*) into n from _c;
  if n <> 12 then raise exception 'expected 12 rows in _c, found %', n; end if;

  select string_agg(c.code, ', ') into bad from _c c
   where not exists (select 1 from public.hotels h
                      where h.hotel_code = c.code and h.country_code = 'HU'
                        and h.michelin_keys is not null and h.name = c.name);
  if bad is not null then raise exception 'not the expected Hungary Key hotel: %', bad; end if;

  select string_agg(c.code, ', ') into bad from _c c join public.hotels h on h.hotel_code = c.code
   where (c.phone is not null and h.phone is not null)
      or (c.website_url is not null and h.website_url is not null)
      or (c.michelin_url is not null and h.michelin_url is not null);
  if bad is not null then raise exception 'field already set since the export (refusing to skip silently): %', bad; end if;

  select string_agg(c.code || ' -> ' || h.hotel_code, ', ') into bad from _c c
    join public.hotels h on h.michelin_url = c.michelin_url and h.hotel_code <> c.code;
  if bad is not null then raise exception 'MICHELIN URL already held by another hotel: %', bad; end if;

  update public.hotels h set michelin_url = c.michelin_url from _c c
   where h.hotel_code = c.code and h.country_code = 'HU' and c.michelin_url is not null and h.michelin_url is null;
  get diagnostics n = row_count;
  if n <> 12 then raise exception 'michelin_url: expected 12 rows, updated %', n; end if;

  update public.hotels h set website_url = c.website_url from _c c
   where h.hotel_code = c.code and h.country_code = 'HU' and c.website_url is not null and h.website_url is null;
  get diagnostics n = row_count;
  if n <> 11 then raise exception 'website_url: expected 11 rows, updated %', n; end if;

  update public.hotels h set phone = c.phone from _c c
   where h.hotel_code = c.code and h.country_code = 'HU' and c.phone is not null and h.phone is null;
  get diagnostics n = row_count;
  if n <> 11 then raise exception 'phone: expected 11 rows, updated %', n; end if;
end $$;

commit;
