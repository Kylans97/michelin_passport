# Catalogue Gaps and the Product Scope Question

**Status: research and analysis only. No catalogue rule has been changed.**

---

## 1. Current catalogue coverage (structural context)

The 687-hotel catalogue covers **21 countries only**: Italy, Germany, Japan, Spain, Austria, Switzerland, Netherlands, Belgium, Hungary, Poland, Croatia, Singapore, Malta, Montenegro, Slovenia, Serbia, Andorra, Monaco, Luxembourg, Brazil, Aruba.

This matters enormously for what follows: **the United States, United Kingdom, France, Thailand, UAE, Hong Kong, China, Mexico, Morocco, Maldives, Indonesia, South Africa, India, Australia, Sri Lanka and most other markets have zero hotels in the catalogue at all** — not because those markets' MICHELIN Key hotels were individually evaluated and rejected, but because hotel-catalogue coverage simply hasn't reached those countries yet. (The restaurant catalogue, by contrast, already spans 38 countries including all of the above.) Every gap reported below should be read through that lens: most of it is a coverage-stage fact about the hotel catalogue's current build state, not a signal about which specific hotels do or don't belong.

---

## 2. Every World's 50 Best hotel missing from the catalogue

109 distinct hotel identities across the 2023–2025 editions are not in the catalogue. Full per-hotel detail, every ranking year, and the exact reason for each: `worlds_50_best_hotels_review.csv`. Summarized:

| Reason | Distinct hotels (2023–2025 combined) | Distinct hotels (2025 Top 50 only) |
|---|---|---|
| Country not in the catalogue at all | 96 | 35 |
| Country covered, this specific hotel not present | 13 | 7 |
| **Total missing** | **109** | **42** |

### The 13 "country covered, specifically missing" cases deserve individual attention

These are not coverage-stage gaps — the catalogue has other hotels in these exact countries, so each of these represents either a real research gap or a genuine editorial choice not yet made:

