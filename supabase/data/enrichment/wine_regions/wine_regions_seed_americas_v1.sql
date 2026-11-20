-- Wine regions of the United States, Argentina and Chile. Written
-- 2026-11-20 (product owner: "I want to add the wine regions in North and
-- South-America"; first batch "USA" and "Argentina + Chile").
--
-- The areas are official (outlines/communes/wr_0021..0031_notes.md):
-- TTB's AVA polygons (27 CFR part 9) for Napa Valley, Willamette Valley,
-- Paso Robles and the Finger Lakes; the county for Sonoma County (a
-- county is a legal US appellation, 27 CFR 4.25(a)(1)(iv)); INV's
-- geographical indications by departamento for Mendoza (the province),
-- Valle de Uco and Cafayate; Decreto 464 by comuna for Maipo (the whole
-- Metropolitan Region), Colchagua and Casablanca. Label notes keep to
-- those texts.
--
-- The official texts say nothing about grapes or style, so the summaries,
-- grape notes, taste scales, pairings and wine-list names below are our
-- own editorial draft from general wine knowledge, like
-- wine_regions_seed_v1.sql: to be checked and fine-tuned.
--
-- latitude/longitude: a point inside the outline; radius_km: from the
-- outline's area. Outlines: run outlines/wine_region_outlines.sql after.

begin;

insert into public.wine_regions
  (region_code, name, aliases, country_code, latitude, longitude, radius_km,
   summary, red_body, red_acidity, red_tannin, pairing, label_note,
   source_url, publication_status)
values
  ('wr_0021', 'Napa Valley', '{Napa}', 'US', 38.460, -122.314, 23,
   'A valley north of San Francisco Bay, warm and sunny, with fog from the bay cooling its southern end. Best known for ripe, powerful Cabernet Sauvignon.',
   4, 3, 4, 'Grilled beef, lamb, aged hard cheese.',
   'Napa Valley on the label means at least 85% of the grapes come from it. Oakville, Rutherford and Stags Leap District are smaller AVAs inside it.',
   'https://www.ecfr.gov/current/title-27/chapter-I/subchapter-A/part-9/subpart-C/section-9.23',
   'published'),
  ('wr_0022', 'Sonoma County', '{Sonoma}', 'US', 38.498, -122.874, 36,
   'Larger and more varied than Napa, from the cool, foggy coast to warm inland valleys: Pinot Noir and Chardonnay near the sea, Zinfandel and Cabernet Sauvignon inland.',
   3, 3, 3, 'Salmon, roast chicken, pork.',
   '''Sonoma County'' on the label means at least 75% of the grapes come from the county. Its AVAs, such as Russian River Valley, are smaller areas with stricter rules.',
   'https://www.ecfr.gov/current/title-27/chapter-I/subchapter-A/part-4/subpart-D/section-4.25',
   'published'),
  ('wr_0023', 'Willamette Valley', '{Willamette}', 'US', 44.680, -123.174, 69,
   'Oregon''s main wine valley, between the Coast Range and the Cascades: cool and often rainy, with dry summers. Famous for elegant Pinot Noir.',
   2, 4, 2, 'Salmon, duck, mushrooms.',
   'Dundee Hills and Eola-Amity Hills are among the smaller AVAs inside it.',
   'https://www.ecfr.gov/current/title-27/chapter-I/subchapter-A/part-9/subpart-C/section-9.90',
   'published'),
  ('wr_0024', 'Paso Robles', '{}', 'US', 35.559, -120.505, 28,
   'Rolling hills halfway between San Francisco and Los Angeles, shielded from the sea by the Santa Lucia Mountains: hot days and cold nights. Rich reds from Cabernet Sauvignon, Zinfandel and Rhône grapes.',
   4, 3, 3, 'Barbecue, grilled meat.',
   'Since 2014 it holds eleven smaller AVAs; their labels must also say Paso Robles.',
   'https://www.ecfr.gov/current/title-27/chapter-I/subchapter-A/part-9/subpart-C/section-9.84',
   'published'),
  ('wr_0025', 'Finger Lakes', '{}', 'US', 42.695, -76.980, 54,
   'Long, deep glacial lakes in upstate New York that soften the hard winters. Best known for Riesling, from bone-dry to sweet.',
   2, 4, 2, 'Spicy dishes, pork, fresh cheese.', null,
   'https://www.ecfr.gov/current/title-27/chapter-I/subchapter-A/part-9/subpart-C/section-9.34',
   'published'),
  ('wr_0026', 'Mendoza', '{}', 'AR', -34.794, -68.436, 218,
   'Argentina''s heartland of wine: high, dry and sunny at the foot of the Andes, the vineyards watered with snowmelt. Malbec here is plush, dark and violet-scented.',
   4, 3, 3, 'Grilled beef, asado.',
   'Mendoza is a geographical indication for the whole province; its departments, such as Luján de Cuyo, and the Uco Valley have their own.',
   'https://www.argentina.gob.ar/inv',
   'published'),
  ('wr_0027', 'Valle de Uco', '{"Uco Valley",Uco}', 'AR', -33.870, -69.086, 75,
   'The high valley south of Mendoza city, its vineyards among the highest in the province: cold nights keep the wines fresh and fragrant.',
   4, 4, 3, 'Lamb, grilled beef.',
   'An indication of its own inside Mendoza: the departments of Tupungato, Tunuyán and San Carlos.',
   'https://www.argentina.gob.ar/inv',
   'published'),
  ('wr_0028', 'Cafayate', '{"Valle de Cafayate",Salta}', 'AR', -26.090, -65.919, 22,
   'In the Calchaquí valleys of Salta, among the highest vineyards in the world: dry, sunny, with big swings between day and night. Home of aromatic Torrontés; the reds are dark and concentrated.',
   4, 3, 4, 'Empanadas, spicy dishes, goat''s cheese.',
   'Labelled Valle de Cafayate: INV''s register notes that Cafayate alone is a registered trademark.',
   'https://www.argentina.gob.ar/inv',
   'published'),
  ('wr_0029', 'Valle del Maipo', '{Maipo,"Maipo Valley"}', 'CL', -33.636, -70.631, 70,
   'Around Santiago, between the Andes and the coastal range: Chile''s classic Cabernet country, ripe, with a minty, herbal edge.',
   4, 3, 4, 'Grilled beef, empanadas.',
   'By decree it covers the whole Metropolitan Region; Puente Alto is one of its named areas.',
   'https://www.bcn.cl/leychile/navegar?idNorma=13601',
   'published'),
  ('wr_0030', 'Valle de Colchagua', '{Colchagua,"Colchagua Valley"}', 'CL', -34.451, -71.683, 54,
   'A broad valley south of Santiago running from the Andes to the Pacific: warm in the middle, cooler toward the coast. Full, ripe reds, Carménère above all.',
   4, 3, 3, 'Roast pork, lamb, spicy dishes.',
   'Part of the Rapel Valley: the provinces of Colchagua and Cardenal Caro.',
   'https://www.bcn.cl/leychile/navegar?idNorma=13601',
   'published'),
  ('wr_0031', 'Valle de Casablanca', '{Casablanca,"Casablanca Valley"}', 'CL', -33.329, -71.368, 18,
   'Between Santiago and Valparaíso, cooled by Pacific fog and breeze: Chile''s cool-climate white wine country, with crisp Sauvignon Blanc and Chardonnay.',
   2, 4, 2, 'Oysters, ceviche, goat''s cheese.',
   'May carry ''Costa'' (coast) on the label when at least 85% of the wine comes from the valley.',
   'https://www.bcn.cl/leychile/navegar?idNorma=13601',
   'published');

insert into public.grapes
  (grape_code, name, aliases, colour, summary, tastes, aged_note,
   body, acidity, tannin, publication_status)
values
  ('gr_0028', 'Zinfandel', '{Primitivo}', 'red',
   'California''s own story, though the grape came from Croatia: ripe, jammy and spicy, often high in alcohol.',
   '{Blackberry,"Black pepper",Raisin}', null, 4, 3, 3, 'published'),
  ('gr_0029', 'Malbec', '{Côt}', 'red',
   'A grape from south-west France that found its home in Argentina: deep purple, plush, with soft tannins.',
   '{Plum,Blackberry,Violet}', 'cocoa, tobacco', 4, 3, 3, 'published'),
  ('gr_0030', 'Carménère', '{Carmenere}', 'red',
   'Once a Bordeaux grape, rediscovered in Chile in the 1990s, where it had been mistaken for Merlot: soft, with a green-pepper edge.',
   '{"Red plum","Bell pepper",Paprika}', null, 3, 3, 3, 'published'),
  ('gr_0031', 'Torrontés', '{Torrontes}', 'white',
   'Argentina''s signature white: intensely floral on the nose, usually dry in the mouth.',
   '{Rose,Peach,"Lemon zest"}', null, 2, 3, null, 'published');

update public.grapes g set similar_grape_id = s.id, similar_note = v.note
from (values
  ('gr_0029', 'gr_0004', 'just as plush, a little softer'),
  ('gr_0030', 'gr_0004', 'it was long mistaken for it'),
  ('gr_0028', 'gr_0005', 'just as dark and peppery')
) as v(code, sim, note)
join public.grapes s on s.grape_code = v.sim
where g.grape_code = v.code;

insert into public.wine_region_grapes (region_id, grape_id, local_note, display_order)
select r.id, g.id, v.note, v.ord
from (values
  ('wr_0021', 'gr_0003', 'the valley''s signature: ripe, dark, firm', 1),
  ('wr_0021', 'gr_0004', null, 2),
  ('wr_0021', 'gr_0002', 'from the cooler south end', 3),
  ('wr_0022', 'gr_0001', 'near the cool coast', 1),
  ('wr_0022', 'gr_0002', null, 2),
  ('wr_0022', 'gr_0028', 'old vines, inland', 3),
  ('wr_0022', 'gr_0003', 'in the warm Alexander Valley', 4),
  ('wr_0023', 'gr_0001', 'elegant, earthy, red-fruited', 1),
  ('wr_0023', 'gr_0024', null, 2),
  ('wr_0023', 'gr_0002', null, 3),
  ('wr_0024', 'gr_0003', null, 1),
  ('wr_0024', 'gr_0028', 'ripe and spicy', 2),
  ('wr_0024', 'gr_0005', null, 3),
  ('wr_0024', 'gr_0006', null, 4),
  ('wr_0025', 'gr_0008', 'racy, dry to sweet', 1),
  ('wr_0025', 'gr_0013', null, 2),
  ('wr_0025', 'gr_0001', null, 3),
  ('wr_0026', 'gr_0029', 'plush, violet-scented', 1),
  ('wr_0026', 'gr_0003', null, 2),
  ('wr_0026', 'gr_0002', null, 3),
  ('wr_0027', 'gr_0029', 'fresher and more fragrant at altitude', 1),
  ('wr_0027', 'gr_0002', null, 2),
  ('wr_0027', 'gr_0013', null, 3),
  ('wr_0028', 'gr_0031', 'floral and dry', 1),
  ('wr_0028', 'gr_0029', 'dark and concentrated', 2),
  ('wr_0028', 'gr_0003', null, 3),
  ('wr_0029', 'gr_0003', 'ripe, with a minty edge', 1),
  ('wr_0029', 'gr_0030', null, 2),
  ('wr_0029', 'gr_0004', null, 3),
  ('wr_0030', 'gr_0030', 'full and ripe', 1),
  ('wr_0030', 'gr_0003', null, 2),
  ('wr_0030', 'gr_0005', null, 3),
  ('wr_0031', 'gr_0011', 'crisp and herbal', 1),
  ('wr_0031', 'gr_0002', null, 2),
  ('wr_0031', 'gr_0001', null, 3)
) as v(region, grape, note, ord)
join public.wine_regions r on r.region_code = v.region
join public.grapes g on g.grape_code = v.grape;

-- Names on a wine list, and the region they belong to.
insert into public.wine_appellations
  (appellation_code, name, aliases, region_id, colour, note, display_order,
   publication_status)
select v.code, v.name, v.aliases::text[], r.id, v.colour, v.note, v.ord, 'published'
from (values
  ('wa_0034', 'Oakville', '{}', 'wr_0021', 'red', 'Cabernet: rich, polished', 1),
  ('wa_0035', 'Rutherford', '{}', 'wr_0021', 'red', 'Cabernet with a dusty edge', 2),
  ('wa_0036', 'Stags Leap District', '{"Stags Leap"}', 'wr_0021', 'red', 'Cabernet: softer, silky', 3),
  ('wa_0037', 'Russian River Valley', '{"Russian River"}', 'wr_0022', 'mixed', 'cool: Pinot Noir and Chardonnay', 1),
  ('wa_0038', 'Alexander Valley', '{}', 'wr_0022', 'red', 'warm: round Cabernet', 2),
  ('wa_0039', 'Dundee Hills', '{}', 'wr_0023', 'red', 'Pinot Noir on red volcanic soil', 1),
  ('wa_0040', 'Eola-Amity Hills', '{"Eola Amity Hills"}', 'wr_0023', 'red', 'Pinot Noir, cooled by evening winds', 2),
  ('wa_0041', 'Luján de Cuyo', '{"Lujan de Cuyo"}', 'wr_0026', 'red', 'Malbec''s historic heart', 1),
  ('wa_0042', 'Maipú', '{Maipu}', 'wr_0026', 'red', 'old vineyards close to the city', 2),
  ('wa_0043', 'Puente Alto', '{}', 'wr_0029', 'red', 'Cabernet at the foot of the Andes', 1)
) as v(code, name, aliases, region, colour, note, ord)
join public.wine_regions r on r.region_code = v.region;

commit;
