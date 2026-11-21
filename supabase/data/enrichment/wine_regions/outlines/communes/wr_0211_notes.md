# Corsica (FR): boundary notes

**Drawn:** Vin de Corse ou Corse (with Calvi, Coteaux du Cap Corse, Figari, Porto-Vecchio, Sartène), Patrimonio, Ajaccio, Muscat du Cap Corse.

**Source:** INAO "Aires géographiques des AOC/AOP" (data.gouv.fr, 2025-10-09-COMAGRI-Communes_Aires_AO.csv, scratchpad/dl_inao/ca.csv), merged communes resolved through INSEE v_mvt_commune_2026 to GISCO LAU 2024 ids FR_<INSEE>; same logic as the repo's fr_communes.py (script: tools/fr_communes_r5.py).

**Cross-check against the cahier des charges:** cahiers Vin de Corse ou Corse arrêté 6 Dec 2019 (BO 12 Dec 2019, e04c94be), Ajaccio same date (67402288), Patrimonio arrêté 25 Apr 2022 (BO 12 May 2022, ef16a4b1); Muscat du Cap Corse from the EU fiche technique PDO-FR-A0722 sec. 5 (eAmbrosia attachment 10480). Spelling only: INAO "Cannelle" = cahier "Canelle", "Sant'Andréa-d'Orcino" = "Saint-André-d'Orcino", "Sainte-Lucie-de-Tallano" = "Santa-Lucia-di-Tallano". Muscat du Cap Corse takes Saint-Florent only on the right bank of the Aliso, but Saint-Florent is wholly in Patrimonio, so the region row is not partial. Patrimonio's aire de proximité immédiate (Olmeta-di-Tuda) is not part of the area and is not drawn. (tools/fr_crosscheck.py checks every INAO commune name against the cahier text.)

**INAO rows per area:** {'Vin de Corse ou Corse': 182, 'Vin de Corse ou Corse Calvi': 32, 'Vin de Corse ou Corse Coteaux du Cap Corse': 21, 'Vin de Corse ou Corse Figari': 3, 'Vin de Corse ou Corse Porto-Vecchio': 8, 'Vin de Corse ou Corse Sartène': 16, 'Patrimonio': 7, 'Ajaccio': 36, 'Muscat du Cap Corse': 17}. LAU rows written: 189; unresolved: 0.

**Partial (whole commune drawn, marked partial):** none.

official_name joins the INAO commune name(s) that resolved to the LAU unit; INAO drops leading articles ("Fleix" for LAU "Le Fleix").

Style: work/notes_fr.md (cahier versions, kept and held back).
