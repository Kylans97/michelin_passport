# Franciacorta (DOCG Franciacorta)

## Official text
- Disciplinare DOCG "Franciacorta", last amended DM 07.05.2024 (header as printed). Art. 3: in the province of Brescia, "tutto il territorio dei comuni di" 14 comuni, "nonché la parte del territorio dei comuni di Cologne, Coccaglio, Rovato e Cazzago S. Martino che si trova a nord delle ex strade statali n. 573 e n. 11 e parte del territorio del comune di Brescia".

Method (all regions): comune names are taken verbatim from Art. 3 of the disciplinare in the MASAF archive (page https://www.masaf.gov.it/flex/cm/pages/ServeBLOB.php/L/IT/IDPagina/4625, archives downloaded 2026-11-20/21, text in `raw/txt/`). Each name is resolved within its named province only, with `it_tools/istat.py` (ISTAT current list, suppressed comuni and variations since 1991), then mapped to GISCO LAU 2024 by ISTAT code (`IT_` + 6 digits). Every name maps to exactly one unit. Build script: `../../it_tools/build_classics.py`; style assembly: `../../it_tools/style_classics.py`. LAU 2024 predates four 2024/25 ISTAT mergers (Sovizzo, Setteville, Santa Caterina d'Este, Uggiate con Ronago); LAU 2024 units are used as they stand.

## Counts
19 names in the text, 18 rows: 14 `partial = no`, 4 `partial = yes`. Brescia left out.

## Judgement calls
- **Brescia left out**: inside Brescia the Art. 3 boundary runs only along the ex SS 11 at Mandolossa, the road to the Badia and the hill of Sant'Anna, then joins the Cellatica boundary: a strip on the side facing Cellatica and Gussago. Including the comune would draw the whole city. (Judgement from the text's wording, no area was measured.) Add IT_017029 if the reviewer prefers the full list.
- Cazzago S. Martino = Cazzago San Martino.
- The four partial comuni keep the "north of the ex SS 573 and SS 11" wording; the part north is substantial in each.

## Style sourcing
Grapes by planted area (consorzio): Chardonnay, Pinot Noir, Pinot Blanc. Erbamat is not in the app and was dropped from the list. Pairing: cheese only, the common ground of the consorzio and Wine Folly.

## Held back
- Erbamat as a grape (not in app, not profiled).
