# A global database of wine estates: plan

Written 2026-11-24. **Proposal, waiting for the product owner.** Nothing
applied 2026-11-24: batch 1 (40 regions, 24 villages), migration 20261101740000 and the village table. Review doc: https://claude.ai/artifact/12zjJDehFJAwfiaEuSypDT

Product owner, 2026-11-24: "Maybe we should first build an extensive
database with vineyards all across the globe. So that first people can
link the wine they had with the vineyard. And once we have that database
fully up and running we can do that globe for wines."

## Where it stands (production, 2026-11-24)

- `vineyards`: 44 estates (The World's 50 Best Vineyards 2026, ranks 1 to
  50 minus 6 held back behind age gates or conflicts). None has
  `wine_region_id`. 0 Place IDs. 23 have the estate's own pin.
- Staged, not loaded: ranks 51 to 100 (names only, unverified) and five
  Dutch estates (`vineyards_editorial/`, codes vine_0051..0055).
- `wine_regions`: 275, all published, 238 with an outline built from the
  official commune lists in the repo.
- Logged wines: 3 visit wines, 2 Cellar wines, 4 linked to an estate.
- The app reads **every** estate at once (`VineyardRepository.getAll`) and
  filters on the device: the wine sheet's Producer field, + Add, the
  wishlist sheet, Explore and the Wine Estates collection.

## 1. Scope: which estates, in which order

**What counts as an estate.** The name on the label that makes the wine and
has a physical seat in a wine region: a domaine, château, bodega, quinta,
weingut, a Champagne house (also when it buys grapes), a cooperative that
bottles under its own name. One row per seat.

**What does not.** A vineyard parcel or cru (Musigny, Cannubi: those are
places, kept as appellations); a second wine (an alias of its estate); a
brand with no winery of its own (supermarket and distributor labels); a
producer no official source names and with no website we can verify. Too
small means: nothing to verify it against, not few bottles.

**Order**, each tier from the body that publishes the list itself:

| Tier | What | Source (the organiser's or authority's own page) | Size, unverified |
|---|---|---|---|
| 0 | The 44 on production: region and village | this plan, batch 1 | 44 |
| 1 | Finish The World's 50 Best Vineyards: the 6 held back, ranks 51 to 100 | the50.com list and estate pages | 56 |
| 1 | The five Dutch estates already staged | estates' own sites, BAG via PDOK | 5 |
| 2 | Benelux, complete: every estate in a Dutch BOB or Belgian AOP/BOB dossier | RVO productdossiers; Belgian federal and regional registers | ~100 |
| 3 | Official classifications: Bordeaux 1855 (Médoc and Sauternes), Saint-Émilion, Graves | Conseil des Grands Crus Classés en 1855; INAO homologation; the Graves decree | ~190 |
| 3 | Spain's Vinos de Pago (each estate is its own DOP) | MAPA | ~25 |
| 3 | VDP (Germany) and ÖTW (Austria) members | the associations' own member lists | ~270 |
| 4 | Estates members actually log: an unlinked producer becomes a request, verified before it is added | members' own wines, `inclusion_reason = member_request` | ongoing |
| later | Burgundy, Champagne, Piedmont, the New World: no official estate list exists; by region, through the atlas, each estate verified singly | estates' own sites, official registers | open |

Sizes are from memory of the published lists and are **not** verified; the
real count comes from the official page when the batch starts (only lists
the body publishes itself proved reliable for MICHELIN, and the same rule
applies here).

Recognition (an 1855 class, a VDP membership, a Pago) is a fact about the
estate, kept in its own table like `worlds_50_best_vineyards`, never gold.

## 2. The record each estate needs

| Field | Where it comes from | Required |
|---|---|---|
| `vineyard_code` | next free code (vine_0056 on 2026-11-24) | yes |
| `name` | as the estate writes it on its own site | yes |
| `aliases` | other names on labels, second wines; for search only | no |
| `country_code` | the official list, or the estate's address | yes |
| `wine_region_id` | chosen by hand per estate, checked against the outline | when the atlas has the region |
| `commune_code` (village) | the unit of that region's official commune list holding the estate's municipality | when the region has two or more units |
| `city`, `address` | the estate's own contact or legal page | address if published |
| `location` | the estate's own pin, or an official address register (BAG); never geocoded | no |
| `google_place_id` | `find-place-id`, proven by the estate's own coordinates | no |
| `website_url` | `find-venue-website`, reached from the official list | yes for tiers 1 to 3 |
| `inclusion_reason` | 50 Best, official classification, editorial, member request | yes |
| `source_url` | the official page the estate was verified against | yes |

