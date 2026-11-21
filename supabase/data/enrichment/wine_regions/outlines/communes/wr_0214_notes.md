# dealu-mare (Dealu Mare, RO): municipality mapping notes

Prepared 2026-11-21. CSV: dealu-mare.csv.

## Official text
- PDO Dealu Mare, EUGI00000006721, PDO-RO-A1079. Single document as amended by the Union amendment PDO-RO-A1079-AM02, published OJ C 253, 18.7.2023 (https://eur-lex.europa.eu/legal-content/RO/TXT/?uri=uriserv:OJ.C_.2023.253.01.0011.01.RON, raw/dealumare_C253_2023_ro.txt), approved by Reg. (EU) 2023/2535 of 17.11.2023. Section 6 lists communes/towns and their villages for eight sub-denominations. National specification: https://www.onvpv.ro/sites/default/files/caiet_sarcini_doc_dealu_mare_modif_cf_cererii_1996_01.10.2020_toate_categ_cf_notificarii_945_12.05.2022.pdf (not downloaded).
- The 2023 amendment unified the earlier separate files for sparkling, aromatic sparkling and pétillant Dealu Mare (EUGI00000007142, 00000006663, 00000006687); the area is the one above.

## How resolved
- SIRUTA, INS register, first half 2026 (data.gov.ro, CC BY 4.0, raw/siruta_s1_2026.csv). The SIRUTA 'LAU' column gives the GISCO_ID (RO_ + UAT SIRUTA code); all present in the LAU 2024 index. Each UAT matched by name inside its județ (Prahova 29, Buzău 10); every listed village checked as a SIRUTA child of that UAT (tools: ro_resolve.py).
- Spelling: text "Boldești-Scăieni" = SIRUTA "Boldești-Scăeni"; villages "Valea Ursoi" = VALEA URSOII, "Răchieri" = RACHIERI, "Măruntiș" = MĂRUNȚIȘ, "Valea Urloi" = VALEA URLOII, "Prosca" = PROȘCA.
- "Valea Săracă", listed among the villages of Valea Călugărească, is not a SIRUTA village (it is also a plai viticol name). Kept as text; the UAT is partial anyway.
- partial = the UAT has villages the text does not list: 12 of 20.

## Counts
- Rows: 20
- Partial: 12
- Provinces: Județul Buzău, Județul Prahova

## Held back / left out (style)
- Dealu Mare red_tannin and red_acidity: Single document says 'light tannins' and 'well-integrated acidity and tannins'; SevenFifty says 'well-structured'. No level that two sources agree on.
- Dealu Mare climate (milder hill winters, south facing slopes): Single document only. winetourism.com says Muntenia areas see 'some of the highest average temperatures in Romania', which is region wide, not Dealu Mare.
- Dealu Mare sub-designations Ceptura, Tohani, Merei giving more robust, deeper coloured reds: Single document only.
- Dealu Mare 'famous for Merlot': winetourism.com only; Merlot kept in the grape list (EU doc + Wikipedia list it) but not given a signature note.

## Style content
See style.json. A claim was kept only where two independent sources agree; an EU single document and its national specification count as one government source.
