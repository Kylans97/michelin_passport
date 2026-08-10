# Country Expansion Sequence — Evidence, Not Assumption

**Status: research and recommendation only. No hotels added, no catalogue expanded.**

Full per-country data: `phase2_country_analysis.csv`.

---

## The central finding

**23 of the 26 countries currently missing from the Chasing Stars hotel catalogue already have confirmed MICHELIN Key coverage**, mostly from the **8–9 October 2025 global MICHELIN Keys reveal** — a single event that took the program from a handful of early markets (France/US/Spain April 2024, Italy May 2024, Japan July 2024, DACH October 2024) to near-global coverage, explicitly adding first-ever selections in dozens of new countries at once, including Australia, mainland China, Hong Kong, India, Indonesia, the Maldives, Morocco, New Zealand, South Africa, Sri Lanka, Thailand's second year, the UAE, the UK & Ireland, and the Caribbean/Central America region (Costa Rica, St. Barthélemy).

This reframes the whole exercise: **the country-coverage gap in the 687-hotel catalogue is very likely a data-collection lag behind MICHELIN's own October 2025 expansion, not a fundamental scope limitation.** Exactly the same pattern found for all 12 hotels in Phase 1 — real Key-holding hotels, simply not yet captured — plausibly repeats at the country level for most of this list. The right next project, in most of these 23 countries, is very likely a data-collection pass under the *existing* Key-hotel rule, not a scope-rule change.

Only 3 countries don't fit this picture:

| Country | Status |
|---|---|
| **Malaysia** | Explicitly confirmed **not** included in the October 2025 launch. No MICHELIN Key data exists yet for this market. |
| **Oman** | Unresolved — the UAE/Middle East launch mentions "five other countries" beyond UAE/Qatar/Saudi Arabia without naming them; Oman is plausible but not confirmed in this pass. |
| **Sweden** | Unresolved — not found in any search this pass. Genuinely unknown, not assumed either way. |

---

## Recommended sequence

Ranked by 2025 Top 50 representation first (the highest-visibility signal), then by total distinct World's 50 Best hotel count — evidence-driven, not the alphabetical or assumed-important ordering the instruction specifically warned against.

| Rank | Country | 2025 Top 50 hotels | Total distinct W50B hotels | Key coverage |
|---|---|---|---|---|
| 1 | United Kingdom | 5 | 9 | Confirmed (124 Keys total) |
| 2 | France | 4 | 11 | Confirmed |
| 3 | Mexico | 4 | 7 | Confirmed (87 Keys total) |
| 4 | UAE | 3 | 3 | Confirmed |
| 5 | Thailand | 3 | 7 | Confirmed (62 Keys total) |
| 6 | Hong Kong | 3 | 6 | Confirmed |
| 7 | United States | 2 | 11 | Confirmed |
| 8 | Australia | 2 | 4 | Confirmed |
| 9 | Indonesia | 2 | 3 | Confirmed |
| 10 | Morocco | 2 | 2 | Confirmed |
| 11 | India | 1 | 5 | Confirmed |
| 12 | Maldives | 1 | 3 | Confirmed |
| 13 | South Africa | 1 | 2 | Confirmed |
| 14 | Greece | 1 | 2 | Confirmed |
| 15 | China (mainland) | 1 | 1 | Confirmed |
| 16–23 | St. Barthélemy, Sri Lanka, French Polynesia, Fiji, Costa Rica, Peru, New Zealand, Turkey | 0 each | 1–2 each | Confirmed, but single-appearance/lower-visibility markets |
| — | Oman, Sweden | 0 | 1 each | **Unresolved — hold** |
| — | Malaysia | 0 | 1 | **No Key data exists — hold** |

### Why the US and France rank below the UK and Mexico despite having more total hotels

France and the US each have 11 distinct World's 50 Best hotels historically — more than the UK's 9 — but the UK has more *current* Top 50 representation (5 vs. 4 and 2 respectively). Weighting toward current visibility over historical volume is a deliberate choice: it prioritizes what would move the "in Chasing Stars today" number the most, which is the more product-relevant signal for a first expansion wave. Total historical volume remains a strong secondary signal (why France still ranks #2 and the US #7 rather than lower) — this is not a case of the US/France being unimportant, just that the UK and Mexico's data would land more of the *current* ranking into the app per hotel researched.

### Note on Hong Kong / China

The two are ranked separately, matching the project's own existing convention (`DATABASE_ARCHITECTURE.md`: "country is geographic, never editorial... Hong Kong... [holds its] own row"). The raw World's 50 Best source data itself is inconsistent here — Rosewood Hong Kong and other Hong Kong-city hotels were labeled country="Hong Kong" in the 2023/2024 lists but country="China" in 2025 — resolved in this analysis by using the hotel's *city* (Hong Kong) rather than the source's inconsistent country label, which correctly keeps all Hong Kong hotels together regardless of which year's raw label was used.
