# Gault&Millau Netherlands & Belgium — Research Report

Retrieval date: 2026-08-11. **Domain note (real gotcha):** Dutch site is **gault-millau.nl** (hyphenated — `gaultmillau.nl` does not resolve). Belgian site is **gaultmillau.be** (no hyphen). Any ingestion pipeline needs these hardcoded correctly.

## Part A — System findings

**A1. Score scale / threshold:** Both markets: 0-20, half-points. No exact official minimum stated on either country site directly; a secondary source (Horecava) paraphrases "~10 points" for NL. Group-wide international FAQ (fr.gaultmillau.com) states "pass mark is 10/20" but this is not confirmed as separately republished on either NL or BE's own domain — their `/en/faq` paths didn't resolve to methodology content when tested directly.

**A2. Toque mapping — same 5-tier table as France, but weakly sourced for NL/BE specifically:**

| Score | Toques |
|---|---|
| 10–10.5 | 0 |
| 11–12.5 | 1 |
| 13–14.5 | 2 |
| 15–16.5 | 3 |
| 17–18.5 | 4 |
| 19–19.5 | 5 (max) |

Only found published on the international/French arm (fr.gaultmillau.com), not independently confirmed on gault-millau.nl or gaultmillau.be directly. **Corroborated by 2 live data points**: GEM. (NL, 18/20) explicitly states "4 koksmutsen"; The Jane (BE, 18.5/20) explicitly states "4 koksmutsen" — both match the table.

**Unresolved discrepancy flagged:** an official gault-millau.nl news post ("Update Scores Gault&Millau Nederland 2022") states *"restaurants with 12 & 12.5 out of 20 now get 1 toque, restaurants with 13 and 13.5 get 2 toques"* — this does not cleanly match the 11-12.5/13-14.5 international bands. May indicate NL runs a locally shifted variant. **Not resolved — do not silently pick one table.**

**A3. Restaurants without a numeric score:**
- **Belgium: YES, confirmed directly.** A separate nav category, **"H!P"**, distinct from "Restaurants" — 250+ addresses (42 new) in the 2026 edition. Verified live: [Martino, Ghent](https://www.gaultmillau.be/en/hip/martino-gent) — H!P of the Year 2026 winner, **no numeric score, no toque count anywhere on the page**, only the H!P badge. Separate URL namespace: `/en/hip/` vs `/en/restaurants/`.
- Also: a normally-scored 3-toque restaurant (Hof van Cleve) reportedly went unscored for one year (2024 edition) during a chef transition — even top restaurants can temporarily lose their score, per secondary source (VRT News). Confirmed it has a score again in 2026 (18/20).
- **Netherlands: not confirmed either way** — no "HIP"-style unscored category found, but absence of evidence isn't evidence of absence.

**A4. Current edition / archive:**
- Belgium: **23rd edition, 2026** — 1,340+ restaurants, 154 new entries, 166 climbers, + 250+ H!P addresses.
- Netherlands: **2026 edition** — 908 restaurants total (up from 865 in 2025), 70 in the printed guide at 16+ points. NL/BE editions appear jointly numbered (21st=2024, 22nd=2025, 23rd=2026) as "Benelux."
- **No systematic archive found on either site** — only forward-looking/current-edition news posts; past scores only reconstructable via individual dated articles or third-party press, not an official structured archive.

**A5. Profile URL patterns:**
- NL: `https://www.gault-millau.nl/en/restaurants/[slug]-[city]`
- BE: `https://www.gaultmillau.be/en/restaurants/[slug]-[city]` (scored) and `https://www.gaultmillau.be/en/hip/[slug]-[city]` (unscored H!P)

**A6. Special awards (2026):**
- **NL:** Chef of the Year, Young Chef of the Year, Host of the Year, Lifetime Achievement, Remarkable Newcomer of the Year, Sommelier of the Year, Best Dutch Chef Abroad, Craftsman of the Year, Wine List of the Year, New Chef on the Block, Vegetable Restaurant of the Year, Pleasure Award, Discovery of the Year, Mediterranean Restaurant, Asian Restaurant, Bistronome of the Year, Terrace of the Year, Cocktail Bar of the Year.
- **BE:** Chef of the Year, Young Chef of the Year (separately for Flanders/Wallonia/Brussels — 3 regional winners), Sommelier of the Year, Hostess of the Year, Best Terrace, Restaurant Design, Italian Restaurant, Asian Restaurant, Dessert, Wine List, Lifetime Achievement, + H!P Selection Winners by region.

## Part B — Sample data (30 restaurants: top 15 NL + top 15 BE by score, 2026 edition, retrieved 2026-08-11)

Both from each country's live sorted directory (`?order=score`). Full detail (address, website, GM URL) in the merged `gault_millau_restaurants.csv`. Headline rows:

**NL top 4:** De Librije (Zwolle, 19.5), Brut172 (Reijmerstok, 19), Ciel Bleu (Amsterdam, 19), Tribeca (Heeze, 19).
**BE top 4:** Boury (Roeselare, 19), L'air du temps (Eghezée, 19), The Jane (Antwerpen, 18.5, 4 toques explicit), Zilte (Antwerpen, 18.5).

Rows 12-15 in each country captured name/city/score from the sorted listing only — address/website marked "not found" rather than guessed, individual profile pages not opened for those 8 rows.

## Data access quality

Both sites fully reachable, no paywalls/blocking. Real gotchas: (1) domain confusion (hyphen in NL, not in BE) — hardcode carefully; (2) **score formatting**: European comma-decimal ("18,5/20") repeatedly got mangled by fetch/extraction into garbled strings ("1820") — manually cross-checked against each page's own descriptive text; a scraper needs a specific parser, not a naive numeric cast; (3) no API/structured export — pure HTML scraping via the sortable/filterable listing pages, which do expose clean slugged URLs; (4) the score-to-toque mapping is the weakest-sourced fact here — only found on the international/French arm, not confirmed as separately published on either NL or BE's own domain, though 2 live data points corroborate it.
