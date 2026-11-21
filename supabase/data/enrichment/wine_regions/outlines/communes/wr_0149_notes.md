# Hokkaido (Japanese wine GI) : JP_PREF_01

## Official designation
- GI 北海道 (Hokkaido), wine, designated by the NTA Commissioner on 28 June 2018 (平成30年6月28日). Production area: 北海道, the whole prefecture. Sources as for Yamanashi (NTA Japanese and English GI lists, `raw/nta_jp_ichiran.htm`, `raw/nta_geographical_02.htm`).
- Product specification: https://www.nta.go.jp/english/taxes/liquor_administration/02_07.htm (`raw/nta_02_07.htm`). Grapes only from Hokkaido, from listed varieties; produced, stored and filled in Hokkaido; acid may not be added to raise sensory acidity; confirmation by the GI "Hokkaido" Use Management Committee.

## Boundary dataset (shared by the three Japanese units)
- MLIT, National Land Numerical Information (国土数値情報), Administrative Areas (行政区域データ, identifier N03), 2026 edition, data base date 1 January 2026 (files `N03-20260101_01/19/20_GML.zip`, the per-prefecture downloads). Page: https://nlftp.mlit.go.jp/ksj/gml/datalist/KsjTmplt-N03-2026.html (saved as `raw/n03_page_2026.html`; the site lists the 2026 edition as the latest, updated April 2026).
- Licence stated on the dataset page: "オープンデータ（CC_BY_4.0）". Terms: 国土数値情報ダウンロードサイトコンテンツ利用規約（政府標準利用規約準拠版）, https://nlftp.mlit.go.jp/ksj/other/agreement_01.html (saved `raw/ksj_agreement_01.html`): free use including commercial; credit the source, and when edited state that it was processed and do not present the result as made by the State. Suggested credit: 「国土数値情報（行政区域データ）」（国土交通省）(https://nlftp.mlit.go.jp/ksj/gml/datalist/KsjTmplt-N03-2026.html) を加工して作成. The page also notes 測量法に基づく国土地理院長承認（複製）R 7JHf 351 and that some municipal boundaries are undetermined in the source.
- CRS: JGD2011 geographic (B, L). Used as WGS84 without transformation; the two frames differ by well under 1 m, far below the 100 m simplification.
- Processing (`jp_cn_tools/build_jp.py`, shapely, run with `-I`): union of all municipal polygons of the prefecture (GeoJSON in the zip), drop polygon parts and holes under 4 km2 (sinusoidal equal area), `simplify(0.001 deg, preserve_topology=True)` (about 100 m), coordinates snapped to 1e-5 deg, parts under 4 km2 created by simplification dropped again. Output validity checked.

## Unit
- One feature, JP_PREF_01. partial is left empty because the GI covers all of Hokkaido, but the drawn polygon deliberately leaves out territory N03 assigns to Hokkaido that Japan does not administer:
  - the six Northern Territories villages, N03 codes 01695 to 01700 (色丹村, 泊村, 留夜別村, 留別村, 紗那村, 蘂取村; 726 features);
  - the Habomai islands, which N03 assigns to Nemuro city (01223); removed as Nemuro features with centroid east of 145.84 E (712 features, 94.4 km2). Nosappu Point, the eastern tip of Nemuro, is at about 145.82 E and stays in.
  This is a judgement call, flagged for review: the GI text says only "Hokkaido"; these islands are administered by Russia. Reversing it means removing the exclusion in build_jp.py.
- 9556 source features, 7927 parts after union; 7920 parts under 4 km2 dropped (10.4 km2 in total). Area from source (after exclusions) 78274.7 km2, output 78288.2 km2. 7 parts (main island, Rishiri, Okushiri, Rebun, Oshima-Oshima, Teuri and Yagishiri), 6036 vertices, valid. Bounds [139.3344, 41.3978, 145.8175, 45.523].
- Hausdorff 0.0034 deg (about 300 m). Simplification split off two slivers under 0.01 km2 (near 139.845 E 42.45 N and 141.303 E 43.221 N, each about 150 m from the output edge), which were then dropped; they are the likely cause, not confirmed point by point.

## Style judgement calls
- Grape order: NTA survey table 47 (FY2024), Hokkaido grapes received: Niagara 693 t, Kerner 440, Zweigelt 350, Pinot Noir 287, Campbell Early 231, Müller-Thurgau 166, Chardonnay 154, Seibel 13053 118, Portland 104. Niagara, Campbell Early, Portland and Seibel 13053 (American or hybrid, not in the app) are left out, which is why the summary says "Among European grapes".
- Summary sources: cool, Winkler Region I: NTA spec and Reuters (via TimesLIVE, 14 Oct 2025, "Region I climate, the coolest of the five"); GuildSomm "markedly cooler". Harsh winters: NTA spec (severe cold, heavy snow) and GuildSomm. Kerner, Zweigelt, Pinot Noir: NTA table and GuildSomm. Yoichi Pinot Noir: Reuters and nippon.com (Sept 2025).

## Held back
- red_body, red_acidity, red_tannin: the NTA spec says reds taste "moderate or light" with "clear acidity and mild astringency"; no second independent source characterises Hokkaido reds as a whole.
- pairing: no source.
- White acidity ("rich acidity" in the NTA spec): one source only; not used in the summary.
