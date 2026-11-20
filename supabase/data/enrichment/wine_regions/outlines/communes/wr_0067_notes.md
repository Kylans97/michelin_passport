# Lavaux (regional AOC within Vaud)

## Official text
- Règlement sur les vins vaudois (RVV), BLV 916.125.2, version in force from 01.07.2026.
  https://www.lexfind.ch/tolv/261089/fr
- Art. 3 al. 1 let. b: "la région de Lavaux comprend toutes les communes viticoles des districts de
  Lavaux-Oron et de la Riviera-Pays-d'Enhaut ainsi que la commune de Lausanne".
- Art. 8: the region is split into lieux de production (Lutry, Villette, Epesses, Saint-Saphorin,
  Chardonne, Montreux/Vevey), each defined by named communes.
- Art. 3 let. g, h and art. 4: Dézaley (part of Puidoux), Calamin (part of the former commune of
  Epesses) and Dézaley-Marsens are Grand cru AOCs inside Lavaux, and their wines may also use the
  Lavaux appellation (art. 4 al. 3).

## How the area is defined
Art. 3 does not list the "communes viticoles". The communes named in art. 8 are taken as that list:
every one of them lies in Lavaux-Oron or Riviera-Pays-d'Enhaut, or is Lausanne (checked against
the BFS district of each). Other communes in those two districts (Oron, Savigny, Château-d'Œx and
others) appear in no lieu de production and are not included.

## Mergers applied
- Villette (Lavaux), Grandvaux, Epesses, Riex, Cully → Bourg-en-Lavaux (BFS 5613), 01.07.2011.
- Saint-Légier-La Chiésaz, Blonay → Blonay - Saint-Légier (BFS 5892), 01.01.2022.
  Both from `raw/bfs_mutations_2011-2023.csv`.

## Counts
19 rows, 19 unique GISCO IDs, all in canton VD. `partial` is empty for all: at region level each
commune is wholly within Lavaux. The part-commune wording in art. 8 only splits lieux de
production inside the region. For example Belmont "(hormis le territoire sis à l'est du ruisseau
de Bouteiller)" and Chardonne south of the motorway decide which lieu de production applies, not
whether the land is in Lavaux.

## Judgement calls
- Lausanne is included whole, as art. 3 let. b says ("la commune de Lausanne").
- Dézaley and Calamin are parts of single communes (Puidoux; Bourg-en-Lavaux) and cannot be drawn
  from LAU units, so they appear only as appellations in style.json.
- This polygon overlaps `vaud.csv`. Show it as a sub-region, or not at all if the globe cannot
  nest regions.

## Style sourcing
- UNESCO listing in 2007: Lavaux management plan (lavaux-unesco.ch, "Le 28 juin 2007") and Swiss
  Wine Promotion. The UNESCO site itself returned 403 to automated fetches.
- Grape list (Chasselas only) has a single source (Swiss Wine Promotion: "especially Chasselas").
  For that reason Chasselas is not mentioned in the summary.

## Held back
- Any statement that Chasselas dominates Lavaux (single source).
- Lavaux grape shares (no statistics found below canton level).
