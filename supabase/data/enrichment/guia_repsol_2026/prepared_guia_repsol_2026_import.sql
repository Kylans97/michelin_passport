-- APPLIED to production 2026-11-16 with the product owner's approval.
--
-- Guía Repsol 2026 (Spain), 2 and 3 Soles, written 2026-11-16 (branch
-- claude/guide-inventory), into the shared guide tables
-- (20261101410000_add_shared_guide_tables.sql, applied 2026-11-16):
--   * 1 guides row: guia_repsol (measure tier, 1-3 Soles);
--   * 159 guide_awards rows: 46 with 3 Soles (all 46 on the list), 113 with 2
--     Soles, each a restaurant already in the catalogue;
--   * the same 159 matches in guide_venue_links, keyed on Repsol's own
--     numeric ficha id, with their evidence;
--   * 1 guide_coverage row (partial: 1 Sol not yet loaded).
--
-- Source: the official 2026 Soles list, guiarepsol.com/es/comer/soles-repsol/
-- ediciones-de-soles/2026/ (46 / 173 / 589 Soles, gala 2026-02-16), and each
-- restaurant's own Repsol ficha (address, coordinates, phone, website).
-- Matched on restaurant_code + country, never name. Per-entry basis:
-- repsol_2026_matches.csv. See GUIA_REPSOL_2026_REPORT.md.
--
--   supabase db query --linked --file prepared_guia_repsol_2026_import.sql
-- One transaction; every check raises, which rolls the whole file back.

begin;

do $$ begin
  if to_regclass('public.guide_awards') is null then
    raise exception 'shared guide tables (20261101410000) are not applied';
  end if;
  if exists (select 1 from public.guides where guide_code = 'guia_repsol') then
    raise exception 'guia_repsol already present -- this file has run before';
  end if;
end $$;

insert into public.guides (guide_code, name, publisher, venue_kind, measure, tier_max, tier_labels, homepage_url, terms_url) values
  ('guia_repsol', 'Guía Repsol', 'Repsol S.A.', 'restaurant', 'tier', 3,
   '{"1": "1 Sol", "2": "2 Soles", "3": "3 Soles"}'::jsonb,
   'https://www.guiarepsol.com/es/comer/soles-repsol/ediciones-de-soles/2026/',
   'https://www.guiarepsol.com/es/condiciones-de-servicio/');

create temp table repsol_stage (
  tier smallint, restaurant_code text, profile_url text, external_id text, evidence text
) on commit drop;

