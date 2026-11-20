# BOB Oolde (PDO, NL)

## Sources
- RVO productdossier: https://www.rvo.nl/sites/default/files/2026-09/Productdossier-BOB-Oolde.pdf (local: dl_nl/Productdossier-BOB-Oolde.pdf)
  - **Version:** "Productdossier BOB Oolde december 2016". PDF created 2026-09-24 (RVO upload).
- eAmbrosia: EUGI00000014935, PDO-NL-02230, registered, protection 2016-08-18. OJ C199 11.06.2018; OJ L282 12.11.2018. No single document via the API; EUR-Lex was unreachable.

## Part 1: area
> "Het te beschermen geografisch gebied is gelegen in het gebied Oolde, welk gebied onderdeel is geworden van de gemeente Lochem. Oolde is een buurtschap van de gemeente Lochem in de provincie Gelderland."
> "Het gebied Oolde beslaat in totaal 658 hectare (bron: Kadastrale Atlas Gelderland 1832 …)."
> "Aan de noord- en zuidgrens wordt Oolde afgebakend door natuurlijke waterlopen (resp. Dortherbeek en Molenbeek). De westkant van het gebied wordt afgebakend door de oorspronkelijke gemeentegrens van Gorssel. De oostgrens loopt parallel aan de Lindenbergsdijk, Stoomdijk en Broekdijk."
- Figure 1: a historical map "Laren Oolde – huisnummering" (Regionaal Archief Zutphen), with the Oolde part outlined in blue.
- Soil (§2.1.2.1): "Voor BOB Oolde zijn van toepassing Beekeerdgronden, aangeduid met de code ZG23 plus de aanduiding P" (pZg23).

### Units used
- **CBS buurt BU02620206 "Verspreide huizen Oolde"** (gemeente Lochem), `partial=yes`.
  - Geometry: dl_nl/oolde_cbs_buurt_BU02620206.geojson
  - Dataset: CBS Wijk- en Buurtkaart 2024 via PDOK OGC API https://api.pdok.nl/cbs/wijken-en-buurten-2024/ogc/v1/collections/buurten, licence CC BY 4.0, CRS84. Retrieved 2026-11-20.
- **Why:** it is the only official unit that carries the name Oolde. There is no BAG woonplaats Oolde: addresses fall under the woonplaats Laren, and the woonplaatsen in the bbox are Almen, Eefde, Epse, Harfsen, Joppe, Kring van Dorth, Laren, Lochem, Bathmen and Deventer. Its western edge borders the buurt "Verspreide huizen Harfsen", which belongs to the former gemeente Gorssel (CBS wijk 05). That is consistent with the dossier's "oorspronkelijke gemeentegrens van Gorssel".
- **Overstatement:** buurt land 1,189 ha (CBS) against the stated 658 ha, so about 1.8x. The buurt also runs further north (towards Kring van Dorth) and around the village of Laren, which the historical map places outside Oolde. The whole LAU Lochem (NL_GM0262, 21,305 ha of land) would be about 32x.
- **Not verified:** that the buurt fully contains the historical 658 ha. I could not check the south boundary (Molenbeek) or the east boundary (parallel to the Lindenbergsdijk) against it. The comparison was visual only: img_nl/lochem_buurten.png vs img_nl/Productdossier-BOB-Oolde_p4.png.

## Part 2: content
- Grapes (Tabel 1): white Cabernet Blanc, Solaris; red Regent, Pinotin, Cabertin.
- Categories: 1 Wijn, 3 Likeurwijn, 5 Mousserende kwaliteitswijn, 8 Parelwijn, 16 Wijn uit overrijpe druiven.
- Types:
  - red full fruity (Regent/Pinotin/Cabertin or a cuvée, barrique); white dry fruity (Cabernet Blanc); white dry full (Solaris); rosé full-fruited
  - liqueur wine red and white
  - sparkling white (Cabernet Blanc)
  - pearl wine rosé
  - late-harvest white from overripe grapes (Solaris, at least 110 °Oechsle)
- Max yields: 65 hl/ha for all varieties; Solaris 40 hl/ha for overripe grapes.
- Vinification is allowed in the area or in the neighbouring gemeente Hof van Twente.
- Soil, climate and style (dossier):
  - Beekeerdgronden: loamy fine sand (10–50% loam), 5–10% organic matter, often with a clay/zavel cover from the IJssel and streams.
  - Climate is compared with neighbouring Twente; slightly lower night temperatures.
  - Style: "kenmerkende frisheid en vruchtrijke smaak van de witte en rosé wijnen en zachte tannines bij de rode wijnen".
- One producer (Wijngoed Gelders Laren, 2 ha, planted 2006/2010).

## Held back
- The exact 658 ha historical Oolde polygon. There is no official vector for it; it could only be digitised from the 1832/huisnummering map.
- The pZg23 soil subset.
- Whether the current Kadaster cadastral sections of Laren match the 1832 Oolde section. Not investigated: the PDOK BRK API exposes parcels and boundaries but not named sections.
