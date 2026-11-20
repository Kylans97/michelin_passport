# Leithaberg: municipality mapping notes

Prepared 2026-11-20. Source of truth for the boundary: the official text below. Municipality IDs: GISCO LAU 2024 (AT_ + Gemeindekennziffer).

## Official text

„§ 1. Der politische Bezirk Eisenstadt Umgebung, die Freistädte Eisenstadt und Rust, die politischen Gemeinden Jois und Winden sowie in der Gemeinde Neusiedl am See die Rieden Hausberg, Neuberg, Marthalwald und Landstraße Hutweide bilden das Weinbaugebiet Leithaberg.“ (DAC-Verordnung „Leithaberg“, BGBl. II Nr. 252/2009, § 1 as amended by BGBl. II Nr. 587/2020)

Source URL(s): https://www.ris.bka.gv.at/Dokumente/Bundesnormen/NOR40230104/NOR40230104.html

In Burgenland, § 21 Abs. 3 Weingesetz 2009 defines only the Weinbaugebiet Burgenland (the whole Land); smaller areas are Herkunftsgebiete for DAC wines under § 21 Abs. 3 Z 4 and § 34 Abs. 1. The Leithaberg area is therefore defined in the DAC-Verordnung itself. Read 2026-11-20 from the RIS consolidated PDF of NOR40230104 (raw/nor/NOR40230104.txt).

Municipality codes: Statistik Austria Gemeindeliste nach Gemeindekennziffer, Gebietsstand 2026 (raw/gemliste_knz.csv), and politische Bezirke (raw/polbezirke.csv). The first three digits of the Gemeindekennziffer are the current politischer Bezirk. All Gemeinden used here have identical codes and names in GISCO LAU 2024; the only 2024 to 2026 change in Austria (Fürstenfeld/Söchau merger, 2025) is outside these regions.

## Counts

- Rows in leithaberg.csv: 27
- Partial: 0
- Provinces: Burgenland

## Judgement calls

- Bezirk Eisenstadt-Umgebung (103): all 23 Gemeinden by code prefix. Freistadt Eisenstadt (AT_10101) and Freistadt Rust (AT_10201).
- Jois: exact name match, AT_10710 (Bezirk Neusiedl am See).
- „Winden“: the Gemeinde is officially Winden am See (AT_10723); it is the only Gemeinde in Burgenland whose name begins with Winden. Matched with that note.
- Neusiedl am See (AT_10713): only four Rieden (Hausberg, Neuberg, Marthalwald, Landstraße Hutweide) belong to Leithaberg. Small part of the Gemeinde, so it is LEFT OUT of leithaberg.csv. The whole Gemeinde is in neusiedlersee.csv.

## Held back / left out

- Neusiedl am See (AT_10713), partial by four Rieden only; left out as a small part.
- Style: Neuburger (a permitted white grape) left out of the grape list: no grape profile with two sources was built.
- Style: Grape order follows the DAC-Verordnung listing (red first, then whites in the order the text names them), not vineyard area; no area figures by variety were found.
- Style: Red structure (body, acidity, tannin) null: only grape-level, not Leithaberg-level, sources.

## Style content

See style.json. Climate, soil and style claims there were kept only where two independent sources agree (the official product specification published by the ministry counts as one; the DAC-Verordnung and the specification are treated as one government source). Red structure scores are null for all regions: no two independent sources gave region-level body, acidity or tannin, including for Leithaberg Blaufränkisch and Neusiedlersee Zweigelt.