insert into repsol_stage values
    (3, 'rest_0336', 'https://www.guiarepsol.com/es/fichas/restaurante/aponiente-8659/', '8659', 'guiarepsol.com ficha: location 0 m, phone, website agree with the catalogue row'),
    (3, 'rest_1617', 'https://www.guiarepsol.com/es/fichas/restaurante/baga-186655/', '186655', 'guiarepsol.com ficha: location 7 m, phone, website agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back.'),
    (3, 'rest_0332', 'https://www.guiarepsol.com/es/fichas/restaurante/noor-10885/', '10885', 'guiarepsol.com ficha: location 0 m, phone, website agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back.'),
    (3, 'rest_0342', 'https://www.guiarepsol.com/es/fichas/restaurante/el-rincon-de-juan-carlos-9240/', '9240', 'guiarepsol.com ficha: location 0 m, phone agree with the catalogue row'),
    (3, 'rest_0340', 'https://www.guiarepsol.com/es/fichas/restaurante/cenador-de-amos-8663/', '8663', 'guiarepsol.com ficha: location 0 m, phone, website agree with the catalogue row'),
    (3, 'rest_0372', 'https://www.guiarepsol.com/es/fichas/restaurante/ivan-cerdeno-cigarral-del-angel-9157/', '9157', 'guiarepsol.com ficha: location 0 m, phone agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back. Name differs: Repsol "Iván Cerdeño - Cigarral del Ángel", catalogue "Iván Cerdeño".'),
    (3, 'rest_0343', 'https://www.guiarepsol.com/es/fichas/restaurante/maralba-8593/', '8593', 'guiarepsol.com ficha: location 0 m, phone, website agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back.'),
    (3, 'rest_0002', 'https://www.guiarepsol.com/es/fichas/restaurante/abac-8564/', '8564', 'guiarepsol.com ficha: location 24 m, phone, website agree with the catalogue row'),
    (3, 'rest_1595', 'https://www.guiarepsol.com/es/fichas/restaurante/alkimia-9027/', '9027', 'guiarepsol.com ficha: location 33 m, phone, website agree with the catalogue row'),
    (3, 'rest_1632', 'https://www.guiarepsol.com/es/fichas/restaurante/can-jubany-9144/', '9144', 'guiarepsol.com ficha: location 18 m, phone, website agree with the catalogue row'),
    (3, 'rest_0330', 'https://www.guiarepsol.com/es/fichas/restaurante/cocina-hermanos-torres-138012/', '138012', 'guiarepsol.com ficha: location 0 m, phone, website agree with the catalogue row'),
    (3, 'rest_0331', 'https://www.guiarepsol.com/es/fichas/restaurante/disfrutar-9152/', '9152', 'guiarepsol.com ficha: location 0 m, phone, website agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back.'),
    (3, 'rest_0337', 'https://www.guiarepsol.com/es/fichas/restaurante/el-celler-de-can-roca-11921/', '11921', 'guiarepsol.com ficha: location 0 m, phone, website agree with the catalogue row'),
    (3, 'rest_0058', 'https://www.guiarepsol.com/es/fichas/restaurante/lasarte-8615/', '8615', 'guiarepsol.com ficha: location 79 m, phone, website agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back.'),
    (3, 'rest_0368', 'https://www.guiarepsol.com/es/fichas/restaurante/les-cols-10358/', '10358', 'guiarepsol.com ficha: location 0 m, phone, website agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back.'),
    (3, 'rest_0360', 'https://www.guiarepsol.com/es/fichas/restaurante/miramar-10303/', '10303', 'guiarepsol.com ficha: location 0 m, phone, website agree with the catalogue row'),
    (3, 'rest_0361', 'https://www.guiarepsol.com/es/fichas/restaurante/coque-39681/', '39681', 'guiarepsol.com ficha: location 0 m, phone, website agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back.'),
    (3, 'rest_1654', 'https://www.guiarepsol.com/es/fichas/restaurante/corral-de-la-moreria-gastronomico-9133/', '9133', 'guiarepsol.com ficha: location 23 m, phone agree with the catalogue row'),
    (3, 'rest_0044', 'https://www.guiarepsol.com/es/fichas/restaurante/diverxo-9902/', '9902', 'guiarepsol.com ficha: location 56 m, phone, website agree with the catalogue row'),
    (3, 'rest_0362', 'https://www.guiarepsol.com/es/fichas/restaurante/dstage-9154/', '9154', 'guiarepsol.com ficha: location 0 m, phone, website agree with the catalogue row'),
    (3, 'rest_0363', 'https://www.guiarepsol.com/es/fichas/restaurante/paco-roncero-9701/', '9701', 'guiarepsol.com ficha: location 0 m, phone, website agree with the catalogue row'),
    (3, 'rest_0364', 'https://www.guiarepsol.com/es/fichas/restaurante/ramon-freixa-atelier-334971/', '334971', 'guiarepsol.com ficha: location 0 m, phone, website agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back.'),
    (3, 'rest_0376', 'https://www.guiarepsol.com/es/fichas/restaurante/bonamb-9044/', '9044', 'guiarepsol.com ficha: location 0 m, phone, website agree with the catalogue row'),
    (3, 'rest_0351', 'https://www.guiarepsol.com/es/fichas/restaurante/lescaleta-9198/', '9198', 'guiarepsol.com ficha: location 0 m, phone, website agree with the catalogue row'),
    (3, 'rest_1720', 'https://www.guiarepsol.com/es/fichas/restaurante/la-finca-10592/', '10592', 'guiarepsol.com ficha: location 32 m, phone, website agree with the catalogue row'),
    (3, 'rest_1727', 'https://www.guiarepsol.com/es/fichas/restaurante/la-salita-9010/', '9010', 'guiarepsol.com ficha: location 23 m, phone, website agree with the catalogue row'),
    (3, 'rest_0333', 'https://www.guiarepsol.com/es/fichas/restaurante/quique-dacosta-10591/', '10591', 'guiarepsol.com ficha: location 0 m, phone, website agree with the catalogue row'),
    (3, 'rest_0375', 'https://www.guiarepsol.com/es/fichas/restaurante/ricard-camarena-10444/', '10444', 'guiarepsol.com ficha: location 0 m, phone, website agree with the catalogue row'),
    (3, 'rest_0334', 'https://www.guiarepsol.com/es/fichas/restaurante/akelarre-10419/', '10419', 'guiarepsol.com ficha: location 0 m, phone, website agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back. Name differs: Repsol "Akelarre", catalogue "Akelaŕe".'),
    (3, 'rest_0335', 'https://www.guiarepsol.com/es/fichas/restaurante/arzak-10908/', '10908', 'guiarepsol.com ficha: location 0 m, phone, website agree with the catalogue row'),
    (3, 'rest_0338', 'https://www.guiarepsol.com/es/fichas/restaurante/azurmendi-11767/', '11767', 'guiarepsol.com ficha: location 0 m, phone agree with the catalogue row'),
    (3, 'rest_0312', 'https://www.guiarepsol.com/es/fichas/restaurante/elkano-11804/', '11804', 'guiarepsol.com ficha: location 0 m, phone, website agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back.'),
    (3, 'rest_0296', 'https://www.guiarepsol.com/es/fichas/restaurante/etxebarri-8642/', '8642', 'guiarepsol.com ficha: location 0 m, phone, website agree with the catalogue row. Name differs: Repsol "Etxebarri", catalogue "Asador Etxebarri".'),
    (3, 'rest_0339', 'https://www.guiarepsol.com/es/fichas/restaurante/martin-berasategui-9735/', '9735', 'guiarepsol.com ficha: location 0 m, phone, website agree with the catalogue row'),
    (3, 'rest_0356', 'https://www.guiarepsol.com/es/fichas/restaurante/mugaritz-8995/', '8995', 'guiarepsol.com ficha: location 0 m, phone, website agree with the catalogue row'),
    (3, 'rest_1757', 'https://www.guiarepsol.com/es/fichas/restaurante/nerua-guggenheim-bilbao-10626/', '10626', 'guiarepsol.com ficha: location 19 m, phone, website agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back.'),
    (3, 'rest_0350', 'https://www.guiarepsol.com/es/fichas/restaurante/atrio-8946/', '8946', 'guiarepsol.com ficha: location 0 m, phone, website agree with the catalogue row'),
    (3, 'rest_1609', 'https://www.guiarepsol.com/es/fichas/restaurante/a-tafona-8637/', '8637', 'guiarepsol.com ficha: location 8 m, phone, website agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back.'),
    (3, 'rest_1802', 'https://www.guiarepsol.com/es/fichas/restaurante/casa-solla-11299/', '11299', 'guiarepsol.com ficha: location 34 m, phone, website agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back. Name differs: Repsol "Casa Solla", catalogue "Solla".'),
    (3, 'rest_0367', 'https://www.guiarepsol.com/es/fichas/restaurante/culler-de-pau-8896/', '8896', 'guiarepsol.com ficha: location 0 m, phone, website agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back.'),
    (3, 'rest_1738', 'https://www.guiarepsol.com/es/fichas/restaurante/maca-de-castro-13606/', '13606', 'guiarepsol.com ficha: location 27 m, phone, website agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back.'),
    (3, 'rest_0349', 'https://www.guiarepsol.com/es/fichas/restaurante/voro-321798/', '321798', 'guiarepsol.com ficha: location 0 m, phone, website agree with the catalogue row'),
    (3, 'rest_0357', 'https://www.guiarepsol.com/es/fichas/restaurante/el-portal-de-echaurren-11786/', '11786', 'guiarepsol.com ficha: location 1 m, phone, website agree with the catalogue row'),
    (3, 'rest_1635', 'https://www.guiarepsol.com/es/fichas/restaurante/casa-gerardo-10631/', '10631', 'guiarepsol.com ficha: phone, website agree with the catalogue row'),
    (3, 'rest_0341', 'https://www.guiarepsol.com/es/fichas/restaurante/casa-marcial-8632/', '8632', 'guiarepsol.com ficha: location 0 m, phone, website agree with the catalogue row'),
    (3, 'rest_0355', 'https://www.guiarepsol.com/es/fichas/restaurante/cabana-buenavista-11560/', '11560', 'guiarepsol.com ficha: location 0 m, phone agree with the catalogue row'),
    (2, 'rest_1589', 'https://www.guiarepsol.com/es/fichas/restaurante/abantal-9122/', '9122', 'guiarepsol.com ficha: location 2 m, phone, website agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back.'),
    (2, 'rest_1594', 'https://www.guiarepsol.com/es/fichas/restaurante/alevante-11746/', '11746', 'guiarepsol.com ficha: location 53 m, phone, website agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back. Name differs: Repsol "Alevante", catalogue "Alevante by Ángel León".'),
    (2, 'rest_0370', 'https://www.guiarepsol.com/es/fichas/restaurante/bardal-12981/', '12981', 'guiarepsol.com ficha: location 0 m, phone, website agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back.'),
    (2, 'rest_1647', 'https://www.guiarepsol.com/es/fichas/restaurante/choco-10879/', '10879', 'guiarepsol.com ficha: location 10 m, phone, website agree with the catalogue row'),
    (2, 'rest_1705', 'https://www.guiarepsol.com/es/fichas/restaurante/jose-carlos-garcia-12510/', '12510', 'guiarepsol.com ficha: location 11 m, phone, website agree with the catalogue row'),
    (2, 'rest_1708', 'https://www.guiarepsol.com/es/fichas/restaurante/kaleja-321913/', '321913', 'guiarepsol.com ficha: location 7 m, phone, website agree with the catalogue row'),
    (2, 'rest_1718', 'https://www.guiarepsol.com/es/fichas/restaurante/la-costa-11658/', '11658', 'guiarepsol.com ficha: location 3 m, phone, website agree with the catalogue row'),
    (2, 'rest_0359', 'https://www.guiarepsol.com/es/fichas/restaurante/lu-cocina-y-alma-114472/', '114472', 'guiarepsol.com ficha: location 0 m, phone, website agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back.'),
    (2, 'rest_1743', 'https://www.guiarepsol.com/es/fichas/restaurante/mantua-118759/', '118759', 'guiarepsol.com ficha: location 9 m, phone, website agree with the catalogue row'),
    (2, 'rest_1749', 'https://www.guiarepsol.com/es/fichas/restaurante/meson-sabor-andaluz-327319/', '327319', 'guiarepsol.com ficha: location 17 m, phone, website agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back.'),
    (2, 'rest_1803', 'https://www.guiarepsol.com/es/fichas/restaurante/sollo-9822/', '9822', 'guiarepsol.com ficha: location 120 m, phone, website agree with the catalogue row'),
    (2, 'rest_1816', 'https://www.guiarepsol.com/es/fichas/restaurante/vandelvira-331545/', '331545', 'guiarepsol.com ficha: location 43 m, phone, website agree with the catalogue row'),
    (2, 'rest_1627', 'https://www.guiarepsol.com/es/fichas/restaurante/callizo-8528/', '8528', 'guiarepsol.com ficha: location 9 m, phone, website agree with the catalogue row'),
    (2, 'rest_1714', 'https://www.guiarepsol.com/es/fichas/restaurante/la-aquarela-27059/', '27059', 'guiarepsol.com ficha: location 69 m, phone, website agree with the catalogue row'),
    (2, 'rest_0358', 'https://www.guiarepsol.com/es/fichas/restaurante/mb-14243/', '14243', 'guiarepsol.com ficha: location 0 m, phone agree with the catalogue row'),
    (2, 'rest_1760', 'https://www.guiarepsol.com/es/fichas/restaurante/nub-130167/', '130167', 'guiarepsol.com ficha: website agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back.'),
    (2, 'rest_1797', 'https://www.guiarepsol.com/es/fichas/restaurante/san-ho-331520/', '331520', 'guiarepsol.com ficha: location 37 m, phone agree with the catalogue row'),
    (2, 'rest_1641', 'https://www.guiarepsol.com/es/fichas/restaurante/casona-del-judio-10899/', '10899', 'guiarepsol.com ficha: location 7 m, phone, website agree with the catalogue row'),
    (2, 'rest_1715', 'https://www.guiarepsol.com/es/fichas/restaurante/la-bicicleta-137114/', '137114', 'guiarepsol.com ficha: location 9 m, phone, website agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back.'),
    (2, 'rest_1801', 'https://www.guiarepsol.com/es/fichas/restaurante/solana-10298/', '10298', 'guiarepsol.com ficha: location 16 m, phone agree with the catalogue row'),
    (2, 'rest_1640', 'https://www.guiarepsol.com/es/fichas/restaurante/casas-colgadas-331682/', '331682', 'guiarepsol.com ficha: location 20 m, phone, website agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back. Name differs: Repsol "Casas Colgadas", catalogue "Casas Colgadas Restaurante".'),
    (2, 'rest_1663', 'https://www.guiarepsol.com/es/fichas/restaurante/el-bohio-8710/', '8710', 'guiarepsol.com ficha: location 7 m, phone, website agree with the catalogue row'),
    (2, 'rest_1665', 'https://www.guiarepsol.com/es/fichas/restaurante/el-doncel-9287/', '9287', 'guiarepsol.com ficha: location 5 m, phone, website agree with the catalogue row'),
    (2, 'rest_1762', 'https://www.guiarepsol.com/es/fichas/restaurante/oba-331578/', '331578', 'guiarepsol.com ficha: location 3 m, website agree with the catalogue row'),
    (2, 'rest_0377', 'https://www.guiarepsol.com/es/fichas/restaurante/ambivium-321780/', '321780', 'guiarepsol.com ficha: location 0 m, phone, website agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back.'),
    (2, 'rest_1650', 'https://www.guiarepsol.com/es/fichas/restaurante/cobo-evolucion-328695/', '328695', 'guiarepsol.com ficha: location 3 m, phone, website agree with the catalogue row'),
    (2, 'rest_1651', 'https://www.guiarepsol.com/es/fichas/restaurante/cocinandos-8708/', '8708', 'guiarepsol.com ficha: location 7 m, phone, website agree with the catalogue row'),
    (2, 'rest_1666', 'https://www.guiarepsol.com/es/fichas/restaurante/el-ermitano-10988/', '10988', 'guiarepsol.com ficha: website agree with the catalogue row'),
    (2, 'rest_1716', 'https://www.guiarepsol.com/es/fichas/restaurante/la-botica-de-matapozuelos-9649/', '9649', 'guiarepsol.com ficha: location 1 m, phone, website agree with the catalogue row'),
    (2, 'rest_1723', 'https://www.guiarepsol.com/es/fichas/restaurante/la-lobita-9673/', '9673', 'guiarepsol.com ficha: location 16 m, phone, website agree with the catalogue row'),
    (2, 'rest_1729', 'https://www.guiarepsol.com/es/fichas/restaurante/lera-9707/', '9707', 'guiarepsol.com ficha: location 43 m, phone, website agree with the catalogue row'),
    (2, 'rest_1770', 'https://www.guiarepsol.com/es/fichas/restaurante/pablo-9117/', '9117', 'guiarepsol.com ficha: location 14 m, phone agree with the catalogue row'),
    (2, 'rest_1786', 'https://www.guiarepsol.com/es/fichas/restaurante/refectorio-11313/', '11313', 'guiarepsol.com ficha: location 87 m, website agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back.'),
    (2, 'rest_1812', 'https://www.guiarepsol.com/es/fichas/restaurante/trigo-12643/', '12643', 'guiarepsol.com ficha: location 29 m, phone, website agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back.'),
    (2, 'rest_1809', 'https://www.guiarepsol.com/es/fichas/restaurante/victor-gutierrez-8850/', '8850', 'guiarepsol.com ficha: location 2 m, phone agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back. Name differs: Repsol "Víctor Gutiérrez", catalogue "Tayta by Víctor Gutiérrez".'),
    (2, 'rest_1602', 'https://www.guiarepsol.com/es/fichas/restaurante/angle-8565/', '8565', 'guiarepsol.com ficha: location 21 m, phone, website agree with the catalogue row'),
    (2, 'rest_0352', 'https://www.guiarepsol.com/es/fichas/restaurante/botic-9041/', '9041', 'guiarepsol.com ficha: location 0 m, phone, website agree with the catalogue row'),
    (2, 'rest_1625', 'https://www.guiarepsol.com/es/fichas/restaurante/caelis-8568/', '8568', 'guiarepsol.com ficha: location 14 m, phone, website agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back.'),
    (2, 'rest_1626', 'https://www.guiarepsol.com/es/fichas/restaurante/ca-lenric-13490/', '13490', 'guiarepsol.com ficha: location 19 m, phone, website agree with the catalogue row'),
    (2, 'rest_1642', 'https://www.guiarepsol.com/es/fichas/restaurante/castell-peralada-27087/', '27087', 'guiarepsol.com ficha: location 38 m, phone, website agree with the catalogue row. Name differs: Repsol "Castell Peralada", catalogue "Castell Perelada".'),
    (2, 'rest_0345', 'https://www.guiarepsol.com/es/fichas/restaurante/cinc-sentits-9118/', '9118', 'guiarepsol.com ficha: location 0 m, phone, website agree with the catalogue row'),
    (2, 'rest_1662', 'https://www.guiarepsol.com/es/fichas/restaurante/dos-palillos-8575/', '8575', 'guiarepsol.com ficha: location 18 m, phone, website agree with the catalogue row'),
    (2, 'rest_1670', 'https://www.guiarepsol.com/es/fichas/restaurante/els-casals-8689/', '8689', 'guiarepsol.com ficha: location 6 m, phone, website agree with the catalogue row'),
    (2, 'rest_1672', 'https://www.guiarepsol.com/es/fichas/restaurante/els-tinars-11376/', '11376', 'guiarepsol.com ficha: location 34 m, phone, website agree with the catalogue row'),
    (2, 'rest_1676', 'https://www.guiarepsol.com/es/fichas/restaurante/emporium-8675/', '8675', 'guiarepsol.com ficha: location 15 m, phone, website agree with the catalogue row'),
    (2, 'rest_0317', 'https://www.guiarepsol.com/es/fichas/restaurante/enigma-27009/', '27009', 'guiarepsol.com ficha: location 12 m, phone, website agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back.'),
    (2, 'rest_0346', 'https://www.guiarepsol.com/es/fichas/restaurante/enoteca-paco-perez-8579/', '8579', 'guiarepsol.com ficha: location 0 m, phone, website agree with the catalogue row'),
    (2, 'rest_1681', 'https://www.guiarepsol.com/es/fichas/restaurante/esperit-roca-333883/', '333883', 'guiarepsol.com ficha: phone, website agree with the catalogue row'),
    (2, 'rest_1697', 'https://www.guiarepsol.com/es/fichas/restaurante/hisop-8597/', '8597', 'guiarepsol.com ficha: location 6 m, phone, website agree with the catalogue row'),
    (2, 'rest_1713', 'https://www.guiarepsol.com/es/fichas/restaurante/koy-shunka-8612/', '8612', 'guiarepsol.com ficha: location 14 m, phone, website agree with the catalogue row'),
    (2, 'rest_1722', 'https://www.guiarepsol.com/es/fichas/restaurante/lalianca-dangles-9159/', '9159', 'guiarepsol.com ficha: location 14 m, phone, website agree with the catalogue row'),
    (2, 'rest_0348', 'https://www.guiarepsol.com/es/fichas/restaurante/la-boscana-37779/', '37779', 'guiarepsol.com ficha: location 0 m, phone, website agree with the catalogue row'),
    (2, 'rest_1731', 'https://www.guiarepsol.com/es/fichas/restaurante/les-moles-8487/', '8487', 'guiarepsol.com ficha: location 44 m, phone, website agree with the catalogue row'),
    (2, 'rest_1735', 'https://www.guiarepsol.com/es/fichas/restaurante/lluerna-9712/', '9712', 'guiarepsol.com ficha: location 9 m, phone, website agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back.'),
    (2, 'rest_1748', 'https://www.guiarepsol.com/es/fichas/restaurante/massana-10167/', '10167', 'guiarepsol.com ficha: location 11 m, phone, website agree with the catalogue row'),
    (2, 'rest_0067', 'https://www.guiarepsol.com/es/fichas/restaurante/moments-8619/', '8619', 'guiarepsol.com ficha: phone agree with the catalogue row'),
    (2, 'rest_1820', 'https://www.guiarepsol.com/es/fichas/restaurante/via-veneto-8654/', '8654', 'guiarepsol.com ficha: location 23 m, phone, website agree with the catalogue row'),
    (2, 'rest_1821', 'https://www.guiarepsol.com/es/fichas/restaurante/villa-retiro-8471/', '8471', 'guiarepsol.com ficha: location 29 m, phone, website agree with the catalogue row'),
    (2, 'rest_1643', 'https://www.guiarepsol.com/es/fichas/restaurante/cebo-11558/', '11558', 'guiarepsol.com ficha: location 20 m, website agree with the catalogue row'),
    (2, 'rest_1645', 'https://www.guiarepsol.com/es/fichas/restaurante/chiron-9099/', '9099', 'guiarepsol.com ficha: location 0 m, phone, website agree with the catalogue row'),
    (2, 'rest_0042', 'https://www.guiarepsol.com/es/fichas/restaurante/deessa-327357/', '327357', 'guiarepsol.com ficha: location 0 m, phone agree with the catalogue row'),
    (2, 'rest_1658', 'https://www.guiarepsol.com/es/fichas/restaurante/desde-1911-331525/', '331525', 'guiarepsol.com ficha: location 13 m, phone, website agree with the catalogue row'),
    (2, 'rest_1667', 'https://www.guiarepsol.com/es/fichas/restaurante/el-invernadero-de-rodrigo-de-la-calle-161219/', '161219', 'guiarepsol.com ficha: location 4 m, phone, website agree with the catalogue row. Name differs: Repsol "El Invernadero de Rodrigo de la Calle", catalogue "El Invernadero".'),
    (2, 'rest_1695', 'https://www.guiarepsol.com/es/fichas/restaurante/gofio-53886/', '53886', 'guiarepsol.com ficha: location 16 m, website agree with the catalogue row'),
    (2, 'rest_1728', 'https://www.guiarepsol.com/es/fichas/restaurante/la-tasqueria-10801/', '10801', 'guiarepsol.com ficha: location 9 m, phone, website agree with the catalogue row'),
    (2, 'rest_1754', 'https://www.guiarepsol.com/es/fichas/restaurante/montia-13133/', '13133', 'guiarepsol.com ficha: location 18 m, phone, website agree with the catalogue row'),
    (2, 'rest_1769', 'https://www.guiarepsol.com/es/fichas/restaurante/osa-332897/', '332897', 'guiarepsol.com ficha: location 6 m, phone, website agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back.'),
    (2, 'rest_1795', 'https://www.guiarepsol.com/es/fichas/restaurante/saddle-321891/', '321891', 'guiarepsol.com ficha: location 7 m, phone, website agree with the catalogue row'),
    (2, 'rest_0365', 'https://www.guiarepsol.com/es/fichas/restaurante/smoked-room-327330/', '327330', 'guiarepsol.com ficha: location 0 m, phone agree with the catalogue row'),
    (2, 'rest_1814', 'https://www.guiarepsol.com/es/fichas/restaurante/ugo-chan-327421/', '327421', 'guiarepsol.com ficha: location 14 m, phone, website agree with the catalogue row'),
    (2, 'rest_1817', 'https://www.guiarepsol.com/es/fichas/restaurante/velascoabella-332812/', '332812', 'guiarepsol.com ficha: location 35 m, phone, website agree with the catalogue row'),
    (2, 'rest_0373', 'https://www.guiarepsol.com/es/fichas/restaurante/molino-de-urdaniz-9006/', '9006', 'guiarepsol.com ficha: location 0 m, phone agree with the catalogue row. Name differs: Repsol "Molino de Urdániz", catalogue "El Molino de Urdániz".'),
    (2, 'rest_1792', 'https://www.guiarepsol.com/es/fichas/restaurante/rodero-11316/', '11316', 'guiarepsol.com ficha: location 48 m, phone, website agree with the catalogue row'),
    (2, 'rest_1610', 'https://www.guiarepsol.com/es/fichas/restaurante/atalaya-327310/', '327310', 'guiarepsol.com ficha: location 26 m, phone, website agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back.'),
    (2, 'rest_1621', 'https://www.guiarepsol.com/es/fichas/restaurante/beat-27072/', '27072', 'guiarepsol.com ficha: location 54 m, website agree with the catalogue row. Name differs: Repsol "Beat", catalogue "Beat by José Manuel Miguel".'),
    (2, 'rest_1628', 'https://www.guiarepsol.com/es/fichas/restaurante/cal-paradis-10597/', '10597', 'guiarepsol.com ficha: location 5 m, website agree with the catalogue row'),
    (2, 'rest_1638', 'https://www.guiarepsol.com/es/fichas/restaurante/casa-pepa-9292/', '9292', 'guiarepsol.com ficha: location 44 m, phone, website agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back.'),
    (2, 'rest_1686', 'https://www.guiarepsol.com/es/fichas/restaurante/fierro-8555/', '8555', 'guiarepsol.com ficha: location 10 m, phone, website agree with the catalogue row'),
    (2, 'rest_1773', 'https://www.guiarepsol.com/es/fichas/restaurante/peix-i-brases-10590/', '10590', 'guiarepsol.com ficha: location 3 m, phone, website agree with the catalogue row. Name differs: Repsol "Peix i Brases", catalogue "Peix & Brases".'),
    (2, 'rest_1782', 'https://www.guiarepsol.com/es/fichas/restaurante/raul-resino-11013/', '11013', 'guiarepsol.com ficha: location 5 m, phone, website agree with the catalogue row'),
    (2, 'rest_1790', 'https://www.guiarepsol.com/es/fichas/restaurante/riff-9801/', '9801', 'guiarepsol.com ficha: location 20 m, website agree with the catalogue row'),
    (2, 'rest_1813', 'https://www.guiarepsol.com/es/fichas/restaurante/tula-37796/', '37796', 'guiarepsol.com ficha: location 7 m, phone, website agree with the catalogue row'),
    (2, 'rest_1592', 'https://www.guiarepsol.com/es/fichas/restaurante/alameda-8988/', '8988', 'guiarepsol.com ficha: location 5 m, phone, website agree with the catalogue row'),
    (2, 'rest_1598', 'https://www.guiarepsol.com/es/fichas/restaurante/ama-tolosa-162189/', '162189', 'guiarepsol.com ficha: location 17 m, phone, website agree with the catalogue row. Name differs: Repsol "AMA Tolosa", catalogue "Ama".'),
    (2, 'rest_1600', 'https://www.guiarepsol.com/es/fichas/restaurante/andra-mari-9420/', '9420', 'guiarepsol.com ficha: location 6 m, phone, website agree with the catalogue row'),
    (2, 'rest_1605', 'https://www.guiarepsol.com/es/fichas/restaurante/arrea-321842/', '321842', 'guiarepsol.com ficha: location 71 m, phone, website agree with the catalogue row'),
    (2, 'rest_1618', 'https://www.guiarepsol.com/es/fichas/restaurante/bakea-332730/', '332730', 'guiarepsol.com ficha: location 17 m, phone, website agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back.'),
    (2, 'rest_1623', 'https://www.guiarepsol.com/es/fichas/restaurante/boroa-9454/', '9454', 'guiarepsol.com ficha: phone, website agree with the catalogue row'),
    (2, 'rest_1692', 'https://www.guiarepsol.com/es/fichas/restaurante/garena-325213/', '325213', 'guiarepsol.com ficha: location 10 m, phone, website agree with the catalogue row'),
    (2, 'rest_1712', 'https://www.guiarepsol.com/es/fichas/restaurante/kokotxa-8678/', '8678', 'guiarepsol.com ficha: location 4 m, phone, website agree with the catalogue row'),
    (2, 'rest_1752', 'https://www.guiarepsol.com/es/fichas/restaurante/mina-8666/', '8666', 'guiarepsol.com ficha: location 13 m, phone, website agree with the catalogue row'),
    (2, 'rest_1826', 'https://www.guiarepsol.com/es/fichas/restaurante/zarate-9054/', '9054', 'guiarepsol.com ficha: location 18 m, phone, website agree with the catalogue row'),
    (2, 'rest_1607', 'https://www.guiarepsol.com/es/fichas/restaurante/asador-opazo-26959/', '26959', 'guiarepsol.com ficha: location 50 m, phone, website agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back.'),
    (2, 'rest_1608', 'https://www.guiarepsol.com/es/fichas/restaurante/as-garzas-8736/', '8736', 'guiarepsol.com ficha: location 128 m, phone, website agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back.'),
    (2, 'rest_1747', 'https://www.guiarepsol.com/es/fichas/restaurante/maruja-limon-9737/', '9737', 'guiarepsol.com ficha: location 3 m, phone, website agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back.'),
    (2, 'rest_0369', 'https://www.guiarepsol.com/es/fichas/restaurante/pepe-vieira-11319/', '11319', 'guiarepsol.com ficha: location 0 m, phone, website agree with the catalogue row'),
    (2, 'rest_0371', 'https://www.guiarepsol.com/es/fichas/restaurante/retiro-da-costina-13485/', '13485', 'guiarepsol.com ficha: location 0 m, phone, website agree with the catalogue row'),
    (2, 'rest_1823', 'https://www.guiarepsol.com/es/fichas/restaurante/yayo-daporta-9183/', '9183', 'guiarepsol.com ficha: location 2 m, phone, website agree with the catalogue row'),
    (2, 'rest_1604', 'https://www.guiarepsol.com/es/fichas/restaurante/arbore-da-veira-9215/', '9215', 'guiarepsol.com ficha: location 12 m, phone, website agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back.'),
    (2, 'rest_1601', 'https://www.guiarepsol.com/es/fichas/restaurante/andreu-genestra-8922/', '8922', 'guiarepsol.com ficha: phone, website agree with the catalogue row'),
    (2, 'rest_1659', 'https://www.guiarepsol.com/es/fichas/restaurante/dins-santi-taura-9815/', '9815', 'guiarepsol.com ficha: address agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back. Repsol''s ficha gives the same address as the catalogue (Plaça Llorenç Villalonga 4, hotel El Llorenç Parc de la Mar, Palma), but its locality says Lloseta and its coordinates are wrong; matched on the address, the restaurant''s own site is the group site.'),
    (2, 'rest_1701', 'https://www.guiarepsol.com/es/fichas/restaurante/ikaro-111021/', '111021', 'guiarepsol.com ficha: location 6 m, phone, website agree with the catalogue row'),
    (2, 'rest_1711', 'https://www.guiarepsol.com/es/fichas/restaurante/kiro-sushi-9353/', '9353', 'guiarepsol.com ficha: location 14 m, phone, website agree with the catalogue row'),
    (2, 'rest_1761', 'https://www.guiarepsol.com/es/fichas/restaurante/nublo-327474/', '327474', 'guiarepsol.com ficha: location 9 m, phone, website agree with the catalogue row'),
    (2, 'rest_0353', 'https://www.guiarepsol.com/es/fichas/restaurante/venta-moncalvillo-8810/', '8810', 'guiarepsol.com ficha: location 0 m, phone, website agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back.'),
    (2, 'rest_1613', 'https://www.guiarepsol.com/es/fichas/restaurante/auga-9305/', '9305', 'guiarepsol.com ficha: location 6 m, phone, website agree with the catalogue row'),
    (2, 'rest_1664', 'https://www.guiarepsol.com/es/fichas/restaurante/el-corral-del-indianu-8634/', '8634', 'guiarepsol.com ficha: location 9 m, phone, website agree with the catalogue row'),
    (2, 'rest_1669', 'https://www.guiarepsol.com/es/fichas/restaurante/el-retiro-8889/', '8889', 'guiarepsol.com ficha: phone, website agree with the catalogue row. Repsol ficha has latitude and longitude swapped; compared swapped back.'),
    (2, 'rest_1784', 'https://www.guiarepsol.com/es/fichas/restaurante/real-balneario-9020/', '9020', 'guiarepsol.com ficha: location 59 m, phone, website agree with the catalogue row'),
    (2, 'rest_1787', 'https://www.guiarepsol.com/es/fichas/restaurante/regueiro-8753/', '8753', 'guiarepsol.com ficha: location 7 m, phone, website agree with the catalogue row'),
    (2, 'rest_1596', 'https://www.guiarepsol.com/es/fichas/restaurante/almo-325210/', '325210', 'guiarepsol.com ficha: location 11 m, phone, website agree with the catalogue row. Name differs: Repsol "Almo", catalogue "Almo de Juan Guillamón".'),
    (2, 'rest_1619', 'https://www.guiarepsol.com/es/fichas/restaurante/barahonda-9817/', '9817', 'guiarepsol.com ficha: phone, website agree with the catalogue row'),
    (2, 'rest_1740', 'https://www.guiarepsol.com/es/fichas/restaurante/magoga-9878/', '9878', 'guiarepsol.com ficha: location 12 m, website agree with the catalogue row');

