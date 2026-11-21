# sachsen: municipality mapping notes

Prepared 2026-11-21. Source of truth for the boundary: the official text below.

## Official text

Single document published with standard amendment PDO-DE-A1277-AM01, Official Journal C/2026/5718, 30.10.2026, section 9 (raw/eamb/oj_C_202605718.html.txt). Wording: „die Rebflächen folgender Gemeinden (Gemarkungen) und deren Ortsteilen“, entries are NAMES with postcodes (no Gemarkung numbers), several of them former Gemeinden, some repeated. Outside Sachsen: Gemeinde Schlieben and Rebflächen in Ortrand (Brandenburg), and Fluren 3, 4, 6 Gemarkung Jessen, 1 and 8 Kleindröben, 2 and 23 Schweinitz in Jessen (Elster) (Sachsen-Anhalt).

Source URL: http://data.europa.eu/eli/C/2026/5718/oj

Municipality IDs: GISCO LAU 2024 (DE_ + 8-digit AGS). Gemarkung lookups used the Länder's official ALKIS open data services (attributes only; no Gemarkung geometry was drawn). Drawn at Gemeinde level; a row is marked partial when the register shows the Gemeinde has Gemarkungen the text does not list.

## Counts

- Rows: 54
- Partial: 2
- Länder/provinces: Brandenburg, Sachsen, Sachsen-Anhalt

## Judgement calls

- Each name was matched to a current Gemeinde in LAU 2024; names that are not current Gemeinden were looked up as Gemarkungen in GeoSN's ALKIS vereinfacht WFS (https://geodienste.sachsen.de/aaa/public_alkis/vereinf/wfs, free with attribution 'GeoSN'; raw/sn/sn_gemarkungen.json, 5,339 Gemarkungen). Every postcode was checked against OpenPLZ (raw/sn/plz_*.json); a row is drawn only when name and postcode agree.
- Former Gemeinden resolved through the register, all into Gemeinden already listed: Heynitz, Leuben-Schleinitz (Gemarkungen Leuben and Schleinitz) -> Nossen; Zabeltitz -> Großenhain; Reinersdorf -> Ebersbach; Langebrück -> Dresden; Mohorn -> Wilsdruff; Wehlen -> Stadt Wehlen.
- Ostrau (04749): Gemarkung Ostrau 142942 lies in Jahnatal, and 04749 is Jahnatal's postcode; drawn as Jahnatal, partial.
- 'Hohenstein-Ernsthal' read as Hohenstein-Ernstthal (DE_14524120), the only Gemeinde of that stem, postcode 09337 agrees. Spelling resolution.
- Current Gemeinden listed by name are drawn whole and not marked partial (as for Baden); the wording '(Gemarkungen)' means only their vineyard land counts.
- Jessen (Elster): seven Fluren only, partial. Schlieben and Ortrand drawn whole as the text names the Gemeinde.

## Held back / left out

- Glashütte (01612): the name matches only Stadt Glashütte (DE_14628130, postcode 01768); 01612 is the postcode of Nünchritz and Glaubitz. Name and postcode disagree; not drawn.
- Glaubitz (01728): the Gemeinde Glaubitz (DE_14627040) has postcode 01612; 01728 is Bannewitz. Name and postcode disagree; not drawn.
- Ketzerbachtal (01623): not a current Gemeinde and not an ALKIS Gemarkung; 01623 is Lommatzsch, which is drawn anyway. No row added; its successor Gemeinde was not established from a register.
- Style: Bereiche (Meißen, Elstertal) left out: seen only in search excerpts, not read on two sources.
- Style: Goldriesling (grown only in Sachsen per DWI) and Traminer left out of the grape list: no grape profile with two sources.

## Style content

See style.json. A claim was kept only where two independent sources agree; the EU or ministry specification and the DAC-Verordnung count as one government source, and all DWI pages and statistics count as one. Red structure scores are null for all regions: no two sources gave region-level body, acidity or tannin.
