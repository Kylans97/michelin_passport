# Friuli (DOC Friuli or Friuli Venezia Giulia)

## Why Friuli DOC, not Friuli Colli Orientali
- Friuli Colli Orientali DOC (disciplinare last amended DM 07.07.2025): Art. 3.1 defines the zone only by a boundary line (from Madonna west of Tarcento, along roads, rivers and the state border). It lists no comuni, so it cannot be drawn as a union of comuni. **Held back.**
- Friuli DOC is used instead, as the brief allowed.

## Official text
- Disciplinare DOC "Friuli" o "Friuli Venezia Giulia" ("Furlanija", "Furlanija Julijska krajina"), approved by Reg. di esecuzione (UE) 2020/1680 of 06.11.2020 (GUUE L 379, 13.11.2020). Art. 3.1: "comprende l'intero territorio comunale, dei seguenti comuni", listed by province: Pordenone 40, Gorizia 25, Trieste 6, Udine 87.

Method (all regions): comune names are taken verbatim from Art. 3 of the disciplinare in the MASAF archive (page https://www.masaf.gov.it/flex/cm/pages/ServeBLOB.php/L/IT/IDPagina/4625, archives downloaded 2026-11-20/21, text in `raw/txt/`). Each name is resolved within its named province only, with `it_tools/istat.py` (ISTAT current list, suppressed comuni and variations since 1991), then mapped to GISCO LAU 2024 by ISTAT code (`IT_` + 6 digits). Every name maps to exactly one unit. Build script: `../../it_tools/build_classics.py`; style assembly: `../../it_tools/style_classics.py`. LAU 2024 predates four 2024/25 ISTAT mergers (Sovizzo, Setteville, Santa Caterina d'Este, Uggiate con Ronago); LAU 2024 units are used as they stand.

## Counts
158 names, 156 rows (Pordenone 40, Gorizia 25, Trieste 6, Udine 85). All `partial = no`.

## Judgement calls
- Mergers: Campolongo al Torre + Tapogliano = Campolongo Tapogliano (2009); Fiumicello + Villa Vicentina = Fiumicello Villa Vicentina (2018). Both predecessors are listed each time, so the successors are whole. "Arzene - Valvasone" is the merged Valvasone Arzene (2015).
- Buia = ISTAT Buja (i for j, the only such comune in Udine).
- Duino-Aurisina, Doberdò del Lago, San Floriano del Collio, Savogna d'Isonzo, Monrupino, Sgonico, San Dorligo della Valle match ISTAT's Italian names (bilingual in LAU).
- Grape order is not a ranking: no planted shares by variety were found in two sources.
- Refosco, Picolit, Verduzzo and Schioppettino are not in the app and not profiled; Picolit appears only as an appellation.

## Held back
- Friuli Colli Orientali polygon (no comune list).
- Red ratings (no typical red; native reds differ widely).
- Refosco, Verduzzo, Picolit, Schioppettino grape profiles.
