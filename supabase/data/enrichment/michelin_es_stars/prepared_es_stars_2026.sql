-- PREPARED -- NOT APPLIED.
--
-- MICHELIN Guide Spain 2026 (Guía MICHELIN España & Andorra 2026, announced
-- 25 November 2025 in Málaga): add every starred Spanish restaurant missing
-- from the catalogue, with Google Place IDs and phone numbers, and complete
-- the 57 Spanish restaurants already there. Written 2026-10-28.
--
-- SOURCE: MICHELIN only for the selection -- guide.michelin.com/en/es
-- starred listing (296 live: 16/37/243), each restaurant's own page
-- (JSON-LD: address, coordinates, phone, dateAwarded "2026"), and the 2026
-- full-list article (307 incl. Andorra; reconciled in ES_STARS_2026_REPORT.md).
-- Place IDs: Google Places API, verified against MICHELIN's coordinates
-- (find-place-id rules). Phones: MICHELIN and Google agreeing, or the
-- venue's own site. Evidence per row: es_restaurants_2026.csv.
--
-- GUIDE YEAR: MICHELIN labels this selection 2026; the 57 seeded ES rows
-- labelled 2026 hold this edition's values (all 57 checked against the live
-- listing), so no relabel. The 2027 edition is announced 1 December 2026
-- (Huesca); it will be a separate update.
--
-- WHAT CHANGES
--   1. 239 restaurants added (rest_1588..rest_1826), each with a 2026
--      award_history row (announced 2025-11-25). Their awards before 2026 are
--      not recorded -- the same launch limitation as every seeded row.
--      235 carry a confirmed Place ID, 232 a confirmed phone,
--      9 a property_name (restaurant in a non-Key hotel).
--   2. 13 hotel_restaurants links: restaurants MICHELIN places in a
--      hotel that is one of our Key hotels (MICHELIN's hotel page carries the
--      Key, and its pin is within 150 m of our hotels row).
--   3. Existing rows, fill-only: michelin_url for 35, phone for 46,
--      property_name for 2; plus Deessa's michelin_url, which 404s
--      (".../restaurant/deesa").
--   NOT CHANGED: the 10 restaurants in MICHELIN's 2026 article that MICHELIN
--   has since taken offline (none is in production; not added). Stored
--   coordinates, names and phones of existing rows (findings logged, QA).
--
-- PREREQUISITE: supabase/migrations/20261019140000_add_es_2026_star_cities.sql.
-- One transaction; every check raises, rolling the whole file back. A
-- re-run after success aborts at the first check.

begin;

do $$
declare n int;
begin
  if exists (select 1 from public.restaurants
              where restaurant_code ~ '^rest_[0-9]+$'
                and substring(restaurant_code from 6)::int between 1588 and 1826) then
    raise exception 'codes rest_1588..rest_1826 are no longer free -- re-check';
  end if;
  select count(*) into n from public.restaurants where country_code = 'ES';
  if n <> 57 then raise exception 'expected 57 ES restaurants (export of 2026-10-28), found % -- production changed, re-check', n; end if;
  select count(*) into n from public.restaurants
   where restaurant_code = any(array['rest_0002', 'rest_0042', 'rest_0044', 'rest_0058', 'rest_0067', 'rest_0296', 'rest_0312', 'rest_0317', 'rest_0330', 'rest_0331', 'rest_0332', 'rest_0333', 'rest_0334', 'rest_0335', 'rest_0336', 'rest_0337', 'rest_0338', 'rest_0339', 'rest_0340', 'rest_0341', 'rest_0342', 'rest_0343', 'rest_0344', 'rest_0345', 'rest_0346', 'rest_0347', 'rest_0348', 'rest_0349', 'rest_0350', 'rest_0351', 'rest_0352', 'rest_0353', 'rest_0354', 'rest_0355', 'rest_0356', 'rest_0357', 'rest_0358', 'rest_0359', 'rest_0360', 'rest_0361', 'rest_0362', 'rest_0363', 'rest_0364', 'rest_0365', 'rest_0366', 'rest_0367', 'rest_0368', 'rest_0369', 'rest_0370', 'rest_0371', 'rest_0372', 'rest_0373', 'rest_0374', 'rest_0375', 'rest_0376', 'rest_0377', 'rest_1387']) and country_code = 'ES';
  if n <> 57 then raise exception 'the 57 exported ES codes no longer all exist (% found)', n; end if;
  select count(*) into n from public.award_history ah join public.restaurants r on r.id = ah.entity_id
   where ah.entity_type = 'restaurant' and ah.award_type = 'michelin_stars'
     and r.country_code = 'ES' and ah.guide_year = 2026 and ah.is_current;
  if n <> 57 then raise exception 'expected 57 current ES 2026 star rows, found %', n; end if;
end $$;

-- 1. missing starred restaurants
create temp table _new (code text, name text, stars smallint, city text, address text,
                        lon float8, lat float8, michelin_url text, website_url text,
                        phone text, property_name text, place_id text) on commit drop;
