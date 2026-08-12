-- PREPARED -- NOT APPLIED.
--
-- Belgium/France Michelin bulk-location expansion: BE restaurant +
-- award_history + hotel_restaurants import for the
-- 100 READY_TO_IMPORT BE candidates (see
-- supabase/data/enrichment/michelin_be_fr_pre_import/BE_FR_PRE_IMPORT_REPORT.md).
--
-- Deliberately NOT placed under supabase/migrations/ -- an unrelated
-- `supabase db push` must not be able to apply this by accident.
--
-- COUNTRY-SEPARABLE BY DESIGN: this file only ever touches country_code =
-- 'BE' rows. Belgium and France can be reviewed/applied independently;
-- neither depends on the other succeeding.
--
-- STAR CORRECTIONS applied in this file (see RECOGNITION audit in the main
-- report for full evidence per case -- manifest values were deliberately
-- NOT preserved where current authoritative evidence clearly contradicted them):
--   (none in this country)
--
-- VERIFIED HOTEL LINKS applied in this file (checked live against production
-- hotels.id, not guessed):
--   be_010 -> Botanic Sanctuary Antwerp (exact)
--
-- SCHEMA CONVENTIONS: identical to the successfully-applied Netherlands
-- import (commit 97de674) -- ST_MakePoint(longitude, latitude), id left to
-- gen_random_uuid(), restaurant_code computed live from
-- max(restaurant_code)+row_number() (never hardcoded), inclusion_reason=
-- 'michelin_star', award_history guide_year=2026/award_type='michelin_stars'/
-- is_current=true/announced_on=NULL (verified live as the exact convention
-- already used by every existing BE/FR current award row in production).
--
-- IDEMPOTENCY: two-tier, because 100 rows split into two groups --
--   (a) rows WITH a real, unique Michelin Guide URL: protected via
--       `on conflict (michelin_url) do nothing` (the schema's real unique
--       constraint).
--   (b) rows WITHOUT a captured Michelin URL (see EVIDENCE FORMAT note in
--       the main report -- these candidates were verified via the earlier
--       michelin_location_spike methodology run, which did not capture a
--       clean URL field): protected via an additional
--       `NOT EXISTS (same country_code + lower(name) + city_id)` guard in
--       the INSERT's WHERE clause, since a NULL michelin_url can never
--       collide with another NULL under a standard unique constraint.
-- A full re-run after a successful apply therefore inserts 0 new rows in
-- either group. Award rows are driven by RETURNING on the restaurant insert,
-- so they inherit the same protection automatically.
--
-- TRANSACTION SAFETY: one statement -- a single `WITH` chaining
-- three data-modifying CTEs (restaurants, award_history, hotel_restaurants).
-- PostgreSQL executes the whole statement atomically.

