-- PREPARED -- NOT APPLIED.
--
-- MICHELIN 2026 Key hotels, Portugal (MICHELIN's global Key article of 18 Sep 2026:
-- "Portugal - 69 Key hotels"). Production holds no Portuguese hotel (export of
-- 2026-11-01), so all 69 are added (hotel_2810..hotel_2878): 2 Three-Key, 14 Two-Key,
-- 53 One-Key, each with a current 2026 michelin_keys row (announced 2026-09-18),
-- the same shape as the 2026 Key refresh for IT/ES/DE/Benelux.
--
-- Sources: guide.michelin.com/en/hotels-stays/portugal (225 cards; 69 Portuguese Key
-- cards -- The Little Nell, Aspen, appears on every listing and is not counted,
-- QA-389) and each hotel's own page (JSON-LD award, which agrees with the card on all
-- 69; name = h1; address, pin, phone). Unlike the earlier Key refresh this file also
-- writes, fill-only, Google Place ID (65), phone (64) and website
-- (65): Place ID = the hotel's own Google lodging record within 100 m of
-- MICHELIN's pin; phone = MICHELIN and Google agreeing, or printed on the official
-- site; website = the confirmed record's link, loading and naming the hotel, or (for
-- 16 sites that block automated fetches) carrying the hotel's name in its URL.
-- Evidence per row: pt_key_hotels_2026.csv.
--
-- PREREQUISITES, in order: supabase/migrations/20261031160000_add_pt_2026_star_cities.sql,
-- then supabase/migrations/20261031170000_add_pt_key_hotel_cities.sql.
-- One transaction; every check raises and rolls the whole file back.

begin;

do $$
declare n int;
begin
  if exists (select 1 from public.hotels where hotel_code ~ '^hotel_[0-9]+$'
              and substring(hotel_code from 7)::int between 2810 and 2878) then
    raise exception 'codes hotel_2810..hotel_2878 are no longer free -- re-check';
  end if;
  select count(*) into n from public.hotels where country_code = 'PT';
  if n <> 0 then raise exception 'expected no Portuguese hotels (export of 2026-11-01), found %', n; end if;
end $$;

create temp table _new_pt_hotels (code text, name text, keys smallint, city text, address text, lon float8, lat float8,
                                  michelin_url text, place_id text, phone text, website text) on commit drop;