insert into _new values
    ('rest_1588', 'Ababol', 1::smallint, 'Albacete', 'Calderón de la Barca 14, 02002 Albacete', -1.8541648, 38.9889097, 'https://guide.michelin.com/en/castilla-la-mancha/albacete/restaurant/ababol', 'https://www.restauranteababol.es', '+34 967 02 08 82', NULL, 'ChIJAcjIi8FfZg0RjKDK4L3pG_4'),
    ('rest_1589', 'Abantal', 1::smallint, 'Sevilla', 'Alcalde José de la Bandera 7, 41003 Sevilla', -5.9836581, 37.3878998, 'https://guide.michelin.com/en/andalucia/sevilla/restaurant/abantal', 'https://abantalrestaurante.es/', '+34 954 54 00 00', NULL, 'ChIJZ9KMjB1sEg0R6NhDbHBZO9M'),
    ('rest_1590', 'A''Barra', 1::smallint, 'Madrid', 'Del Pinar 15, 28006 Madrid', -3.687633, 40.438683, 'https://guide.michelin.com/en/comunidad-de-madrid/madrid/restaurant/a-barra', 'https://www.restauranteabarra.com', '+34 638 95 09 36', NULL, 'ChIJg8E4AOwoQg0RbtjZ1H2hoXM'),
    ('rest_1591', 'Ajonegro', 1::smallint, 'Logroño', 'Hermanos Moroy 1 - bajo 9, 26001 Logroño', -2.4460143, 42.4657582, 'https://guide.michelin.com/en/la-rioja/logrono/restaurant/ajonegro', 'https://restauranteajonegro.es/', '+34 941 54 51 41', NULL, 'ChIJLW6xVkerWg0RAoy1FrbC0ps'),
    ('rest_1592', 'Alameda', 1::smallint, 'Hondarribia', 'Minasoroeta 1, 20280 Hondarribia', -1.7925817, 43.3612194, 'https://guide.michelin.com/en/pais-vasco/hondarribia/restaurant/alameda220551', 'https://restaurantealameda.net/', '+34 943 64 27 89', NULL, 'ChIJfbZAHQYJUQ0RAH0yeLbrfHA'),
    ('rest_1593', 'Alejandro Serrano', 1::smallint, 'Miranda de Ebro', 'Alfonso VI 49, 09200 Miranda de Ebro', -2.9422008, 42.6865108, 'https://guide.michelin.com/en/castilla-y-leon/miranda-de-ebro/restaurant/alejandro-serrano', 'https://www.serranoalejandro.es/', '+34 947 31 26 87', NULL, 'ChIJQ1mJbgybTw0Ro_TTPhgQ5uw'),
    ('rest_1594', 'Alevante by Ángel León', 2::smallint, 'Chiclana de la Frontera', 'Amílcar Barca, 11130 Chiclana de la Frontera', -6.1648673, 36.3468318, 'https://guide.michelin.com/en/andalucia/chiclana-de-la-frontera_1446717/restaurant/alevante', 'https://alevanteangelleon.com/', '+34 956 49 12 00', 'Palacio de Sancti Petri, Gran Meliá', 'ChIJEctnb0YxDA0RQgstYS-K1Mo'),
    ('rest_1595', 'Alkimia', 1::smallint, 'Barcelona', 'Ronda San Antoni 41 - Principal, 08011 Barcelona', 2.1635928, 41.3829097, 'https://guide.michelin.com/en/catalunya/barcelona/restaurant/alkimia', 'https://alkimia.cat/', '+34 932 07 61 15', NULL, 'ChIJ5c4QTsGipBIRaakXWVSPrSY'),
    ('rest_1596', 'Almo de Juan Guillamón', 1::smallint, 'Murcia', 'Madre de Dios 15, 30004 Murcia', -1.132081, 37.9842525, 'https://guide.michelin.com/en/region-de-murcia/murcia/restaurant/almo', 'https://almorestaurante.com/', '+34 868 06 95 57', NULL, 'ChIJQdZB0M6DYw0RZX9zFJkBjRg'),
    ('rest_1597', 'Alquimia - Laboratorio', 1::smallint, 'Valladolid', 'Antigua 6, 47002 Valladolid', -4.7224762, 41.6538741, 'https://guide.michelin.com/en/castilla-y-leon/valladolid/restaurant/alquimia', 'https://alquimiavalladolid.es/', '+34 983 07 53 78', NULL, 'ChIJnQNToL4TRw0RsFaF87qEMYY'),
    ('rest_1598', 'Ama', 1::smallint, 'Tolosa', 'Martín José Iraola 4, 20400 Tolosa', -2.0776318, 43.1322758, 'https://guide.michelin.com/en/pais-vasco/tolosa/restaurant/ama', 'https://www.amatolosa.com', '+34 688 63 80 09', NULL, 'ChIJAZQRmjNLUA0RgFFWA4d__jU'),
    ('rest_1599', 'Ancestral', 1::smallint, 'Pozuelo de Alarcón', 'Saliente 2, 28223 Pozuelo de Alarcón', -3.8412509, 40.4218575, 'https://guide.michelin.com/en/comunidad-de-madrid/pozuelo-de-alarcon/restaurant/ancestral-1241234', 'https://ancestralrestaurante.com/', '+34 608 57 76 58', NULL, 'ChIJV8box5nxQQ0Rd1mn354IgBs'),
    ('rest_1600', 'Andra Mari', 1::smallint, 'Galdakao', 'Barrio Elexalde 22, 48960 Galdakao', -2.8324171, 43.234941, 'https://guide.michelin.com/en/pais-vasco/galdakao/restaurant/andra-mari220169', 'https://www.andra-mari.com/', '+34 944 56 00 05', NULL, 'ChIJo3esY2tJTg0Rbwb9dv-FeYk'),
    ('rest_1601', 'Andreu Genestra', 1::smallint, 'Llucmajor', 'Camí de Sa Torre, Km 8,7, 07609 Llucmajor', 2.8001231, 39.4379554, 'https://guide.michelin.com/en/islas-baleares/llucmajor/restaurant/andreu-genestra-1208507', 'https://www.andreugenestra.com', '+34 603 29 37 45', NULL, 'ChIJMzokPCUWlhIR58zX3CAsSL0'),
    ('rest_1602', 'Angle', 1::smallint, 'Barcelona', 'Aragó 214, 08011 Barcelona', 2.1597015, 41.3882671, 'https://guide.michelin.com/en/catalunya/barcelona/restaurant/angle', 'https://anglebarcelona.com', '+34 932 16 77 77', NULL, 'ChIJecv7K4yipBIRs8mIO7ud1vY'),
    ('rest_1603', 'Ansils', 1::smallint, 'Anciles', 'General Ferraz 6, 22469 Anciles', 0.5097959, 42.5909183, 'https://guide.michelin.com/en/aragon/anciles_7770296/restaurant/ansils', 'https://www.restauranteansils.com', '+34 974 55 11 50', NULL, 'ChIJpw5r5CB5qBIR24mGIwesv4M'),
    ('rest_1604', 'Árbore da Veira', 1::smallint, 'La Coruña', 'Parque Monte San Pedro, 15011 La Coruña', -8.433224, 43.377457, 'https://guide.michelin.com/en/galicia/a-corua/restaurant/arbore-da-veira', 'https://arboredaveira.com/', '+34 981 07 89 14', NULL, 'ChIJkfgOsn18Lg0RrLF-5XbaPWs'),
    ('rest_1605', 'ARREA!', 1::smallint, 'Santa Cruz de Campezo', 'Subida al Frontón 46, 01110 Santa Cruz de Campezo', -2.3497835, 42.6692746, 'https://guide.michelin.com/en/pais-vasco/santa-cruz-de-campezo/restaurant/arrea', 'https://arrea.eus/', '+34 689 74 03 70', NULL, 'ChIJZRGpcCEFUA0RUf0xVgivg1c'),
    ('rest_1606', 'Arrels', 1::smallint, 'Sagunt', 'Castillo 18, 46500 Sagunt', -0.2781263, 39.6786129, 'https://guide.michelin.com/en/comunidad-valenciana/sagunt/restaurant/arrels', 'https://www.restaurantarrels.com/', '+34 606 75 40 76', NULL, 'ChIJ1_2k9BYVYA0RRq5vCnMafJo'),
    ('rest_1607', 'Asador O''Pazo', 1::smallint, 'Padrón', 'Pazos s/n, 15917 Padrón', -8.65202, 42.7564294, 'https://guide.michelin.com/en/galicia/padron/restaurant/o-pazo', 'https://asadoropazo.es', '+34 671 90 34 06', NULL, 'ChIJS7NKPbEELw0RKual8IDWxDw'),
    ('rest_1608', 'As Garzas', 1::smallint, 'Barizo', 'Porto Barizo 40, 15113 Barizo', -8.8719851, 43.3213756, 'https://guide.michelin.com/en/galicia/barizo/restaurant/as-garzas', 'https://www.asgarzas.com', '+34 981 72 17 65', NULL, 'ChIJFXnjnMKiLg0RFxBTuNKTYus'),
    ('rest_1609', 'A Tafona', 1::smallint, 'Santiago de Compostela', 'Virxe da Cerca 7, 15703 Santiago de Compostela', -8.5402512, 42.880744, 'https://guide.michelin.com/en/galicia/santiago-de-compostela/restaurant/a-tafona', 'https://www.luciafreitas.es/a-tafona', '+34 981 56 23 14', NULL, 'ChIJOzpH5kX-Lg0RlK-Jr1AOgAs'),
    ('rest_1610', 'Atalaya', 1::smallint, 'Alcossebre', 'Camí l''Atall 1A, 12579 Alcossebre', 0.284626, 40.2492377, 'https://guide.michelin.com/en/comunidad-valenciana/alcossebre/restaurant/atalaya', 'https://www.atalayarestaurante.com', '+34 964 96 71 07', NULL, 'ChIJuaoEm5QVoBIRDSJwwoh8hkc'),
    ('rest_1611', 'Atempo', 1::smallint, 'Barcelona', 'Còrsega 200, 08036 Barcelona', 2.1523876, 41.3909858, 'https://guide.michelin.com/en/catalunya/barcelona/restaurant/atempo-1196425', 'https://atemporestaurant.com/es/', '+34 937 34 19 19', NULL, 'ChIJHbrt5pLnuhIRtGv2L0MoImQ'),
    ('rest_1612', 'Audrey''s', 1::smallint, 'Calp', 'Avenida Juan Carlos I 48, 03710 Calp', 0.072623, 38.6501744, 'https://guide.michelin.com/en/comunidad-valenciana/calp/restaurant/audrey-s-by-rafa-soler', 'https://www.audreys.es/', NULL, NULL, 'ChIJX9Pn-AD-nRIRnjnr0cB0tXc'),
    ('rest_1613', 'Auga', 1::smallint, 'Gijón', 'Claudio Alvargonzález, 33201 Gijón', -5.6665859, 43.5465083, 'https://guide.michelin.com/en/principado-de-asturias/gijon/restaurant/auga', 'https://www.restauranteauga.com', '+34 985 16 81 86', NULL, 'ChIJtfGTamh8Ng0RKxwJ0Y6vGRM'),
    ('rest_1614', 'Ayalga Villa Rosario', 1::smallint, 'Ribadesella', 'Dionisio Ruisánchez 6, 33560 Ribadesella', -5.067508, 43.4651241, 'https://guide.michelin.com/en/principado-de-asturias/ribadesella/restaurant/ayalga', 'https://www.ayalgavillarosario.com', '+34 696 52 98 19', 'Villa Rosario Palacete', 'ChIJEaqeUFUdNg0RjbGlUNGygdM'),
    ('rest_1615', 'BACK', 1::smallint, 'Marbella', 'Pablo Casals 8, 29602 Marbella', -4.894597, 36.509052, 'https://guide.michelin.com/en/andalucia/marbella/restaurant/back', 'https://www.backrestaurante.com/', '+34 951 55 00 45', NULL, 'ChIJYZLWAwAocw0R0AQizXdQXq0'),
    ('rest_1616', 'Baeza & Rufete', 1::smallint, 'Alicante', 'Avenida de Ansaldo 31, Local 1 - Centro Comercial Portalada, 03540 Alicante', -0.433443, 38.368797, 'https://guide.michelin.com/en/comunidad-valenciana/alacant/restaurant/baeza-rufete', 'https://www.baezarufete.com', '+34 965 16 22 47', NULL, 'ChIJ8_vV1sc5Yg0RCXkhibtfYB8'),
    ('rest_1617', 'Bagá', 1::smallint, 'Jaén', 'Reja de la Capilla 3, 23001 Jaén', -3.7861942, 37.7668005, 'https://guide.michelin.com/en/andalucia/jaen/restaurant/baga', 'https://www.bagagastronomico.com', '+34 953 04 74 50', NULL, 'ChIJebipB3XXbQ0RX9KDUNCP8pw'),
    ('rest_1618', 'Bakea', 1::smallint, 'Mungia', 'Olalde Berezia Kalea 1, 48100 Mungia', -2.8505789, 43.3574809, 'https://guide.michelin.com/en/pais-vasco/mungia_1403141/restaurant/bakea', 'https://www.bakeamungia.com', '+34 611 76 91 49', NULL, 'ChIJHy0LHZFHTg0RPxks3IGDlSc'),
    ('rest_1619', 'Barahonda', 1::smallint, 'Yecla', 'Carretera de Pinoso, 30510 Yecla', -1.0811773, 38.5872328, 'https://guide.michelin.com/en/region-de-murcia/yecla/restaurant/barahonda', 'https://www.barahonda.com/', '+34 968 75 36 04', NULL, 'ChIJYxvdBuv8Yw0Rc04s8MrLIQg'),
    ('rest_1620', 'Barro', 1::smallint, 'Ávila', 'Carretera de Salamanca 4, 05002 Ávila', -4.709749, 40.6577005, 'https://guide.michelin.com/en/castilla-y-leon/avila/restaurant/barro', 'https://www.barrorestaurante.es', '+34 680 25 03 43', NULL, 'ChIJIYPG0M7zQA0Ror1sSrxTxuY'),
    ('rest_1621', 'Beat by José Manuel Miguel', 1::smallint, 'Calp', 'Urbanización Marisol Park 1A, 03710 Calp', 0.060922, 38.6474226, 'https://guide.michelin.com/en/comunidad-valenciana/calp/restaurant/beat', 'https://www.ar-hotels.com/restaurantes-calpe/beat.html', '+34 960 13 01 79', NULL, 'ChIJq3gVhRv-nRIRGoxBecdcLlQ'),
    ('rest_1622', 'Blossom', 1::smallint, 'Malaga', 'Plaza de la Aduana, 29015 Malaga', -4.417583, 36.720118, 'https://guide.michelin.com/en/andalucia/malaga/restaurant/blossom-1202609', 'https://blossommalaga.com/', NULL, NULL, 'ChIJeYu9YXL3cg0R_tDHQ6JhhbA'),
    ('rest_1623', 'Boroa', 1::smallint, 'Amorebieta', 'Caserío Garai 11, 48340 Amorebieta', -2.7598523, 43.2352979, 'https://guide.michelin.com/en/pais-vasco/amorebieta-etxano/restaurant/boroa', 'https://www.boroa.com/', '+34 946 73 47 47', NULL, NULL),
    ('rest_1624', 'brula', 1::smallint, 'Eivissa', 'Paseo Juan Carlos I 17, 07800 Eivissa', 1.4415572, 38.9174239, 'https://guide.michelin.com/en/islas-baleares/eivissa/restaurant/la-gaia', 'https://brulaibiza.com/', '+34 971 80 68 06', NULL, 'ChIJVym_jcpGmRIRFvCjB_YOo6U'),
    ('rest_1625', 'Caelis', 1::smallint, 'Barcelona', 'Via Laietana 49, 08003 Barcelona', 2.1743294, 41.3869216, 'https://guide.michelin.com/en/catalunya/barcelona/restaurant/caelis', 'https://www.caelis.com/', '+34 935 10 12 05', 'Ohla Barcelona', 'ChIJxXEkMe6ipBIRHtCUX_CpuCE'),
    ('rest_1626', 'Ca l''Enric', 1::smallint, 'La Vall de Bianya', 'Carretera Camprodón N 260, 17813 La Vall de Bianya', 2.4401289, 42.2217505, 'https://guide.michelin.com/en/catalunya/la-vall-de-bianya/restaurant/ca-l-enric', 'https://www.restaurantcalenric.cat/', '+34 972 29 00 15', NULL, 'ChIJeQpU25dKpRIRmh9TXCafT2w'),
    ('rest_1627', 'Callizo', 1::smallint, 'Ainsa', 'Plaza Mayor, 22330 Ainsa', 0.1381766, 42.4176644, 'https://guide.michelin.com/en/aragon/ainsa/restaurant/callizo', 'https://restaurantecallizo.es/', '+34 974 50 03 85', NULL, 'ChIJQ_OfZsb6pxIROrbPqvzXc4U'),
    ('rest_1628', 'Cal Paradís', 1::smallint, 'Vall d''Alba', 'Avenida Vilafranca 30, 12194 Vall d''Alba', -0.0339289, 40.1768248, 'https://guide.michelin.com/en/comunidad-valenciana/vall-d-alba/restaurant/cal-paradis', 'https://www.calparadis.es', '+34 964 56 56 21', NULL, 'ChIJ6cjilqj3Xw0RoOAV0cto5v8'),
    ('rest_1629', 'Cañabota', 1::smallint, 'Sevilla', 'Orfila 3, 41003 Sevilla', -5.9936533, 37.3935972, 'https://guide.michelin.com/en/andalucia/sevilla/restaurant/canabota', 'https://www.canabota.es', '+34 954 87 02 98', NULL, 'ChIJx8hXfAVsEg0RSe2YupZmn4U'),
    ('rest_1630', 'Can Bosch', 1::smallint, 'Cambrils', 'Rambla Jaume I 19, 43850 Cambrils', 1.0589362, 41.0668913, 'https://guide.michelin.com/en/catalunya/cambrils/restaurant/can-bosch', 'https://canbosch.com/', '+34 977 36 00 19', NULL, 'ChIJqTsrLy1boRIRvjRuhkEbhsg'),
    ('rest_1631', 'Canfranc Express', 1::smallint, 'Canfranc-Estación', 'Avenida Fernando el Católico 2, 22880 Canfranc-Estación', -0.5147982, 42.753857, 'https://guide.michelin.com/en/aragon/canfranc-estacion_1384216/restaurant/canfranc-express', 'https://www.barcelo.com/es-es/canfranc-estacion-a-royal-hideaway-hotel/gastronomia/canfranc-express/', '+34 974 56 19 00', NULL, 'ChIJ_YWmcTubVw0ROwvHVP0MA24'),
    ('rest_1632', 'Can Jubany', 1::smallint, 'Calldetenes', 'Carretera C 25, 08506 Calldetenes', 2.3018917, 41.9293884, 'https://guide.michelin.com/en/catalunya/calldetenes/restaurant/can-jubany', 'https://canjubany.com', '+34 938 89 10 23', NULL, 'ChIJOwXcR9YnpRIRQ4N4bAXQPcI'),
    ('rest_1633', 'Casa Arcas', 1::smallint, 'Villanova', 'Carretera A-139, 22467 Villanova', 0.4645155, 42.551754, 'https://guide.michelin.com/en/aragon/villanova/restaurant/casa-arcas', 'https://hotelvalledebenasque.com/', NULL, NULL, 'ChIJ3yqMDuHXpxIRA2hRj18CL1Y'),
    ('rest_1634', 'Casa Bernardi', 1::smallint, 'Benissa', 'Partida Pedramala 60C, 03720 Benissa', 0.0785022, 38.6917839, 'https://guide.michelin.com/en/comunidad-valenciana/benissa/restaurant/casa-bernardi', 'https://casabernardi.es/', '+34 622 30 86 25', NULL, 'ChIJSbuQehoHnhIRqYgfM3CgUbY'),
    ('rest_1635', 'Casa Gerardo', 1::smallint, 'Prendes', 'Carretera AS 19 Km 9, 33438 Prendes', -5.7872, 43.53658, 'https://guide.michelin.com/en/principado-de-asturias/prendes/restaurant/casa-gerardo', 'https://www.restaurantecasagerardo.es/', '+34 985 88 77 97', NULL, NULL),
    ('rest_1636', 'Casa Marcelo', 1::smallint, 'Santiago de Compostela', 'Hortas 1, 15705 Santiago de Compostela', -8.5466466, 42.880834, 'https://guide.michelin.com/en/galicia/santiago-de-compostela/restaurant/casa-marcelo', 'https://www.casamarcelo.net', '+34 981 55 85 80', NULL, 'ChIJT360x0P-Lg0RnQ_j3JPH3pI'),
    ('rest_1637', 'Casa Nova', 1::smallint, 'Sant Martí Sarroca', 'Finca Cal Tòfol – Barri La Bleda, 08731 Sant Martí Sarroca', 1.6418923, 41.3553731, 'https://guide.michelin.com/en/catalunya/sant-marti-sarroca/restaurant/casa-nova', 'https://www.casanovarest.com', '+34 937 43 11 70', NULL, 'ChIJU8IhtNZwpBIRHxpoxUdvUhE'),
    ('rest_1638', 'Casa Pepa', 1::smallint, 'Ondara', 'Partida Pamis 7-30, 03760 Ondara', 0.007204, 38.818996, 'https://guide.michelin.com/en/comunidad-valenciana/ondara/restaurant/casa-pepa', 'https://capepa.es/', '+34 965 76 66 06', NULL, 'ChIJn2UkGa0CnhIRFOL9kVq28SA'),
    ('rest_1639', 'Casa Rubén', 1::smallint, 'Tella', 'Carretera de Bielsa km 63 Hospital de Tella, 22364 Tella', 0.1624873, 42.5475683, 'https://guide.michelin.com/en/aragon/tella/restaurant/casa-ruben', 'https://www.restauranteordesa.es', '+34 660 15 47 00', NULL, 'ChIJ____KKHipxIRa3VRtmzsTFs'),
    ('rest_1640', 'Casas Colgadas Restaurante', 1::smallint, 'Cuenca', 'Canónigos, 16001 Cuenca', -2.1283593, 40.077857, 'https://guide.michelin.com/en/castilla-la-mancha/es-cuenca/restaurant/casas-colgadas', 'https://www.restaurantecasascolgadas.com', '+34 644 00 97 95', NULL, 'ChIJ3V0x8DlnXQ0RVz3AsXUBlmQ'),
    ('rest_1641', 'Casona del Judío', 1::smallint, 'Santander', 'Repuente 20, 39012 Santander', -3.8292585, 43.4686232, 'https://guide.michelin.com/en/cantabria/santander/restaurant/casona-del-judio', 'https://www.casonadeljudio.com/', '+34 942 34 27 26', NULL, 'ChIJbbbvHXtJSQ0RkjcmG4mjpQY'),
    ('rest_1642', 'Castell Perelada', 1::smallint, 'Peralada', 'Sant Joan, 17491 Peralada', 3.0114904, 42.3078839, 'https://guide.michelin.com/en/catalunya/peralada/restaurant/castell-peralada', 'https://www.castellperaladarestaurant.com', '+34 972 52 20 40', NULL, 'ChIJ99YGoNGOuhIR15l-EaBibZA'),
    ('rest_1643', 'CEBO', 1::smallint, 'Madrid', 'San Jerónimo 34, 28014 Madrid', -3.6984633, 40.4162213, 'https://guide.michelin.com/en/comunidad-de-madrid/madrid/restaurant/cebo-1203091', 'https://www.cebomadrid.com', '+34 917 87 77 70', 'Urban', 'ChIJaZxVboEoQg0R2Xyk4VBN6QA'),
    ('rest_1644', 'Ceibe', 1::smallint, 'Ourense', 'San Miguel 8, 32005 Ourense', -7.8637958, 42.3377294, 'https://guide.michelin.com/en/galicia/ourense/restaurant/ceibe', 'https://ceiberestaurante.es/', '+34 988 54 25 80', NULL, 'ChIJL9-m9Ir_Lw0RVh139VZWQrs'),
    ('rest_1645', 'Chirón', 1::smallint, 'Valdemoro', 'Alarcón 27, 28341 Valdemoro', -3.6764858, 40.191578, 'https://guide.michelin.com/en/comunidad-de-madrid/valdemoro/restaurant/chiron', 'https://www.restaurantechiron.com/', '+34 918 95 69 74', NULL, 'ChIJJUYTasceQg0RRDvKAk9NHOM'),
    ('rest_1646', 'Chispa Bistró', 1::smallint, 'Madrid', 'Barquillo 8, 28004 Madrid', -3.6956288, 40.4202857, 'https://guide.michelin.com/en/comunidad-de-madrid/madrid/restaurant/chispa-bistro', 'https://Chispabistro.com', '+34 917 51 81 56', NULL, 'ChIJFZPvPOgpQg0Rh6yW8vBMM58'),
    ('rest_1647', 'Choco', 1::smallint, 'Córdoba', 'Compositor Serrano Lucena 14, 14010 Córdoba', -4.7623009, 37.8850096, 'https://guide.michelin.com/en/andalucia/cordoba/restaurant/choco', 'https://www.restaurantechoco.com/', '+34 957 26 48 63', NULL, 'ChIJy-qRHYffbA0RVQx7hteG6BE'),
    ('rest_1648', 'Citrus del Tancat', 1::smallint, 'Alcanar', 'CN-340 KM1059 - Sol de Riu, 43530 Alcanar', 0.5103616, 40.5279565, 'https://guide.michelin.com/en/catalunya/alcanar/restaurant/citrus-del-tancat', 'https://citrusdeltancat.com/', '+34 977 73 71 94', NULL, 'ChIJ78UjhPhRoBIRRONVoAmVO-o'),
    ('rest_1649', 'Clos Madrid', 1::smallint, 'Madrid', 'Raimundo Fernández Villaverde 28, 28003 Madrid', -3.6999179, 40.4465794, 'https://guide.michelin.com/en/comunidad-de-madrid/madrid/restaurant/clos-madrid', 'https://www.restauranteclosmadrid.es/', '+34 910 64 88 05', NULL, 'ChIJF6dzp_koQg0R62gcjySme7g'),
    ('rest_1650', 'Cobo Evolución', 1::smallint, 'Burgos', 'Plaza de la Libertad 9, 09004 Burgos', -3.698853, 42.3415093, 'https://guide.michelin.com/en/castilla-y-leon/burgos/restaurant/cobo-evolucion', 'https://www.coboestratos.com', '+34 947 02 75 81', NULL, 'ChIJi35sDAn9RQ0RyX7FzcuFNCg'),
    ('rest_1651', 'Cocinandos', 1::smallint, 'León', 'Plaza de San Marcos 5, 24001 León', -5.5810161, 42.6019852, 'https://guide.michelin.com/en/castilla-y-leon/leon/restaurant/cocinandos', 'https://www.cocinandos.com/', '+34 987 07 13 78', NULL, 'ChIJmTrDcYyaNw0R7vionrUwnqc'),
    ('rest_1652', 'Código de Barra', 1::smallint, 'Cádiz', 'San Francisco 7, 11004 Cádiz', -6.2954072, 36.5338202, 'https://guide.michelin.com/en/andalucia/cadiz/restaurant/codigo-de-barra', 'https://restaurantecodigodebarracadiz.com/', '+34 635 53 33 03', NULL, 'ChIJqQKeGGLRDQ0RXZS0uekmjao'),
    ('rest_1653', 'COME by Paco Méndez', 1::smallint, 'Barcelona', 'Avenida del Mistral 54, 08015 Barcelona', 2.1540955, 41.376166, 'https://guide.michelin.com/en/catalunya/barcelona/restaurant/come-by-paco-mendez', 'https://come.com.es/', '+34 938 27 59 77', NULL, 'ChIJVwv2p3yipBIR303yebWvbbM'),
    ('rest_1654', 'Corral de la Morería Gastronómico', 1::smallint, 'Madrid', 'Morería 17, 28005 Madrid', -3.7140918, 40.4128471, 'https://guide.michelin.com/en/comunidad-de-madrid/madrid/restaurant/corral-de-la-moreria-gastronomico', 'https://www.moreriagastro.com/', '+34 913 65 84 46', NULL, NULL),
    ('rest_1655', 'Coto de Quevedo Evolución', 1::smallint, 'Torre de Juan Abad', 'Paraje Tejeras Viejas, 13344 Torre de Juan Abad', -3.0492196, 38.5798152, 'https://guide.michelin.com/en/castilla-la-mancha/torre-de-juan-abad/restaurant/coto-de-quevedo', 'https://www.cotodequevedo.com', '+34 649 84 29 01', NULL, NULL),
    ('rest_1656', 'Dama Juana', 1::smallint, 'Jaén', 'Melchor Cobo Medina 7, 23001 Jaén', -3.7854772, 37.767224, 'https://guide.michelin.com/en/andalucia/jaen/restaurant/dama-juana', 'https://www.damajuanajaen.es', '+34 953 00 64 54', NULL, 'ChIJZV8p5pbXbQ0RqCwTVSCIF4A'),
    ('rest_1657', 'Deliranto', 1::smallint, 'Salou', 'Llevant 7, 43840 Salou', 1.1326351, 41.0767475, 'https://guide.michelin.com/en/catalunya/salou/restaurant/deliranto', 'https://deliranto.com/', '+34 977 38 09 42', NULL, 'ChIJc8CxqytaoRIRWa4yjZ0X8lk'),
    ('rest_1658', 'Desde 1911', 1::smallint, 'Madrid', 'Vivero 3, 28040 Madrid', -3.7098877, 40.4485341, 'https://guide.michelin.com/en/comunidad-de-madrid/madrid/restaurant/desde-1911', 'https://www.desde1911.es', '+34 915 45 72 86', NULL, 'ChIJnXNVR5spQg0Rme2Rv3TPPJM'),
    ('rest_1659', 'DINS Santi Taura', 1::smallint, 'Palma', 'Plaza de Llorenç Villalonga 4, 07001 Palma', 2.6529955, 39.565643, 'https://guide.michelin.com/en/islas-baleares/palma/restaurant/dins-santi-taura', 'https://www.grupsantitaura.com/es/dins-santitaura/', '+34 669 95 90 42', NULL, 'ChIJq6qq6hLElxIRc9AqB63IDok'),
    ('rest_1660', 'Divinum', 1::smallint, 'Girona', 'Albereda 7, 17004 Girona', 2.8240743, 41.9822044, 'https://guide.michelin.com/en/catalunya/girona/restaurant/divinum', 'https://www.divinum.cat/', '+34 872 08 02 18', NULL, 'ChIJIwZInOfmuhIRghrx2Xs54wc'),
    ('rest_1661', 'Donaire', 1::smallint, 'Adeje', 'Fernando López Arvelo 1, Planta 4, 38660 Adeje', -16.7387881, 28.0916898, 'https://guide.michelin.com/en/canarias/adeje/restaurant/donaire', 'https://www.restaurantedonaire.com', '+34 922 98 71 77', NULL, 'ChIJL_TNs9eXagwRb8d9BJ1RFTU'),
    ('rest_1662', 'Dos Palillos', 1::smallint, 'Barcelona', 'Elisabets 9, 08001 Barcelona', 2.1688127, 41.3833904, 'https://guide.michelin.com/en/catalunya/barcelona/restaurant/dos-palillos', 'https://www.dospalillos.com/', '+34 933 04 05 13', NULL, 'ChIJyaJCM_SipBIRxsdH2ToFYe0'),
    ('rest_1663', 'El Bohío', 1::smallint, 'Illescas', 'Avenida Castilla-La Mancha 81, 45200 Illescas', -3.8463784, 40.1264098, 'https://guide.michelin.com/en/castilla-la-mancha/illescas/restaurant/el-bohio', 'https://www.elbohio.net/', '+34 925 51 11 26', NULL, 'ChIJm_Zqah_xQQ0RZua_O3edAiQ'),
    ('rest_1664', 'El Corral del Indianu', 1::smallint, 'Arriondas', 'Avenida de Europa 14, 33540 Arriondas', -5.1842735, 43.3902522, 'https://guide.michelin.com/en/principado-de-asturias/arriondas/restaurant/el-corral-del-indianu', 'https://www.elcorraldelindianu.com', '+34 985 84 10 72', NULL, 'ChIJY0Fh_PUYNg0R62nRJ0raHdU'),
    ('rest_1665', 'El Doncel', 1::smallint, 'Sigüenza', 'Paseo de la Alameda 3, 19250 Sigüenza', -2.643727, 41.0692522, 'https://guide.michelin.com/en/castilla-la-mancha/siguenza/restaurant/el-doncel', 'https://eldoncel.com/', '+34 949 39 00 01', NULL, 'ChIJjwaw-D1FQw0Rd-9WYPw7Wjk'),
    ('rest_1666', 'El Ermitaño', 1::smallint, 'Benavente', 'Arrabal Huerta de los Salados, 49600 Benavente', -5.65799, 42.00712, 'https://guide.michelin.com/en/castilla-y-leon/benavente/restaurant/el-ermitano', 'https://www.elermitano.com/', NULL, NULL, 'ChIJ5fZXfRBMOA0RifgANGakSdY'),
    ('rest_1667', 'El Invernadero', 1::smallint, 'Madrid', 'Ponzano 85, 28003 Madrid', -3.6988948, 40.4445251, 'https://guide.michelin.com/en/comunidad-de-madrid/madrid/restaurant/el-invernadero', 'https://elinvernaderorestaurante.com/', '+34 628 93 93 67', NULL, 'ChIJF2e3OHopQg0RM2CPwRwgE2Y'),
    ('rest_1668', 'El Molino de Alcuneza', 1::smallint, 'Sigüenza', 'Carretera GU 128, 19250 Sigüenza', -2.6044708, 41.1055995, 'https://guide.michelin.com/en/castilla-la-mancha/siguenza/restaurant/el-molino-de-alcuneza', 'https://www.molinodealcuneza.com/', '+34 949 39 15 01', 'El Molino de Alcuneza', 'ChIJUQ1FnQZRQw0RFvRQZfROD4k'),
    ('rest_1669', 'El Retiro', 1::smallint, 'Llanes', 'Carretera Pancar, 33500 Llanes', -4.7621095, 43.4123756, 'https://guide.michelin.com/en/principado-de-asturias/llanes/restaurant/el-retiro', 'https://www.elretirollanes.es/', '+34 985 40 02 40', NULL, 'ChIJtx3YjuTqSQ0R74Oo_l49F3U'),
    ('rest_1670', 'Els Casals', 1::smallint, 'Sagàs', 'Masía Els Casals, 08517 Sagàs', 1.9608946, 42.0313907, 'https://guide.michelin.com/en/catalunya/sagas/restaurant/els-casals', 'https://elscasals.cat/', '+34 938 25 12 00', NULL, 'ChIJOR_iFiAOpRIR8lBob-9HLlE'),
    ('rest_1671', 'El Serbal', 1::smallint, 'Santander', 'Avenida de Manuel García Lago 1, 39005 Santander', -3.7881718, 43.4776869, 'https://guide.michelin.com/en/cantabria/santander/restaurant/el-serbal-1197026', 'https://elserbal.com/', '+34 942 22 25 15', NULL, 'ChIJ6yRXjrFLSQ0RqBrm0WBDD-I'),
    ('rest_1672', 'Els Tinars', 1::smallint, 'Llagostera', 'Carretera de Sant Feliu de Guíxols, 17240 Llagostera', 2.9533814, 41.8274496, 'https://guide.michelin.com/en/catalunya/llagostera/restaurant/els-tinars', 'https://www.elstinars.com', '+34 972 83 06 26', NULL, 'ChIJEWkweooduxIRnLAxgnFMXi8'),
    ('rest_1673', 'El Taller Seve Díaz', 1::smallint, 'Puerto de la Cruz', 'San Felipe 32, 38400 Puerto de la Cruz', -16.5531212, 28.416585, 'https://guide.michelin.com/en/canarias/puerto-de-la-cruz/restaurant/el-taller-seve-diaz', 'https://www.eltallersevediaz.com', '+34 822 25 75 38', NULL, 'ChIJuYbpmpR_agwRMnXIHCVYkHc'),
    ('rest_1674', 'El Xato', 1::smallint, 'La Nucía', 'Avenida l''Esglèsia 3, 03530 La Nucía', -0.123197, 38.6172486, 'https://guide.michelin.com/en/comunidad-valenciana/la-nucia/restaurant/el-xato', 'https://elxato.com/', '+34 965 87 09 31', NULL, 'ChIJF-72jeQCYg0Razvn2HwmjMs'),
    ('rest_1675', 'EMi', 1::smallint, 'Madrid', 'Gaztambide 64, 28015 Madrid', -3.7151674, 40.4387941, 'https://guide.michelin.com/en/comunidad-de-madrid/madrid/restaurant/emi', 'https://emimadrid.com/', '+34 638 34 02 22', NULL, 'ChIJ-XWGCQApQg0RudGlyNawyMY'),
    ('rest_1676', 'Empòrium', 1::smallint, 'Castelló d''Empúries', 'Santa Clara 31, 17486 Castelló d''Empúries', 3.0760903, 42.2558205, 'https://guide.michelin.com/en/catalunya/castello-d-empuries/restaurant/emporium', 'https://www.emporiumhotel.com/', '+34 972 25 05 93', NULL, 'ChIJQ4V1ewCLuhIRQC0nU8PNyDc'),
    ('rest_1677', 'Eneko', 1::smallint, 'Larrabetzu', 'Legina Auzoa, 48195 Larrabetzu', -2.8148549, 43.2608738, 'https://guide.michelin.com/en/pais-vasco/larrabetzu/restaurant/eneko', 'https://www.eneko.restaurant', '+34 944 55 88 66', NULL, 'ChIJGzL7JVRITg0RxXA0ZCCCPWg'),
    ('rest_1678', 'En la Parra', 1::smallint, 'Salamanca', 'San Pablo 80, 37008 Salamanca', -5.6642767, 40.9606615, 'https://guide.michelin.com/en/castilla-y-leon/salamanca/restaurant/en-la-parra', 'https://restaurantenlaparra.com/', '+34 923 06 47 83', NULL, 'ChIJX6TY1WomPw0R2ouNS5jL5YA'),
    ('rest_1679', 'Epílogo', 1::smallint, 'Tomelloso', 'Paseo Ramón Ugena 15, 13700 Tomelloso', -3.0266187, 39.1489653, 'https://guide.michelin.com/en/castilla-la-mancha/tomelloso/restaurant/epilogo', 'https://www.restauranteepilogo.com/', '+34 926 16 12 22', NULL, 'ChIJt1BTwOz9aA0RPCn-8HpmzYU'),
    ('rest_1680', 'Es Fum', 1::smallint, 'Palmanova', 'Carretera Palma-Andratx 19, 07181 Palmanova', 2.5506805, 39.5282611, 'https://guide.michelin.com/en/islas-baleares/palmanova/restaurant/es-fum', 'https://www.restaurant-esfum.com/', '+34 971 62 93 15', NULL, 'ChIJvcQA-bqOlxIR18OjsvjtgSY'),
    ('rest_1681', 'Esperit Roca', 1::smallint, 'Sant Julià de Ramis', 'Major, Entrada 1, 17481 Sant Julià de Ramis', 2.8453888, 42.0323124, 'https://guide.michelin.com/en/catalunya/sant-julia-de-ramis/restaurant/esperit-roca', 'https://www.esperitroca.com', '+34 872 20 14 43', NULL, 'ChIJu7HphPPnuhIRkXu7fXuC_kI'),
    ('rest_1682', 'Èter', 1::smallint, 'Madrid', 'Granito 20, 28045 Madrid', -3.6919123, 40.3931752, 'https://guide.michelin.com/en/comunidad-de-madrid/madrid/restaurant/eter', 'https://eterrestaurant.com/', NULL, NULL, 'ChIJl8Vm314nQg0RdSw5ZpYvHM4'),
    ('rest_1683', 'Europa', 1::smallint, 'Pamplona', 'Espoz y Mina 11-1°, 31002 Pamplona', -1.6418103, 42.8161985, 'https://guide.michelin.com/en/comunidad-foral-de-navarra/pamplona/restaurant/europa', 'https://www.hreuropa.com/', '+34 948 22 18 00', NULL, 'ChIJDwTbzf6SUA0RJWS1nSutoLQ'),
    ('rest_1684', 'Faralá', 1::smallint, 'Granada', 'Cuesta de Gomérez 11, 18009 Granada', -3.5952603, 37.1763702, 'https://guide.michelin.com/en/andalucia/granada/restaurant/farala', 'https://www.restaurantefarala.com', '+34 664 08 53 13', NULL, 'ChIJKxxnryz9cQ0R_ME_jHHcHls'),
    ('rest_1685', 'Ferpel Gastronómico', 1::smallint, 'Ortiguera', 'Lugar el Molin y La Cabana 48, 33716 Ortiguera', -6.7450058, 43.5592015, 'https://guide.michelin.com/en/principado-de-asturias/ortiguera/restaurant/ferpel', 'https://www.ferpelgastronomico.com/', '+34 985 47 32 85', NULL, 'ChIJY12opNZfMQ0RsugCv-_OlCs'),
    ('rest_1686', 'Fierro', 1::smallint, 'València', 'Doctor Serrano 4, 46006 València', -0.3726653, 39.4625709, 'https://guide.michelin.com/en/comunidad-valenciana/valencia/restaurant/fierro', 'https://fierrovlc.com/', '+34 963 30 52 44', NULL, 'ChIJbZ_iActIYA0R3g-kBk3ytLU'),
    ('rest_1687', 'Fishølogy', 1::smallint, 'Barcelona', 'Diputació 73, 08015 Barcelona', 2.154461, 41.3809826, 'https://guide.michelin.com/en/catalunya/barcelona/restaurant/fishology', 'https://www.fishology.es', '+34 936 33 98 58', NULL, 'ChIJaWwEYxqjpBIRBweS5Nnc2HY'),
    ('rest_1688', 'Fogony', 1::smallint, 'Sort', 'Avenida Generalitat 45, 25560 Sort', 1.1320678, 42.4155601, 'https://guide.michelin.com/en/catalunya/sort/restaurant/fogony', 'https://www.fogony.com', '+34 973 62 12 25', NULL, 'ChIJp1YopNkFphIRScBxYDYyyOc'),
    ('rest_1689', 'Frases', 1::smallint, 'Murcia', 'San Lorenzo 5 - Bajo Derecha, 30001 Murcia', -1.127942, 37.9861889, 'https://guide.michelin.com/en/region-de-murcia/murcia/restaurant/frases', 'https://www.frasesrestaurante.com/', '+34 697 91 44 92', NULL, 'ChIJQ0hZrBqCYw0RzAifjPj4lFQ'),
    ('rest_1690', 'Fraula', 1::smallint, 'València', 'Cirilo Amorós 84, 46004 València', -0.366224, 39.4694922, 'https://guide.michelin.com/en/comunidad-valenciana/valencia/restaurant/fraula', 'https://fraula.es/', '+34 680 34 81 20', NULL, 'ChIJV_Gxa5lJYA0Rrf9WixkE_no'),
    ('rest_1691', 'Fusion19', 1::smallint, 'Muro', 'Avenida de s''Albufera 23, 07458 Muro', 3.1170442, 39.805798, 'https://guide.michelin.com/en/islas-baleares/muro/restaurant/fusion19', 'https://www.fusion19.com', '+34 971 89 42 59', NULL, 'ChIJ-y08KCItlhIROQvnC7bxB4w'),
    ('rest_1692', 'Garena', 1::smallint, 'Dima', 'Barrio Iturriotz 11, 48141 Dima', -2.7659992, 43.1292766, 'https://guide.michelin.com/en/pais-vasco/dima/restaurant/garena', 'https://www.garena.restaurant', '+34 946 31 72 15', NULL, 'ChIJfbg0SzHLTw0RlnI0RR7sjkY'),
    ('rest_1693', 'Gaytán', 1::smallint, 'Madrid', 'Príncipe de Vergara 205, 28002 Madrid', -3.6783632, 40.4493113, 'https://guide.michelin.com/en/comunidad-de-madrid/madrid/restaurant/gaytan', 'https://chefjavieraranda.com/en/', '+34 689 65 32 27', NULL, 'ChIJd6M8r94oQg0RwUOiAobTPIo'),
    ('rest_1694', 'Gente Rara', 1::smallint, 'Zaragoza', 'Santiago Lapuente 10, 50014 Zaragoza', -0.8705451, 41.6587729, 'https://guide.michelin.com/en/aragon/zaragoza/restaurant/gente-rara', 'https://www.genterara.es', '+34 623 00 20 84', NULL, 'ChIJF48Zmn8VWQ0RIXyjTlXziU0'),
    ('rest_1695', 'Gofio', 1::smallint, 'Madrid', 'Caballero de Gracia 20, 28013 Madrid', -3.7001594, 40.4193176, 'https://guide.michelin.com/en/comunidad-de-madrid/madrid/restaurant/gofio-by-cicero-canary', 'https://gofiorestaurant.com/', '+34 912 03 35 34', NULL, 'ChIJVZqm8YEoQg0RuCSMSdWBFDk'),
    ('rest_1696', 'Haydée by Víctor Suárez', 1::smallint, 'Adeje', 'Unterhaching, 38660 Adeje', -16.7412967, 28.0909726, 'https://guide.michelin.com/en/canarias/adeje/restaurant/haydee-by-victor-suarez', 'https://www.restaurantehaydee.rest/es/inicio/', '+34 822 68 00 48', NULL, 'ChIJqzwL3E_VQQwRoXVAeFGAv8s'),
    ('rest_1697', 'Hisop', 1::smallint, 'Barcelona', 'Passatge de Marimon 9, 08021 Barcelona', 2.1480692, 41.3945109, 'https://guide.michelin.com/en/catalunya/barcelona/restaurant/hisop', 'https://www.hisop.com', '+34 932 41 32 33', NULL, 'ChIJx2nrT5yipBIRcT4_prXJJck'),
    ('rest_1698', 'Hofmann', 1::smallint, 'Barcelona', 'La Granada del Penedès 14-16, 08006 Barcelona', 2.1530609, 41.3971709, 'https://guide.michelin.com/en/catalunya/barcelona/restaurant/hofmann', 'https://www.hofmannrestaurante.com', '+34 932 18 71 65', NULL, 'ChIJU2yMmZmipBIRincP1doW8ak'),
    ('rest_1699', 'Hospedería El Batán', 1::smallint, 'Tramacastilla', 'Carretera A 1512, 44112 Tramacastilla', -1.5602059, 40.42797, 'https://guide.michelin.com/en/aragon/tramacastilla/restaurant/hospederia-el-batan', 'https://www.elbatan.es', '+34 696 48 44 61', NULL, 'ChIJS0e6u6y5XQ0R4gQiErmwM8k'),
    ('rest_1700', 'iBAi by Paulo Airaudo', 1::smallint, 'San Sebastian', 'Getaria 15, 20005 San Sebastian', -1.9806425, 43.3182991, 'https://guide.michelin.com/en/pais-vasco/es-donostia-san-sebastian/restaurant/ibai-by-paulo-airaudo', 'https://www.baribai.com/', '+34 843 67 79 32', NULL, 'ChIJR5us31ClUQ0R8_XX9xRilCc'),
    ('rest_1701', 'Ikaro', 1::smallint, 'Logroño', 'Avenida de Portugal 3, 26001 Logroño', -2.4485193, 42.4643373, 'https://guide.michelin.com/en/la-rioja/logrono/restaurant/ikaro', 'https://www.restauranteikaro.com/', '+34 941 57 16 14', NULL, 'ChIJlziupUerWg0RenC8MSqseg0'),
    ('rest_1702', 'Il Bocconcino by Royal Hideaway', 1::smallint, 'Adeje', 'Avenida Virgen de Guadalupe 21, La Caleta, 38679 Adeje', -16.7539875, 28.1020231, 'https://guide.michelin.com/en/canarias/adeje/restaurant/il-bocconcino-by-royal-hideaway', 'https://www.barcelo.com/es-es/royal-hideaway-corales-resort-2/gastrocorales/il-bocconcino/', '+34 922 75 79 00', NULL, 'ChIJidN5NwqRagwR4SDIJSW1OqI'),
    ('rest_1703', 'Islares', 1::smallint, 'Bilbao', 'Mazarredo Zumarkalea, 65bis, 48009 Bilbao', -2.9353316, 43.2671415, 'https://guide.michelin.com/en/pais-vasco/bilbao/restaurant/islares', 'https://www.islares.restaurant', '+34 747 42 10 86', NULL, 'ChIJ8dkn475PTg0RId5X2UZIrEM'),
    ('rest_1704', 'Itzuli', 1::smallint, 'San Sebastian', 'Gudamendi Bidea 21, 20008 San Sebastian', -2.0268014, 43.3121062, 'https://guide.michelin.com/en/pais-vasco/es-donostia-san-sebastian/restaurant/itzuli', 'https://www.restauranteitzuli.com/', '+34 943 02 17 26', 'Hotel Luze Boutique San Sebastián', 'ChIJRfF94cm7UQ0RcO1OdT2TPpQ'),
    ('rest_1705', 'José Carlos García', 1::smallint, 'Malaga', 'Vélez Málaga 8, 29016 Malaga', -4.410671, 36.718313, 'https://guide.michelin.com/en/andalucia/malaga/restaurant/jose-carlos-garcia', 'https://www.restaurantejcg.com/', '+34 952 00 35 88', NULL, 'ChIJhc9caOj3cg0R314W8tcmG_k'),
    ('rest_1706', 'Kabo', 1::smallint, 'Pamplona', 'Avenida de Zaragoza 10, 31003 Pamplona', -1.6433174, 42.8118407, 'https://guide.michelin.com/en/comunidad-foral-de-navarra/pamplona/restaurant/kabo', 'https://www.restaurantekabo.com', '+34 948 00 27 73', NULL, 'ChIJ5yEZ9BiTUA0RHouai8D0wS4'),
    ('rest_1707', 'Kaido Sushi Bar', 1::smallint, 'València', 'Chile 3, 46021 València', -0.3575637, 39.470454, 'https://guide.michelin.com/en/comunidad-valenciana/valencia/restaurant/kaido-sushi-bar', 'https://kaidosushi.es/', '+34 687 00 06 96', NULL, 'ChIJpWeGRw5JYA0RWBgBYbijiWQ'),
    ('rest_1708', 'Kaleja', 1::smallint, 'Malaga', 'Marquesa de Moya 9, 29015 Malaga', -4.417923, 36.7211416, 'https://guide.michelin.com/en/andalucia/malaga/restaurant/kaleja', 'https://restaurantekaleja.com/', '+34 952 60 00 00', NULL, 'ChIJ26NsLJj3cg0R7M1qfOYrukA'),
    ('rest_1709', 'Kamezí', 1::smallint, 'Playa Blanca', 'Mónaco 2, 35580 Playa Blanca', -13.8655864, 28.8598924, 'https://guide.michelin.com/en/canarias/playa-blanca/restaurant/kamezi', 'https://www.kamezi.restaurant/', '+34 626 87 36 95', NULL, 'ChIJRzXdykQ3RgwRZtjTAuju0fY'),
    ('rest_1710', 'Kamikaze', 1::smallint, 'Barcelona', 'Roselló 197, 08036 Barcelona', 2.155568, 41.3924339, 'https://guide.michelin.com/en/catalunya/barcelona/restaurant/taberna-kamikaze', 'https://www.kamikazebarcelona.com', '+34 931 81 35 70', NULL, 'ChIJb8OJj6GjpBIR15m3GfR9CsY'),
    ('rest_1711', 'Kiro Sushi', 1::smallint, 'Logroño', 'Emilia Pardo Bazán 5, 26009 Logroño', -2.4506228, 42.4747109, 'https://guide.michelin.com/en/la-rioja/logrono/restaurant/kiro-sushi', 'https://www.kirosushi.es', '+34 941 12 31 45', NULL, 'ChIJQzWKFUarWg0RT_fH6n_Ao8o'),
    ('rest_1712', 'Kokotxa', 1::smallint, 'San Sebastian', 'Kanpandegi 11, 20003 San Sebastian', -1.9870824, 43.3236003, 'https://guide.michelin.com/en/pais-vasco/es-donostia-san-sebastian/restaurant/kokotxa', 'https://www.restaurantekokotxa.com', '+34 943 42 19 04', NULL, 'ChIJoyYCPU2lUQ0RER9mC22dzwc'),
    ('rest_1713', 'Koy Shunka', 1::smallint, 'Barcelona', 'De Copons 7, 08002 Barcelona', 2.1754248, 41.385908, 'https://guide.michelin.com/en/catalunya/barcelona/restaurant/koy-shunka', 'https://www.koyshunka.com/KoyShunka/esp_home.html', NULL, NULL, 'ChIJzwnCHfqipBIRBQbVUnQ5gXU'),
    ('rest_1714', 'La Aquarela', 1::smallint, 'Patalavaca', 'Barranco de la Verga, 35129 Patalavaca', -15.6933478, 27.773594, 'https://guide.michelin.com/en/canarias/patalavaca/restaurant/la-aquarela', 'https://www.restaurantelaaquarela.com/', '+34 928 73 58 91', NULL, 'ChIJ71Bn0vmBQAwRXxg0OTXrJuc'),
    ('rest_1715', 'La Bicicleta', 1::smallint, 'Hoznayo', 'La Plaza 12, 39716 Hoznayo', -3.7020062, 43.3902515, 'https://guide.michelin.com/en/cantabria/hoznayo/restaurant/la-bicicleta', 'https://www.labicicletahoznayo.com', '+34 636 29 69 70', NULL, 'ChIJHS3n4FXKTg0RYBmHJVM679g'),
    ('rest_1716', 'La Botica de Matapozuelos', 1::smallint, 'Matapozuelos', 'Plaza Mayor 2, 47230 Matapozuelos', -4.7914841, 41.4143484, 'https://guide.michelin.com/en/castilla-y-leon/matapozuelos/restaurant/la-botica', 'https://laboticadematapozuelos.com/', '+34 983 83 29 42', NULL, 'ChIJG1BSSrZGRw0R-eubJPJEHlY'),
    ('rest_1717', 'La Casa de Manolo Franco', 1::smallint, 'Valdemorillo', 'La Fuente 6, 28210 Valdemorillo', -4.0679548, 40.5009997, 'https://guide.michelin.com/en/comunidad-de-madrid/valdemorillo/restaurant/la-casa-de-manolo-franco', 'https://www.lacasademanolofranco.com', '+34 626 61 57 39', NULL, 'ChIJMfxTKyKfQQ0R_u-5-ulUXr0'),
    ('rest_1718', 'La Costa', 1::smallint, 'El Ejido', 'Bulevar 48, 04700 El Ejido', -2.8277724, 36.7708222, 'https://guide.michelin.com/en/andalucia/el-ejido/restaurant/la-costa', 'https://restaurantelacosta.com/', '+34 950 48 17 77', NULL, 'ChIJme6HHRhDcA0RlC77qB7TLi0'),
    ('rest_1719', 'La Era de los Nogales', 1::smallint, 'Sardas', 'Baja 2, 22613 Sardas', -0.3378358, 42.5067095, 'https://guide.michelin.com/en/aragon/sardas/restaurant/la-era-de-los-nogales', 'https://www.laeradelosnogales.com', '+34 693 01 94 79', NULL, 'ChIJd1OmsQAhWA0RQgCMJX1-Cgg'),
    ('rest_1720', 'La Finca', 1::smallint, 'Elche', 'Partida de Perleta 1-7, 03295 Elche', -0.6504141, 38.2559837, 'https://guide.michelin.com/en/comunidad-valenciana/elche/restaurant/la-finca', 'https://www.lafinca.es', '+34 965 45 60 07', NULL, 'ChIJNQnzeii0Yw0RiAFryDegh4c'),
    ('rest_1721', 'La Fonda Xesc', 1::smallint, 'Gombrèn', 'Plaza Roser 1, 17531 Gombrèn', 2.0915223, 42.2482594, 'https://guide.michelin.com/en/catalunya/gombren/restaurant/la-fonda-xesc', 'https://www.fondaxesc.com/', '+34 972 73 04 04', NULL, 'ChIJl8wM3w1rpRIR2Psock_ZaqI'),
    ('rest_1722', 'L''Aliança d''Anglès', 1::smallint, 'Anglès', 'Jacint Verdaguer 3, 17160 Anglès', 2.6390996, 41.95616, 'https://guide.michelin.com/en/catalunya/angles/restaurant/l-alianca-1919-d-angles', 'https://www.alianca1919.com/', '+34 972 42 01 56', NULL, 'ChIJfc2wK5PZuhIRIGFGGDFv-No'),
    ('rest_1723', 'La Lobita', 1::smallint, 'Navaleno', 'Avenida La Constitución 54, 42149 Navaleno', -3.0064064, 41.8367514, 'https://guide.michelin.com/en/castilla-y-leon/navaleno/restaurant/la-lobita', 'https://www.lalobita.es/', '+34 975 37 43 68', NULL, 'ChIJ1YoirS38RA0RxG0SIkJOST8'),
    ('rest_1724', 'L''Antic Molí', 1::smallint, 'Ulldecona', 'Carretera Ulldecona - La Sénia KM 10, 43550 Ulldecona', 0.3370827, 40.6090476, 'https://guide.michelin.com/en/catalunya/ulldecona/restaurant/l-antic-moli', 'https://www.anticmoli.com/', '+34 977 57 08 93', NULL, 'ChIJES08jwlfoBIRA0cbEvNo_-k'),
    ('rest_1725', 'La Prensa', 1::smallint, 'Zaragoza', 'José Nebra 3, 50007 Zaragoza', -0.8746479, 41.633181, 'https://guide.michelin.com/en/aragon/zaragoza/restaurant/la-prensa', 'https://www.restaurantelaprensa.com', '+34 976 38 16 37', NULL, 'ChIJDx1wggMVWQ0RutblRxGThwk'),
    ('rest_1726', 'La Revelía', 1::smallint, 'Amorebieta', 'Aldana, 29, 48340 Amorebieta', -2.7531089, 43.2649574, 'https://guide.michelin.com/en/pais-vasco/amorebieta-etxano/restaurant/la-revelia', 'https://www.larevelia.com', '+34 946 67 21 12', NULL, 'ChIJoWm4gNU3Tg0RMLrR5QUsXGA'),
    ('rest_1727', 'La Salita', 1::smallint, 'València', 'Pere III El Gran 11, 46005 València', -0.3696366, 39.4623668, 'https://guide.michelin.com/en/comunidad-valenciana/valencia/restaurant/la-salita-1192181', 'https://www.anarkiagroup.com/inicio/la-salita', '+34 609 33 07 60', NULL, 'ChIJ9UOhGJFIYA0R3xWddCYdzrM'),
    ('rest_1728', 'La Tasquería', 1::smallint, 'Madrid', 'Modesto Lafuente 82, 28003 Madrid', -3.6956819, 40.4454892, 'https://guide.michelin.com/en/comunidad-de-madrid/madrid/restaurant/la-tasqueria', 'https://latasqueria.com/', '+34 914 51 10 00', NULL, 'ChIJE3nxYKMoQg0RFOY4NseW04k'),
    ('rest_1729', 'Lera', 1::smallint, 'Castroverde de Campos', 'Conquistadores Zamoranos 6, 49110 Castroverde de Campos', -5.3137839, 41.967639, 'https://guide.michelin.com/en/castilla-y-leon/castroverde-de-campos/restaurant/lera', 'https://restaurantelera.es/', '+34 980 66 46 53', NULL, 'ChIJSfXePrRoOA0RsMyjvrnoBQ8'),
    ('rest_1730', 'Les Magnòlies', 1::smallint, 'Arbúcies', 'Paseo Mossèn Anton Serres 7, 17401 Arbúcies', 2.5082462, 41.8188198, 'https://guide.michelin.com/en/catalunya/arbcies/restaurant/les-magnolies', 'https://www.lesmagnolies.com', '+34 972 86 08 79', NULL, 'ChIJa5nqvesruxIRRhvP_PwzwFs'),
    ('rest_1731', 'Les Moles', 1::smallint, 'Ulldecona', 'Carretera de La Sénia, 43550 Ulldecona', 0.4206069, 40.6042819, 'https://guide.michelin.com/en/catalunya/ulldecona/restaurant/les-moles', 'https://lesmoles.com/', '+34 977 57 32 24', NULL, 'ChIJX2FVvFpYoBIRH3JF41gj28c'),
    ('rest_1732', 'Lienzo', 1::smallint, 'València', 'Plaza de Tetuán 18, 46003 València', -0.3697428, 39.4750292, 'https://guide.michelin.com/en/comunidad-valenciana/valencia/restaurant/lienzo', 'https://www.restaurantelienzo.com/', '+34 963 52 10 81', NULL, 'ChIJz02M-rFIYA0RJGbjth1LmEA'),
    ('rest_1733', 'Lillas Pastia', 1::smallint, 'Huesca', 'del Parque 3, 22002 Huesca', -0.4101935, 42.136332, 'https://guide.michelin.com/en/aragon/huesca/restaurant/lillas-pastia', 'https://www.lillaspastia.es', '+34 974 21 16 91', NULL, 'ChIJ17JQEEpEWA0R2drTwG2fqPY'),
    ('rest_1734', 'Llavor', 1::smallint, 'Oropesa del Mar', 'Plaza Islas Baleares 1, 12594 Oropesa del Mar', 0.1078286, 40.0647805, 'https://guide.michelin.com/en/comunidad-valenciana/oropesa-del-mar/restaurant/llavor', 'https://restaurantellavor.com/', '+34 676 69 64 88', NULL, 'ChIJq73m-6gFoBIR7jCqftx8tBs'),
    ('rest_1735', 'Lluerna', 1::smallint, 'Santa Coloma de Gramenet', 'Avenida Pallaresa 104, 08921 Santa Coloma de Gramenet', 2.2065622, 41.4554734, 'https://guide.michelin.com/en/catalunya/santa-coloma-de-gramenet/restaurant/lluerna', 'https://lluernarestaurant.com/', '+34 933 91 08 20', NULL, 'ChIJd44t9I68pBIRW2Jgo7sGy9E'),
    ('rest_1736', 'L''Ó', 1::smallint, 'Sant Fruitós de Bages', 'Camí de Sant Benet de Bages, 08272 Sant Fruitós de Bages', 1.9003874, 41.7448966, 'https://guide.michelin.com/en/catalunya/sant-fruitos-de-bages/restaurant/l-o', 'https://monstbenet.com/es/restaurantes/restaurante-lo/', '+34 938 75 94 29', NULL, 'ChIJJaQc_Ff3pBIR7YXKvD7qMs0'),
    ('rest_1737', 'Los Guayres', 1::smallint, 'Mogán', 'Avenida de los Marrero 2, 35138 Mogán', -15.7603459, 27.8223994, 'https://guide.michelin.com/en/canarias/mogan/restaurant/los-guayres', 'https://www.losguayres.com', '+34 928 72 41 00', NULL, 'ChIJi6U4tpOAQAwRb0njOj6AC9s'),
    ('rest_1738', 'Maca de Castro', 1::smallint, 'Port d''Alcúdia', 'Juno s/n, 07410 Port d''Alcúdia', 3.11829, 39.8343, 'https://guide.michelin.com/en/islas-baleares/port-d-alcdia/restaurant/maca-de-castro', 'https://www.macadecastro.com', '+34 971 89 23 91', NULL, 'ChIJA0koiuoslhIRExIrzbyyDs4'),
    ('rest_1739', 'MAE Barcelona', 1::smallint, 'Barcelona', 'Sant Elíes 22, 08006 Barcelona', 2.1444565, 41.4011914, 'https://guide.michelin.com/en/catalunya/barcelona/restaurant/mae-barcelona', 'https://maebcn.com/', '+34 645 73 62 83', NULL, 'ChIJjWu7nsuZpBIRgX4WmQwdOps'),
    ('rest_1740', 'Magoga', 1::smallint, 'Cartagena', 'Plaza Doctor Vicente García Marcos 5, 30201 Cartagena', -0.98376, 37.605446, 'https://guide.michelin.com/en/region-de-murcia/cartagena/restaurant/magoga', 'https://www.restaurantemagoga.com', '+34 629 98 02 57', NULL, 'ChIJ4_jwCCdCYw0RMNUaOB3y0fo'),
    ('rest_1741', 'Malak', 1::smallint, 'Jaén', 'Plaza de la Constitución 11, 23001 Jaén', -3.7873502, 37.767638, 'https://guide.michelin.com/en/andalucia/jaen/restaurant/malak', 'https://restaurantemalak.com/', '+34 687 01 86 20', NULL, 'ChIJbZeTpQDXbQ0RsQvNBPrUyBE'),
    ('rest_1742', 'Malena', 1::smallint, 'Gimenells', 'Carretera de Sucs, 25112 Gimenells', 0.3894688, 41.6563332, 'https://guide.michelin.com/en/catalunya/gimenells/restaurant/malena', NULL, '+34 973 74 85 23', NULL, 'ChIJp1zrEJQWpxIR28P4IC4qPwU'),
    ('rest_1743', 'Mantúa', 1::smallint, 'Jerez de la Frontera', 'Plaza Aladro 7, 11402 Jerez de la Frontera', -6.135958, 36.6874327, 'https://guide.michelin.com/en/andalucia/jerez-de-la-frontera/restaurant/mantua', 'https://www.restaurantemantua.com/', '+34 856 65 27 39', NULL, 'ChIJneTu6ZXGDQ0RA3sqA_aWp9w'),
    ('rest_1744', 'Marc Fosh', 1::smallint, 'Palma', 'De la Missió 7, 07003 Palma', 2.6513729, 39.5735982, 'https://guide.michelin.com/en/islas-baleares/palma/restaurant/marc-fosh', 'https://www.marcfosh.com/', '+34 971 72 01 14', NULL, 'ChIJp8jNHVGSlxIRcQ5-_4bPYBg'),
    ('rest_1745', 'Marcos', 1::smallint, 'Gijón', 'Cabrales 76, 33201 Gijón', -5.6601735, 43.5401186, 'https://guide.michelin.com/en/principado-de-asturias/gijon/restaurant/marcos', 'https://www.restaurantemarcos.com', '+34 984 00 75 80', NULL, 'ChIJkQs_fZN9Ng0RmmN0Or3kj6Y'),
    ('rest_1746', 'Mare', 1::smallint, 'Cádiz', 'Plaza de la Candelaria 12, 11005 Cádiz', -6.2955994, 36.5311693, 'https://guide.michelin.com/en/andalucia/cadiz/restaurant/mare-1213853', 'https://www.marerestaurante.com', '+34 628 68 80 30', NULL, 'ChIJ1-AX0HrRDQ0RVQ8s3qASKNo'),
    ('rest_1747', 'Maruja Limón', 1::smallint, 'Vigo', 'Montero Ríos 4, 36201 Vigo', -8.7238018, 42.2403767, 'https://guide.michelin.com/en/galicia/vigo/restaurant/maruja-limon', 'https://www.marujalimon.es', '+34 986 47 34 06', NULL, 'ChIJJf1xI0BiLw0RhdjnY7rAdJ0'),
    ('rest_1748', 'Massana', 1::smallint, 'Girona', 'Bonastruc de Porta 10-12, 17001 Girona', 2.81958, 41.98505, 'https://guide.michelin.com/en/catalunya/girona/restaurant/massana', 'https://www.restaurantmassana.com/', '+34 972 21 38 20', NULL, 'ChIJ1WHjceDmuhIRgdW3srr16BA'),
    ('rest_1749', 'Mesón Sabor Andaluz', 1::smallint, 'Alcalá del Valle', 'La Huerta 3, 11693 Alcalá del Valle', -5.1686392, 36.9008847, 'https://guide.michelin.com/en/andalucia/alcal-del-valle/restaurant/meson-sabor-andaluz', 'https://www.mesonsaborandaluz.com', '+34 956 13 55 10', NULL, 'ChIJTSGL-BNJDQ0RqyakkgaOoAA'),
    ('rest_1750', 'Messina', 1::smallint, 'Marbella', 'Avenida Severo Ochoa 12, 29603 Marbella', -4.8806499, 36.5084597, 'https://guide.michelin.com/en/andalucia/marbella/restaurant/messina', 'https://www.restaurantemessina.com', '+34 952 86 48 95', NULL, 'ChIJVWH3NvYncw0RYd7C6ytZxrc'),
    ('rest_1751', 'Miguel González', 1::smallint, 'Ourense', 'Avenida de Pontevedra 17, 32005 Ourense', -7.86502, 42.33592, 'https://guide.michelin.com/en/galicia/ourense/restaurant/miguel-gonzalez', 'https://restaurantemiguelgonzalez.com/', '+34 988 23 90 72', NULL, 'ChIJUXkEsW7-Lw0R-RXY4IKPoyw'),
    ('rest_1752', 'Mina', 1::smallint, 'Bilbao', 'Ercilla 37, 48011 Bilbao', -2.9385563, 43.2612715, 'https://guide.michelin.com/en/pais-vasco/bilbao/restaurant/mina', 'https://www.restaurantemina.es', '+34 944 79 59 38', NULL, 'ChIJff6iXMlPTg0RLNkfMmjmaZA'),
    ('rest_1753', 'Monte', 1::smallint, 'San Feliz', 'San Feliz, 33638 San Feliz', -5.8225128, 43.1685435, 'https://guide.michelin.com/en/principado-de-asturias/san-feliz/restaurant/monte-1190765', 'https://www.montesanfeliz.com/', '+34 659 59 66 66', NULL, 'ChIJj6eN3z_7Ng0RIrBc1jbrrbs'),
    ('rest_1754', 'Montia', 1::smallint, 'San Lorenzo de El Escorial', 'Juan de Austria 7, 28200 San Lorenzo de El Escorial', -4.1474372, 40.5925602, 'https://guide.michelin.com/en/comunidad-de-madrid/san-lorenzo-de-el-escorial/restaurant/montia-1196081', 'https://www.montia.es', '+34 911 33 69 88', NULL, 'ChIJV4HA3ygKQQ0RniTSMih24dY'),
    ('rest_1755', 'Mu•na', 1::smallint, 'Ponferrada', 'Gil y Carrasco 25, 24401 Ponferrada', -6.59309, 42.5434, 'https://guide.michelin.com/en/castilla-y-leon/ponferrada/restaurant/mu%E2%80%A2na', 'https://restaurantemuna.com/', '+34 693 76 23 70', NULL, 'ChIJ06J5C526MA0Rlj3y0tRfvBg'),
    ('rest_1756', 'Muxgo', 1::smallint, 'Las Palmas de Gran Canaria', 'León y Castillo 227, 35005 Las Palmas de Gran Canaria', -15.4279542, 28.1219882, 'https://guide.michelin.com/en/canarias/las-palmas-de-gran-canaria/restaurant/muxgo', 'https://www.muxgo.es', '+34 828 15 00 28', NULL, 'ChIJKTBugNiVQAwRZSc4n1eb_jQ'),
    ('rest_1757', 'Nerua Guggenheim Bilbao', 1::smallint, 'Bilbao', 'Avenida de Abandoibarra 2, 48009 Bilbao', -2.9323373, 43.2688701, 'https://guide.michelin.com/en/pais-vasco/bilbao/restaurant/nerua-guggenheim-bilbao', 'https://www.neruaguggenheimbilbao.com/', '+34 944 00 04 30', NULL, 'ChIJ1TWrrCZQTg0REIRME28oDuA'),
    ('rest_1758', 'Nintai', 1::smallint, 'Marbella', 'Ramón Gómez de la Serna 18B, 29602 Marbella', -4.8997997, 36.5097674, 'https://guide.michelin.com/en/andalucia/marbella/restaurant/nintai', 'https://www.restaurantenintai.com/', '+34 952 77 78 17', NULL, 'ChIJdwj_CzzXcg0RbVkvSWuwNTI'),
    ('rest_1759', 'Nova', 1::smallint, 'Ourense', 'Valle Inclán 5, 32004 Ourense', -7.8623301, 42.33977, 'https://guide.michelin.com/en/galicia/ourense/restaurant/nova', 'https://novarestaurante.com/', '+34 988 21 79 33', NULL, 'ChIJlbLiG8j-Lw0RWJjTTJV-qps'),
    ('rest_1760', 'Nub', 1::smallint, 'Adeje', 'Avenida de Bruselas, 38660 Adeje', -16.7352801, 28.089486, 'https://guide.michelin.com/en/canarias/adeje/restaurant/nub-1194862', 'https://www.nubrestaurante.com/', '+34 605 13 20 03', NULL, 'ChIJOXsLkcDNQQwRxgVyrfWO88Q'),
    ('rest_1761', 'Nublo', 1::smallint, 'Haro', 'Plaza de San Martín 5, 26200 Haro', -2.8465842, 42.5778988, 'https://guide.michelin.com/en/la-rioja/haro/restaurant/nublo', 'https://www.nublorestaurant.com/', '+34 636 72 58 50', NULL, 'ChIJvWlR24WLTw0RiaiPZRJF8c0'),
    ('rest_1762', 'Oba-', 1::smallint, 'Casas-Ibáñez', 'Tomás Pérez Úbeda 6, Planta 1, 02200 Casas-Ibáñez', -1.4694894, 39.2873133, 'https://guide.michelin.com/en/castilla-la-mancha/casas-ibanez/restaurant/oba', 'https://obarestaurante.es/', '+34 604 96 21 17', NULL, 'ChIJ_fEMf_rfZg0RI07QDOzqE5c'),
    ('rest_1763', 'Ochando', 1::smallint, 'Los Rosales', 'Sevilla 78, 41330 Los Rosales', -5.7333002, 37.5901344, 'https://guide.michelin.com/en/andalucia/los-rosales_3888074/restaurant/ochando', 'https://ochandorestaurante.com/', '+34 613 23 16 17', NULL, 'ChIJU4CgyMFZEg0RVuYZ6rkQ4h4'),
    ('rest_1764', 'O Eirado', 1::smallint, 'Pontevedra', 'Plaza da Leña 3, 36002 Pontevedra', -8.6434132, 42.4326366, 'https://guide.michelin.com/en/galicia/pontevedra/restaurant/eirado-da-lena', 'https://www.oeirado.com', '+34 986 86 02 25', NULL, 'ChIJ33xNfsZxLw0R_VlU-oT6B4A'),
    ('rest_1765', 'Ola Martín Berasategui', 1::smallint, 'Bilbao', 'Ribera 13, 48005 Bilbao', -2.9264328, 43.2579308, 'https://guide.michelin.com/en/pais-vasco/bilbao/restaurant/ola-martin-berasategui', 'https://olamartinberasategui.com', '+34 944 65 20 66', 'Tayko Bilbao', 'ChIJ1VbeTENPTg0Ri7NGFhyFCi4'),
    ('rest_1766', 'Omakase by Walt', 1::smallint, 'Eivissa', 'Canonge Joan Planells 8, 07800 Eivissa', 1.430802, 38.9077399, 'https://guide.michelin.com/en/islas-baleares/eivissa/restaurant/omakase-by-walt', 'https://www.sushibywalt.com', '+34 692 28 52 94', NULL, 'ChIJ9ShcaWZHmRIRC3rtZTTR4k8'),
    ('rest_1767', 'Origen', 1::smallint, 'Carcaixent', 'Avenida Germanies 3, 46740 Carcaixent', -0.4521044, 39.1193545, 'https://guide.michelin.com/en/comunidad-valenciana/carcaixent_1386765/restaurant/origen-1214557', 'https://www.origencarcaixent.com/', '+34 601 99 07 09', NULL, 'ChIJByIW_4SlYQ0R1DIIpnY-N7I'),
    ('rest_1768', 'Orobianco', 1::smallint, 'Calp', 'Colina del Sol 49 A, 03710 Calp', 0.0451019, 38.6665147, 'https://guide.michelin.com/en/comunidad-valenciana/calp/restaurant/orobianco', 'https://www.orobianco.es/', '+34 966 80 66 61', NULL, 'ChIJ8aIAUzsBnhIRAHkXywTPCXo'),
    ('rest_1769', 'OSA', 1::smallint, 'Madrid', 'Ribera del Manzanares 123, 28008 Madrid', -3.7327386, 40.4288531, 'https://guide.michelin.com/en/comunidad-de-madrid/madrid/restaurant/osa', 'https://www.osarestaurante.com', '+34 670 83 55 07', NULL, 'ChIJb8yyUbMpQg0RLtHW6aW7vR0'),
    ('rest_1770', 'Pablo', 1::smallint, 'León', 'Avenida Los Cubos 8, 24007 León', -5.5665652, 42.6004864, 'https://guide.michelin.com/en/castilla-y-leon/leon/restaurant/pablo', 'https://www.restaurantepablo.es', '+34 987 21 65 62', NULL, 'ChIJFR7rHseaNw0R0QL7VEAgZxY'),
    ('rest_1771', 'Pabú', 1::smallint, 'Madrid', 'Panamá 4, 28036 Madrid', -3.6891149, 40.4564116, 'https://guide.michelin.com/en/comunidad-de-madrid/madrid/restaurant/pabu', 'https://www.restaurantepabu.com/', '+34 689 69 67 26', NULL, 'ChIJl37AmnwpQg0R2pcFRgLqEBE'),
    ('rest_1772', 'Palodú', 1::smallint, 'Malaga', 'Sebastián Souvirón 7-9, 29005 Malaga', -4.4241615, 36.719137, 'https://guide.michelin.com/en/andalucia/malaga/restaurant/palodu', 'https://www.palodurestaurante.es', '+34 951 77 71 01', NULL, 'ChIJfyuBfj73cg0RclZpFzcq4EU'),
    ('rest_1773', 'Peix & Brases', 1::smallint, 'Dénia', 'Plaza de Benidorm 18, 03700 Dénia', 0.1079727, 38.8460357, 'https://guide.michelin.com/en/comunidad-valenciana/dnia/restaurant/peix-y-brases', 'https://www.peixibrases.com/', '+34 965 78 27 57', NULL, 'ChIJS3LRUhkbnhIRez6lBvUw6Yk'),
    ('rest_1774', 'Pico Velasco', 1::smallint, 'Carasa', 'Barrio Angustina, 39762 Carasa', -3.4447959, 43.3688338, 'https://guide.michelin.com/en/cantabria/carasa_7770389/restaurant/pico-velasco', 'https://www.picovelasco.com', '+34 842 84 11 11', NULL, 'ChIJbcDWQXDBTg0R6qTezimo2uw'),
    ('rest_1775', 'Poemas by Hermanos Padrón', 1::smallint, 'Las Palmas de Gran Canaria', 'León y Castillo 227, 35005 Las Palmas de Gran Canaria', -15.4272769, 28.1211968, 'https://guide.michelin.com/en/canarias/las-palmas-de-gran-canaria/restaurant/poemas-by-hermanos-padron', 'https://www.restaurantepoemas.com', '+34 928 24 30 41', NULL, 'ChIJhb8hvdCVQAwRga39T1jyqNA'),
    ('rest_1776', 'Prodigi', 1::smallint, 'Barcelona', 'Girona 145, 08037 Barcelona', 2.1658433, 41.3985291, 'https://guide.michelin.com/en/catalunya/barcelona/restaurant/prodigi', 'https://www.prodigi.cat', '+34 936 79 15 92', NULL, 'ChIJZ6c9NnyjpBIR1rxzO3DHze4'),
    ('rest_1777', 'Quatre Molins', 1::smallint, 'Cornudella de Montsant', 'Comte de Rius 8, 43360 Cornudella de Montsant', 0.9048932, 41.2646301, 'https://guide.michelin.com/en/catalunya/cornudella-de-montsant/restaurant/quatre-molins', 'https://quatremolins.com/', '+34 977 82 10 04', NULL, 'ChIJo_sKiVg1oRIR2d7WVP_mXEA'),
    ('rest_1778', 'Quimbaya', 1::smallint, 'Madrid', 'Zurbano 63, 28010 Madrid', -3.6930752, 40.436379, 'https://guide.michelin.com/en/comunidad-de-madrid/madrid/restaurant/quimbaya', 'https://quimbayarestaurant.com/', '+34 912 40 18 96', NULL, 'ChIJRxnN-xspQg0Rw7yGicV9UGM'),
    ('rest_1779', 'Quirat', 1::smallint, 'Barcelona', 'Avenida de Rius I Taulet 1, 08004 Barcelona', 2.154929, 41.3729244, 'https://guide.michelin.com/en/catalunya/barcelona/restaurant/quirat', 'https://quiratrestaurant.com/', '+34 934 26 22 23', 'Intercontinental Barcelona', 'ChIJcWTe2S2jpBIRJuBzwStkSGI'),
    ('rest_1780', 'Radis', 1::smallint, 'Jaén', 'Tableron 10, 23001 Jaén', -3.7863389, 37.7680566, 'https://guide.michelin.com/en/andalucia/jaen/restaurant/radis', 'https://restauranteradis.es/', '+34 953 33 79 89', NULL, 'ChIJ52xcUq_XbQ0RSxdk_rxjpSU'),
    ('rest_1781', 'Raíces-Carlos Maldonado', 1::smallint, 'Talavera de la Reina', 'Ronda de Cañillo 3, 45600 Talavera de la Reina', -4.8321518, 39.9565163, 'https://guide.michelin.com/en/castilla-la-mancha/talavera-de-la-reina/restaurant/raices-carlos-maldonado', 'https://raicescarlosmaldonado.es/', '+34 671 42 21 15', NULL, 'ChIJpwbsfgwcQA0RHzxz8Azk8Zc'),
    ('rest_1782', 'Raúl Resino', 1::smallint, 'Benicarló', 'Alacant 2, 12580 Benicarló', 0.4293978, 40.4221851, 'https://guide.michelin.com/en/comunidad-valenciana/benicarlo/restaurant/raul-resino', 'https://www.restauranteraulresino.com/', '+34 964 86 55 05', NULL, 'ChIJV4VR5aJFoBIR4Juzq61XzAI'),
    ('rest_1783', 'RavioXO', 1::smallint, 'Madrid', 'Plaza de Manuel Gómez Moreno 5, 28020 Madrid', -3.69463, 40.4479012, 'https://guide.michelin.com/en/comunidad-de-madrid/madrid/restaurant/ravioxo', 'https://www.ravioxo.com', '+34 917 64 89 92', NULL, 'ChIJw1etuCMpQg0RBhRII--BcQI'),
    ('rest_1784', 'Real Balneario', 1::smallint, 'Salinas', 'Avenida Juan Sitges 3, 33405 Salinas', -5.966378, 43.5776638, 'https://guide.michelin.com/en/principado-de-asturias/es-salinas/restaurant/real-balneario', 'https://www.realbalneario.com/es/', '+34 985 51 86 13', NULL, 'ChIJKeTo8RWcNg0RM1wtXt3RddU'),
    ('rest_1785', 'ReComiendo', 1::smallint, 'Córdoba', 'Mirto 7, 14012 Córdoba', -4.776105, 37.908204, 'https://guide.michelin.com/en/andalucia/cordoba/restaurant/recomiendo', 'https://www.recomiendopower.com/', '+34 957 10 73 51', NULL, 'ChIJ2dE_gHLfbA0RxjL5L2khycs'),
    ('rest_1786', 'Refectorio', 1::smallint, 'Sardón de Duero', 'Carretera N 122, 47340 Sardón de Duero', -4.4106521, 41.6156187, 'https://guide.michelin.com/en/castilla-y-leon/sardon-de-duero/restaurant/refectorio', 'https://www.abadia-retuerta.com/', NULL, NULL, 'ChIJ8YIynzodRw0RN04ny7TuCKg'),
    ('rest_1787', 'Regueiro', 1::smallint, 'Tox', 'Tox, 33793 Tox', -6.6367002, 43.5587943, 'https://guide.michelin.com/en/principado-de-asturias/tox/restaurant/regueiro', 'https://www.restauranteregueiro.es', '+34 985 64 85 94', NULL, 'ChIJ90du2h1ZMQ0RI4hhC_j0giM'),
    ('rest_1788', 'Retama', 1::smallint, 'Torrenueva', 'Camino  de Altamar, 13740 Torrenueva', -3.3095736, 38.6663677, 'https://guide.michelin.com/en/castilla-la-mancha/torrenueva/restaurant/retama', 'https://www.hotellacaminera.com', '+34 926 34 47 33', NULL, 'ChIJXW2Tuu4xaQ0RiX1sKglNCow'),
    ('rest_1789', 'Ricardo Temiño', 1::smallint, 'Burgos', 'San Juan 3, 09003 Burgos', -3.7002022, 42.3432013, 'https://guide.michelin.com/en/castilla-y-leon/burgos/restaurant/ricardo-temino', 'https://www.fabricarestaurante.com/ricardo-temino', '+34 947 04 04 20', NULL, 'ChIJn189LqD9RQ0RTTB23FTOuZ0'),
    ('rest_1790', 'Riff', 1::smallint, 'València', 'Conde de Altea 18, 46005 València', -0.3684603, 39.4657836, 'https://guide.michelin.com/en/comunidad-valenciana/valencia/restaurant/riff', 'https://www.restaurante-riff.com/', '+34 671 87 59 75', NULL, 'ChIJ_bUFI7ZIYA0RBGv2YwGXskw'),
    ('rest_1791', 'Rincón de Diego', 1::smallint, 'Cambrils', 'Drassanes 19, 43850 Cambrils', 1.0630578, 41.0667338, 'https://guide.michelin.com/en/catalunya/cambrils/restaurant/rincon-de-diego', 'https://www.rincondediego.com/', '+34 977 36 13 07', NULL, 'ChIJzTHb1i1boRIRzaIKuEjT7FA'),
    ('rest_1792', 'Rodero', 1::smallint, 'Pamplona', 'Emilio Arrieta 3, 31002 Pamplona', -1.6367286, 42.8160025, 'https://guide.michelin.com/en/comunidad-foral-de-navarra/pamplona/restaurant/rodero', 'https://restauranterodero.com/', '+34 948 22 80 35', NULL, 'ChIJNRZ9mgCTUA0RvF2gclvSRy8'),
    ('rest_1793', 'Rubén Miralles', 1::smallint, 'Vinaròs', 'Travessia de Sant Vicent 9, 12500 Vinaròs', 0.4746362, 40.4702712, 'https://guide.michelin.com/en/comunidad-valenciana/vinaros/restaurant/ruben-miralles', 'https://www.rubenmiralles.com', '+34 964 02 69 39', NULL, 'ChIJVX5ZenZPoBIR6Q1if6UnbZY'),
    ('rest_1794', 'Sa Clastra', 1::smallint, 'Es Capdellà', 'Carretera Es Capdellà, Km 1.7, 07196 Es Capdellà', 2.4800457, 39.5918479, 'https://guide.michelin.com/en/islas-baleares/es-capdella/restaurant/sa-clastra', 'https://www.castellsonclaret.com/gastronomia/restaurante-sa-clastra-alta-cocina-en-mallorca', '+34 971 13 86 27', NULL, 'ChIJH8Zsw_6LlxIRcsJ6gJNu6Xo'),
    ('rest_1795', 'Saddle', 1::smallint, 'Madrid', 'Amador de los Ríos 6, 28010 Madrid', -3.6911998, 40.4274475, 'https://guide.michelin.com/en/comunidad-de-madrid/madrid/restaurant/saddle', 'https://www.saddle-madrid.com', '+34 912 16 39 36', NULL, 'ChIJf6BKBFcpQg0R2JMv9g5gOyA'),
    ('rest_1796', 'Sala', 1::smallint, 'Olost', 'Plaza Major 17, 08516 Olost', 2.0956608, 41.9861944, 'https://guide.michelin.com/en/catalunya/olost/restaurant/sala', 'https://www.fondasala.com/', '+34 938 88 01 06', NULL, 'ChIJhUDJHy4ZpRIRDFBJ5M32r2Y'),
    ('rest_1797', 'San-Hô', 1::smallint, 'Adeje', 'Avenida Virgen de Guadalupe, 21, La Caleta, 38679 Adeje', -16.7536227, 28.1017164, 'https://guide.michelin.com/en/canarias/adeje/restaurant/san-ho', 'https://www.barcelo.com/es-es/royal-hideaway-corales-resort-2/gastrocorales/san-ho/', '+34 922 75 79 00', NULL, 'ChIJ7_h0vyiRagwRDhWEY9t0ML0'),
    ('rest_1798', 'Sen Omakase', 1::smallint, 'Madrid', 'Santa María Magdalena 14, 28016 Madrid', -3.6701712, 40.4622352, 'https://guide.michelin.com/en/comunidad-de-madrid/madrid/restaurant/sen-omakase', 'https://senomakase.com/', '+34 915 44 07 98', NULL, 'ChIJh12gFQApQg0R97bQnRmGqpU'),
    ('rest_1799', 'Silabario', 1::smallint, 'Vigo', 'Príncipe 44, Planta 6, 36202 Vigo', -8.7220499, 42.2363322, 'https://guide.michelin.com/en/galicia/vigo/restaurant/silabario', 'https://www.silabario.gal', '+34 986 07 73 63', NULL, 'ChIJ1fvRS2piLw0RuAhNR3uNuTs'),
    ('rest_1800', 'Simposio', 1::smallint, 'San Antonio de Benagéber', 'Moreras 2, 46184 San Antonio de Benagéber', -0.4991305, 39.5621719, 'https://guide.michelin.com/en/comunidad-valenciana/san-antonio-de-benageber_1388600/restaurant/simposio', 'https://rogerjulian.es/', '+34 655 38 11 99', NULL, 'ChIJA50zxwxbYA0Rh4vdxDkuuU8'),
    ('rest_1801', 'Solana', 1::smallint, 'Ampuero', 'La Bien Aparecida 11, 39849 Ampuero', -3.4531514, 43.3263141, 'https://guide.michelin.com/en/cantabria/ampuero/restaurant/solana', 'https://www.restaurantesolana.com', '+34 942 67 67 18', NULL, 'ChIJAe7gvk_CTg0RZWlUBgDvqRo'),
    ('rest_1802', 'Solla', 1::smallint, 'San Salvador de Poio', 'Avenida Sineiro 7, 36005 San Salvador de Poio', -8.6686035, 42.4334655, 'https://guide.michelin.com/en/galicia/san-salvador-de-poio/restaurant/solla', 'https://www.restaurantesolla.com', '+34 986 87 28 84', NULL, 'ChIJa7ERgiRuLw0RG8-XvnH445o'),
    ('rest_1803', 'Sollo', 1::smallint, 'Fuengirola', 'Avenida del Higuerón 48, 29640 Fuengirola', -4.5956774, 36.5809892, 'https://guide.michelin.com/en/andalucia/fuengirola/restaurant/sollo', 'https://www.sollo.es', '+34 692 42 53 85', NULL, 'ChIJezXuFzx2LxURgLw_P3n5zLo'),
    ('rest_1804', 'Suto', 1::smallint, 'Barcelona', 'Violant de Hungría Reina de Aragón 134, 08028 Barcelona', 2.1334655, 41.379936, 'https://guide.michelin.com/en/catalunya/barcelona/restaurant/suto', NULL, '+34 610 90 86 51', NULL, 'ChIJv31mchmZpBIRwcQH2AzA_RE'),
    ('rest_1805', 'Tabaiba', 1::smallint, 'Las Palmas de Gran Canaria', 'Portugal 79, 35010 Las Palmas de Gran Canaria', -15.4397592, 28.1353754, 'https://guide.michelin.com/en/canarias/las-palmas-de-gran-canaria/restaurant/tabaiba', NULL, '+34 928 02 70 55', NULL, 'ChIJ93sdTHWVQAwRyETTKEH56KQ'),
    ('rest_1806', 'Taller Arzuaga', 1::smallint, 'Quintanilla de Onésimo', 'Carretera N-122, 47350 Quintanilla de Onésimo', -4.3237821, 41.6280676, 'https://guide.michelin.com/en/castilla-y-leon/quintanilla-de-onesimo/restaurant/taller', 'https://www.tallerarzuaga.com/', '+34 983 68 11 46', NULL, 'ChIJseWhBL3jRg0RFw86Ei44ME4'),
    ('rest_1807', 'Taste 1973', 1::smallint, 'Playa de las Américas', 'Avenida de Rafael Puig Lluvina 38, 38650 Playa de las Américas', -16.7348606, 28.0561987, 'https://guide.michelin.com/en/canarias/playa-de-las-americas/restaurant/taste-1973', NULL, '+34 922 75 77 00', NULL, 'ChIJtbSR-gWXagwRYmh0HmMAvJY'),
    ('rest_1808', 'Tatau', 1::smallint, 'Huesca', 'Azara, 22002 Huesca', -0.4084429, 42.1385269, 'https://guide.michelin.com/en/aragon/huesca/restaurant/tatau', 'https://www.tatau.es', '+34 974 04 20 78', NULL, 'ChIJvV3J20lEWA0R1Wwy9plja1M'),
    ('rest_1809', 'Tayta by Víctor Gutiérrez', 1::smallint, 'Salamanca', 'Empedrada 4, 37007 Salamanca', -5.6703452, 40.9630387, 'https://guide.michelin.com/en/castilla-y-leon/salamanca/restaurant/victor-gutierrez', 'https://taytarestaurante.com/', '+34 923 26 29 73', NULL, 'ChIJ87xD1WomPw0RIkty_jC7eSw'),
    ('rest_1810', 'Toki', 1::smallint, 'Madrid', 'Sagasta 28, 28004 Madrid', -3.6972754, 40.42788, 'https://guide.michelin.com/en/comunidad-de-madrid/madrid/restaurant/toki-1205025', 'https://restaurantetoki.com', '+34 918 02 28 16', NULL, 'ChIJlayPgPMpQg0RTfnpWV0v1bg'),
    ('rest_1811', 'Tresmacarrons', 1::smallint, 'El Masnou', 'Avenida del Maresme 21, 08320 El Masnou', 2.3326156, 41.4831336, 'https://guide.michelin.com/en/catalunya/el-masnou/restaurant/tresmacarrons', 'https://www.tresmacarrons.com', '+34 935 40 92 66', NULL, 'ChIJV7dpq9ywpBIRInmPsN6Rgf8'),
    ('rest_1812', 'Trigo', 1::smallint, 'Valladolid', 'Jorge Guillén 6, 47003 Valladolid', -4.730628, 41.654679, 'https://guide.michelin.com/en/castilla-y-leon/valladolid/restaurant/trigo', 'https://www.restaurantetrigo.com/', '+34 983 11 55 00', NULL, 'ChIJmRnTabISRw0RHIPn57YZYDM'),
    ('rest_1813', 'Tula', 1::smallint, 'Xàbia', 'Avenida de la Llibertat 36, 03730 Xàbia', 0.1925837, 38.7707289, 'https://guide.michelin.com/en/comunidad-valenciana/xbia/restaurant/tula', 'https://www.tularestaurante.com/', '+34 966 47 17 45', NULL, 'ChIJweqhqPsOnhIRNCqMNYXKU7M'),
    ('rest_1814', 'Ugo Chan', 1::smallint, 'Madrid', 'Félix Boix 6, 28036 Madrid', -3.6881793, 40.4633289, 'https://guide.michelin.com/en/comunidad-de-madrid/madrid/restaurant/ugo-chan', 'https://www.ugochan.com', '+34 913 50 65 78', NULL, 'ChIJh67g7DApQg0RNGfPlGDvLg4'),
    ('rest_1815', 'Unic', 1::smallint, 'Sant Josep de sa Talaia', 'Les Begònies 18, 07817 Sant Josep de sa Talaia', 1.4077202, 38.8898956, 'https://guide.michelin.com/en/islas-baleares/sant-josep-de-sa-talaia/restaurant/unic', 'https://www.unicrestaurantibiza.com', '+34 971 30 45 26', NULL, 'ChIJt9yIeyxEmRIRtjCLULPn59A'),
    ('rest_1816', 'Vandelvira', 1::smallint, 'Baeza', 'Plaza de San Francisco, 23440 Baeza', -3.4689799, 37.9941772, 'https://guide.michelin.com/en/andalucia/baeza/restaurant/vandelvira', 'https://vandelvirarestaurante.es/', '+34 681 98 21 57', NULL, 'ChIJt4SN9eaLbg0Ry7l08xk4U4Y'),
    ('rest_1817', 'VelascoAbellà', 1::smallint, 'Madrid', 'Víctor Andrés Belaúnde 25, 28016 Madrid', -3.6797233, 40.4559644, 'https://guide.michelin.com/en/comunidad-de-madrid/madrid/restaurant/velascoabella', 'https://www.velascoabella.com', '+34 915 66 97 40', NULL, 'ChIJ47mISlQpQg0RM1RQwirQGsw'),
    ('rest_1818', 'Versátil', 1::smallint, 'Zarza de Granadilla', 'Lagar 6, 10710 Zarza de Granadilla', -6.0476206, 40.2372182, 'https://guide.michelin.com/en/extremadura/zarza-de-granadilla/restaurant/versatil', 'https://versatilrural.com/', '+34 927 48 62 36', NULL, 'ChIJ8QmRTx9CPg0R--Vd5o9iGAE'),
    ('rest_1819', 'Vértigo', 1::smallint, 'Sober', 'Doade, 27424 Sober', -7.4764957, 42.4087961, 'https://guide.michelin.com/en/galicia/sober_3313368/restaurant/vertigo-1205008', 'https://www.restaurantevertigo.com', '+34 621 23 59 78', NULL, 'ChIJCbLeRXINMA0RdZ9PN7yKRxg'),
    ('rest_1820', 'Via Veneto', 1::smallint, 'Barcelona', 'Ganduxer 10, 08021 Barcelona', 2.1388292, 41.3924041, 'https://guide.michelin.com/en/catalunya/barcelona/restaurant/via-veneto', 'https://www.viavenetobarcelona.com/', '+34 932 00 72 44', NULL, 'ChIJI8Kpv3CYpBIRgYfrEaTZnyc'),
    ('rest_1821', 'Villa Retiro', 1::smallint, 'Xerta', 'Dels Molins 2, 43592 Xerta', 0.4902255, 40.9123115, 'https://guide.michelin.com/en/catalunya/xerta/restaurant/villa-retiro', 'https://hotelvillaretiro.com/', '+34 977 47 38 10', 'Villa Retiro', 'ChIJz3bczPjmoBIR66AWaZCJV8Q'),
    ('rest_1822', 'Voramar', 1::smallint, 'Portbou', 'Passeig de la Sardana 6, 17497 Portbou', 3.1615535, 42.4265274, 'https://guide.michelin.com/en/catalunya/portbou/restaurant/voramar', 'https://www.voramarportbou.com/', '+34 972 39 00 16', NULL, 'ChIJjf_U9R58uhIRM5DBJs7vYSM'),
    ('rest_1823', 'Yayo Daporta', 1::smallint, 'Cambados', 'Hospital 7, 36630 Cambados', -8.8148041, 42.5128612, 'https://guide.michelin.com/en/galicia/cambados/restaurant/yayo-daporta', 'https://yayodaporta.com/', '+34 986 52 60 62', NULL, 'ChIJOzPUZLhqLw0RkdwjW8CG8ko'),
    ('rest_1824', 'Yugo The Bunker', 1::smallint, 'Madrid', 'San Blas 4, 28014 Madrid', -3.694612, 40.410625, 'https://guide.michelin.com/en/comunidad-de-madrid/madrid/restaurant/yugo', 'https://yugothebunker.com/', '+34 914 44 90 34', NULL, 'ChIJx8vqfrAoQg0RMc6ahl5daPk'),
    ('rest_1825', 'Zaranda', 1::smallint, 'Palma', 'Bala Roja 1, 07001 Palma', 2.6554437, 39.5657787, 'https://guide.michelin.com/en/islas-baleares/palma/restaurant/zaranda-1191909', 'https://www.zaranda.es', '+34 680 60 25 80', NULL, 'ChIJ96dh0IwoQg0RVQTtUBZwfOs'),
    ('rest_1826', 'Zarate', 1::smallint, 'Bilbao', 'Alameda San Mamés 28, 48010 Bilbao', -2.937087, 43.258953, 'https://guide.michelin.com/en/pais-vasco/bilbao/restaurant/zarate', 'https://zarate.restaurant/', '+34 944 41 65 21', NULL, 'ChIJw0URXy9QTg0RSRH7KYSpJgE');

