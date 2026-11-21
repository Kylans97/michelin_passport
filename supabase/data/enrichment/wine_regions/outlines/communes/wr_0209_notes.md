# Gaillac (FR): boundary notes

**Drawn:** AOC Gaillac and AOC Gaillac premières côtes.

**Source:** INAO "Aires géographiques des AOC/AOP" (data.gouv.fr, 2025-10-09-COMAGRI-Communes_Aires_AO.csv, scratchpad/dl_inao/ca.csv), merged communes resolved through INSEE v_mvt_commune_2026 to GISCO LAU 2024 ids FR_<INSEE>; same logic as the repo's fr_communes.py (script: tools/fr_communes_r5.py).

**Cross-check against the cahier des charges:** cahier Gaillac arrêté 5 Sep 2025 (BO 11 Sep 2025, b13c44bb): communes of the Tarn, COG 2025. INAO "Puycelci" = cahier "Puycelsi"; INAO "Saint-Sulpice-la-Pointe" = cahier "Saint-Sulpice". Bellegarde-Marsal: INAO lists both Bellegarde-Marsal and former Marsal, one LAU. Gaillac premières côtes: INAO gives 64 communes for its aire géographique, all inside Gaillac's; its cahier was not read (INAO extranet refused connections), so the style note's "11 communes" refers to the parcel area and was not used here. (tools/fr_crosscheck.py checks every INAO commune name against the cahier text.)

**INAO rows per area:** {'Gaillac': 73, 'Gaillac premières côtes': 64}. LAU rows written: 72; unresolved: 0.

**Partial (whole commune drawn, marked partial):** none.

official_name joins the INAO commune name(s) that resolved to the LAU unit; INAO drops leading articles ("Fleix" for LAU "Le Fleix").

Style: work/notes_fr.md (cahier versions, kept and held back).
