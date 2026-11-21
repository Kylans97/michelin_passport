# Colares (PT): boundary notes

**Official text:** DL 246/94 art. 2 as quoted in the caderno de especificações (eAmbrosia attachment 6924, https://webgate.ec.europa.eu/eambrosia-api/api/v1/attachments/6924): "compreende as freguesias de Colares, São Martinho, e São João das Lampas, do concelho de Sintra".

**Why it was held back:** in the 2013 reform São Martinho was merged into Sintra (Santa Maria e São Miguel, São Martinho e São Pedro de Penaferrim) and São João das Lampas into São João das Lampas e Terrugem, so LAU 2024 units overstate.

**Now drawn from official pre-reform geometry:** DGT, Carta Administrativa Oficial de Portugal, CAOP 2012.1, Continente (Cont_AAd_CAOP20121.zip from https://www.dgterritorio.gov.pt/cartografia/cartografia-tematica/caop, raw/caop2012/). The two old freguesias (Dicofre 111111 "Sintra (São Martinho)", 111110 "São João das Lampas") are reprojected from PT-TM06/ETRS89 to WGS84 with an inverse Transverse Mercator written for this (round4/held_tools/shp.py, colares.py) and simplified to about 100 m: units PT_CAOP2012_111111 and PT_CAOP2012_111110 in held_units.geojson. Colares itself kept its boundary in 2013 and is LAU PT_111105.

**Checks:** reprojected areas match the CAOP attribute areas (São Martinho 24.1 km², DGT 24.35; São João das Lampas 56.9, DGT 57.50; the small gap is the approximate degree-to-km conversion). Colares 2012 vs LAU 2024 PT_111105: IoU 0.95. The three old Sintra freguesias together vs PT_111128: IoU 0.96; São João das Lampas plus Terrugem vs PT_111127: IoU 0.97 (LAU is generalised).

**Caveats:** the DL dates from 1994 and CAOP 2012 is the nearest official geometry before the reform; no boundary change to these freguesias between 1994 and 2012 was found, but that was not proven. Licence: DGT says CAOP is free to view and download; its "Condições de utilização" page was not read.

**Rows:** 3; partial 0. Style: Ramisco left out of grapes and new_grapes.json (no two sources for taste words); Malvasia de Colares added.
