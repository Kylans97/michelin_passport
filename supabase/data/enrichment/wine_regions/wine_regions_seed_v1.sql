-- Wine regions, first set: DRAFT FOR REVIEW. Written 2026-11-20 (branch
-- claude/wine-regions) for the globe's wine layer
-- (20261101580000_add_wine_regions.sql). Not a migration and not applied:
-- reference content goes to production only after the product owner has
-- read it.
--
-- What to review:
-- * Every summary, taste word, pairing and label note is our own editorial
--   text, written from general wine knowledge. Check each against a
--   reference before publishing and fill source_url (the regions' official
--   bodies, or a reference such as the Oxford Companion to Wine). Nothing
--   here was copied from a source.
-- * latitude/longitude/radius_km place a soft patch on the globe. They are
--   approximate centres of each region, not boundaries, and should be
--   checked against a map.
-- * The 1-5 scales (body, acidity, tannin) are relative and meant for a
--   newcomer, not a tasting score.
-- * Deliberately left out: Vino Nobile di Montepulciano (a search for
--   "Montepulciano" would also mean the unrelated grape of Abruzzo), and
--   Beaujolais as a region (Gamay is in, as a grape to try).
--
-- Rows are inserted 'published' so the app shows them once this file is
-- applied; apply it only after review.

begin;

-- ------------------------------------------------------------
-- Regions
-- ------------------------------------------------------------
insert into public.wine_regions
  (region_code, name, aliases, country_code, latitude, longitude, radius_km,
   summary, red_body, red_acidity, red_tannin, pairing, label_note,
   publication_status)
