# MICHELIN Guide Belgium & Luxembourg 2026: star update (2026-10-28)

Status: **PREPARED, NOT APPLIED.** The SQL is in `prepared_be_lu_stars_2026.sql`.

## Source

MICHELIN's own site, and nothing else:

- **Listing:** `guide.michelin.com/en/be|lu/restaurants/all-starred` shows
  136 starred restaurants: BE 2/19/103, LU 0/2/10. Pagination totals and the
  tier pages agree. Capture: `michelin_belu_starred.csv`.
- **2026 full-list article:** "De volledige lijst van de Sterren in de
  MICHELIN Gids België en Luxemburg 2026", 4 May 2026, 139 restaurants
  (BE 2/20/105, LU 0/2/10). It matches the listing one-to-one, except for
  three restaurants MICHELIN has since taken offline
  (`michelin_belu_article_only_not_listed.csv`).
- **2025 full list:** 151 restaurants, used for the comparison
  (`michelin_belu_previous.csv`).
- **Edition label:** MICHELIN calls this selection **2026**, and the restaurant
  pages' JSON-LD carries `dateAwarded "2026"`. Exact quotes are in
  `GUIDE_YEAR.md`.

## Guide year: no blanket relabel

Unlike the Netherlands, the BE/LU launch rows labelled 2026 already hold the
2026 edition's values. Every row was checked against the 2026 listing. Six
are the exception: they still carry their 2025 value. Only those six rows are
relabelled 2025, which is the launch-label rule in `DATA_UPDATE_PROCESS.md`
applied row by row.

## What changes

| Change | Restaurants |
|---|---|
| **Lost their star.** The 2026 row becomes 2025 (value unchanged, closed), a 2026 row with no star is added, and `michelin_stars` is set to NULL. | La Durée (2), Ralf Berendsen (2; the chef moved to SUIS, NL), Bar Bulot Zedelgem, Mémoire, Table d'Amis, Aurum by Gary Kirchens |
| **Missing history row added** (QA-221) | Le Lys |
| **`michelin_url` filled in** for 16 restaurants that had none. Same restaurant, same stars. | Bartholomeus, Cuchara, Slagmolen, De Jonkman, Sir Kwinten, Maison Colette, L'Eau Vive, d'Eugénie à Emilie, La Table de Maxime, Kelderman, Sense, Goffin, Hostellerie St-Nicolas, L'air du temps, The Jane, Comme chez Soi |
| **Starred but missing from the catalogue; added** as `rest_1405`–`rest_1417`, each with a 2026 row | Nebo, OAK, Sensum Gent, Couvert Couvert, EED, EssenCiel, De Bakermat, 't Stoveke, Menssa, Héliport Brasserie, La Roseraie Modave, Un Max de Goût, Philippe Fauchet |
| **Kept as they are** (user decision; QA-220) | La Paix (2), Kommilfoo, La Table de Manon. All three are in the 2026 edition with stars, but their pages were removed after May. |

None of the 13 newly added restaurants sits inside a hotel.

- Philippe Fauchet goes in without a phone, because its site and MICHELIN
  disagree (QA-222).
- None of the 13 has a Google Place ID yet.
- Their stars before 2026 are not recorded. This is the same launch
  limitation as every seeded row.

The twelve 2026 newcomers were already correct in production. They are The
Jane and Cuines 33 at two stars, and Bloesem, Subtiel, Moscou, EST, Vintage,
Atelier Noun, Agnes, Komaf, La Table-Lasne and Le Lys at one.

## Before running

Apply `supabase/migrations/20261016150000_add_be_2026_star_cities.sql` first.
It adds the seven towns that do not exist yet.

New restaurants use production's own spelling for existing towns: Antwerp,
Ghent, Heverlee, Liège and Sint-Denijs-Westrem.

## Testing

The file was run on a scratch PostgreSQL 16 + PostGIS database built from a
full migration replay and seeded with all 132 BE/LU rows exactly as exported:
stars, every history row and the current flags.

- **Result:** BE 2/20/105 and LU 2/10, which is exactly MICHELIN's 2026 full
  list.
- **History:** every BE/LU restaurant ends with exactly one current star row
  agreeing with `michelin_stars`.
- **Re-run:** a second run aborts at the first check.

It was not run against the real database.
