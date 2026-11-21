# hessische-bergstrasse: municipality mapping notes

Prepared 2026-11-21. Source of truth for the boundary: the official text below.

## Official text

Product specification „Hessische Bergstraße“ (g.U., Land Hessen, file gU Hessische Bergstraße_111213.pdf, December 2011), eAmbrosia dossier PDO-DE-A1268, section 3 (raw/eamb/att_6412.txt). eAmbrosia lists no amendment, so this is the current EU text. Wording: „die Rebflächen der Städte und Gemeinden Alsbach-Hähnlein, Bensheim, Brensbach, Dietzenbach, Groß-Umstadt, Heppenheim, Roßdorf, Seeheim-Jugenheim sowie Zwingenberg des Bundeslandes Hessen“. The text lists GEMEINDEN only.

Source URL: https://webgate.ec.europa.eu/eambrosia-api/api/v1/attachments/6412

Municipality IDs: GISCO LAU 2024 (DE_ + 8-digit AGS). Gemarkung lookups used the Länder's official ALKIS open data services (attributes only; no Gemarkung geometry was drawn). Drawn at Gemeinde level; a row is marked partial when the register shows the Gemeinde has Gemarkungen the text does not list.

## Counts

- Rows: 9
- Partial: 0
- Länder/provinces: Hessen

## Judgement calls

- Nine names, each matched to exactly one Hessian LAU (Roßdorf and Zwingenberg also exist in other Länder; the Hessian ones were taken as the text says 'des Bundeslandes Hessen').
- Heppenheim -> 'Heppenheim (Bergstraße), Kreisstadt'; Dietzenbach -> 'Dietzenbach, Kreisstadt' (Kreis Offenbach); Brensbach lies in the Odenwaldkreis.

## Held back / left out

- None for the boundary.
- Style: the 'smallest German region' claim was dropped: DWI 2024 gives Mittelrhein 451 ha and Hessische Bergstraße 456 ha.

## Style content

See style.json. A claim was kept only where two independent sources agree; the EU or ministry specification and the DAC-Verordnung count as one government source, and all DWI pages and statistics count as one. Red structure scores are null for all regions: no two sources gave region-level body, acidity or tannin.