values
  ('wr_0001', 'Burgundy', '{Bourgogne}', 'FR', 47.05, 4.85, 70,
   'A long, narrow strip of slopes where almost everything is one grape: Pinot Noir for red, Chardonnay for white. The village on the label tells you more than the grape does.',
   2, 4, 2, 'Duck, mushrooms, poultry, soft cheeses.',
   'From everyday to rare: Bourgogne, then a village name, Premier Cru, Grand Cru.',
   'published'),
  ('wr_0002', 'Bordeaux', '{}', 'FR', 44.85, -0.45, 60,
   'Red blends of Cabernet Sauvignon and Merlot from either side of the Gironde: Cabernet leads on the left bank, Merlot on the right. Also the sweet whites of Sauternes.',
   4, 3, 4, 'Lamb, beef, hard cheeses.',
   'The château leads the label; the appellation tells you the bank: Médoc and Pessac-Léognan on the left, Saint-Émilion and Pomerol on the right.',
   'published'),
  ('wr_0003', 'Champagne', '{}', 'FR', 49.05, 4.0, 50,
   'The cold north of France, where Chardonnay, Pinot Noir and Meunier become sparkling wine. Only wine from here may be called Champagne.',
   null, null, null, 'Oysters, fried food, as an aperitif.',
   'Brut is dry, Extra Brut drier still. Blanc de Blancs is Chardonnay only, Blanc de Noirs black grapes only. Non-vintage is the house style; a vintage comes from one good year.',
   'published'),
  ('wr_0004', 'Rhône Valley', '{Rhône,"Côtes du Rhône"}', 'FR', 44.9, 4.8, 110,
   'Two halves: the steep north makes Syrah, peppery and dark; the warm south blends Grenache with Syrah and Mourvèdre into rich, spicy reds.',
   4, 3, 3, 'Lamb, game, grilled meat, stews.',
   'Côtes du Rhône is the everyday name; village names such as Gigondas or Châteauneuf-du-Pape are a step up.',
   'published'),
  ('wr_0005', 'Loire Valley', '{Loire}', 'FR', 47.3, 0.4, 150,
   'France''s longest river, lined with fresh wines: Sauvignon Blanc in Sancerre, Chenin Blanc in Vouvray, light Cabernet Franc reds in Chinon.',
   2, 4, 2, 'Goat''s cheese, fish, salads, charcuterie.',
   null,
   'published'),
  ('wr_0006', 'Rioja', '{}', 'ES', 42.45, -2.45, 50,
   'Spain''s best-known red: mostly Tempranillo, often with Garnacha, traditionally aged in oak, which gives vanilla and spice.',
   3, 3, 3, 'Lamb, chorizo, roasted vegetables, Manchego.',
   'Crianza: at least two years old, some in oak. Reserva: aged longer, rounder. Gran Reserva: the longest aged, made in good years.',
   'published'),
  ('wr_0007', 'Ribera del Duero', '{Ribera}', 'ES', 41.65, -3.8, 50,
   'A high plateau along the Duero where Tempranillo, here called Tinto Fino, makes full, dark reds.',
   4, 3, 4, 'Roast lamb, beef, game.',
   'Crianza: at least two years old, some in oak. Reserva: aged longer, rounder. Gran Reserva: the longest aged, made in good years.',
   'published'),
  ('wr_0008', 'Douro', '{"Douro Valley"}', 'PT', 41.15, -7.6, 60,
   'Terraced slopes along the Douro river: the home of port, and more and more of dry, dark reds from Touriga Nacional and other local grapes.',
   4, 3, 4, 'Port with blue cheese or chocolate; the dry reds with grilled meat.',
   'Port: Ruby is young and fruity, Tawny is aged and nutty, Vintage comes from one exceptional year.',
   'published'),
  ('wr_0009', 'Mosel', '{Moselle,"Mosel-Saar-Ruwer"}', 'DE', 49.9, 6.95, 60,
   'Slate slopes so steep they are worked by hand, and Riesling that is light, fragrant and high in acidity, from bone-dry to sweet.',
   null, null, null, 'Asian dishes, pork, fish, spicy food.',
   'Trocken means dry. Kabinett, Spätlese and Auslese rise in ripeness, and often in sweetness.',
   'published'),
  ('wr_0010', 'Piedmont', '{Piemonte}', 'IT', 44.65, 8.0, 70,
   'Foothills of the Alps where Nebbiolo makes Barolo and Barbaresco: pale, but with firm tannins and scents of rose and tar.',
   3, 5, 5, 'Truffles, risotto, braised beef, aged cheese.',
   'Barolo and Barbaresco are the great names; Langhe Nebbiolo is the younger, friendlier version.',
   'published'),
  ('wr_0011', 'Tuscany', '{Toscana}', 'IT', 43.45, 11.25, 90,
   'Sangiovese country: Chianti and Brunello di Montalcino, with bright cherry fruit and fresh acidity.',
   3, 4, 4, 'Pasta with tomato, grilled steak, pecorino.',
   'Chianti Classico comes from the historic heart; Riserva is aged longer. "Super Tuscans" are blends outside the rules, often with Cabernet.',
   'published');

-- ------------------------------------------------------------
-- Grapes
-- ------------------------------------------------------------
insert into public.grapes
  (grape_code, name, aliases, colour, summary, tastes, aged_note,
   body, acidity, tannin, publication_status)
