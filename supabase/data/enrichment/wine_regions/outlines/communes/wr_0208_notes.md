# Bergerac (FR): boundary notes

**Drawn:** Bergerac, Côtes de Bergerac, Monbazillac, Saussignac, Pécharmant, Rosette, Montravel, Côtes de Montravel, Haut-Montravel (all satellites lie inside the 90 Bergerac communes).

**Source:** INAO "Aires géographiques des AOC/AOP" (data.gouv.fr, 2025-10-09-COMAGRI-Communes_Aires_AO.csv, scratchpad/dl_inao/ca.csv), merged communes resolved through INSEE v_mvt_commune_2026 to GISCO LAU 2024 ids FR_<INSEE>; same logic as the repo's fr_communes.py (script: tools/fr_communes_r5.py).

**Cross-check against the cahier des charges:** cahier Bergerac arrêté 25 Aug 2021 (BO 2 Sep 2021, a078cfed): communes "retenues en entier" plus "en partie": Beaumontois en Périgord for Nojals-et-Clotte only, Eyraud-Crempse-Maurens for Maurens only. INAO lists the three former communes Saint-Julien-d'Eymet, Sainte-Eulalie-d'Eymet and Sainte-Innocence; the cahier lists their merger Saint-Julien-Innocence-Eulalie whole, so it is not partial. Sigoulès and Flaugeac likewise resolve to Sigoulès-et-Flaugeac, listed whole. Every other INAO name was found in its cahier. (tools/fr_crosscheck.py checks every INAO commune name against the cahier text.)

**INAO rows per area:** {'Bergerac': 90, 'Côtes de Bergerac': 90, 'Monbazillac': 5, 'Saussignac': 4, 'Pécharmant': 4, 'Rosette': 6, 'Montravel': 15, 'Côtes de Montravel': 13, 'Haut-Montravel': 13}. LAU rows written: 87; unresolved: 0.

**Partial (whole commune drawn, marked partial):** FR_24259: cahier Bergerac (BO 2 Sep 2021): Eyraud-Crempse-Maurens only for the former commune of Maurens; the whole commune is drawn; FR_24028: cahier Bergerac (BO 2 Sep 2021): Beaumontois en Périgord only for the former commune of Nojals-et-Clotte; the whole commune is drawn.

official_name joins the INAO commune name(s) that resolved to the LAU unit; INAO drops leading articles ("Fleix" for LAU "Le Fleix").

Style: work/notes_fr.md (cahier versions, kept and held back).