insert into _new_pt_hotels values
    ('hotel_2810', '3HB Faro', 1::smallint, 'Faro', 'Rua Vasco da Gama nº33, 8000-442 Faro', -7.93232, 37.01682, 'https://guide.michelin.com/en/hotels-stays/Faro/3hb-faro-12597', 'ChIJx9Oia3BTBQ0RGgNdD9_YDcA', '+351 289 240 000', 'https://3hb.com/home/3hb-faro/?partner=6259&utm_source=google&utm_medium=organic&utm_campaign=MyBusiness&utm'),
    ('hotel_2811', 'Aethos Ericeira', 1::smallint, 'Encarnação', 'R. da Estalagem, 2640-255, 2640-255 Encarnação', -9.417126, 39.034499, 'https://guide.michelin.com/en/hotels-stays/encarnacao/aethos-ericeira-12640', 'ChIJ6-JqfsclHw0RvNGX8kXL8H8', '+351 261 244 510', 'https://www.aethos.com/destinations/ericeira'),
    ('hotel_2812', 'Areias do Seixo', 1::smallint, 'Santa Cruz', 'Praceta do Atlantico – Mexilhoeira, A dos Cunhados e Maceira, 2560-046 Santa Cruz', -9.362714, 39.153293, 'https://guide.michelin.com/en/hotels-stays/Santa%20Cruz/areias-do-seixo-5811', 'ChIJARTtA4EwHw0RtOuvkVnfrOs', '+351 261 936 350', 'http://www.areiasdoseixo.com/'),
    ('hotel_2813', 'Art Legacy Hotel Baixa-Chiado', 1::smallint, 'Lisbon', 'Rua Áurea 175-181, 1149-021 Lisbon', -9.13881, 38.71105, 'https://guide.michelin.com/en/hotels-stays/lisbon/art-legacy-hotel-baixa-chiado-14519', 'ChIJa21C3ng0GQ0RChtYxppynhI', '+351 21 145 3090', 'http://www.artlegacyhotels.com/'),
    ('hotel_2814', 'Bairro Alto Hotel', 1::smallint, 'Lisbon', 'Praca Luis de Camões No. 2, 1200-243 Lisbon', -9.143333, 38.710278, 'https://guide.michelin.com/en/hotels-stays/lisbon/bairro-alto-hotel-424', 'ChIJr78TU340GQ0RAEUOr_Glzgw', '+351 21 340 8288', 'https://www.bairroaltohotel.com/'),
    ('hotel_2815', 'Bela Vista Hotel & Spa', 2::smallint, 'Portimão', 'Av. Tomás Cabreira, Praia da Rocha, 8500-802 Portimão', -8.537467, 37.118533, 'https://guide.michelin.com/en/hotels-stays/portimao/bela-vista-hotel-spa-6546', 'ChIJlaNBwOIoGw0RHGQJj6u8qlA', '+351 282 460 280', 'https://www.hotelbelavista.net/'),
    ('hotel_2816', 'Brown''s Avenue Hotel', 1::smallint, 'Lisbon', '48 Rua Rodrigues Sampaio, 1150-280 Lisbon', -9.14572, 38.72206, 'https://guide.michelin.com/en/hotels-stays/lisbon/browns-avenue-hotel-14518', 'ChIJc5J8_TkzGQ0RBBhEiHdiDRY', '+351 21 098 8970', 'https://www.brownshotelgroup.com/browns-avenue/'),
    ('hotel_2817', 'Casa da Calçada', 2::smallint, 'Amarante', 'Largo do Paço, Nº6, 4600-017 Amarante', -8.0778409288, 41.2682993244, 'https://guide.michelin.com/en/hotels-stays/amarante/casa-da-calcada-15704', 'ChIJk9LeC_Y1GQ0Rv18OevpPUO0', '+351 255 410 830', 'http://www.casadacalcada.com/'),
    ('hotel_2818', 'Casa das Penhas Douradas', 1::smallint, 'Manteigas', 'Penhas Douradas, 6260 - 200 Manteigas', -7.56776, 40.40822, 'https://guide.michelin.com/en/hotels-stays/manteigas/casa-das-penhas-douradas-14491', 'ChIJ8SnWarvYPA0RkPEhDrxJtPE', '+351 275 981 045', 'http://www.casadaspenhasdouradas.pt/'),
    ('hotel_2819', 'Casa de São Lourenço', 1::smallint, 'Manteigas', 'Estrada Nacional 232, Km 49.3, 6260-200 Manteigas', -7.539849, 40.418738, 'https://guide.michelin.com/en/hotels-stays/manteigas/casa-de-sao-lourenco-9256', 'ChIJPx8BmdPZPA0RHx28B5dQ-ps', '+351 275 249 730', 'https://casadesaolourenco.pt/'),
    ('hotel_2820', 'Casas da Lapa, Nature & Spa Hotel', 1::smallint, 'Seia', 'Rua Eira Costa, 10, Lapa dos Dinheiros, 6270-651 Seia', -7.707519, 40.377046, 'https://guide.michelin.com/en/hotels-stays/Seia/casas-da-lapa-nature-spa-hotel-12972', 'ChIJta7r7QcqPQ0RR4ezq6XRW2w', '+351 934 560 401', 'http://www.casasdalapa.pt/'),
    ('hotel_2821', 'Colégio Charm House', 1::smallint, 'Tavira', 'Rua Chefe António Afonso nº1, 8800-636 Tavira', -7.653594, 37.127313, 'https://guide.michelin.com/en/hotels-stays/tavira/colegio-charm-house-12751', 'ChIJg0YimFsDEA0RplqTJq2YREc', '+351 912 061 961', 'https://colegio-charmhouse.com/'),
    ('hotel_2822', 'Conversas de Alpendre', 1::smallint, 'Vila Nova de Cacela', 'Estrada de Santa Rita, nº 36, 8900-059 Vila Nova de Cacela', -7.568118, 37.173378, 'https://guide.michelin.com/en/hotels-stays/vila-nova-de-cacela/conversas-de-alpendre-11818', 'ChIJsQdv_wcbEA0R6auIWF54kJM', '+351 910 035 704', 'http://www.conversasdealpendre.com/'),
    ('hotel_2823', 'Four Seasons Hotel Ritz Lisbon', 2::smallint, 'Lisbon', 'Rua Rodrigo da Fonseca, 88, 1900-123 Lisbon', -9.15533, 38.72561, 'https://guide.michelin.com/en/hotels-stays/lisbon/four-seasons-hotel-ritz-lisbon-12766', 'ChIJ-x5EtnEzGQ0R8am5BtQUOLs', '+351 21 381 1400', 'https://www.fourseasons.com/lisbon/'),
    ('hotel_2824', 'GA Palace', 1::smallint, 'Porto', 'Rua Alexandre Herculano 311, 4000-053 Porto', -8.60543, 41.14412, 'https://guide.michelin.com/en/hotels-stays/porto/ga-palace-hotel-spa-a-xixth-century-villa-14493', 'ChIJc7menOZlJA0RINkTezYLruE', '+351 22 098 7250', 'https://gapalacehotel.com/'),
    ('hotel_2825', 'Herdade da Malhadinha Nova', 1::smallint, 'Beja', 'Herdade da Malhadinha Nova, 7800-601 Beja', -7.978345, 37.821373, 'https://guide.michelin.com/en/hotels-stays/beja/herdade-de-malhadinha-nova-11446', 'ChIJbfzpdONkGg0RZITScMc_mgI', '+351 284 965 432', 'https://www.malhadinhanova.pt/pt/'),
    ('hotel_2826', 'Hospes Infante Sagres', 1::smallint, 'Porto', 'Praça D. Filipa de Lencastre 62, 4050-259 Porto', -8.6129918865, 41.1480682842, 'https://guide.michelin.com/en/hotels-stays/porto/hospes-infante-sagres-porto-17314', 'ChIJUfTSI-NkJA0RoiVXwkNNgjk', '+351932025474', 'https://www.infantesagres.com/'),
    ('hotel_2827', 'Les Suites at The Cliff Bay - PortoBay', 2::smallint, 'Funchal', 'Estrada Monumental, Sao Martinho, 9004-532 Funchal', -16.9258, 32.63927, 'https://guide.michelin.com/en/hotels-stays/funchal/les-suites-at-the-cliff-bay-portobay-14492', 'ChIJjUJVyvBfYAwRVgmL85fago0', '+351 291 707 770', 'https://www.portobay.com/en/hotels/madeira-hotels/les-suites-at-the-cliff-bay/'),
    ('hotel_2828', 'MS Collection Aveiro - Palacete Valdemouro', 1::smallint, 'Aveiro', '50 Rua José Estevão, 3800-201 Aveiro', -8.65288, 40.6425, 'https://guide.michelin.com/en/hotels-stays/Aveiro-1/ms-collection-aveiro-palacete-valdemouro-13715', 'ChIJUxX7BLaZIw0RWBVWSX4Dr_0', '+351 234 245 630', 'https://www.mscollection.pt/aveiro'),
    ('hotel_2829', 'Octant Douro', 1::smallint, 'Castelo de Paiva', 'Km 41 R. Vista Alegre, 4550-631 Castelo de Paiva', -8.351272, 41.038198, 'https://guide.michelin.com/en/hotels-stays/castelo-de-paiva/octant-hotels-douro-9149', 'ChIJ7UZ-ygqDJA0RceIRNviwUlg', '+351 255 690 160', 'http://www.douro.octanthotels.com/'),
    ('hotel_2830', 'Octant Praia Verde', 1::smallint, 'Altura', 'Urbanização Praia Verde, 8950-434 Altura', -7.4822055, 37.1798579, 'https://guide.michelin.com/en/hotels-stays/altura/octant-praia-verde-15527', 'ChIJe03KJeIYEA0Ri28w74uIHFg', '+351 281 530 600', 'http://www.praiaverde.octanthotels.com/'),
    ('hotel_2831', 'Palacete Severo', 1::smallint, 'Porto', 'Rua de Ricardo Severo 21, 4050-515 Porto', -8.6253522135, 41.1561143287, 'https://guide.michelin.com/en/hotels-stays/porto/palacete-severo-15207', 'ChIJEUiEsgllJA0RUrUTM5CcJLY', '+351 22 967 7000', 'https://palacetesevero.com/'),
    ('hotel_2832', 'Palácio de Tavira', 1::smallint, 'Tavira', 'Praça Doutor António Padinha 35, 8800-549 Tavira', -7.649369, 37.128352, 'https://guide.michelin.com/en/hotels-stays/tavira/palacio-de-tavira-16823', 'ChIJ7RgKr_4DEA0Rbe2IKYwnT_g', '+351 281 512 600', 'https://www.palaciodetavira.com/?utm_source=google&utm_medium=organic&utm_campaign=gmb_profile&utm_content=website'),
    ('hotel_2833', 'Palácio Ludovice Wine Experience Hotel', 1::smallint, 'Lisbon', 'Rua de São Pedro de Alcântara 39-49, 1250-237 Lisbon', -9.1441, 38.71408, 'https://guide.michelin.com/en/hotels-stays/lisbon/palacio-ludovice-wine-experience-hotel-14520', 'ChIJcdXUhdYzGQ0R-_plDS7F0OU', '+351 21 151 3850', 'http://www.palacioludovice.com/?utm_source=gbp'),
    ('hotel_2834', 'Penha Longa Resort', 3::smallint, 'Sintra', 'Estrada da Lagoa Azul, Linhó, 2714-511 Sintra', -9.396923, 38.761532, 'https://guide.michelin.com/en/hotels-stays/sintra/penha-longa-resort-14501', 'ChIJfQ5Ozl0zGQ0RU_13ryv_nyo', '+351 21 924 9011', 'https://www.ritzcarlton.com/en/hotels/lisrz-penha-longa-resort/overview/?scid=f2ae0541-1279-4f24-b197-a979c79310b0'),
    ('hotel_2835', 'PortoBay Flores', 1::smallint, 'Porto', 'Rua das Flores, 27, 4050-416 Porto', -8.614135, 41.144544, 'https://guide.michelin.com/en/hotels-stays/porto/portobay-flores-12216', 'ChIJCxvBXYVlJA0R5nCLrNx-DlQ', '00 351 220 047 000', 'https://www.portobay.com/en/hotels/porto-hotels/portobay-flores/'),
    ('hotel_2836', 'Pousada de Lisboa, Praça do Comércio', 1::smallint, 'Lisbon', 'Praça do Comércio, 31-34, VAT 502 812 974, 1100-148 Lisbon', -9.137707, 38.708206, 'https://guide.michelin.com/en/hotels-stays/lisbon/pousada-de-lisboa-praca-do-comercio-7949', 'ChIJCwpQv3A0GQ0RMdLtcXXgSBM', '+351 21 040 7640', 'https://www.pousadas.pt/en/hotel/pousada-lisboa?utm_source=google-my-business&utm_medium=organicsearch&utm_campaign=pousada-lisboa-partoo'),
    ('hotel_2837', 'Praia do Canal Nature Retreat', 1::smallint, 'Aljezur', 'Herdade Vale dos Polvos, Valinhos, 8670-156 Aljezur', -8.8317316, 37.2609722, 'https://guide.michelin.com/en/hotels-stays/aljezur/praia-do-canal-nature-resort-15656', NULL, NULL, NULL),
    ('hotel_2838', 'Quinta da Casa Branca', 1::smallint, 'Funchal', 'Rua da Casa Branca 7, 51410 Funchal', -16.927243, 32.641797, 'https://guide.michelin.com/en/hotels-stays/funchal/quinta-da-casa-branca-1821', 'ChIJX4nWsvFfYAwRnBZNkS2XBhY', '+351 291 700 770', 'http://www.quintacasabranca.com/'),
    ('hotel_2839', 'Quinta de São Bernardo Winery & Farmhouse', 1::smallint, 'Mesão Frio', 'Caminho do rio 33, 5040-428 Mesão Frio', -7.88642, 41.1448, 'https://guide.michelin.com/en/hotels-stays/Mes%C3%A3o%20Frio/quinta-de-sbernardo-winery-farmhouse-12431', 'ChIJXRBs8m6uJA0RqQ84877oGE8', '+351 967 293 773', 'http://www.quintadesaobernardo.com/'),
    ('hotel_2840', 'Quinta de Silvalde', 1::smallint, 'Santo Tirso', 'Rua de Silvalde 126, 4780-067 Santo Tirso', -8.474963, 41.361493, 'https://guide.michelin.com/en/hotels-stays/Santo%20Tirso/quinta-de-silvalde-14071', 'ChIJfw92OiL1JA0RwcmiO79dmeo', '+351252034140', 'https://www.quintadesilvalde.pt/'),
    ('hotel_2841', 'Quinta do Paral', 2::smallint, 'Vidigueira', 'Quinta do Paral, Selmes, 7960-131 Vidigueira', -7.83251, 38.17731, 'https://guide.michelin.com/en/hotels-stays/Vidigueira/quinta-do-paral-14400', NULL, NULL, NULL),
    ('hotel_2842', 'Quinta São Jose do Barrilario Douro Wine Hotel e Spa', 1::smallint, 'Armamar', 'São Joaninho Vacalar, 5110-662 Armamar', -7.69588, 41.13587, 'https://guide.michelin.com/en/hotels-stays/Armamar/quinta-sao-jose-do-barrilario-douro-wine-hotel-e-spa-14494', 'ChIJpcL-ZxtROw0R9h4dglun_Wg', '+351 254 103 328', 'https://barrilario.com/'),
    ('hotel_2843', 'Reid''s Palace, A Belmond Hotel, Madeira', 2::smallint, 'Funchal', 'Estrada Monumental, 139, 9000-098 Funchal', -16.923988, 32.640588, 'https://guide.michelin.com/en/hotels-stays/madeira/reids-palace-a-belmond-hotel-madeira-6371', 'ChIJFXOVoPBfYAwRJ5wDs8h_jHc', '+351 291 717 171', 'https://www.belmond.com/hotels/europe/portugal/madeira/belmond-reids-palace/?utm_source=local_search&utm_medium=link&utm_campaign=google_business'),
    ('hotel_2844', 'Salvaterra Country House & SPA', 1::smallint, 'Salvaterra de Magos', '839 N114-3, Foros de Salvaterra, 2120-194 Salvaterra de Magos', -8.732031, 38.997104, 'https://guide.michelin.com/en/hotels-stays/salvaterra-de-magos/salvaterra-country-house-spa-11886', 'ChIJUaW7asnjGA0RO_n4S35li2s', '+351 915 355 566', 'http://www.salvaterracountryhouse.com/'),
    ('hotel_2845', 'Santiago de Alfama - Boutique Hotel', 1::smallint, 'Lisbon', 'Rua de Santiago 10 a 14, 1100-494 Lisbon', -9.131215, 38.711435, 'https://guide.michelin.com/en/hotels-stays/lisbon/santiago-de-alfama-boutique-hotel-8830', 'ChIJr7oI-HY0GQ0RrpAGemhK6YE', '+351 21 394 1616', 'https://www.santiagodealfama.com/'),
    ('hotel_2846', 'São Lourenço do Barrocal', 1::smallint, 'Monsaraz', 'São Lourenço do Barrocal, 7200-177 Monsaraz', -7.417591, 38.443208, 'https://guide.michelin.com/en/hotels-stays/monsaraz/sao-lourenco-do-barrocal-11836', NULL, NULL, NULL),
    ('hotel_2847', 'Savoy Palace', 1::smallint, 'Funchal', 'Av. do Infante 25, Funchal', -16.920868, 32.643586, 'https://guide.michelin.com/en/hotels-stays/madeira/savoy-palace-13747', 'ChIJj1rAHPtfYAwRSqtuFknRw4I', '+351 291 213 000', 'https://www.savoysignature.com/savoypalacehotel/en/?utm_source=google&utm_medium=googlemybusiness&utm_campaign=savoypalace'),
    ('hotel_2848', 'Six Senses Douro Valley', 2::smallint, 'Lamego', 'Quinta de Vale Abraão, Samodães, 5100-758 Lamego', -7.812248, 41.144198, 'https://guide.michelin.com/en/hotels-stays/lamego/six-senses-douro-valley-1901', 'ChIJUZmnMbytJA0RwaQ8WYQJLKM', '+351 254 660 600', 'https://www.sixsenses.com/en/hotels-resorts/europe/portugal/douro-valley/'),
    ('hotel_2849', 'Spatia Comporta', 1::smallint, 'Comporta', 'Estrada das Bicas, Marco da Saibreira, Bicas, 7570-337 Comporta', -8.633806, 38.26473, 'https://guide.michelin.com/en/hotels-stays/comporta/spatia-comporta-11624', 'ChIJV7wCda7XGw0RhN-w9r8SiUI', '+351 269 249 486', 'http://www.spatiacomporta.com/'),
    ('hotel_2850', 'Sublime Comporta', 1::smallint, 'Comporta', 'EN 261-1, Muda, 7570-337 Comporta', -8.70096, 38.27894, 'https://guide.michelin.com/en/hotels-stays/comporta/sublime-comporta-7703', NULL, NULL, NULL),
    ('hotel_2851', 'Sublime Lisboa', 1::smallint, 'Lisbon', 'Rua Marques Subserra 10, 1070-012 Lisbon', -9.157059, 38.725623, 'https://guide.michelin.com/en/hotels-stays/lisbon/sublime-lisboa-123233-13219', 'ChIJUwkn9mEzGQ0RBqVG5_4k9eo', '+351 21 846 2121', 'https://www.sublimelisboa.pt/'),
    ('hotel_2852', 'The Largo', 1::smallint, 'Porto', 'Largo de São Domingos, 60, 4050-545 Porto', -8.6148194423, 41.143207, 'https://guide.michelin.com/en/hotels-stays/porto/the-largo-15117', 'ChIJIwN3lXplJA0RUs5bljfAz-E', '+351 22 976 0000', 'http://www.thelargo.com/'),
    ('hotel_2853', 'The Lince Braga', 1::smallint, 'Braga', 'Estr. Via Falperra EN 309, 4715-390 Braga', -8.389428, 41.520594, 'https://guide.michelin.com/en/hotels-stays/Braga/the-lince-braga-15843', 'ChIJBwMthEX7JA0Rg9Qs-sqQFMI', '+351 253 402 000', 'https://thelincehotels.com/braga/'),
    ('hotel_2854', 'The Lince Santa Clara', 2::smallint, 'Vila do Conde', 'Mosteiro de Santa Clara, Largo Dom Afonso Sanches, 4480-754 Vila do Conde', -8.73943, 41.353, 'https://guide.michelin.com/en/hotels-stays/Vila%20do%20Conde/the-lince-santa-clara-125128-14443', 'ChIJ28CAugBFJA0RzP-cAC6-Uzc', '+351 252 035 300', 'http://www.thelincehotels.com/santaclara'),
    ('hotel_2855', 'The One Monumental Palace', 1::smallint, 'Porto', '151 Avenida dos Aliados, 4000-196 Porto', -8.61142, 41.14839, 'https://guide.michelin.com/en/hotels-stays/porto/le-monumental-palace-10607', 'ChIJ_9W8ZwhlJA0REyPO0-_EFBs', '+351 22 766 2410', 'https://www.hotelstheone.com/en/porto-hotels/the-one-monumental-palace?utm_source=google_my_business&utm_medium=boton_sitio_web&utm_campaign=tmp'),
    ('hotel_2856', 'The One Palácio da Anunciada', 1::smallint, 'Lisbon', 'R. das Portas de Santo Antão 112-134, 1150-268 Lisbon', -9.141468, 38.717367, 'https://guide.michelin.com/en/hotels-stays/lisbon/the-one-palacio-da-anunciada-9196', 'ChIJJfYxTW4zGQ0Ryd8m_V8eIOM', '+351 21 041 2300', 'https://www.hotelstheone.com/en/lisbon-hotels/the-one-palacio-da-anunciada?utm_source=google_my_business&utm_medium=boton_sitio_web&utm_campaign=hpa'),
    ('hotel_2857', 'The Reserve Hotel', 2::smallint, 'Funchal', 'Avenida do Infante Nº 25 B, Funchal', -16.92107, 32.643655, 'https://guide.michelin.com/en/hotels-stays/madeira/the-reserve-hotel-13744', 'ChIJ-aGONtJfYAwRCgMcb6om9Rw', '291213000', 'https://www.savoysignature.com/thereservehotel/en'),
    ('hotel_2858', 'The Wine House Hotel - Quinta da Pacheca', 1::smallint, 'Lamego', 'Quinta Da Pacheca, Cambres, 5100-424 Lamego', -7.79846, 41.15572, 'https://guide.michelin.com/en/hotels-stays/lamego/the-wine-house-hotel-quinta-da-pacheca-12025', 'ChIJOaQMDN2sJA0RJI50A1jmUHI', '+351 254 331 229', 'https://quintadapacheca.com/pages/quintadapacheca'),
    ('hotel_2859', 'The Yeatman', 1::smallint, 'Vila Nova de Gaia', 'Rua do Choupelo, Santa Marinha, 4400-088 Vila Nova de Gaia', -8.61309, 41.1337, 'https://guide.michelin.com/en/hotels-stays/Vila-Nova-de-Gaia/the-yeatman-11004', 'ChIJM8ql2NhkJA0RpK5JhEV2Saw', '+351 22 013 3100', 'https://www.the-yeatman-hotel.com/?utm_source=Google&utm_medium=Organic&utm_campaign=GMB'),
    ('hotel_2860', 'Tivoli Kopke Porto Gaia', 1::smallint, 'Vila Nova de Gaia', 'Rua do Barão de Forrester 69, 4400-0034 Vila Nova de Gaia', -8.6174759035, 41.1344660923, 'https://guide.michelin.com/en/hotels-stays/Vila-Nova-de-Gaia/tivoli-kopke-porto-gaia-15673', 'ChIJZb1Wu6plJA0Rzi_G-4TkNXA', '+351 22 410 5600', 'https://www.tivolihotels.com/en/tivoli-kopke-porto-gaia?utm_campaign=local-gmb&utm_medium=organic_search&utm_source=google_gmb'),
    ('hotel_2861', 'Torel 1884', 1::smallint, 'Porto', 'R. de Mouzinho da Silveira N 228, 4050-417 Porto', -8.612592, 41.143702, 'https://guide.michelin.com/en/hotels-stays/porto/torel-1884-9352', 'ChIJp0cze-FkJA0Rvkhq3CjbkQg', '+351 22 600 1783', 'http://www.torel1884.com/'),
    ('hotel_2862', 'Torel Avantgarde', 1::smallint, 'Porto', 'Rua da Restauração 336, 4050-501 Porto', -8.622546, 41.145792, 'https://guide.michelin.com/en/hotels-stays/porto/hotel-torel-avantgarde-9354', 'ChIJ9WyVnhtlJA0RLKZtFkA4Fnc', '+351 22 011 0082', 'http://www.torelavantgarde.com/'),
    ('hotel_2863', 'Torel Palace Lisbon', 1::smallint, 'Lisbon', 'R. Câmara Pestana 23, 1150-082 Lisbon', -9.140064, 38.718157, 'https://guide.michelin.com/en/hotels-stays/lisbon/torel-palace-9351', 'ChIJrxPSrIYzGQ0RF_Ce6MczlP0', '+351 21 829 0810', 'http://www.torelpalacelisbon.com/'),
    ('hotel_2864', 'Torel Palace Porto', 1::smallint, 'Porto', 'Rua de Entreparedes 40, 4050-240 Porto', -8.605855, 41.145197, 'https://guide.michelin.com/en/hotels-stays/porto/torel-palace-porto-9353', 'ChIJYYNjb3tlJA0R2leA3yfqMCs', '+351 22 609 0559', 'http://www.torelpalaceporto.com/'),
    ('hotel_2865', 'Torel Quinta da Vacaria - Douro Valley', 1::smallint, 'Peso da Régua', 'Rua de Vilarinho dos Freires, 5050-364 Peso da Régua', -7.76914, 41.15493, 'https://guide.michelin.com/en/hotels-stays/Peso%20da%20R%C3%A9gua/torel-quinta-da-vacaria-douro-valley-14495', 'ChIJnwB0XV5TOw0RIruTsfQuoSs', NULL, 'https://www.torelquintadavacaria.com/'),
    ('hotel_2866', 'Torel Saboaria', 1::smallint, 'Porto', 'Rua do Bonjardim 564, 4000-118 Porto', -8.6083439423, 41.1513455393, 'https://guide.michelin.com/en/hotels-stays/porto/torel-saboaria-15485', 'ChIJzdfpzPtkJA0RE-4sr3nv8iI', '+351 22 318 7016', 'https://www.torelsaboaria.com/'),
    ('hotel_2867', 'Torre de Palma Wine Hotel', 2::smallint, 'Monforte', '7450 Herdade de Torre de Palma, 250, 7450-250 Monforte', -7.488911, 39.068323, 'https://guide.michelin.com/en/hotels-stays/monforte/torre-de-palma-wine-hotel-8218', 'ChIJiwU9s3J1Fw0RSfQq1m7kl9o', '+351 245 038 890', 'https://www.torredepalma.com/'),
    ('hotel_2868', 'Vermelho Melides', 2::smallint, 'Melides', 'Rua Doutor Evaristo Sousa Gago nº2, 7570-635 Melides', -8.72797, 38.14611, 'https://guide.michelin.com/en/hotels-stays/Melides/vermelho-melides-13109', 'ChIJ71qg3wDSGw0REW83OI8DJew', '+351 915 280 511', 'https://www.vermelhohotel.com/?utm_source=google&utm_medium=maps&utm_campaign=mybusiness&utm_content=vermelho'),
    ('hotel_2869', 'Viceroy at Ombria Algarve', 1::smallint, 'Loulé', 'Rua da Ombria 9, 8100-396 Loulé', -8.012676, 37.191098, 'https://guide.michelin.com/en/hotels-stays/loule/viceroy-at-ombria-algarve-125179-14490', 'ChIJSZ3DHRSxGg0RknUIEX4OZe8', '+351 289 078 300', 'https://www.viceroyhotelsandresorts.com/ombria-algarve?utm_source=google-gbp&utm_medium=organic&utm_campaign=gbp'),
    ('hotel_2870', 'Vidago Palace', 2::smallint, 'Vidago', 'Parque de Vidago, Apartado 16', -7.575469, 41.632859, 'https://guide.michelin.com/en/hotels-stays/norte/vidago-palace-7618', 'ChIJ3e7GNFMmOw0Rf9kZQ8y6PR0', '+351 276 990 920', 'https://www.vidagopalace.com/'),
    ('hotel_2871', 'Vila Foz', 1::smallint, 'Porto', 'Av. Montevideu, 236, 4150-516 Porto', -8.684647, 41.161426, 'https://guide.michelin.com/en/hotels-stays/porto/vila-foz-hotel-spa-9157', 'ChIJo73XAA1vJA0Ren6trqlHRIk', '+351 22 244 9700', 'http://www.vilafozhotel.pt/'),
    ('hotel_2872', 'Vila Joya', 2::smallint, 'Albufeira', 'Estrada da Galé, 8200-416 Albufeira', -8.313732, 37.080053, 'https://guide.michelin.com/en/hotels-stays/albufeira/vila-joya-7487', 'ChIJi9jPs0rTGg0RLT27vOaUYqY', '+351 289 591 795', 'http://www.vilajoya.com/'),
    ('hotel_2873', 'Vilalara Grand Hotel Algarve', 1::smallint, 'Armação de Pêra', 'Praia das Gaivotas - Alporchinhos Porches, 8400-450 Armação de Pêra', -8.38022, 37.09928, 'https://guide.michelin.com/en/hotels-stays/armacao-de-pera/vilalara-grand-hotel-algarve-10379', 'ChIJqZ57hkPRGg0Ry5cdqsuAXpk', '+351 282 320 000', 'https://www.vilalara.com/'),
    ('hotel_2874', 'Vila Vita Parc Resort & Spa', 3::smallint, 'Alporchinhos', 'R. Anneliese Pohl, 8400-450 Alporchinhos', -8.37945, 37.1019, 'https://guide.michelin.com/en/hotels-stays/alporchinhos/vila-vita-parc-11366', 'ChIJX4iNCUTRGg0RSrvhjFgQ3VE', '+351 282 310 100', 'https://vilavitaparc.com/'),
    ('hotel_2875', 'Vinha Boutique Hotel', 2::smallint, 'Vila Nova de Gaia', '383 R. Fonte da Vinha, 4430-487 Vila Nova de Gaia', -8.57506, 41.132418, 'https://guide.michelin.com/en/hotels-stays/Vila-Nova-de-Gaia/vinha-boutique-hotel-13045', 'ChIJBZtUj1JlJA0RX6mSQ7od8Xo', '+351 22 115 4120', 'http://www.vinhaboutiquehotel.com/'),
    ('hotel_2876', 'White Exclusive Suites & Villas', 1::smallint, 'Ponta Delgada', 'Rua. da Rocha Quebrada 10, 9560-420 Ponta Delgada', -25.596592, 37.746051, 'https://guide.michelin.com/en/hotels-stays/ponta-delgada/white-exclusive-suite-villas-8721', 'ChIJMddg3Y3VXAsRZuuujcbqFu0', '+351 296 249 153', 'http://www.whiteazores.com/'),
    ('hotel_2877', 'Wine & Books Lisboa', 1::smallint, 'Lisbon', '56 Travessa da Memória, 1300-403 Lisbon', -9.202193, 38.702162, 'https://guide.michelin.com/en/hotels-stays/lisbon/wine-books-lisboa-15378', 'ChIJofH0-SzLHg0Rx6FQYWwXaHU', '+351 21 156 6250', 'https://lisboa.winebookshotels.com/'),
    ('hotel_2878', 'Wine & Books Porto', 1::smallint, 'Porto', 'Rua de José Falcão, 4050-390 Porto', -8.614388, 41.148299, 'https://guide.michelin.com/en/hotels-stays/porto/wine-books-porto-15373', 'ChIJi0jZP6hlJA0RymumT0rxBx4', '+351 22 244 3750', 'https://porto.winebookshotels.com/');

