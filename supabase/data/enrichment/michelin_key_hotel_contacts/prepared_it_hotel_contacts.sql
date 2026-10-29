-- PREPARED -- NOT APPLIED.
--
-- Contact fields for Italy's MICHELIN Key hotels: phone, website_url and
-- michelin_url, filled only where production has NULL. Written 2026-10-29
-- from a read-only production export of the same day (155 IT hotels with
-- michelin_keys set). Evidence per row, with source URL and how each value
-- was confirmed: it_hotels_all.csv beside this file. Report: IT_REPORT.md.
--
--   michelin_url  150 rows  the hotel's own guide.michelin.com page, matched
--                         on coordinates + postcode, never on name
--   website_url   140 rows  the hotel's own site (for a chain, the property
--                         page), confirmed by name + city + address on the site
--   phone         137 rows  the number printed on the hotel's own site
--                         (rule of 2026-10-28, see michelin_pe_2026)
--
-- Only values marked `confirmed` in the CSV are here; `unclear` and
-- `not_found` stay NULL.
--
-- Guards (one transaction; any failure rolls everything back):
--   1. every code exists as a Italian hotel with a Key and the expected name;
--   2. every field this file fills is still NULL (nothing filled since the
--      export) -- otherwise it raises instead of skipping silently;
--   3. no MICHELIN URL here is already held by another hotel row
--      (hotels_michelin_url_key is unique);
--   4. the number of rows each UPDATE touches equals the number expected.
-- Each UPDATE is also limited to `hotel_code = ... and country_code = 'IT'
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
    ('hotel_317', 'Hotel Santa Caterina', '+39 089 871012', 'https://www.hotelsantacaterina.it/', 'https://guide.michelin.com/en/hotels-stays/amalfi/hotel-santa-caterina-5501'),
    ('hotel_318', 'Il Sereno', '+39 031 5477 800', 'https://www.serenohotels.com/property/il-sereno/', 'https://guide.michelin.com/en/hotels-stays/torno-1/il-sereno-8365'),
    ('hotel_319', 'Casa Angelina', '+39 089 8131333', 'https://www.casangelina.com/', 'https://guide.michelin.com/en/hotels-stays/praiano/casa-angelina-1201'),
    ('hotel_320', 'Il San Pietro di Positano', null, null, 'https://guide.michelin.com/en/hotels-stays/positano/il-san-pietro-di-positano-7453'),
    ('hotel_321', 'Brunelleschi Hotel', '+39 055 27370', 'https://www.hotelbrunelleschi.it/', 'https://guide.michelin.com/en/hotels-stays/florence/hotel-brunelleschi-5427'),
    ('hotel_322', 'Villa Fiorella Art Hotel', '+39 081 878 9832', 'https://arthotelvillafiorella.com/', 'https://guide.michelin.com/en/hotels-stays/massa-lubrense/art-hotel-villa-fiorella-8477'),
    ('hotel_323', 'COMO Castello del Nero', '+39 055 8064701', 'https://www.comohotels.com/italy/como-castello-del-nero', 'https://guide.michelin.com/en/hotels-stays/Barberino-Tavarnelle/como-castello-del-nero-64674-7130'),
    ('hotel_324', 'Il Borro', '+39 055 977053', 'https://www.ilborro.it/', 'https://guide.michelin.com/en/hotels-stays/san-giustino-valdarno/il-borro-6248'),
    ('hotel_325', 'Hotel Vilòn', '+39 06 878187', 'https://hotelvilon.com/', 'https://guide.michelin.com/en/hotels-stays/rome/hotel-vilon-11138'),
    ('hotel_326', 'Country House Villadorata', '+39 0931 34 03 15', 'https://countryhouse.villadorata.com/', 'https://guide.michelin.com/en/hotels-stays/noto/country-house-villadorata-8021'),
    ('hotel_327', 'Grand Hotel Excelsior Vittoria', '+39 081 877 7111', 'https://excelsiorvittoria.com/', 'https://guide.michelin.com/en/hotels-stays/sorrento-2/grand-hotel-excelsior-vittoria-6718'),
    ('hotel_328', 'Aman Venice', null, null, 'https://guide.michelin.com/en/hotels-stays/venice/aman-venice-7277'),
    ('hotel_329', 'Castel Fragsburg', '+39 0473 244 071', 'https://www.fragsburg.com/', 'https://guide.michelin.com/en/hotels-stays/merano/castel-fragsburg-8195'),
    ('hotel_330', 'Byblos Art Hotel Villa Amistà', '+39 045 6855 555', 'https://www.byblosarthotel.com/', 'https://guide.michelin.com/en/hotels-stays/san-pietro-in-cariano/byblos-art-hotel-villa-amista-164'),
    ('hotel_331', 'Hotel Lungarno', null, 'https://www.lungarnocollection.com/florence/hotel-lungarno/', 'https://guide.michelin.com/en/hotels-stays/florence/hotel-lungarno-7072'),
    ('hotel_332', 'Therasia Resort Sea & Spa', '+39 090 9852555', 'https://www.therasiaresort.it/', 'https://guide.michelin.com/en/hotels-stays/vulcano/therasia-resort-8826'),
    ('hotel_333', 'Botania Relais & Spa', '+39 081 997978', 'https://www.botaniarelais.com/', 'https://guide.michelin.com/en/hotels-stays/isola-d-ischia/botania-relais-spa-8827'),
    ('hotel_334', 'Grand Hotel Principe di Piemonte', '+39 0584 4011', 'https://www.principedipiemonte.com/', 'https://guide.michelin.com/en/hotels-stays/viareggio/grand-hotel-principe-di-piemonte-6817'),
    ('hotel_335', 'La Foresteria Planeta Estate', '+39 0925 529986', 'https://www.planetaestate.it/it/la-foresteria-resort/', 'https://guide.michelin.com/en/hotels-stays/1menfi/la-foresteria-planeta-estate-9200'),
    ('hotel_336', 'Hassler Roma', '+39 06 699340', 'https://www.hotelhasslerroma.com/', 'https://guide.michelin.com/en/hotels-stays/rome/hassler-roma-13240'),
    ('hotel_337', 'Goldene Rose Karthaus', '+39 0473 67 91 30', 'https://www.goldenerose.it/', 'https://guide.michelin.com/en/hotels-stays/schnals-1/goldene-rose-karthaus-11678'),
    ('hotel_338', 'Reschio Hotel', null, null, 'https://guide.michelin.com/en/hotels-stays/lisciano-niccone/reschio-hotel-12069'),
    ('hotel_339', 'Riva Lofts Florence', '+39 055 7130272', 'https://rivalofts.com/', 'https://guide.michelin.com/en/hotels-stays/florence/riva-lofts-florence-206'),
    ('hotel_340', 'La Minervetta', '+39 081 877 4455', 'https://www.laminervetta.com/', 'https://guide.michelin.com/en/hotels-stays/sorrento-2/la-minervetta-197'),
    ('hotel_341', 'ADLER Sicilia', '+39 0922 178 8700', 'https://www.adler-resorts.com/en/adler-spa-resort-sicilia/483-0.html', 'https://guide.michelin.com/en/hotels-stays/Siculiana/adler-sicilia-15289'),
    ('hotel_342', 'Villa Sant''Andrea, A Belmond Hotel', '+39 0942 6271 200', 'https://www.belmond.com/en/hotels/europe/italy/villa-sant-andrea-taormina-mare', 'https://guide.michelin.com/en/hotels-stays/taormina/villa-santandrea-a-belmond-hotel-taormina-mare-124593-15176'),
    ('hotel_343', 'Le Sirenuse', null, 'https://sirenuse.it/en/', 'https://guide.michelin.com/en/hotels-stays/positano/le-sirenuse-6213'),
    ('hotel_344', 'Capri Palace Jumeirah', '+39 081 978 0111', 'https://www.jumeirah.com/en/stay/italy/jumeirah-capri-palace', 'https://guide.michelin.com/en/hotels-stays/capri/jumeirah-capri-palace-1463-6205'),
    ('hotel_345', 'Castello di Casole, A Belmond Hotel, Tuscany', '+39 0577 961501', 'https://www.belmond.com/en/hotels/europe/italy/castello-di-casole-tuscany', 'https://guide.michelin.com/en/hotels-stays/casole-d-Elsa/castello-di-casole-a-belmond-hotel-tuscany-6433'),
    ('hotel_346', 'Casa Maria Luigia', null, null, 'https://guide.michelin.com/en/hotels-stays/Modena/casa-maria-luigia-13611'),
    ('hotel_347', 'Grand Hotel Miramare', '+39 0185 287013', 'https://www.grandhotelmiramare.it/', 'https://guide.michelin.com/en/hotels-stays/santa-margherita-ligure/grand-hotel-miramare-6228'),
    ('hotel_348', 'Bellevue Syrene 1820', '+39 081 8781024', 'https://www.bellevue.it/', 'https://guide.michelin.com/en/hotels-stays/sorrento-2/bellevue-syrene-1820-441'),
    ('hotel_349', 'Splendido, A Belmond Hotel, Portofino', null, 'https://www.belmond.com/en/hotels/europe/italy/splendido-portofino', 'https://guide.michelin.com/en/hotels-stays/portofino/belmond-hotel-splendido-7337'),
    ('hotel_350', 'Palazzo Parigi Hotel & Grand Spa', '+39 02 625625', 'https://www.palazzoparigi.com/', 'https://guide.michelin.com/en/hotels-stays/milan/palazzo-parigi-8056'),
    ('hotel_351', 'Violino D''Oro', '+39 041 277 0841', 'https://violinodoro.com/', 'https://guide.michelin.com/en/hotels-stays/venice/violino-doro-14205'),
    ('hotel_352', 'San Luis Retreat Hotel & Lodges', '+39 0473 279570', 'https://www.sanluis-hotel.com/', 'https://guide.michelin.com/en/hotels-stays/averlengo/san-luis-retreat-hotel-lodges-15409'),
    ('hotel_353', 'Masseria Torre Coccaro', '+39 080 482 9310', 'https://masseriatorrecoccaro.com/', 'https://guide.michelin.com/en/hotels-stays/savelletri-di-fasano/masseria-torre-coccaro-158'),
    ('hotel_354', 'Londra Palace Venezia', '+39 041 5200533', 'https://www.londrapalace.com/', 'https://guide.michelin.com/en/hotels-stays/venice/londra-palace-venezia-4291'),
    ('hotel_355', 'Palazzo Margherita', '+39 0835 549060', 'https://thecoppolahideaways.com/resort/palazzo-margherita', 'https://guide.michelin.com/en/hotels-stays/Bernalda/palazzo-margherita-6923'),
    ('hotel_356', 'Hotel Locarno', '+39 06 3610841', 'https://www.hotellocarno.com/', 'https://guide.michelin.com/en/hotels-stays/rome/hotel-locarno-9355'),
    ('hotel_357', 'I Borghi dell''Eremo', '+39 075 8358400', 'https://www.borghidelleremo.it/', 'https://guide.michelin.com/en/hotels-stays/piegaro/i-borghi-delleremo-13468'),
    ('hotel_358', 'Vico Milano', '+39 02 4941 8437', 'https://www.vicomilano.com/', 'https://guide.michelin.com/en/hotels-stays/milan/vico-milano-12446'),
    ('hotel_359', 'Locanda al Colle', '+39 0584 915 195', 'https://www.locandaalcolle.com/', 'https://guide.michelin.com/en/hotels-stays/Camaiore-1/locanda-al-colle-5743'),
    ('hotel_360', 'Vocabolo Moscatelli Boutique Hotel & Restaurant', '+39 075 5455815', 'https://www.vocabolomoscatelli.com/', 'https://guide.michelin.com/en/hotels-stays/Umbertide/vocabolo-moscatelli-boutique-hotel-restaurant-13119'),
    ('hotel_361', 'Cascioni Eco Retreat', '+39 0789 387537', 'https://www.cascioni.com/', 'https://guide.michelin.com/en/hotels-stays/costa-smeralda/cascioni-eco-retreat-11994'),
    ('hotel_362', 'Grand Hotel Victoria', '+39 0344 32003', 'https://www.grandhotelvictoria.it/', 'https://guide.michelin.com/en/hotels-stays/menaggio/grand-hotel-victoria-122062-12002'),
    ('hotel_363', 'Monastero Santa Rosa', '+39 089 832 1199', 'https://monasterosantarosa.com/', 'https://guide.michelin.com/en/hotels-stays/conca-dei-marini/monastero-santa-rosa-9680'),
    ('hotel_364', 'Mediterraneo Sorrento', '+39 081 8781352', 'https://www.mediterraneosorrento.com/', 'https://guide.michelin.com/en/hotels-stays/sorrento-2/mediterraneo-sorrento-13496'),
    ('hotel_365', 'Villa Fontelunga', '+39 0575 660410', 'https://www.fontelunga.com/', 'https://guide.michelin.com/en/hotels-stays/foiano-%20della-chiana/villa-fontelunga-84'),
    ('hotel_366', 'Nordelaia', '+39 0143 038045', 'https://nordelaia.com/', 'https://guide.michelin.com/en/hotels-stays/cremolino/nordelaia-12646'),
    ('hotel_367', 'Palazzo Daniele', '+39 0833 533185', 'https://www.palazzodaniele.com/', 'https://guide.michelin.com/en/hotels-stays/gagliano-del-capo/palazzo-daniele-9160'),
    ('hotel_368', 'Six Senses Rome', '+39 06 8681 4000', 'https://www.sixsenses.com/en/hotels-resorts/europe/italy/rome/', 'https://guide.michelin.com/en/hotels-stays/rome/six-senses-rome-12916'),
    ('hotel_369', 'Villa Cora', '+39 055 22 87 90', 'https://www.villacora.it/', 'https://guide.michelin.com/en/hotels-stays/florence/villa-cora-79'),
    ('hotel_370', 'J.K. Place Capri', '+39 081 83 84 001', 'https://www.jkplaces.com/jkcapri/', 'https://guide.michelin.com/en/hotels-stays/capri/jk-place-capri-2071'),
    ('hotel_371', 'Monaci delle Terre Nere', '+39 095 708 3638', 'https://monacidelleterrenere.it/', 'https://guide.michelin.com/en/hotels-stays/zafferana-etnea/monaci-delle-terre-nere-6782'),
    ('hotel_372', 'Velona''s Jungle Luxury Suites', '+39 055 27 41 536', 'https://www.velonasjungle.com/', 'https://guide.michelin.com/en/hotels-stays/florence/velonas-jungle-luxury-suites-8551'),
    ('hotel_373', 'Precise Tale Poggio Alla Sala', '+39 0578 820050', 'https://www.precisehotels.com/en/poggio-alla-sala', 'https://guide.michelin.com/en/hotels-stays/montepulciano/precise-tale-poggio-alla-sala-13465'),
    ('hotel_374', 'J.K. Place Roma', '+39 06 982 634', 'https://www.jkplaces.com/jkroma/', 'https://guide.michelin.com/en/hotels-stays/rome/jk-place-roma-7112'),
    ('hotel_375', 'Castelfalfi', '+39 0571 892000', 'https://www.castelfalfi.com/', 'https://guide.michelin.com/en/hotels-stays/montaione/castelfalfi-8779'),
    ('hotel_376', 'Canne Bianche Lifestyle Hotel', '+39 080 4829839', 'https://www.cannebianche.com/', 'https://guide.michelin.com/en/hotels-stays/torre-canne-di-fasano/canne-bianche-lifestyle-hotel-8117'),
    ('hotel_377', 'Susafa', '+39 091 7487477', 'https://www.susafa.com/', 'https://guide.michelin.com/en/hotels-stays/polizzi-generosa/susafa-7958'),
    ('hotel_378', 'Il Palazzo Experimental', '+39 041 098 0200', 'https://www.experimentalgroup.com/venice/il-palazzo-experimental', 'https://guide.michelin.com/en/hotels-stays/venice/il-palazzo-experimental-9199'),
    ('hotel_379', 'Hotel Metropole Venice', '+39 041 5205044', 'https://www.hotelmetropole.com/', 'https://guide.michelin.com/en/hotels-stays/venice/hotel-metropole-venice-5972'),
    ('hotel_380', 'Corte della Maestà', '+39 335 879 3077', 'https://www.cortedellamaesta.com/', 'https://guide.michelin.com/en/hotels-stays/civita-di-bagnoregio/corte-della-maesta-8446'),
    ('hotel_381', 'Sextantio Le Grotte della Civita', '+39 0835 332744', 'https://www.sextantio.it/legrottedellacivita/matera/', 'https://guide.michelin.com/en/hotels-stays/matera/sextantio-le-grotte-della-civita-3251'),
    ('hotel_382', 'Palazzo Albricci Peregrini', '+39 331 23 05 764', 'https://www.palazzoalbricciperegrini.it/', 'https://guide.michelin.com/en/hotels-stays/como/palazzo-albriccci-peregrini-9019'),
    ('hotel_383', 'Grand Hotel Minerva', '+39 055 27230', 'https://grandhotelminerva.com/', 'https://guide.michelin.com/en/hotels-stays/florence/grand-hotel-minerva-8879'),
    ('hotel_384', 'Castel Monastero', '+39 0577 570570', 'https://www.castelmonastero.com/', 'https://guide.michelin.com/en/hotels-stays/Castelnuovo-Berardenga/castel-monastero-5253'),
    ('hotel_385', 'Castello di Vicarello', '+39 0564 990718', 'https://www.castellodivicarello.com/', 'https://guide.michelin.com/en/hotels-stays/cinigiano/castello-di-vicarello-216'),
    ('hotel_386', 'Sextantio', '+39 0862 899112', 'https://www.sextantio.it/santostefano/abruzzo/', 'https://guide.michelin.com/en/hotels-stays/santo-stefano-di-sessanio/sextantio-442'),
    ('hotel_387', 'Locanda Rossa', '+39 0564 890462', 'https://locandarossa.com/', 'https://guide.michelin.com/en/hotels-stays/capalbio/locanda-rossa-5387'),
    ('hotel_388', 'Villa le Prata - Residenza del Vescovo', '+39 0577 847130', 'https://villaleprata.com/', 'https://guide.michelin.com/en/hotels-stays/montalcino/villa-le-prata-residenza-del-vescovo-12200'),
    ('hotel_389', 'Aethos Monterosa', '+39 0125 938300', 'https://www.aethos.com/destinations/monterosa', 'https://guide.michelin.com/en/hotels-stays/champoluc/aethos-monterosa-9146'),
    ('hotel_390', 'Nolinski Venezia - Evok Collection', '+39 041 406 2459', 'https://www.evokcollection.com/nolinski-venezia/', 'https://guide.michelin.com/en/hotels-stays/venice/nolinski-venezia-122640-12796'),
    ('hotel_391', 'Palazzo Talia', '+39 06 692521', 'https://www.palazzotalia.com/', 'https://guide.michelin.com/en/hotels-stays/rome/palazzo-talia-14584'),
    ('hotel_392', 'Villa Eden The Private Retreat', '+39 0473 236583', 'https://www.villa-eden.com/', 'https://guide.michelin.com/en/hotels-stays/merano/villa-eden-the-longeviti-retreat-11064'),
    ('hotel_393', 'Monastero di Cortona', '+39 0575 1785839', 'https://www.monasterodicortona.com/', 'https://guide.michelin.com/en/hotels-stays/cortona/monastero-di-cortona-13669'),
    ('hotel_394', 'La Monastica Resort & Spa', '+39 0572 30585', 'https://lamonastica.com/', 'https://guide.michelin.com/en/hotels-stays/buggiano-castello/la-monastica-resort-spa-14165'),
    ('hotel_395', 'Monteverdi Tuscany', '+39 0578 268 146', 'https://monteverdituscany.com/', 'https://guide.michelin.com/en/hotels-stays/castiglioncello-del-trinoro/monteverdi-tuscany-123854-14194'),
    ('hotel_396', 'Vista Verona', '+39 045 1117 0880', 'https://www.vistapalazzo.com/verona/vista-verona/', 'https://guide.michelin.com/en/hotels-stays/verona/vista-verona-122675-12594'),
    ('hotel_397', 'Palazzo Ripetta', '+39 06 3231144', 'https://www.palazzoripetta.com/', 'https://guide.michelin.com/en/hotels-stays/rome/palazzo-ripetta-14263'),
    ('hotel_398', 'ADLER Lodge RITTEN', '+39 0471 1551 700', 'https://www.adler-resorts.com/en/lodge-hotel-renon-italy/73-0.html', 'https://guide.michelin.com/en/hotels-stays/soprabolzano1/adler-lodge-ritten-13915'),
    ('hotel_399', 'LA ROQQA', '+39 0564 195 0290', 'https://www.laroqqa.com/', 'https://guide.michelin.com/en/hotels-stays/porto-ercole/la-roqqa-15292'),
    ('hotel_400', 'Villa Petriolo', '+39 0571 1771225', 'https://www.villapetriolotuscany.com/', 'https://guide.michelin.com/en/hotels-stays/Cerreto%20Guidi/villa-petriolo-15287'),
    ('hotel_401', 'Portrait Milano', null, 'https://www.lungarnocollection.com/milan/portrait-milano/', 'https://guide.michelin.com/en/hotels-stays/milan/portrait-milano-12981'),
    ('hotel_402', 'Hotel Miramalfi', '+39 089 871588', 'https://www.miramalfi.com/', 'https://guide.michelin.com/en/hotels-stays/amalfi/hotel-miramalfi-13667'),
    ('hotel_403', 'COMO Alpina Dolomites', '+39 0471 796 004', 'https://www.comohotels.com/italy/como-alpina-dolomites', 'https://guide.michelin.com/en/hotels-stays/alpe-di-siusi/alpina-dolomites-10766'),
    ('hotel_404', 'Aman Rosa Alpina', '+39 0471 849 500', 'https://www.aman.com/resorts/aman-rosa-alpina', 'https://guide.michelin.com/en/hotels-stays/san-cassiano/rosa-alpina-5857'),
    ('hotel_405', 'La Fiermontina Palazzo Bozzi Corso', '+39 0832 1560335', 'https://www.lafiermontinacollection.com/en/palazzo-bozzi-corso/index', 'https://guide.michelin.com/en/hotels-stays/lecce/la-fiermontina-palazzo-bozzi-corso-13345'),
    ('hotel_406', 'Casa Cipriani Milano', '+39 02 2506 4088', 'https://www.casaciprianimilano.com/', 'https://guide.michelin.com/en/hotels-stays/milan/casa-cipriani-milano-13289'),
    ('hotel_407', 'Palazzo Petrvs', '+39 0763 967230', 'https://palazzopetrvs.com/', 'https://guide.michelin.com/en/hotels-stays/orvieto/palazzo-petrvs-14609'),
    ('hotel_408', 'Casa Newton', '+39 0578 810043', 'https://www.casa-newton.com/', 'https://guide.michelin.com/en/hotels-stays/pienza/casa-newton-14794'),
    ('hotel_409', 'La Palma Capri, an Oetker Collection Hotel', null, null, 'https://guide.michelin.com/en/hotels-stays/capri/la-palma-capri-an-oetker-collection-hotel-13850'),
    ('hotel_410', 'Collegio alla Querce, Auberge Collection', '+39 055 404 9000', 'https://auberge.com/collegio-alla-querce/', 'https://guide.michelin.com/en/hotels-stays/florence/collegio-alla-querce-auberge-collection-14427'),
    ('hotel_411', 'Villa Corallo', '+39 0861 887002', 'https://villacorallo.it/site/', 'https://guide.michelin.com/en/hotels-stays/sant-omero/villa-corallo-14215'),
    ('hotel_412', 'Wine Relais Feudi del Pisciotto', '+39 0933 19 35 186', 'https://www.feudidelpisciotto.it/', 'https://guide.michelin.com/en/hotels-stays/Niscemi/wine-relais-feudi-del-pisciotto-15291'),
    ('hotel_413', 'Donna Coraly Country Boutique Hotel', '+39 0931 17 99 925', 'https://www.donnacoraly.it/', 'https://guide.michelin.com/en/hotels-stays/syracuse/donna-coraly-country-boutique-hotel-9860'),
    ('hotel_414', 'Villa La Massa', '+39 055 626 11', 'https://www.villalamassa.com/', 'https://guide.michelin.com/en/hotels-stays/florence/villa-la-massa-6576'),
    ('hotel_415', 'Corte di Gabriela', '+39 041 5235077', 'https://www.cortedigabriela.com/', 'https://guide.michelin.com/en/hotels-stays/venice/corte-di-gabriela-6834'),
    ('hotel_416', 'Borgo dei Conti Resort', '+39 075 600 338', 'https://www.borgodeicontiresort.com/', 'https://guide.michelin.com/en/hotels-stays/boschetto-vecchio/borgo-dei-conti-resort-7114'),
    ('hotel_417', 'Lido Palace', '+39 0464 021899', 'https://www.lido-palace.it/', 'https://guide.michelin.com/en/hotels-stays/riva-del-garda/lido-palace-7990'),
    ('hotel_418', 'Palazzo Pascal', '+39 089 858312', 'https://www.palazzopascal.com/', 'https://guide.michelin.com/en/hotels-stays/Scala/palazzo-pascal-12185'),
    ('hotel_419', 'Vivere Suites and Rooms', '+39 0464 514786', 'https://www.agrivivere.com/', 'https://guide.michelin.com/en/hotels-stays/arco-lake-garda/vivere-suites-and-rooms-5275'),
    ('hotel_420', 'Lagació Hotel Mountain Residence', '+39 0471 849 503', 'https://www.lagacio.com/', 'https://guide.michelin.com/en/hotels-stays/san-cassiano/lagacio-hotel-mountain-residence-4341'),
    ('hotel_421', 'Casa Clàt', '+39 070 705 0292', 'https://www.casaclat.it/', 'https://guide.michelin.com/en/hotels-stays/cagliari/casa-clat-13425'),
    ('hotel_422', 'Lake Spa Hotel SEELEITEN', '+39 0471 960200', 'https://www.seeleiten.it/', 'https://guide.michelin.com/en/hotels-stays/kaltern/lake-spa-hotel-seeleiten-13154'),
    ('hotel_423', 'La Fiermontina Luxury Home', '+39 0832 302481', 'https://www.lafiermontina.com/', 'https://guide.michelin.com/en/hotels-stays/lecce/la-fiermontina-luxury-home-10935'),
    ('hotel_424', 'Stella d''Italia', '+39 055 010 6659', 'https://stelladitaliaflorence.com/', 'https://guide.michelin.com/en/hotels-stays/florence/stella-ditalia-14322'),
    ('hotel_425', 'Conti di San Bonifacio', '+39 0566 80006', 'https://contidisanbonifacio.com/', 'https://guide.michelin.com/en/hotels-stays/Gavorrano-1/conti-di-san-bonifacio-7060'),
    ('hotel_426', 'Portrait Roma', '+39 06 6938 0742', 'https://www.lungarnocollection.com/rome/portrait-roma/', 'https://guide.michelin.com/en/hotels-stays/rome/portrait-roma-6216'),
    ('hotel_427', 'Masseria Calderisi', '+39 080 433 4340', 'https://www.masseriacalderisi.com/', 'https://guide.michelin.com/en/hotels-stays/savelletri-di-fasano/masseria-calderisi-11915'),
    ('hotel_428', 'Ottolire Resort', '+39 080 443 4370', 'https://ottolireresort.it/', 'https://guide.michelin.com/en/hotels-stays/Locorotondo/ottolire-resort-9432'),
    ('hotel_429', 'Lefay Resort & Spa Lago di Garda', '+39 0365 241800', 'https://lagodigarda.lefayresorts.com/', 'https://guide.michelin.com/en/hotels-stays/gargnano/lefay-resort-spa-lago-di-garda-5131'),
    ('hotel_430', 'Critabianca', '+39 331 766 8648', 'https://www.critabianca.it/', 'https://guide.michelin.com/en/hotels-stays/cutrofiano/critabianca-11885'),
    ('hotel_431', 'Masseria della Volpe', '+39 0931 856055', 'https://www.masseriadellavolpe.it/', 'https://guide.michelin.com/en/hotels-stays/noto/masseria-della-volpe-7995'),
    ('hotel_432', 'Singer Palace Hotel Roma', '+39 06 697 6161', 'https://singerpalacehotel.com/', 'https://guide.michelin.com/en/hotels-stays/rome/singer-palace-hotel-roma-8957'),
    ('hotel_433', 'Seven Rooms Villadorata', '+39 0931 835575', 'https://sevenrooms.villadorata.com/', 'https://guide.michelin.com/en/hotels-stays/noto/seven-rooms-villadorata-8020'),
    ('hotel_434', 'Lefay Resort & Spa Dolomiti', '+39 0465 768800', 'https://dolomiti.lefayresorts.com/', 'https://guide.michelin.com/en/hotels-stays/pinzolo/lefay-resort-spa-dolomiti-11169'),
    ('hotel_435', 'Siena House', '+39 349 413 8388', 'https://www.sienahouse.net/', 'https://guide.michelin.com/en/hotels-stays/torrita-di-siena/siena-house-7129'),
    ('hotel_436', 'Lùme', '+39 328 033 0316', 'https://lume-ortigia.com/', 'https://guide.michelin.com/en/hotels-stays/syracuse/lume-13038'),
    ('hotel_437', 'Hotel Signum', '+39 090 984 42 22', 'https://www.hotelsignum.it/', 'https://guide.michelin.com/en/hotels-stays/salina/hotel-signum-1101'),
    ('hotel_438', 'Grand Hotel et de Milan', '+39 02 723141', 'https://www.grandhoteletdemilan.it/', 'https://guide.michelin.com/en/hotels-stays/milan/grand-hotel-et-de-milan-5467'),
    ('hotel_439', 'Principe Forte dei Marmi', '+39 0584 783636', 'https://www.principefortedeimarmi.com/', 'https://guide.michelin.com/en/hotels-stays/forte-dei-marmi/principe-forte-dei-marmi-6768'),
    ('hotel_440', 'Villa Crespi', '+39 0322 911902', 'https://villacrespi.it/', 'https://guide.michelin.com/en/hotels-stays/orta-san-giulio1/villa-crespi-5809'),
    ('hotel_441', 'La Barchessa di Villa Pisani', '+39 0444 83 12 07', 'https://www.labarchessadivillapisani.it/', 'https://guide.michelin.com/en/hotels-stays/bagnolo-di-lonigo/la-barchessa-di-villa-pisani-8793'),
    ('hotel_442', 'Bellevue Hotel & Spa', '+39 0165 74825', 'https://www.hotelbellevue.it/', 'https://guide.michelin.com/en/hotels-stays/cogne/bellevue-hotel-spa-8179'),
    ('hotel_443', 'Paragon 700 Boutique Hotel & SPA', '+39 0831 36 92 19', 'https://paragon700.com/', 'https://guide.michelin.com/en/hotels-stays/ostuni/paragon-700-boutique-hotel-spa-12280'),
    ('hotel_444', 'Gardena Grödnerhof Hotel & Spa', '+39 0471 796315', 'https://www.gardena.it/', 'https://guide.michelin.com/en/hotels-stays/ortisei-1/gardena-grodnerhof-hotel-spa-13142'),
    ('hotel_445', 'Splendido Mare, A Belmond Hotel, Portofino', '+39 0185 267802', 'https://www.belmond.com/en/hotels/europe/italy/splendido-mare-portofino', 'https://guide.michelin.com/en/hotels-stays/portofino/splendido-mare-a-belmond-hotel-portofino-14249'),
    ('hotel_446', 'The Place Firenze', '+39 055 26 45 181', 'https://www.theplacefirenze.com/', 'https://guide.michelin.com/en/hotels-stays/florence/the-place-firenze-2021'),
    ('hotel_447', 'Grand Hotel Tremezzo', '+39 0344 42491', 'https://www.grandhoteltremezzo.com/', 'https://guide.michelin.com/en/hotels-stays/tremezzina/grand-hotel-tremezzo-5411'),
    ('hotel_448', 'Villa d''Este', '+39 031 3481', 'https://www.villadeste.com/', 'https://guide.michelin.com/en/hotels-stays/cernobbio/villa-deste-7331'),
    ('hotel_449', 'Lupaia', '+39 0577 1917066', 'https://www.lupaia.com/', 'https://guide.michelin.com/en/hotels-stays/torrita-di-siena/lupaia-8678'),
    ('hotel_450', 'L''Andana', '+39 0564 944800', 'https://www.andana.it/', 'https://guide.michelin.com/en/hotels-stays/castiglione-della-pescaia/landana-2751'),
    ('hotel_451', 'Hotel Capo La Gala', '+39 081 801 5758', 'https://www.hotelcapolagala.com/', 'https://guide.michelin.com/en/hotels-stays/vico-equense/hotel-capo-la-gala-5863'),
    ('hotel_452', 'Borgo Egnazia', null, 'https://www.borgoegnazia.com/', 'https://guide.michelin.com/en/hotels-stays/savelletri-di-fasano/borgo-egnazia-5839'),
    ('hotel_453', 'Borgo San Felice Resort', '+39 0577 3964', 'https://www.borgosanfelice.com/', 'https://guide.michelin.com/en/hotels-stays/Castelnuovo-Berardenga/borgo-san-felice-resort-7244'),
    ('hotel_454', 'Capri Tiberio Palace', '+39 081 97 87 111', 'https://www.capritiberiopalace.it/', 'https://guide.michelin.com/en/hotels-stays/capri/capri-tiberio-palace-6877'),
    ('hotel_455', 'Borgo Santo Pietro', '+39 0577 75 1222', null, 'https://guide.michelin.com/en/hotels-stays/chiusdino/borgo-santo-pietro-7004'),
    ('hotel_456', 'Castello Banfi - Il Borgo', '+39 0577 877700', 'https://www.banfi.it/hotel-il-borgo/', 'https://guide.michelin.com/en/hotels-stays/montalcino/castello-banfi-il-borgo-116850-6678'),
    ('hotel_457', 'Relais Blu', '+39 081 878 9552', 'https://www.relaisblu.com/', 'https://guide.michelin.com/en/hotels-stays/massa-lubrense/relais-blu-6648'),
    ('hotel_458', 'Palazzo Avino', null, 'https://www.palazzoavino.com/', 'https://guide.michelin.com/en/hotels-stays/ravello/palazzo-avino-7367'),
    ('hotel_459', 'The First Arte, Rome', '+39 06 45617070', 'https://www.pavilionshotels.com/destinations/italy/thefirstarte/', 'https://guide.michelin.com/en/hotels-stays/rome/the-first-luxury-art-hotel-rome-6540'),
    ('hotel_460', 'Terra - The Magic Place', '+39 0471 62 30 55', 'https://www.terra.place/', 'https://guide.michelin.com/en/hotels-stays/Sarentino/terra-the-magic-place-9303'),
    ('hotel_689', 'Borgo Santandrea', null, null, 'https://guide.michelin.com/en/hotels-stays/amalfi/borgo-santandrea-12461'),
    ('hotel_690', 'Bulgari Roma', '+39 06 3608 0400', null, 'https://guide.michelin.com/en/hotels-stays/rome/bulgari-hotel-roma-13135'),
    ('hotel_691', 'Four Seasons Firenze', '+39 055 26261', 'https://www.fourseasons.com/florence/', 'https://guide.michelin.com/en/hotels-stays/florence/four-seasons-hotel-firenze-7654'),
    ('hotel_693', 'Hotel Cipriani', null, 'https://www.belmond.com/en/hotels/europe/italy/hotel-cipriani-venice', 'https://guide.michelin.com/en/hotels-stays/venice/cipriani-a-belmond-hotel-venice-7365'),
    ('hotel_694', 'Hotel Il Pellicano', '+39 0564 858111', null, 'https://guide.michelin.com/en/hotels-stays/porto-ercole/il-pellicano-7456'),
    ('hotel_696', 'Passalacqua', '+39 031 44311', null, 'https://guide.michelin.com/en/hotels-stays/moltrasio/passalacqua-13418');

do $$
declare bad text; n int;
begin
  select count(*) into n from _c;
  if n <> 150 then raise exception 'expected 150 rows in _c, found %', n; end if;

  select string_agg(c.code, ', ') into bad from _c c
   where not exists (select 1 from public.hotels h
                      where h.hotel_code = c.code and h.country_code = 'IT'
                        and h.michelin_keys is not null and h.name = c.name);
  if bad is not null then raise exception 'not the expected Italian Key hotel: %', bad; end if;

  select string_agg(c.code, ', ') into bad from _c c join public.hotels h on h.hotel_code = c.code
   where (c.phone is not null and h.phone is not null)
      or (c.website_url is not null and h.website_url is not null)
      or (c.michelin_url is not null and h.michelin_url is not null);
  if bad is not null then raise exception 'field already set since the export (refusing to skip silently): %', bad; end if;

  select string_agg(c.code || ' -> ' || h.hotel_code, ', ') into bad from _c c
    join public.hotels h on h.michelin_url = c.michelin_url and h.hotel_code <> c.code;
  if bad is not null then raise exception 'MICHELIN URL already held by another hotel: %', bad; end if;

  update public.hotels h set michelin_url = c.michelin_url from _c c
   where h.hotel_code = c.code and h.country_code = 'IT' and c.michelin_url is not null and h.michelin_url is null;
  get diagnostics n = row_count;
  if n <> 150 then raise exception 'michelin_url: expected 150 rows, updated %', n; end if;

  update public.hotels h set website_url = c.website_url from _c c
   where h.hotel_code = c.code and h.country_code = 'IT' and c.website_url is not null and h.website_url is null;
  get diagnostics n = row_count;
  if n <> 140 then raise exception 'website_url: expected 140 rows, updated %', n; end if;

  update public.hotels h set phone = c.phone from _c c
   where h.hotel_code = c.code and h.country_code = 'IT' and c.phone is not null and h.phone is null;
  get diagnostics n = row_count;
  if n <> 137 then raise exception 'phone: expected 137 rows, updated %', n; end if;
end $$;

commit;
