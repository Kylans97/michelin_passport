# Gault&Millau France — Research Report

Retrieval date for all claims: 2026-08-11. Sourced from official Gault&Millau domains (`fr.gaultmillau.com`, `gaultmillau.fr` shop) unless marked secondary.

## Part A — System findings

**1. Score scale / listing threshold:** 0–20, never a full 20/20 in practice. **Minimum score to be listed: 10/20** — official quote: "The pass mark is set at 10/20. Below this mark, a restaurant is not included in our selection." Source: [Classement des restaurants](https://fr.gaultmillau.com/en/faq/comment-sont-classes-les-restaurants--les-toques-1-a-5-0-a-20-points)

**2. Official score-to-toque mapping (5 tiers):**

| Score range | Toques | Classification name |
|---|---|---|
| 10–10.5 | 0 (listed, unranked) | Tables originales |
| 11–12.5 | 1 | Tables gourmandes |
| 13–14.5 | 2 | Tables de chef |
| 15–16.5 | 3 | Tables remarquables |
| 17–18.5 | 4 | Tables prestige |
| 19–19.5 | 5 | Tables d'exception |

**3. Restaurants without a numeric score: YES, confirmed.** "Toques d'Or" (Gault&Millau Academy) members are explicitly removed from scoring while remaining listed. Verified directly on live pages for Le Meurice-Alain Ducasse, L'Ambroisie, Guy Savoy, L'Arpège, Pierre Gagnaire. Official quote: "With this distinction, their restaurants will no longer be rated, but still recommended to epicureans." ([FAQ](https://fr.gaultmillau.com/en/faq/c-est-quoi-les-toques-d-or%C2%A0))

**4. Current edition / history:** Guide France 2026 ("Guide Jaune"), 2,100 establishments, 80 in the 4-5 toque tier, published 20 Nov 2025 after a gala on 17 Nov 2025. **No historical archive found** — 10+ profile pages checked, none show past-year scores. This is a real gap for year-over-year tracking.

**5. Profile URL pattern:** `https://fr.gaultmillau.com/en/restaurants/{slug}` — confirmed on every restaurant checked.

**6. Special awards (2026 gala, 17 Nov 2025), from [official recap](https://fr.gaultmillau.com/fr/news/gala-gault-millau-2025):**

| French name | English | 2026 Winner | Restaurant |
|---|---|---|---|
| Cuisinier de l'Année | Chef of the Year | César Troisgros | Le Bois sans feuilles - Maison Troisgros |
| Pâtissier de l'Année | Pastry Chef of the Year | Anne Coruble | L'Oiseau Blanc - The Peninsula |
| Sommelier de l'Année | Sommelier of the Year | Marion Cirino | L'Ambroisie |
| Directeur/Directrice de Salle de l'Année | Restaurant Manager of the Year | Fanny Perrot | Alléno Paris – Pavillon Ledoyen |
| Grand de Demain de l'Année | Rising Star of the Year | Loïs Bée | La Table - Christophe Hay et Loïs Bée |
| Jeune Talent de l'Année | Young Talent of the Year | Romain Zarazaga | Lueurs |

Also: **Gault&Millau d'Or** — separate *regional* award (distinct from the national Trophées), given at regional "Gault&Millau Tour" events. No France-specific "Woman Chef of the Year" category found (that title exists in Belgium's franchise, not France's).

**7. Top tier beyond toques: "Toques d'Or" / Gault&Millau Academy** — exactly 10 members ("the 10 sages"), each with 5 gold toques, removed from annual scoring, signs a charter. Only 5 of 10 members identified with confidence this pass (Ducasse/Meurice, L'Ambroisie, Guy Savoy, Passard/L'Arpège, Pierre Gagnaire) — full roster of 10 not located on an official page.

## Part B — Sample data (19 restaurants, guide year 2026, retrieved 2026-08-11)

See `gault_millau_restaurants.csv` for the merged, structured version. Raw findings:

**Toques d'Or (unscored):** Le Meurice-Alain Ducasse, L'Ambroisie, Restaurant Guy Savoy, L'Arpège, Pierre Gagnaire — all Paris.

**5 toques (19-19.5/20):** AM par Alexandre Mazzia (Marseille, 19), Alléno Paris–Pavillon Ledoyen (Paris, 19), Plénitude-Cheval Blanc Paris (Paris, 19), Le 1947 à Cheval Blanc (Courchevel, 19), La Table de Yoann Conte (Veyrier-du-Lac, 19), Le Cinq-Four Seasons George V (Paris, 19).

**4 toques (17-18.5/20):** Le Bois sans feuilles-Maison Troisgros (Ouches, 18.5), Pic/Anne-Sophie Pic (Valence, 18.5), Passédat-Le Petit Nice (Marseille, 18.5), Épicure-Le Bristol Paris (Paris, 17.5), Restaurant Christopher Coutanceau (La Rochelle, 17), Bras Le Suquet (Laguiole, 17), Le Neuvième Art (Lyon, 17).

**3 toques reference:** Une Table au Sud (Marseille, 16).

Full addresses, websites, and exact G&M profile URLs for each are captured in the merged CSV.

## Data access quality

Official site fully reachable, no blocking/CAPTCHA. Key friction: (1) no historical archive anywhere on the live site; (2) toque count not consistently restated on individual profile pages — city "best restaurants" roundup pages are the more reliable structured source; (3) the Toques d'Or tier is a real schema complication — ~10 historically significant restaurants have no numeric score by design, need a nullable score + distinct flag, not treated as missing data.