do $$
declare missing int;
begin
  select count(*) into missing from repsol_stage s
  left join public.restaurants r on r.restaurant_code = s.restaurant_code and r.country_code = 'ES'
  where r.id is null;
  if missing > 0 then
    raise exception '% staged rows do not resolve on restaurant_code + ES', missing;
  end if;
end $$;

insert into public.guide_awards (guide_code, restaurant_id, edition_year, list_name, tier, source_url, announced_on)
select 'guia_repsol', r.id, 2026, 'soles', s.tier,
       'https://www.guiarepsol.com/es/comer/soles-repsol/ediciones-de-soles/2026/', date '2026-02-16'
from repsol_stage s join public.restaurants r on r.restaurant_code = s.restaurant_code and r.country_code = 'ES';

insert into public.guide_venue_links (guide_code, restaurant_id, external_id, profile_url, evidence, verified_at)
select 'guia_repsol', r.id, s.external_id, s.profile_url, s.evidence, date '2026-11-16'
from repsol_stage s join public.restaurants r on r.restaurant_code = s.restaurant_code and r.country_code = 'ES';

insert into public.guide_coverage (guide_code, country_code, edition_year, coverage, note) values
  ('guia_repsol', 'ES', 2026, 'partial',
   'Shown for the restaurants in our catalogue with 3 or 2 Soles: all 46 with three, 113 of 173 with two. Restaurants with 1 Sol follow.');

do $$
declare t3 int; t2 int; k int;
begin
  select count(*) filter (where tier = 3), count(*) filter (where tier = 2) into t3, t2
  from public.guide_awards where guide_code = 'guia_repsol' and edition_year = 2026;
  select count(*) into k from public.guide_venue_links where guide_code = 'guia_repsol';
  if t3 <> 46 or t2 <> 113 or k <> 159 then
    raise exception 'post-check failed: 3 Soles %, 2 Soles %, links %', t3, t2, k;
  end if;
end $$;

commit;
