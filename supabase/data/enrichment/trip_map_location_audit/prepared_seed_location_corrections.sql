-- PREPARED -- NOT APPLIED. Do not run without the product owner's approval.
--
-- Location corrections for 101 seed restaurants (rest_0001..rest_0143) whose
-- stored point has at most 4 decimals and sits a median 752 m (up to 9.2 km)
-- from the venue. QA-530; held-back rows QA-531; written 2026-11-20 on branch
-- claude/trip-map-positions. Evidence per row: seed_coordinates_staged.csv
-- (coordinate_source, source_url, address sources) and README.md.
--
-- A point is moved only when the venue's current address is confirmed by two
-- independent sources (the venue's own website plus the MICHELIN Guide, or
-- World's 50 Best where MICHELIN has no guide; or, for 27 Dutch rows, the
-- BAG address with an OpenStreetMap venue of the same name within 150 m, or
-- with a matching postcode) and that address resolves to one building:
--   * NL (88 rows): the BAG address point (PDOK Locatieserver), exact
--     postcode + house number with the street name checked;
--   * elsewhere (13 rows): the OpenStreetMap object with the same house
--     number and postcode.
-- Only `location` changes. The `address` column is NOT corrected here, though
-- most of these rows' stored addresses are wrong too (QA-532).
--
-- Guards: each code must still carry the expected name and country; a point
-- moves only while the row still holds the old point (within 5 m), so a later
-- correction is never overwritten; a row at neither the old nor the new point
-- aborts the whole transaction. One transaction; safe to re-run.

begin;
create temp table _loc_restaurant (code text primary key, country text, name text, old_lon float8, old_lat float8,
                       new_lon float8, new_lat float8) on commit drop;
