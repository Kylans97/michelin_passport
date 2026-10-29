-- PREPARED -- NOT APPLIED.
--
-- Contact fields for Austria's MICHELIN Key hotels: phone, website_url and
-- michelin_url, filled only where production has NULL. Written 2026-10-29
-- from a read-only production export of the same day (48 AT hotels with
-- michelin_keys set). Evidence per row, with source URL and how each value
-- was confirmed: at_hotels_all.csv beside this file. Report: SIX_COUNTRIES_REPORT.md.
--
--   michelin_url  47 rows  the hotel's own guide.michelin.com page, matched
--                         on coordinates + postcode, never on name
--   website_url   45 rows  the hotel's own site (for a chain, the property
--                         page), confirmed by name + city + address on the site
--   phone         46 rows  the number printed on the hotel's own site
--                         (rule of 2026-10-28, see michelin_pe_2026)
--
-- Only values marked `confirmed` in the CSV are here; `unclear` and
-- `not_found` stay NULL.
--
-- Guards (one transaction; any failure rolls everything back):
--   1. every code exists as a Austria hotel with a Key and the expected name;
--   2. every field this file fills is still NULL (nothing filled since the
--      export) -- otherwise it raises instead of skipping silently;
--   3. no MICHELIN URL here is already held by another hotel row
--      (hotels_michelin_url_key is unique);
--   4. the number of rows each UPDATE touches equals the number expected.
-- Each UPDATE is also limited to `hotel_code = ... and country_code = 'AT'
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
    ('hotel_119', 'Das Kronthaler', '+43 5246 6389', 'https://www.daskronthaler.com/', 'https://guide.michelin.com/en/hotels-stays/Achenkirch/das-kronthaler-7903'),
    ('hotel_120', 'Scheiblhofer THE RESORT', '+43 2176 2610 800', 'https://www.theresort.at/', 'https://guide.michelin.com/en/hotels-stays/Andau/scheiblhofer-the-resort-14172'),
    ('hotel_121', 'The Comodo Bad Gastein', '+43 6434 304 32', 'https://www.thecomodo.com/', 'https://guide.michelin.com/en/hotels-stays/bad-gastein/the-comodo-bad-gastein-13137'),
    ('hotel_122', 'Eriro', '+43 5673 40506', 'https://www.eriro.at/de/', 'https://guide.michelin.com/en/hotels-stays/Ehrwald/eriro-15205'),
    ('hotel_123', 'Schlosshotel Fiss', '+43 5476 6397', 'https://www.schlosshotel-fiss.com/en/', 'https://guide.michelin.com/en/hotels-stays/fiss/schlosshotel-fiss-13950'),
    ('hotel_124', 'Impulshotel FREIGOLD', '+43 7942 22334', 'https://www.hotel-freigold.at/', 'https://guide.michelin.com/en/hotels-stays/Freistadt/hotel-freigold-14167'),
    ('hotel_125', 'Bergblick', '+43 5675 63960', 'https://www.hotelbergblick.at/', 'https://guide.michelin.com/en/hotels-stays/gran/bergblick-13951'),
    ('hotel_126', 'Genießer- & Romantikhotel DAS SCHIFF', '+43 5513 62200', 'https://www.schiff-hittisau.com/', 'https://guide.michelin.com/en/hotels-stays/vorarlberg/genieer-romantikhotel-das-schiff-13771'),
    ('hotel_127', 'Boutique Hotel Weisses Rössl', '+43 512 5830570', 'https://www.roessl.at/', 'https://guide.michelin.com/en/hotels-stays/innsbruck/boutiquehotel-weisses-rossl-13775'),
    ('hotel_128', 'Elizabeth Arthotel', '+43 5444 5411', 'https://www.elizabeth.at/', 'https://guide.michelin.com/en/hotels-stays/ischgl/elizabeth-arthotel-14514'),
    ('hotel_129', 'Hotel Trofana Royal Resort', '+43 5444 600', 'https://www.trofana-royal.at/', 'https://guide.michelin.com/en/hotels-stays/Ischgl-2/hotel-trofana-royal-resort-13883'),
    ('hotel_130', 'Schlosshotel Ischgl', '+43 5444 5633', 'https://www.schlosshotel-ischgl.com/', 'https://guide.michelin.com/en/hotels-stays/Ischgl-2/schlosshotel-ischgl-13941'),
    ('hotel_131', 'Hotel Kitzhof Mountain Design Resort', '+43 5356 632 110', 'https://www.hotel-kitzhof.com/', 'https://guide.michelin.com/en/hotels-stays/kitzbuhel/hotel-kitzhof-mountain-design-resort-6642'),
    ('hotel_132', 'Hotel Weisses Roessl', '+43 5356 71900', 'https://www.roesslkitz.at/', 'https://guide.michelin.com/en/hotels-stays/kitzbuhel/hotel-weisses-roessl-14225'),
    ('hotel_133', 'Schwarzer Adler - Adults Only', '+43 5356 6911', 'https://www.adlerkitz.at/', 'https://guide.michelin.com/en/hotels-stays/kitzbuhel/schwarzer-adler-kitzbuhel-13942'),
    ('hotel_134', 'Post Lech Arlberg', '+43 5583 22060', 'https://www.postlech.com/', 'https://guide.michelin.com/en/hotels-stays/lech-am-arlberg/post-lech-arlberg-8984'),
    ('hotel_135', 'Burg Vital Resort', '+43 5583 3140', 'https://www.burgvitalresort.com/en/', 'https://guide.michelin.com/en/hotels-stays/lech-am-arlberg/burg-vital-resort-13884'),
    ('hotel_136', 'Walch''s Rote Wand Gourmet Hotel', '+43 5583 34350', 'https://www.rotewand.com/', 'https://guide.michelin.com/en/hotels-stays/lech-am-arlberg/rote-wand-gourmet-hotel-453'),
    ('hotel_137', 'Hotel Krallerhof', '+43 6583 8246', 'https://www.krallerhof.com/', 'https://guide.michelin.com/en/hotels-stays/leogang/hotel-krallerhof-13891'),
    ('hotel_138', 'mama thresl', '+43 6583 20800', 'https://www.mama-thresl.com/', 'https://guide.michelin.com/en/hotels-stays/leogang/mama-thresl-7906'),
    ('hotel_139', 'Naturhotel Forsthofgut', '+43 6583 8561', 'https://www.forsthofgut.at/', 'https://guide.michelin.com/en/hotels-stays/leogang/naturehotel-forsthofgut-13780'),
    ('hotel_140', 'die HOCHKÖNIGIN Mountain Resort', '+43 6584 7447', 'https://www.hochkoenigin.com/', 'https://guide.michelin.com/en/hotels-stays/maria-alm/die-hochkonigin-mountain-resort-14169'),
    ('hotel_141', 'Hideaway Hotel Montestyria Chalets & Suiten', '+43 3882 93080', 'https://www.montestyria.at/', 'https://guide.michelin.com/en/hotels-stays/styria/hideaway-hotel-montestyria-chalets-suiten-13556'),
    ('hotel_142', 'ZillergrundRock Luxury Mountain Resort', '+43 5285 62377', 'https://www.zillergrund.at/en/', null),
    ('hotel_143', 'Spa Hotel Jagdhof', '+43 5226 26660', 'https://www.hotel-jagdhof.at/', 'https://guide.michelin.com/en/hotels-stays/Neustift-im-Stubaital-2/relais-chateaux-spa-hotel-jagdhof-13892'),
    ('hotel_144', 'Alpenresort Schwarz', '+43 5264 52120', 'https://www.schwarz.at/', 'https://guide.michelin.com/en/hotels-stays/Obermieming/alpenresort-schwarz-14562'),
    ('hotel_145', 'Holzleiten Bio Wellness Hotel', '+43 5264 8244', 'https://www.holzleiten.at/', 'https://guide.michelin.com/en/hotels-stays/Obsteig/holzleiten-bio-wellness-hotel-14168'),
    ('hotel_146', 'MALAT Weingut und Hotel', '+43 2732 82934', 'https://www.malat.at/wp/', 'https://guide.michelin.com/en/hotels-stays/furth-bei-gottweig/malat-weingut-und-hotel-10767'),
    ('hotel_29', 'Rosewood Schloss Fuschl', '+43 6229 39980', null, 'https://guide.michelin.com/en/hotels-stays/hof-bei-salzburg/rosewood-schloss-fuschl-13887'),
    ('hotel_30', 'Hotel Sacher Wien', null, null, 'https://guide.michelin.com/en/hotels-stays/vienna/hotel-sacher-wien-6301'),
    ('hotel_31', 'DAS EDELWEISS - Salzburg Mountain Resort', '+43 6414 3000', 'https://www.edelweiss-grossarl.com/de/', 'https://guide.michelin.com/en/hotels-stays/grossarl/das-edelweiss-salzburg-mountain-resort-13576'),
    ('hotel_32', 'Family Nature Resort Moar Gut', '+43 6414 318', 'https://www.moargut.com/', 'https://guide.michelin.com/en/hotels-stays/grossarl/family-nature-resort-moar-gut-13886'),
    ('hotel_33', 'TOP Hotel Hochgurgl', '+43 5256 6265', 'https://tophotelhochgurgl.com/', 'https://guide.michelin.com/en/hotels-stays/Hochgurgl/top-hotel-hochgurgl-13949'),
    ('hotel_34', 'Grand Tirolia Kitzbühel', '+43 5356 66615', 'https://grand-tirolia-kitzbuehel.hommage-hotels.com/en/', 'https://guide.michelin.com/en/hotels-stays/kitzbuhel/grand-tirolia-kitzbuhel-13885'),
    ('hotel_35', 'Naturhotel Waldklause', '+43 5253 5455', 'https://www.waldklause.at/', 'https://guide.michelin.com/en/hotels-stays/L%C3%A4ngenfeld/naturhotel-waldklause-14170'),
    ('hotel_36', 'Hotel Almhof Schneider', '+43 5583 3500', 'https://www.almhof.at/', 'https://guide.michelin.com/en/hotels-stays/lech-am-arlberg/hotel-almhof-schneider-13955'),
    ('hotel_37', 'Severins – The Alpine Retreat', '+43 5583 339070', 'https://www.severins-lech.at/', 'https://guide.michelin.com/en/hotels-stays/lech-am-arlberg/severins-the-alpine-retreat-13940'),
    ('hotel_38', 'Alpen-Wellness Resort Hochfirst', '+43 5256 63250', 'https://www.hochfirst.com/de', 'https://guide.michelin.com/en/hotels-stays/obergurgl/alpen-wellness-resort-hochfirst-13947'),
    ('hotel_39', 'Schloss Mönchstein', '+43 662 84 85 550', 'https://monchstein.at/', 'https://guide.michelin.com/en/hotels-stays/salzburg/schloss-monchstein-14144'),
    ('hotel_40', 'Hotel Tannenhof', '+43 5446 30311', 'https://www.hoteltannenhof.net/', 'https://guide.michelin.com/en/hotels-stays/St.-Anton-am-Arlberg/hotel-tannenhof-13560'),
    ('hotel_41', 'Hotel Schloss Seefels', '+43 4272 2377', 'https://www.seefels.at/', 'https://guide.michelin.com/en/hotels-stays/Techelsberg/hotel-schloss-seefels-13778'),
    ('hotel_42', 'Aktiv & Wellnesshotel Bergfried', '+43 5287 87239', 'https://www.bergfried.at/', 'https://guide.michelin.com/en/hotels-stays/Tux/aktiv-wellnesshotel-bergfried-14211'),
    ('hotel_43', 'Falkensteiner Schlosshotel Velden', '+43 4274 520000', 'https://www.falkensteiner.com/schlosshotel-velden', 'https://guide.michelin.com/en/hotels-stays/velden-am-worthersee/schloss-velden-8806'),
    ('hotel_44', 'Hotel Imperial', '+43 1 501100', 'https://www.marriott.com/en-us/hotels/vieil-hotel-imperial-a-luxury-collection-hotel-vienna/overview/', 'https://guide.michelin.com/en/hotels-stays/vienna/hotel-imperial-9475'),
    ('hotel_45', 'Hotel Sans Souci Wien', '+43 1 522 25 20', 'https://www.sanssouci-wien.com/', 'https://guide.michelin.com/en/hotels-stays/vienna/hotel-sans-souci-wien-6879'),
    ('hotel_46', 'Park Hyatt Vienna', null, null, 'https://guide.michelin.com/en/hotels-stays/vienna/park-hyatt-vienna-7641'),
    ('hotel_47', 'Rosewood Vienna', '+43 1 7999 888', 'https://www.rosewoodhotels.com/en/vienna', 'https://guide.michelin.com/en/hotels-stays/vienna/rosewood-vienna-12721'),
    ('hotel_48', 'The Amauris Vienna', '+43 1 22122', 'https://www.theamauris.com/vienna', 'https://guide.michelin.com/en/hotels-stays/vienna/the-amauris-vienna-123383-13550');

do $$
declare bad text; n int;
begin
  select count(*) into n from _c;
  if n <> 48 then raise exception 'expected 48 rows in _c, found %', n; end if;

  select string_agg(c.code, ', ') into bad from _c c
   where not exists (select 1 from public.hotels h
                      where h.hotel_code = c.code and h.country_code = 'AT'
                        and h.michelin_keys is not null and h.name = c.name);
  if bad is not null then raise exception 'not the expected Austria Key hotel: %', bad; end if;

  select string_agg(c.code, ', ') into bad from _c c join public.hotels h on h.hotel_code = c.code
   where (c.phone is not null and h.phone is not null)
      or (c.website_url is not null and h.website_url is not null)
      or (c.michelin_url is not null and h.michelin_url is not null);
  if bad is not null then raise exception 'field already set since the export (refusing to skip silently): %', bad; end if;

  select string_agg(c.code || ' -> ' || h.hotel_code, ', ') into bad from _c c
    join public.hotels h on h.michelin_url = c.michelin_url and h.hotel_code <> c.code;
  if bad is not null then raise exception 'MICHELIN URL already held by another hotel: %', bad; end if;

  update public.hotels h set michelin_url = c.michelin_url from _c c
   where h.hotel_code = c.code and h.country_code = 'AT' and c.michelin_url is not null and h.michelin_url is null;
  get diagnostics n = row_count;
  if n <> 47 then raise exception 'michelin_url: expected 47 rows, updated %', n; end if;

  update public.hotels h set website_url = c.website_url from _c c
   where h.hotel_code = c.code and h.country_code = 'AT' and c.website_url is not null and h.website_url is null;
  get diagnostics n = row_count;
  if n <> 45 then raise exception 'website_url: expected 45 rows, updated %', n; end if;

  update public.hotels h set phone = c.phone from _c c
   where h.hotel_code = c.code and h.country_code = 'AT' and c.phone is not null and h.phone is null;
  get diagnostics n = row_count;
  if n <> 46 then raise exception 'phone: expected 46 rows, updated %', n; end if;
end $$;

commit;
