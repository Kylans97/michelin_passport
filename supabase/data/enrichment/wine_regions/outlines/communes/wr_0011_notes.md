# wr_0011 Tuscany — comuni notes

Compiled 2026-11-20. Output: `wr_0011.csv` — **273 rows**, every comune in the GISCO LAU 2024 index with an ISTAT province code of 045–053 or 100. None are partial.

## Sources (downloaded 2026-11-20 from MASAF "Elenchi e disciplinari vini", https://www.masaf.gov.it/flex/cm/pages/ServeBLOB.php/L/IT/IDPagina/4625)
| Denomination | File in MASAF archive | Latest amendment in header |
|---|---|---|
| IGT **Toscano / Toscana** (defines the outline) | "Disciplinari IGT" (https://www.masaf.gov.it/flex/cm/pages/ServeAttachment.php/L/IT/D/1%252F0%252F8%252FD.80c31f0c0a116455addf/P/BLOB%3AID%3D4625/E/7z?mode=download) → `IGT Toscano o Toscana.pdf` | Provv. Min. 12.07.2019 (GUUE C 225, 05.07.2019) |
| DOCG Chianti Classico | "Disciplinari DOP dalla lettera A alla lettera D" (https://www.masaf.gov.it/flex/cm/pages/ServeAttachment.php/L/IT/D/1%252F2%252Ff%252FD.f3246fc0caf2ec5feb45/P/BLOB%3AID%3D4625/E/7z?mode=download) → `Chianti Classico.pdf` | DM 22.06.2023 (GU 152, 01.07.2023) |
| DOCG Brunello di Montalcino | same archive → `Brunello di Montalcino.pdf` | Provv. Min. 12.07.2019 |
| DOC Bolgheri | same archive → `Bolgheri.pdf` | DM 03.11.2021 (GU 286, 01.12.2021) |

## Area definition (confirmed from the text)
IGT Toscana Art. 3.1: *"comprende l'intero territorio amministrativo delle province di Arezzo, Firenze, Grosseto, Livorno, Lucca, Massa Carrara, Pisa, Pistoia, Prato, Siena, nella Regione Toscana."* These are all ten provinces of the Regione Toscana, so the area is the whole region.

## Counts
The document names 10 whole provinces. ISTAT 045 Massa-Carrara 17, 046 Lucca 33, 047 Pistoia 20, 048 Firenze 41, 049 Livorno 19, 050 Pisa 37, 051 Arezzo 36, 052 Siena 35, 053 Grosseto 28, 100 Prato 7 = **273**.
Cross-check: the ISTAT current list (Elenco-comuni-italiani.csv, region "Toscana") has 273 comuni, identical code set. All LAU names equal the ISTAT names.

## Named wines inside the outline (cited, not mapped separately)
- **Chianti Classico DOCG**: Art. 3 gives a boundary line. The section on the link with the territory (text p. ~9) says the whole comuni of Greve in Chianti (IT_048021), Castellina in Chianti (IT_052005), Radda in Chianti (IT_052023) and Gaiole in Chianti (IT_052013) are in the zone. It also says San Casciano Val di Pesa (IT_048038), Tavarnelle Val di Pesa and Barberino Val d'Elsa (merged 2019 into Barberino Tavarnelle, IT_048054) and Castelnuovo Berardenga (IT_052006) are only partly in it. The UGA San Donato in Poggio text also places part of Poggibonsi (IT_052022) in the zone. All of these are in provinces 048/052.
- **Brunello di Montalcino DOCG**: Art. 3.1 *"l'intero territorio amministrativo del comune di Montalcino ... così come delimitato alla data del 30 novembre 2011"*. That is the pre-2017 Montalcino; it was merged with San Giovanni d'Asso into today's Montalcino (IT_052037) in province 052.
- **Bolgheri DOC**: Art. 3.1, the comune of Castagneto Carducci (IT_049006, province 049) *"ad esclusione dei territori ubicati ad ovest della s.s. Aurelia, vecchio tracciato"*.

## Held back
None.
