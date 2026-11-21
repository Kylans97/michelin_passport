# Vinho Verde (DO, PDO-PT-A1545): source notes

**Boundary source:** single document published with the approved amendment PDO-PT-A1545-AM01, Official Journal C/2024/3412 (29.5.2024), section 6 "Demarcated geographical area": https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=OJ:C_202403412 (approved by Implementing Regulation (EU) 2024/2583). The wording is identical to section 4 of the 2013 eAmbrosia caderno de especificações (https://webgate.ec.europa.eu/eambrosia-api/api/v1/attachments/16924, quoting art. 2 of the Regulamento, Portaria 668/2010). The amendment did not change the area.

Text: all municipalities of the districts of Braga and Viana do Castelo; Aveiro district: Arouca, Castelo de Paiva, Vale de Cambra and the parish of Ossela (Oliveira de Azeméis); Porto district: Amarante, Baião, Felgueiras, Gondomar, Lousada, Maia, Marco de Canaveses, Matosinhos, Paços de Ferreira, Paredes, Penafiel, Póvoa de Varzim, Santo Tirso, Trofa, Valongo, Vila do Conde; Vila Real district: Mondim de Basto, Ribeira de Pena; Viseu district: Cinfães, and Resende except the parish of Barrô.

## Counts
- 45 whole municipalities (14 Braga, 10 Viana do Castelo, 3 Aveiro, 16 Porto, 2 Vila Real, Cinfães) plus Resende without Barrô, plus Ossela.
- 841 CSV rows = 841 distinct GISCO_IDs. Partials: none. Held back: none.
- District membership for "all municipalities of Braga and Viana do Castelo" taken from DICOFRE district codes 03 and 16; municipality codes and names from DGT's CAOP concelho layer (infogeo.dgterritorio.gov.pt, Hosted/Concelhos_CAOP_Continente), raw/conc_cont.json.
- Barrô (Resende, PT_181302) is a standalone LAU unit and is excluded. It belongs to Douro (wr_0008); no GISCO_ID overlaps with Douro.
- Ossela is a standalone LAU unit (PT_011310), not in a union.

## Style sources
Official: the 2024 single document (aromas, high acidity, granite, rainfall; Alvarinho labelling) and the 2013 spec §7 (sub-region descriptions, used for the appellation notes). Independent: Wines of Portugal region page, The Wine Society Portugal guide, Wine Folly Portugal by region.
- Grapes list is a subset in order: Alvarinho (app name Albariño), Loureiro. Arinto, Avesso, Azal, Trajadura and the reds are not in the app and were not added.
- Pairing "Fish": Wine Folly (fish, salads, vegetables) and The Wine Society (local fish and charcuterie) agree only on fish.
- Red ratings null: white-led region; the Wine Society calls red Vinho Verde astringent and low in alcohol, but only one source.
- Sub-regions: the nine names are in the spec §1 and the 2024 single document; their boundaries are in Portaria 668/2010 Annex, not read, and are not drawn.
