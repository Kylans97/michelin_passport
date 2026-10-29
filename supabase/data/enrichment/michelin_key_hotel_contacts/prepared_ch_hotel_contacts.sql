-- PREPARED -- NOT APPLIED.
--
-- Contact fields for Switzerland's MICHELIN Key hotels: phone, website_url and
-- michelin_url, filled only where production has NULL. Written 2026-10-29
-- from a read-only production export of the same day (42 CH hotels with
-- michelin_keys set). Evidence per row, with source URL and how each value
-- was confirmed: ch_hotels_all.csv beside this file. Report: SIX_COUNTRIES_REPORT.md.
--
--   michelin_url  39 rows  the hotel's own guide.michelin.com page, matched
--                         on coordinates + postcode, never on name
--   website_url   35 rows  the hotel's own site (for a chain, the property
--                         page), confirmed by name + city + address on the site
--   phone         41 rows  the number printed on the hotel's own site
--                         (rule of 2026-10-28, see michelin_pe_2026)
--
-- Only values marked `confirmed` in the CSV are here; `unclear` and
-- `not_found` stay NULL.
--
-- Guards (one transaction; any failure rolls everything back):
--   1. every code exists as a Switzerland hotel with a Key and the expected name;
--   2. every field this file fills is still NULL (nothing filled since the
--      export) -- otherwise it raises instead of skipping silently;
--   3. no MICHELIN URL here is already held by another hotel row
--      (hotels_michelin_url_key is unique);
--   4. the number of rows each UPDATE touches equals the number expected.
-- Each UPDATE is also limited to `hotel_code = ... and country_code = 'CH'
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
    ('hotel_49', 'Grand Resort Bad Ragaz', '+41 81 303 30 30', null, 'https://guide.michelin.com/en/hotels-stays/Bad-Ragaz/grand-resort-bad-ragaz-12501'),
    ('hotel_50', 'Hotel Les Trois Rois', '+41 61 260 50 50', null, 'https://guide.michelin.com/en/hotels-stays/basel/hotel-les-trois-rois-6395'),
    ('hotel_51', 'Bürgenstock Resort', '+41 41 612 60 00', null, 'https://guide.michelin.com/en/hotels-stays/burgenstock/burgenstock-9744'),
    ('hotel_52', 'Beau-Rivage Geneva', '+41 22 716 66 66', null, 'https://guide.michelin.com/en/hotels-stays/geneva/beau-rivage-geneva-9048'),
    ('hotel_53', 'The Woodward, Auberge Collection', '+41 22 901 37 00', 'https://auberge.com/the-woodward/', null),
    ('hotel_54', 'The Alpina Gstaad', '+41 33 888 98 88', null, null),
    ('hotel_55', 'Badrutt''s Palace Hotel', null, 'https://www.badruttspalace.com/', null),
    ('hotel_56', 'Carlton Hotel St. Moritz', '+41 81 836 70 00', null, 'https://guide.michelin.com/en/hotels-stays/st-moritz/carlton-hotel-st-moritz-6969'),
    ('hotel_57', 'Baur au Lac', '+41 44 220 50 20', null, 'https://guide.michelin.com/en/hotels-stays/zurich/baur-au-lac-6394'),
    ('hotel_570', 'Le Mirador Resort & Spa', '+41 21 925 11 11', 'https://www.mirador.ch/', 'https://guide.michelin.com/en/hotels-stays/vaud/le-mirador-resort-spa-7787'),
    ('hotel_571', 'Royal Savoy Hotel & Spa', '+41 21 614 88 88', 'https://www.royalsavoy.ch/en', 'https://guide.michelin.com/en/hotels-stays/lausanne/royal-savoy-hotel-spa-10483'),
    ('hotel_572', 'Grand Hôtel du Lac', '+41 21 925 06 06', 'https://www.ghdl.ch/', 'https://guide.michelin.com/en/hotels-stays/Vevey-2/grand-hotel-du-lac-vevey-9205'),
    ('hotel_58', 'The Chedi Andermatt', '+41 41 888 74 88', 'https://www.thechediandermatt.com/', 'https://guide.michelin.com/en/hotels-stays/andermatt/the-chedi-andermatt-7567'),
    ('hotel_59', 'Tschuggen Grand Hotel', '+41 81 378 99 99', 'https://tschuggencollection.ch/en/hotel/tschuggen-grand-hotel', 'https://guide.michelin.com/en/hotels-stays/arosa/tschuggen-grand-hotel-6401'),
    ('hotel_60', 'Valsana Hotel & Appartements', '+41 81 378 63 63', 'https://tschuggencollection.ch/en/hotel/valsana-hotel', 'https://guide.michelin.com/en/hotels-stays/arosa/valsana-hotel-arosa-9152'),
    ('hotel_61', 'Castello del Sole Beach Resort & Spa', '+41 91 791 02 02', 'https://www.castellodelsole.com/en/', 'https://guide.michelin.com/en/hotels-stays/ascona/castello-del-sole-beach-resort-spa-13889'),
    ('hotel_62', 'Hotel Eden Roc', '+41 91 785 71 71', 'https://tschuggencollection.ch/de/hotel/hotel-eden-roc', 'https://guide.michelin.com/en/hotels-stays/ascona/hotel-eden-roc-10096'),
    ('hotel_63', 'Hotel Bellevue Palace Bern', '+41 31 320 45 45', 'https://www.bellevue-palace.ch/', 'https://guide.michelin.com/en/hotels-stays/bern/hotel-bellevue-palace-bern-10697'),
    ('hotel_64', 'Guarda Golf Hotel & Residences', '+41 27 486 20 00', 'https://guardagolf.com/', 'https://guide.michelin.com/en/hotels-stays/crans-montana/guarda-golf-hotel-residences-6831'),
    ('hotel_65', 'Hostellerie du Pas de l''Ours', '+41 27 485 93 33', 'https://www.pasdelours.ch/', 'https://guide.michelin.com/en/hotels-stays/crans-montana/hostellerie-du-pas-de-lours-10189'),
    ('hotel_66', 'LeCrans Hotel & Spa', '+41 27 486 60 60', 'https://lecrans.com/', 'https://guide.michelin.com/en/hotels-stays/crans-montana/lecrans-hotel-spa-7890'),
    ('hotel_67', 'Hotel Villa Honegg', '+41 41 618 32 00', 'https://villa-honegg.ch/de/', 'https://guide.michelin.com/en/hotels-stays/burgenstock/hotel-villa-honegg-6835'),
    ('hotel_68', 'Four Seasons Hotel des Bergues', '+41 22 908 70 00', 'https://www.fourseasons.com/geneva/', 'https://guide.michelin.com/en/hotels-stays/geneva/four-seasons-hotel-des-bergues-geneva-11435'),
    ('hotel_69', 'The Ritz-Carlton Hotel de la Paix, Geneva', '+41 22 909 60 00', 'https://www.ritzcarlton.com/en/hotels/gvarz-the-ritz-carlton-hotel-de-la-paix-geneva/overview/', 'https://guide.michelin.com/en/hotels-stays/geneva/hotel-de-la-paix-geneva-6263'),
    ('hotel_70', 'Gstaad Palace', '+41 33 748 50 00', 'https://www.palace.ch/en/', 'https://guide.michelin.com/en/hotels-stays/gstaad/gstaad-palace-7981'),
    ('hotel_71', 'Le Grand Bellevue', '+41 33 748 00 00', 'https://bellevue-gstaad.ch/', 'https://guide.michelin.com/en/hotels-stays/gstaad/le-grand-bellevue-8791'),
    ('hotel_72', 'Victoria-Jungfrau Grand Hotel & Spa', '+41 33 828 28 28', 'https://www.victoria-jungfrau.ch/', 'https://guide.michelin.com/en/hotels-stays/interlaken/victoria-jungfrau-grand-hotel-spa-5984'),
    ('hotel_73', 'Beau-Rivage Palace', '+41 21 613 33 33', 'https://www.brp.ch/', 'https://guide.michelin.com/en/hotels-stays/lausanne/beaurivage-palace-6965'),
    ('hotel_74', 'Lausanne Palace', '+41 21 331 31 31', 'https://www.lausanne-palace.ch/', 'https://guide.michelin.com/en/hotels-stays/lausanne/lausanne-palace-and-spa-98'),
    ('hotel_75', 'Villa Principe Leopoldo', '+41 91 985 88 55', 'https://www.leopoldohotel.com/', 'https://guide.michelin.com/en/hotels-stays/lugano/villa-principe-leopoldo-7982'),
    ('hotel_76', 'Mandarin Oriental Palace, Luzern', '+41 41 588 18 88', 'https://www.mandarinoriental.com/en/luzern/palace', 'https://guide.michelin.com/en/hotels-stays/luzern/mandarin-oriental-palace-luzern-13203'),
    ('hotel_77', 'Fairmont Le Montreux Palace', '+41 21 962 12 12', 'https://www.fairmont.com/en/hotels/montreux/fairmont-le-montreux-palace.html', 'https://guide.michelin.com/en/hotels-stays/montreux/fairmont-le-montreux-palace-13882'),
    ('hotel_78', 'Grand Hotel Kronenhof', '+41 81 830 30 30', 'https://www.kronenhof.com/en', 'https://guide.michelin.com/en/hotels-stays/pontresina/grand-hotel-kronenhof-8906'),
    ('hotel_79', 'Boutique Hotel Restaurant Krone Regensberg', '+41 44 855 20 20', 'https://kroneregensberg.com/de/', 'https://guide.michelin.com/en/hotels-stays/Regensberg/boutique-hotel-restaurant-krone-regensberg-8082'),
    ('hotel_80', 'The Capra', '+41 27 958 13 58', 'https://www.capra.ch/', 'https://guide.michelin.com/en/hotels-stays/saas-fee/the-capra-8404'),
    ('hotel_81', 'Kulm Hotel St. Moritz', '+41 81 836 80 00', 'https://www.kulm.com/en', 'https://guide.michelin.com/en/hotels-stays/st-moritz/kulm-hotel-st-moritz-7325'),
    ('hotel_82', 'Suvretta House', '+41 81 836 36 36', 'https://suvrettahouse.ch/', 'https://guide.michelin.com/en/hotels-stays/st-moritz/suvretta-house-10858'),
    ('hotel_83', '7132 Hotel', '+41 58 713 20 00', 'https://7132.com/en/', 'https://guide.michelin.com/en/hotels-stays/vals/7132-hotel-8526'),
    ('hotel_84', 'Park Hotel Vitznau', '+41 41 399 60 60', 'https://www.parkhotel-vitznau.ch/', 'https://guide.michelin.com/en/hotels-stays/vitznau/park-hotel-vitznau-11122'),
    ('hotel_85', 'CERVO Mountain Resort', '+41 27 968 12 12', 'https://cervo.swiss/en', 'https://guide.michelin.com/en/hotels-stays/zermatt/cervo-mountain-boutique-resort-12506'),
    ('hotel_86', 'Matterhorn FOCUS', '+41 27 966 24 24', 'https://www.matterhorn-focus.ch/', 'https://guide.michelin.com/en/hotels-stays/zermatt/matterhorn-focus-10451'),
    ('hotel_87', 'La Réserve Eden au Lac Zurich', '+41 44 266 25 25', 'https://www.lareserve-zurich.com/', 'https://guide.michelin.com/en/hotels-stays/zurich/la-reserve-eden-au-lac-zurich-10745');

do $$
declare bad text; n int;
begin
  select count(*) into n from _c;
  if n <> 42 then raise exception 'expected 42 rows in _c, found %', n; end if;

  select string_agg(c.code, ', ') into bad from _c c
   where not exists (select 1 from public.hotels h
                      where h.hotel_code = c.code and h.country_code = 'CH'
                        and h.michelin_keys is not null and h.name = c.name);
  if bad is not null then raise exception 'not the expected Switzerland Key hotel: %', bad; end if;

  select string_agg(c.code, ', ') into bad from _c c join public.hotels h on h.hotel_code = c.code
   where (c.phone is not null and h.phone is not null)
      or (c.website_url is not null and h.website_url is not null)
      or (c.michelin_url is not null and h.michelin_url is not null);
  if bad is not null then raise exception 'field already set since the export (refusing to skip silently): %', bad; end if;

  select string_agg(c.code || ' -> ' || h.hotel_code, ', ') into bad from _c c
    join public.hotels h on h.michelin_url = c.michelin_url and h.hotel_code <> c.code;
  if bad is not null then raise exception 'MICHELIN URL already held by another hotel: %', bad; end if;

  update public.hotels h set michelin_url = c.michelin_url from _c c
   where h.hotel_code = c.code and h.country_code = 'CH' and c.michelin_url is not null and h.michelin_url is null;
  get diagnostics n = row_count;
  if n <> 39 then raise exception 'michelin_url: expected 39 rows, updated %', n; end if;

  update public.hotels h set website_url = c.website_url from _c c
   where h.hotel_code = c.code and h.country_code = 'CH' and c.website_url is not null and h.website_url is null;
  get diagnostics n = row_count;
  if n <> 35 then raise exception 'website_url: expected 35 rows, updated %', n; end if;

  update public.hotels h set phone = c.phone from _c c
   where h.hotel_code = c.code and h.country_code = 'CH' and c.phone is not null and h.phone is null;
  get diagnostics n = row_count;
  if n <> 41 then raise exception 'phone: expected 41 rows, updated %', n; end if;
end $$;

commit;
