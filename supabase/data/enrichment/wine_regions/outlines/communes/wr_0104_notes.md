# Bairrada (DO, PDO-PT-A1537): source notes

**Boundary source:** single document published with amendment PDO-PT-A1537-AM01, Official Journal C 224, 27.6.2023, §6: https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=uriserv%3AOJ.C_.2023.224.01.0043.01.ENG (approved by Implementing Regulation (EU) 2023/2146). It already uses the 2013 freguesia unions. It covers exactly the same old freguesias as §4 of the 2011 spec (https://webgate.ec.europa.eu/eambrosia-api/api/v1/attachments/1701); checked one by one.

## Counts
- Whole municipalities: Anadia, Mealhada, Oliveira do Bairro (20 units).
- Águeda 8, Aveiro 1, Cantanhede 13, Coimbra 3, Vagos 4 units.
- 49 rows = 49 distinct GISCO_IDs. Held back: none.

## Partial rows (text: "in the União das freguesias de ..., only the parish of ...")
The listed former parish is wholly in the region, but the LAU unit is the whole 2013 union, so the map overstates the region there:
- Óis da Ribeira (union with Travassô), PT_010125
- Belazaima do Chão (union with Castanheira do Vouga and Agadão), PT_010123
- Nariz (union with Requeixo and Nossa Senhora de Fátima), PT_010516
- Vil de Matos (union with Antuzede), PT_060332
- Covão do Lobo (union with Fonte de Angeão), PT_011812
- Santa Catarina (union with Ponte de Vagos), PT_011813
The share of each union that the listed parish represents was not measured (no pre-2013 polygons in hand). If the app should leave out units where only a small part is in the region, these six are the candidates to review.

Spelling: the text's "Sepins e Bolhoa" is the LAU "Sepins e Bolho" (PT_060223); the 2011 spec lists "Bolho".

## Style sources
Official: the 2023 single document (Atlantic influence, clay-limestone soils, marked acidity, "solid tannic structure", sparkling since 1890, Clássico rules). Independent: Wines of Portugal Bairrada page, The Wine Society Portugal guide, Wine Folly Portugal by region.
- red_acidity 5 (OJ, Wine Society "high in acidity", Wine Folly "high acidity"); red_tannin 4 (OJ, Wine Society "pretty tannic", Wine Folly "dense structure").
- red_body null: Wine Folly ranges from dense to delicate; no agreement.
- Grapes subset: Baga, Touriga Nacional. Fernão Pires (Maria Gomes), the leading white, and Alfrocheiro, Tinta Pinheira are not in the app and were not added.
- No official sub-regions.
