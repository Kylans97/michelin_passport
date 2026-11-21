# verdicchio-di-matelica

## Official text
- Verdicchio di Matelica DOC and Verdicchio di Matelica Riserva DOCG (DOCG header: last amended DM 24.06.2025, G.U. 157 of 09.07.2025). Art. 3: "parte del territorio dei comuni di" six Macerata and two Ancona comuni, then a boundary line.

## Counts
8 printed names, 8 rows, 8 partial; by province: Ancona 2, Macerata 6.
- All eight rows partial (the text says part of each).

Method: comune names taken verbatim from the disciplinare in the MASAF archive (https://www.masaf.gov.it/flex/cm/pages/ServeBLOB.php/L/IT/IDPagina/4625, archives downloaded 2026-11-20, text extracted to `raw/txt/`). Each name resolved within its named province only with `it_tools/istat.py` (ISTAT current list, suppressed comuni and variations since 1991), then mapped to GISCO LAU 2024 by ISTAT code (`IT_` + 6 digits). Build: `../../it_tools/build_round5.py`; style assembly: `../../it_tools/style_round5.py`. A merged comune is marked partial when it also absorbed (since 1991) a comune the text does not list.

## Style sourcing
- Summary, ratings and pairing: see `sources` in style.json. White region, red ratings null. Decanter's three pages count as one source; the second for style is the Italian Wine Podcast (IWA guest contributor), and the disciplinare backs position, no sea influence and calcareous/marl soils. 'Cold winters' (disciplinare only) and exact altitudes (sources give 300 to 400 m and 350 m) held back. Pairing is grape level, for Verdicchio in general (Decanter: affinity with Adriatic fish; Wine Spectator: drunk with seafood), not Matelica specific. Riserva ageing figures disagree (Decanter 24 months vs 18 elsewhere), not used.
- Label note, grapes and appellations: from the disciplinare (Art. 1, 2, 5, 7), cited as the MASAF archive page.