do $$
declare bad text;
begin
  select string_agg(x.name || ' (' || x.city || ')', ', ') into bad from _new_pt_hotels x
   where (select count(*) from public.cities c where c.country_code = 'PT' and c.name = x.city) <> 1;
  if bad is not null then raise exception 'city does not resolve to exactly one PT row (run both migrations first): %', bad; end if;
  select string_agg(x.name, ', ') into bad from _new_pt_hotels x join public.hotels h on h.michelin_url = x.michelin_url;
  if bad is not null then raise exception 'hotel already present (michelin_url): %', bad; end if;
  select string_agg(x.name, ', ') into bad from _new_pt_hotels x join public.hotels h on h.google_place_id = x.place_id;
  if bad is not null then raise exception 'Place ID already used by another hotel: %', bad; end if;
end $$;

insert into public.hotels (hotel_code, name, michelin_keys, city_id, country_code, address, location, michelin_url,
                           google_place_id, phone, website_url)
select x.code, x.name, x.keys,
       (select c.id from public.cities c where c.country_code = 'PT' and c.name = x.city), 'PT',
       x.address, ST_SetSRID(ST_MakePoint(x.lon, x.lat), 4326)::geography, x.michelin_url,
       x.place_id, x.phone, x.website
  from _new_pt_hotels x;

