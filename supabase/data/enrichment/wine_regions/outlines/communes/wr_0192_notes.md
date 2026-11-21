# saale-unstrut: municipality mapping notes

Prepared 2026-11-21. Source of truth for the boundary: the official text below.

## Official text

Single document published with standard amendment PDO-DE-A1275-AM02, Official Journal C/2024/5342, 2.9.2024, section 6 (raw/eamb/oj_C_202405342.html.txt). The text lists GEMARKUNGEN (not Gemeinden), grouped by Landkreis, plus 'Weimar Ortsteil Schöndorf, Weimar Ortsteil Tiefurt', the kreisfreie Städte Jena and Erfurt (whole), and the Gemarkungen Werder (Havel), Phöben, Plessow and Neu Töplitz of Stadt Werder (Havel), Brandenburg.

Source URL: http://data.europa.eu/eli/C/2024/5342/oj

Municipality IDs: GISCO LAU 2024 (DE_ + 8-digit AGS). Gemarkung lookups used the Länder's official ALKIS open data services (attributes only; no Gemarkung geometry was drawn). Drawn at Gemeinde level; a row is marked partial when the register shows the Gemeinde has Gemarkungen the text does not list.

## Counts

- Rows: 54
- Partial: 42
- Länder/provinces: Brandenburg, Sachsen-Anhalt, Thüringen

## Judgement calls

- Sachsen-Anhalt: each Gemarkung looked up by name and Landkreis in LVermGeo LSA's ALKIS OpenData WFS (https://www.geodatenportal.sachsen-anhalt.de/wss/service/ST_LVermGeo_ALKIS_WFS_OpenData/guest, dl-de/by-2-0, © GeoBasis-DE / LVermGeo ST). Results in raw/st/st_gemarkung_match.json.
- Thüringen: same method with TLBG's ALKIS WFS (https://www.geoproxy.geoportal-th.de/geoproxy/services/adv_alkis_wfs, CC BY 4.0, © GDI-Th). Results in raw/th/th_gemarkung_match.json.
- Brandenburg: LGB ALKIS vereinfacht OGC API, collection katasterbezirk (https://ogc-api.geobasis-bb.de/alkis-vereinfacht/v1, dl-de/by-2-0): Werder (Havel) has 12 Gemarkungen, 4 listed, so partial.
- 'Freyburg/Unstrut' is ALKIS Gemarkung 'Freyburg' (152395), the only one of that stem in the Burgenlandkreis. 'Wallhausen (Helme)' is ALKIS 'Wallhausen' (152072), the only one in Mansfeld-Südharz.
- 'Kromsdorf' does not exist as an ALKIS Gemarkung; Großkromsdorf (165350) and Kleinkromsdorf (165352) both lie in Ilmtal-Weinstraße, which is drawn anyway (Denstedt, Oßmannstedt).
- 'Dorndorf-Steudnitz' (a former Gemeinde) is not an ALKIS Gemarkung; Dorndorf (163023) and Steudnitz (163025) both lie in Dornburg-Camburg, drawn anyway.
- Partial = the WFS returned a Flurstück of the Gemeinde in a Gemarkung not on the list (raw/st_th_partial.json gives one example per Gemeinde). 42 of 54 rows are partial: most of these Einheitsgemeinden are much larger than their wine Gemarkungen (Weißenfels, Zeitz, Naumburg, Querfurt, Weimar).

## Held back / left out

- Graitschen (Saale-Holzland-Kreis): two Gemarkungen match, 'Graitschen auf der Höhe' (162017, Schkölen) and 'Graitschen bei Bürgel' (162019, Graitschen b. Bürgel). Neither drawn.
- Stedten: the text places it in the Saalekreis, but the only ALKIS Gemarkung Stedten in Sachsen-Anhalt (152129) lies in Seegebiet Mansfelder Land, Landkreis Mansfeld-Südharz. Not used; that Gemeinde is drawn anyway through Lüttchendorf, Neehausen and Seeburg.
- Style: no Bereiche listed. The DWI page gives 2 Bereiche; a Wine Scholar Guild map lists Schloss Neuenburg, Thüringen, Mansfelder Seen and Werder (Havel). The sources disagree.
- Style: Bacchus (about 6.5% of the vineyard, DWI 2024) left out of the grape list: not in the app and no grape profile was built.

## Style content

See style.json. A claim was kept only where two independent sources agree; the EU or ministry specification and the DAC-Verordnung count as one government source, and all DWI pages and statistics count as one. Red structure scores are null for all regions: no two sources gave region-level body, acidity or tannin.
