# Savoie: communes and sourcing

**Defining AOC area(s):** AOC Vin de Savoie, Roussette de Savoie and Seyssel.

Crémant de Savoie is not a separate AOC (it is a mention within Vin de Savoie, cahier BO 6 Jul 2023), so nothing extra. Seyssel adds Corbonod and Seyssel (Ain), which are also in Vin de Savoie's red/rosé area per its cahier but are listed by INAO under Seyssel only. Chapareillan (Isère) is included. Partial by the cahiers: Entrelacs (only former Saint-Germain-la-Chambotte), Clarafond-Arcine (only former Clarafond). Bugey is a separate region, not covered.

- Source: INAO "Aires géographiques des AOC/AOP" (data.gouv.fr, file 2025-10-09-COMAGRI-Communes_Aires_AO.csv), merged communes resolved through INSEE v_mvt_commune_2026, mapped to GISCO LAU 2024 ids FR_<INSEE>. Same logic as scratchpad/fr_communes.py (script: scripts/fr_classics_communes.py).
- INAO rows per area: {'Vin de Savoie': 50, 'Roussette de Savoie': 52, 'Seyssel': 3}
- LAU rows written: 55; unresolved INSEE codes: 0
- Partial (drawn whole): FR_73010 Entrelacs: cahiers Vin de Savoie (BO 6 Jul 2023) and Roussette de Savoie (BO 7 Oct 2021): only the former commune of Saint-Germain-la-Chambotte; the whole commune is drawn; FR_74077 Clarafond-Arcine: cahier Vin de Savoie (BO 6 Jul 2023): only the former commune of Clarafond; the whole commune is drawn
- Official names in this file follow INAO, which drops leading articles (e.g. "Arcs" for LAU "Les Arcs"); the gisco_id is the key.

## Style entry (style.json)

# Savoie: sourcing notes (2026-11-21)

Source keys: VDS = Vin de Savoie cahier (BO 6 Jul 2023, doc 1713c806); RDS = Roussette de Savoie (BO 7 Oct 2021, 6439ab55); SEY = Seyssel (BO 29 Oct 2026, 968b93cb). HV = Hachette Vins, Savoie et Bugey region page (regions-vins/340); WF = Wine Folly Savoie wine guide; GS-N = GuildSomm, Charles Neal, Savoie-Faire.

## Kept
| Field | Claim | Sources |
|---|---|---|
| summary | first slopes of the Alps | HV ("occupe les premières pentes alpines"), GS-N (wines of the French Alps) |
| summary | about 70% white, mostly dry | HV (70%, "secs pour la plupart"), WF (70%), GS-N (just under 70%; "crisp, dry finishes") |
| summary | Jacquère most planted | HV, WF (50%), GS-N (50%) |
| summary | Mondeuse the local red | HV ("cépage local", "vins rouges de caractère"), GS-N ("king of red grapes"), WF |
| label_note | 16 DGC crus with own grape rules; grape name only if 100%; sparkling white must say Crémant | VDS II 1° to 3°, V |
| grapes | Jacquère, Altesse, Mondeuse, Chasselas, Gamay, Pinot Noir as main grapes | HV (white and red lists), WF, GS-N, VDS (cépages principaux) |
| grapes | Altesse = Roussette; Roussette de Savoie Altesse only | RDS V ("seul cépage altesse B"), WF ("100% Altesse"), HV |
| grapes | Arbin and Saint-Jean-de-la-Porte Mondeuse only | VDS ("mondeuse N exclusivement"), HV (Arbin, mondeuse exclusive) |
| grapes | Chasselas mainly Haute-Savoie | VDS (principal only in Haute-Savoie), GS-N (70% of Haute-Savoie plantings) |
| appellations | three AOCs | VDS, RDS, SEY; GS-N ("Savoie has three appellations") |

## Held back
- **Crémant de Savoie is not a separate AOC.** In the 2023 Vin de Savoie cahier, "Crémant" is an indication within AOC Vin de Savoie (II 3°: the name must be preceded by "Crémant" for quality sparkling whites). WF calls it "Crémant de Savoie AOP" and HV lists it as an appellation; the cahier is the law, so it is folded into the Vin de Savoie entry and not listed separately.
- **Cru count:** cahier lists 16 DGCs (matching WF's 16); GS-N says 17 (older count). Cahier used.
- **Pairing.** HV lists fondue savoyarde among classic dishes and GS-N describes fondue and tartiflette as local food, but neither states a wine pairing. Held.
- **Red ratings.** White-led (70% white), red_* null by rule. Mondeuse style is not double sourced at any level anyway (see grapes_a_notes.md).
- **Grape order** beyond Jacquère first is not double sourced as a ranking. Altesse is placed second because Roussette de Savoie is the second appellation (GS-N, 10% of production) and HV lists it second among whites.
- **Grapes not on the allowed list:** Roussanne (Bergeron; Chignin-Bergeron is roussanne only per VDS, and HV and WF name it), Gringet (Ayze), Molette (Seyssel), Persan. Left out.
- **Aliases:** "Savoy" not found in a fetched source; none kept.
- Unreachable: vinsdesavoie.com has no content (per grapes_a_notes.md); web search budget for the turn was exhausted.

## Map
Vin de Savoie and Roussette de Savoie harvest areas span Savoie and Haute-Savoie plus Chapareillan (Isère). Vin de Savoie reds, rosés and rosé sparkling also include Corbonod and Seyssel (Ain). Seyssel AOC is Corbonod and Seyssel (Ain) and Seyssel (Haute-Savoie). Bugey is a separate region and not covered here. There is no Crémant de Savoie area to draw separately.
