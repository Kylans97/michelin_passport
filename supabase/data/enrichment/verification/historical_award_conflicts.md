# Historical award conflicts — resolution

Per the instruction: accuracy over coverage. Where sources genuinely conflict on a specific historical year, the row is marked `unresolved` in `michelin_history_premium/restaurant_award_history.csv` rather than forcing a single value. Both rows below have been edited in that file as part of this verification pass (status changed from `proposed` to `unresolved`; nothing else about them altered).

## ABaC Barcelona (`rest_0002`)

Two rows existed for this restaurant:

| guide_year | award_value | Original status | Action taken |
|---|---|---|---|
| 2012 | 2 stars | proposed | **Left as `proposed`** — no conflict found for this value across sources checked. |
| 2018 | 3 stars | proposed | **Changed to `unresolved`** — barcelonayellow.com dates the third star to 2017; other sources (gourmenials.cat and general press) say 2018. A one-year discrepancy on exactly when the third star was awarded is a real, unresolved conflict, not a rounding difference — the fact of the promotion is solid, the exact guide year is not. |

The 2026-current value (3 stars) is untouched either way — only the historical `2018` row's year is now flagged as uncertain rather than asserted.

## Restaurant de l'Hôtel de Ville, Crissier (`rest_0236`)

One row existed:

| guide_year | award_value | Original status | Action taken |
|---|---|---|---|
| 1975 | 3 stars | proposed (already `low` confidence) | **Changed to `unresolved`** |

This is a wider conflict than ABaC's: bilan.ch dates continuous 3-star status to 1975 (under the site's original name, "Girardet," before the 1996 rebrand to "Restaurant de l'Hôtel de Ville" following the change of chef/ownership); forbes.com and guide.michelin.com's own historical references cite 1994; a further source cites 1992. That's a 19-year spread across three sources, further complicated by the fact that the restaurant's identity itself changed name (and arguably concept/ownership) partway through the disputed period — "held 3 stars continuously since 1975" may be conflating the building/address's history with a single restaurant entity's history. This is exactly the kind of case the instruction anticipates: **left unresolved rather than picking one of three conflicting numbers.**

## What this means for the GREEN/AMBER/RED manifest

Both rows move from the `proposed` count into the `unresolved` count in `restaurant_award_history.csv` — see `APPROVAL_MANIFEST.md`. This reduces the "safe to merge automatically" row count by exactly 2, which is the correct direction: fewer, more defensible proposed rows rather than more, weaker ones.
