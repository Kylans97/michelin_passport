# lambrusco-di-sorbara

## Official text
- Lambrusco di Sorbara DOC (header: last amended Decreto 05.11.2024). Art. 3: whole territory of Bastiglia, Bomporto, Nonantola, Ravarino, San Prospero and part of Campogalliano, Camposanto, Carpi, Castelfranco Emilia, Modena, Soliera, San Cesario sul Panaro.

## Counts
12 printed names, 12 rows, 7 partial; by province: Modena 12.
- Seven partial rows as the text says.

Method: comune names taken verbatim from the disciplinare in the MASAF archive (https://www.masaf.gov.it/flex/cm/pages/ServeBLOB.php/L/IT/IDPagina/4625, archives downloaded 2026-11-20, text extracted to `raw/txt/`). Each name resolved within its named province only with `it_tools/istat.py` (ISTAT current list, suppressed comuni and variations since 1991), then mapped to GISCO LAU 2024 by ISTAT code (`IT_` + 6 digits). Build: `../../it_tools/build_round5.py`; style assembly: `../../it_tools/style_round5.py`. A merged comune is marked partial when it also absorbed (since 1991) a comune the text does not list.

## Style sourcing
- Summary, ratings and pairing: see `sources` in style.json. Soil type held back: blogs say sandy and loose, the disciplinare says silty clay loam (Sant'Omobono franca limosa argillosa) of river origin; only 'laid down by the rivers' kept. Climate (continental) only in the disciplinare among fetched pages, left out. Ratings are for the Sorbara grape and its wine (the DOC is mostly Sorbara). Pairing held back: Cellar Tours gives zuppa inglese and torta di riso, Wine Folly spicy Thai and Indian food; no overlap.
- Label note, grapes and appellations: from the disciplinare (Art. 1, 2, 5, 7), cited as the MASAF archive page.