| Hotel | Country | Years ranked | Notable |
|---|---|---|---|
| **Passalacqua** | Italy | 2023, 2024, 2025 | **The World's Best Hotel 2023** (rank 1). Not present under any name in the catalogue. |
| **Four Seasons Firenze** / **Four Seasons Hotel Firenze** | Italy | 2023, 2024, 2025 | Top-10 twice (#9 in 2023 and 2025). Confirmed absent — catalogue's only Florence entries are unrelated properties. |
| **Aman Tokyo** | Japan | 2023, 2024, 2025 | Top-10 twice (#5 2023, #7 2024, #25 2025). Distinct from the catalogue's "Aman Kyoto" — different city, different property. |
| Bulgari Roma | Italy | 2025 | Distinct from the catalogue's "Bvlgari Hotel Tokyo" — different city entirely. |
| Hotel Il Pellicano | Italy | 2025 | Not present under any name. |
| Borgo Santandrea | Italy | 2024, 2025 | Distinct from the catalogue's "Borgo Santo Pietro" — different region (Amalfi vs. Tuscany). |
| The Tokyo Edition Toranomon | Japan | 2025 | Not present under any name. |
| Hotel Cipriani | Italy | 2025 | Distinct from the catalogue's "Casa Cipriani Milano" — different city, related but separate hospitality brand. |
| Hoshinoya Tokyo | Japan | 2023 | Distinct from the catalogue's "Hoshinoya Kyoto" — different city, same brand. |
| Six Senses Ibiza | Spain | 2023 | Distinct from the catalogue's "Petunia Ibiza, Beaumier Hotel" — different property. |
| Rosewood São Paulo | Brazil | 2023, 2024, 2025 | Brazil's only catalogue hotel is Copacabana Palace (Rio) — different city. |
| Hotel das Cataratas | Brazil | 2025 | Same Brazil constraint as above. |

**Current Michelin Key status of these 13**: not independently verified in this pass — that would require the same kind of individual research the P0 and premium-history workstreams did for restaurants, and is out of scope for this research-and-matching pass. Flagged here as the natural next step, not answered by guessing.

**Whether each belongs in Chasing Stars under current catalogue rules**: no — the current rule is Key hotels only (see §3), and none of these 13 is confirmed to hold a Key. If any of them does hold a Key and simply hasn't been captured yet, that's a research gap to close under the *existing* rule, not a scope question. If none of them holds a Key, including them requires the scope decision in §3.

---

## 3. The product scope question

> Should the Chasing Stars hotel catalogue remain "Michelin Key hotels only," or eventually become "Michelin Key hotels + World's 50 Best Hotels" — the same shape of rule the restaurant catalogue already applies (World's 50 Best / Hall of Fame venues included even without a current star)?

### The restaurant precedent, precisely

`DATABASE_ARCHITECTURE.md` §3.3 sets the restaurant scope rule as three independent qualifying conditions: a current MICHELIN star, a place on the current World's 50 Best list, **or** Hall of Fame membership. Seven restaurants in the current catalogue qualify only through the second or third condition and hold no star at all — Maido, the World's 50 Best No.1 in 2025, is the worked example the architecture doc itself uses.

### Why the hotel case is not a clean copy of that precedent

1. **No hotel in the catalogue today qualifies any way other than through a Key.** Every one of the 687 rows holds at least one Michelin Key by construction (`michelin_keys smallint not null check (between 1 and 3)` — there's no nullable path, unlike `restaurants.michelin_stars`). Extending the rule to World's 50 Best Hotels would be a genuinely new scope category, not filling out a branch of a rule that already exists structurally.
2. **The hotel list has no Hall of Fame equivalent.** The restaurant rule's third branch (permanent inclusion for the most celebrated restaurants in the list's history) has nothing to point to on the hotel side — confirmed by research, not assumed. A hotel-side rule modeled on the restaurant one would have only two branches, not three.
3. **The scale of the addition is much larger, proportionally, than the restaurant case.** Seven of 775 restaurants (0.9%) qualify via World's 50 Best alone. For hotels, even restricting to just the *current* Top 50: **42 of the 50 are not in the catalogue at all** (84%) — though the overwhelming majority of that (35 of 42) is the country-coverage gap from §1, not a scope-rule gap. Isolating for the scope question specifically — hotels in an *already-covered* country that would newly qualify — the number is much smaller: **13 hotels** (the table in §2), assuming none holds a Key already.

### How many additional hotels the rule would add, precisely

| Scope | Additional hotels |
|---|---|
| 2025 Top 50 only, hotels in already-covered countries | 13 (all of §2's list happen to be in already-covered countries by definition — country coverage and the scope question are two separate axes, and every "specifically missing" hotel is, by definition, in a covered country) |
| 2025 Top 50, all countries (if hotel-catalogue country coverage also expanded) | 42 |
| Full 2023–2025 historical universe, already-covered countries only | 13 (same set — no additional country-covered hotel appears only in a past year and not 2025) |
| Full 2023–2025 historical universe, all countries | 109 |

**The practical reading**: the scope question and the country-coverage question are separable, but in today's data they mostly move together, because most World's 50 Best Hotels are concentrated in markets (US, France, UK, Thailand, Middle East, wider Asia) the hotel catalogue hasn't reached yet regardless of any scope decision. Answering "yes, widen the rule" today would add a real but modest 13 hotels; the much bigger number (109, or even just 42) is gated on the country-coverage work happening first, independent of this decision.

### Recommendation

**Defer the rule change; do not implement it now** — consistent with the instruction. When it is revisited, frame it as two separate decisions, not one:

1. Should hotel-catalogue country coverage expand toward the restaurant catalogue's 38-country footprint? (A data-collection question, independent of World's 50 Best.)
2. Given that coverage, should a hotel with a current World's 50 Best rank but no Key be admitted? (A scope-rule question, directly analogous to the restaurant precedent, but — per §3.1 above — without a Hall-of-Fame third branch to mirror exactly.)

Both are real, defensible product directions. Neither should be decided as a side effect of this hotel-history data-preparation pass.
