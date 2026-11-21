# Dão (DO, PDO-PT-A1534): source notes

**Boundary sources:**
1. eAmbrosia caderno de especificações (2013), §4: https://webgate.ec.europa.eu/eambrosia-api/api/v1/attachments/16844 ("conforme representada cartograficamente no anexo do Decreto-Lei n.º 376/93").
2. Decreto-Lei 376/93, art. 2 (same list, plus sub-regions): https://faolex.fao.org/docs/pdf/por26220.pdf (FAOLEX copy).
3. Portaria 246/2014, de 25 de novembro, art. 3 and 4, read as reproduced at https://informador.pt/?p=79084 (diariodarepublica.pt not read: JavaScript only, and the search budget was used up). It restates the same area in 2013 freguesia units: Viseu, Repeses e São Salvador, Couto de Baixo e Couto de Cima, Fail e Vila Chã de Sá, Barreiros e Cepões, São Cipriano e Vil de Souto, Boa Aldeia, Farminhão e Torredeita, and 13 single parishes. This is a cross-check of the mapping below; it agrees exactly.

## Counts
- 15 whole municipalities (Arganil, Oliveira do Hospital, Tábua; Aguiar da Beira, Fornos de Algodres, Gouveia, Seia; Carregal do Sal, Mangualde, Mortágua, Nelas, Penalva do Castelo, Santa Comba Dão, Sátão, Tondela): 176 LAU units.
- Viseu municipality: 29 pre-2013 freguesias listed, mapped to 20 LAU units. Not listed and excluded: Bodiosa, Calde, Campo, Lordosa, Ribafeita.
- 205 rows, 196 distinct GISCO_IDs (a union listed through several old freguesias repeats). Partials: none (every union in Viseu is fully listed). Held back: none.

## 2013 unions (Lei 11-A/2013)
- Barreiros, Cepões -> Barreiros e Cepões; Boaldeia, Farminhão, Torredeita -> Boa Aldeia, Farminhão e Torredeita; Fail, Vila Chã de Sá -> one union; Repeses, São Salvador -> one union; São Cipriano, Vil de Soito -> São Cipriano e Vil de Souto.
- Coração de Jesus, Santa Maria de Viseu, São José -> "Viseu" (PT_182341); LAU name does not list components. Composition from pt.wikipedia "Viseu (freguesia)" and Portaria 246/2014 ("Viseu" union).
- Couto de Baixo, Couto de Cima -> "Coutos de Viseu" (PT_182337); composition from pt.wikipedia "Coutos de Viseu" (citing Lei 11-A/2013) and Portaria 246/2014.
- Spelling accepted: Côta -> Cota; Boaldeia -> Boa Aldeia; Vil de Soito -> Vil de Souto; the spec's typos "orgens", "Santso Evos" -> Orgens, Santos Evos (DL 376/93 spells them correctly).

## Style sources
Official: spec §2.2 (reds: soft tannins, good fixed acidity, good ageing) and DL 376/93 art. 4.3 (Nobre grape rules). Independent: Wines of Portugal (Dão and Lafões), Wine Folly Portugal by region, Wine Anorak Dão spotlight, Decanter regional profile.
- red_body 3: Wine Folly (lighter than Douro) and Decanter (lighter bodied, fresh varieties fit the classic profile). red_acidity 4: spec, Wine Folly, Wine Anorak, Decanter. red_tannin 3: spec ("taninos macios") and Wine Folly (moderate tannins).
- Grapes subset: Touriga Nacional, Jaen (Mencía), Tinta Roriz (Tempranillo), Encruzado. Order is a judgement between Wines of Portugal's listing (Touriga Nacional first) and Decanter's area figures (Jaen 3,417 ha ahead of Touriga Nacional 3,116 ha); Alfrocheiro is not in the app and was not added.
- label_note: the 36/12 month Nobre ageing is from the 2013 spec §8.7; the 15% Touriga Nacional / Encruzado rule is from DL 376/93 art. 4.3. Whether Portaria 246/2014 changed the Nobre rules was not checked.
- Sub-regions: from DL 376/93 art. 2.2, with Alva as restated by Portaria 246/2014 (adds Arganil; DL 376/93 had only Oliveira do Hospital and Tábua). Not drawn.