do $$
declare bad text;
begin
  select string_agg(n.name || ' (' || n.city || ')', ', ') into bad from _new n
   where (select count(*) from public.cities c where c.country_code = 'ES' and c.name = n.city) <> 1;
  if bad is not null then raise exception 'city does not resolve to exactly one ES row (run the migration first?): %', bad; end if;
  select string_agg(n.name, ', ') into bad from _new n join public.restaurants r on r.michelin_url = n.michelin_url;
  if bad is not null then raise exception 'restaurant already present (michelin_url): %', bad; end if;
  select string_agg(n.name, ', ') into bad from _new n join public.restaurants r on r.google_place_id = n.place_id;
  if bad is not null then raise exception 'Place ID already used by another restaurant: %', bad; end if;
end $$;

insert into public.restaurants
  (restaurant_code, name, michelin_stars, inclusion_reason, city_id, country_code,
   address, location, michelin_url, website_url, phone, property_name, google_place_id)
select n.code, n.name, n.stars, 'michelin_star',
       (select c.id from public.cities c where c.country_code = 'ES' and c.name = n.city),
       'ES', n.address, ST_SetSRID(ST_MakePoint(n.lon, n.lat), 4326)::geography,
       n.michelin_url, n.website_url, n.phone, n.property_name, n.place_id
