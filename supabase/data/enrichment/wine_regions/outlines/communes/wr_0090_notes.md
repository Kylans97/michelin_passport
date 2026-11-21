# Alto Adige / Südtirol (DOC Alto Adige)

## Official text
- Disciplinare DOC "Alto Adige" o "dell'Alto Adige" (Südtirol, Südtiroler), last amended DM 08.10.2024 (GU 244, 17.10.2024). Art. 3.1: grapes from the part of the province of Bolzano suited to quality wine, namely
  a) "il territorio viticolo dei comuni di" 37 comuni,
  b) "in parte il territorio dei comuni di" Barbiano, Bressanone, Castelrotto, Chiusa, Funes, Laion, Naz-Sciaves, Velturno, Villandro, Varna (delimited in 3.6, Valle Isarco),
  c) "in parte" Castelbello-Ciardes, Laces, Naturno, Parcines, Silandro (delimited in 3.7, Valle Venosta).

Method (all regions): comune names are taken verbatim from Art. 3 of the disciplinare in the MASAF archive (page https://www.masaf.gov.it/flex/cm/pages/ServeBLOB.php/L/IT/IDPagina/4625, archives downloaded 2026-11-20/21, text in `raw/txt/`). Each name is resolved within its named province only, with `it_tools/istat.py` (ISTAT current list, suppressed comuni and variations since 1991), then mapped to GISCO LAU 2024 by ISTAT code (`IT_` + 6 digits). Every name maps to exactly one unit. Build script: `../../it_tools/build_classics.py`; style assembly: `../../it_tools/style_classics.py`. LAU 2024 predates four 2024/25 ISTAT mergers (Sovizzo, Setteville, Santa Caterina d'Este, Uggiate con Ronago); LAU 2024 units are used as they stand.

## Counts
52 names, 52 rows, all Bolzano. 37 `partial = no`, 15 `partial = yes` with the text's wording.

## Judgement calls
- Group a says "territorio viticolo" (the vine land of the comune), not part of the comune: treated as whole, as in the Swiss files.
- Names resolved by the comune's own Italian stem, each the only one of that stem in Bolzano: Appiano, Caldaro, Cortaccia, Termeno (all "sulla strada del vino"), San Genesio (Atesino), Fie' (Fiè allo Sciliar). Montagna and Salorno are ISTAT's own former names. Cortina all'Adige and Magre' all'Adige: the same text calls them "Cortina s.s.d.v." and "Magrè" (Margreid), the only such comuni. Trodena = Trodena nel parco naturale (ISTAT rename).
- Group b and c comuni include large mountain areas (Bressanone, Castelrotto, Funes, Silandro). None is described as a small part, so all are kept as partial.
- The six sub zones are appellations only.

## Style sourcing
Red ratings null: Schiava and Lagrein differ too much to name one typical red. Grape order is by planted area, firm only for Pinot Gris first (Wine Folly, Tiroler Tageszeitung); places two to five are near level.

## Held back
- Pairing (no two sources).
- Red body, acidity, tannin (no typical red).
