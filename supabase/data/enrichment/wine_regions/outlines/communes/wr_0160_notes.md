# abruzzo

## Official text
- Montepulciano d'Abruzzo DOC (header: last amended D.M. 19.01.2023, G.U. 30 of 06.02.2023; G.U.U.E. C 220 of 22.06.2023). Art. 3: "l'intero territorio amministrativo dei seguenti comuni", listed by province (Chieti, L'Aquila, Pescara, Teramo).

## Counts
189 printed names, 189 rows, 0 partial; by province: Chieti 75, L'Aquila 37, Pescara 39, Teramo 38.
- All whole comuni. Colline Teramane DOCG (Art. 3 lists 31 Teramo comuni, all inside the DOC list) is an appellation only, not drawn separately. Its "Celino Attanasio" is a misprint for Cellino Attanasio (the same article's delimitation spells it Cellino). Popoli is now Popoli Terme (ISTAT rename). Cerasuolo d'Abruzzo and Trebbiano d'Abruzzo were not read and are not listed as appellations.

## Name resolution
- ALIAS: Francavilla -> Francavilla al Mare (short form; the only comune in the province of Chieti whose name starts with Francavilla)
- ALIAS: San Demetrio nei Vestini -> San Demetrio ne' Vestini (spelling variant (nei for ne'); the only comune in the province of L'Aquila whose name starts with San Demetrio)
- ALIAS: Tione d'Abruzzi -> Tione degli Abruzzi (spelling variant (d' for degli); the only comune in the province of L'Aquila whose name starts with Tione)
- ALIAS: Villa S. Angelo -> Villa Sant'Angelo (abbreviation of Sant')
- ALIAS: Villa S. Lucia -> Villa Santa Lucia degli Abruzzi (abbreviation and short form; the only comune in the province of L'Aquila whose name starts with Villa Santa Lucia)
- ALIAS: Bussi -> Bussi sul Tirino (short form; the only comune in the province of Pescara whose name starts with Bussi)
- HIST: Popoli -> 068033 Popoli Terme via [('068033', 'renamed')]; predecessors of 068033: []
- ALIAS: San Valentino -> San Valentino in Abruzzo Citeriore (short form; the only comune in the province of Pescara whose name starts with San Valentino)
- ALIAS: Mosciano -> Mosciano Sant'Angelo (short form; the Colline Teramane text spells it Mosciano Sant'Angelo)
- ALIAS: Penna S. Andrea -> Penna Sant'Andrea (abbreviation of Sant')
- ALIAS: Sant'Egidio -> Sant'Egidio alla Vibrata (short form; the Colline Teramane text spells it Sant'Egidio alla Vibrata)
- ALIAS: Isola del Gran Sasso -> Isola del Gran Sasso d'Italia (short form; the only comune in the province of Teramo whose name starts with Isola del Gran Sasso)

Method: comune names taken verbatim from the disciplinare in the MASAF archive (https://www.masaf.gov.it/flex/cm/pages/ServeBLOB.php/L/IT/IDPagina/4625, archives downloaded 2026-11-20, text extracted to `raw/txt/`). Each name resolved within its named province only with `it_tools/istat.py` (ISTAT current list, suppressed comuni and variations since 1991), then mapped to GISCO LAU 2024 by ISTAT code (`IT_` + 6 digits). Build: `../../it_tools/build_round5.py`; style assembly: `../../it_tools/style_round5.py`. A merged comune is marked partial when it also absorbed (since 1991) a comune the text does not list.

## Style sourcing
- Summary, ratings and pairing: see `sources` in style.json. Ratings are grape level (Wine Folly Montepulciano) plus wine level guides; the DOC requires at least 85 percent Montepulciano. Body 4: Wine Folly medium-full and Vinovest medium to full agree; Wine Traveler says medium. Acidity 4: Wine Folly medium-high and Wine Traveler lively/high agree; Vinovest says medium. Tannin nulled: Wine Folly medium-high, Vinovest moderate, Wine Traveler soft-to-medium in one place and firmer in another, no clean two-source bucket. Vinovest is an investment platform's guide, the weakest of the sources. Soils: the disciplinare describes mostly sandy clay soils; clay and limestone is from Wine Traveler (calcareous clay) and Vinovest (clay, limestone, sand); Decanter's clay and limestone line covers only Colline Teramane, so not cited. Dark fruit and Decanter's 'rich' character held back (one source each).
- Label note, grapes and appellations: from the disciplinare (Art. 1, 2, 5, 7), cited as the MASAF archive page.