from _new n;

insert into public.award_history
  (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on)
select 'restaurant', r.id, 2026, 'michelin_stars', n.stars, true, date '2025-11-25'
from _new n join public.restaurants r on r.restaurant_code = n.code;

-- 2. links to Key hotels
create temp table _links (hotel_code text, restaurant_code text, confidence text, evidence text) on commit drop;
insert into _links values
    ('hotel_523', 'rest_1631', 'campus', 'MICHELIN restaurant page: ''Stay at the hotel'' -> guide.michelin.com/en/hotels-stays/huesca/canfranc-estacion-a-royal-hideaway-hotel-13117 (Canfranc Estación, a Royal Hideaway Hotel, MICHELIN Key on that page); MICHELIN hotel pin 47 m from hotel_523; restaurant pin 280 m from it. 2026-10-28.'),
    ('hotel_474', 'rest_1659', 'exact', 'MICHELIN restaurant page: ''Stay at the hotel'' -> guide.michelin.com/en/hotels-stays/majorca/el-llorenc-parc-de-la-mar-adults-only-9395 (El Llorenç Parc de la Mar, MICHELIN Key on that page); MICHELIN hotel pin 17 m from hotel_474; restaurant pin 8 m from it. 2026-10-28.'),
    ('hotel_545', 'rest_1702', 'campus', 'MICHELIN restaurant page: ''Stay at the hotel'' -> guide.michelin.com/en/hotels-stays/tenerife/royal-hideaway-corales-suites-10348 (Royal Hideaway Corales Resort, MICHELIN Key on that page); MICHELIN hotel pin 14 m from hotel_545; restaurant pin 248 m from it. 2026-10-28.'),
    ('hotel_483', 'rest_1744', 'exact', 'MICHELIN restaurant page: ''Stay at the hotel'' -> guide.michelin.com/en/hotels-stays/majorca/convent-de-la-missio-grand-luxury-boutique-hotel-6707-7476 (Convent de La Missió, Grand Luxury Boutique Hotel, MICHELIN Key on that page); MICHELIN hotel pin 13 m from hotel_483; restaurant pin 10 m from it. 2026-10-28.'),
    ('hotel_522', 'rest_1756', 'exact', 'MICHELIN restaurant page: ''Stay at the hotel'' -> guide.michelin.com/en/hotels-stays/gran-canaria/santa-catalina-a-royal-hideaway-hotel-13700 (Santa Catalina, a Royal Hideaway Hotel, MICHELIN Key on that page); MICHELIN hotel pin 26 m from hotel_522; restaurant pin 79 m from it. 2026-10-28.'),
    ('hotel_524', 'rest_1760', 'campus', 'MICHELIN restaurant page: ''Stay at the hotel'' -> guide.michelin.com/en/hotels-stays/tenerife/bahia-del-duque-13701 (Bahia del Duque, MICHELIN Key on that page); MICHELIN hotel pin 74 m from hotel_524; restaurant pin 789 m from it. 2026-10-28.'),
    ('hotel_522', 'rest_1775', 'exact', 'MICHELIN restaurant page: ''Stay at the hotel'' -> guide.michelin.com/en/hotels-stays/gran-canaria/santa-catalina-a-royal-hideaway-hotel-13700 (Santa Catalina, a Royal Hideaway Hotel, MICHELIN Key on that page); MICHELIN hotel pin 26 m from hotel_522; restaurant pin 90 m from it. 2026-10-28.'),
    ('hotel_484', 'rest_1786', 'exact', 'MICHELIN restaurant page: ''Stay at the hotel'' -> guide.michelin.com/en/hotels-stays/valladolid2/abadia-retuerta-ledomaine-10200 (Abadía Retuerta LeDomaine, MICHELIN Key on that page); MICHELIN hotel pin 30 m from hotel_484; restaurant pin 59 m from it. 2026-10-28.'),
    ('hotel_526', 'rest_1788', 'campus', 'MICHELIN restaurant page: ''Stay at the hotel'' -> guide.michelin.com/en/hotels-stays/torrenueva/la-caminera-9664 (Hotel La Caminera Club de Campo, MICHELIN Key on that page); MICHELIN hotel pin 115 m from hotel_526; restaurant pin 109 m from it. 2026-10-28.'),
    ('hotel_510', 'rest_1794', 'exact', 'MICHELIN restaurant page: ''Stay at the hotel'' -> guide.michelin.com/en/hotels-stays/majorca/castell-son-claret-10110 (Castell Son Claret, MICHELIN Key on that page); MICHELIN hotel pin 0 m from hotel_510; restaurant pin 54 m from it. 2026-10-28.'),
    ('hotel_545', 'rest_1797', 'campus', 'MICHELIN restaurant page: ''Stay at the hotel'' -> guide.michelin.com/en/hotels-stays/tenerife/royal-hideaway-corales-suites-10348 (Royal Hideaway Corales Resort, MICHELIN Key on that page); MICHELIN hotel pin 14 m from hotel_545; restaurant pin 198 m from it. 2026-10-28.'),
    ('hotel_539', 'rest_0349', 'exact', 'MICHELIN restaurant page: ''Stay at the hotel'' -> guide.michelin.com/en/hotels-stays/majorca/cap-vermell-grand-hotel-118902-8439 (Cap Vermell Grand Hotel, MICHELIN Key on that page); MICHELIN hotel pin 132 m from hotel_539; restaurant pin 10 m from it. 2026-10-28.'),
    ('hotel_511', 'rest_1825', 'exact', 'MICHELIN restaurant page: ''Stay at the hotel'' -> guide.michelin.com/en/hotels-stays/majorca/es-princep-9273 (Es Princep, MICHELIN Key on that page); MICHELIN hotel pin 2 m from hotel_511; restaurant pin 21 m from it. 2026-10-28.');

