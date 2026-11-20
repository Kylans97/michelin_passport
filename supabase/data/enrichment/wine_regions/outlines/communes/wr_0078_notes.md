# Neusiedlersee: municipality mapping notes

Prepared 2026-11-20. Source of truth for the boundary: the official text below. Municipality IDs: GISCO LAU 2024 (AT_ + Gemeindekennziffer).

## Official text

„§ 1. Der politische Bezirk Neusiedl am See, mit Ausnahme der Gemeinden Winden und Jois, bildet das Weinbaugebiet Neusiedlersee.“ (DAC-Verordnung „Neusiedlersee“, BGBl. II Nr. 431/2020, § 1)

Source URL(s): https://www.ris.bka.gv.at/Dokumente/Bundesnormen/NOR40226845/NOR40226845.html

As for Leithaberg: a Burgenland DAC Herkunftsgebiet defined in its own DAC-Verordnung. Read 2026-11-20 from the RIS consolidated PDF of NOR40226845 (raw/nor/NOR40226845.txt).

Municipality codes: Statistik Austria Gemeindeliste nach Gemeindekennziffer, Gebietsstand 2026 (raw/gemliste_knz.csv), and politische Bezirke (raw/polbezirke.csv). The first three digits of the Gemeindekennziffer are the current politischer Bezirk. All Gemeinden used here have identical codes and names in GISCO LAU 2024; the only 2024 to 2026 change in Austria (Fürstenfeld/Söchau merger, 2025) is outside these regions.

## Counts

- Rows in neusiedlersee.csv: 25
- Partial: 0
- Provinces: Burgenland

## Judgement calls

- All Gemeinden of Bezirk Neusiedl am See (107) by code prefix, minus Jois (AT_10710) and Winden am See (AT_10723, „Winden“ in the text).
- Neusiedl am See is included whole. Four of its Rieden also belong to Leithaberg; the two DAC areas overlap there by law, and the Gemeinde is left out of Leithaberg (small part).
- „Seewinkel“ (Apetlon, Illmitz, Podersdorf am See) is a narrower origin name for the sweet categories, not a separate area.

## Held back / left out

- None.
- Style: Red structure null: the specification says fruity and spicy (Reserve: kräftig) but gives no comparable second source.
- Style: Welschriesling listed second on the strength of its sweet-wine role (Wikipedia, Rose Murray Brown), not vineyard area.

## Style content

See style.json. Climate, soil and style claims there were kept only where two independent sources agree (the official product specification published by the ministry counts as one; the DAC-Verordnung and the specification are treated as one government source). Red structure scores are null for all regions: no two independent sources gave region-level body, acidity or tannin, including for Leithaberg Blaufränkisch and Neusiedlersee Zweigelt.
