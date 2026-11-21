# Madiran (FR): boundary notes

**Drawn:** AOC Madiran and AOC Pacherenc du Vic-Bilh (same 37 communes).

**Source:** INAO "Aires géographiques des AOC/AOP" (data.gouv.fr, 2025-10-09-COMAGRI-Communes_Aires_AO.csv, scratchpad/dl_inao/ca.csv), merged communes resolved through INSEE v_mvt_commune_2026 to GISCO LAU 2024 ids FR_<INSEE>; same logic as the repo's fr_communes.py (script: tools/fr_communes_r5.py).

**Cross-check against the cahier des charges:** cahiers arrêté 26 Nov 2025 (BO 11 Dec 2025, 394c9c74 and f98a4f82): 37 communes, COG 2025, "Riscle (pour le seul territoire de la commune déléguée de Cannet)". All INAO names found in both cahiers. (tools/fr_crosscheck.py checks every INAO commune name against the cahier text.)

**INAO rows per area:** {'Madiran': 37, 'Pacherenc du Vic-Bilh': 37}. LAU rows written: 37; unresolved: 0.

**Partial (whole commune drawn, marked partial):** FR_32344: cahiers Madiran and Pacherenc du Vic-Bilh (BO 11 Dec 2025): Riscle only for the commune déléguée of Cannet; the whole commune is drawn.

official_name joins the INAO commune name(s) that resolved to the LAU unit; INAO drops leading articles ("Fleix" for LAU "Le Fleix").

Style: work/notes_fr.md (cahier versions, kept and held back).
