-- Wine regions of Morocco and Ethiopia. Written 2026-11-20 (product owner:
-- "I want to add the wine regions of Morocco and Ethiopia. From Ethiopia
-- there is only 1 wine maker, I believe it's around 1h drive from Addis
-- Abbeba").
--
-- Research with every source and judgement call:
-- africa_research/REPORT.md and the per-region notes there.
--
-- Points only, no outlines:
-- - Morocco's 14 AOGs (arrêté 869-75, 1977) are described by rivers,
--   roads and 1977 place names; its AOCs by parts of communes on
--   unpublished cadastral plans. No official commune boundaries are open
--   (HCP via HDX stops at provinces) and GADM's communes failed a position
--   check (3-5 km off their towns). Four appellations are shown, each at a
--   GeoNames point the official text places inside it.
-- - Ethiopia has no wine appellation. There are two grape-wine producers:
--   Castel's vineyard near Ziway (about 160 km, ~2.5 h by road from Addis)
--   and Awash Wine, which makes its wine in Addis from its Merti farm in
--   Arsi (115-180 km away, sources disagree). One point, at Ziway; Awash's
--   farm is held back (grapes, altitude and distance unsourced).
--
-- Every claim below rests on two independent sources, or one official
-- text for legal facts; what didn't is left out (no pairings; red scales
-- only where sourced). Run after 20261101600000_add_et_country.sql.

begin;

insert into public.wine_regions
  (region_code, name, aliases, country_code, latitude, longitude, radius_km,
   summary, red_body, red_acidity, red_tannin, pairing, label_note,
   source_url, publication_status)
values
  ('wr_0032', 'Guerrouane', '{"Guerrouane AOG"}', 'MA', 33.731, -5.579, 15,
   'On the Meknès plateau, at about 600 to 700 metres below the Middle Atlas, where altitude tempers a hot, dry climate. Reds and rosés, and Morocco''s pale vin gris.',
   null, null, null, null,
   'On the label: Guerrouane, with ''appellation d''origine garantie'' directly beneath it.',
   'https://www.onssa.gov.ma/wp-content/uploads/Reglementation/R%C3%A9glementation%20Sectorielle/Produits%20Alimentaires/Boissons%20Alcoolis%C3%A9es/Vins/ARR.869-75.FR.pdf',
   'published'),
  ('wr_0033', 'Beni M''Tir', '{"Beni M''tir","Béni M''Tir","Beni Mtir"}', 'MA', 33.903, -5.378, 15,
   'East of Guerrouane on the same Meknès plateau, at about 600 to 700 metres below the Middle Atlas. Morocco''s first AOC, Les Coteaux de l''Atlas, lies within it.',
   null, null, null, null,
   'On the label: Beni M''Tir, with ''appellation d''origine garantie'' directly beneath it.',
   'https://www.onssa.gov.ma/wp-content/uploads/Reglementation/R%C3%A9glementation%20Sectorielle/Produits%20Alimentaires/Boissons%20Alcoolis%C3%A9es/Vins/ARR.869-75.FR.pdf',
   'published'),
  ('wr_0034', 'Les Coteaux de l''Atlas', '{"Coteaux de l''Atlas"}', 'MA', 33.838, -5.445, 5,
   'Morocco''s first AOC (1998), on parts of three communes south of Meknès. Its reds rest on Cabernet Sauvignon, Merlot, Syrah and Tempranillo; its whites on Chardonnay and Sauvignon Blanc.',
   null, null, null, null,
   'On the label with ''appellation d''origine contrôlée''. ''1er cru'' only for a terroir classified by Morocco''s national commission.',
   'https://www.onssa.gov.ma/wp-content/uploads/Reglementation/R%C3%A9glementation%20Sectorielle/Produits%20Alimentaires/Boissons%20Alcoolis%C3%A9es/Vins/ARR.1957-98.FR.pdf',
   'published'),
  ('wr_0035', 'Zenata', '{"Zenata AOG"}', 'MA', 33.616, -7.122, 15,
   'Between Casablanca and Rabat, around Benslimane. Syrah leads here, in full-bodied reds.',
   4, null, null, null,
   'On the label: Zenata, with ''appellation d''origine garantie'' directly beneath it.',
   'https://www.onssa.gov.ma/wp-content/uploads/Reglementation/R%C3%A9glementation%20Sectorielle/Produits%20Alimentaires/Boissons%20Alcoolis%C3%A9es/Vins/ARR.869-75.FR.pdf',
   'published'),
  ('wr_0036', 'Rift Valley (Ziway)', '{Ziway,Batu,Ethiopia}', 'ET', 7.933, 38.717, 5,
   'Ethiopia has no official wine region. Its main vineyard lies near Ziway in the Central Rift Valley, about 160 km south of Addis Ababa, at around 1,600 metres. Mostly Syrah, with Cabernet Sauvignon, Merlot and Chardonnay.',
   null, null, null, null, null,
   'https://ethiopianembassy.be/?p=6802',
   'published');

insert into public.wine_region_grapes (region_id, grape_id, local_note, display_order)
select r.id, g.id, v.note, v.ord
from (values
  ('wr_0034', 'gr_0003', null, 1), ('wr_0034', 'gr_0004', null, 2),
  ('wr_0034', 'gr_0005', null, 3), ('wr_0034', 'gr_0007', null, 4),
  ('wr_0034', 'gr_0002', null, 5), ('wr_0034', 'gr_0011', null, 6),
  ('wr_0035', 'gr_0005', 'full-bodied', 1),
  ('wr_0036', 'gr_0005', null, 1), ('wr_0036', 'gr_0003', null, 2),
  ('wr_0036', 'gr_0004', null, 3), ('wr_0036', 'gr_0002', null, 4)
) as v(region, grape, note, ord)
join public.wine_regions r on r.region_code = v.region
join public.grapes g on g.grape_code = v.grape;

commit;
