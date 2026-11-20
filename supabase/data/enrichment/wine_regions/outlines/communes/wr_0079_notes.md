# Südsteiermark: municipality mapping notes

Prepared 2026-11-20. Source of truth for the boundary: the official text below. Municipality IDs: GISCO LAU 2024 (AT_ + Gemeindekennziffer).

## Official text

„a) Südsteiermark: sämtliche Gemeinden des politischen Bezirkes Leibnitz mit Ausnahme der Gemeinden links der Mur;“ (Weingesetz 2009 § 21 Abs. 3 Z 3 lit. a). DAC-Verordnung (BGBl. II Nr. 299/2018) § 1: „Das Weinbaugebiet Südsteiermark DAC entspricht dem politischen Bezirk Leibnitz ohne die Gemeindegebiete links der Mur.“

Source URL(s): https://www.ris.bka.gv.at/Dokumente/Bundesnormen/NOR40254626/NOR40254626.html, https://www.ris.bka.gv.at/Dokumente/Bundesnormen/NOR40209739/NOR40209739.html, https://www.ris.bka.gv.at/Dokumente/Bundesnormen/NOR40253632/NOR40253632.html

Weingesetz 2009 (BGBl. I Nr. 111/2009), § 21 Abs. 3, consolidated version on RIS, last amended by BGBl. I Nr. 91/2023 (in force 21.07.2023; that amendment changed § 21 Abs. 1, 6 and 8 only, Abs. 3 is the original wording). Read 2026-11-20 from the RIS consolidated PDF of document NOR40254626 (raw copy in raw/WG_21_NOR40254626.txt). The DAC-Verordnung text is NOR40209739 (raw/nor/NOR40209739.txt).

Municipality codes: Statistik Austria Gemeindeliste nach Gemeindekennziffer, Gebietsstand 2026 (raw/gemliste_knz.csv), and politische Bezirke (raw/polbezirke.csv). The first three digits of the Gemeindekennziffer are the current politischer Bezirk. All Gemeinden used here have identical codes and names in GISCO LAU 2024; the only 2024 to 2026 change in Austria (Fürstenfeld/Söchau merger, 2025) is outside these regions.

## Counts

- Rows in suedsteiermark.csv: 21
- Partial: 4 (Gralla, Lebring-Sankt Margarethen, Wildon, Straß in Steiermark)
- Provinces: Steiermark

## Judgement calls

- Neither text lists the Gemeinden; the boundary is the river Mur. „Links der Mur“ means the left bank in the direction of flow, i.e. the east and north side. No official list of Leibnitz Gemeinden by bank was found: the product specifications for Südsteiermark, Vulkanland Steiermark and Weststeiermark (bmluk.gv.at) repeat the river wording only.
- Method: each of the 29 Gemeinden of Bezirk Leibnitz (610) was split by the Mur centreline from OpenStreetMap (relation 59792, fetched via Nominatim, raw/mur_nominatim.json) and the share of area on each bank was computed on the GISCO LAU 2024 polygons (script alps_hr/at_tools/leibnitz_sides2.py; output raw/leibnitz_mur_sides.tsv). An earlier pass with the coarser Natural Earth 10m river line agreed on which Gemeinden lie wholly on one bank.
- Wholly right of the Mur (0% left): Arnfels, Großklein, Heimschuh, Hengsberg, Kitzeck im Sausal, Lang, Oberhaag, Sankt Andrä-Höch, Sankt Johann im Saggautal, Sankt Nikolai im Sausal, Tillmitsch, Gamlitz, Gleinstätten, Leibnitz, Leutschach an der Weinstraße. Ehrenhausen an der Weinstraße (0.2%, 0.04 km²) and Wagna (1%, 0.13 km²) treated as wholly right; the slivers are within the mismatch between the generalised LAU boundary and the river line.
- Partial (included, flagged): Wildon (41% left; Wikipedia: „liegt beiderseits der Mur“), Gralla (33% left), Straß in Steiermark (78% left, 22% right; the Südsteiermark DAC annex itself assigns „von der Gemeinde Straß in der Steiermark die Weinbauflächen rechts der Mur“ to the Ortswein Ehrenhausen, which confirms the Gemeinde straddles the river and has vineyards on the right bank). Lebring-Sankt Margarethen: 13% of the LAU polygon falls left of the centreline, but Wikipedia places Lebring „am rechten Murufer“; marked possibly partial, unconfirmed.
- Left out as wholly or almost wholly left of the Mur (these belong to Vulkanland Steiermark): Allerheiligen bei Wildon, Empersdorf, Heiligenkreuz am Waasen, Ragnitz, Sankt Georgen an der Stiefing, Schwarzautal, Sankt Veit in der Südsteiermark (all 100%) and Gabersdorf (98%). The Vulkanland Steiermark DAC annex names Schwarzautal and Katastralgemeinden of Sankt Veit in der Südsteiermark, consistent with this.
- Straß in Steiermark keeps only about a fifth of its area. It is included, not left out as a small part, because the official annex names its right-bank vineyards for an Ortswein.

## Held back / left out

- Gabersdorf (2% right bank, small part), left out.
- Exact Mur split of the partial Gemeinden is not represented: the whole Gemeinde polygon will be drawn.
- Style: Grape order is by share of vineyard area from Wein Steiermark (steiermark.wine: Sauvignon Blanc 21%, Welschriesling 16.5%, Weissburgunder 11.4%, Muskateller just under 10%, Morillon 8.6%); Wikipedia confirms the same grapes but gives no shares.
- Style: Welschriesling and Muscat Blanc à Petits Grains (Muskateller) appear in new_grapes.json with tastes, body and acidity held back (only one usable source each).

## Style content

See style.json. Climate, soil and style claims there were kept only where two independent sources agree (the official product specification published by the ministry counts as one; the DAC-Verordnung and the specification are treated as one government source). Red structure scores are null for all regions: no two independent sources gave region-level body, acidity or tannin, including for Leithaberg Blaufränkisch and Neusiedlersee Zweigelt.
