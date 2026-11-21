# Côtes de Sambre et Meuse (AOP/PDO, Belgium, Wallonia)

## Defining texts
- EU single document (technical file under Art. 118 vicies Reg. 1234/2007), PDO-BE-A0009, Ref. Ares(2014)684283, eAmbrosia EUGI00000005343: https://ec.europa.eu/geographical-indications-register/eambrosia-public-api/api/v1/attachments/11689 (raw/ea_csm.pdf). Point 5: grapes harvested "exclusivement dans le bassin hydrographique de la Meuse (Meuse amont, Meuse aval, Sambre, Ourthe, Amblève, Semois-Chiers, Vesdre et Lesse) en Région wallonne (dans des communes situées totalement ou partiellement (dans ce cas le vin produit dans ces communes doit provenir de parcelles situées totalement dans le bassin hydrographique de la Meuse) ... La liste détaillée des communes est reprise dans le cahier des charges. Cette zone est définie de manière précise et univoque par l'article D.7 du Code de l'Eau."
- Commune list: Arrêté ministériel du 27 mai 2004 portant agrément des « Côtes de Sambre et Meuse », annex art. 1 as replaced by AMRW du 29 mai 2007 (version in force 06/07/2007 to 22/09/2016): https://wallex.wallonie.be/eli/arrete/2004/05/27/2004203295/2007/07/06 (raw/wallex_2879.txt). "1° Communes situées totalement dans le bassin hydrographique de la Meuse" (152 names) and "2° Communes situées partiellement dans le bassin hydrographique de la Meuse. Le vin produit dans ces communes doit provenir de parcelles situées totalement dans le bassin hydrographique de la Meuse" (47 names).
- Caveat: Wallex marks this ministerial order as repealed by the AGW of 14 July 2016 as a national act. The EU file still defines the area as the Meuse basin and refers to the commune list in the cahier des charges (attached to the EU file as "CC - AOP.Cotes.Sambre.Meuse.pdf", which I could not retrieve). The 2007 list is the latest official commune list found; it matches the EU definition (same eight sub-basins).

