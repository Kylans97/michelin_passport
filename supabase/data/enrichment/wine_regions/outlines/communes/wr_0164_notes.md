# sardinia

## Official text
- Cannonau di Sardegna DOC (header: last amended DM 07.03.2014). Art. 3: "Le uve ... devono essere prodotte nell'ambito territoriale della regione Sardegna." Vermentino di Sardegna DOC Art. 3 says the same ("nella regione Sardegna").

## Counts
377 printed names, 377 rows, 0 partial; by province: Cagliari 17, Nuoro 74, Oristano 87, Sassari 92, Sud Sardegna 107.
- Drawn as every LAU 2024 unit with ISTAT province code 090, 091, 092, 095 or 111 (377 units, which is all Sardinian comuni). Sottozone Oliena, Capo Ferrato and Jerzu and Classico (Nuoro and Ogliastra) are appellations only, not drawn.

Method: comune names taken verbatim from the disciplinare in the MASAF archive (https://www.masaf.gov.it/flex/cm/pages/ServeBLOB.php/L/IT/IDPagina/4625, archives downloaded 2026-11-20, text extracted to `raw/txt/`). Each name resolved within its named province only with `it_tools/istat.py` (ISTAT current list, suppressed comuni and variations since 1991), then mapped to GISCO LAU 2024 by ISTAT code (`IT_` + 6 digits). Build: `../../it_tools/build_round5.py`; style assembly: `../../it_tools/style_round5.py`. A merged comune is marked partial when it also absorbed (since 1991) a comune the text does not list.

## Style sourcing
- Summary, ratings and pairing: see `sources` in style.json. Rated as Cannonau di Sardegna; Vermentino di Sardegna not covered. Body 5: Decanter, Wine Traveler and Wine Folly all say full bodied (Wine Folly's grape level Grenache says medium-full). Acidity 2: Decanter soft and Wine Traveler light; Wine Folly Sardinia says moderate. Tannin 2: Decanter light tannins and Wine Traveler 'adds body and fruit without adding tannin'; caveat, Decanter's Jefford and expert pieces describe firm, sinewy tannins in high Nuoro/Mamoiada wines, so mountain wines run higher. Wine Traveler's 'medium alcohol' conflicts with Decanter and Wine Folly (high); summary follows the latter two. Pairing: suckling pig (porceddu) is backed only by Wine Traveler and blogs, so the line is generalised to roast pork/roasted meats, with Wine Folly's Grenache (grape level) as second source.
- Label note, grapes and appellations: from the disciplinare (Art. 1, 2, 5, 7), cited as the MASAF archive page.
