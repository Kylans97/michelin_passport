-- The nine Dutch protected wine regions (BOB), with the grapes they grow.
-- Written 2026-11-20 (product owner: "can we add the Dutch wine
-- regions?"; then "All 9 separately").
--
-- Sources: each region's product dossier on RVO's official list
-- (https://www.rvo.nl/onderwerpen/marktordening/wijn-olijfolie/wijn/europese-bescherming),
-- in region.source_url. Summaries keep to what the dossier itself says
-- about soil, climate and style; the grapes linked are ones the dossier
-- permits. No pairing advice and no red-wine scale are given: the
-- dossiers don't say. Research notes per region, with every judgement
-- call: outlines/communes/ and outlines/communes_reference/.
--
-- latitude/longitude: a point inside the drawn outline, or, for the
-- three regions not drawn, inside the municipalities the dossier names.
-- radius_km: from the dossier's own area where it gives one, else the
-- outline's, at the column's minimum of 5 for the smallest.
--
-- The new grapes' texts are our own editorial draft from general wine
-- knowledge, like wine_regions_seed_v1.sql: to be checked and fine-tuned.
--
-- Outlines: run outlines/wine_region_outlines.sql after this file.

begin;

insert into public.wine_regions
  (region_code, name, aliases, country_code, latitude, longitude, radius_km,
   summary, source_url, publication_status)
values
  ('wr_0012', 'Achterhoek-Winterswijk', '{Winterswijk}', 'NL', 51.969, 6.739, 7,
   'The whole municipality of Winterswijk, on the East Netherlands Plateau: loam and lime over old sandstone and limestone, and a more continental climate than the rest of the country. The dossier promises freshness and full fruit in the whites and rosés, soft tannins in the reds.',
   'https://www.rvo.nl/sites/default/files/2026-09/Productdossier-BOB-Achterhoek-Winterswijk.pdf',
   'published'),
  ('wr_0013', 'Maasvallei Limburg', '{Maasvallei}', 'NL', 51.079, 5.822, 7,
   'A narrow strip along both banks of the Maas, shared by Dutch and Belgian Limburg. Under the loam lies Maas gravel of limestone, quartz and flint, which the dossier credits with mineral flavours and fine acidity. Sheltered by the Kempen plateau, with the Maas lakes softening frost.',
   'https://www.rvo.nl/sites/default/files/2026-09/Productdossier-BOB-Maasvallei-Limburg.pdf',
   'published'),
  ('wr_0014', 'Mergelland', '{}', 'NL', 50.834, 5.827, 12,
   'The hills of South Limburg: loess over the soft limestone called mergel, from 49 to 322 metres, in a cool climate. Mostly classic varieties, still and sparkling. In the dossier''s words, fruit, fresh elegance and minerality.',
   'https://www.rvo.nl/sites/default/files/2026-09/Productdossier-BOB-Mergelland.pdf',
   'published'),
  ('wr_0015', 'Oolde', '{}', 'NL', 52.205, 6.340, 5,
   'A historic neighbourhood near Laren, in Gelderland, with one producer. Loamy fine sand, often under a cover of river clay. Fresh, fruity whites and rosés, and reds with soft tannins.',
   'https://www.rvo.nl/sites/default/files/2026-09/Productdossier-BOB-Oolde.pdf',
   'published'),
  ('wr_0016', 'Rivierenland', '{}', 'NL', 51.932, 5.559, 31,
   'The land within five kilometres of the great rivers flowing into Gelderland: fertile river clay, a cool climate, ripening into September and October, in the rain shadow of the Veluwe. Disease-resistant grapes only. Full fruit and fresh acidity; supple reds.',
   'https://www.rvo.nl/sites/default/files/2026-08/Productdossier-BOB-Rivierenland.pdf',
   'published'),
  ('wr_0017', 'Schouwen-Duiveland', '{}', 'NL', 51.690, 3.964, 9,
   'An island in Zeeland: calcareous sea clay with shell lime, more sun and less rain than the rest of the country, and a salty sea wind. White wine only, still and sparkling, with pronounced freshness and minerality.',
   'https://www.rvo.nl/sites/default/files/2026-09/Productdossier-BOB-Schouwen-Duiveland.pdf',
   'published'),
  ('wr_0018', 'Twente', '{}', 'NL', 52.310, 6.688, 22,
   'The fourteen municipalities of eastern Overijssel, though only vines on its loamy sands and boulder clay qualify. Whites, rosés and reds from classic and disease-resistant grapes, plus sparkling and sweet wines.',
   'https://www.rvo.nl/sites/default/files/2026-09/Productdossier-BOB-Twente.pdf',
   'published'),
  ('wr_0019', 'Vijlen', '{}', 'NL', 50.780, 5.964, 5,
   'Around Vijlen, at about 200 metres the highest village in the Netherlands: stony loess over flint, on south slopes and the plateau. Warmer nights and little autumn fog give riper grapes, and in the dossier''s words fuller, more expressive wines.',
   'https://www.rvo.nl/sites/default/files/2026-09/Productdossier-BOB-Vijlen.pdf',
   'published'),
  ('wr_0020', 'Voerendaalse Bergen', '{}', 'NL', 50.874, 5.911, 5,
   'Six steep, south-facing limestone slopes around Voerendaal, in South Limburg. Fruity whites and rosés, reds with red-cherry and berry fruit, and sparkling wines; the dossier credits the limestone with a light sparkle.',
   'https://www.rvo.nl/sites/default/files/2026-09/Productdossier-BOB-Voerendaalse-Bergen.pdf',
   'published');

-- Grapes these regions grow that the atlas didn't have yet.
insert into public.grapes
  (grape_code, name, aliases, colour, summary, tastes, aged_note,
   body, acidity, tannin, publication_status)
values
  ('gr_0018', 'Solaris', '{}', 'white',
   'Bred for cool climates: ripens early and resists disease. Ripe and aromatic, often fuller than you''d expect this far north.',
   '{"Ripe pear",Pineapple,Elderflower}', null, 3, 3, null, 'published'),
  ('gr_0019', 'Johanniter', '{}', 'white',
   'A disease-resistant grape with Riesling among its parents: fresh and fruity, in a lighter Riesling style.',
   '{"Green apple",Lemon,Peach}', null, 2, 4, null, 'published'),
  ('gr_0020', 'Souvignier Gris', '{}', 'white',
   'A newer disease-resistant grape with a pink skin: fresh, with a little more body than most.',
   '{Pear,Grapefruit,Melon}', null, 3, 4, null, 'published'),
  ('gr_0021', 'Regent', '{}', 'red',
   'The most widely planted disease-resistant red in northern Europe: deep in colour, with soft tannins.',
   '{Cherry,Blackcurrant,Plum}', null, 3, 3, 2, 'published'),
  ('gr_0022', 'Auxerrois', '{"Auxerrois Blanc"}', 'white',
   'A gentle, low-acid white related to Pinot Blanc and Chardonnay, at home in Alsace and Luxembourg: round and mild.',
   '{Melon,"Yellow apple",Honey}', null, 3, 2, null, 'published'),
  ('gr_0023', 'Müller-Thurgau', '{Rivaner}', 'white',
   'Early and easy: light, soft and floral.',
   '{Peach,Citrus,"White flowers"}', null, 2, 3, null, 'published'),
  ('gr_0024', 'Pinot Gris', '{"Pinot Grigio",Grauburgunder}', 'white',
   'From crisp and light as Italian Pinot Grigio to rich and spicy in Alsace.',
   '{Pear,Lemon,Honey}', null, 3, 3, null, 'published'),
  ('gr_0025', 'Cabernet Cortis', '{}', 'red',
   'A disease-resistant grape with Cabernet Sauvignon as a parent: dark, and a little herbal.',
   '{Blackcurrant,Blackberry,"Bell pepper"}', null, 3, 3, 3, 'published'),
  ('gr_0026', 'Pinotin', '{}', 'red',
   'A disease-resistant grape bred to taste like Pinot Noir: light, with red fruit.',
   '{"Red cherry",Raspberry}', null, 2, 3, 2, 'published'),
  ('gr_0027', 'Cabernet Blanc', '{}', 'white',
   'A disease-resistant white with a Sauvignon Blanc-like freshness.',
   '{Gooseberry,Grapefruit,"Cut grass"}', null, 2, 4, null, 'published');

update public.grapes g set similar_grape_id = s.id, similar_note = v.note
from (values
  ('gr_0026', 'gr_0001', 'the original: more delicate'),
  ('gr_0027', 'gr_0011', 'the classic it resembles'),
  ('gr_0019', 'gr_0008', 'the parent: more intense')
) as v(code, sim, note)
join public.grapes s on s.grape_code = v.sim
where g.grape_code = v.code;

-- Which grapes each region is known for: from each dossier's permitted
-- list, the main ones, in the dossier's own order where it has one.
insert into public.wine_region_grapes (region_id, grape_id, local_note, display_order)
select r.id, g.id, v.note, v.ord
from (values
  ('wr_0012', 'gr_0019', null, 1), ('wr_0012', 'gr_0018', null, 2),
  ('wr_0012', 'gr_0020', null, 3), ('wr_0012', 'gr_0021', null, 4),
  ('wr_0013', 'gr_0022', null, 1), ('wr_0013', 'gr_0024', null, 2),
  ('wr_0013', 'gr_0008', null, 3), ('wr_0013', 'gr_0002', null, 4),
  ('wr_0013', 'gr_0001', 'white, rosé and red', 5),
  ('wr_0014', 'gr_0022', null, 1), ('wr_0014', 'gr_0024', null, 2),
  ('wr_0014', 'gr_0008', null, 3), ('wr_0014', 'gr_0023', 'as Rivaner', 4),
  ('wr_0014', 'gr_0002', null, 5), ('wr_0014', 'gr_0001', 'red, rosé and blanc de noirs', 6),
  ('wr_0015', 'gr_0027', 'dry, and the sparkling', 1), ('wr_0015', 'gr_0018', 'dry and full, or late-harvest', 2),
  ('wr_0015', 'gr_0021', null, 3), ('wr_0015', 'gr_0026', null, 4),
  ('wr_0016', 'gr_0019', null, 1), ('wr_0016', 'gr_0018', null, 2),
  ('wr_0016', 'gr_0020', null, 3), ('wr_0016', 'gr_0027', null, 4),
  ('wr_0016', 'gr_0021', null, 5), ('wr_0016', 'gr_0025', null, 6),
  ('wr_0016', 'gr_0026', null, 7),
  ('wr_0017', 'gr_0022', null, 1), ('wr_0017', 'gr_0024', null, 2),
  ('wr_0017', 'gr_0020', null, 3), ('wr_0017', 'gr_0027', null, 4),
  ('wr_0017', 'gr_0023', 'as Rivaner', 5),
  ('wr_0018', 'gr_0019', null, 1), ('wr_0018', 'gr_0018', null, 2),
  ('wr_0018', 'gr_0020', null, 3), ('wr_0018', 'gr_0024', null, 4),
  ('wr_0018', 'gr_0021', null, 5), ('wr_0018', 'gr_0026', null, 6),
  ('wr_0018', 'gr_0001', null, 7),
  ('wr_0019', 'gr_0024', null, 1), ('wr_0019', 'gr_0019', null, 2),
  ('wr_0019', 'gr_0018', null, 3), ('wr_0019', 'gr_0020', null, 4),
  ('wr_0019', 'gr_0001', null, 5), ('wr_0019', 'gr_0025', null, 6),
  ('wr_0020', 'gr_0022', null, 1), ('wr_0020', 'gr_0008', null, 2),
  ('wr_0020', 'gr_0023', null, 3), ('wr_0020', 'gr_0018', null, 4),
  ('wr_0020', 'gr_0001', null, 5)
) as v(region, grape, note, ord)
join public.wine_regions r on r.region_code = v.region
join public.grapes g on g.grape_code = v.grape;

commit;