do $$
declare bad text;
begin
  select string_agg(l.hotel_code, ', ') into bad from _links l
   where not exists (select 1 from public.hotels h where h.hotel_code = l.hotel_code and h.country_code = 'ES');
  if bad is not null then raise exception 'unknown ES hotel codes: %', bad; end if;
end $$;

insert into public.hotel_restaurants (hotel_id, restaurant_id, link_confidence, evidence, verified_at)
select h.id, r.id, l.confidence, l.evidence, now()
from _links l
join public.hotels h on h.hotel_code = l.hotel_code
join public.restaurants r on r.restaurant_code = l.restaurant_code
on conflict (hotel_id, restaurant_id) do nothing;

-- 3. existing rows, fill-only
create temp table _fill (code text primary key, michelin_url text, phone text, property_name text) on commit drop;
insert into _fill values
    ('rest_0002', NULL, '+34 933 19 66 00', NULL),
    ('rest_0334', NULL, '+34 943 31 12 09', NULL),
    ('rest_0344', 'https://guide.michelin.com/en/catalunya/barcelona/restaurant/aleia', '+34 935 02 00 41', NULL),
    ('rest_0377', 'https://guide.michelin.com/en/castilla-y-leon/penafiel/restaurant/ambivium', '+34 983 88 19 38', NULL),
    ('rest_0354', 'https://guide.michelin.com/en/pais-vasco/es-donostia-san-sebastian/restaurant/amelia-1191398', '+34 943 84 56 47', NULL),
    ('rest_0335', NULL, '+34 943 27 84 65', NULL),
    ('rest_0350', NULL, '+34 927 24 29 28', NULL),
    ('rest_0338', NULL, '+34 944 55 83 59', NULL),
    ('rest_0370', 'https://guide.michelin.com/en/andalucia/ronda/restaurant/bardal', '+34 951 48 98 28', NULL),
    ('rest_0376', 'https://guide.michelin.com/en/comunidad-valenciana/xbia/restaurant/bonamb', '+34 965 08 44 40', NULL),
    ('rest_0352', 'https://guide.michelin.com/en/catalunya/corca/restaurant/bo-tic', '+34 972 63 08 69', NULL),
    ('rest_0355', 'https://guide.michelin.com/en/region-de-murcia/region-de-murcia-el-palmar/restaurant/cabana-buenavista', '+34 968 88 90 06', NULL),
    ('rest_0341', NULL, '+34 985 84 09 91', NULL),
    ('rest_0340', NULL, '+34 942 50 82 43', NULL),
    ('rest_0345', 'https://guide.michelin.com/en/catalunya/barcelona/restaurant/cinc-sentits', '+34 933 23 94 90', NULL),
    ('rest_0361', 'https://guide.michelin.com/en/comunidad-de-madrid/madrid/restaurant/coque', '+34 916 04 02 02', NULL),
    ('rest_0367', 'https://guide.michelin.com/en/galicia/o-grove/restaurant/culler-de-pau', '+34 986 73 22 75', NULL),
    ('rest_0044', NULL, NULL, 'NH Collection Madrid Eurobuilding'),
    ('rest_0362', 'https://guide.michelin.com/en/comunidad-de-madrid/madrid/restaurant/dstage', '+34 917 02 15 86', NULL),
    ('rest_0337', NULL, '+34 972 22 21 57', NULL),
    ('rest_0357', 'https://guide.michelin.com/en/la-rioja/ezcaray/restaurant/el-portal', '+34 941 35 40 47', NULL),
    ('rest_0342', 'https://guide.michelin.com/en/canarias/adeje/restaurant/el-rincon-de-juan-carlos-1194880', '+34 922 86 80 40', NULL),
    ('rest_0346', 'https://guide.michelin.com/en/catalunya/barcelona/restaurant/enoteca204150', '+34 934 83 81 08', NULL),
    ('rest_0374', 'https://guide.michelin.com/en/comunidad-valenciana/valencia/restaurant/flores-raras', '+34 961 11 11 06', NULL),
    ('rest_0372', 'https://guide.michelin.com/en/castilla-la-mancha/es-toledo/restaurant/ivan-cerdeno', '+34 925 22 36 74', NULL),
    ('rest_0348', 'https://guide.michelin.com/en/catalunya/bellvis/restaurant/la-boscana', '+34 973 56 55 75', NULL),
    ('rest_0058', NULL, '+34 934 45 32 42', NULL),
    ('rest_0351', 'https://guide.michelin.com/en/comunidad-valenciana/cocentaina/restaurant/l-escaleta', '+34 965 59 21 00', NULL),
    ('rest_0368', 'https://guide.michelin.com/en/catalunya/olot/restaurant/les-cols', '+34 972 26 92 09', NULL),
    ('rest_0359', 'https://guide.michelin.com/en/andalucia/jerez-de-la-frontera/restaurant/lu-cocina-y-alma', '+34 695 40 84 81', NULL),
    ('rest_0343', 'https://guide.michelin.com/en/castilla-la-mancha/almansa/restaurant/maralba', '+34 967 31 23 26', NULL),
    ('rest_0339', NULL, '+34 943 36 64 71', NULL),
    ('rest_0358', 'https://guide.michelin.com/en/canarias/gua-de-isora/restaurant/m-b', '+34 922 12 60 00', 'The Ritz-Carlton Tenerife, Abama'),
    ('rest_0360', 'https://guide.michelin.com/en/catalunya/llan/restaurant/miramar', '+34 972 38 01 32', NULL),
    ('rest_0373', 'https://guide.michelin.com/en/comunidad-foral-de-navarra/urdaitz/restaurant/el-molino-de-urdaniz', '+34 948 30 41 09', NULL),
    ('rest_0067', NULL, '+34 931 51 87 81', NULL),
    ('rest_0347', 'https://guide.michelin.com/en/catalunya/barcelona/restaurant/mont-bar', '+34 933 23 95 90', NULL),
    ('rest_0356', 'https://guide.michelin.com/en/pais-vasco/errenteria/restaurant/mugaritz', NULL, NULL),
    ('rest_0332', NULL, '+34 957 96 40 55', NULL),
    ('rest_0363', 'https://guide.michelin.com/en/comunidad-de-madrid/madrid/restaurant/la-terraza-del-casino', '+34 915 32 12 75', NULL),
    ('rest_0369', 'https://guide.michelin.com/en/galicia/raxo-%28san-gregorio%29_1412090/restaurant/pepe-vieira', '+34 986 74 13 78', NULL),
    ('rest_0364', 'https://guide.michelin.com/en/comunidad-de-madrid/madrid/restaurant/ramon-freixa-atelier', '+34 603 96 12 93', NULL),
    ('rest_0371', 'https://guide.michelin.com/en/galicia/santa-comba/restaurant/retiro-da-costina', '+34 981 88 02 44', NULL),
    ('rest_0375', 'https://guide.michelin.com/en/comunidad-valenciana/valencia/restaurant/ricard-camarena', '+34 963 35 54 18', NULL),
    ('rest_0366', 'https://guide.michelin.com/en/andalucia/marbella/restaurant/skina', '+34 952 76 52 77', NULL),
    ('rest_0365', 'https://guide.michelin.com/en/comunidad-de-madrid/madrid/restaurant/smoked-room', '+34 911 08 62 77', NULL),
    ('rest_0353', 'https://guide.michelin.com/en/la-rioja/daroca-de-rioja/restaurant/venta-moncalvillo', '+34 941 44 48 32', NULL),
    ('rest_0349', 'https://guide.michelin.com/en/islas-baleares/canyamel/restaurant/voro', '+34 871 81 13 50', NULL);

