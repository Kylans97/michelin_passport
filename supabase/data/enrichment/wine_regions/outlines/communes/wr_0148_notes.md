# Yamanashi (Japanese wine GI) : JP_PREF_19

## Official designation
- GI 山梨 (Yamanashi), wine, designated by the Commissioner of the National Tax Agency on 16 July 2013 (平成25年7月16日). Production area (産地の範囲): 山梨県, the whole prefecture. Sources: NTA Japanese list https://www.nta.go.jp/taxes/sake/hyoji/chiri/ichiran.htm (`raw/nta_jp_ichiran.htm`, Shift_JIS) and English list https://www.nta.go.jp/english/taxes/liquor_administration/geographical/02.htm (`raw/nta_geographical_02.htm`, "Yamanashi Prefecture").
- Product specification (interim English translation): https://www.nta.go.jp/english/taxes/liquor_administration/02_01.htm (`raw/nta_02_01.htm`). Grapes solely harvested in Yamanashi from a listed set of varieties; minimum must sugar by variety; produced, stored and bottled in the prefecture; confirmation by the Management Commission for the GI "Yamanashi". label_note is a paraphrase of section II and III.
- The Japanese designation notice text itself (告示) was not read; the area is taken from the NTA's own list of designated GIs, which gives the area per GI.

## Boundary dataset (shared by the three Japanese units)
- MLIT, National Land Numerical Information (国土数値情報), Administrative Areas (行政区域データ, identifier N03), 2026 edition, data base date 1 January 2026 (files `N03-20260101_01/19/20_GML.zip`, the per-prefecture downloads). Page: https://nlftp.mlit.go.jp/ksj/gml/datalist/KsjTmplt-N03-2026.html (saved as `raw/n03_page_2026.html`; the site lists the 2026 edition as the latest, updated April 2026).
- Licence stated on the dataset page: "オープンデータ（CC_BY_4.0）". Terms: 国土数値情報ダウンロードサイトコンテンツ利用規約（政府標準利用規約準拠版）, https://nlftp.mlit.go.jp/ksj/other/agreement_01.html (saved `raw/ksj_agreement_01.html`): free use including commercial; credit the source, and when edited state that it was processed and do not present the result as made by the State. Suggested credit: 「国土数値情報（行政区域データ）」（国土交通省）(https://nlftp.mlit.go.jp/ksj/gml/datalist/KsjTmplt-N03-2026.html) を加工して作成. The page also notes 測量法に基づく国土地理院長承認（複製）R 7JHf 351 and that some municipal boundaries are undetermined in the source.
- CRS: JGD2011 geographic (B, L). Used as WGS84 without transformation; the two frames differ by well under 1 m, far below the 100 m simplification.
- Processing (`jp_cn_tools/build_jp.py`, shapely, run with `-I`): union of all municipal polygons of the prefecture (GeoJSON in the zip), drop polygon parts and holes under 4 km2 (sinusoidal equal area), `simplify(0.001 deg, preserve_topology=True)` (about 100 m), coordinates snapped to 1e-5 deg, parts under 4 km2 created by simplification dropped again. Output validity checked.

## Unit
- One feature, JP_PREF_19, whole prefecture (not partial). N03 has 36 municipal features, all one part after union. Area from source 4470.3 km2, after simplification 4470.2 km2 (the prefecture publishes about 4465 km2). 1 part, 475 vertices, valid. Bounds [138.1801, 35.1684, 139.1344, 35.9714]. Hausdorff source to output 0.0010 deg (about 100 m).
- The Yamanashi and Shizuoka boundary near the summit of Mount Fuji is undetermined; the polygon follows N03 as published.

## Style judgement calls
- Grape order: NTA, 酒類製造業及び酒類卸売業の概況 (令和7年調査分, covering FY2024), chapter 3 ワイン製造業, table 47, grapes received by wineries from Yamanashi: Koshu 3,377 t (59.8%), Muscat Bailey A 1,105 t (19.6%), Delaware 321 t, Chardonnay 92 t, Merlot 89 t, Adirondack 79 t, Kyoho 72 t, Cabernet Sauvignon 70 t. https://www.nta.go.jp/taxes/sake/shiori-gaikyo/seizo_oroshiuri/r07/pdf/06.pdf (`raw/nta_seizo_r07_06.pdf`, AES encrypted, read with PDFKit). Decanter (Sylvia Wu, 8 March 2026, citing MAFF) and GuildSomm (Yasha Lysenko, 21 August 2026) give Koshu 67% and Muscat Bailey A 28%.
- Delaware, Adirondack and Kyoho (American or table grapes, not in the app) are left out of the grape list although Delaware outweighs Chardonnay by tonnage.
- red_tannin 2: Muscat Bailey A is the main red. "mild astringency from tannin" (NTA spec), "mild astringency from the tannins" (Highlighting Japan, Cabinet Office, Sept 2020), "fine-boned tannins" (Decanter), "soft tannins" (GuildSomm).
- Independence: NTA (tax agency) and Highlighting Japan (Cabinet Office) are different publishers; Decanter and GuildSomm are independent of both. Daily Maverick republishes Elin McCoy for Bloomberg (2019).
- Quotes were read from saved HTML text, not through a summariser.

## Held back
- red_body: only GuildSomm calls Muscat Bailey A light; the NTA spec says Vinifera reds have a "heavy body". Conflict, null.
- red_acidity: no source characterises it for the main red.
- Koshu acidity in the summary: sources split between "gentle" (Decanter) and "crisp"/"clear" (NTA, Highlighting Japan); the summary says "delicate" instead.
- A Katsunuma GI is being discussed (Decanter); not official, so no appellations.
