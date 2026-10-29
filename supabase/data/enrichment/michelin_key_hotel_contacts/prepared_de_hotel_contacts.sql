-- PREPARED -- NOT APPLIED.
--
-- Contact fields for Germany's MICHELIN Key hotels: phone, website_url and
-- michelin_url, filled only where production has NULL. Written 2026-10-29
-- from a read-only production export of the same day (126 DE hotels with
-- michelin_keys set). Evidence per row, with source URL and how each value
-- was confirmed: de_hotels_all.csv beside this file. Report: DE_REPORT.md.
--
--   michelin_url  122 rows  the hotel's own guide.michelin.com page, matched
--                         on coordinates + postcode, never on name
--   website_url   120 rows  the hotel's own site (for a chain, the property
--                         page), confirmed by name + city + address on the site
--   phone         123 rows  the number printed on the hotel's own site
--                         (rule of 2026-10-28, see michelin_pe_2026)
--
-- Only values marked `confirmed` in the CSV are here; `unclear` and
-- `not_found` stay NULL.
--
-- Guards (one transaction; any failure rolls everything back):
--   1. every code exists as a German hotel with a Key and the expected name;
--   2. every field this file fills is still NULL (nothing filled since the
--      export) -- otherwise it raises instead of skipping silently;
--   3. no MICHELIN URL here is already held by another hotel row
--      (hotels_michelin_url_key is unique);
--   4. the number of rows each UPDATE touches equals the number expected.
-- Each UPDATE is also limited to `hotel_code = ... and country_code = 'DE'
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
    ('hotel_100', 'Sofitel Frankfurt Opera', '+49 69 2566950', 'https://www.sofitel-frankfurt.com/', 'https://guide.michelin.com/en/hotels-stays/frankfurt/sofitel-frankfurt-opera-10487'),
    ('hotel_101', 'Vitalhotel Alter Meierhof', '+49 4631 61990', 'https://www.alter-meierhof.de/', 'https://guide.michelin.com/en/hotels-stays/heiligendamm/alter-meierhof-9510'),
    ('hotel_102', 'Seezeitlodge Hotel & Spa', '+49 6852 80980', 'https://www.seezeitlodge-bostalsee.de/', 'https://guide.michelin.com/en/hotels-stays/gonnesweiler/seezeitlodge-hotel-spa-10204'),
    ('hotel_103', 'Das Achental Resort', '+49 8641 4010', 'https://www.das-achental.com/', 'https://guide.michelin.com/en/hotels-stays/Grassau/das-achental-resort-13234'),
    ('hotel_104', 'Hotel Louis C. Jacob', '+49 40 822550', 'https://hotel-jacob.de/', 'https://guide.michelin.com/en/hotels-stays/hamburg/hotel-louis-c-jacob-5860'),
    ('hotel_105', 'Luisenhöhe - Gesundheitsresort Schwarzwald', '+49 761 137330', 'https://www.luisenhoehe-hotel.de/', 'https://guide.michelin.com/en/hotels-stays/Horben/luisenhohe-gesundheitsresort-schwarzwald-13954'),
    ('hotel_106', 'Das Kranzbach Hotel & Wellness Retreat', '+49 8823 928000', 'https://www.daskranzbach.de/', 'https://guide.michelin.com/en/hotels-stays/kranzbach/das-kranzbach-hotel-wellness-retreat-6329'),
    ('hotel_107', 'Mandarin Oriental Munich', '+49 89 290980', 'https://www.mandarinoriental.com/en/munich/altstadt', 'https://guide.michelin.com/en/hotels-stays/munich/mandarin-oriental-munich-6339'),
    ('hotel_108', 'Rocco Forte Charles Hotel', '+49 89 5445550', 'https://www.roccofortehotels.com/hotels-and-resorts/the-charles-hotel/', 'https://guide.michelin.com/en/hotels-stays/munich/the-charles-hotel-a-rocco-forte-hotel-6327'),
    ('hotel_109', 'Rosewood Munich', '+49 89 8000190', 'https://www.rosewoodhotels.com/en/munich', 'https://guide.michelin.com/en/hotels-stays/munich/rosewood-munich-13281'),
    ('hotel_110', 'Sonnenalp Resort', '+49 8321 2720', 'https://www.sonnenalp.de/', 'https://guide.michelin.com/en/hotels-stays/Ofterschwang/sonnenalp-resort-13908'),
    ('hotel_111', 'Hotel Gut Steinbach', '+49 8640 8070', 'https://www.gutsteinbach.de/', 'https://guide.michelin.com/en/hotels-stays/reit-im-winkl/gut-steinbach-9534'),
    ('hotel_112', 'Wellness & Sport Hotel Jagdhof', '+49 8582 91594600', 'https://www.jagdhof-roehrnbach.de/', 'https://guide.michelin.com/en/hotels-stays/R%C3%B6hrnbach/wellness-sport-hotel-jagdhof-13953'),
    ('hotel_113', 'Parkhotel Egerner Höfe', '+49 8022 6660', 'https://www.egerner-hoefe.de/', 'https://guide.michelin.com/en/hotels-stays/rottach-egern/park-hotel-egerner-hofe-9909'),
    ('hotel_114', 'Esplanade Saarbrücken', '+49 681 84499120', 'https://www.esplanade-sb.de/', 'https://guide.michelin.com/en/hotels-stays/saarbrucken/esplanade-saarbrucken-11693'),
    ('hotel_115', 'La Maison', '+49 6831 89440440', 'https://lamaison-hotel.de/', null),
    ('hotel_116', 'Seesteg Norderney', '+49 4932 893600', 'https://seesteg-norderney.de/', 'https://guide.michelin.com/en/hotels-stays/Norderney-1/seesteg-norderney-13450'),
    ('hotel_117', 'Landhaus Stricker', '+49 4651 88990', 'https://www.landhaus-stricker.com/de/', null),
    ('hotel_118', 'Söl’ring Hof', '+49 4651 836200', 'https://www.soelring-hof.de/', null),
    ('hotel_158', 'Cortiina Hotel', '+49 89 2422490', 'https://cortiina.com/', 'https://guide.michelin.com/en/hotels-stays/munich/cortiina-hotel-6328'),
    ('hotel_159', 'Hotel Vier Jahreszeiten Kempinski', '+49 89 21250', 'https://www.kempinski.com/de/hotel-vier-jahreszeiten', 'https://guide.michelin.com/en/hotels-stays/munich/hotel-vier-jahreszeiten-kempinski-7403'),
    ('hotel_160', 'Hotel Adlon Kempinski', '+49 30 22610', 'https://www.kempinski.com/en/hotel-adlon', 'https://guide.michelin.com/en/hotels-stays/berlin/hotel-adlon-kempinski-6421'),
    ('hotel_161', 'Bayerischer Hof Munich', '+49 89 21200', 'https://www.bayerischerhof.de/', 'https://guide.michelin.com/en/hotels-stays/munich/bayerischer-hof-munich-7400'),
    ('hotel_162', 'Excelsior Hotel Ernst', '+49 221 2701', 'https://www.excelsiorhotelernst.com/', 'https://guide.michelin.com/en/hotels-stays/cologne/excelsior-hotel-ernst-6247'),
    ('hotel_163', 'The Mandala Hotel', '+49 30 590050000', 'https://www.themandala.de/', 'https://guide.michelin.com/en/hotels-stays/berlin/the-mandala-hotel-5051'),
    ('hotel_164', 'Wilmina Hotel', '+49 30 2018050', 'https://wilmina.com/', 'https://guide.michelin.com/en/hotels-stays/berlin/wilmina-hotel-12967'),
    ('hotel_165', 'Château Royal Berlin', '+49 30 23456770', 'https://www.chateauroyalberlin.com/en', 'https://guide.michelin.com/en/hotels-stays/berlin/chateau-royal-berlin-13125'),
    ('hotel_166', 'Das Stue', '+49 30 3117220', 'https://www.das-stue.com/', 'https://guide.michelin.com/en/hotels-stays/berlin/das-stue-116913-6744'),
    ('hotel_167', 'Hotel Orania.Berlin', '+49 30 69539680', 'https://orania.berlin/', 'https://guide.michelin.com/en/hotels-stays/berlin/hotel-oraniaberlin-8798'),
    ('hotel_168', 'Schloss Eberstein', '+49 7224 995950', 'https://www.hotel-schloss-eberstein.de/', 'https://guide.michelin.com/en/hotels-stays/gernsbach/schloss-eberstein-9637'),
    ('hotel_169', 'AMERON Neuschwanstein Alpsee Resort & Spa', '+49 8362 70300', 'https://www.ameroncollection.com/de/neuschwanstein-alpsee-resort-spa', 'https://guide.michelin.com/en/hotels-stays/schwangau/ameron-neuschwanstein-alpsee-resort-spa-10723'),
    ('hotel_170', 'Burg Schwarzenstein', '+49 6722 99500', 'https://www.burg-schwarzenstein.de/', 'https://guide.michelin.com/en/hotels-stays/geisenheim/relais-chateaux-hotel-burg-schwarzenstein-9762'),
    ('hotel_171', 'Kloster Hornbach', '+49 6338 910100', 'https://www.kloster-hornbach.de/', 'https://guide.michelin.com/en/hotels-stays/hornbach/kloster-hornbach-7242'),
    ('hotel_172', 'Gasthof Zufriedenheit', '+49 3445 7912051', 'https://gasthof-zufriedenheit.de/', 'https://guide.michelin.com/en/hotels-stays/naumburg/gasthof-zufriedenheit-8617'),
    ('hotel_173', 'Villa Sonnenhof Boutique Hotel', '+49 8651 9039993', 'https://www.villasonnenhof.de/', 'https://guide.michelin.com/en/hotels-stays/bad-reichenhall/villa-sonnenhof-boutique-hotel-12516'),
    ('hotel_174', 'Hotel Landhaus Wachtelhof', '+49 4261 8530', 'https://wachtelhof.de/', 'https://guide.michelin.com/en/hotels-stays/rotenburg-an-der-wumme/hotel-landhaus-wachtelhof-13910'),
    ('hotel_175', 'Althoff Grandhotel Schloss Bensberg', '+49 2204 420', 'https://www.althoffcollection.com/de/althoff-grandhotel-schloss-bensberg', 'https://guide.michelin.com/en/hotels-stays/Bensberg/althoff-grandhotel-schloss-bensberg-6333'),
    ('hotel_176', 'Grand Hotel Heiligendamm', '+49 38203 7400', 'https://www.grandhotel-heiligendamm.de/', 'https://guide.michelin.com/en/hotels-stays/Bad-Doberan/grand-hotel-heiligendamm-7440'),
    ('hotel_177', 'Landhaus Flottbek Boutique Hotel', '+49 40 8227410', 'https://www.landhaus-flottbek.de/de', 'https://guide.michelin.com/en/hotels-stays/hamburg/landhaus-flottbek-9934'),
    ('hotel_178', 'Villa Mittermeier', '+49 9861 94540', 'https://www.villamittermeier.de/', 'https://guide.michelin.com/en/hotels-stays/rothenburg-ob-der-tauber/villa-mittermeier-9736'),
    ('hotel_179', 'RIVA - Das Hotel am Bodensee', '+49 7531 363090', 'https://www.hotel-riva.de/', 'https://guide.michelin.com/en/hotels-stays/konstanz/riva-10089'),
    ('hotel_180', 'Hotel München Palace', '+49 89 419710', 'https://www.hotel-muenchen-palace.de/', 'https://guide.michelin.com/en/hotels-stays/munich/hotel-munchen-palace-6336'),
    ('hotel_181', 'HOTEL ZOO BERLIN', '+49 30 884370', 'https://www.hotelzoo.de/', 'https://guide.michelin.com/en/hotels-stays/berlin/hotel-zoo-7579'),
    ('hotel_182', 'Der Birkenhof Spa & Genuss Resort', '+49 9439 9500', 'https://www.der-birkenhof.de/', 'https://guide.michelin.com/en/hotels-stays/Neunburg%20v.%20W.%20%E2%80%93%20Hofenstetten/landhotel-birkenhof-9764'),
    ('hotel_183', 'Schlosshotel Münchhausen', '+49 5154 70600', 'https://www.schlosshotel-muenchhausen.com/', 'https://guide.michelin.com/en/hotels-stays/aerzen/schlosshotel-munchhausen-124408-14589'),
    ('hotel_184', 'Alpenloge Hotel', '+49 8381 9123600', 'https://alpenloge.com/', 'https://guide.michelin.com/en/hotels-stays/scheidegg/alpenloge-hotel-14604'),
    ('hotel_185', 'Hardenberg Burghotel', '+49 5503 9810', 'https://www.hardenberg-burghotel.de/de/', 'https://guide.michelin.com/en/hotels-stays/norten-hardenberg/relais-chateaux-hardenberg-burghotel-14231'),
    ('hotel_197', 'Hotel Oswald Gourmet & Spa', '+49 9923 84100', 'https://www.hotel-oswald.de/', 'https://guide.michelin.com/en/hotels-stays/Kaikenried/wellnesshotel-oswald-14510'),
    ('hotel_198', 'Hanusel Hof', '+49 8378 92000', 'https://www.hanusel-hof.de/', 'https://guide.michelin.com/en/hotels-stays/hellengerst/hanusel-hof-10088'),
    ('hotel_199', 'Hotel BEI SCHUMANN', '+49 3592 5200', 'https://www.bei-schumann.de/', 'https://guide.michelin.com/en/hotels-stays/Kirschau/hotel-bei-schumann-13912'),
    ('hotel_200', 'Hüttenhof - Wellnesshotel & Luxus-Bergchalets', '+49 8585 96050', 'https://www.huettenhof.de/', 'https://guide.michelin.com/en/hotels-stays/Grainet/huttenhof-wellnesshotel-luxus-bergchalets-adults-only-14423'),
    ('hotel_201', 'Chiemgauhof Lakeside Retreat', '+49 8642 3179800', 'https://www.chiemgauhof.com/', 'https://guide.michelin.com/en/hotels-stays/%C3%9Cbersee/chiemgauhof-lakeside-retreat-15121'),
    ('hotel_202', 'Steigenberger Icon Europäischer Hof Baden Baden', '+49 7221 40470', 'https://hrewards.com/en/steigenberger-icon-europaeischer-hof-baden-baden', 'https://guide.michelin.com/en/hotels-stays/baden-baden/steigenberger-icon-europaischer-hof-baden-baden-15113'),
    ('hotel_203', 'HUBERTUS Mountain Refugio Allgäu', '+49 8328 9200', 'https://www.hotel-hubertus.de/', 'https://guide.michelin.com/en/hotels-stays/oberallgau/hubertus-mountain-refugio-allgau-116503-11339'),
    ('hotel_204', 'Schlosshotel Burg Schlitz', '+49 3996 12700', 'https://www.burg-schlitz.de/', 'https://guide.michelin.com/en/hotels-stays/hohen-demzin/schlosshotel-burg-schlitz-13902'),
    ('hotel_205', '1884 Norderney', '+49 4932 5219900', 'https://1884-norderney.de/', 'https://guide.michelin.com/en/hotels-stays/Norderney-1/1884-norderney-13426'),
    ('hotel_206', 'Hof Galerie', '+49 4651 957050', 'https://www.hotelhofgalerie.de/', 'https://guide.michelin.com/en/hotels-stays/sylt/hof-galerie-9696'),
    ('hotel_207', 'Hotel Deimann', '+49 2975 810', 'https://www.deimann.de/', 'https://guide.michelin.com/en/hotels-stays/schmallenberg/hotel-deimann-13911'),
    ('hotel_208', 'Hotel Romantischer Winkel - RoLigio® & Wellness Resort', '+49 5523 3040', 'https://www.romantischer-winkel.de/', 'https://guide.michelin.com/en/hotels-stays/Bad-Sachsa/roligio-wellness-resort-romantischer-winkel-13898'),
    ('hotel_209', 'Hotel Maximilian''s', '+49 821 50360', 'https://www.hotelmaximilians.com/', 'https://guide.michelin.com/en/hotels-stays/augsburg/hotel-maximlians-13894'),
    ('hotel_210', 'Parkhotel Adler', '+49 7652 1270', 'https://www.parkhoteladler.de/', 'https://guide.michelin.com/en/hotels-stays/hinterzarten/parkhotel-adler-13485'),
    ('hotel_211', 'Strandhotel Fischland', '+49 38226 520', 'https://www.strandhotel-fischland.de/', 'https://guide.michelin.com/en/hotels-stays/Dierhagen/strandhotel-fischland-12418'),
    ('hotel_212', 'niXe Boutiquehotel & Spa', '+49 38393 666200', 'https://www.nixe-hotel.de/', 'https://guide.michelin.com/en/hotels-stays/binz/villa-nixe-9689'),
    ('hotel_213', 'The Wellem', '+49 211 547650622', 'https://thewellem.com/', 'https://guide.michelin.com/en/hotels-stays/dusseldorf/the-wellem-13904'),
    ('hotel_214', 'Das James', '+49 461 1672360', 'https://www.dasjames.com/', 'https://guide.michelin.com/en/hotels-stays/Flensburg-1/das-james-12429'),
    ('hotel_215', 'Strandhaus Spreewald', '+49 3546 7364', 'https://www.strandhaus-spreewald.de/', 'https://guide.michelin.com/en/hotels-stays/lubben/strandhaus-spreewald-11318'),
    ('hotel_216', 'Maison Messmer', '+49 7221 30120', 'https://maison-messmer-baden-baden.hommage-hotels.com/', 'https://guide.michelin.com/en/hotels-stays/baden-baden/maison-messmer-13899'),
    ('hotel_217', 'Do & Co Hotel Munich', '+49 89 69313780', 'https://www.docohotel.com/munich/en/', 'https://guide.michelin.com/en/hotels-stays/munich/do-co-hotel-munich-13907'),
    ('hotel_218', 'Mauritzhof Hotel Münster', '+49 251 41720', 'https://www.mauritzhof.de/', 'https://guide.michelin.com/en/hotels-stays/munster/mauritzhof-hotel-munster-11040'),
    ('hotel_219', 'Boutique-Hotel Friesinger', null, null, 'https://guide.michelin.com/en/hotels-stays/kressbronn-am-bodensee/boutique-hotel-friesinger-10612'),
    ('hotel_220', 'Steigenberger Icon Parkhotel Düsseldorf', '+49 211 13810', 'https://hrewards.com/de/steigenberger-icon-parkhotel-duesseldorf', 'https://guide.michelin.com/en/hotels-stays/dusseldorf/steigenberger-parkhotel-10311'),
    ('hotel_221', 'DAS.HOCHGRAT', '+49 8386 9914620', 'https://das-hochgrat.de/', 'https://guide.michelin.com/en/hotels-stays/oberstaufen/dashochgrat-9859'),
    ('hotel_222', 'ROEWERS Privathotel', '+49 38303 1220', 'https://roewers.de/', 'https://guide.michelin.com/en/hotels-stays/ostseebad-sellin/roewers-privathotel-9778'),
    ('hotel_223', 'Hotel Exquisit', '+49 8322 96330', 'https://www.hotel-exquisit.de/', 'https://guide.michelin.com/en/hotels-stays/oberstdorf/exquisit-9633'),
    ('hotel_224', 'Hotel Breitenburg', '+49 4828 78430', 'https://hotel-breitenburg.de/', 'https://guide.michelin.com/en/hotels-stays/Breitenburg/hotel-breitenburg-12398'),
    ('hotel_225', 'Maximilian', '+49 8822 948740', 'https://www.maximilian-oberammergau.de/', 'https://guide.michelin.com/en/hotels-stays/oberammergau/maximilian-10149'),
    ('hotel_226', 'JW Marriott Hotel Frankfurt', '+49 69 2972370', 'https://www.marriott.com/en-us/hotels/frajw-jw-marriott-hotel-frankfurt/overview/', 'https://guide.michelin.com/en/hotels-stays/frankfurt/jumeirah-frankfurt-6742'),
    ('hotel_227', 'Lieser Castle, Autograph Collection', '+49 6531 986990', 'https://www.schlosslieser.de/', 'https://guide.michelin.com/en/hotels-stays/lieser-1/lieser-castle-autograph-collection-13905'),
    ('hotel_228', 'Das Graseck Mountain Hideaway & Healthcare', '+49 8821 943240', 'https://www.das-graseck.de/', 'https://guide.michelin.com/en/hotels-stays/garmisch-partenkirchen/das-graseck-12287'),
    ('hotel_229', 'Boutiquehotel Blaue Burg Falkenstein', '+49 8363 914540', 'https://www.blaueburg.com/', 'https://guide.michelin.com/en/hotels-stays/pfronten/das-burghotel-falkenstein-9542'),
    ('hotel_23', 'Hotel Bareiss', '+49 7442 470', null, 'https://guide.michelin.com/en/hotels-stays/baiersbronn/hotel-bareiss-13547'),
    ('hotel_230', 'Staudacherhof', '+49 8821 9290', 'https://staudacherhof.de/', 'https://guide.michelin.com/en/hotels-stays/garmisch-partenkirchen/staudacherhof-8778'),
    ('hotel_231', 'Kulturhof Stanggass', '+49 8652 95850', 'https://www.kulturhof.bayern/', 'https://guide.michelin.com/en/hotels-stays/berchtesgaden/kulturhof-stanggass-13014'),
    ('hotel_232', 'Haubers Naturresort', '+49 8386 93305', 'https://www.haubers.de/', 'https://guide.michelin.com/en/hotels-stays/oberstaufen/haubers-naturresort-9987'),
    ('hotel_233', 'Das Rübezahl', '+49 8362 8888', 'https://www.hotelruebezahl.de/', 'https://guide.michelin.com/en/hotels-stays/schwangau/das-rubezahl-9777'),
    ('hotel_234', 'Gewandhaus Dresden', '+49 351 49490', 'https://www.gewandhaus-hotel.de/', 'https://guide.michelin.com/en/hotels-stays/dresden/gewandhaus-dresden-10221'),
    ('hotel_235', 'Landhaus Severin*s Morsum Kliff', '+49 4651 4606880', 'https://www.landhaus-severins.de/', 'https://guide.michelin.com/en/hotels-stays/sylt/landhaus-severins-morsum-kliff-9624'),
    ('hotel_236', 'Hotel Engel Obertal - Wellness & Genuss Resort', '+49 7449 850', 'https://www.engel-obertal.de/de', 'https://guide.michelin.com/en/hotels-stays/baiersbronn/hotel-engel-obertal-wellness-genuss-resort-13901'),
    ('hotel_237', 'Koenigshof, a Luxury Collection Hotel, Munich', '+49 89 858407040', 'https://www.marriott.com/en-us/hotels/muclk-koenigshof-a-luxury-collection-hotel-munich/overview/', 'https://guide.michelin.com/en/hotels-stays/munich/koenigshof-a-luxury-collection-hotel-munich-14009'),
    ('hotel_238', 'Hotel Die Sonne Frankenberg', '+49 6451 7500', 'https://sonne-frankenberg.de/', 'https://guide.michelin.com/en/hotels-stays/frankenberg/die-sonne-frankenberg-10275'),
    ('hotel_239', 'Hotel Kronelamm im Schwarzwald', '+49 7053 92940', 'https://www.kronelamm-schwarzwald.de/', 'https://guide.michelin.com/en/hotels-stays/bad-teinach-zavelstein/hotel-kronelamm-im-schwarzwald-10653'),
    ('hotel_24', 'Hotel Traube Tonbach', '+49 7442 4920', 'https://www.traube-tonbach.de/', 'https://guide.michelin.com/en/hotels-stays/baiersbronn/hotel-traube-tonbach-8972'),
    ('hotel_240', 'Hotel Alpenkönig', '+49 8386 93450', 'https://hotel-alpenkoenig.de/', 'https://guide.michelin.com/en/hotels-stays/oberstaufen/alpenkonig-10428'),
    ('hotel_241', 'Hotel Restaurant Spa Torkel', '+49 8382 98620', 'https://www.hotel-torkel.de/', 'https://guide.michelin.com/en/hotels-stays/nonnenhorn/torkel-9885'),
    ('hotel_242', 'Roomers Berlin Steinplatz, Autograph Collection', '+49 30 5544440', 'https://www.roomers-hotels.com/berlin/', 'https://guide.michelin.com/en/hotels-stays/berlin/hotel-am-steinplatz-7589'),
    ('hotel_243', 'Heidelberg Suites', '+49 6221 655650', 'https://www.heidelbergsuites.com/', 'https://guide.michelin.com/en/hotels-stays/heidelberg/heidelberg-suites-6334'),
    ('hotel_244', 'Andaz Munich Schwabinger Tor', null, null, 'https://guide.michelin.com/en/hotels-stays/munich/andaz-munich-schwabinger-tor-11143'),
    ('hotel_245', 'BEYOND by Geisel', '+49 89 700746700', 'https://www.geisel-privathotels.de/beyond/', 'https://guide.michelin.com/en/hotels-stays/munich/beyond-by-geisel-10259'),
    ('hotel_246', 'Werdenfelserei', '+49 8821 6869390', 'https://www.werdenfelserei.de/', 'https://guide.michelin.com/en/hotels-stays/garmisch-partenkirchen/werdenfelserei-10421'),
    ('hotel_247', 'Tortue Hamburg', '+49 40 33441400', 'https://tortue.de/', 'https://guide.michelin.com/en/hotels-stays/hamburg/tortue-10548'),
    ('hotel_248', 'Spa & Resort Bachmair Weissach', '+49 8022 2780', 'https://bachmair-weissach.com/', 'https://guide.michelin.com/en/hotels-stays/rottach-egern/hotel-bachmair-weissach-8250'),
    ('hotel_249', 'Hotel / Weingut Meintzinger', '+49 9331 87110', 'https://weingut-meintzinger.de/', 'https://guide.michelin.com/en/hotels-stays/Frickenhausen/hotel-weingut-meintzinger-12725'),
    ('hotel_25', 'Schloss Elmau Luxury Spa Retreat & Cultural Hideaway', '+49 8823 180', null, 'https://guide.michelin.com/en/hotels-stays/elmau/schloss-elmau-luxury-spa-retreat-cultural-hideaway-7287'),
    ('hotel_250', 'Widmann''s Löwen', '+49 7328 96270', 'https://www.widmanns-albleben.de/', 'https://guide.michelin.com/en/hotels-stays/konigsbronn/widmanns-lowen-10072'),
    ('hotel_251', 'Hotel Dollenberg', '+49 7806 780', 'https://www.dollenberg.de/', 'https://guide.michelin.com/en/hotels-stays/bad-peterstal-griesbach/dollenberg-9697'),
    ('hotel_252', 'Hotel PURS', '+49 2632 9586750', 'https://purs.com/', 'https://guide.michelin.com/en/hotels-stays/andernach/purs-10038'),
    ('hotel_253', 'Hotel Villa Sorgenfrei & Restaurant Atelier Sanssouci', '+49 351 7956660', 'https://www.hotel-villa-sorgenfrei.de/', 'https://guide.michelin.com/en/hotels-stays/dresden/villa-sorgenfrei-9948'),
    ('hotel_254', 'Hotel Europäischer Hof Heidelberg', '+49 6221 5150', 'https://www.europaeischerhof.com/', 'https://guide.michelin.com/en/hotels-stays/heidelberg/der-europaische-hof-heidelberg-9816'),
    ('hotel_255', 'Hotel Rebstock Durbach', '+49 781 4820', 'https://www.rebstock-durbach.de/', 'https://guide.michelin.com/en/hotels-stays/durbach/rebstock-9681'),
    ('hotel_256', 'The Ritz-Carlton Wolfsburg', '+49 5361 607000', 'https://www.ritzcarlton.com/en/hotels/wfgrz-the-ritz-carlton-wolfsburg/overview/', 'https://guide.michelin.com/en/hotels-stays/wolfsburg/the-ritz-carlton-wolfsburg-8297'),
    ('hotel_257', 'Hotel Heinzler am See', '+49 7545 93190', 'https://www.heinzleramsee.de/', 'https://guide.michelin.com/en/hotels-stays/immenstaad-am-bodensee/heinzler-10127'),
    ('hotel_26', 'Hotel Vier Jahreszeiten', '+49 40 34940', 'https://hvj.de/en/', 'https://guide.michelin.com/en/hotels-stays/hamburg/fairmont-hotel-vier-jahreszeiten-12464'),
    ('hotel_27', 'The Fontenay', '+49 40 60566050', null, null),
    ('hotel_28', 'Althoff Seehotel Überfahrt', '+49 8022 6690', 'https://www.althoffcollection.com/de/althoff-seehotel-ueberfahrt', 'https://guide.michelin.com/en/hotels-stays/rottach-egern/althoff-seehotel-uberfahrt-6183'),
    ('hotel_88', 'Villa Contessa', '+49 33631 58018', 'https://www.villa-contessa.de/', 'https://guide.michelin.com/en/hotels-stays/bad-saarow/villa-contessa-13900'),
    ('hotel_89', 'Kempinski Hotel Berchtesgaden', '+49 8652 97550', 'https://www.kempinski.com/de/kempinski-hotel-berchtesgaden', 'https://guide.michelin.com/en/hotels-stays/berchtesgaden/kempinski-hotel-berchtesgaden-9705'),
    ('hotel_90', 'Hotel de Rome', null, null, 'https://guide.michelin.com/en/hotels-stays/berlin/hotel-de-rome-6335'),
    ('hotel_91', 'Patrick Hellmann Schlosshotel', '+49 30 895840', 'https://www.schlosshotelberlin.com/', 'https://guide.michelin.com/en/hotels-stays/berlin/patrick-hellmann-schlosshotel-4892'),
    ('hotel_92', 'Telegraphenamt', '+49 30 9940590', 'https://www.telegraphenamt.com/', 'https://guide.michelin.com/en/hotels-stays/berlin/telegraphenamt-13032'),
    ('hotel_93', 'The Ritz-Carlton, Berlin', '+49 30 337777', 'https://www.ritzcarlton.com/en/hotels/berzt-the-ritz-carlton-berlin/overview/', 'https://guide.michelin.com/en/hotels-stays/berlin/the-ritz-carlton-berlin-9027'),
    ('hotel_94', 'Spa & Golf Hotel Weimarer Land', '+49 36459 61640', 'https://www.golfresort-weimarerland.de/', 'https://guide.michelin.com/en/hotels-stays/blankenhain/spa-golf-hotel-weimarer-land-10109'),
    ('hotel_95', 'Hotel Ketschauer Hof', '+49 6326 70000', 'https://www.ketschauer-hof.com/', 'https://guide.michelin.com/en/hotels-stays/deidesheim/ketschauer-hof-9918'),
    ('hotel_96', 'Der Öschberghof', '+49 771 840', 'https://www.oeschberghof.com/', 'https://guide.michelin.com/en/hotels-stays/donaueschingen/der-oschberghof-9835'),
    ('hotel_97', 'Bülow Palais', '+49 351 80030', 'https://buelow-palais.de/', 'https://guide.michelin.com/en/hotels-stays/dresden/bulow-palais-10183'),
    ('hotel_98', 'Kempinski Hotel Taschenbergpalais', '+49 351 49120', 'https://www.kempinski.com/en/hotel-taschenbergpalais', 'https://guide.michelin.com/en/hotels-stays/dresden/hotel-taschenbergpalais-kempinski-dresden-7389'),
    ('hotel_99', 'Breidenbacher Hof Düsseldorf', '+49 211 160900', 'https://breidenbacherhof.com/', 'https://guide.michelin.com/en/hotels-stays/dusseldorf/breidenbacher-hof-dusseldorf-11443');

do $$
declare bad text; n int;
begin
  select count(*) into n from _c;
  if n <> 126 then raise exception 'expected 126 rows in _c, found %', n; end if;

  select string_agg(c.code, ', ') into bad from _c c
   where not exists (select 1 from public.hotels h
                      where h.hotel_code = c.code and h.country_code = 'DE'
                        and h.michelin_keys is not null and h.name = c.name);
  if bad is not null then raise exception 'not the expected German Key hotel: %', bad; end if;

  select string_agg(c.code, ', ') into bad from _c c join public.hotels h on h.hotel_code = c.code
   where (c.phone is not null and h.phone is not null)
      or (c.website_url is not null and h.website_url is not null)
      or (c.michelin_url is not null and h.michelin_url is not null);
  if bad is not null then raise exception 'field already set since the export (refusing to skip silently): %', bad; end if;

  select string_agg(c.code || ' -> ' || h.hotel_code, ', ') into bad from _c c
    join public.hotels h on h.michelin_url = c.michelin_url and h.hotel_code <> c.code;
  if bad is not null then raise exception 'MICHELIN URL already held by another hotel: %', bad; end if;

  update public.hotels h set michelin_url = c.michelin_url from _c c
   where h.hotel_code = c.code and h.country_code = 'DE' and c.michelin_url is not null and h.michelin_url is null;
  get diagnostics n = row_count;
  if n <> 122 then raise exception 'michelin_url: expected 122 rows, updated %', n; end if;

  update public.hotels h set website_url = c.website_url from _c c
   where h.hotel_code = c.code and h.country_code = 'DE' and c.website_url is not null and h.website_url is null;
  get diagnostics n = row_count;
  if n <> 120 then raise exception 'website_url: expected 120 rows, updated %', n; end if;

  update public.hotels h set phone = c.phone from _c c
   where h.hotel_code = c.code and h.country_code = 'DE' and c.phone is not null and h.phone is null;
  get diagnostics n = row_count;
  if n <> 123 then raise exception 'phone: expected 123 rows, updated %', n; end if;
end $$;

commit;
