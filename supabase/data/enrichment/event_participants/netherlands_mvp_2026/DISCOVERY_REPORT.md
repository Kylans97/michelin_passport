# Netherlands Premium Gastronomy Event Discovery — Report

Status: research complete across the full Dutch Michelin Key hotel catalogue plus 7 pre-identified candidates. **All three selected MVP events are now APPLIED AND VERIFIED in production** (2026-08-16) — `Erloom x Henrique Sá Pessoa` (`d09498ce-df42-4885-98d9-ec26fae5945c`), `Wildfestival` (`eaad5729-e88c-47fa-b842-0343f6f794a2`), `Vergeet Mij Niet Gala` (`fd23d7f5-ff7c-4caf-ba9b-a17e6397a607`) — each with 0 `event_restaurants`/0 `event_hotels`, correctly and as expected. See each event's own `EVENT_PARTICIPANT_ENRICHMENT_REPORT.md` §"APPLIED AND VERIFIED" for the full record. Git-wise, the accompanying artifacts/docs are staged for commit as part of this same apply task.

**CORRECTION (Dutch Catalogue Gap Pass, `catalogue_gap_pass/`):** this report originally classified Anantara Grand Hotel Krasnapolsky and Hotel Okura Amsterdam as `HOTEL_CATALOGUE_EXPANSION_CANDIDATE` on the reasoning that each hosts a Michelin-starred restaurant. A dedicated follow-up pass reconstructed this project's actual, already-established hotel inclusion rule (1-3 Michelin Keys OR a World's 50 Best Hotels 2023-2025 appearance — explicitly **not** "hosts a starred restaurant") and re-investigated both properties against it. **Both are now classified `NOT_ELIGIBLE_UNDER_CURRENT_RULES`** — see `catalogue_gap_pass/DUTCH_CATALOGUE_GAP_REPORT.md` for the full evidence trail. `michelin_key_hotel_sweep.csv` rows 19-20 have been updated accordingly; this file's own body text below is left as originally written for audit continuity, with this note as the authoritative correction.

---

## Production baseline (queried fresh, read-only)

