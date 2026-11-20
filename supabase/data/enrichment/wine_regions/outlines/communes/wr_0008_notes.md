# wr_0008 Douro (Região Demarcada do Douro): source notes

**Source:** Ficheiro técnico, "Vinho, vinho espumante e vinho licoroso DO Douro", processo PDO-PT-A1539 (EU eAmbrosia dossier, applicant IVV; legal reference Decreto-Lei n.º 173/2009, de 3 de Agosto), section 5 "Área delimitada". It states that the DO Porto area is the same as the area demarcated for Douro wine.
URL: https://www.ivdp.pt/media/d2enomxc/pdo-pt-a1539-douro.pdf (hosted by IVDP). Retrieved 2026-11-20. The document was last saved on 23/12/2011.

**Not checked:** The text of DL 173/2009 itself and its 2020 republication (DL 97/2020) could not be read: diariodarepublica.pt is JavaScript-only and areareservada.ivdp.pt did not respond. The list here is the eAmbrosia technical file's wording, which uses the pre-2013 freguesias.

## Counts
- The document lists 4 whole concelhos (Mesão Frio, Peso da Régua, Santa Marta de Penaguião, Vila Nova de Foz Côa) and 126 named freguesias in 17 other concelhos.
- All 126 freguesias were matched (126/126), and all 4 concelhos were matched. Whole concelhos were expanded to their 34 current LAU freguesias, giving 160 CSV rows and 135 distinct GISCO_IDs.
- Held back: **none**.
- 19 rows are partial (see below).

## How the matching was done
Each freguesia was matched only within its concelho's DICOFRE prefix. A freguesia matched either on its exact name (ignoring accents) or as a named component of a 2013 union in LAU 2024. Where several old freguesias now share one union, each keeps its own row, so a GISCO_ID can repeat.

### Mapped to 2013 unions (Lei n.º 11-A/2013)
Ermida, Nogueira -> Nogueira e Ermida; São Dinis, São Pedro, N. Sra. da Conceição -> "Vila Real" (PT_171438, the union of the three city parishes; the LAU name does not list the components); Santo Adrião, Vila Seca -> Vila Seca e Santo Adrião; Santa Maria de Almacave, Sé -> Lamego (Almacave e Sé); Parada do Bispo, Valdigem -> Parada do Bispo e Valdigem; Amieiro, Carlão -> Carlão e Amieiro; Castedo, Cotas -> Castedo e Cotas; Casal de Loivos, Vale de Mendiz, Vilarinho de Cotas -> one union; Noura -> Noura e Palheiros; Gouvães do Douro, Provesende, São Cristóvão do Douro -> one union; Paradela de Guiães, São Martinho de Anta -> São Martinho de Antas e Paradela de Guiães; Espinhosa, Trevões -> Trevões e Espinhosa; São João da Pesqueira, Várzea de Trevões -> one union; Vilarouco -> Vilarouco e Pereiros; Barcos, Santa Leocádia -> Barcos e Santa Leocádia; Granjinha -> Paradela e Granjinha; Pereiro, Távora -> Távora e Pereiro; Beira Grande, Lavandeira -> Lavandeira, Beira Grande e Selores; Castanheiro do Norte, Ribalonga -> one union; Freixo de Espada à Cinta, Mazouco -> one union; Avantos, Romeu -> Avantos e Romeu; Adeganha -> Adeganha e Cardanha; Peredo dos Castelhanos, Urros -> one union; Assares, Lodões -> Assares e Lodões; Vilarinho das Azenhas, Vilas Boas -> one union; Vila Flor -> Vila Flor e Nabo; Meda, Fontelonga -> Mêda, Outeiro de Gatos e Fonte Longa.

### Spelling differences accepted (one candidate in the concelho)
- São Mamede de Riba Tua -> São Mamede de Ribatua
- São Martinho de Anta -> ...de Antas
- Horta -> Horta da Vilariça (Torre de Moncorvo)
- Santa Comba da Vilariça -> Santa Comba de Vilariça
- Vilarinho de Castanheira -> Vilarinho da Castanheira
- Fontelonga -> Fonte Longa
- Meda -> Mêda

## Partial rows (the `partial` column)
- **Part of the freguesia is in the region (the document's own wording):**
  - Nossa Senhora da Conceição "(parte)"
  - Várzea de Abrunhais (only the Quintas de Foutoura, do Prado e das Várzeas)
  - Frechas (only the D. Maria Angélica de Sousa Pinto Barroso and Sociedade Clemente Meneres properties)
  - Avantos, Carvalhais and Romeu (only the Sociedade Clemente Meneres properties)
  - Vilas Boas (only the Quintas da Peça e das Trigueiras and the propriedades de Vimieiro)
- **The whole freguesia is in the region, but its LAU union also covers ground outside the document:**
  - Noura (+Palheiros)
  - Vilarouco (+Pereiros)
  - Granjinha (+Paradela)
  - Beira Grande and Lavandeira (+Selores)
  - Adeganha (+Cardanha)
  - Vila Flor (+Nabo)
  - Meda and Fontelonga (+Outeiro de Gatos)
  - Vilarinho das Azenhas (+the rest of Vilas Boas)
  - São Dinis and São Pedro (+the rest of N. Sra. da Conceição)

  A map built from these polygons will overstate the region in those places.

## Held back
None.