insert into _loc_restaurant values
    ('rest_0001', 'NL', 'Aan de Poel', 4.8494, 52.3133, 4.8448128, 52.2999361),  -- moves 1,518 m
    ('rest_0004', 'GB', 'Alain Ducasse at The Dorchester', -0.1507, 51.5074, -0.1523634, 51.5072956),  -- moves 116 m
    ('rest_0005', 'NL', 'Alma', 5.1928, 51.5871, 5.1972259, 51.5811250),  -- moves 731 m
    ('rest_0007', 'NL', 'Amarone', 4.4834, 51.9227, 4.4833528, 51.9223864),  -- moves 35 m
    ('rest_0008', 'FR', 'Anne', 2.3262, 48.8461, 2.3659970, 48.8562644),  -- moves 3,124 m
    ('rest_0009', 'NL', 'Apicius', 4.6592, 52.5488, 4.6564858, 52.5587134),  -- moves 1,117 m
    ('rest_0011', 'NL', 'Au Coin des Bons Enfants', 5.6969, 50.85, 5.6873496, 50.8462052),  -- moves 792 m
    ('rest_0012', 'NL', 'Beluga loves you', 5.7007, 50.8504, 5.6991351, 50.8461099),  -- moves 490 m
    ('rest_0013', 'NL', 'Bistro de la Mer', 4.8893, 52.3724, 4.8983267, 52.3641263),  -- moves 1,105 m
    ('rest_0014', 'NL', 'Bolenius Rembrandtpark', 4.8463, 52.3385, 4.8440329, 52.3596184),  -- moves 2,353 m
    ('rest_0016', 'NL', 'Bougainville', 4.8952, 52.3731, 4.8943846, 52.3727291),  -- moves 69 m
    ('rest_0017', 'NL', 'Brass Boer Thuis', 6.0958, 52.5078, 6.0956863, 52.5112831),  -- moves 387 m
    ('rest_0019', 'NL', 'Calla''s', 4.2892, 52.0818, 4.3130678, 52.0866309),  -- moves 1,717 m
    ('rest_0020', 'IT', 'Cavallino', 10.8689, 44.5268, 10.8649530, 44.5300770),  -- moves 480 m
    ('rest_0021', 'NL', 'Central Park', 4.3463, 52.059, 4.3694918, 52.0699937),  -- moves 2,002 m
    ('rest_0022', 'NL', 'Chateau Neercanne', 5.6882, 50.828, 5.6673345, 50.8187109),  -- moves 1,793 m
    ('rest_0023', 'NL', 'Cheval Blanc', 4.6238, 52.3474, 4.6288349, 52.3603068),  -- moves 1,475 m
    ('rest_0024', 'NL', 'Choux', 4.9063, 52.3808, 4.9071808, 52.3775991),  -- moves 361 m
    ('rest_0025', 'NL', 'Ciel Bleu', 4.8956, 52.349, 4.8936253, 52.3485849),  -- moves 142 m
    ('rest_0026', 'NL', 'Codium', 3.8982, 51.5063, 3.8888354, 51.5049183),  -- moves 666 m
    ('rest_0027', 'NL', 'Create by Guido Braeken', 5.7248, 50.7765, 5.7060816, 50.7961150),  -- moves 2,547 m
    ('rest_0028', 'NL', 'CUE', 4.9215, 52.3551, 4.8979270, 52.3644302),  -- moves 1,908 m
    ('rest_0029', 'NL', 'Da Vinci', 5.8833, 51.1599, 5.8850322, 51.1450536),  -- moves 1,655 m
    ('rest_0030', 'NL', 'De Bokkedoorns', 4.5904, 52.3904, 4.5662851, 52.3981333),  -- moves 1,848 m
    ('rest_0031', 'NL', 'De Heeren van Harinxma', 6.0811, 53.0561, 6.0911434, 53.0581333),  -- moves 708 m
    ('rest_0032', 'NL', 'De Juwelier', 4.8982, 52.3601, 4.8982513, 52.3642481),  -- moves 461 m
    ('rest_0033', 'NL', 'De kas', 4.9519, 52.3644, 4.9305718, 52.3522924),  -- moves 1,977 m
    ('rest_0034', 'NL', 'De Kromme Dissel', 5.7563, 51.974, 5.7587929, 51.9839298),  -- moves 1,117 m
    ('rest_0035', 'NL', 'De Kromme Watergang', 3.6888, 51.3764, 3.6029014, 51.3773227),  -- moves 5,963 m
    ('rest_0036', 'NL', 'De Leuf', 5.9428, 50.8636, 5.9521513, 50.8526090),  -- moves 1,387 m
    ('rest_0037', 'NL', 'De Librije', 6.0931, 52.5117, 6.0978784, 52.5153648),  -- moves 520 m
    ('rest_0038', 'NL', 'De Lindenhof', 6.0775, 52.7318, 6.0797790, 52.7463883),  -- moves 1,629 m
    ('rest_0039', 'NL', 'De Nederlanden', 5.0119, 52.2278, 5.0324348, 52.2295075),  -- moves 1,411 m
    ('rest_0040', 'NL', 'De Nieuwe Winkel', 5.8653, 51.838, 5.8597664, 51.8472692),  -- moves 1,099 m
    ('rest_0041', 'NL', 'De Treeswijkhoeve', 5.45, 51.3877, 5.4671537, 51.3727586),  -- moves 2,044 m
    ('rest_0045', 'US', 'Eleven Madison Park', -73.9869, 40.7416, -73.9871904, 40.7415982),  -- moves 24 m
    ('rest_0047', 'NL', 'Flore', 4.8906, 52.3638, 4.8943087, 52.3676598),  -- moves 498 m
    ('rest_0048', 'NL', 'Fred', 4.5307, 51.929, 4.4894568, 51.9162509),  -- moves 3,164 m
    ('rest_0050', 'NL', 'Herberg Onder de Linden', 6.4607, 53.1753, 6.4576608, 53.2583352),  -- moves 9,235 m
    ('rest_0051', 'NL', 'Inter Scaldes', 4.0258, 51.4532, 4.0225687, 51.4570695),  -- moves 485 m
    ('rest_0052', 'NL', 'Joelia', 4.4793, 51.921, 4.4773291, 51.9231693),  -- moves 277 m
    ('rest_0053', 'US', 'Jungsik New York', -74.0082, 40.7191, -74.0094760, 40.7187900),  -- moves 113 m
    ('rest_0054', 'NL', 'Kaatje bij de Sluis', 5.9617, 52.7245, 5.9609397, 52.7265929),  -- moves 238 m
    ('rest_0055', 'NL', 'Karel 5', 5.1177, 52.0911, 5.1177592, 52.0876347),  -- moves 385 m
    ('rest_0056', 'NL', 'La Provence', 5.2835, 52.0168, 5.2821172, 52.0525275),  -- moves 3,974 m
    ('rest_0057', 'NL', 'Lars Amsterdam', 4.8779, 52.3915, 4.8748954, 52.4013808),  -- moves 1,117 m
    ('rest_0058', 'ES', 'Lasarte', 2.1617, 41.3943, 2.1621260, 41.3936394),  -- moves 82 m
    ('rest_0060', 'FR', 'Le Gabriel - La Reserve Paris', 2.3149, 48.8697, 2.3132448, 48.8696988),  -- moves 121 m
    ('rest_0061', 'IT', 'L''Erba del Re', 10.9278, 44.6459, 10.9238038, 44.6491807),  -- moves 483 m
    ('rest_0062', 'NL', 'Lizz', 4.709, 52.0109, 4.7128872, 52.0114202),  -- moves 272 m
    ('rest_0063', 'NL', 'Lutum', 5.3392, 51.9742, 5.3454909, 51.9720366),  -- moves 494 m
    ('rest_0064', 'NL', 'Maeve', 5.1162, 52.0905, 5.1242267, 52.0923709),  -- moves 587 m
    ('rest_0065', 'NL', 'Marrees', 5.6934, 51.2408, 5.7033906, 51.2514132),  -- moves 1,370 m
    ('rest_0066', 'NL', 'ML', 4.6373, 52.3825, 4.6384833, 52.3809955),  -- moves 186 m
    ('rest_0068', 'NL', 'Monarh', 5.0891, 51.558, 5.0700499, 51.5555755),  -- moves 1,344 m
    ('rest_0069', 'NL', 'MOS', 4.9019, 52.3772, 4.8954756, 52.3837816),  -- moves 852 m
    ('rest_0070', 'NL', 'Nami', 5.17, 51.6667, 5.2297068, 51.6654066),  -- moves 4,120 m
    ('rest_0074', 'NL', 'O&O', 4.5888, 51.5446, 4.5917796, 51.5524449),  -- moves 896 m
    ('rest_0075', 'NL', 'Odille', 5.4591, 51.5665, 5.4614694, 51.5645246),  -- moves 274 m
    ('rest_0076', 'NL', 'One', 5.9874, 51.1942, 5.9804538, 51.1890193),  -- moves 752 m
    ('rest_0078', 'IT', 'Osteria Francescana', 10.9256, 44.6447, 10.9215627, 44.6447968),  -- moves 320 m
    ('rest_0079', 'NL', 'Parkheuvel', 4.4685, 51.9069, 4.4715461, 51.9039036),  -- moves 393 m
    ('rest_0081', 'NL', 'Perceel', 4.5714, 51.9295, 4.5848315, 51.9219609),  -- moves 1,245 m
    ('rest_0083', 'NL', 'Ratatouille Food & Wine', 4.6368, 52.3826, 4.6376030, 52.3786756),  -- moves 440 m
    ('rest_0084', 'NL', 'Restaurant 1857', 4.4608, 51.5328, 4.4599847, 51.5340747),  -- moves 153 m
    ('rest_0085', 'NL', 'Restaurant 212', 4.906, 52.3402, 4.9002601, 52.3658779),  -- moves 2,882 m
    ('rest_0086', 'NL', 'Restaurant Affect', 6.0967, 52.5098, 6.0960144, 52.5148494),  -- moves 563 m
    ('rest_0087', 'NL', 'Restaurant Atelier', 5.886, 50.8146, 5.8913850, 50.8155754),  -- moves 394 m
    ('rest_0088', 'NL', 'Restaurant Calva', 4.3724, 52.031, 4.3933400, 52.0458754),  -- moves 2,188 m
    ('rest_0089', 'NL', 'Restaurant de Burgemeester', 4.8918, 52.0212, 4.9145192, 52.0619463),  -- moves 4,790 m
    ('rest_0090', 'NL', 'Restaurant kasteel Heemstede', 5.1569, 52.0036, 5.1251369, 52.0329568),  -- moves 3,922 m
    ('rest_0091', 'NL', 'Restaurant Showw', 4.873, 52.3418, 4.8929414, 52.3373981),  -- moves 1,440 m
    ('rest_0094', 'NL', 'Rijnzicht', 6.0165, 51.8871, 6.0226242, 51.8900466),  -- moves 533 m
    ('rest_0095', 'NL', 'Ron Gastrobar', 4.8755, 52.3534, 4.8567144, 52.3522271),  -- moves 1,283 m
    ('rest_0096', 'NL', 'Sabero', 5.5438, 51.3547, 5.5600094, 51.3432352),  -- moves 1,701 m
    ('rest_0098', 'NL', 'Sense', 5.3026, 51.6517, 5.2986585, 51.6577356),  -- moves 724 m
    ('rest_0099', 'NL', 'Sinne', 4.8916, 52.3531, 4.8940457, 52.3530176),  -- moves 166 m
    ('rest_0100', 'NL', 'Spetters', 3.5587, 51.3961, 3.5680970, 51.3952201),  -- moves 659 m
    ('rest_0101', 'NL', 'Studio', 5.6947, 50.85, 5.6993196, 50.8486669),  -- moves 357 m
    ('rest_0102', 'US', 'Sushi Sho', -73.9843, 40.7624, -73.9798580, 40.7522730),  -- moves 1,187 m
    ('rest_0103', 'NL', 't Amsterdammertje', 5.0189, 52.2155, 5.0214420, 52.2096142),  -- moves 677 m
    ('rest_0104', 'NL', 't Ganzenest', 4.331, 52.038, 4.3458104, 52.0370327),  -- moves 1,019 m
    ('rest_0105', 'NL', 't Raedthuys', 6.0242, 51.9509, 6.0235475, 51.9504179),  -- moves 70 m
    ('rest_0106', 'NL', 'Tante Koosje', 5.0189, 52.2155, 5.0235044, 52.2091221),  -- moves 775 m
    ('rest_0107', 'NL', 'The Millen', 4.4834, 51.9227, 4.4714704, 51.9226611),  -- moves 818 m
    ('rest_0109', 'NL', 'Tout a Fait', 5.6921, 50.8477, 5.6940907, 50.8464043),  -- moves 201 m
    ('rest_0110', 'NL', 'Tribeca', 5.5747, 51.3776, 5.5780347, 51.3793002),  -- moves 299 m
    ('rest_0111', 'NL', 'Triptyque', 4.288, 52.0175, 4.2744360, 52.0247475),  -- moves 1,229 m
    ('rest_0113', 'NL', 'Versaen', 5.6496, 51.7865, 5.6520464, 51.7972488),  -- moves 1,207 m
    ('rest_0114', 'NL', 'Vinkeles', 4.8851, 52.3663, 4.8839831, 52.3692791),  -- moves 340 m
    ('rest_0116', 'NL', 'Voltaire', 5.4175, 52.0083, 5.3997560, 52.0078289),  -- moves 1,216 m
    ('rest_0117', 'NL', 'Wiesen', 5.4748, 51.4408, 5.4752761, 51.4378309),  -- moves 332 m
    ('rest_0118', 'NL', 'Wils', 4.8608, 52.3408, 4.8562959, 52.3434135),  -- moves 422 m
    ('rest_0119', 'NL', 'Yamazato', 4.8956, 52.349, 4.8936253, 52.3485849),  -- moves 142 m
    ('rest_0120', 'NL', 'Zarzo', 5.4697, 51.4601, 5.4840995, 51.4352506),  -- moves 2,938 m
    ('rest_0121', 'NL', 'Zeezout', 4.4782, 51.9105, 4.4775403, 51.9062430),  -- moves 476 m
    ('rest_0122', 'NL', 'Zoldering', 4.9012, 52.3741, 4.8993998, 52.3613355),  -- moves 1,425 m
    ('rest_0123', 'NL', 'Zout & Citroen', 4.86, 51.6427, 4.8602279, 51.6404198),  -- moves 254 m
    ('rest_0134', 'PE', 'Maido', -77.0338, -12.1223, -77.0306079, -12.1253878),  -- moves 488 m
    ('rest_0141', 'PE', 'Mayta', -77.0324, -12.1116, -77.0492589, -12.1098682),  -- moves 1,843 m
    ('rest_0142', 'SE', 'Vyn', 14.2833, 55.4833, 14.3135520, 55.4959517);  -- moves 2,369 m

