# Valais (AOC Valais)

## Official text
- Ordonnance sur la vigne et le vin (OVV), RS VS 916.142, of 17.03.2004. Current version in force
  since 01.04.2026 (adopted 25.02.2026), lex.vs.ch version id 3580.
  https://lex.vs.ch/app/fr/texts_of_law/916.142 (PDF: `raw/vs_ovv_916142_v3580.pdf`).
- Art. 37 al. 1: "AOC Valais" is given only to wines from Valais AOC harvests ("vendanges
  valaisannes AOC"). Art. 40 al. 1: AOC Valais wines must come from grapes picked, weighed, tested
  and vinified in Valais. Art. 8: the "aire vinicole" is the set of parcels for commercial wine
  production, recorded in the cadastre viticole.
- Federal frame: Ordonnance sur le vin RS 916.140 (état 1.1.2026), art. 21: an AOC is named after a
  canton or an area within one, and the canton delimits it.

## How the area is defined
The whole canton: the appellation name is the canton and the text sets no communal limit beyond the
cadastre viticole. All 122 Valais communes (BFS 31.12.2023) are listed; `partial` empty.

## Counts
- 122 rows, 122 unique GISCO IDs, all `CH_CH6xxx`, all names identical to LAU.
- Excluded: `CH_CH9759` Lac Léman (VS), a water unit.

## Judgement calls
- Grand Cru areas are set by communal regulations (OVV art. 85–86), not listed in the OVV. They
  are not drawn and are not named individually in style.json.
- Grape order (style.json) follows the Swiss Wine Promotion Valais table (Pinot Noir 1,275 ha,
  Chasselas 755, Gamay 457, Silvaner 317, Petite Arvine 259, Savagnin Blanc 214, Syrah 172,
  Cornalin 163, Humagne Rouge 143). The federal statistics (BLW, L'anno viticolo 2025, table 1.2/1.3,
  `raw/weinjahr_2024.pdf`; the file name says 2024 but its content is the 2025 edition) agree where
  the column reading is unambiguous: Valais Pinot Noir ≈1,222 ha, Chasselas ≈736 ha, and nearly all
  Swiss Petite Arvine, Cornalin and Humagne Rouge.
- Silvaner (Johannisberg) and Savagnin Blanc (Heida) are left out of the grape list because neither
  is in the existing grape list and neither was researched as a new grape. The order of the
  remaining grapes is unchanged.
- Red body, acidity and tannin are null: Valais reds span Pinot Noir, Gamay, Cornalin, Humagne
  Rouge and Syrah, and no two sources give one regional rating.

## Held back
- Individual Grand Cru names and perimeters (communal regulations, not fetched).
- A Valais style pairing for Petite Arvine with cheese (only one source).