with next_code_base as (
  select coalesce(max(substring(restaurant_code from 6)::int), 0) as base
  from public.restaurants
  where restaurant_code ~ '^rest_[0-9]+$'
),
proposed (seq, candidate_id, name, michelin_stars, city_id, lon, lat, address, michelin_url) as (
  values
    (1, 'be_007', 'Bistrot du Nord', 1, '4de2e02c-0e95-443b-9319-d1ff935a114c'::uuid, 4.4187220, 51.2275728, 'Lange Dijkstraat 36, 2060 Antwerpen, Belgium', 'https://guide.michelin.com/ae-az/en/antwerpen/be-antwerpen/restaurant/bistrot-du-nord'),
    (2, 'be_008', 'The Butcher''s son', 1, '4de2e02c-0e95-443b-9319-d1ff935a114c'::uuid, 4.4158394, 51.1995473, 'Boomgaardstraat 1, 2018 Antwerpen, Belgium', 'https://guide.michelin.com/en/antwerpen/be-antwerpen/restaurant/the-butcher-s-son'),
    (3, 'be_010', 'Fine Fleur', 1, '4de2e02c-0e95-443b-9319-d1ff935a114c'::uuid, 4.4050482, 51.2153311, 'Lange Gasthuisstraat 41b, 2000 Antwerpen, Belgium', 'https://guide.michelin.com/hu/en/antwerpen/be-antwerpen/restaurant/fine-fleur'),
    (4, 'be_011', 'Kommilfoo', 1, '4de2e02c-0e95-443b-9319-d1ff935a114c'::uuid, 4.3926732, 51.2111252, 'Vlaamse Kaai 17, 2000 Antwerpen, Belgium', 'https://guide.michelin.com/en/antwerpen/be-antwerpen/restaurant/kommilfoo'),
    (5, 'be_013', 'Misera', 1, '4de2e02c-0e95-443b-9319-d1ff935a114c'::uuid, 4.3823102, 51.2045642, 'Michel de Braeystraat 18, 2000 Antwerpen, Belgium', 'https://guide.michelin.com/us/en/antwerpen/be-antwerpen/restaurant/misera'),
    (6, 'be_014', 'Nathan', 1, '4de2e02c-0e95-443b-9319-d1ff935a114c'::uuid, 4.4027864, 51.2231170, 'Lange Koepoortstraat 13, 2000 Antwerpen, Belgium', 'https://guide.michelin.com/gb/en/antwerpen/be-antwerpen/restaurant/nathan'),
    (7, 'be_016', 'Pont neuf', 1, '4de2e02c-0e95-443b-9319-d1ff935a114c'::uuid, 4.4081274, 51.2304881, 'Verbindingsdok Oostkaai 9, 2000 Antwerpen, Belgium', 'https://guide.michelin.com/us/en/antwerpen/be-antwerpen/restaurant/pont-neuf'),
    (8, 'be_017', '''t Fornuis', 1, '4de2e02c-0e95-443b-9319-d1ff935a114c'::uuid, 4.3994157, 51.2190167, 'Reyndersstraat 24, 2000 Antwerpen, Belgium', 'https://guide.michelin.com/us/en/antwerpen/be-antwerpen/restaurant/t-fornuis'),
    (9, 'be_018', 'Centpourcent', 1, '8bc77d85-2eb0-488e-a92c-e55132b9279d'::uuid, 4.4634265, 51.0557966, 'Antwerpsesteenweg 1, 2860 Sint-Katelijne-Waver, Belgium', 'https://guide.michelin.com/us/en/antwerpen/sint-katelijne-waver/restaurant/centpourcent'),
    (10, 'be_019', 'De Pastorie', 1, 'ff92bd50-b965-45f0-a081-5848a3e138b5'::uuid, 4.9241642, 51.2261191, 'Plaats 2, 2460 Lichtaart, Belgium', 'https://guide.michelin.com/us/en/antwerpen/lichtaart/restaurant/de-pastorie209876'),
    (11, 'be_020', 'Hert', 1, 'b6c3093d-c9a0-4069-98d1-84846c68f7d7'::uuid, 4.9523127, 51.3232299, 'Turnovatoren 18, 2300 Turnhout, Belgium', 'https://guide.michelin.com/us/en/antwerpen/turnhout/restaurant/hert'),
    (12, 'be_021', 'Hof Ter Hulst', 1, '0e4616c4-0e7e-4fa0-a8ac-33c092a32ad3'::uuid, 4.7935031, 51.0770585, 'Kerkstraat 33, 2235 Hulshout, Belgium', 'https://guide.michelin.com/us/en/antwerpen/hulshout/restaurant/hof-ter-hulst'),
    (13, 'be_022', 'La Belle', 1, '09f3ae87-5802-4dcb-83b0-d1a49818958b'::uuid, 5.0638738, 51.1632537, 'Bel 162, 2440 Geel, Belgium', 'https://guide.michelin.com/en/antwerpen/geel/restaurant/la-belle'),
    (14, 'be_023', 'Neon', 1, '03b3dcc8-b374-4a66-b6cf-07667cc89550'::uuid, 4.5766348, 51.1303285, 'Barbara-Vettersplein 4, 2500 Lier, Belgium', 'https://guide.michelin.com/cz/en/antwerpen/lier/restaurant/neon'),
    (15, 'be_030', 'Kelderman', 1, 'ddfeca86-0d74-4b4d-99ee-705a7c4ab892'::uuid, 4.0418528, 50.9301090, 'Parklaan 4, 9300 Aalst, Belgium', NULL),
    (16, 'be_034', 'Sense', 1, 'a398e028-bebf-44e8-87c9-e92d73df3d09'::uuid, 4.1032334, 51.1229282, 'Fortenstraat 62, 9250 Waasmunster, Belgium', NULL),
    (17, 'be_045', 'Goffin', 1, '65da3090-95da-4373-927d-72ebc42e250d'::uuid, 3.2418157, 51.2119589, 'Maalse Steenweg 2, 8310 Sint-Kruis (Brugge), Belgium', NULL),
    (18, 'be_047', 'Hostellerie St-Nicolas', 1, '98b401db-3283-4514-8b88-b68d05f57c68'::uuid, 2.8197826, 50.8855753, 'Veurnseweg 532, 8906 Elverdinge (Ieper), Belgium', NULL),
    (19, 'be_024', 'Tinèlle', 1, '621341b1-a9e3-444d-aa28-bbe69752fafe'::uuid, 4.4800897, 51.0336431, 'Goswin de Stassartstraat 90, 2800 Mechelen, Belgium', 'https://guide.michelin.com/en/antwerpen/mechelen/restaurant/tinelle'),
    (20, 'be_025', 'Bloesem', 1, 'cb27049d-57ec-4e45-b1c9-1a6cef166f0d'::uuid, 4.4490358, 51.2005187, 'De Leescorfstraat 8, 2140 Borgerhout, Belgium', 'https://guide.michelin.com/us/en/antwerpen/borgerhout/restaurant/bloesem'),
    (21, 'be_026', 'Komaf', 1, '17f90cee-c070-423d-be7b-a4e0cdd035d3'::uuid, 4.5088010, 51.2002265, 'Schranshoevebaan 35, 2160 Wommelgem, Belgium', 'https://guide.michelin.com/us/en/vlaams-gewest/wommelgem_1063155/restaurant/komaf'),
    (22, 'be_027', 'Vintage', 1, '8324089e-2fbf-4f27-af64-36f29e7e0089'::uuid, 4.4378325, 51.1155529, 'Rijkerooistraat 14, 2550 Kontich, Belgium', 'https://guide.michelin.com/us/en/antwerpen/kontich/restaurant/vintage'),
    (23, 'be_028', 'Benoit en Bernard Dewitte', 1, '31e8ab51-a9b5-4619-b68a-7708bcd3fa76'::uuid, 3.6063860, 50.9133712, 'Beertegemstraat 52, 9750 Ouwegem, Belgium', 'https://guide.michelin.com/us/en/oost-vlaanderen/ouwegem/restaurant/benoit-en-bernard-dewitte'),
    (24, 'be_029', 'Fleur de Lin', 1, '6c9cbe11-5f43-4bae-8d9a-33cba0aa898e'::uuid, 4.0409546, 51.0758261, 'Lokerenbaan 100, 9240 Zele, Belgium', 'https://guide.michelin.com/gb/en/oost-vlaanderen/zele/restaurant/fleur-de-lin'),
    (25, 'be_031', 'Le Julien', 1, 'ebf3d28f-56b9-400e-9f9e-6c131518bffb'::uuid, 3.4664999, 51.0599634, 'Prinsenstraat 9, 9880 Lotenhulle, Belgium', 'https://guide.michelin.com/ae-az/en/oost-vlaanderen/lotenhulle_1064911/restaurant/le-julien'),
    (26, 'be_033', 'Publiek', 1, 'dc860991-6378-420f-9e94-7c8a851ef2b8'::uuid, 3.7329399, 51.0577781, 'Ham 39, 9000 Gent, Belgium', 'https://guide.michelin.com/us/en/oost-vlaanderen/gent/restaurant/publiek'),
    (27, 'be_037', 'Hofke van Bazel', 1, '78cbfabd-35d2-4d6a-bfd4-8104c8750642'::uuid, 4.3001270, 51.1472884, 'Kon. Astridplein 11, 9150 Bazel, Belgium', 'https://guide.michelin.com/us/en/oost-vlaanderen/bazel/restaurant/hofke-van-bazel'),
    (28, 'be_038', '''t Korennaer', 1, '472d98a1-0321-4ff6-868a-4c47ce9a14df'::uuid, 4.1784454, 51.1928751, 'Nieuwkerkenstraat 4, 9100 Nieuwkerken-Waas, Belgium', 'https://guide.michelin.com/se/en/oost-vlaanderen/nieuwkerken-waas/restaurant/t-korennaer'),
    (29, 'be_040', 'Moscou by Danny Horseele', 1, '30d0b843-43bc-4b1b-bd55-1bf0093f9ac6'::uuid, 3.7546287, 51.0320200, 'Oefenpleinstraat 3, 9050 Gentbrugge, Belgium', 'https://guide.michelin.com/us/en/oost-vlaanderen/gentbrugge_1064169/restaurant/moscou-by-danny-horseele'),
    (30, 'be_041', 'Bar Bulot Zedelgem', 1, 'ebfe8084-ac6f-458a-9f9b-58245d70222f'::uuid, 3.1495160, 51.1488985, 'Loppemsestraat 52, 8210 Zedelgem, Belgium', 'https://guide.michelin.com/us/en/west-vlaanderen/zedelgem/restaurant/bar-bulot'),
    (31, 'be_042', 'Boo Raan', 1, '7f38fb1d-beb8-4c56-947a-2f8019837d52'::uuid, 3.2892734, 51.3394944, 'Edward Verheyestraat 17, 8300 Knokke-Heist, Belgium', 'https://guide.michelin.com/en/west-vlaanderen/knokke/restaurant/boo-raan'),
    (32, 'be_043', 'Carcasse', 1, '6ab18621-0eaf-4e5a-9fe5-16dad9fc3429'::uuid, 2.6112357, 51.1099417, 'Henri Christiaenlaan 5, 8670 Sint-Idesbald, Belgium', 'https://guide.michelin.com/us/en/west-vlaanderen/sint-idesbald/restaurant/carcasse'),
    (33, 'be_044', 'De Zuidkant', 1, '821fb226-7c8f-487b-9404-26bba0f881e0'::uuid, 3.2823619, 51.2518644, 'Jacob van Maerlantstraat 6, 8340 Damme, Belgium', 'https://guide.michelin.com/us/en/west-vlaanderen/damme/restaurant/de-zuidkant'),
    (34, 'be_046', 'HAUT', 1, 'd96ec6ef-ff94-4f7d-bd36-031c8389e25f'::uuid, 2.9243512, 51.2275175, 'Leopold III-Laan 2, 8400 Oostende, Belgium', 'https://guide.michelin.com/us/en/west-vlaanderen/oostende/restaurant/haut'),
    (35, 'be_048', 'L''Envie', 1, 'd9138622-e411-4e84-804d-ac5c8bed40f7'::uuid, 3.3712079, 50.7491990, 'Helkijnstraat 38, 8554 Sint-Denijs, Belgium', 'https://guide.michelin.com/gb/en/west-vlaanderen/sint-denijs/restaurant/l-envie'),
    (36, 'be_049', 'Mémoire', 1, '9c2f6d51-b087-4790-9f31-90f2ce8b3b6c'::uuid, 3.2267846, 51.2063079, 'Dijver 7, 8000 Brugge, Belgium', 'https://guide.michelin.com/gb/en/west-vlaanderen/brugge/restaurant/memoire'),
    (37, 'be_050', 'Rebelle', 1, '62db7841-b6fc-4bee-ba5a-be3ccafbd762'::uuid, 3.2219177, 50.8039494, 'Rekkemsestraat 226, 8510 Marke, Belgium', 'https://guide.michelin.com/us/en/west-vlaanderen/marke/restaurant/rebelle548550'),
    (38, 'be_051', 'Sans Cravate', 1, '9c2f6d51-b087-4790-9f31-90f2ce8b3b6c'::uuid, 3.2380851, 51.2123905, 'Langestraat 159, 8000 Brugge, Belgium', 'https://guide.michelin.com/us/en/west-vlaanderen/brugge/restaurant/sans-cravate'),
    (39, 'be_001', 'Cuines 33', 2, '7f38fb1d-beb8-4c56-947a-2f8019837d52'::uuid, 3.2879539, 51.3394236, 'Smedenstraat 33, 8300 Knokke-Heist, Belgium', 'https://guide.michelin.com/en/west-vlaanderen/knokke/restaurant/cuines-33'),
    (40, 'be_002', 'L''air du temps', 2, '353a8b11-38c2-4112-be4c-fdbea7cd6c55'::uuid, 4.8329602, 50.5930505, 'Rue de la Croix Monet 2, 5310 Eghezee, Belgium', NULL),
    (41, 'be_004', 'Arabelle Meirlaen', 1, '916e4a03-b374-42e6-b91a-9b10bae8a327'::uuid, 5.2222404, 50.4864828, 'Chemin de Bertrandfontaine 7, 4570 Marchin, Belgium', 'https://guide.michelin.com/us/en/liege/marchin/restaurant/arabelle-meirlaen'),
    (42, 'be_006', 'La Paix', 2, '4967ac0e-64af-4fe0-afa2-3acaa20ef5e5'::uuid, 4.3283571, 50.8437328, 'Rue Ropsy-Chaudron 49, 1070 Anderlecht, Belgium', 'https://guide.michelin.com/us/en/bruxelles-capitale/anderlecht/restaurant/la-paix203164'),
    (43, 'be_003', 'The Jane', 2, '4de2e02c-0e95-443b-9319-d1ff935a114c'::uuid, 4.4048738, 51.2343679, 'Limastraat 5, 2000 Antwerp, Belgium', NULL),
    (44, 'be_005', 'Comme chez Soi', 1, '4967ac0e-64af-4fe0-afa2-3acaa20ef5e5'::uuid, 4.3458140, 50.8423459, 'Place Rouppe 23, 1000 Brussels, Belgium', NULL),
    (45, 'be_052', 'Sel Gris', 1, '7f38fb1d-beb8-4c56-947a-2f8019837d52'::uuid, 3.2563957, 51.3440990, 'Zeedijk 314, 8300 Knokke-Heist, Belgium', 'https://guide.michelin.com/us/en/west-vlaanderen/knokke/restaurant/sel-gris'),
    (46, 'be_053', 'Table d''Amis', 1, '28f47abf-4bf7-439e-985e-a78ce0bd53bf'::uuid, 3.2681661, 50.8279332, 'Sint-Maartenskerkhof 8, 8500 Kortrijk, Belgium', 'https://guide.michelin.com/us/en/west-vlaanderen/kortrijk/restaurant/table-d-amis'),
    (47, 'be_054', 'Vol-Ver', 1, '62db7841-b6fc-4bee-ba5a-be3ccafbd762'::uuid, 3.2369143, 50.7976678, 'Watervalstraat 23, 8510 Marke, Belgium', 'https://guide.michelin.com/us/en/west-vlaanderen/marke/restaurant/vol-ver'),
    (48, 'be_055', 'Willem Hiele', 1, '713ef35b-bcb7-4c60-82a4-b9ee7996328a'::uuid, 2.9731338, 51.1906910, 'Kapittelstraat 71, 8460 Oudenburg, Belgium', 'https://guide.michelin.com/us/en/west-vlaanderen/oudenburg/restaurant/willem-hiele-1203519'),
    (49, 'be_056', 'Zet''Joe by Geert Van Hecke', 1, '9c2f6d51-b087-4790-9f31-90f2ce8b3b6c'::uuid, 3.2320790, 51.2097693, 'Langestraat 11, 8000 Brugge, Belgium', 'https://guide.michelin.com/us/en/west-vlaanderen/brugge/restaurant/zet-joe-by-geert-van-hecke'),
    (50, 'be_057', 'Subtiel', 1, 'e9144af7-5bda-4355-90dd-6ec746a35247'::uuid, 2.5830690, 51.0935435, 'Westhoeklaan 31, 8660 De Panne, Belgium', 'https://guide.michelin.com/en/west-vlaanderen/de-panne/restaurant/subtiel'),
    (51, 'be_058', 'Alter', 1, '2ca05455-51be-461b-9032-2b09bde6a9cf'::uuid, 5.4654602, 50.8025064, 'Bilzersteenweg 366, 3700 Tongeren, Belgium', 'https://guide.michelin.com/en/be-limburg/tongeren/restaurant/altermezzo'),
    (52, 'be_059', 'Aurum by Gary Kirchens', 1, 'cec01979-8d97-4493-bb6d-90ecada67341'::uuid, 5.2285647, 50.8099505, 'Ordingen-Dorp 5, 3800 Sint-Truiden, Belgium', 'https://guide.michelin.com/th/en/be-limburg/ordingen/restaurant/aurum'),
    (53, 'be_060', 'De Kristalijn', 1, 'df852e79-e2ce-44a9-bf08-0b8f4459127e'::uuid, 5.5559858, 50.9700865, 'Wiemesmeerstraat 105, 3600 Genk, Belgium', 'https://guide.michelin.com/us/en/be-limburg/genk/restaurant/de-kristalijn'),
    (54, 'be_061', 'De Mijlpaal', 1, '2ca05455-51be-461b-9032-2b09bde6a9cf'::uuid, 5.4616326, 50.7803832, 'Sint-Truiderstraat 25, 3700 Tongeren, Belgium', 'https://guide.michelin.com/en/be-limburg/tongeren/restaurant/de-mijlpaal'),
    (55, 'be_062', 'Hoeve De Bies', 1, '96e4111a-43dd-4f8f-8fff-9ec7888ec000'::uuid, 5.8151619, 50.7467209, 'Bies 4, 3790 Sint-Martens-Voeren, Belgium', 'https://guide.michelin.com/us/en/be-limburg/st-martens-voeren/restaurant/hoeve-de-bies'),
    (56, 'be_063', 'Hostellerie Vivendum', 1, '941a9970-9f8f-4106-b6ec-d09d40d3b8fd'::uuid, 5.7364148, 51.0333638, 'Vissersstraat 2, 3650 Dilsen-Stokkem, Belgium', 'https://guide.michelin.com/us/en/be-limburg/dilsen/restaurant/hostellerie-vivendum'),
    (57, 'be_064', 'Innesto', 1, 'f7fd6bca-0312-400a-b9ab-faec0b17bed8'::uuid, 5.3689034, 50.9875602, 'Kapelhof 13, 3520 Zonhoven, Belgium', 'https://guide.michelin.com/us/en/be-limburg/zonhoven/restaurant/innesto'),
    (58, 'be_065', 'JER', 1, '96c54d14-b8cb-4c8a-a836-0adb8ddfd7e7'::uuid, 5.3406210, 50.9308528, 'Persoonstraat 16, 3500 Hasselt, Belgium', 'https://guide.michelin.com/us/en/be-limburg/hasselt/restaurant/jer'),
    (59, 'be_066', 'La Botte', 1, 'df852e79-e2ce-44a9-bf08-0b8f4459127e'::uuid, 5.5010139, 50.9663334, 'Europalaan 99, 3600 Genk, Belgium', 'https://guide.michelin.com/en/be-limburg/genk/restaurant/la-botte'),
    (60, 'be_067', 'Modest', 1, '609a8582-4571-4b69-9ddf-ed9e2ed71b62'::uuid, 5.5991781, 51.0494721, 'Weg naar Opoeteren 117, 3660 Opglabbeek, Belgium', 'https://guide.michelin.com/gb/en/be-limburg/opglabbeek/restaurant/modest'),
    (61, 'be_068', 'Ogst', 1, '96c54d14-b8cb-4c8a-a836-0adb8ddfd7e7'::uuid, 5.3335057, 50.9293652, 'Ridder Portmansstraat 4, 3500 Hasselt, Belgium', 'https://guide.michelin.com/us/en/be-limburg/hasselt/restaurant/ogst'),
    (62, 'be_069', 'Melchior', 1, 'b834b4ff-7dd8-4ca3-bd2e-ebe83f53017a'::uuid, 4.9409097, 50.8058331, 'Veemarkt 47, 3300 Tienen, Belgium', 'https://guide.michelin.com/us/en/vlaams-brabant/tienen/restaurant/melchior'),
    (63, 'be_075', 'Agnes', 1, '9ef6df96-762b-4b1e-bcaa-0edfbcaa92ee'::uuid, 4.2148869, 50.8620569, 'Processiestraat 3, 1700 Dilbeek, Belgium', 'https://guide.michelin.com/us/en/vlaams-brabant/sint-martens-bodegem/restaurant/agnes-1207215'),
    (64, 'be_076', 'EST', 1, 'a5c4b502-c3a9-4073-81c0-b4fab1f99f59'::uuid, 4.6649859, 50.8609616, 'Kapeldreef 46, 3001 Heverlee, Belgium', 'https://guide.michelin.com/be/nl/vlaams-brabant/heverlee/restaurant/est-1242817'),
    (65, 'be_077', 'Atelier Noun', 1, 'f00f7526-6b2c-46b3-a26c-754395007b72'::uuid, 4.6140890, 50.8573562, 'Dorpstraat 252, 3061 Leefdaal, Belgium', 'https://guide.michelin.com/en/vlaams-brabant/leefdaal/restaurant/atelier-noun'),
    (66, 'be_078', 'Barge', 1, '4967ac0e-64af-4fe0-afa2-3acaa20ef5e5'::uuid, 4.3469641, 50.8568936, 'Boulevard d''Ypres 33, 1000 Bruxelles, Belgium', 'https://guide.michelin.com/us/en/bruxelles-capitale/bruxelles/restaurant/barge'),
    (67, 'be_079', 'Da Mimmo', 1, '9b53fd50-9f65-4dc7-912c-9530469e9fd8'::uuid, 4.4181790, 50.8434622, 'Avenue du Roi Chevalier 24, 1200 Woluwe-Saint-Lambert, Belgium', 'https://guide.michelin.com/us/en/bruxelles-capitale/woluwe-saint-lambert/restaurant/da-mimmo209466'),
    (68, 'be_080', 'Eliane', 1, '4967ac0e-64af-4fe0-afa2-3acaa20ef5e5'::uuid, 4.3600878, 50.8506650, 'Rue Saint-Laurent 36, 1000 Bruxelles, Belgium', 'https://guide.michelin.com/ca/fr/bruxelles-capitale/bruxelles/restaurant/eliane'),
    (69, 'be_081', 'humus x hortense', 1, '49ae3d25-9bc8-4fbc-a5e2-3664b97c927f'::uuid, 4.3703813, 50.8294890, 'Rue De Vergnies 2, 1050 Ixelles, Belgium', 'https://guide.michelin.com/us/en/bruxelles-capitale/ixelles/restaurant/humus-x-hortense'),
    (70, 'be_082', 'Kamo', 1, '49ae3d25-9bc8-4fbc-a5e2-3664b97c927f'::uuid, 4.3615191, 50.8193649, 'Chaussée de Waterloo 550A, 1050 Ixelles, Belgium', 'https://guide.michelin.com/en/bruxelles-capitale/ixelles/restaurant/kamo'),
    (71, 'be_084', 'La Villa in the Sky', 1, '4967ac0e-64af-4fe0-afa2-3acaa20ef5e5'::uuid, 4.3721830, 50.8172663, 'Avenue Louise 480, 1050 Bruxelles, Belgium', 'https://guide.michelin.com/gr/en/bruxelles-capitale/bruxelles/restaurant/la-villa-in-the-sky'),
    (72, 'be_085', 'Les Gourmands', 1, 'a620cde2-7bf9-43e1-95cf-5162cb39088d'::uuid, 3.8872241, 50.3607052, 'Rue de Sars 15, 7040 Blaregnies, Belgium', 'https://guide.michelin.com/en/hainaut/blaregnies/restaurant/les-gourmands'),
    (73, 'be_086', 'Le Vieux Château', 1, '24ccbcf3-d446-444b-848c-8c716dd728c7'::uuid, 3.7329021, 50.7372799, 'Rue Docteur Degavre 23, 7880 Flobecq, Belgium', 'https://guide.michelin.com/en/hainaut/flobecq/restaurant/le-vieux-chateau'),
    (74, 'be_087', 'l''Impératif d''Éole', 1, '11d7ac8c-4121-4720-83e8-3ee711222532'::uuid, 3.9648245, 50.3813917, 'Grand''Route 58, 7040 Quévy-le-Grand, Belgium', 'https://guide.michelin.com/us/en/hainaut/quevy-le-grand_1065568/restaurant/l-imperatif-d-eole'),
    (75, 'be_088', 'Vicomté', 1, 'e40b94b4-a8d4-441c-9ceb-f37194bc51e9'::uuid, 3.5747608, 50.5246117, 'Rue d''Arondeau 29, 7601 Roucourt, Belgium', 'https://guide.michelin.com/us/en/hainaut/roucourt/restaurant/vicomte'),
    (76, 'be_089', 'Au Gré du Vent', 1, '58189788-1285-4ccd-b8aa-b0ff30c73248'::uuid, 4.2618565, 50.5159466, 'Rue de Soudromont 67, 7180 Seneffe, Belgium', 'https://guide.michelin.com/us/en/hainaut/seneffe/restaurant/au-gre-du-vent'),
    (77, 'be_092', 'Le Coq aux Champs', 1, 'b948e883-647d-4fb9-868b-bee204c0a647'::uuid, 5.3878509, 50.4713346, 'Rue du Montys 71, 4557 Soheit-Tinlot, Belgium', 'https://guide.michelin.com/us/en/liege/soheit-tinlot/restaurant/le-coq-aux-champs'),
    (78, 'be_093', 'Le Roannay', 1, '91323d6d-3e9f-4789-96c9-c51c78690407'::uuid, 5.9526291, 50.4561478, 'Rue de Spa 155, 4970 Francorchamps, Belgium', 'https://guide.michelin.com/us/en/liege/francorchamps/restaurant/le-roannay'),
    (79, 'be_094', 'Quadras', 1, 'a5f9a254-8638-4980-858e-890c7470e51a'::uuid, 6.1221320, 50.2844598, 'Malmedyer Straße 53, 4780 Saint-Vith, Belgium', 'https://guide.michelin.com/en/liege/sankt-vith/restaurant/quadras'),
    (80, 'be_096', '¡Toma!', 1, '0791a7ca-3a95-42f1-9125-fbaa802010ac'::uuid, 5.5655129, 50.6436084, 'Boulevard de la Sauvenière 70, 4000 Liège, Belgium', 'https://guide.michelin.com/us/en/liege/liege/restaurant/toma'),
    (81, 'be_098', 'Zur Post', 1, 'a5f9a254-8638-4980-858e-890c7470e51a'::uuid, 6.1261217, 50.2801758, 'Hauptstraße 39, 4780 Saint-Vith, Belgium', 'https://guide.michelin.com/en/liege/sankt-vith/restaurant/zur-post210392'),
    (82, 'be_099', 'Chai Gourmand', 1, '2471f104-ca89-4afe-b431-776dc0f37d87'::uuid, 4.7398433, 50.5303124, 'rue Chainisse 53, 5030 Beuzet, Belgium', 'https://guide.michelin.com/en/namur/beuzet/restaurant/chai-gourmand'),
    (83, 'be_100', 'Pré de chez vous', 1, '549d8289-0a25-4319-bfdb-b169176e688c'::uuid, 4.8820699, 50.4802165, 'Chaussée de Louvain 380, 5004 Bouge, Belgium', 'https://guide.michelin.com/gb/en/namur/bouge/restaurant/pre-de-chez-vous'),
    (84, 'be_101', 'Le Beau Rivage by Curtis', 1, '6634f916-c6e7-44ed-8a55-625f20942822'::uuid, 4.8851266, 50.4145764, 'Rue du Rivage 8, 5100 Dave, Belgium', 'https://guide.michelin.com/us/en/namur/dave_1063818/restaurant/le-beau-rivage-by-curtis'),
    (85, 'be_102', 'La Grange d''Hamois', 1, 'e89e36b4-fc67-4c5f-b1d8-1880da1c9309'::uuid, 5.1039602, 50.3376332, 'Chaussée d''Andenne 10a, 5363 Emptinne, Belgium', 'https://guide.michelin.com/en/namur/emptinne/restaurant/la-grange-d-hamois'),
    (86, 'be_103', 'Attablez-vous', 1, 'cd839fe5-64b7-404d-bc8f-9f90ba20af41'::uuid, 4.8537555, 50.4448917, 'Tienne Maquet 16, 5000 Namur, Belgium', 'https://guide.michelin.com/us/en/namur/namur/restaurant/attablez-vous'),
    (87, 'be_104', 'l''Essentiel', 1, 'f976616a-0d21-4120-8577-4b23265aa1d5'::uuid, 4.7387083, 50.4753298, 'Rue Roger Clément 32, 5020 Temploux, Belgium', 'https://guide.michelin.com/us/en/namur/temploux/restaurant/l-essentiel210192'),
    (88, 'be_105', 'Arden', 1, 'bfa25bda-28fc-4fe2-add2-36451a84ed07'::uuid, 5.0746265, 50.1578142, 'Rue de Montainpré 27, 5580 Villers-sur-Lesse, Belgium', 'https://guide.michelin.com/us/en/namur/villers-sur-lesse/restaurant/arden'),
    (89, 'be_106', 'La Table-Lasne by Alain Bianchin', 1, 'e5550678-0ef8-4b81-84bf-91738554ed10'::uuid, 4.4694911, 50.6985809, 'Rue du Try Bara 33, 1380 Lasne, Belgium', 'https://guide.michelin.com/en/brabant-wallon/ohain/restaurant/la-table-lasne-by-alain-bianchin'),
    (90, 'be_107', 'Maison Marit', 1, '63aca91f-99f1-4024-ae96-43171c4ff417'::uuid, 4.3796402, 50.6603391, 'Chaussée de Nivelles 336, 1420 Braine-l''Alleud, Belgium', 'https://guide.michelin.com/us/en/brabant-wallon/braine-l-alleud/restaurant/maison-marit'),
    (91, 'be_108', 'Philippe Meyers', 1, '63aca91f-99f1-4024-ae96-43171c4ff417'::uuid, 4.3700437, 50.6823203, 'rue Doyen Van Belle 6, 1420 Braine-l''Alleud, Belgium', 'https://guide.michelin.com/us/en/brabant-wallon/braine-l-alleud/restaurant/philippe-meyers'),
    (92, 'be_109', 'Bistro Racine', 1, '4429f9fc-cac2-4a17-9bd1-c4a09933d5af'::uuid, 4.2731352, 50.6815901, 'Place de la Station 3, 1440 Braine-le-Château, Belgium', 'https://guide.michelin.com/us/en/brabant-wallon/braine-le-chteau/restaurant/bistro-racine'),
    (93, 'be_110', 'Aux petits oignons', 1, 'c10b51cd-e271-46b1-a714-c320266bf5e9'::uuid, 4.8801826, 50.7418362, 'Chaussée de Tirlemont 260, 1370 Jodoigne, Belgium', 'https://guide.michelin.com/en/brabant-wallon/jodoigne/restaurant/aux-petits-oignons'),
    (94, 'be_111', 'La Grappe d''Or', 1, '945ed237-d90b-4421-904a-fbaaf14570bc'::uuid, 5.8437457, 49.6625497, 'Route de Luxembourg 317, 6700 Arlon, Belgium', 'https://guide.michelin.com/en/be-luxembourg/arlon/restaurant/la-grappe-d-or-1203424'),
    (95, 'be_112', 'Le Grand Verre', 1, '8d469fbf-058e-460f-8aac-b5a164120917'::uuid, 5.4559682, 50.3519966, 'Place aux Foires 26, 6940 Durbuy, Belgium', 'https://guide.michelin.com/us/en/be-luxembourg/durbuy/restaurant/le-grand-verre'),
    (96, 'be_113', 'La Table de Manon', 1, 'e603dbf3-7f76-4727-8716-aa2af1ad82c2'::uuid, 5.4218646, 50.3241923, 'Rue de Givet 79, 6940 Grandhan, Belgium', 'https://guide.michelin.com/us/en/be-luxembourg/grandhan/restaurant/la-table-de-manon'),
    (97, 'be_114', 'Bistrot Blaise', 1, '5e2bf0d7-eac9-4526-8e65-b4ba646be35e'::uuid, 5.3449532, 50.2264063, 'Rue Porte Haute 5, 6900 Marche-en-Famenne, Belgium', 'https://guide.michelin.com/us/en/be-luxembourg/marche-en-famenne/restaurant/bistrot-blaise'),
    (98, 'be_115', 'Les Pieds dans le Plat', 1, '60a917b3-0e7a-403c-b42c-c6dfba39a88a'::uuid, 5.4108377, 50.2396417, 'Rue du Centre 3, 6990 Marenne, Belgium', 'https://guide.michelin.com/us/en/be-luxembourg/marenne/restaurant/les-pieds-dans-le-plat'),
    (99, 'be_116', 'Le Gastronome', 1, '3f0835ed-f7c2-40b1-b325-9a43be5ec07e'::uuid, 5.1177911, 49.8953169, 'rue de Bouillon 2, 6850 Paliseul, Belgium', 'https://guide.michelin.com/en/be-luxembourg/paliseul/restaurant/le-gastronome'),
    (100, 'be_117', 'Le Cor de Chasse', 1, '968ae34b-85bd-48f4-adc8-6443e4a0de38'::uuid, 5.5300615, 50.3244966, 'Rue des Combattants 16, 6940 Wéris, Belgium', 'https://guide.michelin.com/en/be-luxembourg/wris/restaurant/le-cor-de-chasse')
),
coded as (
  select p.*, 'rest_' || lpad((b.base + p.seq)::text, 4, '0') as restaurant_code
  from proposed p
  cross join next_code_base b
),
new_restaurants as (
  insert into public.restaurants
    (restaurant_code, name, michelin_stars, inclusion_reason, city_id,
     country_code, address, location, michelin_url)
  select
    c.restaurant_code,
    c.name,
    c.michelin_stars,
    'michelin_star',
    c.city_id,
    'BE',
    c.address,
    ST_SetSRID(ST_MakePoint(c.lon, c.lat), 4326)::geography,
    c.michelin_url
  from coded c
  where c.michelin_url is not null
     or not exists (
       select 1 from public.restaurants r2
       where r2.country_code = 'BE'
         and lower(r2.name) = lower(c.name)
         and r2.city_id = c.city_id
     )
  on conflict (michelin_url) do nothing
  returning id, restaurant_code, michelin_stars
),
new_awards as (
  insert into public.award_history
    (entity_type, entity_id, guide_year, award_type, award_value, is_current)
  select
    'restaurant', nr.id, 2026, 'michelin_stars', nr.michelin_stars, true
  from new_restaurants nr
  returning entity_id
),
hotel_links (candidate_id, hotel_id, link_confidence, evidence) as (
  values
    ('be_010', '47856b16-7aba-486e-8647-3213960a66c9'::uuid, 'exact', 'Botanic Sanctuary Antwerp')
)
insert into public.hotel_restaurants (hotel_id, restaurant_id, link_confidence, evidence)
select hl.hotel_id, nr.id, hl.link_confidence, hl.evidence
from new_restaurants nr
join coded c on c.restaurant_code = nr.restaurant_code
join hotel_links hl on hl.candidate_id = c.candidate_id;