do $$
declare bad text;
begin
  if (select count(*) from _loc_restaurant) <> 101 then raise exception 'expected 101 rows'; end if;
  select string_agg(l.code, ', ') into bad from _loc_restaurant l
   where not exists (select 1 from public.restaurants x where x.restaurant_code = l.code and x.name = l.name and x.country_code = l.country);
  if bad is not null then raise exception 'code is no longer the expected row: %', bad; end if;
  select string_agg(l.code, ', ') into bad from _loc_restaurant l join public.restaurants x on x.restaurant_code = l.code
   where not ST_DWithin(x.location, ST_SetSRID(ST_MakePoint(l.old_lon, l.old_lat), 4326)::geography, 5)
     and not ST_DWithin(x.location, ST_SetSRID(ST_MakePoint(l.new_lon, l.new_lat), 4326)::geography, 1);
  if bad is not null then raise exception 'point changed since this file was prepared: %', bad; end if;
end $$;

-- move only while the row still holds the old point (never overwrites a later fix)
update public.restaurants x set location = ST_SetSRID(ST_MakePoint(l.new_lon, l.new_lat), 4326)::geography, updated_at = now()
  from _loc_restaurant l
 where x.restaurant_code = l.code
   and ST_DWithin(x.location, ST_SetSRID(ST_MakePoint(l.old_lon, l.old_lat), 4326)::geography, 5);

do $$
declare n int;
begin
  select count(*) into n from _loc_restaurant l join public.restaurants x on x.restaurant_code = l.code
   where ST_DWithin(x.location, ST_SetSRID(ST_MakePoint(l.new_lon, l.new_lat), 4326)::geography, 1);
  if n <> 101 then raise exception 'only % of 101 rows at the new point; rolled back', n; end if;
end $$;
commit;