insert into public.award_history (entity_type, entity_id, guide_year, award_type, award_value, is_current, announced_on)
select 'hotel', h.id, 2026, 'michelin_keys', h.michelin_keys, true, date '2026-09-18'
  from public.hotels h join _new_pt_hotels x on x.code = h.hotel_code;

do $$
declare n int;
begin
  select count(*) into n from public.hotels where country_code = 'PT' and michelin_keys is not null;
  if n <> 69 then raise exception 'PT: expected 69 Key hotels, found %', n; end if;
  select count(*) into n from public.hotels where country_code = 'PT' and michelin_keys = 3;
  if n <> 2 then raise exception 'PT: expected 2 3-Key hotels, found %', n; end if;
  select count(*) into n from public.hotels where country_code = 'PT' and michelin_keys = 2;
  if n <> 14 then raise exception 'PT: expected 14 2-Key hotels, found %', n; end if;
  select count(*) into n from public.hotels where country_code = 'PT' and michelin_keys = 1;
  if n <> 53 then raise exception 'PT: expected 53 1-Key hotels, found %', n; end if;
  select count(*) into n from public.hotels h where h.country_code = 'PT'
     and (select count(*) from public.award_history a where a.entity_type = 'hotel' and a.entity_id = h.id
           and a.award_type = 'michelin_keys' and a.is_current and a.award_value = h.michelin_keys) <> 1;
  if n <> 0 then raise exception 'PT: % hotels without exactly one current Key row equal to michelin_keys', n; end if;
end $$;

commit;
