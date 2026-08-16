# Dutch Catalogue Gap Pass — Report

Status: research complete. **Correction to the prior Netherlands Event Discovery pass**: Hotel Okura Amsterdam and Anantara Grand Hotel Krasnapolsky were previously flagged as `HOTEL_CATALOGUE_EXPANSION_CANDIDATE` on the reasoning that they host Michelin-starred restaurants. That reasoning was **not valid** under this project's actual, already-established hotel inclusion rule — this pass reconstructs that rule from the architecture docs/migrations and re-decides both properties correctly. No production writes.

---

## 1. Reconstructed canonical inclusion rules

**Restaurants** (`docs/Architecture/Michelin_Database/DATABASE_ARCHITECTURE.md`, `START_HERE.md`): a restaurant qualifies if it holds **at least one MICHELIN star**, OR appears on the **current World's 50 Best** list, OR is a **Hall of Fame** (Best of the Best) member. `inclusion_reason` (5 permitted values: `michelin_star`, `worlds_50_best`, `hall_of_fame`, `bib_gourmand` [reserved, unused], `gault_millau`) records only the *original creation reason*, never current status.

**Hotels** — originally Key-only, but **superseded by a union rule** decided and shipped 2026-08-10 (`supabase/data/enrichment/worlds_50_best_hotels/catalogue_expansion/phase7_end_state_report.md`): a hotel qualifies if it holds **1-3 MICHELIN Keys**, OR has appeared in **The World's 50 Best Hotels (2023-2025)**, OR both. `hotels.michelin_keys` is nullable specifically so a hotel can qualify via W50B alone. **Hotels have no `inclusion_reason` column and, per explicit architecture-review guidance, should never get one.**

**Critical, explicitly-documented rule**, stated identically in three architecture docs: **"A starred restaurant inside a hotel is not evidence that the hotel holds a Key."** A restaurant physically inside a non-Key hotel is recorded via `restaurants.is_in_hotel`/`property_name` — the hotel itself gets no row in `hotels` unless it independently qualifies.

