# Jurançon (FR): boundary notes

**Drawn:** AOC Jurançon.

**Source:** INAO "Aires géographiques des AOC/AOP" (data.gouv.fr, 2025-10-09-COMAGRI-Communes_Aires_AO.csv, scratchpad/dl_inao/ca.csv), merged communes resolved through INSEE v_mvt_commune_2026 to GISCO LAU 2024 ids FR_<INSEE>; same logic as the repo's fr_communes.py (script: tools/fr_communes_r5.py).

**Cross-check against the cahier des charges:** cahier arrêté 26 May 2025 (BO 12 Jun 2025, d645c8b2-...): 25 communes, COG 2024. All 25 INAO communes appear in the cahier list (INAO "Estialesq" = cahier "Estialescq"). (tools/fr_crosscheck.py checks every INAO commune name against the cahier text.)

**INAO rows per area:** {'Jurançon': 25}. LAU rows written: 25; unresolved: 0.

**Partial (whole commune drawn, marked partial):** none.

official_name joins the INAO commune name(s) that resolved to the LAU unit; INAO drops leading articles ("Fleix" for LAU "Le Fleix").

Style: work/notes_fr.md (cahier versions, kept and held back).
