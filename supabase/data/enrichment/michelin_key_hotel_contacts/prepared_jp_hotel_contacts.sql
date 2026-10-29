-- PREPARED -- NOT APPLIED.
--
-- Contact fields for Japan's MICHELIN Key hotels: phone, website_url and
-- michelin_url, filled only where production has NULL. Written 2026-10-29
-- from a read-only production export of the same day (118 JP hotels with
-- michelin_keys set). Evidence per row, with source URL and how each value
-- was confirmed: jp_hotels_all.csv beside this file. Report: JP_REPORT.md.
--
--   michelin_url  116 rows  the hotel's own guide.michelin.com page, matched
--                         on coordinates + postcode, never on name
--   website_url   97 rows  the hotel's own site (for a chain, the property
--                         page), confirmed by name + city + address on the site
--   phone         93 rows  the number printed on the hotel's own site
--                         (rule of 2026-10-28, see michelin_pe_2026)
--
-- Only values marked `confirmed` in the CSV are here; `unclear` and
-- `not_found` stay NULL.
--
-- Guards (one transaction; any failure rolls everything back):
--   1. every code exists as a Japanese hotel with a Key and the expected name;
--   2. every field this file fills is still NULL (nothing filled since the
--      export) -- otherwise it raises instead of skipping silently;
--   3. no MICHELIN URL here is already held by another hotel row
--      (hotels_michelin_url_key is unique);
--   4. the number of rows each UPDATE touches equals the number expected.
-- Each UPDATE is also limited to `hotel_code = ... and country_code = 'JP'
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
    ('hotel_573', 'Yamagata The Takinami', '+81 238 43 6111', 'http://www.takinami.co.jp/', 'https://guide.michelin.com/en/hotels-stays/Nanyo/yamagata-the-takinami-14299'),
    ('hotel_574', 'Rosewood Miyakojima', null, 'https://www.rosewoodhotels.com/en/miyakojima', 'https://guide.michelin.com/en/hotels-stays/miyakojima/rosewood-miyakojima-14863'),
    ('hotel_575', 'Patina Osaka', null, 'https://patinahotels.com/osaka', 'https://guide.michelin.com/en/hotels-stays/osaka1/patina-osaka-14861'),
    ('hotel_576', 'TAYUTA', '+81 50 1706 5284', 'https://amakusa-tayuta.com/', 'https://guide.michelin.com/en/hotels-stays/Kami%20Amakusa/tayuta-15424'),
    ('hotel_577', 'Fairmont Tokyo', '+81 3 4321 1111', 'https://www.fairmont.com/en/hotels/tokyo/fairmont-tokyo.html', 'https://guide.michelin.com/en/hotels-stays/tokyo/fairmont-tokyo-15406'),
    ('hotel_578', 'Myoken Ishiharaso', '+81 995 77 2111', 'https://www.m-ishiharaso.com/', 'https://guide.michelin.com/en/hotels-stays/kirishima/myoken-ishiharaso-15243'),
    ('hotel_579', 'RYOTEI HANZUIRYO', '+81 957 73 2111', 'https://hanzuiryo-unzen.jp/', 'https://guide.michelin.com/en/hotels-stays/unzen1/ryotei-hanzuiryo-13984'),
    ('hotel_580', 'Banyan Tree Higashiyama Kyoto', '+81 75 531 0500', 'https://www.banyantree.com/japan/kyoto', 'https://guide.michelin.com/en/hotels-stays/kyoto/banyan-tree-higashiyama-kyoto-14282'),
    ('hotel_581', 'THE HIRAMATSU Karuizawa Miyota', '+81 267 31 5680', 'https://www.hiramatsuhotels.com/miyota/', 'https://guide.michelin.com/en/hotels-stays/miyota-cho-kitasaku-gun/the-hiramatsu-karuizawa-miyota-13939'),
    ('hotel_582', 'Shoraiso', '+81 269 33 2114', 'https://shoraiso.com/', 'https://guide.michelin.com/en/hotels-stays/Yamanouchi/shoraiso-14284'),
    ('hotel_583', 'ESPACIO The Hakone Geihinkan Rin-Poh-Ki-Ryu', '+81 460 87 9200', 'https://houoh.jp/', 'https://guide.michelin.com/en/hotels-stays/hakone/espacio-the-hakone-geihinkan-rin-poh-ki-ryu-14280'),
    ('hotel_584', 'SIMOSE ART GARDEN VILLA', null, 'https://artsimose.jp/villa/', 'https://guide.michelin.com/en/hotels-stays/Otake/simose-art-garden-villa-14272'),
    ('hotel_585', 'Fuji Speedway Hotel', null, null, 'https://guide.michelin.com/en/hotels-stays/Oyama/fuji-speedway-hotel-14253'),
    ('hotel_586', 'Fugaku Gunjo', '+81 50 5805 9386', 'https://www.fugakugunjo.jp/', 'https://guide.michelin.com/en/hotels-stays/izu/fugaku-gunjo-14307'),
    ('hotel_587', 'THE HIRAMATSU HOTELS & RESORTS Kashikojima', '+81 599 65 7001', 'https://www.hiramatsuhotels.com/kashikojima/', 'https://guide.michelin.com/en/hotels-stays/Shima/the-hiramatsu-hotels-resorts-kashikojima-13376'),
    ('hotel_588', 'TIAD, Autograph Collection', '+81 52 252 2288', 'https://www.marriott.com/en-us/hotels/ngoak-tiad-autograph-collection/overview/', 'https://guide.michelin.com/en/hotels-stays/nagoya/tiad-autograph-collection-13321'),
    ('hotel_589', 'Setsu Niseko', '+81 136 55 7882', 'https://setsuniseko.com/en/', 'https://guide.michelin.com/en/hotels-stays/kutchancho/setsu-niseko-13383'),
    ('hotel_590', 'MUWA NISEKO', '+81 136 23 0955', 'https://www.muwaniseko.com/', 'https://guide.michelin.com/en/hotels-stays/kutchancho/muwa-niseko-13937'),
    ('hotel_591', 'THE HIRAMATSU HOTELS & RESORTS SENGOKUHARA', '+81 460 83 8981', 'https://www.hiramatsuhotels.com/sengokuhara/', 'https://guide.michelin.com/en/hotels-stays/hakone/the-hiramatsu-hotels-resorts-sengokuhara-13436'),
    ('hotel_592', 'Kofuyuden Beniya', null, null, 'https://guide.michelin.com/en/hotels-stays/Awara/beniya-kofuyuden-13385'),
    ('hotel_593', 'Sansui Niseko', '+81 136 22 2000', 'https://sansuiniseko.com/', 'https://guide.michelin.com/en/hotels-stays/kutchancho/sansui-niseko-13372'),
    ('hotel_594', 'Fufu Nara', null, null, 'https://guide.michelin.com/en/hotels-stays/nara/fufu-nara-13938'),
    ('hotel_595', 'Nasu Mukunone', '+81 287 73 8169', 'https://mukunone.jp/', 'https://guide.michelin.com/en/hotels-stays/nasu/nasu-mukunone-auberge-13877'),
    ('hotel_596', 'Ryokan Onomichi Nishiyama', null, 'https://o-nishiyama.co.jp/', 'https://guide.michelin.com/en/hotels-stays/onomichi/ryokan-onomichi-nishivama-13396'),
    ('hotel_597', 'Fufu Karuizawa Wind in the Sunshine', null, null, 'https://guide.michelin.com/en/hotels-stays/karuizawamachi/fufu-karuizawa-yokou-no-kaze-13391'),
    ('hotel_598', 'THE HIRAMATSU HOTELS & RESORTS Ginoza', '+81 98 968 5600', 'https://www.hiramatsuhotels.com/ginoza/', 'https://guide.michelin.com/en/hotels-stays/Ginoza/the-hiramatsu-ginoza-13377'),
    ('hotel_599', 'The Kahala Hotel & Resort Yokohama', '+81 45 522 0008', 'https://thekahala.jp/yokohama/', 'https://guide.michelin.com/en/hotels-stays/yokohama/the-kahala-hotel-resort-yokohama-13371'),
    ('hotel_600', 'One Suite THE GRAND', '+81 980 51 5770', 'https://onesuite.thegrand.jp/', 'https://guide.michelin.com/en/hotels-stays/Nakijin/one-suite-the-grand-13390'),
    ('hotel_601', 'Garrya Nijo Castle Kyoto', '+81 75 366 5806', 'https://www.garrya.com/en/destinations/kyoto', 'https://guide.michelin.com/en/hotels-stays/kyoto-prefecture/garrya-nijo-castle-kyoto-banyan-tree-group-12785'),
    ('hotel_602', 'Fufu Nikko', null, null, 'https://guide.michelin.com/en/hotels-stays/nikko/fufu-nikko-13437'),
    ('hotel_603', 'Hakone Gora Karaku', '+81 460 83 8860', 'https://gora-karaku.orixhotelsandresorts.com/', 'https://guide.michelin.com/en/hotels-stays/hakone/hakone-gora-karaku-13439'),
    ('hotel_604', 'BYAKU Narai', '+81 264 34 3001', 'https://byaku.site/', 'https://guide.michelin.com/en/hotels-stays/Shiojiri/byaku-narai-13531'),
    ('hotel_605', 'The Ritz-Carlton Fukuoka', '+81 92 401 8888', 'https://www.ritzcarlton.com/en/hotels/fukrz-the-ritz-carlton-fukuoka/overview/', 'https://guide.michelin.com/en/hotels-stays/fukuoka/the-ritz-carlton-fukuoka-13322'),
    ('hotel_606', 'Naoshima Ryokan Roka', '+81 87 899 2356', 'https://roka.voyage/', 'https://guide.michelin.com/en/hotels-stays/naoshima/naoshima-ryokan-roka-13528'),
    ('hotel_607', 'Fufu Kyu-Karuizawa Restful Forest', null, null, 'https://guide.michelin.com/en/hotels-stays/karuizawamachi/fufu-kyu-karuizawa-seiyou-no-mori-13395'),
    ('hotel_608', 'ENOWA Yufuin', '+81 977 28 8310', 'https://enowa-yufuin.jp/', 'https://guide.michelin.com/en/hotels-stays/yufu1/enowa-13213'),
    ('hotel_609', 'Araya Totoan', '+81 761 77 0010', 'https://www.araya-totoan.com/', 'https://guide.michelin.com/en/hotels-stays/kaga/araya-totoan-3661'),
    ('hotel_610', 'Park Hyatt Niseko Hanazono', null, null, 'https://guide.michelin.com/en/hotels-stays/kutchancho/park-hyatt-niseko-hanazono-11905'),
    ('hotel_611', 'Hyakuna Garan', '+81 98 949 1011', 'https://www.hyakunagaran.com/', 'https://guide.michelin.com/en/hotels-stays/nanjo/hyakuna-garan-8930'),
    ('hotel_612', 'Izumo Hotel The Cliff', '+81 853 86 3300', 'https://hotel-the-cliff.jp/', 'https://guide.michelin.com/en/hotels-stays/izumo/izumo-hotel-the-cliff-13394'),
    ('hotel_613', 'GOTO RETREAT by Onko Chishin', '+81 959 78 5551', 'https://goto.by-onko-chishin.com/', 'https://guide.michelin.com/en/hotels-stays/goto/okcs-retreat-goto-ray-12784'),
    ('hotel_614', 'JW Marriott Hotel Nara', '+81 742 36 6000', 'https://www.marriott.com/en-us/hotels/osajw-jw-marriott-hotel-nara/overview/', 'https://guide.michelin.com/en/hotels-stays/nara/jw-marriott-hotel-nara-12571'),
    ('hotel_615', 'Four Seasons Hotel Kyoto', '+81 75 541 8288', 'https://www.fourseasons.com/kyoto/', 'https://guide.michelin.com/en/hotels-stays/kyoto-prefecture/four-seasons-hotel-kyoto-13516'),
    ('hotel_616', 'Fufu Hakone', null, null, 'https://guide.michelin.com/en/hotels-stays/hakone/fufu-hakone-13389'),
    ('hotel_617', 'Jusandi', '+81 980 88 2833', 'https://www.jusandi.jp/', 'https://guide.michelin.com/en/hotels-stays/ishigaki-island/jusandi-8006'),
    ('hotel_618', 'Conrad Osaka', '+81 6 6222 0111', 'https://conrad-osaka.hiltonjapan.co.jp/', 'https://guide.michelin.com/en/hotels-stays/osaka1/conrad-osaka-8734'),
    ('hotel_619', 'Fufu Kyoto', null, null, 'https://guide.michelin.com/en/hotels-stays/kyoto/fufu-kyoto-13865'),
    ('hotel_620', 'W Osaka', '+81 6 6484 5355', 'https://www.marriott.com/en-us/hotels/osaow-w-osaka/overview/', 'https://guide.michelin.com/en/hotels-stays/osaka1/w-osaka-11937'),
    ('hotel_621', 'Fufu Kawaguchiko', null, null, 'https://guide.michelin.com/en/hotels-stays/Fujikawaguchiko/fufu-kawaguchiko-12055'),
    ('hotel_622', 'The Ritz-Carlton, Nikko', '+81 288 25 6666', 'https://www.ritzcarlton.com/en/hotels/tyonz-the-ritz-carlton-nikko/overview/', 'https://guide.michelin.com/en/hotels-stays/nikko/the-ritz-carlton-nikko-11907'),
    ('hotel_623', 'The Ritz-Carlton, Okinawa', '+81 980 43 5555', 'https://www.ritzcarlton.com/en/hotels/okarz-the-ritz-carlton-okinawa/overview/', 'https://guide.michelin.com/en/hotels-stays/nago/the-ritz-carlton-okinawa-8457'),
    ('hotel_624', 'The Aoyama Grand Hotel', '+81 3 6271 5430', 'https://aoyamagrand.com/', 'https://guide.michelin.com/en/hotels-stays/tokyo/the-aoyama-grand-hotel-13862'),
    ('hotel_625', 'Sekitei', '+81 829 55 0601', 'https://www.sekitei.to/', 'https://guide.michelin.com/en/hotels-stays/hatsukaichi/sekitei-3681'),
    ('hotel_626', 'Wanosato', '+81 577 53 2321', 'https://www.wanosato.com/', 'https://guide.michelin.com/en/hotels-stays/takayama1/wanosato-6564'),
    ('hotel_627', 'Ochiairo', '+81 558 85 0014', 'https://www.ochiairo.co.jp/', 'https://guide.michelin.com/en/hotels-stays/izu/ochiairou-murakami-6663'),
    ('hotel_628', 'Satoyama Jujo', null, 'https://www.satoyama-jujo.com/', 'https://guide.michelin.com/en/hotels-stays/niigata-prefecture/satoyama-jujo-7822'),
    ('hotel_629', 'Suiran, A Luxury Collection Hotel, Kyoto', '+81 75 872 0101', 'https://www.marriott.com/en-us/hotels/ukylc-suiran-a-luxury-collection-hotel-kyoto/overview/', 'https://guide.michelin.com/en/hotels-stays/kyoto-prefecture/suiran-kyoto-11795'),
    ('hotel_630', 'Zaborin', '+81 136 23 0003', 'https://zaborin.com/', 'https://guide.michelin.com/en/hotels-stays/Kutchan/zaborin-ryokan-8795'),
    ('hotel_631', 'SETOUCHI RETREAT by Onko Chishin', '+81 89 977 9500', 'https://setouchi.by-onko-chishin.com/', 'https://guide.michelin.com/en/hotels-stays/matsuyama1/setouchi-retreat-by-onko-chrishin-8075'),
    ('hotel_632', 'Halekulani Okinawa', '+81 98 953 8600', 'https://www.okinawa.halekulani.com/', 'https://guide.michelin.com/en/hotels-stays/onna/halekulani-okinawa-11475'),
    ('hotel_633', 'Four Seasons Hotel Osaka', '+81 6 6676 8682', 'https://www.fourseasons.com/osaka/', 'https://guide.michelin.com/en/hotels-stays/osaka1/four-seasons-hotel-osaka-14295'),
    ('hotel_634', 'Andaz Tokyo', null, null, 'https://guide.michelin.com/en/hotels-stays/tokyo/andaz-tokyo-7174'),
    ('hotel_635', 'The Okura Tokyo', null, 'https://theokuratokyo.jp/', 'https://guide.michelin.com/en/hotels-stays/tokyo/the-okura-tokyo-11478'),
    ('hotel_636', 'Hotel The Celestine Kyoto Gion', '+81 75 532 3111', 'https://www.celestinehotels.jp/kyoto-gion/', 'https://guide.michelin.com/en/hotels-stays/kyoto-prefecture/hotel-the-celestine-kyoto-gion-8835'),
    ('hotel_637', 'Four Seasons Hotel Tokyo at Marunouchi', '+81 3 5222 7222', 'https://www.fourseasons.com/tokyo/', 'https://guide.michelin.com/en/hotels-stays/tokyo/four-seasons-hotel-tokyo-at-marunouchi-7346'),
    ('hotel_638', 'Shangri-La Tokyo', '+81 3 6739 7888', 'https://www.shangri-la.com/tokyo/shangrila/', 'https://guide.michelin.com/en/hotels-stays/tokyo/shangrila-tokyo-6735'),
    ('hotel_639', 'Hiiragiya', '+81 75 221 1136', 'https://www.hiiragiya.co.jp/', 'https://guide.michelin.com/en/hotels-stays/kyoto-prefecture/hiiragiya-7587'),
    ('hotel_640', 'The Prince Gallery Tokyo Kioicho, a Luxury Collection Hotel', '+81 3 3234 1111', 'https://www.princehotels.com/kioicho/', 'https://guide.michelin.com/en/hotels-stays/tokyo/the-prince-gallery-tokyo-kioicho-a-luxury-collection-hotel-8450'),
    ('hotel_641', 'Mandarin Oriental Tokyo', '+81 3 3270 8800', 'https://www.mandarinoriental.com/en/tokyo/nihonbashi', 'https://guide.michelin.com/en/hotels-stays/tokyo/mandarin-oriental-tokyo-6225'),
    ('hotel_642', 'The Peninsula Tokyo', '+81 3 6270 2888', 'https://www.peninsula.com/en/tokyo/5-star-luxury-hotel-ginza', 'https://guide.michelin.com/en/hotels-stays/tokyo/the-peninsula-tokyo-5745'),
    ('hotel_643', 'HOTEL THE MITSUI KYOTO', null, null, 'https://guide.michelin.com/en/hotels-stays/kyoto-prefecture/the-mitsui-kyoto-11869'),
    ('hotel_644', 'The Ritz-Carlton Tokyo', '+81 3 3423 8000', 'https://www.ritzcarlton.com/en/hotels/tyorz-the-ritz-carlton-tokyo/overview/', 'https://guide.michelin.com/en/hotels-stays/tokyo/the-ritz-carlton-tokyo-7342'),
    ('hotel_645', 'The Ritz-Carlton Osaka', '+81 6 6343 7000', 'https://www.ritzcarlton.com/en/hotels/osarz-the-ritz-carlton-osaka/overview/', 'https://guide.michelin.com/en/hotels-stays/osaka1/the-ritz-carlton-osaka-7284'),
    ('hotel_646', 'The Ritz-Carlton, Kyoto', '+81 75 746 5555', 'https://www.ritzcarlton.com/en/hotels/ukyrz-the-ritz-carlton-kyoto/overview/', 'https://guide.michelin.com/en/hotels-stays/kyoto-prefecture/the-ritz-carlton-kyoto-7457'),
    ('hotel_647', 'Bvlgari Hotel Tokyo', '+81 3 6262 3333', null, 'https://guide.michelin.com/en/hotels-stays/tokyo/bvlgari-hotel-tokyo-13107'),
    ('hotel_648', 'The Hotel Seiryu Kyoto Kiyomizu', '+81 75 532 1111', 'https://www.princehotels.com/seiryu-kiyomizu/', 'https://guide.michelin.com/en/hotels-stays/kyoto/the-hotel-seiryu-kyoto-kiyomizu-13867'),
    ('hotel_649', 'Numazu Club', '+81 55 954 6611', 'https://numazu-club.com/', 'https://guide.michelin.com/en/hotels-stays/numazu/numazu-club-7913'),
    ('hotel_650', 'ROKU KYOTO LXR HOTELS & RESORTS', '+81 75 320 0111', 'https://www.rokukyoto.com/', 'https://guide.michelin.com/en/hotels-stays/kyoto/roku-kyoto-12343'),
    ('hotel_651', 'Higashiyama Niseko Village, a Ritz-Carlton Reserve', '+81 136 44 3491', 'https://www.ritzcarlton.com/en/hotels/ctsrz-higashiyama-niseko-village-a-ritz-carlton-reserve/overview/', 'https://guide.michelin.com/en/hotels-stays/nisekocho/higashiyama-niseko-village-a-ritz-carlton-reserve-11963'),
    ('hotel_652', 'GAJOEN', '+81 995 77 2114', 'https://gajoen.jp/', 'https://guide.michelin.com/en/hotels-stays/kirishima/gajoen-14006'),
    ('hotel_653', 'Hoshinoya Kyoto', '+81 75 871 0001', 'https://hoshinoresorts.com/ja/hotels/hoshinoyakyoto/', 'https://guide.michelin.com/en/hotels-stays/kyoto-prefecture/hoshinoya-kyoto-7458'),
    ('hotel_654', 'Yufuin Tamanoyu', '+81 977 84 2158', 'https://tamanoyu.co.jp/', 'https://guide.michelin.com/en/hotels-stays/yufu1/yufuin-tamanoyu-14506'),
    ('hotel_655', 'Onyado Chikurintei', '+81 954 23 0210', 'https://www.chikurintei.jp/', 'https://guide.michelin.com/en/hotels-stays/Takeo/onyado-chikurintei-15370'),
    ('hotel_656', 'OSTERIA SINCERITA', '+81 238 43 7800', 'https://osteria-sincerita.com/', 'https://guide.michelin.com/en/hotels-stays/Nanyo/osteria-sincerita-15369'),
    ('hotel_657', 'InterContinental Yokohama Pier 8', '+81 45 307 1111', 'https://icyokohama-pier8.com/', 'https://guide.michelin.com/en/hotels-stays/yokohama/intercontinental-yokohama-pier-8-11492'),
    ('hotel_658', 'Park Hyatt Kyoto', null, null, 'https://guide.michelin.com/en/hotels-stays/kyoto-prefecture/park-hyatt-kyoto-9433'),
    ('hotel_659', 'Four Seasons Hotel Tokyo at Otemachi', '+81 3 6810 0600', 'https://www.fourseasons.com/otemachi/', 'https://guide.michelin.com/en/hotels-stays/tokyo/four-seasons-hotel-tokyo-at-otemachi-12943'),
    ('hotel_660', 'Kifune Ugenta', '+81 75 741 2146', 'https://www.ugenta.co.jp/', 'https://guide.michelin.com/en/hotels-stays/kyoto-prefecture/ugenta-6875'),
    ('hotel_661', 'The Tokyo Station Hotel', '+81 3 5220 1111', 'https://www.tokyostationhotel.jp/', 'https://guide.michelin.com/en/hotels-stays/tokyo/the-tokyo-station-hotel-6748'),
    ('hotel_662', 'Oyado The Earth', null, null, 'https://guide.michelin.com/en/hotels-stays/mie-prefecture/oyado-the-earth-6607'),
    ('hotel_663', 'Bettei Otozure', '+81 837 25 3377', 'https://www.otozure.jp/', 'https://guide.michelin.com/en/hotels-stays/nagato/bettei-otozure-3691'),
    ('hotel_664', 'MUNI KYOTO', null, null, 'https://guide.michelin.com/en/hotels-stays/kyoto/muni-kyoto-11908'),
    ('hotel_665', 'Gora Kadan', '+81 460 82 3331', null, 'https://guide.michelin.com/en/hotels-stays/hakone/gora-kadan-64357-2371'),
    ('hotel_666', 'Arcana Izu', '+81 558 85 2700', 'https://www.arcanaresorts.com/', 'https://guide.michelin.com/en/hotels-stays/izu/arcana-izu-1281'),
    ('hotel_667', 'Ace Hotel Kyoto', '+81 75 229 9000', 'https://acehotel.com/kyoto/', 'https://guide.michelin.com/en/hotels-stays/kyoto/ace-hotel-kyoto-11701'),
    ('hotel_668', 'TRUNK (HOTEL) YOYOGI PARK', '+81 3 5454 3210', 'https://yoyogipark.trunk-hotel.com/', 'https://guide.michelin.com/en/hotels-stays/tokyo/trunkhotel-yoyogi-park-13365'),
    ('hotel_669', 'Genji Kyoto', '+81 75 365 3001', 'https://genjikyoto.com/', 'https://guide.michelin.com/en/hotels-stays/kyoto/genji-kyoto-12683'),
    ('hotel_670', 'Bettei Senjuan', '+81 278 20 4141', 'https://www.senjyuan.jp/', 'https://guide.michelin.com/en/hotels-stays/minakami/bettei-senjuan-3671'),
    ('hotel_671', 'SHISHI-IWA-HOUSE Karuizawa', '+81 267 31 6658', 'https://www.shishiiwahouse.jp/', 'https://guide.michelin.com/en/hotels-stays/karuizawamachi/shishi-iwa-house-karuizawa-13384'),
    ('hotel_672', 'Kamenoi Besso', '+81 977 84 3166', 'https://www.kamenoi-bessou.jp/', 'https://guide.michelin.com/en/hotels-stays/yufu1/kamenoibesso-13983'),
    ('hotel_673', 'Auberge TOKITO', '+81 42 525 8888', 'https://www.aubergetokito.com/', 'https://guide.michelin.com/en/hotels-stays/Tachikawa/auberge-tokito-14466'),
    ('hotel_674', 'Hotel New Otani Tokyo - Executive House ZEN', '+81 3 3265 1111', 'https://www.newotani.co.jp/tokyo/stay/exe/', 'https://guide.michelin.com/en/hotels-stays/tokyo/hotel-new-otani-tokyo-executive-house-zen-5535'),
    ('hotel_675', 'InterContinental Osaka', '+81 6 6374 5700', 'https://www.ihg.com/intercontinental/hotels/jp/ja/osaka/osaha/hoteldetail', 'https://guide.michelin.com/en/hotels-stays/osaka1/intercontinental-osaka-10779'),
    ('hotel_676', 'K5', '+81 3 5962 3485', 'https://k5-tokyo.com/', 'https://guide.michelin.com/en/hotels-stays/tokyo/k5-120190-10724'),
    ('hotel_677', 'Beniya Mukayu', '+81 761 77 1340', 'https://mukayu.com/', 'https://guide.michelin.com/en/hotels-stays/ishikawa-prefecture/beniya-mukayu-7221'),
    ('hotel_678', 'Nishimuraya Honkan', '+81 796 32 2211', 'https://www.nishimuraya.ne.jp/honkan/', 'https://guide.michelin.com/en/hotels-stays/toyooka/nishimuraya-honkan-ryokan-hyogo-8603'),
    ('hotel_679', 'Aman Kyoto', null, 'https://www.aman.com/resorts/aman-kyoto', 'https://guide.michelin.com/en/hotels-stays/kyoto-prefecture/aman-kyoto-9333'),
    ('hotel_680', 'Amanemu', '+81 599 52 5000', null, 'https://guide.michelin.com/en/hotels-stays/Shima/amanemu-8553'),
    ('hotel_681', 'JANU Tokyo', '+81 3 6731 2333', 'https://www.janu.com/janu-tokyo/', 'https://guide.michelin.com/en/hotels-stays/tokyo/janu-tokyo-13417'),
    ('hotel_682', 'Azumi Setoda', '+81 845 23 7911', 'https://azumi.co/setoda/', 'https://guide.michelin.com/en/hotels-stays/onomichi/azumi-setoda-13824'),
    ('hotel_683', 'Dusit Thani Kyoto', '+81 75 343 7150', 'https://www.dusit.com/dusitthani-kyoto/', 'https://guide.michelin.com/en/hotels-stays/kyoto/dusit-thani-kyoto-13366'),
    ('hotel_684', 'Six Senses Kyoto', '+81 75 531 0700', 'https://www.sixsenses.com/en/hotels-resorts/asia-the-pacific/japan/kyoto/', 'https://guide.michelin.com/en/hotels-stays/kyoto-prefecture/six-senses-kyoto-13660'),
    ('hotel_685', 'Bellustar Tokyo, A Pan Pacific Hotel', '+81 3 6233 8800', 'https://www.panpacific.com/en/hotels-and-resorts/bellustar-tokyo.html', 'https://guide.michelin.com/en/hotels-stays/tokyo/bellustar-tokyo-13392'),
    ('hotel_686', 'The Tower Hotel Nagoya', '+81 52 953 4450', 'https://thetowerhotel.jp/', 'https://guide.michelin.com/en/hotels-stays/nagoya/the-tower-hotel-nagoya-13381'),
    ('hotel_687', 'Kanamean Nishitomiya', '+81 75 211 2411', 'https://kanamean.co.jp/', 'https://guide.michelin.com/en/hotels-stays/kyoto-prefecture/kanamean-nishitomiya-8768'),
    ('hotel_688', 'Aman Tokyo', null, null, 'https://guide.michelin.com/en/hotels-stays/tokyo/aman-tokyo-7804');

do $$
declare bad text; n int;
begin
  select count(*) into n from _c;
  if n <> 116 then raise exception 'expected 116 rows in _c, found %', n; end if;

  select string_agg(c.code, ', ') into bad from _c c
   where not exists (select 1 from public.hotels h
                      where h.hotel_code = c.code and h.country_code = 'JP'
                        and h.michelin_keys is not null and h.name = c.name);
  if bad is not null then raise exception 'not the expected Japanese Key hotel: %', bad; end if;

  select string_agg(c.code, ', ') into bad from _c c join public.hotels h on h.hotel_code = c.code
   where (c.phone is not null and h.phone is not null)
      or (c.website_url is not null and h.website_url is not null)
      or (c.michelin_url is not null and h.michelin_url is not null);
  if bad is not null then raise exception 'field already set since the export (refusing to skip silently): %', bad; end if;

  select string_agg(c.code || ' -> ' || h.hotel_code, ', ') into bad from _c c
    join public.hotels h on h.michelin_url = c.michelin_url and h.hotel_code <> c.code;
  if bad is not null then raise exception 'MICHELIN URL already held by another hotel: %', bad; end if;

  update public.hotels h set michelin_url = c.michelin_url from _c c
   where h.hotel_code = c.code and h.country_code = 'JP' and c.michelin_url is not null and h.michelin_url is null;
  get diagnostics n = row_count;
  if n <> 116 then raise exception 'michelin_url: expected 116 rows, updated %', n; end if;

  update public.hotels h set website_url = c.website_url from _c c
   where h.hotel_code = c.code and h.country_code = 'JP' and c.website_url is not null and h.website_url is null;
  get diagnostics n = row_count;
  if n <> 97 then raise exception 'website_url: expected 97 rows, updated %', n; end if;

  update public.hotels h set phone = c.phone from _c c
   where h.hotel_code = c.code and h.country_code = 'JP' and c.phone is not null and h.phone is null;
  get diagnostics n = row_count;
  if n <> 93 then raise exception 'phone: expected 93 rows, updated %', n; end if;
end $$;

commit;
