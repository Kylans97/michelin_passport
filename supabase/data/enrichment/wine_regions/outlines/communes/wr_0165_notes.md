# gallura

## Official text
- Vermentino di Gallura DOCG (header: last amended DM 07.03.2014). Art. 3: "l'intero territorio dei comuni di" 22 comuni "in Provincia di Olbia-Tempio, e Viddalba in Provincia di Sassari".

## Counts
23 printed names, 23 rows, 0 partial; by province: Sassari 23.
- Olbia-Tempio no longer exists; all 23 resolve to ISTAT province 090 (Sassari), which is how LAU 2024 codes them. All whole.

## Name resolution
- ALIAS: S. Antonio di Gallura -> Sant'Antonio di Gallura (abbreviation of Sant')
- ALIAS: S. Teodoro -> San Teodoro (abbreviation of San)
- ALIAS: S. Teresa di Gallura -> Santa Teresa Gallura (abbreviation of Santa; ISTAT name has no "di"; the only Santa Teresa in Sardinia)
- ALIAS: Trinità d'Agultu -> Trinità d'Agultu e Vignola (short form; the only comune in Sardinia whose name starts with Trinità d'Agultu)

Method: comune names taken verbatim from the disciplinare in the MASAF archive (https://www.masaf.gov.it/flex/cm/pages/ServeBLOB.php/L/IT/IDPagina/4625, archives downloaded 2026-11-20, text extracted to `raw/txt/`). Each name resolved within its named province only with `it_tools/istat.py` (ISTAT current list, suppressed comuni and variations since 1991), then mapped to GISCO LAU 2024 by ISTAT code (`IT_` + 6 digits). Build: `../../it_tools/build_round5.py`; style assembly: `../../it_tools/style_round5.py`. A merged comune is marked partial when it also absorbed (since 1991) a comune the text does not list.

## Style sourcing
- Summary, ratings and pairing: see `sources` in style.json. White region, red ratings null. Granite: disciplinare, Decanter, Wine Folly. Wind: disciplinare and Wine Folly. Day/night swings: Decanter and Wine Folly. Intensity: Decanter (intense) and Wine Folly (aromatic intensity). Acidity: Wine Folly (bright, refreshing) with Decanter's grape glossary (good acid retention). Decanter's 'minerally rather than overtly fruity' and salty edge held back (one source each for Gallura). Pairing: Wine Folly and Decanter name seafood for Sardinian Vermentino generally; Wine Traveler fish, also general.
- Label note, grapes and appellations: from the disciplinare (Art. 1, 2, 5, 7), cited as the MASAF archive page.
