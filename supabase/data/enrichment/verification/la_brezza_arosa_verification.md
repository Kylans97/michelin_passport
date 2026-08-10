# La Brezza, Arosa — star-count verification

**Recommendation: CHANGE 3 → 2. Confidence: high.**

## Current state

`rest_0240` "La Brezza", Arosa, Switzerland — stored in `supabase/data/restaurants_master.csv` at **3 MICHELIN stars**, `property_name = null`, linked to Tschuggen Grand Hotel (`hotel_59`) via a shared `google_place_id`.

## What the evidence shows

- **guide.michelin.com's own listing** for La Brezza, Arosa (`/en/graubunden/arosa/restaurant/la-brezza-1191835`) — surfaced via WebSearch (direct WebFetch returned HTTP 403, consistent with this project's documented experience that MICHELIN blocks automated fetching) — describes it as a **Two Stars: Excellent cooking** restaurant in the **2026** MICHELIN Guide Switzerland.
- A second, independent WebSearch pass against the same guide.michelin.com URL for the **2025** guide year confirms the same: **Two Stars**, address Tschuggentorweg 1, Arosa.
- Chef Marco Campanella's own history, per the Tschuggen Collection's own site: arrived at La Brezza in 2018; first MICHELIN star followed his 2019 GaultMillau "Discovery of the Year" recognition; **second star added in 2022**. No source found anywhere — official, press, or aggregator — mentions a third star at this location, ever.
- The Tschuggen Collection's own site additionally states this is the **same 2-star rating** shared with the restaurant's summer sister location, La Brezza at Hotel Eden Roc, Ascona — i.e. one restaurant concept operating seasonally in two places, both currently rated at two stars by MICHELIN (Arosa in winter, Ascona/Eden Roc in summer). This is a materially different picture from what the catalogue currently stores (Arosa distinct restaurant at 3★, Ascona distinct restaurant at 2★).

## Historical progression (verified)

| Year | Stars | Source |
|---|---|---|
| 2019 | 1 | GaultMillau "Discovery of the Year," Tschuggen Collection's own retrospective |
| 2022 | 2 | Tschuggen Collection's own retrospective ("second Michelin star was added in 2022") |
| 2025 | 2 | guide.michelin.com (via WebSearch) |
| 2026 | 2 | guide.michelin.com (via WebSearch) — matches the currently-stored MICHELIN card capture date used to originally populate this row |

**It never held 3 stars at any point covered by available sources.**

## Is `DATABASE_ARCHITECTURE.md`'s worked example therefore incorrect?

**Yes, once this correction is applied.** §7 of that document reads: *"La Brezza appears twice in Switzerland — Arosa at three stars, Ascona at two, 130 km apart, because one chef cooks in each seasonally."* That framing does two things that no longer hold once Arosa is corrected to 2 stars:

1. It asserts a **star-count contrast** (three vs. two) that motivates the example's point about needing `restaurant_code`-based deduplication rather than name matching. With both locations at 2 stars, the *reason the example is illustrative* (merging two different awards) weakens, though the underlying point — two distinct catalogue rows sharing a name — still stands on its own regardless of star count.
2. The "one chef cooks in each seasonally" framing is corroborated by this research (same restaurant concept, same current rating, alternating by season) — that part of the example holds up and is in fact reinforced.

**Per your instruction, `DATABASE_ARCHITECTURE.md` has not been edited.** This is flagged for that document's next revision, not actioned here.

## Recommended catalogue action

Update `rest_0240` (La Brezza, Arosa): `michelin_stars` **3 → 2**. Row already added to `p0_corrections.csv` in this pass (`ma_id = VERIFY-01`).