do $$
declare bad text;
begin
  select string_agg(f.code, ', ') into bad from _fill f
    join public.restaurants r on r.michelin_url = f.michelin_url and r.restaurant_code <> f.code;
  if bad is not null then raise exception 'michelin_url already used by another row: %', bad; end if;
end $$;

update public.restaurants r set michelin_url = f.michelin_url, updated_at = now()
  from _fill f where r.restaurant_code = f.code and f.michelin_url is not null and r.michelin_url is null;
update public.restaurants r set phone = f.phone, updated_at = now()
  from _fill f where r.restaurant_code = f.code and f.phone is not null and r.phone is null;
update public.restaurants r set property_name = f.property_name, updated_at = now()
  from _fill f where r.restaurant_code = f.code and f.property_name is not null and r.property_name is null
   and not exists (select 1 from public.hotel_restaurants hr where hr.restaurant_id = r.id);

-- Deessa: stored link 404s; replace only if it is still the broken value.
update public.restaurants set michelin_url = 'https://guide.michelin.com/en/comunidad-de-madrid/madrid/restaurant/deessa', updated_at = now()
 where restaurant_code = 'rest_0042' and michelin_url = 'https://guide.michelin.com/nl/nl/madrid/madrid/restaurant/deesa';

-- Post-conditions: production's ES rows equal MICHELIN's live 2026 listing.
do $$
declare n int;
begin
  select count(*) into n from public.restaurants where country_code = 'ES' and michelin_stars = 3;
  if n <> 16 then raise exception 'ES: expected 16 three-star, found %', n; end if;
  select count(*) into n from public.restaurants where country_code = 'ES' and michelin_stars = 2;
  if n <> 37 then raise exception 'ES: expected 37 two-star, found %', n; end if;
  select count(*) into n from public.restaurants where country_code = 'ES' and michelin_stars = 1;
  if n <> 243 then raise exception 'ES: expected 243 one-star, found %', n; end if;
  select count(*) into n from public.restaurants r
   where r.country_code = 'ES'
     and (select count(*) from public.award_history ah
           where ah.entity_type = 'restaurant' and ah.entity_id = r.id
             and ah.award_type = 'michelin_stars' and ah.is_current) <> 1;
  if n <> 0 then raise exception '% ES restaurants do not have exactly one current star row', n; end if;
  select count(*) into n from public.restaurants r
    join public.award_history ah on ah.entity_type = 'restaurant' and ah.entity_id = r.id
                                and ah.award_type = 'michelin_stars' and ah.is_current
   where r.country_code = 'ES' and ah.award_value is distinct from r.michelin_stars;
  if n <> 0 then raise exception '% ES restaurants disagree with their current award_history row', n; end if;
  select count(*) into n from public.restaurants r
   where r.country_code = 'ES' and r.property_name is not null
     and exists (select 1 from public.hotel_restaurants hr where hr.restaurant_id = r.id);
  if n <> 0 then raise exception '% ES restaurants have both a Key-hotel link and a property_name', n; end if;
end $$;

commit;
