**Not drawn:** Maasvallei Limburg is a strip "tot op de middenterrassen" on both Maas banks, 155 km², fixed by roads and canals; its eleven municipalities are 5-7x that.

# BOB Maasvallei Limburg (PDO, cross-border BE + NL)

## Sources
- NL productdossier (current RVO link): https://www.rvo.nl/sites/default/files/2026-09/Productdossier-BOB-Maasvallei-Limburg.pdf
  - local: dl_nl/Productdossier-BOB-Maasvallei-Limburg.pdf. No date or version in the text; the PDF was created 2026-09-24 (RVO upload). Treat that as the upload date, not the version date.
- BE (Flemish) productdossier: https://lv.vlaanderen.be/media/9154/download
  - local: dl_nl/vl_9154.bin (a PDF, 29 pages); PDF created 2016-05-02. Found by web search. The NL dossier §3 points to lv.vlaanderen.be for the dossier. I did not confirm that this 2016 file is the current Flemish version (held back below).
- eAmbrosia: EUGI00000012784, file PDO-BE+NL-02172, registered, protection 2016-05-12. OJ C278 22.08.2017; OJ L342 21.12.2017 (Reg. 2017/2404). The API gives no single document (singleDocument: null). The OJ texts on EUR-Lex were not reachable (the bot wall returns HTTP 202 with an empty body).

## Part 1: area
NL dossier §4.4.1 (the list of Dutch municipalities is only in the page image, p.6):
> "De voor de productie van wijn uit de Maasvallei Limburg afgebakende zone bevindt zich in de wijnbouwzone A, gesitueerd tot op de geografische middenterrassen aan de beide oevers van de Maas in het historisch en geografisch verbonden Belgisch en Nederlands Limburg."
> "Gemeenten/steden langs Belgische zijde: Kinrooi, Maaseik, Dilsen-Stokkem, Maasmechelen Lanaken"
> "Langs Nederlandse zijde: Stein, Sittard-Geleen, Echt-Susteren, Maasgouw, Roermond, Maasgouw en Leudal"
> "Het afgebakende gebied heeft een oppervlakte van 155,09 km2"
The NL dossier also has a map (§4.4.3): a narrow red band along the Maas from Lanaken/Maasmechelen to Roermond/Horn.

The BE dossier, Bijlage 4, gives a precise, road- and canal-based delineation per municipality (quoted, abridged):
- Kinrooi: from the NL border, east of the Venlosesteenweg (N78)
- Maaseik: east of the Venlosesteenweg / Oude Ophoverbaan / Heirweg / Weertersteenweg … east of the Maastrichtersteenweg (N78b/N78)
- Dilsen-Stokkem: east of the Rijksweg N78
- Maasmechelen: east of N78 north of the N78/Zuid-Willemsvaart junction; east of the Zuid-Willemsvaart south of it
- Lanaken: east of the Zuid-Willemsvaart, north of the Geulerweg to Herbricht
- Stein: north of Voulwames to the bridge over the Julianakanaal, west of the Julianakanaal
- Sittard-Geleen and Echt-Susteren: west of the Julianakanaal
- Maasgouw: west of the Julianakanaal south of Haven Maasbracht; north of Maasbracht / Brachterbeek / Linne along named streets; west of N271
- Roermond: west of N271 / Maastrichterweg / Burg. Geuljanslaan / Bisschop Lindanussingel / Roersingel / Roerkade / Buitenop; south of the Hornerweg N280
- Maasgouw and Leudal: south of N280; south-east of the Napoleonsweg/N273 to the Belgian border

### Units used
All 11 municipalities as GISCO LAU 2024, each `partial=yes`. Only a strip of each municipality lies inside the zone.
- No official geometry exists for this delineation. A faithful polygon would have to be built from road and canal centrelines (for example NWB / Wegenregister plus the Maas border). That would be a derived construction, not an official boundary, so I did not build it.
- **Overstatement.** The Dutch six alone have 47,140 ha of land (CBS 2024: Stein 2,092; Sittard-Geleen 7,861; Echt-Susteren 10,302; Maasgouw 4,570; Roermond 6,064; Leudal 16,251). That is about 3x the official 15,509 ha for both sides together, before adding the five Belgian municipalities. I did not compute Belgian municipality areas, because no official area source was fetched for them. Expect the full LAU outline to overstate by roughly 5–7x. The shape will also be wrong: a wide blob instead of a river-bank strip.

## Part 2: content (NL dossier = EU single-document format)
- Category: **Wijn only** (§4.1; every other category is unticked). No sparkling.
- Grapes (§4.5): Acolon, Auxerrois, Chardonnay, Dornfelder, Gewürztraminer, Pinot Blanc, Pinot Gris, Pinot Noir, Riesling, Siegerrebe (spelled "Siegerebe" in §4.2.2/§4.3.2). The BE dossier §6 has the same list.
- Colours: white (Auxerrois, Chardonnay, Gewürztraminer, Pinot Blanc, Pinot Gris, Riesling, Siegerebe), red (Acolon, Dornfelder, Pinot Noir). For Pinot Noir: "Kleur: wit, rosé en van robijnrood tot granaatrood". Mainly single-variety wines; "Een assemblage is eerder een uitzonderling, maar mogelijk."
- Analytics: minimum natural alcohol 9.5% vol; total acidity at least 4.5 g/l (as tartaric acid); enrichment up to 2.5% vol.
- Maximum yields: 75 hl/ha (Acolon, Auxerrois, Chardonnay, Gewürztraminer, Pinot Blanc, Pinot Gris, Riesling, Siegerebe); Pinot Noir 60 hl/ha; Dornfelder 90 hl/ha.
- Soil and climate, in the dossier's own words (§4.6):
  - Alluvial plain of the gravel Maas, with 5–15 m of gravel from the Jura and Ardennes, under a thick loam layer.
  - Maas gravel is "kalksteen, kwarts en silex", which gives "mineralige smaken en ragfijne zuren".
  - The Kempisch Plateau shelters the valley: drier and warmer.
  - The gravel lakes (Maasplassen) buffer temperature, limiting spring frost and warming the autumn.
  - Style notes repeatedly cite the "kiezel" (pebble) subsoil for minerality.

## Judgement calls
- Dutch "Maasgouw" appears twice in the NL list. Both mentions refer to the same LAU. The BE text clarifies that the second one goes with Leudal (south of N280 / south-east of N273).
- "Lanaken" carries no comma in the NL list ("Maasmechelen Lanaken"). The BE text lists them separately, so I took them as two municipalities.

## Held back
- Exact strip geometry (road- and canal-based). There is no official dataset for it.
- The currency of the Flemish 2016 text. I could not confirm whether a newer Flemish version exists.
- Belgian municipality areas, so the exact overstatement ratio.
- The EU single document published in OJ C278/2017, because EUR-Lex was unreachable.
