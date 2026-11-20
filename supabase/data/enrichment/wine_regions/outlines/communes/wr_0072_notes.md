# Wachau: municipality mapping notes

Prepared 2026-11-20. Source of truth for the boundary: the official text below. Municipality IDs: GISCO LAU 2024 (AT_ + Gemeindekennziffer).

## Official text

„g) Wachau: die Gemeinden Aggsbach, Bergern im Dunkelsteinerwald, Dürnstein, Mautern an der Donau, Mühldorf, Rossatz-Arnsdorf, Spitz und Weißenkirchen in der Wachau;“ (Weingesetz 2009 § 21 Abs. 3 Z 1 lit. g)

Source URL(s): https://www.ris.bka.gv.at/Dokumente/Bundesnormen/NOR40254626/NOR40254626.html, https://www.ris.bka.gv.at/Dokumente/Bundesnormen/NOR40223096/NOR40223096.html

Weingesetz 2009 (BGBl. I Nr. 111/2009), § 21 Abs. 3, consolidated version on RIS, last amended by BGBl. I Nr. 91/2023 (in force 21.07.2023; that amendment changed § 21 Abs. 1, 6 and 8 only, Abs. 3 is the original wording). Read 2026-11-20 from the RIS consolidated PDF of document NOR40254626 (raw copy in raw/WG_21_NOR40254626.txt).

Municipality codes: Statistik Austria Gemeindeliste nach Gemeindekennziffer, Gebietsstand 2026 (raw/gemliste_knz.csv), and politische Bezirke (raw/polbezirke.csv). The first three digits of the Gemeindekennziffer are the current politischer Bezirk. All Gemeinden used here have identical codes and names in GISCO LAU 2024; the only 2024 to 2026 change in Austria (Fürstenfeld/Söchau merger, 2025) is outside these regions.

## Counts

- Rows in wachau.csv: 8
- Partial: 0
- Provinces: Niederösterreich

## Judgement calls

- All eight names matched exactly one Gemeinde in Niederösterreich, all in politischer Bezirk Krems (Land) (313). „Aggsbach“ is the Gemeinde Aggsbach (31301), not Schönbühel-Aggsbach (31542, Bezirk Melk), which the text does not name.
- The DAC-Verordnung „Wachau“ (BGBl. II Nr. 200/2020 as amended by BGBl. II Nr. 191/2023) § 3 Abs. 2 lists Ortsangaben by village or Katastralgemeinde (e.g. Loiben for Oberloiben and Unterloiben). These are label names inside the eight Gemeinden, not a different boundary, so no Gemeinde is partial.

## Held back / left out

- None.
- Style: Zweigelt listed third: the specification says it dominates the small red share; Wine Folly lists it among minor plantings.

## Style content

See style.json. Climate, soil and style claims there were kept only where two independent sources agree (the official product specification published by the ministry counts as one; the DAC-Verordnung and the specification are treated as one government source). Red structure scores are null for all regions: no two independent sources gave region-level body, acidity or tannin, including for Leithaberg Blaufränkisch and Neusiedlersee Zweigelt.