Outside Europe a "village" is whatever the region's official text is built
from: a comuna in Chile, a departamento in Argentina, a ward in South
Africa. Where that unit is the whole region, the village stays empty.

**Never by name.** Region and village are written per estate with the
reason; a script only checks them. Two estates with one name in two
countries are two rows; the code is the key.

## 3. How a member finds and picks the estate

1. In the wine sheet the Producer field stays free text. From two letters
   it suggests up to three estates from **the server** (`search_vineyards`),
   folded for accents, matching names and aliases, ranked: start of name,
   start of a word, anywhere, then similarity.
2. Each suggestion shows name, then village or region and the country flag,
   so two estates with one name are told apart.
3. Tapping one links it (`vineyard_id`). Typing on past it unlinks it, as
   today. Nothing is ever linked by itself.
4. No match: the wine is kept as written, and one quiet line offers
   "Suggest this estate", which files a request (tier 4).

**Why server search is needed first.** Shipped builds download every row;
PostgREST returns at most 1,000 rows, unordered, so past 1,000 estates a
shipped build silently loses some, possibly ranked ones; and the Wine
Estates collection shows every row, so it would turn from the 50 Best list
into a directory. Until a build that searches on the server is the only one
in the wild, the catalogue should stay well under 1,000 (tiers 0 to 2 fit),
and the collection should list only recognised estates. This is the three
step rule: add the search, ship it, then grow.

## 4. Schema change and server search (applied 2026-11-24)

Product owner, 2026-11-24: "Migration + server search" first. Branch
`claude/vineyards-global`.

- Migration `supabase/migrations/20261101740000_add_vineyard_villages_and_search.sql`:
  `wine_region_communes` (the repo's commune lists as a read only table);
  on `vineyards` `commune_code` (composite foreign key with
  `wine_region_id`; a trigger clears the village whenever the region is
  cleared), `aliases`, `inclusion_reason`, `source_url`, `search_text`
  (trigger, trigram index); `vineyards_full` gains region name, village
  and aliases at the end; `search_vineyards(query, country, limit)`,
  security invoker.
- Data, in this order after the migration:
  `vineyards_global/prepared_wine_region_communes.sql` (13,293 units in
  238 regions, built by `build_wine_region_communes.py`), then batch 1
  part B (24 villages).
- App: the wine sheet asks `search_vineyards` once typing pauses. Before
  the migration is on production the server answers PGRST202 and the
  repository falls back to the on-device match, so the build works on
  either side. `getAll` pages in a fixed order, so the collection and the
  other pickers never lose estates past 1,000 rows (they still download
  every estate; moving them to search is the next app step).
- Tested on a scratch stack: clean replay of all migrations, production's
  regions, estates and ranks loaded read only, communes and part B
  applied, search over REST as anon, grants, the village guard and a
  region delete. Not tested in the simulator.

## 5. Batch 1 (applied 2026-11-24)

`supabase/data/enrichment/vineyards_global/batch_01_existing_44/`: 24
estates get region and village, 16 region only, 4 have no atlas region
(Gusbourne, Perelada, William Chris, Colomé). Part A (regions) needs no
migration and was dry-run against production read only; part B (villages)
needs the migration. QA-540 to QA-543 proposed in its README.

Applying part A alone already lets the 4 linked wines reach a region.

## Batch 2 (applied 2026-11-24)

58 estates: 50 Best ranks 51 to 100, four rechecked held rows, the five
Dutch estates. Production now holds 102 estates, 97 ranked. Details and
QA in `supabase/data/enrichment/vineyards_global/batch_02_w50b/README.md`.

## Decisions (product owner, 2026-11-24)

1. Scope and order: approved ("ja laten we dit allemaal doen").
2. Batch 1 part A: applied ("Yes, apply part A").
3. Migration and three step order: applied ("Yes, apply them"); every
   picker now searches on the server (PR #16, ships with the next build).
4. The Wine Estates collection shows only the top recognised estates;
   every other estate is found through search ("we willen alleen die top
   erkende wijnhuizen echt in de collectie in de app tonen en de rest
   gewoon via zoeken vindbaar maken"). Today that is the current 50 Best
   list; an official classification joins it once its table exists.
5. Addresses read from the page HTML under an unanswered client-side age
   check may stay; clicking one stays off limits ("Yes, keep them").
