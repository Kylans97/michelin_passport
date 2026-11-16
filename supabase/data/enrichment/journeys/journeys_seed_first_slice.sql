-- Journeys, first slice: the recommended set the product owner approved on
-- 2026-11-16 (9 trains, 11 ships). PREPARED, NOT APPLIED to production.
-- Needs migration 20261101500000_add_journeys.sql first.
--
-- Every value comes from trains_candidates.csv / ships_candidates.csv in this
-- folder, which carry an operator source per row. Anything those files mark
-- unverified is left out: no capacity where only cabins are stated, no
-- night count where the operator gives days, no route without a published
-- start and end, no star claims in dining_text (the ships' chef claims are
-- the operators' own words and still need checking against the Guide).
--
-- Held back from the restaurant links: Jean Imbert for the Venice
-- Simplon-Orient-Express. rest_0972 is now "La Grande Table du Plaza
-- Athénée" in production, and whether Imbert still cooks there was not
-- checked, so the train's dining_text names him and no restaurant is linked.
--
-- Two countries a route needs are not in public.countries (BB, KH), so the
-- Corinthian's Lisbon – Barbados crossing is left out and Aqua Mekong has
-- no primary country; adding them is its own migration.

begin;

insert into public.journey_operators (operator_code, name, website_url) values
  ('op_001', 'Belmond',                          'https://www.belmond.com/'),
  ('op_002', 'Orient Express',                   'https://www.orient-express.com/'),
  ('op_003', 'Golden Eagle Luxury Trains',       'https://www.goldeneagleluxurytrains.com/'),
  ('op_004', 'IRCTC',                            'https://www.the-maharajas.com/'),
  ('op_005', 'JR West',                          'https://twilightexpress-mizukaze.jp/en/'),
  ('op_006', 'Four Seasons Yachts',              'https://www.fourseasons.com/yachts/'),
  ('op_007', 'The Ritz-Carlton Yacht Collection','https://www.ritzcarltonyachtcollection.com/'),
  ('op_008', 'Aqua Expeditions',                 'https://www.aquaexpeditions.com/'),
  ('op_009', 'Aman',                             'https://www.aman.com/aman-yachts'),
  ('op_010', 'PONANT',                           'https://www.ponant.com/');

insert into public.journeys
  (journey_code, slug, kind, ship_type, name, operator_id, primary_country_code,
   regions_text, status, summary, cabins_text, guest_capacity, dining_text,
   official_url, publication_status)
select v.journey_code, v.slug, v.kind, v.ship_type, v.name, o.id,
       v.country, v.regions, 'operating', v.summary, v.cabins, v.capacity,
       v.dining, v.url, 'published'
from (values
  -- Trains
  ('train_001', 'venice-simplon-orient-express', 'train', null::text,
   'Venice Simplon-Orient-Express', 'op_001', null::char(2), 'Europe',
   'Historic sleeper train between Paris, Venice and other European cities, with a five-night Istanbul – Paris journey.',
   'Historic Cabins (32), Suites (16), Grand Suites (6), L''Observatoire Suite (1)', null::smallint,
   'Three restaurant cars and a bar car. Chef of the train: Jean Imbert.',
   'https://www.belmond.com/trains/europe/venice-simplon-orient-express/'),
  ('train_002', 'belmond-andean-explorer', 'train', null,
   'Belmond Andean Explorer', 'op_001', 'PE', 'Peruvian Andes',
   'Sleeper train across the Peruvian highlands between Cusco, Lake Titicaca and Arequipa.',
   '35 sleeper cabins: twin and bunk-bed cabins', null,
   'Two dining cars serving Peruvian cuisine, full board; piano bar, spa and observation cars.',
   'https://www.belmond.com/trains/south-america/peru/belmond-andean-explorer/'),
  ('train_003', 'belmond-royal-scotsman', 'train', null,
   'Belmond Royal Scotsman', 'op_001', 'GB', 'Scotland',
   'Journeys through the Scottish Highlands, all from Edinburgh Waverley.',
   'Double and twin cabins, suites and a Grand Suite', null,
   'Meals included daily in the dining cars. "A Taste of Scotland" departures are hosted by Tom Kitchin, Lorna McNee and Mark Donald.',
   'https://www.belmond.com/trains/europe/scotland/belmond-royal-scotsman/'),
  ('train_004', 'eastern-and-oriental-express', 'train', null,
   'Eastern & Oriental Express', 'op_001', null, 'Singapore and Malaysia',
   'Round trips from Singapore through Malaysia, and a six-night journey to Langkawi.',
   'Presidential Suites (2), State Cabins (20), Pullman Cabins (10)', null,
   'Two dining cars and a piano bar. Culinary curator: André Chiang.',
   'https://www.belmond.com/trains/asia/eastern-and-oriental-express/'),
  ('train_005', 'britannic-explorer', 'train', null,
   'Britannic Explorer', 'op_001', 'GB', 'England and Wales',
   'Round trips from London Victoria to the Lake District, Cornwall and Wales.',
   'Grand Suites (3), Twin Suites (4), Double Suites (11)', null,
   'Two restaurant cars and a bar and observation car, all inclusive. Menus curated by Simon Rogan.',
   'https://www.belmond.com/trains/europe/uk/britannic-explorer/'),
  ('train_006', 'la-dolce-vita-orient-express', 'train', null,
   'La Dolce Vita Orient Express', 'op_002', 'IT', 'Italy',
   'Journeys through Italy from Rome, Venice and Palermo, and a Rome – Istanbul journey.',
   'La Dolce Vita Suite, Suites and Deluxe cabins', null,
   'Dining curated by Heinz Beck.',
   'https://www.orient-express.com/la-dolce-vita/'),
  ('train_007', 'golden-eagle-danube-express', 'train', null,
   'Golden Eagle Danube Express', 'op_003', null, 'Europe',
   'Long journeys across Europe, including Paris – Istanbul and the Balkans.',
   'Superior Deluxe and Deluxe cabins', null,
   'Restaurant cars seat every guest in one sitting.',
   'https://www.goldeneagleluxurytrains.com/'),
  ('train_008', 'maharajas-express', 'train', null,
   'Maharajas'' Express', 'op_004', 'IN', 'India',
   'Journeys between Delhi and Mumbai through Rajasthan, Agra and Varanasi, from October to April.',
   'Deluxe Cabins, Junior Suites, Suites and the Presidential Suite', null,
   'Two restaurant cars, Rang Mahal and Mayur Mahal, with a club car and a bar.',
   'https://www.the-maharajas.com/'),
  ('train_009', 'twilight-express-mizukaze', 'train', null,
   'Twilight Express Mizukaze', 'op_005', 'JP', 'Western Japan',
   'Sleeper train through western Japan between Kyoto and Shimonoseki.',
   null, null,
   'Dining with tastes from along the route.',
   'https://twilightexpress-mizukaze.jp/en/'),
  -- Ships
  ('ship_001', 'four-seasons-i', 'ship', 'yacht',
   'Four Seasons I', 'op_006', null, 'Mediterranean in summer, Caribbean and Bahamas in winter',
   'Four Seasons'' first yacht, in service since March 2026.',
   '95 suites', 222,
   'Eleven restaurants and lounges. At Sedna, chefs-in-residence from Four Seasons restaurants.',
   'https://www.fourseasons.com/yachts/'),
  ('ship_002', 'orient-express-corinthian', 'ship', 'sailing_yacht',
   'Orient Express Corinthian', 'op_002', null, 'Mediterranean and Caribbean',
   'Ocean-going sailing yacht, in service since May 2026, on voyages of three to seven nights.',
   '54 suites', 110,
   'Two restaurants and two private dining rooms. La Table de l''Orient Express by Yannick Alléno.',
   'https://www.orient-express.com/en/sailing-yachts'),
  ('ship_003', 'evrima', 'ship', 'yacht',
   'Evrima', 'op_007', null, null,
   'The first yacht of The Ritz-Carlton Yacht Collection.',
   '149 suites', 298,
   'Five dining options, including S.E.A. by Sven Elverfeld.',
   'https://www.ritzcarltonyachtcollection.com/yachts/evrima'),
  ('ship_004', 'aqua-nera', 'ship', 'river',
   'Aqua Nera', 'op_008', 'PE', 'Peruvian Amazon',
   'River ship on the Amazon in Peru.',
   '20 suites', 40,
   'Menus by Pedro Miguel Schiaffino.',
   'https://www.aquaexpeditions.com/cruise-ships/aqua-nera'),
  ('ship_005', 'aqua-mekong', 'ship', 'river',
   'Aqua Mekong', 'op_008', null, 'Mekong River, Cambodia and Vietnam',
   'River ship on the Mekong through Cambodia and Vietnam.',
   '20 suites', 40,
   'Cuisine from local produce, with market visits. Consulting chef: Benjamin Cross.',
   'https://www.aquaexpeditions.com/cruise-ships/aqua-mekong'),
  ('ship_006', 'aqua-blu', 'ship', 'expedition',
   'Aqua Blu', 'op_008', 'ID', 'Eastern Indonesia',
   'Expedition yacht in eastern Indonesia: Komodo, Raja Ampat and the Spice Islands.',
   '15 suites', 30,
   'Consulting chef: Benjamin Cross.',
   'https://www.aquaexpeditions.com/cruise-ships/aqua-blu'),
  ('ship_007', 'aqua-lares', 'ship', 'expedition',
   'Aqua Lares', 'op_008', null, 'Seychelles and Tanzania; Svalbard',
   'Expedition yacht in East Africa and the Arctic.',
   '15 cabins', 30,
   'Menus by Karime López.',
   'https://www.aquaexpeditions.com/cruise-ships/aqua-lares'),
  ('ship_008', 'amandira', 'ship', 'sailing_yacht',
   'Amandira', 'op_009', 'ID', 'Indonesia',
   'Phinisi sailing yacht, private charter only, in Komodo, Raja Ampat, the Spice Islands and Alor.',
   '5 cabins', 10,
   'Two private chefs among a crew of fifteen.',
   'https://www.aman.com/aman-yachts'),
  ('ship_009', 'le-commandant-charcot', 'ship', 'expedition',
   'Le Commandant Charcot', 'op_010', null, 'Polar regions',
   'Polar expedition ship.',
   '123 cabins and suites', 245,
   'Nuna, an Alain Ducasse restaurant.',
   'https://www.ponant.com/navires/le-commandant-charcot'),
  ('ship_010', 'le-ponant', 'ship', 'sailing_yacht',
   'Le Ponant', 'op_010', null, null,
   'Three-masted sailing yacht.',
   '16 cabins and suites', 32,
   'Le Diamant, cooking from the coasts visited.',
   'https://www.ponant.com/navires/le-ponant'),
  ('ship_011', 'napoleon-les-bateaux-belmond', 'ship', 'river',
   'Napoléon', 'op_001', 'FR', 'Rhône and Provence',
   'Hotel barge of Les Bateaux Belmond on the Rhône, by cabin or as a private charter.',
   '6 cabins', 12,
   'A private chef on board, all meals included. Fleet menus curated by Dominique Crenn.',
   'https://www.belmond.com/en/boats/europe/france/les-bateaux-belmond')
) as v(journey_code, slug, kind, ship_type, name, operator_code, country,
       regions, summary, cabins, capacity, dining, url)
join public.journey_operators o on o.operator_code = v.operator_code;

-- Routes: only those with a published start and end.
insert into public.journey_routes
  (journey_id, route_code, name, from_place, from_country_code, to_place,
   to_country_code, nights, duration_text, season_text, display_order)
select j.id, v.route_code, v.name, v.from_place, v.from_cc, v.to_place, v.to_cc,
       v.nights, v.duration_text, v.season_text, v.display_order
from (values
  ('train_001', 'train_001_r01', 'Paris – Venice',           'Paris', 'FR', 'Venice', 'IT', 1::smallint, null::text, null::text, 1::smallint),
  ('train_001', 'train_001_r02', 'Venice – Paris',           'Venice', 'IT', 'Paris', 'FR', 1, null, null, 2),
  ('train_001', 'train_001_r03', 'Brussels – Venice',        'Brussels', 'BE', 'Venice', 'IT', 1, null, null, 3),
  ('train_001', 'train_001_r04', 'Paris – Florence',         'Paris', 'FR', 'Florence', 'IT', 1, null, null, 4),
  ('train_001', 'train_001_r05', 'Paris – Vienna',           'Paris', 'FR', 'Vienna', 'AT', 1, null, null, 5),
  ('train_001', 'train_001_r06', 'Istanbul – Paris',         'Istanbul', 'TR', 'Paris', 'FR', 5, null, null, 6),
  ('train_001', 'train_001_r07', 'Paris – Portofino',        'Paris', 'FR', 'Portofino', 'IT', 3, null, null, 7),
  ('train_001', 'train_001_r08', 'Paris – Amalfi Coast',     'Paris', 'FR', 'Amalfi Coast', 'IT', 3, null, null, 8),
  ('train_002', 'train_002_r01', 'Peruvian Highlands',       'Cusco', 'PE', 'Arequipa', 'PE', 2, null, null, 1),
  ('train_003', 'train_003_r01', 'The Highlands',            'Edinburgh', 'GB', 'Edinburgh', 'GB', null, '2, 3 or 4 nights', null, 1),
  ('train_003', 'train_003_r02', 'A Taste of Scotland',      'Edinburgh', 'GB', 'Edinburgh', 'GB', 2, null, null, 2),
  ('train_003', 'train_003_r03', 'Scotland: The West Coast', 'Edinburgh', 'GB', 'Edinburgh', 'GB', 3, null, null, 3),
  ('train_003', 'train_003_r04', 'Wild Scotland',            'Edinburgh', 'GB', 'Edinburgh', 'GB', 3, null, null, 4),
  ('train_003', 'train_003_r05', 'Scotch Malt Whisky Tour',  'Edinburgh', 'GB', 'Edinburgh', 'GB', 4, null, null, 5),
  ('train_003', 'train_003_r06', 'Heritage Homes & Gardens', 'Edinburgh', 'GB', 'Edinburgh', 'GB', 4, null, null, 6),
  ('train_003', 'train_003_r07', 'Clans, Castles & Isles',   'Edinburgh', 'GB', 'Edinburgh', 'GB', 5, null, null, 7),
  ('train_003', 'train_003_r08', 'Grand Tour of Scotland',   'Edinburgh', 'GB', 'Edinburgh', 'GB', 7, null, null, 8),
  ('train_004', 'train_004_r01', 'Essence of Malaysia',      'Singapore', 'SG', 'Singapore', 'SG', 3, null, null, 1),
  ('train_004', 'train_004_r02', 'Wild Malaysia',            'Singapore', 'SG', 'Singapore', 'SG', 3, null, null, 2),
  ('train_004', 'train_004_r03', 'Tiger Express',            'Singapore', 'SG', 'The Datai Langkawi', 'MY', 6, null, null, 3),
  ('train_005', 'train_005_r01', 'The Lake District',        'London', 'GB', 'London', 'GB', 3, null, null, 1),
  ('train_005', 'train_005_r02', 'Cornwall',                 'London', 'GB', 'London', 'GB', 3, null, null, 2),
  ('train_005', 'train_005_r03', 'Wales',                    'London', 'GB', 'London', 'GB', 3, null, null, 3),
  ('train_005', 'train_005_r04', 'Cornwall & Wales',         'London', 'GB', 'London', 'GB', 6, null, null, 4),
  ('train_005', 'train_005_r05', 'The Lake District & Wales','London', 'GB', 'London', 'GB', 6, null, null, 5),
  ('train_006', 'train_006_r01', 'Magic Istanbul',           'Rome', 'IT', 'Istanbul', 'TR', null, null, null, 1),
  ('train_007', 'train_007_r01', 'Paris – Istanbul',         'Paris', 'FR', 'Istanbul', 'TR', null, '8 days', null, 1),
  ('train_007', 'train_007_r02', 'Istanbul – Paris',         'Istanbul', 'TR', 'Paris', 'FR', null, '8 days', null, 2),
  ('train_007', 'train_007_r03', 'Balkan Explorer',          'Venice', 'IT', 'Istanbul', 'TR', null, '12 days', null, 3),
  ('train_008', 'train_008_r01', 'The Indian Panorama',      'Delhi', 'IN', 'Delhi', 'IN', 6, null, 'October – April', 1),
  ('train_008', 'train_008_r02', 'Treasures of India',       'Delhi', 'IN', 'Delhi', 'IN', 3, null, 'October – April', 2),
  ('train_008', 'train_008_r03', 'The Indian Splendour',     'Delhi', 'IN', 'Mumbai', 'IN', 6, null, 'October – April', 3),
  ('train_008', 'train_008_r04', 'The Heritage of India',    'Mumbai', 'IN', 'Delhi', 'IN', 6, null, 'October – April', 4),
  ('train_009', 'train_009_r01', 'Sanin Course',             'Kyoto', 'JP', 'Shimonoseki', 'JP', null, null, null, 1),
  ('train_009', 'train_009_r02', 'Sanin Course',             'Shimonoseki', 'JP', 'Kyoto', 'JP', null, null, null, 2),
  ('ship_002',  'ship_002_r01',  'Marseille – Rome',         'Marseille', 'FR', 'Rome', 'IT', 3, null, null, 1),
  ('ship_011',  'ship_011_r01',  'Avignon – La Voulte-sur-Rhône', 'Avignon', 'FR', 'La Voulte-sur-Rhône', 'FR', 6, null, null, 1),
  ('ship_011',  'ship_011_r02',  'La Voulte-sur-Rhône – Avignon', 'La Voulte-sur-Rhône', 'FR', 'Avignon', 'FR', 6, null, null, 2)
) as v(journey_code, route_code, name, from_place, from_cc, to_place, to_cc,
       nights, duration_text, season_text, display_order)
join public.journeys j on j.journey_code = v.journey_code;

-- Every journey enters the Selection on the day it was decided.
insert into public.journey_selections (journey_id, selected_on)
select id, date '2026-11-16' from public.journeys;

-- Dining partnerships, by restaurant code plus country, never by name.
-- Refuses to finish if a code is missing or sits in another country.
do $$
declare
  wanted constant text[][] := array[
    array['train_006', 'rest_0382', 'IT'],  -- Heinz Beck, La Pergola
    array['train_005', 'rest_2529', 'GB'],  -- Simon Rogan, L'Enclume
    array['train_003', 'rest_2605', 'GB'],  -- Tom Kitchin, The Kitchin
    array['train_003', 'rest_2473', 'GB'],  -- Lorna McNee, Cail Bruich
    array['train_003', 'rest_2603', 'GB']   -- Mark Donald, The Glenturret Lalique
  ];
  w text[];
  n int;
begin
  foreach w slice 1 in array wanted loop
    insert into public.journey_restaurants (journey_id, restaurant_id)
    select j.id, r.id
    from public.journeys j, public.restaurants r
    where j.journey_code = w[1]
      and r.restaurant_code = w[2]
      and r.country_code = w[3];
    get diagnostics n = row_count;
    if n <> 1 then
      raise exception 'journey_restaurants: % / % (%) matched % rows', w[1], w[2], w[3], n;
    end if;
  end loop;
end $$;

commit;
