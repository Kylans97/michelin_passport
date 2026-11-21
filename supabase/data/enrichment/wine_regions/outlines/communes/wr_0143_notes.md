# Vale dos Vinhedos (Brazil): drawn, 1 unit (Embrapa official delimitation)

## Official basis
- Brazil's wine GIs are registered by INPI under Lei 9.279/1996 (IP = Indicação de Procedência, DO = Denominação de Origem). INPI's own lists, read 2026-11-21: "Denominações de Origem reconhecidas" (at 20 Oct 2026, raw/inpi_do_list.pdf) and "Indicações de Procedência reconhecidas" (at 27 Oct 2026, raw/inpi_ip_list.pdf). Full Brazilian wine GI list as registered:
  - DO: Vale dos Vinhedos (IG201008, 25/09/2012); Altos de Pinto Bandeira (BR412021000003-4, 29/11/2022, natural sparkling only); Vales da Uva Goethe (IG201009, IP 14/02/2012, changed to DO 10/06/2025).
  - IP: Vale dos Vinhedos (IG200002, 19/11/2002, 81.23 km²); Pinto Bandeira (IG200803, 13/07/2010); Altos Montes (BR402012000002-0, 11/12/2012); Monte Belo (BR402012000006-3, 01/10/2013); Farroupilha (BR402014000006-9, 14/07/2015, Moscatel products only); Campanha Gaúcha (BR402017000009-1, 05/05/2020, amended 27/05/2025); Vinhos de Altitude de Santa Catarina (BR402020000008-6, 29/06/2021, 29 whole municipalities per IBGE 2018); Bituruna (BR402021000001-1, 18/10/2022, whole municipality); Vale do São Francisco (BR402020000021-3, 01/11/2022, 5 whole municipalities per IBGE); Sul de Minas (BR402023000001-7, 11/02/2025, winter wines, land at or above 800 m in 10 municipalities).
  - Not wine: Vale do Submédio São Francisco (IG200701, table grapes and mango), Marialva (table grapes), Jundiahy (Niagara Rosada grapes).
  - "Serra Gaúcha" is NOT a registered GI; it is the traditional region containing six of the wine GIs.
- DO Vale dos Vinhedos delimitation (INPI DO list and ficha técnica, raw/inpi_ficha_ValedosVinhedosDO.pdf): 72.45 km², 29°08'–29°15' S, 51°30'–51°39' W; 61.07% Bento Gonçalves, 33.49% Garibaldi, 5.44% Monte Belo do Sul; limit is the watershed of the Arroio Vale dos Vinhedos and Arroio Leopoldina, with a 45% slope / 400 m rule in the north west. Not defined by municipalities, so the Embrapa polygon is used.

## Unit
- BR_do_IG201008: Embrapa Uva e Vinho, GeoInfo dataset 2121 "DO Vale dos Vinhedos - Limite" (geonode:do_vale_dos_vinhedos_limite4326; authors Jorge Tonietto, Ivanira Falcade, Rosemary Hoff; published 2020-10-24; EPSG:4326). WFS GetFeature, saved raw/emb_do_vale_dos_vinhedos_limite4326.geojson. One feature, attribute area_ha 7,244.82.
- Licence: the dataset's licence field is EMPTY. Embrapa has a general data licence (BRS DADOS 1.0, seen via search only) and gov.br content is CC BY-ND 3.0; neither is confirmed to apply. Needs human check before publishing.
- Checks: computed area 72.59 km² (sphere) vs 72.45 official; bounds 29.140–29.241 S, 51.497–51.633 W match the INPI extent. Simplified 100 m in a local equal-area projection: area change < 0.1%, symmetric difference 2.2% (small, intricate outline).
- The IP (81.23 km², 2002) is a different, larger area; it is not drawn. No GeoInfo layer for the IP limit was found.

## Style (sources)
- Summary: first Brazilian GI (INPI IP list, IG200002 2002; Embrapa cadastro "a primeira I.P. do Brasil"; SevenFifty "Brazil's first DO"); by Bento Gonçalves (INPI ficha, MAPA booklet 2021); Merlot leads reds and Chardonnay whites (Embrapa cadastro: Aprovale chose Merlot and Chardonnay as identity grapes; MAPA booklet: Merlot obligatory in reds, Chardonnay in whites; INPI ficha: Merlot predominant; SevenFifty: Merlot "especially expressive" here); sparkling made too (INPI ficha product types; MAPA).
- Altitude 500–700 m (MAPA only) left out.
- Grapes, order by area of authorised DO varieties in 2013 (Embrapa Cadastro Vitícola DO VV, capítulo I, Tabela 5): Merlot 138.33 ha, Cabernet Sauvignon 93.44, Chardonnay 63.20, Pinot Noir 30.01, Riesling Itálico 22.51, Tannat 21.42, Cabernet Franc 10.95. Riesling Itálico = app's Graševina (alias "Riesling Italico").
- Label note: INPI ficha (non-varietal reds: Merlot majority plus only Cabernet Franc, Cabernet Sauvignon, Tannat); MAPA booklet (Merlot obligatory, Chardonnay obligatory, Riesling Italico allowed). Embrapa cadastro gives 60% minimums (Merlot in red blends, Chardonnay in white blends, Chardonnay/Pinot Noir in sparkling); the 60% figure is in no official text read, so it is left out.
- CONFLICT, left out: Embrapa cadastro and MAPA booklet say DO sparkling wine is traditional method only; the INPI ficha's product definition says "método champenoise ou tradicional ou ... charmat". The official regulation (caderno de especificações, raw/inpi_caderno_ValedosVinhedosDO.pdf) has font-encoded text that could not be extracted reliably; not used.
- Red structure: only the INPI ficha (red fruit, "acidez bastante equilibrada"); white acidity medium/high (INPI ficha only). All null.
- Pairing: none found; null.
