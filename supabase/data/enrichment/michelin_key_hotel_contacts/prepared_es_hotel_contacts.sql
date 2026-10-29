-- PREPARED -- NOT APPLIED.
--
-- Contact fields for Spain's MICHELIN Key hotels: phone, website_url and
-- michelin_url, filled only where production has NULL. Written 2026-10-29
-- from a read-only production export of the same day (109 ES hotels with
-- michelin_keys set). Evidence per row, with source URL and how each value
-- was confirmed: es_hotels_all.csv beside this file. Report: ES_REPORT.md.
--
--   michelin_url  109 rows  the hotel's own guide.michelin.com page, matched
--                         on coordinates + postcode, never on name
--   website_url   107 rows  the hotel's own site (for a chain, the property
--                         page), confirmed by name + city + address on the site
--   phone         104 rows  the number printed on the hotel's own site
--                         (rule of 2026-10-28, see michelin_pe_2026)
--
-- Only values marked `confirmed` in the CSV are here; `unclear` and
-- `not_found` stay NULL.
--
-- Guards (one transaction; any failure rolls everything back):
--   1. every code exists as a Spanish hotel with a Key and the expected name;
--   2. every field this file fills is still NULL (nothing filled since the
--      export) -- otherwise it raises instead of skipping silently;
--   3. no MICHELIN URL here is already held by another hotel row
--      (hotels_michelin_url_key is unique);
--   4. the number of rows each UPDATE touches equals the number expected.
-- Each UPDATE is also limited to `hotel_code = ... and country_code = 'ES'
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
    ('hotel_461', 'Son Bunyola Hotel & Villas', '+34 871 62 06 02', 'https://www.virginlimitededition.com/son-bunyola/', 'https://guide.michelin.com/en/hotels-stays/majorca/son-bunyola-hotel-villas-15063'),
    ('hotel_462', 'Faustino Gran', '+34 971 489 191', 'https://faustinogran.com/', 'https://guide.michelin.com/en/hotels-stays/minorca/faustino-gran-relais-chateaux-7714'),
    ('hotel_463', 'Only YOU Hotel Atocha', '+34 914 09 78 76', 'https://www.onlyyouhotels.com/en/hotels/only-you-hotel-atocha/', 'https://guide.michelin.com/en/hotels-stays/madrid/only-you-hotel-atocha-8400'),
    ('hotel_464', 'The Palace, A Luxury Collection Hotel, Madrid', '+34 913 60 80 00', 'https://www.marriott.com/en-us/hotels/madcl-the-palace-a-luxury-collection-hotel-madrid/overview/', 'https://guide.michelin.com/en/hotels-stays/madrid/the-westin-palace-madrid-9482'),
    ('hotel_465', 'Nobis Hotel Palma', '+34 871 555 800', 'https://www.nobishotel.es/', 'https://guide.michelin.com/en/hotels-stays/majorca/nobis-hotel-palma-13514'),
    ('hotel_466', 'Castillo Hotel Son Vida, a Luxury Collection Hotel', '+34 971 49 34 93', 'https://www.marriott.com/en-us/hotels/pmilc-castillo-hotel-son-vida-a-luxury-collection-hotel-mallorca/overview/', 'https://guide.michelin.com/en/hotels-stays/majorca/castillo-h-son-vida-9796'),
    ('hotel_467', 'Room Mate Helen Berger', '+34 960 47 91 36', 'https://room-matehotels.com/gb/hotel-helen-berger-centre-valencia/', 'https://guide.michelin.com/en/hotels-stays/valencia/room-mate-helen-berger-12466'),
    ('hotel_468', 'Seventy Barcelona', '+34 930 121 270', 'https://www.seventybarcelona.com/es', 'https://guide.michelin.com/en/hotels-stays/barcelona/seventy-barcelona-13713'),
    ('hotel_469', 'Mirlo Barcelona', '+34 931 42 59 29', 'https://mirlobarcelona.com/', 'https://guide.michelin.com/en/hotels-stays/barcelona/hotel-boutique-mirlo-barcelona-12598'),
    ('hotel_470', 'Four Seasons Hotel Madrid', null, 'https://www.fourseasons.com/madrid/', 'https://guide.michelin.com/en/hotels-stays/madrid/four-seasons-hotel-madrid-13597'),
    ('hotel_471', 'La Zambra Resort', '+34 951 311 234', 'https://lazambrahotel.com/', 'https://guide.michelin.com/en/hotels-stays/malaga/la-zambra-resort-13703'),
    ('hotel_472', 'Only YOU Hotel Valencia', '+34 963 98 10 00', 'https://www.onlyyouhotels.com/hoteles/only-you-hotel-valencia/', 'https://guide.michelin.com/en/hotels-stays/valencia/only-you-hotel-valencia-13039'),
    ('hotel_473', 'Helguera Palacio Boutique & Antique', '+34 942 94 50 51', 'https://www.palaciohelguera.com/', 'https://guide.michelin.com/en/hotels-stays/Santander/helguera-palacio-boutique-antique-13204'),
    ('hotel_474', 'El Llorenç Parc de la Mar', '+34 971 67 77 70', 'https://www.elllorenc.com/', 'https://guide.michelin.com/en/hotels-stays/majorca/el-llorenc-parc-de-la-mar-adults-only-9395'),
    ('hotel_475', 'Hotel Can Ferrereta', '+34 971 905 905', 'https://www.hotelcanferrereta.com/es/', 'https://guide.michelin.com/en/hotels-stays/majorca/hotel-can-ferrereta-12001'),
    ('hotel_476', 'Sant Francesc Hotel Singular', '+34 971 495 000', 'https://www.hotelsantfrancesc.com/es/', 'https://guide.michelin.com/en/hotels-stays/majorca/sant-francesc-hotel-singular-10853'),
    ('hotel_477', 'Ohla Eixample', '+34 937 37 79 77', 'https://www.ohlaboutiquehotels.com/es/ohla-eixample/', 'https://guide.michelin.com/en/hotels-stays/barcelona/ohla-eixample-8735'),
    ('hotel_478', 'Torralbenc', '+34 971 37 72 11', 'https://torralbenc.com/', 'https://guide.michelin.com/en/hotels-stays/minorca/torralbenc-6993'),
    ('hotel_479', 'Cristine Bedfor Mahón', '+34 971 635 502', 'https://cristinebedforhotel.com/menorca/', 'https://guide.michelin.com/en/hotels-stays/minorca/cristine-bedfor-12081'),
    ('hotel_480', 'Atrio Restaurante Hotel', '+34 927 242 928', null, 'https://guide.michelin.com/en/hotels-stays/caceres-1/atrio-restaurante-hotel-6598'),
    ('hotel_481', 'Pepe Vieira', '+34 986 741 378', 'https://pepevieira.com/hotel', 'https://guide.michelin.com/en/hotels-stays/pontevedra/hotel-pepe-vieira-13404'),
    ('hotel_482', 'Monument Hotel', '+34 935 482 000', 'https://www.monumenthotel.com/', 'https://guide.michelin.com/en/hotels-stays/barcelona/monument-hotel-8177'),
    ('hotel_483', 'Convent de La Missió, Grand Luxury Boutique Hotel', '+34 971 227 347', 'https://www.conventdelamissio.com/es/', 'https://guide.michelin.com/en/hotels-stays/majorca/convent-de-la-missio-grand-luxury-boutique-hotel-6707-7476'),
    ('hotel_484', 'Abadía Retuerta LeDomaine', '+34 983 687 600', 'https://abadia-retuerta.com/', 'https://guide.michelin.com/en/hotels-stays/valladolid2/abadia-retuerta-ledomaine-10200'),
    ('hotel_485', 'Hotel Santa María Briones', '+34 941 99 15 99', 'https://santamariabriones.com/', 'https://guide.michelin.com/en/hotels-stays/briones/hotel-santa-maria-briones-13146'),
    ('hotel_486', 'Wittmore', '+34 935 500 885', 'https://www.wittmorehotel.com/', 'https://guide.michelin.com/en/hotels-stays/barcelona/wittmore-hotel-13856'),
    ('hotel_487', 'Cavalta Boutique Hotel', '+34 955 44 20 10', 'https://hiddenhotels.com/cavalta-boutique-hotel/', 'https://guide.michelin.com/en/hotels-stays/sevilla/cavalta-boutique-hotel-123845-13803'),
    ('hotel_488', 'Mercer Barcelona', '+34 933 107 480', 'https://www.mercerbarcelona.com/es', 'https://guide.michelin.com/en/hotels-stays/barcelona/mercer-hotel-barcelona-6912'),
    ('hotel_489', 'Es Raco d''Artà', '+34 971 83 66 73', 'https://www.esracodarta.com/', 'https://guide.michelin.com/en/hotels-stays/majorca/es-raco-darta-11990'),
    ('hotel_490', 'Antiga Casa Buenavista', '+34 93 330 30 30', 'https://hotelcasabuenavista.com/', 'https://guide.michelin.com/en/hotels-stays/barcelona/antiga-casa-buenavista-12122'),
    ('hotel_491', 'Terra Dominicata - Hotel & Winery', '+34 877 91 22 92', 'https://terradominicata.com/', 'https://guide.michelin.com/en/hotels-stays/tarragona/terra-dominicata-hotel-winery-8962'),
    ('hotel_492', 'Alma Barcelona', '+34 932 164 490', 'https://almahotels.com/barcelona/', 'https://guide.michelin.com/en/hotels-stays/barcelona/alma-barcelona-6441'),
    ('hotel_493', 'CoolRooms Palacio Villapanés', '+34 954 50 20 63', 'https://coolrooms.com/palaciovillapanes/', 'https://guide.michelin.com/en/hotels-stays/sevilla/coolrooms-palacio-villapanes-5-gl-3421'),
    ('hotel_494', 'The Principal Madrid', '+34 91 521 87 43', 'https://www.unicohotels.com/en/the-principal-madrid/', 'https://guide.michelin.com/en/hotels-stays/madrid/the-principal-madrid-7791'),
    ('hotel_495', 'Hotel Cortijo del Marqués', '+34 958 34 00 77', 'https://www.cortijodelmarques.com/', 'https://guide.michelin.com/en/hotels-stays/granada/hotel-cortijo-del-marques-9276'),
    ('hotel_496', 'Finca Serena Mallorca', '+34 971 18 17 58', 'https://www.unicohotels.com/en/finca-serena-mallorca/', 'https://guide.michelin.com/en/hotels-stays/majorca/finca-serena-mallorca-9136'),
    ('hotel_497', 'The Artist Grand Hotel of Art', '+34 944 253 300', 'https://hoteltheartist.com/', 'https://guide.michelin.com/en/hotels-stays/bilbao/the-artist-grand-hotel-of-art-1271'),
    ('hotel_498', 'Finca Cortesin', '+34 952 937 800', 'https://fincacortesin.com/', 'https://guide.michelin.com/en/hotels-stays/marbella/finca-cortesin-2721'),
    ('hotel_499', 'Castillo del Buen Amor', '+34 923 35 50 02', 'https://www.buenamor.net/', 'https://guide.michelin.com/en/hotels-stays/salamanca4/castillo-del-buen-amor-11820'),
    ('hotel_500', 'Can Mascort Eco Hotel', '+34 623 188 828', 'https://www.canmascortecohotel.com/es/', 'https://guide.michelin.com/en/hotels-stays/costa-brava/can-mascort-eco-hotel-13021'),
    ('hotel_501', 'Can Alberti 1740 Hotel Boutique', '+34 971 35 42 10', 'https://www.hotelcanalberti.com/', 'https://guide.michelin.com/en/hotels-stays/minorca/can-alberti-1740-hotel-boutique-12462'),
    ('hotel_502', 'Hotel Rector', '+34 923 218 482', 'https://www.hotelrector.com/', 'https://guide.michelin.com/en/hotels-stays/salamanca4/hotel-rector-5135'),
    ('hotel_503', 'Teranka Formentera', '+34 871 873 030', 'https://www.teranka.com/', 'https://guide.michelin.com/en/hotels-stays/formentera/teranka-formentera-13664'),
    ('hotel_504', 'Cap Menorca', null, 'https://www.capmenorca.com/es/', 'https://guide.michelin.com/en/hotels-stays/minorca/cap-menorca-relais-chateaux-14161'),
    ('hotel_505', 'Brach Madrid - Evok Collection', '+34 915 46 36 39', 'https://www.evokcollection.com/brach-madrid/', 'https://guide.michelin.com/en/hotels-stays/madrid/brach-madrid-evok-collection-13593'),
    ('hotel_506', 'Cap Rocat', '+34 971 74 78 78', 'https://caprocat.com/', 'https://guide.michelin.com/en/hotels-stays/majorca/cap-rocat-6377'),
    ('hotel_507', 'La Residencia, A Belmond Hotel, Mallorca', '+34 971 63 90 11', 'https://www.belmond.com/en/hotels/europe/spain/la-residencia-mallorca', 'https://guide.michelin.com/en/hotels-stays/majorca/la-residencia-a-belmond-hotel-mallorca-6384'),
    ('hotel_508', 'Akelarre', '+34 943 311 208', 'https://akelarre.net/', 'https://guide.michelin.com/en/hotels-stays/san-sebastian/akelarre-8643'),
    ('hotel_509', 'Unico', '+34 917 81 01 73', 'https://www.unicohotels.com/es/hotel-unico-madrid/', 'https://guide.michelin.com/en/hotels-stays/madrid/hotel-unico-madrid-2911'),
    ('hotel_510', 'Castell Son Claret', '+34 971 13 86 20', 'https://www.castellsonclaret.com/', 'https://guide.michelin.com/en/hotels-stays/majorca/castell-son-claret-10110'),
    ('hotel_511', 'Es Princep', '+34 971 72 00 00', 'https://www.esprincep.com/es', 'https://guide.michelin.com/en/hotels-stays/majorca/es-princep-9273'),
    ('hotel_512', 'La Torre del Visco', '+34 978 76 90 15', 'https://torredelvisco.com/', 'https://guide.michelin.com/en/hotels-stays/teruel/la-torre-del-visco-9765'),
    ('hotel_513', 'URSO', '+34 914 444 458', 'https://hotelurso.com/', 'https://guide.michelin.com/en/hotels-stays/madrid/urso-hotel-spa-madrid-7607'),
    ('hotel_514', 'Hospes Palacio Del Bailio', '+34 957 49 89 93', 'https://www.hospes.com/palacio-bailio/', 'https://guide.michelin.com/en/hotels-stays/cordoba-1/hospes-palacio-del-bailio-301'),
    ('hotel_515', 'The One Barcelona', '+34 932 14 20 70', 'https://www.hotelstheone.com/en/barcelona-hotels/the-one-barcelona', 'https://guide.michelin.com/en/hotels-stays/barcelona/the-one-barcelona-8519'),
    ('hotel_516', 'Can Bordoy Grand House & Garden', '+34 871 871 202', 'https://www.canbordoy.com/', 'https://guide.michelin.com/en/hotels-stays/majorca/can-bordoy-grand-house-garden-9143'),
    ('hotel_517', 'Almanac Barcelona', '+34 930 18 70 00', 'https://www.almanachotels.com/barcelona/', 'https://guide.michelin.com/en/hotels-stays/barcelona/almanac-barcelona-9002'),
    ('hotel_518', 'Mercer Sevilla', '+34 954 223 004', 'https://www.mercersevilla.com/es', 'https://guide.michelin.com/en/hotels-stays/sevilla/hotel-mercer-sevilla-8527'),
    ('hotel_519', 'Torre del Marqués Hotel Spa & Winery', '+34 978 870 600', 'https://www.hoteltorredelmarques.com/', 'https://guide.michelin.com/en/hotels-stays/teruel/torre-del-marques-hotel-spa-winery-11626'),
    ('hotel_520', 'Can Cera', '+34 971 71 50 12', 'https://www.cancerahotel.com/', 'https://guide.michelin.com/en/hotels-stays/majorca/hotel-can-cera-6753'),
    ('hotel_521', 'A Quinta da Auga', '+34 981 53 46 36', 'https://www.aquintadaauga.com/', 'https://guide.michelin.com/en/hotels-stays/santiago-de-compostela/hotel-spa-relais-chateaux-a-quinta-da-auga-3601'),
    ('hotel_522', 'Santa Catalina, a Royal Hideaway Hotel', '+34 928 24 30 40', 'https://www.barcelo.com/es-es/santa-catalina-a-royal-hideaway-hotel/', 'https://guide.michelin.com/en/hotels-stays/gran-canaria/santa-catalina-a-royal-hideaway-hotel-13700'),
    ('hotel_523', 'Canfranc Estación, a Royal Hideaway Hotel', '+34 974 56 19 00', 'https://www.barcelo.com/es-es/canfranc-estacion-a-royal-hideaway-hotel/', 'https://guide.michelin.com/en/hotels-stays/huesca/canfranc-estacion-a-royal-hideaway-hotel-13117'),
    ('hotel_524', 'Bahia del Duque', '+34 922 74 69 00', 'https://thetaishotels.com/bahia-del-duque/', 'https://guide.michelin.com/en/hotels-stays/tenerife/bahia-del-duque-13701'),
    ('hotel_525', 'Esperit Roca', '+34 872 20 14 41', 'https://esperitroca.com/', 'https://guide.michelin.com/en/hotels-stays/girona/sants-metges-hotel-esperit-roca-10423'),
    ('hotel_526', 'Hotel La Caminera Club de Campo', '+34 926 344 733', 'https://www.hotellacaminera.com/', 'https://guide.michelin.com/en/hotels-stays/torrenueva/la-caminera-9664'),
    ('hotel_527', 'Fairmont La Hacienda Costa del Sol', '+34 856 29 08 11', 'https://www.fairmont.com/en/hotels/san-roque/fairmont-la-hacienda-costa-del-sol.html', 'https://guide.michelin.com/en/hotels-stays/Alcaidesa/fairmont-la-hacienda-costa-del-sol-15148'),
    ('hotel_528', 'Rural Sant Ignasi', '+34 666 52 88 80', 'https://santignasi.com/es/', 'https://guide.michelin.com/en/hotels-stays/minorca/rural-sant-ignasi-15147'),
    ('hotel_529', 'Only YOU Boutique Hotel Madrid', '+34 910 05 22 22', 'https://www.onlyyouhotels.com/hoteles/only-you-boutique-hotel-madrid/', 'https://guide.michelin.com/en/hotels-stays/madrid/only-you-boutique-hotel-madrid-8366'),
    ('hotel_530', 'Predi Son Jaumell', '+34 971 818 796', 'https://www.hotelsonjaumell.com/es', 'https://guide.michelin.com/en/hotels-stays/majorca/predi-son-jaumell-9788'),
    ('hotel_531', 'Hotel Mas Lazuli', '+34 872 222 220', 'https://www.hotelmaslazuli.es/es/', 'https://guide.michelin.com/en/hotels-stays/girona/hotel-mas-lazuli-7693'),
    ('hotel_532', 'Santo Mauro, a Luxury Collection Hotel', '+34 913 19 69 00', 'https://www.marriott.com/en-us/hotels/madlc-santo-mauro-a-luxury-collection-hotel-madrid/overview/', 'https://guide.michelin.com/en/hotels-stays/madrid/ac-santo-mauro-200'),
    ('hotel_533', 'VIVOOD Landscape Hotel & Spa', '+34 966 31 85 85', 'https://vivood.com/', 'https://guide.michelin.com/en/hotels-stays/alicante/vivood-landscape-hotel-10247'),
    ('hotel_534', 'Seda Club Hotel', '+34 858 16 01 61', 'https://hiddenhotels.com/seda-club/', 'https://guide.michelin.com/en/hotels-stays/granada/seda-club-hotel-13304'),
    ('hotel_535', 'Hotel Arts Barcelona', '+34 932 21 10 00', 'https://www.ritzcarlton.com/en/hotels/bcnrz-hotel-arts-barcelona/overview/', 'https://guide.michelin.com/en/hotels-stays/barcelona/hotel-arts-barcelona-7408'),
    ('hotel_536', 'Sa Creu Nova Petit Palais', '+34 871 51 53 45', 'https://sacreunova.com/es/', 'https://guide.michelin.com/en/hotels-stays/majorca/sa-creu-nova-petit-palais-art-spa-8732'),
    ('hotel_537', 'ABaC Restaurant & Hotel', '+34 933 196 600', 'https://www.abacbarcelona.com/', 'https://guide.michelin.com/en/hotels-stays/barcelona/abac-restaurant-hotel-1581'),
    ('hotel_538', 'Son Brull', '+34 971 53 53 53', 'https://sonbrull.com/', 'https://guide.michelin.com/en/hotels-stays/majorca/son-brull-hotel-spa-8464'),
    ('hotel_539', 'Cap Vermell Grand Hotel', '+34 871 811 222', 'https://capvermellgrandhotel.com/', 'https://guide.michelin.com/en/hotels-stays/majorca/cap-vermell-grand-hotel-118902-8439'),
    ('hotel_540', 'Mandarin Oriental Ritz, Madrid', null, null, 'https://guide.michelin.com/en/hotels-stays/madrid/hotel-ritz-5865'),
    ('hotel_541', 'Mandarin Oriental Barcelona', '+34 93 151 88 88', 'https://www.mandarinoriental.com/es/barcelona/passeig-de-gracia', 'https://guide.michelin.com/en/hotels-stays/barcelona/mandarin-oriental-barcelona-6386'),
    ('hotel_542', 'Hotel Maria Cristina', '+34 943 43 76 00', 'https://www.marriott.com/en-us/hotels/easlc-hotel-maria-cristina-a-luxury-collection-hotel-san-sebastian/overview/', 'https://guide.michelin.com/en/hotels-stays/san-sebastian/hotel-maria-cristina-7470'),
    ('hotel_543', 'Rosewood Villa Magna', '+34 915 87 12 34', 'https://www.rosewoodhotels.com/en/villa-magna', 'https://guide.michelin.com/en/hotels-stays/madrid/hotel-villa-magna-5307'),
    ('hotel_544', 'Hotel Marques de Riscal, a Luxury Collection Hotel', '+34 945 18 08 80', 'https://www.marriott.com/en-us/hotels/biolc-hotel-marques-de-riscal-a-luxury-collection-hotel-elciego/overview/', 'https://guide.michelin.com/en/hotels-stays/elciego/hotel-marques-de-riscal-7425'),
    ('hotel_545', 'Royal Hideaway Corales Suites', '+34 922 75 79 00', 'https://www.barcelo.com/es-es/royal-hideaway-corales-suites/', 'https://guide.michelin.com/en/hotels-stays/tenerife/royal-hideaway-corales-suites-10348'),
    ('hotel_546', 'La Almunia del Valle', '+34 958 30 80 10', 'https://www.laalmuniadelvalle.com/', 'https://guide.michelin.com/en/hotels-stays/granada/la-almunia-del-valle-9642'),
    ('hotel_547', 'Anantara Villa Padierna Palace Benahavís Marbella Resort', '+34 952 88 91 50', 'https://www.anantara.com/en/villa-padierna-marbella', 'https://guide.michelin.com/en/hotels-stays/marbella/anantara-villa-padierna-palace-benahavis-marbella-resort-8770'),
    ('hotel_548', 'Petunia Ibiza, Beaumier Hotel', '+34 971 808 197', 'https://www.beaumier.com/en/properties/petunia/', 'https://guide.michelin.com/en/hotels-stays/ibiza/petunia-ibiza-a-beaumier-hotel-12256'),
    ('hotel_549', 'Palacio de Luces', '+34 985 85 00 80', 'https://www.unicohotels.com/en/palacio-de-luces/', 'https://guide.michelin.com/en/hotels-stays/Luces/coolrooms-palacio-de-luces-12682'),
    ('hotel_550', 'Hotel L''Avenida', '+34 971 63 40 75', 'https://www.avenida-hotel.com/', 'https://guide.michelin.com/en/hotels-stays/majorca/hotel-lavenida-8574'),
    ('hotel_551', 'Little Beach House Barcelona', null, 'https://www.sohohouse.com/houses/little-beach-house-barcelona', 'https://guide.michelin.com/en/hotels-stays/garraf/little-beach-house-barcelona-13093'),
    ('hotel_552', 'Fontsanta Thermal Spa & Wellness', '+34 971 655 016', 'https://www.fontsantahotel.com/', 'https://guide.michelin.com/en/hotels-stays/majorca/fontsanta-thermal-spa-wellness-14062'),
    ('hotel_553', 'Vincci Selección Unuk', '+34 955 26 64 99', 'https://www.vinccihoteles.com/es/hoteles/sevilla/vincci-seleccion-unuk/', 'https://guide.michelin.com/en/hotels-stays/sevilla/vincci-seleccion-unuk-5-gl-13699'),
    ('hotel_554', 'La Fonda Heritage', '+34 952 12 38 40', 'https://lafondaheritage.com/', 'https://guide.michelin.com/en/hotels-stays/marbella/la-fonda-heritage-hotel-relais-chateaux-13663'),
    ('hotel_555', 'Gran Hotel Inglés', '+34 91 360 00 01', 'https://hiddenhotels.com/gran-hotel-ingles/', 'https://guide.michelin.com/en/hotels-stays/madrid/gran-hotel-ingles-11161'),
    ('hotel_556', 'Caro Hotel', '+34 963 059 000', 'https://www.carohotel.com/', 'https://guide.michelin.com/en/hotels-stays/valencia/caro-hotel-13702'),
    ('hotel_557', 'Hotel Puntagrande', '+34 611 28 59 83', 'https://hotelpuntagrande.com/', 'https://guide.michelin.com/en/hotels-stays/el-hierro/hotel-puntagrande-14081'),
    ('hotel_558', 'Marbella Club Hotel', '+34 952 82 22 11', 'https://www.marbellaclub.com/', 'https://guide.michelin.com/en/hotels-stays/marbella/marbella-club-hotel-5985'),
    ('hotel_559', 'Serras Barcelona', '+34 936 061 632', 'https://serrasbarcelona.com/es/', 'https://guide.michelin.com/en/hotels-stays/barcelona/serras-barcelona-12051'),
    ('hotel_560', 'Lasala Plaza Hotel', '+34 943 547 000', 'https://www.lasalaplazahotel.com/', 'https://guide.michelin.com/en/hotels-stays/san-sebastian/lasala-plaza-hotel-119438-8902'),
    ('hotel_561', 'Yurbban Passage', '+34 938 82 89 77', 'https://hotels.yurbban.com/es/hoteles/passage', 'https://guide.michelin.com/en/hotels-stays/barcelona/yurbban-passage-hotel-spa-11009'),
    ('hotel_562', 'Mas de Torrent', '+34 972 30 32 92', 'https://www.unicohotels.com/es/hotel-mas-de-torrent/', 'https://guide.michelin.com/en/hotels-stays/costa-brava/mas-de-torrent-hotel-spa-7200'),
    ('hotel_563', 'Hotel Villa Favorita - Adults Only', '+34 843 931 111', 'https://hotelvillafavorita.com/', 'https://guide.michelin.com/en/hotels-stays/san-sebastian/hotel-villa-favorita-adults-only-11631'),
    ('hotel_564', 'CoolRooms Palacio de Atocha', '+34 910 88 77 80', 'https://coolrooms.com/palaciodeatocha/', 'https://guide.michelin.com/en/hotels-stays/madrid/coolrooms-atocha-11111'),
    ('hotel_565', 'Palacio de los Duques, Gran Meliá', '+34 915 41 67 00', 'https://www.melia.com/es/hoteles/espana/madrid/palacio-de-los-duques-gran-melia', 'https://guide.michelin.com/en/hotels-stays/madrid/gran-melia-palacio-de-los-duques-8808'),
    ('hotel_566', 'Casa Beatnik Country House', null, 'https://www.casabeatnik.com/', 'https://guide.michelin.com/en/hotels-stays/la-coruna/casa-beatnik-hotel-13030'),
    ('hotel_567', 'Hotel Peralada Wine Spa & Golf', '+34 972 53 88 30', 'https://www.hotelperalada.com/es', 'https://guide.michelin.com/en/hotels-stays/girona/peralada-9668'),
    ('hotel_568', 'Boutique Hotel Posada Terra Santa', '+34 971 21 47 42', 'https://hiddenhotels.com/posada-terra-santa/', 'https://guide.michelin.com/en/hotels-stays/majorca/boutique-hotel-posada-terra-santa-9261'),
    ('hotel_569', 'Soho House Barcelona', '+34 932 20 46 00', 'https://www.sohohouse.com/houses/soho-house-barcelona', 'https://guide.michelin.com/en/hotels-stays/barcelona/soho-house-barcelona-13089');

do $$
declare bad text; n int;
begin
  select count(*) into n from _c;
  if n <> 109 then raise exception 'expected 109 rows in _c, found %', n; end if;

  select string_agg(c.code, ', ') into bad from _c c
   where not exists (select 1 from public.hotels h
                      where h.hotel_code = c.code and h.country_code = 'ES'
                        and h.michelin_keys is not null and h.name = c.name);
  if bad is not null then raise exception 'not the expected Spanish Key hotel: %', bad; end if;

  select string_agg(c.code, ', ') into bad from _c c join public.hotels h on h.hotel_code = c.code
   where (c.phone is not null and h.phone is not null)
      or (c.website_url is not null and h.website_url is not null)
      or (c.michelin_url is not null and h.michelin_url is not null);
  if bad is not null then raise exception 'field already set since the export (refusing to skip silently): %', bad; end if;

  select string_agg(c.code || ' -> ' || h.hotel_code, ', ') into bad from _c c
    join public.hotels h on h.michelin_url = c.michelin_url and h.hotel_code <> c.code;
  if bad is not null then raise exception 'MICHELIN URL already held by another hotel: %', bad; end if;

  update public.hotels h set michelin_url = c.michelin_url from _c c
   where h.hotel_code = c.code and h.country_code = 'ES' and c.michelin_url is not null and h.michelin_url is null;
  get diagnostics n = row_count;
  if n <> 109 then raise exception 'michelin_url: expected 109 rows, updated %', n; end if;

  update public.hotels h set website_url = c.website_url from _c c
   where h.hotel_code = c.code and h.country_code = 'ES' and c.website_url is not null and h.website_url is null;
  get diagnostics n = row_count;
  if n <> 107 then raise exception 'website_url: expected 107 rows, updated %', n; end if;

  update public.hotels h set phone = c.phone from _c c
   where h.hotel_code = c.code and h.country_code = 'ES' and c.phone is not null and h.phone is null;
  get diagnostics n = row_count;
  if n <> 104 then raise exception 'phone: expected 104 rows, updated %', n; end if;
end $$;

commit;