values
  ('gr_0001', 'Pinot Noir', '{Spätburgunder,"Pinot Nero"}', 'red',
   'Thin-skinned and fussy, at its best where it''s cool. Pale in the glass, but it carries a lot of scent.',
   '{"Red cherry",Raspberry,Strawberry}', 'mushroom, forest floor', 2, 4, 2, 'published'),
  ('gr_0002', 'Chardonnay', '{}', 'white',
   'The chameleon: lean and steely in a cool climate, round and buttery when ripened in the sun and aged in oak.',
   '{Lemon,"Green apple","Butter, with oak",Hazelnut}', null, 3, 3, null, 'published'),
  ('gr_0003', 'Cabernet Sauvignon', '{}', 'red',
   'Small, thick-skinned berries that give dark colour, firm tannins and a long life.',
   '{Blackcurrant,Cedar,Graphite}', 'tobacco, leather', 4, 3, 5, 'published'),
  ('gr_0004', 'Merlot', '{}', 'red',
   'Softer than Cabernet, with plush fruit; the backbone of Bordeaux''s right bank.',
   '{Plum,"Black cherry",Chocolate}', null, 4, 3, 3, 'published'),
  ('gr_0005', 'Syrah', '{Shiraz}', 'red',
   'Dark and spicy: black pepper in the cool northern Rhône, riper and jammier as Shiraz in warm places.',
   '{Blackberry,"Black pepper",Olive}', null, 4, 3, 4, 'published'),
  ('gr_0006', 'Grenache', '{Garnacha}', 'red',
   'Loves heat; gives ripe, warm reds with soft tannins, usually in a blend.',
   '{Strawberry,Raspberry,"Dried herbs"}', null, 4, 2, 2, 'published'),
  ('gr_0007', 'Tempranillo', '{"Tinto Fino","Tinta del País","Tinta Roriz"}', 'red',
   'Spain''s great red grape: medium-bodied, and it takes well to oak.',
   '{Cherry,"Dried fig",Leather,"Vanilla, with oak"}', null, 3, 3, 3, 'published'),
  ('gr_0008', 'Riesling', '{}', 'white',
   'Aromatic and high in acidity, at home on steep, cool slopes; from bone-dry to lusciously sweet.',
   '{Lime,"Green apple",Peach}', 'petrol, honey', 2, 5, null, 'published'),
  ('gr_0009', 'Nebbiolo', '{}', 'red',
   'Pale and perfumed, but with high acidity and strong tannins; it needs time.',
   '{Rose,Tar,"Red cherry"}', null, 3, 5, 5, 'published'),
  ('gr_0010', 'Sangiovese', '{}', 'red',
   'Italy''s most planted red: bright, savoury and fresh, made for food.',
   '{"Sour cherry","Tomato leaf","Dried herbs"}', null, 3, 4, 4, 'published'),
  ('gr_0011', 'Sauvignon Blanc', '{}', 'white',
   'Crisp and green, with high acidity: flinty in the Loire, tropical in New Zealand.',
   '{Gooseberry,Grapefruit,"Cut grass"}', null, 2, 5, null, 'published'),
  ('gr_0012', 'Chenin Blanc', '{}', 'white',
   'Versatile: dry, off-dry, sweet or sparkling, always with fresh acidity.',
   '{Quince,Apple,Honey}', null, 3, 5, null, 'published'),
  ('gr_0013', 'Cabernet Franc', '{}', 'red',
   'Lighter than Cabernet Sauvignon, fragrant, sometimes a little leafy.',
   '{Raspberry,"Bell pepper",Violet}', null, 3, 4, 3, 'published'),
  ('gr_0014', 'Gamay', '{}', 'red',
   'Light, juicy and low in tannin: the grape of Beaujolais.',
   '{"Red cherry",Raspberry,Violet}', null, 2, 4, 1, 'published'),
  ('gr_0015', 'Touriga Nacional', '{}', 'red',
   'Portugal''s leading grape: dark, floral and structured, the heart of port and of dry Douro reds.',
   '{Blackberry,Violet,Bergamot}', null, 4, 3, 4, 'published'),
  ('gr_0016', 'Meunier', '{"Pinot Meunier"}', 'red',
   'A cousin of Pinot Noir grown mostly in Champagne, where it adds fruit and roundness.',
   '{"Red apple","Red berries"}', null, 2, 4, 1, 'published'),
  ('gr_0017', 'Mourvèdre', '{Monastrell,Mataro}', 'red',
   'Dark and meaty, it needs heat; it gives structure to southern Rhône blends.',
   '{Blackberry,Game,"Black pepper"}', null, 4, 3, 4, 'published');

