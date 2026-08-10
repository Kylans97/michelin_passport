# MICHELIN 3-Star Restaurants — Award History & Field Enrichment Report

**Scope:** all 121 restaurants in `_source/three_star_restaurants.csv` (current 3-MICHELIN-star restaurants).
**Status:** research only, nothing imported. Every row carries `confidence` / `match_method` / `evidence_source` / `status` per `PROVENANCE_SCHEMA.md`. All rows here are `status = proposed` except the 5 restaurants noted below, which are `unresolved`.

---

## Part 1 — Historical star-award data

**Output:** `restaurant_award_history.csv` (177 rows), `restaurant_history_unresolved.csv` (5 rows)

- **116 of 121 restaurants (96%)** now have at least one historical `award_history`-shaped row with a real `guide_year` (never the 2026 placeholder).
- Of those 116, **68 restaurants** have a full multi-tier progression recorded (e.g. "1 star 2010, 2 stars 2012, 3 stars since 2013"), not just the first 3-star year.
- **5 restaurants (4%)** are in the unresolved file — see below.
- Confidence split across the 177 rows: **120 high, 55 medium, 2 low**. `guide.michelin.com` blocked automated fetching for most direct lookups (as expected per the task brief), so most rows are sourced from press coverage, official restaurant sites, and Wikipedia rather than the primary MICHELIN card; confidence was set accordingly (`high` only where multiple consistent secondary sources agree, `medium`/`low` where sources conflict).

**How far back does the data go?** First-3-star years range from **1975** (Restaurant de l'Hôtel de Ville, Crissier — flagged `low` confidence, see caveat below) to **2026** (Kadeau, Copenhagen). The average first-3-star year across the 116 verified restaurants is **~2016**, and the distribution by decade of first award is:

| Decade of first 3-star award | Restaurants |
|---|---|
| 1970s | 1 |
| 1980s | 1 |
| 1990s | 4 |
| 2000s | 18 |
| 2010s | 44 |
| 2020s (through 2026) | 48 |

Oldest confirmed three-star holders: Restaurant de l'Hôtel de Ville (1975, low confidence — see caveat), Arzak (1989), Schwarzwaldstube (1993), Enoteca Pinchiorri (1993), Arpège (1996).
Most recently promoted: Kadeau (2026), and a cluster of 2025 promotions (Sushi Sho NY, FZN by Björn Frantzén, Trèsind Studio, Restaurant Haerlin, Tohru in der Schreiberei, Steirereck im Stadtpark, Sorn).

### The 5 unresolved restaurants

| restaurant_code | name | reason |
|---|---|---|
| rest_0240 | La Brezza (Arosa) | **Likely source data-quality issue, not a missing-history case.** Every current source shows La Brezza at the Tschuggen Grand Hotel, Arosa (chef Marco Campanella) holding **two** MICHELIN stars, not three. A different, unrelated "La Brezza" at Hotel Eden Roc, Ascona also exists — do not conflate the two. Flagged for separate P0 review rather than fabricating a 3-star history. |
| rest_0487 | Miyamasou (Kyoto) | Secondary source dates the 3-star award to 2026 itself — the same year as the current row this workspace does not restate. No distinct pre-2026 tier history found. |
| rest_0493 | Myojaku (Tokyo) | Same situation as Miyamasou — award year coincides with 2026, no prior-tier history found. |
| rest_0740 | Californios (San Francisco) | Same situation — award year coincides with 2026, no prior-tier history found. |
| rest_0741 | Restaurant Enclos (Sonoma) | Same situation — award year coincides with 2026, no prior-tier history found. |

Four of the five are not really "missing" data so much as restaurants whose only known 3-star year is the current one — there is nothing pre-2026 to record yet, and confirming that requires primary MICHELIN archive access this workspace couldn't reach.

### Notable verification difficulties
- **`guide.michelin.com` blocked WebFetch** (HTTP 403) on every direct attempt — all MICHELIN-sourced facts came from search-result snippets, press articles quoting MICHELIN ceremonies, or Wikipedia, per the task's guidance to fall back and lower confidence.
- **Conflicting sources on exact year**: ABaC Barcelona (2017 vs 2018), Cheval Blanc by Peter Knogl Basel (2015 vs 2016), Restaurant de l'Hôtel de Ville Crissier (1975 vs 1992 vs 1994 — compounded by a mid-history restaurant rename from "Girardet" to its current name), Le Bernardin (exact NYC guide launch year ambiguity). All recorded at `medium` or `low` confidence with the conflict noted in `evidence_source`.
- **Restaurants that may have since closed or changed status**: Aqua (Wolfsburg) — press reports the restaurant closing March 2026; La Brezza (Arosa) — see above. Both flagged in `evidence_source` text for human reviewer awareness; neither guardrail-violates since this workspace doesn't touch the current row either way.
- **WebSearch budget exhausted mid-task** (hit the 200-call session cap). The remaining ~25 restaurants (mostly the Kyoto/Osaka kaiseki cluster and the Tokyo/US clusters) were researched via WebFetch against Wikipedia's "List of Michelin 3-starred restaurants" and individual restaurant articles instead — still real, cited sources, but capped at `medium` confidence since Wikipedia is a secondary/tertiary aggregator rather than primary press or the MICHELIN card itself.

---

## Part 2 — Field enrichment (cuisine, website_url, michelin_url, booking_url)

**Output:** `field_enrichment/restaurants_3star_fields.csv` (153 proposed rows)

| Field | Before | After (incl. proposed) | Coverage before → after |
|---|---:|---:|---|
| `cuisine` | 72 / 121 | 111 / 121 | 60% → 92% |
| `website_url` | 1 / 121 | 67 / 121 | 1% → 55% |
| `michelin_url` | 24 / 121 | 70 / 121 | 20% → 58% |
| `booking_url` | 0 / 121 | 2 / 121 | 0% → 2% |

Confidence split across the 153 field rows: **108 high, 45 medium**, none low (fields below `medium` confidence — e.g. a website URL I couldn't confirm was official — were left out rather than proposed).

**`booking_url` is the weak spot by design, not by omission.** Almost none of these restaurants expose a reservation URL distinct from their own website (no separate "book now" domain) — the two found (Jungsik New York via Tock, FZN Dubai via SevenRooms) were genuine third-party booking-platform links surfaced incidentally during other research. Per the brief's guardrail, we did not fetch or store any Google ratings/reviews, and did not guess a booking link where none was evidenced.

**`website_url` is the field with the most remaining headroom** — 54 restaurants still have no proposed value, concentrated in the Japan kaiseki cluster (Miyamasou, Mizai, Gion Sasaki, Taian, Kashiwaya, Hajime, Myojaku — many traditional ryotei don't run conventional websites at all) and a scattering of European fine-dining rooms where no distinctly "official" domain could be confirmed with medium+ confidence in the time available (e.g. Schloss Schauenstein, Da Vittorio, Aponiente).

---

## Bottom line

- **116 / 121 (96%)** restaurants got at least one real, sourced historical award row; the other 5 are honestly flagged rather than guessed, including one likely data-quality issue in the source master itself (La Brezza / Arosa).
- Field enrichment materially improved all three in-scope columns with real values: cuisine +39, website_url +66, michelin_url +46, booking_url +2.
- Everything here is `proposed` or `unresolved` pending human review — nothing has been written to `supabase/data/*.csv` or any live database.
