# marsala

## Official text
- Marsala DOC (header lists Decreti 01.07.2025 and 05.08.2026 as the last changes). Art. 3: "l'intero territorio della provincia di Trapani, esclusi i comuni di Pantelleria, Favignana ed Alcamo".

## Counts
22 printed names, 22 rows, 0 partial; by province: Trapani 22.
- Drawn as every LAU 2024 unit with ISTAT province code 081 except 081014 Pantelleria, 081009 Favignana and 081001 Alcamo (22 units, including Misiliscemi, created in 2021 from part of Trapani).

Method: comune names taken verbatim from the disciplinare in the MASAF archive (https://www.masaf.gov.it/flex/cm/pages/ServeBLOB.php/L/IT/IDPagina/4625, archives downloaded 2026-11-20, text extracted to `raw/txt/`). Each name resolved within its named province only with `it_tools/istat.py` (ISTAT current list, suppressed comuni and variations since 1991), then mapped to GISCO LAU 2024 by ISTAT code (`IT_` + 6 digits). Build: `../../it_tools/build_round5.py`; style assembly: `../../it_tools/style_round5.py`. A merged comune is marked partial when it also absorbed (since 1991) a comune the text does not list.

## Style sourcing
- Summary, ratings and pairing: see `sources` in style.json. Fortified, red ratings null. Altitude, climate and soils: disciplinare and WineTourism. Western tip and Trapani: Wine Folly, Decanter, WineTourism, Il Sole 24 Ore. Dry to sweet: Wine Folly and Decanter. Cannoli: Decanter and WineTourism. Cheese: WineTourism (pecorino with secco/semisecco) and Il Sole 24 Ore (blue cheese); the cheeses differ, so the line says only 'cheese'. Wine Folly's terra rossa and saline note, Decanter's oxidative complexity, and flavour descriptors held back (one source each).
- Label note, grapes and appellations: from the disciplinare (Art. 1, 2, 5, 7), cited as the MASAF archive page.