## Method
- Names matched by name to GISCO LAU 2024 within the five Walloon provinces only. Spelling differences resolved: "Ham-sur-Heure-Nalinne" = LAU "Ham-sur-Heure-Nalinnes"; "Villers-le-Bouillet" = "Villers-Le-Bouillet"; "Kelmis/La Calamine" = "Kelmis / La Calamine"; "Butgenbach" = "Bütgenbach / Butgenbach"; "SanktVith" = "Sankt Vith". Each name to exactly one unit; 199/199 matched.
- Basin share computed against the official SPW layer "Bassins versants fluviaux / Districts hydrographiques", district BE_MEUSE_RW (https://geoservices.wallonie.be/arcgis/rest/services/EAU/BASSINS/MapServer/0, raw/spw_districts.geojson), intersected with GISCO LAU 2024 geometry. Check: every "totalement" commune comes out at 97% or more.
- Rule used: a "partiellement" commune is drawn if 50% or more of it lies in the basin; below that it is left out as a minority part. Martelange is at 50.2%, drawn, borderline.

## Units: 179 LAU, about 12,339 km2 (Wallonia is about 16,905 km2)
- 152 whole communes, 27 partial communes drawn. By province: Liège 80, Luxembourg 40, Namur 38, Hainaut 21, Brabant wallon 0.

### Partial communes drawn (text wording in the CSV; share of the unit in the Meuse basin)
- Amel (BE_63001, Liège): 79%
- Arlon (BE_81001, Luxembourg (BE)): 62%
- Berloz (BE_64008, Liège): 84%
- Büllingen (BE_63012, Liège): 65%
- Chapelle-lez-Herlaimont (BE_52010, Hainaut): 75%
- Chimay (BE_56016, Hainaut): 90%
- Courcelles (BE_52015, Hainaut): 99%
- Eghezée (BE_92035, Namur): 96%
- Erquelinnes (BE_56022, Hainaut): 78%
- Fleurus (BE_52021, Hainaut): 99%
- Gembloux (BE_92142, Namur): 87%
- Gouvy (BE_82037, Luxembourg (BE)): 92%
- Houffalize (BE_82014, Luxembourg (BE)): 98%
- Les Bons Villers (BE_52075, Hainaut): 91%
- Libramont-Chevigny (BE_84077, Luxembourg (BE)): 99%
- Lobbes (BE_56044, Hainaut): 100%
- Léglise (BE_84033, Luxembourg (BE)): 72%
- Martelange (BE_81013, Luxembourg (BE)): 50%
- Merbes-le-Château (BE_56049, Hainaut): 100%
- Messancy (BE_81015, Luxembourg (BE)): 82%
- Neufchâteau (BE_84043, Luxembourg (BE)): 97%
- Oreye (BE_64056, Liège): 84%
- Pont-à-Celles (BE_52055, Hainaut): 94%
- Sombreffe (BE_92114, Namur): 79%
- Vielsalm (BE_82032, Luxembourg (BE)): 100%
- Waremme (BE_64074, Liège): 94%
- Wasseiges (BE_64075, Liège): 91%

### Partial communes left out (share in the Meuse basin)
- Bastogne (BE_82003): 37% in the Meuse basin
- Sankt Vith (text: SanktVith) (BE_63067): 31% in the Meuse basin
- Anderlues (BE_56001): 28% in the Meuse basin
- Momignies (BE_56051): 28% in the Meuse basin
- Vaux-sur-Sûre (BE_82036): 27% in the Meuse basin
- Hannut (BE_64034): 25% in the Meuse basin
- Attert (BE_81003): 18% in the Meuse basin
- Villers-la-Ville (BE_25107): 9% in the Meuse basin
- Ramillies (BE_25122): 8% in the Meuse basin
- Binche (BE_58002): 7% in the Meuse basin
- Perwez (BE_25084): 6% in the Meuse basin
- Estinnes (BE_58003): 4% in the Meuse basin
- Nivelles (BE_25072): 4% in the Meuse basin
- Seneffe (BE_55085): 2% in the Meuse basin
- Manage (BE_55086): 1% in the Meuse basin
- Genappe (BE_25031): 1% in the Meuse basin
- Walhain (BE_25124): 0% in the Meuse basin
- Burg-Reuland (BE_63087): 0% in the Meuse basin
- Chastre (BE_25117): 0% in the Meuse basin
- Morlanwelz (BE_58004): 0% in the Meuse basin
- Morlanwelz, Burg-Reuland, Chastre and Walhain come out at or near 0%: the listed portion is below what the generalised GISCO boundaries resolve.

## Mergers
- No Walloon merger affects LAU 2024. On 1 January 2025 Bastogne and Bertogne merged; Bertogne is listed "totalement", Bastogne "partiellement" (37%, left out). A later LAU vintage would need the new Bastogne re-checked.

## Other Walloon names (not drawn as regions)
- Crémant de Wallonie (PDO-BE-A0012, Ares(2014)684542) and Vin mousseux de qualité de Wallonie (PDO-BE-A0011, Ares(2014)684268): "L'aire géographique ... correspond à la Wallonie dans son entièreté" (raw/ea_cremw.pdf, raw/ea_vmqw.pdf). White or rosé, traditional method.
- Vin de pays des jardins de Wallonie (PGI-BE-A0010, Ares(2014)684243): "vendanges récoltées uniquement en Région wallonne (constituée des provinces de Brabant wallon, Hainaut, Liège, Luxembourg, Namur)" (raw/ea_jardins.pdf).
- These three cover the whole Walloon Region, so they are listed as appellations inside the Côtes de Sambre et Meuse style entry rather than drawn.

## Held back
- Grapes: the authorised list has about 30 varieties and no ranking; no planting data by appellation found. grapes left empty.
- Red style scores: only the EU file describes the reds ("La teneur en tanins est faible", "acidité typique ... fraîcheur"); no second source found, so null.
