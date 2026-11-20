# Wagram: municipality mapping notes

Prepared 2026-11-20. Source of truth for the boundary: the official text below. Municipality IDs: GISCO LAU 2024 (AT_ + Gemeindekennziffer).

## Official text

„d) Wagram: der politische Bezirk Tulln, ausgenommen die Gemeinden Atzenbrugg, Sitzenberg-Reidling und Würmla, sowie die Gemeinden Klosterneuburg, Gerasdorf bei Wien und Stetteldorf am Wagram;“ (Weingesetz 2009 § 21 Abs. 3 Z 1 lit. d)

Source URL(s): https://www.ris.bka.gv.at/Dokumente/Bundesnormen/NOR40254626/NOR40254626.html, https://www.ris.bka.gv.at/Dokumente/Bundesnormen/NOR40241647/NOR40241647.html

Weingesetz 2009 (BGBl. I Nr. 111/2009), § 21 Abs. 3, consolidated version on RIS, last amended by BGBl. I Nr. 91/2023 (in force 21.07.2023; that amendment changed § 21 Abs. 1, 6 and 8 only, Abs. 3 is the original wording). Read 2026-11-20 from the RIS consolidated PDF of document NOR40254626 (raw copy in raw/WG_21_NOR40254626.txt).

Municipality codes: Statistik Austria Gemeindeliste nach Gemeindekennziffer, Gebietsstand 2026 (raw/gemliste_knz.csv), and politische Bezirke (raw/polbezirke.csv). The first three digits of the Gemeindekennziffer are the current politischer Bezirk. All Gemeinden used here have identical codes and names in GISCO LAU 2024; the only 2024 to 2026 change in Austria (Fürstenfeld/Söchau merger, 2025) is outside these regions.

## Counts

- Rows in wagram.csv: 21
- Partial: 0
- Provinces: Niederösterreich

## Judgement calls

- Politischer Bezirk Tulln read as it stands today (Bezirk code 321, 22 Gemeinden), minus the three named exceptions: 19 Gemeinden.
- Klosterneuburg was in Bezirk Wien-Umgebung when the Act was written; since that Bezirk was dissolved on 1 January 2017 it belongs to Bezirk Tulln (code 32144). It is named in the text anyway, so there is no conflict.
- Gerasdorf bei Wien (AT_31235) is named for Wagram, but since 2017 it lies in politischer Bezirk Korneuburg, which § 21 Abs. 3 lit. h assigns to the Weinviertel (except Stetteldorf am Wagram). Read literally, the Act now puts Gerasdorf in both areas. Judgement: Gerasdorf is placed in Wagram only, because it is named individually, which is more specific than the Bezirk reference, and the wording dates from 2009, when Gerasdorf was not in Bezirk Korneuburg. Conflicting signal: the newer DAC-Verordnung „Wagram“ (BGBl. II Nr. 30/2022) § 1 says Bezirk Tulln minus the three Gemeinden plus Stetteldorf „bilden das Weinbaugebiet Wagram“ and does not mention Gerasdorf. Gerasdorf is excluded from weinviertel.csv. Flag for review; drop it from Wagram if you prefer the DAC wording.
- Stetteldorf am Wagram (AT_31228, Bezirk Korneuburg) is named and is explicitly excluded from the Weinviertel.

## Held back / left out

- None, beyond the Gerasdorf judgement above.
- Style: Roter Veltliner (and Frühroter Veltliner) left out of the grape list: the product specification calls Frühroter Veltliner typical while donau.com and Wikipedia name Roter Veltliner, two different grapes; no grape profile was built.

## Style content

See style.json. Climate, soil and style claims there were kept only where two independent sources agree (the official product specification published by the ministry counts as one; the DAC-Verordnung and the specification are treated as one government source). Red structure scores are null for all regions: no two independent sources gave region-level body, acidity or tannin, including for Leithaberg Blaufränkisch and Neusiedlersee Zweigelt.
