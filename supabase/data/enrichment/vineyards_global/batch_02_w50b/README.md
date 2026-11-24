# Batch 2: finish The World's 50 Best Vineyards 2026, plus the Dutch estates

Prepared 2026-11-24 (product owner: "ja laten we dit allemaal doen").
**Nothing here is applied.** Waiting for the product owner's review.

## What is in it

| Group | Rows | Loaded | Held back |
|---|---|---|---|
| Ranks 51 to 100 (`extended_51_100`), codes vine_0056..vine_0105 in rank order | 50 | 49 | Château Mukhrani (vine_0060) |
| Ranks 1 to 50 held back on 2026-11-20, rechecked | 6 | 4 (Tio Pepe, Almaviva, El Enemigo, Philipponnat) | Salentein (vine_0015), Santa Rita (vine_0048) |
| Dutch estates already staged in `vineyards_editorial/` (`editorial_selection`) | 5 | 5 | none |
| **Total** | **61** | **58** | **3** |

Of the 58 loaded: 37 get region and village, 15 region only, 6 no region.
After this batch production would hold 102 estates, 97 of them ranked, so
the Wine Estates collection would show 97 (it shows only ranked estates).

## Files

| File | What it is |
|---|---|
| `research/ranks_051_063.csv` .. `ranks_089_100.csv` | One row per estate, every value from the estate's own site or the organiser's pages, with sources and conflicts in `note` |
| `research/held_back_recheck.csv` | The six held-back estates, rechecked |
| `assemble_batch02.py` | Codes, one written region and village decision per estate, the checks |
| `batch02_estates.csv` | The result, one row per estate, for review |
| `prepared_batch02.sql` | Inserts the 58 estates with region, village and the 2026 ranks |

## Method

Research followed the 1 to 50 method (`worlds_50_best_vineyards/README.md`):
address from the estate's own site; coordinates only from the estate's own
pin, printed coordinates or JSON-LD, never geocoded and never a map
centre. Ranks 51 to 100 have no estate page on the50.com. Each row's
source is instead the organiser's own "The 50 Discovery" page, linked from
its 51 to 100 article (published 9 November 2026). That article also gave
the country and the website link.

Region and village work as in batch 1: chosen by hand per estate, with the
reason, then checked by the script. It checks that the region exists in
the estate's country and that the village is in that region's official
list. Where the estate published a pin, it also checks that the pin lies
inside the region outline, and outside Europe inside the village polygon.

**Tested** on a scratch stack: every migration replayed, then production's
data, the village table, batch 1 part B and this file. Result: 102
estates, 92 with a region, 61 with a village, 97 ranked. Search finds the
new estates with region and village. A second run is refused.

## For you to decide

**Age checks.** None was ever clicked. But for 16 rows the text was read
from the page's own HTML, under a pop-up age check that only hides the
page: 21, 28, 61, 65, 77, 78, 79, 80, 86, 88, 90, 92, 93, 97, 98 and 100
(ranks; vine_00NN for 21 and 28). Is that acceptable? If not, those rows
lose their address and stay in only by name, country and region. Sites
whose server refuses every page without the click stay held back
(Mukhrani, Salentein, Santa Rita).

**Decided 2026-11-24, product owner: "Yes, keep them".** Addresses read
from the HTML under an unanswered client-side overlay stay. Clicking a
check stays off limits.

## Proposed QA log entries

```
QA-544,Access,Medium,vineyards batch 2,ranks 61 65 77 78 79 80 86 88 90 92 93 97 98 100; vine_0021; vine_0028,"Estate sites with a client-side age-check overlay: never clicked, but the address was read from the page HTML served beneath it (Tio Pepe's pages are served without the overlay at all; Almaviva's contact page loads under it)",Product owner decided 2026-11-24: keep them (reading under an unanswered overlay is acceptable; clicking stays off limits),Closed
QA-545,Access,Medium,vineyards batch 2,vine_0060;vine_0015;vine_0048,"Still held back: Château Mukhrani, Bodegas Salentein and Santa Rita serve only an age gate on every page (server side for Salentein); nothing readable without answering it",Human opens the sites past the gate, or the estate is asked; until then not loaded,Open
QA-546,Data conflict,Medium,vineyards wine_region_id,vine_0094,"Babylonstoren: the list and its postal address say Franschhoek, but the estate's own printed GPS (-33.8225, 18.93) lies inside the Paarl district (wr_0039), outside Franschhoek (wr_0038). Loaded without a region",Confirm the Wine of Origin on the estate's labels, then place it,Open
QA-547,Scope gap,Low,vineyards wine_region_id,vine_0072;vine_0078;vine_0086;vine_0091;vine_0104,"No atlas region: Ridge Monte Bello (list 'Santa Clara'; Santa Cruz Mountains AVA by reputation only, not read from the estate), Bodega Bouza (Montevideo), Midalidare (Thracian Lowlands), Graham's Port Lodge (Vila Nova de Gaia is outside the Douro region), Abadía Retuerta (Sardón de Duero is outside Ribera del Duero)",Add regions from official texts where wanted; confirm Ridge from its own labels,Open
QA-548,Data conflict,Low,vineyards batch 2,ranks 52 56 57 66 68 69 77 82 83 86 88; vine_0021,"Logged per row, coordinates withheld where pins disagree: Moët 18/9/20 avenue de Champagne; Brooks Amity (estate) vs Salem (organiser); Castigno cellar pin vs head office address; Torres restaurant address; Henri Giraud no. 71 vs the Manoir at 83; Mission Hill pins 2.3 km apart; Ferrari pins 166 m apart; Rippon postcode 9305 vs 9181; Estocada La Vencedora vs Gualtallary; Graham's GPS vs pin 115 m; Mondavi Napa 94558 vs Oakville 94562; Tio Pepe postcode 11402 vs 11403 (left out)",Review notes before applying,Open
QA-549,Near-miss,Low,vineyards batch 2,ranks 63 76 77 80 83 95; vine_0055,"Placed by definition, not by name: Vajra 'Barolo' in Piedmont; Ferrari 'Trentino' in Trentodoc (lists Trento); Kaiken, Balbo and Estocada in Mendoza although Tupungato is also in Valle de Uco; Occhipinti 'Sicily' in Cerasuolo di Vittoria, the only atlas region holding Vittoria; St. Martinus in Vijlen, not Mergelland (it claims no BOB). Arricau Bordes has no site of its own; website is its producer Plaimont's page",Confirm on review,Open
```
