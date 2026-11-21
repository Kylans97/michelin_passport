# mittelrhein: municipality mapping notes

Prepared 2026-11-21. Source of truth for the boundary: the official text below.

## Official text

Single document published with standard amendment PDO-DE-A1269-AM03, Official Journal C/2026/738, 5.2.2026, section 9 (raw/eamb/oj_C_202600738.html.txt). Wording: „die Rebflächen der Gemeinden und deren Ortsteilen“ with Gemarkung numbers in Rheinland-Pfalz; in Nordrhein-Westfalen named Gemarkungen of Königswinter, Bad Honnef and Bonn. The text lists Gemeinden AND Gemarkungen (numbers).

Source URL: http://data.europa.eu/eli/C/2026/738/oj

Municipality IDs: GISCO LAU 2024 (DE_ + 8-digit AGS). Gemarkung lookups used the Länder's official ALKIS open data services (attributes only; no Gemarkung geometry was drawn). Drawn at Gemeinde level; a row is marked partial when the register shows the Gemeinde has Gemarkungen the text does not list.

## Counts

- Rows: 50
- Partial: 13
- Länder/provinces: Nordrhein-Westfalen, Rheinland-Pfalz

## Judgement calls

- Every Rheinland-Pfalz Gemarkung number was looked up as '07'+number in LVermGeo RLP's WFS ALKIS Vereinfacht (https://www.geoportal.rlp.de/registry/wfs/519, dl-de/by-2-0); all 61 numbers exist and every Gemarkung name matches the text (the one Kreis mismatch is held back below). Partial = the same WFS returned a Flurstück in another Gemarkung of that Gemeinde.
- NRW Gemarkungen checked in the NRW ALKIS vereinfacht WFS (https://www.wfs.nrw.de/geobasis/wfs_nw_alkis_vereinfacht, dl-de/zero-2-0): Oberdollendorf 054057, Niederdollendorf 054053, Königswinter 054038 (Königswinter), Honnef 054033 (Bad Honnef), Kessenich 054311 (Bonn); all three Gemeinden have further Gemarkungen, so all are partial. Bonn is drawn whole but only Kessenich counts.
- Urbar (1355, 1839): two numbers resolve to two different Gemeinden both named Urbar (Mayen-Koblenz, DE_07137224, and Rhein-Hunsrück-Kreis, DE_07140155). Name and number agree for both, so both are drawn.
- Langscheid (1843) is Gemarkung Langscheid of Oberwesel; Oberwesel is already drawn (partial).

## Held back / left out

- Breitscheid: the text says 'Breitscheid (Landkreis Mainz-Bingen) (0261)', but Gemarkung 0261 is Breitscheid in Landkreis Neuwied (DE_07138006). Breitscheid in Mainz-Bingen is Gemarkung 3501 (DE_07339007; it fits the run 3502 to 3508 of the Bacharach area). Kreis and number disagree; neither drawn.
- Langscheid (1207): Gemarkung 1207 is the Gemeinde Langscheid, Mayen-Koblenz (DE_07137061), an Eifel village away from the Rhine; the text lists it under one name together with Oberwesel's Gemarkung Langscheid (1843). Intent unclear; not drawn.

## Style content

See style.json. A claim was kept only where two independent sources agree; the EU or ministry specification and the DAC-Verordnung count as one government source, and all DWI pages and statistics count as one. Red structure scores are null for all regions: no two sources gave region-level body, acidity or tannin.
