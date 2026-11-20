# Vaud (AOC Vaud)

## Official text
- Règlement sur les vins vaudois (RVV), BLV 916.125.2, of 27.05.2009, consolidated version in
  force from 01.07.2026 ("Actuelle", document generated 07.07.2026).
  https://www.lexfind.ch/tolv/261089/fr (PDF: `raw/lexfind_261089.pdf`).
- Art. 1 al. 1: wines from grapes harvested on the territory of the Canton of Vaud that meet
  art. 14–21 are entitled to AOC "Vaud" (or terms with "vaudois").
- Art. 3: nine wine regions (Chablais, Lavaux, La Côte, Côtes-de-l'Orbe, Bonvillars, Vully,
  Dézaley, Calamin; i is repealed). Art. 4: the regional AOCs and the three Grand cru AOCs
  (Dézaley, Calamin, Dézaley-Marsens).

## How the area is defined
The whole canton (art. 1). All 300 Vaud communes (BFS 31.12.2023) are listed; `partial` empty.
Lavaux, as a regional AOC within Vaud, has its own file (`lavaux.csv`) and overlaps this one.

## Counts
- 300 rows, 300 unique GISCO IDs (`CH_CH5401`–`CH_CH5939`), all names identical to LAU.
- Excluded water units: 9154 Lac de Neuchâtel (VD), 9296 Murtensee (VD), 9758 Lac Léman (VD),
  9751 Lac de Joux.

## Judgement calls
- Vully AOC is shared with Fribourg (Mont-Vully, art. 3 let. f). The Fribourg part is not in this
  file because the Vaud AOC itself covers only Vaud.
- Appellation colours "white, red" for the regional AOCs come from art. 18, which sets minimum
  sugar levels for white grapes, Gamay and other red grapes in each region including Dézaley and
  Calamin.
- Grape order follows Swiss Wine Promotion (Chasselas 2,233 ha, Pinot Noir 476, Gamay 311,
  Gamaret 148, Garanoir 126, Chardonnay 47). The federal statistics give Vaud Chasselas ≈2,182 ha
  of 3,747 ha, which agrees.
- "Second largest wine canton" uses the BLW harvest 2024 table (VS 4,616 ha, VD 3,747 ha, GE 1,326 ha).
  "Only canton where white grapes lead": Swiss Wine Promotion, and the federal white-grape totals
  (Vaud ≈2,428 ha white of 3,747).

## Held back
- Garanoir from the grape list (it would need a new grape entry; not researched).
- Pairing "lake fish with Chasselas": Swiss Wine Promotion says so, but the second source found
  (a Vaud tasting booklet, `raw/vd_carnet_degustation_2017.pdf`) pairs it with a single wine only.
  The pairing used instead, fondue with Chasselas, is in Swiss Wine Promotion and Wine Folly.
