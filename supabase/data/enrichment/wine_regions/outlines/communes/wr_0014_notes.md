# BOB Mergelland (PDO, NL)

## Sources
- RVO productdossier: https://www.rvo.nl/sites/default/files/2026-09/Productdossier-BOB-Mergelland.pdf (local: dl_nl/Productdossier-BOB-Mergelland.pdf)
  - **Date/version:** none stated in the text. PDF metadata: Word document created 2016-11-10, modified 2026-09-24 (RVO re-upload). Treat the content as the 2016 dossier.
- eAmbrosia: EUGI00000014415, PDO-NL-02114, registered, protection 2016-01-26. OJ C296 07.09.2017; OJ L41 14.02.2018 (Reg. 2018/215). No single document via the API; EUR-Lex was unreachable.

## Part 1: area
> "De voor de productie van Mergellandse wijn afgebakende zone bevindt zich in de wijnbouwzone A. Zij beslaat het gebied van de Limburgse gemeenten Maastricht, Meerssen, Nuth, Simpelveld, Voerendaal, Vaals, Gulpen-Wittem, Eijsden - Margraten en Valkenburg a/d Geul, voor zover de wijnbouwpercelen gelegen zijn op een bodem die bestaat uit een teellaag van löss."
> "… zijn gebieden met rivierklei als toplaag uitgesloten van het geografisch gebied."

The area is defined as whole municipalities (pre-2019 boundaries), restricted to vineyard parcels on a loess topsoil. River clay topsoil is excluded.

### Units used
- 8 LAU 2024 municipalities, each `partial=yes` because of the loess-parcel restriction:
  - NL_GM0935 Maastricht
  - NL_GM0938 Meerssen
  - NL_GM0965 Simpelveld
  - NL_GM0986 Voerendaal
  - NL_GM0981 Vaals
  - NL_GM1729 Gulpen-Wittem
  - NL_GM1903 Eijsden-Margraten
  - NL_GM0994 Valkenburg aan de Geul
- **Nuth no longer exists.** It merged into Beekdaelen (GM1954) on 2019-01-01 together with Onderbanken and Schinnen, so the LAU 2024 unit for Beekdaelen would overstate the area by about 2.4x. I used finer official units instead: CBS Wijk- en Buurtkaart 2024 wijken WK195401 "Wijk 01 Nuth", WK195402 "Wijk 02 Wijnandsrade", WK195403 "Wijk 03 Hulsberg" and WK195404 "Wijk 04 Schimmert" (land: 1,072 + 687 + 646 + 905 = 3,310 ha, CBS figures).
  - Geometry: dl_nl/mergelland_nuth_cbs_wijken_GM1954_01-04.geojson
  - Dataset: CBS Wijk- en Buurtkaart 2024, PDOK OGC API https://api.pdok.nl/cbs/wijken-en-buurten-2024/ogc/v1/collections/wijken, licence CC BY 4.0, CRS84.
  - **Judgement call:** I treat these 4 wijken as equal to the former gemeente Nuth (GM0928). This is not stated in any document I fetched. Supporting check: the union of the BAG woonplaatsen Nuth, Hulsberg, Schimmert and Wijnandsrade (official BAG, PDOK WFS) comes to about 3,287 ha, against about 3,286 ha for the 4 wijken (my planar area estimate). Two independent official datasets agree. An official pre-2019 gemeente polygon for Nuth would be definitive. The PDOK CBS gebiedsindelingen API only goes back to 2019, and I found no reachable 2018 wijk/buurt service.
- Total outline about 37,450 ha of land.
- **Overstatement:** cannot be quantified. The loess-parcel restriction cannot be mapped without a soil-map overlay, and the dossier states no total area.
- **Overlaps:** Vijlen (in Vaals) and De Voerendaalse Bergen (in Voerendaal) lie inside this outline.

## Part 2: content
- Grapes, as listed: "Auxerois, Chardonnay, Dornfelder, Gewürztraminer, Rivaner/Müller-Thurgau, Pinot Blanc, Pinot gris, Pinot noir en Pinot Noir Précoce, Riesling."
  - Spelling in the text: "Auxerois" in the list, "Auxerrois" elsewhere.
  - Blends of two or more are allowed, as are rosé wines and "blanc de noirs van Pinot Noir en Dornfelder".
- Wine types:
  - The dossier has no formal category list.
  - Bijlage 2 describes white, red, rosé (Dornfelder rosé, Pinot Noir rosé) and white Pinot Noir.
  - For most varieties it also covers "mousserende kwaliteitswijn" by the traditional method (méthode traditionnelle).
- Rules:
  - 100% of the grapes from the area; vinification within the area.
  - Minimum must weight 1070 g/l, about 9% vol natural.
  - Maximum yields:
    - 60 hl/ha for red Pinot Noir
    - 75 hl/ha for white or rosé Pinot Noir
    - 80 hl/ha for Pinot Blanc, Pinot Gris, Riesling, Gewürztraminer, Auxerrois and Chardonnay
    - 85 hl/ha for Rivaner/Müller-Thurgau and Dornfelder
    - Pinot Noir Précoce has no separate yield.
- Soil, climate and style (dossier's own words):
  - Loess topsoil (Pleistocene wind-blown silt) over Cretaceous limestone "mergel" (the Maastricht and Gulpen formations), with local Tertiary and Pleistocene deposits.
  - Hilly, 49–322 m NAP, about 180 km from the sea, a "cool climate".
  - "wijnen uit Mergelland worden gekenmerkt door een typische combinatie van fruitigheid, frisse elegantie en mineraliteit."
  - Historical claims: viticulture since 968 AD; modern revival since 1970.

## Held back
- The loess-only parcel subset (soil-map polygons). Not attempted.
- Bijlage 1 (p.6) is an image I did not render or check. It is probably a map.
- The official pre-2019 Nuth polygon (see judgement call above).
