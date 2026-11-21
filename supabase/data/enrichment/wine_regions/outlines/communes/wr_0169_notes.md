# lugana

## Official text
- Lugana DOC (header: last listed change Provvedimento Ministeriale 12.07.2019). Art. 3 is a boundary line only, naming the provinces of Brescia and Verona. Art. 9 of the same official text states the comuni: "tutto il comune di Sirmione (BS) e una porzione dei comuni confinati Desenzano del Garda (BS), Lonato del Garda (BS), Pozzolengo (BS) e Peschiera del Garda (VR)".

## Counts
5 printed names, 5 rows, 4 partial; by province: Brescia 4, Verona 1.
- Comuni from Art. 9, not Art. 3; Sirmione whole, the other four partial.

Method: comune names taken verbatim from the disciplinare in the MASAF archive (https://www.masaf.gov.it/flex/cm/pages/ServeBLOB.php/L/IT/IDPagina/4625, archives downloaded 2026-11-20, text extracted to `raw/txt/`). Each name resolved within its named province only with `it_tools/istat.py` (ISTAT current list, suppressed comuni and variations since 1991), then mapped to GISCO LAU 2024 by ISTAT code (`IT_` + 6 digits). Build: `../../it_tools/build_round5.py`; style assembly: `../../it_tools/style_round5.py`. A merged comune is marked partial when it also absorbed (since 1991) a comune the text does not list.

## Style sourcing
- Summary, ratings and pairing: see `sources` in style.json. White, so red ratings null. Glacial origin of the clay and the flat terrain are in the disciplinare only among fetched sources, so left out. Almond: disciplinare (mandorla) and Cellar Tours (with age). Pairing: VinePair names pike, Cellar Tours lake whitefish and lake trout. Wine Enthusiast (403) and Decanter (truncated) could not be read. italianwinecentral lists the grape as 'Verdicchio', a synonym muddle; not used.
- Label note, grapes and appellations: from the disciplinare (Art. 1, 2, 5, 7), cited as the MASAF archive page.