| Metric | Value |
|---|---|
| Dutch hotels in catalogue | 17 (100% hold Michelin Keys — this catalogue is Key-curated, not a general hotel directory) |
| Dutch Michelin Key hotels | 17 — 11×1 Key, 5×2 Keys, 1×3 Keys |
| Dutch Michelin-starred restaurants | 120 — 99×1★, 20×2★, 1×3★ (realistic distribution, no anomaly) |
| Total production events (all countries) | 1 ('t Preuvenemint) |
| Current future Dutch events | 1 ('t Preuvenemint itself) |

Full 17-hotel sweep: `michelin_key_hotel_sweep.csv`. Full candidate list with scoring: `candidate_events.csv`. Final selection: `mvp_selection.csv`.

## Michelin Key hotel sweep

- **Hotels searched:** all 17 canonical Dutch Key hotels, plus 3 non-canonical properties that surfaced through candidate research (Anantara Grand Hotel Krasnapolsky, Hotel Okura Amsterdam, art'otel Amsterdam).
- **Official sites searched:** all 17 canonical hotels' own websites/agenda pages where reachable; De Echoput, Erloom, ARCA, and the gala's own official sites for the discovered events.
- **Hotels with a qualifying future event found:** 0 of the 17 *canonical* Key hotels directly. All three selected events are hosted at properties **not currently in the production hotel catalogue** — a genuinely important finding, not a research shortfall (see Database Quality below).
- **Hotels with no qualifying event:** the remaining 14 canonical hotels — no discrete, dated, public gastronomic event was found via their own official channels in this pass (several, like Château Neercanne and De L'Europe, host private/corporate events but nothing publicly ticketed and gastronomically distinctive was surfaced).
- **Catalogue gaps surfaced:** Anantara Grand Hotel Krasnapolsky (hosts The White Room, 1★, already in the restaurant catalogue) and Hotel Okura Amsterdam (hosts Ciel Bleu 2★ and Yamazato 1★, both already in the restaurant catalogue) are both real, prominent Amsterdam luxury hotels absent from the canonical hotel catalogue. Their own Michelin Key status could not be independently confirmed via `guide.michelin.com` in this pass — recorded as `HOTEL_CATALOGUE_EXPANSION_CANDIDATE`, not fixed here.

---

## Previously identified candidates — fresh verification results

| Candidate | Status |
|---|---|
| A. Royal Suite Dining (Jacob Jan Boerma) | Series **confirmed real** (multiple editions verified: I, II, III with an April date found, IV "now bookable"); the specific **11-12 September 2026 dates could NOT be independently confirmed** via official source in this pass. The restaurant itself (The White Room by Jacob Jan Boerma) IS a confirmed 1-star EXACT_MATCH candidate. **GOOD BUT DEFER** pending date reconfirmation. |
| B. Wildfestival 2026 | **Confirmed and SELECTED.** 13 Sep 2026, 3rd edition, €114pp, publicly ticketed. |
| C. Erloom × Henrique Sá Pessoa | **Confirmed and SELECTED.** 25-27 Sep 2026, publicly bookable, €99/€129. |
| D. Henrique Sá Pessoa / ARCA / art'otel Amsterdam, 30 Sep-4 Oct | **Could not be verified.** No official source found describing this specific event/date range — likely a conflation with the confirmed Erloom dates or the recurring (undated) ARCA "Behind the Pass" series. **Excluded.** |
| E. Vergeet Mij Niet Gala | **Confirmed and SELECTED.** 6 Oct 2026, 1st edition, €575/seat, publicly bookable. |
| F. 't Lansink Special Events (Truffle Dinner, Game Night) | **Not currently confirmed.** 't Lansink itself is a real, confirmed 1-star restaurant (Hengelo), but no specific dated 2026 special event was found via search or the restaurant's own site in this pass. **Excluded — future monitoring candidate.** |
| G. Ciel Bleu Events (Hotel Okura Amsterdam) | **Not currently confirmed.** Ciel Bleu is a real, confirmed 2-star restaurant, but no specific dated special-event series (beyond normal service) was found in this pass. **Excluded — future monitoring candidate.** |

## New discoveries

Beyond the 7 pre-identified candidates, systematic research surfaced:

- **ARCA "Behind the Pass"** — a genuine recurring (quarterly) guest-chef collaboration series at ARCA/art'otel Amsterdam, hosting past guests Kiko Martins, Vitor Sobral, Schilo Van Coevorden, and Jonathan Zandbergen. No confirmed future 2026 date was found in this pass — recorded as a future-watchlist series (`candidate H` in `candidate_events.csv`), not selected.
- No other genuinely new, sufficiently-evidenced signature/premium events were found across the remaining 14 canonical Key hotels in this pass — Château Neercanne, Château St. Gerlach, De L'Europe, and the Amsterdam boutique hotels (Pillows, Rosewood, Tivoli Doelen, TwentySeven, Pulitzer, The Dylan, The Craftsmen, Soho House) all lack a discrete, dated, public gastronomic event discoverable via their own official channels in this research pass.

---

## MVP recommendation

**#1 — Erloom x Henrique Sá Pessoa** (25-27 Sep 2026, Hilvarenbeek). Highest average score (4.57/5). The single most distinctive concept found — a rotating international guest-chef farm residency, genuinely embodying the "limited culinary residency" archetype the product direction calls out. The chef carries real 2-Michelin-star pedigree (Alma, Lisbon), even though it isn't displayable via the current catalogue.

**#2 — Wildfestival 2026** (13 Sep 2026, Apeldoorn/Veluwe). The clear "public gastronomic festival" portfolio slot — recurring (3rd edition), sells out, closest Dutch analogue to 't Preuvenemint's own proven model.

**#3 — Vergeet Mij Niet Gala** (6 Oct 2026, Amsterdam). The "ultra-premium chef experience" portfolio slot — highest price point of any candidate (€575/seat), black-tie, first-edition, strong charitable-prestige angle, with a plausible (though unconfirmed) tie to two catalogue restaurants via its host hotel.

**Optional #4 — none recommended.** No candidate in the "Michelin Key hotel experience" category met the evidence bar for MVP inclusion (Royal Suite Dining is the closest fit but its specific 2026 dates are unconfirmed). Rather than lower the evidence standard to force a fourth pick, this portfolio slot is left open, with Royal Suite Dining flagged as the priority follow-up (see Future Watchlist).

**Intended portfolio mix:** international guest-chef collaboration (Erloom) + public gastronomic festival (Wildfestival) + ultra-premium exclusive experience (Vergeet Mij Niet Gala) — genuinely distinct formats, cities (Hilvarenbeek, Apeldoorn, Amsterdam), and price points, avoiding four near-identical Amsterdam chef dinners as cautioned against.

### Good but defer

- **Royal Suite Dining Experience** (Jacob Jan Boerma / The White Room) — the strongest *Michelin-tie* candidate found (a confirmed 1-star restaurant), but held back pending confirmation of the specific September 2026 dates via a working official source.

### Excluded (insufficient evidence / unconfirmed)

- ARCA event Sept 30-Oct 4 (candidate D) — could not verify exists.
- 't Lansink Truffle Dinner / Game Night — no current dated event found.
- Ciel Bleu special events — no current dated event found.
- ARCA "Behind the Pass" — real series, no confirmed future 2026 date.

### Routine / excluded on principle

None of the researched candidates were classified C (routine programming) or D (not relevant) — the sweep's official-source-first methodology meant low-signal candidates (standard brunches, generic packages) simply didn't surface as search results in the first place, rather than being found and screened out.

### Past / reference-only

None found — all candidates researched were prospective 2026 editions of ongoing or first-time series.

---

## Michelin participation summary (selected events)

| Event | Restaurant candidates | EXACT_MATCH | Michelin matches | Preview |
|---|---|---|---|---|
| Erloom x Henrique Sá Pessoa | 1 | 0 | 0 | Section would not render (chef's restaurant Alma, 2★, is a genuine Lisbon restaurant not in the catalogue) |
| Wildfestival 2026 | 2 | 0 | 0 | Section would not render (neither De Echoput nor Wild Atelier is in the catalogue) |
| Vergeet Mij Niet Gala | 0 named | 0 | 0 | Section would not render (no specific restaurant participation disclosed yet; Ciel Bleu/Yamazato plausible but unconfirmed) |

**Honest finding:** unlike the earlier Preuvenemint and MVP-2026 international batches, none of the three selected Dutch events currently produce any MICHELIN AT THIS EVENT content. This is disclosed plainly rather than stretched — per the task's own explicit product direction, a Michelin-starred participant is not required for eligibility, and all three events were selected on their own curation merits (novelty, exclusivity, brand fit), not on Michelin-display value.

## Hotel relationships (selected events)

None of the three selected events can be linked to a canonical `event_hotels` relationship — De Echoput, Erloom's farm venue, and Hotel Okura Amsterdam are all absent from the production hotel catalogue (the first two genuinely aren't Key hotels; Okura is a plausible catalogue gap — see Database Quality).

---

## Database quality

- **Netherlands Key coverage:** 17 hotels, 100% Key-holding. Two real, prominent Amsterdam luxury hotels — **Anantara Grand Hotel Krasnapolsky** and **Hotel Okura Amsterdam** — are absent from the catalogue despite each hosting Michelin-starred restaurants that ARE already in the catalogue (The White Room 1★; Ciel Bleu 2★ + Yamazato 1★ respectively). Their own Michelin Key status was not independently confirmed via `guide.michelin.com` in this pass — recorded as `HOTEL_CATALOGUE_EXPANSION_CANDIDATE`, not fixed.
- **Missing Key hotels:** the above two are the only concrete gaps surfaced through this task's research (not an exhaustive Michelin Guide Netherlands cross-reference — that would be a larger, separate audit).
- **Restaurant-star sanity check:** Netherlands' 120 starred restaurants (99×1★/20×2★/1×3★) show a *realistic* distribution, unlike the earlier-flagged Spain/Italy/Austria anomalies — **no GLOBAL CATALOGUE COMPLETENESS flag needed for the Netherlands.**
- **Catalogue-expansion candidates surfaced:** De Echoput, Wild Atelier (both Veluwe), Alma-Lisbon (distinct from the unrelated Alma-Oisterwijk already in the catalogue), ARCA (Amsterdam). None created.

## Future watchlist

- **Royal Suite Dining Experience** (Jacob Jan Boerma / The White Room, Anantara Krasnapolsky) — highest priority: confirm the exact September 2026 (or next) edition dates via a working official source; this is the strongest Michelin-tie candidate found in the entire sweep.
- **ARCA "Behind the Pass"** — quarterly series, confirm the next 2026 guest chef and date.
- **'t Lansink** and **Ciel Bleu** — both real starred restaurants; monitor for any announced special-event programming (truffle/game dinners, chef collaborations).
- **Anantara Grand Hotel Krasnapolsky** and **Hotel Okura Amsterdam** — worth a dedicated hotel-catalogue-expansion look given each already indirectly touches the restaurant catalogue.

---

## Artifacts

- `DISCOVERY_REPORT.md` — this file
- `candidate_events.csv` — all 8 candidates (A-H) with classification and quality scores
- `michelin_key_hotel_sweep.csv` — full 17-hotel canonical sweep + 3 non-canonical properties surfaced by research
- `mvp_selection.csv` — the 3 selected events, summarized
- `erloom_henrique_sa_pessoa/` — `event_payload.json`, `participant_source.csv`, `participant_matches.csv`, `insert_event.sql`, `EVENT_PARTICIPANT_ENRICHMENT_REPORT.md`
- `wildfestival_2026/` — same structure
- `vergeet_mij_niet_gala/` — `event_payload.json`, `insert_event.sql`, `EVENT_PARTICIPANT_ENRICHMENT_REPORT.md` (no participant CSVs — genuinely no participant data exists yet, not omitted for convenience)

No `exact_matches.csv`, `manual_review.csv`, `link_event_restaurants.sql`, or `link_event_hotels.sql` were created for any of the three selected events — none had any EXACT_MATCH, ambiguous match, or hotel relationship to record, and the task's own instruction is explicit: do not create empty noise files.

## Safety

- No event, hotel, or restaurant rows inserted.
- No Michelin stars or Keys changed.
- No `award_history` changes.
- No migrations — schema unchanged.
- No Flutter code touched (`lib/`, `test/` untouched).
- Nothing staged, committed, or pushed.