-- "Like this? Try ..."
update public.grapes g set similar_grape_id = s.id, similar_note = v.note
from (values
  ('gr_0001', 'gr_0014', 'just as light, a little juicier'),
  ('gr_0003', 'gr_0004', 'softer and rounder'),
  ('gr_0007', 'gr_0010', 'similar cherry fruit, brighter'),
  ('gr_0009', 'gr_0001', 'also pale and perfumed, much softer'),
  ('gr_0002', 'gr_0012', 'just as versatile, fresher'),
  ('gr_0011', 'gr_0008', 'even more aromatic')
) as v(code, sim, note)
join public.grapes s on s.grape_code = v.sim
where g.grape_code = v.code;

-- ------------------------------------------------------------
-- Which grapes each region is known for
-- ------------------------------------------------------------
insert into public.wine_region_grapes (region_id, grape_id, local_note, display_order)
select r.id, g.id, v.note, v.ord
from (values
  ('wr_0001', 'gr_0001', 'earthy, elegant', 1),
  ('wr_0001', 'gr_0002', 'from steely Chablis to rich Meursault', 2),
  ('wr_0002', 'gr_0003', 'leads on the left bank: firm, cedar', 1),
  ('wr_0002', 'gr_0004', 'leads on the right bank: round, plummy', 2),
  ('wr_0002', 'gr_0013', 'in the blend, adds lift', 3),
  ('wr_0003', 'gr_0002', 'finesse and citrus', 1),
  ('wr_0003', 'gr_0001', 'body and red fruit', 2),
  ('wr_0003', 'gr_0016', 'fruit and roundness', 3),
  ('wr_0004', 'gr_0005', 'the north: peppery and dark', 1),
  ('wr_0004', 'gr_0006', 'the south: warm and generous', 2),
  ('wr_0004', 'gr_0017', 'the south: structure', 3),
  ('wr_0005', 'gr_0011', 'Sancerre: flinty, crisp', 1),
  ('wr_0005', 'gr_0012', 'Vouvray: dry to sweet', 2),
  ('wr_0005', 'gr_0013', 'Chinon: a light, fragrant red', 3),
  ('wr_0006', 'gr_0007', 'cherry, and vanilla from oak', 1),
  ('wr_0006', 'gr_0006', 'warmth in the blend', 2),
  ('wr_0007', 'gr_0007', 'as Tinto Fino: fuller, darker', 1),
  ('wr_0008', 'gr_0015', 'port and dark dry reds', 1),
  ('wr_0008', 'gr_0007', 'as Tinta Roriz', 2),
  ('wr_0009', 'gr_0008', 'light, fragrant, dry to sweet', 1),
  ('wr_0010', 'gr_0009', 'Barolo and Barbaresco', 1),
  ('wr_0011', 'gr_0010', 'Chianti and Brunello', 1),
  ('wr_0011', 'gr_0003', 'in the Super Tuscans', 2)
) as v(region, grape, note, ord)
join public.wine_regions r on r.region_code = v.region
join public.grapes g on g.grape_code = v.grape;

-- ------------------------------------------------------------
-- Names on a wine list
-- ------------------------------------------------------------
insert into public.wine_appellations
  (appellation_code, name, aliases, region_id, colour, note, display_order,
   publication_status)
