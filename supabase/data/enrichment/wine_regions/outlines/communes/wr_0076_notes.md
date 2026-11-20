# Weinviertel: municipality mapping notes

Prepared 2026-11-20. Source of truth for the boundary: the official text below. Municipality IDs: GISCO LAU 2024 (AT_ + Gemeindekennziffer).

## Official text

„h) Weinviertel: die politischen Bezirke Gänserndorf, Korneuburg, ausgenommen die Gemeinde Stetteldorf am Wagram, Mistelbach, Hollabrunn und Horn;“ (Weingesetz 2009 § 21 Abs. 3 Z 1 lit. h)

Source URL(s): https://www.ris.bka.gv.at/Dokumente/Bundesnormen/NOR40254626/NOR40254626.html

Weingesetz 2009 (BGBl. I Nr. 111/2009), § 21 Abs. 3, consolidated version on RIS, last amended by BGBl. I Nr. 91/2023 (in force 21.07.2023; that amendment changed § 21 Abs. 1, 6 and 8 only, Abs. 3 is the original wording). Read 2026-11-20 from the RIS consolidated PDF of document NOR40254626 (raw copy in raw/WG_21_NOR40254626.txt).

Municipality codes: Statistik Austria Gemeindeliste nach Gemeindekennziffer, Gebietsstand 2026 (raw/gemliste_knz.csv), and politische Bezirke (raw/polbezirke.csv). The first three digits of the Gemeindekennziffer are the current politischer Bezirk. All Gemeinden used here have identical codes and names in GISCO LAU 2024; the only 2024 to 2026 change in Austria (Fürstenfeld/Söchau merger, 2025) is outside these regions.

## Counts

- Rows in weinviertel.csv: 142
- Partial: 0
- Provinces: Niederösterreich

## Judgement calls

- All Gemeinden of the current politische Bezirke Gänserndorf (308), Hollabrunn (310), Horn (311), Korneuburg (312) and Mistelbach (316), by Gemeindekennziffer prefix.
- Stetteldorf am Wagram excluded as the text says.
- Gerasdorf bei Wien (AT_31235), in Bezirk Korneuburg since 2017, is excluded here and placed in Wagram, where § 21 names it individually. See wagram_notes.md. This is a judgement call.
- The DAC-Verordnung „Weinviertel“ (BGBl. II Nr. 58/2010) does not redefine the area.

## Held back / left out

- None, beyond the Gerasdorf judgement.
- Style: Climate held back: the product specification describes a Pannonian climate with hot summers, cold winters and little rain, but the second source found (Falstaff, via search only) speaks of a moderate to cool climate. Not reconciled.
- Style: Only Grüner Veltliner listed; Welschriesling, Zweigelt and others are named only by Wikipedia.

## Style content

See style.json. Climate, soil and style claims there were kept only where two independent sources agree (the official product specification published by the ministry counts as one; the DAC-Verordnung and the specification are treated as one government source). Red structure scores are null for all regions: no two independent sources gave region-level body, acidity or tannin, including for Leithaberg Blaufränkisch and Neusiedlersee Zweigelt.