**Implication for event enrichment:** "this hotel hosts a Michelin-starred restaurant" is **never**, by itself, grounds to add the hotel to the canonical catalogue — exactly the mistake the prior Netherlands discovery pass made. §18 of `EVENT_PARTICIPANT_ENRICHMENT_STANDARD.md` now documents this explicitly (see that file's own diff).

**Documentation drift found (informational, not fixed):** `DATABASE_ARCHITECTURE.md` and `START_HERE.md` both still state "hotels holds only MICHELIN Key hotels" — neither was updated when the union rule shipped 2026-08-10. The migrations, `hotel.dart`'s own doc comments, and the enrichment reports all agree the union rule is what was actually built; the two architecture docs are simply stale on this one point. Flagged as `INFORMATIONAL` — not corrected in this task (out of scope; a documentation-only fix belonging to whoever next touches those two files).

## 2. Dutch Michelin Key coverage

Production: 17 hotels, all Key-holding (11×1, 5×2, 1×3), zero qualifying via W50B alone (all NL hotels' `worlds_50_best_rank` is null). A full, exhaustive cross-reference against every hotel on the live `guide.michelin.com` Netherlands Key listing was not possible in this pass — `guide.michelin.com` returns HTTP 403 to automated fetches (confirmed directly). Targeted searches for the two specific candidates below were performed instead of a full-catalogue diff; a complete Netherlands Key-hotel reconciliation remains a larger, separate audit if wanted.

## 3. Hotel Okura Amsterdam — investigated fresh

- **Michelin Key evidence:** none found. Multiple searches (including one specifically targeting `guide.michelin.com/hotels-stays`) surfaced only the hotel's **restaurants'** stars — Ciel Bleu (2★), Yamazato (1★), Serre (Bib Gourmand) — never a Key count or Key award statement for the hotel property itself. `guide.michelin.com` does list Okura as a bookable "MICHELIN Guide Hotel" (a partner-booking listing, a materially different and much less selective designation than a Key award).
- **World's 50 Best Hotels evidence:** none found across 2023-2025 coverage searched.
- **Ciel Bleu relationship:** confirmed canonical restaurant (`rest_0025`, Amsterdam, 2★, `status: open`), but `is_in_hotel: false`, `property_name: null` — the hotel-campus relationship is **not currently recorded** despite Ciel Bleu genuinely being inside Okura. Classified `MANUAL_REVIEW`-worthy data gap, not fixed here.
- **Yamazato relationship:** same finding (`rest_0119`, 1★, `status: open`, `is_in_hotel: false`).
- **Decision: `NOT_ELIGIBLE_UNDER_CURRENT_RULES`.** Recommend one final manual check directly against `guide.michelin.com/hotels-stays` (blocked to automated tools in this pass) before treating this as fully closed.

## 4. Anantara Grand Hotel Krasnapolsky — investigated fresh

- **Michelin Key evidence:** none found — same pattern as Okura; only its restaurant The White Room carries recognition.
- **World's 50 Best Hotels evidence:** none found.
- **The White Room relationship:** confirmed canonical restaurant (`rest_0108`, "The White Room by Jacob Jan Boerma", Amsterdam, 1★, `status: open`), but `is_in_hotel: false`, `property_name: null` — same unrecorded-campus-relationship gap as Okura's two restaurants.
- **Decision: `NOT_ELIGIBLE_UNDER_CURRENT_RULES`.** Same recommended final manual check.

## 5. Event-related restaurant gaps

| Candidate | Michelin evidence | Decision |
|---|---|---|
| De Echoput | None found | `NOT_ELIGIBLE_UNDER_CURRENT_RULES` — catalogue-expansion candidate, deferred |
| Wild Atelier | None found | Same |
| Alma (Lisbon, Henrique Sá Pessoa) | **2 Michelin stars, confirmed** | Satisfies the restaurant rule in principle, but Portugal catalogue breadth is a separate, larger workstream (currently 1 restaurant nationwide) — explicitly out of this task's scope, not added |
| ARCA (Amsterdam) | None found | `NOT_ELIGIBLE` — no recognition found at all |

No restaurant was created. A same-named-but-different "Alma" (Oisterwijk, NL, 1★) already exists in the catalogue — explicitly confirmed as a distinct restaurant, not the Lisbon one, avoiding a false-positive link.

## 6. Data-quality side findings

| Finding | Severity |
|---|---|
| Ciel Bleu, Yamazato, The White Room all missing `is_in_hotel`/`property_name` despite being genuinely hotel-restaurant | `NORMAL_CATALOGUE_GAP` |
| `DATABASE_ARCHITECTURE.md`/`START_HERE.md` still describe hotels as "Key-only," not reflecting the 2026-08-10 union-rule update | `INFORMATIONAL` (documentation drift only) |
| Rosewood Amsterdam (already canonical, 2 Keys) initially appeared to be missing a #1 World's 50 Best Hotels 2025 ranking per a misleading headline — **investigated and corrected**: Rosewood Amsterdam is NOT on the official "The World's 50 Best Hotels 2025" list at all (that #1 spot is Rosewood Hong Kong); the Amsterdam property only tops a *different*, unrelated Robb Report list. Production's `worlds_50_best_rank: null` for Rosewood Amsterdam is **correct, not stale** | `INFORMATIONAL` (false alarm, resolved within this pass — no discrepancy exists) |

None of these are `BLOCKING_FOR_EVENT` or `HIGH_PRIORITY_CATALOGUE_GAP` — none prevent any of the three selected events from being inserted; they simply mean those events currently carry no `event_hotels`/`event_restaurants` relationships, which is an accurate, accepted state per the enrichment standard's own product direction.

## 7. Conclusion

**Zero canonical catalogue additions are recommended from this pass.** Both hotel candidates fail the established union rule; the restaurant candidates either lack Michelin recognition or fall outside this task's approved scope (Portugal). This is the enrichment standard's §18 principle working as intended: an event surfacing a venue does not, by itself, justify adding that venue to the canonical catalogue.
