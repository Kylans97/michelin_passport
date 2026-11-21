# fiano-di-avellino

## Official text
- Fiano di Avellino DOCG (header: last amended DM 13.10.2020; Union amendment Reg. 2025/1086 of 3 June 2025). Art. 3: "l'intero territorio amministrativo dei seguenti comuni della provincia di Avellino", 26 names.

## Counts
26 printed names, 26 rows, 0 partial; by province: Avellino 26.
- All whole. Not an existing name under Taurasi, so drawn as its own region; it overlaps Taurasi at Lapio and Montefalcione.

## Name resolution
- ALIAS: S. Stefano del Sole -> Santo Stefano del Sole (abbreviation of Santo)
- ALIAS: S. Potito Ultra -> San Potito Ultra (abbreviation of San)
- ALIAS: S. Angelo a Scala -> Sant'Angelo a Scala (abbreviation of Sant')

Method: comune names taken verbatim from the disciplinare in the MASAF archive (https://www.masaf.gov.it/flex/cm/pages/ServeBLOB.php/L/IT/IDPagina/4625, archives downloaded 2026-11-20, text extracted to `raw/txt/`). Each name resolved within its named province only with `it_tools/istat.py` (ISTAT current list, suppressed comuni and variations since 1991), then mapped to GISCO LAU 2024 by ISTAT code (`IT_` + 6 digits). Build: `../../it_tools/build_round5.py`; style assembly: `../../it_tools/style_round5.py`. A merged comune is marked partial when it also absorbed (since 1991) a comune the text does not list.

## Style sourcing
- Summary, ratings and pairing: see `sources` in style.json. White, so red ratings null. Altitude figures (300 to 650 m) not independently confirmed twice, left out. Hazelnut kept only as 'toasted nut notes with age' (Gambero Rosso toasted hazelnut, Irish Times toasted nuts). Pairing held back: Cellar Tours names langoustines, Irish Times only says the region's wines suit seafood generally; not the same claim for Fiano.
- Label note, grapes and appellations: from the disciplinare (Art. 1, 2, 5, 7), cited as the MASAF archive page.
