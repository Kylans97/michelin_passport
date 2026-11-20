# Genève (AOC Genève)

## Official text
- Règlement sur la vigne et les vins de Genève (RVV), rsGE M 2 50.05, of 20.05.2009; SILGENEVE
  version with "Dernières modifications au 17 novembre 2026".
  https://silgeneve.ch/legis/data/rsg_m2_50p05.htm (`raw/ge_rvv_m25005.html`).
- Art. 57 (Aire géographique): the AOC Genève area comprises
  a) "la totalité du territoire du canton de Genève";
  b) "la totalité des communes françaises de Challex et Ferney-Voltaire";
  c) "les parties des communes françaises d'Ornex, Chens-sur-Léman, Veigy-Foncenex,
     Saint-Julien-en-Genevois et Viry, conformément au plan adopté par le Conseil d'Etat".
- Art. 57A: the grape zone is the cadastre viticole in Geneva and, in France, at most 140 ha.
  Art. 57B: vinification only on Swiss territory.
- Art. 51: AOC Premier cru areas are drawn on plans kept by the cantonal office, not named in
  the text.

## How the area is defined
Whole canton (45 communes) plus 7 French communes (2 whole, 5 partial).

## French communes
- GISCO FR IDs are the INSEE codes. They were checked against the official INSEE COG 2026 file
  already in this workspace (`dl_inao/v_commune_2026.csv`): 01078 Challex, 01160 Ferney-Voltaire,
  01281 Ornex (Ain); 74070 Chens-sur-Léman, 74243 Saint-Julien-en-Genevois, 74293 Veigy-Foncenex,
  74309 Viry (Haute-Savoie). The GISCO names match.
- Viry: three French communes have this name (39, 71, 74). The text gives no department. The pick
  is 74309 (Haute-Savoie, arrondissement of Saint-Julien-en-Genevois), the only one bordering
  Geneva. A French 2009 arrêté on the Franco-Swiss vine zone, found by search but not downloaded,
  also places Viry in Haute-Savoie. Logged as a judgement call.
- The 5 partial rows carry the art. 57 c wording in `partial`. The perimeters are on a Conseil
  d'Etat plan that was not retrieved.

## Counts
52 rows: 45 Geneva communes (`CH_CH66xx`) + 7 French. 5 partial. Excluded: `CH_CH9760` Lac Léman (GE).

## Style sourcing
- Grape order: official Geneva statistics 2024 (`raw/ge_stats_2024.pdf`: Gamay 275.1 ha, Chasselas
  254.8, Pinot noir 159.9, Gamaret 116.8, Chardonnay 116.4), the same order as Swiss Wine Promotion.
- "Perlan" note: RVV art. 59A (label mention for still Chasselas AOC Genève).

## Held back
- Names of the Premier Cru appellations. Swiss Wine Promotion says there are 22, but the RVV does
  not list them; they sit on cantonal plans.
- Red body, acidity and tannin and a pairing: no two sources gave a regional view.
