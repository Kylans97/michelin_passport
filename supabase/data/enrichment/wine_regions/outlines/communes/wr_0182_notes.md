# Navarra DOP: production zone

**Source:** https://www.mapa.gob.es/dam/mapa/contenido/alimentacion/temas/calidad-agroalimentaria/2017-calidad-diferenciada/nuevo_denominaciones/pliegos-de-condiciones/pliego-condiciones-vinos/dops/navarra_2024_10_11.pdf

Pliego DOP Navarra, version July 2024, on MAPA (navarra_2024_10_11.pdf; eAmbrosia shows an amendment in progress). Section 4 lists municipalities in five unidades geográficas menores plus Etxauri. Partial: Piedramillera (cadastral polygon 3), Cizur (polygon 13), Romanzado (concejos Arboniés and Domeño), Urraul Bajo (concejos Rípodas, San Vicente, Tabar). Name judgements: Estella = Estella-Lizarra, Oteiza de la Solana = Oteiza, Biurrun = Biurrun-Olcoz (sole candidates).

## Counts
**107 rows**, 4 partial: Piedramillera, Cizur, Romanzado, Urraul Bajo.

## Held back
'Sansoaín' (Ribera Alta list): no LAU municipality of that name in Navarra; Sansoáin exists as a concejo name (in Leoz and in Urraul Bajo), so it cannot be resolved without guessing. Facerías 30, 31 and 32 (communal lands, not municipalities). The vineyards of Allín, Azuelo, Guesálaz, Lapoblación, Metauten, Mirafuentes, Mues, Nazar, Oco, Sorlada, Lónguida, Yesa, Vidaurreta and Zabalza count only 'en tanto subsistan' for vineyards already registered: not a delimitation, left out.

## Method
Names matched to Eurostat GISCO LAU 2024 by name within the stated province only (the pliego gives no INE codes), accent, article and bilingual-name insensitive, using `classics/es/tools/match.py`; spellings that differ from the LAU name were resolved by hand to the sole candidate in the province (aliases in `tools/build.py`). Every name resolved to exactly one LAU unit and every GISCO_ID is unique. Raw text in `raw/`. Partial municipalities are kept and flagged partial = yes when the text names an administrative or cadastral unit (parish, concejo, cadastral polygon); municipalities where the text names only individual villages, places or a pago are held back, because the whole municipality would overstate the area badly. Unlike the classics round, no cadastral share was measured, so a partial row can overstate the area considerably.
