# yamagata: GI Yamagata (wine), JP_PREF_06

## Official designation
- GI 山形 (Yamagata), wine, designated 30 June 2021 (令和3年6月30日); area 山形県, the whole prefecture. NTA Japanese list (`raw/nta_jp_ichiran.htm`, Shift_JIS) and English list (`raw/nta_geographical_02.htm`: "Yamagata Prefecture", Annex 02_3). Specification (interim translation) https://www.nta.go.jp/english/taxes/liquor_administration/02_3.htm (`raw/nta_02_3.htm`); control body: Geographical Indication of Wine "Yamagata" Use Management Committee, c/o Takahata Winery.

## Boundary
- MLIT National Land Numerical Information, Administrative Areas N03, 2026 edition (base date 1 January 2026), `raw/n03/N03-20260101_06_GML.zip`; licence on the dataset page: CC BY 4.0 (government standard terms, `raw/ksj_agreement_01.html`). Credit: 「国土数値情報（行政区域データ）」（国土交通省）を加工して作成. JGD2011 used as WGS84 (well under 1 m apart).
- Processing exactly as round 4 (`na_asia_tools/build_jp.py`): dissolve 721 municipal features (35 municipalities, no unassigned land features), drop parts and holes under 4 km², simplify 0.001° (~100 m), snap 1e-5°.
- Result: source 9,322.0 km² in 645 parts; kept 1 part; dropped 644 parts totalling 3.14 km², Tobishima island among them. Output 9,318.9 km² (prefecture publishes about 9,323 km²), 922 vertices, valid, Hausdorff 0.001°.

## Style evidence
- Grape order: NTA 酒類製造業及び酒類卸売業の概況 (令和7年調査分), table 47, grapes from Yamagata received by wineries FY2024 (2,362 t): Muscat Bailey A 630 t (26.7%), Delaware 488 t (20.7%), Chardonnay 262 t (11.1%), Merlot 166 t, Niagara 145 t, Koshu 96 t, Yama Sauvignon 86 t, Cabernet Sauvignon 71 t (round 4's copy, `round4/jp_cn/raw/nta_seizo_r07_06.pdf`, text in `round4/jp_cn_tools/nta_r07.txt`). Presence confirmed independently: Delaware and Chardonnay (Tohoku Tourism and Visit Yamagata: Takahata ships the most Chardonnay and Delaware for wine; Serai: Takahata first in Japan for Delaware); Muscat Bailey A (Serai: 80 year old vines at Takeda Winery). The ranking itself rests on the NTA survey alone.
- Day and night swing: NTA specification and Serai (Takeda Winery: 寒暖の差が激しい).
- Held back: Merlot (NTA only); red_acidity ("refreshing acidity") and red_tannin ("mild astringency"), NTA specification only; Niagara and Yama Sauvignon not in the app.