select v.code, v.name, v.aliases::text[], r.id, v.colour, v.note, v.ord, 'published'
from (values
  ('wa_0001', 'Chablis', '{}', 'wr_0001', 'white', 'crisp, mineral', 1),
  ('wa_0002', 'Meursault', '{}', 'wr_0001', 'white', 'rich, nutty', 2),
  ('wa_0003', 'Puligny-Montrachet', '{"Puligny Montrachet"}', 'wr_0001', 'white', 'elegant, precise', 3),
  ('wa_0004', 'Mâcon-Villages', '{"Macon-Villages","Mâcon"}', 'wr_0001', 'white', 'fresh, fruity, good value', 4),
  ('wa_0005', 'Volnay', '{}', 'wr_0001', 'red', 'delicate, perfumed', 5),
  ('wa_0006', 'Pommard', '{}', 'wr_0001', 'red', 'sturdier, more tannin', 6),
  ('wa_0007', 'Gevrey-Chambertin', '{"Gevrey Chambertin"}', 'wr_0001', 'red', 'firmer, darker', 7),
  ('wa_0008', 'Nuits-Saint-Georges', '{"Nuits-St-Georges"}', 'wr_0001', 'red', 'earthy, firm', 8),
  ('wa_0009', 'Médoc', '{Medoc,"Haut-Médoc"}', 'wr_0002', 'red', 'left bank, Cabernet: firm', 1),
  ('wa_0010', 'Pauillac', '{}', 'wr_0002', 'red', 'left bank: powerful, cedar', 2),
  ('wa_0011', 'Margaux', '{}', 'wr_0002', 'red', 'left bank: perfumed, elegant', 3),
  ('wa_0012', 'Saint-Émilion', '{"Saint-Emilion","St-Émilion","St-Emilion"}', 'wr_0002', 'red', 'right bank, Merlot: round', 4),
  ('wa_0013', 'Pomerol', '{}', 'wr_0002', 'red', 'right bank: plush, velvety', 5),
  ('wa_0014', 'Pessac-Léognan', '{"Pessac-Leognan",Graves}', 'wr_0002', 'mixed', 'red and white, smoky', 6),
  ('wa_0015', 'Sauternes', '{}', 'wr_0002', 'white', 'sweet, honeyed', 7),
  ('wa_0016', 'Châteauneuf-du-Pape', '{"Chateauneuf-du-Pape"}', 'wr_0004', 'red', 'rich, spicy Grenache blend', 1),
  ('wa_0017', 'Côte-Rôtie', '{"Cote-Rotie"}', 'wr_0004', 'red', 'Syrah: perfumed, peppery', 2),
  ('wa_0018', 'Hermitage', '{}', 'wr_0004', 'red', 'Syrah: powerful, long-lived', 3),
  ('wa_0019', 'Crozes-Hermitage', '{}', 'wr_0004', 'red', 'Syrah: lighter, good value', 4),
  ('wa_0020', 'Gigondas', '{}', 'wr_0004', 'red', 'robust, spicy', 5),
  ('wa_0021', 'Sancerre', '{}', 'wr_0005', 'white', 'Sauvignon Blanc: crisp, flinty', 1),
  ('wa_0022', 'Pouilly-Fumé', '{"Pouilly-Fume"}', 'wr_0005', 'white', 'Sauvignon Blanc: smoky, mineral', 2),
  ('wa_0023', 'Vouvray', '{}', 'wr_0005', 'white', 'Chenin Blanc: dry to sweet', 3),
  ('wa_0024', 'Chinon', '{}', 'wr_0005', 'red', 'Cabernet Franc: light, fragrant', 4),
  ('wa_0025', 'Muscadet', '{}', 'wr_0005', 'white', 'light, salty, made for oysters', 5),
  ('wa_0026', 'Port', '{Porto}', 'wr_0008', 'red', 'fortified and sweet', 1),
  ('wa_0027', 'Barolo', '{}', 'wr_0010', 'red', 'Nebbiolo: powerful, firm tannins', 1),
  ('wa_0028', 'Barbaresco', '{}', 'wr_0010', 'red', 'Nebbiolo: a little softer', 2),
  ('wa_0029', 'Barbera d''Alba', '{"Barbera d''Asti"}', 'wr_0010', 'red', 'juicy, fresh, low tannin', 3),
  ('wa_0030', 'Moscato d''Asti', '{}', 'wr_0010', 'sparkling', 'lightly sparkling, sweet, low alcohol', 4),
  ('wa_0031', 'Chianti Classico', '{Chianti}', 'wr_0011', 'red', 'Sangiovese: cherry, savoury', 1),
  ('wa_0032', 'Brunello di Montalcino', '{Brunello}', 'wr_0011', 'red', 'Sangiovese: fuller, long-aged', 2),
  ('wa_0033', 'Bolgheri', '{}', 'wr_0011', 'red', 'Bordeaux-style blends near the coast', 3)
) as v(code, name, aliases, region, colour, note, ord)
join public.wine_regions r on r.region_code = v.region;

commit;
