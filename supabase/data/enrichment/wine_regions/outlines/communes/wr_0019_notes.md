# BOB Vijlen (PDO, NL)

## Sources
- RVO productdossier: https://www.rvo.nl/sites/default/files/2026-09/Productdossier-BOB-Vijlen.pdf (local: dl_nl/Productdossier-BOB-Vijlen.pdf)
  - **Date/version:** none in the text. PDF created 2026-09-24 (RVO upload).
- eAmbrosia: EUGI00000014220, PDO-NL-02168, registered, protection 2016-02-12. OJ C203 13.06.2018; OJ L282 12.11.2018. No single document via the API; EUR-Lex was unreachable.

## Part 1: area
> "Het oorsprongsgebied van de BOB Vijlen in zijn geheel gelegen in de Drielandengemeente Vaals, in de deelgemeente Vijlen. De exacte locatie van het oorsprongsgebied … is weergegeven in onderstaand figuur."
> "De Beschermde Oorsprongsbenaming Vijlen is alleen van toepassing op het grondgebied in Vijlen met een bodem van löss in de bovenste laag, met daarin veel stenen, zoals vuursteen, kiezel, kalksteen en vuursteen/kalksteenachtige stenen. In de laag daaronder … vuursteeneluvium …"
> "Het gebied voor de BOB Vijlen is 419 ha groot"

The area is defined by a map (Figure 1A, "De afbakening van het totale gebied Vijlen") inside the village of Vijlen, further restricted by soil.

### Units used
- **BAG woonplaats Vijlen**, identificatie 1431 (gemeente Vaals), `partial=yes`.
  - Geometry: dl_nl/vijlen_bag_woonplaats_1431.geojson
  - Dataset: Basisregistratie Adressen en Gebouwen (BAG), Kadaster, PDOK WFS https://service.pdok.nl/lv/bag/wfs/v2_0 (typeName bag:woonplaats), EPSG:4326 (lon/lat), licence CC0 (BAG open data). Retrieved 2026-11-20.
- **Why the woonplaats.** I drew it next to the dossier's Figure 1A (img_nl/vijlen_cmp.png vs img_nl/Productdossier-BOB-Vijlen_p3.png). The shapes match closely: north tip at the Gulpen–Vaals road, west edge towards Mechelen, south-west lobe to Epen. Figure 1A looks like a web-map rendering of the woonplaats boundary.
- **Conflict, flagged.** The woonplaats measures about 1,143 ha (my planar estimate), but the dossier says 419 ha. The CBS buurt BU09810000 "Vijlen" (Wijk- en Buurtkaart 2024) is officially 419 ha, an exact match to the dossier number, but its shape does not match Figure 1A: it is a compact pentagon and lacks the south-west lobe. Possible explanations:
  - (a) The 419 ha was taken from the CBS buurt while the map shows the woonplaats.
  - (b) 419 ha is the soil-qualifying part of the woonplaats.

  I cannot decide from the text. I used the woonplaats, which matches the map, the stronger evidence for an outline. The CBS buurt is kept as an alternative: dl_nl/vijlen_cbs_buurt_BU09810000.geojson (CBS Wijk- en Buurtkaart 2024, https://api.pdok.nl/cbs/wijken-en-buurten-2024/ogc/v1/collections/buurten, CC BY 4.0).
- **Overstatement:** the woonplaats (about 1,143 ha) is about 2.7x the stated 419 ha. The whole LAU Vaals (NL_GM0981, 2,389 ha of land) would be about 5.7x.
- Vijlen lies inside the Mergelland outline (Vaals). The dossier distinguishes the two by soil: Vijlen is "vuursteeneluvium", Mergelland is loess over mergel.

## Part 2: content
- Grapes (Tabel 1):
  - White: Pinot Gris, Chardonnay, Johanniter, Solaris, Souvignier Gris, Muscaris, Cabernet Blanc.
  - Red: Monarch, Cabernet Cortis, Pinot Noir, Baron, Pinotin.
- Categories: 1 Wijn, 4 Mousserende wijn, 5 Mousserende kwaliteitswijn.
- Types:
  - red: fruity/full; full-fruited with part barrique; dry full barrique (at least 9 months, 50% new oak)
  - white: dry fruity; dry barrique; medium-dry (halfdroog) fruity
  - rosé
  - sparkling white and rosé, méthode traditionnelle
- Max yields: red 50 hl/ha, white 55 hl/ha.
- Soil, climate and style (dossier):
  - Loess with many stones (flint, pebble, limestone) over flint eluvium; also "kleefaarde" (sticky clay).
  - Vineyards at 170–220 m NAP on south slopes and the plateau. Vijlen is described as about 200 m, "het hoogst gelegen dorp van Nederland".
  - Warmer nights than the valleys, little fog in Sept–Oct, rain shadow of the Eifel and Ardennes, föhn effect.
  - Style: "hogere suikergehalten, lagere zuurgehalte … waardoor de wijnen voller en expressiever van smaak zijn."
  - Wines are vinified in the village, 500 m from the area.
- Viticulture since 1988 (Wijndomein St. Martinus); Domein Holset since 2009.

## Held back
- Exact 419 ha soil-qualifying polygon. No official geodata for it.
- Which of the woonplaats or the CBS buurt the authors intended (see the conflict above).
