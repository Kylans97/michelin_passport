# Nagano (Japanese wine GI) : JP_PREF_20

## Official designation
- GI 長野 (Nagano), wine, designated by the NTA Commissioner on 30 June 2021 (令和3年6月30日). Production area: 長野県, the whole prefecture. Sources: NTA Japanese and English GI lists as above.
- Product specification: https://www.nta.go.jp/english/taxes/liquor_administration/02_16.htm (`raw/nta_02_16.htm`). Grapes only from Nagano, in variety groups; produced, stored and bottled in Nagano; a stricter subdivision "Nagano Wine Premium"; confirmation by the control body.

## Boundary dataset (shared by the three Japanese units)
- MLIT, National Land Numerical Information (国土数値情報), Administrative Areas (行政区域データ, identifier N03), 2026 edition, data base date 1 January 2026 (files `N03-20260101_01/19/20_GML.zip`, the per-prefecture downloads). Page: https://nlftp.mlit.go.jp/ksj/gml/datalist/KsjTmplt-N03-2026.html (saved as `raw/n03_page_2026.html`; the site lists the 2026 edition as the latest, updated April 2026).
- Licence stated on the dataset page: "オープンデータ（CC_BY_4.0）". Terms: 国土数値情報ダウンロードサイトコンテンツ利用規約（政府標準利用規約準拠版）, https://nlftp.mlit.go.jp/ksj/other/agreement_01.html (saved `raw/ksj_agreement_01.html`): free use including commercial; credit the source, and when edited state that it was processed and do not present the result as made by the State. Suggested credit: 「国土数値情報（行政区域データ）」（国土交通省）(https://nlftp.mlit.go.jp/ksj/gml/datalist/KsjTmplt-N03-2026.html) を加工して作成. The page also notes 測量法に基づく国土地理院長承認（複製）R 7JHf 351 and that some municipal boundaries are undetermined in the source.
- CRS: JGD2011 geographic (B, L). Used as WGS84 without transformation; the two frames differ by well under 1 m, far below the 100 m simplification.
- Processing (`jp_cn_tools/build_jp.py`, shapely, run with `-I`): union of all municipal polygons of the prefecture (GeoJSON in the zip), drop polygon parts and holes under 4 km2 (sinusoidal equal area), `simplify(0.001 deg, preserve_topology=True)` (about 100 m), coordinates snapped to 1e-5 deg, parts under 4 km2 created by simplification dropped again. Output validity checked.

## Unit
- One feature, JP_PREF_20, whole prefecture (not partial). 79 municipal features, one part. Area from source 13552.2 km2, output 13552.5 km2 (the prefecture publishes about 13562 km2). 1 part, 1234 vertices, valid. Bounds [137.3246, 35.1989, 138.7392, 37.0303]. Hausdorff 0.0010 deg.

## Style judgement calls
- Grape order: NTA survey table 47 (FY2024), Nagano grapes received: Concord 917 t, Merlot 684, Niagara 542, Chardonnay 447, Black Queen 391, Muscat Bailey A 214, Ryugan 164, Kyoho 135; table 45/46 add Cabernet Sauvignon 89 t and Sauvignon Blanc 87 t from Nagano. Concord, Niagara and Kyoho (American or table grapes) are left out; Black Queen and Ryugan are not in the app and were not researched as new grapes.
- Summary: altitude (NTA spec "many ... over 500 m", GuildSomm "roughly 80% ... above 500 meters"), cool nights and acidity (NTA spec, GuildSomm), dry by Japanese standards (NTA spec "about 1,000 mm, one of the lowest in Japan", GuildSomm), Merlot and Chardonnay (NTA table, GuildSomm).

## Held back
- red_body, red_acidity, red_tannin: the NTA spec describes reds as deep, "well-structured tannin and moderate acidity"; no second independent source for Nagano reds overall.
- pairing: NTA spec lists local dishes (sanzoku-yaki, soba, game, horse meat); single source.
- Shinshu Wine Valley and the five valleys: prefectural promotion areas, not official wine appellations; not listed.
