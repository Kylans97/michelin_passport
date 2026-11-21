# Taurasi (DOCG Taurasi)

## Official text
- Disciplinare DOCG "Taurasi", last amended DM 13.10.2020 (GU 266, 26.10.2020). Art. 3: "comprende l'intero territorio amministrativo dei comuni di" 17 comuni, "tutti in provincia di Avellino".
- Irpinia DOC was checked and not used: its Art. 3 covers "le aree vocate alla coltivazione della vite dell'intero territorio amministrativo della provincia di Avellino", i.e. the whole province; Taurasi is the comune based core the brief asked for.

Method (all regions): comune names are taken verbatim from Art. 3 of the disciplinare in the MASAF archive (page https://www.masaf.gov.it/flex/cm/pages/ServeBLOB.php/L/IT/IDPagina/4625, archives downloaded 2026-11-20/21, text in `raw/txt/`). Each name is resolved within its named province only, with `it_tools/istat.py` (ISTAT current list, suppressed comuni and variations since 1991), then mapped to GISCO LAU 2024 by ISTAT code (`IT_` + 6 digits). Every name maps to exactly one unit. Build script: `../../it_tools/build_classics.py`; style assembly: `../../it_tools/style_classics.py`. LAU 2024 predates four 2024/25 ISTAT mergers (Sovizzo, Setteville, Santa Caterina d'Este, Uggiate con Ronago); LAU 2024 units are used as they stand.

## Counts
17 names, 17 rows, all Avellino, all `partial = no`.

## Judgement calls
- Montemileto (Art. 3) = Montemiletto: Art. 9 of the same text spells it Montemiletto, the only such comune.

## Style sourcing
- Summary: position from Art. 3 and Art. 9 (17 comuni of Irpinia, volcanic ash deposits in places) with Italian Wine Central (Campania; Aglianico's best vineyards on volcanic soils); character from Wine Folly and Italian Wine Central Aglianico pages.
- Ratings are Aglianico grape ratings, not Taurasi specific (body 5: Wine Folly, Wine Companion; acidity 4 and tannin 4: Wine Folly, Italian Wine Central).
- Grapes from Art. 2 (Aglianico at least 85 percent) and Italian Wine Central.

## Held back
- Climate (Art. 9 describes it, no second source reached).
- Pairing (Wine Folly only, and for Aglianico in general).
