-- PREPARED -- NOT APPLIED.
--
-- Contact fields for Belgium's MICHELIN Key hotels: phone, website_url and
-- michelin_url, filled only where production has NULL. Written 2026-10-29
-- from a read-only production export of the same day (15 BE hotels with
-- michelin_keys set). Evidence per row, with source URL and how each value
-- was confirmed: be_hotels_all.csv beside this file. Report: SIX_COUNTRIES_REPORT.md.
--
--   michelin_url  10 rows  the hotel's own guide.michelin.com page, matched
--                         on coordinates + postcode, never on name
--   website_url   14 rows  the hotel's own site (for a chain, the property
--                         page), confirmed by name + city + address on the site
--   phone         15 rows  the number printed on the hotel's own site
--                         (rule of 2026-10-28, see michelin_pe_2026)
--
-- Only values marked `confirmed` in the CSV are here; `unclear` and
-- `not_found` stay NULL.
--
-- Guards (one transaction; any failure rolls everything back):
--   1. every code exists as a Belgium hotel with a Key and the expected name;
--   2. every field this file fills is still NULL (nothing filled since the
--      export) -- otherwise it raises instead of skipping silently;
--   3. no MICHELIN URL here is already held by another hotel row
--      (hotels_michelin_url_key is unique);
--   4. the number of rows each UPDATE touches equals the number expected.
-- Each UPDATE is also limited to `hotel_code = ... and country_code = 'BE'
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
    ('hotel_147', 'Pillows Grand Boutique Hotel Reylof Ghent', '+32 9 235 40 70', 'https://www.pillowshotels.com/ghent/', null),
    ('hotel_148', 'Kasteel van Ordingen', '+32 11 58 68 18', 'https://kasteelvanordingen.be/', 'https://guide.michelin.com/en/hotels-stays/Sint-Truiden/kasteel-van-ordingen-15346'),
    ('hotel_149', 'Boutiquehotel ''t Fraeyhuis', '+32 50 96 03 01', 'https://www.fraeyhuis.be/', 'https://guide.michelin.com/en/hotels-stays/bruges/boutiquehotel-t-fraeyhuis-14721'),
    ('hotel_150', 'Dukes'' Palace Brugge', '+32 50 44 78 88', 'https://hoteldukespalace.com/', 'https://guide.michelin.com/en/hotels-stays/bruges/dukes-palace-brugge-14722'),
    ('hotel_151', 'La Butte aux Bois', '+32 89 73 97 70', 'https://labutteauxbois.be/', 'https://guide.michelin.com/en/hotels-stays/lanaken/domaine-la-butte-aux-bois-9801'),
    ('hotel_152', 'Château de Vignée', '+32 84 69 00 50', 'https://www.chateaudevignee.be/', 'https://guide.michelin.com/en/hotels-stays/rochefort/chateau-de-vignee-12584'),
    ('hotel_153', 'Corinthia Grand Hotel Astoria Brussels', '+32 2 593 10 00', 'https://www.corinthia.com/en-gb/brussels/', 'https://guide.michelin.com/en/hotels-stays/brussels/corinthia-grand-hotel-astoria-brussels-14567'),
    ('hotel_154', '1898 The Post', '+32 9 391 53 79', 'https://www.1898thepost.com/', 'https://guide.michelin.com/en/hotels-stays/ghent/1898-the-post-8744'),
    ('hotel_155', 'Hotel De Witte Lelie', '+32 3 226 19 66', 'https://www.dewittelelie.be/', 'https://guide.michelin.com/en/hotels-stays/antwerp/hotel-de-witte-lelie-6284'),
    ('hotel_156', 'The Notary', '+32 50 89 64 46', 'https://www.thenotary.be/', 'https://guide.michelin.com/en/hotels-stays/bruges/the-notary-13020'),
    ('hotel_157', 'Hotel Flora', '+32 472 033 066', 'https://hotelflora.be/', 'https://guide.michelin.com/en/hotels-stays/antwerp/flora-123463-13288'),
    ('hotel_18', 'Botanic Sanctuary Antwerp', '+32 3 269 00 00', 'https://www.botanicantwerp.be/', null),
    ('hotel_19', 'Juliana Hotel Brussels', '+32 2 214 08 00', null, null),
    ('hotel_20', 'Hôtel Amigo', '+32 2 547 47 47', 'https://www.roccofortehotels.com/hotels-and-resorts/hotel-amigo/', null),
    ('hotel_21', 'Hotel Van Cleef', '+32 50 34 64 14', 'https://www.hotelvancleef.be/', null);

do $$
declare bad text; n int;
begin
  select count(*) into n from _c;
  if n <> 15 then raise exception 'expected 15 rows in _c, found %', n; end if;

  select string_agg(c.code, ', ') into bad from _c c
   where not exists (select 1 from public.hotels h
                      where h.hotel_code = c.code and h.country_code = 'BE'
                        and h.michelin_keys is not null and h.name = c.name);
  if bad is not null then raise exception 'not the expected Belgium Key hotel: %', bad; end if;

  select string_agg(c.code, ', ') into bad from _c c join public.hotels h on h.hotel_code = c.code
   where (c.phone is not null and h.phone is not null)
      or (c.website_url is not null and h.website_url is not null)
      or (c.michelin_url is not null and h.michelin_url is not null);
  if bad is not null then raise exception 'field already set since the export (refusing to skip silently): %', bad; end if;

  select string_agg(c.code || ' -> ' || h.hotel_code, ', ') into bad from _c c
    join public.hotels h on h.michelin_url = c.michelin_url and h.hotel_code <> c.code;
  if bad is not null then raise exception 'MICHELIN URL already held by another hotel: %', bad; end if;

  update public.hotels h set michelin_url = c.michelin_url from _c c
   where h.hotel_code = c.code and h.country_code = 'BE' and c.michelin_url is not null and h.michelin_url is null;
  get diagnostics n = row_count;
  if n <> 10 then raise exception 'michelin_url: expected 10 rows, updated %', n; end if;

  update public.hotels h set website_url = c.website_url from _c c
   where h.hotel_code = c.code and h.country_code = 'BE' and c.website_url is not null and h.website_url is null;
  get diagnostics n = row_count;
  if n <> 14 then raise exception 'website_url: expected 14 rows, updated %', n; end if;

  update public.hotels h set phone = c.phone from _c c
   where h.hotel_code = c.code and h.country_code = 'BE' and c.phone is not null and h.phone is null;
  get diagnostics n = row_count;
  if n <> 15 then raise exception 'phone: expected 15 rows, updated %', n; end if;
end $$;

commit;
