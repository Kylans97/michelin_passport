# Kamptal: municipality mapping notes

Prepared 2026-11-20. Source of truth for the boundary: the official text below. Municipality IDs: GISCO LAU 2024 (AT_ + Gemeindekennziffer).

## Official text

„c) Kamptal: die Gemeinden Grafenegg, Hadersdorf-Kammern, Langenlois, Lengenfeld, Schönberg am Kamp und Straß im Straßertale;“ (Weingesetz 2009 § 21 Abs. 3 Z 1 lit. c). DAC-Verordnung „Kamptal“ (BGBl. II Nr. 250/2024) § 2 Abs. 1: „Das Herkunftsgebiet für Kamptal DAC entspricht dem Weinbaugebiet Kamptal.“

Source URL(s): https://www.ris.bka.gv.at/Dokumente/Bundesnormen/NOR40254626/NOR40254626.html, https://www.ris.bka.gv.at/Dokumente/Bundesnormen/NOR40265238/NOR40265238.html, https://www.ris.bka.gv.at/Dokumente/Bundesnormen/NOR40265246/NOR40265246.html

Weingesetz 2009 (BGBl. I Nr. 111/2009), § 21 Abs. 3, consolidated version on RIS, last amended by BGBl. I Nr. 91/2023 (in force 21.07.2023; that amendment changed § 21 Abs. 1, 6 and 8 only, Abs. 3 is the original wording). Read 2026-11-20 from the RIS consolidated PDF of document NOR40254626 (raw copy in raw/WG_21_NOR40254626.txt).

Municipality codes: Statistik Austria Gemeindeliste nach Gemeindekennziffer, Gebietsstand 2026 (raw/gemliste_knz.csv), and politische Bezirke (raw/polbezirke.csv). The first three digits of the Gemeindekennziffer are the current politischer Bezirk. All Gemeinden used here have identical codes and names in GISCO LAU 2024; the only 2024 to 2026 change in Austria (Fürstenfeld/Söchau merger, 2025) is outside these regions.

## Counts

- Rows in kamptal.csv: 6
- Partial: 0
- Provinces: Niederösterreich

## Judgement calls

- All six names matched exactly one Gemeinde in Bezirk Krems (Land) (313).
- The Kamptal DAC annex defines 12 ortsübergreifende Weinbaugemeinden by Rieden and Katastralgemeinden (Ortswein labels); they lie inside the six Gemeinden and do not change the boundary.

## Held back / left out

- None.
- Style: Climate held back: only the product specification describes it (Pannonian warmth and cool Waldviertel air).

## Style content

See style.json. Climate, soil and style claims there were kept only where two independent sources agree (the official product specification published by the ministry counts as one; the DAC-Verordnung and the specification are treated as one government source). Red structure scores are null for all regions: no two independent sources gave region-level body, acidity or tannin, including for Leithaberg Blaufränkisch and Neusiedlersee Zweigelt.
